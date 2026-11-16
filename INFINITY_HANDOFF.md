# INFINITY Handoff

Last updated: 2026-11-16

## Project direction

INFINITY combines the existing Strata iOS host/launcher with Husk-derived Android execution capabilities. The project owner has approved including QEMU if it improves coverage or avoids blocking work. The architecture will support two isolated Android backends: a native translation runtime for direct APK execution, and an optional QEMU Android-guest backend where required. APK and IPA imports must appear together in one Home Screen and unified Library; the runtime is selected internally when an app launches. Store/catalog work is planned for both IPA and APK apps.

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
- Husk's upstream repository is GPL-2.0-or-later. The project owner approved evaluating and including QEMU. QEMU is an optional compatibility backend, not a presumed performance shortcut: it emulates a full Android guest on iOS devices without a usable hardware hypervisor and can require multi-gigabyte guest assets. Keep native translation and QEMU guest execution isolated so APKs can use the appropriate backend.
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
- QEMU is now permitted as an optional backend. Audit its build, iOS threading, display/input/audio bridge, guest-image distribution, memory requirements, and shutdown lifecycle separately from the native translation runtime.
- Do not make QEMU the default APK path or claim it improves speed. Benchmark native translation and guest emulation independently on supported devices.
- Keep QEMU guest images optional and downloadable only with clear storage/network warnings; never bundle multi-gigabyte images by default.
- Preserve upstream copyright headers, GPL notices, and all third-party licenses.
- Do not import unlicensed wrappers or files with unclear provenance.
- Integrate the selected source into the Xcode project/build system and document the pinned upstream revision.

### Phase 2 — APK intake and analysis
Status: not started.

- Import APKs without confusing them with IPA packages.
- Parse APK ZIP entries, manifest, DEX files, ABI folders, ELF metadata, and 16 KiB page requirements.
- Extract app name/icon/version/package ID for the unified Home Screen.
- Report unsupported ABIs and missing runtime features honestly.

### Phase 3 — Java/DEX execution
Status: not started in INFINITY.

- Port ART/Dalvik execution components selected from the QEMU-free runtime.
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
- UIKit/Metal/CoreAudio integration; no Android guest OS.

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

## Current batch report

- Runtime changes: added an isolated backend registry contract for native translation and QEMU guest backends. Both default to Not integrated; selection cannot report a backend as ready until an implementation explicitly registers readiness.
- UI/UX changes: none in this batch; no placeholder runtime UI was added.
- Extra features: documented dual-backend architecture, optional QEMU guest handling, storage/performance implications, and integration boundaries.
- Tests: source and repository structure inspected; no Xcode build, simulator run, device run, or APK execution test performed. IPA build/export remains unauthorized.
- SideStore: protected paths, targets, entitlements, and workflows were not modified.
- Blockers: full source/provenance and license review; actual engine source integration; QEMU build/guest/graphics/audio bridge; test access to a real device. Existing Strata AGPL-3.0 and imported GPL/QEMU components require documented compatibility review before combining or redistributing binaries.
- Actual progress: Phase 0 complete. Phase 1 has source inventory, dual-backend design, and registry foundation committed; native and QEMU engine integration remain incomplete.
