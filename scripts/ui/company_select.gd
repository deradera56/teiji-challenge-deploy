extends Control
## 会社選択（難易度選択）。未解放の会社は予算でアンロックできる。

var _list: VBoxContainer


func _ready() -> void:
	UiTheme.fill_bg(self)
	var vb := UiTheme.make_margin_vbox(self, 36, 16)

	var title := UiTheme.make_label("どの会社に出社する？", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var money := UiTheme.make_label("💰 予算 %d" % Meta.budget, 26, UiTheme.TEXT_DIM)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money.name = "MoneyLabel"
	vb.add_child(money)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_list)
	_rebuild()

	var back := UiTheme.make_button("← タイトルへ", Color(0.3, 0.3, 0.35), 24)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Title.tscn"))
	vb.add_child(back)


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	for company in Config.companies:
		_list.add_child(_make_company_card(company))
	var money := find_child("MoneyLabel", true, false) as Label
	if money:
		money.text = "💰 予算 %d" % Meta.budget


func _make_company_card(company: Dictionary) -> PanelContainer:
	var id := String(company["id"])
	var unlocked: bool = Meta.unlocked_companies.has(id)
	var p := UiTheme.make_panel(UiTheme.CARD if unlocked else UiTheme.PANEL, 16)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	vb.add_child(top)
	top.add_child(UiTheme.make_label(String(company.get("icon", "🏢")), 40))
	var name_l := UiTheme.make_label(String(company.get("name", "")), 32)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	var mult := UiTheme.make_label("報酬 x%.2f" % float(company.get("reward_mult", 1.0)), 24, UiTheme.WARN)
	top.add_child(mult)

	vb.add_child(UiTheme.make_label(String(company.get("desc", "")), 22, UiTheme.TEXT_DIM, true))

	if unlocked:
		var go := UiTheme.make_button("🚪 ここに出社する", UiTheme.ACCENT, 28)
		go.pressed.connect(func() -> void:
			Meta.selected_company = id
			Meta.save_game()
			get_tree().change_scene_to_file("res://scenes/Game.tscn"))
		vb.add_child(go)
	else:
		var cost := int(company.get("unlock_cost", 0))
		var unlock := UiTheme.make_button("🔒 転職する（💰%d）" % cost, UiTheme.WARN, 26)
		unlock.disabled = Meta.budget < cost
		unlock.pressed.connect(func() -> void:
			if Meta.unlock_company(id):
				_rebuild())
		vb.add_child(unlock)
	return p
