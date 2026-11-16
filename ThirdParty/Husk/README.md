# Husk upstream source and license record

- Upstream: https://github.com/Leviidev/Husk
- Audited revision: `29abb512d81bf8cc08babcbe7f7007cb557208ef` (2026-11-11)
- Upstream license: GPL-2.0-or-later
- License text: [LICENSE](LICENSE)

Husk-authored files carry their own SPDX and copyright notices. When source files are vendored or modified, preserve those headers and record the exact upstream revision and any local changes. Audit every file for embedded third-party code and dependencies before inclusion.

The upstream `src/translation-layer-next` directory is a native Android translation runtime, not a self-contained drop-in library. It depends on a larger set of runtime files, platform frameworks, generated Java framework/DEX assets, ANGLE and other resources. Its upstream XcodeGen project compiles the directory as a unit and links additional Apple system frameworks and libraries. Do not copy a small handful of C files and claim the runtime is integrated.

**Current INFINITY status:** the Husk source has been audited and its license text pinned here, but the native runtime source has not yet been vendored or compiled into INFINITY. The APK archive/manifest inspection code currently in INFINITY is original INFINITY code, not copied from Husk.

Before distributing an IPA containing Husk-derived code, provide the complete corresponding source and license notices required by the applicable GPL terms. Review the combined licensing of the Strata base and any optional QEMU components before distribution; do not assume that merely keeping code in separate folders resolves license compatibility.
