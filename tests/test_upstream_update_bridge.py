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


if __name__ == "__main__":
    unittest.main()
