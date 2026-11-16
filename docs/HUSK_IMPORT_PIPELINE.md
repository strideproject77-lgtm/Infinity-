# Husk runtime import pipeline

This pipeline imports the pinned native translation engine together with the selected iOS host-side runtime code and the upstream build recipes that produce required Android runtime data. It is a **source-vendoring and audit step**, not a claim that the runtime is compiled or executable.

## Pinned source snapshot

The importer fetches exact Husk revision 29abb512d81bf8cc08babcbe7f7007cb557208ef and copies:

- src/translation-layer-next/ — native runtime, ELF loader, Bionic, JNI, DEX/Dalvik, Binder, engine bridges, EGL/GLES, audio and input.
- Selected host runtime files: TLUnityView.swift, TLAppSettings.swift, HuskGamepad.swift, HuskKeyboard.swift, HuskLog.swift and HuskFilePicker.swift.
- Runtime build recipes: build_java_runtime.sh, build_android_system.sh, build_angle_ios.sh and build_art_support.sh.
- Technical and licensing documentation needed to understand those components.

The result is placed under Vendor/Husk/, outside Strata's synchronized Xcode source groups. The importer does not add source files to any Xcode target.

## Import

From the INFINITY repository root:

```sh
bash scripts/import_husk_runtime.sh
```

The GitHub Actions equivalent is available from Actions → Import Husk Runtime Sources → Run workflow on main. Leave refresh=false for the first import. The workflow commits the vendored source and generated audit to main.

## Refresh

The importer refuses to overwrite an existing native source tree by default. After reviewing upstream changes and deliberately changing the pinned revision in the script, run:

```sh
bash scripts/import_husk_runtime.sh --refresh
```

Only importer-owned paths are replaced. INFINITY-owned files such as Vendor/Husk/THIRD_PARTY_NOTICES.md are preserved.

## What is deliberately excluded

- Husk's @main app entry point and complete app/catalog UI.
- QEMU source, QEMU runner, guest images, kernels, firmware, qcow2 disks and guest staging.
- Husk's complete XcodeGen project and QEMU-linked build configuration.
- JIT helper extension, pairing/signing/refresh/install flows and unrelated app features.
- Prebuilt binaries and generated Android runtime payloads.

QEMU remains a separate optional backend decision. The native translation layer is the primary integration path; ANGLE/GLES, Java runtime assets, Android system fonts/certificates and Vulkan/MoltenVK are separately audited dependencies. The included build recipes are retained for review, not executed by the importer.

## Integration workflow

1. Import the pinned source snapshot.
2. Review the generated file-level manifest, SPDX markers, quoted includes and Swift framework imports.
3. Resolve native symbols, compiler flags, frameworks, deployment-target constraints and Swift type dependencies.
4. Audit every selected file and transitive dependency's license/provenance. The root Husk license does not replace component-specific notices.
5. Build an isolated runtime target/module. Keep vendor sources outside synchronized Strata source groups until the target is dependency-complete.
6. Adapt only the Apple host boundary and Strata lifecycle integration; keep upstream runtime implementation intact wherever possible.
7. Connect the engine's real APK discovery, native library, DEX, Java runtime data, graphics, audio and input paths to Strata's APK records and app screen.
8. Preserve all existing Strata targets and the built-in SideStore. Do not alter SideStoreSupport, signing, refresh, installation, entitlements or packaging.
9. Run one consolidated test pass after the integration batch. No compatibility status is granted by import, parsing or compilation alone; real APK execution is required.
10. Update INFINITY_HANDOFF.md with exact revision, source groups, tests and blockers.

## Audit limitations

scripts/audit_husk_runtime.py inventories imported source groups, source types, SPDX identifiers, quoted includes, system header includes and Swift imports. It is not a compiler, full symbol resolver, legal opinion or proof of runtime compatibility. Missing generated headers, conditional includes, linker symbols, runtime resources, and transitive dependencies still require review.

## Safety

- The pinned revision is 29abb512d81bf8cc08babcbe7f7007cb557208ef.
- The importer uses git archive from that exact commit and does not execute upstream scripts.
- The destination is Vendor/Husk/, not LiveContainerSwiftUI/ or SideStoreSupport/.
- The importer workflow does not invoke the IPA builder.
- No IPA build, signing or export is performed by this pipeline.
