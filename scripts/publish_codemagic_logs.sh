#!/usr/bin/env bash
# Publish the latest Codemagic logs to a fixed path on the dedicated codemagic-logs branch.
# Credentials are supplied only through Codemagic's secure environment variables.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_LOG="${INFINITY_CODEMAGIC_BUILD_LOG:-/tmp/infinity-codemagic-logs/build.log}"
ARCHIVE_LOG="${INFINITY_CODEMAGIC_ARCHIVE_LOG:-/tmp/infinity-codemagic-logs/xcodebuild-archive.log}"

python3 - "$BUILD_LOG" "$ARCHIVE_LOG" <<'PY'
import base64
import datetime
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
    # Keep compiler diagnostics intact while removing common credential formats.
    text = re.sub(r"(?i)(authorization\s*[:=]\s*bearer\s+)[^\s]+", r"\1[REDACTED]", text)
    text = re.sub(r"(?i)\b(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b", "[REDACTED_GITHUB_TOKEN]", text)
    text = re.sub(r"(?i)(\b(?:token|password|passwd|client_secret|api[_-]?key)\b\s*[:=]\s*)[^\s,;]+", r"\1[REDACTED]", text)
    text = re.sub(r"\bAKIA[0-9A-Z]{16}\b", "[REDACTED_AWS_KEY]", text)
    text = re.sub(r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----", "[REDACTED_PRIVATE_KEY]", text, flags=re.S)
    return text.encode("utf-8")

def request(method, url, payload=None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            raw = response.read()
            return json.loads(raw.decode("utf-8")) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub API {method} {url} returned {exc.code}: {detail[:1200]}") from exc

def put_file(path, content, message):
    encoded_path = urllib.parse.quote(path, safe="/")
    url = f"{api}/repos/{repo}/contents/{encoded_path}"
    sha = None
    try:
        existing = request("GET", url + "?ref=" + urllib.parse.quote(branch, safe=""))
        sha = existing.get("sha")
    except RuntimeError as exc:
        if "returned 404" not in str(exc):
            raise
    payload = {
        "message": message,
        "content": base64.b64encode(content).decode("ascii"),
        "branch": branch,
    }
    if sha:
        payload["sha"] = sha
    result = request("PUT", url, payload)
    print(f"Published {path} ({len(content)} bytes), commit {result.get('commit', {}).get('sha', 'unknown')}")

build_path, archive_path = sys.argv[1:3]
status = int(os.environ.get("INFINITY_CODEMAGIC_BUILD_EXIT_CODE", "1"))
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
metadata = {
    "provider": "Codemagic",
    "repository": repo,
    "branch": os.environ.get("CM_BRANCH", "unknown"),
    "commit": os.environ.get("CM_COMMIT", "unknown"),
    "build_id": os.environ.get("CM_BUILD_ID", "unknown"),
    "build_number": os.environ.get("CM_BUILD_NUMBER", "unknown"),
    "workflow": os.environ.get("CM_WORKFLOW_NAME", "INFINITY IPA (Codemagic backup)"),
    "xcode": os.environ.get("XCODE_VERSION", "26.2 (configured)"),
    "exit_code": status,
    "result": "success" if status == 0 else "failed",
    "uploaded_at_utc": now,
    "redaction": "Common credential/token patterns and PEM private-key blocks are redacted before publication.",
}
files = [
    ("latest/xcodebuild-archive.log", archive_path, "Update latest Codemagic Xcode archive log"),
    ("latest/build.log", build_path, "Update latest Codemagic full build log"),
    ("latest/metadata.json", None, "Update latest Codemagic build metadata"),
]
for path, local, message in files:
    if local:
        if not os.path.isfile(local):
            print(f"Skipping missing log: {local}")
            continue
        content = redact(open(local, "rb").read())
    else:
        content = (json.dumps(metadata, indent=2) + "\n").encode("utf-8")
    put_file(path, content, message)
PY
