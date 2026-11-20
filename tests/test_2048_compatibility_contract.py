from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class TPCSTLD2048FrameworkContractTests(unittest.TestCase):
    """Source-level contract for the native Java/Canvas tpcstld 2048 target.

    These checks protect framework surfaces identified from the upstream source.
    They are not an APK execution or game-compatibility test.
    """

    def read(self, relative: str) -> str:
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_native_canvas_and_text_rendering_are_backed_by_husk_graphics(self):
        canvas = self.read("Vendor/Husk/src/java-framework/src/android/graphics/Canvas.java")
        paint = self.read("Vendor/Husk/src/java-framework/src/android/graphics/Paint.java")
        gfx = self.read("Vendor/Husk/src/java-framework/src/husk/Gfx.java")
        native = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm-graphics.c")

        for symbol in (
            "drawBitmap(Bitmap b, float left, float top, Paint p)",
            "drawText(String s, float x, float y, Paint p)",
        ):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, canvas)
        for symbol in (
            "setColor(int c)", "setTextSize(float s)", "setTextAlign(Align a)",
            "setTypeface(Typeface t)", "measureText(String s)",
            "float ascent()", "float descent()",
        ):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, paint)
        for symbol in ("cvDrawBitmap(", "cvDrawText(", "txMeasure(", "present("):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, gfx)
        for symbol in (
            '"cvDrawBitmap", "(JJFFFFFFFF[I)V"',
            '"cvDrawText", "(JLjava/lang/String;IIFF[IJJ)V"',
            '"txMeasure", "(Ljava/lang/String;II[IJ)F"',
        ):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, native)

    def test_single_pointer_swipe_input_reaches_the_android_view(self):
        event = self.read("Vendor/Husk/src/java-framework/src/android/view/MotionEvent.java")
        view = self.read("Vendor/Husk/src/java-framework/src/android/view/View.java")
        root = self.read("Vendor/Husk/src/java-framework/src/husk/ViewRoot.java")

        for symbol in ("ACTION_DOWN", "ACTION_MOVE", "ACTION_UP", "getAction()", "getX()", "getY()"):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, event)
        for symbol in ("setOnTouchListener(OnTouchListener l)", "dispatchTouchEvent(MotionEvent e)"):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, view)
        self.assertIn("r.mView.dispatchTouchEvent", root)

    def test_game_font_drawables_and_apk_assets_have_framework_paths(self):
        assets = self.read("Vendor/Husk/src/java-framework/src/android/content/res/AssetManager.java")
        resources = self.read("Vendor/Husk/src/java-framework/src/android/content/res/Resources.java")
        typeface = self.read("Vendor/Husk/src/java-framework/src/android/graphics/Typeface.java")
        bitmap_drawable = self.read("Vendor/Husk/src/java-framework/src/android/graphics/drawable/BitmapDrawable.java")

        self.assertIn("InputStream open(String name)", assets)
        self.assertIn("husk.Native.readAsset(n)", assets)
        self.assertIn("getDrawable(int id, Theme theme)", resources)
        self.assertIn("createFromAsset(android.content.res.AssetManager mgr, String path)", typeface)
        self.assertIn("c.drawBitmap(mBitmap, null, mDst, mPaint)", bitmap_drawable)

    def test_local_game_state_and_activity_lifecycle_are_present(self):
        prefs_api = self.read("Vendor/Husk/src/java-framework/src/android/content/SharedPreferences.java")
        prefs_impl = self.read("Vendor/Husk/src/java-framework/src/android/content/HuskSharedPreferences.java")
        preference_manager = self.read("Vendor/Husk/src/java-framework/src/android/preference/PreferenceManager.java")
        activity = self.read("Vendor/Husk/src/java-framework/src/android/app/Activity.java")
        runner = self.read("Vendor/Husk/src/java-framework/src/husk/AppRunner.java")

        for symbol in ("getInt(String k, int d)", "getLong(String k, long d)", "putInt(String k, int v)", "putLong(String k, long v)", "void apply()"):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, prefs_api)
        self.assertIn("public static SharedPreferences getDefaultSharedPreferences(Context c)", preference_manager)
        self.assertIn("public void apply()", prefs_impl)
        for symbol in ("onCreate(Bundle state)", "onResume()", "onPause()", "onSaveInstanceState(Bundle out)", "setContentView(View v)"):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, activity)
        for symbol in ("public static void run(", "onResume", "onPause", "dispatchTouchEvent"):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, runner)

    def test_android_15_status_bar_path_and_legacy_fallback_exist(self):
        build = self.read("Vendor/Husk/src/java-framework/src/android/os/Build.java")
        window = self.read("Vendor/Husk/src/java-framework/src/android/view/Window.java")
        view = self.read("Vendor/Husk/src/java-framework/src/android/view/View.java")
        insets = self.read("Vendor/Husk/src/java-framework/src/android/view/WindowInsets.java")

        self.assertIn("VANILLA_ICE_CREAM = 35", build)
        self.assertIn("setStatusBarColor(int c)", window)
        self.assertIn("setOnApplyWindowInsetsListener(OnApplyWindowInsetsListener l)", view)
        self.assertIn("statusBars()", insets)
        self.assertIn("getInsets(int types)", insets)


if __name__ == "__main__":
    unittest.main()
