class_name GameConfig
extends RefCounted
# =====================================================================
#  데이터 테이블 (장원영 / 데이터 설계)
#  - 몬스터 티어: 플레이어 레벨이 오를수록 더 강한 몬스터가 등장
#  - 주인공 진화: 레벨 구간마다 외형·색·아우라가 업그레이드
#  스프라이트 경로의 파일이 있으면 그림으로, 없으면 도형 폴백으로 렌더링됨.
# =====================================================================

# 30분 생존 웨이브 표.
# primary/secondary: 해당 분의 적 조합, mix: secondary 비율,
# density: 동시 상한·웨이브 수 보정, elite: 자연 엘리트 확률,
# threat: -1=없음, 0~5=일시적인 몬스터 강화 종류.
const WAVE_SCHEDULE := [
	# 0~5분: 던전 — 약한 적의 속도 차이와 기본 전투 학습
	{"primary":"slime",       "secondary":"goblin",       "mix":0.12, "density":0.62, "elite":0.010, "threat":-1},
	{"primary":"slime",       "secondary":"bat",          "mix":0.18, "density":0.70, "elite":0.012, "threat":1},
	{"primary":"goblin",      "secondary":"slime",        "mix":0.25, "density":0.77, "elite":0.015, "threat":0},
	{"primary":"skeleton",    "secondary":"goblin",       "mix":0.22, "density":0.83, "elite":0.018, "threat":-1},
	{"primary":"zombie",      "secondary":"bat",          "mix":0.25, "density":0.90, "elite":0.022, "threat":2},
	{"primary":"bat",         "secondary":"skeleton",     "mix":0.30, "density":0.97, "elite":0.026, "threat":3},
	# 6~11분: 지옥 — 단단한 적 사이에 빠른 화염 몬스터 혼합
	{"primary":"skeleton",    "secondary":"fire_imp",     "mix":0.18, "density":0.88, "elite":0.025, "threat":1},
	{"primary":"fire_imp",    "secondary":"skeleton",     "mix":0.28, "density":0.94, "elite":0.030, "threat":4},
	{"primary":"orc",         "secondary":"fire_imp",     "mix":0.24, "density":1.00, "elite":0.034, "threat":-1},
	{"primary":"hellhound",   "secondary":"orc",          "mix":0.25, "density":1.05, "elite":0.038, "threat":3},
	{"primary":"demon",       "secondary":"fire_imp",     "mix":0.30, "density":1.09, "elite":0.042, "threat":2},
	{"primary":"hellhound",   "secondary":"demon",        "mix":0.35, "density":1.13, "elite":0.046, "threat":5},
	# 12~17분: 빙하 — 느린 탱커와 빠른 위습의 대비
	{"primary":"mushroom",    "secondary":"ice_wisp",     "mix":0.18, "density":0.96, "elite":0.038, "threat":0},
	{"primary":"ice_wisp",    "secondary":"bat",          "mix":0.25, "density":1.02, "elite":0.042, "threat":-1},
	{"primary":"frost_golem", "secondary":"ice_wisp",     "mix":0.24, "density":1.07, "elite":0.047, "threat":1},
	{"primary":"spider",      "secondary":"mushroom",     "mix":0.28, "density":1.11, "elite":0.052, "threat":3},
	{"primary":"ice_wisp",    "secondary":"frost_golem",  "mix":0.30, "density":1.15, "elite":0.056, "threat":4},
	{"primary":"frost_golem", "secondary":"spider",       "mix":0.34, "density":1.19, "elite":0.060, "threat":5},
	# 18~23분: 공허 — 빠르고 단단한 적을 높은 혼합률로 압박
	{"primary":"spider",      "secondary":"gargoyle",      "mix":0.20, "density":1.03, "elite":0.048, "threat":2},
	{"primary":"gargoyle",    "secondary":"fire_imp",     "mix":0.26, "density":1.09, "elite":0.054, "threat":-1},
	{"primary":"void_wraith", "secondary":"spider",       "mix":0.28, "density":1.14, "elite":0.060, "threat":0},
	{"primary":"demon",       "secondary":"void_wraith",  "mix":0.30, "density":1.19, "elite":0.066, "threat":3},
	{"primary":"void_wraith", "secondary":"gargoyle",     "mix":0.34, "density":1.24, "elite":0.072, "threat":4},
	{"primary":"gargoyle",    "secondary":"demon",        "mix":0.38, "density":1.29, "elite":0.078, "threat":5},
	# 24~29분: 마왕성 — 최종 빌드 검증, 체력벽과 고속 적 동시 등장
	{"primary":"hellhound",   "secondary":"wraith_knight","mix":0.22, "density":1.10, "elite":0.060, "threat":1},
	{"primary":"wraith_knight","secondary":"demon",       "mix":0.28, "density":1.16, "elite":0.068, "threat":-1},
	{"primary":"dark_knight", "secondary":"hellhound",    "mix":0.28, "density":1.22, "elite":0.076, "threat":2},
	{"primary":"demon",       "secondary":"dark_knight",  "mix":0.34, "density":1.27, "elite":0.084, "threat":3},
	{"primary":"gargoyle",    "secondary":"wraith_knight","mix":0.38, "density":1.32, "elite":0.092, "threat":4},
	{"primary":"dark_knight", "secondary":"gargoyle",     "mix":0.42, "density":1.36, "elite":0.100, "threat":5},
]


# RPG형 지역 위협. 별도 몬스터를 쏟아내지 않고 전투 중인 몬스터와 이후 등장할
# 몬스터를 잠시 강화한다. duration이 짧아 회피·집중 공격으로 넘길 수 있어야 한다.
const MONSTER_THREAT_EVENTS := [
	{"name":"강철 피부", "duration":12.0, "attack_mult":1.00, "speed_mult":1.00,
		"damage_taken_mult":0.72, "desc":"받는 피해 -28%", "color":Color(0.52, 0.72, 0.92)},
	{"name":"광포화", "duration":12.0, "attack_mult":1.28, "speed_mult":1.00,
		"damage_taken_mult":1.00, "desc":"공격력 +28%", "color":Color(1.00, 0.32, 0.20)},
	{"name":"사냥 본능", "duration":12.0, "attack_mult":1.10, "speed_mult":1.20,
		"damage_taken_mult":1.00, "desc":"이동 속도 +20% · 공격력 +10%", "color":Color(1.00, 0.72, 0.24)},
	{"name":"전투 고양", "duration":13.0, "attack_mult":1.18, "speed_mult":1.13,
		"damage_taken_mult":1.00, "desc":"공격력 +18% · 이동 속도 +13%", "color":Color(0.96, 0.40, 0.34)},
	{"name":"마력 장막", "duration":13.0, "attack_mult":1.12, "speed_mult":1.00,
		"damage_taken_mult":0.80, "desc":"받는 피해 -20% · 공격력 +12%", "color":Color(0.64, 0.42, 0.96)},
	{"name":"정예의 기세", "duration":14.0, "attack_mult":1.22, "speed_mult":1.10,
		"damage_taken_mult":0.85, "desc":"공격력 +22% · 이동 속도 +10%", "color":Color(1.00, 0.62, 0.18)},
]

const STAGE_THREAT_AURAS := [
	"전장의 기운", "던전의 기운", "업화의 기운",
	"빙설의 기운", "공허의 기운", "마왕의 기운",
]


static func monster_threat(threat_index: int, stage: int = 0) -> Dictionary:
	var index := posmod(threat_index, MONSTER_THREAT_EVENTS.size())
	var threat: Dictionary = MONSTER_THREAT_EVENTS[index].duplicate(true)
	var aura: String = str(STAGE_THREAT_AURAS[clampi(stage, 0, STAGE_THREAT_AURAS.size() - 1)])
	threat["id"] = index
	threat["display_name"] = "%s · %s" % [aura, str(threat["name"])]
	return threat


static func wave_for_minute(minute: int, selected_stage: int = 0) -> Dictionary:
	var wave: Dictionary = WAVE_SCHEDULE[clamp(minute, 0, WAVE_SCHEDULE.size() - 1)].duplicate()
	# 0은 기존 5막 캠페인 시간표. 독립 스테이지는 선택한 로스터를 30분간 유지한다.
	if selected_stage > 0:
		var roster := stage_roster(selected_stage)
		wave["primary"] = roster[minute % roster.size()]
		wave["secondary"] = roster[(minute + 2) % roster.size()]
	return wave

# --- 몬스터 티어 (낮을수록 약함) ---
static func enemy_tiers() -> Array:
	return [
		{"name": "슬라임", "key": "slime", "shape": "blob",  "color": Color(0.40, 0.90, 0.50),
			"hp_mult": 1.0, "speed_mult": 0.60, "xp": 1, "radius": 15.0, "behavior": "splitter",
			"sprite": "res://assets/enemies/slime.png"},
		{"name": "고블린", "key": "goblin", "shape": "orc",  "color": Color(0.45, 0.75, 0.35),
			"hp_mult": 1.15, "speed_mult": 1.05, "xp": 2, "radius": 13.0,
			"sprite": "res://assets/enemies/goblin.png"},
		{"name": "박쥐",   "key": "bat",   "shape": "bat",   "color": Color(0.70, 0.40, 0.95),
			"hp_mult": 1.25, "speed_mult": 1.40, "xp": 2, "radius": 13.0,
			"sprite": "res://assets/enemies/bat.png", "weak": "holy", "resist": "dark"},
		{"name": "거미",   "key": "spider", "shape": "bat", "color": Color(0.32, 0.22, 0.38),
			"hp_mult": 1.3, "speed_mult": 1.55, "xp": 3, "radius": 13.0,
			"sprite": "res://assets/enemies/spider.png"},
		{"name": "좀비",   "key": "zombie", "shape": "blob", "color": Color(0.55, 0.65, 0.45),
			"hp_mult": 1.4, "speed_mult": 0.68, "xp": 3, "radius": 15.0,
			"sprite": "res://assets/enemies/zombie.png", "weak": "holy", "resist": "dark"},
		{"name": "구울",   "key": "ghoul", "shape": "orc", "color": Color(0.62, 0.70, 0.55),
			"hp_mult": 1.5, "speed_mult": 0.95, "xp": 3, "radius": 15.0,
			"sprite": "res://assets/enemies/ghoul.png", "weak": "holy", "resist": "dark"},
		{"name": "해골",   "key": "skeleton", "shape": "skull", "color": Color(0.92, 0.92, 0.85),
			"hp_mult": 1.6, "speed_mult": 1.00, "xp": 3, "radius": 15.0,
			"sprite": "res://assets/enemies/skeleton.png", "weak": "holy", "resist": "dark"},
		{"name": "독버섯", "key": "mushroom", "shape": "blob", "color": Color(0.6, 0.4, 0.75),
			"hp_mult": 1.9, "speed_mult": 0.58, "xp": 4, "radius": 16.0, "min_stage": 2,
			"sprite": "res://assets/enemies/mushroom.png"},
		{"name": "파이어 임프", "key": "fire_imp", "shape": "demon", "color": Color(0.95, 0.45, 0.2),
			"hp_mult": 1.9, "speed_mult": 1.0, "xp": 4, "radius": 13.0, "min_stage": 2,
			"sprite": "res://assets/enemies/fire_imp.png", "weak": "ice", "resist": "fire"},
		{"name": "오크",   "key": "orc",   "shape": "orc",   "color": Color(0.50, 0.80, 0.35),
			"hp_mult": 2.2, "speed_mult": 0.85, "xp": 4, "radius": 21.0,
			"sprite": "res://assets/enemies/orc.png"},
		{"name": "용암 두꺼비", "key": "lava_toad", "shape": "blob", "color": Color(0.80, 0.40, 0.18),
			"hp_mult": 2.4, "speed_mult": 0.62, "xp": 5, "radius": 19.0, "min_stage": 2,
			"sprite": "res://assets/enemies/lava_toad.png", "weak": "ice", "resist": "fire"},
		{"name": "헬하운드", "key": "hellhound", "shape": "demon", "color": Color(0.85, 0.35, 0.15),
			"hp_mult": 2.5, "speed_mult": 1.05, "xp": 5, "radius": 17.0, "min_stage": 2,
			"sprite": "res://assets/enemies/hellhound.png", "weak": "ice", "resist": "fire"},
		{"name": "가고일", "key": "gargoyle", "shape": "demon", "color": Color(0.5, 0.5, 0.55),
			"hp_mult": 2.8, "speed_mult": 1.12, "xp": 6, "radius": 20.0, "min_stage": 3,
			"sprite": "res://assets/enemies/gargoyle.png"},
		{"name": "데몬",   "key": "demon", "shape": "demon", "color": Color(0.95, 0.30, 0.35),
			"hp_mult": 3.0, "speed_mult": 1.02, "xp": 6, "radius": 24.0,
			"sprite": "res://assets/enemies/demon.png", "weak": "ice", "resist": "fire"},
		{"name": "서리 거미", "key": "frost_spider", "shape": "bat", "color": Color(0.65, 0.82, 0.95),
			"hp_mult": 3.2, "speed_mult": 1.35, "xp": 7, "radius": 15.0, "min_stage": 3,
			"sprite": "res://assets/enemies/frost_spider.png", "weak": "fire", "resist": "ice"},
		{"name": "아이스 위습", "key": "ice_wisp", "shape": "bat", "color": Color(0.6, 0.85, 1.0),
			"hp_mult": 3.4, "speed_mult": 1.05, "xp": 8, "radius": 14.0, "min_stage": 3,
			"sprite": "res://assets/enemies/ice_wisp.png", "weak": "fire", "resist": "ice"},
		{"name": "프로스트 골렘", "key": "frost_golem", "shape": "orc", "color": Color(0.5, 0.7, 0.95),
			"hp_mult": 4.0, "speed_mult": 0.55, "xp": 9, "radius": 25.0, "min_stage": 3,
			"sprite": "res://assets/enemies/frost_golem.png", "weak": "fire", "resist": "ice"},
		{"name": "눈알 덩어리", "key": "eye_mass", "shape": "demon", "color": Color(0.60, 0.40, 0.80),
			"hp_mult": 4.4, "speed_mult": 0.95, "xp": 10, "radius": 18.0, "min_stage": 4,
			"sprite": "res://assets/enemies/eye_mass.png", "weak": "holy", "resist": "dark"},
		{"name": "보이드 레이스", "key": "void_wraith", "shape": "demon", "color": Color(0.55, 0.35, 0.85),
			"hp_mult": 4.6, "speed_mult": 1.22, "xp": 11, "radius": 20.0, "min_stage": 4,
			"sprite": "res://assets/enemies/void_wraith.png", "weak": "holy", "resist": "dark"},
		{"name": "망령 기사", "key": "wraith_knight", "shape": "orc", "color": Color(0.4, 0.45, 0.55),
			"hp_mult": 5.2, "speed_mult": 0.88, "xp": 13, "radius": 23.0, "min_stage": 4,
			"sprite": "res://assets/enemies/wraith_knight.png", "weak": "holy", "resist": "dark"},
		{"name": "뿔 광신도", "key": "cultist", "shape": "orc", "color": Color(0.70, 0.28, 0.30),
			"hp_mult": 5.5, "speed_mult": 1.00, "xp": 13, "radius": 16.0, "min_stage": 5,
			"sprite": "res://assets/enemies/cultist.png", "weak": "holy", "resist": "dark"},
		{"name": "다크 나이트", "key": "dark_knight", "shape": "orc", "color": Color(0.35, 0.30, 0.40),
			"hp_mult": 6.0, "speed_mult": 0.82, "xp": 14, "radius": 22.0, "min_stage": 5,
			"sprite": "res://assets/enemies/dark_knight.png", "weak": "holy", "resist": "dark"},
	]

# 정예·중간보스 전용 특수 공격. 22종을 몬스터 특징 6계열로 묶는다.
# color는 전조 동안 몸을 물들이는 색이다. 도형 오버레이(원·부채꼴)는 쓰지 않는다
# (사장님: "원 같은 게 생겨서 집중도를 해친다"). 전조는 정지·몸 색·포즈 고정 셋으로만 읽힌다.
const ELITE_SPECIALS := {
	# 느리고 물컹한 것들: 몸을 부풀려 사방으로 독을 터뜨린다
	"venom_burst": {"name": "독 분출", "color": Color(0.42, 0.95, 0.32)},
	# 빠른 절지·비행: 앞쪽으로 속박 거미줄을 뱉어 발을 묶는다
	"web_snare": {"name": "속박 거미줄", "color": Color(0.78, 0.88, 1.00)},
	# 언데드·사수형: 넓은 부채꼴 일제사격
	"bone_volley": {"name": "뼈 일제사격", "color": Color(0.96, 0.92, 0.74)},
	# 화염 계열: 좁은 각도로 관통 화염을 내리 뿜는다
	"flame_lash": {"name": "화염 채찍", "color": Color(1.00, 0.45, 0.12)},
	# 거대 탱커·중장 기사: 제자리에서 지면을 내려쳐 주변을 쓸어버린다
	"ground_slam": {"name": "지면 강타", "color": Color(1.00, 0.72, 0.24)},
	# 마법·공허 계열: 느리고 큰 저주 구체로 진로를 막는다
	"hex_orb": {"name": "저주 구체", "color": Color(0.74, 0.44, 1.00)},
}
const ELITE_SPECIAL_BY_KEY := {
	"slime": "venom_burst", "zombie": "venom_burst", "ghoul": "venom_burst",
	"mushroom": "venom_burst", "lava_toad": "venom_burst",
	"spider": "web_snare", "frost_spider": "web_snare", "bat": "web_snare",
	"skeleton": "bone_volley", "goblin": "bone_volley", "cultist": "bone_volley",
	"fire_imp": "flame_lash", "hellhound": "flame_lash", "demon": "flame_lash",
	"gargoyle": "flame_lash",
	"orc": "ground_slam", "frost_golem": "ground_slam",
	"wraith_knight": "ground_slam", "dark_knight": "ground_slam",
	"ice_wisp": "hex_orb", "void_wraith": "hex_orb", "eye_mass": "hex_orb",
	# 던전 전용 정예·중간보스 (고유 키, 스프라이트는 base 몹과 공유)
	"ember_stalker": "flame_lash", "hell_enforcer": "flame_lash",
	"grave_warden": "ground_slam", "tomb_knight": "ground_slam",
	"frost_sentry": "hex_orb", "icewall_golem": "ground_slam",
	"rift_stalker": "hex_orb", "abyss_oracle": "hex_orb",
	"gate_commander": "ground_slam", "black_marshal": "ground_slam",
	"throne_guard": "flame_lash",
}


# 티어 키 → 특수 공격 정의. 없으면 빈 사전(특수 공격 없음).
static func elite_special(key: String) -> Dictionary:
	var kind := str(ELITE_SPECIAL_BY_KEY.get(key, ""))
	if kind == "" or not ELITE_SPECIALS.has(kind):
		return {}
	var info: Dictionary = (ELITE_SPECIALS[kind] as Dictionary).duplicate()
	info["kind"] = kind
	return info


# 현재 레벨·스테이지에 맞는 몬스터 티어를 가중 선택
static func pick_enemy_tier(level: int, stage: int = 1) -> Dictionary:
	var pool: Array = []
	for t in enemy_tiers():
		if stage >= int(t.get("min_stage", 1)):
			pool.append(t)
	var top: int = clamp(int((level - 1) / 3.0), 0, pool.size() - 1)
	# 고스테이지 전용 몬스터는 스테이지가 열리면 바로 등장 가능
	if stage >= 4:
		top = pool.size() - 1
	var idx := top
	if top > 0 and randf() < 0.35:
		idx = top - 1
	return pool[idx]


# 스테이지별 테마 몬스터 로스터. 심연(6+)은 순환.
# 몹 22종을 5던전 x 6칸(30칸)에 배분하므로 중복 8칸은 구조적으로 불가피하다.
# 정리 기준(사장님 요청 "던전별로 등장하는 몬스터가 다른지 체크"):
#   1) 최종 던전 마왕성의 정체성 확보 — 전용 4종(다크나이트·망령기사·광신도·가고일)을 두고
#      나머지 2칸만 지옥과 공유한다. 이전에는 6종 중 3종이 여러 던전과 겹쳐 이미 본 얼굴이었다.
#   2) 어떤 몹도 3개 던전 이상에 등장하지 않는다 — 최대 2회.
#   3) 지옥의 화염 태그 4종(임프·용암두꺼비·헬하운드·데몬)은 상성이 걸려 있어 그대로 유지한다.
#   4) 독버섯을 빙하에서 빼 부패 테마(묘지·공허)로 옮겼다. 냉기 던전에 독은 어긋났다.
#   5) 22종을 전부 사용한다. 이전에는 용암두꺼비·독버섯이 한 던전에만 있었다.
static func stage_roster(stage: int) -> Array:
	var rosters := [
		# 1 묘지: 부패·언데드 (전용 slime/zombie)
		["slime", "zombie", "ghoul", "skeleton", "bat", "mushroom"],
		# 2 지옥: 화염 (전용 fire_imp/lava_toad/hellhound/goblin)
		["fire_imp", "lava_toad", "hellhound", "demon", "orc", "goblin"],
		# 3 빙하: 냉기 (전용 ice_wisp/frost_golem)
		["ice_wisp", "frost_spider", "frost_golem", "spider", "bat", "skeleton"],
		# 4 공허: 이형·포자 (전용 eye_mass/void_wraith)
		["eye_mass", "void_wraith", "spider", "frost_spider", "ghoul", "mushroom"],
		# 5 마왕성: 마족 군단 (전용 dark_knight/wraith_knight/cultist/gargoyle)
		["dark_knight", "wraith_knight", "cultist", "demon", "gargoyle", "orc"],
	]
	return rosters[(max(1, stage) - 1) % rosters.size()]


static func tier_by_key(key: String) -> Dictionary:
	for t in enemy_tiers():
		if t["key"] == key:
			return t
	return enemy_tiers()[0]


# --- 스테이지 정의 ---
static func stages() -> Array:
	return [
		{"name": "묘지",   "boss": "boss_1", "boss_name": "묘지 수호자", "tint": Color(0.70, 0.70, 0.78),
			"element": "phys", "boss_weak": "",
			"rule": "영혼 봉인비 3곳 점령 · 2:30 무덤 기사 · 묘지 수호자 영혼 방패",
			"field_passives": ["armor", "wings", "magnet", "spinach"],
			"props": ["res://assets/props/s1_a.png", "res://assets/props/s1_b.png"]},
		{"name": "지옥",   "boss": "boss_2", "boss_name": "화염 군주", "tint": Color(0.85, 0.55, 0.50),
			"element": "fire", "boss_weak": "ice",
			"rule": "용암 균열 3개 봉인 · 2:30 용암 집행자 · 화염 갑옷 파괴",
			"field_passives": ["spinach", "tomato", "candela", "stone_mask"],
			"props": ["res://assets/props/s2_a.png", "res://assets/props/s2_b.png"]},
		{"name": "빙하",   "boss": "boss_3", "boss_name": "빙결 거상", "tint": Color(0.50, 0.65, 0.90),
			"element": "ice", "boss_weak": "fire",
			"rule": "얼어붙은 화로 3곳 점화 · 누적 냉기 관리 · 빙결 거상 얼음 갑옷 파괴",
			"field_passives": ["tome", "spellbinder", "crown", "armor"],
			"props": ["res://assets/props/s3_a.png", "res://assets/props/s3_b.png"]},
		{"name": "공허",   "boss": "boss_4", "boss_name": "공허 감시자", "tint": Color(0.60, 0.45, 0.85),
			"element": "dark", "boss_weak": "holy",
			"rule": "공허 닻 3곳 안정화 · 중력장 탈출 · 공허 감시자 분신 핵 파괴",
			"field_passives": ["duplicator", "keen_eye", "clover", "skull"],
			"props": ["res://assets/props/s4_a.png", "res://assets/props/s4_b.png"]},
		{"name": "마왕성", "boss": "boss_5", "boss_name": "마왕 아바돈", "tint": Color(0.75, 0.65, 0.55),
			"element": "dark", "boss_weak": "holy",
			"rule": "성문 관문 2곳 봉쇄전 돌파 · 2:35 흑기사 사령관 · 마왕 왕좌 보호막",
			"field_passives": ["vitality", "iron_will", "berserker", "swiftness"],
			"props": ["res://assets/props/s5_a.png", "res://assets/props/s5_b.png"]},
	]

static func stage_info(n: int) -> Dictionary:
	# 심연 모드(6스테이지+)에서는 테마가 순환
	var arr := stages()
	return arr[(n - 1) % arr.size()]


# M3 지옥 고유 정예. 일반 웨이브가 아니라 용암 균열과 함께 등장해 목표 전투를 만든다.
static func hell_elite_tier() -> Dictionary:
	return {
		"name": "잿불 추적자", "key": "ember_stalker", "shape": "demon",
		"color": Color(1.0, 0.42, 0.10), "hp_mult": 2.7, "speed_mult": 1.30,
		"xp": 10, "radius": 19.0, "behavior": "charge",
		"sprite": "res://assets/enemies/hellhound.png", "weak": "ice", "resist": "fire",
	}


# M3 지옥 중간보스 전용 티어. 일반 웨이브 풀에 섞지 않아 2:30 전투 리듬을 보장한다.
static func hell_midboss_tier() -> Dictionary:
	return {
		"name": "용암 집행자", "key": "hell_enforcer", "shape": "demon",
		"color": Color(1.0, 0.30, 0.10), "hp_mult": 4.8, "speed_mult": 0.92,
		"xp": 18, "radius": 27.0, "behavior": "charge",
		"sprite": "res://assets/enemies/demon.png", "weak": "ice", "resist": "fire",
	}


# M5-A 묘지 고유 정예. 영혼 봉인비를 지키며 등장해 점령 전투를 만든다.
# 묘지는 입문 던전이라 약점/저항 속성을 강제하지 않는다(어떤 빌드도 진행 가능).
static func graveyard_elite_tier() -> Dictionary:
	return {
		"name": "묘지 파수꾼", "key": "grave_warden", "shape": "demon",
		"color": Color(0.62, 0.78, 0.92), "hp_mult": 2.4, "speed_mult": 1.14,
		"xp": 9, "radius": 18.0, "behavior": "charge",
		"sprite": "res://assets/enemies/wraith_knight.png", "weak": "", "resist": "",
	}


# M5-A 묘지 중간보스 전용 티어. 일반 웨이브에 섞지 않아 2:30 무덤 기사 전투를 보장한다.
static func graveyard_midboss_tier() -> Dictionary:
	return {
		"name": "무덤 기사", "key": "tomb_knight", "shape": "demon",
		"color": Color(0.55, 0.70, 0.88), "hp_mult": 4.4, "speed_mult": 0.96,
		"xp": 16, "radius": 26.0, "behavior": "charge",
		"sprite": "res://assets/enemies/dark_knight.png", "weak": "", "resist": "",
	}


# M5-B 빙하 화로를 지키는 원거리 정예. 투사체 둔화와 화로 해빙을 동시에 판단하게 한다.
static func glacier_elite_tier() -> Dictionary:
	return {
		"name": "서리 감시자", "key": "frost_sentry", "shape": "demon",
		"color": Color(0.58, 0.84, 1.0), "hp_mult": 3.0, "speed_mult": 1.08,
		"xp": 11, "radius": 18.0, "behavior": "ranged", "shot_chill": true,
		"sprite": "res://assets/enemies/ice_wisp.png", "weak": "fire", "resist": "ice",
	}


# M5-B 빙하 중간보스. 일반 로스터와 분리해 2:35의 돌진 전투를 보장한다.
static func glacier_midboss_tier() -> Dictionary:
	return {
		"name": "빙벽 골렘", "key": "icewall_golem", "shape": "orc",
		"color": Color(0.48, 0.72, 0.98), "hp_mult": 5.2, "speed_mult": 0.78,
		"xp": 20, "radius": 29.0, "behavior": "charge",
		"sprite": "res://assets/enemies/frost_golem.png", "weak": "fire", "resist": "ice",
	}


# M5-C 공허 닻을 지키는 돌진 정예. void_wraith 스프라이트와 애니메이션을 재사용한다.
static func void_elite_tier() -> Dictionary:
	return {
		"name": "균열 추적자", "key": "rift_stalker", "shape": "demon",
		"color": Color(0.68, 0.38, 0.96), "hp_mult": 3.3, "speed_mult": 1.24,
		"xp": 12, "radius": 19.0, "behavior": "charge",
		"sprite": "res://assets/enemies/void_wraith.png", "weak": "holy", "resist": "dark",
	}


# M5-C 공허 중간보스. 원거리 투사체와 추종 중력장이 이동 경로 선택을 압박한다.
static func void_midboss_tier() -> Dictionary:
	return {
		"name": "심연의 눈", "key": "abyss_oracle", "shape": "demon",
		"color": Color(0.72, 0.42, 0.92), "hp_mult": 5.6, "speed_mult": 0.88,
		"xp": 21, "radius": 27.0, "behavior": "ranged", "damage_source": "void_boss",
		"sprite": "res://assets/enemies/eye_mass.png", "weak": "holy", "resist": "dark",
	}


# M5-D 마왕성 성문 봉쇄전을 지키는 정예. 진입 시 여럿이 동시에 소환되므로 개체는
# 다른 던전 정예보다 가볍게 잡고 수로 압박한다. wraith_knight 아트·애니메이션 재사용.
static func castle_elite_tier() -> Dictionary:
	return {
		"name": "성문 지휘관", "key": "gate_commander", "shape": "orc",
		"color": Color(0.72, 0.60, 0.52), "hp_mult": 2.6, "speed_mult": 1.10,
		"xp": 11, "radius": 19.0, "behavior": "charge",
		"sprite": "res://assets/enemies/wraith_knight.png", "weak": "holy", "resist": "dark",
	}


# M5-D 마왕성 중간보스. 일반 웨이브에 섞지 않아 2:35 흑기사 전투를 보장한다.
static func castle_midboss_tier() -> Dictionary:
	return {
		"name": "흑기사 사령관", "key": "black_marshal", "shape": "orc",
		"color": Color(0.52, 0.44, 0.56), "hp_mult": 5.4, "speed_mult": 0.90,
		"xp": 20, "radius": 28.0, "behavior": "charge",
		"sprite": "res://assets/enemies/dark_knight.png", "weak": "holy", "resist": "dark",
	}


# 마왕 왕좌 페이즈에서 소환되는 지휘관. 이들이 살아 있는 동안 마왕 보호막에 피해가 없다.
# 보호막 자체가 체력 게이트이므로 지휘관은 단단하기보다 빠르게 압박한다.
static func castle_guard_tier() -> Dictionary:
	return {
		"name": "왕좌 지휘관", "key": "throne_guard", "shape": "demon",
		"color": Color(0.88, 0.42, 0.36), "hp_mult": 3.4, "speed_mult": 1.16,
		"xp": 13, "radius": 20.0, "behavior": "charge",
		"sprite": "res://assets/enemies/demon.png", "weak": "holy", "resist": "dark",
	}


# 맵별 진입 방향과 지역 위협 순환으로 스테이지 정체성을 만든다.
static func stage_spawn_profile(stage: int) -> Dictionary:
	var profiles := [
		{"mode": "cross", "threats": [1, 2, 0, 1], "breakables": 4},
		{"mode": "bridge", "threats": [1, 3, 2, 4], "breakables": 4},
		{"mode": "wide", "threats": [0, 2, 4, 0], "breakables": 3},
		{"mode": "tower", "threats": [4, 2, 5, 4], "breakables": 3},
		{"mode": "castle", "threats": [3, 5, 4, 5], "breakables": 4},
	]
	return profiles[(maxi(1, stage) - 1) % profiles.size()]


# --- 주인공 진화 단계 (레벨 / 3 → 0~3단계) ---
# (구세대 hero_stages() 테이블은 캐릭터별 char_stages로 대체되어 제거 — 인덱스 함수만 사용)
static func hero_stage_for_level(level: int) -> int:
	# 진화 시점: Lv10 / 30 / 50 / 75 → 1 / 2 / 3 / 4단계 (0=기본)
	if level >= 75:
		return 4
	if level >= 50:
		return 3
	if level >= 30:
		return 2
	if level >= 10:
		return 1
	return 0

# 진화 단계별 능력치 배수 (공격력·효과에 곱)
static func stage_power(stage: int) -> float:
	var p := [1.0, 1.12, 1.26, 1.42, 1.62]
	return p[clamp(stage, 0, 4)]


# --- 플레이어 캐릭터 ---
static func characters() -> Array:
	# melee/ranged: 해당 계열 무기 피해 배수 (특화 빌드 유도)
	# range: 투사체 사거리/범위 배수, cd: 공격 속도(낮을수록 빠름)
	return [
		# growth: 뱀서식 레벨 성장 특성. per레벨마다 amt씩, max단계까지 (안토니오 "10레벨마다 피해 +10%, 최대 +50%").
		#   캐릭터 차별화 = 기본 스탯 배수(hp/speed/cd/range/melee/ranged) + 고유 시작 무기 + 이 성장 특성.
		#   직업 전용 스킬은 없음 — 무기 풀은 전 캐릭터 공유 (뱀서 원칙).
		{"key": "corvius", "name": "코르비우스", "weapon": "poison_cloud",
			"desc": "역병의사 · 원거리 캐스터\n독안개 · 역병 확산",
			"hp": 0.85, "speed": 1.0, "cd": 0.92, "range": 1.1,
			"melee": 0.85, "ranged": 1.2,
			"trait": "역병 확산", "trait_desc": "10레벨마다 효과 범위 +5% (최대 +25%)",
			"growth": {"stat": "area", "per": 10, "amt": 0.05, "max": 5}},
		{"key": "gustavo", "name": "구스타보", "weapon": "cleave",
			"desc": "미친 정육점주인 · 근접 탱커\n큰 식칼 · 흡혈",
			"hp": 1.4, "speed": 0.9, "cd": 1.0, "range": 0.8,
			"melee": 1.35, "ranged": 0.7,
			"trait": "고기 흡혈", "trait_desc": "5레벨마다 재생 +0.3/초 (최대 +3.0)",
			"growth": {"stat": "regen", "per": 5, "amt": 0.3, "max": 10}},
		{"key": "serafina", "name": "세라피나", "weapon": "aura", "weapon2": "holy_cross",
			"desc": "타락한 수녀 · 서포터\n오라 + 유도 성십자 · 가호",
			"hp": 1.15, "speed": 0.95, "cd": 1.0, "range": 1.0,
			"melee": 1.0, "ranged": 0.9,
			"trait": "성스러운 가호", "trait_desc": "성십자 항상 장착 · 5레벨마다 경험치 +4% (최대 +40%)",
			"growth": {"stat": "xp", "per": 5, "amt": 0.04, "max": 10}},
		{"key": "valentino", "name": "발렌티노", "weapon": "blood_sword",
			"unlock": "win_gustavo", "unlock_desc": "구스타보로 승리",
			"desc": "뱀파이어 백작 · 근접\n흡혈검 · 치명",
			"hp": 1.0, "speed": 1.0, "cd": 0.95, "range": 0.95,
			"melee": 1.2, "ranged": 0.85,
			"trait": "흡혈귀", "trait_desc": "10레벨마다 치명타 +5% (최대 +25%)",
			"growth": {"stat": "crit", "per": 10, "amt": 0.05, "max": 5}},
		{"key": "pixie", "name": "픽시", "weapon": "fireball",
			"unlock": "survivor", "unlock_desc": "한 판에서 15분 생존",
			"desc": "꼬마 마녀 · 유리대포\n화염구 · 고화력 저체력",
			"hp": 0.75, "speed": 1.0, "cd": 0.92, "range": 1.15,
			"melee": 0.8, "ranged": 1.2,
			"trait": "유리대포", "trait_desc": "10레벨마다 피해량 +10% (최대 +50%)",
			"growth": {"stat": "damage", "per": 10, "amt": 0.10, "max": 5}},
		# key는 에셋 경로(hero/django_1.png, anim/django_1_walk)에 묶여 있어 유지.
		# 표시명·설명만 뽑힌 디자인(삼각모+붉은 코트+대형 리볼버)에 맞춰 교체.
		{"key": "django", "name": "바르톨로", "weapon": "spread_shot",
			"unlock": "slayer", "unlock_desc": "한 판에서 800킬",
			"desc": "유령 노상강도 · 초고속 연사\n삼각모 · 대형 산탄총",
			"hp": 0.95, "speed": 1.0, "cd": 0.9, "range": 1.1,
			"melee": 0.6, "ranged": 1.2,
			"trait": "속사", "trait_desc": "10레벨마다 쿨다운 -3% (최대 -15%)",
			"growth": {"stat": "cooldown", "per": 10, "amt": 0.03, "max": 5}},
		# 뽑힌 디자인이 언데드 해골 → 태엽 자동인형 컨셉 폐기, 낙뢰 → 뼈나선으로.
		{"key": "bolt", "name": "오사리오", "weapon": "bone_spiral",
			"unlock": "first_win", "unlock_desc": "첫 승리 달성",
			"desc": "납골당에서 걸어나온 해골 · 정밀\n뼈나선 · 관통",
			"hp": 1.05, "speed": 0.95, "cd": 0.95, "range": 1.05,
			"melee": 0.9, "ranged": 1.1,
			"trait": "뼈 사리", "trait_desc": "25레벨마다 투사체 +1 (최대 +2)",
			"growth": {"stat": "amount", "per": 25, "amt": 1.0, "max": 2}},
		{"key": "morgana", "name": "모르가나", "weapon": "moonlight",
			"unlock": "hard_clear", "unlock_desc": "어려움 난이도 승리",
			"desc": "떠도는 유령 소녀 · 배회\n월광 · 초고속 이동",
			"hp": 0.85, "speed": 1.18, "cd": 0.95, "range": 1.05,
			"melee": 0.9, "ranged": 1.05,
			"trait": "배회", "trait_desc": "5레벨마다 이동속도 +2% (최대 +20%)",
			"growth": {"stat": "speed", "per": 5, "amt": 0.02, "max": 10}},
		{"key": "isolde", "name": "이졸데", "weapon": "ice_lance",
			"unlock": "combo_master", "unlock_desc": "유니온 무기 1개 완성",
			"desc": "얼음 관에서 깨어난 서리 마녀 · 냉기 캐스터\n얼음창 · 혹한의 결계",
			"hp": 0.9, "speed": 0.95, "cd": 0.95, "range": 1.1,
			"melee": 0.8, "ranged": 1.15,
			"trait": "혹한", "trait_desc": "10레벨마다 방어력 +1 (최대 +5)",
			"growth": {"stat": "armor", "per": 10, "amt": 1.0, "max": 5}},
		{"key": "grimble", "name": "그림블", "weapon": "chain_bolt",
			"unlock": "legend_weapon", "unlock_desc": "무기 1개 진화",
			"desc": "늪에서 기어나온 부두술사 · 뇌전 캐스터\n연쇄뇌전 · 저주받은 공물",
			"hp": 0.9, "speed": 0.98, "cd": 0.93, "range": 1.05,
			"melee": 0.75, "ranged": 1.15,
			"trait": "저주받은 공물", "trait_desc": "5레벨마다 골드 획득 +5% (최대 +50%)",
			"growth": {"stat": "greed", "per": 5, "amt": 0.05, "max": 10}},
		{"key": "mordek", "name": "모르덱", "weapon": "axe",
			"unlock": "boss_slayer", "unlock_desc": "한 판에서 보스 4마리 처치",
			"desc": "두건 쓴 거구의 처형인 · 도끼 탱커\n전투도끼 · 사슬 갈고리",
			"hp": 1.3, "speed": 0.88, "cd": 1.02, "range": 0.85,
			"melee": 1.3, "ranged": 0.65,
			"trait": "사슬 갈고리", "trait_desc": "5레벨마다 자석 범위 +10 (최대 +100)",
			"growth": {"stat": "magnet", "per": 5, "amt": 10.0, "max": 10}},
	]

# 캐릭터별 진화 5단계 외형 데이터
static func char_stages(ckey: String) -> Array:
	var scales := [1.0, 1.12, 1.26, 1.42, 1.58]
	var auras := [Color(0, 0, 0, 0), Color(0.4, 0.9, 1.0, 0.22),
		Color(0.7, 0.5, 1.0, 0.28), Color(1.0, 0.8, 0.2, 0.34),
		Color(1.0, 0.95, 0.7, 0.42)]
	var cols := {"corvius": Color(0.45, 0.75, 0.55), "gustavo": Color(0.80, 0.35, 0.35),
		"serafina": Color(1.0, 0.9, 0.6), "valentino": Color(0.70, 0.20, 0.30),
		"pixie": Color(0.75, 0.45, 0.95), "django": Color(0.85, 0.40, 0.25),
		"bolt": Color(0.85, 0.85, 0.78), "morgana": Color(0.6, 0.85, 1.0),
		"isolde": Color(0.55, 0.78, 0.98), "grimble": Color(0.58, 0.72, 0.40),
		"mordek": Color(0.62, 0.60, 0.64)}
	var arr: Array = []
	for i in 5:
		arr.append({
			"key": "%s_%d" % [ckey, i + 1],
			"sprite": "res://assets/hero/%s_%d.png" % [ckey, i + 1],
			"scale": scales[i], "aura": auras[i],
			"color": cols.get(ckey, Color(0.25, 0.70, 1.00)),
		})
	return arr


# --- 난이도 프리셋 ---
static func difficulties() -> Array:
	return [
		{"key": "easy",   "label": "쉬움",
			"desc": "넉넉한 체력 · 약하고 느린 적 · 장비 보상 감소",
			"player_hp": 1.85, "enemy_hp": 0.42, "enemy_speed": 0.68, "spawn": 1.35, "loot": 1.50,
			"gold": 0.80, "xp": 1.00, "gear": 0.80, "rarity_luck": 0.0, "reward_tag": "안정",
			"color": Color(0.45, 0.85, 0.55)},
		{"key": "normal", "label": "보통",
			"desc": "균형 잡힌 표준 위험과 보상",
			"player_hp": 1.10, "enemy_hp": 0.90, "enemy_speed": 0.96, "spawn": 1.08, "loot": 1.00,
			"gold": 1.00, "xp": 1.00, "gear": 1.00, "rarity_luck": 0.0, "reward_tag": "표준",
			"color": Color(0.5, 0.75, 1.0)},
		{"key": "hard",   "label": "어려움",
			"desc": "강한 적과 빠른 공세 · 골드와 장비 보상 증가",
			"player_hp": 0.85, "enemy_hp": 1.35, "enemy_speed": 1.18, "spawn": 0.78, "loot": 0.72,
			"gold": 1.25, "xp": 1.12, "gear": 1.40, "rarity_luck": 2.0, "reward_tag": "보상 +",
			"color": Color(1.0, 0.45, 0.45)},
		{"key": "nightmare", "label": "악몽",
			"desc": "극한 압박 · 최고 보상과 고등급 장비",
			"player_hp": 0.70, "enemy_hp": 1.75, "enemy_speed": 1.30, "spawn": 0.62, "loot": 0.50,
			"gold": 1.55, "xp": 1.25, "gear": 1.80, "rarity_luck": 4.0, "reward_tag": "보상 ++",
			"color": Color(0.82, 0.42, 1.0)},
	]
