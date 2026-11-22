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
        self.assertIn('if ! echo "${SIDESTORE_IPA_SHA256}  SideStore.ipa" | shasum -a 256 -c -; then', build)
        self.assertIn('echo "SideStore IPA checksum verification failed." >&2', build)
        self.assertIn("    exit 1\nfi", build)



    def test_sidestore_packaging_fails_fast_and_cleans_the_real_payload(self):
        build = source(".github/build_github.sh")
        self.assertIn("set -eu", build)
        self.assertIn('find Payload -type d -name "_CodeSignature" -prune -exec rm -rf {} +', build)
        self.assertNotIn("find payloadlc/Payload", build)
        self.assertIn("rm -rf .zsign_cache", build)
        self.assertIn("LiveContainer/SideStore nightly 0.7.0-20261107.512+044bd72a", source("RELEASE.json"))
        self.assertIn('Add :PreferenceSpecifiers:2 dict', build)
        self.assertIn('Add :PreferenceSpecifiers:2:Key string LCOpenSideStore', build)
        self.assertNotIn('Add :PreferenceSpecifiers:3:Type', build)
        self.assertIn('unzip -t "$scheme.ipa"', build)
        self.assertIn('unzip -t "$scheme+SideStore.ipa"', build)


if __name__ == "__main__":
    unittest.main()
