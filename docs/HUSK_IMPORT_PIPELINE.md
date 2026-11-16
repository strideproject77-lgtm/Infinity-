# Husk runtime import pipeline

This pipeline makes the selected Husk runtime source available to INFINITY in one repeatable operation. It is a **source-vendoring step**, not a claim that the runtime is already compiled or executable.

## Import

From the INFINITY repository root on a machine with Git:

```sh
bash scripts/import_husk_runtime.sh
```

The script fetches the exact audited Husk revision and copies only:

- `src/translation-layer-next/`
- Husk's root `LICENSE`
- Husk's `docs/01-licensing.md`

The result is placed under `Vendor/Husk/`, outside Strata's synchronized Xcode source groups. This prevents an unreviewed 126-file import from being compiled into the app automatically.

## Refresh

The importer refuses to overwrite an existing vendor tree by default. After reviewing the new upstream revision and changing the pinned revision in the script deliberately, run:

```sh
bash scripts/import_husk_runtime.sh --refresh
```

Review the complete vendor diff before accepting it. Do not point the script at a moving branch or tag.

## Integration workflow

1. Import the pinned source snapshot.
2. Inventory every source/header/include file and retain its original copyright and SPDX header.
3. Build a dependency map for each selected subsystem (ELF loader, Bionic, JNI, DEX/ART, Binder, graphics, audio).
4. Check all transitive third-party licenses and platform-derived provenance; the root Husk license alone does not replace component-specific notices.
5. Select a coherent dependency-complete batch. Do not cherry-pick isolated C files whose internal headers or callbacks are missing.
6. Port Apple-specific code and build settings separately. Keep imported sources outside Xcode target membership until reviewed.
7. Add the selected files to an isolated INFINITY runtime target/module; never modify SideStore targets, packaging, signing, refresh or installation flows.
8. Compile and run consolidated host tests, then an iOS build only when separately authorized. Test 2048 first, then Hill Climb Racing.
9. Record exact upstream revision, imported paths, notices, test evidence and blockers in `INFINITY_HANDOFF.md`.

## Exclusions

This importer intentionally does not copy Husk's app/UI, QEMU source tree, guest images, build scripts, packaging scripts, signing workflows, generated binaries, or unrelated tools. QEMU remains a separately evaluated optional backend.

## Safety

- The pinned revision is `29abb512d81bf8cc08babcbe7f7007cb557208ef`.
- The script uses `git archive` at that exact commit; it does not execute upstream scripts.
- The destination is `Vendor/Husk/`, not `LiveContainerSwiftUI/` and not `SideStoreSupport/`.
- Importing source does not mean it is build-ready, linked, licensed for every bundled dependency, or capable of running APKs.
