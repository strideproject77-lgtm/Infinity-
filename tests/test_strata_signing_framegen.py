from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class StrataSigningAndFrameGenerationTests(unittest.TestCase):
    def test_keychain_uses_the_actual_signed_access_group(self):
        shared = source("LiveContainer/LCSharedUtils.m")
        query = shared.split("+ (NSMutableDictionary *)strataIdentityQuery", 1)[1].split(
            "+ (NSDictionary *)strataSigningIdentity", 1
        )[0]
        self.assertIn('CFSTR("keychain-access-groups")', query)
        self.assertIn('hasSuffix:@".com.kdt.livecontainer.shared"', query)
        self.assertIn("self.teamIdentifier", query)
        self.assertIn("kSecAttrAccessGroup", query)

    def test_side_store_bundle_and_husk_share_the_exported_p12_password(self):
        packaging = source(".github/build_github.sh")
        launch = source("LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift")
        jitless = source("LiveContainerSwiftUI/Strata3/INFINITYJITLess.swift")

        self.assertIn("LiveContainer/SideStore@044bd72ad4eb270c3900bd04dc6f508d0ac474db", packaging)
        self.assertIn('SIDESTORE_IPA_SHA256="f65f5a5e1adca962e663563bc8ade90f64da98dd7f1d1b51f2d5b33002ced00e"', packaging)
        self.assertIn("let certificatePassword = LCSharedUtils.certificatePassword()", launch)
        self.assertIn("certificatePassword: certificatePassword", launch)
        self.assertIn("certificatePassword.withCString", jitless)
        self.assertIn("certificateTeamID: certificateTeamID", launch)

    def test_strata_4_runtime_connections_are_wired(self):
        settings = source("LiveContainerSwiftUI/Views/AppList/AppSettings/LCAppSettingsView.swift")
        model = source("LiveContainerSwiftUI/Models/LCAppModel.swift")
        bootstrap = source("LiveContainer/LCBootstrap.m")
        host = source("LiveContainerSwiftUI/Utilities/LCUtils.m")
        switcher = source("LiveContainerSwiftUI/Views/StrataSwitcherSettings.swift")

        self.assertIn("$model.uiHelperProcessesSupport", settings)
        self.assertIn('guestAppInfo[@"helperProcessesSupport"]', bootstrap)
        self.assertIn("StrataSeamlessSwitching", model)
        self.assertIn("[MultitaskWindowManager openAppWindowWithDisplayName", host)
        self.assertIn("StrataToggleHostControls", host)
        self.assertIn("StrataSwitcherPinnedApps", switcher)

    def test_frame_generation_is_built_and_embedded_for_the_runtime_loader(self):
        build = source("scripts/build_ipa.sh")
        builder = source("scripts/build_strata_framegen.sh")
        bootstrap = source("LiveContainer/LCBootstrap.m")
        framegen = source("FrameGeneration/StrataFrameGen.mm")

        self.assertIn("scripts/build_strata_framegen.sh", build)
        self.assertIn('Frameworks/StrataFrameGen.dylib', build)
        self.assertIn('Frameworks/StrataFrameGen.dylib', bootstrap)
        self.assertIn("StrataFrameGenStart", framegen)
        for path in (
            "FrameGeneration/StrataFrameGen.mm",
            "Vendor/MetalFG/Source/TouchTracker.mm",
            "Vendor/MetalFG/Source/CoreMotionTracker.mm",
            "Vendor/MetalFG/Source/MetalFGWarper.mm",
            "Vendor/MetalFG/Source/MetalFGSynchronizer.mm",
            "Vendor/MetalFG/Source/MetalFGOverlay.mm",
        ):
            self.assertIn(path, builder)

    def test_diagnostics_report_the_real_aot_and_framegen_state(self):
        diagnostics = source("LiveContainerSwiftUI/Strata3/StrataRuntimeCenter.swift")
        self.assertIn('"huskEmbeddedAOT": "prelaunchIntegratedDeviceTestPending"', diagnostics)
        self.assertIn('"frameGeneration": "buildIntegratedExperimental2x3x4xDeviceTestPending"', diagnostics)
        self.assertIn('"helperProcesses": "sourceConnectedDeviceTestPending"', diagnostics)
        self.assertIn('"appSwitcher": "sourceConnectedDeviceTestPending"', diagnostics)
        self.assertIn('"memoryDonor": "notDeviceVerified"', diagnostics)
        self.assertIn('"version": INFINITYVersion.display', diagnostics)
        identity = source("LiveContainerSwiftUI/Strata3/StrataIdentitySettings.swift")
        self.assertIn("password chosen during export—not your Apple Account password", identity)


if __name__ == "__main__":
    unittest.main()
