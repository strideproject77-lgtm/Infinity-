#!/usr/bin/env bash
# Publish a verified, sanitized snapshot of the latest Codemagic logs.
set -euo pipefail
BUILD_LOG="${INFINITY_CODEMAGIC_BUILD_LOG:-/tmp/infinity-codemagic-logs/build.log}"
ARCHIVE_LOG="${INFINITY_CODEMAGIC_ARCHIVE_LOG:-/tmp/infinity-codemagic-logs/xcodebuild-archive.log}"
SUBMODULE_LOG="${INFINITY_CODEMAGIC_SUBMODULE_LOG:-/tmp/infinity-codemagic-logs/submodules.log}"
python3 - "$BUILD_LOG" "$ARCHIVE_LOG" "$SUBMODULE_LOG" <<'PY'
import base64
import datetime
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

repo = "strideproject77-lgtm/Infinity-"
branch = "codemagic-logs"
token = os.environ["INFINITY_LOGS_GITHUB_TOKEN"]
api = "https://api.github.com"
headers = {
    "Accept": "application/vnd.github+json",
    "Authorization": "Bearer " + token,
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "INFINITY-Codemagic-Log-Publisher",
}

def redact(data: bytes) -> bytes:
    text = data.decode("utf-8", errors="replace")
    text = re.sub(r"(?i)(authorization\s*[:=]\s*bearer\s+)[^\s]+", r"\1[REDACTED]", text)
    text = re.sub(r"(?i)\b(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b", "[REDACTED_GITHUB_TOKEN]", text)
    text = re.sub(r"(?i)(\b(?:token|password|passwd|client_secret|api[_-]?key)\b\s*[:=]\s*)[^\s,;]+", r"\1[REDACTED]", text)
    text = re.sub(r"\bAKIA[0-9A-Z]{16}\b", "[REDACTED_AWS_KEY]", text)
    text = re.sub(r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----", "[REDACTED_PRIVATE_KEY]", text, flags=re.S)
    return text.encode("utf-8")

def api_request(method, path, payload):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{api}/repos/{repo}/{path}",
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub API {method} {path} returned {exc.code}: {detail[:1200]}") from exc

def create_blob(data: bytes) -> str:
    result = api_request("POST", "git/blobs", {
        "content": base64.b64encode(data).decode("ascii"),
        "encoding": "base64",
    })
    return result["sha"]

build_path, archive_path, submodule_path = sys.argv[1:4]
if not os.path.isfile(build_path) or os.path.getsize(build_path) == 0:
    raise RuntimeError(f"Refusing to publish an empty or missing build log: {build_path}")
if not os.path.isfile(archive_path):
    raise RuntimeError(f"Required archive log is missing: {archive_path}")
if not os.path.isfile(submodule_path):
    raise RuntimeError(f"Required submodule log is missing: {submodule_path}")

status = int(os.environ.get("INFINITY_CODEMAGIC_BUILD_EXIT_CODE", "1"))
log_sources = {
    "build.log": build_path,
    "xcodebuild-archive.log": archive_path,
    "submodules.log": submodule_path,
}
log_data = {}
log_stats = {}
for name, path in log_sources.items():
    with open(path, "rb") as handle:
        raw = handle.read()
    clean = redact(raw)
    log_data[name] = clean
    log_stats[name] = {
        "bytes": len(clean),
        "lines": clean.count(b"\n"),
        "sha256": hashlib.sha256(clean).hexdigest(),
    }

now = datetime.datetime.now(datetime.timezone.utc).isoformat()
metadata = {
    "provider": "Codemagic",
    "repository": repo,
    "source_branch": os.environ.get("CM_BRANCH", "unknown"),
    "commit": os.environ.get("CM_COMMIT", "unknown"),
    "build_id": os.environ.get("CM_BUILD_ID", "unknown"),
    "build_number": os.environ.get("CM_BUILD_NUMBER", "unknown"),
    "workflow": os.environ.get("CM_WORKFLOW_NAME", "INFINITY IPA (Codemagic backup)"),
    "xcode": os.environ.get("INFINITY_XCODE_VERSION", "unknown"),
    "exit_code": status,
    "result": "success" if status == 0 else "failed",
    "uploaded_at_utc": now,
    "logs": log_stats,
    "redaction": "Common credential/token patterns and PEM private-key blocks are redacted before publication.",
}
files = [
    ("latest/build.log", log_data["build.log"]),
    ("latest/xcodebuild-archive.log", log_data["xcodebuild-archive.log"]),
    ("latest/submodules.log", log_data["submodules.log"]),
    ("latest/metadata.json", (json.dumps(metadata, indent=2) + "\n").encode("utf-8")),
]
tree_entries = []
for path, content in files:
    tree_entries.append({
        "path": path,
        "mode": "100644",
        "type": "blob",
        "sha": create_blob(content),
    })
    print(f"Prepared {path}: {len(content)} bytes, {content.count(b'\n')} lines")

tree = api_request("POST", "git/trees", {"tree": tree_entries})
commit = api_request("POST", "git/commits", {
    "message": f"Replace latest Codemagic logs (build {metadata['build_number']})",
    "tree": tree["sha"],
    "parents": [],
})
ref = urllib.parse.quote("heads/" + branch, safe="/")
api_request("PATCH", "git/refs/" + ref, {
    "sha": commit["sha"],
    "force": True,
})
print(f"Published latest logs to {repo}/tree/{branch}/latest")
print("Verified non-empty build log; snapshot contains build, archive, submodule logs and metadata.")
PY
