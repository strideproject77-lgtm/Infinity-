/* SPDX-License-Identifier: GPL-2.0-or-later */
/*
 * Typed JNI reference-handle registry.
 *
 * Handles are opaque guest-facing tokens. This module keeps the object pointer
 * private to the registry and records reference kind and local frame ownership
 * separately from the Java object itself.
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

bool tl_jni_refs_push_local_frame(size_t capacity);
tl_jni_ref_handle *tl_jni_refs_pop_local_frame(tl_jni_ref_handle *preserve);
tl_jni_ref_handle *tl_jni_refs_new_local(jobj *object);
void tl_jni_refs_detach_thread(void);

tl_jni_ref_handle *tl_jni_refs_new_global(jobj *object);
tl_jni_ref_handle *tl_jni_refs_new_weak_global(jobj *object);
void tl_jni_refs_delete(tl_jni_ref_handle *handle, tl_jni_ref_kind expected_kind);

/* Acquire returns a temporary strong object reference; caller releases via tl_jni_unref. */
jobj *tl_jni_refs_acquire(tl_jni_ref_handle *handle);
tl_jni_ref_kind tl_jni_refs_get_kind(tl_jni_ref_handle *handle);
bool tl_jni_refs_is_same(tl_jni_ref_handle *left, tl_jni_ref_handle *right);

/*
 * Weak globals retain strongly until a tracing collector is actually active.
 * Enable weak-GC semantics only at a stop-the-world safepoint, after installing
 * the collector's complete root walk and weak processing hooks.
 */
void tl_jni_refs_enable_weak_gc(void);

typedef void (*tl_jni_refs_root_visitor)(jobj *object, void *context);
typedef bool (*tl_jni_refs_is_marked)(jobj *object, void *context);

/* Collector hooks run at a stop-the-world safepoint and must not re-enter this registry. */
void tl_jni_refs_visit_strong_roots(tl_jni_refs_root_visitor visitor, void *context);
void tl_jni_refs_process_weak(tl_jni_refs_is_marked is_marked, void *context);

#ifdef __cplusplus
}
#endif

#endif
