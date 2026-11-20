/* SPDX-License-Identifier: GPL-2.0-or-later */
#include "husk-tl-jni-refs.h"

#include <pthread.h>
#include <stdlib.h>

struct tl_jni_ref_handle {
    struct tl_jni_ref_handle *next;
    jobj *object;
    pthread_t owner;
    uint32_t frame_depth;
    tl_jni_ref_kind kind;
    bool alive;
};

/*
 * Handle records are tombstoned instead of freed. JNI permits stale values to
 * be passed back to deletion and identity entry points; retaining the tiny
 * token record prevents allocator address reuse from making a stale token
 * alias a newly-created reference. The Java object is released at deletion.
 */
static pthread_mutex_t g_refs_lock = PTHREAD_MUTEX_INITIALIZER;
static tl_jni_ref_handle *g_refs;
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

    h->object = (kind == TL_JNI_REF_WEAK_GLOBAL) ? object : tl_jni_ref(object);
    h->kind = kind;
    h->alive = true;
    if (kind == TL_JNI_REF_LOCAL) {
        h->owner = pthread_self();
        h->frame_depth = t_frame_depth;
    }

    pthread_mutex_lock(&g_refs_lock);
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
    jobj *preserved_object = tl_jni_refs_resolve(preserve);
    if (preserved_object) tl_jni_ref(preserved_object);

    if (t_frame_depth == 0) {
        if (preserved_object) tl_jni_unref(preserved_object);
        return NULL;
    }

    jobj **release = NULL;
    size_t count = 0, capacity = 0;
    pthread_mutex_lock(&g_refs_lock);
    for (tl_jni_ref_handle *h = g_refs; h; h = h->next) {
        if (h->alive && h->kind == TL_JNI_REF_LOCAL &&
            pthread_equal(h->owner, pthread_self()) && h->frame_depth == t_frame_depth) {
            if (count == capacity) {
                size_t next = capacity ? capacity * 2 : 8;
                jobj **items = realloc(release, next * sizeof(*items));
                if (!items) continue; /* Keep this handle live if release storage fails. */
                release = items;
                capacity = next;
            }
            h->alive = false;
            release[count++] = h->object;
            h->object = NULL;
        }
    }
    pthread_mutex_unlock(&g_refs_lock);

    for (size_t i = 0; i < count; i++) tl_jni_unref(release[i]);
    free(release);
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
        if (h->kind != TL_JNI_REF_WEAK_GLOBAL) release = h->object;
        h->object = NULL;
    }
    pthread_mutex_unlock(&g_refs_lock);
    if (release) tl_jni_unref(release);
}

jobj *tl_jni_refs_resolve(tl_jni_ref_handle *handle)
{
    jobj *object = NULL;
    pthread_mutex_lock(&g_refs_lock);
    tl_jni_ref_handle *h = find_locked(handle);
    if (h && h->alive && local_owned_by_caller(h)) object = h->object;
    pthread_mutex_unlock(&g_refs_lock);
    return object;
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
    if (left == right) return true;
    jobj *a = tl_jni_refs_resolve(left);
    jobj *b = tl_jni_refs_resolve(right);
    return a && b && a == b;
}

void tl_jni_refs_detach_thread(void)
{
    jobj **release = NULL;
    size_t count = 0, capacity = 0;
    pthread_mutex_lock(&g_refs_lock);
    for (tl_jni_ref_handle *h = g_refs; h; h = h->next) {
        if (h->alive && h->kind == TL_JNI_REF_LOCAL && pthread_equal(h->owner, pthread_self())) {
            if (count == capacity) {
                size_t next = capacity ? capacity * 2 : 8;
                jobj **items = realloc(release, next * sizeof(*items));
                if (!items) continue;
                release = items;
                capacity = next;
            }
            h->alive = false;
            release[count++] = h->object;
            h->object = NULL;
        }
    }
    pthread_mutex_unlock(&g_refs_lock);
    for (size_t i = 0; i < count; i++) tl_jni_unref(release[i]);
    free(release);
    t_frame_depth = 0;
}

void tl_jni_refs_visit_strong_roots(tl_jni_refs_root_visitor visitor, void *context)
{
    if (!visitor) return;
    pthread_mutex_lock(&g_refs_lock);
    for (tl_jni_ref_handle *h = g_refs; h; h = h->next) {
        if (h->alive && h->object && h->kind != TL_JNI_REF_WEAK_GLOBAL)
            visitor(h->object, context);
    }
    pthread_mutex_unlock(&g_refs_lock);
}

void tl_jni_refs_process_weak(tl_jni_refs_is_marked is_marked, void *context)
{
    if (!is_marked) return;
    pthread_mutex_lock(&g_refs_lock);
    for (tl_jni_ref_handle *h = g_refs; h; h = h->next) {
        if (h->alive && h->kind == TL_JNI_REF_WEAK_GLOBAL && h->object &&
            !is_marked(h->object, context)) h->object = NULL;
    }
    pthread_mutex_unlock(&g_refs_lock);
}
