#!/usr/bin/env python3
"""Forensic inventory of the pinned upstream tpcstld 2048 release APK.

This inspects a real distributable APK. It does not execute the app and does not
claim Husk compatibility. Android build-tools provide the authoritative AAPT
manifest/resource dump and DEX disassembly.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import zlib
import sys
import zipfile
from pathlib import Path
from typing import Any

EXPECTED_PACKAGE = "com.tpcstld.twozerogame"
APK_RELEASE_URL = (
    "https://github.com/tpcstld/2048/releases/download/1.3.3/133-release.apk"
)
DEX_HEADER_SIZE = 0x70
DEX_ENDIAN_CONSTANT = 0x12345678


def parse_dex_header(data: bytes) -> dict[str, Any]:
    """Validate and extract the fixed DEX header fields used by this audit."""
    if len(data) < DEX_HEADER_SIZE or not data.startswith(b"dex\n") or data[7:8] != b"\0":
        raise ValueError("invalid or truncated DEX header")
    version_bytes = data[4:7]
    if not version_bytes.isdigit():
        raise ValueError("unsupported DEX version marker")
    file_size, header_size, endian_tag = (
        int.from_bytes(data[offset:offset + 4], "little")
        for offset in (32, 36, 40)
    )
    if file_size != len(data):
        raise ValueError(f"DEX file_size mismatch: header={file_size}, actual={len(data)}")
    if header_size != DEX_HEADER_SIZE:
        raise ValueError(f"unexpected DEX header_size: {header_size}")
    if endian_tag != DEX_ENDIAN_CONSTANT:
        raise ValueError(f"unsupported DEX endian tag: 0x{endian_tag:08x}")
    if hashlib.sha1(data[32:]).digest() != data[12:32]:
        raise ValueError("DEX SHA-1 signature mismatch")
    stored_checksum = int.from_bytes(data[8:12], "little")
    if zlib.adler32(data[12:]) & 0xFFFFFFFF != stored_checksum:
        raise ValueError("DEX Adler-32 checksum mismatch")
    fields = {
        "string_ids_size": (56, 60, 4),
        "type_ids_size": (64, 68, 4),
        "proto_ids_size": (72, 76, 12),
        "field_ids_size": (80, 84, 8),
        "method_ids_size": (88, 92, 8),
        "class_defs_size": (96, 100, 32),
    }
    result: dict[str, Any] = {
        "version": version_bytes.decode("ascii"),
        "file_size": file_size,
        "header_size": header_size,
        "checksum_adler32": data[8:12].hex(),
        "sha1_signature": data[12:32].hex(),
    }
    for name, (size_offset, data_offset, item_size) in fields.items():
        count = int.from_bytes(data[size_offset:size_offset + 4], "little")
        offset = int.from_bytes(data[data_offset:data_offset + 4], "little")
        if count == 0:
            if offset != 0:
                raise ValueError(f"empty DEX section has a nonzero offset: {name}")
        elif (offset < DEX_HEADER_SIZE or offset % 4 != 0
              or count > (len(data) - offset) // item_size):
            raise ValueError(f"DEX section is out of bounds: {name}")
        result[name] = count
    return result


def archive_inventory(apk_path: Path) -> dict[str, Any]:
    with zipfile.ZipFile(apk_path) as archive:
        bad_entry = archive.testzip()
        if bad_entry is not None:
            raise ValueError(f"APK CRC check failed for {bad_entry}")
        names = [item.filename for item in archive.infolist() if not item.is_dir()]
        if "AndroidManifest.xml" not in names:
            raise ValueError("APK has no AndroidManifest.xml")
        dex_names = [
            name for name in names
            if re.fullmatch(r"classes(?:[2-9]|[1-9][0-9]+)?\.dex", name)
        ]
        dex_names.sort(key=lambda name: 1 if name == "classes.dex"
                       else int(name[len("classes"):-len(".dex")]))
        if not dex_names:
            raise ValueError("APK has no classes.dex")
        dex_headers = {}
        dex_payloads = {}
        for name in dex_names:
            payload = archive.read(name)
            dex_headers[name] = parse_dex_header(payload)
            dex_payloads[name] = payload
        return {
            "entries": names,
            "dex_files": dex_names,
            "dex_headers": dex_headers,
            "dex_payloads": dex_payloads,
            "resource_entries": sorted(
                name for name in names
                if name == "resources.arsc" or name.startswith(("res/", "assets/"))
            ),
            "native_libraries": sorted(
                name for name in names if name.startswith("lib/") and name.endswith(".so")
            ),
        }


def run_tool(command: list[str], output: Path) -> str:
    completed = subprocess.run(command, check=True, text=True, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT)
    output.write_text(completed.stdout, encoding="utf-8")
    return completed.stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--aapt", required=True)
    parser.add_argument("--dexdump", required=True)
    args = parser.parse_args()

    apk = args.apk.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if not apk.is_file():
        parser.error(f"APK does not exist: {apk}")

    inventory = archive_inventory(apk)
    badging = run_tool([args.aapt, "dump", "badging", str(apk)], output / "badging.txt")
    package_match = re.search(r"^package: name='([^']+)' versionCode='([^']*)' versionName='([^']*)'",
                              badging, re.MULTILINE)
    if package_match is None:
        raise ValueError("AAPT did not report an application package identity")
    package_name, version_code, version_name = package_match.groups()
    if package_name != EXPECTED_PACKAGE:
        raise ValueError(
            f"unexpected APK package: expected {EXPECTED_PACKAGE}, got {package_name}"
        )

    run_tool([args.aapt, "dump", "xmltree", str(apk), "AndroidManifest.xml"],
             output / "manifest-xmltree.txt")
    run_tool([args.aapt, "dump", "resources", str(apk)], output / "resources.txt")

    dependency_refs: set[str] = set()
    for dex_name, payload in inventory.pop("dex_payloads").items():
        safe_name = dex_name.replace("/", "_")
        extracted = output / safe_name
        extracted.write_bytes(payload)
        run_tool([args.dexdump, "-d", str(extracted)],
                 output / f"{safe_name}.disassembly.txt")
        for match in re.findall(
            rb"L(?:androidx|com/google/android/gms)/[A-Za-z0-9_/$]+;", payload
        ):
            dependency_refs.add(match.decode("ascii", errors="replace"))

    apk_digest = hashlib.sha256(apk.read_bytes()).hexdigest()
    report = {
        "source_release": APK_RELEASE_URL,
        "expected_package": EXPECTED_PACKAGE,
        "package": package_name,
        "version_code": version_code,
        "version_name": version_name,
        "apk_filename": apk.name,
        "apk_bytes": apk.stat().st_size,
        "apk_sha256": apk_digest,
        **inventory,
        "androidx_and_google_play_class_descriptors": sorted(dependency_refs),
        "dex_disassembly_files": [
            f"{name.replace('/', '_')}.disassembly.txt"
            for name in inventory["dex_files"]
        ],
        "inspection_tools": {
            "aapt": args.aapt,
            "dexdump": args.dexdump,
        },
        "limitations": [
            "Static APK inventory and DEX disassembly only; no class verifier was executed.",
            "No AndroidX runtime path was executed.",
            "No APK was launched through Husk.",
        ],
    }
    (output / "report.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    summary = [
        "# tpcstld 2048 APK forensic inventory",
        "",
        f"- Release: {APK_RELEASE_URL}",
        f"- Package: `{package_name}`",
        f"- Version: `{version_name}` (code `{version_code}`)",
        f"- APK size: {apk.stat().st_size} bytes",
        f"- SHA-256: `{apk_digest}`",
        f"- DEX files: {', '.join(inventory['dex_files'])}",
        f"- Resource entries: {len(inventory['resource_entries'])}",
        f"- Native libraries: {len(inventory['native_libraries'])}",
        f"- AndroidX / Google Play class descriptors: {len(dependency_refs)}",
        "",
        "## DEX header counts",
        "",
    ]
    for name, header in inventory["dex_headers"].items():
        summary.append(
            f"- `{name}`: DEX {header['version']}, "
            f"{header['class_defs_size']} classes, "
            f"{header['method_ids_size']} method IDs, "
            f"{header['field_ids_size']} field IDs"
        )
    summary += [
        "",
        "## Interpretation boundary",
        "",
        "This is static package evidence. DEX disassembly is not proof of successful "
        "class verification, AndroidX execution, or real APK launch through Husk.",
        "",
    ]
    (output / "REPORT.md").write_text("\n".join(summary), encoding="utf-8")
    print(f"Wrote APK forensic report to {output}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        print(f"2048 APK audit failed: {error}", file=sys.stderr)
        raise SystemExit(1)
