# Case registry

Competition target (D-019): 12–20 deeply researched, playable cases. The long-term corpus goal stays at 100+ (candidates below).

## Implemented
| ID | Title | Year | Domain | Island group / provinces | Research status | Follow-ups | Golden master |
|---|---|---|---|---|---|---|---|
| CASE-0001 | Banjir dan longsor Jabodetabek–Banten | 2020 | disaster (flood) | Jawa: DKI, Jawa Barat (Kab. Bogor), Banten (Kab. Lebak) | researched | A, B, C, R (recurring) | case0001.json |
| CASE-0002 | Gempa, tsunami, likuefaksi Palu–Sigi–Donggala | 2018 | disaster (earthquake / reconstruction) | Sulawesi: Sulawesi Tengah | researched | B, C | case0002.json |
| CASE-0003 | Krisis minyak goreng & larangan ekspor CPO | 2022 | food / industry / economy (non-disaster) | National + Sumatera: Riau, Jambi, Sumatera Selatan | researched | A, B, C | case0003.json |
| CASE-0004 | Kebakaran hutan dan lahan gambut & tata kelola gambut | 2015 | environment / land use / livelihoods / **local wisdom** | Kalimantan: Kalimantan Tengah (+ peat provinces Riau, Jambi, Sumsel, Kalbar, Kalsel) | researched | A, C, R (recurring fire season) | case0004.json |
| CASE-0005 | Hilirisasi nikel: larangan ekspor bijih, kawasan Morowali & Weda Bay | 2020–2024 | **natural resources / industrial policy / trade / environment / occupational safety** | Sulawesi + **Maluku**: Kab. Morowali (72.06), Kab. Halmahera Tengah (82.02) | researched | A (environment-conditioned), C (after moratorium) | case0005.json |
| CASE-0006 | Kekeringan 2023 NTT: ketahanan air dan penghidupan | 2023 | **climate / water / livelihood** | **Bali–Nusa Tenggara**: Kab. Sabu Raijua (53.20), Kab. Kupang (53.01) | researched | R (next dry season, scaled by water infrastructure) | case0006.json |
| CASE-0007 | Akses layanan kesehatan primer di Papua Pegunungan dan Papua Tengah | 2022–2024 | **health services / social policy** | **Papua**: Papua Pegunungan (95), Papua Tengah (94) — province-level evidence | researched | A (services still < 45), B (end of central deployment) | case0007.json |
| CASE-0008 | Pengalihan subsidi BBM 2022: harga Pertalite/Solar, BLT BBM, BSU, 2% DTU | 2022 | **fiscal / energy / social protection** (national) | National — all 514 kab/kota (no regional distribution data) | researched | A (fiscal drain after holding prices), B (BLT about to end, prices > 101) | case0008.json |

Coverage so far: all seven island groups (Bali–Nusa Tenggara via CASE-0006, Papua via CASE-0007). Energy/fiscal covered by CASE-0008. First local-wisdom mechanic: CULT-0001 via POL-KEBENCANAAN-API-ADAT (CASE-0004).

## Candidate corpus (to research; not yet validated; no facts claimed here)
| Candidate | Region | Domain | Why |
|---|---|---|---|
| Kelangkaan/kenaikan harga beras 2023 | national | food | food chain at national scale |
| Pelestarian bahasa daerah / warisan budaya | to choose by evidence | cultural governance | requires culture research first (no checklist culture) |

## CASE-0004 selection (evaluation against the 10 criteria)
| Candidate | Geography | New domain | New causal links | New policy type | Education | Regional asymmetry | Cascades | Source quality | Local wisdom | Feasibility | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Kalimantan peat fires 2015 | **new (Kalimantan)** | environment / land use | governance → prevention → fire season → damage/welfare | enforcement vs restoration vs community governance | high | high (6 peat provinces vs rest) | yes | KLHK, Setkab, IPB journal, Pergub | **direct, documented** (Dayak Ngaju handel/jipen; tabat) | high (reuses scale_by, policies) | **selected** |
| Fuel price 2022 | national | energy / fiscal | subsidy ↔ fiscal ↔ inflation | subsidy reform | high | weak evidence | yes | good | none | high | strong, but no local wisdom and no new geography |
| NTT drought | new (Nusa Tenggara) | food / climate | rainfall → harvest → food | food relief | high | medium | medium | not yet researched | unknown | medium | later |
| Nickel downstreaming | new (Maluku) | extraction / industry | extraction → revenue vs environment | industrial policy | high | high | yes | mixed, contested | weak link | medium (needs new variables) | later |
| Rice price 2023 | national | food (already covered by CASE-0003) | — | — | medium | low | medium | good | indirect (subak is irrigation, not price) | high | lower novelty |
| Papua health services | new (Papua) | social / health | services → welfare | service delivery | high | high | low | needs careful sourcing | sensitive | low before deadline | later, with care |
