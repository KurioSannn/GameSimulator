"""Write build/releases/<v>/update.json for the in-game Updater (game/src/app/updater.gd)."""
import hashlib, json, sys
from pathlib import Path
v, out, base_url, patch_from = sys.argv[1], Path(sys.argv[2]), sys.argv[3].rstrip("/"), (sys.argv[4] if len(sys.argv) > 4 else "")
line = ".".join(v.split(".")[:2])
def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()
url = lambda name: "%s/v%s/%s" % (base_url, v, name)
prev = {}
m = {"schema": "nusantara.update/1", "latest": v, "notes": ""}
if patch_from:
    files = {}
    for k in ["windows", "macos", "android"]:
        p = out / ("patch-%s-%s.pck" % (v, k))
        files[k] = {"url": url(p.name), "sha256": sha(p), "size": p.stat().st_size}
    m["patch"] = {"version": v, "binary_line": line, "files": files}
    # the full installers of the binary line stay those of the base release
    base_v = patch_from
else:
    base_v = v
ext = {"windows": "exe", "macos": "zip", "android": "apk"}
m["full"] = {"version": base_v, "binary_line": ".".join(base_v.split(".")[:2])}
for k, e in ext.items():
    m["full"][k] = "%s/v%s/NUSANTARA-%s-%s.%s" % (base_url, base_v, base_v, k, e)
(out / "update.json").write_text(json.dumps(m, indent=1) + "\n", encoding="utf-8")
print(json.dumps(m, indent=1))
