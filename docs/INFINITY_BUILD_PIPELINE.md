# INFINITY Build Pipeline and Language Plan

Updated: 2026-11-16

## Decision

Use the languages already suited to each layer instead of forcing the whole app into one language:

- **Swift** for Strata's iOS app, launcher, settings, app records, import flow, and runtime orchestration.
- **C** for Husk translation-layer components that are authored in C (DEX/ART-adjacent runtime, ELF loader, Bionic and JNI compatibility layers).
- **Objective-C / Objective-C++** for narrow Apple-framework and Swift/native boundaries where required.
- **C++** for dependencies that require it, including QEMU and selected native libraries. Expose only small stable C-compatible interfaces to Swift where practical.

This matches the existing Strata/Xcode application and minimizes unnecessary rewrites. It also lets the project retain Husk's native runtime implementation and its required notices rather than translating it into Swift.

## Existing IPA builder audit

The repository already has an iOS IPA build pipeline; a new builder is not required at this stage.

- Workflow: `.github/workflows/build.yml`
- Build system: Xcode / `xcodebuild archive`
- Xcode selected by workflow: 27.2
- Build target scheme: `LiveContainer`
- Target platform/architecture/configuration: iOS device, ARM64, Release
- Packaging script: `.github/build_github.sh`
- Trigger: manual `workflow_dispatch`
- Artifacts: `LiveContainer.ipa`, `LiveContainer+SideStore.ipa`, and an Xcode archive tarball.

The workflow already uses Xcode, which supports Swift, C, Objective-C, Objective-C++, and C++ in one project. Source-file extensions and target membership determine the compiler; there is no separate Swift-only or C++-only IPA builder to install.

## SideStore protection / build constraint

The existing packaging script contains SideStore-specific packaging operations: it temporarily moves SideStoreSupport, edits SideStore-related app metadata, downloads and embeds the SideStore app, transforms its executable, and packages a second SideStore IPA.

The project owner has explicitly protected built-in SideStore. Therefore:

- Do not edit `.github/build_github.sh`, SideStore packaging steps, SideStore targets, entitlements, framework embedding, signing/refresh/install paths, or dependencies.
- Do not run the existing workflow as part of this work without explicit IPA build/export permission.
- Do not change the workflow merely to simplify Android integration.
- Keep Android build steps isolated from SideStore.
- Before any future builder change, prove it does not alter the existing SideStore output or protected source/configuration. If this cannot be established, stop and ask.

## How the existing builder will support Husk / Stride

The current Xcode workflow can compile newly integrated native sources once they are correctly included in the intended app target and their required headers, frameworks, and libraries are configured. That does not mean the current project is already configured for every Husk or QEMU dependency.

Before changing build settings:

1. Complete the per-file license/provenance and dependency audit for the selected Husk runtime revision.
2. Identify which C/Objective-C sources can join the existing synchronized source group without changing SideStore target membership.
3. Identify C++ and Objective-C++ requirements, compiler standard, ARC/exception settings, and required iOS frameworks.
4. Keep QEMU as a separately built/linkable component. If its build or guest-image staging would delay the first usable release, isolate that work rather than blocking the native Husk runtime; include it sooner only where it materially improves the release target.
5. Make only narrowly scoped Xcode project changes after auditing all target effects, especially SideStore.
6. Validate compilation in CI only after the project owner authorizes an IPA build/export workflow run. A source audit is not a successful build.

## Current result

- IPA builder: **already present**; no new builder installed.
- Language decision: **Swift + C + Objective-C/Objective-C++ + C++ where required**.
- Builder configuration changed in this batch: **none**. The existing workflow already invokes Xcode and supports the selected language mix; runtime source membership and native dependency settings are not yet ready to configure safely.
- IPA build/export run: **not performed**.
- SideStore: **untouched**.
