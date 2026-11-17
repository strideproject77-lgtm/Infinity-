/* SPDX-License-Identifier: GPL-2.0-or-later */
/*
 * INFINITY-owned, narrow host API for the pinned Husk translation runtime.
 * Keep upstream app/QEMU/JIT/pairing interfaces out of Strata's bridging header.
 */
#ifndef INFINITY_HUSK_RUNTIME_H
#define INFINITY_HUSK_RUNTIME_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum infinity_husk_state {
    INFINITY_HUSK_IDLE = 0,
    INFINITY_HUSK_STARTING = 1,
    INFINITY_HUSK_RUNNING = 2,
    INFINITY_HUSK_FAILED = 3,
    INFINITY_HUSK_ENDED = 4
} infinity_husk_state;

typedef struct infinity_husk_performance {
    double fps;
    double mean_ms;
    double max_ms;
} infinity_husk_performance;

/* Configure the Java/Dalvik runtime before starting a Java APK. Required root is the
   prepared Java runtime generated from the pinned Android system image. */
bool infinity_husk_prepare_native(const char *system_certificates_dir,
                                  const char *system_fonts_root,
                                  const char *extra_fonts_dir,
                                  const char *shared_storage_dir);

bool infinity_husk_prepare_java(const char *runtime_root, float density,
                                const char *system_certificates_dir,
                                const char *system_fonts_root,
                                const char *extra_fonts_dir,
                                const char *shared_storage_dir,
                                bool night_mode);

typedef enum infinity_husk_engine {
    INFINITY_HUSK_ENGINE_UNITY = 0,
    INFINITY_HUSK_ENGINE_JAVA = 1,
    INFINITY_HUSK_ENGINE_COCOS = 2,
    INFINITY_HUSK_ENGINE_GAME_ACTIVITY = 3,
    INFINITY_HUSK_ENGINE_SDL = 4,
    INFINITY_HUSK_ENGINE_UNREAL = 5,
    INFINITY_HUSK_ENGINE_GODOT = 6,
    INFINITY_HUSK_ENGINE_GTA = 7,
    INFINITY_HUSK_ENGINE_FLUTTER = 8,
    INFINITY_HUSK_ENGINE_GAMEMAKER = 9
} infinity_husk_engine;

/* Explicit backend dispatch. ANGLE is required by Husk's launch contract. */
bool infinity_husk_launch_engine(int engine,
                                 const char *apk_path, const char *data_dir,
                                 void *metal_layer, int width, int height,
                                 const char *angle_dylib, const char *ca_bundle,
                                 const char *moltenvk_dylib);

/* Start is asynchronous. APK/data/ANGLE paths must be readable; ANGLE is required by
   Husk's EGL/GLES launch path. The surface is a host CAMetalLayer. */
bool infinity_husk_launch_java(const char *apk_path, const char *data_dir,
                               void *metal_layer, int width, int height,
                               const char *angle_dylib, const char *ca_bundle);
bool infinity_husk_launch_unity(const char *apk_path, const char *data_dir,
                                void *metal_layer, int width, int height,
                                const char *angle_dylib, const char *ca_bundle);

/* Java-app host input and lifecycle. Coordinates are surface pixels, origin top-left. */
void infinity_husk_java_touch(int phase, int pointer_id, float x, float y);
void infinity_husk_java_key(int android_keycode, bool down);
void infinity_husk_java_back(void);
void infinity_husk_java_set_paused(bool paused);
void infinity_husk_java_set_insets(int left, int top, int right, int bottom, int keyboard_bottom);
void infinity_husk_java_insert_text(const char *utf8);
void infinity_husk_java_delete_backward(void);
void infinity_husk_java_text_action(void);
void infinity_husk_java_keyboard_closed(void);
void infinity_husk_java_set_host(void (*keyboard)(int show, int input_type, int ime_options),
                                 void (*set_clipboard)(const char *utf8),
                                 char *(*get_clipboard)(void),
                                 void (*share)(const char *utf8),
                                 void (*orientation)(int android_orientation));
void infinity_husk_java_set_document_picker(void (*pick)(const char *mime_types, int multiple));
void infinity_husk_java_documents_picked(const char *const *paths, int count);
void infinity_husk_gamepad_connect(int slot, const char *name);
void infinity_husk_gamepad_disconnect(int slot);
void infinity_husk_gamepad_update(int slot, unsigned buttons, float lx, float ly,
                                  float rx, float ry, float left_trigger, float right_trigger);

/* Runtime control and diagnostics. */
void infinity_husk_stop(void);
infinity_husk_state infinity_husk_get_state(void);
const char *infinity_husk_loaded_apk(void);
unsigned long infinity_husk_frames(void);
void infinity_husk_touch(int phase, int pointer_id, float x, float y);
void infinity_husk_set_paused(bool paused);
/* Backward-compatible aliases; both use Husk's engine-aware dispatcher. */
void infinity_husk_unity_touch(int phase, int pointer_id, float x, float y);
void infinity_husk_unity_set_paused(bool paused);
void infinity_husk_unity_performance(infinity_husk_performance *out);
void infinity_husk_performance_snapshot(double *fps, double *mean_ms, double *max_ms);
int infinity_husk_apk_orientation(const char *apk_path);
bool infinity_husk_apk_is_game(const char *apk_path);
bool infinity_husk_apk_requires_splits(const char *apk_path);

#ifdef __cplusplus
}
#endif
#endif
