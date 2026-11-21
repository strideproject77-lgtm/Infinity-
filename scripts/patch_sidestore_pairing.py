#!/usr/bin/env python3
"""Apply the reviewed SideStore pairing-file protocol typo fix to a source checkout.

This patch is intentionally source-only. INFINITY currently bundles a prebuilt
SideStore IPA, so this helper does not alter an already-built IPA.
"""
from __future__ import annotations

import argparse
from pathlib import Path

OLD = "} else if pprotocol == .rppairing {"
NEW = "} else if pprotocol == .lockdown {"


def patch_source(source: str) -> str:
    old_count = source.count(OLD)
    new_count = source.count(NEW)
    if old_count == 0 and new_count == 1:
        return source  # already patched
    if old_count != 1 or new_count != 0:
        raise ValueError(
            "Expected exactly one unpatched Lockdown protocol branch; "
            f"found old={old_count}, already_fixed={new_count}. Refusing an unsafe edit."
        )
    return source.replace(OLD, NEW, 1)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_file", type=Path)
    args = parser.parse_args()
    original = args.source_file.read_text(encoding="utf-8")
    updated = patch_source(original)
    if updated != original:
        args.source_file.write_text(updated, encoding="utf-8")
        print("Applied SideStore Lockdown pairing protocol branch fix.")
    else:
        print("SideStore pairing protocol branch is already fixed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
