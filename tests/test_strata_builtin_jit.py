from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class StrataBuiltInJITContractTests(unittest.TestCase):
    def test_settings_exposes_pairing_and_device_setup(self):
        settings = source("LiveContainerSwiftUI/Views/Settings/LCSettingsView.swift")
        self.assertIn('if JITEnabler == .BuiltIn', settings)
        self.assertIn('LiveBoardJITSetup()', settings)

        setup = source("LiveContainerSwiftUI/Views/LiveBoardJITSetup.swift")
        self.assertIn('LiveBoardBuiltInJIT.importPairing(url)', setup)
        self.assertIn('perform("prepare")', setup)
        self.assertIn('perform("reset")', setup)

    def test_host_preflight_and_helper_handoff_are_gated(self):
        host = source("LiveContainerSwiftUI/Views/LiveBoardBuiltInJIT.swift")
        self.assertIn('#available(iOS 17.4, *)', host)
        self.assertIn('LCUtils.strataCanDebug()', host)
        self.assertIn('StrataPairingRecord.validate(data)', host)
        self.assertIn('LCUtils.strataStartJITHelper(', host)
        self.assertIn('LCUtils.strataStopJITHelper(helper)', host)

    def test_helper_serializes_stikjit_operations(self):
        worker = source("ShareExtension/StrataJITWorker.swift")
        self.assertIn('DispatchQueue(label: "Strata.JIT.helper")', worker)
        self.assertIn('StikJIT.prepareDevice(', worker)
        self.assertIn('StikJIT.enableJIT(', worker)
        self.assertIn('StikJIT.resetCachedDDI(at: paths)', worker)
        self.assertIn('defer { try? fm.removeItem(at: pairing) }', worker)

    def test_guest_waits_for_real_debugger_attachment(self):
        gate = source("LiveProcess/StrataJITGuestGate.m")
        main = source("LiveProcess/main.m")
        self.assertIn('StrataWaitForGuestDebugger(', gate)
        self.assertIn('CS_DEBUGGED', main)
        self.assertIn('StrataWaitForGuestDebugger(jitToken', main)

    def test_apk_status_style_uses_one_concrete_color_type(self):
        runtime = source("LiveContainerSwiftUI/Strata3/StrataRuntimeCenter.swift")
        self.assertIn('Color.secondary : Color.orange', runtime)


if __name__ == "__main__":
    unittest.main()
