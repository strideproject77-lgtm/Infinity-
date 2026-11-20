/* SPDX-License-Identifier: GPL-2.0-or-later */
#include "husk-tl-jni-refs.h"
#include "husk-tl-dvm.h"

#include <pthread.h>
#include <stdlib.h>

struct tl_jni_ref_handle {
    struct tl_jni_ref_handle *next;
    struct tl_jni_ref_handle *release_next;
    jobj *object;
    jobj *release_object;
    pthread_t owner;
    uint32_t frame_depth;
    tl_jni_ref_kind kind;
    bool alive;
    bool weak_retained;
    uintptr_t token_id;
};

static pthread_mutex_t g_refs_lock = PTHREAD_MUTEX_INITIALIZER;
static tl_jni_ref_handle *g_refs;
static bool g_weak_gc_enabled;
static uintptr_t g_next_token_id = 1;
static __thread uint32_t t_frame_depth;

static tl_jni_ref_handle *find_locked(tl_jni_ref_handle *candidate)
{
    if (!candidate) return NULL;
    for (tl_jni_ref_handle *h = g_refs; h; h = h->next)
        if (h == candidate) return h;
    return NULL;
}

static bool local_owned_by_caller(const tl_jni_ref_handle *h)
{
    return h->kind != TL_JNI_REF_LOCAL || pthread_equal(h->owner, pthread_self());
}

static tl_jni_ref_handle *create_handle(jobj *object, tl_jni_ref_kind kind)
{
    if (!object || kind < TL_JNI_REF_LOCAL || kind > TL_JNI_REF_WEAK_GLOBAL) return NULL;

    tl_jni_ref_handle *h = calloc(1, sizeof(*h));
    if (!h) return NULL;

    h->kind = kind;
    h->alive = true;
    if (kind == TL_JNI_REF_LOCAL) {
        h->object = tl_jni_ref(object);
        h->owner = pthread_self();
        h->frame_depth = t_frame_depth;
    } else if (kind == TL_JNI_REF_GLOBAL) {
        h->object = tl_jni_ref(object);
    }

    pthread_mutex_lock(&g_refs_lock);
    if (kind == TL_JNI_REF_WEAK_GLOBAL) {
        if (g_weak_gc_enabled) {
            h->object = object;
        } else {
            h->object = tl_jni_ref(object);
            h->weak_retained = true;
        }
    }
    if (g_next_token_id == 0) {
        bool release_object = h->object &&
            (h->kind != TL_JNI_REF_WEAK_GLOBAL || h->weak_retained);
        jobj *object = release_object ? h->object : NULL;
        pthread_mutex_unlock(&g_refs_lock);
        if (object) tl_jni_unref(object);
        free(h);
        return NULL;
    }
    h->token_id = g_next_token_id++;
    h->next = g_refs;
    g_refs = h;
    pthread_mutex_unlock(&g_refs_lock);
    return h;
}

bool tl_jni_refs_push_local_frame(size_t capacity)
{
    (void)capacity; /* The JNI adapter reserves the corresponding ABI capacity. */
    if (t_frame_depth == UINT32_MAX) return false;
    t_frame_depth++;
    return true;
}

tl_jni_ref_handle *tl_jni_refs_pop_local_frame(tl_jni_ref_handle *preserve)
{
    jobj *preserved_object = tl_jni_refs_acquire(preserve);
    if (t_frame_depth == 0) {
        if (preserved_object) tl_jni_unref(preserved_object);
        return NULL;
    }

    tl_jni_ref_handle *release = NULL;
    pthread_mutex_lock(&g_refs_lock);
    tl_jni_ref_handle **cursor = &g_refs;
    while (*cursor) {
        tl_jni_ref_handle *h = *cursor;
        if (h->alive && h->kind == TL_JNI_REF_LOCAL &&
            pthread_equal(h->owner, pthread_self()) && h->frame_depth == t_frame_depth) {
            h->alive = false;
            h->release_object = h->object;
            h->object = NULL;
            h->release_next = release;
            release = h;
        }
        cursor = &h->next;
    }
    pthread_mutex_unlock(&g_refs_lock);

    while (release) {
        tl_jni_ref_handle *next = release->release_next;
        if (release->release_object) tl_jni_unref(release->release_object);
        release->release_object = NULL;
        release->release_next = NULL;
        release = next;
    }
    t_frame_depth--;

    tl_jni_ref_handle *result = preserved_object ? create_handle(preserved_object, TL_JNI_REF_LOCAL) : NULL;
    if (preserved_object) tl_jni_unref(preserved_object);
    return result;
}

tl_jni_ref_handle *tl_jni_refs_new_local(jobj *object)
{
    return create_handle(object, TL_JNI_REF_LOCAL);
}

tl_jni_ref_handle *tl_jni_refs_new_global(jobj *object)
{
    return create_handle(object, TL_JNI_REF_GLOBAL);
}

tl_jni_ref_handle *tl_jni_refs_new_weak_global(jobj *object)
{
    return create_handle(object, TL_JNI_REF_WEAK_GLOBAL);
}

void tl_jni_refs_delete(tl_jni_ref_handle *handle, tl_jni_ref_kind expected_kind)
{
    jobj *release = NULL;
    pthread_mutex_lock(&g_refs_lock);
    tl_jni_ref_handle *h = find_locked(handle);
    if (h && h->alive && (expected_kind == TL_JNI_REF_INVALID || h->kind == expected_kind) &&
        local_owned_by_caller(h)) {
        h->alive = false;
        if (h->kind != TL_JNI_REF_WEAK_GLOBAL || h->weak_retained) release = h->object;
        h->object = NULL;
        h->weak_retained = false;
    }
    pthread_mutex_unlock(&g_refs_lock);
    if (release) tl_jni_unref(release);
}

jobj *tl_jni_refs_acquire(tl_jni_ref_handle *handle)
{
    jobj *object = NULL;
    pthread_mutex_lock(&g_refs_lock);
    tl_jni_ref_handle *h = find_locked(handle);
    if (h && h->alive && local_owned_by_caller(h) && h->object)
        object = tl_jni_ref(h->object);
    pthread_mutex_unlock(&g_refs_lock);
    return object;
}

static tl_jni_ref_handle *find_token_locked(const void *token)
{
    uintptr_t id = (uintptr_t)token;
    if (!id) return NULL;
    for (tl_jni_ref_handle *h = g_refs; h; h = h->next)
        if (h->token_id == id) return h;
    return NULL;
}

void *tl_jni_refs_export_token(tl_jni_ref_handle *handle)
{
    if (!handle) return NULL;
    pthread_mutex_lock(&g_refs_lock);
    tl_jni_ref_handle *h = find_locked(handle);
    void *token = h && h->alive && local_owned_by_caller(h)
        ? (void *)(uintptr_t)h->token_id : NULL;
    pthread_mutex_unlock(&g_refs_lock);
    return token;
}

jobj *tl_jni_refs_acquire_token(const void *token)
{
    jobj *object = NULL;
    pthread_mutex_lock(&g_refs_lock);
    tl_jni_ref_handle *h = find_token_locked(token);
    if (h && h->alive && local_owned_by_caller(h) && h->object)
        object = tl_jni_ref(h->object);
    pthread_mutex_unlock(&g_refs_lock);
    return object;
}

tl_jni_ref_kind tl_jni_refs_token_kind(const void *token)
{
    tl_jni_ref_kind kind = TL_JNI_REF_INVALID;
    pthread_mutex_lock(&g_refs_lock);
    tl_jni_ref_handle *h = find_token_locked(token);
    if (h && h->alive && local_owned_by_caller(h)) kind = h->kind;
    pthread_mutex_unlock(&g_refs_lock);
    return kind;
}

tl_jni_ref_kind tl_jni_refs_get_kind(tl_jni_ref_handle *handle)
{
    tl_jni_ref_kind kind = TL_JNI_REF_INVALID;
    pthread_mutex_lock(&g_refs_lock);
    tl_jni_ref_handle *h = find_locked(handle);
    if (h && h->alive && local_owned_by_caller(h)) kind = h->kind;
    pthread_mutex_unlock(&g_refs_lock);
    return kind;
}

bool tl_jni_refs_is_same(tl_jni_ref_handle *left, tl_jni_ref_handle *right)
{
    /* JNI defines two null references as the same. Do not use token equality
     * for non-null handles: a deleted/tombstoned token is not a live object
     * reference, even when both arguments contain that same stale token. */
    if (!left || !right) return left == right;

    jobj *a = tl_jni_refs_acquire(left);
    jobj *b = tl_jni_refs_acquire(right);
    bool same = a && b && a == b;
    if (a) tl_jni_unref(a);
    if (b) tl_jni_unref(b);
    return same;
}

void tl_jni_refs_detach_thread(void)
{
    tl_jni_ref_handle *release = NULL;
    pthread_mutex_lock(&g_refs_lock);
    tl_jni_ref_handle **cursor = &g_refs;
    while (*cursor) {
        tl_jni_ref_handle *h = *cursor;
        if (h->alive && h->kind == TL_JNI_REF_LOCAL && pthread_equal(h->owner, pthread_self())) {
            h->alive = false;
            h->release_object = h->object;
            h->object = NULL;
            h->release_next = release;
            release = h;
        }
        cursor = &h->next;
    }
    pthread_mutex_unlock(&g_refs_lock);

    while (release) {
        tl_jni_ref_handle *next = release->release_next;
        if (release->release_object) tl_jni_unref(release->release_object);
        release->release_object = NULL;
        release->release_next = NULL;
        release = next;
    }
    t_frame_depth = 0;
}

void tl_jni_refs_enable_weak_gc(void)
{
    /* Weak-handle transitions are collector metadata mutations. Never drop the
     * strong-retention fallback outside the active stop-the-world owner. */
    if (!tl_dvm_safepoint_is_owner()) return;
    tl_jni_ref_handle *release = NULL;
    pthread_mutex_lock(&g_refs_lock);
    g_weak_gc_enabled = true;
    for (tl_jni_ref_handle *h = g_refs; h; h = h->next) {
        if (h->alive && h->kind == TL_JNI_REF_WEAK_GLOBAL && h->weak_retained) {
            h->weak_retained = false;
            h->release_next = release;
            release = h;
        }
    }
    pthread_mutex_unlock(&g_refs_lock);

    while (release) {
        tl_jni_ref_handle *next = release->release_next;
        if (release->object) tl_jni_unref(release->object);
        release->release_next = NULL;
        release = next;
    }
}

bool tl_jni_refs_visit_strong_roots(tl_jni_refs_root_visitor visitor, void *context)
{
    if (!visitor) return false;

    /* Build a complete snapshot under one lock acquisition so concurrent
     * handle creation/deletion cannot make a two-pass count stale. Collector
     * callbacks are always invoked after releasing the registry mutex. */
    jobj **snapshot = NULL;
    size_t count = 0, capacity = 0;
    pthread_mutex_lock(&g_refs_lock);
    for (tl_jni_ref_handle *h = g_refs; h; h = h->next) {
        bool strong = h->kind != TL_JNI_REF_WEAK_GLOBAL || h->weak_retained;
        if (!h->alive || !h->object || !strong) continue;
        if (count == capacity) {
            size_t next_capacity = capacity ? capacity * 2 : 16;
            if (next_capacity < capacity || next_capacity > SIZE_MAX / sizeof(*snapshot)) {
                pthread_mutex_unlock(&g_refs_lock);
                free(snapshot);
                return false;
            }
            jobj **grown = realloc(snapshot, next_capacity * sizeof(*snapshot));
            if (!grown) {
                pthread_mutex_unlock(&g_refs_lock);
                free(snapshot);
                return false;
            }
            snapshot = grown;
            capacity = next_capacity;
        }
        snapshot[count++] = h->object;
    }
    pthread_mutex_unlock(&g_refs_lock);

    for (size_t i = 0; i < count; i++) visitor(snapshot[i], context);
    free(snapshot);
    return true;
}

void tl_jni_refs_process_weak(tl_jni_refs_is_marked is_marked, void *context)
{
    /* Clearing weak targets is only valid while every DVM mutator is parked.
     * The guest ABI still uses raw object pointers, so weak-GC activation remains
     * disabled by default until handle resolution is converted at the JNI boundary. */
    if (!is_marked || !tl_dvm_safepoint_is_owner()) return;
    pthread_mutex_lock(&g_refs_lock);
    if (g_weak_gc_enabled) {
        for (tl_jni_ref_handle *h = g_refs; h; h = h->next) {
            if (h->alive && h->kind == TL_JNI_REF_WEAK_GLOBAL && h->object &&
                !is_marked(h->object, context)) h->object = NULL;
        }
    }
    pthread_mutex_unlock(&g_refs_lock);
}
