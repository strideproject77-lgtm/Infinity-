# Cross-platform core policy

INFINITY is an iOS application, not a promise that the complete iOS host can be built on Linux.
The portable APK-processing core is kept in shared source and is checked on both supported
development environments with the same script:

- `INFINITYAPKManifest.swift` and `INFINITYAPKInspection.swift` use Foundation APIs and
  must remain type-checkable with Swift on Linux and macOS.
- `INFINITYAPKArchive.c` and its public C headers use portable C/POSIX interfaces and
  must remain syntax-checkable with Clang on Linux and macOS.
- Platform-specific host behavior (SwiftUI, UIKit, Security-scoped file access, iOS
  entitlements, signing, extensions and the iOS archive) stays behind platform boundaries
  and is validated with Apple's toolchain on macOS.

## Commands

Run the same portable checks locally on either OS:

```sh
bash scripts/test-portable-core.sh
```

Ubuntu is the default continuous-integration runner to avoid unnecessary macOS queue delays.
The macOS equivalent is available as a manual GitHub Actions workflow dispatch. It runs the
same script against the same checked-out source; it is not a substitute for an iOS/Xcode archive
build. Do not start a Codemagic archive merely because the portable checks pass.
