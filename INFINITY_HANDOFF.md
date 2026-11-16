# INFINITY Handoff

Last updated: 2026-11-16

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
