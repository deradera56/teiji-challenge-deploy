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
	var line2 := UiTheme.make_label(
		"💮 パーフェクト %d回｜🎓 熟練合計 Lv%d" % [Meta.perfect_days, Meta.mastery_total_level()],
		24, UiTheme.TEXT_DIM)
	line2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_vb.add_child(line2)
	var money := UiTheme.make_label("💰 予算 %d" % Meta.budget, 28)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_vb.add_child(money)

	# --- プレイヤーレベル（実績で貯まるXPで成長） ---
	stats_vb.add_child(UiTheme.vspace(8))
	var prog := Meta.player_level_progress()
	var ach_count := Meta.achievement_progress_count()
	var lv_row := HBoxContainer.new()
	stats_vb.add_child(lv_row)
	var lv_label := UiTheme.make_label("🧗 プレイヤーLv%d" % int(prog["level"]), 24, UiTheme.ACCENT)
	lv_row.add_child(lv_label)
	var ach_label := UiTheme.make_label("🏆 実績 %d/%d" % [int(ach_count["unlocked"]), int(ach_count["total"])],
			24, UiTheme.TEXT_DIM)
	ach_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lv_row.add_child(ach_label)

	var lv_bar := UiTheme.make_bar(UiTheme.ACCENT)
	lv_bar.max_value = max(1.0, float(prog["need"]))
	lv_bar.value = float(prog["cur"])
	stats_vb.add_child(lv_bar)

	# --- 次の実績まであと一歩ヒント（ゴールが近いと分かると続けたくなる） ---
	var hint: Dictionary = Meta.next_achievement_hint()
	if not hint.is_empty():
		var ratio := float(hint.get("_progress", 0.0))
		var hint_text := "次の実績まであと少し！"
		if ratio < 0.05:
			hint_text = "次に目指す実績"
		var hint_l := UiTheme.make_label