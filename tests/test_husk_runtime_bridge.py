from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HuskRuntimeBridgeContractTests(unittest.TestCase):
    def read(self, relative: str) -> str:
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_strata_bridge_uses_infinity_owned_header_only(self):
        bridge = self.read("LiveContainerSwiftUI/Strata3/INFINITYHuskRuntimeBridge.h")
        self.assertIn("../../Vendor/Husk/include/INFINITYHuskRuntime.h", bridge)
        self.assertNotIn("HuskBridge.h", bridge)
        self.assertNotIn("husk-tl-unity-app.h", bridge)

    def test_runtime_package_compiles_both_upstream_translation_trees(self):
        package = self.read("Vendor/Husk/Package.swift")
        self.assertIn('"translation-layer"', package)
        self.assertIn('"translation-layer-next"', package)
        self.assertIn('"bridge"', package)
        self.assertIn('name: "INFINITYHuskRuntime"', package)
        self.assertIn('type: .static', package)

    def test_infinity_c_adapter_owns_launch_lifecycle_and_input_surface(self):
        adapter = self.read("Vendor/Husk/bridge/INFINITYHuskRuntime.c")
        for symbol in (
            "husk_java_launch(",
            "husk_unity_launch(",
            "husk_native_unload(",
            "tl_javaapp_touch(",
            "husk_unity_set_paused(",
            "husk_gamepad_update(",
            "husk_unity_perf_snapshot("
        ):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, adapter)

    def test_all_husk_backend_engines_are_dispatched_without_collapsing_identity(self):
        header = self.read("Vendor/Husk/include/INFINITYHuskRuntime.h")
        adapter = self.read("Vendor/Husk/bridge/INFINITYHuskRuntime.c")
        for engine in (
            "UNITY", "JAVA", "COCOS", "GAME_ACTIVITY", "SDL",
            "UNREAL", "GODOT", "GTA", "FLUTTER", "GAMEMAKER"
        ):
            with self.subTest(engine=engine):
                self.assertIn(f"INFINITY_HUSK_ENGINE_{engine}", header)
                self.assertIn(f"case INFINITY_HUSK_ENGINE_{engine}:", adapter)
        self.assertIn("atomic_store(&g_infinity_engine, (int)engine)", adapter)
        self.assertIn("husk_unity_touch(phase, pointer_id, x, y)", adapter)
        self.assertIn("husk_unity_set_paused(paused)", adapter)

    def test_java_runtime_is_rejected_when_boot_assets_are_missing(self):
        adapter = self.read("Vendor/Husk/bridge/INFINITYHuskRuntime.c")
        for asset in (
            "com.android.art/javalib/core-oj.jar",
            "com.android.art/javalib/core-libart.jar",
            "com.android.i18n/javalib/core-icu4j.jar",
            "com.android.art/javalib/okhttp.jar",
            "com.android.art/lib64/libopenjdk.so",
            "com.android.i18n/javalib/core-icu4j.jar",
            "com.android.conscrypt/javalib/conscrypt.jar",
            "com.android.conscrypt/lib64/libjavacrypto.so",
            "husk-framework.dex",
            "husk-framework-core.dex",
            "org.apache.http.legacy.jar",
            "framework-res.apk"
        ):
            with self.subTest(asset=asset):
                self.assertIn(asset, adapter)
        self.assertIn('runtime_directory(system_fonts_root, "fonts")', adapter)
        self.assertIn('runtime_file(system_fonts_root, "etc/fonts.xml")', adapter)
        self.assertIn('runtime_file(system_fonts_root, "etc/font_fallback.xml")', adapter)

    def test_swift_runtime_controller_uses_real_native_entrypoints(self):
        swift = self.read("LiveContainerSwiftUI/Strata3/INFINITYHuskRuntime.swift")
        self.assertIn("@MainActor", swift)
        self.assertIn("infinity_husk_launch_engine", swift)
        self.assertIn("case java = 1", swift)
        self.assertIn("case gameActivity = 3", swift)
        self.assertIn("case unreal = 5", swift)
        self.assertIn("infinity_husk_java_touch", swift)
        self.assertIn("infinity_husk_stop", swift)
        self.assertNotIn("Hello from Stride", swift)

    def test_package_dependency_is_attached_to_strata_swiftui_not_sidestore(self):
        project = self.read("LiveContainer.xcodeproj/project.pbxproj")
        swiftui = re.search(
            r"17413FB42D9C0BAE00F3F928 /\* LiveContainerSwiftUI \*/ = \{(.*?)\n\t\t\};",
            project,
            re.S
        )
        sidestore = re.search(
            r"173545A72E2C7913001B3B4C /\* SideStoreSupport \*/ = \{(.*?)\n\t\t\};",
            project,
            re.S
        )
        self.assertIsNotNone(swiftui)
        self.assertIsNotNone(sidestore)
        self.assertIn("F10000000000000000000002", swiftui.group(1))
        self.assertNotIn("F10000000000000000000002", sidestore.group(1))


if __name__ == "__main__":
    unittest.main()
