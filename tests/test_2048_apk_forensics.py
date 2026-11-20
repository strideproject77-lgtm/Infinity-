from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

from scripts.inspect_2048_apk import (
    DEX_HEADER_SIZE,
    EXPECTED_PACKAGE,
    APK_RELEASE_URL,
    archive_inventory,
    parse_dex_header,
)

ROOT = Path(__file__).resolve().parents[1]


def make_dex(version=b"035") -> bytes:
    import hashlib
    import zlib

    data = bytearray(512)
    data[:8] = b"dex\n" + version + b"\0"
    struct.pack_into("<III", data, 32, len(data), DEX_HEADER_SIZE, 0x12345678)
    sections = (
        (56, 60, 3, 112),
        (64, 68, 2, 124),
        (72, 76, 1, 132),
        (80, 84, 4, 144),
        (88, 92, 5, 176),
        (96, 100, 2, 216),
    )
    for size_at, offset_at, count, offset in sections:
        struct.pack_into("<II", data, size_at, count, offset)
    data[12:32] = hashlib.sha1(data[32:]).digest()
    struct.pack_into("<I", data, 8, zlib.adler32(data[12:]) & 0xFFFFFFFF)
    return bytes(data)


class TPCSTLD2048APKForensicsTests(unittest.TestCase):
    def test_dex_header_reports_version_and_table_counts(self):
        result = parse_dex_header(make_dex())
        self.assertEqual(result["version"], "035")
        self.assertEqual(result["class_defs_size"], 2)
        self.assertEqual(result["method_ids_size"], 5)
        self.assertEqual(result["field_ids_size"], 4)

    def test_dex_header_rejects_truncation_and_size_mismatch(self):
        with self.assertRaisesRegex(ValueError, "invalid or truncated"):
            parse_dex_header(b"dex\n035\0")
        data = bytearray(make_dex())
        struct.pack_into("<I", data, 32, DEX_HEADER_SIZE + 1)
        with self.assertRaisesRegex(ValueError, "file_size mismatch"):
            parse_dex_header(bytes(data))
        import zlib
        data = bytearray(make_dex())
        data[12] ^= 0x01
        struct.pack_into("<I", data, 8, zlib.adler32(data[12:]) & 0xFFFFFFFF)
        result = parse_dex_header(bytes(data))
        self.assertFalse(result["sha1_signature_valid"])
        self.assertTrue(result["adler32_checksum_valid"])
        data = bytearray(make_dex())
        data[8] ^= 0x01
        result = parse_dex_header(bytes(data))
        self.assertTrue(result["sha1_signature_valid"])
        self.assertFalse(result["adler32_checksum_valid"])

    def test_archive_inventory_finds_multidex_resources_assets_and_native_libs(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "target.apk"
            with zipfile.ZipFile(apk, "w", zipfile.ZIP_DEFLATED) as archive:
                archive.writestr("AndroidManifest.xml", b"binary manifest fixture")
                archive.writestr("classes.dex", make_dex())
                archive.writestr("classes2.dex", make_dex())
                archive.writestr("classes10.dex", make_dex())
                archive.writestr("resources.arsc", b"resources")
                archive.writestr("assets/fonts/ClearSans.ttf", b"font")
                archive.writestr("res/drawable/icon.png", b"icon")
                archive.writestr("lib/arm64-v8a/libexample.so", b"native")
            result = archive_inventory(apk)
            self.assertEqual(result["dex_files"], ["classes.dex", "classes2.dex", "classes10.dex"])
            self.assertIn("assets/fonts/ClearSans.ttf", result["resource_entries"])
            self.assertIn("resources.arsc", result["resource_entries"])
            self.assertEqual(result["native_libraries"], ["lib/arm64-v8a/libexample.so"])
            self.assertEqual(result["dex_headers"]["classes2.dex"]["version"], "035")

    def test_workflow_pins_the_real_upstream_release_and_runs_aapt_and_dexdump(self):
        workflow = (ROOT / ".github/workflows/2048-apk-forensics.yml").read_text()
        script = (ROOT / "scripts/inspect_2048_apk.py").read_text()
        self.assertIn(APK_RELEASE_URL, workflow)
        self.assertIn("build-tools;35.0.0", workflow)
        self.assertIn("aapt", workflow)
        self.assertIn("dexdump", workflow)
        self.assertIn(f'EXPECTED_PACKAGE = "{EXPECTED_PACKAGE}"', script)
        self.assertIn('"dump", "xmltree"', script)
        self.assertIn('"dump", "resources"', script)
        self.assertIn('"-d"', script)
        self.assertNotIn("package_name_whitelist", script)
        self.assertNotIn("fake_execution", script)


if __name__ == "__main__":
    unittest.main()
