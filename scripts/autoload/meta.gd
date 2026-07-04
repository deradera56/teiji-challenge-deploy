extends Node
## 永続データ（会社の成長・予算・熟練度）とセーブ/ロード。

const SAVE_PATH := "user://save.json"

## カテゴリ別熟練度の表示名
const CATEGORY_NAMES := {
	"mail": "メール", "chat": "チャット", "phone": "電話",
	"meeting": "会議", "incident": "障害", "paper": "書類", "rush": "修羅場",
}

var budget: int = 0                     # 予算（メタ通貨）
var teiji_count: int = 0                # 定時退社の累計回数
var total_days: int = 0
var streak: int = 0                     # 連続定時退社
var best_streak: int = 0
var perfect_days: int = 0               # パーフェクトデー回数
var upgrade_levels: Dictionary = {}     # upgrade_id -> level
var mastery: Dictionary = {}            # category -> 累計XP（やり込みで熟練）
var unlocked_companies: Array = ["it"]
var selected_company: String = "it"
var last_result: Dictionary = {}        # 直近の1日の結果（Result画面表示用）

# --- 実績・プレイヤーレベル（生涯統計） ---
var unlocked_achievements: Array = []   # 解除済み実績ID
var player_xp: int = 0                  # 実績解除で得られるXP（プレイヤーレベルの元）
var lifetime_tasks_done: int = 0
var lifetime_tasks_failed: int = 0
var lifetime_tasks_refused: int = 0
var lifetime_budget_earned: int = 0
var best_combo_ever: int = 0
var rare_events_seen: int = 0
var epic_events_seen: int = 0


func _ready() -> void:
	load_game()


## アップグレード効果の合計値を返す（例: "work_speed" -> 0.45）
func effect(effect_name: String) -> float:
	var total := 0.0
	for u in Config.upgrades:
		if String(u.get("effect", "")) == effect_name:
			total += float(u.get("per_level", 0)) * float(upgrade_levels.get(String(u["id"]), 0))
	return total


func upgrade_level(id: String) -> int:
	return int(upgrade_levels.get(id, 0))


func upgrade_cost(u: Dictionary) -> int:
	var lv := upgrade_level(String(u["id"]))
	return int(round(float(u["base_cost"]) * pow(float(u["cost_mult"]), lv)))


func buy_upgrade(id: String) -> bool:
	for u in Config.upgrades:
		if String(u["id"]) != id:
			continue
		var lv := upgrade_level(id)
		if lv >= int(u["max_level"]):
			return false
		var cost := upgrade_cost(u)
		if budget < cost:
			return false
		budget -= cost
		upgrade_levels[id] = lv + 1
		save_game()
		return true
	return false


func unlock_company(id: String) -> bool:
	if unlocked_companies.has(id):
		return true
	var c := Config.get_company(id)
	var cost := int(c.get("unlock_cost", 0))
	if budget < cost:
		return false
	budget -= cost
	unlocked_companies.append(id)
	save_game()
	return true


# ------------------------------------------------------------ 熟練度

## カテゴリの熟練レベル（0〜10）。必要XPはレベルごとに1.4倍ずつ増える
func mastery_level(category: String) -> int:
	var xp := float(mastery.get(category, 0))
	var lv := 0
	var need := 30.0
	while xp >= need and lv < 10:
		xp -= need
		need *= 1.4
		lv += 1
	return lv


## XPを加算し、レベルが上がったら新レベルを返す（上がらなければ0）
func add_mastery(category: String, xp: int) -> int:
	var before := mastery_level(category)
	mastery[category] = int(mastery.get(category, 0)) + xp
	var after := mastery_level(category)
	return after if after > before else 0


func mastery_total_level() -> int:
	var total := 0
	for cat in CATEGORY_NAMES:
		total += mastery_level(cat)
	return total


func category_name(category: String) -> String:
	return String(CATEGORY_NAMES.get(category, category))


# ------------------------------------------------------------ プレイヤーレベル・実績
## 実績解除で得たXPからプレイヤーレベルを算出する（必要XPはレベルごとに1.25倍）
const PLAYER_XP_BASE := 40.0
const PLAYER_XP_MULT := 1.25

func player_level() -> int:
	return _player_level_progress()["level"]


## {level, cur, need} を返す（curは現レベル内蓄積XP、needは次レベルに必要なXP）
func player_level_progress() -> Dictionary:
	return _player_level_progress()


func _player_level_progress() -> Dictionary:
	var xp := float(player_xp)
	var lv := 0
	var need := PLAYER_XP_BASE
	while xp >= need:
		xp -= need
		need *= PLAYER_XP_MULT
		lv += 1
	return {"level": lv, "cur": xp, "need": need}


## 設備アップグレードが最大レベルになっている個数
func maxed_upgrades_count() -> int:
	var n := 0
	for u in Config.upgrades:
		if upgrade_level(String(u["id"])) >= int(u["max_level"]):
			n += 1
	return n


## 実績条件で参照する統計値を名前から引く
func get_stat(stat_name: String) -> float:
	match stat_name:
		"teiji_count": return float(teiji_count)
		"streak": return float(streak)
		"best_streak": return float(best_streak)
		"perfect_days": return float(perfect_days)
		"total_days": return float(total_days)
		"mastery_total_level": return float(mastery_total_level())
		"lifetime_tasks_done": return float(lifetime_tasks_done)
		"lifetime_tasks_failed": return float(lifetime_tasks_failed)
		"lifetime_tasks_refused": return float(lifetime_tasks_refused)
		"lifetime_budget_earned": return float(lifetime_budget_earned)
		"best_combo_ever": return float(best_combo_ever)
		"rare_events_seen": return float(rare_events_seen)
		"epic_events_seen": return float(epic_events_seen)
		"unlocked_companies_count": return float(unlocked_companies.size())
		"maxed_upgrades_count": return float(maxed_upgrades_count())
		"budget": return float(budget)
	if stat_name.begins_with("mastery_"):
		return float(mastery_level(stat_name.substr(8)))
	return 0.0


func _condition_met(cond: Dictionary) -> bool:
	var val := get_stat(String(cond.get("stat", "")))
	var target := float(cond.get("value", 0))
	match String(cond.get("op", ">=")):
		">=": return val >= target
		">": return val > target
		"==": return val == target
		"<=": return val <= target
		"<": return val < target
	return false


## 未解除の実績のうち条件を満たしたものを解除し、新規解除リストを返す
func check_achievements() -> Array:
	var newly: Array = []
	for a in Config.achievements:
		var id := String(a["id"])
		if unlocked_achievements.has(id):
			continue
		if _condition_met(a.get("condition", {})):
			unlocked_achievements.append(id)
			player_xp += int(a.get("xp", 20))
			newly.append(a)
	return newly


## 未解除の実績のうち、条件に最も近いもの（進捗のヒント表示用）
func next_achievement_hint() -> Dictionary:
	var best := {}
	var best_ratio := -1.0
	for a in Config.achievements:
		var id := String(a["id"])
		if unlocked_achievements.has(id):
			continue
		var cond: Dictionary = a.get("condition", {})
		var target := max(0.001, float(cond.get("value", 1)))
		var val := get_stat(String(cond.get("stat", "")))
		var ratio: float = clamp(val / target, 0.0, 0.999)
		if ratio > best_ratio:
			best_ratio = ratio
			best = a.duplicate()
			best["_progress"] = ratio
			best["_val"] = val
			best["_target"] = target
	return best


func achievement_progress_count() -> Dictionary:
	return {"unlocked": unlocked_achievements.size(), "total": Config.achievements.size()}


# ------------------------------------------------------------ ランク・結果

func rank_name() -> String:
	var current := "定時の新人"
	for r in Config.ranks:
		if teiji_count >= int(r["teiji"]):
			current = String(r["name"])
	return current


## 1日の結果を反映してセーブする
func apply_result(r: Dictionary) -> void:
	total_days += 1
	budget += int(r.get("budget_total", 0))
	if String(r.get("reason", "")) == "teiji":
		teiji_count += 1
		streak += 1
		best_streak = max(best_streak, streak)
	else:
		streak = 0
	if bool(r.get("perfect", false)):
		perfect_days += 1

	# 生涯統計を積み上げる（実績判定の元データ）
	lifetime_tasks_done += int(r.get("tasks_done", 0))
	lifetime_tasks_failed += int(r.get("tasks_failed", 0))
	lifetime_tasks_refused += int(r.get("tasks_refused", 0))
	lifetime_budget_earned += int(r.get("budget_total", 0))
	best_combo_ever = max(best_combo_ever, int(r.get("combo_max", 0)))
	rare_events_seen += int(r.get("rare_events", 0))
	epic_events_seen += int(r.get("epic_events", 0))

	# 実績判定とプレイヤーレベルアップ判定
	var level_before := player_level()
	var newly := check_achievements()
	var level_after := player_level()
	r["new_achievements"] = newly
	r["level_before"] = level_before
	r["level_after"] = level_after
	r["level_up"] = level_after > level_before

	last_result = r
	save_game()


func save_game() -> void:
	var data := {
		"budget": budget,
		"teiji_count": teiji_count,
		"total_days": total_days,
		"streak": streak,
		"best_streak": best_streak,
		"perfect_days": perfect_days,
		"upgrade_levels": upgrade_levels,
		"mastery": mastery,
		"unlocked_companies": unlocked_companies,
		"selected_company": selected_company,
		"unlocked_achievements": unlocked_achievements,
		"player_xp": player_xp,
		"lifetime_tasks_done": lifetime_tasks_done,
		"lifetime_tasks_failed": lifetime_tasks_failed,
		"lifetime_tasks_refused": lifetime_tasks_refused,
		"lifetime_budget_earned": lifetime_budget_earned,
		"best_combo_ever": best_combo_ever,
		"rare_events_seen": rare_events_seen,
		"epic_events_seen": epic_events_seen,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("セーブに失敗しました")
		return
	f.store_string(JSON.stringify(data, "\t"))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed
	budget = int(d.get("budget", 0))
	teiji_count = int(d.get("teiji_count", 0))
	total_days = int(d.get("total_days", 0))
	streak = int(d.get("streak", 0))
	best_streak = int(d.get("best_streak", 0))
	perfect_days = int(d.get("perfect_days", 0))
	upgrade_levels = d.get("upgrade_levels", {})
	mastery = d.get("mastery", {})
	unlocked_companies = d.get("unlocked_companies", ["it"])
	selected_company = String(d.get("selected_company", "it"))
	unlocked_achievements = d.get("unlocked_achievements", [])
	player_xp = int(d.get("player_xp", 0))
	lifetime_tasks_done = int(d.get("lifetime_tasks_done", 0))
	lifetime_tasks_failed = int(d.get("lifetime_tasks_failed", 0))
	lifetime_tasks_refused = int(d.get("lifetime_tasks_refused", 0))
	lifetime_budget_earned = int(d.get("lifetime_budget_earned", 0))
	best_combo_ever = int(d.get("best_combo_ever", 0))
	rare_events_seen = int(d.get("rare_events_seen", 0))
	epic_events_seen = int(d.get("epic_events_seen", 0))


func reset_all() -> void:
	budget = 0
	teiji_count = 0
	total_days = 0
	streak = 0
	best_streak = 0
	perfect_days = 0
	upgrade_levels = {}
	mastery = {}
	unlocked_companies = ["it"]
	selected_company = "it"
	unlocked_achievements = []
	player_xp = 0
	lifetime_tasks_done = 0
	lifetime_tasks_failed = 0
	lifetime_tasks_refused = 0
	lifetime_budget_earned = 0
	best_combo_ever = 0
	rare_events_seen = 0
	epic_events_seen = 0
	save_game()
