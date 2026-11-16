# INFINITY Android Runtime Architecture

Status: design and source-audit baseline; no runtime backend is integrated yet.
Updated: 2026-11-16

## Approved direction

The project owner approved including QEMU if it is needed. INFINITY will evaluate and keep two separate Android execution backends:

1. **Native translation backend (primary target):** execute APK DEX and ARM64 native components through a host-side Android compatibility layer. This avoids booting a complete Android operating system for apps that the translation layer can support.
2. **QEMU guest backend (optional compatibility path):** run a complete ARM64 Android guest for apps that cannot yet run through the native translation backend, or for diagnostics/comparison. This is a separate execution mode, not a transparent speed improvement.

The APK launcher should choose a backend only from explicit capability checks and user-visible status. Never report an APK as compatible merely because it imports, parses, or boots an Android guest.

## What QEMU changes

Husk's current QemuRunner.swift describes QEMU as an in-process shared library driven by a dedicated pthread because iOS apps cannot spawn arbitrary child processes. Its guest manager describes a LineageOS ARM64 guest, QCOW2 system disk, userdata disk, and optional pre-booted snapshot.

Consequences:
- QEMU emulates a full guest on devices without a suitable hypervisor; it is not expected to make execution faster.
- Cold Android boot is documented by Husk as taking several minutes; a pre-booted snapshot reduces boot time but has a multi-gigabyte download and device-specific RAM/resolution constraints.
- Guest execution adds a Linux kernel, Android userspace, virtual devices, display transport, guest memory, storage, and lifecycle management.
- QEMU may provide broader Android framework compatibility, but it consumes substantially more storage and memory and can perform poorly on older iPhones.
- QEMU must be optional, with storage/network disclosure, cancellation, cleanup, safe shutdown, and a way to return to the native launcher.

## Integration boundaries

- Keep all Android runtime code in a new isolated INFINITY runtime module.
- Do not edit, refactor, relink, replace, or change settings for SideStoreSupport, SideStore-related targets, entitlements, signing/refresh/install flows, or their dependencies.
- Do not alter the built-in SideStore to accommodate either Android backend.
- Keep APK app records and the unified Home Screen independent from backend implementation details.
- Keep native translation and QEMU guest data in separate directories and diagnostics namespaces.
- Do not add QEMU guest assets to the app bundle by default.
- Do not modify global Xcode project settings or shared build phases until their effect on SideStore and all existing Strata targets has been audited.

## Source and licensing gate

Audited upstream: Leviidev/Husk, main revision observed 2026-11-16.

- Husk src/translation-layer-next/ contains 126 files (79 C, 41 headers, 4 Objective-C, 2 include files), approximately 2.67 MiB.
- Sampled native-runtime C files carry SPDX-License-Identifier: GPL-2.0-or-later.
- Husk's iOS app target also includes QEMU and references a built libqemu-aarch64-softmmu.dylib, ANGLE, pairing/debug support, and guest image management. These are not interchangeable with the native translation backend.
- The inspected QEMU runner and guest image manager are GPL-2.0-or-later and document an in-process QEMU library and LineageOS guest workflow.
- INFINITY currently lists LiveContainer under AGPL-3.0 and has additional third-party dependencies. Before importing code or distributing a combined binary, perform a component-by-component license and notice review. GPL-2.0-or-later can sometimes be taken under GPL-3.0-or-later, but this does not by itself establish that every dependency, patch, asset, or binary is compatible. No legal compatibility claim is made here.
- Preserve upstream notices and licenses. Exclude files with unclear provenance until verified. Do not silently strip or rewrite license headers.

## Implementation order

1. Complete the source manifest and license/provenance review for native runtime, QEMU, ANGLE, guest images, and helper components.
2. Create an isolated Android runtime module and stable Swift-facing API; do not touch SideStore or existing IPA launch paths.
3. Integrate APK import/metadata extraction and persistent app records.
4. Bring up native DEX execution and validate a real small APK.
5. Integrate ARM64 ELF/Bionic/JNI and framework services incrementally.
6. Add QEMU as a separately selectable optional backend after its iOS build and licensing gate passes.
7. Connect backend selection to the unified launcher, then add diagnostics and real-game testing.

## Validation rules

- No IPA build/sign/export without explicit owner permission.
- No compatibility claim without actual APK execution evidence on a real device.
- One consolidated test pass per batch, in this order: 2048, Hill Climb Racing, then other real APKs.
- Record device, iOS, backend, memory, JIT mode, launch/render/input/audio result, session duration, and crash logs.
- If QEMU guest setup cannot complete on the target device, report it as a blocker rather than counting guest boot or static analysis as APK compatibility.