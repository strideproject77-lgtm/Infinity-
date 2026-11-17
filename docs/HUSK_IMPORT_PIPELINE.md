# Husk runtime import pipeline

This pipeline vendors Husk's native translation engine, its legacy host-facing C API dependency, selected iOS host-side runtime code, and the build recipes/resources needed to audit a full translation-layer integration. It is a **source-vendoring and audit step**, not a claim that the runtime is compiled or executable.

## Pinned source snapshot

The importer fetches exact Husk revision 29abb512d81bf8cc08babcbe7f7007cb557208ef and copies:

- src/translation-layer-next/ — primary native runtime: DEX/Dalvik, ARM64/ARM32, ELF, Bionic, JNI, Binder, graphics and engine bridges.
- src/translation-layer/ — retained because selected upstream Swift host code still calls its attempt/check APIs. This legacy tree is a host dependency, not a replacement for translation-layer-next.
- Selected host runtime files: TranslationLayer.swift, TLUnityView.swift, TLAppSettings.swift, AppWindows.swift, HuskGamepad.swift, HuskKeyboard.swift, HuskAudio.swift, HuskLog.swift and HuskFilePicker.swift.
- HuskApp.swift under host-reference/ only. It contains an @main app entry point and must never be compiled into Strata.
- The Java framework implementation sources under src/java-framework/src/, compile-time stubs, generated Android platform signature/constant stubs under gen-src/, and the GLES/API generators.
- The Android guest-side ART support source under src/art-support/.
- Runtime asset build helpers: tools/strip_framework_res.py, tools/compat/, and scripts/copy_aosp_bundle.sh.
- The upstream CA certificate resource, selected Java/Android-system/ANGLE/ART build recipes, technical docs and licensing guide.

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

- QEMU source, QEMU runner, guest images, kernels, firmware, qcow2 disks and guest staging.
- Husk's complete XcodeGen project and QEMU-linked build configuration.
- JIT helper extension, pairing/signing/refresh/install flows and unrelated app features.
- Prebuilt QEMU binaries and generated Android runtime payloads.

QEMU remains a separate optional backend decision. The native translation layer is the primary path; ANGLE/GLES, Java runtime assets, Android system fonts/certificates and Vulkan/MoltenVK are separately audited dependencies. The included build recipes are retained for review, not executed by the importer. The Java runtime build requires a matching Lineage system image/APEX tree, JDK, R8/D8 and framework resources; source import alone does not generate the runtime payload.

## Integration workflow

1. Import the pinned source snapshot.
2. Review the generated manifest across both C trees, host-runtime sources, host-reference, resources, build recipes and docs.
3. Resolve the legacy-vs-next API relationship. Do not assume translation-layer-next alone satisfies all host calls.
4. Resolve native symbols, compiler flags, frameworks, deployment-target constraints and Swift type dependencies.
5. Audit every selected file and transitive dependency's license/provenance. The root Husk license does not replace component-specific notices.
6. Build an isolated runtime target/module. Keep vendor sources outside synchronized Strata source groups until the target is dependency-complete.
7. Extract/adapt the minimal window and orientation host boundaries; never compile HuskApp.swift or import Husk's full app UI.
8. Connect real APK/split-APK paths, runtime data, native libraries, DEX execution, graphics, audio and input to Strata's app lifecycle.
9. Preserve all existing Strata targets and the built-in SideStore. Do not alter SideStoreSupport, signing, refresh, installation, entitlements or packaging.
10. Run consolidated compile and real-device tests. Import, parsing or compilation alone does not establish playable compatibility.
11. Update INFINITY_HANDOFF.md with exact revision, source groups, tests and blockers.

## Audit limitations

scripts/audit_husk_runtime.py inventories imported native/Java source groups, generated platform stub provenance, SPDX identifiers, quoted includes, system header includes and Swift imports. It is not a compiler, full symbol resolver, legal opinion or proof of runtime compatibility. Missing generated headers, conditional includes, linker symbols, runtime resources and transitive dependencies still require review.

## Safety

- The pinned revision is 29abb512d81bf8cc08babcbe7f7007cb557208ef.
- The importer uses git archive from that exact commit and does not execute upstream scripts.
- The destination is Vendor/Husk/, not LiveContainerSwiftUI/ or SideStoreSupport/.
- The importer workflow does not invoke the IPA builder.
- No IPA build, signing or export is performed by this pipeline.
