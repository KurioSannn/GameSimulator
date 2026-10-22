class_name BudgetPanel
extends PanelContainer
## National budget allocation (SIMULATED state). Shows sector shares relative to the DERIVED
## baseline and the spending level. Real APBN rupiah are shown only when budget.json carries a
## REAL_OFFICIAL pool; otherwise values are relative and labeled as uncalibrated.

var _level: HSlider
var _level_label: Label
var _spins: Dictionary = {}
var _total: Label
var _msg: Label
var _ledger: Label


func _ready() -> void:
	custom_minimum_size = Vector2(420, 0)
	var box := UiKit.vbox(8)
	add_child(box)
	var head := UiKit.hbox()
	var title := UiKit.label("Anggaran Nasional", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	box.add_child(head)
	var cfg: Dictionary = ContentDB.budget
	if str(cfg.get("pool_status", "")) == "REAL_OFFICIAL":
		box.add_child(UiKit.tag("NYATA · APBN %s: %s" % [cfg.pool_reference_period, Fmt.rupiah(float(cfg.pool_rp))], UiKit.REAL))
	else:
		box.add_child(UiKit.tag("BELUM TERKALIBRASI · porsi dasar netral, APBN 2026 belum dimuat", UiKit.WARN))
	box.add_child(UiKit.label("Tingkat belanja (relatif terhadap dasar). Di atas 100% menggerus ruang fiskal tiap bulan.", 12, UiKit.MUTED, true))
	var lrow := UiKit.hbox()
	_level = HSlider.new()
	_level.min_value = float(cfg.get("level_min", 0.8))
	_level.max_value = float(cfg.get("level_max", 1.2))
	_level.step = 0.05
	_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level.value_changed.connect(func(_v): _update_labels())
	lrow.add_child(_level)
	_level_label = UiKit.label("", 15)
	lrow.add_child(_level_label)
	box.add_child(lrow)
	box.add_child(UiKit.label("Porsi sektor (%), total harus 100:", 14))
	for sid in cfg.get("sectors", {}):
		var s: Dictionary = cfg.sectors[sid]
		var row := UiKit.hbox()
		var name := UiKit.label("%s (dasar %s%%)" % [s.label, Fmt.num(float(s.base_share), 0)], 14)
		name.custom_minimum_size.x = 260
		row.add_child(name)
		var sp := SpinBox.new()
		sp.min_value = 0
		sp.max_value = 100
		sp.step = 1
		sp.value_changed.connect(func(_v): _update_labels())
		row.add_child(sp)
		_spins[sid] = sp
		box.add_child(row)
	_total = UiKit.label("", 14)
	box.add_child(_total)
	var apply := Button.new()
	apply.text = "Terapkan"
	apply.pressed.connect(_apply)
	box.add_child(apply)
	_msg = UiKit.label("", 13, UiKit.ACCENT, true)
	box.add_child(_msg)
	_ledger = UiKit.label("", 12, UiKit.MUTED, true)
	box.add_child(_ledger)
	title.tooltip_text = "Efek per bulan: Infrastruktur → infrastruktur; Kebencanaan → proteksi banjir di wilayah terpapar + pemulihan; Layanan → layanan publik; Pangan → kapasitas pangan. Koefisien adalah model permainan (TURUNAN), bukan data resmi."
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open() -> void:
	var n: Dictionary = Game.world.national
	_level.value = float(n.get("budget_level", 1.0))
	for sid in _spins:
		_spins[sid].value = float(n.get("budget_shares", {}).get(sid, 0.0))
	_msg.text = ""
	var f: Dictionary = Game.sim.fiscal_report(Game.world)
	_ledger.text = "Neraca bulanan (unit fiskal relatif, 100 = anggaran program dasar setahun; BELUM TERKALIBRASI): pendapatan %s · program sektor %s · komitmen kebijakan %s (%s%%) · saldo %s" % [
		Fmt.num(f.revenue, 2), Fmt.num(f.programs, 2), Fmt.num(f.policies, 2), Fmt.num(f.commitment_share * 100.0, 0), Fmt.signed(f.balance, 2)]
	_update_labels()
	visible = true


func _update_labels() -> void:
	_level_label.text = "%s%%" % Fmt.num(_level.value * 100.0, 0)
	var total := 0.0
	for sid in _spins:
		total += float(_spins[sid].value)
	_total.text = "Total: %s%%" % Fmt.num(total, 0)
	_total.add_theme_color_override("font_color", UiKit.TEXT if absf(total - 100.0) < 0.01 else UiKit.WARN)


func _apply() -> void:
	var shares := {}
	for sid in _spins:
		shares[sid] = float(_spins[sid].value)
	var err := Game.set_budget(_level.value, shares)
	_msg.text = err if err != "" else "Anggaran diterapkan mulai bulan berikutnya."
