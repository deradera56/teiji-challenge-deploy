extends Control
## 実績一覧画面。解除済み/未解除を一覧表示し、未解除は進捗を見せてやり込みを促す。

const TIER_COLOR := {
	"platinum": Color(0.75, 0.85, 0.95),
	"gold": Color(0.92, 0.78, 0.25),
	"silver": Color(0.75, 0.78, 0.82),
	"bronze": Color(0.80, 0.55, 0.35),
}
const TIER_ORDER := {"platinum": 0, "gold": 1, "silver": 2, "bronze": 3}

var _list: VBoxContainer


func _ready() -> void:
	UiTheme.fill_bg(self)
	var vb := UiTheme.make_margin_vbox(self, 32, 14)

	var title := UiTheme.make_label("🏆 実績一覧", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var count := Meta.achievement_progress_count()
	var count_l := UiTheme.make_label(
		"%d / %d 解除｜🧗 プレイヤーLv%d" % [int(count["unlocked"]), int(count["total"]), Meta.player_level()],
		24, UiTheme.WARN)
	count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(count_l)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	var back := UiTheme.make_button("← 戻る", Color(0.3, 0.3, 0.35), 26)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Title.tscn"))
	vb.add_child(back)

	_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()

	var unlocked_list: Array = []
	var locked_list: Array = []
	for a in Config.achievements:
		if Meta.unlocked_achievements.has(String(a["id"])):
			unlocked_list.append(a)
		else:
			locked_list.append(a)

	unlocked_list.sort_custom(func(a, b) -> bool:
		return int(TIER_ORDER.get(String(a.get("tier", "")), 9)) < int(TIER_ORDER.get(String(b.get("tier", "")), 9)))

	locked_list.sort_custom(func(a, b) -> bool:
		return _progress_ratio(a) > _progress_ratio(b))

	if unlocked_list.size() > 0:
		_list.add_child(UiTheme.make_label("✅ 解除済み", 24, UiTheme.GOOD))
		for a in unlocked_list:
			_list.add_child(_make_row(a, true))

	if locked_list.size() > 0:
		_list.add_child(UiTheme.vspace(6))
		_list.add_child(UiTheme.make_label("🔒 未解除", 24, UiTheme.TEXT_DIM))
		for a in locked_list:
			_list.add_child(_make_row(a, false))


func _progress_ratio(a: Dictionary) -> float:
	var cond: Dictionary = a.get("condition", {})
	var target := max(0.001, float(cond.get("value", 1)))
	var val := Meta.get_stat(String(cond.get("stat", "")))
	return clamp(val / target, 0.0, 1.0)


func _make_row(a: Dictionary, unlocked: bool) -> PanelContainer:
	var tier := String(a.get("tier", "bronze"))
	var tier_col: Color = TIER_COLOR.get(tier, UiTheme.TEXT_DIM)
	var p := UiTheme.make_panel(UiTheme.CARD if unlocked else UiTheme.PANEL, 14)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	p.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	vb.add_child(top)
	var icon_l := UiTheme.make_label(String(a.get("icon", "🏆")), 32)
	if not unlocked:
		icon_l.modulate.a = 0.4
	top.add_child(icon_l)
	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 2)
	top.add_child(name_col)
	var name_l := UiTheme.make_label(String(a.get("name", "")), 24, UiTheme.TEXT_MAIN if unlocked else UiTheme.TEXT_DIM)
	name_col.add_child(name_l)
	var desc_l := UiTheme.make_label(String(a.get("desc", "")), 18, UiTheme.TEXT_DIM)
	name_col.add_child(desc_l)
	var tier_l := UiTheme.make_label(tier.to_upper(), 16, tier_col)
	top.add_child(tier_l)

	if unlocked:
		var xp_l := UiTheme.make_label("+%dXP" % int(a.get("xp", 0)), 18, UiTheme.WARN)
		vb.add_child(xp_l)
	else:
		var cond: Dictionary = a.get("condition", {})
		var target := max(0.001, float(cond.get("value", 1)))
		var val := Meta.get_stat(String(cond.get("stat", "")))
		var bar := UiTheme.make_bar(tier_col)
		bar.max_value = target
		bar.value = clamp(val, 0.0, target)
		vb.add_child(bar)
		var prog_l := UiTheme.make_label("%d / %d" % [int(min(val, target)), int(target)], 16, UiTheme.TEXT_DIM)
		vb.add_child(prog_l)

	return p
