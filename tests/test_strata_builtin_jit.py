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

    def test_jit_helper_resolves_the_embedded_share_extension_identifier(self):
        shared_header = source("LiveContainer/LCSharedUtils.h")
        shared = source("LiveContainer/LCSharedUtils.m")
        utilities = source("LiveContainerSwiftUI/Utilities/LCUtils.m")
        extension_config = source("xcconfigs/ShareExtension.xcconfig")
        extension_info = source("ShareExtension/Info.plist")

        self.assertIn("strataJITHelperBundleIdentifier", shared_header)
        self.assertIn('@"ShareExtension.appex"', shared)
        self.assertIn("helperBundle.bundleIdentifier", shared)
        self.assertIn("[LCSharedUtils strataJITHelperBundleIdentifier]", utilities)
        self.assertIn("PRODUCT_BUNDLE_IDENTIFIER = $(LIVECONTAINER_BUNDLE_IDENTIFIER).ShareExtension", extension_config)
        self.assertIn("ShareExtensionHandler", extension_info)
        self.assertNotIn('stringByAppendingString:@".JITHelper"', shared)
        self.assertNotIn('stringByAppendingString:@".JITHelper"', utilities)

    def test_hostjit_per_app_toggle_writes_the_exact_launch_key(self):
        settings = source("LiveContainerSwiftUI/Views/AppList/AppSettings/LCAppSettingsView.swift")
        model = source("LiveContainerSwiftUI/Models/LCAppModel.swift")
        self.assertIn('@AppStorage("StrataHostJITApps"', settings)
        self.assertIn('private var hostJITKey: String', settings)
        self.assertIn('model.uiIsShared ? "shared" : "local"', settings)
        self.assertIn('appInfo.relativeBundlePath ?? model.bundleIdentifier', settings)
        self.assertIn('hostJITApps = encoded', settings)
        self.assertIn('hostOptions[hostKey] == true', model)
        self.assertIn('strataAttachHostJIT:hostJITRequest', source("LiveContainer/LCBootstrap.m"))

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

    def test_strata_version_labels_use_the_shared_infinity_version_symbol(self):
        runtime = source("LiveContainerSwiftUI/Strata3/StrataRuntimeCenter.swift")
        home = source("LiveContainerSwiftUI/Views/LiveBoardHomeScreen.swift")
        about = source("LiveContainerSwiftUI/Views/StrataAboutView.swift")
        settings = source("LiveContainerSwiftUI/Views/Settings/LCSettingsView.swift")
        self.assertNotIn("StrataVersion", runtime)
        self.assertNotIn("StrataVersion", home)
        self.assertNotIn("StrataVersion", settings)
        self.assertIn("INFINITYVersion.display", runtime)
        self.assertIn("INFINITYVersion.display", home)
        self.assertIn("INFINITYVersion.display", about)
        self.assertIn("INFINITYVersion.display", settings)
        self.assertIn("private var strataRuntimeManagerLink: some View", settings)
        self.assertIn("launch: launchStrataApp", settings)
        self.assertIn("private func launchStrataApp(_ app: LCAppModel)", settings)
        self.assertIn("LCUtils.authenticateUser()", settings)
        self.assertIn("try await app.runApp()", settings)
        self.assertIn("Strata runtime · INFINITY", runtime)

        version = source("LiveContainerSwiftUI/Strata3/INFINITYVersion.swift")
        self.assertIn("enum INFINITYVersion", version)
        self.assertIn('info["CFBundleShortVersionString"]', version)
        self.assertIn('info["CFBundleVersion"]', version)
        self.assertNotIn("StrataVersion", version)


if __name__ == "__main__":
    unittest.main()
