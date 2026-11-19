class_name BudgetPanel
extends PanelContainer
## Clean national budget allocation modal (SIMULATED state).
## Keeps exact relative sector shares and fiscal ledger readout without clutter.

var _level: HSlider
var _level_label: Label
var _spins: Dictionary = {}
var _bars: Dictionary = {}
var _total_pill: Label
var _msg: Label
var _ledger_vals: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(680, 0)
	add_theme_stylebox_override("panel", StitchTheme.box(StitchTheme.color("surface"), StitchTheme.color("outline"), 4, 14, 20, 18))
	var box := UiKit.vbox(14)
	add_child(box)

	box.add_child(UiKit.modal_header(
		"KEUANGAN NEGARA",
		"ANGGARAN NASIONAL",
		func(): visible = false,
		"",
		UiKit.WARN,
		"✕",
		"Tutup panel anggaran (Esc / B)"
	))

	var cfg: Dictionary = ContentDB.budget
	if str(cfg.get("pool_status", "")) == "REAL_OFFICIAL":
		box.add_child(UiKit.tag("NYATA · APBN %s: %s" % [cfg.pool_reference_period, Fmt.rupiah(float(cfg.pool_rp))], UiKit.REAL))
	else:
		var bt := UiKit.tag("ⓘ Mode simulasi · APBN 2026 belum terkalibrasi", UiKit.INFO, 11)
		bt.tooltip_text = "Porsi dasar sektor masih netral dalam poin simulasi."
		bt.mouse_filter = Control.MOUSE_FILTER_STOP
		box.add_child(bt)

	# Spending level card
	var lvl_card := PanelContainer.new()
	lvl_card.theme_type_variation = "PanelCard"
	var lv := UiKit.vbox(8)
	lvl_card.add_child(lv)
	var ltop := UiKit.hbox(10)
	var ltitle := UiKit.title("1. TINGKAT BELANJA NEGARA", 16, UiKit.ACCENT)
	ltitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ltitle.tooltip_text = "Efek per bulan: Infrastruktur -> infrastruktur; Kebencanaan -> proteksi banjir + pemulihan; Layanan -> layanan publik; Pangan -> kapasitas pangan."
	ltitle.mouse_filter = Control.MOUSE_FILTER_STOP
	ltop.add_child(ltitle)
	_level_label = UiKit.title("100%", 20, UiKit.ACCENT)
	ltop.add_child(_level_label)
	lv.add_child(ltop)
	lv.add_child(UiKit.label("100% = belanja standar. Melebihi 100% mengurangi cadangan anggaran tiap bulan.", 13, UiKit.MUTED, true))
	_level = HSlider.new()
	_level.min_value = float(cfg.get("level_min", 0.8))
	_level.max_value = float(cfg.get("level_max", 1.2))
	_level.step = 0.05
	_level.value_changed.connect(func(_v): _update_labels())
	lv.add_child(_level)
	box.add_child(lvl_card)

	# Sector allocation card
	var sec_card := PanelContainer.new()
	sec_card.theme_type_variation = "PanelCard"
	var sv := UiKit.vbox(10)
	sec_card.add_child(sv)
	var stop := UiKit.hbox(10)
	var stitle := UiKit.title("2. PORSI TIAP SEKTOR", 16, UiKit.ACCENT)
	stitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stop.add_child(stitle)
	_total_pill = UiKit.title("Total: 100%", 15, UiKit.SUCCESS)
	stop.add_child(_total_pill)
	sv.add_child(stop)
	sv.add_child(UiKit.subheader("BAGIKAN TOTAL 100% KE EMPAT BIDANG UTAMA", UiKit.MUTED, 11))

	for sid in cfg.get("sectors", {}):
		var s: Dictionary = cfg.sectors[sid]
		var row := UiKit.hbox(12)
		var name := UiKit.label("%s (dasar %s%%)" % [s.label, Fmt.num(float(s.base_share), 0)], 14, UiKit.TEXT)
		name.custom_minimum_size.x = 240
		row.add_child(name)
		var pb := ProgressBar.new()
		pb.min_value = 0
		pb.max_value = 100
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(180, 10)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pb)
		_bars[sid] = pb
		var sp := SpinBox.new()
		sp.min_value = 0
		sp.max_value = 100
		sp.step = 1
		sp.suffix = "%"
		sp.custom_minimum_size.x = 96
		sp.value_changed.connect(func(val): pb.value = val; _update_labels())
		row.add_child(sp)
		_spins[sid] = sp
		sv.add_child(row)
	box.add_child(sec_card)

	# Structured 4-column Fiscal Ledger strip
	var led_card := PanelContainer.new()
	led_card.theme_type_variation = "PanelCard"
	var led_box := UiKit.vbox(8)
	led_card.add_child(led_box)
	led_box.add_child(UiKit.title("3. RINGKASAN KAS BULANAN", 15, UiKit.ACCENT))
	led_box.add_child(UiKit.subheader("ARUS POIN ANGGARAN SETIAP BULAN", UiKit.MUTED, 11))
	var lgrid := UiKit.hbox(10)
	for spec in [["revenue", "Pemasukan"], ["programs", "Belanja Sektor"], ["policies", "Biaya Kebijakan"], ["balance", "Selisih Kas"]]:
		var cell := UiKit.vbox(2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(UiKit.label(spec[1], 12, UiKit.MUTED))
		var vlbl := UiKit.title("0,0", 18)
		cell.add_child(vlbl)
		_ledger_vals[spec[0]] = vlbl
		lgrid.add_child(cell)
	led_box.add_child(lgrid)
	box.add_child(led_card)

	var foot := UiKit.hbox(12)
	var reset := UiKit.ghost_button("Reset ke Dasar", _reset_to_base, "Kembalikan ke porsi dasar 100%")
	reset.custom_minimum_size.y = 44
	foot.add_child(reset)
	_msg = UiKit.label("", 13, UiKit.ACCENT, true)
	_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_msg)
	var apply := UiKit.button("TERAPKAN ANGGARAN", _apply, true)
	apply.custom_minimum_size = Vector2(220, 46)
	foot.add_child(apply)
	box.add_child(foot)
	visible = false


func open() -> void:
	var n: Dictionary = Game.world.national
	_level.value = float(n.get("budget_level", 1.0))
	for sid in _spins:
		var v := float(n.get("budget_shares", {}).get(sid, 0.0))
		_spins[sid].value = v
		_bars[sid].value = v
	_msg.text = ""
	var f: Dictionary = Game.sim.fiscal_report(Game.world)
	_ledger_vals["revenue"].text = Fmt.num(f.revenue, 2)
	_ledger_vals["programs"].text = Fmt.num(f.programs, 2)
	_ledger_vals["policies"].text = "%s (%s%%)" % [Fmt.num(f.policies, 2), Fmt.num(f.commitment_share * 100.0, 0)]
	_ledger_vals["balance"].text = Fmt.signed(f.balance, 2)
	_ledger_vals["balance"].add_theme_color_override("font_color", UiKit.SUCCESS if f.balance >= 0.0 else UiKit.DANGER)
	_update_labels()
	visible = true
	UiKit.animate_open(self)


func _reset_to_base() -> void:
	_level.value = 1.0
	var sectors: Dictionary = ContentDB.budget.get("sectors", {})
	for sid in _spins:
		var base := float(sectors.get(sid, {}).get("base_share", 25.0))
		_spins[sid].value = base
		_bars[sid].value = base
	_update_labels()


func _update_labels() -> void:
	_level_label.text = "%s%%" % Fmt.num(_level.value * 100.0, 0)
	var total := 0.0
	for sid in _spins:
		total += float(_spins[sid].value)
	_total_pill.text = "Total: %s%%" % Fmt.num(total, 0)
	_total_pill.add_theme_color_override("font_color", UiKit.SUCCESS if absf(total - 100.0) < 0.01 else UiKit.DANGER)


func _apply() -> void:
	var shares := {}
	for sid in _spins:
		shares[sid] = float(_spins[sid].value)
	var err := Game.set_budget(_level.value, shares)
	_msg.text = err if err != "" else "Anggaran diterapkan mulai bulan berikutnya."
	_msg.add_theme_color_override("font_color", UiKit.DANGER if err != "" else UiKit.SUCCESS)
