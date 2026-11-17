# Third-party notices — Husk runtime

INFINITY vendors selected source from [Leviidev/Husk](https://github.com/Leviidev/Husk), pinned initially to commit `29abb512d81bf8cc08babcbe7f7007cb557208ef`.

Husk is licensed under **GNU General Public License v2.0 or later**. The import pipeline preserves the upstream `LICENSE`, licensing guide, and original source headers in `Vendor/Husk/`. Any distributed derivative must satisfy the applicable GPL source, notice, and license obligations.

This notice is not a substitute for auditing each imported file and every transitive dependency. Some components may have separate provenance, notices, or licensing terms. Do not redistribute files whose origin or terms have not been verified.

Imported source is not yet a compiled or working runtime merely because it is present in the repository.

## Android framework build sources

The pinned Husk snapshot also includes `src/java-framework/` and `src/art-support/` as build inputs for the Java translation runtime:

- `src/java-framework/src/` is Husk's handwritten Java framework implementation and remains covered by the upstream Husk GPL-2.0-or-later license.
- `src/java-framework/gen-src/` contains generated Java signatures and constants extracted from an Android platform `framework.jar`; the generated methods are stubs and do not contain the platform's method implementations. Preserve this provenance. The originating Android platform APIs are distributed under AOSP/Android licensing (primarily Apache-2.0 for platform source); the exact Lineage image/framework version and corresponding notices must be pinned before redistributing generated payloads.
- `src/java-framework/stubs/` contains compile-time interface copies for libcore APIs. Their source provenance is distinct from Husk-authored runtime code and remains part of the license review.
- `tools/compat/` and `tools/strip_framework_res.py` are upstream GPL-2.0-or-later build tools. They are retained with their upstream headers.
- `src/art-support/libartpalette-system.c` is an Android guest-side support library source, not an iOS host library.

The runtime asset build recipes consume a matching Lineage system image/APEX tree, framework resources, Apache HttpClient legacy jar, JDK and R8/D8. Those generated binary assets are not present merely because the source trees are vendored. Do not bundle third-party APEX, framework jars, fonts, certificates or generated payloads until their exact origin, version, license and redistribution notices have been verified.
