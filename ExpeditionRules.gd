class_name ExpeditionRules
extends RefCounted

# M4 원정의 순수 규칙. Main의 전투/UI와 분리해 경로·추출·보상 불변식을
# 빠른 회귀 테스트로 잠글 수 있게 한다.
const FLOOR_COUNT := 3
const CLEAR_EXTRACT_LIMIT := 2
const DEATH_INSURANCE_LIMIT := 1
const FLOOR_CLEAR_STAT_POINTS := 1
const MERCHANT_COST := 45
const BOSS_CRAFT_COST := 5

const NODE_DEFS := {
	"camp": {
		"name": "회복 캠프",
		"glyph": "♨",
		"color": Color(0.45, 0.92, 0.66),
		"desc": "최대 체력의 45% 회복 · 능력치 포인트 +1",
	},
	"merchant": {
		"name": "떠돌이 상인",
		"glyph": "◆",
		"color": Color(1.0, 0.80, 0.34),
		"desc": "%d G로 다음 층용 고급 장비 구매" % MERCHANT_COST,
	},
	"event": {
		"name": "저주받은 제단",
		"glyph": "✦",
		"color": Color(0.82, 0.52, 1.0),
		"desc": "최대 체력 18%를 바쳐 에픽 장비와 70 G 획득",
	},
}

const FRAGMENT_DEFS := {
	1: {"key": "grave", "name": "망자의 골편"},
	2: {"key": "inferno", "name": "화염핵 파편"},
	3: {"key": "glacier", "name": "빙정 파편"},
	4: {"key": "void", "name": "공허 결정"},
	5: {"key": "citadel", "name": "마왕의 인장편"},
}


static func wrap_stage(stage: int) -> int:
	return posmod(stage - 1, 5) + 1


# 각 노드는 서비스와 다음 전장을 함께 결정한다. 절차 생성 대신 기존 5개
# 수제 레이아웃을 고정 간선으로 연결해 선택 결과를 읽기 쉽게 유지한다.
static func route_options(current_stage: int, cleared_floor: int) -> Array:
	if cleared_floor < 1 or cleared_floor >= FLOOR_COUNT:
		return []
	var node_keys := ["camp", "merchant", "event"]
	var offsets := [1, 2, 3] if cleared_floor == 1 else [2, 1, 3]
	var options: Array = []
	for i in node_keys.size():
		var node_key: String = node_keys[i]
		var option: Dictionary = NODE_DEFS[node_key].duplicate(true)
		option["key"] = node_key
		option["target_stage"] = wrap_stage(current_stage + offsets[i])
		options.append(option)
	return options


static func extraction_limit(won: bool) -> int:
	return CLEAR_EXTRACT_LIMIT if won else DEATH_INSURANCE_LIMIT


static func boss_fragment(stage: int) -> Dictionary:
	return FRAGMENT_DEFS[wrap_stage(stage)].duplicate(true)


static func fragment_reward(cleared_floor: int) -> int:
	return 3 if cleared_floor >= FLOOR_COUNT else 1


static func floor_pressure(cleared_floor: int) -> float:
	return 1.0 + 0.18 * float(clampi(cleared_floor, 1, FLOOR_COUNT) - 1)


static func merchant_rarity(cleared_floor: int) -> String:
	return "epic" if cleared_floor >= 2 else "rare"
