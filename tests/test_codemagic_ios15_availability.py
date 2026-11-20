from pathlib import Path


def test_runtime_manager_link_is_guarded_for_ios16():
    source = Path("LiveContainerSwiftUI/Views/Settings/LCSettingsView.swift").read_text()
    declaration = "    @available(iOS 16.0, *)\\n    private var strataRuntimeManagerLink: some View {"
    assert declaration in source
    assert "if #available(iOS 16.0, *) {\\n                        strataRuntimeManagerLink" in source


def test_runtime_center_keeps_ios16_availability_contract():
    source = Path("LiveContainerSwiftUI/Strata3/StrataRuntimeCenter.swift").read_text()
    assert "@available(iOS 16.0, *)\\nstruct StrataRuntimeCenter: View" in source
