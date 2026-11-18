#!/usr/bin/env bash
# Replace the dedicated log branch with one fresh snapshot containing only the latest Codemagic logs.
set -euo pipefail
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

build_path, archive_path = sys.argv[1:3]
status = int(os.environ.get("INFINITY_CODEMAGIC_BUILD_EXIT_CODE", "1"))
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
metadata = {
    "provider": "Codemagic",
    "repository": repo,
    "source_branch": os.environ.get("CM_BRANCH", "unknown"),
    "commit": os.environ.get("CM_COMMIT", "unknown"),
    "build_id": os.environ.get("CM_BUILD_ID", "unknown"),
    "build_number": os.environ.get("CM_BUILD_NUMBER", "unknown"),
    "workflow": os.environ.get("CM_WORKFLOW_NAME", "INFINITY IPA (Codemagic backup)"),
    "xcode": os.environ.get("INFINITY_XCODE_VERSION", "26.2 (configured)"),
    "exit_code": status,
    "result": "success" if status == 0 else "failed",
    "uploaded_at_utc": now,
    "redaction": "Common credential/token patterns and PEM private-key blocks are redacted before publication.",
}
files = [
    ("latest/xcodebuild-archive.log", archive_path),
    ("latest/build.log", build_path),
    ("latest/metadata.json", None),
]
tree_entries = []
for path, local in files:
    if local:
        if not os.path.isfile(local):
            raise RuntimeError(f"Required log file is missing: {local}")
        content = redact(open(local, "rb").read())
    else:
        content = (json.dumps(metadata, indent=2) + "\n").encode("utf-8")
    tree_entries.append({
        "path": path,
        "mode": "100644",
        "type": "blob",
        "sha": create_blob(content),
    })
    print(f"Prepared {path}: {len(content)} bytes")

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
print("The log branch now contains only this build's three latest files.")
PY
