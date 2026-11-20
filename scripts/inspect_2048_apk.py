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
    sha1_valid = hashlib.sha1(data[32:]).digest() == data[12:32]
    stored_checksum = int.from_bytes(data[8:12], "little")
    adler32_valid = (zlib.adler32(data[12:]) & 0xFFFFFFFF) == stored_checksum
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
        "sha1_signature_valid": sha1_valid,
        "adler32_checksum_valid": adler32_valid,
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
    completed = subprocess.run(command, check=True, text=True, encoding="utf-8",
                               errors="replace", stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT)
    output.write_text(completed.stdout, encoding="utf-8")
    return completed.stdout


def parse_manifest_facts(badging: str, manifest_xmltree: str) -> dict[str, str | None]:
    def capture(pattern: str, source: str) -> str | None:
        match = re.search(pattern, source, re.MULTILINE | re.DOTALL)
        return match.group(1) if match else None

    return {
        "min_sdk": capture(r"^sdkVersion:'([^']+)'", badging),
        "target_sdk": capture(r"^targetSdkVersion:'([^']+)'", badging),
        "compile_sdk": capture(r"compileSdkVersion='([^']+)'", badging),
        "launch_activity": capture(r"^launchable-activity: name='([^']+)'", badging),
        "android_support_version": capture(
            r'android\.support\.VERSION[^\n]*\n\s*A: android:value[^\n]*="([^"]+)"',
            manifest_xmltree,
        ),
    }


def dependency_class_descriptors(dex_payloads: dict[str, bytes]) -> dict[str, set[str]]:
    patterns = {
        "android_support": rb"Landroid/support/[A-Za-z0-9_/$]+;",
        "androidx": rb"Landroidx/[A-Za-z0-9_/$]+;",
        "google_play_services": rb"Lcom/google/android/gms/[A-Za-z0-9_/$]+;",
    }
    result = {name: set() for name in patterns}
    for payload in dex_payloads.values():
        for name, pattern in patterns.items():
            result[name].update(
                match.decode("ascii", errors="replace")
                for match in re.findall(pattern, payload)
            )
    return result



def parse_dex_disassembly(disassembly: str) -> dict[str, Any]:
    """Extract app/support class identity and Android framework calls from DEX class blocks."""
    descriptors = sorted(set(re.findall(
        r"Class descriptor\s*:\s*'([^']+)'", disassembly
    )))
    class_blocks = re.split(r"(?=^Class #\d+)", disassembly, flags=re.MULTILINE)
    app_classes = []
    main_superclass = None
    support_superclasses = {}
    app_method_refs = set()
    support_method_refs = set()
    for block in class_blocks:
        descriptor_match = re.search(
            r"Class descriptor\s*:\s*'([^']+)'", block
        )
        if descriptor_match is None:
            continue
        descriptor = descriptor_match.group(1)
        superclass_match = re.search(
            r"Superclass\s*:\s*'([^']+)'", block
        )
        superclass = superclass_match.group(1) if superclass_match else None
        if descriptor.startswith("Lcom/tpcstld/twozerogame/"):
            app_classes.append(descriptor)
            if descriptor == "Lcom/tpcstld/twozerogame/MainActivity;":
                main_superclass = superclass
            target_support_classes = (
                "Landroid/support/v7/app/AppCompatActivity;",
                "Landroid/support/v4/app/FragmentActivity;",
                "Landroid/support/v4/app/SupportActivity;",
            )
        elif descriptor.startswith("Landroid/support/"):
            if descriptor in (
                "Landroid/support/v7/app/AppCompatActivity;",
                "Landroid/support/v4/app/FragmentActivity;",
                "Landroid/support/v4/app/SupportActivity;",
            ):
                support_superclasses[descriptor] = superclass
            target_support_classes = ()
        else:
            continue
        refs = app_method_refs if descriptor.startswith("Lcom/tpcstld/twozerogame/") else support_method_refs
        for owner, method in re.findall(
            r"(L[^;\s]+;)(?:->|\.)([A-Za-z_$][A-Za-z0-9_$]*)\s*:\s*\(",
            block,
        ):
            if owner.startswith("Landroid/") and not owner.startswith("Landroid/support/"):
                refs.add(f"{owner}->{method}")
    return {
        "class_descriptor_count": len(descriptors),
        "app_class_descriptors": sorted(set(app_classes)),
        "main_activity_superclass": main_superclass,
        "support_superclasses": support_superclasses,
        "android_framework_method_ref_count": len(app_method_refs),
        "android_framework_method_refs": sorted(app_method_refs),
        "support_framework_method_ref_count": len(support_method_refs),
        "support_framework_method_refs": sorted(support_method_refs),
    }


def audit_framework_api_methods(method_refs: list[str], repo_root: Path) -> dict[str, Any]:
    """Check referenced Android API methods against Husk Java framework sources and superclasses."""
    source_roots = (
        repo_root / "Vendor/Husk/src/java-framework/src",
        repo_root / "Vendor/Husk/src/java-framework/gen-src",
    )
    source_cache: dict[str, tuple[str, str, dict[str, str]] | None] = {}

    def source_exists(qualified_name: str) -> bool:
        relative = qualified_name.replace(".", "/") + ".java"
        return any((root / relative).is_file() for root in source_roots)

    def load_source(descriptor: str):
        if descriptor in source_cache:
            return source_cache[descriptor]
        relative = descriptor[1:-1].split("$")[0] + ".java"
        for root in source_roots:
            path = root / relative
            if path.is_file():
                source = path.read_text(encoding="utf-8", errors="replace")
                package_match = re.search(r"^\s*package\s+([\w.]+)\s*;", source, re.MULTILINE)
                package = package_match.group(1) if package_match else ""
                import_names = re.findall(
                    r"^\s*import\s+(?:static\s+)?([\w.$]+)\s*;",
                    source,
                    re.MULTILINE,
                )
                imports = {
                    name.split(".")[-1]: name
                    for name in import_names if not name.endswith(".*")
                }
                wildcard_imports = [
                    name[:-2] for name in import_names if name.endswith(".*")
                ]
                result = (source, package, imports, wildcard_imports)
                source_cache[descriptor] = result
                return result
        source_cache[descriptor] = None
        return None

    def parent_descriptor(descriptor: str, source: str, package: str,
                          imports: dict[str, str],
                          wildcard_imports: list[str]) -> str | None:
        simple_name = descriptor[1:-1].split("/")[-1].split("$")[-1]
        declaration = re.search(
            r"\b(?:class|interface|enum)\s+" + re.escape(simple_name)
            + r"\b(?:\s*<[^>{}]*>)?\s+extends\s+([\w.$]+)",
            source,
        )
        if declaration is None:
            return None
        parent = declaration.group(1)
        if parent in imports:
            qualified = imports[parent]
        elif parent.startswith(("android.", "java.", "javax.", "dalvik.")):
            qualified = parent
        elif "." in parent:
            qualified = parent
        else:
            candidates = ([package + "." + parent] if package else []) + [
                prefix + "." + parent for prefix in wildcard_imports
            ]
            qualified = next((candidate for candidate in candidates
                              if source_exists(candidate)), None)
            if qualified is None:
                return None
        return "L" + qualified.replace(".", "/") + ";"

    missing_methods = []
    missing_owners = set()
    checked = 0
    object_methods = {"equals", "hashCode", "toString", "getClass", "wait",
                      "notify", "notifyAll", "clone", "finalize"}
    for reference in sorted(set(method_refs)):
        if "->" not in reference:
            continue
        owner, method = reference.split("->", 1)
        checked += 1
        current = owner
        visited = set()
        found = method in object_methods
        for _ in range(10):
            if found or current in visited:
                break
            visited.add(current)
            loaded = load_source(current)
            if loaded is None:
                if current == owner:
                    missing_owners.add(owner)
                break
            source, package, imports, wildcard_imports = loaded
            if re.search(r"\b" + re.escape(method) + r"\s*\(", source):
                found = True
                break
            parent = parent_descriptor(current, source, package, imports, wildcard_imports)
            if parent is None:
                break
            current = parent
        if not found:
            missing_methods.append(reference)
    return {
        "checked_method_ref_count": checked,
        "missing_owner_classes": sorted(missing_owners),
        "missing_owner_class_count": len(missing_owners),
        "unresolved_method_refs": missing_methods,
        "unresolved_method_ref_count": len(missing_methods),
    }


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

    manifest_xmltree = run_tool(
        [args.aapt, "dump", "xmltree", str(apk), "AndroidManifest.xml"],
        output / "manifest-xmltree.txt",
    )
    run_tool([args.aapt, "dump", "resources", str(apk)], output / "resources.txt")
    manifest_facts = parse_manifest_facts(badging, manifest_xmltree)

    dex_payloads = inventory.pop("dex_payloads")
    dependency_sets = dependency_class_descriptors(dex_payloads)
    dex_disassembly_facts = {}
    for dex_name, payload in dex_payloads.items():
        safe_name = dex_name.replace("/", "_")
        extracted = output / safe_name
        extracted.write_bytes(payload)
        disassembly = run_tool(
            [args.dexdump, "-d", str(extracted)],
            output / f"{safe_name}.disassembly.txt",
        )
        dex_disassembly_facts[dex_name] = parse_dex_disassembly(disassembly)

    all_framework_method_refs = sorted({
        *next(iter(dex_disassembly_facts.values()))["android_framework_method_refs"],
        *next(iter(dex_disassembly_facts.values()))["support_framework_method_refs"],
    })
    framework_api_audit = audit_framework_api_methods(
        all_framework_method_refs, Path(__file__).resolve().parents[1]
    )
    apk_digest = hashlib.sha256(apk.read_bytes()).hexdigest()
    report = {
        "source_release": APK_RELEASE_URL,
        "expected_package": EXPECTED_PACKAGE,
        "package": package_name,
        "version_code": version_code,
        "version_name": version_name,
        **manifest_facts,
        "apk_filename": apk.name,
        "apk_bytes": apk.stat().st_size,
        "apk_sha256": apk_digest,
        **inventory,
        "dependency_class_descriptors": {
            name: sorted(values) for name, values in dependency_sets.items()
        },
        "dependency_class_descriptor_counts": {
            name: len(values) for name, values in dependency_sets.items()
        },
        "dex_disassembly_facts": dex_disassembly_facts,
        "framework_api_audit": framework_api_audit,
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
        f"- Minimum SDK: {manifest_facts['min_sdk']}",
        f"- Target SDK: {manifest_facts['target_sdk']}",
        f"- Compile SDK: {manifest_facts['compile_sdk']}",
        f"- Launcher activity: `{manifest_facts['launch_activity']}`",
        f"- Android Support Library version: {manifest_facts['android_support_version']}",
        f"- DEX files: {', '.join(inventory['dex_files'])}",
        f"- Resource entries: {len(inventory['resource_entries'])}",
        f"- Native libraries: {len(inventory['native_libraries'])}",
        f"- Android Support class descriptors: {len(dependency_sets['android_support'])}",
        f"- AndroidX class descriptors: {len(dependency_sets['androidx'])}",
        f"- Google Play Services class descriptors: {len(dependency_sets['google_play_services'])}",
        f"- MainActivity superclass: {next(iter(dex_disassembly_facts.values())).get('main_activity_superclass')}",
        f"- Android framework method references: {sum(v['android_framework_method_ref_count'] for v in dex_disassembly_facts.values())}",
        f"- DEX SHA-1 signature valid: {all(v['sha1_signature_valid'] for v in inventory['dex_headers'].values())}",
        f"- Framework API refs not resolved from Husk Java sources/superclasses: {framework_api_audit['unresolved_method_ref_count']} of {framework_api_audit['checked_method_ref_count']}",
        "",
        "## DEX header counts",
        "",
    ]
    for name, header in inventory["dex_headers"].items():
        summary.append(
            f"- `{name}`: DEX {header['version']}, "
            f"{header['class_defs_size']} classes, "
            f"{header['method_ids_size']} method IDs, "
            f"{header['field_ids_size']} field IDs, "
            f"SHA-1={'ok' if header['sha1_signature_valid'] else 'MISMATCH'}, "
            f"Adler-32={'ok' if header['adler32_checksum_valid'] else 'MISMATCH'}"
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
