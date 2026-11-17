# ANGLE iOS arm64 prebuilt

Built from the pinned WebKit/ANGLE source revision recorded in WEBKIT_REVISION.txt
by .github/workflows/infinity-husk-angle.yml. LICENSE-ANGLE.txt is retained beside
the binary. This is a dynamically loaded iOS arm64 library, not an IPA.
The Strata app target must embed it in Frameworks with CodeSignOnCopy.
