class_name FxMatrix
extends RefCounted

# 이펙트를 "무기 이름"이 아니라 "형태 × 원소"로 조회한다.
#
# 예전에는 무기마다 전용 이펙트 이름이 박혀 있었다(fx_inferno, fx_judgment, ...).
# 그래서 무기를 추가할 때마다 아트가 필요했고, 43종 중 5종은 죽어 있었으며
# 투사체 애니 17종은 폴더 자체가 없어 정지 아이콘으로 날아가고 있었다.
#
# 새 규칙(사장님 결정):
#   무기 = 형태를 정한다 (어떻게 나가는가)
#   캐릭터 = 원소를 정한다 (무슨 색·무슨 속성인가)
#   이펙트 = FORMS[형태][원소]
#
# 자산은 AFGameAssets VFX 팩(구매, 64px 6프레임)이다.
#
# 형태를 8개로 못 늘리는 이유: 팩은 원소마다 8종이지만 형태가 통일돼 있지 않다.
# 9원소 전부에 있는 건 Ball·Shield·Slash 3종뿐이고 Explosion이 5원소, 나머지는
# 원소 고유다(Tornado / BlackHole / Wings / Cascade / Turbine / Lava / Lighting).
# 그래서 공통 6형태로 일반 전투를 덮고, 원소 고유 항목은 SIGNATURE로 빼
# 캐릭터의 시그니처 기술에 쓴다. 억지로 8형태를 맞추면 안 어울리는 배정이 생긴다.

# 원소 9종. 물·바람·대지·전기는 팩을 다 쓰려고 확장했다(사장님: "각 다 쓸 수 있으면 좋겠음").
# 전투 상성(약점·저항)은 아직 fire/ice/dark/holy 4종만 쓴다 — 던전 5종 설계가 거기 걸려 있어
# 시각 원소만 먼저 늘렸다. 신규 4원소는 상성상 phys처럼 중립이다.
const ELEMENTS := ["phys", "fire", "ice", "dark", "holy", "water", "wind", "earth", "elec"]
const FALLBACK_ELEMENT := "phys"

# 형태 6종. 무기가 자기 전달 방식에 맞는 것을 고른다.
#   cast    발동 순간, 플레이어 자리에서 터진다
#   bolt    날아가는 투사체 본체 (Arrow.anim_dir)
#   impact  적중 지점
#   slash   근접 호를 그리는 베기
#   zone    바닥에 남는 장판·오라
#   ward    보호·버프 (자기 강화)
const FORMS := {
	"cast": {
		# cast는 _muzzle이 손끝에 30~44px로 찍는 총구 섬광이다. 작고 뾰족한 그림이 맞다.
		# 화염은 flamme(제대로 된 불꽃 모양)을 여기 두면 손끝에서만 반짝이고 끝난다.
		# 불꽃은 장판(zone)으로 보내고 여기엔 작은 pit을 쓴다.
		"phys": "vfx_phys_005", "fire": "vfx_fire_pit", "ice": "vfx_ice_claw",
		"dark": "vfx_dark_spin", "holy": "vfx_holy_wings", "water": "vfx_water_splash",
		"wind": "vfx_wind_gust", "earth": "vfx_earth_grow", "elec": "vfx_elec_spin",
	},
	"bolt": {
		# phys만 Ball이 없다. 베기 스미어가 이동 궤적으로 읽혀 투사체 본체로 쓸 만하다.
		"phys": "vfx_phys_001", "fire": "vfx_fire_ball", "ice": "vfx_ice_ball",
		"dark": "vfx_dark_ball", "holy": "vfx_holy_ball", "water": "vfx_water_ball",
		"wind": "vfx_wind_ball", "earth": "vfx_earth_ball", "elec": "vfx_elec_ball",
	},
	"impact": {
		# 대지가 lavabubble(용암 거품)을 쓰고 있었다. 용암은 화염 테마라 대지 적중이
		# 붉게 터졌다. earth_rock 은 아무 데도 안 쓰이고 있었다 — 바위 적중이 제자리다.
		# 얼음은 rock 을 쓰고 있었는데 slam(내려찍기)이 놀고 있었다. slam 이 적중 그 자체다.
		"phys": "vfx_phys_002", "fire": "vfx_fire_explosion1", "ice": "vfx_ice_slam",
		"dark": "vfx_dark_explosion1", "holy": "vfx_holy_cross",
		"water": "vfx_water_explosion", "wind": "vfx_wind_explosion",
		"earth": "vfx_earth_rock", "elec": "vfx_elec_explosion",
	},
	"slash": {
		"phys": "vfx_phys_003", "fire": "vfx_fire_slash", "ice": "vfx_ice_slash",
		"dark": "vfx_dark_slash", "holy": "vfx_holy_slash", "water": "vfx_water_slash",
		"wind": "vfx_wind_slash", "earth": "vfx_earth_spin", "elec": "vfx_elec_slash",
	},
	"zone": {
		# 장판은 "바닥에 깔려 지속되는 것"이다. 화염은 pit(작은 불씨 웅덩이)이라
		# 96px로 늘리면 갈색 원처럼 보였다. 불꽃 모양인 flamme으로 바꾼다.
		"phys": "vfx_boom_05", "fire": "vfx_fire_flamme", "ice": "vfx_ice_spike",
		"dark": "vfx_dark_portal", "holy": "vfx_holy_blessing",
		"water": "vfx_water_colomn", "wind": "vfx_wind_ground",
		"earth": "vfx_earth_lava", "elec": "vfx_elec_lighting1",
	},
	"ward": {
		# phys만 Shield가 없다. 몸 주위에서 터지는 충격파를 방어 연출로 쓴다.
		"phys": "vfx_boom_07", "fire": "vfx_fire_shield", "ice": "vfx_ice_shield",
		"dark": "vfx_dark_shield", "holy": "vfx_holy_shield", "water": "vfx_water_shield",
		"wind": "vfx_wind_shield", "earth": "vfx_earth_shield", "elec": "vfx_elec_shield",
	},
}

# 같은 형태의 더 크고 무거운 변형. 궁극기·보스 패턴처럼 "이건 큰 거다"를 알려야 할 때만.
# 정의가 없는 형태는 기본으로 떨어진다.
const HEAVY := {
	"impact": {
		"phys": "vfx_boom_03", "fire": "vfx_fire_explosion2", "ice": "vfx_ice_slam",
		"dark": "vfx_dark_explosion2", "holy": "vfx_holy_slash2",
		"water": "vfx_water_wave", "wind": "vfx_wind_spread",
		"earth": "vfx_earth_rock", "elec": "vfx_elec_lighting2",
	},
	"zone": {
		"phys": "vfx_boom_06", "fire": "vfx_fire_tornado", "ice": "vfx_ice_projectile",
		"dark": "vfx_dark_blackhole", "holy": "vfx_holy_projectile",
		"water": "vfx_water_cascade", "wind": "vfx_wind_turbine",
		"earth": "vfx_earth_heal", "elec": "vfx_elec_tornado",
	},
}

# 원소 고유 시그니처. 캐릭터의 궁극기처럼 "이 캐릭터다" 하고 알아보게 하는 한 방.
# 형태 매트릭스에 안 들어가는 개성 있는 항목들을 여기로 뺐다.
const SIGNATURE := {
	"phys": "vfx_boom_01", "fire": "vfx_fire_tornado", "ice": "vfx_ice_slam",
	"dark": "vfx_dark_blackhole", "holy": "vfx_holy_wings", "water": "vfx_water_wave",
	"wind": "vfx_wind_turbine", "earth": "vfx_earth_rock", "elec": "vfx_elec_lighting2",
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


# 캐릭터 시그니처 이펙트. 궁극기 연출에 쓴다.
static func signature(element: String) -> String:
	return str(SIGNATURE.get(normalize_element(element), ""))
