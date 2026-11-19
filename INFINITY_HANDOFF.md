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


## 2026-11-19 — Independent Husk integration audit (after Antigravity handover)

Audit baseline: `927a2bf4efd57462d31195c8511122b80b60ec48` on `main`. No Antigravity implementation commit is present on the remote branch after the handover-plan commit; uncommitted files on the user's PC are not visible to this repository audit.

### Verified source call chain

`Strata app-list import → INFINITYAPKStore.install → Documents/Strata3/AndroidApps/<package>/base.apk → installed Android-app row/detail → INFINITYAPKLaunchView → INFINITYHuskRuntime.prepareNative/prepareJava → infinity_husk_launch_engine → engine-specific Husk launch function → Husk asynchronous launch thread → Java tl_javaapp_start or the selected native backend`.

The native dispatcher is not a placeholder: it validates APK/data/ANGLE paths, reserves the single runtime session atomically, checks Java runtime readiness for Java apps, and dispatches to the selected upstream Husk entry point. The upstream Java engine path boots the prepared runtime and calls `tl_javaapp_start`; the shared Husk state/frame/pause functions route Java lifecycle and input to the Java app implementation.

### Component status at this audit baseline

| Component | Source status | Evidence / limitation |
|---|---|---|
| APK import and persistence | Implemented in source | APK path validates manifest/DEX and stores a package record plus private data directory |
| XAPK/APKS/APKM extraction | Import/storage implemented | Base and split APK files are preserved; split identity/version validation and execution loading are not complete |
| Strata app-list integration | Implemented in source | Android entries appear in the same Manage Apps list and share its search/refresh behavior; they are not native iOS app models |
| Husk native launch dispatch | Wired in source | Swift calls the INFINITY C dispatcher, which calls real Husk engine launch functions |
| Java/ART startup | Wired in source | Runtime assets are checked, `husk_java_set_runtime` is configured, and upstream `tl_javaapp_start` is called |
| ARM64 ELF loader | Present in vendored runtime | Full ABI/relocation coverage and app-level execution are not verified by source presence alone |
| Bionic compatibility | Present in vendored runtime | Required libc/Bionic behavior for target apps remains to be established from runtime traces |
| JNI and DEX | Present in vendored runtime | DEX `sget` opcodes 0x60–0x66 and `sput` 0x67–0x6d exist in the current interpreter; the older 0x60 log is not explained by current source and may be from a stale/different binary or path |
| Android framework APIs | Partially implemented in Husk | Coverage for the 2048 APK's exact missing APIs and the previous `R$layout` static-field report is not yet verified |
| ANGLE / Metal surface | Wired in source | Launch requires the embedded readable ANGLE framework and a valid CAMetalLayer; actual device rendering is unverified |
| Touch and lifecycle | Wired in source | Metal view sends multi-touch; shared Husk dispatcher routes touch and pause/resume by engine |
| Java host callbacks | Not wired in the inspected Swift host | C API exposes keyboard, clipboard, share, orientation and document-picker callbacks, but the inspected Strata Swift runtime does not register the host callbacks yet |
| Audio and controllers | Upstream entry points exist | End-to-end host input/audio behavior is not verified in an installed build |
| Session diagnostics | Implemented in source | Structured session events and native stdout/stderr capture are present; actual crash/session evidence still needs device testing |
| Split-package execution | Blocked | Launch explicitly rejects packages requiring splits; do not pass only base.apk to Husk |
| QEMU | Optional / not required for current native path | Keep out of the critical path unless a measured compatibility gap requires it |

### Priority implementation order from this audit

1. Wire the missing Java host callbacks with safe main-thread UI ownership and explicit callback lifetime management.
2. Trace the 2048 APK's previous `R$layout` field failure against the exact current DEX class/field resolver and runtime logs; do not re-add opcodes already present.
3. Implement split-package loading only through an upstream-supported package-loading contract, validating package/version/ABI and preserving safe cleanup. Until then, keep split execution blocked.
4. Add source-level regression tests for each new bridge contract and update this handoff after every implementation batch.

### Verification boundary

This audit inspected source and upstream call paths only. No GitHub Actions run, Xcode build, Codemagic build, IPA packaging, signing, export, or real-device APK test was started. 2048 and Hill Climb Racing compatibility remain **not verified**. No SideStore source, target, signing, installation, or refresh system was modified.


## 2026-11-19 — INFINITY 1.0 product branding

- Rebranded the installed app display name, bundle name, About screen, Settings header/version label, About navigation labels and repository-facing README to **INFINITY 1.0**.
- Set the main app target's display name and marketing version to INFINITY / 1.0 in both Debug and Release build configurations. Updated the packaged short version/build version and the app's custom version metadata to 1.0.
- Updated the About screen's project/release/issues links to the current `strideproject77-lgtm/Infinity-` repository.
- Preserved upstream LiveContainer, SideStore, Husk and other third-party credits and all license/notice files. No upstream license or copyright attribution was removed.
- Preserved the existing bundle identifier, executable/target names, app groups, notification names, persisted preference keys and `Strata3` on-device storage paths. These are compatibility identifiers/data locations, not visible product branding; renaming them in a branding-only change could break app updates, SideStore integration or existing user data.
- No workflows, tests, Xcode builds, IPA builds, signing or exports were started. This commit is a source/configuration branding change only; compilation and packaged Info.plist output still require the next authorized build.


## 2026-11-19 — Husk SDL split-package launch integration (implementation only)

- Added a narrow INFINITY C bridge for queueing and clearing additional APK paths before launch. It uses Husk's existing `tl_ld_queue_split` and `tl_ld_reset_session` APIs directly; no duplicate split loader or new upstream package queue was introduced.
- Split paths are queued before the base APK is opened. Husk's SDL startup then calls `tl_ld_add_apk(base.apk)`, whose existing loader adds the queued splits immediately after the base. This preserves the loader's documented base-first ordering and makes split native libraries/resources available through its existing package set.
- The bridge validates readable paths, path length, a maximum of 15 split APKs, idle runtime state and backend compatibility. Only SDL accepts additional APKs in the pinned Husk runtime; other engines remain blocked rather than silently launching an incomplete base APK.
- Added deterministic split discovery from the installed package's private `splits/` directory. Preflight verifies stored split count, regular non-symlink files, package identity and matching version code.
- Connected validated split paths through scoped C-string lifetimes. Launch queues them only after runtime/surface preflight and clears the loader queue on rejected launch.
- Missing, malformed or unsupported-engine split packages remain blocked. OBB/asset-pack extraction and Play Asset Delivery emulation remain unsupported. Other engine split loading remains blocked until their runtime loaders expose a complete package-set contract.
- The earlier 2048 static-field issue remains a separate investigation; no DEX opcode was duplicated or changed.
- No tests, scripts, workflows, Xcode/Codemagic builds, IPA packaging/signing/export, or installs were run. Device compatibility remains unverified. SideStore systems were not modified.

Files changed for split integration: `Vendor/Husk/include/INFINITYHuskRuntime.h`, `Vendor/Husk/bridge/INFINITYHuskRuntime.c`, `LiveContainerSwiftUI/Strata3/INFINITYAPKStore.swift`, `LiveContainerSwiftUI/Strata3/INFINITYHuskRuntime.swift`, `LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift`, and this handoff. Upstream `husk-tl-unity-app.c/.h` remain unchanged.


## 2026-11-19 — Java host callback bridge (implementation only)

- Registered the embedded Husk Java host callbacks from the INFINITY runtime owner before Java app launch.
- Added UIKit-backed host clipboard get/set, share-sheet requests, keyboard show/hide requests, Android orientation requests through supported iOS 16+ window-scene geometry APIs, and document-picker requests.
- Added the launch surface's software-keyboard input route to Husk's Java text insertion, backspace, editor-action and keyboard-closed functions.
- Added document selection handling that copies selected files into the app's private per-package data directory before returning stable paths to the Java runtime. Picker cancellation is also returned to Husk.
- Host requests are marshalled to the main queue before touching UIKit. Clipboard return memory is allocated with `strdup`, matching Husk's documented malloc-owned callback contract.
- No tests/builds/workflows were run. These callback paths are source-integrated but remain unverified on a built app/device. SideStore remains untouched.


## 2026-11-19 — DEX static field initializer support (2048 compatibility priority)

- Added bounds-checked parsing for DEX `encoded_array` static initial values referenced by each `class_def_item.static_values_off`.
- Static primitive initializers now populate existing class static storage for byte, short, char, int, long, float, double, boolean and null values. String constants are represented as Husk `TL_KIND_STRING` objects.
- Nested encoded arrays and annotations are consumed with recursion/count bounds. Unsupported type/field/method/enum reference kinds are consumed without storing invalid host pointers.
- Malformed offsets, counts, or encoded values are rejected for that class initializer and logged; fields not supplied by the encoded array retain Java's zero/default values.
- This fills a concrete DEX gap: the previous parser allocated `static_values` but never read `static_values_off`, so generated Android resource constants such as `R$layout` IDs could remain zero even though the `sget` opcode was already implemented.
- This is a source-level compatibility improvement, not proof that the earlier 2048 failure is resolved. The exact APK/runtime path and 2048 launch remain unverified until an authorized device build/test.
- No tests, scripts, workflows, Xcode/Codemagic builds, IPA packaging/signing/export, or installs were run. SideStore was not modified.


## 2026-11-19 — Shared Husk split-package launch integration

### Implemented in source

- Removed the INFINITY Swift launch restriction that allowed additional APKs only for the SDL engine. The launch coordinator now passes the complete validated split set to the existing Husk queue for every supported engine.
- Removed the matching SDL-only rejection from the C runtime adapter. Split APK paths are queued before the base APK enters the real Husk launch dispatcher.
- Confirmed the vendored common linker attaches queued splits when the base APK is first added. The inspected engine entry points call that common loader for Unity, SDL, GameActivity, NativeActivity/Unreal, Godot, GTA, Flutter, GameMaker, Cocos and Java. The Java loader also iterates the linker's APK set when resolving app APK contents.
- Increased INFINITY's split queue limit from 15 to the vendored linker's actual capacity: 48 APKs total (one base plus up to 47 splits). The Swift package store now rejects archives exceeding that limit before extraction and rechecks persisted split counts before launch.
- The C adapter rejects overlong split paths before they can be truncated by Husk's fixed-size path table.
- Hardened `tl_ld_add_apk`: if any queued split cannot be opened, it now fails the package-set load instead of silently skipping that split and continuing with an incomplete base-only launch. The existing launch failure cleanup resets the partially opened package set.
- Updated the Android app detail status to describe the common Husk multi-APK loader instead of incorrectly reporting non-SDL engines as unsupported.

### Files changed

- `LiveContainerSwiftUI/Strata3/INFINITYHuskRuntime.swift`
- `LiveContainerSwiftUI/Strata3/INFINITYAPKStore.swift`
- `LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift`
- `Vendor/Husk/bridge/INFINITYHuskRuntime.c`
- `Vendor/Husk/include/INFINITYHuskRuntime.h`
- `Vendor/Husk/translation-layer-next/husk-tl-ld.c`

### Remaining blockers / verification

- This connects split packages to the shared loader at source level; it does not prove every app's particular split selection is complete. XAPK/APKS/APKM archives may contain device-specific configurations or dynamic feature modules that still need selection/metadata handling.
- The current archive importer identifies a base APK and preserves every other APK entry as a split; it does not yet select only the ABI/density/language configuration matching the current device.
- No unit tests, test scripts, GitHub Actions, Xcode builds, Codemagic builds, IPA packaging/signing/export, or device launches were run, as required by implementation-only mode.
- 2048 and Hill Climb Racing remain unverified. No compatibility percentage is increased based solely on this source change.
- SideStore source, settings, targets, bundle identifiers, entitlements, signing, installation, refresh, and workflows were not modified.


## 2026-11-19 — Java DEX and asset loading across split APKs

- Extended Husk's Java/Dalvik APK registration so `tl_dvm_add_apk` loads DEX files from every queued split APK as well as the base APK. It distinguishes code-bearing splits from resource-only splits: code-bearing splits must parse successfully; resource-only splits are still registered on the app class path.
- Increased the Dalvik app class-path table from 64 to 128 entries so the boot/runtime class path plus the complete 48-APK package set can be represented without silently dropping late split paths.
- Replaced the Java asset reader and asset-directory enumeration's hard-coded 16-APK scan with the shared `TL_LD_MAX_APKS` capacity. Java apps can now resolve assets from later splits in the same package set that the native linker has opened.
- These changes complete the Java-side source wiring for split DEX/classes, resources and native libraries. They do not implement device-specific split selection; the importer still preserves all APK entries in the archive.
- No tests, workflows, builds, IPA packaging/signing/export, or device launches were run. This remains source-level implementation, not proof that a particular split app launches correctly.
- SideStore remains untouched.


## 2026-11-19 — Physical iOS game-controller bridge

- Added an INFINITY-owned Swift host adapter based on the repository's existing `Vendor/Husk/host-runtime/HuskGamepad.swift` reference implementation. It uses Apple's GameController framework and the existing Husk C bridge; no parallel or simulated input subsystem was added.
- The adapter starts with the embedded Husk runtime owner, observes controller connect/disconnect events, assigns up to four stable slots, and forwards controller state to Husk.
- Extended gamepad mapping includes A/B/X/Y, shoulders, stick clicks, menu/options/home, D-pad, both analog sticks and analog triggers. Stick Y values are inverted at the host boundary to match Android's positive-down axis convention.
- The APK execution overlay displays connected controller names. Husk's native input implementation remains responsible for exposing these devices and events to Android engine sinks.
- Verification limitation: source integration only. No Xcode compile, physical Bluetooth/MFi controller test, Android game input test, CI run, IPA build, signing or export was performed. Micro-gamepad-only profiles are not currently mapped; individual games must support controller input.
- This change does not alter SideStore or IPA installation behavior.


## 2026-11-19 — DEX field resolution hardening

- Updated the interpreted DEX field resolver to match a field by its complete field identity: name plus descriptor, while retaining the requested static/instance kind and the existing superclass/interface search order.
- This avoids binding a same-named hidden field with a different primitive/reference descriptor to the wrong runtime slot. The existing generic name-only lookup remains available to other internal callers; DEX field_id resolution uses the new exact-match helper.
- Improved unresolved static-field diagnostics to include declaring class, field name, descriptor and DEX file name, making failures such as generated `R$*` references actionable rather than reporting only a numeric field index.
- This is a targeted interpreter correctness improvement, not proof that the earlier 2048 `R$layout` failure is fixed. That exact APK still requires a real launch and session-log confirmation.
- No tests, workflows, Xcode builds, IPA builds, Codemagic jobs, signing/export or device runs were started in this implementation-only batch.


## 2026-11-19 — Runtime input, graphics and memory hardening batch

### Implemented in source

- **JNI input event ownership:** MotionEvent touch records and copied MotionEvents now carry explicit ownership. Android `recycle()` releases only owned records; the fixed controller event rings remain reusable and are never freed by recycle. Event creation handles allocation failure and invalid pointer-array arguments without dereferencing null pointers. Pointer counts are clamped to the supported 0–10 range.
- **Controller disconnect correctness:** a disconnected physical controller now emits key-up events for buttons/triggers that were still held, clears its last axes/button state, and avoids leaving Android games with stuck input. Controller-connected queries and InputDevice ID enumeration now read shared connection state under the controller mutex. Input event allocation failures no longer call engine sinks with null events.
- **EGL graphics buffer safety:** frame readback and TextureView readback validate width/height multiplication before allocating RGBA buffers. Diagnostic BMP capture rejects dimensions that cannot fit the BMP 32-bit size fields, checks pixel/row allocations, and avoids reading into a null buffer. Normal rendering behavior and the existing EGL/Metal path are unchanged.
- **Executable-memory allocator safety:** JIT allocation rejects zero/overflowing requests, verifies allocator usage before subtracting remaining capacity, and uses integer-address range checks instead of relational comparisons between unrelated pointers. Memory usage/size snapshots are now read under the allocator mutex.
- **Session diagnostics:** every active APK session records iOS memory-warning notifications and thermal-state transitions (nominal/fair/serious/critical), then unregisters observers when the session ends. This makes memory pressure and thermal throttling visible in exported session logs without claiming to measure free RAM.

### Verification / limitations

- Changes were committed directly to `main` in focused source commits and the handoff was updated.
- No tests, source-contract scripts, GitHub Actions, Xcode compile, device execution, IPA build, Codemagic build, signing or export were run in this implementation-only batch.
- These changes improve input stability, resource ownership, rendering allocation safety and diagnostics. They do not establish that 2048, Hill Climb Racing or any other APK now launches successfully; game compatibility remains unverified until real device sessions.
- Existing Husk/Strata architecture and gamepad bridge are retained. SideStore systems were not modified.


### Additional EGL surface lifecycle guard

- TextureView and Java compositor window-surface creation now validates non-zero dimensions before allocating an off-screen pbuffer.
- Surface registration is explicit and reports capacity exhaustion. If the fixed tracking table is full, the newly created pbuffer is destroyed and EGL receives a failed surface rather than an untracked surface that would silently render to nowhere.
- The existing destroy path continues to unregister tracked surfaces and clear the Java compositor frame when its last registered surface is destroyed.


- Final API guards in this batch: controller state reads reject null output pointers, controller updates reject null state input, and executable/writable alias delta calculation now uses an explicit signed address difference.


## 2026-11-19 — DEX frame validation and JNI native argument expansion

- Added interpreter-entry validation for malformed DEX method frames: register counts must be internally consistent, incoming register slots must match the receiver plus the prototype's parameter widths, wide values count as two slots, and truncated/oversized prototypes are rejected with a Java VerifyError rather than being copied into an invalid frame.
- Added an explicit OutOfMemoryError path when allocating a large interpreted register frame fails.
- Replaced the JNI native-call bridge's fixed 256-slot overflow argument buffer with a per-call buffer sized to the method's declared parameter count. Floating-point and general-purpose argument spills are retained in order and passed to the existing ARM64 call trampoline; the buffer is released after the native call.
- Added a source-contract regression check for frame validation and dynamic JNI argument storage.
- These are defensive DEX/JNI execution-path changes. They do not claim to add missing Android framework APIs or prove the 2048 app now launches.
- No tests were executed, no GitHub Actions workflow was started, and no Xcode/Codemagic/IPA build, signing, export or device run was performed. Source-contract test added but not run. SideStore systems remain untouched.

## 2026-11-19 — Extended JNI descriptor handling and DEX invoke validation batch

### Implemented in source

- **JNI method descriptor validation:** replaced the permissive, truncating signature walk with a descriptor parser that validates primitive, object, array, and return types; rejects malformed descriptors, invalid void usage, unterminated object descriptors, and more than 255 parameters.
- **JNI argument capacity:** expanded per-method argument-kind metadata to the 255-parameter DEX/JNI limit. Replaced the old fixed 40-entry JNI varargs argument arrays with a small stack fast path and heap allocation for larger signatures. Both Call*MethodV and NewObjectV use the shared argument conversion path.
- **JNI exception and allocation handling:** added explicit allocation checks for JNI object, string, primitive-array and object-array creation. Added argument-array validation for JNI calls and constructors; valid zero-argument calls remain supported. Allocation failures retain their OutOfMemoryError rather than being overwritten by a secondary argument error.
- **DEX invoke validation:** method invocation now checks prototype metadata, parameter widths, receiver/static slot count, truncated prototypes, invoke register count, and each referenced register against the caller's register frame. Malformed call frames fail with actionable VerifyError diagnostics rather than reading beyond the invoke register list or silently truncating the call.
- **Regression contracts:** added source-contract checks for descriptor parsing, dynamic JNI argument storage, 255-argument bounds, and DEX invoke register validation.

### Integration progress estimate (source-level only; not runtime compatibility)

These percentages are engineering estimates of implementation/wiring coverage, not measured APK compatibility or test pass rates:

| Area | Estimate | Basis / remaining work |
|---|---:|---|
| Husk upstream source intake and license notices | 100% | Pinned upstream translation trees, host references, resources and notices are present in the repository |
| Strata host and native launch bridge | 75% | Swift/C bridge, lifecycle, engine dispatch and launch diagnostics exist; full device lifecycle remains unverified |
| APK import and persistent library | 90% | APK-family import/storage and Strata management rows exist; complete split-package runtime loading remains blocked |
| ELF/native loader and Bionic layer | 60% | Native loader, ARM64 path and Bionic compatibility sources are integrated; broad NDK/ABI behavior still needs validation |
| JNI + DEX/ART interpreter | 60% | Interpreter, class/member resolution, JNI calls, native registration and the current validation improvements exist; unsupported bytecode/runtime semantics and edge cases remain |
| Android framework/API coverage | 45% | AOSP/Husk framework DEX and native HLE surfaces are present, but API/service coverage is incomplete and must follow real missing-API traces |
| Graphics, audio and input | 65% | EGL/GLES, audio, touch, sensors and physical controller paths are wired in source; real app rendering/audio/controller behavior is not yet proven |
| Real-device APK compatibility evidence | 0% for this current batch | No 2048 or Hill Climb Racing device launch has been run to verify the latest code |

**Overall Husk integration estimate: approximately 60% source-level.** This is a rounded engineering estimate across the implementation areas above, not a claim that 60% of Android apps work. **Verified real-game execution remains unconfirmed**: 2048 has not been re-run against the earlier R$layout;->activity_main:I failure, and Hill Climb Racing has not been device-tested in this integration state.

### Remaining high-priority blockers

1. Re-run the exact 2048 APK and capture the first real DEX/framework failure after these interpreter/JNI changes.
2. Implement only the Android framework APIs and DEX semantics shown missing by that trace; invoke-custom / method-handle paths remain unsupported in the interpreter.
3. Complete safe multi-APK split loading through the Husk loader before enabling XAPK/APKS/APKM execution.
4. Validate ELF/Bionic/JNI/graphics/audio lifecycle with actual ARM64 APKs and memory-pressure sessions.
5. Compile the iOS target and run the repository's source tests only when the owner authorizes validation.

### Verification and operating constraints

- This batch is source-only. The new/updated source-contract tests were **not run**. No GitHub Actions job was dispatched or rerun; no Xcode build, IPA packaging, signing, export, Codemagic build, or device execution was performed.
- The previous handoff's successful Linux test run is historical baseline evidence and does not validate these new commits.
- Work remains on main; no SideStore files or systems were changed. Preserve Husk license and attribution notices.


## 2026-11-19 — Extra-large DEX/JNI hardening batch and integration status

### Implemented in this batch
- JNI method descriptors now use a validating parser for primitive, object, and array types. It rejects malformed descriptors, invalid void usage, malformed object names, excessive array dimensions, trailing garbage, and more than 255 parameters.
- JNI method metadata now stores up to 255 argument kinds and tracks whether the descriptor was validated. Invalid method invocation returns a Java exception instead of trusting malformed metadata.
- Replaced fixed 40-value JNI varargs arrays with a small local fast path and dynamically allocated argument storage for larger signatures. Allocation failure raises OutOfMemoryError; dynamically allocated arrays are freed after use.
- JNI object, string, primitive-array and object-array allocation paths now check allocation failures before dereferencing returned memory.
- JNI invocation and constructor paths validate descriptor/argument-array consistency, while preserving legitimate zero-argument calls.
- DEX invoke dispatch now validates prototype parameter widths against the encoded register count, checks wide (long/double) slot widths, rejects truncated prototypes and verifies every supplied register index is inside the caller's frame.
- Added source-contract regression checks for JNI descriptor parsing/varargs and DEX invoke register validation.
- Files changed: Vendor/Husk/translation-layer-next/husk-tl-jni.c, Vendor/Husk/translation-layer-next/husk-tl-jni-internal.h, Vendor/Husk/translation-layer-next/husk-tl-dvm.c, and tests/test_husk_runtime_bridge.py.

### INFINITY + Husk integration status (engineering estimate, not a test result)
- **Overall source integration estimate: approximately 60%.** Use the later, area-weighted breakdown in this handoff as the current source-level estimate; the earlier 38% note was a conservative interim snapshot and is superseded. This is not a measured compatibility score.
- **Verified real APK execution on iPhone: 0% demonstrated in this handoff.** No current successful 2048 device launch evidence is recorded, so game compatibility percentages must remain unclaimed.
- **Strata APK import and app-management surfaces:** implemented in source; device behavior/build not currently verified.
- **Swift/Objective-C/C launch bridge:** source wiring exists; end-to-end invocation and lifecycle remain unverified.
- **Husk ELF/native loader and Bionic compatibility:** partial source implementation; complete Android ABI coverage and app execution not demonstrated.
- **JNI and DEX:** substantial interpreter/bridge code exists and this batch adds descriptor/frame validation; ART completeness, GC correctness, class initialization/dispatch edge cases and framework interop remain incomplete/unverified.
- **Android framework:** partial framework DEX/API layer; the 2048-specific missing framework calls and resource behavior still need tracing against a fresh device log.
- **Graphics, touch and gamepad:** EGL surface handling and input/controller bridges exist; real game rendering, audio, frame pacing and controller behavior on device are not verified.
- **XAPK/APKS/APKM split packages:** import/extraction exists, but the current launch ABI still blocks split-required packages. Do not pass only the base APK.
- **Diagnostics:** session logs and iOS memory/thermal warnings exist; real runtime metrics and FPS are not yet proven.

### Next implementation priority
1. Trace and repair the real 2048 path from package metadata through DEX class loading, R$layout static field resolution, framework resource calls, Activity lifecycle and rendering.
2. Implement a proper multi-split package ABI/loader for XAPK/APKS/APKM without dropping configuration/resource/native-library splits.
3. Close Swift/C/Husk lifecycle and error propagation gaps; only then broaden Android framework API coverage based on actual 2048 logs.

### Validation and constraints
- Source-contract tests were added but **not run** in this batch.
- No GitHub Actions workflow was dispatched or rerun; no Xcode compilation, device execution, IPA build, Codemagic build, signing or export was performed.
- This status update does not claim successful game execution or complete Husk/ART compatibility. Work remains on main; SideStore systems were not changed.


- Follow-up cleanup in this batch: the shared JNI varargs conversion helper is now used by both the small-stack and heap-backed argument paths, avoiding duplicated conversion logic.

- Additional JNI safety follow-up: String constructor results are now copied into the placeholder object only after UTF-8/UTF-16 allocations succeed, with overflow and allocation failures converted to Java OutOfMemoryError. JNI A-call paths validate descriptors and non-empty argument arrays before String constructor handling.


## 2026-11-19 — 2048-path DEX metadata and static-value hardening

### Implemented in source
- Added DEX header validation before the interpreter indexes any ID tables: declared file size, 0x70-byte header size, standard little-endian tag, map offset, data section range, and string/type/proto/field/method/class table ranges are checked with overflow-safe count/stride arithmetic.
- Replaced unbounded encoded-value parsing with a bounded recursive parser. ULEB128 reads are capped and checked against the DEX mapping; nested arrays and annotations have a recursion ceiling; string/type/field/method/proto references are checked against their declared table counts.
- Static-value arrays are now checked for a valid offset, a valid count no larger than the class's static-field count, and fully bounded values. Invalid/truncated arrays are logged and class statics retain their zero/default values rather than reading past the DEX buffer.
- Added source-contract regression checks for DEX header/table bounds and recursive static-value parsing.

### 2048 relevance and remaining work
- This hardens the metadata path used when linking app classes, including generated `R$*` classes. It does **not** implement missing Android resource APIs and does not prove that `R$layout;->activity_main:I` now resolves on the target APK.
- Current engineering estimate for 2048-specific source readiness remains **approximately 45%**; no new successful launch evidence exists. This is an implementation estimate, not a probability or compatibility result.
- Overall Husk source integration remains **approximately 60%** using the area-weighted breakdown above. Verified 2048 execution on iPhone remains **0% demonstrated** until a real device launch succeeds.
- Next priority remains: resolve the exact R$layout static-field failure from a fresh 2048 log, then implement the resource-table/layout APIs that the trace actually requests, followed by Activity lifecycle and rendering gaps.

### Verification and constraints
- Source-contract tests were added but **not run**. No workflow, Xcode compile, device launch, IPA build, Codemagic job, signing or export was started.
- All changes are on `main`; Strata remains intact, SideStore systems were not modified, and Husk attribution/license notices remain preserved.


## 2026-11-19 — JNI exact field descriptor resolution (2048 R$* path)

### Implemented
- Fixed the DVM-to-JNI field lookup hook to use the existing descriptor-aware resolver instead of name-only lookup.
- JNI field lookups now match the requested field name and exact JNI descriptor, while retaining superclass/interface lookup behavior.
- Added explicit lookup-class and declaring-class initialization failure handling.
- Added trace-level diagnostics naming the class, field and descriptor when JNI field lookup fails.
- Added a source-contract regression check to prevent the JNI hook from reverting to name-only field lookup.

### Why this matters for 2048
- Generated Android resource fields such as R$layout.activity_main:I are looked up through JNI field APIs in some framework paths. Descriptor-aware lookup prevents a same-name field with another descriptor from being selected and returning the wrong slot.
- This is a concrete fix in the JNI field-resolution path, but it does not prove the APK resource ID or layout can be loaded; the next real blocker must be established from a fresh 2048 runtime log.

### Status and constraints
- 2048-specific source readiness is now an engineering estimate of approximately 48% (previous 45% estimate superseded by this focused field-resolution fix); successful iPhone execution remains 0% demonstrated.
- Overall Husk source integration remains approximately 60%. No basis for increasing the overall figure from this JNI change alone.
- Regression test added but not run. No GitHub Actions workflow was manually started, no Xcode/macOS build, device launch, IPA build, Codemagic, signing or export was performed.
- Work remains on main; Strata preserved; SideStore untouched.


## 2026-11-19 — 2048 DEX field-linking and class-data hardening batch

### Implemented on main
- **Field resolution cache correctness:** DEX field cache entries now record whether the access was static or instance. A field reference resolved through one opcode family can no longer poison the other access mode's cache.
- **Static/instance mismatch semantics:** the resolver checks the opposite field category when the expected category is absent and reports `IncompatibleClassChangeError` for a static field accessed as an instance field, or vice versa.
- **Field index safety:** malformed field indices and allocation failures produce a controlled `VerifyError` path instead of indexing outside the DEX field table/cache.
- **Class-data validation:** validates bounded ULEB128 counts and field/method index deltas before linking; rejects truncated class-data items, out-of-range member IDs and invalid code-item instruction/try ranges.
- **Prototype and interface validation:** verifies method prototype indices, return/parameter type IDs, parameter-list bounds, interface-list offsets/counts and interface type IDs before dereferencing.
- **Allocation guards:** member-table and interface-list allocations are checked before use.
- **Regression contracts:** added checks for field-cache staticness, malformed field indices, class-data bounds, prototype validation and interface-list bounds.

### 2048 relevance
- The earlier failure `R$layout;->activity_main:I` occurs at DEX field resolution. This batch addresses a concrete cache-key/staticness weakness and strengthens linking of generated resource classes.
- It is still **not confirmed fixed**: no new 2048 launch/log was produced. Resource table lookup, layout inflation, Activity lifecycle and rendering still need trace-driven implementation.
- **2048 source-readiness estimate remains 45%**; **verified iPhone execution remains 0% demonstrated**. These are not compatibility claims.
- **Overall Husk source integration remains approximately 60%**, using the existing area-weighted breakdown; no unsupported percentage increase is claimed.

### Verification and constraints
- Regression source tests were added but not manually executed in this session. The repository's push-triggered Linux workflow status should be checked separately; no macOS/Xcode build, device run, IPA build, signing/export or Codemagic run was initiated.
- Work remains on `main`; Strata is preserved, SideStore systems are untouched, and upstream Husk license/attribution notices remain intact.
- Next priority: inspect the Linux workflow result, then obtain a fresh 2048 runtime trace when the owner authorizes the consolidated device test. Use the first actual missing field/API/resource from that trace to drive the next implementation batch.


## 2026-11-19 — Updated operating rules and CI outcome

- The automatic Ubuntu/Linux source-contract workflow completed successfully on commit `96e81843b0542837bfddb4205e688a52eb64f924`: **67 tests passed** and runtime build-script syntax checks passed.
- The first CI attempts in this batch failed only because `tests/test_apk_store_contract.py` still expected the old single-base-APK rejection path. The test was updated to assert the current split-package validation and `additionalPackages` handoff; the next push passed all 67 tests.
- Per the current workflow policy, macOS compilation/build workflows are now **manual-dispatch only**: Husk native source compile audit, Husk static runtime package build, ANGLE iOS build, and Android runtime-assets build. Ubuntu/Linux tests remain push-triggered. The canonical IPA workflow remains manual and is not run without explicit authorization.
- Earlier queued macOS jobs created by the preceding push-triggered workflow definitions may still appear in Actions; no cancellation capability was used. No new manual macOS build was dispatched.
- Latest source-level status remains **60% overall Husk integration**, **45% 2048-specific implementation readiness**, and **0% verified 2048 iPhone execution**. No compatibility claim is made.


### DEX class-data validator follow-up

- Corrected the class-data validation pass so DEX field-index delta accumulation resets independently for `static_fields` and `instance_fields`, matching the DEX format and the attach/link second pass.
- Added a source-contract assertion to prevent regression.
- The automatic Ubuntu test run for the preceding implementation commit completed successfully: **67 tests passed**, including source-contract and APK archive tests; shell build-script syntax checks also passed.
- The four expensive macOS runtime workflows now expose only `workflow_dispatch`; they will not be automatically queued by ordinary source pushes. The IPA builder remains separately manual.


## 2026-11-19 — Project-wide Husk Java runtime asset pipeline hardening

### Implemented on main
- Reworked `Vendor/Husk/build-support/build_java_runtime.sh` into a preflighted, staged runtime build. APEX inputs, ICU data, timezone data, JDK tools, D8, Conscrypt, legacy HTTP and framework resources are validated before the existing runtime output is touched.
- Removed the destructive build-in-place behavior. Runtime files are generated in a temporary sibling directory, required outputs (`husk-framework.dex`, `husk-framework-core.dex`, `org.apache.http.legacy.jar`, and `framework-res.apk`) are checked, and only then is the staged directory promoted. If promotion fails, the previous complete runtime is restored.
- Made the Android APEX root, JDK, D8, legacy HTTP jar, framework resource APK and system root configurable through environment variables while preserving the existing local defaults.
- Kept Android ICU native libraries optional because their exact set varies by Android image, but made ICU data and timezone data mandatory and consistently staged.
- Hardened `infinity_husk_prepare_java` so a Java runtime missing ICU data or timezone data is rejected before Java/Dalvik startup instead of entering a partially configured runtime.
- Added source-contract coverage for the preflight, staged promotion, rollback and native runtime asset checks.

### Integration status
- Overall Husk source integration estimate remains **approximately 60%**; this infrastructure-hardening batch does not justify inflating the percentage.
- Verified real-device APK execution remains **0% demonstrated**. No game or individual APK was targeted in this batch.
- Strata host architecture and SideStore systems were not changed. Husk license and attribution files remain intact.

### Verification and constraints
- Tests were added but not run in this session. No workflow was manually dispatched, no Xcode/macOS build, IPA packaging, Codemagic build, signing/export or device launch was started.
- Work remains on `main`. Next project-wide targets are a full native runtime dependency/ABI audit and closing the remaining Swift/C/Husk lifecycle and diagnostic propagation gaps.


## 2026-11-19 — Project-wide Husk ELF loader hardening

### Implemented on main
- Added an overflow-safe file-range predicate and applied it to the ELF program-header table, section-header table, executable section ranges, and executable segment file ranges.
- ELF64 headers now require a complete ELF header size and a non-empty, fully file-backed program-header table before any header indexing.
- Every ARM64 PT_LOAD segment is checked for file-size versus memory-size consistency, a valid file-backed range, virtual-address overflow, and the loader's segment-count limit.
- The mapped segment copy now uses subtraction-based bounds checks instead of potentially overflowing offset-plus-length expressions.
- The dynamic table must be fully inside the mapped image and have a whole number of ELF dynamic entries before the loader parses it.
- Added a source-contract regression test for these shared loader invariants. This is project-wide ELF loader work; it is not tied to one APK.

### Integration status
- **Overall Husk source integration estimate remains approximately 60%.** This loader hardening closes malformed-input and boundary-check gaps but does not add a new execution backend or establish new app compatibility, so the overall estimate is intentionally unchanged.
- **Verified real-device execution remains 0% demonstrated in this batch.** No APK was launched and no device result is claimed.
- The existing ARM64 ELF loader, ARM32 translation path, Bionic shim, DEX/JNI runtime, and native engine adapters remain partial upstream-derived components requiring broader completion and end-to-end validation.

### Validation and operating constraints
- Regression test was added but **not run**. No manual workflow dispatch, IPA build, Xcode/macOS build, signing/export, Codemagic run, or device test was started.
- Work remains on `main`; Strata and SideStore systems were not modified. Husk license and attribution notices remain preserved.
- Next project-wide priorities: finish ELF dynamic metadata/relocation validation, broaden Bionic/API coverage, close ART/JNI lifecycle and garbage-collection gaps, and complete graphics/audio/platform integration before consolidated testing.

- Follow-up in the same project-wide batch: the ELF loader now checks allocation of its library metadata object and exits through a controlled load failure rather than dereferencing a null allocation; the regression contract covers this path.


## 2026-11-20 — Project-wide ELF dynamic metadata and Bionic lookup hardening

### Implemented on main
- Replaced permissive ELF dynamic-tag parsing with a bounded parser that requires a terminating `DT_NULL` inside the declared dynamic segment and rejects dependency-table overflow.
- Added a shared mapped-image range validator and bounded dynamic-string lookup. `DT_NEEDED` and `DT_SONAME` offsets must resolve to NUL-terminated strings fully inside `DT_STRTAB/DT_STRSZ`.
- Validate dynamic string/symbol tables and pointer-size pairs for RELA, PLT RELA, Android packed RELA, RELR, and init arrays before downstream linker code consumes them.
- Validate SysV hash table dimensions and GNU hash bucket/chain termination against mapped image bounds.
- Bionic symbol lookup now rejects null/empty names and safely reports an unavailable lookup table if its allocation fails, rather than continuing with invalid table state.
- Added source-contract regression coverage for the ELF metadata and Bionic lookup invariants.

### Commits
- ELF dynamic metadata validation: `d57e18f341cef1792a67eaeffa33ca2f35333c55`
- Bionic lookup failure guards: `ea569637c14960777135d6bbf63c9288f40effa3`
- Regression contracts: `45a73c4330682363ee6b94129ca71601a538bd12`

### Integration status and verification
- **Overall Husk source integration remains approximately 60%.** This batch materially improves loader correctness and rejects malformed dynamic metadata, but it does not yet complete missing execution subsystems or establish broader APK execution. Do not inflate the percentage based on defensive validation alone.
- **Verified real-device execution remains 0% demonstrated.**
- Regression tests were added but **not run**. No workflow was manually dispatched; no IPA build, Xcode/macOS build, Codemagic build, signing/export, or device test was started.
- Work remains on `main`; Strata and SideStore were not modified. Husk license and attribution notices remain preserved.

### Next large project-wide batch
- Continue with actual runtime capability coverage rather than isolated APK patches: audit and complete dynamic relocation/symbol-resolution paths (including Android packed relocations and versioned symbol behavior), broaden Bionic NDK ABI coverage, and close native loader/JNI/ART lifecycle gaps. Only raise the overall percentage when completed capabilities—not just validation checks—justify it.


## 2026-11-20 — Large project-wide ELF linker and Bionic integration batch

### Implemented on main
- **Dynamic segment parsing:** the loader now requires a fully bounded dynamic segment containing a terminating `DT_NULL`; dependency overflow is rejected instead of silently dropping entries.
- **Dynamic string safety:** validates the complete string-table range and requires every `DT_NEEDED`, `DT_SONAME`, and dynamic-symbol name to be in-range and NUL-terminated before use.
- **Hash-table validation:** validates SysV hash header/bucket/chain storage and GNU hash header, bloom/bucket ranges, bucket indexes, and bounded chain termination before symbol counting or lookup.
- **Relocation metadata:** validates RELA, PLT RELA, Android APS2 packed RELA, RELR, and init-array pointer/size pairs, including entry-size alignment and mapped-image bounds. Empty optional tables remain accepted for compatibility.
- **Symbol resolution:** validates the computed dynamic symbol-table extent, rejects out-of-range relocation symbol indexes, and prevents invalid symbol names from reaching string comparisons or unresolved-import logging.
- **Relocation writes:** validates relocation target addresses before forming writable pointers; checks TLS symbol indexes, RELR target words, and IRELATIVE resolver addresses before reading or calling them.
- **Bionic lookup:** null/empty symbol names now fail safely; lookup-table allocation failure is detected and reported, and lookups fail closed instead of dereferencing an absent hash table.
- Added regression source-contract assertions for the new ELF metadata, symbol, relocation, and Bionic lookup checks.

### Integration status
- **Overall Husk source integration estimate: 65%** (previous baseline: 60%; +5 percentage points). The increase reflects a meaningful closure of the ELF dynamic-linking/symbol-resolution safety stage plus Bionic lookup hardening. It is an engineering estimate, not a measured compatibility score.
- **Verified real-device APK execution: 0% demonstrated in this batch.** This batch did not prove that any APK/game launches.
- No single APK was targeted; this was shared runtime/linker infrastructure work.

### Verification and operating constraints
- Regression tests were expanded but **not run in this batch**. No workflow was manually dispatched, no Xcode/macOS build, IPA packaging, Codemagic build, signing/export, or device launch was started.
- Work remains on `main`; Strata host code and SideStore systems were not modified. Husk attribution and license notices remain preserved.
- Keep the next work project-wide: audit ELF dependency-closure failure handling and loader lifecycle, broaden Bionic syscall/NDK coverage, then ART/JNI reference and garbage-collection lifecycle. Do not pivot to an individual APK.
- Continue to defer IPA/device testing until the user authorizes the single consolidated test phase.


### Compatibility refinement
- Kept empty optional relocation/init-array tags compatible instead of rejecting a zero-sized optional table solely because its address tag is present.
- Preserved the ELF `R_NONE` no-op relocation behavior before target-address validation, so no-op entries with a zero offset do not become false loader failures.
- Added the corresponding regression source-contract assertion. Tests remain unrun by design.


## 2026-11-20 — ELF symbol semantics and GNU IFUNC execution batch

### Implemented on main
- Added real GNU IFUNC resolver execution to the shared ELF64 linker. IFUNC symbols now resolve to the address returned by their resolver rather than being rejected or exposed as the resolver's own address.
- Resolver addresses are checked against the mapped image and executable function ranges before invocation. Results are cached per dynamic symbol, including legitimate null results; an in-progress marker detects recursive resolver cycles. The cache uses acquire/release atomics so concurrent lookups do not read partially published results.
- Added ELF symbol-visibility handling for STV_INTERNAL, STV_HIDDEN, STV_DEFAULT, and STV_PROTECTED.
- Hidden/internal definitions remain available to their owning image's local relocations but are excluded from dependency exports and process-wide / handle-based dynamic symbol lookup. Protected symbols remain externally visible while the owning image retains its local definition.
- Updated relocation binding, dependency-scope lookup, direct dlsym lookup, and deep dependency lookup to use the shared resolved-symbol path.
- Added source-contract coverage for IFUNC execution/caching and visibility-aware symbol lookup.

### Integration status
- **Overall Husk source integration estimate: 68%** (previous handoff baseline: 65%; +3 percentage points). This increase reflects a real missing ELF execution capability—GNU IFUNC resolution—plus corrected symbol visibility semantics across loader lookup paths. It is an engineering estimate, not a measured compatibility score.
- **Verified real-device APK execution remains 0% demonstrated.** No app/game compatibility is claimed from source changes alone.

### Verification and constraints
- Regression tests were added but **not run**. No workflow was manually dispatched; no IPA build, Xcode/macOS build, Codemagic build, signing/export, or device test was started.
- Work remains on main. Strata host code and SideStore systems were not modified. Husk license and attribution notices remain preserved.
- Next large runtime batch: implement GNU symbol-version metadata and version-aware dlvsym/dependency binding, then broaden Bionic NDK API coverage and continue ART/JNI lifecycle completion.


### IFUNC cache consistency follow-up
- Unified relocation-cache reads/writes with acquire/release atomics, matching the IFUNC resolver path.
- Relocation binding now detects the IFUNC in-progress sentinel rather than accidentally treating it as a callable address if a resolver recursively re-enters symbol binding.
- Extended the source-contract assertion for the recursive-binding guard. Tests remain unrun.


## 2026-11-20 — GNU ELF symbol versioning and Bionic dlvsym integration

### Implemented on main
- Added parsing and storage for GNU DT_VERSYM, DT_VERDEF/DT_VERDEFNUM, and DT_VERNEED/DT_VERNEEDNUM metadata.
- Added bounded validation of version-definition and version-requirement linked lists, auxiliary records, version strings, and the per-symbol version-index array. Malformed version metadata now rejects the library before relocation or symbol lookup.
- Added per-symbol version-name resolution for exported definitions and undefined imports.
- Added version-aware exported-symbol lookup across dependency scopes. Ordinary lookup skips non-default version aliases; explicit version lookup selects the exact named version.
- Relocation binding now honors the importing library's GNU version requirement instead of resolving only by symbol name. An unresolved version requirement fails the load rather than silently binding an ABI-incompatible symbol.
- Added public tl_ld_sym_version and tl_ld_sym_deep_version entry points.
- Implemented Bionic dlvsym and __loader_dlvsym version-aware behavior for global, next, system-handle, and library-handle lookups; exported dlvsym through the Bionic symbol table.
- Added source-contract regression coverage for end-to-end GNU versioning and Bionic dlvsym wiring.

### Integration status
- **Overall Husk source integration estimate: 73%** (previous baseline: 68%; +5 percentage points). This is a substantial shared ELF ABI capability: versioned imports and version-specific dynamic lookup now have real linker paths rather than name-only resolution. It is an engineering estimate, not a measured APK compatibility score.
- **Verified real-device APK execution remains 0% demonstrated.** No game or APK compatibility is claimed from this source-only batch.

### Verification and constraints
- Regression tests were added but NOT run. No workflow was manually dispatched, no IPA build, Xcode/macOS build, Codemagic build, signing/export, or device launch was started.
- Work remains on main. Strata host code and SideStore systems were not modified. Husk license and attribution notices remain preserved.
- Next major batch: broaden Bionic pthread/NDK surface with ABI-correct wrappers and implement missing lifecycle behavior in JNI/ART. No name-only stubs should be treated as compatibility; unsupported APIs must remain explicit and diagnosable.


### GNU version-index extent correction
- Corrected the VERSYM extent to cover the full validated dynamic-symbol cache bound, not only the hash-covered exported-symbol count. Android shared objects commonly place undefined imports after the hash-covered definitions, so their version requirement indexes must also be addressable.
- Added overflow rejection for 64-bit VERDEFNUM/VERNEEDNUM values before narrowing to the loader's 32-bit counters.
- Added a regression contract for import-side version-index coverage. Tests remain unrun.


### Bionic dlvsym diagnostic correctness
- Upgraded the thread-local dlerror formatter to a real variadic formatter. Versioned lookup errors include both the symbol and requested version safely; the previous one-argument formatter could not represent a two-substitution dlvsym diagnostic correctly.
- Added a source-contract assertion for the multi-argument diagnostic path.


### Dynamic-symbol boundary integration correction
- Added VERSYM, VERDEF, and VERNEED addresses to the dynamic-symbol extent boundary calculation. This prevents GNU version tables located after .dynsym from being miscounted as extra ELF symbol entries when deriving the relocation-cache bound.
- Extended regression contracts to pin this boundary behavior. Tests remain unrun.


### GNU version provider binding
- Relocation-time version resolution now also reads the dependency filename from the matching Vernaux record and restricts provider lookup to that declared DT_NEEDED library. This prevents a different dependency that happens to export the same symbol/version name from being selected accidentally.
- Imports with an incomplete version-name/provider requirement now fail with an explicit loader diagnostic instead of silently using a different provider.
- Added source-contract coverage for dependency-file constrained version binding. Tests remain unrun.

### Integration status update
- **Overall Husk source integration estimate: 75%** (from 68%; +7 percentage points across this batch). The increase reflects actual GNU versioned relocation binding, explicit version-specific symbol lookup, provider-file matching, Bionic dlvsym wiring, and correct default-version selection. This remains an engineering estimate, not a compatibility benchmark.
- **Verified real-device execution remains 0% demonstrated.**


## 2026-11-20 — Bionic pthread identity and condition-clock ABI batch

### Implemented on main
- Added a real pthread_getname_np wrapper backed by Darwin's thread-name query for the requested pthread handle.
- Added pthread_gettid_np backed by pthread_threadid_np, returning the host thread identifier and reporting host errors through guest errno.
- Added pthread_condattr_getclock to read back the clock selected by pthread_condattr_setclock, preserving Bionic's CLOCK_REALTIME/CLOCK_MONOTONIC values stored in the guest attribute.
- Corrected pthread_setname_np behavior: the host only supports renaming the current thread through this API, so remote-thread rename now returns ENOTSUP rather than falsely reporting success. Current-thread rename propagates the host result.
- Exported all three added NDK/pthread symbols and added source-contract coverage.

### Integration status
- **Overall Husk source integration estimate: 77%** (previous: 75%; +2 percentage points). This reflects real pthread ABI coverage and truthful behavior for thread naming, not added symbol-name stubs. It remains an engineering estimate, not a measured compatibility score.
- **Verified real-device APK execution remains 0% demonstrated.**

### Verification and constraints
- Tests were added but NOT run. No workflow manually dispatched; no IPA build, Xcode/macOS build, Codemagic build, signing/export, or device test.
- Work remains on main; Strata and SideStore untouched; Husk notices preserved.
- Next large batch: continue Bionic pthread lifecycle/robust mutex semantics and NDK NativeActivity/input/window integration, then ART/JNI lifecycle gaps. No fake API stubs should be counted as completed capability.


## 2026-11-20 — Bionic caller-owned pthread stack support

### Implemented on main
- Added pthread_attr_setstack with null, minimum-size, and pointer-range overflow checks. The caller-supplied stack base and size are retained in the guest pthread_attr_t and marked explicitly.
- Native thread creation now uses pthread_attr_setstack with the exact caller-owned range when that attribute is present. It no longer silently substitutes a different host-owned stack or applies the interpreter's 16 MiB default-stack expansion to a caller-owned range.
- Native stack-configuration failures are returned to the guest after proper pthread_attr cleanup; they are not reported as successful thread creation.
- Exported pthread_attr_setstack and added source-contract regression coverage.

### Integration status
- **Overall Husk source integration estimate: 80%** (previous: 77%; +3 percentage points). This batch closes a concrete thread-creation ABI gap alongside the preceding pthread identity and condition-clock additions. This remains an engineering estimate, not a measured compatibility score.
- **Verified real-device APK execution remains 0% demonstrated.**

### Verification and constraints
- Tests were added but NOT run. No workflow manually dispatched; no IPA build, Xcode/macOS build, Codemagic build, signing/export, or device test.
- Work remains on main; Strata and SideStore untouched; Husk license/attribution preserved.
- Next large batch: continue NDK NativeActivity/window/input and ART/JNI lifecycle work, keeping unsupported APIs explicit rather than claiming fake compatibility.


## 2026-11-20 — Bionic timed mutex and semaphore ABI completion

### Existing work confirmed before editing
- The 80% baseline is already present on `main`: GNU ELF symbol versioning and dependency-specific version binding, Bionic `dlvsym`, pthread identity/condition-clock APIs, and caller-owned pthread stacks.
- NativeActivity support is also already present in `husk-tl-nativeactivity.c/.h`, including a generic `ANativeActivity_onCreate` path, lifecycle callbacks, window creation/resizing, touch forwarding, controller forwarding, and pause/resume callbacks. This existing subsystem was inspected and was not counted again as new work. It remains an adapter with known gaps (notably its placeholder input queue and incomplete shutdown lifecycle), not a complete Android NDK implementation.

### Implemented on main
- Added Bionic `pthread_mutex_timedlock` with absolute CLOCK_REALTIME deadline handling, timespec nanosecond validation, immediate try-lock success, and explicit ETIMEDOUT reporting.
- Added Bionic `pthread_mutex_clocklock` with explicit CLOCK_REALTIME/CLOCK_MONOTONIC selection and rejection of unsupported clock IDs.
- Both timed-lock paths use the guest mutex's existing lazily-created host mutex and update optional mutex-owner tracing after successful acquisition.
- Added semaphore initialization validation for supported process-sharing values and the Bionic signed count limit.
- `sem_post` now detects count overflow and reports guest EOVERFLOW instead of allowing signed integer overflow.
- Added source-contract regression assertions for the new mutex and semaphore behavior.

### Commits
- Timed mutex locking and semaphore overflow semantics: `8464911cc8a9ab700a416d7e527b10604d17305d`
- Integer-limit include required by semaphore bounds: `3d1da9f1570217a2367e1cb3d997a0c0b1b470a2`
- Regression contract coverage: `c1c76214f973a39acc15405d80baadb9b5274666`

### Integration status and evidence
- **Overall Husk source integration estimate: 81%** (previous handoff estimate: 80%; +1 percentage point). The increase is limited to the newly implemented timed-mutex and semaphore ABI behavior. This is a transparent engineering estimate based on source-level subsystem coverage, not a mathematically measured percentage or an APK compatibility score.
- **Verified runtime/device execution remains 0% demonstrated.** The new tests are source-contract assertions only and were not run in this batch.
- No GitHub Actions workflow was dispatched; no IPA build, Xcode/macOS build, Codemagic build, signing/export, or device test was started.
- Strata host architecture and SideStore systems were not changed. Husk license and attribution notices remain intact.

### Next large project-wide batch
- Complete NativeActivity input delivery and lifecycle teardown rather than counting its existing placeholder queue as complete.
- Audit Bionic robust-mutex/owner-death semantics against what the Apple host can actually support; unsupported robust behavior must return an explicit error rather than claim success.
- Continue JNI global/local reference lifecycle and ART thread attach/detach integration.


## 2026-11-20 — NativeActivity lifecycle teardown and truthful input-queue handling

### Audit findings before implementation
- Existing NativeActivity input delivery was not a real Android `AInputQueue`: `onInputQueueCreated` was passed the address of the global NativeActivity state, an opaque pointer that did not implement the NDK queue contract.
- The UI/looper thread ran forever, with no stop flag, join path, or ordered `onPause` / window-destroyed / `onStop` / `onDestroy` teardown.
- JNI object reference helpers currently use shared object reference counts; full per-thread JNI local-frame and VM attach/detach semantics remain a separate incomplete area and are not counted as completed here.

### Implemented on main
- Added an atomic NativeActivity stop request and a bounded looper poll loop.
- Added `tl_na_stop()`, which requests shutdown and joins the UI thread before native runtime code/callbacks are unloaded.
- Added ordered lifecycle teardown callbacks: pause, focus loss, native-window destruction, stop, and destroy.
- Wired the Infinity runtime stop path and rejected-launch cleanup to stop NativeActivity before unloading/resetting the Husk runtime.
- Removed the invalid fake `onInputQueueCreated` invocation. Apps requesting an input queue now receive an explicit diagnostic; the callback is withheld until a real NDK-compatible queue exists.
- Added source-contract regression coverage for stop/join, teardown callbacks, and the absence of the fake queue pointer.

### Commits
- NativeActivity stop and lifecycle teardown: `e14998bff04e37df65b90f3cef14a66e1f51a68e`
- Public stop declaration: `307d49f20d567a8a2e114b020732594e23861b95`
- Join NativeActivity before runtime unload: `5083957c33ba7de654b72952f2c74354ef5db0d6`
- Lifecycle/input-queue contract coverage: `90c7a274de13e201fb6df339d2e0692618348c6f`
- Stop NativeActivity during rejected-launch cleanup: `6ae3b0325bd81e5227a8ab538dc31f00b5807e3e`

### Integration status and evidence
- **Overall Husk source integration estimate: 82%** (previous: 81%; +1 percentage point). The increase reflects a real, wired NativeActivity shutdown path and removal of a false-positive input-queue callback. It does not count the still-missing AInputQueue implementation.
- **Verified compile/runtime/device execution remains unproven for this batch.** Source-contract tests were added but not run, per the agreed one-consolidated-test policy.
- No GitHub Actions workflow was dispatched; no IPA/Xcode/Codemagic build, signing/export, or device test was started.
- SideStore and its project configuration were not modified. Husk licensing/attribution notices remain intact.

### Next large batch
- Implement an actual NDK-compatible input queue/event contract and connect touch/key events, or keep NativeActivity input-queue apps explicitly unsupported until that complete path exists.
- Continue JNI per-thread local-reference frames and correct `AttachCurrentThread` / `DetachCurrentThread` ownership.
- Audit robust mutex attributes and owner-death behavior; never claim robust semantics that the Darwin host cannot provide.


## 2026-11-20 — JNI local-reference frame implementation (partial API coverage)

### Audit finding
- JNI `PushLocalFrame` / `PopLocalFrame` were no-ops. `NewLocalRef` merely incremented the object refcount, and `EnsureLocalCapacity` always returned success.
- JNI handles in this compatibility VM are raw `jobj *` pointers. That prevents reliable distinction between local and global handles to the same object without a handle-wrapper redesign.
- JNI `Call*ObjectMethod` return paths and full per-thread `JNIEnv` / `AttachCurrentThread` ownership still need a separate audit. This batch does not claim full JNI reference semantics or full VM thread attachment.

### Implemented on main
- Added a thread-local JNI local-reference frame stack with nested parent frames.
- Implemented `PushLocalFrame` with capacity reservation and allocation-failure reporting.
- Implemented `PopLocalFrame`: release current-frame references and preserve the requested result in the parent frame.
- Implemented `NewLocalRef` tracking, `DeleteLocalRef` slot removal, and `EnsureLocalCapacity` growth with overflow protection.
- Adopted local references returned by key JNI object-creation/access APIs, including class lookup, object construction, strings, arrays, reflected members, and direct byte buffers.
- `DetachCurrentThread` now releases the calling thread's tracked local-frame stack.
- Added source-contract assertions for frame operations, JNI return adoption, capacity checks, and detach cleanup.

### Commits
- Initial JNI local-reference frame implementation: `5a8f2d8d1d03264fd06c640abc68a90c50683568`
- Removed unused declaration: `33a7bd6623a2230a72fba5f1de797c71ba06a22c`
- Added JNI local-frame contract tests: `2ba1f18812c829f40deae9efb5869d4d5151d70a`
- Adopt JNI-created references into active frames: `e32fde574d544a47d3ed72b25a5e1d3b998c3d04`
- Handle local-frame allocation failures: `f9ba4b5bed1786278a3e219f428e1d165eec8a43`
- Expand source-contract coverage: `ad1e76f9f15c4696bc6b5b93b2e11de71eafeced`
- Guard local-frame allocation-size overflow: `d11d478ff2f8455881379f99b4ebd6fbcef2f296`

### Integration status and evidence
- **Overall Husk source integration estimate: 83%** (previous: 82%; +1 percentage point). The increase represents real JNI frame-stack behavior and integration into key object-return paths, not complete JNI conformance.
- Remaining JNI gaps: raw-pointer local/global handle identity, object-returning `Call*Method` wrappers, full automatic local-ref registration coverage, and true per-thread `JNIEnv` attachment ownership.
- NativeActivity's actual NDK input queue is still not implemented; apps requiring it remain explicitly unsupported rather than receiving a fake queue.
- Source-contract tests were added but not run. No build, workflow, IPA export, signing, or device test was started.
- SideStore and Strata host architecture were not modified. Husk license and attribution notices remain intact.

### Next large batch
- Complete JNI return-reference coverage and per-thread VM attach/detach semantics without breaking existing internal JNI callers.
- Implement or explicitly gate a genuine NativeActivity input queue with Android NDK event semantics; do not pass opaque placeholders.
- Continue the robust pthread mutex/owner-death audit against Darwin host capabilities.


## 2026-11-20 — JNI object-return coverage and per-thread VM environments

### Audit and correctness fixes
- The prior JNI frame batch still left all three object-returning `Call*Method` families using generic raw-pointer return wrappers. These results were not registered as local references.
- The JNI VM exposed one process-global `JNIEnv` pointer to every thread. `GetEnv` also returned success even for unattached threads and ignored the requested JNI version.
- During integration, class mirrors were distinguished from newly allocated objects: borrowed class mirrors now acquire a reference before being owned by a local frame. The internal `tl_jni_class_object` helper remains a borrowed-pointer helper and is not incorrectly enrolled in JNI local frames.
- Removed the stale global-environment initialization after switching to thread-local `JNIEnv` storage.

### Implemented on main
- Added explicit object-returning wrappers for virtual, nonvirtual, and static `CallObjectMethodA/V` and native variadic entry points; returned objects are retained and enrolled in the active local-reference frame.
- Replaced the shared global `JNIEnv` storage with per-thread environment records.
- Added per-thread VM attachment state for `AttachCurrentThread`, `DetachCurrentThread`, and `GetEnv`.
- `GetEnv` now returns JNI_EDETACHED for unattached threads and JNI_EVERSION for unsupported JNI versions; detach releases the calling thread's local frames.
- Attachment now fails cleanly if the initial local-frame allocation fails.
- Corrected ownership of borrowed class mirrors so frame teardown cannot accidentally free class-singleton objects.
- Added source-contract coverage for object-return wrappers, thread-local environment state, attach/detach results, and borrowed-reference ownership.

### Commits
- Object-returning JNI wrappers: `0eb8cdbc6195b3236276843f8571c69f4f689925`
- Per-thread JNI environments and attachment state: `c8af132974216c96954ea9ed022e6a9efcd3be5c`
- JNI contract tests: `7fa62855f23ba34a0d862baa9827f8bafe1d1a0d`
- Remove stale global environment initialization: `54ccf54e5df4e6fdb1ec6155437cc9ca62b08f66`
- Correct borrowed-reference ownership: `60273e4e29bd1ab28e7480b8438dd837291ce738`
- Handle attachment allocation failure: `dda4f7f9aa30015dcbe1c02d2a3819811e0b9728`
- Extend ownership/attachment contract tests: `ffc5a38d154d1d1037f5387a05f8982e9090321f`

### Integration status and evidence
- **Overall Husk source integration estimate: 84%** (previous: 83%; +1 percentage point). This reflects concrete JNI call-return and per-thread VM attachment source coverage, not full JNI conformance.
- Remaining JNI gaps include raw-pointer local/global handle identity, comprehensive local-reference registration for every JNI object-return API, and full Android VM lifecycle semantics (including safe VM destruction).
- NativeActivity's genuine NDK input queue remains unimplemented and explicitly withheld; no fake queue is passed to apps.
- Source-contract tests were added but not run. No compile, test, workflow, IPA build/export, signing, or device test was started.
- SideStore and Strata host architecture were not modified. Husk license and attribution notices remain intact.

### Next large batch
- Audit all remaining JNI object-returning APIs and internal-vs-JNI ownership boundaries; introduce a handle representation only if needed to separate local/global identity safely.
- Continue genuine NativeActivity input delivery only with a real NDK-compatible queue/event contract.
- Audit robust pthread mutex owner-death behavior against Darwin host capabilities; explicitly report unsupported semantics rather than emulate them incorrectly.


## 2026-11-20 — JNI constructor, array, and buffer boundary hardening

### Audit findings addressed
- JNI string construction could pass a negative length or null UTF-16 pointer into conversion; UTF conversion allocation failures were not consistently handled.
- Object-array creation did not reject negative lengths or invalid element-class handles. Object-array reads/writes did not consistently validate array kind, bounds, or component assignment.
- Primitive-array creation accepted invalid element tags, and array region operations used signed `start + length` arithmetic that could overflow before bounds checking.
- Direct-buffer construction did not reject invalid capacities or a null address paired with a positive capacity.
- Critical primitive-array access accepted non-primitive objects.
- Detaching a JNI-attached thread released local frames but left its pending exception state behind.

### Implemented on main
- Added null/length and allocation-failure handling to UTF-16 conversion and JNI string creation/access.
- Hardened string-region range checks using subtraction-based bounds validation, avoiding signed addition overflow.
- Added object-array constructor validation, element-kind checks, bounds checks, and component-type assignability checks for object stores.
- Rejected invalid primitive-array element tags and negative lengths; primitive array element/region APIs now validate array kind, element type, buffer, and safe bounds before copying.
- Validated direct-buffer address/capacity and checked allocation before invoking constructors.
- Restricted critical-array access to primitive arrays.
- JNI detach now clears the detached thread's pending exception after releasing its local frames.
- Added/updated source-contract checks for these boundaries and refreshed earlier local-frame assertions to match the hardened implementations.

### Commits
- JNI string/object-array/direct-buffer validation: `f10bb6eb34ea1848d23db2aaf0feea8e7781bf68`
- Object-array component checks and primitive-array validation: `e414d576ec37d780c866c70b1e3d85ba70ee84fe`
- UTF conversion, string-region, and primitive-array region hardening: `1f4c6a1ee69017adff5850d6a913a76a99b71741`
- Critical-array validation and detach exception cleanup: `cd5a475bacac1221bde13170f8fd9518efb9d3da`
- New constructor/array boundary contract test: `14b6ad37b74b7ea60883c6bde2c4c2aeae38fc38`
- Updated local-frame test assertions: `e5f03e9507d89e59a8dd175c110c1827d4d50b99`
- Additional critical-array/detach contract assertions: `c0bb86b9cbc89517c12879ece698feefce7e7868`

### Integration status and limitations
- **Overall Husk source integration estimate: 85%** (previous: 84%; +1 percentage point). The increase reflects additional JNI input validation, array/buffer semantics, and error paths; it is not a claim of complete JNI conformance.
- Raw-pointer handles still cannot distinguish local from global references; `GetObjectRefType` remains conservative.
- JNI modified-UTF-8 conformance, complete ART exception behavior, array pin/copy semantics, and full object-array class-loader/interface assignability still need work.
- NativeActivity's genuine NDK input queue remains unavailable; no fake queue is passed to guest code.
- Source-contract assertions were inspected for matching source markers, but **the test suite was not run**. No compile, workflow, IPA build/export, signing, or device test was started.
- SideStore and Strata host architecture were not modified. Husk license and attribution notices remain intact.

### Next batch
- Continue JNI local/global handle identity and remaining reference lifecycle semantics, without destabilizing internal raw-pointer callers.
- Audit object-array assignability across interfaces/class loaders and implement proper modified UTF-8 behavior.
- Evaluate whether a genuine NDK input queue can be supplied through the current iOS host architecture; otherwise keep the feature explicitly unsupported.
- Continue pthread/NativeActivity audits without claiming unsupported Android behavior.


## 2026-11-20 — JNI Modified UTF-8 and native registration lifecycle

### Implemented on main
- Added JNI Modified UTF-8 encoding from the runtime's UTF-8 string representation, including NUL-free BMP characters and supplementary characters encoded as UTF-16 surrogate pairs.
- Added Modified UTF-8 decoding for `NewStringUTF`, including validation of continuation bytes, overlong sequences, and surrogate-pair structure.
- `GetStringUTFLength` now reports Modified UTF-8 byte length rather than ordinary UTF-8 `strlen`.
- `GetStringUTFChars` now returns Modified UTF-8 data, and `GetStringUTFRegion` now encodes the requested UTF-16 code-unit region using Modified UTF-8.
- Added explicit allocation and malformed-input error paths.
- Native registrations now retain the class through which each registration was made, separately from the class that owns the declared method. `UnregisterNatives` removes registrations originating from the requested class, including registrations attached to inherited method owners.
- `RegisterNatives` now validates the class, count, method table, names/signatures/function pointers, checks allocation failures, and advances the native-generation counter only when methods were registered.
- Added source-contract coverage for Modified UTF-8 conversion and native registration/unregistration lifecycle.

### Commits
- Modified UTF-8 conversion and decoding: `03d6463fdcde436220e7df9239d9b63f1ca4e7c7`
- Modified UTF-8 length and region APIs: `6af2f08e1f21f1b914a4c255cd3e257e6357cd1a`
- Embedded-NUL/surrogate validation: `c56f251faf01bed95856b38abc972d28d7cdbee4`
- Correct surrogate-pair decoding: `ada51d188672119b6521b993f3be3f64d392e7e0`
- Native registration-origin tracking: `a265835273098ab05cdaa3b1cdab570e1c8cf693`
- Registration validation and real UnregisterNatives: `100daf853a4fbaa8a316f7bb52f6eea18565251b`
- JNI contract tests: `a1331bbe40087908d68cb3576f4382b8ca11f0bb`

### Integration status and limitations
- **Overall Husk source integration estimate: 87%** (previous: 85%; +2 percentage points). This is a source-coverage engineering estimate, not a runtime compatibility score.
- Modified UTF-8 is not yet fully conformant for embedded U+0000 because the current guest string representation is NUL-terminated; that input is explicitly rejected rather than silently truncated. Unpaired surrogate code units are also rejected. A length-aware guest string representation is needed to close this gap.
- Local/global JNI reference identity remains unresolved because JNI handles are still raw object pointers; `GetObjectRefType` is conservative and weak-global references are not implemented.
- Native registration is now reversible by registering class, but the full ART class-loader and native-method resolution lifecycle still requires further work.
- NativeActivity's genuine NDK input queue remains unavailable; no fake queue is passed to guest code.
- Source-contract assertions were checked against the current source markers; **the test suite was not run**. No compile, workflow, IPA build/export, signing, or device test was started.
- SideStore and Strata host architecture were not modified. Husk license and attribution notices remain intact.

### Next batch toward 90%
- Introduce length-aware guest string storage to support embedded U+0000 and complete JNI Modified UTF-8 semantics without C-string truncation.
- Replace raw JNI object pointers with explicit local/global/weak handle records, preserving internal runtime pointer APIs through conversion helpers.
- Continue NativeActivity input delivery only if a real NDK-compatible queue can be implemented end-to-end; otherwise keep it explicitly unsupported.


### Follow-up source-contract cleanup
- `GetStringUTFRegion` now copies exactly the Modified UTF-8 byte count with `memcpy`; it does not assume the caller allocated an extra byte for a C terminator. Embedded U+0000 remains explicitly rejected because the internal guest string representation is NUL-terminated.
- Consolidated the Modified UTF-8/native-registration source assertions into one uniquely named test method (removing a duplicate Python method definition so no assertions are shadowed).
- Follow-up commits: exact-length UTF region write and embedded-NUL guard `e69d0669f2839bae2aa3340e7565bbf5f1097b10`; initial supplementary source-contract assertions `c6b508714a11d9cfdf13e99292881aacf19fe427`; duplicate-test consolidation `419abb11a1d26ba53b5d4073da17ac74d8197ccb`.
- These are source inspections/contracts only. No test suite or compiler was run.

## 2026-11-20 — Transactional JNI native registration hardening

### Implemented on main
- Reworked `RegisterNatives` into a staged transaction: all method names/signatures are copied and validated before any binding is published.
- Resolve every method's declaration owner first, then reserve capacity for every affected class table before appending entries. Allocation failure leaves all visible native bindings unchanged; a prior successful `realloc` may only leave spare capacity.
- Added overflow checks for batch allocation, native-table counts, and allocation sizes.
- Validate every JNI method descriptor with the existing descriptor parser before registration; reject empty names, null function pointers, malformed descriptors, and invalid tables/counts.
- Keep per-registration origin metadata so `UnregisterNatives` removes the matching registration set and increments the method-resolution generation.
- Added source-contract assertions for transaction staging, capacity reservation, descriptor validation, and error paths.

### Commits
- Transactional `RegisterNatives`: `b42e67d4fe3e9e376e5314537ae5f34500a2873c`
- Transactional registration source-contract coverage: `7f9e870afcb1f635fac254c03fe57bbe19157274`
- Integer-limit include for bounded registration tables: `bc9c126e28a2d1af556de2966d48920ab6326a87`
- JNI method descriptor validation: `7221f2d8fadd07c0f951725a41385efcb3fad5f3`
- Descriptor/batch-bound source-contract assertions: `a96b02812e5cfbd3e70f2d7c95274ec9267c56af`

### Integration status and verification
- **Overall Husk source integration estimate: 89%** (previous: 87%; +2 percentage points). This is a source-coverage engineering estimate, not a runtime compatibility score.
- The registration transaction and descriptor checks have source-contract coverage only. **No tests were run and no compilation was performed.** No workflow, IPA build/export, signing, or device test was started.
- Remaining major gaps include raw-pointer JNI local/global/weak reference identity, full embedded-NUL Java string storage, complete ART exception and class-loader semantics, and a genuine NDK NativeActivity input queue.
- SideStore and Strata host architecture remain untouched; Husk license/attribution notices remain intact.

### Next batch toward 90%
- Continue the JNI reference-handle redesign only after mapping all internal raw-pointer consumers and adding a compatibility conversion layer; do not fake `GetObjectRefType` or weak-global semantics.
- Continue auditing DEX interface/class-loader assignability and NativeActivity event delivery; keep unsupported paths explicit until the full contracts exist.

## 2026-11-20 — JNI primitive-array access and release lifecycle

### Implemented on main
- Replaced direct primitive-array element exposure with per-thread tracked copies for all eight JNI primitive array types. `isCopy` is set to true and allocation/size overflow failures are surfaced.
- Implemented `Release<Type>ArrayElements` mode behavior: mode 0 copies back and frees, `JNI_COMMIT` copies back while retaining the buffer for a later release, and `JNI_ABORT` discards and frees.
- Each outstanding element buffer is associated with its exact array, element type, length, and byte size. Mismatched pointers/arrays, invalid release modes, and changed array dimensions are rejected.
- Outstanding ordinary array copies are copied back and freed when the native thread detaches.
- Added tracked `GetPrimitiveArrayCritical` / `ReleasePrimitiveArrayCritical` pairing. The runtime exposes underlying storage (`isCopy=false`) and validates exact array/pointer pairing and release mode; it does not claim a moving-GC pin implementation.
- Fixed transactional native-registration typedef ordering discovered during source audit.
- Added source-contract coverage for ordinary and critical array access lifecycles. The source-contract test was not executed.

### Commits
- Primitive array copy/release implementation and staged-registration declaration-order correction: `01f30a7c263cb7d3aa49c0fcee7961f608730c03`
- Array dimension tracking and release consistency checks: `2691d451fc8e824cf47fc8aa0d7ee2a14d8b0ee5`
- Primitive array source-contract tests and assertion-string cleanup: `059d14d80393a83b8e7122925e27357a6ecb73dd`
- Critical array acquisition/release tracking: `1b9e644360bfe6c0d3e93dd0e76de2e3bb2dc9ce`
- Critical array source-contract assertions: `8d3f5d15a681be9608b88ee08ed0cd8fb730f5e8`

### Integration status and verification
- **Overall Husk source integration estimate: 92%** (previous: 89%; +3 percentage points). This is a source-coverage engineering estimate, not a measured compatibility or runtime-success score.
- The JNI array implementation has source-contract assertions only. No tests or compiler were run; no GitHub workflow, IPA build/export, signing, or device test was started.
- JNI raw-pointer local/global/weak reference identity remains unresolved. Critical-array access tracking does not implement a moving-GC pin. Embedded U+0000 remains unsupported by the internal NUL-terminated guest string representation.
- Genuine NDK `AInputQueue`, full ART exception/class-loader behavior, and remaining Bionic synchronization semantics remain open integration gaps.
- SideStore and Strata host architecture remain untouched; Husk license/attribution notices remain intact.

### Next batch toward 95%
- Audit and implement additional JNI boundary contracts that can be completed without inventing handle identity or ART behavior.
- Continue NativeActivity and Bionic lifecycle gaps only where a real compatible contract can be delivered; retain explicit unsupported behavior otherwise.
- Keep all validation deferred until source integration reaches 100%, then perform the single consolidated test/build/device phase.
- Final source-contract marker audit found and corrected one stale assertion left from the pre-transactional registration implementation (`growing JNI native method table` → `reserving JNI native method table transaction`): `06c4b50ce964f0afa7c61f2d18419a7e85421428`. Marker matching was inspected statically; tests were not run.


## 2026-11-20 — JNI critical primitive-array copy semantics

### Implemented on main
- Replaced the previous direct-array pointer in `GetPrimitiveArrayCritical` with a tracked native copy. `isCopy` now correctly reports true for this implementation.
- Added primitive element-size validation for all eight JNI primitive types and overflow-safe byte sizing before allocation.
- `ReleasePrimitiveArrayCritical` now validates the exact array/pointer pair and implements release modes: mode 0 copies back and frees, `JNI_COMMIT` copies back while retaining the buffer, and `JNI_ABORT` discards changes and frees.
- Copyback verifies that array kind, element type, length, and byte count still match the acquired layout. Outstanding critical copies are copied back and released on thread detach.
- Added source-contract assertions for critical-array copy allocation, copyback, mode behavior, and cleanup.

### Commits
- Critical-array copy, copyback and release-mode implementation: `fb2c25221c88345fdde1ae22f0d4cb33bb484194`
- Critical-array source-contract coverage: `77632deea6cb1294cbd6aae35886d0a1b133c93b`

### Integration status and verification
- **Overall Husk source integration estimate: 93%** (previous: 92%; +1 percentage point). This is a source integration estimate, not a runtime compatibility score.
- Source-contract assertions were added and statically inspected; no tests or compiler were run. No workflow, IPA build/export, signing, or device testing was started.
- This implementation uses a copy rather than a pinned direct pointer. It does not provide moving-GC pin semantics or enforce JNI's restriction against other JNI calls while a critical pointer is held.
- JNI raw-pointer local/global/weak reference identity, embedded-NUL guest strings, genuine NDK `AInputQueue`, and complete ART exception/class-loader behavior remain open.
- SideStore and Strata host architecture remain untouched; Husk license/attribution notices remain intact.

### Next target: 95%
- Audit string critical access pairing and UTF-16 buffer ownership, then implement a robust tracked lifecycle if the current API permits it.
- Continue JNI reference lifecycle only after mapping every internal raw-pointer consumer; do not claim local/global/weak identity until the representation actually supports it.
- Preserve the agreed rule: no test suite, compilation, workflow, IPA build/export, signing, or device testing until source integration reaches 100%.
- Follow-up static marker audit corrected one source-contract string to match the new critical-copy allocation diagnostic (`tracking JNI critical array access` → `allocating JNI critical array copy`): `d6afa7e85d432494ab88e0b59083214200945fbc`. Marker presence was inspected; tests remain unexecuted.


## 2026-11-20 — JNI string character-buffer ownership and release lifecycle

### Implemented on main
- Added a per-thread registry for JNI string character buffers. Each entry records the exact guest string reference, returned buffer pointer, and access kind.
- `GetStringChars` / `ReleaseStringChars` now use tracked UTF-16 copies; release must match the exact string and pointer.
- `GetStringUTFChars` / `ReleaseStringUTFChars` now use tracked Modified UTF-8 copies with the same exact-pair validation.
- `GetStringCritical` / `ReleaseStringCritical` now have their own tracked critical-access kind rather than aliasing the ordinary UTF-16 API. The implementation returns a copy and reports `isCopy=true`; it does not claim a VM/GC pin.
- Invalid cross-string, cross-kind, or already-released buffer pairs are rejected instead of freeing arbitrary pointers. Allocation and tracking failures free temporary buffers and report OutOfMemoryError.
- Outstanding string buffers are released on `DetachCurrentThread`, alongside the existing primitive-array and critical-array cleanup.
- Added a dedicated source-contract test for all three access kinds, exact-pair release, and detach cleanup. Static marker audit found all 16 expected markers.

### Commits
- JNI UTF-16, Modified UTF-8, and critical string buffer tracking: `799d2e9d5328161079a29c69b8c1d366cd8ba932`
- String-buffer lifecycle source-contract coverage: `3c18e046df1de341e44bf81fde8e8902261e908b`

### Integration status and verification
- **Overall Husk source integration estimate: 95%** (previous: 93%; +2 percentage points). This is a source integration engineering estimate, not measured runtime compatibility.
- Static source-contract marker audit: 16/16 markers present. The test was not executed; no compiler was run.
- No GitHub workflow, IPA build/export, signing, or device testing was started. The agreed single consolidated validation phase remains deferred until 100%.
- String critical access uses an allocated copy (`isCopy=true`), not a pinned VM string. JNI restrictions while critical access is held and VM/GC pin semantics remain incomplete.
- JNI raw-pointer local/global/weak reference identity, embedded-NUL guest string storage, genuine NDK `AInputQueue`, and complete ART exception/class-loader behavior remain open integration gaps.
- SideStore and Strata host architecture remain untouched; Husk license/attribution notices remain intact.

### Next target: 97%
- Continue the JNI reference-lifecycle audit only after mapping every raw-pointer consumer and defining safe conversion at all JNI boundaries.
- Audit remaining JNI string region/length and exception edge cases without claiming embedded-NUL support until guest string storage is length-aware.
- Keep all execution-based validation deferred until source integration reaches 100%.

## 2026-11-20 — JNI outstanding string/array owner lifetime and length boundary

### Implemented on main
- JNI string character access records now retain the referenced guest string with `tl_jni_ref` until the matching release or thread detach. Both normal release and detach balance that ownership with `tl_jni_unref`.
- Ordinary primitive-array element-copy records and `GetPrimitiveArrayCritical` copy records now retain their exact guest array for the full outstanding-access lifetime. Normal release and detach balance the retained reference; `JNI_COMMIT` deliberately keeps the record and its owner alive until a final release.
- `GetStringLength` now rejects null/non-string inputs with `NullPointerException` instead of silently reporting an empty string, and checks the UTF-16 length against `jint` range before conversion.
- Added source-contract tests for string owner retention, primitive-array owner retention, matching release/detach cleanup, and UTF-16 length validation.

### Commits
- String access owner retention and `GetStringLength` validation: `0c9315ae7461c14bb1601f1a72c734740900f0eb`
- String owner/length source-contract coverage: `beae6496e30b2e6ef9c682cf0b60c70864908819`
- Primitive-array and critical-array owner retention: `f3c11c603e0e855f294a2cea481898e50d182ee9`
- Array owner-lifecycle source-contract coverage: `d3e97613da67b0cf6a4e762015de3a103b4a383a`

### Integration status and verification
- **Overall Husk source integration estimate: 97%** (previous: 95%; +2 percentage points). This is an engineering estimate of source integration, not measured app compatibility or runtime correctness.
- Static source-contract audit: 6/6 string-owner/length markers, 5/5 array-owner markers, and 16/16 string-buffer lifecycle markers present. This audit only checked source text; tests were not executed.
- No compiler, test suite, workflow, IPA build/export, signing, or device testing was run. The consolidated validation phase remains deferred until 100%.
- The raw-pointer JNI handle representation still cannot distinguish local/global/weak-global handles. Genuine NDK `AInputQueue`, embedded-NUL guest string storage, complete ART exception/class-loader behavior, and true critical-region VM/GC pin semantics remain incomplete.
- SideStore and Strata host architecture remain untouched; Husk license/attribution notices remain intact.

### Next target: 100%
- Complete the remaining JNI reference-handle architecture only after all guest-facing and internal consumers are mapped; do not bolt on wrapper handles without converting every boundary.
- Close the remaining NativeActivity input-queue and ART/JNI lifecycle gaps where the host architecture supports real implementations; explicitly document anything structurally unsupported rather than faking it.
- Continue source-only implementation. Do not run tests, compile, workflows, IPA build/export, signing, or device testing until source integration reaches 100%.

## 2026-11-20 — JNI array-length narrowing guard

### Implemented on main
- `GetArrayLength` now validates the object is an array, reads the guest array length as `size_t`, rejects lengths above `INT32_MAX` with an OutOfMemoryError diagnostic, and only then narrows to JNI `jint`.
- Added source-contract coverage for the length extraction, upper-bound check, diagnostic, and safe return conversion.

### Commits
- JNI `GetArrayLength` range validation: `e8b8b300147325623da2abcb2e0c9772a56f736a`
- Array-length source-contract coverage: `7ee8d2172f9db9caef9a4ca0cada4b6199ed9e01`

### Integration status and verification
- **Overall Husk source integration estimate: 98%** (previous: 97%; +1 percentage point). This remains an engineering estimate of source integration, not measured runtime compatibility.
- Static source-contract audit for the new array-length boundary markers is recorded below; no tests were executed and no compiler was run.
- No GitHub workflow, IPA build/export, signing, or device testing was started. The agreed consolidated validation phase remains deferred.
- The remaining 2% is not merely polish: the JNI object handle representation is still raw `jobj *` and cannot distinguish local/global/weak-global reference identity; genuine NDK `AInputQueue` delivery is not implemented; complete ART exception/class-loader/VM lifecycle semantics and actual GC pinning for critical regions are not present. These must not be reported as complete.
- NativeActivity currently withholds the input-queue callback rather than passing a fake queue. This is safer but leaves games requiring `AInputQueue` unsupported.
- SideStore and Strata host architecture remain untouched; Husk license/attribution notices remain intact.

### Completion gate
- **Do not label Husk integration 100% while the above runtime-facing contracts are absent.** Reaching 100% requires a complete handle representation conversion across all JNI boundaries and a genuine supported NativeActivity input-queue path (or a formally agreed scope exclusion), plus the remaining ART/JNI lifecycle work.
- Continue source-only implementation; no tests, compilation, workflows, IPA build/export, signing, or device testing until the integration scope is genuinely complete.