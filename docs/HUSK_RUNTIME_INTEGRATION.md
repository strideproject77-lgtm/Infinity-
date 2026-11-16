# Husk native runtime integration audit

Upstream: Leviidev/Husk
Audited revision: 29abb512d81bf8cc08babcbe7f7007cb557208ef (2026-11-11)
Primary engine: src/translation-layer-next/
Host-side source candidates: src/app/Husk/

## Integration decision

Use Husk's current translation-layer-next engine as the primary Android execution runtime inside Strata. The target is not a new minimal interpreter and not a basic APK demo: preserve Husk's complete native translation architecture and its engine drivers as far as iOS integration permits.

Strata remains the iOS host, app manager and UI. Husk supplies the Android execution engine. Adapt the host boundary and Strata lifecycle rather than reimplementing the engine.

## Native engine inventory

The upstream tree contains 126 native files (approximately 2.67 MiB):
- 79 C files
- 41 headers
- 4 Objective-C files
- 2 include files

The engine includes:
- DEX indexing and Dalvik execution.
- ARM64/ARM32 code paths, AOT/JIT arena and executable memory management.
- ELF dynamic loading, relocation and symbol binding.
- Bionic compatibility for I/O, pthreads, networking, system calls, NDK and C++.
- JNI and Java/native bridge.
- Binder and service manager.
- Android framework/native APIs, NativeActivity and GameActivity.
- EGL and GLES 1.x–3.x.
- Audio, OpenSL ES, gamepad and input.
- Unity, Unreal, SDL, Godot, Cocos, Flutter, GameMaker, Python and GTA SA engine bridges.
- Vulkan interface paths.

Five inspected core implementation files declare SPDX-License-Identifier: GPL-2.0-or-later. This is a sample, not a complete file-by-file provenance review.

## Host-side runtime code candidates

The expanded importer also retains these selected upstream Swift files under Vendor/Husk/host-runtime/:

- TLUnityView.swift — native-engine surface, touch routing, keyboard/text input, engine launch and performance counters.
- TLAppSettings.swift — per-app orientation, resolution and runtime settings.
- HuskGamepad.swift — GameController integration and Android-style controller events.
- HuskKeyboard.swift — keyboard input adaptation.
- HuskLog.swift — persistent native/host diagnostics.
- HuskFilePicker.swift — document-picker integration used by runtime callbacks.

These files are vendored as reference source only. They are not automatically compiled into Strata. Their dependencies on Husk-specific models, orientation, windowing, file handling and C bridge declarations must be mapped to Strata before target membership.

## Runtime data and build dependencies

Husk's native layer is not self-contained. Its build recipes identify separate runtime data and graphics dependencies:
- Java runtime assets: libcore/ICU/framework DEX and native libraries.
- Android system data: CA certificates and system fonts.
- ANGLE/GLES runtime libraries for OpenGL ES paths.
- Vulkan/MoltenVK path for compatible Unreal/Vulkan workloads.
- Engine-specific resources and runtime settings.

The importer retains selected build recipes for dependency review but does not execute them or download generated payloads. QEMU guest assets and QEMU build products are excluded from the native translation import.

## QEMU boundary

Do not import or invoke QEMU as part of the native runtime target:
- QEMU source, libraries, dylibs, headers or build outputs.
- LineageOS guest images, kernels, initramfs, qcow2 disks or firmware.
- QEMU launch/boot orchestration and guest-image staging.
- Husk's complete XcodeGen project as a replacement for Strata's project.

QEMU may be evaluated later as a separate optional backend, but it must not block the native translation runtime or be silently linked into its target.

## Strata integration boundary

- Keep the Strata application and its current app/extension targets.
- Keep the built-in SideStore completely untouched. Protected paths include SideStoreSupport/, LiveProcess/SideStoreLiveProcessHandler.m, SideStore build targets, framework embedding, signing/refresh/install flows, entitlements and related configuration.
- Keep the vendor snapshot outside synchronized Xcode source groups until a dedicated runtime target is reviewed.
- Add a stable Swift-facing runtime interface in a separate INFINITY-owned adapter.
- Preserve upstream files and notices. Do not strip SPDX/copyright headers.
- Do not claim Husk compatibility until a real APK has launched, rendered, accepted input and remained stable on device.

## Licensing gate

Husk's native runtime is GPL-2.0-or-later. Preserve the exact upstream LICENSE and all file-level notices. Review each source, embedded include, generated resource, framework and transitive dependency individually before combining or distributing a build. INFINITY/Strata has its own license obligations; no blanket compatibility conclusion is made here.

## Work completed in this batch

- Expanded the pinned importer to include the complete translation-layer-next source directory, selected native-runtime host Swift files, required runtime build recipes and technical/licensing documentation.
- Expanded the audit generator to inventory native and Swift source groups, SPDX markers, quoted includes, system header includes and Swift module imports.
- Kept all imported material under Vendor/Husk/, outside Strata's synchronized source groups.
- Did not change Xcode target membership, project build settings, SideStore or the IPA builder.

## Remaining integration work

1. Execute the manual import workflow and review the generated manifest/audit.
2. Resolve all compile-time dependencies and host Swift type dependencies.
3. Create a dedicated isolated runtime target/module and stable Strata-facing API.
4. Connect APK intake, split APKs, runtime data, native libraries, DEX execution, graphics, audio and input to Strata's app lifecycle.
5. Compile the isolated target without changing SideStore or global project settings.
6. Run real APK tests and record device-level evidence. Never count APK inspection or a successful compile as playable compatibility.

## Evidence and limitations

The upstream source tree and project manifest were inspected at the pinned revision. Husk's project.yml includes translation-layer-next but also links QEMU, ANGLE, MoltenVK and other separately built components and stages a guest image. Its project file must not be copied wholesale.

The expanded importer and audit generator are committed, but the workflow has not yet been dispatched. No Husk sources have yet been copied by that workflow, no native runtime target has been compiled, no IPA has been built, and no real APK execution is claimed.
