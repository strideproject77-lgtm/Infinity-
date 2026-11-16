# Husk source and host integration audit

> Inventory only. This does not prove compilation, linking, complete license compatibility, or APK execution.

- Total imported files: **169**
- Native C/Objective-C/C++/assembly sources: **96**
- Swift host-runtime sources: **10**
- Headers/includes: **53**
- Build recipes: **4**
- Technical/licensing documents: **4**
- Files without SPDX identifier in first 8 KiB: **13**
- Quoted includes with no matching local basename: **1**

## Imported groups

- translation-layer/
- translation-layer-next/
- host-runtime/
- host-reference/
- build-support/
- upstream-docs/
- resources/

## Swift module imports

- AVFoundation: 2
- Darwin: 1
- Foundation: 2
- GameController: 1
- QuartzCore: 1
- SwiftUI: 7
- UIKit: 7
- UniformTypeIdentifiers: 3
- os: 1

## System header includes

- Accelerate/Accelerate.h: 1
- AudioToolbox/AudioToolbox.h: 3
- CommonCrypto/CommonDigest.h: 2
- CommonCrypto/CommonHMAC.h: 1
- CoreFoundation/CoreFoundation.h: 6
- CoreGraphics/CoreGraphics.h: 3
- CoreMedia/CoreMedia.h: 1
- CoreText/CoreText.h: 2
- CoreVideo/CoreVideo.h: 1
- ImageIO/ImageIO.h: 2
- Security/Security.h: 2
- TargetConditionals.h: 12
- VideoToolbox/VideoToolbox.h: 1
- alloca.h: 1
- arpa/inet.h: 4
- assert.h: 1
- crt_externs.h: 2
- crtdbg.h: 1
- ctype.h: 2
- dirent.h: 6
- dispatch/dispatch.h: 1
- dlfcn.h: 13
- errno.h: 25
- execinfo.h: 1
- fcntl.h: 18
- fnmatch.h: 1
- getopt.h: 1
- ifaddrs.h: 2
- inttypes.h: 2
- libgen.h: 1
- libkern/OSCacheControl.h: 6
- limits.h: 4
- locale.h: 1
- mach-o/dyld.h: 1
- mach-o/fat.h: 1
- mach-o/fixup-chains.h: 1
- mach-o/getsect.h: 1
- mach-o/loader.h: 2
- mach/mach.h: 8
- mach/mach_time.h: 3
- mach/mach_vm.h: 1
- mach/thread_policy.h: 1
- mach/vm_map.h: 4
- malloc.h: 1
- malloc/malloc.h: 1
- math.h: 15
- net/if.h: 3
- netdb.h: 1
- netinet/in.h: 3
- netinet/tcp.h: 1
- os/proc.h: 4
- poll.h: 2
- pthread.h: 58
- regex.h: 1
- resolv.h: 1
- sched.h: 5
- search.h: 1
- semaphore.h: 1
- setjmp.h: 5
- signal.h: 11
- sqlite3.h: 1
- stdarg.h: 17
- stdatomic.h: 33
- stdbool.h: 63
- stddef.h: 26
- stdint.h: 61
- stdio.h: 72
- stdlib.h: 85
- string.h: 95
- strings.h: 4
- sys/event.h: 1
- sys/file.h: 1
- sys/ioctl.h: 2
- sys/mman.h: 8
- sys/mount.h: 3
- sys/resource.h: 1
- sys/select.h: 2
- sys/socket.h: 1
- sys/stat.h: 27
- sys/statvfs.h: 1
- sys/sysctl.h: 3
- sys/time.h: 6
- sys/times.h: 1
- sys/types.h: 1
- sys/ucontext.h: 3
- sys/uio.h: 2
- sys/un.h: 1
- sys/utsname.h: 1
- sys/wait.h: 1
- time.h: 33
- unistd.h: 50
- utime.h: 1
- wchar.h: 3
- wctype.h: 1
- xlocale.h: 2
- zlib.h: 6

## Unresolved quoted includes

- host-reference/HuskBridge.h: HuskRPPairing.h

## Files without SPDX markers

- build-support/build_android_system.sh
- build-support/build_angle_ios.sh
- build-support/build_art_support.sh
- build-support/build_java_runtime.sh
- build-support/project.yml
- resources/cacert.pem
- translation-layer/stb_vorbis.inc
- translation-layer-next/husk-console-abi.h
- translation-layer-next/husk-jit-arena.h
- translation-layer-next/husk-tl-codesign-wwdr.inc
- upstream-docs/00-architecture.md
- upstream-docs/04-translation-layer.md
- upstream-docs/05-translation-layer-milestone2-handoff.md

## Integration gates

- Keep the vendor snapshot outside Strata's synchronized Xcode source groups until a dedicated runtime target is reviewed.
- host-reference/ is source-audit material only; never add HuskApp.swift or its @main entry point to Strata's target.
- host-reference/HuskBridge.h is also audit-only: it declares QEMU/JIT interfaces and includes Husk-only pairing headers; create an INFINITY-owned translation-layer bridge instead.
- build-support/project.yml records upstream source membership, frameworks and resource requirements; it is a reference, not a replacement for Strata project settings.
- Do not import QEMU guest orchestration, QEMU binaries, signing/refresh systems, or Husk's complete XcodeGen project.
- Review every file's provenance and license, including embedded .inc data and generated assets; absence of an SPDX marker is not proof of an incompatible license.
- Resolve all native symbols, framework/linker requirements, deployment-target constraints, Swift type dependencies, resources, and runtime data before adding target membership.
- The legacy translation-layer/ tree is included because the selected Swift host sources still reference its attempt/check APIs; do not assume translation-layer-next alone satisfies the host dependency graph.
- The native runtime's ANGLE/GLES, Java runtime assets, system fonts/certificates, Vulkan/MoltenVK path, and engine-specific bridges are separate dependency groups; do not mark an engine ready until its required assets are present.
- Vendor inventory does not imply build membership: host-reference/, resources/, and all source groups remain outside Xcode targets until a separate reviewed integration step.
- Preserve Strata and SideStore target memberships, entitlements, signing/refresh/install flows, and the existing IPA builder.
