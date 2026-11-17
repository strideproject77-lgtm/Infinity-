# Husk native build boundary

Audited against pinned Husk revision `29abb512d81bf8cc08babcbe7f7007cb557208ef` and the vendored `Vendor/Husk/build-support/project.yml`.

## Source membership

The upstream XcodeGen app target includes both `src/translation-layer/` and `src/translation-layer-next/`. The latter excludes `husk-tl-unity-app.h`. This confirms that importing only the newer tree would not reproduce the upstream app's source membership. INFINITY's current snapshot contains 96 native source files across both trees.

This is a source-membership reference, not an instruction to add every file blindly to Strata. Before compilation, classify conditional/platform-specific files, resolve generated headers and macros, and confirm each native source's direct dependencies.

## Native SDK dependency candidates

The upstream manifest lists these libraries/frameworks for its app target:

- SDK/system libraries: zlib (`-lz`), libresolv (`-lresolv`), SQLite (`-lsqlite3`).
- Apple frameworks: AudioToolbox, CoreText, CoreGraphics, ImageIO, WebKit, VideoToolbox, CoreMedia, CoreVideo, Accelerate and Security.
- The source inventory additionally finds Apple SDK headers for CoreFoundation, CommonCrypto, Darwin/Mach, dispatch and standard POSIX interfaces.

Treat this as a dependency candidate list. It does not establish that every item is required by the selected native source slice or that all APIs are available at INFINITY's deployment target. Resolve actual undefined symbols and availability during an isolated compile/link test before adding target settings.

## Explicitly excluded from the first native target

The upstream app manifest also contains components that are not part of the first native translation target:

- QEMU dylib, guest kernel/initramfs, qcow2 seed disks, firmware, BIOS files and guest-image staging scripts.
- ANGLE is not compiled into the static C translation target, but it is a required runtime dylib for Husk's native EGL/GLES launch path: the common launch function rejects a missing ANGLE path and passes it to the engine's EGL configuration. It is also used by QEMU/virgl. Build it separately, preserve its BSD notice, and embed/code-sign it in the host app before native APK launch can work. It is not QEMU-only.
- MoltenVK: separately built Vulkan path for selected Unreal workloads; optional and engine-specific.
- `libhuskps4.dylib`: separate PS4/FEX backend.
- `libhusk_rppairing`, StikJIT helper, and the file-picker fix dylib: separate helper/pairing or host-app features; do not import them as native Android translation dependencies.
- Husk's full app target, `HuskApp.swift` entry point, QEMU pre/post-build scripts, and broad app UI.

QEMU remains a separate optional backend. No QEMU library, guest image, pairing system or PS4 backend is needed to begin validating the native C translation target.

## Generated runtime data is a separate gate

The retained recipes reveal four distinct data/build groups:

1. `build_android_system.sh` stages Android system data, including certificates and fonts, from a prepared Android system image.
2. `build_java_runtime.sh` copies Android APEX/libcore/ICU/Conscrypt artifacts, framework resources and Husk's generated Java framework DEX from a prepared system image and source tree.
3. `build_art_support.sh` uses the Android NDK to produce Android guest-side shared libraries (`libunwind.so`, `libartpalette-system.so`); these are not iOS host libraries.
4. `build_angle_ios.sh` builds the iOS arm64 ANGLE dylib from a pinned WebKit checkout. The native launch API requires a readable ANGLE dylib for EGL/GLES, so this is a runtime-launch prerequisite even though it remains a separate build artifact and is not a static-library link dependency. Preserve the ANGLE BSD license and WebKit revision alongside the artifact.

Do not run these recipes as a group. They have external toolchain, source-image, generated-artifact and licensing requirements. Review each output's provenance, architecture and redistribution terms before bundling it.

## Host bridge boundary

The 73 Swift-to-C function names now have textual matches to native declarations and definitions. That is useful symbol inventory only: it does not prove ABI compatibility, calling conventions, ownership/lifetime safety or link success. The selected upstream Swift host files also depend on Husk-specific window/orientation/app models. Keep them as reference material until INFINITY-owned adapters are written; do not compile them wholesale.

## Safe next build milestone

Create an isolated native C target/module that:

- Uses the pinned dual-tree source set only after per-file source/flag review.
- Exposes a narrow INFINITY-owned C header and Swift wrapper, without importing `HuskBridge.h`.
- Links only dependencies proven by the target's compile/link output.
- Does not add QEMU, MoltenVK, StikJIT, SideStore, guest-image scripts or unrelated app targets. ANGLE is built and embedded as a separate signed runtime resource because the native launch contract requires it.
- Can be compiled in Xcode CI without invoking the existing IPA builder.

No Xcode project target or native compile/link test is claimed by this document. SideStore and the IPA build/sign/export workflows remain out of scope.

## Java runtime source closure and asset generation

The source importer now also vendors the runtime build inputs that the upstream recipes previously referenced but that were absent from the first snapshot:

- `src/java-framework/src/`: 820 Husk Java framework implementation files.
- `src/java-framework/gen-src/`: 2,270 generated Android platform signature/constant stubs. These are compile-time declarations, not Android framework method implementations.
- `src/java-framework/gen/` and `stubs/`: generators and compile-time interface inputs.
- `src/art-support/`: Android guest-side ART support source.
- `tools/strip_framework_res.py`, `tools/compat/`, and `scripts/copy_aosp_bundle.sh`: helpers referenced by the runtime build recipes.

The generated source audit currently reports 3,286 imported files: 99 native C/Objective-C sources across all audited groups, 820 Java framework sources, 2,270 generated platform stubs, 53 headers/includes, 24 build/helper scripts, 10 Swift host references and 7 documents. The source inventory is not a license clearance: 837 non-generated files still lack per-file SPDX markers and 2,270 generated stubs lack SPDX markers. The root Husk GPL-2.0-or-later notice and the additional Android/AOSP provenance note must be retained; verify the exact Lineage framework image notices before redistributing generated runtime payloads.

### Runtime data requirements

- `build_java_runtime.sh` consumes extracted ART, i18n, Conscrypt and tzdata APEX contents, the matching `framework-res.apk` and `org.apache.http.legacy.jar`, a JDK and R8/D8. It generates `husk-framework.dex` and `husk-framework-core.dex` plus the copied APEX Java/native libraries.
- `build_android_system.sh` supplies the Android system fonts, font XML and Conscrypt certificate store.
- `build_art_support.sh` builds Android guest-side `libunwind.so` and `libartpalette-system.so`; it is separate from the iOS host runtime.
- The new INFINITY asset builder extracts only the required system/APEX content from the pinned Lineage v2 image, builds the Java runtime in an isolated temporary source copy, validates required files, preserves the Android NOTICE when present, and emits a runtime-data ZIP. It does not package the full QEMU guest image or an IPA.
- The runtime asset workflow is manual-dispatch only and uploads an Actions artifact. It has not yet been executed; no runtime data bundle is claimed available.

### Native bridge implementation boundary

- The INFINITY-owned C adapter now dispatches all ten Husk engine kinds through the app-facing native API: Unity, Java, Cocos, GameActivity, SDL, Unreal, Godot, GTA, Flutter and GameMaker.
- Husk's own generic `husk_unity_touch`, `husk_unity_set_paused`, frame and performance APIs are engine-aware dispatchers; INFINITY routes generic controls through those rather than collapsing non-Java engines into Unity.
- Java launch is gated by a successful runtime-asset validation. All launches require a readable ANGLE library and a valid Metal surface; Unreal additionally requires a readable MoltenVK library.
- Swift exposes the engine selection, launch, touch, pause, Java keyboard hooks, live frame metrics and nonblocking stop through `INFINITYHuskRuntime`. It is not yet connected to the APK Library UI.
- The ANGLE build has its own isolated iOS arm64 workflow and is not an IPA build. The ANGLE artifact must still be integrated/embedded and code-signed as part of a future authorized app build before it can be loaded by the app.

## Strata APK library and launch surface

- Added a persistent APK store under Strata's Documents area. Imports are copied into a staging directory, inspected as ZIP/APK, decoded for manifest metadata, validated for package ID and DEX content, then atomically moved into a package-named directory with an index update/rollback path.
- Split-required APKs are recorded but launch is blocked; split APK installation is not implemented yet.
- APK app data is stored separately from the base APK under a per-package data directory.
- Added a Metal-backed UIKit surface with multi-touch pointer tracking and a SwiftUI launch screen showing live FPS/frame-time diagnostics and pause-on-background behavior.
- Added a folder-based runtime-data installer. It validates Java framework/APEX files, Android system fonts/font maps/certificates and the CA bundle, stages the payload, then swaps it into the runtime directory with rollback.
- The app does not treat a dylib copied into Documents as executable code. ANGLE and optional MoltenVK are accepted only from the app's signed `Frameworks` bundle. The ANGLE build workflow is separate and currently produces a build artifact; project embedding/signing is still a gate.
- APK UI launch remains blocked until native/system assets and the signed ANGLE library are present. No real APK has yet been launched from this UI.
