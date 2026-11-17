/* SPDX-License-Identifier: GPL-2.0-or-later */
/* INFINITY adapter: only the Android translation-layer API is exposed to Strata. */
#include "INFINITYHuskRuntime.h"
#include "husk-tl-unity-app.h"
#include "husk-tl-dvm-javaapp.h"

#include <math.h>
#include <stdatomic.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

enum { INFINITY_ENGINE_NONE = -1 };
static atomic_int g_infinity_engine = ATOMIC_VAR_INIT(INFINITY_ENGINE_NONE);
static atomic_bool g_java_runtime_ready = ATOMIC_VAR_INIT(false);

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

static bool runtime_directory(const char *root, const char *relative)
{
    char path[2048];
    struct stat st;
    int n = snprintf(path, sizeof(path), "%s/%s", root, relative);
    return n > 0 && (size_t)n < sizeof(path) &&
           stat(path, &st) == 0 && S_ISDIR(st.st_mode) && access(path, R_OK) == 0;
}

bool infinity_husk_prepare_java(const char *runtime_root, float density,
                                const char *system_certificates_dir,
                                const char *system_fonts_root,
                                const char *extra_fonts_dir,
                                const char *shared_storage_dir,
                                bool night_mode)
{
    if (!readable_directory(runtime_root) || !isfinite(density) || density <= 0.0f) { atomic_store(&g_java_runtime_ready, false); return false; }

    /* Fail early when the prepared Dalvik boot/runtime assets are incomplete. */
    static const char *required[] = {
        "com.android.art/javalib/core-oj.jar",
        "com.android.art/javalib/core-libart.jar",
        "com.android.art/javalib/okhttp.jar",
        "com.android.art/javalib/bouncycastle.jar",
        "com.android.art/javalib/apache-xml.jar",
        "com.android.art/lib64/libandroidio.so",
        "com.android.art/lib64/libbase.so",
        "com.android.art/lib64/libc++.so",
        "com.android.art/lib64/libexpat.so",
        "com.android.art/lib64/libjavacore.so",
        "com.android.art/lib64/libnativehelper.so",
        "com.android.art/lib64/libopenjdk.so",
        "com.android.i18n/javalib/core-icu4j.jar",
        "com.android.conscrypt/javalib/conscrypt.jar",
        "com.android.conscrypt/lib64/libjavacrypto.so",
        "com.android.conscrypt/lib64/libcrypto.so",
        "com.android.conscrypt/lib64/libssl.so",
        "husk-framework.dex",
        "husk-framework-core.dex",
        "org.apache.http.legacy.jar",
        "framework-res.apk"
    };
    for (size_t i = 0; i < sizeof(required) / sizeof(required[0]); i++)
        if (!runtime_file(runtime_root, required[i])) { atomic_store(&g_java_runtime_ready, false); return false; }

    /* build_android_system.sh emits one root with fonts/, etc/ and cacerts/.
       The fonts root is the Android-system root, not the fonts/ subdirectory. */
    if (!readable_directory(system_certificates_dir) ||
        !readable_directory(system_fonts_root) ||
        !runtime_directory(system_fonts_root, "fonts") ||
        !runtime_file(system_fonts_root, "etc/fonts.xml") ||
        !runtime_file(system_fonts_root, "etc/font_fallback.xml"))
        { atomic_store(&g_java_runtime_ready, false); return false; }

    husk_java_set_runtime(runtime_root, density);
    husk_native_set_system_files(system_certificates_dir, system_fonts_root);
    if (extra_fonts_dir && extra_fonts_dir[0])
        husk_native_set_extra_fonts(extra_fonts_dir);
    husk_native_set_shared_storage(shared_storage_dir && shared_storage_dir[0] ? shared_storage_dir : NULL);
    husk_java_set_night_mode(night_mode ? 1 : 0);
    atomic_store(&g_java_runtime_ready, true);
    return true;
}

bool infinity_husk_launch_engine(infinity_husk_engine engine,
                                 const char *apk_path, const char *data_dir,
                                 void *metal_layer, int width, int height,
                                 const char *angle_dylib, const char *ca_bundle,
                                 const char *moltenvk_dylib)
{
    if (!apk_path || !apk_path[0] || !data_dir || !data_dir[0] || !metal_layer ||
        width <= 0 || height <= 0 || !angle_dylib || !angle_dylib[0] ||
        atomic_load(&g_infinity_engine) != INFINITY_ENGINE_NONE ||
        !readable_file(apk_path) || !readable_directory(data_dir) ||
        !readable_file(angle_dylib) ||
        (ca_bundle && ca_bundle[0] && !readable_file(ca_bundle)))
        return false;

        if (engine == INFINITY_HUSK_ENGINE_JAVA && !atomic_load(&g_java_runtime_ready)) return false;

    if (engine == INFINITY_HUSK_ENGINE_UNREAL) {
        if (!readable_file(moltenvk_dylib)) return false;
        husk_ue4_set_vulkan(moltenvk_dylib);
    }

    bool accepted = false;
    switch (engine) {
        case INFINITY_HUSK_ENGINE_UNITY:
            accepted = husk_unity_launch(apk_path, data_dir, metal_layer, width, height, angle_dylib, ca_bundle); break;
        case INFINITY_HUSK_ENGINE_JAVA:
            accepted = husk_java_launch(apk_path, data_dir, metal_layer, width, height, angle_dylib, ca_bundle); break;
        case INFINITY_HUSK_ENGINE_COCOS:
            accepted = husk_cocos_launch(apk_path, data_dir, metal_layer, width, height, angle_dylib, ca_bundle); break;
        case INFINITY_HUSK_ENGINE_GAME_ACTIVITY:
            accepted = husk_gameactivity_launch(apk_path, data_dir, metal_layer, width, height, angle_dylib, ca_bundle); break;
        case INFINITY_HUSK_ENGINE_SDL:
            accepted = husk_sdl_launch(apk_path, data_dir, metal_layer, width, height, angle_dylib, ca_bundle); break;
        case INFINITY_HUSK_ENGINE_UNREAL:
            accepted = husk_ue4_launch(apk_path, data_dir, metal_layer, width, height, angle_dylib, ca_bundle); break;
        case INFINITY_HUSK_ENGINE_GODOT:
            accepted = husk_godot_launch(apk_path, data_dir, metal_layer, width, height, angle_dylib, ca_bundle); break;
        case INFINITY_HUSK_ENGINE_GTA:
            accepted = husk_gta_launch(apk_path, data_dir, metal_layer, width, height, angle_dylib, ca_bundle); break;
        case INFINITY_HUSK_ENGINE_FLUTTER:
            accepted = husk_flutter_launch(apk_path, data_dir, metal_layer, width, height, angle_dylib, ca_bundle); break;
        case INFINITY_HUSK_ENGINE_GAMEMAKER:
            accepted = husk_gamemaker_launch(apk_path, data_dir, metal_layer, width, height, angle_dylib, ca_bundle); break;
        default:
            return false;
    }

    if (accepted)
        atomic_store(&g_infinity_engine, (int)engine);
    return accepted;
}

bool infinity_husk_launch_java(const char *apk_path, const char *data_dir,
                               void *metal_layer, int width, int height,
                               const char *angle_dylib, const char *ca_bundle)
{
    return infinity_husk_launch_engine(INFINITY_HUSK_ENGINE_JAVA, apk_path, data_dir,
                                       metal_layer, width, height, angle_dylib, ca_bundle, NULL);
}

bool infinity_husk_launch_unity(const char *apk_path, const char *data_dir,
                                void *metal_layer, int width, int height,
                                const char *angle_dylib, const char *ca_bundle)
{
    return infinity_husk_launch_engine(INFINITY_HUSK_ENGINE_UNITY, apk_path, data_dir,
                                       metal_layer, width, height, angle_dylib, ca_bundle, NULL);
}

void infinity_husk_java_touch(int phase, int pointer_id, float x, float y)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_HUSK_ENGINE_JAVA)
        tl_javaapp_touch(phase, pointer_id, x, y);
}

void infinity_husk_java_key(int android_keycode, bool down)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_HUSK_ENGINE_JAVA)
        tl_javaapp_key(android_keycode, down);
}

void infinity_husk_java_back(void)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_HUSK_ENGINE_JAVA)
        tl_javaapp_back();
}

void infinity_husk_java_set_paused(bool paused)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_HUSK_ENGINE_JAVA)
        husk_unity_set_paused(paused);
}

void infinity_husk_java_set_insets(int left, int top, int right, int bottom, int keyboard_bottom)
{
    /* Initial values are accepted before launch; subsequent calls update rotation/IME geometry. */
    husk_java_set_insets(left, top, right, bottom, keyboard_bottom);
}

void infinity_husk_java_insert_text(const char *utf8)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_HUSK_ENGINE_JAVA && utf8)
        tl_javaapp_text(utf8);
}

void infinity_husk_java_delete_backward(void)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_HUSK_ENGINE_JAVA)
        tl_javaapp_text_delete();
}

void infinity_husk_java_text_action(void)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_HUSK_ENGINE_JAVA)
        tl_javaapp_text_action();
}

void infinity_husk_java_keyboard_closed(void)
{
    if (atomic_load(&g_infinity_engine) == INFINITY_HUSK_ENGINE_JAVA)
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
    if (atomic_load(&g_infinity_engine) == INFINITY_HUSK_ENGINE_JAVA)
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
    return atomic_load(&g_infinity_engine) == INFINITY_ENGINE_NONE ? 0 : husk_unity_frames();
}

void infinity_husk_touch(int phase, int pointer_id, float x, float y)
{
    if (atomic_load(&g_infinity_engine) != INFINITY_ENGINE_NONE)
        husk_unity_touch(phase, pointer_id, x, y);
}

void infinity_husk_set_paused(bool paused)
{
    if (atomic_load(&g_infinity_engine) != INFINITY_ENGINE_NONE)
        husk_unity_set_paused(paused);
}

void infinity_husk_unity_touch(int phase, int pointer_id, float x, float y)
{
    infinity_husk_touch(phase, pointer_id, x, y);
}

void infinity_husk_unity_set_paused(bool paused)
{
    infinity_husk_set_paused(paused);
}

void infinity_husk_performance_snapshot(double *fps, double *mean_ms, double *max_ms)
{
    if (!fps || !mean_ms || !max_ms) return;
    *fps = 0.0;
    *mean_ms = 0.0;
    *max_ms = 0.0;
    if (atomic_load(&g_infinity_engine) != INFINITY_ENGINE_NONE) {
        husk_unity_perf native = { 0 };
        husk_unity_perf_snapshot(&native);
        *fps = native.fps;
        *mean_ms = native.mean_ms;
        *max_ms = native.max_ms;
    }
}

void infinity_husk_unity_performance(infinity_husk_performance *out)
{
    if (!out) return;
    infinity_husk_performance_snapshot(&out->fps, &out->mean_ms, &out->max_ms);
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
