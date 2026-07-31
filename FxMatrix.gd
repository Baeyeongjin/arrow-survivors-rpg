class_name FxMatrix
extends RefCounted

# 이펙트를 "무기 이름"이 아니라 "형태 × 원소"로 조회한다.
#
# 예전에는 무기마다 전용 이펙트 이름이 박혀 있었다(fx_inferno, fx_judgment, ...).
# 그래서 무기를 추가할 때마다 아트가 필요했고, 43종 중 실제로는 5종이 죽어 있었으며
# 투사체 애니 17종은 폴더 자체가 없어 정지 아이콘으로 날아가고 있었다.
#
# 새 규칙(사장님 결정):
#   무기 = 형태를 정한다 (어떻게 나가는가)
#   캐릭터 = 원소를 정한다 (무슨 색·무슨 속성인가)
#   이펙트 = FORMS[형태][원소]
#
# 이러면 같은 캐릭터는 어떤 무기를 들어도 항상 자기 색으로 싸우고, 무기를 늘려도
# 이펙트는 늘지 않는다. 자산은 AFGameAssets VFX 팩(64px 6프레임)이다.

# 게임 원소 5종. 팩의 Electricity는 번개 계열 무기가 쓰라고 elec으로 함께 들여왔다.
const ELEMENTS := ["phys", "fire", "ice", "dark", "holy"]
const FALLBACK_ELEMENT := "phys"

# 형태 6종. 무기가 자기 전달 방식에 맞는 것을 고른다.
#   cast    발동 순간, 플레이어 자리에서 터진다
#   bolt    날아가는 투사체 본체 (Arrow.anim_dir)
#   impact  적중 지점
#   slash   근접 호를 그리는 베기
#   zone    바닥에 남는 장판·오라
#   ward    보호·버프 (자기 강화)
# phys는 처음에 Explosion 폴더(vfx_boom_*)를 썼는데, 실제 렌더로 비교해 보니
# 화염과 똑같은 주황 폭발이 나와 캐릭터 구분이 안 됐다. 흙·바위(Earth)와 순수 베기
# (Attack Slash)로 갈아 물리에 강철·대지 정체성을 줬다.
const FORMS := {
	"cast": {
		"phys": "vfx_phys_005",
		"fire": "vfx_fire_flamme",
		"ice": "vfx_ice_claw",
		"dark": "vfx_dark_spin",
		"holy": "vfx_holy_wings",
	},
	"bolt": {
		"phys": "vfx_earth_rock",
		"fire": "vfx_fire_ball",
		"ice": "vfx_ice_ball",
		"dark": "vfx_dark_ball",
		"holy": "vfx_holy_ball",
	},
	"impact": {
		"phys": "vfx_phys_002",
		"fire": "vfx_fire_explosion1",
		"ice": "vfx_ice_rock",
		"dark": "vfx_dark_explosion1",
		"holy": "vfx_holy_cross",
	},
	"slash": {
		"phys": "vfx_phys_003",
		"fire": "vfx_fire_slash",
		"ice": "vfx_ice_slash",
		"dark": "vfx_dark_slash",
		"holy": "vfx_holy_slash",
	},
	"zone": {
		"phys": "vfx_earth_spin",
		"fire": "vfx_fire_pit",
		"ice": "vfx_ice_spike",
		"dark": "vfx_dark_portal",
		"holy": "vfx_holy_blessing",
	},
	"ward": {
		"phys": "vfx_earth_shield",
		"fire": "vfx_fire_shield",
		"ice": "vfx_ice_shield",
		"dark": "vfx_dark_shield",
		"holy": "vfx_holy_shield",
	},
}

# 같은 형태 안에서 더 크고 무거운 변형. 궁극기·보스 패턴처럼 "이건 큰 거다"를
# 알려야 할 때만 쓴다. 없으면 기본 형태로 떨어진다.
const HEAVY := {
	"impact": {
		"phys": "vfx_boom_03",
		"fire": "vfx_fire_explosion2",
		"ice": "vfx_ice_slam",
		"dark": "vfx_dark_explosion2",
		"holy": "vfx_holy_slash2",
	},
	"zone": {
		"phys": "vfx_earth_grow",
		"fire": "vfx_fire_tornado",
		"ice": "vfx_ice_projectile",
		"dark": "vfx_dark_blackhole",
		"holy": "vfx_holy_projectile",
	},
}


static func normalize_element(element: String) -> String:
	return element if element in ELEMENTS else FALLBACK_ELEMENT


# 형태 + 원소 -> 이펙트 폴더 이름. 없으면 빈 문자열(호출부가 조용히 건너뛴다).
static func resolve(form: String, element: String, heavy: bool = false) -> String:
	var elem := normalize_element(element)
	if heavy and HEAVY.has(form):
		var heavy_row: Dictionary = HEAVY[form]
		if heavy_row.has(elem):
			return str(heavy_row[elem])
	if not FORMS.has(form):
		return ""
	var row: Dictionary = FORMS[form]
	return str(row.get(elem, ""))


# 자산 경로까지. Arrow.anim_dir처럼 경로를 요구하는 곳에서 쓴다.
static func resolve_path(form: String, element: String, heavy: bool = false) -> String:
	var name := resolve(form, element, heavy)
	return "" if name == "" else "res://assets/anim/%s" % name
