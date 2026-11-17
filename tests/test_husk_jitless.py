from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HuskJITLessContractTests(unittest.TestCase):
    def read(self, relative: str) -> str:
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_native_aot_api_is_exposed_through_infinity_header(self):
        header = self.read("Vendor/Husk/include/INFINITYHuskRuntime.h")
        self.assertIn("infinity_husk_prepare_jitless", header)
        self.assertIn("infinity_husk_configure_jitless", header)
        self.assertIn("const uint8_t *p12", header)
        self.assertIn("signing_identifier", header)

    def test_adapter_uses_upstream_aot_converter_and_codesigning(self):
        adapter = self.read("Vendor/Husk/bridge/INFINITYHuskRuntime.c")
        self.assertIn('#include "husk-tl-aot.h"', adapter)
        self.assertIn('#include "husk-tl-codesign.h"', adapter)
        self.assertIn("husk_aot_prepare(", adapter)
        self.assertIn("husk_codesign_chain_from_executable(", adapter)
        self.assertIn("readable_file(apk_paths[i])", adapter)
        self.assertIn("access(cache_dir, W_OK)", adapter)

    def test_jitless_mode_disables_runtime_executable_memory_and_sets_aot_dirs(self):
        adapter = self.read("Vendor/Husk/bridge/INFINITYHuskRuntime.c")
        self.assertIn('setenv("TL_NO_XMEM", "1", 1)', adapter)
        self.assertIn("tl_ld_set_aot_dir(search_path)", adapter)
        self.assertIn("tl_ld_set_aot_dir(NULL)", adapter)
        self.assertIn('unsetenv("TL_NO_XMEM")', adapter)
        self.assertIn("atomic_load(&g_infinity_engine) != INFINITY_ENGINE_NONE", adapter)

    def test_swift_facade_reuses_imported_identity_and_requires_complete_aot_set(self):
        swift = self.read("LiveContainerSwiftUI/Strata3/INFINITYJITLess.swift")
        launch = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift")
        self.assertIn("certificateP12: Data?", swift)
        self.assertIn("certificatePassword: String?", swift)
        self.assertIn("certificateTeamID == appTeamID", swift)
        self.assertIn("prepared == requiredNames.count", swift)
        self.assertIn("Husk prepared %d of %d required ARM64 libraries", swift)
        self.assertIn("SHA256.hash(data: certificateP12)", swift)
        self.assertIn("LCUtils.certificateData()", launch)
        self.assertIn("LCSharedUtils.certificatePassword()", launch)
        self.assertIn("LCUtils.getCertTeamId(withKeyData:", launch)
        self.assertIn("Original APKs are never modified", swift)
        self.assertIn("infinity_husk_prepare_jitless(", swift)
        self.assertIn("infinity_husk_configure_jitless(", swift)

    def test_jit_error_requires_husks_explicit_executable_memory_diagnostic(self):
        swift = self.read("LiveContainerSwiftUI/Strata3/INFINITYJITLess.swift")
        self.assertIn('normalized.contains("no stikdebug jit region:")', swift)
        self.assertIn('normalized.contains("this process cannot make executable memory for itself")', swift)
        self.assertIn('normalized.contains("executable memory is turned off (tl_no_xmem)")', swift)
        self.assertIn("return .other", swift)
        self.assertIn("DEX, ELF, Android API, graphics, audio, or memory", swift)
        self.assertNotIn('normalized.contains("failed")', swift)
        self.assertNotIn('normalized.contains("crash")', swift)

    def test_launch_uses_a_fresh_husk_log_and_resets_jitless_after_stop(self):
        launch = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift")
        runtime = self.read("LiveContainerSwiftUI/Strata3/INFINITYHuskRuntime.swift")
        self.assertIn('engine == .unity ? "unity-run.log" : "native-run.log"', launch)
        self.assertIn("removeItem(at: logURL)", launch)
        self.assertIn("diagnosticLogURL: logURL", launch)
        self.assertIn("try? INFINITYJITLess.configure(enabled: false)", runtime)


if __name__ == "__main__":
    unittest.main()
