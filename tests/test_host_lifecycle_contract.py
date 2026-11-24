from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class HostLifecycleContractTests(unittest.TestCase):
    def test_husk_session_is_paused_and_preserved_during_system_app_switching(self):
        launch = (ROOT / "LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift").read_text(encoding="utf-8")
        self.assertIn('.onChange(of: scenePhase)', launch)
        self.assertIn('runtime.setPaused(paused)', launch)
        self.assertIn('runtime.setJavaPaused(paused)', launch)
        self.assertIn('pausing both native and Java engines', launch)
        self.assertIn('HOST_SCENE_BACKGROUND', launch)
        self.assertIn('HOST_SCENE_ACTIVE', launch)
        self.assertIn('keeping Husk session alive across system app switching', launch)

    def test_native_runtime_is_not_stopped_immediately_on_view_disappearance(self):
        launch = (ROOT / "LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift").read_text(encoding="utf-8")
        self.assertIn('DispatchQueue.main.asyncAfter(deadline: .now() + 0.8)', launch)
        self.assertIn('let phaseAtDisappear = scenePhase', launch)
        self.assertIn('if phaseAtDisappear == .active && scenePhase == .active', launch)
        self.assertIn('runtime.stop()', launch)


if __name__ == "__main__":
    unittest.main()
