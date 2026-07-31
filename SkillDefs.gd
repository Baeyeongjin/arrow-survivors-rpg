class_name SkillDefs
extends RefCounted

# 스킬 = 아키타입 8종 × 원소 9종.
#
# 72개를 손으로 쓰지 않는다. 아키타입이 "무엇을 하는가"(전달 방식·판정·쿨다운)를 정하고,
# 원소가 "무슨 색이며 무슨 규칙을 덧붙이는가"를 정한다. FxMatrix와 같은 구조라
# 이펙트도 자동으로 따라온다(아키타입의 form + 캐릭터 원소).
#
# 원소 효과는 배수 증가가 아니라 규칙 변경이다(사장님 원칙: 범위·피해만 커지는 건
# 특수효과가 아니다). 화상 도트, 둔화, 흡혈, 자힐, 밀어내기, 관통, 기절, 연쇄, 치명.

# 아키타입 8종. form은 FxMatrix 조회 키와 같다.
#   slot: "basic"은 마우스 좌클릭 기본 공격, 나머지는 QWER에 장착 가능
#   cd: 기본 쿨다운(초) · dmg: 기본 피해 계수 · range/radius: 판정 크기(px)
const ARCHETYPES := {
	"bolt": {
		"name": "탄", "form": "bolt", "slot": "basic",
		"cd": 0.42, "dmg": 1.0, "range": 300.0, "radius": 11.0,
		"desc": "커서 방향으로 관통 투사체를 쏜다",
	},
	# 근접 기본 공격. 원거리형과 같은 탄을 쏘는 게 어색하다는 지적(사장님)에 맞춰
	# 근접 캐릭터는 투사체 대신 눈앞을 벤다. form이 slash라 이펙트도 탄이 아닌 베기다.
	# bolt보다 느리고(0.52) 세지만(1.5) 사거리가 1/3이라 붙어야 한다 — 그게 근접의 값이다.
	"swing": {
		"name": "휘두르기", "form": "slash", "slot": "basic",
		"cd": 0.52, "dmg": 1.5, "range": 104.0, "radius": 0.0, "arc": 2.1,
		"desc": "눈앞을 짧게 휘둘러 벤다",
	},
	"slash": {
		"name": "베기", "form": "slash", "slot": "skill",
		"cd": 3.2, "dmg": 2.4, "range": 132.0, "radius": 0.0, "arc": 1.5,
		"desc": "전방 부채꼴을 베어 밀어낸다",
	},
	"burst": {
		"name": "작렬", "form": "impact", "slot": "skill",
		"cd": 5.0, "dmg": 3.1, "range": 300.0, "radius": 108.0,
		"desc": "커서 위치를 즉발로 터뜨린다",
	},
	"field": {
		"name": "장판", "form": "zone", "slot": "skill",
		"cd": 8.5, "dmg": 0.9, "range": 300.0, "radius": 118.0, "duration": 4.5,
		"desc": "커서 위치에 지속 피해 지대를 남긴다",
	},
	"ward": {
		"name": "보호", "form": "ward", "slot": "skill",
		"cd": 12.0, "dmg": 0.0, "range": 0.0, "radius": 96.0, "duration": 5.0,
		"desc": "자신을 감싸는 보호막을 두른다",
	},
	"nova": {
		"name": "분출", "form": "cast", "slot": "skill",
		"cd": 6.5, "dmg": 2.2, "range": 0.0, "radius": 142.0,
		"desc": "자기 주위로 터뜨려 밀어낸다",
	},
	# 대형 스킬 2종. 캐릭터 궁극기(마우스 우클릭 · 게이지 소모)와는 별개로, 긴 쿨다운을
	# 대가로 한 방이 큰 Q/E/R/F 스킬이다. 궁극기는 게이지가 자원이고 이쪽은 쿨다운이다.
	"ruin": {
		"name": "파멸", "form": "impact", "slot": "heavy", "heavy": true,
		"cd": 24.0, "dmg": 6.5, "range": 320.0, "radius": 176.0,
		"desc": "커서 위치에 대형 폭발 (긴 쿨다운)",
	},
	"aegis": {
		"name": "결계", "form": "zone", "slot": "heavy", "heavy": true,
		"cd": 28.0, "dmg": 1.6, "range": 260.0, "radius": 192.0, "duration": 7.0,
		"desc": "넓은 지속 결계를 펼친다 (긴 쿨다운)",
	},
}

# 원소 9종. effect는 스킬이 적중했을 때 덧붙는 규칙이고, 배수가 아니다.
const ELEMENT_TRAITS := {
	"fire":  {"name": "화염", "effect": "burn",    "desc": "3초 화상 (초당 피해)"},
	"ice":   {"name": "냉기", "effect": "chill",   "desc": "2.5초 둔화 35%"},
	"dark":  {"name": "어둠", "effect": "drain",   "desc": "준 피해의 12% 흡혈"},
	"holy":  {"name": "신성", "effect": "mend",    "desc": "적중당 최대체력 1% 회복"},
	"water": {"name": "물",   "effect": "push",    "desc": "강한 밀어내기 + 0.8초 둔화"},
	"wind":  {"name": "바람", "effect": "pierce",  "desc": "관통 +2 · 시전 후 0.6초 가속"},
	"earth": {"name": "대지", "effect": "stun",    "desc": "0.7초 기절"},
	"elec":  {"name": "전기", "effect": "chain",   "desc": "주변 2명에게 연쇄"},
	"phys":  {"name": "물리", "effect": "execute", "desc": "치명 +20% · 처형 피해"},
}

# 기본 공격은 원소(=캐릭터)마다 근접·원거리로 갈린다. GameConfig의 melee/ranged
# 배수가 높은 쪽을 그대로 따랐다 — 모르덱(1.3/0.65)·구스타보(1.35/0.7)·세라피나(1.0/0.9)가
# 근접, 나머지 6명이 원거리다. 스탯과 손맛이 어긋나면 캐릭터를 고를 이유가 없다.
const BASIC_BY_ELEMENT := {
	"phys": "swing", "earth": "swing", "holy": "swing",
	"fire": "bolt", "ice": "bolt", "dark": "bolt", "water": "bolt",
	"wind": "bolt", "elec": "bolt",
}

# 캐릭터 9명 = 원소 9종 1:1. 이펙트도 스킬도 캐릭터를 따라간다.
const CHAR_ELEMENT := {
	"pixie": "fire", "isolde": "ice", "corvius": "dark", "serafina": "holy",
	"morgana": "water", "django": "wind", "gustavo": "earth", "bolt": "elec",
	"mordek": "phys",
}

# 스킬 슬롯 4개. QWER가 아니라 Q/E/R/F다 — W는 WASD 이동과 겹친다(사장님 지적).
# F는 WASD를 잡은 왼손 검지가 그대로 닿아 이동 중에도 누를 수 있다.
# 기본 공격(마우스 좌클릭)과 회피(Space)는 슬롯을 쓰지 않는다.
const SLOT_KEYS := ["q", "e", "r", "f"]
const SLOT_LABEL := {"q": "Q", "e": "E", "r": "R", "f": "F"}
const MAX_SKILL_LEVEL := 5


# 원소 효과의 짧은 이름. 캐릭터 상세처럼 좁은 칸에 쓴다(긴 desc는 잘린다).
const EFFECT_NAME := {
	"burn": "화상", "chill": "둔화", "drain": "흡혈", "mend": "자힐", "push": "밀어내기",
	"pierce": "관통", "stun": "기절", "chain": "연쇄", "execute": "처형",
}


static func archetype_keys() -> Array:
	return ARCHETYPES.keys()


static func elements() -> Array:
	return ELEMENT_TRAITS.keys()


static func element_of(char_key: String) -> String:
	return str(CHAR_ELEMENT.get(char_key, "phys"))


# 스킬 하나의 완성된 정의. 아키타입 + 원소를 합쳐 만든다.
# level은 1부터. 강화는 피해와 쿨다운에만 붙고 판정 크기는 그대로 둔다
# (사장님 원칙: 범위가 넓어지는 성장은 화면을 덮고 판단을 없앤다).
static func build(archetype: String, element: String, level: int = 1) -> Dictionary:
	if not ARCHETYPES.has(archetype):
		return {}
	var base: Dictionary = (ARCHETYPES[archetype] as Dictionary).duplicate(true)
	var elem := element if ELEMENT_TRAITS.has(element) else "phys"
	var trait_row: Dictionary = ELEMENT_TRAITS[elem]
	var lv := clampi(level, 1, MAX_SKILL_LEVEL)
	var growth := 1.0 + 0.22 * float(lv - 1)      # Lv5에서 피해 1.88배
	var haste := 1.0 - 0.06 * float(lv - 1)       # Lv5에서 쿨다운 24% 단축

	base["key"] = "%s_%s" % [elem, archetype]
	base["archetype"] = archetype
	base["element"] = elem
	base["level"] = lv
	base["dmg"] = float(base["dmg"]) * growth
	base["cd"] = float(base["cd"]) * haste
	base["effect"] = str(trait_row["effect"])
	base["name"] = "%s %s" % [str(trait_row["name"]), str(base["name"])]
	base["desc"] = "%s · %s" % [str(base["desc"]), str(trait_row["desc"])]
	base["fx"] = FxMatrix.resolve(str(base["form"]), elem, bool(base.get("heavy", false)))
	return base


# 캐릭터가 배울 수 있는 스킬 전체(기본 공격 제외). 레벨업 카드가 여기서 뽑는다.
# 기본 공격은 전부(bolt·swing) 빠진다 — 자기 것은 처음부터 갖고 있고 남의 것은 못 배운다.
static func learnable(element: String) -> Array:
	var out: Array = []
	for key in ARCHETYPES:
		if str((ARCHETYPES[key] as Dictionary).get("slot", "skill")) == "basic":
			continue
		out.append(key)
	return out


# 이 원소(=캐릭터)의 기본 공격 아키타입.
static func basic_archetype(element: String = "") -> String:
	return str(BASIC_BY_ELEMENT.get(element, "bolt"))


# 자기 중심·근접 판정인가. 캐릭터의 근접·원거리 피해 배수를 어느 쪽에 걸지 가른다.
static func is_melee(archetype: String) -> bool:
	if not ARCHETYPES.has(archetype):
		return false
	return float((ARCHETYPES[archetype] as Dictionary).get("range", 0.0)) <= 140.0
