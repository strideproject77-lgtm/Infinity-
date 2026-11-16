#!/usr/bin/env python3
"""Create a deterministic inventory of vendored Husk translation-layer sources.

This is a source/dependency audit, not a compiler and not a compatibility claim.
"""
from __future__ import annotations

import argparse
import collections
import json
import pathlib
import re
import sys

SOURCE_SUFFIXES = {".c", ".m", ".mm", ".cc", ".cpp", ".cxx", ".S", ".s"}
HEADER_SUFFIXES = {".h", ".hh", ".hpp", ".hxx", ".inc", ".def"}
INCLUDE_RE = re.compile(r'^\s*#\s*include\s*"([^"]+)"', re.MULTILINE)
SPDX_RE = re.compile(r"SPDX-License-Identifier:\s*([^\s*]+)")

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--vendor-root", default="Vendor/Husk")
    parser.add_argument("--output-dir", default="docs/generated")
    args = parser.parse_args()

    root = pathlib.Path(args.vendor_root).resolve()
    source_root = root / "translation-layer-next"
    if not source_root.is_dir():
        print(f"Missing imported source tree: {source_root}", file=sys.stderr)
        return 2

    files = sorted(p for p in source_root.rglob("*") if p.is_file())
    by_suffix = collections.Counter(p.suffix or "[no extension]" for p in files)
    basename_index: dict[str, list[pathlib.Path]] = collections.defaultdict(list)
    for path in files:
        basename_index[path.name].append(path)

    entries = []
    missing_headers = []
    no_spdx = []
    for path in files:
        rel = path.relative_to(root.parent).as_posix()
        try:
            content = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            content = ""
        match = SPDX_RE.search(content[:4096])
        includes = INCLUDE_RE.findall(content)
        unresolved = []
        for include in includes:
            candidate = (path.parent / include).resolve()
            if candidate.is_file():
                continue
            matches = basename_index.get(pathlib.PurePosixPath(include).name, [])
            if not matches:
                unresolved.append(include)
                missing_headers.append((rel, include))
        if not match:
            no_spdx.append(rel)
        entries.append({
            "path": rel,
            "suffix": path.suffix,
            "kind": "source" if path.suffix in SOURCE_SUFFIXES else
                    "header" if path.suffix in HEADER_SUFFIXES else "other",
            "spdx": match.group(1) if match else None,
            "quoted_includes": includes,
            "unresolved_quoted_includes": unresolved,
        })

    output = pathlib.Path(args.output_dir)
    output.mkdir(parents=True, exist_ok=True)
    manifest_path = output / "HUSK_SOURCE_MANIFEST.json"
    report_path = output / "HUSK_SOURCE_AUDIT.md"
    manifest_path.write_text(json.dumps({
        "upstream": "https://github.com/Leviidev/Husk",
        "revision_file": (root / "UPSTREAM_REVISION.txt").read_text(encoding="utf-8").strip()
                         if (root / "UPSTREAM_REVISION.txt").exists() else None,
        "source_root": str(source_root),
        "file_count": len(files),
        "counts_by_suffix": dict(sorted(by_suffix.items())),
        "files": entries,
    }, indent=2) + "\n", encoding="utf-8")

    source_count = sum(1 for e in entries if e["kind"] == "source")
    header_count = sum(1 for e in entries if e["kind"] == "header")
    report = [
        "# Husk source import audit",
        "",
        "> Inventory only. This report does not prove that files compile, link, or run on iOS.",
        "",
        f"- Total files: **{len(files)}**",
        f"- C/Objective-C/C++/assembly source files: **{source_count}**",
        f"- Header/include files: **{header_count}**",
        f"- Files without an SPDX identifier in the first 4 KiB: **{len(no_spdx)}**",
        f"- Quoted includes with no matching header basename in the imported tree: **{len(missing_headers)}**",
        "",
        "## File types",
        "",
        "| Extension | Count |",
        "|---|---:|",
    ]
    report += [f"| `{suffix}` | {count} |" for suffix, count in sorted(by_suffix.items())]
    report += ["", "## Missing quoted includes", ""]
    if missing_headers:
        report += [f"- `{path}`: `{include}`" for path, include in missing_headers]
    else:
        report.append("None detected by this simple quoted-include scan.")
    report += ["", "## Files without SPDX marker", ""]
    if no_spdx:
        report += [f"- `{path}`" for path in no_spdx]
    else:
        report.append("None detected in the first 4 KiB of each file.")
    report += [
        "",
        "## Integration rule",
        "",
        "Use the JSON manifest to select coherent, dependency-complete source groups. "
        "Quoted-include scanning is only a first pass: generated headers, conditional "
        "includes, framework/module maps, compiler flags, linker symbols, assembly, "
        "runtime resources, and transitive third-party licenses still require manual review. "
        "Do not add the entire tree to an Xcode target automatically.",
        "",
    ]
    report_path.write_text("\n".join(report), encoding="utf-8")
    print(f"Audited {len(files)} files ({source_count} source, {header_count} headers)")
    print(f"Wrote {manifest_path} and {report_path}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
