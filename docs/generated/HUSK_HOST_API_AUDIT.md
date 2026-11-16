# Husk Swift host-to-native API map

> Textual first-pass scan only. It does not replace Clang/Swift compilation or linker symbol inspection.

- Husk function calls found in selected Swift host files: **73**
- C struct initializers identified separately: **1**
- Calls with a matching declaration in the two native header trees: **73**
- Calls with a matching native source definition: **73**
- Calls without a matching declaration: **0**
- Calls without a matching definition: **0**

## API map

- husk_apk_is_game — declared / defined; host: host-runtime/TranslationLayer.swift
- husk_apk_orientation — declared / defined; host: host-runtime/TLUnityView.swift
- husk_cocos_delete_backward — declared / defined; host: host-runtime/TLUnityView.swift
- husk_cocos_insert_text — declared / defined; host: host-runtime/TLUnityView.swift
- husk_cocos_launch — declared / defined; host: host-runtime/TLUnityView.swift
- husk_cocos_set_geode — declared / defined; host: host-runtime/TLUnityView.swift
- husk_flutter_back — declared / defined; host: host-runtime/AppWindows.swift, host-runtime/TLUnityView.swift
- husk_flutter_delete_backward — declared / defined; host: host-runtime/TLUnityView.swift
- husk_flutter_insert_text — declared / defined; host: host-runtime/TLUnityView.swift
- husk_flutter_launch — declared / defined; host: host-runtime/TLUnityView.swift
- husk_flutter_resize — declared / defined; host: host-runtime/TLUnityView.swift
- husk_flutter_set_insets — declared / defined; host: host-runtime/TLUnityView.swift
- husk_flutter_set_keyboard_inset — declared / defined; host: host-runtime/TLUnityView.swift
- husk_flutter_set_pixel_ratio — declared / defined; host: host-runtime/TLUnityView.swift
- husk_flutter_text_action — declared / defined; host: host-runtime/TLUnityView.swift
- husk_flutter_text_multiline — declared / defined; host: host-runtime/TLUnityView.swift
- husk_ga_delete_backward — declared / defined; host: host-runtime/TLUnityView.swift
- husk_ga_editor_action — declared / defined; host: host-runtime/TLUnityView.swift
- husk_ga_insert_text — declared / defined; host: host-runtime/TLUnityView.swift
- husk_ga_text — declared / defined; host: host-runtime/TLUnityView.swift
- husk_gameactivity_launch — declared / defined; host: host-runtime/TLUnityView.swift
- husk_gamemaker_launch — declared / defined; host: host-runtime/TLUnityView.swift
- husk_gamemaker_orientation — declared / defined; host: host-runtime/TLUnityView.swift
- husk_gamepad_connect — declared / defined; host: host-runtime/HuskGamepad.swift
- husk_gamepad_disconnect — declared / defined; host: host-runtime/HuskGamepad.swift
- husk_gamepad_update — declared / defined; host: host-runtime/HuskGamepad.swift
- husk_godot_launch — declared / defined; host: host-runtime/TLUnityView.swift
- husk_gta_launch — declared / defined; host: host-runtime/TLUnityView.swift
- husk_java_back — declared / defined; host: host-runtime/TLUnityView.swift
- husk_java_delete_backward — declared / defined; host: host-runtime/TLUnityView.swift
- husk_java_documents_picked — declared / defined; host: host-runtime/TLUnityView.swift
- husk_java_insert_text — declared / defined; host: host-runtime/TLUnityView.swift
- husk_java_keyboard_closed — declared / defined; host: host-runtime/TLUnityView.swift
- husk_java_launch — declared / defined; host: host-runtime/TLUnityView.swift
- husk_java_set_host — declared / defined; host: host-runtime/TLUnityView.swift
- husk_java_set_insets — declared / defined; host: host-runtime/TLUnityView.swift
- husk_java_set_night_mode — declared / defined; host: host-runtime/TLUnityView.swift
- husk_java_set_runtime — declared / defined; host: host-runtime/TLUnityView.swift
- husk_java_text_action — declared / defined; host: host-runtime/TLUnityView.swift
- husk_java_web_attach — declared / defined; host: host-runtime/TLUnityView.swift
- husk_java_web_hit — declared / defined; host: host-runtime/TLUnityView.swift
- husk_native_add_package — declared / defined; host: host-runtime/TLUnityView.swift
- husk_native_loaded_apk — declared / defined; host: host-runtime/TLAppSettings.swift, host-runtime/TLUnityView.swift
- husk_native_set_extra_fonts — declared / defined; host: host-runtime/TLUnityView.swift
- husk_native_set_shared_storage — declared / defined; host: host-runtime/TLUnityView.swift
- husk_native_set_system_files — declared / defined; host: host-runtime/TLUnityView.swift
- husk_native_wants_controller — declared / defined; host: host-runtime/TLUnityView.swift
- husk_sdl_apk_is_portrait — declared / defined; host: host-runtime/TLUnityView.swift
- husk_sdl_commit_text — declared / defined; host: host-runtime/TLUnityView.swift
- husk_sdl_key — declared / defined; host: host-runtime/TLUnityView.swift
- husk_sdl_launch — declared / defined; host: host-runtime/TLUnityView.swift
- husk_sdl_set_safe_insets — declared / defined; host: host-runtime/TLUnityView.swift
- husk_tl_attempt_done — declared / defined; host: host-runtime/TranslationLayer.swift
- husk_tl_attempt_frames — declared / defined; host: host-runtime/TranslationLayer.swift
- husk_tl_attempt_log — declared / defined; host: host-runtime/TLUnityView.swift, host-runtime/TranslationLayer.swift
- husk_tl_attempt_start — declared / defined; host: host-runtime/TranslationLayer.swift
- husk_tl_attempt_stop — declared / defined; host: host-runtime/TranslationLayer.swift
- husk_tl_free — declared / defined; host: host-runtime/TranslationLayer.swift
- husk_tl_read_entry — declared / defined; host: host-runtime/TranslationLayer.swift
- husk_tl_run_checks — declared / defined; host: host-runtime/TranslationLayer.swift
- husk_tl_scan — declared / defined; host: host-runtime/TranslationLayer.swift
- husk_ue4_launch — declared / defined; host: host-runtime/TLUnityView.swift
- husk_ue4_set_vulkan — declared / defined; host: host-runtime/TLUnityView.swift
- husk_unity_delete_backward — declared / defined; host: host-runtime/TLUnityView.swift
- husk_unity_finish_text — declared / defined; host: host-runtime/TLUnityView.swift
- husk_unity_frames — declared / defined; host: host-runtime/TLUnityView.swift
- husk_unity_insert_text — declared / defined; host: host-runtime/TLUnityView.swift
- husk_unity_launch — declared / defined; host: host-runtime/TLUnityView.swift
- husk_unity_perf_snapshot — declared / defined; host: host-runtime/TLUnityView.swift
- husk_unity_set_paused — declared / defined; host: host-runtime/TLUnityView.swift
- husk_unity_state — declared / defined; host: host-runtime/TLUnityView.swift
- husk_unity_text — declared / defined; host: host-runtime/TLUnityView.swift
- husk_unity_touch — declared / defined; host: host-runtime/TLUnityView.swift

## C struct initializers (not function symbols)

- husk_unity_perf — host-runtime/TLUnityView.swift

## Missing declarations

None detected by this textual scan.

## Missing native definitions

None detected by this textual scan.

## Integration notes

- The upstream HuskBridge.h is audit-only and intentionally excluded from the native declaration scan because it also declares QEMU/JIT APIs and imports Husk-only pairing headers.
- Unresolved names may be supplied by excluded host/QEMU code or generated headers; resolve each against the intended native translation-layer interface before compiling.
- A text match is not proof of ABI compatibility, correct calling convention, or a successful link.
