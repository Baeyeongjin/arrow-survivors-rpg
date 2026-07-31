extends SceneTree

const Telemetry = preload("res://RunTelemetry.gd")

const TEST_PATH := "res://.godot/run_telemetry_test.json"

var failed := false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _record(outcome: String, floor_no: int, route: String, damage: Dictionary,
		extracted: int, duration: float) -> Dictionary:
	return {
		"outcome": outcome,
		"floor_reached": floor_no,
		"route_history": [route],
		"damage_dealt": 100.0,
		"damage_by_source": damage,
		"extracted_gear_count": extracted,
		"duration_seconds": duration,
		"skills": {"bolt": 5, "burst": 3},
		"passives": {"tome": 3},
		"mastery_picks": {4: "a"},
	}


func _initialize() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

	var first := _record("defeat", 2, "camp", {"arrow": 70.0, "aura": 30.0}, 1, 420.0)
	var second := _record("victory", 3, "merchant", {"arrow": 20.0, "blade": 80.0}, 2, 900.0)
	_expect(Telemetry.append_record(first, TEST_PATH, 2), "첫 전투 기록 저장 실패")
	_expect(Telemetry.append_record(second, TEST_PATH, 2), "두 번째 전투 기록 저장 실패")
	_expect(Telemetry.append_record(first, TEST_PATH, 2), "최대 보존 수 검증용 저장 실패")

	var loaded := Telemetry.load_records(TEST_PATH)
	_expect(loaded.size() == 2, "최대 2개 기록 보존이 지켜지지 않음: %d" % loaded.size())
	_expect(int(loaded[0].get("schema_version", 0)) == Telemetry.SCHEMA_VERSION,
		"스키마 버전이 저장되지 않음")

	var ranked := Telemetry.ranked_damage({"arrow": 30.0, "blade": 70.0}, 100.0, 2)
	_expect(ranked.size() == 2 and str(ranked[0]["key"]) == "blade",
		"피해 비중 정렬 오류: %s" % str(ranked))
	_expect(is_equal_approx(float(ranked[0]["share"]), 0.7),
		"피해 비중 계산 오류: %s" % str(ranked))

	var summary := Telemetry.aggregate([first, second])
	_expect(int(summary["runs"]) == 2 and int(summary["wins"]) == 1,
		"런/클리어 집계 오류: %s" % summary)
	_expect(is_equal_approx(float(summary["win_rate"]), 0.5),
		"클리어율 집계 오류: %s" % summary)
	_expect(int(summary["deaths_by_floor"].get("2", 0)) == 1,
		"사망 층 집계 오류: %s" % summary)
	_expect(int(summary["route_counts"].get("camp", 0)) == 1
		and int(summary["route_counts"].get("merchant", 0)) == 1,
		"경로 선택 집계 오류: %s" % summary)
	_expect(int(summary["extracted_gear_count"]) == 3,
		"추출 장비 집계 오류: %s" % summary)
	_expect(int(summary["skill_counts"].get("bolt", 0)) == 2
		and int(summary["skill_counts"].get("burst", 0)) == 2
		and int(summary["passive_counts"].get("tome", 0)) == 2
		and int(summary["mastery_counts"].get("4:a", 0)) == 2,
		"빌드 선택률 집계 오류: %s" % summary)

	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	if failed:
		quit(1)
		return
	print("RUN_TELEMETRY_OK")
	quit(0)
