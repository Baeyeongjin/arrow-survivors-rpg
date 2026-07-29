class_name RunTelemetry
extends RefCounted

const SCHEMA_VERSION := 1
const DEFAULT_PATH := "user://run_telemetry.json"
const MAX_RECORDS := 100


static func load_records(path: String = DEFAULT_PATH) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		return []
	var records: Array = []
	for entry in parsed:
		if entry is Dictionary:
			records.append((entry as Dictionary).duplicate(true))
	return records


static func append_record(record: Dictionary, path: String = DEFAULT_PATH,
		max_records: int = MAX_RECORDS) -> bool:
	var records := load_records(path)
	var entry := record.duplicate(true)
	entry["schema_version"] = SCHEMA_VERSION
	entry["recorded_at_unix"] = int(Time.get_unix_time_from_system())
	records.push_front(entry)
	if records.size() > maxi(1, max_records):
		records.resize(maxi(1, max_records))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Run telemetry file could not be opened: %s" % path)
		return false
	file.store_string(JSON.stringify(records, "\t"))
	return true


static func ranked_damage(source: Dictionary, total: float, limit: int = 4) -> Array:
	var ranked: Array = []
	for key in source.keys():
		var amount := maxf(0.0, float(source[key]))
		if amount <= 0.0:
			continue
		ranked.append({
			"key": str(key),
			"amount": amount,
			"share": amount / maxf(1.0, total),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["amount"]) > float(b["amount"]))
	if ranked.size() > maxi(0, limit):
		ranked.resize(maxi(0, limit))
	return ranked


static func aggregate(records: Array) -> Dictionary:
	var runs := 0
	var wins := 0
	var total_time := 0.0
	var total_damage := 0.0
	var total_extracted := 0
	var deaths_by_floor := {}
	var route_counts := {}
	var damage_by_source := {}
	var weapon_counts := {}
	var passive_counts := {}
	var mastery_counts := {}
	for raw_record in records:
		if not (raw_record is Dictionary):
			continue
		var record := raw_record as Dictionary
		runs += 1
		var victory := str(record.get("outcome", "")) == "victory"
		if victory:
			wins += 1
		else:
			var floor_key := str(maxi(1, int(record.get("floor_reached", 1))))
			deaths_by_floor[floor_key] = int(deaths_by_floor.get(floor_key, 0)) + 1
		total_time += maxf(0.0, float(record.get("duration_seconds", 0.0)))
		total_damage += maxf(0.0, float(record.get("damage_dealt", 0.0)))
		total_extracted += maxi(0, int(record.get("extracted_gear_count", 0)))
		for route_key in record.get("route_history", []):
			var route := str(route_key)
			route_counts[route] = int(route_counts.get(route, 0)) + 1
		var source_map = record.get("damage_by_source", {})
		if source_map is Dictionary:
			for source_key in source_map.keys():
				var source := str(source_key)
				damage_by_source[source] = (
					float(damage_by_source.get(source, 0.0))
					+ maxf(0.0, float(source_map[source_key])))
		var selected_weapons = record.get("weapons", {})
		if selected_weapons is Dictionary:
			for weapon_key in selected_weapons.keys():
				var weapon := str(weapon_key)
				weapon_counts[weapon] = int(weapon_counts.get(weapon, 0)) + 1
		var selected_passives = record.get("passives", {})
		if selected_passives is Dictionary:
			for passive_key in selected_passives.keys():
				var passive := str(passive_key)
				passive_counts[passive] = int(passive_counts.get(passive, 0)) + 1
		var selected_masteries = record.get("mastery_picks", {})
		if selected_masteries is Dictionary:
			for mastery_level in selected_masteries.keys():
				var mastery_key := "%s:%s" % [
					str(mastery_level), str(selected_masteries[mastery_level])]
				mastery_counts[mastery_key] = int(mastery_counts.get(mastery_key, 0)) + 1
	return {
		"runs": runs,
		"wins": wins,
		"win_rate": float(wins) / maxf(1.0, float(runs)),
		"average_time": total_time / maxf(1.0, float(runs)),
		"average_damage": total_damage / maxf(1.0, float(runs)),
		"extracted_gear_count": total_extracted,
		"deaths_by_floor": deaths_by_floor,
		"route_counts": route_counts,
		"damage_by_source": damage_by_source,
		"weapon_counts": weapon_counts,
		"passive_counts": passive_counts,
		"mastery_counts": mastery_counts,
	}
