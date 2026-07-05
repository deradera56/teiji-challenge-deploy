class_name TaskCard
extends PanelContainer
## タスクカード1枚。表示・操作ボタン・進捗/締切の状態を持つ。
## ロジック判断はしない（Signalでgame.gdに委譲する疎結合設計）。

signal start_requested(card: TaskCard)
signal ai_requested(card: TaskCard)
signal refuse_requested(card: TaskCard)

enum State { WAITING, ACTIVE, AI }

var tpl: Dictionary = {}
var state: int = State.WAITING
var deadline_left: float = 0.0
var deadline_total: float = 1.0
var progress_min: float = 0.0
var focus_paid: bool = false

var _urgent: bool = false
var _dl_label: Label
var _bar: ProgressBar
var _btn_start: Button
var _btn_ai: Button
var _btn_refuse: Button
var _state_label: Label


func setup(task_tpl: Dictionary) -> void:
	tpl = task_tpl
	_urgent = bool(tpl.get("urgent", false))
	deadline_total = max(1.0, float(tpl.get("deadline_min", 60)))
	deadline_left = deadline_total
	_build()


func work_total() -> float:
	return max(1.0, float(tpl.get("work_min", 10)))


func _build() -> void:
	var base_col: Color = UiTheme.CARD_URGENT if _urgent else UiTheme.CARD
	add_theme_stylebox_override("panel", UiTheme.flat_style(base_col, 14))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	vb.add_child(top)

	var icon_l := UiTheme.make_label(String(tpl.get("icon", "📄")), 38)
	icon_l.autowrap_mode = TextServer.AUTOWRAP_OFF  # 2文字絵文字を横並びで固定
	top.add_child(icon_l)
	var mastery_lv := Meta.mastery_level(String(tpl.get("category", "")))
	if mastery_lv > 0:
		top.add_child(UiTheme.make_label("Lv%d" % mastery_lv, 20, UiTheme.WARN))
	var name_l := UiTheme.make_label(String(tpl.get("name", "?")), 30)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	if _urgent:
		top.add_child(UiTheme.make_label("⚠急", 24, UiTheme.BAD))
	_dl_label = UiTheme.make_label("", 24, UiTheme.TEXT_DIM)
	top.add_child(_dl_label)

	var desc := UiTheme.make_label(String(tpl.get("desc", "")), 21, UiTheme.TEXT_DIM, true)
	vb.add_child(desc)

	_bar = UiTheme.make_bar(UiTheme.ACCENT)
	_bar.max_value = work_total()
	_bar.value = 0
	_bar.visible = false
	vb.add_child(_bar)

	_state_label = UiTheme.make_label("🤖 AI処理中…", 24, UiTheme.AI_COL)
	_state_label.visible = false
	vb.add_child(_state_label)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	vb.add_child(btns)

	_btn_start = UiTheme.make_button("▶ 着手", UiTheme.GOOD, 24)
	_btn_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_start.custom_minimum_size = Vector2(0, 64)
	_btn_start.pressed.connect(func() -> void: start_requested.emit(self))
	btns.add_child(_btn_start)

	_btn_ai = UiTheme.make_button("🤖 AI", UiTheme.AI_COL, 24)
	_btn_ai.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_ai.custom_minimum_size = Vector2(0, 64)
	_btn_ai.pressed.connect(func() -> void: ai_requested.emit(self))
	btns.add_child(_btn_ai)

	_btn_refuse = UiTheme.make_button("× 断る", UiTheme.BAD, 24)
	_btn_refuse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_refuse.custom_minimum_size = Vector2(0, 64)
	_btn_refuse.pressed.connect(func() -> void: refuse_requested.emit(self))
	btns.add_child(_btn_refuse)


## 毎フレームの表示更新。ai_available=AI導入済みか、ai_free=空きスロットがあるか
func update_view(ai_available: bool, ai_free: bool) -> void:
	# 締切表示
	var ratio := deadline_left / deadline_total
	var col := UiTheme.GOOD
	if ratio < 0.25:
		col = UiTheme.BAD
	elif ratio < 0.5:
		col = UiTheme.WARN
	_dl_label.text = "締切 %d分" % int(ceil(deadline_left))
	_dl_label.add_theme_color_override("font_color", col)

	_bar.value = progress_min

	match state:
		State.WAITING:
			_bar.visible = progress_min > 0.0
			_state_label.visible = false
			_btn_start.visible = true
			_btn_start.text = "▶ 再開" if progress_min > 0.0 else "▶ 着手"
			_btn_ai.visible = ai_available
			_btn_ai.disabled = not ai_free
			_btn_refuse.visible = true
		State.ACTIVE:
			_bar.visible = true
			_state_label.visible = false
			_btn_start.visible = true
			_btn_start.text = "⏸ 中断"
			_btn_ai.visible = ai_available
			_btn_ai.disabled = not ai_free
			_btn_refuse.visible = false
		State.AI:
			_bar.visible = true
			_state_label.visible = true
			_btn_start.visible = false
			_btn_ai.visible = false
			_btn_refuse.visible = false
