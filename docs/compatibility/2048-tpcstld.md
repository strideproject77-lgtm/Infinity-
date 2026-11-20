# tpcstld 2048 — Infinity compatibility audit

Status: **source audit in progress; not yet launch-verified**

## Target identity

- Android package: `com.tpcstld.twozerogame`
- Launcher: `com.tpcstld.twozerogame.MainActivity`
- Upstream: https://github.com/tpcstld/2048
- Upstream manifest declares a portrait launcher Activity.
- The game is a native Java custom-View game, not a WebView app and not a 3D-engine title.
- Main rendering path: `MainView extends View`, Android `Canvas`, `Paint`, `BitmapDrawable`, and a bundled ClearSans font.
- Input path: `InputListener implements View.OnTouchListener` and interprets `MotionEvent` swipes.
- Local persistence: default `SharedPreferences`, including board state, undo state, score, and high score.
- The pinned distributable APK (`1.3.3`, version code `1007`) reports min SDK 14, target SDK 28 and compile SDK 28. Its manifest reports Android Support Library `26.1.0`; the APK DEX contains 1,452 `android.support.*` class descriptors, zero AndroidX descriptors and 2,106 Google Play Services descriptors. The APK contains one DEX file (3,711 class definitions), 492 resource entries and no native `.so` libraries. These exact APK facts take precedence over assumptions from the current upstream source tree.
- Infinity's APK engine detector already classifies a DEX-bearing APK with no recognized native engine library as `java`; the launch view routes that selection to Husk's Java backend and requires the Java runtime bundle.

## Infinity/Husk framework surfaces already present in source

The source audit found implementations for the core platform APIs used by the gameplay surface:

- Activity lifecycle and `setContentView(View)`
- View drawing, invalidation, background, and touch-listener dispatch
- MotionEvent action and coordinate accessors
- Canvas bitmap/text drawing and Paint text measurement/configuration
- Typeface loading from APK assets
- Drawable/resource lookup and APK AssetManager reads
- SharedPreferences typed reads/writes and asynchronous `apply()`
- Window status-bar color and WindowInsets status-bar access
- Husk ViewRoot forwarding touch input and presenting rendered view surfaces
- Native graphics bridge registrations for bitmap drawing, text drawing, and text measurement

The source-level regression contract is `tests/test_2048_compatibility_contract.py`. It protects these known API paths; it does not prove that the app launches or renders correctly.

## Remaining blockers before claiming full support

1. Inspect the exact distributable APK's manifest, DEX files, resources, and dependency contents. The upstream source tree is not a substitute for the exact APK under test.
2. Verify DEX class hierarchy, instruction/opcode coverage and verifier behavior for the exact compiled app. The forensic report records the `MainActivity` superclass and Android framework method references from `dexdump`.
3. Audit Android Support Library 26.1.0 (not AndroidX) paths reached by the app, then compare every referenced Android framework method with Husk's actual framework implementations.
4. Treat Google Play Services sign-in/cloud snapshots as optional. The APK includes many GMS classes, but local gameplay and local save must work without a Play Games service backend.
5. Investigate the DEX header's SHA-1 signature mismatch (Adler-32 checksum passes and `dexdump` can disassemble it); do not assume it is harmless or fatal until checked against ART/Dalvik verifier behavior.
6. Run a real APK launch and test swipe input, draw/animation, undo, restart, high-score persistence, pause/resume, and portrait behavior after the broader Husk runtime gate is ready.

## Scope guard

Do not add a package-name whitelist, fake game screen, or simulated success path. The goal is general Android API/runtime compatibility so the real APK executes through Husk. Hill Climb Racing and Subway Surfers remain out of scope until the 2048 milestone is validated.
