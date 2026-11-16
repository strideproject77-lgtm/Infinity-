undefined

## IPA builder and language audit — 2026-11-16

- Confirmed the existing IPA builder is present at `.github/workflows/build.yml`; no replacement builder is needed.
- It uses Xcode 27.2, `xcodebuild archive`, the `LiveContainer` scheme, iOS device ARM64 Release, then `.github/build_github.sh` packaging. It is manually dispatched and publishes LiveContainer and LiveContainer+SideStore artifacts plus an archive.
- The packaging script contains SideStore-specific packaging and metadata operations. Because SideStore is protected, this script and its workflow were not modified or run. No IPA was built, signed, or exported.
- Language decision: Swift for Strata/UI and orchestration; C for Husk translation runtime; Objective-C/Objective-C++ for Apple/native bridging; C++ only where required by dependencies such as QEMU. Existing Xcode builder supports this mixed-language project; new source membership and linker settings still require a target-by-target audit.
- Added `docs/INFINITY_BUILD_PIPELINE.md` with the builder audit, language decision, and SideStore-safe integration rules.
- Tests: repository/workflow/source inspection only. No Xcode compile, IPA build, simulator run, device run, or APK execution test.
- SideStore: untouched.
- Blockers: per-file Husk license/provenance audit; selected runtime dependency graph; safe Xcode target membership; native framework/linker configuration; QEMU dependency and guest-image assessment.
