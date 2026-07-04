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
		"