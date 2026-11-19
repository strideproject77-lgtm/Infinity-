# INFINITY 1.0

INFINITY is an iOS app-hosting and app-management project built on the LiveContainer foundation. It preserves the existing iOS app workflow and integrates the Husk Android translation runtime so Android APKs can be imported, inspected, managed and launched through the same host.

<p align="center"><img src="Resources/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png" width="160" alt="INFINITY app icon"></p>

## Core areas

- **iOS app hosting:** retain the existing LiveContainer-based IPA/TIPA management and launch architecture.
- **Android app library:** import APK, XAPK, APKS and APKM packages, inspect package metadata and persist installed Android app entries alongside IPA entries.
- **Husk runtime:** native runtime dispatch and Java/ART startup are wired into the INFINITY launch path. Runtime/API coverage and real-device compatibility remain under active development.
- **Launcher interfaces:** retain the existing home, library, multitasking, JIT and app-management features from the host foundation.
- **Diagnostics:** per-session logs record launch preparation, runtime state, errors and available frame-performance measurements.

## Android execution status

APK import and the INFINITY-to-Husk launch path are present in source. Split packages are extracted and stored, but launch remains blocked for apps that require split APKs until the runtime can load the complete package set safely. Do not treat a successful import or static inspection as proof that an APK runs.

Compatibility is tested in priority order: **2048 first, then Hill Climb Racing**, followed by additional real APKs. No game should be described as compatible until it has been tested on a built app and the result has been recorded.

## Upstream components and licensing

INFINITY builds on and redistributes upstream components, including LiveContainer and SideStore-related support, and incorporates Husk source. Their required licenses, copyright notices, attribution and third-party notices are retained. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), the upstream license files and pinned provenance records. INFINITY branding does not imply ownership of upstream projects.

## Build

Use the repository's existing GitHub Actions build pipeline and the documented Codemagic path only after the source is prepared and the relevant build is explicitly authorized. No IPA build, signing or export is started by this branding change.

For a local source build, use the existing Xcode project and scheme:

```sh
git clone --recurse-submodules https://github.com/strideproject77-lgtm/Infinity-.git
cd Infinity-
python3 Scripts/fetch-bundled-dependencies.py
xcodebuild -project LiveContainer.xcodeproj -scheme LiveContainer \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

The Xcode target, executable name, bundle identifier, app-group identifiers and existing data locations are intentionally preserved for compatibility with the hosting architecture and existing user data. The installed app's display name and marketing version are **INFINITY 1.0**.
