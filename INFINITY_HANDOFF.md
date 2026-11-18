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
