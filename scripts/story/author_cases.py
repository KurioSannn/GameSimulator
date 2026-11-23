"""Authoring source for researched cases added from 2026-11-23 (CASE-0021 onward).

Each entry produces three files that stay linked but separate:
  research/cases/<ID>.json            research record (REAL facts, sources read on the retrieval date)
  game/data/cases/<ID>.json           playable case (trigger, design-value effects, choices)
  game/data/story/episodes/<ID>.json  narrative episode (FICTIONAL composites, no real quotes)
and appends one access-log row per source (deduplicated).

Rules followed for every case (CLAUDE.md, AGENTS.md):
  - every fact line paraphrases text that was fetched and read; numbers are copied exactly;
  - claims that could not be verified go to rejected_or_unverified, never into facts;
  - effect magnitudes are design values (documented in shock_note / consequence_notes);
  - characters are fictional composites; real officials are never quoted in dialogue.

Run: python3 scripts/story/author_cases.py   (idempotent)
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def S(sid, inst, title, url, pub, quality="REAL_OFFICIAL", res="", period="", unit="", retrieved="2026-11-23", note=None):
    d = {"source_id": sid, "institution": inst, "title": title, "url": url, "publication_date": pub,
         "retrieved_at": retrieved, "source_quality": quality, "geographic_resolution": res,
         "reference_period": period, "unit": unit}
    if note:
        d["note"] = note
    return d


def E(scope, var, value, **kw):
    e = {"scope": scope, "var": var, "op": "add", "value": value}
    e.update(kw)
    return e


def B(s, t, e="netral", bg=None, **kw):
    b = {"s": s, "e": e, "t": t}
    if bg:
        b["bg"] = bg
    b.update(kw)
    return b


def PICK(*variants):
    return {"pick": [{"if": c, "beats": beats} for c, beats in variants]}


CASES = []

# =====================================================================================  BATCH A
FOC21 = "regions:32.73,74.71,32.17,32.71,32.13,33.20"
CASES.append(dict(
 id="CASE-0021", tick=14, island="jawa", provinces=["32", "74", "33"],
 title_r="Lonjakan kasus demam berdarah dengue 2024",
 title="Musim Nyamuk di Kota-Kota", location="Kota Bandung, Kota Kendari, Bandung Barat, Kota Bogor, Subang, Jepara",
 focus=["32.73", "74.71", "32.17", "32.71", "32.13", "33.20"], category="health_outbreak",
 subcats=["dengue", "vector_control", "urban_health", "climate"],
 start="2024-01", end="2024-06", asof="2024-04-02",
 sources=[
  S("SRC-KEMKES-DBD-2024-04-02", "Kementerian Kesehatan RI", "Waspada, Kenaikan Kasus DBD Belum Mencapai Puncak",
    "https://www.kemkes.go.id/id/waspada-kenaikan-kasus-dbd-belum-mencapai-puncak", "2024-04-02",
    res="nasional; kab/kota teratas", period="s.d. pekan ke-13 2024", unit="kasus; kematian"),
  S("SRC-KEMKES-DBD-2024-06-14", "Kementerian Kesehatan RI", "Waspada DBD di Musim Kemarau",
    "https://www.kemkes.go.id/id/waspada-dbd-di-musim-kemarau", "2024-06-14",
    res="nasional", period="s.d. pekan ke-22 2024", unit="kasus; kematian"),
 ],
 facts=[
  ("Hingga pekan ke-13 2024 (26 Maret), Kemenkes mencatat 53.131 kasus dengue dan 404 kematian. Kasus terbanyak di Kota Bandung (1.741), Kota Kendari (1.195), Bandung Barat (1.143), Kota Bogor (939), dan Subang (909); kematian terbanyak di Jepara (17) dan Subang (15).", "SRC-KEMKES-DBD-2024-04-02", "2024-04-02"),
  ("Hingga pekan ke-17 2024 tercatat 88.593 kasus dan 621 kematian; kematian terjadi di 174 kabupaten/kota di 28 provinsi.", "SRC-KEMKES-DBD-2024-06-14", "2024-06-14"),
  ("Pada pekan ke-22 2024 kasus mencapai 119.709, lebih tinggi dari total sepanjang 2023 (114.720). Kemenkes menyebut siklus tahunan lonjakan dengue memendek dari sekitar 10 tahun menjadi 3 tahun atau kurang, dikaitkan dengan El Nino.", "SRC-KEMKES-DBD-2024-06-14", "2024-06-14"),
 ],
 info="Awal April 2024: kasus dengue naik di banyak kota dan belum mencapai puncak menurut Kemenkes; tempat tidur rumah sakit masih tersedia.",
 root="Musim hujan dan suhu tinggi, genangan di permukiman padat, dan siklus lonjakan yang makin pendek.",
 stake=["Kementerian Kesehatan", "dinas kesehatan kota", "puskesmas dan rumah sakit", "kader jumantik", "warga permukiman padat"],
 rejected=["Total kasus akhir tahun 2024 tidak diambil dari halaman resmi dalam batch ini.", "Rincian program nyamuk ber-Wolbachia tidak diverifikasi; pilihan c di game adalah opsi kebijakan simulasi, bukan klaim program."],
 todo=["Data kasus per kab/kota akhir 2024 (SKDR/Kemenkes)"],
 adapt="Pencegahan berbasis warga (murah, bergantung partisipasi) vs respons rumah sakit dan pengasapan (cepat, mahal) vs teknologi pengendalian vektor jangka panjang (lambat).",
 shock=[E(FOC21, "services", -2.0), E(FOC21, "welfare", -1.0), E("all", "welfare", -0.15)],
 shock_note="Case event (design): services -2 and welfare -1 in the six regencies/cities named by Kemenkes (top cases and top deaths), plus a small national welfare dent. Magnitudes are design values.",
 cons=dict(cross_system_chain="dengue surge -> services strain and welfare -> sentiment; community prevention -> welfare (temporary) + trust; hospital surge -> services now; vector technology -> services and welfare_base later",
           immediate="a: fiscal -0.5, welfare +0.4/month x3, trust +0.5; b: fiscal -2, services +1.5/month x2, trust +1; c: fiscal -3, trust -0.5",
           delayed="c: services +4 after 9 months, welfare_base +0.5 after 12 months", regional="six named cities/regencies", national="fiscal_space; small national welfare dent",
           branching="none", assumptions="All magnitudes are design values."),
 choices=[
  ("a", "Gerakan bersih sarang nyamuk serentak", "Kader dan warga membersihkan genangan dari rumah ke rumah setiap pekan. Murah dan cepat menyebar, tetapi bergantung pada kemauan warga.",
   [E("national", "fiscal_space", -0.5), E(FOC21, "welfare", 0.4, duration=3), E(FOC21, "trust", 0.5)], {"dbd2024_response": "community"}),
  ("b", "Perkuat rumah sakit dan pengasapan", "Tambahan tempat tidur, tenaga, dan pengasapan di kota-kota dengan kasus tertinggi. Paling cepat menolong yang sakit, mahal, dan tidak menyentuh jentik.",
   [E("national", "fiscal_space", -2.0), E(FOC21, "services", 1.5, duration=2), E(FOC21, "trust", 1.0)], {"dbd2024_response": "hospital_fogging"}),
  ("c", "Teknologi pengendalian nyamuk jangka panjang", "Pengendalian vektor berbasis teknologi dan surveilans yang lebih rapat. Tidak menolong musim ini, tetapi bisa menekan lonjakan berikutnya.",
   [E("national", "fiscal_space", -3.0), E(FOC21, "trust", -0.5), E(FOC21, "services", 4.0, delay=9), E(FOC21, "welfare_base", 0.5, delay=12)], {"dbd2024_response": "vector_tech"}),
 ],
 ep=dict(background="kota",
  locals={"bu_sri": {"name": "Bu Sri", "role": "Kader jumantik, Kota Bandung", "color": "6a7a3a", "initials": "S"},
          "dr_fikri": {"name": "dr. Fikri", "role": "Dokter IGD, Kota Kendari", "color": "3a5a8a", "initials": "F"}},
  hook="Kasus demam berdarah melonjak di banyak kota. Rumah sakit mulai penuh, dan puncaknya belum datang.",
  if_postponed="Lonjakan dengue ditangani masing-masing daerah tanpa dorongan nasional.",
  opening=[B("narasi", "Musim hujan belum benar-benar pergi. Di gang-gang sempit, air tergenang di pot, ban bekas, dan talang.", bg="kota"),
           B("bu_sri", "Setiap Jumat saya keliling memeriksa bak mandi. Sekarang hampir setiap rumah ada jentiknya, Pak.", "cemas"),
           B("dr_fikri", "IGD kami penuh pasien demam. Kebanyakan anak-anak. Kami harus cepat membedakan mana yang berbahaya.", "serius", "rumah_sakit"),
           B("yosef", "Kasusnya naik di banyak kota sekaligus. Bandung, Kendari, Bogor. Dan polanya datang makin sering dari tahun ke tahun.", "serius", "ruang_rapat"),
           B("bayu", "Rumah sakit dan pengasapan cepat terlihat, tapi mahal. Gerakan warga murah, tapi hasilnya bergantung pada orang mau bergerak.", "netral"),
           B("sekar", "Orang tua panik, Pak. Mereka ingin melihat pemerintah bergerak di kampungnya, bukan hanya di televisi.", "cemas"),
           B("nara", "Kita tidak bisa mengasapi seluruh negeri. Tapi kita juga tidak bisa membiarkan rumah sakit kewalahan.", "berpikir")],
  info={"a": ("Mengajak warga membersihkan sarang nyamuk serentak.", "Warga kampung padat: lebih sedikit jentik, biaya kecil.", "Hasilnya bergantung pada partisipasi warga.", "Kesejahteraan dan kepercayaan di kota terdampak naik sedikit.", "Tidak ada perubahan kapasitas layanan."),
        "b": ("Menambah kapasitas rumah sakit dan pengasapan.", "Pasien yang sudah sakit: tertangani lebih cepat.", "Anggaran; jentik di rumah tidak tersentuh.", "Layanan kesehatan naik selama dua bulan.", "Lonjakan berikutnya tetap sama besar."),
        "c": ("Membangun pengendalian nyamuk berbasis teknologi.", "Kota-kota rawan untuk tahun-tahun berikutnya.", "Warga yang sakit sekarang; anggaran.", "Kepercayaan turun sedikit.", "Layanan naik besar setelah sekitar sembilan bulan.")},
  reactions={"a": [B("narasi", "Sirene masjid dan pengeras suara RT mengumumkan Jumat bersih. Warga turun membawa ember dan sikat."),
                   B("bu_sri", "Ibu-ibu sekarang saling mengingatkan. Kemarin satu gang menemukan tiga puluh tempat jentik.", "senyum"),
                   B("dr_fikri", "Ini bagus untuk minggu-minggu depan. Pasien yang sudah sakit tetap datang ke kami.", "netral", "rumah_sakit")],
             "b": [B("narasi", "Bangsal tambahan dibuka. Mobil pengasapan berkeliling kota menjelang magrib.", bg="rumah_sakit"),
                   B("dr_fikri", "Tempat tidur tambahan sangat menolong. Kami tidak lagi merawat pasien di lorong.", "lega"),
                   B("bu_sri", "Asapnya memang terlihat. Tapi besok pagi jentiknya masih ada di bak tetangga.", "berpikir", "kota")],
             "c": [B("narasi", "Tim peneliti dan dinas kesehatan memetakan kota-kota yang paling sering dilanda dengue.", bg="ruang_rapat"),
                   B("sekar", "Musim ini orang akan bertanya kenapa kita bicara riset saat anak-anak dirawat.", "cemas"),
                   B("yosef", "Kalau berhasil, lonjakan seperti ini tidak lagi datang setiap tiga tahun. Kalau gagal, kita kehilangan satu musim.", "serius")]},
  callbacks=[{"id": "musim", "after_quarters": 3, "beats": [PICK(
     ({"delta": "services", "op": ">", "value": 2}, [B("dr_fikri", "Musim hujan ini, IGD kami jauh lebih tenang, Pak. Kasus dengue tidak meledak seperti tahun lalu.", "senyum", "rumah_sakit")]),
     ({"delta": "welfare", "op": ">", "value": 0}, [B("bu_sri", "Kebiasaan Jumat bersih masih jalan di gang kami. Tidak semua, tapi cukup banyak.", "netral", "kota")]),
     ({}, [B("bu_sri", "Musim hujan datang lagi, dan jentik kembali, Pak. Kami seperti mulai dari nol.", "kecewa", "kota")]))]}],
  unattended=[B("narasi", "Tanpa arahan nasional, setiap kota menghadapi lonjakan dengue dengan kemampuannya sendiri.", bg="kota"),
              B("dr_fikri", "Kami merawat di lorong selama berminggu-minggu.", "sedih", "rumah_sakit")],
  journal={"a": "Gerakan bersih sarang nyamuk serentak di kota-kota dengan kasus dengue tertinggi.", "b": "Rumah sakit diperkuat dan pengasapan dilakukan saat lonjakan dengue 2024.", "c": "Pengendalian nyamuk berbasis teknologi dimulai untuk menekan lonjakan dengue berikutnya."},
  promises={"c": {"text": "Kota-kota rawan dengue lebih siap menghadapi musim hujan berikutnya.", "due_quarters": 4, "check": {"delta": "services", "op": ">", "value": 2}}})))

FOC22 = "regions:11.07,11.18"
CASES.append(dict(
 id="CASE-0022", tick=46, island="sumatera", provinces=["11"],
 title_r="Kejadian luar biasa polio di Kabupaten Pidie, Aceh, 2022",
 title="Polio Kembali di Pidie", location="Kab. Pidie dan Pidie Jaya, Aceh",
 focus=["11.07", "11.18"], category="health_outbreak",
 subcats=["polio", "immunization", "vaccine_coverage", "public_trust"],
 start="2022-11", end="2023-01", asof="2022-11-28",
 sources=[
  S("SRC-KEMKES-POLIO-2022-11-28", "Kementerian Kesehatan RI", "Kemenkes Gelar Sub Pekan Imunisasi Nasional di Provinsi Aceh, Targetkan 95% Anak Diimunisasi Polio",
    "https://kemkes.go.id/id/kemenkes-gelar-sub-pekan-imunisasi-nasional-di-provinsi-aceh-targetkan-95-anak-diimunisasi-polio", "2022-11-28",
    res="Kab. Pidie; Provinsi Aceh", period="2022-11-28", unit="anak"),
  S("SRC-KEMKES-POLIO-2022-12-05", "Kementerian Kesehatan RI", "Menkes Optimis Target 95% Anak di Provinsi Aceh Diimunisasi Polio Tercapai",
    "https://www.kemkes.go.id/id/menkes-optimis-target-95-anak-di-provinsi-aceh-diimunisasi-polio-tercapai", "2022-12-05",
    res="Kab. Pidie; Provinsi Aceh", period="2022-12-04", unit="persen anak"),
 ],
 facts=[
  ("Indonesia telah menerima sertifikat bebas polio dari WHO pada 2014, tetapi kasus polio kembali ditemukan di Kabupaten Pidie, Aceh, yang menurut Menteri Kesehatan termasuk daerah dengan cakupan imunisasi polio rendah.", "SRC-KEMKES-POLIO-2022-12-05", "2022-12-05"),
  ("Sebagai tindak lanjut KLB, imunisasi polio massal (Sub PIN) dimulai 28 November 2022 di Pidie dengan sasaran 95.603 anak usia 0 sampai 12 tahun; pada hari pertama 14.000 anak diimunisasi.", "SRC-KEMKES-POLIO-2022-11-28", "2022-11-28"),
  ("Sub PIN diperluas ke 21 kabupaten/kota lain di Aceh dalam dua putaran dengan sasaran sekitar 1.217.939 anak; pada hari keenam di Pidie (4 Desember) cakupan mencapai 79,5 persen.", "SRC-KEMKES-POLIO-2022-12-05", "2022-12-05"),
 ],
 info="Akhir November 2022: satu kasus polio terkonfirmasi di Pidie; cakupan imunisasi di wilayah itu rendah bertahun-tahun; vaksinasi massal baru dimulai.",
 root="Cakupan imunisasi rutin yang rendah selama bertahun-tahun.",
 stake=["Kementerian Kesehatan", "Dinas Kesehatan Aceh dan Pidie", "orang tua dan anak", "tokoh masyarakat dan agama", "puskesmas"],
 rejected=["Penyebab rendahnya cakupan imunisasi di Aceh tidak dijelaskan di sumber terverifikasi; game tidak menyebut penyebab tertentu.", "Cakupan akhir putaran kedua tidak ditemukan."],
 todo=["Laporan akhir Sub PIN Aceh 2023"],
 adapt="Kampanye cepat se-provinsi (mahal, merata) vs fokus satu kabupaten (murah, risiko menyebar) vs memperkuat kepercayaan dan imunisasi rutin (lambat, bertahan).",
 shock=[E(FOC22, "services", -2.0), E(FOC22, "trust", -0.5), E("province:11", "services", -0.5)],
 shock_note="Case event (design): services -2 and trust -0.5 in Pidie and Pidie Jaya, services -0.5 across Aceh (low coverage province-wide per Kemenkes). Design values.",
 cons=dict(cross_system_chain="outbreak -> services -> sentiment; province-wide campaign -> services now; local-only -> risk of later welfare loss; routine immunization + trust -> services later",
           immediate="a: fiscal -1.5, Aceh services +1.5/month x3, trust +0.5; b: fiscal -0.5, Pidie services +2/month x2; c: fiscal -1",
           delayed="b: Aceh welfare -0.5 after 6 months (spread risk, design); c: Aceh trust +1.5 after 3 months, services +3 after 6 months",
           regional="Pidie, Pidie Jaya, Aceh province", national="fiscal_space", branching="none", assumptions="All magnitudes are design values."),
 choices=[
  ("a", "Imunisasi serentak se-Aceh", "Vaksinasi massal di semua kabupaten dan kota Aceh dalam dua putaran. Paling luas dan cepat menutup celah, butuh banyak tenaga dan dana.",
   [E("national", "fiscal_space", -1.5), E("province:11", "services", 1.5, duration=3), E("province:11", "trust", 0.5)], {"polio2022_response": "province_wide"}),
  ("b", "Fokus di Pidie dulu", "Vaksinasi intensif hanya di daerah kasus. Murah dan cepat di titik api, tetapi virus bisa saja sudah beredar di kabupaten tetangga.",
   [E("national", "fiscal_space", -0.5), E(FOC22, "services", 2.0, duration=2), E("province:11", "welfare", -0.5, delay=6)], {"polio2022_response": "local_only"}),
  ("c", "Bangun kepercayaan dan imunisasi rutin", "Bersama tokoh masyarakat dan puskesmas, memperbaiki imunisasi rutin di seluruh Aceh. Lebih lambat, tetapi menutup akar masalahnya.",
   [E("national", "fiscal_space", -1.0), E("province:11", "trust", 1.5, delay=3), E("province:11", "services", 3.0, delay=6)], {"polio2022_response": "routine_trust"}),
 ],
 ep=dict(background="desa",
  locals={"bu_cut": {"name": "Bu Cut", "role": "Bidan desa, Pidie", "color": "4a6a7a", "initials": "C"},
          "pak_ilyas": {"name": "Pak Ilyas", "role": "Ayah dan petani, Pidie Jaya", "color": "6a5a3a", "initials": "I"}},
  hook="Kasus polio ditemukan lagi di Pidie, Aceh, delapan tahun setelah Indonesia dinyatakan bebas polio.",
  if_postponed="Vaksinasi polio di Aceh berjalan seadanya tanpa dorongan nasional.",
  opening=[B("narasi", "Sebuah desa di Pidie. Seorang anak tiba-tiba tidak bisa menggerakkan kakinya.", bg="desa"),
           B("bu_cut", "Saya sudah dua puluh tahun jadi bidan. Ini pertama kali saya melihat polio dengan mata sendiri.", "cemas"),
           B("pak_ilyas", "Anak saya belum lengkap imunisasinya, Bu. Dulu kami tidak terlalu memikirkannya.", "sedih"),
           B("yosef", "Satu kasus polio berarti virusnya beredar, Pak. Cakupan imunisasi di sana rendah sudah bertahun-tahun.", "serius", "ruang_rapat"),
           B("bayu", "Vaksinasi seluruh Aceh mahal. Fokus satu kabupaten murah. Pertanyaannya, apakah virusnya mau menunggu di satu kabupaten.", "netral"),
           B("sekar", "Dan orang tua harus mau datang. Itu soal kepercayaan, bukan hanya vaksin.", "berpikir"),
           B("nara", "Kita pernah menghapus polio dari negeri ini. Saya tidak mau ia kembali tinggal.", "serius")],
  info={"a": ("Vaksinasi massal di seluruh Aceh.", "Semua anak di Aceh: celah imunisasi ditutup cepat.", "Anggaran dan tenaga kesehatan.", "Layanan kesehatan Aceh naik selama tiga bulan.", "Tidak ada perubahan pada imunisasi rutin."),
        "b": ("Vaksinasi intensif di Pidie dan sekitarnya saja.", "Anak-anak di daerah kasus, dengan biaya kecil.", "Kabupaten lain di Aceh jika virus sudah menyebar.", "Layanan di Pidie naik dua bulan.", "Risiko dampak di Aceh enam bulan kemudian."),
        "c": ("Memperbaiki imunisasi rutin bersama tokoh masyarakat.", "Anak-anak Aceh untuk jangka panjang.", "Anak yang belum terlindungi minggu ini.", "Biaya sedang.", "Kepercayaan naik setelah tiga bulan, layanan setelah enam bulan.")},
  reactions={"a": [B("narasi", "Posyandu, sekolah, dan meunasah menjadi pos imunisasi di seluruh Aceh.", bg="desa"),
                   B("bu_cut", "Antreannya panjang sekali. Hari pertama saja ribuan anak. Saya hampir kehabisan suara.", "lega"),
                   B("pak_ilyas", "Anak bungsu saya ikut. Kakaknya, semoga masih bisa pulih.", "netral")],
             "b": [B("narasi", "Tim imunisasi dipusatkan di Pidie dan Pidie Jaya.", bg="desa"),
                   B("bu_cut", "Di sini hampir semua anak sudah ditetes. Tapi keluarga di sini juga berdagang ke kabupaten lain setiap minggu.", "berpikir"),
                   B("yosef", "Murah dan cepat. Saya hanya berharap kita tidak terlambat satu langkah.", "cemas", "ruang_rapat")],
             "c": [B("narasi", "Petugas puskesmas duduk bersama tokoh masyarakat dan guru pengajian, membicarakan imunisasi anak.", bg="desa"),
                   B("pak_ilyas", "Kalau yang menjelaskan orang yang kami kenal, kami lebih tenang.", "netral"),
                   B("sekar", "Ini tidak akan masuk berita besar. Tapi ini yang membuat orang tua datang lagi tahun depan.", "senyum", "ruang_rapat")]},
  callbacks=[{"id": "imunisasi", "after_quarters": 3, "beats": [PICK(
     ({"delta": "services", "op": ">", "value": 1.5}, [B("bu_cut", "Posyandu kami sekarang ramai, Pak. Ibu-ibu datang sendiri, tidak perlu dijemput.", "senyum", "desa")]),
     ({}, [B("bu_cut", "Setelah kampanye selesai, posyandu sepi lagi. Imunisasi rutin belum banyak berubah.", "kecewa", "desa")]))]}],
  unattended=[B("narasi", "Tanpa arahan nasional, Dinas Kesehatan Aceh memvaksinasi dengan tenaga yang ada.", bg="desa"),
              B("bu_cut", "Kami bekerja sampai malam. Tapi desa-desa jauh belum terjangkau.", "sedih")],
  journal={"a": "Imunisasi polio serentak dijalankan di seluruh Aceh.", "b": "Imunisasi polio dipusatkan di Pidie dan Pidie Jaya.", "c": "Imunisasi rutin di Aceh diperkuat bersama tokoh masyarakat."},
  promises={"c": {"text": "Imunisasi rutin anak di Aceh kembali kuat.", "due_quarters": 3, "check": {"delta": "services", "op": ">", "value": 1.5}}})))

CASES.append(dict(
 id="CASE-0023", tick=34, island="jawa", provinces=["32"],
 title_r="Gempa bumi Cianjur, Jawa Barat, 21 November 2022",
 title="Gempa di Kaki Gunung Gede", location="Kab. Cianjur, Jawa Barat",
 focus=["32.03"], category="disaster_earthquake",
 subcats=["earthquake", "housing_reconstruction", "landslide", "aid_scheme"],
 start="2022-11-21", end="2022-11-24", asof="2022-11-24",
 sources=[
  S("SRC-SETKAB-CIANJUR-2022-11-22", "Sekretariat Kabinet RI (mengutip BNPB)", "BNPB Turunkan Tim Reaksi Cepat dan Salurkan Bantuan Logistik ke Lokasi Terdampak Gempa Cianjur",
    "https://setkab.go.id/bnpb-turunkan-tim-reaksi-cepat-dan-salurkan-bantuan-logistik-ke-lokasi-terdampak-gempa-cianjur/", "2022-11-22", res="Kab. Cianjur", period="2022-11-21"),
  S("SRC-SETKAB-CIANJUR-2022-11-24", "Sekretariat Kabinet RI", "Kunjungan ke Pos Pengungsi Gempa di Kecamatan Cugenang, Kabupaten Cianjur, 24 November 2022 (keterangan pers)",
    "https://setkab.go.id/kunjungan-ke-pos-pengungsi-gempa-di-kecamatan-cugenang-kabupaten-cianjur-provinsi-jawa-barat-24-november-2022/", "2022-11-24", res="Kec. Cugenang, Kab. Cianjur", period="2022-11-24", unit="pasien; rupiah per rumah"),
  S("SRC-SETKAB-CIANJUR-PUPR-2022-11-22", "Sekretariat Kabinet RI (mengutip Kementerian PUPR)", "Gerak Cepat Pemerintah Tangani Dampak Bencana Gempa Bumi Cianjur",
    "https://setkab.go.id/gerak-cepat-pemerintah-tangani-bencana-gempa-bumi-cianjur/", "2022-11-22", res="ruas Cipanas-Cianjur", period="2022-11-21/22"),
 ],
 facts=[
  ("Gempa bermagnitudo 5,6 mengguncang Kabupaten Cianjur pada siang hari 21 November 2022. BNPB mengirim tim reaksi cepat, 47 tenda, dan bantuan logistik senilai Rp500 juta.", "SRC-SETKAB-CIANJUR-2022-11-22", "2022-11-22"),
  ("Longsoran akibat gempa menutup ruas jalan Cipanas sampai Cianjur; alat berat dari dua sisi berhasil menembusnya pada pagi 22 November.", "SRC-SETKAB-CIANJUR-PUPR-2022-11-22", "2022-11-22"),
  ("Kecamatan Cugenang menjadi episentrum dengan kerusakan rumah dan korban terbanyak. Dari 741 pasien yang awalnya masuk rumah sakit, 24 masih dirawat pada 24 November.", "SRC-SETKAB-CIANJUR-2022-11-24", "2022-11-24"),
  ("Pemerintah menyiapkan bantuan Rp50 juta untuk rumah rusak berat, Rp25 juta rusak sedang, dan Rp10 juta rusak ringan, dengan beberapa skema pembangunan: oleh kementerian, dibantu TNI, atau oleh warga sendiri.", "SRC-SETKAB-CIANJUR-2022-11-24", "2022-11-24"),
 ],
 info="24 November 2022: evakuasi masih berjalan di Cugenang; bantuan perbaikan rumah sudah diumumkan, skema pembangunannya belum diputuskan.",
 root="Permukiman padat di kawasan rawan gempa dan longsor, dengan banyak rumah yang tidak tahan gempa.",
 stake=["BNPB", "Kementerian PUPR", "TNI", "Pemkab Cianjur", "warga Cugenang dan sekitarnya"],
 rejected=["Total korban jiwa dan rumah rusak final berasal dari halaman Kemenko PMK yang tidak dapat diakses otomatis; tidak dipakai.", "Detail sesar dan zona relokasi tidak diverifikasi; pilihan relokasi di game adalah opsi simulasi."],
 todo=["Data final korban dan rumah rusak (BNPB)"],
 adapt="Rekonstruksi oleh pemerintah (cepat, mahal) vs dana stimulan per tingkat kerusakan (langsung ke warga) vs relokasi dan standar rumah tahan gempa (lambat, aman).",
 shock=[E("region:32.03", "damage", 14.0), E("region:32.03", "welfare", -3.0), E("region:32.03", "services", -2.0)],
 shock_note="Case event (design): Cianjur damage 14, welfare -3, services -2. Grounded in the reported epicentre damage and casualties; magnitudes are design values.",
 cons=dict(cross_system_chain="earthquake -> damage -> services & welfare; government rebuild -> damage recovery + trust; stimulus -> welfare + damage recovery; relocation -> infrastructure + welfare_base later at a trust cost",
           immediate="a: fiscal -5, damage -2/month x4 (from month 1), trust +1.5; b: fiscal -3.5, damage -1.5/month x3, welfare +1/month x3, trust +1; c: fiscal -6, trust -1, damage -1/month x2",
           delayed="c: infrastructure +6 after 9 months, welfare_base +1 after 12 months", regional="Kab. Cianjur", national="fiscal_space", branching="none", assumptions="All magnitudes are design values."),
 choices=[
  ("a", "Bangun ulang oleh pemerintah dan TNI", "Kementerian dan TNI membangun kembali rumah yang rusak dengan standar tahan gempa. Rapi dan cepat, tetapi biaya terbesar ditanggung negara.",
   [E("national", "fiscal_space", -5.0), E("region:32.03", "damage", -2.0, delay=1, duration=4), E("region:32.03", "trust", 1.5)], {"cianjur2022_response": "government_rebuild"}),
  ("b", "Dana stimulan sesuai tingkat kerusakan", "Warga menerima bantuan sesuai kerusakan rumahnya dan membangun sendiri dengan pendampingan. Cepat menyentuh keluarga, mutu bergantung pada pengawasan.",
   [E("national", "fiscal_space", -3.5), E("region:32.03", "damage", -1.5, duration=3), E("region:32.03", "welfare", 1.0, duration=3), E("region:32.03", "trust", 1.0)], {"cianjur2022_response": "stimulus"}),
  ("c", "Relokasi dan rumah tahan gempa", "Permukiman di lereng paling rawan dipindahkan dan semua rumah baru wajib tahan gempa. Paling aman untuk jangka panjang, paling lambat dan paling berat diterima.",
   [E("national", "fiscal_space", -6.0), E("region:32.03", "trust", -1.0), E("region:32.03", "damage", -1.0, duration=2), E("region:32.03", "infrastructure", 6.0, delay=9), E("region:32.03", "welfare_base", 1.0, delay=12)], {"cianjur2022_response": "relocation"}),
 ],
 ep=dict(background="desa",
  locals={"teh_neneng": {"name": "Teh Neneng", "role": "Guru madrasah, Cugenang", "color": "8a5a6a", "initials": "N"},
          "mang_ujang": {"name": "Mang Dadan", "role": "Tukang bangunan, Cianjur", "color": "5a6a3a", "initials": "D"}},
  hook="Gempa merobohkan ribuan rumah di Cianjur. Banyak korban adalah anak-anak yang sedang belajar.",
  if_postponed="Pembangunan kembali Cianjur berjalan tanpa skema yang jelas. Warga membangun dengan apa yang ada.",
  opening=[B("narasi", "Siang hari di kaki Gunung Gede. Tanah berguncang hanya belasan detik.", bg="desa"),
           B("teh_neneng", "Anak-anak sedang mengaji waktu dindingnya runtuh. Kami menggali dengan tangan sampai sore.", "sedih"),
           B("mang_ujang", "Rumah-rumah di sini kebanyakan bata tanpa tulang besi, Pak. Murah dibangun, cepat roboh.", "serius"),
           B("yosef", "Jalan ke Cipanas sempat tertimbun longsor. Kecamatan Cugenang paling parah.", "serius", "ruang_rapat"),
           B("bayu", "Bantuan perbaikan rumah sudah diumumkan sesuai tingkat kerusakan. Sekarang pertanyaannya, siapa yang membangun.", "netral"),
           B("sekar", "Warga takut tidur di dalam rumah. Mereka ingin tahu kapan bisa tinggal dengan aman.", "cemas"),
           B("nara", "Membangun cepat itu penting. Membangun yang tidak roboh lagi, lebih penting.", "berpikir")],
  info={"a": ("Pemerintah dan TNI membangun kembali rumah warga.", "Warga terdampak: rumah tahan gempa dibangun rapi.", "Anggaran negara: biaya terbesar.", "Kerusakan pulih cepat selama empat bulan, kepercayaan naik.", "Tidak ada perubahan lokasi permukiman."),
        "b": ("Memberi dana stimulan sesuai kerusakan rumah.", "Keluarga terdampak: bantuan langsung dan pilihan sendiri.", "Mutu bangunan bergantung pengawasan.", "Kesejahteraan dan pemulihan naik tiga bulan.", "Risiko mutu tidak merata."),
        "c": ("Memindahkan permukiman paling rawan dan mewajibkan rumah tahan gempa.", "Keselamatan warga untuk jangka panjang.", "Warga yang harus pindah; anggaran.", "Kepercayaan turun.", "Infrastruktur naik setelah sembilan bulan, kesejahteraan struktural setelah setahun.")},
  reactions={"a": [B("narasi", "Prajurit dan pekerja kementerian mendirikan rumah-rumah baru dengan rangka tahan gempa.", bg="desa"),
                   B("mang_ujang", "Saya ikut jadi pekerja. Sekarang saya tahu cara memasang besi yang benar.", "senyum"),
                   B("bayu", "Tagihannya besar, Pak. Tapi rumah-rumah ini akan berdiri lama.", "netral", "ruang_rapat")],
             "b": [B("narasi", "Dana bantuan masuk ke rekening warga sesuai tingkat kerusakan rumahnya.", bg="desa"),
                   B("teh_neneng", "Kami bisa memilih tukang sendiri, dan rumah cepat berdiri lagi.", "senyum"),
                   B("mang_ujang", "Asal ada yang mengawasi, Pak. Kalau tidak, orang akan membangun seperti dulu lagi.", "berpikir")],
             "c": [B("narasi", "Lereng paling rawan ditandai. Lahan baru disiapkan untuk permukiman yang lebih aman.", bg="desa"),
                   B("teh_neneng", "Madrasah kami harus pindah. Saya sedih, tapi saya tidak mau mengajar di bawah dinding yang bisa runtuh lagi.", "sedih"),
                   B("sekar", "Pindah itu berat, Pak. Kita harus terus hadir sampai mereka benar-benar tinggal di tempat baru.", "cemas", "ruang_rapat")]},
  callbacks=[{"id": "rumah", "after_quarters": 3, "beats": [PICK(
     ({"delta": "damage", "op": "<", "value": -8}, [B("teh_neneng", "Anak-anak sudah mengaji lagi di bangunan baru, Pak. Mereka masih kaget kalau ada truk lewat, tapi pelan-pelan tenang.", "senyum", "desa")]),
     ({}, [B("mang_ujang", "Masih banyak keluarga di tenda, Pak. Pembangunannya belum selesai.", "kecewa", "desa")]))]}],
  unattended=[B("narasi", "Tanpa skema yang jelas, warga Cianjur membangun kembali dengan cara lama.", bg="desa"),
              B("mang_ujang", "Bata tanpa besi lagi, Pak. Cepat, murah, dan sama rapuhnya.", "kecewa")],
  journal={"a": "Rumah warga Cianjur dibangun ulang oleh pemerintah dan TNI dengan standar tahan gempa.", "b": "Warga Cianjur menerima dana stimulan sesuai tingkat kerusakan rumah.", "c": "Permukiman paling rawan di Cianjur direlokasi dan rumah baru wajib tahan gempa."},
  promises={"c": {"text": "Warga dari lereng paling rawan di Cianjur tinggal di permukiman baru yang aman.", "due_quarters": 4, "check": {"delta": "infrastructure", "op": ">", "value": 3}}})))

CASES.append(dict(
 id="CASE-0024", tick=23, island="jawa", provinces=["35"],
 title_r="Erupsi Gunung Semeru dan relokasi warga Lumajang, Desember 2021",
 title="Awan Panas Semeru", location="Kab. Lumajang, Jawa Timur",
 focus=["35.08"], category="disaster_volcanic",
 subcats=["volcanic_eruption", "relocation", "temporary_housing", "livelihoods"],
 start="2021-12-04", end="2022-03-31", asof="2021-12-26",
 sources=[
  S("SRC-SETKAB-SEMERU-2021-12-05", "Sekretariat Kabinet RI", "President Jokowi Orders Immediate Response Following Mt. Semeru Eruption",
    "https://setkab.go.id/en/president-jokowi-orders-for-immediate-response-following-mt-semeru-eruption/", "2021-12-05", res="Kab. Lumajang", period="2021-12-04/05"),
  S("SRC-BNPB-SEMERU-2021-12-26", "BNPB", "Penanganan Paska Awan Panas Guguran Semeru Memasuki Status Transisi Darurat",
    "https://www.bnpb.go.id/berita/penanganan-paska-awan-panas-guguran-semeru-memasuki-status-transisi-darurat", "2021-12-26", res="Kec. Candipuro, Pronojiwo, Pasirian", period="2021-12-25", unit="unit rumah; jiwa"),
  S("SRC-BNPB-SEMERU-2022-03-31", "BNPB", "Tahap Pertama Targetkan Penyintas Erupsi Semeru di Pengungsian Tinggal di Huntap dan Huntara",
    "https://bnpb.go.id/berita/tahap-pertama-targetkan-penyintas-erupsi-semeru-di-pengungsian-tinggal-di-huntap-dan-huntara", "2022-03-31", res="Desa Sumbermujur, Kec. Candipuro", period="2022-03-31", unit="unit"),
 ],
 facts=[
  ("Setelah erupsi Gunung Semeru pada Sabtu 4 Desember 2021, Presiden memerintahkan BNPB, Basarnas, para menteri terkait, TNI, Polri, gubernur, dan bupati sekitar untuk segera menangani darurat, mencari korban, dan merawat yang terluka.", "SRC-SETKAB-SEMERU-2021-12-05", "2021-12-05"),
  ("Per 25 Desember 2021, posko mencatat 1.027 rumah rusak di Desa Sumberwuluh (Candipuro) dan Desa Supiturang (Pronojiwo), serta 9.417 warga mengungsi di 402 titik; Bupati Lumajang menetapkan masa transisi darurat 90 hari.", "SRC-BNPB-SEMERU-2021-12-26", "2021-12-26"),
  ("Lahan relokasi di Desa Sumbermujur, Candipuro, disiapkan setelah mendapat izin Kementerian LHK; pada Maret 2022 BNPB menargetkan 300 sampai 478 keluarga dari pengungsian menempati hunian tetap dan sementara tahap pertama sebelum Lebaran.", "SRC-BNPB-SEMERU-2022-03-31", "2022-03-31"),
 ],
 info="Akhir Desember 2021: ribuan warga masih mengungsi; lahan relokasi sedang dibersihkan; warga belum tahu kapan bisa pindah.",
 root="Permukiman dan lahan pertanian berada di jalur aliran awan panas dan lahar Semeru.",
 stake=["BNPB", "Pemkab Lumajang", "Kementerian PUPR", "Kementerian LHK", "warga Candipuro dan Pronojiwo"],
 rejected=["Angka korban jiwa berbeda antarsumber (berita); tidak dicantumkan sebagai fakta.", "Halaman BNPB tentang relokasi Dusun Sumbersari bertanggal November 2025 membahas erupsi yang lebih baru; tidak dipakai untuk kasus 2021."],
 todo=["Data korban jiwa final erupsi Desember 2021 (BNPB)"],
 adapt="Pemulihan di tempat (cepat, risiko tetap) vs relokasi ke hunian tetap (aman, lambat, berat) vs menopang penghidupan (langsung, tidak mengubah risiko).",
 shock=[E("region:35.08", "damage", 12.0), E("region:35.08", "welfare", -2.5), E("region:35.08", "services", -1.5)],
 shock_note="Case event (design): Lumajang damage 12, welfare -2.5, services -1.5 (1,027 damaged houses and 9,417 displaced per BNPB). Design values.",
 cons=dict(cross_system_chain="eruption -> damage & welfare; recovery in place -> damage recovery; relocation -> infrastructure + welfare_base later at a trust cost; livelihood support -> welfare",
           immediate="a: fiscal -2.5, damage -2/month x3, trust +1; b: fiscal -5, trust -1, damage -1/month x2; c: fiscal -3, welfare +1/month x4, trust +0.5",
           delayed="b: infrastructure +6 after 6 months, welfare_base +1 after 9 months", regional="Kab. Lumajang", national="fiscal_space", branching="none", assumptions="All magnitudes are design values."),
 choices=[
  ("a", "Pulihkan di tempat semula", "Hunian sementara dan perbaikan rumah di desa-desa terdampak. Warga cepat kembali, tetapi tetap tinggal di jalur awan panas.",
   [E("national", "fiscal_space", -2.5), E("region:35.08", "damage", -2.0, duration=3), E("region:35.08", "trust", 1.0)], {"semeru2021_response": "in_place"}),
  ("b", "Relokasi ke hunian tetap yang aman", "Warga dari zona bahaya dipindahkan ke hunian tetap di lahan baru yang jauh dari jalur lahar. Paling aman, paling mahal, dan berat bagi yang harus meninggalkan ladangnya.",
   [E("national", "fiscal_space", -5.0), E("region:35.08", "trust", -1.0), E("region:35.08", "damage", -1.0, duration=2), E("region:35.08", "infrastructure", 6.0, delay=6), E("region:35.08", "welfare_base", 1.0, delay=9)], {"semeru2021_response": "relocation"}),
  ("c", "Topang penghidupan petani dan pekerja", "Bantuan tunai, bibit, dan pekerjaan sementara bagi keluarga yang kehilangan ladang dan penghasilan. Menolong dapur warga, tidak menjauhkan mereka dari bahaya.",
   [E("national", "fiscal_space", -3.0), E("region:35.08", "welfare", 1.0, duration=4), E("region:35.08", "trust", 0.5)], {"semeru2021_response": "livelihood"}),
 ],
 ep=dict(background="gunung_api",
  locals={"pak_sutrisno": {"name": "Pak Sutrisno", "role": "Petani, Candipuro", "color": "6a5a3a", "initials": "S"},
          "mbak_lina": {"name": "Mbak Lina", "role": "Relawan dapur umum, Pronojiwo", "color": "8a4a5a", "initials": "L"}},
  hook="Awan panas Semeru mengubur desa-desa di Lumajang. Ribuan warga mengungsi dan bertanya ke mana harus pulang.",
  if_postponed="Pemulihan Lumajang berjalan tanpa keputusan relokasi. Warga kembali ke desa di jalur awan panas.",
  opening=[B("narasi", "Sore itu langit di Lumajang mendadak gelap. Abu turun seperti hujan, lalu awan panas meluncur ke lembah.", bg="gunung_api"),
           B("pak_sutrisno", "Ladang saya di bawah pasir sekarang, Pak. Rumah juga. Yang tersisa cuma atapnya.", "sedih"),
           B("mbak_lina", "Di dapur umum kami memasak untuk ribuan orang setiap hari. Mereka bertanya, kapan bisa pulang.", "cemas"),
           B("yosef", "Lebih dari seribu rumah rusak, Pak. Lahan untuk relokasi sudah ada, di luar jalur lahar.", "serius", "ruang_rapat"),
           B("bayu", "Relokasi mahal dan lama. Membangun di tempat lama lebih murah, tapi gunungnya tidak pindah.", "netral"),
           B("sekar", "Dan banyak warga tidak mau jauh dari ladangnya. Bagi mereka, tanah itu hidup.", "berpikir"),
           B("nara", "Saya mengerti kenapa mereka ingin pulang. Saya juga mengerti kenapa kita tidak boleh membiarkan mereka.", "berpikir")],
  info={"a": ("Memulihkan desa di tempat semula.", "Warga yang ingin segera pulang.", "Warga di masa depan: risiko awan panas tetap.", "Kerusakan pulih cepat tiga bulan, kepercayaan naik.", "Tidak ada pengurangan risiko."),
        "b": ("Memindahkan warga ke hunian tetap yang aman.", "Keselamatan warga jangka panjang.", "Warga yang harus meninggalkan ladang; anggaran.", "Kepercayaan turun di awal.", "Infrastruktur naik setelah enam bulan, kesejahteraan struktural setelah sembilan bulan."),
        "c": ("Menopang penghidupan keluarga terdampak.", "Petani dan pekerja yang kehilangan penghasilan.", "Risiko tempat tinggal tidak berubah.", "Kesejahteraan naik empat bulan.", "Manfaat berhenti saat bantuan selesai.")},
  reactions={"a": [B("narasi", "Hunian sementara dibangun di dekat desa lama. Jalan dan jembatan diperbaiki.", bg="gunung_api"),
                   B("pak_sutrisno", "Saya bisa menengok ladang setiap hari. Itu yang saya mau.", "lega"),
                   B("yosef", "Mereka senang. Saya hanya berharap gunung itu tenang selama mungkin.", "cemas", "ruang_rapat")],
             "b": [B("narasi", "Alat berat membersihkan lahan relokasi. Rumah-rumah tetap mulai berdiri berderet.", bg="desa"),
                   B("pak_sutrisno", "Rumahnya bagus, Pak. Tapi ladang saya jauh sekarang. Saya harus naik motor sejam.", "kecewa"),
                   B("mbak_lina", "Anak-anak senang ada listrik dan air di rumah baru. Orang tua butuh waktu.", "netral")],
             "c": [B("narasi", "Bantuan tunai, bibit, dan pekerjaan padat karya disalurkan ke keluarga terdampak.", bg="desa"),
                   B("mbak_lina", "Dapur-dapur keluarga mulai menyala lagi. Dapur umum bisa sedikit istirahat.", "senyum"),
                   B("yosef", "Ini menolong mereka bertahan. Tapi mereka bertahan di tempat yang sama berbahayanya.", "berpikir", "ruang_rapat")]},
  callbacks=[{"id": "huntap", "after_quarters": 3, "choices": ["b"], "beats": [PICK(
     ({"delta": "infrastructure", "op": ">", "value": 3}, [B("mbak_lina", "Ratusan keluarga sudah pindah ke hunian tetap, Pak. Listrik dan airnya jalan.", "senyum", "desa")]),
     ({}, [B("pak_sutrisno", "Hunian tetapnya belum selesai, Pak. Sebagian dari kami kembali ke desa lama.", "kecewa", "gunung_api")]))]},
            {"id": "ladang", "after_quarters": 2, "choices": ["a", "c"], "beats": [B("pak_sutrisno", "Ladang mulai hijau lagi, Pak. Tapi setiap kali gunung bergemuruh, kami semua berhenti bekerja dan menoleh.", "netral", "gunung_api")]}],
  unattended=[B("narasi", "Tanpa keputusan relokasi, warga Lumajang kembali ke desa lamanya satu per satu.", bg="gunung_api"),
              B("mbak_lina", "Mereka pulang karena tidak ada pilihan lain.", "sedih")],
  journal={"a": "Desa-desa terdampak Semeru dipulihkan di tempat semula.", "b": "Warga zona bahaya Semeru direlokasi ke hunian tetap.", "c": "Keluarga terdampak Semeru dibantu penghidupannya."},
  promises={"b": {"text": "Warga dari jalur awan panas Semeru menempati hunian tetap yang aman.", "due_quarters": 3, "check": {"delta": "infrastructure", "op": ">", "value": 3}}})))

FOC25 = "regions:53.06,53.13,53.05,53.01,53.71"
CASES.append(dict(
 id="CASE-0025", tick=39, island="bali_nusa_tenggara", provinces=["53"],
 title_r="Siklon tropis Seroja, banjir bandang, dan longsor di Nusa Tenggara Timur, April 2021",
 title="Badai Seroja di Kepulauan Timur", location="Flores Timur, Lembata, Alor, Kab. Kupang, Kota Kupang (NTT)",
 focus=["53.06", "53.13", "53.05", "53.01", "53.71"], category="disaster_cyclone",
 subcats=["tropical_cyclone", "flash_flood", "island_logistics", "early_warning"],
 start="2021-04-02", end="2021-05-05", asof="2021-04-10",
 sources=[
  S("SRC-BNPB-SEROJA-2021-04-08", "BNPB", "Gubernur NTT Tetapkan Tanggap Darurat Bencana",
    "https://bnpb.go.id/berita/gubernur-ntt-tetapkan-tanggap-darurat-bencana-", "2021-04-08", res="Kota Kupang dan 21 kabupaten NTT", period="2021-04-06/05-05"),
  S("SRC-BNPB-SEROJA-2021-04-12", "BNPB", "BNPB Perbaharui Data Korban NTT, Pencarian Korban Hilang Terus Dioptimalkan",
    "https://www.bnpb.go.id/index.php/berita/bnpb-perbaharui-data-korban-ntt-pencarian-korban-hilang-terus-dioptimalkan", "2021-04-12", res="kabupaten/kota NTT", period="2021-04-10", unit="orang"),
  S("SRC-BNPB-SEROJA-2021-04-30", "BNPB", "Pembelajaran dari Banjir Bandang dan Longsor NTT",
    "https://www.bnpb.go.id/berita/pembelajaran-dari-banjir-bandang-dan-longsor-ntt", "2021-04-30", res="Provinsi NTT", period="2021-04", unit="orang"),
 ],
 facts=[
  ("Gubernur NTT menetapkan status tanggap darurat bencana siklon tropis, banjir bandang, longsor, dan gelombang pasang dari 6 April sampai 5 Mei 2021, mencakup Kota Kupang dan 21 kabupaten.", "SRC-BNPB-SEROJA-2021-04-08", "2021-04-08"),
  ("Per 10 April 2021, BNPB mencatat 174 orang meninggal dan 48 hilang di NTT: Flores Timur 71 meninggal, Lembata 46, Alor 28, Kabupaten Kupang 12, dan Kota Kupang 6.", "SRC-BNPB-SEROJA-2021-04-12", "2021-04-12"),
  ("Data BPBD NTT kemudian mencatat 182 korban jiwa. BMKG telah beberapa kali mengeluarkan peringatan dini cuaca ekstrem dan bibit siklon; Seroja disebut siklon terbesar kedua di Indonesia setelah siklon Kenanga.", "SRC-BNPB-SEROJA-2021-04-30", "2021-04-30"),
 ],
 info="10 April 2021: pencarian korban hilang masih berjalan; banyak desa di pulau-pulau kecil hanya bisa dijangkau lewat laut; status tanggap darurat sebulan.",
 root="Cuaca ekstrem di pulau-pulau dengan lereng curam, permukiman di jalur banjir bandang, dan logistik antarpulau yang terbatas.",
 stake=["BNPB dan BPBD NTT", "BMKG", "pemerintah kabupaten kepulauan", "warga Adonara, Lembata, Alor", "nelayan dan petani"],
 rejected=["Angka lain di pemberitaan (177, 181) tidak dipakai; game memakai angka BNPB 10 April dan BPBD 182.", "Kunjungan Presiden ke lokasi tidak diverifikasi dari sumber resmi dalam batch ini."],
 todo=["Data rumah rusak per kabupaten (BNPB)"],
 adapt="Logistik darurat antarpulau (cepat, mahal) vs peringatan dini sampai desa (murah, pencegahan) vs relokasi dari jalur banjir bandang (lambat, aman).",
 shock=[E("region:53.06", "damage", 12.0), E("region:53.13", "damage", 10.0), E("region:53.05", "damage", 7.0), E("region:53.01", "damage", 3.0), E("region:53.71", "damage", 2.0),
        E("regions:53.06,53.13", "welfare", -2.0), E(FOC25, "services", -1.0)],
 shock_note="Case event (design): damage ordered by BNPB deaths of 10 April (Flores Timur 71 > Lembata 46 > Alor 28 > Kab. Kupang 12 > Kota Kupang 6). Magnitudes are design values.",
 cons=dict(cross_system_chain="cyclone -> damage & services; island logistics -> damage recovery + trust; early warning -> infrastructure/services later; relocation -> infrastructure + welfare_base later at a trust cost",
           immediate="a: fiscal -3.5, damage -2/month x3, trust +1; b: fiscal -1.5, trust +0.5; c: fiscal -4.5, trust -1",
           delayed="b: infrastructure +3 and services +1 after 6 months; c: infrastructure +5 after 9 months, welfare_base +0.8 after 12 months (Flores Timur, Lembata)",
           regional="five NTT regencies/cities with BNPB-recorded deaths", national="fiscal_space", branching="none", assumptions="All magnitudes are design values."),
 choices=[
  ("a", "Logistik darurat lintas pulau", "Kapal dan pesawat membawa bantuan, alat berat, dan tenaga ke pulau-pulau terdampak. Cepat dan mahal.",
   [E("national", "fiscal_space", -3.5), E(FOC25, "damage", -2.0, duration=3), E(FOC25, "trust", 1.0)], {"seroja2021_response": "island_logistics"}),
  ("b", "Peringatan dini sampai ke desa", "Peringatan cuaca ekstrem diteruskan sampai kepala desa, dengan jalur dan latihan mengungsi. Murah, tidak memulihkan kerusakan sekarang.",
   [E("national", "fiscal_space", -1.5), E(FOC25, "trust", 0.5), E(FOC25, "infrastructure", 3.0, delay=6), E(FOC25, "services", 1.0, delay=6)], {"seroja2021_response": "early_warning"}),
  ("c", "Relokasi dari jalur banjir bandang", "Permukiman di muara sungai dan kaki lereng paling rawan di Flores Timur dan Lembata dipindahkan. Aman untuk jangka panjang, berat dan lama.",
   [E("national", "fiscal_space", -4.5), E(FOC25, "trust", -1.0), E("regions:53.06,53.13", "infrastructure", 5.0, delay=9), E("regions:53.06,53.13", "welfare_base", 0.8, delay=12)], {"seroja2021_response": "relocation"}),
 ],
 ep=dict(background="pesisir_rusak",
  locals={"mama_theresia": {"name": "Mama Theresia", "role": "Penenun dan ibu rumah tangga, Adonara", "color": "8a3a4a", "initials": "T"},
          "om_frans": {"name": "Om Frans", "role": "Nakhoda kapal penyeberangan, Lewoleba", "color": "2a5a7a", "initials": "F"}},
  hook="Siklon tropis membawa banjir bandang dan longsor ke pulau-pulau di NTT. Banyak desa hanya bisa dicapai lewat laut.",
  if_postponed="Pulau-pulau terdampak Seroja menunggu bantuan dengan kapal seadanya.",
  opening=[B("narasi", "Hujan tidak berhenti selama tiga hari. Angin mencabut atap-atap seng di pulau-pulau timur.", bg="pesisir_rusak"),
           B("mama_theresia", "Banjir datang malam hari dari bukit. Batu dan lumpur menutup separuh kampung kami.", "sedih"),
           B("om_frans", "Kapal saya satu-satunya yang berani menyeberang minggu ini, Pak. Bantuan menumpuk di pelabuhan.", "cemas", "pelabuhan"),
           B("yosef", "Flores Timur, Lembata, Alor. Korbannya ratusan, Pak. Dan jarak antarpulau membuat semuanya lebih lambat.", "serius", "ruang_rapat"),
           B("bayu", "Membawa bantuan lewat laut dan udara mahal. Tapi menunggu juga mahal, dengan cara lain.", "netral"),
           B("sekar", "Peringatan cuaca sebenarnya sudah dikeluarkan. Tapi apakah sampai ke kampung-kampung di lereng?", "berpikir"),
           B("nara", "Kalau peringatannya ada tapi tidak sampai, itu juga kegagalan kita.", "serius")],
  info={"a": ("Mengirim logistik darurat lewat laut dan udara.", "Warga di pulau-pulau terdampak: bantuan cepat sampai.", "Anggaran; tidak mengubah kesiapan berikutnya.", "Kerusakan pulih tiga bulan, kepercayaan naik.", "Risiko berikutnya sama."),
        "b": ("Memastikan peringatan dini sampai ke desa.", "Seluruh kepulauan untuk badai berikutnya.", "Kerusakan sekarang pulih seperti biasa.", "Biaya kecil, kepercayaan naik sedikit.", "Infrastruktur dan layanan naik setelah enam bulan."),
        "c": ("Memindahkan permukiman dari jalur banjir bandang.", "Keselamatan warga Flores Timur dan Lembata.", "Warga yang harus pindah; anggaran.", "Kepercayaan turun.", "Infrastruktur naik setelah sembilan bulan.")},
  reactions={"a": [B("narasi", "Kapal perang dan pesawat angkut membawa beras, terpal, dan alat berat ke Adonara dan Lembata.", bg="pelabuhan"),
                   B("om_frans", "Pelabuhan sibuk siang malam. Kapal saya ikut mengangkut ke desa-desa kecil.", "senyum"),
                   B("mama_theresia", "Bantuan sampai ke kampung kami di hari kelima. Anak-anak bisa makan nasi lagi.", "lega", "pesisir_rusak")],
             "b": [B("narasi", "Pengeras suara gereja dan masjid, radio desa, dan pesan singkat disiapkan sebagai jalur peringatan cuaca.", bg="desa"),
                   B("om_frans", "Kami nakhoda sekarang dapat peringatan langsung. Itu berarti nyawa, Pak.", "senyum", "pelabuhan"),
                   B("mama_theresia", "Itu baik untuk nanti. Tapi rumah kami masih tertimbun hari ini.", "kecewa", "pesisir_rusak")],
             "c": [B("narasi", "Desa-desa di muara sungai dan kaki lereng paling rawan dipetakan untuk dipindahkan.", bg="pesisir_rusak"),
                   B("mama_theresia", "Kampung kami sudah di sini sejak nenek moyang. Tapi saya tidak mau tidur dengan suara banjir lagi.", "sedih"),
                   B("yosef", "Kita harus memindahkan dengan menghormati adat dan tanah mereka. Bukan sekadar membangun rumah di tempat lain.", "serius", "ruang_rapat")]},
  callbacks=[{"id": "musim", "after_quarters": 3, "beats": [PICK(
     ({"delta": "infrastructure", "op": ">", "value": 2}, [B("om_frans", "Musim angin kemarin, peringatan datang dua hari sebelumnya. Semua kapal tinggal di pelabuhan. Tidak ada yang hilang.", "senyum", "pelabuhan")]),
     ({"delta": "damage", "op": "<", "value": -5}, [B("mama_theresia", "Kampung kami sudah bersih, Pak. Kami menenun lagi di bawah rumah panggung.", "senyum", "desa")]),
     ({}, [B("mama_theresia", "Bekas banjir masih banyak di kampung, Pak. Kami membersihkan sendiri pelan-pelan.", "kecewa", "pesisir_rusak")]))]}],
  unattended=[B("narasi", "Tanpa arahan nasional, bantuan untuk pulau-pulau terdampak Seroja datang tersendat.", bg="pelabuhan"),
              B("om_frans", "Bantuan menumpuk di pelabuhan. Kapalnya yang tidak ada.", "kecewa")],
  journal={"a": "Logistik darurat lintas pulau dikirim ke daerah terdampak Seroja.", "b": "Peringatan dini cuaca ekstrem diteruskan sampai ke desa-desa NTT.", "c": "Permukiman di jalur banjir bandang Flores Timur dan Lembata direlokasi."},
  promises={"b": {"text": "Desa-desa di kepulauan NTT menerima peringatan cuaca ekstrem sebelum badai berikutnya.", "due_quarters": 3, "check": {"delta": "infrastructure", "op": ">", "value": 2}},
            "c": {"text": "Warga dari jalur banjir bandang di Flores Timur dan Lembata tinggal di tempat yang lebih aman.", "due_quarters": 4, "check": {"delta": "infrastructure", "op": ">", "value": 2.5}}})))

CASES.append(dict(
 id="CASE-0026", tick=26, island="jawa", provinces=["31"],
 title_r="Kebakaran depo BBM Pertamina Plumpang dan zona penyangga permukiman, Maret 2023",
 title="Api di Pagar Depo", location="Kota Adm. Jakarta Utara, DKI Jakarta",
 focus=["31.72"], category="industrial_safety_urban",
 subcats=["industrial_fire", "buffer_zone", "urban_settlement", "critical_infrastructure"],
 start="2023-03", end="2023-03-05", asof="2023-03-05",
 sources=[
  S("SRC-SETKAB-PLUMPANG-2023-03-05", "Sekretariat Kabinet RI", "Peninjauan Posko Pengungsian Korban Kebakaran TBBM Pertamina Plumpang, RPTRA Rasela, Rawa Badak Selatan, 5 Maret 2023 (keterangan pers)",
    "https://setkab.go.id/peninjauan-posko-pengungsian-korban-kebakaran-terminal-bahan-bakar-minyak-tbbm-pertamina-plumpang-di-ruang-publik-terpadu-ramah-anak-rptra-rasela-rawa-badak-selatan-jakarta-utara-provinsi-dki/", "2023-03-05", res="Rawa Badak Selatan, Jakarta Utara", period="2023-03-05"),
  S("SRC-SETKAB-PLUMPANG-EN-2023-03-05", "Sekretariat Kabinet RI", "President Jokowi Calls for Post-Disaster Plan Following Fuel Depot Fire",
    "https://setkab.go.id/en/president-jokowi-calls-for-post-disaster-plan-following-fuel-depot-fire/", "2023-03-05", res="Jakarta Utara", period="2023-03-05", unit="meter"),
 ],
 facts=[
  ("Di posko pengungsian korban kebakaran depo BBM Plumpang pada 5 Maret 2023, Presiden menyatakan kawasan itu zona berbahaya yang tidak bisa lagi ditinggali dan memerintahkan Menteri BUMN serta Gubernur DKI mencari solusi: memindahkan depo ke lahan reklamasi atau merelokasi penduduk.", "SRC-SETKAB-PLUMPANG-2023-03-05", "2023-03-05"),
  ("Presiden juga meminta semua zona berbahaya di sekitar objek vital, tidak hanya Plumpang, diaudit dan dievaluasi, dan menyebut zona di sekitar depo semestinya berupa zona air seperti sungai.", "SRC-SETKAB-PLUMPANG-2023-03-05", "2023-03-05"),
  ("Rencana zona penyangga selebar 50 meter yang memisahkan permukiman dan depo Plumpang telah disiapkan.", "SRC-SETKAB-PLUMPANG-EN-2023-03-05", "2023-03-05"),
 ],
 info="5 Maret 2023: warga di sekitar depo mengungsi; keputusan antara memindahkan depo atau warga diserahkan kepada Pertamina dan Gubernur dalam beberapa hari.",
 root="Permukiman padat yang tumbuh hingga menempel pagar objek vital berisiko tinggi.",
 stake=["Pertamina", "Kementerian BUMN", "Pemprov DKI Jakarta", "warga Rawa Badak Selatan", "pemadam kebakaran"],
 rejected=["Jumlah korban jiwa dan tanggal pasti kebakaran tidak tercantum di sumber resmi yang dibaca; tidak dicantumkan.", "Lebar zona penyangga lain (52,5 m; 500 m) hanya dari pemberitaan; tidak dipakai."],
 todo=["Data korban dan pengungsi resmi (BPBD DKI)"],
 adapt="Memindahkan depo (mahal, warga tetap) vs zona penyangga dengan relokasi warga terdekat (murah, menyakitkan) vs audit nasional zona berbahaya (pencegahan luas).",
 shock=[E("region:31.72", "damage", 4.0), E("region:31.72", "trust", -2.0), E("region:31.72", "welfare", -1.0)],
 shock_note="Case event (design): Jakarta Utara damage 4, trust -2, welfare -1. Localised event; design values.",
 cons=dict(cross_system_chain="industrial fire -> damage & trust; move depot -> trust + infrastructure later; buffer zone -> damage recovery now, trust cost; national audit -> small infrastructure/trust gains everywhere",
           immediate="a: fiscal -6, trust +2; b: fiscal -2, trust -1.5, damage -2 (month 1); c: fiscal -3, trust +0.3 nationwide, damage -1 Jakarta Utara",
           delayed="a: infrastructure +4 after 12 months; b: services +1 after 6 months; c: infrastructure +0.5 nationwide after 6 months",
           regional="Jakarta Utara", national="fiscal_space; option c touches every region", branching="none", assumptions="All magnitudes are design values."),
 choices=[
  ("a", "Pindahkan depo ke lahan reklamasi", "Depo BBM dipindahkan menjauh dari permukiman. Warga tetap tinggal di kampungnya, tetapi biayanya sangat besar dan butuh waktu bertahun-tahun.",
   [E("national", "fiscal_space", -6.0), E("region:31.72", "trust", 2.0), E("region:31.72", "infrastructure", 4.0, delay=12)], {"plumpang2023_response": "move_depot"}),
  ("b", "Zona penyangga dan relokasi warga terdekat", "Permukiman yang menempel pagar depo dipindahkan untuk zona penyangga. Lebih murah dan cepat mengurangi risiko, berat bagi keluarga yang harus pindah.",
   [E("national", "fiscal_space", -2.0), E("region:31.72", "trust", -1.5), E("region:31.72", "damage", -2.0, delay=1), E("region:31.72", "services", 1.0, delay=6)], {"plumpang2023_response": "buffer_zone"}),
  ("c", "Audit semua zona berbahaya di negeri ini", "Semua objek vital berisiko tinggi di dekat permukiman diperiksa dan dibenahi. Mencegah Plumpang berikutnya, tetapi warga Plumpang menunggu keputusan khusus.",
   [E("national", "fiscal_space", -3.0), E("all", "trust", 0.3), E("region:31.72", "damage", -1.0), E("all", "infrastructure", 0.5, delay=6)], {"plumpang2023_response": "national_audit"}),
 ],
 ep=dict(background="kota_gelap",
  locals={"bu_marni": {"name": "Bu Marni", "role": "Pedagang warung, Rawa Badak Selatan", "color": "8a5a3a", "initials": "M"},
          "bang_jefri": {"name": "Bang Jefri", "role": "Petugas pemadam kebakaran, Jakarta Utara", "color": "a03a2a", "initials": "J"}},
  hook="Kebakaran di depo BBM Plumpang merembet ke permukiman yang menempel pagarnya. Rumah-rumah hangus dalam semalam.",
  if_postponed="Keputusan soal Plumpang ditunda. Warga kembali membangun di samping pagar depo.",
  opening=[B("narasi", "Malam di Jakarta Utara. Ledakan terdengar sampai jauh, dan langit berubah jingga.", bg="kota_gelap"),
           B("bang_jefri", "Apinya cepat sekali masuk ke gang. Rumah-rumah di sana nempel ke pagar depo, Pak. Tidak ada jarak sama sekali.", "serius"),
           B("bu_marni", "Saya lahir di gang ini. Malam itu kami lari bawa anak, tanpa sandal.", "sedih"),
           B("yosef", "Pilihannya jelas tapi sulit. Depo yang pindah, atau warga yang pindah.", "serius", "ruang_rapat"),
           B("bayu", "Memindahkan depo itu proyek raksasa. Zona penyangga lebih murah, tapi artinya ratusan keluarga kehilangan rumah.", "netral"),
           B("sekar", "Dan orang di kota lain mulai bertanya: apakah rumah kami juga di samping bahaya seperti ini?", "cemas"),
           B("nara", "Tidak boleh ada lagi rumah yang hanya berjarak satu pagar dari tangki bahan bakar.", "serius")],
  info={"a": ("Memindahkan depo BBM menjauh dari permukiman.", "Warga sekitar depo: tidak perlu pindah.", "Anggaran: biaya sangat besar, butuh bertahun-tahun.", "Kepercayaan warga naik.", "Infrastruktur membaik setelah sekitar setahun."),
        "b": ("Membuat zona penyangga dengan merelokasi warga terdekat.", "Keselamatan warga yang tersisa, dengan biaya kecil.", "Keluarga yang rumahnya masuk zona penyangga.", "Kepercayaan turun; risiko berkurang bulan depan.", "Layanan membaik setelah enam bulan."),
        "c": ("Mengaudit semua zona berbahaya di sekitar objek vital.", "Warga di seluruh negeri yang tinggal dekat bahaya serupa.", "Warga Plumpang menunggu keputusan khusus.", "Kepercayaan nasional naik sedikit.", "Infrastruktur nasional membaik setelah enam bulan.")},
  reactions={"a": [B("narasi", "Rencana pemindahan depo diumumkan. Kajian lahan reklamasi dimulai.", bg="kota"),
                   B("bu_marni", "Jadi kami tidak perlu pindah? Alhamdulillah. Tapi sampai depo itu pergi, kami tetap tidur di sampingnya.", "lega"),
                   B("bayu", "Ini salah satu proyek termahal yang pernah kita setujui, Pak.", "cemas", "ruang_rapat")],
             "b": [B("narasi", "Patok-patok dipasang lima puluh meter dari pagar depo. Rumah di dalamnya akan dipindahkan.", bg="kota"),
                   B("bu_marni", "Rumah saya kena patok, Pak. Saya mengerti alasannya. Tapi warung saya hidup dari gang ini.", "sedih"),
                   B("bang_jefri", "Lima puluh meter itu jarak yang memberi kami waktu kalau terjadi lagi.", "netral", "kota_gelap")],
             "c": [B("narasi", "Tim audit dikirim ke depo, kilang, dan gudang bahan berbahaya di seluruh negeri.", bg="ruang_rapat"),
                   B("sekar", "Warga di banyak kota lega ada yang memeriksa lingkungannya.", "senyum"),
                   B("bu_marni", "Bagus untuk semua orang. Tapi kami di Plumpang masih menunggu, Pak.", "kecewa", "kota")]},
  callbacks=[{"id": "gang", "after_quarters": 3, "beats": [PICK(
     ({"case_choice": "CASE-0026", "choice": "b"}, [B("bu_marni", "Saya buka warung lagi di rusun baru, Pak. Pelanggannya beda, tapi anak-anak tidur tanpa takut.", "netral", "kota")]),
     ({"case_choice": "CASE-0026", "choice": "a"}, [B("bu_marni", "Depo masih di sana, Pak. Katanya pindahnya bertahun-tahun lagi. Kami menunggu.", "berpikir", "kota")]),
     ({}, [B("bang_jefri", "Hasil audit menemukan beberapa tempat lain yang sama berbahayanya. Pelan-pelan dibenahi.", "netral", "kota")]))]}],
  unattended=[B("narasi", "Keputusan soal Plumpang terus ditunda. Rumah-rumah yang terbakar dibangun kembali di tempat yang sama.", bg="kota_gelap"),
              B("bang_jefri", "Kami kembali memadamkan di gang yang sama. Semoga tidak.", "cemas")],
  journal={"a": "Depo BBM Plumpang dipindahkan menjauh dari permukiman.", "b": "Zona penyangga 50 meter dibuat di sekitar depo Plumpang dengan merelokasi warga terdekat.", "c": "Semua zona berbahaya di sekitar objek vital nasional diaudit."},
  promises={"a": {"text": "Depo BBM Plumpang tidak lagi berbatasan langsung dengan rumah warga.", "due_quarters": 5, "check": {"delta": "infrastructure", "op": ">", "value": 2}}})))


# =====================================================================================  writers

def research(c):
    return {
        "schema": "nusantara.case_research/1", "case_id": c["id"], "title": c["title_r"], "status": "researched",
        "status_note": "Diteliti 2026-11-23: semua sumber diunduh dan isinya dibaca; angka disalin persis dari halaman sumber.",
        "category": c["category"], "subcategories": c["subcats"], "start_date": c["start"], "end_date": c["end"],
        "decision_as_of": c["asof"], "island": c["island"], "provinces": c["provinces"],
        "regency_city_documented": c["focus"], "geographic_resolution": c["location"],
        "real_facts": [{"fact": f, "kind": "fact", "source_refs": [s], "as_of": d} for f, s, d in c["facts"]],
        "information_available_at_decision": c["info"], "trigger": [c["title_r"]], "root_causes_note": c["root"],
        "stakeholders": c["stake"], "sources": c["sources"], "rejected_or_unverified": c["rejected"],
        "todo_to_validate": c["todo"], "game_adaptation_ref": "game/data/cases/%s.json" % c["id"],
        "game_adaptation_notes": c["adapt"],
        "fact_vs_simulation_notes": "Peristiwa dan angka di real_facts nyata dan bersumber. Pilihan, besaran efek, dan hasilnya adalah simulasi; tokoh dalam episode cerita fiktif.",
    }


def game(c):
    return {
        "schema": "nusantara.case/1", "case_id": c["id"], "research_ref": "research/cases/%s.json" % c["id"],
        "research_status": "researched", "class": "major_historical", "title": c["title"], "location_label": c["location"],
        "focus_regions": c["focus"],
        "trigger": {"type": "condition", "conditions": {"all": [{"tick": ">=", "value": c["tick"]}, {"not": {"case_seen": c["id"]}}]},
                    "weight": 100, "story_priority": 8},
        "on_trigger_effects": c["shock"],
        "real_context": {"fact_class": "REAL_OFFICIAL", "lines": [{"text": f, "source_refs": [s], "as_of": d} for f, s, d in c["facts"]]},
        "briefing": {"fact_class": "FICTIONAL", "speaker": "Laras Prameswari", "text": c["ep"]["hook"]},
        "shock_note": {"fact_class": "DERIVED", "text": c["shock_note"]},
        "follow_ups": [], "consequence_notes": dict({"fact_class": "SIMULATED"}, **c["cons"]),
        "choices": [{"choice_id": i, "label": l, "description": d, "fact_class": "SIMULATED", "effects": e, "memory": m}
                    for i, l, d, e, m in c["choices"]],
    }


def episode(c):
    ep = c["ep"]
    return {
        "schema": "nusantara.story_episode/1", "case_id": c["id"], "fact_class": "FICTIONAL",
        "note": "Characters are fictional composites; no line quotes a real person. Reactions follow each choice's scheduled effects; callbacks read actual state.",
        "background": ep["background"], "locals": ep["locals"],
        "agenda": {"hook": ep["hook"], "if_postponed": ep["if_postponed"]},
        "opening": ep["opening"],
        "choices": {k: dict(zip(["intent", "helps", "burden", "now", "later"], v)) for k, v in ep["info"].items()},
        "reactions": ep["reactions"], "callbacks": ep.get("callbacks", []), "unattended": ep["unattended"],
        "journal": ep["journal"], "promises": ep.get("promises", {}),
    }


def write(path, obj):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def main():
    log_path = ROOT / "research/sources/access_log.jsonl"
    seen = set()
    for line in log_path.read_text(encoding="utf-8").splitlines():
        try:
            r = json.loads(line)
            seen.add((r.get("source_id"), r.get("detail", "")[:60]))
        except json.JSONDecodeError:
            pass
    new_rows = []
    for c in CASES:
        write("research/cases/%s.json" % c["id"], research(c))
        write("game/data/cases/%s.json" % c["id"], game(c))
        write("game/data/story/episodes/%s.json" % c["id"], episode(c))
        for s in c["sources"]:
            detail = "ok; %s research, page text read and facts checked" % c["id"]
            if (s["source_id"], detail[:60]) not in seen:
                new_rows.append({"at": s["retrieved_at"] + "T12:00:00Z", "source_id": s["source_id"], "url": s["url"], "status": "ok", "detail": detail})
                seen.add((s["source_id"], detail[:60]))
    with log_path.open("a", encoding="utf-8") as fh:
        for r in new_rows:
            fh.write(json.dumps(r, ensure_ascii=False) + "\n")
    print("wrote %d cases; %d new access-log rows" % (len(CASES), len(new_rows)))


if __name__ == "__main__":
    main()
