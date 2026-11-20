/* SPDX-License-Identifier: GPL-2.0-or-later */
/*
 * Typed JNI reference-handle registry.
 *
 * Handles are opaque guest-facing tokens. This module deliberately keeps the
 * object pointer private to the registry and records reference kind and local
 * frame ownership separately from the Java object itself.
 */
#ifndef HUSK_TL_JNI_REFS_H
#define HUSK_TL_JNI_REFS_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "husk-tl-jni.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct tl_jni_ref_handle tl_jni_ref_handle;

typedef enum tl_jni_ref_kind {
    TL_JNI_REF_INVALID = 0,
    TL_JNI_REF_LOCAL = 1,
    TL_JNI_REF_GLOBAL = 2,
    TL_JNI_REF_WEAK_GLOBAL = 3
} tl_jni_ref_kind;

/* Local handles belong to the calling thread and current frame. */
bool tl_jni_refs_push_local_frame(size_t capacity);
tl_jni_ref_handle *tl_jni_refs_pop_local_frame(tl_jni_ref_handle *preserve);
tl_jni_ref_handle *tl_jni_refs_new_local(jobj *object);
void tl_jni_refs_detach_thread(void);

/* Global handles are strong roots; weak globals are cleared by the collector. */
tl_jni_ref_handle *tl_jni_refs_new_global(jobj *object);
tl_jni_ref_handle *tl_jni_refs_new_weak_global(jobj *object);
void tl_jni_refs_delete(tl_jni_ref_handle *handle, tl_jni_ref_kind expected_kind);

/* Resolve only after validating registry membership, liveness and local ownership. */
jobj *tl_jni_refs_resolve(tl_jni_ref_handle *handle);
tl_jni_ref_kind tl_jni_refs_get_kind(tl_jni_ref_handle *handle);
bool tl_jni_refs_is_same(tl_jni_ref_handle *left, tl_jni_ref_handle *right);

/*
 * Collector integration. Call while the runtime is at a stop-the-world
 * safepoint. The visitor must not call back into this registry. Weak handles
 * are not roots; process_weak clears them after the mark phase.
 */
typedef void (*tl_jni_refs_root_visitor)(jobj *object, void *context);
typedef bool (*tl_jni_refs_is_marked)(jobj *object, void *context);
void tl_jni_refs_visit_strong_roots(tl_jni_refs_root_visitor visitor, void *context);
void tl_jni_refs_process_weak(tl_jni_refs_is_marked is_marked, void *context);

#ifdef __cplusplus
}
#endif

#endif
