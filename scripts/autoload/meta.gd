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


# ------------------------------------------------------------ ランク・結果

func rank_name() -> String:
	var current := "定時の新人"
	for r in Config.ranks:
		if teiji_count >= int(r["teiji"]):
			current = String(r["name"])
	return current


## 1日の結果を反映してセーブする
func apply_result(r: Dictionary) -> void:
	last_result = r
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
	save_game()
