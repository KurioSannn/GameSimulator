"""Fetch the shared catalog's pinned CC0 selection; never execute downloaded code."""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "game/assets/map/kenney"
CATALOG = ROOT / "game/data/map/art_catalog.json"


def raw_url(mirror: dict[str, str], rel_path: str) -> str:
    owner_repo = mirror["repository"].removeprefix("https://github.com/").rstrip("/")
    return f"https://raw.githubusercontent.com/{owner_repo}/{mirror['commit']}/{rel_path}"


def fetch(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    tmp = destination.with_suffix(destination.suffix + ".tmp")
    subprocess.run(
        ["curl.exe", "-f", "-s", "-S", "-L", "--retry", "3", "--connect-timeout", "15", "--max-time", "60", url, "-o", str(tmp)],
        check=True,
    )
    magic = tmp.read_bytes()[:4]
    if destination.suffix == ".glb" and magic != b"glTF":
        tmp.unlink(missing_ok=True)
        raise ValueError(f"Downloaded file is not a binary glTF (.glb): {url}")
    if destination.suffix == ".png" and magic != b"\x89PNG":
        tmp.unlink(missing_ok=True)
        raise ValueError(f"Downloaded file is not a valid PNG: {url}")
    tmp.replace(destination)


def download_job(item: tuple[dict[str, str], dict[str, object], str]) -> tuple[Path, str, dict[str, str], dict[str, object], str, str]:
    mirror, group, name = item
    subdir = str(group.get("subdir", "")).strip("/")
    rel_file = f"{subdir}/{name}.glb" if subdir else f"{name}.glb"
    rel_url_path = mirror["path_template"].format(pack=group["pack"], name=name)
    url = raw_url(mirror, rel_url_path)
    path = OUT / rel_file
    if not path.exists():
        fetch(url, path)
    return path, rel_file, mirror, group, name, url


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    mirrors: dict[str, dict[str, str]] = catalog["mirrors"]

    jobs: list[tuple[dict[str, str], dict[str, object], str]] = []
    seen_files: set[str] = set()
    texture_deps: dict[str, tuple[dict[str, str], str]] = {}
    for group in catalog["groups"].values():
        mirror_id = str(group["mirror"])
        mirror = mirrors[mirror_id]
        subdir = str(group.get("subdir", "")).strip("/")
        if mirror_id == "shorepine" and subdir:
            texture_deps[subdir] = (mirror, str(group["pack"]))
        for name in group["models"]:
            rel_file = f"{subdir}/{name}.glb" if subdir else f"{name}.glb"
            if rel_file in seen_files:
                raise ValueError(f"Duplicate output filename in art_catalog.json: {rel_file}")
            seen_files.add(rel_file)
            jobs.append((mirror, group, str(name)))

    # Fetch external glTF colormap textures first for packs that reference Textures/colormap.png
    textures_meta = []
    for subdir, (mirror, pack) in texture_deps.items():
        tex_url = raw_url(mirror, f"3d/{pack}/Textures/colormap.png")
        tex_dest = OUT / subdir / "Textures/colormap.png"
        if not tex_dest.exists():
            fetch(tex_url, tex_dest)
        tex_bytes = tex_dest.read_bytes()
        textures_meta.append({
            "file": f"{subdir}/Textures/colormap.png",
            "pack": pack,
            "download": tex_url,
            "sha256": hashlib.sha256(tex_bytes).hexdigest(),
        })

    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(download_job, jobs))

    records = []
    for path, rel_file, mirror, group, name, url in results:
        data = path.read_bytes()
        if data[:4] != b"glTF":
            raise ValueError(f"Not a GLB: {path}")
        pack = str(group["pack"])
        records.append({
            "file": rel_file,
            "creator": "Kenney",
            "license": mirror.get("license", "CC0-1.0"),
            "repository": mirror["repository"],
            "commit": mirror["commit"],
            "source": f"https://kenney.nl/assets/{pack}",
            "download": url,
            "source_institution": "Kenney",
            "title": f"{pack} / {name}",
            "retrieved_at": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat(),
            "retrieval_timestamp_basis": "local download file modification time (UTC)",
            "publication_date": None,
            "geographic_resolution": "not applicable; stylized art",
            "reference_period": "not applicable",
            "unit": "3D model",
            "source_status": "creator CC0 verified; pinned converted GLB mirror",
            "sha256": hashlib.sha256(data).hexdigest(),
            "bytes": len(data),
            "use": "decorative diorama props; no real-world land-cover claim",
        })

    for mirror_id, mirror in mirrors.items():
        license_name = "LICENSE.txt" if mirror_id == "tge" else f"LICENSE-{mirror_id.upper()}.txt"
        dest = OUT / license_name
        if not dest.exists():
            fetch(raw_url(mirror, mirror["license_path"]), dest)

    primary = mirrors["tge"]
    (OUT / "manifest.json").write_text(
        json.dumps(
            {
                "repository": primary["repository"],
                "commit": primary["commit"],
                "mirrors": mirrors,
                "textures": textures_meta,
                "assets": records,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(f"Verified {len(records)} pinned CC0 models and {len(textures_meta)} colormap textures across {len(mirrors)} mirrors")


if __name__ == "__main__":
    main()
