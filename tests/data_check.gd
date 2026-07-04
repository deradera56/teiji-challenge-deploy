extends SceneTree
## データ整合性チェック（ヘッドレス実行用）
## 実行: godot --headless -s tests/data_check.gd

func _initialize() -> void:
	var errors: Array[String] = []

	var td := _load("res://data/tasks.json")
	var ed := _load("res://data/events.json")
	var cd := _load("res://data/companies.json")
	var ud := _load("res://data/upgrades.json")
	var achd := _load("res://data/achievements.json")

	var ids := {}
	for t in td.get("tasks", []):
		ids[t["id"]] = true
	for ref in td.get("initial_tasks", []) + td.get("rush_pool", []):
		if not ids.has(ref):
			errors.append("不明なタスクID参照: %s" % ref)
	for ev in ed.get("events", []):
		for ref in ev.get("spawn_tasks", []):
			if not ids.has(ref):
				errors.append("イベント %s が不明なタスクを参照: %s" % [ev["id"], ref])
	if cd.get("companies", []).is_empty():
		errors.append("会社データが空")
	if ud.get("upgrades", []).is_empty():
		errors.append("アップグレードデータが空")

	# --- 実績データの整合性チェック ---
	var known_stats := {
		"teiji_count": true, "streak": true, "best_streak": true, "perfect_days": true,
		"total_days": true, "mastery_total_level": true, "lifetime_tasks_done": true,
		"lifetime_tasks_failed": true, "lifetime_tasks_refused": true,
		