"""Cross-process WKWebView -> explicit local transfer -> Dart file store proof.

Synthetic fixture only. Does not discover or open installed app containers.
macOS 14+, swiftc, Dart from the current Flutter toolchain are required.
"""
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import hashlib
import json
import subprocess
import threading
import uuid

root = Path(__file__).resolve().parent.parent
run = root / "build" / "migration-fixture" / str(uuid.uuid4())
run.mkdir(parents=True)
fixture_id = str(uuid.uuid4())
scope = "synthetic named WKWebsiteDataStore only; no installed app storage"
handler = partial(SimpleHTTPRequestHandler, directory=str(root / "tool" / "fixtures"))
server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
origin = f"http://127.0.0.1:{server.server_port}"
manifest = {"fixtureId": fixture_id, "origin": origin, "scope": scope}
(run / "fixture-run.json").write_text(json.dumps(manifest, indent=2))

try:
    binary = run / "webkit_fixture"
    subprocess.run(["swiftc", str(root / "tool" / "webkit_fixture.swift"),
                    "-framework", "AppKit", "-framework", "WebKit", "-o", str(binary)],
                   check=True, timeout=60)
    for mode in ("write", "read"):
        subprocess.run([str(binary), mode, fixture_id, origin + "/fixture.html",
                        str(run / (mode + ".json"))], check=True, timeout=32)
    written = json.loads((run / "write.json").read_text())
    read = json.loads((run / "read.json").read_text())
    assert written == read and len(read) == 21, "WebKit persistence differs"
    subprocess.run(["dart", "run", "tool/import_fixture.dart", str(run)],
                   cwd=root, check=True, timeout=60)
    report = json.loads((run / "report.json").read_text())
    report.update({"webkitCrossProcessPersistence": "PASS", "macOS": subprocess.check_output(
        ["sw_vers", "-productVersion"], text=True).strip(),
        "fixtureScriptSha256": hashlib.sha256((root / "tool/webkit_fixture.swift").read_bytes()).hexdigest(),
        "scopeLimits": "Actual WKWebView + Dart candidate persistence; not a Tauri installed-app update, iOS or Android proof"})
    output = root / "docs" / "webkit-fixture-proof-20261025.json"
    output.write_text(json.dumps(report, indent=2) + "\n")
    print("PASS:", output)
finally:
    server.shutdown()
