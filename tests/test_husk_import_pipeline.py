import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
IMPORTER = ROOT / "scripts" / "import_husk_runtime.sh"
AUDITOR = ROOT / "scripts" / "audit_husk_runtime.py"


class HuskImportContractTests(unittest.TestCase):
    def test_importer_is_pinned_and_includes_both_translation_layers(self):
        script = IMPORTER.read_text(encoding="utf-8")
        self.assertIn('REVISION="29abb512d81bf8cc08babcbe7f7007cb557208ef"', script)
        self.assertIn("src/translation-layer \\", script)
        self.assertIn("src/translation-layer-next \\", script)
        for name in (
            "TranslationLayer.swift",
            "TLUnityView.swift",
            "TLAppSettings.swift",
            "AppWindows.swift",
            "HuskGamepad.swift",
            "HuskKeyboard.swift",
            "HuskAudio.swift",
            "HuskLog.swift",
            "HuskFilePicker.swift",
            "build_java_runtime.sh",
            "build_android_system.sh",
            "build_angle_ios.sh",
            "build_art_support.sh",
            "cacert.pem",
            "HuskBridge.h",
            "project.yml",
        ):
            self.assertIn(name, script)

    def test_app_entry_point_is_audit_only_and_qemu_side_store_are_excluded(self):
        script = IMPORTER.read_text(encoding="utf-8")
        self.assertIn('cp "$ARCHIVE/src/app/Husk/HuskApp.swift" "$STAGE/host-reference/HuskApp.swift"', script)
        self.assertIn('cp "$ARCHIVE/src/app/Husk/HuskBridge.h" "$STAGE/host-reference/HuskBridge.h"', script)
        for qemu_reference in ("HuskAudio.swift", "HuskKeyboard.swift", "HuskLog.swift"):
            self.assertIn(f'cp "$ARCHIVE/src/app/Husk/{qemu_reference}" "$STAGE/host-reference/{qemu_reference}"', script)
        self.assertIn('cp "$ARCHIVE/src/app/project.yml" "$STAGE/build-support/project.yml"', script)
        self.assertIn("never compiled", script)
        forbidden_paths = (
            "src/app/Husk/QemuRunner.swift",
            "src/app/Husk.xcodeproj",
            "SideStoreSupport/",
            ".github/workflows/build.yml",
        )
        for path in forbidden_paths:
            self.assertNotIn(path, script)

    def test_importer_refuses_overwrite_of_any_owned_group_without_refresh(self):
        script = IMPORTER.read_text(encoding="utf-8")
        guard = script.split('if [[ "$REFRESH" -ne 1 ]] && {', 1)[1].split("}; then", 1)[0]
        for owned_path in (
            '"$DEST/translation-layer"',
            '"$DEST/translation-layer-next"',
            '"$DEST/host-runtime"',
            '"$DEST/host-reference"',
            '"$DEST/build-support"',
            '"$DEST/upstream-docs"',
            '"$DEST/resources"',
            '"$DEST/HUSK-LICENSE"',
            '"$DEST/UPSTREAM_REVISION.txt"',
        ):
            self.assertIn(owned_path, guard)

    def test_importer_replaces_only_owned_vendor_groups(self):
        script = IMPORTER.read_text(encoding="utf-8")
        self.assertIn(
            "translation-layer translation-layer-next host-runtime host-reference build-support upstream-docs resources",
            script,
        )
        self.assertIn('cp "$STAGE/HUSK-LICENSE" "$DEST/HUSK-LICENSE"', script)
        self.assertIn("THIRD_PARTY_NOTICES.md", script)

    def test_auditor_generates_native_and_swift_dependency_inventory(self):
        with tempfile.TemporaryDirectory() as temp:
            base = pathlib.Path(temp)
            vendor = base / "Vendor" / "Husk"
            groups = (
                "translation-layer",
                "translation-layer-next",
                "host-runtime",
                "host-reference",
                "build-support",
                "upstream-docs",
                "resources",
            )
            for group in groups:
                (vendor / group).mkdir(parents=True)
            (vendor / "UPSTREAM_REVISION.txt").write_text("Revision: fixture\n", encoding="utf-8")
            (vendor / "translation-layer-next" / "engine.c").write_text(
                '/* SPDX-License-Identifier: GPL-2.0-or-later */\n#include "engine.h"\n#include <pthread.h>\nvoid husk_fixture_start(void) { }\n',
                encoding="utf-8",
            )
            (vendor / "translation-layer-next" / "engine.h").write_text(
                "/* SPDX-License-Identifier: GPL-2.0-or-later */\n/* This comment mentions husk_missing_api(); but does not declare it. */\nvoid husk_fixture_start(void);\ntypedef struct husk_fixture_perf { double fps; } husk_fixture_perf;\n",
                encoding="utf-8",
            )
            (vendor / "host-reference" / "HuskBridge.h").write_text("#include \"qemu.h\"\\n", encoding="utf-8")
            (vendor / "build-support" / "project.yml").write_text("targets: {}\\n", encoding="utf-8")
            (vendor / "host-runtime" / "Host.swift").write_text(
                "// SPDX-License-Identifier: GPL-2.0-or-later\nimport Foundation\nimport UIKit\nfunc launch() { husk_fixture_start(); husk_missing_api(); let _ = husk_fixture_perf() }\n",
                encoding="utf-8",
            )
            (vendor / "build-support" / "build.sh").write_text("#!/bin/sh\n", encoding="utf-8")
            (vendor / "upstream-docs" / "runtime.md").write_text("# Runtime\n", encoding="utf-8")
            output = base / "generated"
            subprocess.run(
                [sys.executable, str(AUDITOR), "--vendor-root", str(vendor), "--output-dir", str(output)],
                check=True,
                capture_output=True,
                text=True,
            )
            manifest = json.loads((output / "HUSK_SOURCE_MANIFEST.json").read_text(encoding="utf-8"))
            report = (output / "HUSK_SOURCE_AUDIT.md").read_text(encoding="utf-8")
            self.assertEqual(manifest["file_count"], 7)
            self.assertEqual(manifest["counts_by_kind"]["native-source"], 1)
            self.assertEqual(manifest["counts_by_kind"]["swift-host-source"], 1)
            self.assertEqual(manifest["swift_imports"]["UIKit"], 1)
            self.assertIn("pthread.h", manifest["system_header_includes"])
            self.assertIn("legacy translation-layer/", report)
            self.assertIn("Husk source and host integration audit", report)
            api_report = (output / "HUSK_HOST_API_AUDIT.md").read_text(encoding="utf-8")
            api_manifest = json.loads((output / "HUSK_HOST_API_MANIFEST.json").read_text(encoding="utf-8"))
            self.assertIn("husk_fixture_start — declared / defined", api_report)
            self.assertIn("husk_missing_api", api_report)
            self.assertEqual(len(api_manifest), 2)
            missing = next(item for item in api_manifest if item["symbol"] == "husk_missing_api")
            self.assertFalse(missing["declared"])
            self.assertFalse(missing["defined"])
            source_manifest = json.loads((output / "HUSK_SOURCE_MANIFEST.json").read_text(encoding="utf-8"))
            self.assertIn("husk_fixture_perf", source_manifest["host_api_types"])


if __name__ == "__main__":
    unittest.main()
