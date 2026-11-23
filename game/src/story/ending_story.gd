class_name EndingStory
extends RefCounted
## The presidential legacy sequence (GDD "Akhir Masa Bakti"), written from what actually happened in
## this term: the provinces that improved most and those still struggling, the decisions whose regions
## changed most since the decision, promises kept and broken, the agenda the president left to others,
## and each adviser's verdict on the pillar they care about. Pure functions over state: no UI, testable.
##
## Sequence: final address -> map overview of Indonesia -> voices from the regions -> the cabinet's
## reactions -> (archetype scene, title and closing from endings.json, appended by Main).

const ADVISER_PILLAR := {"bayu": "fiscal", "sekar": "trust", "yosef": "services", "laras": "promises"}


## Everything the retrospective needs, computed from the session.
static func retrospective(session: Session) -> Dictionary:
	var w := session.world
	var s := Narrative.ensure(w)
	# per-province change in welfare and services since the start of the term
	var acc := {}
	var w0: PackedFloat64Array = session.initial_vars.get("welfare", PackedFloat64Array())
	var s0: PackedFloat64Array = session.initial_vars.get("services", PackedFloat64Array())
	var wn: PackedFloat64Array = w.vars.get("welfare", PackedFloat64Array())
	var sn: PackedFloat64Array = w.vars.get("services", PackedFloat64Array())
	for id in w.region_index:
		var i: int = w.region_index[id]
		if i >= w0.size() or i >= wn.size():
			continue
		var p := str(id).substr(0, 2)
		if not acc.has(p):
			acc[p] = {"sum": 0.0, "n": 0}
		acc[p].sum += (wn[i] - w0[i]) + 0.5 * ((sn[i] - s0[i]) if i < s0.size() and i < sn.size() else 0.0)
		acc[p].n += 1
	var provs: Array = []
	for p in acc:
		provs.append({"id": p, "name": province_name(p), "change": float(acc[p].sum) / maxi(1, int(acc[p].n))})
	provs.sort_custom(func(a, b): return a.change > b.change)
	var best: Array = provs.slice(0, mini(2, provs.size()))
	var worst: Array = provs.slice(maxi(0, provs.size() - 2))
	worst.reverse()
	# decisions whose focus regions changed most since the decision
	var defining: Array = []
	for cid in s.snapshots:
		var rec: Dictionary = session.cases.cases.get(cid, {})
		if rec.is_empty():
			continue
		var before: Dictionary = s.snapshots[cid]
		var now := Narrative.focus_means(w, rec)
		var d := 0.0
		for v in ["welfare", "services", "trust"]:
			d += float(now.get(v, 0.0)) - float(before.get(v, 0.0))
		var ch := str(w.case_state.get(cid, {}).get("choice_id", ""))
		var label := ""
		for c in rec.get("choices", []):
			if str(c.choice_id) == ch:
				label = str(c.label)
		var locals: Dictionary = rec.get("story", {}).get("locals", {})
		defining.append({"case": cid, "title": str(rec.get("title", cid)), "choice": ch, "label": label,
			"location": str(rec.get("location_label", "")), "change": d,
			"local": str(locals.keys()[0]) if not locals.is_empty() else ""})
	defining.sort_custom(func(a, b): return absf(a.change) > absf(b.change))
	var kept := 0
	var broken := 0
	for pid in s.promises:
		match str(s.promises[pid].status):
			"kept": kept += 1
			"broken": broken += 1
	return {"best": best, "worst": worst, "defining": defining.slice(0, mini(3, defining.size())),
		"kept": kept, "broken": broken, "outcomes": Campaign.outcome_counts(w),
		"priority": str(s.flags.get("prioritas_awal", ""))}


static func province_name(code: String) -> String:
	var p: Dictionary = ContentDB.province_by_id.get(code, {})
	return str(p.get("name", "provinsi " + code))


static func _b(s: String, t: String, e := "netral", bg := "") -> Dictionary:
	var d := {"s": s, "t": t, "e": e}
	if bg != "":
		d["bg"] = bg
	return d


static func _names(rows: Array) -> String:
	var n: Array = rows.map(func(r): return str(r.name))
	if n.size() == 2:
		return "%s dan %s" % n
	return ", ".join(n)


## Beats for the legacy sequence, before the archetype scene.
static func build_beats(session: Session, ev: Dictionary) -> Array:
	var r := retrospective(session)
	var ratings: Dictionary = ev.get("ratings", {})
	var f: Dictionary = ev.get("features", {})
	var out: Array = []
	# 1. Final address
	out.append(_b("narasi", "Hari terakhir masa bakti. Halaman Istana penuh wartawan, pegawai, dan warga yang datang dari jauh.", "netral", "istana_siang"))
	out.append(_b("laras", "Pidatonya sudah siap, Pak. Tapi saya rasa Bapak akan bicara dari ingatan saja.", "senyum"))
	out.append(_b("nara", "Lima tahun lalu saya berdiri di sini tanpa tahu krisis apa yang akan datang. Hari ini saya tahu namanya satu per satu.", "serius"))
	var prio := str(r.priority)
	if prio != "":
		var said := {"welfare": "kehidupan warga sehari-hari", "trust": "kepercayaan Saudara-saudara",
			"services": "layanan yang benar-benar sampai ke desa", "fiscal": "keuangan negara yang sehat"}
		var rate := str(ratings.get(prio, "fair"))
		var line := "Di hari pertama saya berjanji mendahulukan %s. " % said.get(prio, prio)
		line += "Saya rasa janji itu kami jaga." if rate == "good" else "Saya akui, hasilnya belum sebaik yang saya harapkan." if rate == "poor" else "Sebagian berhasil, sebagian masih harus diteruskan."
		out.append(_b("nara", line, "berpikir"))
	if not (r.defining as Array).is_empty():
		var d0: Dictionary = r.defining[0]
		out.append(_b("nara", "Keputusan yang paling saya ingat adalah %s. Kami memilih: %s." % [str(d0.title), str(d0.label).to_lower()], "serius"))
	if int(r.kept) + int(r.broken) > 0:
		if int(r.broken) == 0:
			out.append(_b("nara", "Setiap janji jangka panjang yang kami buat, kami tepati. Itu bukan karena mudah.", "yakin"))
		elif int(r.kept) == 0:
			out.append(_b("nara", "Ada janji yang tidak sempat kami tepati. Saya tidak akan berpura-pura sebaliknya.", "sedih"))
		else:
			out.append(_b("nara", "%d janji kami tepati, %d belum. Yang belum, saya titipkan kepada pemerintahan berikutnya." % [int(r.kept), int(r.broken)], "berpikir"))
	out.append(_b("nara", "Terima kasih telah mengingatkan kami setiap kali kami lupa untuk siapa kami bekerja.", "senyum"))
	# 2. Map overview
	out.append(_b("narasi", "Malam itu, peta Nusantara dibentangkan untuk terakhir kalinya. Lima ratus empat belas wilayah, masing-masing dengan ceritanya sendiri.", "netral", "peta"))
	if not (r.best as Array).is_empty():
		out.append(_b("narasi", "Yang paling banyak berubah ke arah lebih baik: %s." % _names(r.best)))
	if not (r.worst as Array).is_empty():
		out.append(_b("narasi", "Yang masih berjuang paling berat: %s. Pekerjaan di sana belum selesai." % _names(r.worst)))
	var missed := int(f.get("missed_critical", 0))
	var delegated := int((r.outcomes as Dictionary).get(Campaign.OUTCOME_DELEGATED, 0))
	if missed > 0:
		out.append(_b("narasi", "%d krisis besar terlewat tanpa keputusan Presiden. Di daerah-daerah itu, orang masih membicarakannya." % missed))
	elif delegated > 0:
		out.append(_b("narasi", "Tidak satu pun krisis besar dibiarkan tanpa keputusan. %d urusan lain diserahkan kepada kementerian dengan sengaja." % delegated))
	# 3. Voices from the regions (fictional locals from the decisions that changed their places most)
	for d in (r.defining as Array).slice(0, 2):
		if str(d.local) == "":
			continue
		var better := float(d.change) > 0.0
		var place := str(d.location).split(",")[0]
		var t := ("Pak Presiden, sejak keputusan soal %s, hidup kami di %s pelan-pelan membaik. Kami tidak lupa." % [str(d.title).to_lower(), place]) if better \
			else ("Pak, sejak %s, keadaan di %s belum juga pulih. Semoga yang berikutnya datang lebih cepat." % [str(d.title).to_lower(), place])
		out.append({"s": str(d.local), "t": t, "e": "senyum" if better else "kecewa", "case": str(d.case)})
	# 4. The cabinet's reactions, each on the pillar they care about
	out.append(_b("narasi", "Di ruang rapat yang mulai dikosongkan, para penasihat berkumpul sekali lagi.", "netral", "ruang_rapat"))
	var fr := str(ratings.get("fiscal", "fair"))
	out.append(_b("bayu", "Kas negara masih kuat, Pak. Pemerintahan berikutnya punya ruang untuk bergerak." if fr == "good" else "Kas kita tipis sekali. Pemerintahan berikutnya mewarisi tagihan, bukan tabungan." if fr == "poor" else "Neraca kita tidak indah, tapi masih bisa dipertanggungjawabkan.", "senyum" if fr == "good" else "cemas" if fr == "poor" else "netral"))
	var tr := str(ratings.get("trust", "fair"))
	out.append(_b("sekar", "Orang masih percaya pada kita. Bukan karena kita selalu benar, tapi karena kita tidak menghilang." if tr == "good" else "Kepercayaan itu terkikis, Pak. Orang merasa sering ditinggal." if tr == "poor" else "Orang tidak selalu setuju dengan kita. Tapi kebanyakan masih mau mendengar.", "senyum" if tr == "good" else "sedih" if tr == "poor" else "netral"))
	var sr := str(ratings.get("services", "fair"))
	out.append(_b("yosef", "Puskesmas, jembatan, sekolah. Di banyak daerah, layanan sekarang benar-benar sampai." if sr == "good" else "Masih banyak desa yang harus menempuh jalan jauh untuk layanan dasar. Itu yang paling mengganjal buat saya." if sr == "poor" else "Ada daerah yang jauh lebih baik. Ada yang masih menunggu giliran.", "senyum" if sr == "good" else "kecewa" if sr == "poor" else "berpikir"))
	var lr := "Semua janji tercatat lengkap, Pak. Yang ditepati dan yang belum." if int(r.kept) + int(r.broken) > 0 else "Catatan lima tahun ini sudah saya rapikan, Pak. Semuanya."
	out.append(_b("laras", lr, "senyum"))
	return out
