# Regression coverage for the embedded SideStore IPA source pin.
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "check_upstream_updates", ROOT / "scripts" / "check_upstream_updates.py"
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class UpstreamBridgeTests(unittest.TestCase):
    def test_manifest_has_review_only_components_and_full_pins(self):
        manifest = json.loads((ROOT / "upstream" / "manifest.json").read_text())
        self.assertFalse(manifest["policy"]["automatic_source_merges"])
        self.assertFalse(manifest["policy"]["automatic_version_bumps"])
        for component in manifest["components"]:
            self.assertEqual(component["mode"], "review-only")
            self.assertRegex(component["pinned_revision"], r"^[0-9a-f]{40}$")

    def test_update_bridge_is_manual_only(self):
        workflow = (ROOT / ".github" / "workflows" / "infinity-upstream-update-bridge.yml").read_text()
        self.assertIn("workflow_dispatch:", workflow)
        self.assertNotIn("schedule:", workflow)
        self.assertNotIn("push:", workflow)

    def test_local_strata_and_infinity_are_protected(self):
        manifest = json.loads((ROOT / "upstream" / "manifest.json").read_text())
        protected = {item["id"] for item in manifest["local_components"]}
        self.assertEqual(protected, {"strata", "infinity"})

    def test_report_explains_no_automatic_source_merge(self):
        component = {
            "id": "livecontainer",
            "name": "LiveContainer",
            "repository": "LiveContainer/LiveContainer",
            "pinned_revision": "a" * 40,
            "latest_revision": "b" * 40,
            "ahead_by": 3,
            "behind_by": 0,
            "status": "ahead",
            "latest_message": "Example update",
            "latest_date": "",
            "result": "UPDATE_AVAILABLE",
            "error": None,
        }
        report = MODULE.render_markdown([component], [], "2026-11-21 00:00 UTC")
        self.assertIn("Read-only report", report)
        self.assertIn("3 upstream commit(s) ahead", report)
        self.assertIn("macOS iOS-device compile validation", report)

    def test_bundled_sidestore_source_matches_packaging_pipeline(self):
        manifest = json.loads((ROOT / "upstream" / "manifest.json").read_text())
        bundle = next(item for item in manifest["components"] if item["id"] == "sidestore_bundle")
        self.assertEqual(bundle["repository"], "LiveContainer/SideStore")
        self.assertEqual(bundle["pinned_revision"], "044bd72ad4eb270c3900bd04dc6f508d0ac474db")

        packaging = (ROOT / ".github" / "build_github.sh").read_text()
        self.assertIn(
            "https://github.com/LiveContainer/SideStore/releases/download/nightly/SideStore.ipa",
            packaging,
        )
        self.assertIn("SIDESTORE_IPA_SHA256=", packaging)
        self.assertIn("f65f5a5e1adca962e663563bc8ade90f64da98dd7f1d1b51f2d5b33002ced00e", packaging)

    def test_pairing_patch_only_corrects_lockdown_branch(self):
        patch_spec = importlib.util.spec_from_file_location(
            "patch_sidestore_pairing", ROOT / "scripts" / "patch_sidestore_pairing.py"
        )
        patch_module = importlib.util.module_from_spec(patch_spec)
        patch_spec.loader.exec_module(patch_module)
        source = """if pprotocol == .rppairing {\n    requiredKeys = [\"private_key\"]\n} else if pprotocol == .rppairing {\n    requiredKeys = [\"HostID\"]\n}"""
        fixed = patch_module.patch_source(source)
        self.assertIn("} else if pprotocol == .lockdown {", fixed)
        self.assertEqual(fixed.count("pprotocol == .rppairing"), 1)
        self.assertEqual(patch_module.patch_source(fixed), fixed)

    def test_pairing_patch_fails_closed_on_unexpected_source(self):
        patch_spec = importlib.util.spec_from_file_location(
            "patch_sidestore_pairing", ROOT / "scripts" / "patch_sidestore_pairing.py"
        )
        patch_module = importlib.util.module_from_spec(patch_spec)
        patch_spec.loader.exec_module(patch_module)
        with self.assertRaises(ValueError):
            patch_module.patch_source("unrecognized source")


if __name__ == "__main__":
    unittest.main()
