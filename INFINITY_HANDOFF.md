- The GitHub Actions repository secrets `CODEMAGIC_API_TOKEN` and `INFINITY_LOGS_GITHUB_TOKEN` are no longer required by the removed bootstrap workflow. The available GitHub connection cannot delete repository Actions secrets, so the repository owner must remove those two secret entries manually in Settings → Secrets and variables → Actions. Do not delete any unrelated secrets.
- No Codemagic build or IPA packaging was started. The first real Codemagic run must verify that logs publish successfully to the `codemagic-logs` branch; this has not yet been tested.


## Codemagic empty-log capture repair — 2026-11-18

- Replaced the build wrapper's shell `tee`/pipeline capture with a Python byte-streaming subprocess. Build stdout and stderr are copied directly to the log file and Codemagic console, flushed before publication, and the original build exit code is preserved.
- The wrapper now records build identity and a terminal exit-code marker in `build.log`. Xcode version detection no longer runs before the build and cannot silently short-circuit log capture.
- Submodule synchronization/update output is captured independently in `submodules.log`, streamed to the Codemagic console, and included in the artifact set and GitHub snapshot.
- The publisher refuses to replace the previous snapshot when `build.log` is missing or empty. Metadata now records byte counts, line counts, and SHA-256 checksums for each sanitized log. Empty archive output is allowed only for failures occurring before archive starts and is explicitly reported as zero bytes.
- The dedicated `codemagic-logs` snapshot now contains `build.log`, `xcodebuild-archive.log`, `submodules.log`, and `metadata.json`. Credentials continue to be redacted before public publication.
- Source changes committed on `main`; no Codemagic run was started here, no IPA was built/exported, and the new capture path still requires the next real Codemagic run to verify end-to-end receipt. The previous empty snapshot is not represented as repaired retroactively.

## Codemagic pre-build repair — 2026-11-18

- Latest full mirrored build log for build `6afdd47fd133a39c4a12c4c5` contains three diagnostics at one source location in `StrataInstalledAppPicker.reload()`. The Objective-C declaration in `LiveContainerSwiftUI/Utilities/LCUtils.h` is `+ (NSDictionary *)strataPhoneApplications;`; because the header does not declare `NS_ASSUME_NONNULL`, Swift imports the return as an optional `[AnyHashable: Any]?`.
- Updated the detached task to extract the Objective-C optional dictionary inside the background closure and return only `[[String: String]]` across the task boundary. The closure has an explicit return type, preventing `Void` inference and avoiding non-Sendable `NSDictionary`/`AnyHashable` values crossing concurrency boundaries. The exact equivalent was type-checked with Swift 6.2 on Linux; Apple Objective-C importer/Xcode archive validation is still required.
- Fixed the raw archive-log path handoff: `run_codemagic_build.sh` now exports `INFINITY_ARCHIVE_LOG`, which is the variable consumed by `build_ipa.sh`. Previously the wrapper exported only `INFINITY_CODEMAGIC_ARCHIVE_LOG` for the publisher, so the publisher received an empty archive log while xcodebuild wrote elsewhere.
- Log snapshot behavior remains unchanged: the publisher creates a new root commit and force-updates `codemagic-logs` with the same fixed `latest/` paths. The previous snapshot is replaced rather than accumulated on that branch.
- No Codemagic build was triggered here. No IPA was built, signed, or exported. The fix still needs Xcode 26.2 archive validation; do not claim success until the user starts the next build and its new logs are inspected.

## Single-download Codemagic artifact packaging — 2026-11-18

- Updated the Codemagic backup workflow to publish one file, `INFINITY-Complete-Artifacts.zip`, instead of separate IPA/archive/log artifacts.
- Added `scripts/package_codemagic_artifacts.sh`. After the canonical build succeeds, it verifies both IPA exports and `archive.xcarchive`, then packages them together with available build, archive, submodule, and metadata logs plus a `BUILD-INFO.txt` manifest.
- The previous third ZIP's diagnostic/archive contents are represented inside the single package; no separate nested copy of the same archive ZIP is added. The IPAs remain byte-for-byte copies of the existing exported files.
- Packaging validates the resulting ZIP with `unzip -t`. If either IPA or the Xcode archive is missing, packaging fails rather than publishing an incomplete ZIP.
- Codemagic now declares only the combined ZIP as an artifact. The GitHub log mirror remains unchanged.
- This is a configuration/script change only. No Codemagic run was started, and no IPA was built, signed, or exported to validate the new package yet.


## Shared IPA / APK file-import entry — 2026-11-18

- Audited the original `huzaifahshahid71-ops/Strata` `main` branch: `LiveContainerSwiftUI/Views/AppList/LCAppListView.swift` exposes an IPA picker with `.ipa` and `.tipa` only; its install path calls `installIpaFile`. No Android APK import/runtime pipeline was found in that original Strata tree.
- INFINITY already contained APK ZIP inspection, manifest parsing, persistent storage under `Strata3/AndroidApps`, and the APK launch/detail surface. The existing IPA picker was not connected to those components.
- Updated the existing `+` menu item to read “Import IPA / APK” and expanded its existing document picker to accept `.apk` alongside `.ipa` / `.tipa`. No second file-import button was added.
- APK selections now go through `INFINITYAPKStore.install(from:)`, which copies into staging, inspects the manifest/DEX content, validates the package name, and commits the APK into persistent storage. IPA/TIPA selections continue through the original IPA installer unchanged.
- Added an Android APK Library entry to the same `+` menu. It lists persisted APK imports, opens the existing app detail/launch view, and supports removal. File-URL open/share imports also route APK files into the APK store.
- Added Python contract tests for the shared picker route and persisted APK library. These tests are committed but have not yet been run by GitHub Actions; no Xcode/macOS compile or IPA build was started. Runtime execution compatibility remains unverified.


## Android package import expansion and Runtime Manager repair — 2026-11-18

- Expanded the existing shared launcher import picker to accept APK, XAPK, APKS and APKM while preserving the existing IPA/TIPA install route. Android selections route to the INFINITY APK store; IPA/TIPA selections continue through the original Strata installer.
- Added ZIP-entry streaming extraction for embedded APKs. XAPK/APKS/APKM containers are inspected, a unique base APK is required, and accompanying split APKs are retained in the installed package directory. The extraction path validates compression method, bounds, decompressed size and CRC, and removes incomplete output on failure.
- Extended the installed-app record with a backward-compatible split APK count. The detail screen reports stored splits and continues to block launch because the current Husk launch adapter still accepts only a base APK; split loading is not claimed as implemented.
- Repaired the separate Runtime Manager importer: it now advertises the four Android package extensions, validates the selected extension, shows an in-progress state and a success message, refreshes the installed list, and surfaces picker/import errors rather than silently leaving the user without feedback.
- Added source contract coverage for archive extraction and the Runtime Manager import route.
- Recent commits: `d68484b9`, `e7b7e29c`, `10301ebe`, `084d6f27`, `664e6769`, `9326a8c3`, `84ca4a11`, `ab894921`.
- Verification is pending the GitHub Actions run triggered by these `main` pushes. No IPA build, signing, export, or workflow cancellation was performed. APK import/storage is not evidence that APK execution compatibility is verified.


## Framework build toolchain alignment — 2026-11-19

- Investigated framework workflow run `44433850998`. Package resolution succeeded; the framework compile failed inside the transitive `swift-srp` → `big-num` dependency with a missing generated `CBigNumBoringSSL.modulemap`, followed by `no such module 'BigNum'`.
- Confirmed this failure was from the separate framework-only workflow running Xcode 27.2 on the `xcode-27` runner. The canonical IPA workflow and `scripts/build_ipa.sh` are pinned to Xcode 26.2.
- Aligned the framework-only workflow to `macos-15` + Xcode 26.2, matching the canonical IPA builder. This is a toolchain-consistency correction; it does not claim the dependency issue is fixed until the new framework job completes successfully.
- APK import source remains in place: the shared picker routes APK/XAPK/APKS/APKM to `INFINITYAPKStore.install(from:)`, while IPA/TIPA retains the original installer. The Runtime Manager importer also supports the four Android formats and reports success/errors.
- The latest native test workflow on the prior commit passed all 3 jobs, including APK source-contract/archive tests. This is source-level evidence only, not device picker validation.
- No APK importer code was changed in this toolchain-only correction. The user will perform the on-device import test after receiving a fresh IPA.
- No IPA build, signing, or export was started. The canonical `build.yml` is manual-dispatch only, and the available GitHub connection cannot dispatch it. User must start that workflow manually after the framework validation; do not enable automatic macOS IPA builds or change the canonical trigger.


## SwiftASN1 compiler search-path repair attempt — 2026-11-19

- Framework validation run `44435588398` failed after package resolution and Xcode 26.2 selection. The exact compiler diagnostic is `CryptoExtras/EC/Curve25519+PEM.swift:16:8: error: no such module 'SwiftASN1'`.
- The build log confirms SwiftPM resolved and scheduled the `SwiftASN1` target and generated its module map under the swift-asn1 checkout. However, the failing `CryptoExtras` Swift compiler invocation did not receive the swift-asn1 product build directory as a Swift `-I` search path. This is a module visibility/search-path issue in the framework build invocation, not an APK importer source diagnostic.
- Updated the framework validation step to locate the resolved `swift-asn1/build/Debug-iphoneos` directory after package resolution and pass it through Xcode's `SWIFT_INCLUDE_PATHS` build setting. The step fails with an explicit message if the expected directory is absent.
- This is a targeted build-configuration workaround; it is not yet verified until the automatically triggered framework validation completes. Do not claim the framework or IPA build is successful yet.
- APK import UI/store source remains unchanged. No device import test or IPA artifact exists from run `44435588398`.


## Codemagic three-ZIP artifact split — 2026-11-19

- Replaced the previous single-output packaging behavior with three distinct ZIP outputs:
  - `INFINITY-LiveContainer-Only.zip`: contains only `LiveContainer.ipa` at the ZIP root.
  - `INFINITY-LiveContainer-SideStore.zip`: contains only `LiveContainer+SideStore.ipa` at the ZIP root.
  - `INFINITY-Complete-Artifacts.zip`: preserves the existing full bundle with both IPA files, `archive.xcarchive`, available build/archive/submodule logs, metadata, and `BUILD-INFO.txt`.
- Updated `codemagic.yaml` to publish all three ZIP files as separate Codemagic artifacts. The GitHub log mirror behavior is unchanged.
- The packaging script validates each ZIP with `unzip -t` and fails if either IPA or the Xcode archive is missing.
- Changes committed on `main`: packaging script commit `d2acc89`; Codemagic artifact declaration commit `e1c3aa0`; handoff update follows.
- This is source/configuration verification only. No Codemagic build was started; the three ZIP outputs have not yet been produced by a real run.


## 2026-11-19 — Android APK launch action visibility
- Fixed the APK detail screen so the **Launch** navigation action is always visible; it was previously hidden whenever engine/runtime readiness checks failed, making it impossible for users to enter the launch diagnostics screen.
- Runtime preparation now reports a dedicated, explicit error when an imported package requires split APK loading. Split packages remain blocked from unsafe base-APK-only execution.
- Updated host-side source-contract tests to assert the always-visible Launch action and the split-package safety gate.
- Source changes committed on `main`; no IPA build or device execution was started. The Launch button visibility is source-verified, not yet verified in an installed build. Subway Surfers compatibility remains unverified until a real device launch test.


## 2026-11-19 — Advanced Husk session logging and launch diagnostics

- Added an INFINITY-integrated adaptation of Husk's upstream `host-reference/HuskLog.swift`, retaining the GPL-2.0-or-later notice and recording the upstream source in the file header.
- The native logger starts immediately before the first APK runtime preparation call. It redirects process stdout/stderr into durable native output files, mirrors messages into the in-app ring buffer and unified log, retains previous-run logs, and installs the upstream fatal-signal / uncaught-exception diagnostic handlers while leaving the JIT trap signals untouched.
- Added a per-launch structured session log under `Documents/INFINITY/SessionLogs/<package>/`. It records app/build/device metadata, launch request, split-package gate, engine selection, APK validation, data/runtime readiness, JIT-less preparation, Husk launch acceptance, runtime state transitions, periodic FPS/mean/max frame time, pause/resume, errors, and shutdown outcome.
- The launch surface now exposes a live Session Log viewer. It displays structured launch events and the latest native Husk output, and provides separate share/export actions for the session event log, `husk.log`, and `husk-native.log`.
- Removed the previous deletion of the single `native-run.log`; each attempt now receives a unique diagnostic filename so earlier evidence is not overwritten.
- Kept the APK detail screen's always-visible Launch action. Unsupported engine detection now reports a specific error; split APK execution remains safely blocked until split loading is implemented.
- Added source-contract tests for native stderr capture, crash-log wiring, persistent session events, performance/error logging, log export, and unique native diagnostic files.
- Verification status: source changes are committed on `main`; GitHub Actions validation is pending. No macOS build, IPA packaging, signing, or on-device APK launch was started. The native capture and UI are not claimed as build- or device-verified until CI and a real device test pass.
- Limitation to preserve in reports: a hard OS jetsam kill or power loss may prevent a clean session-end event; the previous-run native log rotation is intended to preserve the available crash evidence. Raw upstream diagnostics are captured through stdout/stderr, while structured INFINITY lifecycle/performance events are recorded separately.


## 2026-11-19 — Session logging validation corrections

- GitHub validation exposed two integration issues before any IPA build: the older JIT-less contract test still expected the previous fixed native log filename, and the bridge smoke test was compiling the runtime facade against the macOS SDK without UIKit.
- Corrected the regression contract to require unique per-attempt diagnostic filenames and preserve prior logs.
- Moved the SwiftUI Session Log viewer into the iOS launch UI file; kept the runtime facade Foundation/Combine/QuartzCore-only for the bridge smoke check, and replaced UIKit-only host metadata with ProcessInfo metadata.
- Corrected the logger's newline string literals so the source is valid Swift.
- Updated workflow scheduling to keep push-triggered source tests on Linux and reserve macOS Swift checks / framework compilation for manual dispatch, avoiding repeated macOS runner use on each source commit.
- Added the new native logger source to the manual framework build's path documentation and corrected source-contract assertions to match the separated UI layer.
- Validation of these corrections is pending on the next GitHub push run. Older queued/in-progress runs are being left untouched. No IPA packaging, signing, Codemagic build, or device launch was started.


### Validation update — 2026-11-19
- GitHub Actions run [44445041169](https://github.com/strideproject77-lgtm/Infinity-/actions/runs/44445041169) passed the Linux source-contract and APK archive suite: **52 tests passed**; runtime build-script shell checks and audit-script syntax validation also completed successfully.
- The automatic push workflow now correctly skips macOS-only bridge/parser checks; those remain available by manual dispatch.
- A previously started macOS framework job from the earlier push is still resolving Xcode package dependencies. It has not yet compiled the updated SwiftUI framework, so full iOS compilation is still pending. It is being left running rather than cancelled.
- This pass validates source contracts only. It does not prove the native logger compiles in the iOS target, does not prove APK execution, and is not an IPA build.


## 2026-11-19 — SwiftASN1 framework workflow path correction

- Inspected failed macOS framework run `44444921655`: SwiftPM successfully resolved and checked out SwiftASN1 1.7.3 and the other package dependencies. The workflow then failed before invoking the compiler because it incorrectly searched for a nonstandard `SourcePackages/checkouts/swift-asn1/build/Debug-iphoneos` directory immediately after package resolution.
- Removed that invalid pre-build directory assertion and the manually injected `SWIFT_INCLUDE_PATHS` override. Xcode now owns package module compilation and search-path propagation through the normal SwiftPM integration.
- Pinned a dedicated runner-temporary DerivedData path and passed the same path to both package resolution and the framework build, so package checkout/build products share one deterministic location.
- This corrects the confirmed workflow-level failure only. The next manually dispatched macOS framework compile must still reveal any actual Swift/Objective-C integration errors. No IPA packaging, signing, Codemagic build, or device execution was started.


## 2026-11-19 — Framework workflow follow-up: resolver requires scheme

- Manual run `44446024968` confirmed the previous SwiftASN1 path check was removed, but Xcode exited before package resolution because `-resolvePackageDependencies` was passed `-derivedDataPath` without a scheme.
- Added the canonical `LiveContainer` scheme to the package-resolution invocation. The same DerivedData path remains shared with the subsequent framework build.
- The previous run did not reach compilation; the next manual dispatch is still required to validate package resolution and actual Swift/Objective-C compilation. No IPA packaging or signing was run.


## 2026-11-19 — Framework build invocation correction

- Inspected both failed manual runs `44446236878` and `44446222524`. Package resolution completed successfully, but the framework build command failed before compilation because Xcode rejects `-derivedDataPath` with a target-only invocation unless a scheme/test product is also selected.
- Kept the intended target-only build (so this check does not silently compile/package the full LiveContainer app) and removed `-derivedDataPath` from that command. The previous workaround had added a scheme only to package resolution; adding a scheme to the target build could change the selected build graph, so it was not used as a blind fix.
- Made the SwiftPM checkout location explicit with one runner-temporary `-clonedSourcePackagesDirPath` shared by dependency resolution and framework compilation. This preserves a consistent package cache without requiring a DerivedData path on the target build.
- Added strict shell handling to dependency resolution and retained `pipefail` for the compiler log pipeline. Xcode 26.2 remains pinned; macOS framework validation remains manual-dispatch only; signing and IPA packaging remain disabled.
- This is a workflow configuration correction, not proof of compilation. The next manual dispatch must validate the actual Swift/Objective-C target build and expose any source-level diagnostics. Linux push tests should run automatically after this commit. No Codemagic build, IPA export, signing, or device execution was started.


## 2026-11-19 — Framework workflow regression tests passed

- Added `tests/test_strata_framework_workflow.py` to guard the target-only Xcode invocation, shared SwiftPM checkout directory, pinned Xcode version, manual-only scheduling, and no-sign/no-IPA-package constraints.
- Added the framework workflow and its contract test to the Linux push-test path filters so future workflow edits cannot bypass the source regression suite.
- GitHub Actions run [44496687265](https://github.com/strideproject77-lgtm/Infinity-/actions/runs/44496687265) completed successfully on `main`: **56 Python tests passed**, including all four new framework workflow contract tests; runtime shell checks and audit-script syntax check also passed.
- This is verified Linux/source validation only. It does not execute Xcode or prove iOS framework compilation. The macOS framework workflow is intentionally manual-dispatch only; no IPA build, signing, export, Codemagic build, or device execution was started.


## 2026-11-19 — Android apps shown in the existing Strata app-management list

- Added persisted INFINITY APK entries directly beneath the existing IPA rows in Strata's **Manage apps** list. Android entries use the same search field, display name/package/engine metadata, and open the existing APK detail/Launch screen.
- The Android list refreshes on app-list appearance and immediately after a successful APK/XAPK/APKS/APKM import. The existing Android APK Library sheet remains available as a secondary management route; IPA installation behavior is unchanged.
- This deliberately does not fabricate an `LCAppModel` or pretend an Android package is a native iOS app. The current Strata LiveBoard home cards still use the iOS `LCAppModel` pipeline; this change puts APKs alongside IPA entries in the app-management list, where they can be selected for INFINITY execution.
- Added a regression contract for the inline Android rows and refresh path. Linux CI must pass before treating the source change as validated; Xcode compilation and on-device UI remain unverified.
- Execution blocker confirmed during this audit: XAPK/APKS/APKM split files are extracted and persisted, but `INFINITYAPKLaunchView` still rejects `requiresSplits` because the current INFINITY-to-Husk launch ABI accepts only one base-APK path. Passing only the base APK would silently omit required resources/native libraries, so that guard remains until multi-split loading is implemented in the Husk loader. The exact user-visible XAPK error still needs the current import/launch log to distinguish archive import failure from split-execution rejection.
- No Codemagic build, IPA packaging, signing, export, or workflow dispatch was started.


# Antigravity implementation handover — 2026-11-19

## Mission
Complete the real INFINITY + Strata + Husk integration. Treat "100% integrated" as the engineering target, not a status claim: report completion only for code paths that are actually implemented and evidenced. The goal is real execution of Android APKs on the iPhone through the integrated Husk runtime, not a mock screen, static-analysis-only result, Android VM, or fake compatibility layer.

## Absolute operating constraints
1. Work only in this repository and only on branch `main`. Fetch/pull the latest `main` before editing. Do not create/switch branches, force-push, reset, or discard existing user changes.
2. **Never inspect for the purpose of changing, and never modify, SideStore systems.** Do not change SideStore source, targets, schemes, bundle identifiers, entitlements, signing, installation, refresh, provisioning, workflows, configuration, or files. Do not rename/remove SideStore-related app variants or artifacts. Preserve all SideStore functionality exactly.
3. Preserve Strata and the existing LiveContainer hosting/IPA management architecture. INFINITY APKs must be integrated into Strata's existing app-management/launcher experience; do not replace Strata with a separate shell or create fake `LCAppModel` objects for APKs.
4. **Implementation only. Do not run tests, test suites, builds, workflow jobs, workflow dispatches, workflow reruns, Codemagic, Xcode, IPA packaging, signing, or export.** Do not edit GitHub Actions/workflow files or build configuration merely to trigger validation. No test command should be invoked. Leave validation for the owner to authorize later.
5. Do not cancel, restart, or rerun any existing workflow. Do not claim tests/builds passed. If a push naturally triggers repository automation, do not interact with that run.
6. No IPA build, signing, packaging, export, or installation without the owner's separate explicit permission.
7. Keep upstream Husk/Strata license obligations and notices intact. Preserve attribution and GPL-2.0-or-later notices for reused Husk code; do not strip license files or notices.
8. Do not implement placeholder APIs, fake success states, fake FPS, simulated Android screens, or compatibility percentages unsupported by real device evidence. Never silently fall back to a built-in demo when APK launch fails.
9. Make substantial, coherent implementation batches. After each batch, update this file with exact files changed, actual behavior implemented, unresolved blockers, and validation status (clearly state "not run" because this handover prohibits tests).

## Verified repository baseline at handover
- Repository: `strideproject77-lgtm/Infinity-`; branch: `main`.
- Starting commit: `bbb4e08f14de65e4c68007226cb90c40ce85c232`.
- The latest source-only Linux CI run for that commit is `44503237554` and completed successfully; this is historical baseline evidence only, not evidence for any Antigravity changes.
- APK/XAPK/APKS/APKM import/storage exists in `LiveContainerSwiftUI/Strata3/INFINITYAPKStore.swift`.
- The IPA picker and Runtime Manager already route APK-family formats through the Android import path.
- Imported Android apps are now shown inline beneath IPA entries in Strata's Manage apps list, with shared search, refresh, and existing APK detail navigation. This does not yet make Android packages native iOS apps or add them to every LiveBoard card pipeline.
- APK detail has an always-visible Launch action. Session event logging, native Husk stdout/stderr capture, log viewer, and export surfaces have been added. Their source exists, but current iOS compilation and on-device behavior are not verified.
- The current launch ABI accepts one base APK path. `INFINITYAPKLaunchView` deliberately blocks `requiresSplits`; do not bypass this by launching only the base APK. Correct split APK loading is a key implementation task.
- The previous 2048 log reported opcode `0x60` and unresolved static field `R$layout;->activity_main:I`. The checked-in DEX interpreter already appears to implement the `sget`/`sput` opcode family, so trace the exact runtime/interpreter path and field-resolution behavior before changing opcode tables or duplicating existing support.
- Java runtime build assets include both `husk-framework.dex` and `husk-framework-core.dex`; verify actual asset generation/consumption paths rather than assuming either is missing.
- A manual Strata framework workflow has had prior invocation/dependency failures. Do not spend this implementation-only task editing or dispatching workflows; source-level iOS compilation remains unverified.
- Do not infer runtime readiness from the presence of source files. Trace the complete APK-to-Husk call chain and distinguish implemented, wired, and actually executed components.

## Required implementation sequence

### Phase 1 — End-to-end architecture and call-chain audit
- Map the complete path: file picker/import → archive extraction and package metadata → persisted Android app record → Strata list/detail → launch coordinator → runtime asset preparation → Swift/Objective-C bridge → C bridge → Husk loader/interpreter → Android app lifecycle → graphics/input/audio → shutdown/logging.
- Identify duplicate or dead implementations, ABI mismatches, missing symbols, mismatched paths, lifecycle ownership errors, memory ownership bugs, and target membership/resource-bundle omissions.
- Reuse existing Husk and Stride code where it is correct; do not create a second parallel runtime.
- Record a concise dependency graph and a per-component status matrix in this handoff.

### Phase 2 — Native bridge and real launch path
- Make the Swift/Objective-C++/C interfaces agree on exact types, ownership, threading, error propagation, callbacks, and lifecycle.
- Ensure the Launch action reaches the real Husk APK execution entry point. Runtime preparation alone, APK parsing, metadata extraction, or a successful return from a stub is not execution.
- Wire actual launch, pause/resume, stop, process cleanup, and error callbacks. Prevent stale sessions, duplicate launches, file-descriptor leaks, and unsafe cross-thread UI updates.
- Verify all required C sources, headers, resources, and generated runtime assets are included in the correct iOS target/build phases without altering SideStore targets or signing.
- Keep JIT optional and capability-detected. The no-JIT path must report its actual limitations; never claim JIT is active unless it is.

### Phase 3 — APK formats and package loading
- Preserve single APK support and implement correct multi-APK package loading for XAPK/APKS/APKM, including base APK, configuration splits, ABI splits, resource splits, package metadata, and native libraries.
- Pass the complete package/split set through a well-defined Husk loader interface. Validate package identity/version consistency and reject malformed or incompatible sets with actionable errors.
- Do not extract or execute arbitrary archive paths; defend against path traversal, duplicate entries, oversized expansion, and malformed manifests.
- Keep app icons, names, package IDs, version metadata, and persisted install state stable across relaunches and app-list refreshes.

### Phase 4 — Core Android execution compatibility
Implement and wire real support in dependency order, auditing existing code before adding anything:
1. ARM64 ELF loading first; ARM32 only where the iOS host/runtime architecture permits and the upstream runtime supports it. Include mapping, segments, relocations, symbol resolution, TLS/constructors as required, and clean failure diagnostics.
2. Bionic compatibility: required libc/libm/libdl/pthread/syscall behavior, errno, file and memory APIs, dynamic linker interactions, and Android-specific ABI shims. Do not pretend iOS libc is identical to Bionic.
3. JNI: VM lifecycle, JNIEnv/thread attachment, class/method/field lookup, references, arrays/strings, native registration, exception propagation, and native library loading.
4. DEX/ART execution: parser/verifier requirements, class loading/linking/initialization, method dispatch, fields/static fields, exceptions, object model, GC/memory safety, and Android framework DEX integration. Trace the prior `0x60` and `R$layout` failures to their real source.
5. Android framework/API compatibility: prioritize APIs exercised by 2048, then expand by observed missing API diagnostics. Implement Activity/Context, resources/assets, PackageManager, intents, views, storage, preferences, display/orientation, input, lifecycle, and threading as required by real app traces.
6. Native graphics/audio/input: connect the actual rendering backend and surface lifecycle, touch/controller input, orientation, audio output, frame pacing, and background/foreground transitions. Keep optional backends modular; QEMU is optional and must not be introduced unless a demonstrated compatibility gap requires it.
7. Memory/performance: correct allocation accounting, pressure handling, leak cleanup, bounded caches, safe shutdown, and meaningful frame-time/FPS metrics. Never fabricate performance numbers.

### Phase 5 — Strata user experience
- Keep Android apps alongside IPA entries in the existing Strata management experience, searchable and refreshable.
- Make APK details, launch state, runtime readiness, errors, and logs understandable without hiding the Launch action.
- Preserve original APK icon artwork/background; do not destructively strip icon backgrounds.
- Maintain the existing dark visual direction and responsive controls, but prioritize launch correctness over cosmetic redesign.
- Keep diagnostic session logs useful: package/build/device metadata, exact runtime stage, native errors, missing APIs/symbols, performance samples, stop/failure outcome, and export. Do not claim OS-kill logs are guaranteed.

### Phase 6 — Compatibility-first integration
- First target: the real 2048 APK. Trace each blocker and implement the missing behavior rather than special-casing the package or faking its screen.
- Next target: Hill Climb Racing. Focus on graphics/resource correctness, native libraries, memory pressure, and sustained runtime stability.
- Then evaluate other real APKs (for example Subway Surfers, Dr. Driving, and Beach Buggy) based on measured dependencies and diagnostics.
- Keep a compatibility matrix with columns: APK/version/ABI, import result, package/split loading, runtime entry reached, first frame, input, audio, orientation, sustained run, crash/error, device/OS, evidence. Mark every untested cell "Not tested"; do not invent percentages.
- Do not optimize only for one APK in a way that breaks general Android compatibility.

## Completion definition
Do not mark Husk "100% integrated" until all of the following are true:
- Real APK import and persistence work for supported formats, including complete split-package loading.
- Strata app list/detail routes to a real Husk execution entry point.
- Swift/ObjC/C ABI is wired end-to-end and the actual runtime starts and stops cleanly.
- Required runtime assets are generated, bundled, located, and loaded correctly.
- ARM64 ELF, JNI, DEX/ART, Bionic, and the Android APIs needed by the tested apps are genuinely implemented and connected, not just present as source files.
- Graphics, touch/input, audio, orientation, app lifecycle, memory handling, and diagnostics operate in a real app session.
- 2048 is tested on a real device first; then Hill Climb Racing; then additional APKs. These tests are explicitly deferred until the owner authorizes them.
- All license/attribution obligations are preserved and SideStore remains untouched.
Until then, report exact completed components and blockers. Never convert "implementation written" into "build verified" or "game compatible."

## Required final handoff report from Antigravity
At the end of implementation, update this file and report:
- Starting and ending commit hashes.
- Files/modules changed and why.
- Runtime call chain before/after.
- Components genuinely implemented vs pre-existing vs newly wired vs still blocked.
- Split APK/XAPK status.
- Remaining known limitations and blockers.
- Tests/builds/workflows: explicitly "not run, per instruction".
- Device compatibility: explicitly "not verified; real-device tests deferred".
- Confirmation that SideStore source/configuration/targets/signing/install/refresh systems were not modified.
