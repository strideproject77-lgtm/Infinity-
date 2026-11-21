from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class LiveContainerUpstreamSyncContractTests(unittest.TestCase):
    def test_entitlement_lookup_handles_missing_value(self):
        shared = source("LiveContainer/LCSharedUtils.m")
        self.assertIn(
            "if(cfans && CFGetTypeID(cfans) == CFStringGetTypeID())",
            shared,
        )
        self.assertIn(
            '[@"group.com.SideStore.SideStore" stringByAppendingPathExtension:[self teamIdentifier]]',
            shared,
        )
        self.assertIn(
            '[@"group.com.rileytestut.AltStore" stringByAppendingPathExtension:[self teamIdentifier]]',
            shared,
        )

    def test_liveprocess_identifier_uses_component_safe_path_extensions(self):
        utils = source("LiveContainerSwiftUI/Utilities/LCUtils.m")
        self.assertIn(
            '[[@"com.kdt.livecontainer" stringByAppendingPathExtension:LCSharedUtils.teamIdentifier] stringByAppendingPathExtension:@"LiveProcess"]',
            utils,
        )

    def test_altstore_sources_are_loaded_only_when_tab_is_opened(self):
        sources = source("LiveContainerSwiftUI/Views/LCAltStoreSourcesView.swift")
        self.assertIn("private var hasLoadedSources = false", sources)
        self.assertIn("func loadSourcesIfNeeded()", sources)
        self.assertIn("guard !hasLoadedSources else { return }", sources)
        self.assertIn("viewModel.loadSourcesIfNeeded()", sources)
        self.assertIn(".onChange(of: sharedModel.selectedTab)", sources)
        self.assertNotIn(
            "init() {\n        loadStoredSources()",
            sources,
        )

    def test_embedded_sidestore_nightly_is_hash_pinned(self):
        release = json.loads(source("RELEASE.json"))
        build = source(".github/build_github.sh")
        self.assertEqual(
            release["sideStoreCommit"],
            "044bd72ad4eb270c3900bd04dc6f508d0ac474db",
        )
        self.assertEqual(
            release["sideStoreIpaSha256"],
            "f65f5a5e1adca962e663563bc8ade90f64da98dd7f1d1b51f2d5b33002ced00e",
        )
        self.assertIn('echo "${SIDESTORE_IPA_SHA256}  SideStore.ipa" | shasum -a 256 -c -', build)
        self.assertIn("LiveContainer/SideStore nightly 0.7.0-20261107.512+044bd72a", source("RELEASE.json"))


if __name__ == "__main__":
    unittest.main()
