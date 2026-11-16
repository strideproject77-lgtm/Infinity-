# INFINITY Android Runtime Architecture

Status: expanded Husk integration plan; source importer and audit pipeline updated 2026-11-16.

## Target architecture

INFINITY merges Strata's existing iOS host with Husk's advanced Android translation runtime. The target is to preserve the upstream runtime's architecture and implementation as-is wherever possible, not to create a reduced interpreter and gradually grow it.

- Strata remains responsible for iOS UI, app/library management, IPA handling, lifecycle, settings and the existing host infrastructure.
- Husk's translation-layer-next is the primary Android execution engine.
- INFINITY-owned adapters connect Husk's native runtime and host callbacks to Strata's app records, display surface, input, orientation, audio and diagnostics.
- QEMU is a separate optional backend only if it adds meaningful compatibility. It is not the default path and does not replace the native translation layer.

## Runtime components to preserve

The integration should reuse Husk's existing:
- DEX indexing and Dalvik execution.
- ARM64/ARM32 translation, JIT/AOT and executable-memory handling.
- ELF loader, relocations, dependency resolution and symbol binding.
- Bionic compatibility and system-library shims.
- JNI and Android Java/native bridge.
- Binder/service manager and Android framework services.
- NativeActivity/GameActivity and engine-specific launchers.
- EGL/GLES, ANGLE integration and Vulkan/MoltenVK path where required.
- Audio, gamepad, touch, keyboard and text input.
- Unity, Unreal, SDL, Godot, Cocos, Flutter, GameMaker, Java and other upstream engine bridges.
- Java runtime and Android system resources required by those engines.

Do not replace these with placeholders or claim support based only on APK inspection.

## Source import boundary

The pinned importer fetches Husk revision 29abb512d81bf8cc08babcbe7f7007cb557208ef. It imports:
- src/translation-layer-next/
- selected host-side Swift runtime sources
- selected Java/Android-system/ANGLE/ART build recipes
- relevant technical and licensing documentation

The import remains under Vendor/Husk/, outside synchronized Xcode source groups. It is a source snapshot, not yet an Xcode target. Build recipes are for audit and controlled integration; the importer does not execute them or download runtime payloads.

## Host integration

A dedicated runtime target/module must be created after the source and dependency audit. It must expose a stable Swift-facing API to Strata without pulling the entire Husk app or replacing Strata's Xcode project.

Host adapters should preserve upstream behavior and only bridge platform boundaries:
- APK and split-APK paths into Husk's app/engine drivers.
- App data, Android system paths, Java runtime assets and shared storage.
- CAMetalLayer/display surfaces and frame lifecycle.
- Touch, keyboard, text and controller events.
- Orientation, pause/resume, safe shutdown and per-app settings.
- Native logs, crash diagnostics, FPS and frame timing.

The selected Swift host sources are reference material until their Husk-specific dependencies have been mapped. Do not compile them into Strata's main synchronized source group directly.

## QEMU boundary

QEMU may be included as a separate optional backend after its platform, resource, performance and licensing requirements are audited. Keep guest images, kernels, firmware, qcow2 disks and QEMU libraries separate from the native translation runtime. Do not copy Husk's complete XcodeGen project or its QEMU guest-staging build phases.

## Protected Strata components

- Preserve all existing Strata UI and IPA launch behavior.
- Do not edit, refactor, relink, replace, or change settings for SideStoreSupport, SideStore-related targets, entitlements, signing/refresh/install flows, or their dependencies.
- Do not modify the existing IPA builder or its packaging scripts.
- Do not change global Xcode settings or shared build phases until all target effects are reviewed.
- Work only on main; never force-push or reset it.

## Licensing

Husk is GPL-2.0-or-later. Preserve the upstream license, file headers and notices. Audit every native/Swift source, embedded include, generated resource, framework and transitive dependency before integration and distribution. INFINITY's existing license and dependency obligations also apply. No blanket compatibility claim is made.

## Validation

- No IPA build/sign/export without explicit permission.
- No compatibility claim without real APK execution on device.
- Test evidence must distinguish import, static analysis, compile/link, launch, render, input, audio and sustained stability.
- Record device, iOS, runtime revision, backend, memory, JIT mode, FPS/frame timing, session duration and crash logs.
- Keep one consolidated test pass per batch and record exact blockers in INFINITY_HANDOFF.md.
