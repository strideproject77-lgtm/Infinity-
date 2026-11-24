from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class HostLifecycleContractTests(unittest.TestCase):
    def test_husk_is_not_paused_for_transient_system_overlays(self):
        launch = (ROOT / "LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift").read_text(encoding="utf-8")
        self.assertIn('.onChange(of: scenePhase)', launch)
        self.assertIn('case .inactive:', launch)
        self.assertIn('keeping Husk attached during transient system UI', launch)
        self.assertIn('case .background:', launch)
        self.assertIn('pausing Husk after background transition', launch)
        self.assertIn('runtime.setPaused(true)', launch)
        self.assertIn('runtime.setPaused(false)', launch)
        self.assertNotIn('runtime.setJavaPaused(paused)', launch)

    def test_native_runtime_is_not_stopped_immediately_on_view_disappearance(self):
        launch = (ROOT / "LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift").read_text(encoding="utf-8")
        self.assertIn('DispatchQueue.main.asyncAfter(deadline: .now() + 0.8)', launch)
        self.assertIn('let phaseAtDisappear = scenePhase', launch)
        self.assertIn('if phaseAtDisappear == .active && appIsActive', launch)
        self.assertIn('UIApplication.shared.applicationState == .active', launch)
        self.assertNotIn('phaseAtDisappear == .active && scenePhase == .active', launch)
        self.assertIn('runtime.stop()', launch)

    def test_scene_phase_is_handled_once_and_inactive_does_not_call_husk_pause(self):
        launch = (ROOT / "LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift").read_text(encoding="utf-8")
        self.assertEqual(launch.count('.onChange(of: scenePhase)'), 1)
        inactive = launch.split('case .inactive:', 1)[1].split('case .background:', 1)[0]
        self.assertNotIn('runtime.setPaused', inactive)
        self.assertNotIn('runtime.setJavaPaused', inactive)


if __name__ == "__main__":
    unittest.main()
