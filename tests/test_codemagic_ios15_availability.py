from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class CodemagicIOS15AvailabilityTests(unittest.TestCase):
    def test_runtime_manager_link_is_guarded_for_ios16(self):
        source = (ROOT / "LiveContainerSwiftUI/Views/Settings/LCSettingsView.swift").read_text()
        lines = source.splitlines()
        declaration = lines.index("    private var strataRuntimeManagerLink: some View {")
        self.assertEqual(lines[declaration - 1], "    @available(iOS 16.0, *)")
        self.assertIn("if #available(iOS 16.0, *) {", source)

    def test_runtime_center_keeps_ios16_availability_contract(self):
        source = (ROOT / "LiveContainerSwiftUI/Strata3/StrataRuntimeCenter.swift").read_text()
        lines = source.splitlines()
        declaration = lines.index("struct StrataRuntimeCenter: View")
        self.assertEqual(lines[declaration - 1], "@available(iOS 16.0, *)")


if __name__ == "__main__":
    unittest.main()
