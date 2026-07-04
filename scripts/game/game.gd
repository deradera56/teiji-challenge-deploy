extends Control
## コアゲームループ：出社→タスク発生→優先順位判断→イベント→17:50ラッシュ→退社判定
## 時間はゲーム内分（9:00開始=0分、18:00=540分）で管理する。

const DAY_END_MIN := 540.0      # 18:00 定時
const RUSH_MIN := 530.0         # 17:50 ラッシュ
const SPAWN_STOP_MIN := 500.0   # 通常タスクの発生はここまで
const FORCE_END_MIN := 660.0    # 20:00 強制退社
const GAME_MIN_PER_SEC := 3.2   # 実時間1秒 = ゲーム内3.2分（1日 約2.8分）

# --- 5リソース（時間はt、予算はbudget_earned） ---
var t: float = 0.0
var focus: float = 100.0
var motivation: float = 70.0  # 基本70。福利厚生アップグレードで上昇
var trust: float = 50.0
var budget_earned: int = 0

var tasks_done: int = 0
var tasks_failed: int = 0
var tasks_refused: int = 0
var combo: int = 0
var combo_max: int = 0

var overtime: bool = false
var rush_fired: bool = false
var ended: bool = false
var rare_events_today: int = 0
var epic_events_today: int = 0

var company: Dictionary = {}
var spawn_timer: float = 14.0
var event_timer: float = 40.0
var coffee_cd: float = 0.0

var active_card: TaskCard = null
var cards: Array[TaskCard] = []

# --- UI参照 ---
var day_label: Label
var streak_label: Label
var combo_label: Label
var clock_label: Label
var status_label: Label
var focus_label: Label
var motiv_label: Label
var trust_label: Label
var focus_bar: ProgressBar
var motiv_bar: ProgressBar
var trust_bar: ProgressBar
var money_label: Label
var coffee_btn: Button
var card_list: VBoxContainer
var toast_box: VBoxContainer
var flash_rect: ColorRect


func _ready() -> void:
	company = Config.get_company(Meta.selected_company)
	motivation = min(100.0, 70.0 + Meta.effect("start_motivation"))
	_build_ui()
	for id in Config.initial_tasks:
		var tpl := Config.get_task(String(id))
		if not tpl.is_empty():
			_add_task(tpl)
	if Meta.total_days == 0:
		_toast("💼 出社！ タスクを捌いて18:00に退社しよう", UiTheme.PANEL)
		_toast("💡 全部やる必要はない。『断る』のも優先順位のうち", UiTheme.PANEL)
	else:
		_toast("💼 Day %d 出社！今日も定時で帰るぞ" % (Meta.total_days + 1), UiTheme.PANEL)


func _process(delta: float) -> void:
	if ended:
		return
	var dgm := delta * GAME_MIN_PER_SEC
	t += dgm
	coffee_cd = max(0.0, coffee_cd - dgm)

	_update_spawning(dgm)
	_update_events(dgm)
	_update_work(dgm)
	_update_deadlines(dgm)
	_update_resources(dgm)
	if ended:
		return
	_check_rush()
	_check_day_end()
	_update_hud()


# ------------------------------------------------------------------ 進行

func _update_spawning(dgm: float) -> void:
	if t > SPAWN_STOP_MIN or overtime:
		return
	spawn_timer -= dgm
	if spawn_timer <= 0.0:
		_spawn_random_task()
		var interval := Config.spawn_interval_min \
			* float(company.get("spawn_interval_mult", 1.0)) \
			* (1.0 + Meta.effect("spawn_slow"))
		spawn_timer = interval * randf_range(0.7, 1.35)


func _update_events(dgm: float) -> void:
	if t > SPAWN_STOP_MIN or overtime:
		return
	event_timer -= dgm
	if event_timer <= 0.0:
		_fire_random_event()
		var interval := Config.event_interval_min \
			* float(company.get("event_interval_mult", 1.0))
		event_timer = interval * randf_range(0.7, 1.4)


func _update_work(dgm: float) -> void:
	# 手作業（同時に1つ）
	if active_card != null:
		var cat := String(active_card.tpl.get("category", ""))
		var speed := (1.0 + Meta.effect("work_speed")) \
				* (1.0 + 0.04 * Meta.mastery_level(cat))
		active_card.progress_min += dgm * speed
		if active_card.progress_min >= active_card.work_total():
			_complete_task(active_card)
	else:
		# 手が空いていると集中力が少し回復
		focus = min(100.0, focus + 0.25 * dgm)

	# AI委任（並列処理）
	var ai_speed := 0.5 * (1.0 + Meta.effect("ai_speed"))
	for card in cards.duplicate():
		if card.state == TaskCard.State.AI:
			card.progress_min += dgm * ai_speed
			if card.progress_min >= card.work_total():
				_complete_task(card)


func _update_deadlines(dgm: float) -> void:
	for card in cards.duplicate():
		if card.state == TaskCard.State.ACTIVE:
			continue  # 作業中は締切を止める（集中の恩恵）
		card.deadline_left -= dgm
		if card.deadline_left <= 0.0:
			_fail_task(card)


func _update_resources(dgm: float) -> void:
	if overtime:
		motivation -= 0.6 * dgm  # 残業はやる気を削る
	focus = clamp(focus, 0.0, 100.0)
	motivation = clamp(motivation, 0.0, 100.0)
	trust = clamp(trust, 0.0, 100.0)
	if focus <= 0.0:
		_end_day("zero_focus")
	elif motivation <= 0.0:
		_end_day("zero_motivation")
	elif trust <= 0.0:
		_end_day("zero_trust")


func _check_rush() -> void:
	if rush_fired or t < RUSH_MIN:
		return
	rush_fired = true
	var count := int(company.get("rush_count", 3))
	for i in count:
		var id: String = Config.rush_pool.pick_random()
		var tpl := Config.get_task(id)
		if not tpl.is_empty():
			_add_task(tpl, true)
	_toast("⏰ 17:50！帰宅直前ラッシュ発生！！", UiTheme.CARD_URGENT)
	_flash(UiTheme.BAD)


func _check_day_end() -> void:
	if t >= FORCE_END_MIN:
		for card in cards.duplicate():
			_fail_task(card, true)
		_end_day("force")
		return
	if not overtime and t >= DAY_END_MIN:
		if _all_clear():
			_end_day("teiji")
		else:
			overtime = true
			_toast("🌆 18:00…タスクが残っている。残業突入！", UiTheme.CARD_URGENT)
			_flash(UiTheme.WARN)
	elif overtime and _all_clear():
		_end_day("overtime")


func _all_clear() -> bool:
	return cards.is_empty()


# ------------------------------------------------------------------ タスク

func _spawn_random_task() -> void:
	var mults: Dictionary = company.get("category_weight_mult", {})
	var pool: Array = []
	var weights: Array[float] = []
	for tpl in Config.task_list:
		var w := float(tpl.get("weight", 0))
		if w <= 0.0:
			continue
		w *= float(mults.get(String(tpl.get("category", "")), 1.0))
		pool.append(tpl)
		weights.append(w)
	if pool.is_empty():
		return
	_add_task(pool[_weighted_index(weights)])


func _add_task(tpl: Dictionary, silent: bool = false) -> void:
	# RPA：メール系タスクを発生時に自動処理
	if String(tpl.get("category", "")) == "mail" and randf() < Meta.effect("auto_mail_chance"):
		tasks_done += 1
		budget_earned += _reward_of(tpl) / 2
		_toast("⚙ RPAが『%s』を自動処理！" % String(tpl.get("name", "")), UiTheme.PANEL)
		return
	var card := TaskCard.new()
	card.setup(tpl)
	card.start_requested.connect(_on_card_start)
	card.ai_requested.connect(_on_card_ai)
	card.refuse_requested.connect(_on_card_refuse)
	card_list.add_child(card)
	cards.append(card)
	if not silent and bool(tpl.get("urgent", false)):
		_toast("🔔 緊急タスク発生：%s" % String(tpl.get("name", "")), UiTheme.CARD_URGENT)


func _on_card_start(card: TaskCard) -> void:
	if ended:
		return
	if card.state == TaskCard.State.ACTIVE:
		# 中断
		card.state = TaskCard.State.WAITING
		active_card = null
		return
	var cost := _focus_cost(card)
	if not card.focus_paid and focus <= cost + 1.0:
		_toast("😵 集中力が足りない！☕休憩しよう", UiTheme.CARD_URGENT)
		return
	if active_card != null:
		active_card.state = TaskCard.State.WAITING
	active_card = card
	card.state = TaskCard.State.ACTIVE
	if not card.focus_paid:
		focus = max(0.0, focus - cost)
		card.focus_paid = true


func _on_card_ai(card: TaskCard) -> void:
	if ended or card.state == TaskCard.State.AI:
		return
	if _ai_free_slots() <= 0:
		_toast("🤖 AIスロットが埋まっている…", UiTheme.PANEL)
		return
	if active_card == card:
		active_card = null
	card.state = TaskCard.State.AI


func _on_card_refuse(card: TaskCard) -> void:
	if ended:
		return
	tasks_refused += 1
	trust += float(card.tpl.get("refuse_trust", -3))
	_toast("🙅『すみません、今日は無理です』（信用%d）" % int(card.tpl.get("refuse_trust", -3)), UiTheme.PANEL)
	_remove_card(card)


func _complete_task(card: TaskCard) -> void:
	tasks_done += 1
	combo += 1
	combo_max = max(combo_max, combo)
	trust += float(card.tpl.get("trust_done", 0))
	motivation += float(card.tpl.get("motivation_done", 0))
	# 連続完了コンボ：2連続目から報酬+10%ずつ（最大+100%）
	var mult := 1.0 + minf(1.0, maxf(0.0, float(combo - 1)) * 0.1)
	var earned := int(round(_reward_of(card.tpl) * mult))
	budget_earned += earned
	var cat := String(card.tpl.get("category", ""))
	var new_lv := Meta.add_mastery(cat, int(card.work_total()))
	if combo >= 3:
		_toast("✅ %s 完了！+💰%d ⚡コンボx%d" % [String(card.tpl.get("name", "")), earned, combo], UiTheme.PANEL)
	else:
		_toast("✅ %s 完了！+💰%d" % [String(card.tpl.get("name", "")), earned], UiTheme.PANEL)
	if new_lv > 0:
		_toast("🎓 %s熟練度 Lv%d に上昇！（処理速度UP）" % [Meta.category_name(cat), new_lv], UiTheme.AI_COL)
	_remove_card(card)


func _fail_task(card: TaskCard, silent: bool = false) -> void:
	if combo >= 3 and not silent:
		_toast("⚡ コンボ消滅…", UiTheme.CARD_URGENT)
	combo = 0
	tasks_failed += 1
	trust += float(card.tpl.get("trust_fail", -5))
	motivation += float(card.tpl.get("motivation_fail", -3))
	if not silent:
		_toast("💥 %s の期限切れ…" % String(card.tpl.get("name", "")), UiTheme.CARD_URGENT)
	_remove_card(card)


func _remove_card(card: TaskCard) -> void:
	if active_card == card:
		active_card = null
	cards.erase(card)
	card.queue_free()


func _reward_of(tpl: Dictionary) -> int:
	return int(round(float(tpl.get("budget_reward", 0)) * float(company.get("reward_mult", 1.0))))


func _focus_cost(card: TaskCard) -> float:
	var reduce: float = min(0.6, Meta.effect("focus_cost_reduce"))
	return float(card.tpl.get("focus_cost", 5)) * (1.0 - reduce)


func _ai_free_slots() -> int:
	var total := int(Meta.effect("ai_slots"))
	var used := 0
	for card in cards:
		if card.state == TaskCard.State.AI:
			used += 1
	return total - used


func _weighted_index(weights: Array[float]) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var r := randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return weights.size() - 1


# ------------------------------------------------------------------ イベント

func _fire_random_event() -> void:
	if Config.events.is_empty():
		return
	var weights: Array[float] = []
	for ev in Config.events:
		weights.append(float(ev.get("weight", 1)))
	var ev: Dictionary = Config.events[_weighted_index(weights)]
	var effects: Dictionary = ev.get("effects", {})
	focus += float(effects.get("focus", 0))
	motivation += float(effects.get("motivation", 0))
	trust += float(effects.get("trust", 0))
	budget_earned += int(effects.get("budget", 0))
	for id in ev.get("spawn_tasks", []):
		var tpl := Config.get_task(String(id))
		if not tpl.is_empty():
			_add_task(tpl, true)
	var text := "%s %s：%s" % [String(ev.get("icon", "❗")), String(ev.get("name", "")), String(ev.get("desc", ""))]
	match String(ev.get("rarity", "normal")):
		"rare":
			rare_events_today += 1
			_toast("💜レア！ " + text, UiTheme.AI_COL)
			_flash(UiTheme.AI_COL)
		"epic":
			epic_events_today += 1
			_toast("🌟激レア！！ " + text, UiTheme.WARN)
			_flash(UiTheme.WARN)
		_:
			var good := float(effects.get("motivation", 0)) > 0 \
					or float(effects.get("focus", 0)) > 0 or int(effects.get("budget", 0)) > 0
			_toast(text, UiTheme.PANEL if good else UiTheme.CARD_URGENT)
	# 誰かがタスクを片付けてくれる系レア効果
	for i in int(effects.get("auto_complete", 0)):
		var target: TaskCard = null
		for card in cards:
			if card.state == TaskCard.State.WAITING:
				target = card
				break
		if target != null:
			_toast("✨ 『%s』が勝手に片付いた！" % String(target.tpl.get("name", "")), UiTheme.AI_COL)
			_complete_task(target)


# ------------------------------------------------------------------ 退社判定

func _end_day(reason: String) -> void:
	if ended:
		return
	ended = true
	var reward_mult := float(company.get("reward_mult", 1.0))
	var overtime_min := int(max(0.0, t - DAY_END_MIN))
	var bonus := 0
	var outcome := ""
	match reason:
		"teiji":
			bonus = 40
			outcome = "🎉 定時退社成功！"
		"overtime":
			bonus = int(max(5.0, 25.0 - overtime_min / 6.0))
			outcome = "🌙 残業%d分…なんとか退社" % overtime_min
		"force":
			bonus = 5
			outcome = "🌃 20:00 ビル消灯。強制退社…"
		"zero_focus":
			budget_earned /= 2
			outcome = "😵 集中力が尽きた…もう画面が読めない"
		"zero_motivation":
			budget_earned /= 2
			outcome = "💔 心が折れた…今日はもう帰ろう"
		"zero_trust":
			budget_earned /= 2
			outcome = "📉 信用を失った…席がない気がする"
	# 日次評価：処理数・失敗・定時退社・残リソースからS〜Dを判定
	var perfect := reason == "teiji" and tasks_failed == 0
	var score := tasks_done * 2 - tasks_failed * 3
	if reason == "teiji":
		score += 8
	score += int((focus + motivation + trust) / 60.0)
	var grade := "C"
	if reason.begins_with("zero_"):
		grade = "D"
	elif perfect and score >= 24:
		grade = "S"
	elif score >= 18:
		grade = "A"
	elif score >= 10:
		grade = "B"
	var grade_bonus: Dictionary = {"S": 30, "A": 18, "B": 8, "C": 0, "D": 0}
	bonus += int(grade_bonus[grade])
	if perfect:
		bonus += 15
	var result := {
		"reason": reason,
		"grade": grade,
		"perfect": perfect,
		"combo_max": combo_max,
		"outcome": outcome,
		"day": Meta.total_days + 1,
		"company": "%s %s" % [String(company.get("icon", "")), String(company.get("name", ""))],
		"tasks_done": tasks_done,
		"tasks_failed": tasks_failed,
		"tasks_refused": tasks_refused,
		"overtime_min": overtime_min,
		"budget_total": budget_earned + int(round(bonus * reward_mult)),
		"focus": int(focus),
		"motivation": int(motivation),
		"trust": int(trust),
		"rare_events": rare_events_today,
		"epic_events": epic_events_today,
	}
	Meta.apply_result(result)
	get_tree().change_scene_to_file("res://scenes/Result.tscn")


# ------------------------------------------------------------------ UI構築・更新

func _build_ui() -> void:
	UiTheme.fill_bg(self)
	var vb := UiTheme.make_margin_vbox(self, 20, 12)

	# --- HUDパネル ---
	var hud := UiTheme.make_panel(UiTheme.PANEL, 16)
	vb.add_child(hud)
	var hud_vb := VBoxContainer.new()
	hud_vb.add_theme_constant_override("separation", 6)
	hud.add_child(hud_vb)

	var top_row := HBoxContainer.new()
	hud_vb.add_child(top_row)
	day_label = UiTheme.make_label("", 24, UiTheme.TEXT_DIM)
	day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(day_label)
	streak_label = UiTheme.make_label("", 24, UiTheme.WARN)
	top_row.add_child(streak_label)
	combo_label = UiTheme.make_label("", 24, UiTheme.ACCENT)
	top_row.add_child(combo_label)

	clock_label = UiTheme.make_label("09:00", 62)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_vb.add_child(clock_label)

	status_label = UiTheme.make_label("", 24, UiTheme.TEXT_DIM)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_vb.add_child(status_label)

	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 14)
	hud_vb.add_child(bars)
	var focus_pack := _make_resource_block(bars, "🧠 集中", UiTheme.ACCENT)
	focus_label = focus_pack[0]
	focus_bar = focus_pack[1]
	var motiv_pack := _make_resource_block(bars, "🔥 やる気", UiTheme.WARN)
	motiv_label = motiv_pack[0]
	motiv_bar = motiv_pack[1]
	var trust_pack := _make_resource_block(bars, "🤝 信用", UiTheme.GOOD)
	trust_label = trust_pack[0]
	trust_bar = trust_pack[1]

	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 12)
	hud_vb.add_child(money_row)
	money_label = UiTheme.make_label("💰 本日の稼ぎ 0", 26)
	money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_row.add_child(money_label)
	coffee_btn = UiTheme.make_button("☕ 休憩", UiTheme.GOOD, 24)
	coffee_btn.custom_minimum_size = Vector2(180, 60)
	coffee_btn.pressed.connect(_on_coffee)
	money_row.add_child(coffee_btn)

	# --- タスクリスト ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	card_list = VBoxContainer.new()
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_list.add_theme_constant_override("separation", 12)
	scroll.add_child(card_list)

	# --- 演出レイヤー ---
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 0, 0, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_box.offset_left = 40
	toast_box.offset_right = -40
	toast_box.offset_top = 320
	toast_box.add_theme_constant_override("separation", 8)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)


func _make_resource_block(parent: Control, title: String, color: Color) -> Array:
	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 2)
	parent.add_child(block)
	var l := UiTheme.make_label(title, 22, UiTheme.TEXT_DIM)
	block.add_child(l)
	var bar := UiTheme.make_bar(color)
	block.add_child(bar)
	return [l, bar]


func _update_hud() -> void:
	var hour := 9 + int(t) / 60
	var minute := int(t) % 60
	clock_label.text = "%02d:%02d" % [hour, minute]
	clock_label.add_theme_color_override("font_color",
			UiTheme.BAD if (overtime or t >= RUSH_MIN) else UiTheme.TEXT_MAIN)

	if overtime:
		status_label.text = "🔥 残業中…（残りタスク %d）" % cards.size()
	elif t >= RUSH_MIN:
		status_label.text = "⚡ 帰宅ラッシュ！定時まで あと%d分" % int(DAY_END_MIN - t)
	else:
		status_label.text = "定時まで あと%d分｜タスク %d件" % [int(DAY_END_MIN - t), cards.size()]

	day_label.text = "Day %d｜%s %s" % [Meta.total_days + 1,
			String(company.get("icon", "")), String(company.get("name", ""))]
	streak_label.text = "🔥 連続定時 %d" % Meta.streak if Meta.streak > 0 else ""
	combo_label.text = " ⚡x%d" % combo if combo >= 2 else ""

	focus_bar.value = focus
	motiv_bar.value = motivation
	trust_bar.value = trust
	focus_label.text = "🧠 集中 %d" % int(focus)
	motiv_label.text = "🔥 やる気 %d" % int(motivation)
	trust_label.text = "🤝 信用 %d" % int(trust)
	money_label.text = "💰 本日の稼ぎ %d" % budget_earned

	if coffee_cd > 0.0:
		coffee_btn.disabled = true
		coffee_btn.text = "☕ %d分" % int(ceil(coffee_cd))
	else:
		coffee_btn.disabled = false
		coffee_btn.text = "☕ 休憩"

	var ai_available := int(Meta.effect("ai_slots")) > 0
	var ai_free := _ai_free_slots() > 0
	for card in cards:
		card.update_view(ai_available, ai_free)


func _on_coffee() -> void:
	if coffee_cd > 0.0 or ended:
		return
	var heal := 25.0 * (1.0 + Meta.effect("coffee_boost"))
	focus = min(100.0, focus + heal)
	coffee_cd = 60.0
	_toast("☕ ふぅ…（集中力 +%d）" % int(heal), UiTheme.PANEL)


func _toast(text: String, bg: Color) -> void:
	var p := UiTheme.make_panel(bg, 12)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.modulate.a = 0.0
	p.add_child(UiTheme.make_label(text, 23))
	toast_box.add_child(p)
	if toast_box.get_child_count() > 4:
		toast_box.get_child(0).queue_free()
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


func _flash(color: Color) -> void:
	flash_rect.color = Color(color.r, color.g, color.b, 0.3)
	var tw := flash_rect.create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 1.0)
