from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ImportedIPAGuestLifecycleContractTests(unittest.TestCase):
    def test_new_installations_default_to_separate_guest_processes(self):
        model = (ROOT / "LiveContainerSwiftUI/Models/LCAppModel.swift").read_text(encoding="utf-8")
        self.assertIn(
            'object(forKey: "StrataSeamlessSwitching") as? Bool ?? true',
            model,
        )
        self.assertIn("let multitask = preferredMultitask || fullScreenJIT || seamless", model)
        self.assertIn("LCUtils.launchMultitaskGuestApp(appInfo.displayName())", model)

    def test_existing_installations_migrate_to_the_separate_guest_process_default(self):
        app = (ROOT / "LiveContainerSwiftUI/App/LiveContainerSwiftUIApp.swift").read_text(encoding="utf-8")
        self.assertIn('INFINITYMultitaskingDefaultsMigrationV2', app)
        self.assertIn('set(true, forKey: "StrataSeamlessSwitching")', app)
        self.assertNotIn('set(false, forKey: "StrataSeamlessSwitching")', app)

    def test_settings_ui_matches_the_enabled_default(self):
        settings = (ROOT / "LiveContainerSwiftUI/Views/StrataSettingsApp.swift").read_text(encoding="utf-8")
        self.assertIn('private var seamlessSwitching = true', settings)
        self.assertIn('Toggle(isOn: $seamlessSwitching)', settings)

    def test_ios_scene_host_keeps_guest_scene_foreground_during_resign_active_regression(self):
        scene = (ROOT / "MultitaskSupport/AppSceneViewController.m").read_text(encoding="utf-8")
        self.assertIn('FBSSceneObserver takes priority', scene)
        self.assertIn('UIApplicationWillResignActiveNotification', scene)
        self.assertIn('settings.foreground = YES;', scene)


if __name__ == "__main__":
    unittest.main()
