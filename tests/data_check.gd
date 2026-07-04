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
		"lifetime_budget_earned": true, "best_combo_ever": true, "rare_events_seen": true,
		"epic_events_seen": true, "unlocked_companies_count": true,
		"maxed_upgrades_count": true, "budget": true,
	}
	var known_categories := ["mail", "chat", "phone", "meeting", "incident", "paper", "rush"]
	for cat in known_categories:
		known_stats["mastery_%s" % cat] = true

	var achievements: Array = achd.get("achievements", [])
	if achievements.is_empty():
		errors.append("実績データが空")
	var ach_ids := {}
	for a in achievements:
		var aid := String(a.get("id", ""))
		if aid.is_empty():
			errors.append("idの無い実績定義があります")
		elif ach_ids.has(aid):
			errors.append("実績IDが重複: %s" % aid)
		else:
			ach_ids[aid] = true
		for field in ["name", "desc", "tier", "condition"]:
			if not a.has(field):
				errors.append("実績 %s に %s が未定義" % [aid, field])
		var cond: Dictionary = a.get("condition", {})
		var stat := String(cond.get("stat", ""))
		if not known_stats.has(stat):
			errors.append("実績 %s が不明な統計値を参照: %s" % [aid, stat])
		if not cond.has("value"):
			errors.append("実績 %s の条件にvalueが未定義" % aid)

	if errors.is_empty():
		print("ALL CHECKS PASSED")
	else:
		for e in errors:
			printerr(e)
	quit(0 if errors.is_empty() else 1)


func _load(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
