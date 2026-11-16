#!/usr/bin/env python3
"""Inventory the pinned Husk native engine and selected iOS host sources.

This is a deterministic source/dependency/provenance inventory. It is not a
compiler, complete license opinion, or proof of iOS/runtime compatibility.
"""
from __future__ import annotations

import argparse
import collections
import json
import pathlib
import re
import sys

SOURCE_SUFFIXES = {".c", ".m", ".mm", ".cc", ".cpp", ".cxx", ".S", ".s", ".swift"}
C_SOURCE_SUFFIXES = {".c", ".m", ".mm", ".cc", ".cpp", ".cxx", ".S", ".s"}
HEADER_SUFFIXES = {".h", ".hh", ".hpp", ".hxx", ".inc", ".def"}
SCRIPT_SUFFIXES = {".sh", ".py"}
INCLUDE_RE = re.compile(r'^\s*#\s*include\s*"([^"]+)"', re.MULTILINE)
SYSTEM_INCLUDE_RE = re.compile(r'^\s*#\s*include\s*<([^>]+)>', re.MULTILINE)
SWIFT_IMPORT_RE = re.compile(r'^\s*(?:@preconcurrency\s+)?import\s+([A-Za-z_][A-Za-z0-9_]*)', re.MULTILINE)
SPDX_RE = re.compile(r"SPDX-License-Identifier:\s*([^\s*]+)")
COPYRIGHT_RE = re.compile(r"SPDX-FileCopyrightText:|Copyright\s+(?:\(c\)\s*)?\d{4}", re.IGNORECASE)

ROOTS = ("translation-layer", "translation-layer-next", "host-runtime", "host-reference", "build-support", "upstream-docs", "resources")

def classify(path: pathlib.Path) -> str:
    suffix = path.suffix
    if suffix in C_SOURCE_SUFFIXES:
        return "native-source"
    if suffix == ".swift":
        return "swift-host-source"
    if suffix in HEADER_SUFFIXES:
        return "header"
    if suffix in SCRIPT_SUFFIXES:
        return "build-script"
    if suffix in {".md", ".txt"}:
        return "documentation"
    return "other"

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--vendor-root", default="Vendor/Husk")
    parser.add_argument("--output-dir", default="docs/generated")
    args = parser.parse_args()

    root = pathlib.Path(args.vendor_root).resolve()
    selected_roots = [root / name for name in ROOTS]
    missing_roots = [str(p) for p in selected_roots if not p.is_dir()]
    if missing_roots:
        print("Missing imported Husk groups: " + ", ".join(missing_roots), file=sys.stderr)
        return 2

    files = sorted(p for base in selected_roots for p in base.rglob("*") if p.is_file())
    basename_index: dict[str, list[pathlib.Path]] = collections.defaultdict(list)
    for path in files:
        basename_index[path.name].append(path)

    by_kind = collections.Counter()
    by_suffix = collections.Counter()
    entries = []
    unresolved_includes = []
    no_spdx = []
    swift_imports = collections.Counter()
    system_includes = collections.Counter()

    for path in files:
        rel = path.relative_to(root).as_posix()
        kind = classify(path)
        by_kind[kind] += 1
        by_suffix[path.suffix or "[no extension]"] += 1
        try:
            content = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            content = ""

        spdx = SPDX_RE.search(content[:8192])
        if not spdx:
            no_spdx.append(rel)
        quoted = INCLUDE_RE.findall(content)
        unresolved = []
        for include in quoted:
            candidate = (path.parent / include).resolve()
            if candidate.is_file():
                continue
            if not basename_index.get(pathlib.PurePosixPath(include).name):
                unresolved.append(include)
                unresolved_includes.append((rel, include))
        angle = SYSTEM_INCLUDE_RE.findall(content)
        imports = SWIFT_IMPORT_RE.findall(content) if path.suffix == ".swift" else []
        swift_imports.update(imports)
        system_includes.update(angle)

        entries.append({
            "path": rel,
            "kind": kind,
            "suffix": path.suffix,
            "spdx": spdx.group(1) if spdx else None,
            "has_copyright_marker": bool(COPYRIGHT_RE.search(content[:8192])),
            "quoted_includes": quoted,
            "unresolved_quoted_includes": unresolved,
            "system_includes": angle,
            "swift_imports": imports,
        })

    revision_file = root / "UPSTREAM_REVISION.txt"
    revision = revision_file.read_text(encoding="utf-8").strip() if revision_file.exists() else None
    output = pathlib.Path(args.output_dir)
    output.mkdir(parents=True, exist_ok=True)
    manifest_path = output / "HUSK_SOURCE_MANIFEST.json"
    report_path = output / "HUSK_SOURCE_AUDIT.md"
    manifest_path.write_text(json.dumps({
        "upstream": "https://github.com/Leviidev/Husk",
        "revision_file": revision,
        "imported_groups": list(ROOTS),
        "file_count": len(files),
        "counts_by_kind": dict(sorted(by_kind.items())),
        "counts_by_suffix": dict(sorted(by_suffix.items())),
        "swift_imports": dict(sorted(swift_imports.items())),
        "system_header_includes": dict(sorted(system_includes.items())),
        "files": entries,
    }, indent=2) + "\n", encoding="utf-8")

    report = [
        "# Husk source and host integration audit",
        "",
        "> Inventory only. This does not prove compilation, linking, complete license compatibility, or APK execution.",
        "",
        f"- Total imported files: **{len(files)}**",
        f"- Native C/Objective-C/C++/assembly sources: **{by_kind['native-source']}**",
        f"- Swift host-runtime sources: **{by_kind['swift-host-source']}**",
        f"- Headers/includes: **{by_kind['header']}**",
        f"- Build recipes: **{by_kind['build-script']}**",
        f"- Technical/licensing documents: **{by_kind['documentation']}**",
        f"- Files without SPDX identifier in first 8 KiB: **{len(no_spdx)}**",
        f"- Quoted includes with no matching local basename: **{len(unresolved_includes)}**",
        "",
        "## Imported groups",
        "",
        *[f"- {name}/" for name in ROOTS],
        "",
        "## Swift module imports",
        "",
        *[f"- {name}: {count}" for name, count in sorted(swift_imports.items())],
        "",
        "## System header includes",
        "",
        *[f"- {name}: {count}" for name, count in sorted(system_includes.items())],
        "",
        "## Unresolved quoted includes",
        "",
    ]
    report += ([f"- {path}: {include}" for path, include in unresolved_includes]
               if unresolved_includes else ["None detected by this local-path scan."])
    report += ["", "## Files without SPDX markers", ""]
    report += ([f"- {path}" for path in no_spdx] if no_spdx else ["None detected."])
    report += [
        "",
        "## Integration gates",
        "",
        "- Keep the vendor snapshot outside Strata's synchronized Xcode source groups until a dedicated runtime target is reviewed.",
        "- host-reference/ is source-audit material only; never add HuskApp.swift or its @main entry point to Strata's target.",
        "- host-reference/HuskBridge.h is also audit-only: it declares QEMU/JIT interfaces and includes Husk-only pairing headers; create an INFINITY-owned translation-layer bridge instead.",
        "- build-support/project.yml records upstream source membership, frameworks and resource requirements; it is a reference, not a replacement for Strata project settings.",
        "- Do not import QEMU guest orchestration, QEMU binaries, signing/refresh systems, or Husk's complete XcodeGen project.",
        "- Review every file's provenance and license, including embedded .inc data and generated assets; absence of an SPDX marker is not proof of an incompatible license.",
        "- Resolve all native symbols, framework/linker requirements, deployment-target constraints, Swift type dependencies, resources, and runtime data before adding target membership.",
        "- The legacy translation-layer/ tree is included because the selected Swift host sources still reference its attempt/check APIs; do not assume translation-layer-next alone satisfies the host dependency graph.",
        "- The native runtime's ANGLE/GLES, Java runtime assets, system fonts/certificates, Vulkan/MoltenVK path, and engine-specific bridges are separate dependency groups; do not mark an engine ready until its required assets are present.",
        "- Vendor inventory does not imply build membership: host-reference/, resources/, and all source groups remain outside Xcode targets until a separate reviewed integration step.",
        "- Preserve Strata and SideStore target memberships, entitlements, signing/refresh/install flows, and the existing IPA builder.",
        "",
    ]
    report_path.write_text("\n".join(report), encoding="utf-8")
    print(f"Audited {len(files)} imported files")
    print(f"Wrote {manifest_path} and {report_path}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
