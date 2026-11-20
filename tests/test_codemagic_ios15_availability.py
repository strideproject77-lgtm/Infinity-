from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class CodemagicIOS16DeploymentTests(unittest.TestCase):
    def test_all_ios_deployment_targets_are_at_least_16(self):
        project = (ROOT / "LiveContainer.xcodeproj/project.pbxproj").read_text()
        deployment_targets = [
            float(value)
            for value in __import__("re").findall(
                r"IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);", project
            )
        ]
        self.assertTrue(deployment_targets, "No iOS deployment targets found")
        self.assertGreaterEqual(min(deployment_targets), 16.0)

    def test_jni_object_varargs_stubs_export_linkable_implementations(self):
        jni = (ROOT / "Vendor/Husk/translation-layer-next/husk-tl-jni.c").read_text()
        for name in (
            "CallObjectMethod",
            "CallNonvirtualObjectMethod",
            "CallStaticObjectMethod",
        ):
            implementation = f"tl_vai_jni_{name}(tl_va_frame *f)"
            stub = f"TL_VA_STUB(tl_va_jni_{name}, tl_vai_jni_{name})"
            self.assertIn(implementation, jni)
            self.assertIn(stub, jni)
            self.assertNotIn(f"static jo {implementation}", jni)


    def test_runtime_manager_and_runtime_center_availability_contract(self):
        settings = (ROOT / "LiveContainerSwiftUI/Views/Settings/LCSettingsView.swift").read_text()
        self.assertIn("@available(iOS 16.0, *)", settings)
        self.assertIn("if #available(iOS 16.0, *) {", settings)

        runtime_center = (ROOT / "LiveContainerSwiftUI/Strata3/StrataRuntimeCenter.swift").read_text()
        lines = runtime_center.splitlines()
        declaration = next(i for i, line in enumerate(lines) if line.startswith("struct StrataRuntimeCenter: View"))
        self.assertEqual(lines[declaration - 1], "@available(iOS 16.0, *)")


if __name__ == "__main__":
    unittest.main()
