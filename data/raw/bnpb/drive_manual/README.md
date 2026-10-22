# Manual BNPB downloads (G-15)

Google Drive's robots.txt disallows automated downloads, so these files must be fetched by a person.

1. Open `research/sources/bnpb_yearly_index.md`. Each year 2002–2023 lists its official BNPB Drive folder.
2. Open the folder in a browser and use **Download** (Drive zips the folder).
3. Unzip into `data/raw/bnpb/drive_manual/<year>/` (one folder per year; keep the original file names, e.g. `stat_by_wil_32_2019.xlsx`).
4. Do not edit, rename or convert the files. Raw captures are immutable.
5. Run `.venv/bin/python scripts/pipelines/hazard/index_bnpb_years.py`. It records checksums and marks the year `MANUAL_FILES_PRESENT`.

The parser for these files is written only after their real structure has been inspected.
