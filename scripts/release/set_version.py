"""Stamp a version into project.godot and the export presets (Android versionCode = MAJOR*10000+MINOR*100+PATCH)."""
import re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
v = sys.argv[1]
a, b, c = (list(map(int, v.split("."))) + [0, 0])[:3]
proj = ROOT / "game/project.godot"
s = proj.read_text(encoding="utf-8")
s = re.sub(r'config/version="[^"]*"', 'config/version="%s"' % v, s)
proj.write_text(s, encoding="utf-8")
pre = ROOT / "game/export_presets.cfg"
s = pre.read_text(encoding="utf-8")
s = re.sub(r'application/(file|product)_version="[^"]*"', lambda m: 'application/%s_version="%s.0"' % (m.group(1), v), s)
s = re.sub(r'application/(short_version|version)="[^"]*"', lambda m: 'application/%s="%s"' % (m.group(1), v), s)
s = re.sub(r'version/name="[^"]*"', 'version/name="%s"' % v, s)
s = re.sub(r'version/code=\d+', 'version/code=%d' % (a * 10000 + b * 100 + c), s)
pre.write_text(s, encoding="utf-8")
print("version", v)
