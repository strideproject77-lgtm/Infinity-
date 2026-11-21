#!/usr/bin/env python3
"""Read-only upstream update checker for INFINITY.

This tool reports upstream commits newer than the revisions recorded in
upstream/manifest.json. It never edits source files, pins, or branches.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "upstream" / "manifest.json"
REPORT_DIR = ROOT / "upstream" / "reports"


def github_json(url: str) -> dict:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "INFINITY-Upstream-Update-Bridge",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def inspect_component(component: dict) -> dict:
    repo = component["repository"]
    pinned = component["pinned_revision"]
    compare_url = f"https://api.github.com/repos/{repo}/compare/{pinned}...HEAD"
    try:
        comparison = github_json(compare_url)
        commits = comparison.get("commits", [])
        latest = commits[-1] if commits else None
        return {
            "id": component["id"],
            "name": component["name"],
            "repository": repo,
            "pinned_revision": pinned,
            "latest_revision": (comparison.get("commits") or [{}])[-1].get("sha", pinned),
            "ahead_by": comparison.get("ahead_by", 0),
            "behind_by": comparison.get("behind_by", 0),
            "status": comparison.get("status", "unknown"),
            "latest_message": ((latest or {}).get("commit", {}).get("message", "").splitlines() or [""])[0],
            "latest_date": (latest or {}).get("commit", {}).get("committer", {}).get("date", ""),
            "result": "UPDATE_AVAILABLE" if comparison.get("ahead_by", 0) > 0 else "UP_TO_DATE",
            "error": None,
        }
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, ValueError, KeyError) as exc:
        return {
            "id": component.get("id", "unknown"),
            "name": component.get("name", "Unknown"),
            "repository": repo,
            "pinned_revision": pinned,
            "result": "CHECK_FAILED",
            "error": str(exc),
        }


def render_markdown(results: list[dict], local_components: list[dict], generated: str) -> str:
    lines = [
        "# INFINITY upstream update report",
        "",
        f"Generated: {generated}",
        "",
        "> Read-only report. No source, branch, pin, or app bundle is modified.",
        "> Updates require review, selective integration, tests, and macOS validation.",
        "",
        "| Component | State | Commits ahead | Current pin | Upstream head |",
        "|---|---:|---:|---|---|",
    ]
    for item in results:
        ahead = item.get("ahead_by", "—")
        lines.append(
            f"| {item['name']} | {item['result']} | {ahead} | "
            f"`{item['pinned_revision'][:12]}` | "
            f"`{item.get('latest_revision', '—')[:12]}` |"
        )
    lines += ["", "## Review notes", ""]
    for item in results:
        if item["result"] == "UPDATE_AVAILABLE":
            lines.append(f"- **{item['name']}**: {item['ahead_by']} upstream commit(s) ahead. Latest: {item.get('latest_message') or 'No commit message'}")
        elif item["result"] == "CHECK_FAILED":
            lines.append(f"- **{item['name']}**: check failed: {item.get('error')}")
        else:
            lines.append(f"- **{item['name']}**: pinned revision matches upstream HEAD.")
    lines += ["", "## Protected local components", ""]
    for item in local_components:
        lines.append(f"- **{item['name']}**: {item['policy']}")
    lines += [
        "",
        "## Adoption gate",
        "",
        "1. Review upstream release notes and commit diffs.",
        "2. Port only relevant changes; preserve local INFINITY/STRATA patches.",
        "3. Update the manifest pin only after the port is reviewed.",
        "4. Run source tests and macOS iOS-device compile validation.",
        "5. Perform real-device SideStore/LiveContainer regression tests before release.",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    results = [inspect_component(item) for item in manifest["components"]]
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    (REPORT_DIR / "latest.json").write_text(
        json.dumps({"generated_at": generated, "components": results}, indent=2) + "\n",
        encoding="utf-8",
    )
    (REPORT_DIR / "latest.md").write_text(
        render_markdown(results, manifest.get("local_components", []), generated),
        encoding="utf-8",
    )
    print((REPORT_DIR / "latest.md").read_text(encoding="utf-8"))
    return 1 if any(item["result"] == "CHECK_FAILED" for item in results) else 0


if __name__ == "__main__":
    sys.exit(main())
