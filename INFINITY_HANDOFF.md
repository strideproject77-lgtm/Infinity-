# INFINITY Handoff

Last updated: 2026-11-17

## Project direction

INFINITY combines the existing Strata iOS host/launcher with the licensed Husk Android translation runtime, plus selected useful Stride features. Husk's applicable licenses and notices will be followed. Use Swift for Strata/UI and orchestration, C for Husk's native translation components, Objective-C/Objective-C++ for Apple/native bridges, and C++ where dependencies such as QEMU require it. QEMU is approved if it materially helps coverage or avoids delaying a releasable build; keep it isolated and do not let optional guest-image work block the first usable native-runtime milestone. APK and IPA imports must appear together in one Home Screen and unified Library; the runtime is selected internally when an app launches. Store/catalog work is planned for both IPA and APK apps.

## Repository safety

- Repository: `strideproject77-lgtm/Infinity-`
- Active branch: `main` (the only branch found during this audit).
- Baseline commit: `3221d76e332ceb1330882b4d55fdb6a1bf565cb0` — Strata 4.0.
- Do not create a second development branch unless the project owner changes this instruction.
- Do not force-push or reset `main`.
- Do not build, sign, or export an IPA without explicit permission.

## Protected components

- **Built-in SideStore is protected and must remain untouched.** Do not edit, refactor, rename, move, replace, relink, or change entitlements/configuration for anything under `SideStoreSupport/`, `LiveProcess/SideStoreLiveProcessHandler.m`, SideStore build targets, SideStore framework embedding, refresh/signing/installation flows, or their dependencies. Do not change SideStore-related project settings. Keep Android runtime code isolated from SideStore. If an integration appears to require a SideStore change, stop and report the conflict before editing.

## Current verified baseline

- Strata 4.0 is present, including its launcher, app switcher, settings, runtime diagnostics, memory overlay, and existing LiveContainer/LiveExec32 paths.
- The current runtime manager has no Android APK execution engine integrated.
- No Husk translation-layer source directory is present in the INFINITY tree.
- Husk's upstream repository is GPL-2.0-or-later. The project owner approved following Husk's applicable license obligations for included components. QEMU is permitted when it materially helps compatibility or avoids delaying the release. QEMU is not presumed to improve speed: it emulates a full Android guest on iOS devices without a usable hardware hypervisor and can require multi-gigabyte guest assets.
- Husk's own translation-layer code and every third-party component must retain their applicable copyright notices and licenses. Android/ATL-derived, AOSP, ART/libcore, and platform-native components require per-component provenance and compatibility review before redistribution.
- Husk's translation-layer documentation describes an experimental path; milestones and hardware evidence must be checked against current source before claiming APK execution support.

## Fork synchronization

- No scheduled or push-triggered upstream-source synchronization workflow was found.
- `.github/workflows/update_source.yml` is manual-dispatch only and updates the AltStore source metadata; it is not an upstream fork-sync workflow.
- GitHub fork synchronization is therefore manual. Keep it manual and only sync upstream after an explicit review.

## Implementation phases

### Phase 0 — baseline audit
Status: complete.

- Confirmed `main`, current baseline commit, existing Strata runtime entry points, third-party notices, and workflow inventory.
- Confirmed no Android runtime source is currently integrated.

### Phase 1 — Husk runtime and QEMU backend source/provenance migration
Status: source inventory complete; architecture documented; isolated backend registry committed; engine integration not yet started.

- Audited Husk upstream revision `29abb512d81bf8cc08babcbe7f7007cb557208ef` (2026-11-11).
- Found 126 files / approximately 2.67 MiB under `src/translation-layer-next/`: 79 C, 41 headers, 4 Objective-C, and 2 include files. The selected runtime tree includes Dalvik/DEX, ELF loader, Bionic, JNI, Binder/service manager, EGL/GLES, audio, and engine-specific bridges.
- Sampled core runtime files (`husk-tl-dvm.c`, `husk-tl-ld.c`, `husk-tl-bionic.c`, `husk-tl-jni.c`, `husk-tl-egl.c`); each inspected file declares `GPL-2.0-or-later`. Full per-file provenance audit is still required before copying the whole tree.
- Husk's XcodeGen project includes `translation-layer-next` in the Husk app target, but also links QEMU and runs a guest-image staging build phase. INFINITY must import the runtime sources and only their required iOS dependencies, not the Husk app target/build scripts/guest assets.
- QEMU is approved when it materially improves coverage or avoids blocking the release. Audit its build, iOS threading, display/input/audio bridge, guest-image distribution, memory requirements, and shutdown lifecycle separately from the native translation runtime.
- Do not make QEMU the default APK path or claim it improves speed. Benchmark native translation and guest emulation independently on supported devices.
- Keep QEMU guest images optional and downloadable only with clear storage/network warnings; never bundle multi-gigabyte images by default.
- Preserve upstream copyright headers, GPL notices, and all third-party licenses.
- Do not import unlicensed wrappers or files with unclear provenance.
- Integrate the selected source into the Xcode project/build system and document the pinned upstream revision.

### Phase 2 — APK intake and analysis
Status: ZIP inventory, bounded manifest extraction, and binary Android manifest metadata decoding implemented; APK installation and execution are not implemented.

- `INFINITYAPKInspection.swift` inventories the APK ZIP central directory, DEX filenames, native libraries, ABI folders, compression methods, and archive sizes.
- `INFINITYAPKArchive.c/.h` extracts a named ZIP entry using stored or raw-DEFLATE compression, with a 16 MiB output cap, local-header/name checks, and CRC validation. zlib is linked only to the LiveContainerSwiftUI target.
- `INFINITYAPKManifest.swift` decodes Android binary XML string pools (UTF-8/UTF-16), manifest package, version name/code, application label/icon resource reference, and MAIN/LAUNCHER activity.
- Runtime Manager now displays the decoded package and launch metadata when available. Resource references are reported as IDs; `resources.arsc` resolution and actual icon extraction are not implemented.
- Added `tests/test_infinity_apk_archive.py` for stored/deflated extraction, missing entries, and corrupt archive rejection. The test harness is committed but has not been executed in this environment.
- No Xcode/iOS build or real APK execution test has been performed. Do not treat manifest parsing as runtime compatibility evidence.
- Next: add resources.arsc/icon extraction and DEX/ELF header inspection, then wire validated package records into the unified Home Screen.

### Phase 3 — Java/DEX execution
Status: not started in INFINITY.

- Port the selected Husk DEX/ART execution components under their applicable license.
- Implement class loading, method resolution, verification, lazy class initialization, exceptions, and Android core-library dependencies.
- Validate with real APKs, not a built-in demo screen.

### Phase 4 — Native ARM64 execution
Status: not started.

- ELF mapping, relocations, symbols, TLS, executable memory/JIT, Bionic ABI shims, JNI, and Android system-call adaptation.
- Handle iOS 16 KiB pages and Darwin memory/thread semantics.
- ARM32-only APKs require a separate CPU-emulation strategy and are not native ARM64 support.

### Phase 5 — Android framework and graphics
Status: not started.

- Activity/Context lifecycle, resources, views/widgets, services, storage, permissions, networking, input, audio, EGL/GLES and supported Vulkan paths.
- UIKit/Metal/CoreAudio integration; no Android guest OS for the native path.

### Phase 6 — unified platform UX
Status: not started.

- APK and IPA apps share the same Home Screen, Library, search, folders, icons, and recently played list.
- Add separate IPA App Store and APK catalog experiences with download/install management, subject to iOS restrictions.

### Phase 7 — consolidated real-device validation
Status: not started.

- One consolidated test pass per implementation batch.
- Start with 2048, then Hill Climb Racing, then additional real APKs.
- Record device, iOS version, signing/JIT mode, app version, launch result, rendering, input, audio, stability, and logs.
- Never claim compatibility based only on static analysis, a simulator, or a one-frame demo.

## IPA builder and language audit — 2026-11-16

- Confirmed the existing IPA builder is present at `.github/workflows/build.yml`; no replacement builder is needed.
- It uses Xcode 27.2, `xcodebuild archive`, the `LiveContainer` scheme, iOS device ARM64 Release, then `.github/build_github.sh` packaging. It is manually dispatched and publishes LiveContainer and LiveContainer+SideStore artifacts plus an archive.
- The packaging script contains SideStore-specific packaging and metadata operations. Because SideStore is protected, this script and its workflow were not modified or run. No IPA was built, signed, or exported.
- Language decision: Swift for Strata/UI and orchestration; C for Husk translation runtime; Objective-C/Objective-C++ for Apple/native bridging; C++ only where required by dependencies such as QEMU. Existing Xcode builder supports this mixed-language project; new source membership and linker settings still require a target-by-target audit.
- Added `docs/INFINITY_BUILD_PIPELINE.md` with the builder audit, language decision, and SideStore-safe integration rules.
- Tests: repository/workflow/source inspection only. No Xcode compile, IPA build, simulator run, device run, or APK execution test.
- SideStore: untouched.
- Blockers: per-file Husk license/provenance audit; selected runtime dependency graph; safe Xcode target membership; native framework/linker configuration; QEMU dependency and guest-image assessment.

## Current batch report

- Runtime changes: existing isolated backend registry remains a capability contract only; native and QEMU engines are not integrated.
- UI/UX changes: none in this batch; no placeholder runtime UI was added.
- Extra features: existing builder audit and mixed-language implementation plan documented.
- Tests: repository/workflow/source inspection only; no Xcode build, simulator run, device run, or APK execution test. IPA build/export remains unauthorized.
- SideStore: protected source, targets, packaging script, entitlements, and workflows were not modified.
- Blockers: full source/provenance and license review; actual engine source integration; native framework/linker configuration; QEMU build/guest/graphics/audio bridge; test access to a real device.
- Actual progress: Phase 0 complete. Phase 1 has source inventory, dual-backend design, and registry foundation committed; native and QEMU engine integration remain incomplete.

## Upstream update audit — 2026-11-16

- Checked the latest visible commits for Strata upstream (`huzaifahshahid71-ops/Strata`): latest remains `3221d76e332ceb1330882b4d55fdb6a1bf565cb0` (Strata 4.0, 2026-11-11), matching the INFINITY baseline.
- Checked Husk upstream (`Leviidev/Husk`): latest visible commit remains `29abb512d81bf8cc08babcbe7f7007cb557208ef` (2026-11-11), matching the previously audited revision.
- No newer upstream commits were found in this check. Continue manual monitoring; do not blindly sync or merge. Audit code, dependencies, compatibility, security, and licenses before selectively integrating changes.

## Current batch report — 2026-11-16

- Runtime changes: no Husk execution engine imported yet. The backend registry remains a capability contract and is not marked ready.
- APK intake: added a read-only ZIP archive inspector and connected it to Strata Runtime Manager. It inventories manifest presence, DEX names, native library paths, ABI folders, compression methods, and sizes; it does not decode, extract, install, or run APKs.
- Tests: `swiftc -typecheck` passed for the inspector on Linux after guarding Apple security-scoped URL calls by platform. A synthetic ZIP/APK fixture passed checks for manifest presence, DEX inventory, arm64-v8a detection, native library inventory, and stored/deflated entry counts. No Xcode build, iOS device test, or real APK execution was performed.
- UI: added a small APK inspection section in Runtime Manager. Existing IPA launch path and SideStore code were not intentionally changed.
- IPA: no build, signing, or export performed.
- Blockers: Husk per-file provenance/dependency audit and source integration; APK binary XML decoding; real APK test assets/device validation; safe native runtime build configuration.
- Actual progress: Phase 0 complete; Phase 1 architecture/source inventory and backend registry foundation complete but runtime engine integration pending; Phase 2 started with read-only APK archive inspection.


## Husk bulk-import pipeline — 2026-11-16

- Added `scripts/import_husk_runtime.sh`, a repeatable source importer pinned to Husk commit `29abb512d81bf8cc08babcbe7f7007cb557208ef`.
- The importer fetches the exact commit and uses `git archive` to copy only `src/translation-layer-next/`, the upstream root license, and Husk's licensing guide. It does not execute upstream scripts.
- Vendored output is staged under `Vendor/Husk/`, outside Strata's synchronized Xcode source groups so an unreviewed source dump is not auto-compiled.
- Added `docs/HUSK_IMPORT_PIPELINE.md` with import/refresh and dependency-audit workflow, and `Vendor/Husk/THIRD_PARTY_NOTICES.md` recording the upstream GPL-2.0-or-later obligation and per-component license caveat.
- Import command: `bash scripts/import_husk_runtime.sh`; refresh requires explicit `--refresh` and a deliberate pin update after upstream review.
- The importer has been committed but **has not yet been executed** in a checkout. No Husk source files have been vendored or compiled by this step, and no APK execution capability is claimed.
- The importer deliberately excludes Husk UI/app code, QEMU tree and guest images, build/package/signing scripts, generated binaries, and unrelated tools. QEMU remains a separate optional integration decision.
- SideStore source, settings, targets, packaging, signing, refresh, and installation workflows were not changed. The existing IPA builder was not run; no IPA was built or signed.
- Next substantial batch: run the importer in a controlled checkout, audit the imported tree's per-file SPDX/provenance and transitive dependencies, then integrate a dependency-complete native runtime slice behind an isolated target. Keep all source out of SideStore and do not mark the backend ready until a real APK launch is verified.

## Current batch report — 2026-11-16 (APK metadata batch)

- Implemented bounded ZIP entry extraction in C using the iOS SDK zlib library. Stored and raw-DEFLATE entries are supported; output is capped at 16 MiB and validated against the local header, central-directory name, and CRC.
- Implemented Android binary XML manifest decoding in Swift, including UTF-8/UTF-16 string pools, package ID, versionName/versionCode, application label, icon resource ID, and MAIN/LAUNCHER activity resolution.
- Connected manifest metadata to the Runtime Manager APK inspection report.
- Added a host-side Python regression test harness and a separate GitHub Actions test workflow for C ZIP-extraction tests plus Swift parser type-checking. The workflow has been committed but no run result has been verified; no test pass is claimed. This workflow does not build, sign, or export an IPA.
- Added the exact Husk upstream GPL-2 license text and provenance record at `ThirdParty/Husk/`. Husk native runtime source is still not vendored or compiled. The current APK inspection code is original INFINITY code.
- Modified only the LiveContainerSwiftUI bridging header and its Debug/Release linker flags to expose the archive helper and link zlib. SideStore source, target, signing, install/refresh logic, and packaging workflow were not modified.
- No IPA build/sign/export was run. No Xcode build, iOS device test, or real APK execution was performed.
- Known limitations: no `resources.arsc` string/icon resolution, no actual icon extraction, no DEX/ELF metadata parsing, no APK installation or execution.
- Next large batch: inspect and import the complete required Husk runtime source/dependency set, create a dedicated build integration that does not affect SideStore, and then connect the native runtime entry points.


## One-click bulk Husk source import — 2026-11-16

- Added manual workflow `.github/workflows/import-husk-runtime.yml`. From GitHub Actions on `main`, it runs the pinned importer, generates the audit, and commits the vendored runtime snapshot to `main`; no local Mac/laptop is required. It does not invoke the IPA builder.
- Added `scripts/audit_husk_runtime.py` to generate `docs/generated/HUSK_SOURCE_MANIFEST.json` and `docs/generated/HUSK_SOURCE_AUDIT.md`, inventorying source/header files, SPDX markers, and unresolved quoted includes.
- Updated `docs/HUSK_IMPORT_PIPELINE.md` with the mobile-friendly Actions workflow steps.
- Workflow is manual-dispatch only, limited to the main ref, and commits only `Vendor/Husk` plus the generated source audit. Refresh is an explicit boolean input; the upstream commit remains pinned in the importer.
- This is a bulk source-copy and audit pipeline. It is not yet an automatic Xcode integration generator: the source tree may require generated headers, framework/linker settings, platform adaptations, and third-party dependencies. The workflow intentionally does not compile all 126 files or register them in Strata's target without a dependency-complete selection.
- The Actions workflow has been committed and its files were fetched back for verification. It has **not been dispatched**, so no vendor snapshot or generated inventory has been created yet.
- No Xcode build, IPA build/sign/export, device test, or APK execution was performed. SideStore and the existing IPA builder remain untouched.

## Husk source import readiness — 2026-11-16

- A pinned importer is available at `scripts/import_husk_runtime.sh`; it fetches exact Husk revision `29abb512d81bf8cc08babcbe7f7007cb557208ef` and stages only `src/translation-layer-next/`, its GPL license, and licensing guide under `Vendor/Husk/`.
- `scripts/audit_husk_runtime.py` creates a file/SPDX/quoted-include inventory after import.
- Manual GitHub Actions workflow: `.github/workflows/import-husk-runtime.yml` (Actions → Import Husk Runtime Sources → Run workflow on `main`, `refresh=false`).
- This import workflow has not yet been dispatched or verified. Until it runs and its generated manifest/audit are reviewed, no Husk native source is present in the vendored tree and no runtime integration is claimed.
- A separate `.github/workflows/infinity-tests.yml` was added for the original APK ZIP helper and Swift parser type-check. Its run result is not yet verified.


## Husk-level native integration batch — 2026-11-16

- Reconfirmed the latest upstream Husk revision is still 29abb512d81bf8cc08babcbe7f7007cb557208ef (2026-11-11); the Strata upstream remains at release 4.0 (2026-11-11).
- Changed the integration target from a minimal staged runtime to preserving Husk's advanced translation-layer architecture inside Strata. Strata remains the host/UI; Husk's translation-layer-next remains the primary execution engine; Apple-specific work belongs in a separate adapter.
- Expanded scripts/import_husk_runtime.sh to vendor the pinned 126-file native translation-layer-next tree plus selected host runtime files (TLUnityView.swift, TLAppSettings.swift, HuskGamepad.swift, HuskKeyboard.swift, HuskLog.swift and HuskFilePicker.swift), runtime build recipes and technical/licensing docs.
- The importer remains isolated under Vendor/Husk and replaces only its owned groups. It explicitly preserves Vendor/Husk/THIRD_PARTY_NOTICES.md. It does not add files to Xcode targets or execute upstream build scripts.
- Expanded scripts/audit_husk_runtime.py to inventory native and Swift source groups, SPDX identifiers, quoted includes, system headers and Swift module imports. Added tests/test_husk_import_pipeline.py and updated infinity-tests.yml to run the importer contract checks alongside existing APK archive tests.
- Updated docs/HUSK_IMPORT_PIPELINE.md, docs/HUSK_RUNTIME_INTEGRATION.md and docs/INFINITY_RUNTIME_ARCHITECTURE.md to reflect the advanced Husk-as-runtime direction, the required Java/system/ANGLE assets, host callback dependencies, QEMU separation and protected Strata/SideStore boundaries.
- Upstream review found TLUnityView.swift is the native-engine host surface and includes engine launch, touch/text input and performance hooks; the selected Swift host files have dependencies on Husk-specific models/orientation/windowing/file-picker APIs. They are vendored for reuse but are not yet compiled into Strata.
- The Husk project.yml includes translation-layer-next but also links separately built ANGLE, MoltenVK, QEMU and helper libraries and runs guest staging. Its full Xcode project must not be copied into Strata. QEMU remains optional and separate.
- No source import workflow has been dispatched yet; therefore the expanded vendor snapshot and generated audit are not present. No dedicated Xcode runtime target has been created, no compile/link test or real APK execution has been performed, and no compatibility percentage is claimed.
- No IPA build/sign/export was run. SideStore source/targets/configuration/entitlements/signing/refresh/install systems and the existing IPA builder were not modified.
- Next action: run Actions → Import Husk Runtime Sources on main with refresh=false, review the generated manifest/audit, then create the isolated Husk runtime target and Strata adapter as one dependency-complete integration batch.


## Husk host dependency closure — 2026-11-16

- Updated `scripts/import_husk_runtime.sh` to stage both upstream C source trees: `src/translation-layer-next/` (primary native runtime) and `src/translation-layer/` (legacy host API dependency).
- Reason: the pinned Husk `TranslationLayer.swift` still calls legacy `husk_tl_attempt_*` and APK scan/check APIs. Importing only `translation-layer-next` would leave unresolved host-side C symbols and an incomplete source snapshot.
- Expanded the isolated vendor snapshot to include the selected host source set: `TranslationLayer.swift`, `TLUnityView.swift`, `TLAppSettings.swift`, `AppWindows.swift`, `HuskGamepad.swift`, `HuskKeyboard.swift`, `HuskAudio.swift`, `HuskLog.swift`, and `HuskFilePicker.swift`. The upstream `HuskApp.swift` is kept in `host-reference/` only because it contains the `@main` app entry point; it must never be compiled into Strata.
- Added the upstream CA certificate resource and retained the existing build recipes and technical/licensing documents as references.
- Expanded `scripts/audit_husk_runtime.py` to inventory both native trees, host-runtime sources, host-reference files, resources, build recipes and documentation.
- Reviewed the pinned Husk project manifest and host source references. `TLUnityView.swift` also depends on `TLWindowHost` (currently declared in broad `AppWindows.swift`) and `HuskOrientation` (currently declared beside Husk's `@main` entry point). These must be extracted/adapted before selective compilation; do not add the upstream app entry point or full app UI to Strata.
- The upstream project declares conditional link dependencies including zlib, libresolv, sqlite3, AudioToolbox, CoreText, CoreGraphics, ImageIO, WebKit, VideoToolbox, CoreMedia, CoreVideo, Accelerate and Security. No global linker flags were changed; actual symbol requirements must be resolved in the isolated runtime target.
- Commits on `main`: importer expansion `5336d69`; audit expansion `15eb544`; integration dependency documentation `b1bcb1a`.
- Verification status: GitHub accepted all three commits. The manual import workflow has not been dispatched, so the vendor source files and generated audit have not yet been materialized. No compile, IPA build, device test, or APK execution was run. SideStore, Xcode target membership, the IPA builder and signing/refresh flows were not changed.

### Next integration batch

1. Run the manual source import workflow from GitHub Actions on `main`, then inspect the generated complete manifest.
2. Resolve the full native source dependency closure, generated headers, runtime data and per-file provenance before selecting target membership.
3. Extract the minimal window/orientation adapters from Husk's host UI without importing its `@main` app or unrelated screens.
4. Build an isolated runtime target and stable Strata bridge; keep all SideStore paths and settings unchanged.
5. Only after the target builds, connect APK intake and lifecycle, then validate real APK launch/render/input on device.


### Verification update — 2026-11-16

- The INFINITY native tests run for commit 578d496356070817ebebf0fafb6564eafa1f19a5 completed the source-contract and APK archive regression job successfully.
- Verified passing steps: bash -n scripts/import_husk_runtime.sh, python -m unittest discover -s tests -p test_*.py -v, and python -m py_compile scripts/audit_husk_runtime.py.
- The Swift APK parser type-check job was still queued when this handoff update was made; no result is claimed for it.
- The Husk import workflow remains manual and has not been dispatched. Therefore no imported vendor source, complete generated manifest, runtime compile, or APK execution is claimed.


## Import pipeline hardening — 2026-11-16

- Updated the importer guard so it refuses to overwrite any importer-owned path (both translation-layer trees, host runtime/reference, build-support, docs, resources, license and revision marker) unless --refresh is explicitly supplied.
- Updated the contract tests to cover both legacy and next-generation source trees, the audit-only app entry point, all vendor groups, and overwrite protection.
- Synchronized the import-pipeline and runtime-architecture docs with the actual dual-layer import scope.
- The native test workflow now runs shell syntax validation, all Python unit tests, audit-script syntax validation and the existing Swift parser type-check. The workflow run result has not yet been verified.
- No importer workflow dispatch, vendor materialization, Xcode runtime target build, IPA build, or real APK execution has occurred. SideStore and IPA packaging remain untouched.


## Husk source materialization — 2026-11-17

- The import workflow was changed to run on pushes to main that modify only the pinned importer, audit generator, or import workflow; manual dispatch remains available. This allowed the already-reviewed import pipeline to run without touching the IPA builder.
- GitHub Actions run 43935128347 completed successfully. It checked out main, fetched the exact pinned Husk revision, imported both C source trees and selected host references, generated the source manifest/audit, and committed the result.
- Verified vendor commit: 7895c7dc03b66f49598081bd4e5a19c9cc93513d — `Vendor pinned Husk runtime sources and audit dependencies`.
- Materialized snapshot: 167 files total: 96 native C/Objective-C/C++/assembly sources, 10 Swift host-reference/runtime files, 52 headers/includes, 4 build recipes, 4 technical/licensing documents, and 1 resource.
- Static audit: 0 unresolved quoted includes by the current local-path/basename scan; 12 files have no SPDX identifier in the first 8 KiB. This is not a complete compiler or provenance check. The 12 items include build scripts, certificate data, embedded .inc files, and upstream documentation; each still needs provenance review.
- Upstream `src/app/project.yml` confirms both `translation-layer` and `translation-layer-next` are compiled into Husk's app. It also identifies native dependencies: zlib, libresolv, sqlite3, AudioToolbox, CoreText, CoreGraphics, ImageIO, WebKit, VideoToolbox, CoreMedia, CoreVideo, Accelerate, Security, ANGLE, MoltenVK, Java runtime assets, and Android system data. QEMU guest staging is separate and is not required for the native translation target.
- Host Swift files are not drop-in Strata code. `TranslationLayer.swift` references legacy scan/attempt APIs and Husk-specific app models/services; `TLUnityView.swift` expects Husk's C entry points, window/orientation behavior, and engine callbacks. Do not compile these references wholesale.
- The latest source-contract test jobs report success for the most recent importer guard commits. Earlier runs failed on stale importer contract assertions before the latest test updates; the Swift parser type-check jobs were still queued at the time of inspection.
- No Xcode runtime target, native compile/link, iOS build, IPA build/sign/export, device test, or real APK execution has occurred. SideStore and the existing IPA builder remain untouched.

### Next integration batch

1. Build a complete host-to-C API map for the imported Swift references and native headers; resolve legacy/next ownership and required exported symbols.
2. Review the 12 no-SPDX files and embedded third-party data, plus the build recipes' generated artifacts and transitive licenses.
3. Define a dedicated INFINITY-owned runtime target and stable Swift bridge. Include the native source trees and only the proven iOS dependencies; keep QEMU optional and separate.
4. Add the target to Strata's app path only after verifying project membership does not alter SideStore targets, packaging, signing, refresh, or installation.
5. Compile the runtime target in Xcode CI (not an IPA build), then connect APK lifecycle and run real-device tests.


## Host bridge and build-manifest audit extension — 2026-11-17

- Expanded the pinned importer to include upstream `src/app/Husk/HuskBridge.h` under `Vendor/Husk/host-reference/` only, and `src/app/project.yml` under `Vendor/Husk/build-support/`. Both are audit references, not target members.
- The upstream bridge header is not safe to compile wholesale: it declares QEMU and JIT interfaces and includes `HuskRPPairing.h`, which belongs to Husk's separate pairing/JIT feature. INFINITY needs its own narrow C/Swift bridge for the native translation layer.
- Updated the import workflow so pushes to main that change the pinned importer/auditor/workflow refresh the vendor snapshot; manual dispatch remains available. Push refresh uses `--refresh`, while manual dispatch preserves the explicit refresh choice.
- Import run 43935561028 completed successfully and refreshed the source snapshot. Latest vendor commit: 3d76ba91deed9da67bed6fe6517ba637733fb028.
- Latest manifest: 169 files — 96 native sources, 10 Swift host references, 53 headers/includes, 4 build recipes, 4 docs, 1 resource, and 1 build manifest. Audit reports 13 files without SPDX markers and 1 unresolved quoted include: `host-reference/HuskBridge.h -> HuskRPPairing.h`. This unresolved reference is expected because the entire header is audit-only and its pairing/JIT dependency is intentionally excluded. Do not silence it by importing unrelated JIT code.
- The updated source-contract/ZIP test job for run 43935582154 passed, including shell syntax and audit-script syntax checks. Swift APK parser type-check remained queued at the last check.
- A first overlapping push-triggered import run failed only at the final git push because another main commit landed after checkout; the subsequent serialized import run checked out current main and succeeded. No force-push or reset was used.
- Still not done: no runtime Xcode target, no Husk C compilation/link, no iOS app build, no IPA build/sign/export, no device launch, and no real APK execution. SideStore remains untouched.

### Next batch

1. Map all Swift host calls to the exact native C declarations/definitions, including legacy scanner/attempt functions and next-generation engine lifecycle/input/performance functions.
2. Determine the smallest coherent source target that still preserves Husk's full native architecture; identify generated assets and linker/framework requirements from the upstream build manifest and recipes.
3. Review the 13 no-SPDX items for provenance and transitive licensing; do not treat missing SPDX text as proof of incompatibility.
4. Add a Strata-owned narrow bridge and isolated runtime target only after the symbol/dependency map is complete. Keep SideStore and IPA workflows untouched.


## Native host API closure audit — 2026-11-17

- Reclassified `HuskAudio.swift`, `HuskKeyboard.swift`, and `HuskLog.swift` as host-reference-only because their current implementations depend on QEMU guest audio/display/JIT paths. They are not native translation-layer host components and must not be compiled into the native runtime target as-is.
- The six remaining Swift host candidates stay under `host-runtime/` as references pending Strata adaptation: `TranslationLayer.swift`, `TLUnityView.swift`, `TLAppSettings.swift`, `AppWindows.swift`, `HuskGamepad.swift`, and `HuskFilePicker.swift`.
- Added a first-pass Swift-to-native API audit. After comment stripping and C-struct initializer classification, it maps 73 function calls from the selected Swift host references to 73 matching declarations and 73 matching native source definitions. It separately identifies one C struct initializer (`husk_unity_perf`). No missing function declarations/definitions were reported by this textual scan.
- This is not ABI/compiler/linker proof. The scanner is intentionally scoped to the two translation-layer source trees; QEMU/JIT host functions remain excluded. The upstream HuskBridge.h is still audit-only.
- The importer now refreshes only after reviewed importer/auditor/workflow changes on main; manual dispatch remains available. The latest import/audit run 43936567610 completed successfully and refreshed the snapshot at pinned revision 29abb512d81bf8cc08babcbe7f7007cb557208ef. Vendor commit: 9eb30d6a824ae0238203fed9bbf51d3c797f625f.
- The latest source-contract and APK archive test job (run 43936567412) passed. The Swift APK parser type-check job was still queued at the last check.
- Remaining static audit warnings: 13 files lack SPDX identifiers in the first 8 KiB; one unresolved quoted include remains in audit-only `host-reference/HuskBridge.h` (`HuskRPPairing.h`). Do not import the unrelated pairing/JIT dependency to silence it.
- No native runtime target, Xcode compile/link, IPA build/sign/export, device launch, or real APK execution has occurred. SideStore remains untouched.

### Next integration batch

1. Extract the minimal window/orientation and lifecycle contracts from the host references into INFINITY-owned adapters; do not compile Husk's broad app UI or @main entry point.
2. Define a dedicated native runtime target with both translation-layer trees, an INFINITY-owned narrow bridging header, and only the confirmed iOS frameworks/resources.
3. Audit generated Java runtime, Android system files, ANGLE and optional MoltenVK build products and their licences before any build recipe is run.
4. Add the target only to Strata's app build graph after a target-by-target check proves SideStore source, target, entitlements, packaging, signing, installation and refresh remain unchanged.
5. Run an Xcode compile/link CI job (not the IPA builder), then connect APK intake/lifecycle and validate real device launch/render/input/stability.


## Native build-boundary audit — 2026-11-17

- Reviewed the vendored upstream XcodeGen manifest and all four retained runtime build recipes. The upstream app compiles both `translation-layer/` and `translation-layer-next/`; the newer tree excludes `husk-tl-unity-app.h`. INFINITY currently vendors 96 native sources across both trees.
- Added `docs/HUSK_NATIVE_BUILD_MATRIX.md` to separate native SDK dependency candidates from unrelated app/backend dependencies and generated runtime data.
- Explicitly excluded QEMU guest/build/staging components, the current QEMU/virgl ANGLE path, optional MoltenVK, the separate PS4/FEX dylib, StikJIT/pairing helpers, and Husk's broad app UI from the first native translation target.
- Classified generated data recipes: Android system fonts/certificates, Java APEX/libcore/ICU/Conscrypt/framework assets, Android NDK guest-side ART support libraries, and the ANGLE/WebKit build. None were executed; generated assets and third-party redistribution terms still require review.
- The upstream framework list is a candidate set only. Actual target requirements must be established from compile/link evidence and deployment availability, not copied wholesale from Husk's app manifest.
- Latest verified checks at this point: import workflow 43936567610 succeeded; source-contract/APK archive job in native-tests run 43936567412 passed. Its Swift parser type-check job was still queued when checked. No native C compile/link, Xcode runtime target, IPA build, device test or APK execution has occurred.
- SideStore source, targets, entitlements, packaging, signing, installation and refresh flows remain untouched.

### Immediate next implementation step

Create a narrowly scoped INFINITY-owned native bridge and isolated compile target only after per-file source/flag review. Run its compile/link check in a separate CI workflow that does not invoke the existing IPA builder. Do not mark the runtime integrated until that compile passes; do not claim APK compatibility until real-device execution is verified.

## Swift-to-Husk bridge boundary — 2026-11-17

- Added `LiveContainerSwiftUI/Strata3/INFINITYHuskRuntimeBridge.h` as an isolated declaration boundary. It imports only Husk's app-facing `translation-layer-next/husk-tl-unity-app.h`; it deliberately does not import `HuskBridge.h` or its QEMU/JIT/pairing dependency surface.
- Included that header from the existing `LiveContainerSwiftUI-Bridging-Header.h`, so the existing Strata Swift target can see the upstream C API declarations.
- This is **declaration-level bridging only**.
- Added a dedicated macOS CI smoke check that type-checks the imported Husk C declarations from Swift; it does not link the engine or build an app/IPA. The Husk C implementation is still not part of an Xcode native target, no C symbols are linked, and Swift must not call these functions until the native source target and its dependency closure compile and link.
- No `PRODUCT_BUNDLE_IDENTIFIER`, app target identity, signing setting, IPA builder, SideStore source/target/configuration, or install/refresh flow was changed.
- No IPA build, signing, export, Xcode app build, or device test was run. This commit is not evidence of APK execution.
- Next: finish source/flag/dependency closure, then add an isolated native runtime target and compile-only CI before connecting launch calls.


## Husk native compile-audit batch — 2026-11-17

- Added `scripts/check_husk_native_sources.sh`, a compile-only source audit that enumerates every C and Objective-C implementation in both vendored translation-layer trees and invokes the iPhoneOS SDK Clang for `arm64-apple-ios15.0` with `-fsyntax-only`.
- Added `.github/workflows/infinity-husk-native-compile.yml`, isolated from the IPA builder. It runs only on relevant native-source/script changes or manual dispatch. It does not invoke `xcodebuild`, create an app target, link an app, archive, sign, export, or package an IPA.
- The script's shell syntax was checked locally after correcting the `find` expression. The latest GitHub Actions run for the corrected revision `315c4833c097fd402ff569780b117587f6cab54e` was queued when checked; no native source compile pass/failure is claimed yet.
- The workflow intentionally compiles source files individually rather than asserting that a linkable runtime target exists. It is expected to expose missing generated headers, per-file flags, and SDK incompatibilities. Fixes must be based on actual compiler diagnostics, not broad speculative flags.
- The existing declaration bridge remains in place: `INFINITYHuskRuntimeBridge.h` imports only Husk's app-facing translation API and is included by Strata's existing Swift bridging header. This still does not link the C engine, and Swift launch calls remain gated off until a complete native target links.
- No Xcode project, bundle identifier, product identity, signing setting, IPA workflow/builder, SideStore source/target/configuration, or install/refresh path was modified in this batch.
- No app/IPA build, signing, export, simulator/device launch, or real APK execution was performed.
- Next: review the compile workflow's complete diagnostics, resolve source-level blockers with narrowly scoped changes, then build a dedicated native target without changing Strata's existing LiveContainer bundle ID or protected SideStore/IPA workflows.

## INFINITY master status and progress dashboard — 2026-11-17

This section is the authoritative current snapshot. Older dated sections below/above it are retained as historical records; where their status differs, use this dashboard.

### Product approach and architecture

- Product goal: preserve Strata as the iOS host, launcher, unified Home Screen/Library and IPA manager, while adding Husk's real Android translation runtime for APKs. Do not replace Strata with a separate Android VM or a fake/demo execution surface.
- Runtime strategy: reuse Husk's advanced translation-layer implementation as the primary Android execution engine, rather than inventing a small placeholder runtime and gradually replacing it. INFINITY-owned adapters are required wherever Husk assumes its own app models, window host, orientation, callbacks or services.
- Language boundary: Swift owns Strata UI, app lifecycle orchestration and APK management; C owns the translation engine; Objective-C/Objective-C++ provides Apple-platform adapters where needed; C++ is limited to dependencies that require it.
- Bridging strategy: Swift calls a narrow INFINITY-owned interface; that interface exposes only the native translation-layer API needed by Strata. Do not import Husk's broad `HuskBridge.h`, because it brings unrelated QEMU/JIT/pairing dependencies. A visible C declaration is not proof that a C implementation is compiled, linked or safe to call.
- Native path first. QEMU remains modular and optional; do not let guest images, multi-gigabyte assets, ANGLE/virgl or unrelated PS4/FEX support block the first native Android runtime.
- Keep both upstream translation source trees in scope because Husk's upstream app manifest compiles both. Select files and flags from actual dependency/compile evidence; do not blindly compile every source into Strata.
- Test order: real 2048 APK first, Hill Climb Racing second, then additional real APKs. Compatibility is only claimed after real-device launch, rendering, input, audio and stability evidence.
- Repository discipline: work only on `main`; preserve Strata; do not touch SideStore source, target, entitlements, signing, packaging, installation or refresh paths. Reuse the existing IPA builder only when explicitly authorized. No IPA build/sign/export without explicit permission.

### Current completion estimate

**Overall INFINITY Android-runtime integration: approximately 13%.** This is an engineering estimate of integration work, not a promise of compatibility, and not a measure of how many source files were copied.

| Workstream | Completion | Evidence / meaning |
|---|---:|---|
| Strata baseline and protected-component audit | 100% | Strata 4.0 baseline and SideStore boundaries documented |
| Husk source import pipeline and pinned snapshot | 100% | Automated import/audit workflow succeeded; 169-file snapshot at pinned revision is present |
| Architecture, provenance and dependency inventory | 80% | Dual source trees, upstream manifest, candidate SDK dependencies, build recipes and major exclusions documented; per-file closure/licence review remains |
| Swift-to-C API name inventory | 100% textual scan | 73 function names matched declarations and native definitions; not ABI, compiler or linker proof |
| Swift bridging-header declaration visibility | 100% of this narrow step | `INFINITYHuskRuntimeBridge.h` is included by Strata's existing bridging header and exposes the upstream app-facing translation API |
| INFINITY-owned lifecycle/window/orientation adapters | 0% complete | Still needs extraction and implementation |
| Callable Swift wrapper and runtime lifecycle integration | 0% complete | No safe launch/stop/input/performance call path is wired |
| Isolated Xcode native runtime target | 0% complete | No dedicated target compiling/linking Husk engine |
| Native source compile/link proof | 0% complete | Latest compile-audit job was cancelled; no compiler pass is claimed |
| 2048 real APK execution | 0% | Not run |
| Hill Climb Racing real APK execution | 0% | Not run |
| Other APK compatibility validation | 0% | Not run |
| Unified APK+IPA Home Screen/Library execution flow | 0% runtime integration | Strata host exists; APK records are not yet launchable through a real engine |

The 13% overall estimate reflects completed source materialization, substantial static audit and declaration-level bridge work. It must not be raised merely for documentation, copied source volume or a queued/cancelled CI job. Raise it only when implementation and test evidence advance.

### Implemented and verified so far

1. Strata 4.0 is the host/base; existing IPA builder was audited and retained.
2. APK intake has original INFINITY code for ZIP inventory, bounded ZIP entry extraction, CRC checks, Android binary XML manifest decoding and Runtime Manager reporting. It is inspection/metadata support, not installation or execution.
3. Husk revision `29abb512d81bf8cc08babcbe7f7007cb557208ef` is pinned and materialized under `Vendor/Husk/`; both `translation-layer/` and `translation-layer-next/` are included in the imported snapshot.
4. Import/audit automation and generated source/API inventories are present. Current source snapshot contains 169 files: 96 native sources, 10 Swift host-reference/runtime files, 53 headers/includes, 4 build recipes, 4 documents, 1 resource and 1 build manifest.
5. The upstream XcodeGen manifest and runtime recipes were reviewed. QEMU guest staging, current ANGLE/virgl route, MoltenVK, PS4/FEX, pairing/JIT helpers and Husk's broad app UI are excluded from the initial native translation target.
6. A textual API scan found 73 Swift-to-C function-name matches across declarations and definitions. This does not prove ABI correctness or linking.
7. `LiveContainerSwiftUI/Strata3/INFINITYHuskRuntimeBridge.h` was added and included from `LiveContainerSwiftUI-Bridging-Header.h`. It includes only `husk-tl-unity-app.h`, not `HuskBridge.h`. This currently exposes declarations to Swift; it does not compile or link the engine and no Swift runtime calls are enabled.
8. A separate native source compile-audit script/workflow was added. It attempts syntax-only compilation of C/Objective-C files against the iPhoneOS SDK and is separate from the IPA builder.
9. Source-contract and APK archive regression tests have passed in recent runs. The parser type-check and bridge-check jobs in the most recent relevant native test runs were cancelled, so their success is not claimed.
10. SideStore source, targets, entitlements, packaging/signing/installation/refresh flows and the IPA builder have not been intentionally modified or run.

### Latest CI evidence and current blockers

- Husk source import run `43936567610`: **success**; pinned source snapshot and audit were committed.
- Native test run `43936567412`: source-contract/APK archive job **success**; Swift APK parser type-check job **cancelled**.
- Native test run `43940319040`: source-contract/APK archive job **success**; Swift parser type-check and Swift-to-Husk bridge-header check jobs **cancelled**.
- Husk native source compile-audit run `43943201448`: job **cancelled**. Its log was unavailable when checked, so there is no trustworthy compiler diagnostic summary and no source compile pass/failure count to report.
- No dedicated runtime target, native link, Xcode app build, IPA build/sign/export, simulator/device launch or real APK execution has occurred.
- Remaining technical gates: per-file source/compile-flag/dependency closure; review of 13 files without SPDX markers; generated Android Java/system runtime assets and redistribution provenance; INFINITY-owned window/orientation/lifecycle adapters; a linkable native target; runtime resource packaging; APK lifecycle/framework/graphics/audio/input support; real-device test evidence.
- Treat the 13 missing SPDX markers as provenance-review flags, not proof that those files are unlicensed. The unresolved include in audit-only `HuskBridge.h` is the excluded pairing/JIT header; do not import unrelated pairing/JIT code to silence it.

### Next implementation sequence

1. Inspect and classify every native source's direct includes, conditional macros, platform APIs, generated headers and required compile flags. Resolve the 13 provenance flags before redistribution.
2. Audit the exact upstream app-facing header and exported API semantics, then write INFINITY-owned Swift/C adapters for runtime creation, launch, callbacks, input, orientation, window/display, performance reporting and safe shutdown.
3. Add a dedicated native runtime target with explicit source membership and only proven frameworks/libraries. Keep it isolated from SideStore and from IPA packaging/signing.
4. Add a separate compile-and-link CI job. Fix errors from actual compiler/linker output; do not hide them with speculative global flags or fake stubs.
5. Only after native linking succeeds, connect APK intake to runtime launch/lifecycle and add resource/runtime-data handling.
6. Run one consolidated real-device test batch: 2048 first, then Hill Climb Racing. Record device/iOS version, signing/JIT mode, APK version/ABI, launch result, rendering, touch/controller input, audio, memory/stability and logs.
7. Update this handoff with commit IDs, test run IDs and evidence after each substantial batch. Do not claim an APK is compatible until it has actually run.

### Explicit non-claims

- The declaration bridge is not a completed runtime bridge.
- Imported Husk source is not a compiled engine.
- Static API-name matching is not ABI or link validation.
- APK manifest/ZIP inspection is not APK installation or execution.
- A cancelled CI job is neither a pass nor a confirmed compiler failure.
- No 2048, Hill Climb Racing or other APK compatibility percentage is currently evidence-based; all real execution test coverage remains 0%.
- No IPA has been built, signed or exported in this work.

## Large native-runtime integration batch — 2026-11-17

- Added an INFINITY-owned C boundary over the pinned Husk runtime and connected it to Strata's Swift bridging header. The C API now dispatches explicit launch requests to Husk's Unity, Java/Dalvik, Cocos2d-x, GameActivity, SDL, Unreal, Godot, GTA, Flutter, and GameMaker backends.
- Runtime state, stop, generic multi-touch, pause/resume, frame count, and frame-time/FPS snapshots are routed through Husk's engine-neutral entry points. Java-specific keyboard, text, insets, document-picker, and gamepad host APIs remain exposed separately.
- Java launch is gated on a prepared runtime tree, including the expected ART/libcore/ICU/Conscrypt jars and native libraries, Husk framework DEX, framework resources, Android system fonts and font maps, and certificate directory. Native launches require a readable iOS ANGLE dylib; Unreal additionally requires MoltenVK. This is validation and dispatch code, not proof that any APK works.
- Added a Swift runtime controller and a Metal-backed, multi-touch UIKit surface. Launch waits for a valid drawable size and forwards touch, pause, state, FPS, and frame-time updates to the native runtime.
- Added persistent APK import: validated APKs are copied to Documents/Strata3/AndroidApps/<package>/base.apk, indexed in installed-apks.json, and given a stable separate private data directory so APK updates do not overwrite app data. Known engine markers are detected from native-library names; unknown packages are not assigned a guessed engine.
- Current intake is single-APK only. XAPK/APKS installation, split-APK staging, Android resource/icon extraction, and automatic engine identification for all native engines remain incomplete. APKs that require splits must not be treated as fully supported.
- Added a manual runtime-data build workflow using a checksum-pinned LineageOS image and pinned D8/R8. It builds the Java runtime plus Android fonts, font maps, and certificate data as a temporary Actions artifact. The workflow explicitly excludes QEMU guest images and IPA output; generated Android platform assets still require component-by-component redistribution/license review.
- Added a separate manual iOS arm64 ANGLE build workflow from a pinned WebKit revision. It preserves ANGLE's license and WebKit revision metadata and uploads a temporary artifact. At the time of this handoff, the ANGLE build is still running; no successful artifact validation is claimed.
- Tests: native source-contract/APK archive tests pass on run 44006707225 and source-contract tests pass on run 44007054609. Swift bridge/type-check jobs and the latest native static-library build were still queued/in progress at the last check. A prior full Strata integration build reached the Xcode compile stage but failed on the existing LiveContainer/dyld_bypass_validation.m dependency litehook.h not being found; this is not yet resolved.
- No real APK has been launched. 2048 and Hill Climb Racing remain untested. No simulator/device runtime test has been performed. No IPA has been built, signed, or exported.
- SideStore source, target, settings, signing, installation, refresh, and packaging paths remain protected and untouched.


## Authoritative current status — 2026-11-17 (large Husk integration batch)

This section supersedes earlier phase/status statements above where they still say the Husk source is absent, APK installation is not implemented, or native integration has not started.

### Chosen architecture and implementation approach

- **Strata remains the iOS host, UI, IPA manager and app lifecycle owner.** The existing IPA/LiveContainer flow remains the host foundation.
- **Husk is the Android translation runtime.** Both upstream translation trees are included in an isolated Swift package target under `Vendor/Husk/Package.swift`; the package does not compile Husk's `@main` app, QEMU app UI, pairing/JIT helpers, or SideStore code.
- **INFINITY owns the narrow host boundary.** Strata imports `INFINITYHuskRuntime.h`, not Husk's broad `HuskBridge.h`. C dispatches explicit engine types; Swift owns lifecycle and UI; Objective-C sources required by the translation tree are compiled in the isolated runtime package.
- **Runtime assets are separate from runtime code.** Java/APEX/ICU/Conscrypt/framework DEX and Android system fonts/certificates are generated from a matching Android system image. ANGLE is a separate iOS arm64 dylib and is required by Husk's native EGL/GLES launch contract; it is not merely a QEMU/virgl dependency. MoltenVK remains optional and Unreal-specific.
- **QEMU remains optional and separate.** The runtime asset builder does not include a QEMU guest image. QEMU is not used as a prerequisite for the first native 2048 test.
- **Test order remains 2048 first, then Hill Climb Racing.** Source import, parser results, and engine detection do not count as APK compatibility evidence.

### Implemented in this batch

- Vendored the pinned Husk snapshot and runtime build inputs under `Vendor/Husk`, including both translation trees, Java framework implementation sources, generated platform signature stubs, ART support sources, and build helpers. The importer preserves the INFINITY vendor-layout patch to the Java framework generator.
- Added an isolated Swift package static target for the Husk translation runtime and an INFINITY-owned C API.
- Added explicit C dispatch for Unity, Java/Dalvik, Cocos, GameActivity, SDL, Unreal, Godot, GTA, Flutter and GameMaker. The bridge routes generic touch, pause, frame count and performance through Husk's engine-aware dispatchers; Java keyboard/text/insets/document-picker hooks remain separately exposed.
- Added runtime readiness checks: Java launch requires the prepared ART/libcore/ICU/Conscrypt/framework DEX/resource files; native engine launch requires Android system files/fonts/certificates and ANGLE; Unreal additionally requires MoltenVK. The bridge rejects incomplete runtime assets instead of pretending to launch.
- Added the Swift runtime controller, asynchronous native shutdown, frame/FPS metrics, and a Metal-backed multi-touch surface.
- Added persistent APK import and Library entries. APKs are copied to the app's private Documents store; per-package app data is stored separately so APK replacement does not overwrite app data. Unsafe package identifiers are rejected. Apps requiring uninstalled split APKs are blocked rather than treated as supported.
- Added runtime-gated launch details. Unknown engine types are not guessed. The launch view uses the selected Husk engine and a real CAMetalLayer; it does not contain a built-in demo execution path.
- Added a reproducible Java framework DEX workflow and a separate iOS arm64 ANGLE build workflow. The ANGLE build pins WebKit source and preserves the BSD license notice/revision metadata.
- Added `scripts/build_infinity_runtime_assets.sh` to prepare Android Java/system runtime data from a user-supplied matching Lineage image. It validates required assets and produces a data-only ZIP; it does not include a QEMU guest or IPA.
- Expanded source-contract tests for engine dispatch, APK persistence/data separation, split gating, Metal launch surface, runtime asset builder, and ANGLE provenance.

### Verified evidence and unresolved CI

- **Java framework DEX build:** workflow run `44006040768` completed successfully. This verifies the Java framework source-to-DEX build only; it does not verify Android app execution.
- **Source contract/APK archive tests:** run `44007714483` source-contract job completed successfully. Swift parser and bridge-header jobs were still queued at the last check.
- **Husk static iOS runtime build:** an earlier run (`44006707186`) failed on a C declaration/definition mismatch for `infinity_husk_launch_engine` (enum versus `int`). The public ABI and implementation have since been aligned. Rerun `44007676547` was queued at the last check; **no successful native static-library build is claimed yet**.
- **Strata SwiftUI framework integration:** an earlier Xcode 16.4 run failed because that SDK did not contain the existing project's newer `UIGlassEffect` API. The workflow was moved to Xcode 27.2. A later Xcode 27.2 attempt exposed an index-store path issue; the isolated CI command now disables the compiler index store. Latest reruns `44007676586` and `44007696461` were queued at the last check. **No successful full SwiftUI framework build is claimed yet**.
- **ANGLE iOS arm64:** run `44006769136` was still in progress at the last check. No validated ANGLE artifact is claimed.
- **Android runtime data:** the asset builder has not been run because no matching Lineage image was supplied to this batch. No Android runtime-data ZIP is available yet.
- **Real APK execution:** 2048 and Hill Climb Racing have not been launched. Real APK compatibility remains unverified (0% test coverage).
- **IPA:** no IPA was built, signed, or exported. The existing IPA builder was not run.
- **SideStore:** SideStore source, target, configuration, entitlements, signing, installation, refresh, and packaging paths remain protected and untouched.

### Progress estimate and next work

- Overall implementation progress is approximately **20%**. This is a rough engineering estimate for source/runtime integration, not a compatibility percentage.
- Verified Java DEX generation is complete. Native static-library compilation, full SwiftUI integration compilation, ANGLE packaging, Android system asset generation, and real-device execution remain gates.
- Next: finish the native static build and full SwiftUI framework compile from actual CI diagnostics; validate the ANGLE artifact; prepare the Android runtime-data bundle from a matching image; embed/code-sign ANGLE through an approved app build path without changing SideStore; then install and test 2048 on-device before attempting Hill Climb Racing.

## Runtime gating and lifecycle follow-up — 2026-11-17

- Split-APK requirements are now recorded in the persistent APK index. Older index entries decode with a safe false default for the new field. The Launch screen blocks apps declaring required splits because only a single base APK is installed; it explains the limitation instead of attempting a known-incomplete launch.
- Shared Android system assets are now a separate native-runtime preparation step, required before every engine launch. Java additionally requires the Dalvik/DEX runtime. The launch view validates these assets before calling the C bridge.
- Fixed the Android super-partition name parser to split GPT names on an actual NUL byte, and added a regression assertion for that parsing detail.
- Native shutdown now always reaches the C adapter even if SwiftUI has not yet received its first state poll; the C stop operation is idempotent when no session exists.
- Latest source-contract/APK archive tests passed before these final follow-up commits. New split-store and native-preparation assertions have been added; their Actions runs are queued. Current Swift-to-C checks, full Strata framework compile, and static runtime compile are still pending. ANGLE's iOS build remains in progress.

## Graphics runtime signing gate — 2026-11-17

- Runtime readiness now checks for ANGLE and (for Unreal) MoltenVK inside the app's signed Frameworks directory. A loose dylib copied into Documents/Files is deliberately not accepted because iOS code-signing/dyld rules can reject it.
- Runtime Manager reports whether ANGLE is embedded and signed; Java/native runtime data can be imported separately from an extracted folder.
- The ANGLE workflow only builds and uploads a temporary iOS arm64 artifact. It does not yet embed ANGLE into the app target or modify the existing IPA builder. Until a signed app build contains ANGLE, all APK launch paths remain correctly blocked.
- The same limitation applies to MoltenVK for Unreal. No graphics backend launch has been verified.
