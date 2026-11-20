from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RuntimeAssetBuilderTests(unittest.TestCase):
    def read(self, relative: str) -> str:
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_builder_extracts_only_required_lineage_apex_modules(self):
        script = self.read("scripts/build_infinity_runtime_assets.sh")
        for module in (
            "com.android.art",
            "com.android.i18n",
            "com.android.tzdata",
            "com.android.conscrypt",
        ):
            with self.subTest(module=module):
                self.assertIn(module, script)
        self.assertIn("framework-res.apk", script)
        self.assertIn("org.apache.http.legacy.jar", script)

    def test_builder_uses_pinned_java_framework_recipe_and_android_system_data(self):
        script = self.read("scripts/build_infinity_runtime_assets.sh")
        self.assertIn('build-support/build_java_runtime.sh', script)
        self.assertIn('build/java-runtime', script)
        self.assertIn('build/android-system', script)
        self.assertIn('etc/font_fallback.xml', script)
        self.assertIn(r'-exec cp {} "$ANDROID_SYSTEM/fonts/" \;', script)
        self.assertIn('cacerts', script)

    def test_builder_records_streamed_sha256_for_every_required_runtime_payload(self):
        script = self.read("scripts/build_infinity_runtime_assets.sh")
        self.assertIn("import datetime, hashlib, json, os, sys", script)
        self.assertIn('"payload_files": payload_files', script)
        self.assertIn('"sha256": hasher.hexdigest()', script)
        self.assertIn("source.read(1024 * 1024)", script)
        self.assertIn('stream.write("\\n")', script)

    def test_builder_never_packages_qemu_guest_or_ipa(self):
        script = self.read("scripts/build_infinity_runtime_assets.sh")
        workflow = self.read(".github/workflows/infinity-runtime-assets.yml")
        self.assertIn('"qemu_guest_included": False', script)
        self.assertIn('"ipa_included": False', script)
        self.assertNotIn("xcodebuild", script)
        self.assertNotIn("build.yml", workflow)
        self.assertNotIn("ipa-builder", workflow.lower())

    def test_gpt_partition_names_are_split_on_a_single_nul_byte(self):
        script = self.read("scripts/build_infinity_runtime_assets.sh")
        self.assertIn(r'entry[:36].split(b"\0", 1)[0]', script)
        self.assertNotIn(r'entry[:36].split(b"\\0", 1)[0]', script)

    def test_workflow_verifies_pinned_image_and_uploads_data_artifact_only(self):
        workflow = self.read(".github/workflows/infinity-runtime-assets.yml")
        self.assertIn("vda-v12.qcow2", workflow)
        self.assertIn("a8dbaecc8fdcd682991b078d6bbb7df6972e459208634fa8dcbad24f17208d6a", workflow)
        self.assertIn("actions/upload-artifact@v4", workflow)
        self.assertIn("INFINITY-Android-Runtime-Assets-v1", workflow)
        self.assertIn("retention-days: 7", workflow)


if __name__ == "__main__":
    unittest.main()
