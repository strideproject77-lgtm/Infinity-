#!/usr/bin/env python3
"""Host-side regression tests for INFINITYAPKArchive.c (requires Python 3 and a C compiler)."""
from __future__ import annotations

import ctypes
import pathlib
import subprocess
import tempfile
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "LiveContainerSwiftUI" / "Strata3" / "INFINITYAPKArchive.c"
INCLUDE = SOURCE.parent


class APKArchiveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="infinity-apk-test-")
        library = pathlib.Path(cls.temp.name) / "libinfinityapk.so"
        subprocess.run(
            ["cc", "-shared", "-fPIC", "-O2", "-I", str(INCLUDE), str(SOURCE), "-lz", "-o", str(library)],
            check=True,
        )
        cls.lib = ctypes.CDLL(str(library))
        cls.lib.infinity_apk_extract_entry.argtypes = [
            ctypes.POINTER(ctypes.c_uint8), ctypes.c_size_t, ctypes.c_char_p,
            ctypes.POINTER(ctypes.POINTER(ctypes.c_uint8)), ctypes.POINTER(ctypes.c_size_t),
        ]
        cls.lib.infinity_apk_extract_entry.restype = ctypes.c_int
        cls.lib.infinity_apk_free.argtypes = [ctypes.c_void_p]

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def extract(self, archive: bytes, name: str):
        source = (ctypes.c_uint8 * len(archive)).from_buffer_copy(archive)
        output = ctypes.POINTER(ctypes.c_uint8)()
        output_length = ctypes.c_size_t()
        status = self.lib.infinity_apk_extract_entry(
            source, len(archive), name.encode(), ctypes.byref(output), ctypes.byref(output_length)
        )
        try:
            result = ctypes.string_at(output, output_length.value) if status == 0 else None
        finally:
            if output:
                self.lib.infinity_apk_free(output)
        return status, result

    def make_zip(self, method: int, payload: bytes) -> bytes:
        buffer = pathlib.Path(self.temp.name) / "fixture.apk"
        compression = zipfile.ZIP_STORED if method == 0 else zipfile.ZIP_DEFLATED
        with zipfile.ZipFile(buffer, "w", compression=compression) as archive:
            archive.writestr("AndroidManifest.xml", payload)
            archive.writestr("classes.dex", b"dex\n035\0")
        return buffer.read_bytes()

    def test_linux_swift_archive_shim_matches_the_exported_c_api(self):
        shim = (ROOT / "tests" / "fixtures" / "INFINITYAPKArchiveLinuxShim.swift").read_text(encoding="utf-8")
        header = (INCLUDE / "INFINITYAPKArchive.h").read_text(encoding="utf-8")
        self.assertIn("@_silgen_name(\"infinity_apk_extract_entry\")", shim)
        self.assertIn("@_silgen_name(\"infinity_apk_free\")", shim)
        self.assertIn("const uint8_t *archive, size_t archive_length", header)
        self.assertIn("uint8_t **output, size_t *output_length", header)
        self.assertIn("void infinity_apk_free(void *pointer)", header)
        self.assertIn("UnsafePointer<UInt8>?", shim)
        self.assertIn("UnsafeMutablePointer<Int>?", shim)

    def test_extract_stored_manifest(self):
        payload = b"binary-xml-stored-fixture"
        status, result = self.extract(self.make_zip(0, payload), "AndroidManifest.xml")
        self.assertEqual(status, 0)
        self.assertEqual(result, payload)

    def test_extract_deflated_manifest(self):
        payload = (b"binary-xml-deflated-fixture-" * 2048)
        status, result = self.extract(self.make_zip(8, payload), "AndroidManifest.xml")
        self.assertEqual(status, 0)
        self.assertEqual(result, payload)

    def test_missing_entry_is_reported(self):
        status, result = self.extract(self.make_zip(0, b"manifest"), "missing.bin")
        self.assertEqual(status, 5)
        self.assertIsNone(result)

    def test_corrupt_archive_is_rejected(self):
        archive = bytearray(self.make_zip(8, b"manifest-payload" * 100))
        archive[52] ^= 0x55
        status, result = self.extract(bytes(archive), "AndroidManifest.xml")
        self.assertNotEqual(status, 0)
        self.assertIsNone(result)


if __name__ == "__main__":
    unittest.main()
