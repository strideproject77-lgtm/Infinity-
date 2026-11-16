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
    def test_importer_is_pinned_and_includes_native_and_host_runtime(self):
        script = IMPORTER.read_text(encoding="utf-8")
        self.assertIn('REVISION="29abb512d81bf8cc08babcbe7f7007cb557208ef"', script)
        self.assertIn("src/translation-layer-next", script)
        for name in (
            "TLUnityView.swift",
            "TLAppSettings.swift",
            "HuskGamepad.swift",
            "HuskKeyboard.swift",
            "HuskLog.swift",
            "HuskFilePicker.swift",
            "build_java_runtime.sh",
            "build_android_system.sh",
            "build_angle_ios.sh",
            "build_art_support.sh",
        ):
            self.assertIn(name, script)

    def test_importer_does_not_vendor_qemu_app_or_side_store_workflows(self):
        script = IMPORTER.read_text(encoding="utf-8")
        forbidden_paths = (
            "src/app/Husk/QemuRunner.swift",
            "src/app/Husk/HuskApp.swift",
            "src/app/Husk/HuskBridge.h",
            "src/app/Husk.xcodeproj",
            "SideStoreSupport/",
            ".github/workflows/build.yml",
        )
        for path in forbidden_paths:
            self.assertNotIn(path, script)

    def test_importer_only_replaces_owned_vendor_groups(self):
        script = IMPORTER.read_text(encoding="utf-8")
        self.assertIn("translation-layer-next host-runtime build-support upstream-docs", script)
        self.assertIn('cp "$STAGE/HUSK-LICENSE" "$DEST/HUSK-LICENSE"', script)
        self.assertIn("THIRD_PARTY_NOTICES.md", script)

    def test_auditor_generates_native_and_swift_dependency_inventory(self):
        with tempfile.TemporaryDirectory() as temp:
            base = pathlib.Path(temp)
            vendor = base / "Vendor" / "Husk"
            for group in ("translation-layer-next", "host-runtime", "build-support", "upstream-docs"):
                (vendor / group).mkdir(parents=True)
            (vendor / "UPSTREAM_REVISION.txt").write_text("Revision: fixture\n", encoding="utf-8")
            (vendor / "translation-layer-next" / "engine.c").write_text(
                '/* SPDX-License-Identifier: GPL-2.0-or-later */\n#include "engine.h"\n#include <pthread.h>\n',
                encoding="utf-8",
            )
            (vendor / "translation-layer-next" / "engine.h").write_text(
                "/* SPDX-License-Identifier: GPL-2.0-or-later */\n",
                encoding="utf-8",
            )
            (vendor / "host-runtime" / "Host.swift").write_text(
                "// SPDX-License-Identifier: GPL-2.0-or-later\nimport Foundation\nimport UIKit\n",
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
            self.assertEqual(manifest["file_count"], 5)
            self.assertEqual(manifest["counts_by_kind"]["native-source"], 1)
            self.assertEqual(manifest["counts_by_kind"]["swift-host-source"], 1)
            self.assertEqual(manifest["swift_imports"]["UIKit"], 1)
            self.assertIn("pthread.h", manifest["system_header_includes"])
            self.assertIn("Husk source and host integration audit", report)


if __name__ == "__main__":
    unittest.main()
