import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from codemagic_log_chunks import MAX_CHUNK_BYTES, split_log


class CodemagicLogChunkTests(unittest.TestCase):
    def test_small_log_keeps_legacy_path(self):
        self.assertEqual(split_log("build.log", b"hello"), [("latest/build.log", b"hello")])

    def test_large_log_is_split_into_numbered_parts(self):
        payload = bytes(range(256)) * 50000
        pieces = split_log("xcodebuild-archive.log", payload, 1024 * 1024)
        self.assertEqual(pieces[0][0], "latest/xcodebuild-archive.log")
        self.assertEqual(pieces[1][0], "latest/xcodebuild-archive.log.part002")
        self.assertEqual(pieces[2][0], "latest/xcodebuild-archive.log.part003")
        self.assertEqual(b"".join(data for _, data in pieces), payload)
        self.assertTrue(all(len(data) <= 1024 * 1024 for _, data in pieces))

    def test_empty_log_still_has_one_piece(self):
        self.assertEqual(split_log("submodules.log", b""), [("latest/submodules.log", b"")])

    def test_rejects_oversized_chunk_setting(self):
        with self.assertRaises(ValueError):
            split_log("build.log", b"x", MAX_CHUNK_BYTES + 1)


if __name__ == "__main__":
    unittest.main()
