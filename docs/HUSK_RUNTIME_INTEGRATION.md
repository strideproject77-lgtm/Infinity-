# Husk QEMU-Free Runtime Integration Audit

Upstream: Leviidev/Husk
Audited revision: 29abb512d81bf8cc08babcbe7f7007cb557208ef (2026-11-11)
Primary source directory: src/translation-layer-next/

## Decision

Use the current translation-layer-next source as the primary Android runtime candidate for INFINITY. Do not treat the older src/translation-layer prototype as the complete engine. Do not import Husk's complete app project or its QEMU/LineageOS guest stack.

## Inventory

The upstream tree contains 126 files (approximately 2.67 MiB):
- 79 C files
- 41 headers
- 4 Objective-C files
- 2 include files

Core areas identified from filenames and inspected includes:
- DEX indexing and Dalvik execution
- ARM64/ARM32 code paths and AOT/JIT arena
- ELF dynamic loader and executable-memory handling
- Bionic compatibility (I/O, pthread, networking, system, NDK and C++ shims)
- JNI and Java/native bridge
- Binder and service manager
- Android framework/native APIs and NativeActivity/GameActivity
- EGL and GLES 1.x–3.x
- Audio, OpenSL ES and gamepad/input
- Unity, Unreal, SDL, Godot, Cocos, Flutter, GameMaker, Python and GTA SA engine bridges
- Vulkan interface paths

Five inspected core implementation files (husk-tl-dvm.c, husk-tl-ld.c, husk-tl-bionic.c, husk-tl-jni.c, husk-tl-egl.c) declare SPDX-License-Identifier: GPL-2.0-or-later. This is a sample, not yet a complete 126-file provenance audit. Every file and embedded include must be checked before import.

## QEMU exclusion boundary

Do not import or invoke:
- QEMU source, libraries, dylibs, headers, or build outputs
- LineageOS guest images, kernels, initramfs, qcow2 disks, firmware or guest staging
- QEMU launch/boot orchestration
- guest-only scripts and assets
- Husk's complete XcodeGen project as a replacement for Strata's project

Husk's src/app/project.yml currently includes translation-layer-next in the Husk app target but also links libqemu-aarch64-softmmu.dylib and runs a pre-build guest-image staging script. That project file must not be copied into INFINITY.

## INFINITY integration boundary

- Keep the Strata application and its current app/extension targets.
- Keep the built-in SideStore completely untouched. Protected paths include SideStoreSupport/, LiveProcess/SideStoreLiveProcessHandler.m, SideStore build targets, framework embedding, signing/refresh/install flows, entitlements and related configuration.
- Put Android runtime sources in a dedicated isolated directory and wire them only into a dedicated runtime target or an explicitly reviewed runtime build phase.
- Do not put runtime files inside the SideStore target or modify SideStore project settings.
- Keep source attribution, upstream revision pin, GPL-2.0-or-later LICENSE text and third-party notices with the imported files.
- Do not claim the imported engine is fully working until the INFINITY build and real-device APK execution tests pass.

## Integration work still required

1. Complete per-file SPDX/provenance scan for all 126 files and all embedded include data.
2. Resolve exact compile-time dependencies and framework/linker requirements without importing QEMU.
3. Design an isolated Xcode target/module; preserve all existing Strata and SideStore target memberships.
4. Import the reviewed source snapshot at the pinned revision.
5. Connect APK intake, DEX/native library discovery and runtime launch APIs to INFINITY's app model.
6. Run one consolidated test pass after the batch: 2048 first, then Hill Climb Racing, then other APKs.
7. Record real-device results, unsupported paths, logs and remaining blockers in INFINITY_HANDOFF.md.

## Evidence and limitations

- The upstream source tree at the pinned revision lists 126 files in src/translation-layer-next/.
- The upstream XcodeGen manifest includes that directory in Husk's app target, but the same target has QEMU linkage and a guest-image staging pre-build script.
- Core runtime source headers inspected in this audit identify the files as GPL-2.0-or-later.
- No source files have yet been copied into INFINITY by this audit. No Xcode build, device test, or IPA build was run.