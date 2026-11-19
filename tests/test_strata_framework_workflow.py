import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "infinity-strata-framework-build.yml"


class StrataFrameworkWorkflowContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = WORKFLOW.read_text(encoding="utf-8")
        cls.resolve_step = cls.source.split(
            "- name: Resolve Xcode package dependencies", 1
        )[1].split("- name: Build only the LiveContainerSwiftUI framework target", 1)[0]
        cls.build_step = cls.source.split(
            "- name: Build only the LiveContainerSwiftUI framework target", 1
        )[1]

    def test_framework_validation_is_manual_and_uses_pinned_xcode(self):
        self.assertIn("workflow_dispatch:", self.source)
        self.assertIn("xcode-version: '26.2'", self.source)
        self.assertNotIn("\n  push:", self.source)
        self.assertNotIn("workflow_dispatch", self.source.split("jobs:", 1)[0].replace("workflow_dispatch:", ""))

    def test_resolve_and_build_share_explicit_swiftpm_cache(self):
        cache_assignment = 'PACKAGE_CACHE="$RUNNER_TEMP/infinity-source-packages"'
        self.assertIn(cache_assignment, self.resolve_step)
        self.assertIn("-clonedSourcePackagesDirPath \"$PACKAGE_CACHE\"", self.resolve_step)
        self.assertIn(cache_assignment, self.build_step)
        self.assertIn("-clonedSourcePackagesDirPath \"$PACKAGE_CACHE\"", self.build_step)

    def test_target_only_build_does_not_use_derived_data_path(self):
        self.assertIn("-target LiveContainerSwiftUI", self.build_step)
        self.assertNotIn("-derivedDataPath", self.build_step)
        self.assertIn("-SYMROOT=", self.build_step)
        self.assertIn("-OBJROOT=", self.build_step)

    def test_framework_validation_never_signs_or_packages_an_ipa(self):
        self.assertIn("CODE_SIGNING_ALLOWED=NO", self.build_step)
        self.assertNotIn("-archivePath", self.build_step)
        self.assertNotIn(" -exportArchive", self.build_step)
        self.assertNotIn("xcodebuild -export", self.build_step)


if __name__ == "__main__":
    unittest.main()
