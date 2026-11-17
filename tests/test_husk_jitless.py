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

    def test_swift_facade_requires_certificate_and_preserves_original_apks(self):
        swift = self.read("LiveContainerSwiftUI/Strata3/INFINITYJITLess.swift")
        self.assertIn("certificateP12: Data", swift)
        self.assertIn("certificatePassword: String", swift)
        self.assertIn("infinity_husk_prepare_jitless(", swift)
        self.assertIn("INFINITY/JITless", swift)
        self.assertIn("Original APKs stay intact", swift)
        self.assertIn("infinity_husk_configure_jitless(", swift)


if __name__ == "__main__":
    unittest.main()
