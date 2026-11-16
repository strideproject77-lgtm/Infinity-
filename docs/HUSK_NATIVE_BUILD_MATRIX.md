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
- ANGLE dylib as currently described by the manifest: dynamically loaded by the QEMU/virgl graphics path. Re-evaluate only if a native translation-layer EGL path demonstrably requires it.
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
4. `build_angle_ios.sh` builds ANGLE from a WebKit checkout. Its own description is tied to the QEMU/virgl graphics stack; do not make it a prerequisite for the initial native runtime compile.

Do not run these recipes as a group. They have external toolchain, source-image, generated-artifact and licensing requirements. Review each output's provenance, architecture and redistribution terms before bundling it.

## Host bridge boundary

The 73 Swift-to-C function names now have textual matches to native declarations and definitions. That is useful symbol inventory only: it does not prove ABI compatibility, calling conventions, ownership/lifetime safety or link success. The selected upstream Swift host files also depend on Husk-specific window/orientation/app models. Keep them as reference material until INFINITY-owned adapters are written; do not compile them wholesale.

## Safe next build milestone

Create an isolated native C target/module that:

- Uses the pinned dual-tree source set only after per-file source/flag review.
- Exposes a narrow INFINITY-owned C header and Swift wrapper, without importing `HuskBridge.h`.
- Links only dependencies proven by the target's compile/link output.
- Does not add QEMU, ANGLE, MoltenVK, StikJIT, SideStore, guest-image scripts or unrelated app targets.
- Can be compiled in Xcode CI without invoking the existing IPA builder.

No Xcode project target or native compile/link test is claimed by this document. SideStore and the IPA build/sign/export workflows remain out of scope.
