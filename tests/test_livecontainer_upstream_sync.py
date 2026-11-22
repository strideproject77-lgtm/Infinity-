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



    def test_openssl_uses_the_pinned_submodule_without_custom_download(self):
        modules = source(".gitmodules")
        project = source("LiveContainer.xcodeproj/project.pbxproj")
        build = source("scripts/build_ipa.sh")
        self.assertIn('path = OpenSSL', modules)
        self.assertIn('path = OpenSSL/Frameworks/OpenSSL.xcframework', project)
        self.assertNotIn("prepare_livecontainer_dependencies.sh", build)
        self.assertNotIn("Dependencies/OpenSSL.xcframework", project)

    def test_archive_path_matches_codemagic_artifact_packager(self):
        build = source("scripts/build_ipa.sh")
        codemagic = source("codemagic.yaml")
        packager = source("scripts/package_codemagic_artifacts.sh")
        self.assertIn(': "${archive_path:=archive}"', build)
        self.assertIn('ARCHIVE_BASE="${archive_path%.xcarchive}"', build)
        self.assertIn('archive_path="$ARCHIVE_BASE"', build)
        self.assertIn("archive_path: archive", codemagic)
        self.assertIn('[[ ! -d "archive.xcarchive" ]]', packager)
        self.assertIn('ditto "archive.xcarchive"', packager)

    def test_archive_uses_external_sideload_signing(self):
        build = source("scripts/build_ipa.sh")
        self.assertIn("CODE_SIGNING_ALLOWED=NO", build)
        self.assertIn("CODE_SIGNING_REQUIRED=NO", build)
        self.assertIn('CODE_SIGN_IDENTITY=""', build)

    def test_archive_path_and_unsigned_sideload_build_are_consistent(self):
        self.assertIn("export scheme", build)
        build = source("scripts/build_ipa.sh")
        self.assertIn('ARCHIVE_PATH="\${ARCHIVE_BASE}.xcarchive"', build)
        self.assertIn('archive_path="$ARCHIVE_BASE"', build)
        self.assertIn('-archivePath "$ARCHIVE_PATH"', build)
        self.assertIn("CODE_SIGNING_ALLOWED=NO", build)
        self.assertIn("CODE_SIGNING_REQUIRED=NO", build)
        self.assertIn('test -s "$scheme.ipa"', build)

    def test_stikjit_archive_download_retries_transient_network_failures(self):
        prepare = source("scripts/prepare_stikjit_idevice.sh")
        self.assertIn("--retry 6 --retry-all-errors --retry-delay 5 --retry-max-time 600", prepare)
        self.assertIn("--connect-timeout 30 --max-time 900", prepare)
        self.assertIn('rm -f "$TEMP_ARCHIVE"', prepare)
        self.assertIn('EXPECTED_GIT_BLOB="3fb7e2dbfdb9db3d47bd6364a435bbc10d5581f9"', prepare)

    def test_packaging_downloads_retry_transient_network_errors(self):
        build = source(".github/build_github.sh")
        self.assertEqual(build.count("--retry 6 --retry-all-errors --retry-delay 5 --retry-max-time 600"), 2)
        self.assertNotIn("wget https://github.com/LiveContainer", build)

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
