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
- The upstream Gradle project declares min SDK 21 and target SDK 35. It also declares AndroidX AppCompat and Google Play Games dependencies.

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
2. Verify DEX opcodes and class verification for the app's compiled code and bundled AndroidX dependencies.
3. Audit the AndroidX AppCompat/Core code paths reached by `AppCompatActivity` and `ResourcesCompat`.
4. Treat Google Play Games sign-in/cloud snapshots as an optional integration. No Play Games service implementation is claimed; local gameplay and local save must remain independent of cloud sign-in.
5. Run a real APK launch and test swipe input, draw/animation, undo, restart, high-score persistence, pause/resume, and rotation/portrait behavior after the broader Husk runtime gate is ready.

## Scope guard

Do not add a package-name whitelist, fake game screen, or simulated success path. The goal is general Android API/runtime compatibility so the real APK executes through Husk. Hill Climb Racing and Subway Surfers remain out of scope until the 2048 milestone is validated.
