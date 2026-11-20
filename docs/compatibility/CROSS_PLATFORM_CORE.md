# Cross-platform core policy

INFINITY is an iOS application; this policy does not claim that the complete iOS host can be
built on Linux. The portable APK-processing core is maintained as shared source and checked
with the same script on Linux and macOS.

- `INFINITYAPKManifest.swift` and `INFINITYAPKInspection.swift` use Foundation APIs and
  must remain type-checkable with Swift on Linux and macOS.
- `INFINITYAPKArchive.c` and its public C headers use portable C/POSIX interfaces and
  must remain syntax-checkable with Clang on Linux and macOS.
- SwiftUI, UIKit, security-scoped file access, iOS entitlements, signing, extensions and the
  iOS archive remain Apple-platform concerns and require Apple's toolchain on macOS.

## Run locally

```sh
bash scripts/test-portable-core.sh
```

Ubuntu 24.04 is the default continuous-integration runner to avoid routine macOS queue delays.
The macOS equivalent is available through manual GitHub Actions dispatch and runs the exact
same script. Passing these portable checks is not proof of a successful iOS/Xcode archive;
do not trigger a Codemagic archive solely because these checks pass.
