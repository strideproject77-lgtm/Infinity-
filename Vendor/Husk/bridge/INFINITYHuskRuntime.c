/* SPDX-License-Identifier: GPL-2.0-or-later */
/* INFINITY adapter: only the Android translation-layer API is exposed to Strata. */
#include "INFINITYHuskRuntime.h"
#include "husk-tl-unity-app.h"
#include "husk-tl-dvm-javaapp.h"

#include <math.h>
#include <stddef.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

enum { INFINITY_ENGINE_NONE = 0, INFINITY_ENGINE_JAVA = 1, INFINITY_ENGINE_UNITY = 2 };
static int g_infinity_engine = INFINITY_ENGINE_NONE;

static bool readable_directory(const char *path)
{
    struct stat st;
    return path && path[0] && stat(path, &st) == 0 && S_ISDIR(st.st_mode) && access(path, R_OK) == 0;
}

bool infinity_husk_prepare_java(const char *runtime_root, float density,
                                const char *system_certificates_dir,
                                const char *system_fonts_root,
                                const char *extra_fonts_dir,
                                const char *shared_storage_dir,
                                bool night_mode)
{
    if (!readable_directory(runtime_root) || !isfinite(density) || density <= 0.0f) return false;

    husk_java_set_runtime(runtime_root, density);
    if (system_certificates_dir && system_certificates_dir[0])
        husk_native_set_system_files(system_certificates_dir,
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
        width <= 0 || height <= 0 || g_infinity_engine != INFINITY_ENGINE_NONE)
        return false;

    if (!husk_java_launch(apk_path, data_dir, metal_layer, width, height,
                          angle_dylib && angle_dylib[0] ? angle_dylib : NULL,
                          ca_bundle && ca_bundle[0] ? ca_bundle : NULL))
        return false;

    g_infinity_engine = INFINITY_ENGINE_JAVA;
    return true;
}

bool infinity_husk_launch_unity(const char *apk_path, const char *data_dir,
                                void *metal_layer, int width, int height,
                                const char *angle_dylib, const char *ca_bundle)
{
    if (!apk_path || !apk_path[0] || !data_dir || !data_dir[0] ||
        width <= 0 || height <= 0 || g_infinity_engine != INFINITY_ENGINE_NONE)
        return false;

    if (!husk_unity_launch(apk_path, data_dir, metal_layer, width, height,
                           angle_dylib && angle_dylib[0] ? angle_dylib : NULL,
                           ca_bundle && ca_bundle[0] ? ca_bundle : NULL))
        return false;

    g_infinity_engine = INFINITY_ENGINE_UNITY;
    return true;
}

void infinity_husk_java_touch(int phase, int pointer_id, float x, float y)
{
    if (g_infinity_engine == INFINITY_ENGINE_JAVA)
        tl_javaapp_touch(phase, pointer_id, x, y);
}

void infinity_husk_java_key(int android_keycode, bool down)
{
    if (g_infinity_engine == INFINITY_ENGINE_JAVA)
        tl_javaapp_key(android_keycode, down);
}

void infinity_husk_java_back(void)
{
    if (g_infinity_engine == INFINITY_ENGINE_JAVA)
        tl_javaapp_back();
}

void infinity_husk_java_set_paused(bool paused)
{
    if (g_infinity_engine == INFINITY_ENGINE_JAVA)
        tl_javaapp_set_paused(paused);
}

void infinity_husk_java_set_insets(int left, int top, int right, int bottom, int keyboard_bottom)
{
    if (g_infinity_engine == INFINITY_ENGINE_JAVA)
        tl_javaapp_set_insets(left, top, right, bottom, keyboard_bottom);
}

void infinity_husk_java_insert_text(const char *utf8)
{
    if (g_infinity_engine == INFINITY_ENGINE_JAVA && utf8)
        tl_javaapp_text(utf8);
}

void infinity_husk_java_delete_backward(void)
{
    if (g_infinity_engine == INFINITY_ENGINE_JAVA)
        tl_javaapp_text_delete();
}

void infinity_husk_java_text_action(void)
{
    if (g_infinity_engine == INFINITY_ENGINE_JAVA)
        tl_javaapp_text_action();
}

void infinity_husk_java_keyboard_closed(void)
{
    if (g_infinity_engine == INFINITY_ENGINE_JAVA)
        tl_javaapp_keyboard_closed();
}

void infinity_husk_stop(void)
{
    if (g_infinity_engine == INFINITY_ENGINE_NONE) return;
    husk_native_unload();
    g_infinity_engine = INFINITY_ENGINE_NONE;
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
    if (g_infinity_engine == INFINITY_ENGINE_JAVA) return tl_javaapp_frames();
    if (g_infinity_engine == INFINITY_ENGINE_UNITY) return husk_unity_frames();
    return 0;
}

void infinity_husk_unity_touch(int phase, int pointer_id, float x, float y)
{
    if (g_infinity_engine == INFINITY_ENGINE_UNITY)
        husk_unity_touch(phase, pointer_id, x, y);
}

void infinity_husk_unity_set_paused(bool paused)
{
    if (g_infinity_engine == INFINITY_ENGINE_UNITY)
        husk_unity_set_paused(paused);
}

void infinity_husk_unity_performance(infinity_husk_performance *out)
{
    if (!out) return;
    out->fps = 0.0;
    out->mean_ms = 0.0;
    out->max_ms = 0.0;
    if (g_infinity_engine == INFINITY_ENGINE_UNITY) {
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
