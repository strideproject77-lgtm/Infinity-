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

## Pinned distributable APK forensic audit

- Selected the upstream GitHub release asset `133-release.apk` from tag `1.3.3` as the reproducible APK under test. The published asset is 2,233,942 bytes; the audit workflow computes and records its SHA-256 at run time rather than assuming an unverified digest.
- `scripts/inspect_2048_apk.py` validates the ZIP/DEX structure, records DEX header table counts, checks the package identity with AAPT, dumps the binary manifest and resources, and disassembles every DEX file with `dexdump`. It also records AndroidX and Google Play SDK class descriptors found in DEX strings.
- `.github/workflows/2048-apk-forensics.yml` downloads that exact release asset and publishes a report artifact. The report is static evidence only: it does not prove class verification, framework execution, or a successful Husk launch.
- The actual inspection results remain pending until the workflow completes and its artifact is reviewed.

## Remaining blockers before claiming full support

1. Inspect the exact distributable APK's manifest, DEX files, resources, and dependency contents. The upstream source tree is not a substitute for the exact APK under test.
2. Verify DEX opcodes and class verification for the app's compiled code and bundled AndroidX dependencies.
3. Audit the AndroidX AppCompat/Core code paths reached by `AppCompatActivity` and `ResourcesCompat`.
4. Treat Google Play Games sign-in/cloud snapshots as an optional integration. No Play Games service implementation is claimed; local gameplay and local save must remain independent of cloud sign-in.
5. Run a real APK launch and test swipe input, draw/animation, undo, restart, high-score persistence, pause/resume, and rotation/portrait behavior after the broader Husk runtime gate is ready.

## Scope guard

Do not add a package-name whitelist, fake game screen, or simulated success path. The goal is general Android API/runtime compatibility so the real APK executes through Husk. Hill Climb Racing and Subway Surfers remain out of scope until the 2048 milestone is validated.
