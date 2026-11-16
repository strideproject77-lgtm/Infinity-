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

- Expanded the pinned importer to include both translation-layer C trees, the selected Swift host files, app-entry-point source as audit-only reference, CA certificate resource, required runtime build recipes and technical/licensing documentation.
- Recorded the discovered dual dependency: translation-layer-next is the primary runtime, but the selected current Swift host still calls legacy translation-layer attempt/check APIs.
- Added host dependency notes for TLWindowHost, HuskOrientation, file picker, input/audio/log helpers and upstream linker frameworks.
- Expanded the audit generator to inventory native and Swift source groups, SPDX markers, quoted includes, system header includes and Swift module imports.
- Kept all imported material under Vendor/Husk/, outside Strata's synchronized source groups.
- Did not change Xcode target membership, project build settings, SideStore or the IPA builder.

## Remaining integration work

1. Execute the manual import workflow and review the generated manifest/audit, including per-file provenance and embedded include data.
2. Resolve legacy-vs-next runtime ownership and replace legacy attempt/check calls only after mapping their behavior to the new runtime.
3. Extract TLWindowHost and orientation behavior into INFINITY-owned adapters; do not compile HuskApp.swift or unrelated app UI.
4. Create a dedicated isolated runtime target/module and stable Strata-facing API, with explicit framework/resource dependencies.
5. Connect APK intake, split APKs, runtime data, native libraries, DEX execution, graphics, audio and input to Strata's app lifecycle.
6. Compile the isolated target without changing SideStore or global project settings.
7. Run real APK tests and record device-level evidence. Never count APK inspection or a successful compile as playable compatibility.

## Evidence and limitations

The upstream source tree and project manifest were inspected at the pinned revision. Husk's project.yml includes translation-layer-next but also links QEMU, ANGLE, MoltenVK and other separately built components and stages a guest image. Its project file must not be copied wholesale.

The importer and audit generator have been expanded to stage both C source trees and the relevant host dependency sources, but the manual workflow has not yet been dispatched. No Husk sources have yet been copied by that workflow, no native runtime target has been compiled, no IPA has been built, and no real APK execution is claimed.


## Materialized source audit — 2026-11-17

The pinned source import has now run successfully through GitHub Actions run 43935128347 and was committed as 7895c7dc03b66f49598081bd4e5a19c9cc93513d. The vendored snapshot contains 167 files: 96 native source files, 10 Swift host files, 52 headers/includes, 4 build recipes, 4 docs, and 1 certificate resource.

The generated audit found no unresolved quoted includes using its current local-path/basename scan, and 12 files without SPDX markers in the first 8 KiB. Neither result proves that the source compiles or that provenance is fully resolved. The no-SPDX items include scripts, a certificate bundle, embedded include data, and docs; provenance must be reviewed individually.

The pinned upstream XcodeGen manifest compiles both `src/translation-layer` and `src/translation-layer-next` into Husk's app target. It lists native link dependencies (zlib, libresolv, sqlite3, AudioToolbox, CoreText, CoreGraphics, ImageIO, WebKit, VideoToolbox, CoreMedia, CoreVideo, Accelerate, Security), plus separately built ANGLE/MoltenVK and runtime data (Java runtime and Android system fonts/certificates). Its QEMU guest staging/build assets are separate from the native translation target and are not imported into INFINITY.

The Swift host references are not directly compilable as a Strata drop-in: the legacy host layer references Husk-only app services/models, and the engine view depends on native C entry points plus Husk window/orientation adapters. Keep the original sources intact under Vendor/Husk and write Strata-owned adapters around a stable runtime interface.

## Integration gates after source import

1. Complete a host-to-C symbol/API map, including legacy scan/attempt APIs and native launch, input, graphics, and lifecycle calls.
2. Review all no-SPDX and embedded data files for provenance and applicable licenses; inspect build recipes without executing them blindly.
3. Create an isolated INFINITY-owned runtime target with explicit source membership, frameworks, generated assets, and deployment constraints.
4. Keep QEMU outside the native target unless a separately tested optional backend is justified.
5. Preserve SideStore targets, source, entitlements, packaging, signing, installation and refresh flows. Do not alter the IPA builder or build/sign/export an IPA without explicit permission.
6. Require Xcode compile/link evidence before marking the backend integrated, then require real-device APK launch/render/input/stability evidence before claiming compatibility.

**Current status:** source materialized and inventoried; no Husk source has yet been compiled into Strata, no runtime target exists, and no APK execution is verified.


## Host API closure audit — 2026-11-17

The import pipeline now separates the native translation-layer host candidates from QEMU/mixed-host references. `HuskAudio.swift`, `HuskKeyboard.swift`, and `HuskLog.swift` are kept under `host-reference/`: their current implementations call QEMU guest audio/display/JIT functions, not the native translation-layer APIs. The six host candidates retained under `host-runtime/` are still reference material, not direct Strata target members.

The generated host API audit maps 73 function calls from those Swift files to 73 declarations and 73 native definitions in the two translation-layer trees. One C struct initializer (`husk_unity_perf`) is classified separately. The audit strips C comments before matching, avoiding false declarations from comments. This is a textual source map, not an ABI, compiler, or linker test.

The latest import workflow (run 43936567610) succeeded and committed the refreshed pinned snapshot as 9eb30d6a824ae0238203fed9bbf51d3c797f625f. The source-contract/APK archive test job (run 43936567412) passed. Swift parser type-check was queued at the last check.

The snapshot still has 13 files without SPDX markers in the first 8 KiB and one unresolved include in audit-only `host-reference/HuskBridge.h` (`HuskRPPairing.h`). The latter belongs to the excluded pairing/JIT feature and should not be imported merely to make the reference header self-contained.

**Current status:** both Husk C source trees are vendored and inventoried; 73 native host API calls are textually mapped; no native runtime target has been created or compiled, and no real APK execution is verified.
