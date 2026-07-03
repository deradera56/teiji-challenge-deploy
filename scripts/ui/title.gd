extends Control
## タイトル画面。会社の成長状況を見せつつ出社へ誘導する。


func _ready() -> void:
	UiTheme.fill_bg(self)
	var vb := UiTheme.make_margin_vbox(self, 48, 20)

	vb.add_child(UiTheme.vspace(80))

	var logo := UiTheme.make_label("🏢", 110)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(logo)

	var title := UiTheme.make_label("定時退社チャレンジ", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var sub := UiTheme.make_label("〜今日も18時に帰れるか？〜", 28, UiTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	vb.add_child(UiTheme.vspace(30))

	# 戦績パネル
	var stats := UiTheme.make_panel(UiTheme.PANEL, 16)
	vb.add_child(stats)
	var stats_vb := VBoxContainer.new()
	stats_vb.add_theme_constant_override("separation", 6)
	stats.add_child(stats_vb)
	var rank := UiTheme.make_label("👑 %s" % Meta.rank_name(), 32, UiTheme.WARN)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_vb.add_child(rank)
	var line := UiTheme.make_label(
		"定時退社 %d回｜出社 %d日｜最高連続 %d" % [Meta.teiji_count, Meta.total_days, Meta.best_streak],
		24, UiTheme.TEXT_DIM)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_vb.add_child(line)
	var money := UiTheme.make_label("💰 予算 %d" % Meta.budget, 28)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_vb.add_child(money)

	vb.add_child(UiTheme.vspace(30))

	var start_btn := UiTheme.make_button("💼 出社する", UiTheme.ACCENT, 36)
	start_btn.custom_minimum_size = Vector2(0, 100)
	start_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/CompanySelect.tscn"))
	vb.add_child(start_btn)

	var shop_btn := UiTheme.make_button("🛠 会社強化（AI・設備）", UiTheme.GOOD, 30)
	shop_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Shop.tscn"))
	vb.add_child(shop_btn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var reset_btn := UiTheme.make_button("データリセット", Color(0.3, 0.3, 0.35), 20)
	reset_btn.custom_minimum_size = Vector2(0, 52)
	reset_btn.pressed.connect(_on_reset)
	vb.add_child(reset_btn)


func _on_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "会社の成長・予算・記録をすべて消去します。よろしいですか？"
	dialog.ok_button_text = "消去する"
	dialog.cancel_button_text = "やめる"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		Meta.reset_all()
		get_tree().reload_current_scene())
	dialog.popup_centered()
