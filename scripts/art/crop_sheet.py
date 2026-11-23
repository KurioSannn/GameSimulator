"""Split a generated 2x2 portrait sheet (white gutters) into four square portraits.

Usage: python scripts/art/crop_sheet.py SHEET.png OUT_TL OUT_TR OUT_BL OUT_BR [--size 512]
Gutters are found as the whitest row/column band near the middle; outer white margins are trimmed.
"""
import sys
import numpy as np
from PIL import Image


def _band(profile, lo, hi):
    seg = profile[lo:hi]
    idx = np.where(seg >= seg.max() - 0.02)[0]
    return lo + int(idx.min()), lo + int(idx.max())


def _trim(a):
    white = (a.min(axis=2) > 235)
    rows = np.where(white.mean(axis=1) < 0.9)[0]
    cols = np.where(white.mean(axis=0) < 0.9)[0]
    return a[rows.min():rows.max() + 1, cols.min():cols.max() + 1]


def main():
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    size = 512
    if "--size" in sys.argv:
        size = int(sys.argv[sys.argv.index("--size") + 1])
        args.remove(str(size))
    a = np.asarray(Image.open(args[0]).convert("RGB"))
    h, w, _ = a.shape
    white = (a.min(axis=2) > 235).astype(float)
    c0, c1 = _band(white.mean(axis=0), int(w * 0.4), int(w * 0.6))
    r0, r1 = _band(white.mean(axis=1), int(h * 0.4), int(h * 0.6))
    quads = [a[:r0, :c0], a[:r0, c1 + 1:], a[r1 + 1:, :c0], a[r1 + 1:, c1 + 1:]]
    for q, out in zip(quads, args[1:5]):
        q = _trim(q)
        s = min(q.shape[0], q.shape[1])
        y = (q.shape[0] - s) // 2
        x = (q.shape[1] - s) // 2
        img = Image.fromarray(q[y:y + s, x:x + s]).resize((size, size), Image.LANCZOS)
        img.save(out, quality=90)
        print("wrote", out)


if __name__ == "__main__":
    main()
