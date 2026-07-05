extends Control
## 会社強化ショップ。予算でAI・設備をアップグレードする（永続成長）。

var _money_label: Label
var _list: VBoxContainer


func _ready() -> void:
	UiTheme.fill_bg(self)
	var vb := UiTheme.make_margin_vbox(self, 36, 16)

	var title := UiTheme.make_label("🛠 会社強化", 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	_money_label = UiTheme.make_label("", 30, UiTheme.WARN)
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_money_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)

	var back := UiTheme.make_button("← タイトルへ", Color(0.3, 0.3, 0.35), 26)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Title.tscn"))
	vb.add_child(back)

	_rebuild()


func _rebuild() -> void:
	_money_label.text = "💰 予算 %d" % Meta.budget
	for c in _list.get_children():
		c.queue_free()
	for u in Config.upgrades:
		_list.add_child(_make_upgrade_row(u))


func _make_upgrade_row(u: Dictionary) -> PanelContainer:
	var id := String(u["id"])
	var lv := Meta.upgrade_level(id)
	var max_lv := int(u["max_level"])
	var p := UiTheme.make_panel(UiTheme.CARD, 14)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	vb.add_child(top)
	top.add_child(UiTheme.make_label(String(u.get("icon", "🔧")), 36))
	var name_l := UiTheme.make_label(String(u.get("name", "")), 28)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	var lv_col := UiTheme.GOOD if lv >= max_lv else UiTheme.TEXT_DIM
	top.add_child(UiTheme.make_label("Lv %d/%d" % [lv, max_lv], 26, lv_col))

	vb.add_child(UiTheme.make_label(String(u.get("desc", "")), 21, UiTheme.TEXT_DIM, true))

	if lv >= max_lv:
		var done := UiTheme.make_label("✅ 最大レベル", 24, UiTheme.GOOD)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(done)
	else:
		var cost := Meta.upgrade_cost(u)
		var buy := UiTheme.make_button("強化する（💰%d）" % cost, UiTheme.ACCENT, 26)
		buy.disabled = Meta.budget < cost
		buy.pressed.connect(func() -> void:
			if Meta.buy_upgrade(id):
				_rebuild())
		vb.add_child(buy)
	return p
