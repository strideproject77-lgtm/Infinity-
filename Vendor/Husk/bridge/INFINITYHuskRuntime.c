/* SPDX-License-Identifier: GPL-2.0-or-later */
/* INFINITY adapter: only the Android translation-layer API is exposed to Strata. */
#include "INFINITYHuskRuntime.h"
#include "husk-tl-unity-app.h"
#include "husk-tl-dvm-javaapp.h"

#include <math.h>
#include <stdatomic.h>
#include <stddef.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

enum { INFINITY_ENGINE_NONE = 0, INFINITY_ENGINE_JAVA = 1, INFINITY_ENGINE_UNITY = 2 };
static atomic_int g_infinity_engine = ATOMIC_VAR_INIT(INFINITY_ENGINE_NONE);

static bool readable_directory(const char *path)
{
    struct stat st;
    return path && path[0] && stat(path, &st) == 0 && S_ISDIR(st.st_mode) && access(path, R_OK) == 0;
}

static bool readable_file(const char *path)
{
    struct stat st;
    return path && path[0] && stat(path, &st) == 0 && S_ISREG(st.st_mode) && access(path, R_OK) == 0;
}

static bool runtime_file(const char *root, const char *relative)
{
    char path[2048];
    int n = snprintf(path, sizeof(path), "%s/%s", root, relative);
    return n > 0 && (size_t)n < sizeof(path) && readable_file(path);
}

bool infinity_husk_prepare_java(const char *runtime_root, float density,
                                const char *system_certificates_dir,
                                const char *system_fonts_root,
                                const char *extra_fonts_dir,
                                const char *shared_storage_dir,
                                bool night_mode)
{
    if (!readable_directory(runtime_root) || !isfinite(density) || density <= 0.0f) return false;

    /* Fail early when the prepared Dalvik boot/runtime assets are incomplete. */
    static const char *required[] = {
        "com.android.art/javalib/core-oj.jar",
        "com.android.art/javalib/core-libart.jar",
        "com.android.i18n/javalib/core-icu4j.jar",
        "com.android.conscrypt/javalib/conscrypt.jar",
        "husk-framework.dex",
        "framework-res.apk"
    };
    for (size_t i = 0; i < sizeof(required) / sizeof(required[0]); i++)
        if (!runtime_file(runtime_root, required[i])) return false;

    husk_java_set_runtime(runtime_root, density);
    if ((system_certificates_dir && system_certificates_dir[0]) ||
        (system_fonts_root && system_fonts_root[0]))
        husk_native_set_system_files(system_certificates_dir && system_certificates_dir[0] ? system_certificates_dir : NULL,
                                     system_fonts_root && system_fonts_root[0] ? system_fonts_root : NULL);
    if (extra_fonts_dir && extra_fonts_dir[0])
        husk_native_set_extra_fonts(extra_fonts_dir);
    husk_native_set_shared_storage(shared_storage_dir && shared_storage_dir[0] ? shared_storage_dir : NULL);
    husk_java_set_night_mode(night_mode ? 1 : 0);
    return true;
}

bool infinity_husk_launch_java(const char *apk_path, const char *data_dir,
                               void *metal_layer, int width, int height,
                               const char *angle_dylib, const char *ca_bundle)
{
    if (!apk_path || !apk_path[0] || !data_dir || !data_dir[0] ||
        width <= 0 || height <= 0 || atomic_load(&g_infinity_engine) != INFINITY_ENGINE_NONE ||
        !readable_file(apk_path) || !readable_directory(data_dir))
        return false;

    if (!husk_java_launch(apk_path, data_dir, metal_layer, width, height,
                          angle_dylib && angle_dylib[0] ? angle_dylib : NULL,
                          ca_bundle && ca_bundle[0] ? ca_bundle : NULL))
        return false;

    atomic_store(&g_infinity_engine, INFINITY_ENGINE_JAVA);
    return true;
}

bool infinity_husk_launch_unity(const char *apk_path, const char *data_dir,
                                void *metal_layer, int width, int height,
                                const char *angle_dylib, const char *ca_bundle)
{
    if (!apk_path || !apk_path[0] || !data_dir || !data_dir[0] ||
        width <= 0 || height <= 0 || atomic_load(&g_infinity_engine) != INFINITY_ENGINE_NONE)
        return false;

    if (!husk_unity_launch(apk_path, data_dir, metal_layer, width, height,
                           angle_dylib && angle_dylib[0] ? angle_dylib : NULL,
                           ca_bundle && ca_bundle[0] ? ca_bundle : NULL))
        return false;

    atomic_store(&g_infinity_engine, INFINITY_ENGINE_UNITY);
    return true;
}

void infinity_husk_java_touch(int phase, int pointer_id, float x, float y)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_JAVA)
        tl_javaapp_touch(phase, pointer_id, x, y);
}

void infinity_husk_java_key(int android_keycode, bool down)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_JAVA)
        tl_javaapp_key(android_keycode, down);
}

void infinity_husk_java_back(void)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_JAVA)
        tl_javaapp_back();
}

void infinity_husk_java_set_paused(bool paused)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_JAVA)
        tl_javaapp_set_paused(paused);
}

void infinity_husk_java_set_insets(int left, int top, int right, int bottom, int keyboard_bottom)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_JAVA)
        tl_javaapp_set_insets(left, top, right, bottom, keyboard_bottom);
}

void infinity_husk_java_insert_text(const char *utf8)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_JAVA && utf8)
        tl_javaapp_text(utf8);
}

void infinity_husk_java_delete_backward(void)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_JAVA)
        tl_javaapp_text_delete();
}

void infinity_husk_java_text_action(void)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_JAVA)
        tl_javaapp_text_action();
}

void infinity_husk_java_keyboard_closed(void)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_JAVA)
        tl_javaapp_keyboard_closed();
}

void infinity_husk_java_set_host(void (*keyboard)(int, int, int),
                                 void (*set_clipboard)(const char *),
                                 char *(*get_clipboard)(void),
                                 void (*share)(const char *),
                                 void (*orientation)(int))
{
    husk_java_set_host(keyboard, set_clipboard, get_clipboard, share, orientation);
}

void infinity_husk_java_set_document_picker(void (*pick)(const char *, int))
{
    husk_java_set_document_picker(pick);
}

void infinity_husk_java_documents_picked(const char *const *paths, int count)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_JAVA)
        husk_java_documents_picked(paths, count);
}

void infinity_husk_gamepad_connect(int slot, const char *name)
{
    husk_gamepad_connect(slot, name);
}

void infinity_husk_gamepad_disconnect(int slot)
{
    husk_gamepad_disconnect(slot);
}

void infinity_husk_gamepad_update(int slot, unsigned buttons, float lx, float ly,
                                  float rx, float ry, float left_trigger, float right_trigger)
{
    husk_gamepad_update(slot, buttons, lx, ly, rx, ry, left_trigger, right_trigger);
}

void infinity_husk_stop(void)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_NONE) return;
    husk_native_unload();
    atomic_store(&g_infinity_engine, INFINITY_ENGINE_NONE);
}

infinity_husk_state infinity_husk_get_state(void)
{
    return (infinity_husk_state)husk_unity_state();
}

const char *infinity_husk_loaded_apk(void)
{
    return husk_native_loaded_apk();
}

unsigned long infinity_husk_frames(void)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_JAVA) return tl_javaapp_frames();
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_UNITY) return husk_unity_frames();
    return 0;
}

void infinity_husk_unity_touch(int phase, int pointer_id, float x, float y)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_UNITY)
        husk_unity_touch(phase, pointer_id, x, y);
}

void infinity_husk_unity_set_paused(bool paused)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_UNITY)
        husk_unity_set_paused(paused);
}

void infinity_husk_unity_performance(infinity_husk_performance *out)
{
    if (!out) return;
    out->fps = 0.0;
    out->mean_ms = 0.0;
    out->max_ms = 0.0;
    if (atomic_load(&g_infinity_engine) == INFINITY_ENGINE_UNITY) {
        husk_unity_perf native = { 0 };
        husk_unity_perf_snapshot(&native);
        out->fps = native.fps;
        out->mean_ms = native.mean_ms;
        out->max_ms = native.max_ms;
    }
}

int infinity_husk_apk_orientation(const char *apk_path)
{
    return apk_path && apk_path[0] ? husk_apk_orientation(apk_path) : -1;
}

bool infinity_husk_apk_is_game(const char *apk_path)
{
    return apk_path && apk_path[0] && husk_apk_is_game(apk_path) != 0;
}

bool infinity_husk_apk_requires_splits(const char *apk_path)
{
    return apk_path && apk_path[0] && husk_apk_split_required(apk_path) != 0;
}
