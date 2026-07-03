extends Control
## 退社リザルト画面。1日の成績と報酬を表示し、次の行動へ誘導する。


func _ready() -> void:
	UiTheme.fill_bg(self)
	var r: Dictionary = Meta.last_result
	var vb := UiTheme.make_margin_vbox(self, 44, 18)

	vb.add_child(UiTheme.vspace(50))

	var teiji := String(r.get("reason", "")) == "teiji"
	var outcome := UiTheme.make_label(String(r.get("outcome", "退社")), 42,
			UiTheme.GOOD if teiji else UiTheme.WARN)
	outcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(outcome)

	var day_l := UiTheme.make_label("Day %d｜%s" % [int(r.get("day", 1)), String(r.get("company", ""))],
			24, UiTheme.TEXT_DIM)
	day_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(day_l)

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
	if int(r.get("overtime_min", 0)) > 0:
		_add_row(sv, "🌙 残業時間", "%d分" % int(r.get("overtime_min", 0)))
	_add_row(sv, "🧠 集中 / 🔥 やる気 / 🤝 信用",
			"%d / %d / %d" % [int(r.get("focus", 0)), int(r.get("motivation", 0)), int(r.get("trust", 0))])

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

	var title_btn := UiTheme.make_button("🏠 タイトルへ", Color(0.3, 0.3, 0.35), 24)
	title_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Title.tscn"))
	vb.add_child(title_btn)


func _add_row(parent: Control, label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := UiTheme.make_label(label_text, 24, UiTheme.TEXT_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UiTheme.make_label(value_text, 24))
