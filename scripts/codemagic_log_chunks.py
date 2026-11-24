"""Byte-safe chunking for Codemagic logs published to GitHub.

GitHub log files are deliberately kept below 4 MiB so browser/API readers
with smaller response limits can retrieve every piece reliably.
"""
from __future__ import annotations

DEFAULT_CHUNK_BYTES = 3 * 1024 * 1024
MAX_CHUNK_BYTES = 4 * 1024 * 1024


def split_log(name: str, data: bytes, chunk_bytes: int = DEFAULT_CHUNK_BYTES):
    """Return (repository_path, payload) pairs; first piece keeps the legacy path."""
    if not name or "/" in name or "\\" in name:
        raise ValueError("name must be a plain filename")
    if not isinstance(data, bytes):
        raise TypeError("data must be bytes")
    if chunk_bytes < 1 or chunk_bytes > MAX_CHUNK_BYTES:
        raise ValueError(f"chunk_bytes must be between 1 and {MAX_CHUNK_BYTES}")
    pieces = []
    for offset in range(0, max(len(data), 1), chunk_bytes):
        index = offset // chunk_bytes + 1
        suffix = "" if index == 1 else f".part{index:03d}"
        pieces.append((f"latest/{name}{suffix}", data[offset:offset + chunk_bytes]))
    return pieces
