from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class StrataPerformanceWiringTests(unittest.TestCase):
    def test_memory_and_controls_are_started_for_real_execution_paths(self):
        bootstrap = source("LiveContainer/LCBootstrap.m")
        guest = source("LiveProcess/main.m")
        process_memory = source("LiveContainer/StrataProcessMemory.m")

        self.assertIn('StrataStartMemoryOverlaySampler([LCSharedUtils appGroupID]', bootstrap)
        self.assertIn('StrataStartMemoryOverlaySampler(LCSharedUtils.appGroupID, @"helper"', bootstrap)
        self.assertIn('StrataStartGuestControlsWithIdentity(', bootstrap)
        self.assertIn('StrataStartGuestMemoryDiagnostics(appInfo[@"strataDiagnosticsGroup"]', guest)
        self.assertIn('os_proc_available_memory()', process_memory)
        self.assertIn('TASK_VM_INFO', process_memory)

    def test_background_keepalive_and_opt_in_resume_are_connected(self):
        bootstrap = source("LiveContainer/LCBootstrap.m")
        interface = source("LiveContainerSwiftUI/Views/LiveBoard.swift")

        self.assertIn('Toggle("Reopen the running app if iOS closes Strata in the background"', interface)
        self.assertIn('boolForKey:@"StrataResumeAfterSystemClose"', bootstrap)
        self.assertIn('resume[@"app"]', bootstrap)
        self.assertIn('resume[@"container"]', bootstrap)
        self.assertIn("validAppPath", bootstrap)
        self.assertIn("containerExists", bootstrap)
        self.assertIn('@{@"app": resumeApp, @"container": resumeContainer', bootstrap)
        self.assertIn('StrataKeepAliveStart();', bootstrap)
        self.assertIn('StrataKeepAliveStop();', bootstrap)

    def test_memory_entitlement_is_present_on_host_and_guest_targets(self):
        host = source("entitlements.xml")
        guest = source("LiveProcess/LiveProcess.entitlements")
        self.assertIn("com.apple.developer.kernel.increased-memory-limit", host)
        self.assertIn("com.apple.developer.kernel.increased-memory-limit", guest)


if __name__ == "__main__":
    unittest.main()
