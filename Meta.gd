class_name Meta
extends RefCounted
# =====================================================================
#  메타 진행 (런 사이 영구 저장): 골드 + 영구 강화
#  user://meta.cfg 에 저장됨
# =====================================================================

const PATH := "user://meta.cfg"
const CURRENT_VERSION := 2
const DEFAULT_CHARS := ["corvius", "gustavo", "serafina"]
const LEGACY_CHARS := ["corvius", "gustavo", "serafina", "valentino", "pixie", "django", "bolt", "morgana"]


static func initial_chars_for_save(had_save: bool, saved_version: int) -> Array:
	return LEGACY_CHARS if had_save and saved_version < CURRENT_VERSION else DEFAULT_CHARS

const UPGRADES := [
	{"key": "dmg",    "name": "공격력",     "desc": "모든 무기 피해 +4%/Lv", "max": 10, "base_cost": 15},
	{"key": "hp",     "name": "최대 체력",  "desc": "+10/Lv",               "max": 10, "base_cost": 12},
	{"key": "speed",  "name": "이동속도",   "desc": "+3%/Lv",               "max": 5,  "base_cost": 20},
	{"key": "cd",     "name": "쿨다운 감소", "desc": "무기 발동 -2%/Lv",     "max": 5,  "base_cost": 25},
	{"key": "magnet", "name": "자석 범위",  "desc": "+12/Lv",               "max": 5,  "base_cost": 10},
	{"key": "regen",  "name": "재생",       "desc": "초당 체력 +0.2/Lv",    "max": 5,  "base_cost": 18},
	{"key": "armor",  "name": "방어력",     "desc": "피해 감소 +1/Lv",      "max": 5,  "base_cost": 22},
	{"key": "area",   "name": "효과 범위",  "desc": "무기 범위 +5%/Lv",     "max": 5,  "base_cost": 20},
	{"key": "greed",  "name": "황금 손",    "desc": "골드 획득 +12%/Lv",    "max": 5,  "base_cost": 16},
	{"key": "xp",     "name": "지혜",       "desc": "경험치 획득 +8%/Lv",   "max": 5,  "base_cost": 20},
	{"key": "amount", "name": "추가 투사체", "desc": "무기 투사체 +1 (2Lv당)", "max": 4,  "base_cost": 40},
	{"key": "luck",   "name": "행운",       "desc": "상자·전리품 확률 +8%/Lv", "max": 5,  "base_cost": 24},
	{"key": "revive", "name": "부활",       "desc": "사망 시 1회 부활",     "max": 2,  "base_cost": 60},
]

static func load_data() -> Dictionary:
	var had_save := FileAccess.file_exists(PATH)
	var cf := ConfigFile.new()
	cf.load(PATH)   # 파일 없으면 무시되고 기본값 사용
	var saved_version := int(cf.get_value("meta", "version", 0))
	var d := {"gold": int(cf.get_value("meta", "gold", 0)), "up": {}, "ach": {},
		"evo_known": {}, "evo_seen": {}, "union_seen": {}, "enemy_kills": {}, "records": {},
		"unlocked_chars": {}, "unlocked_relics": {}, "meta_version": CURRENT_VERSION,
		"stage_unlocked": int(cf.get_value("meta", "stage_unlocked", 1)),
		"ach_knife": bool(cf.get_value("meta", "ach_knife", false)),
		"music_vol": float(cf.get_value("opt", "music_vol", 0.7)),
		"sfx_vol": float(cf.get_value("opt", "sfx_vol", 0.8)),
		"fullscreen": bool(cf.get_value("opt", "fullscreen", false)),
		"lang": str(cf.get_value("opt", "lang", "ko")),
		# 이펙트 강도 0=끔 1=약함 2=보통(기본) 3=화려함 — 파티클 수·섬광·화면 흔들림에 반영
		"fx_level": int(cf.get_value("opt", "fx_level", 2)),
		"screen_shake": bool(cf.get_value("opt", "screen_shake", true))}
	for u in UPGRADES:
		d["up"][u["key"]] = int(cf.get_value("up", u["key"], 0))
	# 업적 (섹션 [ach])
	if cf.has_section("ach"):
		for k in cf.get_section_keys("ach"):
			d["ach"][k] = bool(cf.get_value("ach", k, false))
	for section in ["evo_known", "evo_seen", "union_seen"]:
		if cf.has_section(section):
			for k in cf.get_section_keys(section):
				d[section][k] = bool(cf.get_value(section, k, false))
	if cf.has_section("enemy_kills"):
		for k in cf.get_section_keys("enemy_kills"):
			d["enemy_kills"][k] = int(cf.get_value("enemy_kills", k, 0))
	if cf.has_section("records"):
		for k in cf.get_section_keys("records"):
			var record = cf.get_value("records", k, {})
			if record is Dictionary:
				d["records"][k] = record
	for section in ["unlocked_chars", "unlocked_relics"]:
		if cf.has_section(section):
			for k in cf.get_section_keys(section):
				d[section][k] = bool(cf.get_value(section, k, false))
	# 신규 프로필은 3명으로 시작한다. 해금 시스템 도입 전 세이브는 기존 8명 접근권을 보존한다.
	if d["unlocked_chars"].is_empty():
		var initial_chars := initial_chars_for_save(had_save, saved_version)
		for character_key in initial_chars:
			d["unlocked_chars"][character_key] = true
	# 구버전 ach_knife 호환
	if d["ach_knife"]:
		d["ach"]["knife_thrower"] = true
	return d

static func save_data(d: Dictionary) -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "version", CURRENT_VERSION)
	cf.set_value("meta", "gold", d["gold"])
	cf.set_value("meta", "ach_knife", d.get("ach_knife", false))
	cf.set_value("meta", "stage_unlocked", d.get("stage_unlocked", 1))
	cf.set_value("opt", "music_vol", d.get("music_vol", 0.7))
	cf.set_value("opt", "sfx_vol", d.get("sfx_vol", 0.8))
	cf.set_value("opt", "fullscreen", d.get("fullscreen", false))
	cf.set_value("opt", "lang", d.get("lang", "ko"))
	cf.set_value("opt", "fx_level", d.get("fx_level", 2))
	cf.set_value("opt", "screen_shake", d.get("screen_shake", true))
	for k in d["up"].keys():
		cf.set_value("up", k, d["up"][k])
	for k in d.get("ach", {}).keys():
		cf.set_value("ach", k, d["ach"][k])
	for k in d.get("evo_known", {}).keys():
		cf.set_value("evo_known", k, d["evo_known"][k])
	for k in d.get("evo_seen", {}).keys():
		cf.set_value("evo_seen", k, d["evo_seen"][k])
	for k in d.get("union_seen", {}).keys():
		cf.set_value("union_seen", k, d["union_seen"][k])
	for k in d.get("enemy_kills", {}).keys():
		cf.set_value("enemy_kills", k, d["enemy_kills"][k])
	for k in d.get("records", {}).keys():
		cf.set_value("records", k, d["records"][k])
	for k in d.get("unlocked_chars", {}).keys():
		cf.set_value("unlocked_chars", k, d["unlocked_chars"][k])
	for k in d.get("unlocked_relics", {}).keys():
		cf.set_value("unlocked_relics", k, d["unlocked_relics"][k])
	cf.save(PATH)

static func cost(u: Dictionary, lv: int) -> int:
	return int(u["base_cost"]) * (lv + 1)
