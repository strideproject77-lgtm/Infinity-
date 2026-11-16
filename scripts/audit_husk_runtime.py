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

HUSK_CALL_RE = re.compile(r"\b(husk_[A-Za-z0-9_]+)\s*\(")
HUSK_DECL_RE = re.compile(r"\b(husk_[A-Za-z0-9_]+)\s*\([^;{}]*?\)\s*;", re.DOTALL)
HUSK_DEF_RE = re.compile(r"\b(husk_[A-Za-z0-9_]+)\s*\([^;{}]*?\)\s*\{", re.DOTALL)

HUSK_TYPE_RE = re.compile(r"\btypedef\s+struct\s+(husk_[A-Za-z0-9_]+)\b")
C_COMMENTS_RE = re.compile(r"/\*.*?\*/|//[^\n]*", re.DOTALL)

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
    host_api_calls: dict[str, set[str]] = collections.defaultdict(set)
    native_api_declarations: dict[str, set[str]] = collections.defaultdict(set)
    native_api_definitions: dict[str, set[str]] = collections.defaultdict(set)
    native_api_types: set[str] = set()
    host_api_types: dict[str, set[str]] = collections.defaultdict(set)

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

        if rel.startswith(("translation-layer/", "translation-layer-next/")) and path.suffix in HEADER_SUFFIXES:
            clean_content = C_COMMENTS_RE.sub(" ", content)
            native_api_types.update(HUSK_TYPE_RE.findall(clean_content))
            for symbol in HUSK_DECL_RE.findall(clean_content):
                native_api_declarations[symbol].add(rel)
        elif rel.startswith(("translation-layer/", "translation-layer-next/")) and path.suffix in C_SOURCE_SUFFIXES:
            clean_content = C_COMMENTS_RE.sub(" ", content)
            for symbol in HUSK_DEF_RE.findall(clean_content):
                native_api_definitions[symbol].add(rel)
        if path.suffix == ".swift" and rel.startswith("host-runtime/"):
            for symbol in HUSK_CALL_RE.findall(content):
                if symbol in native_api_types:
                    host_api_types[symbol].add(rel)
                else:
                    host_api_calls[symbol].add(rel)

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

    # Source paths sort after host-runtime/, so classify C struct initializers after all headers are scanned.
    for symbol in list(host_api_calls):
        if symbol in native_api_types:
            host_api_types[symbol].update(host_api_calls.pop(symbol))

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
        "host_api_calls": {name: sorted(paths) for name, paths in sorted(host_api_calls.items())},
        "host_api_types": {name: sorted(paths) for name, paths in sorted(host_api_types.items())},
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
    api_entries = []
    for symbol, host_paths in sorted(host_api_calls.items()):
        api_entries.append({
            "symbol": symbol,
            "host_files": sorted(host_paths),
            "declared": symbol in native_api_declarations,
            "defined": symbol in native_api_definitions,
            "declaration_files": sorted(native_api_declarations.get(symbol, set())),
            "definition_files": sorted(native_api_definitions.get(symbol, set())),
        })
    api_manifest_path = output / "HUSK_HOST_API_MANIFEST.json"
    api_manifest_path.write_text(json.dumps(api_entries, indent=2) + "\n", encoding="utf-8")
    unresolved_decl = [item for item in api_entries if not item["declared"]]
    unresolved_def = [item for item in api_entries if not item["defined"]]
    api_report = [
        "# Husk Swift host-to-native API map",
        "",
        "> Textual first-pass scan only. It does not replace Clang/Swift compilation or linker symbol inspection.",
        "",
        f"- Husk function calls found in selected Swift host files: **{len(api_entries)}**",
        f"- C struct initializers identified separately: **{len(host_api_types)}**",
        f"- Calls with a matching declaration in the two native header trees: **{len(api_entries) - len(unresolved_decl)}**",
        f"- Calls with a matching native source definition: **{len(api_entries) - len(unresolved_def)}**",
        f"- Calls without a matching declaration: **{len(unresolved_decl)}**",
        f"- Calls without a matching definition: **{len(unresolved_def)}**",
        "",
        "## API map",
        "",
    ]
    for item in api_entries:
        state = ("declared" if item["declared"] else "NO DECLARATION") + " / " + ("defined" if item["defined"] else "NO DEFINITION")
        api_report.append("- {} — {}; host: {}".format(item["symbol"], state, ", ".join(item["host_files"])))
    api_report += ["", "## C struct initializers (not function symbols)", ""]
    api_report += (["- {} — {}".format(name, ", ".join(paths)) for name, paths in sorted(host_api_types.items())]
                   if host_api_types else ["None detected."])
    api_report += ["", "## Missing declarations", ""]
    api_report += (["- {} — {}".format(item["symbol"], ", ".join(item["host_files"])) for item in unresolved_decl]
                   if unresolved_decl else ["None detected by this textual scan."])
    api_report += ["", "## Missing native definitions", ""]
    api_report += (["- {} — {}".format(item["symbol"], ", ".join(item["host_files"])) for item in unresolved_def]
                   if unresolved_def else ["None detected by this textual scan."])
    api_report += [
        "",
        "## Integration notes",
        "",
        "- The upstream HuskBridge.h is audit-only and intentionally excluded from the native declaration scan because it also declares QEMU/JIT APIs and imports Husk-only pairing headers.",
        "- Unresolved names may be supplied by excluded host/QEMU code or generated headers; resolve each against the intended native translation-layer interface before compiling.",
        "- A text match is not proof of ABI compatibility, correct calling convention, or a successful link.",
        "",
    ]
    (output / "HUSK_HOST_API_AUDIT.md").write_text("\n".join(api_report), encoding="utf-8")
    print(f"Audited {len(files)} imported files")
    print(f"Wrote {manifest_path} and {report_path}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
