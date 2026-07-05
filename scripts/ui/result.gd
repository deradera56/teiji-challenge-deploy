extends Control
## 退社リザルト画面。1日の成績と報酬を表示し、次の行動へ誘導する。


func _ready() -> void:
	UiTheme.fill_bg(self)
	var r: Dictionary = Meta.last_result

	# 実績解除演出などで内容が長くなっても必ず下のボタンまで届くようスクロール可能にする
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var vb := UiTheme.make_margin_vbox(scroll, 44, 16)

	vb.add_child(UiTheme.vspace(12))

	var teiji := String(r.get("reason", "")) == "teiji"
	var outcome := UiTheme.make_label(String(r.get("outcome", "退社")), 42,
			UiTheme.GOOD if teiji else UiTheme.WARN, true)
	outcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(outcome)

	var day_l := UiTheme.make_label("Day %d｜%s" % [int(r.get("day", 1)), String(r.get("company", ""))],
			24, UiTheme.TEXT_DIM)
	day_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(day_l)

	# 日次評価グレード
	var grade := String(r.get("grade", "C"))
	var grade_colors: Dictionary = {
		"S": UiTheme.WARN, "A": UiTheme.GOOD, "B": UiTheme.ACCENT,
		"C": UiTheme.TEXT_DIM, "D": UiTheme.BAD,
	}
	var grade_l := UiTheme.make_label("評価 %s" % grade, 60, grade_colors.get(grade, UiTheme.TEXT_DIM))
	grade_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(grade_l)
	if bool(r.get("perfect", false)):
		var p := UiTheme.make_label("💮 パーフェクトデー！（失敗ゼロで定時退社）", 25, UiTheme.WARN)
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(p)

	# レベルアップ演出（プレイヤーレベルが上がった日は一番目立たせる）
	if bool(r.get("level_up", false)):
		vb.add_child(UiTheme.vspace(6))
		var lvup := UiTheme.make_panel(UiTheme.WARN, 16)
		vb.add_child(lvup)
		var lvup_l := UiTheme.make_label(
			"🆙 プレイヤーレベルアップ！ Lv%d → Lv%d" % [int(r.get("level_before", 0)), int(r.get("level_after", 0))],
			26, UiTheme.TEXT_MAIN)
		lvup_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lvup.add_child(lvup_l)

	vb.add_child(UiTheme.vspace(10))

	# 成績パネル
	var stats := UiTheme.make_panel(UiTheme.PANEL, 16)
	vb.add_child(stats)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	stats.add_child(sv)
	_add_row(sv, "✅ 処理したタスク", "%d件" % int(r.get("tasks_done", 0)))
	_add_row(sv, "💥 期限切れ", "%d件" % int(r.get("tasks_failed", 0)))
	_add_row(sv, "🙅 断ったタスク", "%d件" % int(r.get("tasks_refused", 0)))
	_add_row(sv, "⚡ 最大コンボ", "x%d" % int(r.get("combo_max", 0)))
	if int(r.get("overtime_min", 0)) > 0:
		_add_row(sv, "🌙 残業時間", "%d分" % int(r.get("overtime_min", 0)))
	_add_row(sv, "🧠 集中 / 🔥 やる気 / 🤝 信用",
			"%d / %d / %d" % [int(r.get("focus", 0)), int(r.get("motivation", 0)), int(r.get("trust", 0))])

	# 熟練度（やり込みの証）
	var levels := PackedStringArray()
	for cat in Meta.CATEGORY_NAMES:
		var lv := Meta.mastery_level(String(cat))
		if lv > 0:
			levels.append("%s Lv%d" % [Meta.category_name(String(cat)), lv])
	if levels.size() > 0:
		var m := UiTheme.make_label("🎓 熟練度：" + "・".join(levels), 21, UiTheme.TEXT_DIM, true)
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(m)

	# 実績解除パネル（新規解除があるときだけ表示）
	var new_achievements: Array = r.get("new_achievements", [])
	if new_achievements.size() > 0:
		vb.add_child(UiTheme.vspace(6))
		var ach_panel := UiTheme.make_panel(UiTheme.AI_COL, 16)
		vb.add_child(ach_panel)
		var ach_vb := VBoxContainer.new()
		ach_vb.add_theme_constant_override("separation", 4)
		ach_panel.add_child(ach_vb)
		var ach_title := UiTheme.make_label("🏆 実績解除！（+%dXP）" % _sum_xp(new_achievements), 24, UiTheme.TEXT_MAIN)
		ach_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ach_vb.add_child(ach_title)
		for a in new_achievements:
			var line := UiTheme.make_label(
				"%s %s — %s" % [String(a.get("icon", "🏆")), String(a.get("name", "")), String(a.get("desc", ""))],
				20, UiTheme.TEXT_MAIN, true)
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ach_vb.add_child(line)

	# 報酬パネル
	var reward := UiTheme.make_panel(UiTheme.CARD, 16)
	vb.add_child(reward)
	var rv := VBoxContainer.new()
	reward.add_child(rv)
	var money := UiTheme.make_label("💰 獲得予算 +%d（合計 %d）" % [int(r.get("budget_total", 0)), Meta.budget], 30, UiTheme.WARN)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(money)
	var rank := UiTheme.make_label("👑 %s｜定時退社 %d回｜🔥連続 %d" % [Meta.rank_name(), Meta.teiji_count, Meta.streak],
			24, UiTheme.TEXT_DIM)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(rank)

	var prog := Meta.player_level_progress()
	var ach_count := Meta.achievement_progress_count()
	var lv_line := UiTheme.make_label(
		"🧗 プレイヤーLv%d（%d/%d XP）｜🏆 実績 %d/%d" % [
			int(prog["level"]), int(prog["cur"]), int(prog["need"]),
			int(ach_count["unlocked"]), int(ach_count["total"])],
		21, UiTheme.TEXT_DIM)
	lv_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(lv_line)

	vb.add_child(UiTheme.vspace(16))

	var next_btn := UiTheme.make_button("💼 次の日へ", UiTheme.ACCENT, 34)
	next_btn.custom_minimum_size = Vector2(0, 92)
	next_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	vb.add_child(next_btn)

	var shop_btn := UiTheme.make_button("🛠 会社強化（AI・設備）", UiTheme.GOOD, 28)
	shop_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Shop.tscn"))
	vb.add_child(shop_btn)

	var ach_btn := UiTheme.make_button("🏆 実績一覧", UiTheme.AI_COL, 26)
	ach_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Achievements.tscn"))
	vb.add_child(ach_btn)

	var title_btn := UiTheme.make_button("🏠 タイトルへ", Color(0.3, 0.3, 0.35), 24)
	title_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Title.tscn"))
	vb.add_child(title_btn)


func _sum_xp(achievements: Array) -> int:
	var total := 0
	for a in achievements:
		total += int(a.get("xp", 0))
	return total


func _add_row(parent: Control, label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := UiTheme.make_label(label_text, 24, UiTheme.TEXT_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UiTheme.make_label(value_text, 24))
