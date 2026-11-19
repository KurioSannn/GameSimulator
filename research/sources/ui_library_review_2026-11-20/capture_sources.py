"""Run from repository root. Cache creator metadata/previews; never execute downloaded code."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re
import urllib.error
import urllib.request

directory = Path(__file__).resolve().parent
raw = directory / "raw"
raw.mkdir(parents=True, exist_ok=True)
events = []


def capture(url, filename):
    path = raw / filename
    try:
        if path.exists():
            payload = path.read_bytes()
            status = "cached"
        else:
            request = urllib.request.Request(url, headers={"User-Agent": "Nusantara-UI-Source-Review/1.0"})
            with urllib.request.urlopen(request, timeout=20) as response:
                payload = response.read()
            path.write_bytes(payload)
            status = "downloaded"
        events.append({"url": url, "file": filename, "status": status,
                       "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest(),
                       "retrieved_at": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat()})
        return payload
    except (urllib.error.URLError, TimeoutError) as error:
        events.append({"url": url, "status": "failed", "reason": str(error)})
        return None


for owner, repository, branch, prefix in [("wadlo", "Themey", "master", "themey"),
                                          ("Maaack", "Godot-Game-Template", "main", "maaack")]:
    metadata = capture(f"https://api.github.com/repos/{owner}/{repository}/commits/{branch}", f"{prefix}-commit.json")
    if not metadata:
        continue
    commit = json.loads(metadata)["sha"]
    files = [("README.md", f"{prefix}-README.md")]
    if prefix == "themey":
        files += [("LICENSE", "themey-LICENSE.txt"), ("IMAGES_LICENSE", "themey-IMAGES_LICENSE.txt"),
                  ("themey-screenshot.png", "themey-screenshot.png")]
    else:
        files += [("LICENSE.txt", "maaack-LICENSE.txt")]
    for remote, local in files:
        capture(f"https://raw.githubusercontent.com/{owner}/{repository}/{commit}/{remote}", local)

capture("https://github.com/wadlo/Themey/assets/86272030/fdf924c1-af79-4920-aa98-994d76f18a1e", "themey-clashy-preview.png")
for slug in ["ui-pack-adventure", "fantasy-ui-borders"]:
    html = capture(f"https://kenney.nl/assets/{slug}", slug + ".html")
    if html:
        match = re.search(r'<meta[^>]+property=[\'"]og:image[\'"][^>]+content=[\'"]([^\'"]+)', html.decode())
        if match:
            url = match.group(1)
            capture(url, slug + "-preview" + Path(url.split("?")[0]).suffix)

(directory / "capture.json").write_text(json.dumps({"events": events}, indent=2) + "\n", encoding="utf-8", newline="\n")
for event in events:
    print(event["status"], event.get("file", event["url"]), event.get("bytes", ""), event.get("reason", ""))
