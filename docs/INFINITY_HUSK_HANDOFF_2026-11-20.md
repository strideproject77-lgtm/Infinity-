# INFINITY × Husk integration handoff — 2026-11-20

## Current checkpoint

- Working branch: `agent/husk-56-70-20261120`
- Base commit: `e0a317ac588c6cb8de7074750f454078251b4982`
- Current head: `d28d13ed70157c54cf0171507b085044aef4cf71`
- Branch is 11 commits ahead of the base and 0 commits behind it.
- Estimated Husk integration coverage: **68%**. This is source/integration coverage, not APK or game compatibility.
- `main` was not modified. SideStore files and integration were not changed.
- No IPA build, Codemagic run, device launch, or game test was started. Regression tests were added but deliberately not executed.

## Implemented in this batch

1. APK ZIP inspection now rejects duplicate paths, traversal/dot/empty path segments, control characters, and ZIP encryption variants.
2. XAPK/APKS/APKM split validation now reads the manifest split name and rejects duplicate split identities.
3. Runtime assets can be imported from either the prepared folder or `infinity-android-runtime-assets.zip`.
4. Runtime ZIP extraction is restricted to the expected Java/system payload paths, with an 8 GiB aggregate limit, 1 GiB per-file limit, and a 4 MiB manifest limit.
5. The runtime asset builder writes a SHA-256 inventory for every required payload file. ZIP import validates the inventory, file sizes, and hashes before installation. Folder import validates the inventory when a manifest is present; legacy folders without a manifest remain accepted.
6. Runtime replacement uses staging and rollback. If rollback itself fails, a non-empty recovery backup is preserved rather than deleted.
7. Husk launch, split queuing, split clearing, and stop are serialized through a lifecycle mutex. A rejected launch always resets the failed global Husk session, including launches without split APKs.
8. Swift runtime stop is idempotent while teardown is already running.
9. JNI weak-reference processing snapshots targets under the registry lock and calls the collector mark callback after releasing that lock. Allocation failure fails closed and leaves weak references intact.
10. Regression contract tests were added for these changes, but were not run per the requested single-test policy.

## Audit findings still open

- DVM still rejects `invoke-custom` (0xfc/0xfd) and `const-method-handle/type` (0xfe/0xff); parts of MethodHandle and VarHandle remain unsupported.
- Weak JNI references still use conservative retention until the complete object-handle/collector integration is ready. The weak-GC change above is lock-safety hardening, not full JNI/GC completion.
- Android framework/Binder APIs and native-method coverage remain partial; some unsupported paths can still cause application features to fail.
- The repository/project tree has no tracked MoltenVK binary or build integration. The Unreal launch path requires MoltenVK, so that engine remains blocked until the dependency is integrated and signed.
- ZIP64 is not supported by the current archive inspector/extractor.
- Runtime Java/system assets are imported data, not embedded in the IPA. ANGLE is app-bundled; MoltenVK is currently absent.
- End-to-end engine launch and game compatibility remain unverified (0% verified); source compilation checks from the earlier checkpoint do not prove successful runtime execution.

## Next implementation sequence

1. Finish DEX invoke-custom / method-handle support or implement explicit safe capability rejection with diagnostics where upstream semantics are not ready.
2. Complete JNI guest-handle resolution, weak-reference lifecycle, and collector root/safepoint integration; do not enable weak GC prematurely.
3. Audit and implement missing Android framework/native APIs needed by real applications, prioritizing Activity lifecycle, PackageManager/resources, content/document access, permissions, and Binder service responses.
4. Add a reproducible MoltenVK iOS arm64 build/sign/embed pipeline and verify the Xcode project embeds the resulting framework before advertising Unreal readiness.
5. Continue ELF/Bionic relocation, TLS, symbol-version, and native-engine edge-case audit.
6. Finish source-only regression coverage. Do not run repeated tests or build an IPA during implementation.
7. Only when Husk integration reaches 100%, perform one consolidated source/CI validation pass, then one IPA build and the agreed single device test cycle.

## Audit scope and honesty

The repository tree was inventoried and the main integration-critical Swift, C, DEX, JNI, linker, runtime-asset, project, and workflow paths were inspected in depth. This was not a manual line-by-line review of every vendored upstream file. Do not describe all upstream files as bug-free or claim all games are supported without real launch evidence.
