from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class CodemagicIOS15AvailabilityTests(unittest.TestCase):
    def test_runtime_manager_link_is_guarded_for_ios16(self):
        source = (ROOT / "LiveContainerSwiftUI/Views/Settings/LCSettingsView.swift").read_text()
        declaration = "    @available(iOS 16.0, *)\\n    private var strataRuntimeManagerLink: some View {"
        self.assertIn(declaration, source)
        self.assertIn("if #available(iOS 16.0, *) {\\n                        strataRuntimeManagerLink", source)

    def test_runtime_center_keeps_ios16_availability_contract(self):
        source = (ROOT / "LiveContainerSwiftUI/Strata3/StrataRuntimeCenter.swift").read_text()
        self.assertIn("@available(iOS 16.0, *)\\nstruct StrataRuntimeCenter: View", source)


if __name__ == "__main__":
    unittest.main()
