extends Node
## データ駆動設定ローダー。data/*.json を起動時に読み込む。
## 新しいタスク・イベント・会社・強化はJSONに追記するだけで追加できる。

var tasks: Dictionary = {}            # id -> タスク定義
var task_list: Array = []             # タスク定義の配列
var spawn_interval_min: float = 24.0  # タスク発生間隔（ゲーム内分）
var initial_tasks: Array = []         # 出社直後に積まれるタスク
var rush_pool: Array = []             # 17:50ラッシュ用タスク

var events: Array = []
var event_interval_min: float = 55.0

var companies: Array = []
var upgrades: Array = []
var ranks: Array = []
var achievements: Array = []


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	var td := _load_json("res://data/tasks.json")
	task_list = td.get("tasks", [])
	spawn_interval_min = float(td.get("spawn_interval_min", 24.0))
	initial_tasks = td.get("initial_tasks", [])
	rush_pool = td.get("rush_pool", [])
	tasks.clear()
	for t in task_list:
		tasks[t["id"]] = t

	var ed := _load_json("res://data/events.json")
	events = ed.get("events", [])
	event_interval_min = float(ed.get("event_interval_min", 55.0))

	var cd := _load_json("res://data/companies.json")
	companies = cd.get("companies", [])

	var ud := _load_json("res://data/upgrades.json")
	upgrades = ud.get("upgrades", [])
	ranks = ud.get("ranks", [])

	var achd := _load_json("res://data/achievements.json")
	achievements = achd.get("achievements", [])


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("データファイルを開けません: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("JSONの形式が不正です: %s" % path)
	return {}


func get_task(id: String) -> Dictionary:
	return tasks.get(id, {})


func get_company(id: String) -> Dictionary:
	for c in companies:
		if c["id"] == id:
			return c
	return companies[0] if not companies.is_empty() else {}
