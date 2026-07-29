extends Node2D
# =====================================================================
#  Vampire-Survivors 스타일 게임 매니저 (카리나 / 통합)
#  전방향 이동 · 자동 무기 5종 · 경험치 젬+자석 · 떼거리 웨이브
#  무기 레벨업/진화 · 난이도 · 티어 몬스터 · 보스
# =====================================================================

enum State { TITLE, PLAYING, LEVELUP, GAMEOVER, VICTORY, PAUSED }

# 장판 무기는 독안개(poison_cloud) 하나만 남김 — 성수·용암지대 제거.
# (공허구 void_orb는 VoidZone을 쓰지만 바닥 장판이 아니라 끌어당기는 블랙홀이라 유지)
const ALL_WEAPONS := ["arrow", "blade", "aura", "lightning", "frost", "knife",
	"fireball", "boomerang", "holy", "venom", "whip",
	"chakram", "spear", "starfall",
	"flamethrower", "ice_lance", "crossbow", "holy_cross",
	"poison_cloud", "quake", "spread_shot", "soul_bolt",
	"holy_beam", "bone_spiral", "moonlight", "axe",
	"homing_skull", "thorn_burst", "chain_bolt", "frost_ring", "blood_sword",
	"cleave",
	"excalibur", "void_orb"]
const TIMED_WEAPONS := ["arrow", "lightning", "frost", "knife",
	"fireball", "boomerang", "holy", "venom", "whip", "excalibur", "void_orb",
	# 신규 무기 웨이브 1~5 (전부 쿨다운 발사)
	"chakram", "spear", "starfall",
	"flamethrower", "ice_lance", "crossbow", "holy_cross",
	"poison_cloud", "quake", "spread_shot", "soul_bolt",
	"holy_beam", "bone_spiral", "moonlight", "axe",
	"homing_skull", "thorn_burst", "chain_bolt", "frost_ring", "blood_sword",
	"cleave"]
const RANGED_WEAPONS := ["arrow", "lightning", "frost", "knife", "fireball", "boomerang",
	"holy", "venom", "chakram", "spear", "starfall", "flamethrower", "ice_lance",
	"crossbow", "holy_cross", "spread_shot", "soul_bolt", "holy_beam", "bone_spiral",
	"moonlight", "axe", "homing_skull", "thorn_burst", "chain_bolt", "frost_ring",
	"excalibur", "void_orb"]

# 직업 전용 스킬은 제거됨. 뱀서는 전 캐릭터가 같은 무기 풀을 공유하고,
# 캐릭터 차별화는 '고유 시작 무기 + 레벨에 따라 자라는 고유 특성'으로만 한다.
# (관통사격·노바·메테오 등 17종의 발사 코드/아이콘/카드는 이 커밋에서 함께 삭제)
# sword.png는 칼끝이 '좌상단 45°'를 향해 그려져 있는데 회전검 코드는 '위를 향함'으로
# 가정하고 돌린다 → 45° 틀어져 보임. 스프라이트 고유 방향 보정값.
# (아트를 45° 회전시키면 픽셀이 뭉개지므로 코드에서 보정)
const BLADE_ART_FIX := PI * 0.75

# CC0 슬래시 아트 보정 (tbbk 팩)
#  fx_cleave: 크레센트의 볼록한 면이 '오른쪽(0)'을 향함 → 조준 θ에 그대로 맞음
#  fx_whip  : 아트 단계에서 가로로 구워둠 → 추가 보정 불필요 (0/180°만 쓰므로
#             세로 눌림(stretch)과 축이 어긋나지 않음)
const SLASH_ART_FIX := 0.0

# 무기 표시명. 캐릭터 선택 화면이 참조 — 여기 없으면 내부 키가 그대로 노출된다.
# (같은 표가 아래 함수들에도 지역 변수로 복붙돼 있음. 무기 추가 시 함께 갱신 필요)
const WNAMES := {
	"arrow": "마법 화살", "blade": "회전 검", "aura": "신성 오라",
	"lightning": "번개", "frost": "서리 폭발", "knife": "칼 던지기",
	"fireball": "파이어볼", "boomerang": "부메랑", "holy": "천벌",
	"venom": "독날", "whip": "채찍", "chakram": "차크람", "spear": "창격",
	"starfall": "별똥별", "flamethrower": "화염분사", "ice_lance": "얼음창",
	"crossbow": "석궁", "holy_cross": "성십자", "poison_cloud": "독안개", "quake": "대지강타",
	"spread_shot": "산탄", "soul_bolt": "혼탄",
	"holy_beam": "성광선", "bone_spiral": "뼈나선", "moonlight": "월광강림", "axe": "전투도끼",
	"homing_skull": "유도해골", "thorn_burst": "가시분출",
	"chain_bolt": "연쇄뇌전", "frost_ring": "서리고리", "blood_sword": "흡혈검", "cleave": "검기",
	"excalibur": "엑스칼리버", "void_orb": "공허구",
}

# 장비 무기 5종은 캐릭터 수와 별개인 전투 아키타입이다.
# 캐릭터는 고유 패시브·Q를, 현재 주무기는 자동공격·E를 결정한다.
const WEAPON_ACTIVE_DEFS := {
	"sword": {"name": "반격의 호", "cd": 6.0, "glyph": "⚔", "icon": "res://assets/items/gear_sword.png",
		"desc": "짧게 무적이 되고 전방을 넓게 베어 밀쳐냅니다."},
	"axe": {"name": "파쇄 강타", "cd": 7.5, "glyph": "◆", "icon": "res://assets/items/gear_axe.png",
		"desc": "주변을 내려쳐 큰 피해와 경직을 줍니다."},
	"staff": {"name": "원소 폭발", "cd": 6.5, "glyph": "✦", "icon": "res://assets/items/gear_staff.png",
		"desc": "조준 지점에 현재 속성의 폭발을 일으킵니다."},
	"dagger": {"name": "그림자 난무", "cd": 4.0, "glyph": "✣", "icon": "res://assets/items/gear_dagger.png",
		"desc": "치명타 확률이 높은 단검을 빠르게 난사합니다."},
	"spear": {"name": "돌파 찌르기", "cd": 5.5, "glyph": "➤", "icon": "res://assets/items/gear_spear.png",
		"desc": "짧게 돌진한 뒤 긴 직선을 관통합니다."},
}

# 모든 시작·드롭·해금 무기를 5개 조작 문법에 연결한다. 새 무기를 추가하면 테스트가 누락을 잡는다.
const WEAPON_ACTIVE_ARCHETYPE := {
	"arrow": "dagger", "blade": "sword", "aura": "staff", "lightning": "staff",
	"frost": "staff", "knife": "dagger", "fireball": "staff", "boomerang": "dagger",
	"holy": "staff", "venom": "dagger", "whip": "sword", "chakram": "dagger",
	"spear": "spear", "starfall": "staff", "flamethrower": "staff", "ice_lance": "spear",
	"crossbow": "spear", "holy_cross": "staff", "poison_cloud": "staff", "quake": "axe",
	"spread_shot": "dagger", "soul_bolt": "staff", "holy_beam": "spear", "bone_spiral": "staff",
	"moonlight": "staff", "axe": "axe", "homing_skull": "staff", "thorn_burst": "staff",
	"chain_bolt": "staff", "frost_ring": "staff", "blood_sword": "sword", "cleave": "sword",
	"excalibur": "sword", "void_orb": "staff",
}

# 장비를 끼지 않은 캐릭터는 같은 5개 조작 문법 안에서도 고유 시작 무기 이름을 유지한다.
# 실제 장비 무기는 WEAPON_ACTIVE_DEFS의 보편적인 명칭을 사용해 교체 결과를 예측하기 쉽게 한다.
const STARTING_WEAPON_ACTIVE_VARIANTS := {
	"poison_cloud": {"name": "역병 폭발", "desc": "조준 지점에 암흑 역병을 터뜨려 적을 둔화합니다."},
	"aura": {"name": "성역 파동", "desc": "자신을 중심으로 신성 파동을 일으키고 생명력을 회복합니다."},
	"blood_sword": {"name": "혈월 반격", "desc": "짧게 무적이 되어 베고, 적중한 피를 흡수합니다."},
	"fireball": {"name": "화염 폭발", "desc": "조준 지점에 강력한 화염 폭발을 일으킵니다."},
	"spread_shot": {"name": "속사 난무", "desc": "치명타 확률이 높은 총탄을 부채꼴로 난사합니다."},
	"bone_spiral": {"name": "뼈 폭풍", "desc": "조준 지점에서 암흑 뼈 폭풍을 폭발시킵니다."},
	"moonlight": {"name": "월광 폭발", "desc": "조준 지점에 차가운 월광을 응축해 터뜨립니다."},
	"ice_lance": {"name": "빙하 돌진", "desc": "짧게 돌진한 뒤 적을 둔화하는 얼음창으로 관통합니다."},
	"chain_bolt": {"name": "연쇄 폭발", "desc": "조준 지점에 암흑 뇌전을 응축해 폭발시킵니다."},
}
# 무기별 발사 섬광 (색 + 스타일). style: "slash"(전방 부채꼴)/"spin"(회전)/"ring"(방사링)/"burst"(파티클)
# 신규 무기 위주로 발사 순간 생동감 부여 — 기존 무기는 자체 이펙트가 있어 제외.
# "slash"(반투명 부채꼴) 스타일은 전면 폐기 — 투사체가 이미 날아가는데 그 위에
# 부채꼴이 겹쳐 지저분했음. arrow·spear·flamethrower·ice_lance·crossbow·
# spread_shot·axe가 쓰고 있었고, blood_sword는 근접 전환 때 먼저 제외됨.
const WMUZZLE := {
	"knife": [Color(0.85, 0.9, 1.0), "spin"],
	"fireball": [Color(1.0, 0.55, 0.2), "burst"],
	"boomerang": [Color(0.85, 0.65, 0.35), "spin"],
	"chakram": [Color(0.8, 0.85, 0.95), "spin"],
	"starfall": [Color(0.8, 0.6, 1.0), "burst"],
	"holy_cross": [Color(1.0, 0.95, 0.6), "burst"],   # 노란 링 → 작은 파티클
	"poison_cloud": [Color(0.4, 0.85, 0.3), "ring"],
	"quake": [Color(0.7, 0.5, 0.3), "ring"],
	"soul_bolt": [Color(0.5, 0.9, 0.7), "burst"],
	"holy_beam": [Color(1.0, 0.95, 0.7), "burst"],
	"bone_spiral": [Color(0.9, 0.9, 0.82), "spin"],
	"moonlight": [Color(0.7, 0.8, 1.0), "burst"],
	"homing_skull": [Color(0.5, 1.0, 0.6), "burst"],
	"thorn_burst": [Color(0.6, 0.8, 0.4), "spin"],
	"chain_bolt": [Color(0.7, 0.85, 1.0), "burst"],
	"frost_ring": [Color(0.7, 0.9, 1.0), "spin"],
}
const MAX_WEAPONS := 6
const MAX_PASSIVES := 6
const MAX_WLEVEL := 8   # 뱀서식: 무기 만렙 Lv8
const MAX_PLEVEL := 5
const EVO_START_TIME := 600.0 # 일반 런 진화 상자는 10:00 이후부터 활성화
const FREE_WEAPON_SLOTS := 6   # 뱀서식: 6칸까지 자유롭게 신규무기 획득 (억제 사실상 제거)
const BOSS_TIME := 180.0        # 첫 보스 3분 (1분→3분: 초반에 빌드 쌓을 여유)
const FINAL_STAGE := 5
const RUN_TIME := 1800.0     # 30분에 피날레 사신 강림 (레거시 캠페인 모드)
const DUNGEON_BOSS_TIME := 300.0   # 던전 모드: 5분 생존 후 던전 보스(목표) 출현 → 처치=클리어
const MAX_ENEMIES := 300     # 동시 등장 상한 (뱀서형 밀도 + 내장 GPU 부하 관리. 340은 Iris Xe에서 랙 → 300으로 한 단계 롤백)
# 무기 진화 레시피 (뱀서식): 무기 만렙(Lv8) + 필수 패시브 보유 → 보스 상자 개봉 시 진화
# passive=필수 패시브 키, name=진화 무기 이름
const EVO_RECIPE := {
	"arrow":     {"passive": "candela", "name": "폭풍 화살", "icon": "res://assets/items/evo_arrow.png"},
	"blade":     {"passive": "armor",   "name": "사신의 대검", "icon": "res://assets/items/evo_blade.png"},
	"aura":      {"passive": "heart",   "name": "지옥불 오라", "icon": "res://assets/items/evo_aura.png"},
	"lightning": {"passive": "tome",    "name": "천둥의 진노", "icon": "res://assets/items/evo_lightning.png"},
	"frost":     {"passive": "wings",   "name": "절대영도", "icon": "res://assets/items/evo_frost.png"},
	"knife":     {"passive": "spinach", "name": "천 개의 칼", "icon": "res://assets/items/evo_knife.png"},
	"fireball":  {"passive": "candela", "name": "운석우", "icon": "res://assets/items/evo_fireball.png"},
	"boomerang": {"passive": "wings",   "name": "사신의 낫", "icon": "res://assets/items/evo_boomerang.png"},
	"holy":      {"passive": "tome",    "name": "신의 심판", "icon": "res://assets/items/evo_holy.png"},
	"venom":     {"passive": "tomato",  "name": "역병", "icon": "res://assets/items/evo_venom.png"},
	"whip":      {"passive": "spinach", "name": "피의 눈물", "icon": "res://assets/items/evo_whip.png"},
	# 신규 무기 진화 (중앙 강화 방식 — NEW_EVO_WEAPONS)
	"chakram":      {"passive": "duplicator",  "name": "죽음의 원반", "icon": "res://assets/items/evo_chakram.png"},
	"spear":        {"passive": "keen_eye",    "name": "관통의 벼락창", "icon": "res://assets/items/evo_spear.png"},
	"starfall":     {"passive": "candela",     "name": "종말의 유성우", "icon": "res://assets/items/evo_starfall.png"},
	"flamethrower": {"passive": "candela",     "name": "지옥불 분사", "icon": "res://assets/items/evo_flamethrower.png"},
	"ice_lance":    {"passive": "wings",       "name": "절대영도창", "icon": "res://assets/items/evo_ice_lance.png"},
	"crossbow":     {"passive": "berserker",   "name": "발리스타", "icon": "res://assets/items/evo_crossbow.png"},
	"holy_cross":   {"passive": "tome",        "name": "심판의 십자", "icon": "res://assets/items/evo_holy_cross.png"},
	"poison_cloud": {"passive": "tomato",      "name": "대역병 안개", "icon": "res://assets/items/evo_poison_cloud.png"},
	"quake":        {"passive": "armor",       "name": "대격변", "icon": "res://assets/items/evo_quake.png"},
	"spread_shot":  {"passive": "duplicator",  "name": "폭풍 산탄", "icon": "res://assets/items/evo_spread_shot.png"},
	"soul_bolt":    {"passive": "keen_eye",    "name": "군단 혼탄", "icon": "res://assets/items/evo_soul_bolt.png"},
	"holy_beam":    {"passive": "spellbinder", "name": "천상의 빛기둥", "icon": "res://assets/items/evo_holy_beam.png"},
	"bone_spiral":  {"passive": "skull",       "name": "죽음의 나선", "icon": "res://assets/items/evo_bone_spiral.png"},
	"moonlight":    {"passive": "candela",     "name": "월식 강림", "icon": "res://assets/items/evo_moonlight.png"},
	"axe":          {"passive": "berserker",   "name": "파멸의 도끼", "icon": "res://assets/items/evo_axe.png"},
	"homing_skull": {"passive": "skull",       "name": "망령 군세", "icon": "res://assets/items/evo_homing_skull.png"},
	"thorn_burst":  {"passive": "spinach",     "name": "가시 지옥", "icon": "res://assets/items/evo_thorn_burst.png"},
	"chain_bolt":   {"passive": "tome",        "name": "뇌신의 분노", "icon": "res://assets/items/evo_chain_bolt.png"},
	"frost_ring":   {"passive": "wings",       "name": "절대 동결지대", "icon": "res://assets/items/evo_frost_ring.png"},
	"blood_sword":  {"passive": "vitality",    "name": "흡혈 대검", "icon": "res://assets/items/evo_blood_sword.png"},
	"cleave":       {"passive": "armor",       "name": "파천 검기", "icon": "res://assets/items/evo_cleave.png"},
}
# 신규 무기 진화는 _fire_weapon에서 일괄 강화(피해·투사체·범위↑) — 개별 _fire 수정 불필요
# 레벨업에 제안되는 핵심 무기 풀 (뱀서식: 패턴별 대표만 남겨 "골라 키우는 맛"). 코드는 전부 유지,
# 여기 없는 무기는 신규 카드로 안 뜸(시작무기·진화·유니온은 별개로 정상 동작).
# 미니멀 무기 풀 (뱀서식): 아키타입별 대표 하나씩만 신규 카드로 제안 → 겹치는 무기 제거.
# (제외된 무기도 코드·진화 레시피는 유지 → 진화무기·시작무기로는 여전히 등장)
const POOL_WEAPONS := [
	"arrow",        # 유도 단발 (매직완드)
	"knife",        # 직선 다중 투척
	"spread_shot",  # 전방 산탄
	"crossbow",     # 관통 저격
	"blade",        # 공전 검 (성경)
	"aura",         # 근접 오라 (마늘)
	"whip",         # 전방 채찍
	"cleave",       # 검기 호
	"frost",        # 빙결 노바
	"lightning",    # 랜덤 낙뢰
	"fireball",     # 폭발 투척
	"boomerang",    # 귀환 투척
	"chakram",      # 튕기는 원반 (룬트레이서)
	"moonlight",    # 하늘 폭격
]
const NEW_EVO_WEAPONS := ["chakram", "spear", "starfall", "flamethrower",
	"ice_lance", "crossbow", "holy_cross", "poison_cloud", "quake", "spread_shot", "soul_bolt",
	"holy_beam", "bone_spiral", "moonlight", "axe", "homing_skull",
	"thorn_burst", "chain_bolt", "frost_ring", "blood_sword", "cleave"]
# 신규 진화 무기의 시그니처 효과 (Arrow 투사체에 부여). Arrow._ready가 부모의 EVO_FX를 읽어 적용.
# 지원 키: pierce(+관통), explode(폭발 반경)+efrac(폭발 피해 비율), homing(유도), slow/slow_t(둔화), ls(흡혈)
const EVO_FX := {
	"chakram":      {"pierce": 99},                         # 죽음의 원반: 전관통
	"spear":        {"pierce": 99, "explode": 60.0, "efrac": 0.5},  # 벼락창: 관통+낙뢰
	"flamethrower": {"explode": 66.0, "efrac": 0.6},        # 지옥불: 착탄마다 폭발
	"ice_lance":    {"pierce": 99, "slow": 0.6, "slow_t": 2.0},     # 절대영도창: 관통+빙결
	"crossbow":     {"pierce": 99, "explode": 96.0, "efrac": 0.8},  # 발리스타: 관통 폭발볼트
	"spread_shot":  {"homing": 4.0},                        # 산탄 유도
	"soul_bolt":    {"homing": 5.0, "explode": 54.0, "efrac": 0.5}, # 혼탄: 추적+작렬
	"holy_beam":    {"explode": 74.0, "efrac": 0.6},        # 성광선: 관통+폭발광
	"bone_spiral":  {"pierce": 3, "explode": 50.0, "efrac": 0.4},   # 뼈나선 작렬
	"axe":          {"explode": 104.0, "efrac": 0.7},       # 전투도끼: 대지 폭쇄
	"homing_skull": {"explode": 70.0, "efrac": 0.6},        # 유도해골: 작렬
	"thorn_burst":  {"pierce": 99},                         # 가시분출 전관통
	"frost_ring":   {"pierce": 2, "slow": 0.6, "slow_t": 2.2},      # 서리고리 강빙결
	# 흡혈검은 근접 베기로 바뀌어 Arrow를 안 만듦 → EVO_FX(투사체 전용) 대상 아님.
	#   진화 효과는 _fire_blood_sword 안에서 직접 처리 (범위·피해·흡혈 강화)
	"holy_cross":   {"pierce": 2, "explode": 60.0, "efrac": 0.5},   # 성십자 작렬
}
var _evo_kind := ""   # 현재 발사 중인 진화 무기 kind (Arrow가 EVO_FX 조회용)

# 진화 무기 시그니처 색 — 진화하면 투사체·이펙트·후광·트레일이 이 색으로 물든다.
# 기본 무기 색과 확 다르게 잡아 "진화했다"가 한눈에 보이게 (뱀서식 비주얼 정체성).
const EVO_TINT := {
	"arrow": Color(1.0, 0.45, 0.40),        # 진홍 마탄
	"lightning": Color(0.80, 0.55, 1.00),   # 보라 뇌전
	"fireball": Color(0.50, 0.65, 1.00),    # 청염
	"frost": Color(0.60, 0.92, 1.00),       # 심빙
	"knife": Color(1.00, 0.55, 0.50),       # 혈인
	"boomerang": Color(1.00, 0.85, 0.40),   # 황금 원반
	"holy": Color(1.00, 0.95, 0.65),        # 순백금
	"venom": Color(0.70, 1.00, 0.30),       # 맹독 라임
	"whip": Color(1.00, 0.40, 0.40),        # 핏빛 채찍
	"starfall": Color(0.70, 0.80, 1.00),    # 청백 유성
	"poison_cloud": Color(0.75, 0.50, 1.00),# 독보라
	"quake": Color(1.00, 0.55, 0.25),       # 용암 균열
	"moonlight": Color(1.00, 0.45, 0.50),   # 붉은 월식
	"cleave": Color(1.00, 0.85, 0.50),      # 황금 검기
	"blood_sword": Color(1.00, 0.25, 0.30), # 심홍 혈검
	"chakram": Color(0.85, 0.40, 1.00),     # 죽음 보라
	"spear": Color(0.55, 0.85, 1.00),       # 전격 하늘
	"flamethrower": Color(0.45, 0.65, 1.00),# 지옥 청염
	"ice_lance": Color(0.70, 0.95, 1.00),   # 절대영도
	"crossbow": Color(1.00, 0.70, 0.35),    # 발리스타 주황
	"spread_shot": Color(0.50, 1.00, 0.55), # 유도 녹탄
	"soul_bolt": Color(0.50, 1.00, 0.90),   # 유령 청록
	"holy_beam": Color(1.00, 0.90, 0.40),   # 순금 광선
	"bone_spiral": Color(1.00, 0.50, 0.45), # 핏빛 뼈
	"axe": Color(1.00, 0.55, 0.20),         # 용암 도끼
	"homing_skull": Color(0.55, 1.00, 0.40),# 지옥 녹염
	"thorn_burst": Color(0.80, 0.40, 0.90), # 독자주 가시
	"frost_ring": Color(0.60, 0.90, 1.00),  # 얼음 고리
	"holy_cross": Color(1.00, 0.95, 0.60),  # 금백 십자
}


# 진화 시그니처 색 조회 (없으면 공통 황금)
func _evo_tint(kind: String) -> Color:
	return EVO_TINT.get(kind, Color(1.3, 1.15, 0.7))

# 무기 조합: 두 무기 모두 Lv3+ → 조합 카드 등장 (조합당 1회)
const COMBO_DEFS := [
	{"key": "arrow_lightning", "a": "arrow", "b": "lightning", "t": "⚡스톰 애로우",
		"d": "화살 명중 시 30% 번개 연쇄", "icon": "res://assets/items/icon_lightning.png"},
	{"key": "arrow_frost", "a": "arrow", "b": "frost", "t": "❄프로스트 애로우",
		"d": "모든 화살에 둔화 부여", "icon": "res://assets/items/icon_frost.png"},
	{"key": "blade_aura", "a": "blade", "b": "aura", "t": "블레이드 스톰",
		"d": "검 +1, 오라 범위 +15%", "icon": "res://assets/items/sword.png"},
	{"key": "lightning_frost", "a": "lightning", "b": "frost", "t": "블리자드",
		"d": "번개 맞은 적 둔화", "icon": "res://assets/items/icon_frost.png"},
	{"key": "aura_frost", "a": "aura", "b": "frost", "t": "서리 오라",
		"d": "오라가 적을 둔화", "icon": "res://assets/items/icon_aura.png"},
	{"key": "blade_lightning", "a": "blade", "b": "lightning", "t": "뇌명검",
		"d": "검 피해 +40%, 번개 강타 +1", "icon": "res://assets/items/sword.png"},
	# 신규 무기 조합
	{"key": "fire_frost", "a": "fireball", "b": "frost", "t": "🌋증기 폭발",
		"d": "파이어볼 폭발 +30%, 둔화 부여", "icon": "res://assets/items/icon_fireball.png"},
	{"key": "venom_fire", "a": "venom", "b": "fireball", "t": "☠맹독 화염",
		"d": "독날 명중 시 화염 폭발", "icon": "res://assets/items/icon_venom.png"},
	{"key": "holy_lightning", "a": "holy", "b": "lightning", "t": "⚡천벌 강림",
		"d": "천벌 착탄에 번개 연쇄", "icon": "res://assets/items/icon_holy.png"},
	{"key": "whip_boomerang", "a": "whip", "b": "boomerang", "t": "🌀난무",
		"d": "채찍 범위 +30%, 부메랑 +1", "icon": "res://assets/items/icon_whip.png"},
	{"key": "arrow_fireball", "a": "arrow", "b": "fireball", "t": "🔥폭렬 화살",
		"d": "화살이 소형 폭발", "icon": "res://assets/items/icon_fireball.png"},
]
# 유니온: 두 무기 모두 Lv8(만렙) → 보스 상자에서 합체 신규 무기 (뱀서 Union)
const UNION_DEFS := [
	{"key": "storm_bow",    "a": "arrow",   "b": "lightning", "name": "폭풍궁",
		"desc": "화살 폭풍 + 낙뢰 동시 강타", "icon": "res://assets/items/icon_lightning.png", "cd": 1.1},
	{"key": "frostfire",    "a": "fireball", "b": "frost",    "name": "빙염",
		"desc": "화상+빙결 대폭발", "icon": "res://assets/items/icon_fireball.png", "cd": 1.6},
	{"key": "cyclone",      "a": "whip",    "b": "boomerang", "name": "선풍",
		"desc": "전방위 고속 회전 참격", "icon": "res://assets/items/icon_whip.png", "cd": 1.3},
	{"key": "plague_bomb",  "a": "venom",   "b": "fireball",  "name": "역병탄",
		"desc": "독구름 남기는 폭발", "icon": "res://assets/items/icon_venom.png", "cd": 1.8},
	{"key": "divine_storm", "a": "holy",    "b": "lightning", "name": "신벌",
		"desc": "신성 기둥 + 낙뢰 다중 강타", "icon": "res://assets/items/icon_holy.png", "cd": 1.5},
	{"key": "blade_dance",  "a": "blade",   "b": "aura",      "name": "검무",
		"desc": "검+오라 융합 광역 지속", "icon": "res://assets/items/sword.png", "cd": 1.4},
]
const WORLD := Vector2(2800, 2800)   # 월드 크기 (뱀서식 넓은 맵. 몹은 플레이어 주변 스폰이라 밀도 유지)
const StageLayoutData = preload("res://StageLayout.gd")
const StageTiles = preload("res://StageTileRenderer.gd")
const STAGE_MAP_DIRS := ["graveyard", "hell_bridge", "glacier", "void_altar", "demon_castle"]
# 바닥 타일 톤 보정. 생성 원본이 대체로 밝고 채도가 높아 그대로 쓰면
# 캐릭터·몬스터·아이템이 배경에 묻힌다. 스테이지마다 눌러서 대비를 확보.
const STAGE_TILE_MODULATES := [
	# 경계 타일 톤. 너무 눌러 맵이 시커멨다 → 전반적으로 밝게 완화(캐릭터 대비는 유지).
	Color(0.78, 0.84, 0.76),   # 묘지: 이끼 낀 석재 포장
	Color(0.82, 0.68, 0.68),   # 지옥: 화산암 벽돌
	Color(0.82, 0.88, 0.96),   # 빙하: 얼음 벽돌
	Color(0.88, 0.80, 1.00),   # 공허: 보라 룬 바닥
	Color(0.82, 0.84, 0.94),   # 마성: 석판
]
var _decor_cache: Array = []
var _decor_loaded := false
var _evo_spawn := false   # 진화 무기 발사 중이면 true (Arrow가 진화 오라를 켜기 위해 읽음)
# 현재 발사 중 무기의 시각 배율 (레벨·진화 성장감). 디스패처가 설정, 발사 후 1.0 복귀.
# 발사 중 동기 생성되는 투사체(Arrow)·이펙트(spawn_fx)·낙하체(SkyStrike)가 읽는다.
var wfx_boost := 1.0

# 업적 (달성 시 골드 보상 + 일부는 특수무기 해금)
const ACHIEVEMENTS := [
	{"key": "first_win",    "name": "첫 승리",        "desc": "30분 생존 또는 최종보스 처치", "gold": 100},
	{"key": "survivor",     "name": "불굴의 생존자",   "desc": "한 판에서 15분 이상 생존",     "gold": 120},
	{"key": "slayer",       "name": "학살자",         "desc": "한 판에서 800킬 달성",         "gold": 250, "unlock": "void_orb"},
	{"key": "evolved",      "name": "완전한 진화",     "desc": "Lv75 도달 (5단계 진화)",       "gold": 200},
	{"key": "combo_master", "name": "유니온 완성",     "desc": "한 판에서 유니온 무기 1개 완성", "gold": 150},
	{"key": "legend_weapon","name": "전설을 손에",     "desc": "무기 하나를 진화시킴",          "gold": 100},
	{"key": "boss_slayer",  "name": "보스 슬레이어",   "desc": "한 판에서 보스 4마리 처치",     "gold": 150},
	{"key": "rich",         "name": "부호",           "desc": "골드 3000 보유",               "gold": 100},
	{"key": "hard_clear",   "name": "진정한 도전자",   "desc": "어려움 난이도 승리",            "gold": 300, "unlock": "excalibur"},
	{"key": "no_revive",    "name": "무결점",         "desc": "부활 없이 승리",               "gold": 200},
	{"key": "abyss",        "name": "심연의 정복자",   "desc": "심연 5층 도달",                "gold": 250},
	{"key": "knife_thrower","name": "투척 전문가",     "desc": "보통 이상에서 원거리 무기 4종 보유 승리", "gold": 150, "unlock": "knife"},
	{"key": "win_corvius",  "name": "역병의 승리",     "desc": "코르비우스로 승리",             "gold": 80},
	{"key": "win_gustavo",  "name": "정육점의 승리",   "desc": "구스타보로 승리",               "gold": 80},
	{"key": "win_serafina", "name": "타락한 가호",     "desc": "세라피나로 승리",               "gold": 80},
	{"key": "win_valentino","name": "피의 백작",       "desc": "발렌티노로 승리",               "gold": 80},
	{"key": "win_pixie",    "name": "꼬마 대마녀",     "desc": "픽시로 승리",                   "gold": 80},
	{"key": "win_django",   "name": "노상강도의 전설", "desc": "바르톨로로 승리",               "gold": 80},
	{"key": "win_bolt",     "name": "납골당의 주인",   "desc": "오사리오로 승리",               "gold": 80},
	{"key": "win_morgana",  "name": "월광의 해방",     "desc": "모르가나로 승리",               "gold": 80},
	{"key": "win_isolde",   "name": "겨울의 승리",     "desc": "이졸데로 승리",                 "gold": 80},
	{"key": "win_grimble",  "name": "늪의 승리",       "desc": "그림블로 승리",                 "gold": 80},
	{"key": "win_mordek",   "name": "처형 집행",       "desc": "모르덱으로 승리",               "gold": 80},
]
# 업적 달성 시 다음 런부터 자동 적용되는 영구 유물. 별도 슬롯을 차지하지 않는다.
const RELIC_DEFS := [
	{"key":"yellow_sign", "name":"노란 표식", "desc":"도감의 모든 진화·유니온 재료 공개", "unlock":"survivor", "icon_key":"clover", "icon":"res://assets/items/relic_yellow_sign.png"},
	{"key":"milky_map", "name":"은하 지도", "desc":"일시정지 화면에 플레이어·남은 유물 지도 표시", "unlock":"first_win", "icon_key":"magnet", "icon":"res://assets/items/relic_milky_map.png"},
	{"key":"great_gospel", "name":"위대한 복음", "desc":"매 런 시작 무기 +1레벨", "unlock":"no_revive", "icon_key":"tome", "icon":"res://assets/items/relic_great_gospel.png"},
	{"key":"witch_tear", "name":"마녀의 눈물", "desc":"저주 +12% · 경험치·골드 +12%", "unlock":"slayer", "icon_key":"skull", "icon":"res://assets/items/relic_witch_tear.png"},
	{"key":"black_chalice", "name":"검은 성배", "desc":"모든 피해에 흡혈 1.5% 부여", "unlock":"legend_weapon", "icon_key":"heart", "icon":"res://assets/items/relic_black_chalice.png"},
	{"key":"silver_ring", "name":"은빛 반지", "desc":"모든 무기 범위 +10%", "unlock":"boss_slayer", "icon_key":"candela", "icon":"res://assets/items/relic_silver_ring.png"},
	{"key":"golden_mask", "name":"황금 가면", "desc":"골드 획득 +15%", "unlock":"rich", "icon_key":"stone_mask", "icon":"res://assets/items/relic_golden_mask.png"},
	{"key":"metaglio", "name":"강철 문장", "desc":"방어력 +1 · 재생 +0.25/초", "unlock":"hard_clear", "icon_key":"armor", "icon":"res://assets/items/relic_metaglio.png"},
	{"key":"abyss_eye", "name":"심연의 눈", "desc":"경험치 획득 +10%", "unlock":"evolved", "icon_key":"tome", "icon":"res://assets/items/relic_abyss_eye.png"},
	{"key":"soul_lantern", "name":"영혼 등불", "desc":"자석 범위 +30", "unlock":"knife_thrower", "icon_key":"magnet", "icon":"res://assets/items/relic_soul_lantern.png"},
	{"key":"fallen_halo", "name":"타락한 광륜", "desc":"이동속도 +8%", "unlock":"abyss", "icon_key":"wings", "icon":"res://assets/items/relic_fallen_halo.png"},
	{"key":"hungry_heart", "name":"굶주린 심장", "desc":"최대 체력 +15%", "unlock":"combo_master", "icon_key":"heart", "icon":"res://assets/items/relic_hungry_heart.png"},
]
# 해금 무기: 무기키 → 필요 업적키 (미달성이면 카드 풀에 안 나옴)
const UNLOCK_WEAPONS := {"knife": "knife_thrower", "excalibur": "hard_clear", "void_orb": "slayer"}

# 던전 가호(선택): 입장 전 1개 선택해 런의 성격을 바꾼다.
# 위험과 보상은 난이도가 전담하고, 가호는 플레이 방식의 변주만 담당한다.
const MODIFIERS := [
	{"key": "none", "name": "기본", "desc": "추가 효과 없음",
		"color": Color(0.6, 0.62, 0.68)},
	{"key": "blessed", "name": "[축복] 축복받은 시작", "desc": "시작 무기 Lv3 · 골드 -25%",
		"start_weapon": 3, "gold": 0.75, "color": Color(0.5, 0.85, 1.0)},
	{"key": "golden_vow", "name": "[축복] 황금빛 서약", "desc": "골드 +50% · 적 체력 +12%",
		"gold": 1.5, "enemy_hp": 1.12, "color": Color(1.0, 0.82, 0.35)},
	{"key": "sage_mind", "name": "[축복] 현자의 총명", "desc": "경험치 +45% · 골드 -30%",
		"xp": 1.45, "gold": 0.7, "color": Color(0.6, 0.8, 1.0)},
	{"key": "swift_feet", "name": "[축복] 신속한 발", "desc": "이동속도 +14% · 최대 체력 -12%",
		"player_speed": 1.14, "player_hp": 0.88, "color": Color(0.55, 0.95, 0.7)},
	{"key": "iron_flesh", "name": "[축복] 강철 육신", "desc": "최대 체력 +35% · 이동속도 -8%",
		"player_hp": 1.35, "player_speed": 0.92, "color": Color(0.85, 0.7, 0.5)},
	{"key": "volley", "name": "[축복] 다발 사격", "desc": "투사체 +1 · 골드 -30%",
		"player_amount": 1, "gold": 0.7, "color": Color(1.0, 0.6, 0.75)},
]

# ── 유물 세트 효과: 관련 유물 3종을 모두 해금하면 추가 보너스 (뱀서식 컬렉션 시너지) ──
# 12종 유물을 4개 테마 세트로 묶었다. 세트 보너스는 전부 스탯형이라
# _apply_unlocked_relic_effects에서 개별 효과 뒤에 한 번에 적용한다.
const RELIC_SETS := [
	{"name": "심연의 계약", "relics": ["witch_tear", "abyss_eye", "fallen_halo"],
		"desc": "저주 +15% · 경험치 +12% · 이동속도 +5%", "color": Color(0.72, 0.4, 1.0)},
	{"name": "연금술사의 보고", "relics": ["golden_mask", "soul_lantern", "silver_ring"],
		"desc": "골드 +20% · 자석 범위 +40 · 무기 범위 +8%", "color": Color(1.0, 0.82, 0.35)},
	{"name": "불멸의 심장", "relics": ["hungry_heart", "metaglio", "black_chalice"],
		"desc": "최대 체력 +12% · 재생 +0.5/초 · 흡혈 +2%", "color": Color(1.0, 0.45, 0.5)},
	{"name": "예언자의 유산", "relics": ["yellow_sign", "milky_map", "great_gospel"],
		"desc": "경험치 +12% · 골드 +12%", "color": Color(0.5, 0.85, 1.0)},
]

# 무기/패시브 아이콘 (파일 없으면 아이콘 없이 텍스트만)
const WICON := {
	"arrow": "res://assets/items/arrow.png",
	"blade": "res://assets/items/sword.png",
	"aura": "res://assets/items/icon_aura.png",
	"lightning": "res://assets/items/icon_lightning.png",
	"frost": "res://assets/items/icon_frost.png",
	"knife": "res://assets/items/icon_throwknife.png",
	"fireball": "res://assets/items/icon_fireball.png",
	"boomerang": "res://assets/items/icon_boomerang.png",
	"holy": "res://assets/items/icon_holy.png",
	"venom": "res://assets/items/icon_venom.png",
	"whip": "res://assets/items/icon_whip.png",
	"chakram": "res://assets/items/icon_chakram.png",
	"spear": "res://assets/items/icon_spear.png",
	"starfall": "res://assets/items/icon_starfall.png",
	"flamethrower": "res://assets/items/icon_flamethrower.png",
	"ice_lance": "res://assets/items/icon_icelance.png",
	"crossbow": "res://assets/items/icon_crossbow.png",
	"holy_cross": "res://assets/items/icon_holycross.png",
	"poison_cloud": "res://assets/items/icon_poisoncloud.png",
	"quake": "res://assets/items/icon_quake.png",
	"spread_shot": "res://assets/items/icon_spreadshot.png",
	"soul_bolt": "res://assets/items/icon_soulbolt.png",
	"holy_beam": "res://assets/items/icon_holybeam.png",
	"bone_spiral": "res://assets/items/icon_bonespiral.png",
	"moonlight": "res://assets/items/icon_moonlight.png",
	"axe": "res://assets/items/icon_axe.png",
	"homing_skull": "res://assets/items/icon_homingskull.png",
	"thorn_burst": "res://assets/items/icon_thornburst.png",
	"chain_bolt": "res://assets/items/icon_chainbolt.png",
	"frost_ring": "res://assets/items/icon_frostring.png",
	"blood_sword": "res://assets/items/icon_bloodsword.png",
	"cleave": "res://assets/items/icon_slash.png",
	"excalibur": "res://assets/items/icon_excalibur.png",
	"void_orb": "res://assets/items/icon_voidorb.png",
}
const PICON := {
	"spinach": "res://assets/items/icon_spinach.png",
	"armor": "res://assets/items/icon_armor.png",
	"wings": "res://assets/items/icon_wings.png",
	"tome": "res://assets/items/icon_tome.png",
	"candela": "res://assets/items/icon_candela.png",
	"heart": "res://assets/items/icon_voidheart.png",
	"magnet": "res://assets/items/magnet.png",
	"tomato": "res://assets/items/icon_tomato.png",
	"duplicator": "res://assets/items/icon_clone.png",
	"spellbinder": "res://assets/items/icon_spellbinder.png",
	"might": "res://assets/items/icon_charge.png",
	"crown": "res://assets/items/icon_crown.png",
	"stone_mask": "res://assets/items/icon_stonemask.png",
	"clover": "res://assets/items/icon_clover.png",
	"keen_eye": "res://assets/items/icon_keeneye.png",
	"berserker": "res://assets/items/icon_berserker.png",
	"vitality": "res://assets/items/icon_vitality.png",
	"iron_will": "res://assets/items/icon_ironwill.png",
	"swiftness": "res://assets/items/icon_swiftness.png",
	"skull": "res://assets/items/icon_skull.png",
}

var state: int = State.TITLE

var player: Player
var boss = null
var boss_spawned := false

var time_survived := 0.0
var kills := 0
var level := 1
var xp := 0
var xp_to_next := 10
var pending_levelups := 0

var spawn_timer := 1.0
var pickup_timer := 10.0
var breakable_timer := 6.0   # 파괴 오브젝트 주기 스폰
var _blade_angle := 0.0
var _aura_pulse_t := 0.0
var _blade_evo_pulse_t := 0.0

# 스테이지
var stage_num := 1
var map_stage := 0           # 0=기존 5막 캠페인, 1~5=선택한 독립 스테이지
var stage_layout # 독립 맵의 이동 가능 영역·고정 아이템 좌표
var stage_map_texture: Texture2D # PixelLab Wang tiles assembled from stage_layout
var next_boss_time := BOSS_TIME
var last_boss_stage := 0     # 스테이지당 보스 1회 보장
var _event_idx := 0          # 이벤트 종류 순환 인덱스
var featured_enemy := ""     # 이번 웨이브 주력 몬스터 key (테마 웨이브)
var _wave_minute := -1       # 분 단위 웨이브 진행 인덱스
var _current_wave: Dictionary = {} # GameConfig의 현재 분 웨이브 데이터
var abyss_mode := false      # 30분 승리 후 무한 모드
var reaper_warned := false    # 사신 강림 경고 표시 여부 (던전 모드에선 보스 출현 경고로 재사용)
var _boss_is_objective := false  # 던전 모드: 이 보스가 목표 보스인가 (처치=클리어)
var stage_banner_t := 0.0
var stage_label: Label

# 맵 조형물 (스테이지별 바위/나무 등 — 순수 장식)
var decorations: Array = []

# 메타 진행 (영구 저장)
var meta: Dictionary = {}
var run_gold := 0
# 치트: 백쿼트(`)로 모드를 켠 뒤 F키. 치트를 쓴 런은 업적·기록·보상 미반영(cheated).
var cheat_mode := false
var cheated := false
var cheat_invincible := false
var run_damage_dealt := 0.0
var run_damage_taken := 0.0
var greed_mult := 1.0   # 골드 획득 배수 (영구강화)
var xp_mult := 1.0      # 경험치 획득 배수 (영구강화)
var revives := 0        # 남은 부활 횟수 (영구강화)
var run_bosses := 0     # 이번 판 보스 처치 수 (업적)
var used_revive := false  # 이번 판 부활 사용 여부 (업적)
var ach_toast: Label    # 업적 달성 토스트
var ach_toast_t := 0.0
var shop_panel: Control
var shop_gold_label: Label
var shop_buttons: Array = []
var title_gold_label: Label
# 마을 대장간 (Phase 5): 지속 장비 보관함 강화/장착
var forge_panel: Control
var forge_gold_label: Label
var forge_stash_label: Label
var forge_loadout_box: HBoxContainer
var forge_list_box: VBoxContainer
var forge_detail_label: Label
var forge_equip_btn: Button
var forge_upgrade_btn: Button
var forge_discard_btn: Button
var forge_loadout_width := 250.0
var forge_list_item_width := 300.0
var _forge_sel := -1              # 선택한 보관함 인덱스
var pause_panel: Control
var pause_stats_box: GridContainer   # 일시정지 스탯 패널 (레벨업과 동일한 아이콘 그리드)
var pause_weap_box: HBoxContainer   # 일시정지: 무기 아이콘 줄
var pause_pass_box: HBoxContainer   # 일시정지: 패시브 아이콘 줄
var pause_map_rect: TextureRect     # 일시정지: 유물 「은하 지도」 미니맵 (해금 시에만)
var pause_map_title: Label
var abyss_btn: Button
var char_panel: Control
var stage_select_panel: Control
var stage_select_backdrop: ColorRect
var map_cards: Array[Button] = []
var map_selection_borders: Array[Panel] = []
var map_selection_badges: Array[Label] = []
var map_detail_label: Label
var map_confirm_button: Button
var map_difficulty_buttons: Array[Button] = []
var map_blessing_button: Button
var unlocked_stage_count := 1
var sel_diff: Dictionary = {}
var sel_stage := 0
var sel_modifier: Dictionary = {}
var options_panel: Control
var achievements_panel: Control
var ach_list_box: GridContainer
var ach_progress_label: Label
var collection_panel: Control
var collection_list_box: GridContainer
var collection_progress_label: Label
var collection_tab := "evolutions"
var collection_tab_buttons: Dictionary = {}

# 캐릭터 선택 + 특화 배수
var sel_char: Dictionary = {}
var char_buttons: Array = []
var char_melee := 1.0    # 근접(검/오라) 피해 배수
var char_ranged := 1.0   # 원거리(화살/번개/서리/칼) 피해 배수
var _growth_tier := 0    # 캐릭터 성장 특성: 지금까지 적용한 단계 수
var _base_speed := 125.0 # 성장 특성 speed 계산 기준 (런 시작 시 속도)
var char_range := 1.0    # 사거리/범위 배수


# 사운드
var bgm_player: AudioStreamPlayer
var _sfx_cd := {}        # 사운드 스팸 방지


# ── 오디오 버스 / 옵션 설정 ──
func _setup_audio_buses() -> void:
	# Music / SFX 버스 생성 (없을 때만)
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.get_bus_index("Music"), "Master")
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.get_bus_index("SFX"), "Master")


func _vol_to_db(v: float) -> float:
	if v <= 0.001:
		return -80.0
	return linear_to_db(v)


func _apply_audio_settings() -> void:
	var mi := AudioServer.get_bus_index("Music")
	var si := AudioServer.get_bus_index("SFX")
	if mi >= 0:
		AudioServer.set_bus_volume_db(mi, _vol_to_db(float(meta.get("music_vol", 0.7))))
		AudioServer.set_bus_mute(mi, float(meta.get("music_vol", 0.7)) <= 0.001)
	if si >= 0:
		AudioServer.set_bus_volume_db(si, _vol_to_db(float(meta.get("sfx_vol", 0.8))))
		AudioServer.set_bus_mute(si, float(meta.get("sfx_vol", 0.8)) <= 0.001)


# 이펙트 설정 반영 (옵션 → 런타임). Effect는 static이라 클래스에 직접 주입.
func _apply_fx_settings() -> void:
	fx_level = int(meta.get("fx_level", 2))
	shake_enabled = bool(meta.get("screen_shake", true))
	Effect.fx_level = fx_level


func _apply_fullscreen() -> void:
	var fs: bool = meta.get("fullscreen", false)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)


func play_sfx(sname: String, vol_db: float = -8.0, min_gap: float = 0.05) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if float(_sfx_cd.get(sname, 0.0)) > now:
		return
	_sfx_cd[sname] = now + min_gap
	var path := "res://assets/sfx/%s.wav" % sname
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = vol_db
	p.bus = "SFX"
	p.pitch_scale = randf_range(0.94, 1.06)
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _start_bgm() -> void:
	if bgm_player:
		return
	var path := "res://assets/sfx/bgm.wav"
	if not ResourceLoader.exists(path):
		return
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = load(path)
	bgm_player.volume_db = -6.0
	bgm_player.bus = "Music"
	bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bgm_player)
	bgm_player.finished.connect(bgm_player.play)
	bgm_player.play()

# 화면 흔들림
var shake_t := 0.0
var fx_level := 2          # 이펙트 강도 0=끔 1=약함 2=보통 3=화려함 (옵션)
var shake_enabled := true  # 화면 흔들림 (옵션)
var _dmgnum := 0   # 활성 데미지 숫자 개수 (대량 피격 시 성능 상한)
var ui_overlay: CanvasLayer   # 룰렛 등 런타임 오버레이 부착용
var postfx: PostFX            # 레트로 후처리(레버2) — F4로 프리셋 순환
var flash_overlay: FlashOverlay   # 레벨업·진화 화면 플래시
var _slowmo_until := 0        # 슬로우모션 종료 시각(ms, 실시간)
var skill_label: Label

var weapons := {}     # kind -> level
var wtimer := {}      # 쿨다운 무기 -> 남은 시간
var passives := {}    # kind -> level
var evolved := {}     # 진화한 무기 kind -> true
var combos := {}      # (구) 조합 — 유니온으로 대체, 미사용
var unions := {}      # 획득한 유니온 key -> true (합체 신규 무기)

# 난이도
var diff_enemy_hp := 1.0
var diff_enemy_speed := 1.0
var diff_spawn := 1.0
var diff_loot := 1.0   # 전리품(상자·아이템) 드랍 배수 (난이도별)
var diff_gold_reward := 1.0
var diff_xp_reward := 1.0
var diff_gear_drop := 1.0
var diff_rarity_luck := 0.0
var run_pressure_mult := 1.0  # 패시브·유물이 런 중 추가하는 적 압박과 골드 보상
var global_lifesteal := 0.0  # 유물·세트 효과가 부여하는 모든 무기 명중 흡혈
var diff_label := ""

# UI
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var ult_bar: ProgressBar        # 궁극기 충전 게이지 (하단 중앙)
var ult_bar_label: Label        # "Q 궁극기" / "READY!"
var ult_gauge := 0.0            # 0~1, 처치로 충전 → Q로 발동
var skill_e_cd := 0.0           # 현재 주무기 E 액티브 남은 쿨다운
var skill_hud_label: Label      # E 스킬과 Space 회피 상태 표시
# 장비 시스템 (Phase 3): 3슬롯 + 등급별 랜덤 어픽스
var equipped := {"weapon": {}, "armor": {}, "trinket": {}}   # 슬롯 → 아이템 딕셔너리
var _equip_applied := {}        # stat → 현재 player에 적용된 총량 (교체 시 diff 제거용)
var equip_hud_label: Label      # 장착 3슬롯 표시
var inventory := []             # 미장착 장비 목록 (가방)
var inventory_panel: Control
var inv_equip_box: HBoxContainer
var inv_list_box: VBoxContainer
var inv_detail_label: RichTextLabel
var inv_bag_label: Label
var inv_equip_btn: Button
var inv_discard_btn: Button
var inv_equip_width := 230.0
var inv_stat_label_width := 170.0
var inv_list_item_width := 260.0
var _inv_sel := -1              # 선택한 가방 인덱스
var stat_points := 0            # 미분배 능력치 포인트 (레벨업마다 +1)
var char_stats := {"str": 0, "agi": 0, "vit": 0, "foc": 0}   # 분배 누적치 (리셋 대상)
var attack_element := "phys"    # 내 공격 속성 = 장착 무기 속성 (상성 판정 기준). take_damage가 참조.
var inv_stat_box: VBoxContainer # 인벤토리 좌하단 능력치 분배 UI
var hp_text: Label
var lv_label: Label             # 뱀서식: 최상단 XP 바 안의 레벨 표기
var timer_label: Label          # 뱀서식: 상단 중앙 대형 생존 타이머
var hud_portrait: TextureRect   # HUD 뱃지 초상화 (선택 캐릭터로 갱신)
var perf_label: Label           # FPS·적 수 카운터 (부하 테스트)
var show_perf := true           # F3로 토글
var info_label: Label
var inv_weapons_box: HBoxContainer
var inv_passives_box: HBoxContainer
var inv_bg: Panel
var levelup_panel: Control
var reroll_btn: Button
var banish_btn: Button
var skip_btn: Button
var run_rerolls := 3
var run_banishes := 2
var run_skips := 2
var banished: Dictionary = {}   # 이번 판 밴된 카드 제목
var _banish_mode := false
var _cur_picks: Array = []
var levelup_title: Label
var stat_side: Label   # (미사용) 옛 스탯창 — 뱀서식 개편으로 제거
var lvl_inv: HBoxContainer   # 레벨업 화면 상단 보유 아이템 아이콘 줄
var cards: Array = []
var _card_badges: Array = []   # 카드별 "신규!" 뱃지 라벨
var lvl_stats_box: GridContainer   # 레벨업 좌측 스탯 패널 (아이콘·이름·값 3열)
var char_stats_box: GridContainer  # 캐릭터 선택 좌측 세부 스탯 (뱀서식)
var char_det_name: Label           # 캐릭터 선택 하단 상세: 이름
var char_det_desc: Label           # 캐릭터 선택 하단 상세: 설명·특성
var char_det_spr: TextureRect      # 캐릭터 선택 하단 상세: 스프라이트
var char_det_wicon: TextureRect    # 캐릭터 선택 하단 상세: 시작 무기 아이콘
var end_panel: Control
var end_label: Label
var end_title: Label
var end_build_box: VBoxContainer
var title_panel: Control


func _ready() -> void:
	randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color(0.03, 0.03, 0.05))
	# UI/아이콘 픽셀 선명하게 (기본 linear → nearest)
	get_viewport().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	meta = Meta.load_data()
	var removed_dev_preview_gear := _ensure_gear_meta()   # Phase 5 저장 포맷 정리
	if removed_dev_preview_gear:
		# 개발 자동 캡처가 중단돼도 검수용 장비는 실제 보관함에 남지 않는다.
		Meta.save_data(meta)
	var startup_unlocks := _sync_meta_unlocks()
	if not startup_unlocks.is_empty():
		Meta.save_data(meta)
	# 개발 캡처 전용: 실제 저장은 건드리지 않고 신규 프로필 잠금 UI를 재현한다.
	if "--fresh-profile-preview" in OS.get_cmdline_user_args():
		meta["ach"] = {}
		meta["unlocked_relics"] = {}
		meta["unlocked_chars"] = {"corvius": true, "gustavo": true, "serafina": true}
	Loc.lang = str(meta.get("lang", "ko"))
	sel_char = GameConfig.characters()[0]
	_setup_audio_buses()
	_apply_audio_settings()
	_apply_fx_settings()
	_apply_fullscreen()

	# 픽셀 폰트 전역 적용 (모든 Label/Button)
	var font_res: FontFile = null
	if ResourceLoader.exists("res://assets/fonts/pixel.ttf"):
		font_res = load("res://assets/fonts/pixel.ttf")
	if font_res:
		var ui_theme := Theme.new()
		ui_theme.default_font = font_res
		ui_theme.default_font_size = 15
		get_window().theme = ui_theme

	var s := get_viewport_rect().size

	player = Player.new()
	player.world_size = WORLD
	player.position = WORLD / 2.0
	add_child(player)

	_build_ui(s)

	# ESC 일시정지 감지 (정지 중에도 동작)
	var pc := PauseCatcher.new()
	add_child(pc)
	pc.esc_pressed.connect(_toggle_pause)
	# 치트 키는 타이틀·일시정지(tree paused)에서도 들어와야 해 PauseCatcher 경유
	pc.cheat_key.connect(_on_cheat_key)

	state = State.TITLE
	get_tree().paused = true
	title_panel.visible = true

	if "--autoshot" in OS.get_cmdline_user_args():
		_autoshot()


# UI 레이아웃 검수용 샘플. --autoshot --screen=inventory|forge --ui-preview-gear 에서만 사용하며 저장하지 않는다.
func _seed_gear_ui_preview() -> void:
	var current_weapon := {
		"slot": "weapon", "rarity": "rare", "name": "심연의 단검", "gear_id": "preview-current-weapon", "lvl": 1,
		"weapon_kind": "knife", "element": "dark",
		"affixes": [{"stat": "damage_mult", "name": "공격력", "value": 0.1008, "base_value": 0.09, "pct": true}]}
	var preview_armor := {
		"slot": "armor", "rarity": "common", "name": "강철의 갑옷", "gear_id": "preview-armor", "lvl": 0,
		"affixes": [{"stat": "armor", "name": "방어", "value": 1.0, "base_value": 1.0, "pct": false}]}
	var preview_trinket := {
		"slot": "trinket", "rarity": "epic", "name": "빛나는 부적", "gear_id": "preview-trinket", "lvl": 2,
		"affixes": [{"stat": "regen", "name": "재생", "value": 0.4704, "base_value": 0.36, "pct": false}, {"stat": "pickup_radius", "name": "자석", "value": 28.8, "base_value": 22.0, "pct": false}]}
	var weapon_candidate := {
		"slot": "weapon", "rarity": "epic", "name": "폭풍의 창", "gear_id": "preview-weapon-candidate", "lvl": 0,
		"weapon_kind": "spear", "element": "ice",
		"affixes": [{"stat": "damage_mult", "name": "공격력", "value": 0.145, "base_value": 0.145, "pct": true}, {"stat": "area_mult", "name": "범위", "value": 0.11, "base_value": 0.11, "pct": true}]}
	var armor_candidate := {
		"slot": "armor", "rarity": "rare", "name": "얼어붙은 로브", "gear_id": "preview-armor-candidate", "lvl": 0,
		"affixes": [{"stat": "max_hp", "name": "최대체력", "value": 20.0, "base_value": 20.0, "pct": false}]}
	current_weapon["icon"] = "res://assets/items/gear_dagger.png"
	preview_armor["icon"] = "res://assets/items/gear_plate.png"
	preview_trinket["icon"] = "res://assets/items/gear_amulet.png"
	weapon_candidate["icon"] = "res://assets/items/gear_spear.png"
	armor_candidate["icon"] = "res://assets/items/gear_robe.png"
	meta["gold"] = 240
	meta["stash"] = [current_weapon.duplicate(true), preview_armor.duplicate(true), preview_trinket.duplicate(true), weapon_candidate.duplicate(true), armor_candidate.duplicate(true)]
	meta["loadout"] = {"weapon": current_weapon.duplicate(true), "armor": preview_armor.duplicate(true), "trinket": preview_trinket.duplicate(true)}
	equipped = {"weapon": current_weapon.duplicate(true), "armor": preview_armor.duplicate(true), "trinket": preview_trinket.duplicate(true)}
	inventory = [weapon_candidate.duplicate(true), armor_candidate.duplicate(true)]
	_inv_sel = 0
	stat_points = 2
	char_stats = {"str": 3, "agi": 1, "vit": 0, "foc": 2}


# [개발 도구] --autoshot: 화면을 캡처해 user://autoshot.png로 저장 후 종료.
#   --screen=title|char|diff|inventory|forge : 해당 메뉴 화면을 캡처 (기본: 런 시작 후 HUD)
#   --pause                  : 일시정지 화면 캡처
func _autoshot() -> void:
	await get_tree().create_timer(0.5, true, false, true).timeout
	var args := OS.get_cmdline_user_args()
	# [개발 도구] --relic-all: 유물 전부 해금 상태로 캡처 (은하 지도 미니맵 등 확인용)
	if "--relic-all" in args:
		var ur: Dictionary = meta.get_or_add("unlocked_relics", {})
		for relic in RELIC_DEFS:
			ur[str(relic["key"])] = true
	for arg in args:
		if arg.begins_with("--selected-stage="):
			unlocked_stage_count = FINAL_STAGE
			_choose_stage_card(clampi(int(arg.trim_prefix("--selected-stage=")), 1, FINAL_STAGE))
	if "--stage-ui-debug" in args and stage_select_backdrop:
		print("STAGE_UI_DEBUG panel=%s backdrop=%s visible=%s color=%s" % [
			stage_select_panel.get_global_rect(), stage_select_backdrop.get_global_rect(),
			stage_select_backdrop.visible, stage_select_backdrop.color
		])
	if "--map-mouse-click-test" in args:
		var click_passed := await _run_map_mouse_click_test()
		get_tree().quit(0 if click_passed else 1)
		return
	if "--screen=inventory" in args or "--screen=forge" in args:
		if "--ui-preview-gear" in args:
			_seed_gear_ui_preview()
		title_panel.visible = false
		if "--screen=inventory" in args:
			inventory_panel.visible = true
			_refresh_inventory_screen()
		else:
			_open_forge()
			var preview_stash: Array = meta.get("stash", [])
			if "--ui-preview-gear" in args and not preview_stash.is_empty():
				_select_forge_item(0)
		await get_tree().create_timer(0.5, true, false, true).timeout
		var gear_ui_image := get_viewport().get_texture().get_image()
		gear_ui_image.save_png("user://autoshot.png")
		print("AUTOSHOT SAVED: ", ProjectSettings.globalize_path("user://autoshot.png"))
		get_tree().quit()
		return
	for scr in ["title", "char", "stage", "diff", "modifier", "shop", "ach", "collection", "opt"]:
		if ("--screen=" + scr) in args:
			# 구버전 diff/modifier 캡처 인자는 통합된 던전 준비 화면으로 호환한다.
			var panel: Control = {"title": title_panel, "char": char_panel, "diff": stage_select_panel,
				"stage": stage_select_panel, "modifier": stage_select_panel,
				"shop": shop_panel, "ach": achievements_panel, "collection": collection_panel,
				"opt": options_panel}[scr]
			if scr == "shop":
				_refresh_shop()
			elif scr == "ach":
				_refresh_achievements()
			elif scr == "collection":
				for arg in args:
					if arg.begins_with("--collection-tab="):
						var requested_tab := arg.trim_prefix("--collection-tab=")
						if requested_tab in ["evolutions", "unions", "relics", "enemies"]:
							collection_tab = requested_tab
				_refresh_collection()
			_goto_screen(panel)
			panel.visible = true
			await get_tree().create_timer(0.5, true, false, true).timeout
			var im := get_viewport().get_texture().get_image()
			im.save_png("user://autoshot.png")
			print("AUTOSHOT SAVED: ", ProjectSettings.globalize_path("user://autoshot.png"))
			get_tree().quit()
			return
	if "--map-selection-test" in args:
		var selection_errors: Array[String] = []
		unlocked_stage_count = FINAL_STAGE
		for requested_stage in range(1, FINAL_STAGE + 1):
			_choose_stage_card(requested_stage)
			if sel_stage != requested_stage:
				selection_errors.append("card %d selected %d" % [requested_stage, sel_stage])
			var expected_detail := "%d. %s" % [requested_stage, GameConfig.stage_info(requested_stage)["name"]]
			if map_detail_label == null or not expected_detail in map_detail_label.text:
				selection_errors.append("card %d detail did not refresh" % requested_stage)
			if not _prepare_selected_stage():
				selection_errors.append("card %d failed stage preparation" % requested_stage)
			elif map_stage != requested_stage or int(stage_layout.stage_id) != requested_stage:
				selection_errors.append("card %d entered map %d/layout %d" % [requested_stage, map_stage, int(stage_layout.stage_id)])
		var selection_passed := selection_errors.is_empty()
		print("MAP_SELECTION_TEST %s selected=%d map=%d layout=%d" % [
			"PASS" if selection_passed else "FAIL", sel_stage, map_stage, int(stage_layout.stage_id)
		])
		for selection_error in selection_errors:
			push_error(selection_error)
		get_tree().quit(0 if selection_passed else 1)
		return
	# 진화 회귀 검사는 실제 사용자 로드아웃과 무관하게 캐릭터 시작 무기로 수행한다.
	if "--evo-test" in args:
		meta["loadout"] = {"weapon": {}, "armor": {}, "trinket": {}}
	var active_preview := ""
	for arg in args:
		if arg.begins_with("--active-preview="):
			var requested_active := arg.trim_prefix("--active-preview=")
			if WEAPON_ACTIVE_DEFS.has(requested_active):
				active_preview = requested_active
	if active_preview != "":
		var preview_weapon_kind := str({
			"sword": "cleave", "axe": "axe", "staff": "soul_bolt",
			"dagger": "knife", "spear": "spear",
		}[active_preview])
		var preview_element := str({
			"sword": "phys", "axe": "fire", "staff": "fire",
			"dagger": "dark", "spear": "ice",
		}[active_preview])
		var preview_active_def: Dictionary = WEAPON_ACTIVE_DEFS[active_preview]
		var preview_loadout: Dictionary = (meta.get("loadout", {}) as Dictionary).duplicate(true)
		preview_loadout["weapon"] = {
			"slot": "weapon", "rarity": "epic", "name": "검수용 %s" % str(preview_active_def["name"]),
			"gear_id": "active-preview-%s" % active_preview, "lvl": 0, "affixes": [],
			"weapon_kind": preview_weapon_kind, "element": preview_element,
			"icon": str(preview_active_def["icon"]),
		}
		meta["loadout"] = preview_loadout
	title_panel.visible = false
	sel_modifier = {}
	_start_game(GameConfig.difficulties()[0])

	# --active-preview=<sword|axe|staff|dagger|spear>: E 스킬과 HUD를 실제 렌더로 검수한다.
	if active_preview != "":
		if state == State.PAUSED:
			_toggle_pause()
		weapons.clear()
		wtimer.clear()
		xp_to_next = 999999
		if stage_label:
			stage_label.visible = false
		if levelup_panel:
			levelup_panel.visible = false
		var impact_center := player.position + Vector2.RIGHT * 180.0
		_current_wave["elite"] = 0.0
		for i in 11:
			var spawn_pos := impact_center
			match active_preview:
				"axe":
					spawn_pos = player.position + Vector2.from_angle(TAU * i / 11.0) * 125.0
				"staff":
					spawn_pos = impact_center + Vector2.from_angle(TAU * i / 11.0) * 68.0
				_:
					var lane := float(i - 5) * 18.0
					spawn_pos = player.position + Vector2(105.0 + absf(lane) * 2.2, lane)
			if stage_layout:
				spawn_pos = stage_layout.nearest_walkable(spawn_pos, 18.0)
			_make_enemy(spawn_pos, false, null, 4.0, true)
		for preview_enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(preview_enemy):
				preview_enemy.hp = 5000.0
				preview_enemy.max_hp = 5000.0
		await get_tree().process_frame
		match active_preview:
			"sword":
				_fire_sword_active(Vector2.RIGHT)
			"axe":
				_fire_axe_active()
			"staff":
				_fire_staff_active(impact_center)
			"dagger":
				_fire_dagger_active(Vector2.RIGHT)
			"spear":
				_fire_spear_active(Vector2.RIGHT)
		skill_e_cd = _weapon_active_cooldown()
		_refresh_skill_hud()
		# 숨긴 GUI 창은 Windows에서 1 FPS로 스로틀될 수 있다. 짧은 FX가 한 프레임 만에
		# 사라지지 않도록 중간 프레임에 고정해 실제 모양을 안정적으로 캡처한다.
		var preview_arrow_index := 0
		for preview_node in get_children():
			if preview_node is Effect:
				preview_node.life = preview_node.max_life * 0.52
				preview_node.process_mode = Node.PROCESS_MODE_DISABLED
				preview_node.queue_redraw()
			elif preview_node is FxAnim:
				preview_node._t = 0.12
				preview_node.process_mode = Node.PROCESS_MODE_DISABLED
				preview_node.queue_redraw()
			elif preview_node is Arrow:
				preview_node.position += preview_node.velocity.normalized() * (54.0 + preview_arrow_index * 10.0)
				preview_arrow_index += 1
				preview_node.process_mode = Node.PROCESS_MODE_DISABLED
				preview_node.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		var active_image := get_viewport().get_texture().get_image()
		active_image.save_png("user://autoshot.png")
		print("ACTIVE_PREVIEW %s" % active_preview)
		print("AUTOSHOT SAVED: ", ProjectSettings.globalize_path("user://autoshot.png"))
		get_tree().quit()
		return

	# --gemcap-test : 젬 상한 이후 XP 보존 + 현재 처치 위치 재등장 회귀 테스트.
	if "--gemcap-test" in args:
		player.pickup_radius = 1.0
		for i in GEM_CAP:
			var test_gem := Gem.new()
			test_gem.value = 1
			test_gem.position = player.position + Vector2(320.0 + i, 320.0)
			add_child(test_gem)
		await get_tree().process_frame
		var spawn_pos := player.position + Vector2(100.0, 0.0)
		_spawn_gem(spawn_pos, 7)
		await get_tree().process_frame
		var gem_nodes := get_tree().get_nodes_in_group("gems")
		var total_value := 0
		var nearest_spawn: float = INF
		for node in gem_nodes:
			var test_gem := node as Gem
			if test_gem:
				total_value += test_gem.value
				nearest_spawn = minf(nearest_spawn, test_gem.position.distance_to(spawn_pos))
		var passed := gem_nodes.size() == GEM_CAP and total_value == GEM_CAP + 7 and nearest_spawn < 1.0
		print("GEM_CAP_TEST %s count=%d xp=%d nearest=%.1f" % ["PASS" if passed else "FAIL", gem_nodes.size(), total_value, nearest_spawn])
		if not passed:
			push_error("Gem cap regression test failed")
		get_tree().quit(0 if passed else 1)
		return

	# --telemetry-test : 실제 체력 감소량만 전투 통계에 누적되는지 검증.
	if "--telemetry-test" in args:
		run_damage_dealt = 0.0
		run_damage_taken = 0.0
		var enemy_probe := Enemy.new()
		enemy_probe.hp = 100.0
		add_child(enemy_probe)
		enemy_probe.take_damage(30.0)
		var boss_probe := Boss.new()
		boss_probe.hp = 200.0
		add_child(boss_probe)
		boss_probe.take_damage(50.0)
		player.hp = 100.0
		apply_player_damage(12.0)
		var passed := is_equal_approx(run_damage_dealt, 80.0) and is_equal_approx(run_damage_taken, 12.0)
		print("TELEMETRY_TEST %s dealt=%.1f taken=%.1f" % ["PASS" if passed else "FAIL", run_damage_dealt, run_damage_taken])
		if not passed:
			push_error("Combat telemetry regression test failed")
		get_tree().quit(0 if passed else 1)
		return

	# --balance-test : 0/10/20/30분 대표 적과 피날레 보스의 실효 수치 회귀 테스트.
	if "--balance-test" in args:
		var samples := [
			{"time":0.0, "key":"slime"}, {"time":600.0, "key":"hellhound"},
			{"time":1200.0, "key":"void_wraith"}, {"time":1800.0, "key":"dark_knight"},
		]
		var late_hp := {}
		var late_touch := 0.0
		for difficulty in GameConfig.difficulties():
			diff_enemy_hp = float(difficulty["enemy_hp"])
			diff_enemy_speed = float(difficulty["enemy_speed"])
			run_pressure_mult = 1.0
			for sample in samples:
				var probe := Enemy.new()
				probe.setup(GameConfig.tier_by_key(sample["key"]), float(sample["time"]))
				_apply_enemy_run_scaling(probe, float(sample["time"]))
				print("BALANCE %s t=%4d %s hp=%.1f dmg=%.1f spd=%.1f" % [difficulty["key"], int(sample["time"]), sample["key"], probe.hp, probe.touch_damage, probe.speed])
				if float(sample["time"]) >= RUN_TIME:
					late_hp[difficulty["key"]] = probe.hp
					late_touch = probe.touch_damage
				probe.free()
		var hp_before := diff_enemy_hp
		var speed_before := diff_enemy_speed
		for danger_stage in range(2, FINAL_STAGE + 1):
			_advance_stage(danger_stage)
		var stage_scale_ok := is_equal_approx(diff_enemy_hp, hp_before) and is_equal_approx(diff_enemy_speed, speed_before)
		var passed := (float(late_hp.get("easy", 0.0)) >= 350.0 and float(late_hp.get("easy", 0.0)) <= 800.0
			and float(late_hp.get("normal", 0.0)) >= 800.0 and float(late_hp.get("normal", 0.0)) <= 1500.0
			and float(late_hp.get("hard", 0.0)) >= 1200.0 and float(late_hp.get("hard", 0.0)) <= 2200.0
			and float(late_hp.get("nightmare", 0.0)) >= 1700.0 and float(late_hp.get("nightmare", 0.0)) <= 3000.0
			and late_touch >= 25.0 and late_touch <= 35.0 and stage_scale_ok)
		print("BALANCE_TEST %s late_hp=%s touch=%.1f stage_multiplier_removed=%s" % ["PASS" if passed else "FAIL", late_hp, late_touch, stage_scale_ok])
		if not passed:
			push_error("Balance curve regression test failed")
		get_tree().quit(0 if passed else 1)
		return

	# --data-test : 캐릭터 업적·무기 해금·진화·유니온·웨이브 참조 무결성 검사.
	if "--data-test" in args:
		var errors: Array[String] = []
		for character in GameConfig.characters():
			var win_key := "win_" + str(character["key"])
			if _ach_by_key(win_key).is_empty():
				errors.append("missing character achievement: " + win_key)
			var character_unlock := str(character.get("unlock", ""))
			if character_unlock != "" and _ach_by_key(character_unlock).is_empty():
				errors.append("missing character unlock achievement: " + character_unlock)
		for relic in RELIC_DEFS:
			if _ach_by_key(str(relic["unlock"])).is_empty():
				errors.append("missing relic unlock achievement: " + str(relic["unlock"]))
			if not FileAccess.file_exists(str(relic.get("icon", ""))):
				errors.append("missing relic icon: " + str(relic["key"]))
		for weapon_key in UNLOCK_WEAPONS.keys():
			if not (weapon_key in ALL_WEAPONS):
				errors.append("unknown unlock weapon: " + str(weapon_key))
			if _ach_by_key(str(UNLOCK_WEAPONS[weapon_key])).is_empty():
				errors.append("missing unlock achievement: " + str(UNLOCK_WEAPONS[weapon_key]))
		var passive_defs := _passive_defs()
		for weapon_key in EVO_RECIPE.keys():
			if not (weapon_key in ALL_WEAPONS):
				errors.append("unknown evolution weapon: " + str(weapon_key))
			var passive_key := str(EVO_RECIPE[weapon_key]["passive"])
			if not passive_defs.has(passive_key):
				errors.append("unknown evolution passive: " + passive_key)
			if not FileAccess.file_exists(str(EVO_RECIPE[weapon_key].get("icon", ""))):
				errors.append("missing evolution icon: " + str(weapon_key))
		for union_data in UNION_DEFS:
			for material in [union_data["a"], union_data["b"]]:
				if not (material in ALL_WEAPONS):
					errors.append("unknown union material: " + str(material))
		for stage_index in range(1, FINAL_STAGE + 1):
			for enemy_key in GameConfig.stage_roster(stage_index):
				if str(GameConfig.tier_by_key(enemy_key)["key"]) != str(enemy_key):
					errors.append("unknown stage enemy: " + str(enemy_key))
			var field_passives: Array = GameConfig.stage_info(stage_index).get("field_passives", [])
			if field_passives.size() != 4:
				errors.append("stage must have four field passives: %d" % stage_index)
			for passive_key in field_passives:
				if not passive_defs.has(str(passive_key)):
					errors.append("unknown stage passive: " + str(passive_key))
		if GameConfig.WAVE_SCHEDULE.size() != 30:
			errors.append("wave schedule is not 30 minutes")
		var passed := errors.is_empty()
		print("DATA_TEST %s characters=%d achievements=%d evolutions=%d unions=%d waves=%d" % ["PASS" if passed else "FAIL", GameConfig.characters().size(), ACHIEVEMENTS.size(), EVO_RECIPE.size(), UNION_DEFS.size(), GameConfig.WAVE_SCHEDULE.size()])
		for error in errors:
			push_error(error)
		get_tree().quit(0 if passed else 1)
		return

	# --stage-layout-test : 맵별 시작점·스테이지 아이템·유물 슬롯이 이동 가능 영역 안에 있는지 검사.
	if "--stage-layout-test" in args:
		var layout_errors: Array[String] = []
		for stage_index in range(1, FINAL_STAGE + 1):
			var layout = StageLayoutData.make(stage_index, Color(GameConfig.stage_info(stage_index)["tint"]))
			if not layout.is_walkable(WORLD * 0.5, Player.BASE_RADIUS):
				layout_errors.append("start outside walkable area: %d" % stage_index)
			for item_pos in layout.item_positions:
				if not layout.is_walkable(item_pos, 18.0):
					layout_errors.append("stage item outside walkable area: %d" % stage_index)
			if not layout.is_walkable(layout.relic_position, 18.0):
				layout_errors.append("relic slot outside walkable area: %d" % stage_index)
			var first_step: Vector2 = layout.steer_toward(WORLD * 0.5, layout.item_positions[0], 36.0, 18.0)
			if first_step.distance_squared_to(WORLD * 0.5) < 1.0:
				layout_errors.append("no initial route to stage item: %d" % stage_index)
		var layout_passed := layout_errors.is_empty()
		print("STAGE_LAYOUT_TEST %s maps=%d" % ["PASS" if layout_passed else "FAIL", FINAL_STAGE])
		for layout_error in layout_errors:
			push_error(layout_error)
		get_tree().quit(0 if layout_passed else 1)
		return

	# --progression-test : 업적 → 캐릭터/유물 영구 해금 연결을 저장 없이 검증.
	if "--progression-test" in args:
		meta["ach"] = {"first_win": true, "survivor": true}
		meta["unlocked_chars"] = {"corvius": true, "gustavo": true, "serafina": true}
		meta["unlocked_relics"] = {}
		var unlocked_names := _sync_meta_unlocks()
		meta["unlocked_relics"]["witch_tear"] = true
		run_pressure_mult = 1.0
		xp_mult = 1.0
		greed_mult = 1.0
		_apply_unlocked_relic_effects()
		var relic_effect_ok := (is_equal_approx(run_pressure_mult, 1.12)
			and is_equal_approx(xp_mult, 1.12) and is_equal_approx(greed_mult, 1.12))
		var passed := (_is_char_unlocked(GameConfig.characters()[4])
			and _is_char_unlocked(GameConfig.characters()[6])
			and _has_relic("yellow_sign") and _has_relic("milky_map")
			and unlocked_names.size() == 4
			and relic_effect_ok
			and Meta.initial_chars_for_save(false, 0).size() == 3
			and Meta.initial_chars_for_save(true, 0).size() == 8)
		print("PROGRESSION_TEST %s chars=%s relics=%s new=%s" % ["PASS" if passed else "FAIL", meta["unlocked_chars"], meta["unlocked_relics"], unlocked_names])
		if not passed:
			push_error("Meta progression regression test failed")
		get_tree().quit(0 if passed else 1)
		return

	# --xp-test : 주요 레벨의 단일/누적 XP가 목표 성장 구간에 있는지 검사.
	if "--xp-test" in args:
		var cumulative := 10 # Lv1 → Lv2
		var totals := {2: cumulative}
		var monotonic := true
		var previous_req := 10
		for current_level in range(2, 100):
			var requirement := _xp_requirement(current_level)
			if requirement < previous_req:
				monotonic = false
			previous_req = requirement
			cumulative += requirement
			var reached_level := current_level + 1
			if reached_level in [10, 25, 50, 75, 100]:
				totals[reached_level] = cumulative
				print("XP_CURVE Lv%d next=%d cumulative=%d" % [reached_level, _xp_requirement(reached_level), cumulative])
		var passed := (monotonic and _xp_requirement(25) >= 280 and _xp_requirement(25) <= 420
			and int(totals.get(25, 0)) >= 3400 and int(totals.get(25, 0)) <= 5000
			and int(totals.get(50, 0)) >= 15000 and int(totals.get(50, 0)) <= 21000
			and int(totals.get(75, 0)) >= 37000 and int(totals.get(75, 0)) <= 50000)
		print("XP_TEST %s totals=%s" % ["PASS" if passed else "FAIL", totals])
		if not passed:
			push_error("XP curve regression test failed")
		get_tree().quit(0 if passed else 1)
		return

	# --evo-test : 집중 성장 선택지와 10분 상자 제한을 저장 변경 없이 검사.
	if "--evo-test" in args:
		var start_weapon := str(sel_char.get("weapon", "arrow"))
		var material_key := str(EVO_RECIPE[start_weapon]["passive"])
		var choices_ok := true
		# 시작 무기 레벨은 저장 상태(유물 「위대한 복음」 등)에 따라 1이 아닐 수 있으므로
		# 만렙까지 실제 필요한 강화 횟수를 동적으로 계산한다.
		var upgrades_needed: int = MAX_WLEVEL - int(weapons.get(start_weapon, 1))
		# 무기 레벨 시간 소프트캡(_weapon_time_cap)이 초반엔 Lv8을 막으므로,
		# 만렙 시뮬레이션은 10분 경과 상태(진화 시점)로 두고 돌린다.
		time_survived = EVO_START_TIME + 5.0
		for upgrade_index in upgrades_needed:
			var picks := _pick3(_card_options())
			var weapon_card: Dictionary = {}
			var material_offered := false
			for card in picks:
				if card.get("t", "") == "w" and card.get("key", "") == start_weapon:
					weapon_card = card
				if card.get("t", "") == "p" and card.get("key", "") == material_key:
					material_offered = true
			choices_ok = choices_ok and not weapon_card.is_empty() and material_offered
			if weapon_card.is_empty():
				break
			(weapon_card["act"] as Callable).call()
		var material_card: Dictionary = {}
		for card in _card_options():
			if card.get("t", "") == "p" and card.get("key", "") == material_key:
				material_card = card
				break
		if not material_card.is_empty():
			(material_card["act"] as Callable).call()
		var ready_kind: String = _ready_evolution_kind()
		time_survived = EVO_START_TIME - 1.0
		var blocked_before_ten: bool = not _can_evolve_from_chest()
		time_survived = EVO_START_TIME + 1.0
		var enabled_after_ten: bool = _can_evolve_from_chest()
		var passed: bool = (choices_ok and int(weapons.get(start_weapon, 0)) == MAX_WLEVEL
			and int(passives.get(material_key, 0)) >= 1 and ready_kind == start_weapon
			and blocked_before_ten and enabled_after_ten)
		print("EVO_TEST %s weapon=%s lv=%d material=%s offered=%s gate_599=%s gate_601=%s" % ["PASS" if passed else "FAIL", start_weapon, int(weapons.get(start_weapon, 0)), material_key, choices_ok, blocked_before_ten, enabled_after_ten])
		if not passed:
			push_error("Evolution pacing regression test failed")
		get_tree().quit(0 if passed else 1)
		return

	# --growth : 캐릭터별 성장 특성이 레벨에 따라 실제로 붙는지 콘솔 검증
	if "--growth" in args:
		for c in GameConfig.characters():
			sel_char = c
			var g: Dictionary = c.get("growth", {})
			player.damage_mult = 1.0; player.area_mult = 1.0; player.cooldown_mult = 1.0
			player.crit_chance = 0.0; player.regen = 0.0; player.armor = 0.0
			player.amount = 0; player.speed = 125.0; xp_mult = 1.0
			_base_speed = 125.0
			_growth_tier = 0
			level = 1
			var before := _growth_probe(str(g.get("stat", "")))
			level = int(g.get("per", 10)) * int(g.get("max", 5))   # 만렙 단계
			_apply_char_growth()
			var after := _growth_probe(str(g.get("stat", "")))
			print("%-10s %-9s Lv1=%.3f → Lv%d=%.3f  (단계 %d)" % [
				c["key"], g.get("stat", "-"), before, level, after, _growth_tier])
		get_tree().quit()
		return

	# --wfx=<무기키> : 해당 무기를 지급하고 발사 순간을 캡처 (모션 점검용)
	for a in args:
		if a.begins_with("--wfx="):
			var wk := a.split("=")[1]
			weapons[wk] = 5
			wtimer[wk] = 0.0
			await get_tree().create_timer(1.0, true, false, true).timeout
			if state == State.PAUSED:
				_toggle_pause()
			# 발사 직후를 잡기 위해 짧게 여러 프레임 대기
			await get_tree().create_timer(0.06, true, false, true).timeout
			var imw := get_viewport().get_texture().get_image()
			imw.save_png("user://autoshot.png")
			print("AUTOSHOT SAVED: ", ProjectSettings.globalize_path("user://autoshot.png"))
			get_tree().quit()
			return

	# --census=<초> : 시간대별 적 수·젬 수를 콘솔에 찍음 (뱀서 밀도 비교용)
	for a in args:
		if a.begins_with("--census="):
			var total := float(a.split("=")[1])
			if state == State.PAUSED:
				_toggle_pause()
			var t := 0.0
			print("  분:초 |  적  | 젬  | 코인 | FPS")
			while t < total:
				await get_tree().create_timer(10.0, true, false, true).timeout
				t += 10.0
				if state == State.PAUSED:
					_toggle_pause()
				print("  %02d:%02d | %4d | %3d | %4d | %d" % [
					int(time_survived) / 60, int(time_survived) % 60,
					get_tree().get_nodes_in_group("enemies").size(),
					get_tree().get_nodes_in_group("gems").size(),
					get_tree().get_nodes_in_group("coins").size(),
					Engine.get_frames_per_second()])
			get_tree().quit()
			return

	# --items : 젬 등급별 + 픽업 종류별을 한 줄로 깔고 캡처 (크기 비교용)
	if "--items" in args:
		if state == State.PAUSED:
			_toggle_pause()
		await get_tree().create_timer(0.3, true, false, true).timeout
		# 레벨업 카드가 떠서 화면을 가리지 않게 XP를 아주 멀리 밀어둠
		xp_to_next = 999999
		if levelup_panel:
			levelup_panel.visible = false
		# 자석 범위 밖에 배치 — 안 그러면 젬이 즉시 빨려가서 안 보임
		player.pickup_radius = 1.0
		var base := player.position + Vector2(-150.0, -110.0)
		for i in 4:   # 젬 4등급 (파랑/초록/빨강/금)
			var g := Gem.new()
			g.value = [1, 5, 12, 30][i]
			g.position = base + Vector2(i * 46.0, 0)
			add_child(g)
		var kinds := ["heart", "magnet", "clock", "rosary", "chest", "chicken"]
		for i in kinds.size():
			var p := Pickup.new()
			p.kind = kinds[i]
			p.position = base + Vector2(i * 46.0, 52.0)
			add_child(p)
		await get_tree().create_timer(0.4, true, false, true).timeout
		var imi := get_viewport().get_texture().get_image()
		imi.save_png("user://autoshot.png")
		print("AUTOSHOT SAVED: ", ProjectSettings.globalize_path("user://autoshot.png"))
		get_tree().quit()
		return

	# --map : 현재 스테이지의 바닥/지형을 캡처 (--selected-stage=N 과 함께 사용)
	if "--map" in args:
		if true:
			if state == State.PAUSED:
				_toggle_pause()
			await get_tree().create_timer(0.6, true, false, true).timeout
			var imm2 := get_viewport().get_texture().get_image()
			imm2.save_png("user://autoshot.png")
			print("AUTOSHOT SAVED: ", ProjectSettings.globalize_path("user://autoshot.png"))
			get_tree().quit()
			return

	# --mobs : 플레이어 주위에 몹을 깔고 캡처 (크기 점검용)
	if "--mobs" in args:
		if state == State.PAUSED:
			_toggle_pause()
		if stage_label:
			stage_label.visible = false
		await get_tree().create_timer(0.3, true, false, true).timeout
		for i in 24:
			var ang := TAU * i / 24.0
			var preview_distance := 76.0 if i == 0 else randf_range(70.0, 240.0)
			_make_enemy(player.position + Vector2.from_angle(ang) * preview_distance, i == 0)
		# 근거리 적의 예고 동작이 끝나기 전에 찍어 크기와 공격 가독성을 함께 검수한다.
		await get_tree().create_timer(0.2, true, false, true).timeout
		var imm := get_viewport().get_texture().get_image()
		imm.save_png("user://autoshot.png")
		print("AUTOSHOT SAVED: ", ProjectSettings.globalize_path("user://autoshot.png"))
		get_tree().quit()
		return

	# --zone : 장판 3종을 한 화면에 띄우고 캡처 (아트 점검용)
	if "--zone" in args:
		await get_tree().create_timer(0.6, true, false, true).timeout
		if state == State.PAUSED:
			_toggle_pause()
		var zdefs := [["res://assets/anim/zone_holy", Color(1.0, 0.85, 0.4), -190.0],
			["res://assets/anim/zone_lava", Color(1.0, 0.5, 0.2), 0.0],
			["res://assets/anim/zone_poison", Color(0.4, 1.0, 0.4), 190.0]]
		for zd in zdefs:
			var z := VoidZone.new()
			z.radius = 84.0
			z.dps = 0.0
			z.pull = 0.0
			z.life = 30.0
			z.col = zd[1]
			z.anim_dir = zd[0]
			z.position = player.position + Vector2(zd[2], 0.0)
			add_child(z)
		await get_tree().create_timer(0.8, true, false, true).timeout
		var imz := get_viewport().get_texture().get_image()
		imz.save_png("user://autoshot.png")
		print("AUTOSHOT SAVED: ", ProjectSettings.globalize_path("user://autoshot.png"))
		get_tree().quit()
		return

	# --blade=<레벨> : 회전검을 즉시 지급하고 캡처 (이펙트 점검용)
	for a in args:
		if a.begins_with("--blade="):
			weapons["blade"] = int(a.split("=")[1])
			if "--evo" in args:
				evolved["blade"] = true
			await get_tree().create_timer(1.2, true, false, true).timeout
			if state == State.PAUSED:
				_toggle_pause()
			await get_tree().process_frame
			var imb := get_viewport().get_texture().get_image()
			imb.save_png("user://autoshot.png")
			print("AUTOSHOT SAVED: ", ProjectSettings.globalize_path("user://autoshot.png"))
			get_tree().quit()
			return

	# --chest=<초> : 3릴 룰렛을 띄우고 [열기] 후 지정 시각에 캡처 (연출 단계 점검용)
	for a in args:
		if a.begins_with("--chest="):
			var at := float(a.split("=")[1])
			await get_tree().create_timer(0.3, true, false, true).timeout
			var icons: Array = []
			for k in WICON.keys():
				var t := Assets.tex(WICON[k])
				if t:
					icons.append(t)
			var rw: Array = []
			for i in 3:
				rw.append({"icon": icons[i % icons.size()], "name": "테스트 보상 %d" % (i + 1)})
			_show_roulette(rw, "✦ 보물상자 ✦", 55.0)
			await get_tree().create_timer(0.2, true, false, true).timeout
			var rl: ChestRoulette = ui_overlay.get_children().filter(
				func(x: Node) -> bool: return x is ChestRoulette)[0]
			rl._open()
			await get_tree().create_timer(at, true, false, true).timeout
			var im2 := get_viewport().get_texture().get_image()
			im2.save_png("user://autoshot.png")
			print("AUTOSHOT SAVED: ", ProjectSettings.globalize_path("user://autoshot.png"))
			get_tree().quit()
			return
	await get_tree().create_timer(6.0, true, false, true).timeout
	# 포커스 상실로 자동 일시정지가 걸렸으면 해제하고 찍는다
	if state == State.PAUSED:
		_toggle_pause()
	if "--pause" in OS.get_cmdline_user_args():
		_toggle_pause()
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://autoshot.png")
	print("AUTOSHOT SAVED: ", ProjectSettings.globalize_path("user://autoshot.png"))
	get_tree().quit()


# ---------------------------------------------------------------------
#  루프
# ---------------------------------------------------------------------
func _process(delta: float) -> void:
	queue_redraw()
	# 슬로우모션 자동 복귀 (실시간 기준)
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= _slowmo_until:
		Engine.time_scale = 1.0
	if state != State.PLAYING:
		return

	time_survived += delta
	_blade_angle += delta * 3.2
	# 업적 토스트 타이머
	if ach_toast_t > 0.0:
		ach_toast_t -= delta
		if ach_toast_t <= 0.0 and ach_toast:
			ach_toast.visible = false

	# 자동 기본공격 위에 E 무기 스킬·Space 회피·Q 궁극기를 얹어 능동 전투 리듬을 만든다.

	# 화면 흔들림 (옵션으로 끌 수 있음 — 멀미 대응)
	if shake_t > 0.0:
		shake_t -= delta
		if player.cam:
			var mag: float = 6.0 if shake_enabled else 0.0
			player.cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * mag
	elif player.cam and player.cam.offset != Vector2.ZERO:
		player.cam.offset = Vector2.ZERO

	if player.regen > 0.0:
		player.hp = min(player.max_hp, player.hp + player.regen * delta)

	# 쿨다운 무기 발동 (뱀서식: 기본공격 없음 — 시작무기가 캐릭터 정체성)
	for kind in wtimer.keys():
		wtimer[kind] -= delta
		if wtimer[kind] <= 0.0:
			_fire_weapon(kind)
			_weapon_muzzle(kind)   # 발사 순간 무기별 섬광
			wtimer[kind] = _weapon_cooldown(kind)

	# 진행 (시간 기반) / 보스
	if abyss_mode:
		# 심연: 예약 시간마다 보스 (무한)
		if not boss_spawned and time_survived >= next_boss_time:
			last_boss_stage = stage_num
			_spawn_boss()
	elif map_stage > 0:
		# 던전 모드(B블렌드): 5분 생존 → 단일 목표 보스 → 처치=클리어. 다중보스·사신 없음.
		if not boss_spawned and not _boss_is_objective:
			if not reaper_warned and time_survived >= DUNGEON_BOSS_TIME - 45.0:
				reaper_warned = true
				_event_banner("⚠ 곧 던전 보스가 나타난다...")
			if time_survived >= DUNGEON_BOSS_TIME:
				_spawn_dungeon_boss()

	# 분 단위 웨이브 표: 적 조합·밀도·엘리트·특수 이벤트를 함께 교체한다.
	var current_minute := int(time_survived / 60.0)
	if current_minute != _wave_minute or featured_enemy == "":
		_wave_minute = current_minute
		_current_wave = GameConfig.wave_for_minute(current_minute, map_stage)
		featured_enemy = str(_current_wave.get("primary", "slime"))
		var scheduled_event := int(_current_wave.get("event", -1))
		if scheduled_event >= 0 and not boss_spawned and current_minute > 0:
			_spawn_event(scheduled_event)

	# 스테이지 배너 타이머
	if stage_banner_t > 0.0:
		stage_banner_t -= delta
		if stage_banner_t <= 0.0 and stage_label:
			stage_label.visible = false
	# 뱀서식: 보스 등장 중에도 호드는 계속 몰려온다 (보스가 게임을 멈추지 않음)
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		# 뱀서형: 초반부터 촘촘하게 (0.45s → 0.16s). 보스 중엔 약간 완화. (밀도 2차 상향)
		var boss_ease: float = 1.4 if boss_spawned else 1.0
		var wave_density: float = maxf(0.5, float(_current_wave.get("density", 1.0)))
		var density_pace: float = lerpf(1.0, wave_density, 0.45)
		spawn_timer = max(0.14, max(0.16, 0.45 - time_survived * 0.0008) / density_pace) * diff_spawn * boss_ease
		_spawn_wave()

	# 주기적으로 새 아이템 스폰 (뱀서식: 필드 아이템은 드물게)
	pickup_timer -= delta
	if pickup_timer <= 0.0:
		pickup_timer = 34.0 / max(0.4, diff_loot)   # 뱀서식으로 더 뜸하게 (쉬움 ~28초 / 보통 ~44초)
		if get_tree().get_nodes_in_group("pickups").size() < int(2 + 2 * diff_loot):   # 화면 상한 하향 (쉬움 4 / 보통 3)
			_spawn_pickup_random()

	# 주기적으로 파괴 오브젝트 스폰 (플레이어 주변) — 뱀서식으로 드물게
	breakable_timer -= delta
	if breakable_timer <= 0.0:
		breakable_timer = 10.0
		if get_tree().get_nodes_in_group("breakables").size() < 8:
			_spawn_breakable(player.position + Vector2.from_angle(randf() * TAU) * randf_range(220.0, 460.0))

	_update_ui()


func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return

	# 능동 스킬 쿨다운 감소 + HUD 갱신
	if skill_e_cd > 0.0:
		skill_e_cd = maxf(0.0, skill_e_cd - delta)
	_refresh_skill_hud()

	var enemies := get_tree().get_nodes_in_group("enemies")

	# 공간 격자(spatial hash): 적을 셀에 담아 화살이 주변 셀만 검사 → O(화살×적) 제거
	const GRID := 80.0
	var grid := {}
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var gk := Vector2i(int(floor(e.position.x / GRID)), int(floor(e.position.y / GRID)))
		if grid.has(gk):
			grid[gk].append(e)
		else:
			grid[gk] = [e]

	# 적끼리 밀어내기(separation): 같은/인접 셀만 검사해 겹친 무리를 벌린다 (뱀서식 '벽').
	# ponytail: 격자 지역 검사 — 한 셀이 병적으로 밀집하면 O(cell²)로 degrade. MAX_ENEMIES 300에선 허용.
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var ex := int(floor(e.position.x / GRID))
		var ey := int(floor(e.position.y / GRID))
		var push := Vector2.ZERO
		for gx in range(ex - 1, ex + 2):
			for gy in range(ey - 1, ey + 2):
				var cell = grid.get(Vector2i(gx, gy), null)
				if cell == null:
					continue
				for o in cell:
					if o == e or not is_instance_valid(o):
						continue
					var diff: Vector2 = e.position - o.position
					var dist := diff.length()
					var mind: float = e.radius + o.radius
					if dist > 0.01 and dist < mind:
						push += diff / dist * (mind - dist)
		# 부드럽게(0.5) + 프레임당 상한(6px)으로 튐 방지
		e.sep = (push * 0.5).limit_length(6.0)

	# 화살 투사체 (격자로 근처 적만 검사)
	for a in get_tree().get_nodes_in_group("arrows"):
		if not is_instance_valid(a):
			continue
		var acx := int(floor(a.position.x / GRID))
		var acy := int(floor(a.position.y / GRID))
		var dead := false
		for gx in range(acx - 1, acx + 2):
			if dead:
				break
			for gy in range(acy - 1, acy + 2):
				var cell = grid.get(Vector2i(gx, gy), null)
				if cell == null:
					continue
				for e in cell:
					if not is_instance_valid(e) or a.hit.has(e):
						continue
					if a.position.distance_to(e.position) < a.radius + e.radius:
						a.hit[e] = true
						_apply_arrow_hit(a, e)
						# 튕김(리코셰): 다음 가장 가까운 미타격 적으로 방향 전환
						if a.bounce > 0:
							var nxt = _nearest_unhit_enemy(a)
							if nxt:
								a.bounce -= 1
								a.velocity = (nxt.position - a.position).normalized() * maxf(a.velocity.length(), 340.0)
							elif a.pierce <= 0:
								a.queue_free()
								dead = true
								break
							else:
								a.pierce -= 1
						elif a.pierce <= 0:
							a.queue_free()
							dead = true
							break
						else:
							a.pierce -= 1
				if dead:
					break
		if is_instance_valid(a) and boss and is_instance_valid(boss):
			if not a.hit.has(boss) and a.position.distance_to(boss.position) < a.radius + boss.radius:
				a.hit[boss] = true
				_apply_arrow_hit(a, boss)
				if a.pierce <= 0:
					a.queue_free()
				else:
					a.pierce -= 1
		# 파괴 오브젝트 타격 (촛대·항아리·상자)
		if is_instance_valid(a):
			for b in get_tree().get_nodes_in_group("breakables"):
				if not is_instance_valid(b) or a.hit.has(b):
					continue
				if a.position.distance_to(b.position) < a.radius + b.radius:
					a.hit[b] = true
					b.take_damage(a.damage)
					# 타격 이펙트 (파괴 오브젝트에도 명중 연출 — 딜 들어가는 게 보이게)
					spawn_fx(a.fx_hit if a.fx_hit != "" else "fx_hit", b.position, 40.0)
					_spawn_dmg_num(b.position, max(1, int(round(a.damage))), false)
					if a.pierce <= 0:
						a.queue_free()
						break
					else:
						a.pierce -= 1

	# 신성 오라 (지속 범위 피해)
	if weapons.has("aura"):
		var ar := _aura_radius()
		var dps := _aura_dps()
		_aura_pulse_t -= delta
		for e in enemies:
			if is_instance_valid(e) and player.position.distance_to(e.position) < ar + e.radius:
				e.take_damage(dps * delta, false, true)   # dot: 넉백·플래시 없음 (장판·오라 공통)
				if combos.has("aura_frost"):
					e.apply_slow(0.25, 0.4)
		if evolved.get("aura", false) and _aura_pulse_t <= 0.0:
			_aura_pulse_t = 1.25
			for e in enemies:
				if is_instance_valid(e) and player.position.distance_to(e.position) < ar + e.radius:
					e.take_damage(dps * 0.55)
					e.shove(player.position, 95.0)
			_spawn_proc_fx("ring", player.position, ar, Color(1.0, 0.32, 0.08), 0.42)
			_spawn_proc_fx("burst", player.position, ar * 0.32, Color(1.0, 0.82, 0.25), 0.30)
		if boss and is_instance_valid(boss) and player.position.distance_to(boss.position) < ar + boss.radius:
			boss.take_damage(dps * delta)
			if evolved.get("aura", false) and _aura_pulse_t > 1.15:
				boss.take_damage(dps * 0.55)
		# 오라로 파괴 오브젝트도 부숨
		for br in get_tree().get_nodes_in_group("breakables"):
			if is_instance_valid(br) and player.position.distance_to(br.position) < ar + br.radius:
				br.take_damage(dps * delta)

	# 회전 검 (공전 접촉 피해)
	if weapons.has("blade"):
		var cnt := _blade_count()
		var dpsb := _blade_dps()
		var orad := _blade_orbit()
		for i in cnt:
			var ang := _blade_angle + i * TAU / cnt
			var bpos := player.position + Vector2(cos(ang), sin(ang)) * orad
			for e in enemies:
				if is_instance_valid(e) and bpos.distance_to(e.position) < 16.0 + e.radius:
					e.take_damage(dpsb * delta)
			if boss and is_instance_valid(boss) and bpos.distance_to(boss.position) < 16.0 + boss.radius:
				boss.take_damage(dpsb * delta)
			# 회전 검으로 파괴 오브젝트도 부숨
			for br in get_tree().get_nodes_in_group("breakables"):
				if is_instance_valid(br) and bpos.distance_to(br.position) < 16.0 + br.radius:
					br.take_damage(dpsb * delta)
		if evolved.get("blade", false):
			_blade_evo_pulse_t -= delta
			if _blade_evo_pulse_t <= 0.0:
				_blade_evo_pulse_t = 1.05
				var sweep_dir := Vector2.from_angle(_blade_angle)
				var sweep_rad := orad * 1.35
				for e2 in enemies:
					if is_instance_valid(e2):
						var to2: Vector2 = e2.position - player.position
						if to2.length() <= sweep_rad + e2.radius and abs(to2.angle_to(sweep_dir)) < 0.95:
							e2.take_damage(dpsb * 0.65)
				if boss and is_instance_valid(boss):
					var tob2: Vector2 = boss.position - player.position
					if tob2.length() <= sweep_rad + boss.radius and abs(tob2.angle_to(sweep_dir)) < 0.95:
						boss.take_damage(dpsb * 0.65)
				_spawn_proc_fx("slash", player.position, sweep_rad, Color(1.0, 0.22, 0.12), 0.28,
					sweep_dir, player.position + sweep_dir * sweep_rad)

	# 적 접촉: 겹친 적은 몸박 넉백으로 밀어냄(뚫고 지나가지 않게) + 데미지(무적 프레임)
	var _touched := false
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.position.distance_to(player.position) < e.radius + player.radius:
			e.shove(player.position, 240.0)   # 몸박 넉백 (매 프레임 → 몸으로 막힘)
		# 몸 자체는 서로 밀어내지만, 피해는 적이 예고한 타격의 활성 프레임에만 발생한다.
		if not _touched and player.invuln <= 0.0 and e.can_damage_player(player.position, player.radius):
			apply_player_damage(max(1.0, e.touch_damage - player.armor))
			player.invuln = 0.6
			player.play_hurt()
			shake_t = 0.15
			play_sfx("hurt", -8.0, 0.3)
			_touched = true
	if player.invuln <= 0.0 and boss and is_instance_valid(boss):
		if boss.position.distance_to(player.position) < boss.radius + player.radius:
			var boss_touch := (22.0 + stage_num * 3.0) * sqrt(diff_enemy_hp)
			apply_player_damage(max(1.0, boss_touch - player.armor))
			player.invuln = 0.75
			player.play_hurt()

	# 보스 탄막
	for ea in get_tree().get_nodes_in_group("enemy_arrows"):
		if not is_instance_valid(ea):
			continue
		if ea.position.distance_to(player.position) < ea.radius + player.radius:
			if player.invuln <= 0.0:
				apply_player_damage(max(1.0, ea.damage - player.armor))
				player.invuln = 0.6
				player.play_hurt()
				if ea.chill:
					player.slow_t = 1.5
				play_sfx("hurt", -8.0, 0.3)
			ea.queue_free()

	if player.hp <= 0:
		_game_over()


# ---------------------------------------------------------------------
#  무기 발동
# ---------------------------------------------------------------------
# 전역 무기 쿨다운 배율 (뱀서식 느린 발사 — 값 클수록 느림). 밸런스 튜닝용 단일 노브.
const WEAPON_CD_SCALE := 1.15   # 발사 속도 대폭↑ (쿨다운 1.50→1.15, 추가 +30%)
# 전역 무기 범위(장판·폭발·AoE) 배율. 1보다 작을수록 좁아짐 (밸런스 너프 노브).
const WPN_AREA := 0.72


func _weapon_cooldown(kind: String) -> float:
	return _weapon_cooldown_base(kind) * WEAPON_CD_SCALE


func _weapon_cooldown_base(kind: String) -> float:
	# 유니온 무기 쿨다운 (UNION_DEFS에서 조회)
	for u in UNION_DEFS:
		if u["key"] == kind:
			return float(u["cd"]) * player.cooldown_mult
	var lv: int = weapons.get(kind, 1)
	match kind:
		"arrow":
			return max(0.34, 1.15 - lv * 0.09) * player.cooldown_mult
		"lightning":
			return max(0.55, 1.7 - lv * 0.20) * player.cooldown_mult
		"frost":
			return max(1.0, 2.5 - lv * 0.25) * player.cooldown_mult
		"knife":
			return max(0.38, 1.2 - lv * 0.07) * player.cooldown_mult
		"fireball":
			return max(0.5, 1.5 - lv * 0.12) * player.cooldown_mult
		"boomerang":
			return max(0.6, 1.6 - lv * 0.12) * player.cooldown_mult
		"holy":
			return max(1.1, 2.6 - lv * 0.20) * player.cooldown_mult
		"venom":
			return max(0.45, 1.1 - lv * 0.06) * player.cooldown_mult
		"whip":
			return max(0.55, 1.5 - lv * 0.12) * player.cooldown_mult
		"excalibur":
			return max(0.9, 2.4 - lv * 0.2) * player.cooldown_mult
		"void_orb":
			return max(2.6, 5.2 - lv * 0.3) * player.cooldown_mult
		"cleave":
			return max(0.42, 1.15 - lv * 0.07) * player.cooldown_mult
		"chakram":
			return max(0.7, 1.9 - lv * 0.13) * player.cooldown_mult
		"spear":
			return max(0.45, 1.25 - lv * 0.08) * player.cooldown_mult
		"starfall":
			return max(1.4, 3.2 - lv * 0.2) * player.cooldown_mult
		"flamethrower":
			return max(0.5, 1.4 - lv * 0.1) * player.cooldown_mult
		"ice_lance":
			return max(0.4, 1.1 - lv * 0.08) * player.cooldown_mult
		"crossbow":
			return max(0.55, 1.5 - lv * 0.12) * player.cooldown_mult
		"holy_cross":
			return max(0.7, 1.8 - lv * 0.13) * player.cooldown_mult
		"poison_cloud":
			return max(1.3, 3.0 - lv * 0.2) * player.cooldown_mult
		"quake":
			return max(1.2, 2.8 - lv * 0.18) * player.cooldown_mult
		"spread_shot":
			return max(0.64, 1.5 - lv * 0.09) * player.cooldown_mult
		"soul_bolt":
			return max(0.55, 1.5 - lv * 0.11) * player.cooldown_mult
		"holy_beam":
			return max(0.6, 1.7 - lv * 0.13) * player.cooldown_mult
		"bone_spiral":
			return max(0.45, 1.2 - lv * 0.09) * player.cooldown_mult
		"moonlight":
			return max(1.6, 3.6 - lv * 0.24) * player.cooldown_mult
		"axe":
			return max(0.6, 1.6 - lv * 0.12) * player.cooldown_mult
		"homing_skull":
			return max(0.5, 1.4 - lv * 0.1) * player.cooldown_mult
		"thorn_burst":
			return max(0.7, 1.8 - lv * 0.13) * player.cooldown_mult
		"chain_bolt":
			return max(0.8, 2.0 - lv * 0.15) * player.cooldown_mult
		"frost_ring":
			return max(1.0, 2.4 - lv * 0.18) * player.cooldown_mult
		"blood_sword":
			return max(0.55, 1.5 - lv * 0.11) * player.cooldown_mult
		_:
			return 1.0


func _fire_weapon(kind: String) -> void:
	# 뱀서식 성장 곡선: 저레벨 무기는 확 약하고 레벨업으로 강해짐 (공식은 그대로, 여기서 배율만).
	# damage_mult를 임시로 조정 → 모든 무기 데미지 공식(전부 * player.damage_mult)에 일괄 적용.
	var _sv_dmg: float = player.damage_mult
	var _sv_amt: int = player.amount
	var _sv_area: float = player.area_mult
	player.damage_mult *= _weapon_level_scale(weapons.get(kind, 1))
	# 신규 무기 진화: 일괄 강화(피해 ×1.45 · 투사체 +1 · 범위 ×1.2)
	if evolved.get(kind, false) and (kind in NEW_EVO_WEAPONS):
		player.damage_mult *= 1.45
		player.amount += 1
		player.area_mult *= 1.2
	# 진화 무기 투사체에 공통 진화 오라(황금 후광) + 고유 효과 부여 — Arrow가 _ready에서 읽음
	_evo_spawn = evolved.get(kind, false)
	_evo_kind = kind if _evo_spawn else ""
	# 성장 시각 배율: 레벨당 +5%, 진화 시 ×1.3 (Lv8+진화 = 1.75배).
	# 무기가 강해지면 이펙트·투사체도 눈에 띄게 커진다 (사장님 피드백).
	wfx_boost = (1.0 + 0.05 * (int(weapons.get(kind, 1)) - 1)) * (1.3 if _evo_spawn else 1.0)
	_fire_weapon_dispatch(kind)
	wfx_boost = 1.0
	_evo_spawn = false
	_evo_kind = ""
	player.damage_mult = _sv_dmg
	player.amount = _sv_amt
	player.area_mult = _sv_area


# 무기 레벨별 데미지 배율 (정통 뱀서형): Lv1 = 0.40 (초반 매우 약함 → 컨트롤로 생존)
# → Lv8 = 1.55 (레벨 투자할수록 확 강해짐). 초반/후반 격차를 크게 벌려 성장감·긴장감↑.
func _weapon_level_scale(lv: int) -> float:
	return lerp(0.40, 1.35, clamp((lv - 1) / 7.0, 0.0, 1.0))   # Lv1 초반 공격력 상향(0.33→0.40, +20%)


# 조준 우선순위 거리: 파괴 오브젝트(관·상자)는 +90 보정으로 후순위 (적 우선, 근처 물체는 쏨)
func _target_dist(n: Node) -> float:
	var d := player.position.distance_to((n as Node2D).position)
	if n.is_in_group("breakables"):
		d += 90.0
	return d


# 가까운 순으로 정렬된 조준 대상 — 매직완드식 자동조준.
# 뱀서식: 적이 있으면 적만 조준. 파괴 오브젝트는 지나가는 공격·근접 휩쓸기·폭발로 부서진다.
# (예전엔 항상 포함했더니 조형물이 빼곡한 맵에서 무기가 애먼 방향으로 날아가는 것처럼 보였음)
# 화면에 적이 전혀 없을 때만 파괴물을 조준해 초반 파밍 편의는 유지.
func _nearest_list() -> Array:
	var t := _enemies_and_boss()
	if t.is_empty():
		for b in get_tree().get_nodes_in_group("breakables"):
			if is_instance_valid(b):
				t.append(b)
	t.sort_custom(func(a, b): return _target_dist(a) < _target_dist(b))
	return t


# idx번째로 가까운 적 방향 (없으면 fallback). 투사체를 하나씩 조준시키는 데 사용.
func _seek_dir(idx: int, fallback: Vector2, targets: Array) -> Vector2:
	if targets.size() > 0:
		var tt = targets[idx % targets.size()]
		if is_instance_valid(tt):
			return ((tt as Node2D).position - player.position).normalized()
	return fallback


func _fire_weapon_dispatch(kind: String) -> void:
	match kind:
		"arrow":
			_fire_arrow()
		"lightning":
			_fire_lightning()
		"frost":
			_fire_frost()
		"knife":
			_fire_knife()
		"fireball":
			_fire_fireball()
		"boomerang":
			_fire_boomerang()
		"holy":
			_fire_holy()
		"venom":
			_fire_venom()
		"whip":
			_fire_whip()
		"excalibur":
			_fire_excalibur()
		"void_orb":
			_fire_void_orb()
		"cleave":
			_fire_cleave()
		"chakram":
			_fire_chakram()
		"spear":
			_fire_spear()
		"starfall":
			_fire_starfall()
		"flamethrower":
			_fire_flamethrower()
		"ice_lance":
			_fire_ice_lance()
		"crossbow":
			_fire_crossbow()
		"holy_cross":
			_fire_holy_cross()
		"poison_cloud":
			_fire_poison_cloud()
		"quake":
			_fire_quake()
		"spread_shot":
			_fire_spread_shot()
		"soul_bolt":
			_fire_soul_bolt()
		"holy_beam":
			_fire_holy_beam()
		"bone_spiral":
			_fire_bone_spiral()
		"moonlight":
			_fire_moonlight()
		"axe":
			_fire_axe()
		"homing_skull":
			_fire_homing_skull()
		"thorn_burst":
			_fire_thorn_burst()
		"chain_bolt":
			_fire_chain_bolt()
		"frost_ring":
			_fire_frost_ring()
		"blood_sword":
			_fire_blood_sword()
		"storm_bow":
			_fire_storm_bow()
		"frostfire":
			_fire_frostfire()
		"cyclone":
			_fire_cyclone()
		"plague_bomb":
			_fire_plague_bomb()
		"divine_storm":
			_fire_divine_storm()
		"blade_dance":
			_fire_blade_dance()


# --- 유니온 (합체 무기) 구현 ---
func _fire_storm_bow() -> void:
	# 화살 폭풍 + 낙뢰 동시
	var dmg := 30.0 * player.damage_mult * char_ranged
	var targets := _enemies_and_boss()
	targets.shuffle()
	var basedir := Vector2(0, -1)
	if targets.size() > 0:
		basedir = ((targets[0] as Node2D).position - player.position).normalized()
	for i in 6:
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = 99
		a.radius = 9.0
		a.anim_dir = "res://assets/anim/proj_tempest"
		a.life = 2.0 * char_range
		a.position = player.position
		a.velocity = basedir.rotated((i - 2.5) * 0.16) * 720.0
		add_child(a)
	var n: int = min(4, targets.size())
	for i in n:
		var e = targets[i]
		if is_instance_valid(e):
			e.take_damage(dmg * 1.2)
			spawn_fx("bolt", (e as Node2D).position)   # 코드 지그재그 낙뢰 (fx_thunder 기둥 아트 폐기)


func _fire_frostfire() -> void:
	# 최근접 적 위치에 화상+빙결 대폭발
	var t = _nearest_enemy(player.position)
	var pos: Vector2 = (t as Node2D).position if t else player.position + player._last_dir * 160.0
	var rad := 150.0 * player.area_mult * WPN_AREA
	_explode(pos, rad, 60.0 * player.damage_mult * char_ranged, null)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and pos.distance_to(e.position) <= rad and e.has_method("apply_slow"):
			e.apply_slow(0.55, 2.2)
	spawn_fx("fx_meteorshower", pos, rad * 1.6)
	spawn_fx("fx_absolzero", pos, rad * 1.4)


func _fire_cyclone() -> void:
	# 플레이어 주변 전방위 고속 회전 참격 + 넉백
	var rad := 150.0 * player.area_mult * WPN_AREA
	var dmg := 34.0 * player.damage_mult * char_melee
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and player.position.distance_to(e.position) <= rad:
			e.take_damage(dmg)
	var b = get_tree().get_first_node_in_group("boss")
	if b and is_instance_valid(b) and player.position.distance_to(b.position) <= rad:
		b.take_damage(dmg)
	spawn_fx("fx_whirl", player.position, rad * 2.0)


func _fire_plague_bomb() -> void:
	# 최근접 적 위치에 폭발 + 독구름(Hazard) 잔류
	var t = _nearest_enemy(player.position)
	var pos: Vector2 = (t as Node2D).position if t else player.position + player._last_dir * 150.0
	var rad := 130.0 * player.area_mult * WPN_AREA
	_explode(pos, rad, 44.0 * player.damage_mult * char_ranged, null)
	# 독구름: 범위 내 적 강한 둔화 (플레이어 무해)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and pos.distance_to(e.position) <= rad and e.has_method("apply_slow"):
			e.apply_slow(0.55, 3.0)
	spawn_fx("fx_plague", pos, rad * 1.7)


func _fire_divine_storm() -> void:
	# 신성 기둥 + 낙뢰 다중 강타
	var targets := _enemies_and_boss()
	targets.shuffle()
	var dmg := 48.0 * player.damage_mult * char_ranged
	var n: int = min(5, targets.size())
	for i in n:
		var e = targets[i]
		if is_instance_valid(e):
			var s := SkyStrike.new()
			s.target = (e as Node2D).position
			s.fall_time = 0.16 + i * 0.05
			s.dmg = dmg
			s.radius = 64.0 * player.area_mult * WPN_AREA
			s.col = Color(1.0, 0.95, 0.6)
			s.fx_name = "fx_judgment"   # 신성 빛기둥 (테마 유지)
			s.bolt_fx = true            # 낙뢰는 코드 지그재그 (fx_thunder 기둥 아트 폐기)
			add_child(s)


func _fire_blade_dance() -> void:
	# 검+오라 융합: 플레이어 주변 강한 지속 광역
	var rad := 130.0 * player.area_mult * WPN_AREA
	var dmg := 30.0 * player.damage_mult * char_melee
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and player.position.distance_to(e.position) <= rad:
			e.take_damage(dmg)
	var b = get_tree().get_first_node_in_group("boss")
	if b and is_instance_valid(b) and player.position.distance_to(b.position) <= rad:
		b.take_damage(dmg)
	spawn_fx("fx_inferno", player.position, rad * 2.0)


# 숨겨진 무기: 칼 던지기 (업적 「칼을 던지면 되네?」 해금)
func _fire_knife() -> void:
	var lv: int = weapons["knife"]
	var evo: bool = evolved.get("knife", false)
	var dmg := (7.0 + lv * 3.0) * player.damage_mult * char_ranged * (1.6 if evo else 1.0)
	var target = _nearest_enemy(player.position)
	var dir := Vector2(0, -1)
	if target:
		dir = ((target as Node2D).position - player.position).normalized()
	# 로그 정체성: 여러 자루를 빠르게 흩뿌리는 단검 다발 (아처의 정밀 단발과 대비)
	var n := 1 + int((lv - 1) / 2.0) + (2 if evo else 0) + player.amount
	for i in n:
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = 1 + (2 if evo else 0)
		a.radius = 6.0
		a.sprite_path = "res://assets/items/sword.png"
		a.spin = 22.0   # 회전하며 날아가는 단검
		a.scale_mul = 0.9
		if evo:
			a.anim_dir = "res://assets/anim/proj_thousandknife"
		else:
			a.anim_dir = "res://assets/anim/proj_knife"
		a.life = 1.4 * char_range
		a.position = player.position + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		a.velocity = dir.rotated((i - (n - 1) / 2.0) * 0.16 + randf_range(-0.08, 0.08)) * 900.0
		add_child(a)


# --- M2 신규 무기 ---

# 파이어볼: 최근접 적에게 화염구 → 착탄 폭발(광역)
func _fire_fireball() -> void:
	var lv: int = weapons["fireball"]
	var t = _nearest_enemy(player.position)
	var dir := player._last_dir
	if t:
		dir = ((t as Node2D).position - player.position).normalized()
	var evo: bool = evolved.get("fireball", false)
	var dmg := (10.0 + lv * 4.0) * player.damage_mult * char_ranged * (1.4 if evo else 1.0)
	if evo:
		for shot_i in 3:
			var meteor := Arrow.new()
			meteor.damage = dmg * 0.72
			meteor.radius = 13.0
			meteor.pierce = 1
			meteor.life = 1.65 * char_range
			meteor.trail = true
			meteor.trail_col = Color(1.0, 0.26, 0.06)
			meteor.visual_kind = "meteor"
			meteor.anim_dir = "res://assets/anim/proj_meteor"
			meteor.explode_radius = (68.0 + lv * 8.0) * player.area_mult * WPN_AREA
			meteor.explode_damage = dmg * 0.72
			meteor.fx_hit = "fx_meteorshower"
			meteor.fx_hit_size = meteor.explode_radius * 1.8
			meteor.position = player.position
			meteor.velocity = dir.rotated((shot_i - 1) * 0.18) * (520.0 + shot_i * 35.0)
			add_child(meteor)
		return
	var a := Arrow.new()
	a.damage = dmg
	a.radius = 11.0
	a.pierce = 0
	a.life = 1.5 * char_range
	a.trail = true
	a.anim_dir = "res://assets/anim/proj_fireball"
	a.upright = true   # 불꽃은 회전 없이 일렁이는 프레임 애니로 (진행방향 회전 시 어색)
	a.sprite_path = "res://assets/items/icon_fireball.png"
	a.explode_radius = (56.0 + lv * 7.0) * player.area_mult * WPN_AREA * (1.5 if evo else 1.0)
	a.explode_damage = (14.0 + lv * 5.0) * player.damage_mult * char_ranged * (1.5 if evo else 1.0)
	# 조합 「증기 폭발」: 둔화 + 폭발 범위 증가
	if combos.has("fire_frost"):
		a.slow_amount = 0.3
		a.slow_time = 1.2
		a.explode_radius *= 1.3
	a.fx_hit = "fx_meteorshower" if evo else "fx_explosion"   # 진화: 운석우
	a.fx_hit_size = a.explode_radius * 2.0
	a.position = player.position
	a.velocity = dir * 560.0
	add_child(a)


# 부메랑: 회전하며 다수 관통 (진행방향 스핀 애니)
func _fire_boomerang() -> void:
	var lv: int = weapons["boomerang"]
	var t = _nearest_enemy(player.position)
	var dir := player._last_dir
	if t:
		dir = ((t as Node2D).position - player.position).normalized()
	var evo: bool = evolved.get("boomerang", false)
	var n := 1 + int((lv - 1) / 2.0) + (2 if evo else 0) + player.amount
	if combos.has("whip_boomerang"):
		n += 1
	for i in n:
		var a := Arrow.new()
		a.damage = (12.0 + lv * 4.0) * player.damage_mult * char_ranged * (1.4 if evo else 1.0)
		a.pierce = 99
		a.radius = 13.0 * (1.2 if evo else 1.0)
		a.life = 2.2 * char_range   # 나갔다 돌아올 시간 확보
		a.trail = true
		a.boomerang = true          # 던져서 되돌아오는 궤도 (뱀서식)
		a.anim_dir = "res://assets/anim/proj_scythe" if evo else "res://assets/anim/proj_boomerang"
		a.sprite_path = "res://assets/items/icon_boomerang.png"
		a.position = player.position
		a.velocity = dir.rotated((i - (n - 1) / 2.0) * 0.35) * 620.0
		add_child(a)


# 천벌(홀리): 적 머리 위로 신성한 빛 강타
func _fire_holy() -> void:
	var lv: int = weapons["holy"]
	var evo: bool = evolved.get("holy", false)
	var dmg := (22.0 + lv * 8.0) * player.damage_mult * char_ranged * (1.4 if evo else 1.0)
	var targets := _enemies_and_boss()
	targets.shuffle()
	var n: int = min(2 + int(lv / 2.0) + (2 if evo else 0), targets.size())
	for i in n:
		var e = targets[i]
		if is_instance_valid(e):
			var strike := SkyStrike.new()
			strike.target = (e as Node2D).position
			strike.fall_time = 0.18 + i * 0.05
			strike.dmg = dmg
			strike.radius = (46.0 + lv * 4.0) * player.area_mult * WPN_AREA * (1.4 if evo else 1.0)
			strike.col = Color(1.0, 0.92, 0.5)
			strike.fx_name = "fx_judgment" if evo else "fx_holy"
			strike.show_warn = false   # 예고 원 제거 (사장님 결정)
			add_child(strike)
			# 조합 「천벌 강림」: 착탄 지점에 번개 연쇄
			if combos.has("holy_lightning"):
				_spawn_bolt((e as Node2D).position)


# ─── 신규 무기 웨이브 1 ───
# 차크람: 사방으로 회전 날붙이 방사 (관통)
func _fire_chakram() -> void:
	var lv: int = weapons["chakram"]
	var evo: bool = evolved.get("chakram", false)
	# 튕기는 원반: 기본 1개(+복제) 던져 적들 사이를 팅팅팅 리코셰. 레벨업=데미지+튕김 횟수.
	var dmg := (13.0 + lv * 5.0) * player.damage_mult * char_ranged
	var n: int = 1 + player.amount
	var t = _nearest_enemy(player.position)
	var basedir: Vector2 = player._last_dir if player else Vector2(0, -1)
	if t:
		basedir = ((t as Node2D).position - player.position).normalized()
	player.play_attack()
	for i in n:
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = 0
		a.bounce = 3 + int(lv / 2.0) + (3 if evo else 0)   # 튕김 횟수 (레벨업으로 증가)
		a.radius = 8.0
		a.sprite_path = "res://assets/items/icon_chakram.png"
		a.anim_dir = "res://assets/anim/proj_chakram"   # 회전 원반 프레임 애니
		a.spin = 16.0   # 빙글빙글 회전 날붙이
		a.scale_mul = 1.3
		a.fx_hit = "fx_hit"   # 차크람: 기본 타격 스파크 (쌍검 모양 fx_xslash는 원반에 안 맞아 되돌림)
		a.life = 2.4 * char_range
		a.position = player.position
		a.velocity = basedir.rotated((i - (n - 1) / 2.0) * 0.4) * 520.0
		add_child(a)


# 창격: 가장 가까운 적 방향으로 강력한 관통 창
func _fire_spear() -> void:
	var lv: int = weapons["spear"]
	var dmg := (26.0 + lv * 9.0) * player.damage_mult * char_ranged
	var basedir: Vector2 = player._last_dir if player else Vector2(0, -1)
	var target = _nearest_enemy(player.position)
	if target:
		basedir = ((target as Node2D).position - player.position).normalized()
	player.play_attack()
	var shots: int = 1 + player.amount + int(lv / 3.0)
	for i in shots:
		var off := (i - (shots - 1) / 2.0) * 0.11
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = 99
		a.radius = 9.0
		a.sprite_path = "res://assets/items/icon_spear.png"
		a.anim_dir = "res://assets/anim/proj_spear"
		a.scale_mul = 1.4
		a.trail = true
		a.trail_col = Color(0.8, 0.9, 1.0)
		a.life = 1.6 * char_range
		a.position = player.position
		a.velocity = basedir.rotated(off) * 780.0
		add_child(a)


# 별똥별: 무작위 적 위로 유성 낙하 (광역)
func _fire_starfall() -> void:
	var lv: int = weapons["starfall"]
	var dmg := (20.0 + lv * 7.0) * player.damage_mult * char_ranged
	var targets := _enemies_and_boss()
	targets.shuffle()
	var n: int = 2 + lv + player.amount
	for i in n:
		var pos: Vector2
		if i < targets.size() and is_instance_valid(targets[i]):
			pos = (targets[i] as Node2D).position
		else:
			pos = player.position + Vector2(randf_range(-260, 260), randf_range(-260, 260))
		var st := SkyStrike.new()
		st.target = pos
		st.fall_time = 0.2 + i * 0.06
		st.dmg = dmg
		st.radius = (48.0 + lv * 4.0) * player.area_mult * WPN_AREA
		st.col = Color(1.0, 0.85, 0.4)
		st.fx_name = "fx_explosion"
		st.big = lv >= MAX_WLEVEL
		st.show_warn = false   # 예고 원 제거 (사장님 결정)
		add_child(st)


# ─── 신규 무기 웨이브 2 ───
# 화염분사: 바라보는 방향으로 근거리 불꽃 부채꼴 (짧은 사거리 다발)
func _fire_flamethrower() -> void:
	var lv: int = weapons["flamethrower"]
	var dmg := (7.0 + lv * 2.6) * player.damage_mult * char_ranged
	var basedir: Vector2 = player._last_dir if player else Vector2(0, -1)
	var target = _nearest_enemy(player.position)
	if target:
		basedir = ((target as Node2D).position - player.position).normalized()
	player.play_attack()
	var n: int = 4 + lv + player.amount
	for i in n:
		var off := randf_range(-0.42, 0.42)
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = 2
		a.radius = 8.0
		a.sprite_path = "res://assets/items/icon_flamethrower.png"
		a.trail = true
		a.trail_col = Color(1.0, 0.5, 0.1)
		a.fx_hit = "fx_explosion"
		a.life = 0.42 * char_range   # 근거리
		a.position = player.position
		a.velocity = basedir.rotated(off) * randf_range(360.0, 520.0)
		add_child(a)


# 얼음창: 가까운 적을 관통하는 서리창 + 둔화
func _fire_ice_lance() -> void:
	var lv: int = weapons["ice_lance"]
	var dmg := (14.0 + lv * 5.0) * player.damage_mult * char_ranged
	var basedir: Vector2 = player._last_dir if player else Vector2(0, -1)
	var target = _nearest_enemy(player.position)
	if target:
		basedir = ((target as Node2D).position - player.position).normalized()
	player.play_attack()
	# 원뿔이 아니라 전방을 향해 나란히 전진하는 '얼음창 벽' (수직 정렬 → 밀집 라인 관통)
	var shots: int = 3 + player.amount + int(lv / 3.0)
	var perp := basedir.orthogonal()
	var spacing := 26.0
	for i in shots:
		var lane := (i - (shots - 1) / 2.0)
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = 3 + int(lv / 2.0)
		a.radius = 8.0
		a.slow_amount = 0.4
		a.slow_time = 1.4
		a.sprite_path = "res://assets/items/icon_icelance.png"
		a.anim_dir = "res://assets/anim/proj_icelance"
		a.scale_mul = 1.2
		a.trail = true
		a.trail_col = Color(0.6, 0.85, 1.0)
		a.fx_hit = "fx_frost"
		a.life = 1.5 * char_range
		a.position = player.position + perp * lane * spacing   # 벽처럼 옆으로 벌려 배치
		a.velocity = basedir * 700.0                            # 전부 같은 방향 = 벽이 전진
		add_child(a)


# 석궁: 가까운 적에게 강력한 단발 대관통 볼트 (느리고 아픔)
func _fire_crossbow() -> void:
	var lv: int = weapons["crossbow"]
	var dmg := (34.0 + lv * 12.0) * player.damage_mult * char_ranged
	var basedir: Vector2 = player._last_dir if player else Vector2(0, -1)
	var target = _nearest_enemy(player.position)
	if target:
		basedir = ((target as Node2D).position - player.position).normalized()
	player.play_attack()
	var bolts: int = 1 + int((lv - 1) / 4.0) + player.amount
	for i in bolts:
		var off := (i - (bolts - 1) / 2.0) * 0.1
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = 99
		a.radius = 10.0
		a.sprite_path = "res://assets/items/icon_crossbow.png"
		a.anim_dir = "res://assets/anim/proj_crossbow"
		a.scale_mul = 1.3
		a.trail = true
		a.trail_col = Color(0.85, 0.9, 0.7)
		a.life = 1.8 * char_range
		a.position = player.position
		a.velocity = basedir.rotated(off) * 900.0
		add_child(a)


# 성십자: 상하좌우 4방향 성스러운 십자 탄 (범위 확장)
func _fire_holy_cross() -> void:
	var lv: int = weapons["holy_cross"]
	var dmg := (13.0 + lv * 4.5) * player.damage_mult * char_ranged
	player.play_attack()
	# 매직완드식: 사방 발사 대신 가까운 적들을 하나씩 조준하는 유도 성탄 (레벨업=탄 수↑)
	var n := 1 + int((lv - 1) / 2.0) + player.amount
	var targets := _nearest_list()
	var basedir: Vector2 = player._last_dir if player else Vector2(0, -1)
	for i in n:
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = 2 + int(lv / 2.0)
		a.radius = 8.0
		a.homing = 6.0
		a.sprite_path = "res://assets/items/icon_holycross.png"
		a.anim_dir = "res://assets/anim/proj_holycross"   # 회전 성십자 프레임 애니
		a.spin = 10.0
		a.scale_mul = 1.15
		a.fx_hit = "fx_holy"
		a.life = 0.9 * char_range   # 짧게: 슉 쏘고 사라짐
		a.position = player.position
		a.velocity = _seek_dir(i, basedir, targets) * 620.0
		add_child(a)


# ─── 신규 무기 웨이브 3 ───
# 독안개: 적 밀집지에 지속 피해 독구름. 유일하게 남은 장판 무기.
# 시그니처 = 중첩 — 구름 안에 오래 머문 적일수록 아파진다. 스쳐 지나가는 적에겐 약하고,
# 밀집 구간에 장판을 유지할수록 보상받는 구조 (코르비우스의 정체성).
func _fire_poison_cloud() -> void:
	var lv: int = weapons["poison_cloud"]
	# Lv1은 작고 약하게 시작 → 레벨업 체감이 크도록
	var dmg := (4.0 + lv * 3.4) * player.damage_mult * char_ranged * _weapon_level_scale(lv)
	var zones: int = 1 + player.amount + int(lv / 4.0)
	var targets := _enemies_and_boss()
	targets.sort_custom(func(a, b): return player.position.distance_to((a as Node2D).position) < player.position.distance_to((b as Node2D).position))
	for i in zones:
		var pos: Vector2
		if i < targets.size() and is_instance_valid(targets[i]):
			pos = (targets[i] as Node2D).position
		else:
			pos = player.position + Vector2(randf_range(-240, 240), randf_range(-240, 240))
		var z := VoidZone.new()
		z.radius = (48.0 + lv * 12.0) * player.area_mult * WPN_AREA
		z.anim_dir = "res://assets/anim/zone_poison"
		z.dps = dmg
		z.pull = 0.0
		z.col = Color(0.4, 0.85, 0.3)
		z.outline = false   # 초록 외곽 링 제거 — 구름 자체가 범위를 보여줌
		# 중첩: 초당 +40%씩, 최대 +140% (약 3.5초 노출 시 2.4배)
		z.stack_rate = 0.4 + lv * 0.05
		z.stack_max = 1.4 + lv * 0.1
		z.life = 3.2 + lv * 0.45
		z.max_life = z.life
		z.position = pos
		add_child(z)


# 대지강타: 플레이어 주변 링 형태로 대지 강타 연쇄 (광역 + 흔들림)
func _fire_quake() -> void:
	var lv: int = weapons["quake"]
	var dmg := (18.0 + lv * 6.5) * player.damage_mult * char_melee
	var n: int = 4 + lv + player.amount
	var rad := 120.0 + lv * 10.0
	for i in n:
		var ang := TAU * i / float(n) + randf_range(-0.2, 0.2)
		var st := SkyStrike.new()
		st.target = player.position + Vector2.from_angle(ang) * randf_range(50.0, rad)
		st.fall_time = 0.15 + i * 0.03
		st.dmg = dmg
		st.radius = (54.0 + lv * 5.0) * player.area_mult * WPN_AREA
		st.col = Color(0.7, 0.5, 0.3)
		st.fx_name = "fx_rocks"   # 지진: 암석 파편(Foozle Rocks)
		st.big = true
		add_child(st)


# 산탄: 전방으로 넓게 퍼지는 관통 산탄 (원거리)
func _fire_spread_shot() -> void:
	var lv: int = weapons["spread_shot"]
	var dmg := (4.5 + lv * 1.7) * player.damage_mult * char_ranged   # 딜 재하향 (거너 사기 완화)
	var basedir: Vector2 = player._last_dir if player else Vector2(0, -1)
	var target = _nearest_enemy(player.position)
	if target:
		basedir = ((target as Node2D).position - player.position).normalized()
	player.play_attack()
	var n: int = 3 + int(lv / 3.0) + player.amount   # 총알 수·범위 재하향 (만렙 5발)
	for i in n:
		var off := (i - (n - 1) / 2.0) * 0.13
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = 1   # 관통 2→1
		a.radius = 7.0
		a.sprite_path = "res://assets/items/icon_spreadshot.png"
		a.anim_dir = "res://assets/anim/proj_bullet"
		a.trail = true
		a.trail_col = Color(1.0, 0.85, 0.4)
		a.life = 0.6 * char_range   # 사거리 재하향 (근~중거리 산탄)
		a.position = player.position
		a.velocity = basedir.rotated(off) * 640.0
		add_child(a)


# 혼탄: 가장 가까운 여러 적에게 유령탄을 동시 발사 (다중 조준)
func _fire_soul_bolt() -> void:
	var lv: int = weapons["soul_bolt"]
	var dmg := (13.0 + lv * 4.5) * player.damage_mult * char_ranged
	var targets := _enemies_and_boss()
	targets.sort_custom(func(a, b): return player.position.distance_to((a as Node2D).position) < player.position.distance_to((b as Node2D).position))
	var n: int = min(1 + int((lv - 1) / 2.0) + player.amount, targets.size())   # 1발 시작 → 2레벨마다 +1
	player.play_attack()
	for i in n:
		var e = targets[i]
		if not is_instance_valid(e):
			continue
		var dir := ((e as Node2D).position - player.position).normalized()
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = 1 + int(lv / 3.0)
		a.radius = 8.0
		a.sprite_path = "res://assets/items/icon_soulbolt.png"
		a.anim_dir = "res://assets/anim/proj_soulbolt"
		a.upright = true   # 혼탄 에너지는 회전 없이 맥동
		a.scale_mul = 1.2
		a.trail = true
		a.trail_col = Color(0.5, 0.9, 0.7)
		a.fx_hit = "fx_arcane"   # 혼탄: 유령 마력 (뼈나선/유도해골과 구분)
		a.life = 1.6 * char_range
		a.position = player.position
		a.velocity = dir * 620.0
		add_child(a)


# ─── 신규 무기 웨이브 4 ───
# 성광선: 상하로 뻗는 긴 관통 빛기둥 (밀집 라인 청소)
func _fire_holy_beam() -> void:
	var lv: int = weapons["holy_beam"]
	var dmg := (12.0 + lv * 4.2) * player.damage_mult * char_ranged
	player.play_attack()
	# 상하 2방향 기본, Lv5+ 좌우까지 4방향
	var dirs := [Vector2(0, -1), Vector2(0, 1)]
	if lv >= 5:
		dirs.append(Vector2(-1, 0))
		dirs.append(Vector2(1, 0))
	var extra := player.amount
	for d in dirs:
		for j in (1 + extra):
			var a := Arrow.new()
			a.damage = dmg
			a.pierce = 99
			a.radius = 11.0
			a.sprite_path = "res://assets/items/icon_holybeam.png"
			a.anim_dir = "res://assets/anim/proj_holybeam"
			a.upright = true   # 성광선 빛기둥은 회전 없이 맥동
			a.scale_mul = 1.5
			a.trail = true
			a.trail_col = Color(1.0, 0.95, 0.7)
			a.fx_hit = "fx_judgment"   # 성광선: 심판의 빛 (성십자와 구분)
			a.life = 1.4 * char_range
			a.position = player.position + (d as Vector2) * (18.0 * j)
			a.velocity = (d as Vector2) * 780.0
			add_child(a)


# 뼈나선: 매 발사마다 각도를 돌려 뿌리는 방사 뼈탄 (나선 패턴)
func _fire_bone_spiral() -> void:
	var lv: int = weapons["bone_spiral"]
	var dmg := (10.0 + lv * 3.4) * player.damage_mult * char_ranged
	player.play_attack()
	# 매직완드식: 가까운 적들을 하나씩 조준하는 유도 뼈탄
	var n: int = 2 + int(lv / 2.0) + player.amount
	var targets := _nearest_list()
	var basedir: Vector2 = player._last_dir if player else Vector2(0, -1)
	for i in n:
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = 1 + int(lv / 3.0)
		a.radius = 8.0
		a.homing = 6.5
		a.sprite_path = "res://assets/items/icon_bonespiral.png"
		a.anim_dir = "res://assets/anim/proj_bonespiral"   # 회전 뼈나선 프레임 애니
		a.spin = 13.0
		a.scale_mul = 1.2
		a.fx_hit = "fx_shadowstorm"   # 뼈나선: 죽음의 폭풍 (혼탄/유도해골과 구분)
		a.life = 0.95 * char_range   # 짧게
		a.position = player.position
		a.velocity = _seek_dir(i, basedir, targets) * 600.0
		add_child(a)


# 월광강림: 화면 전역에 달빛 폭격 낙하 (광역 소탕)
func _fire_moonlight() -> void:
	var lv: int = weapons["moonlight"]
	var dmg := (20.0 + lv * 6.0) * player.damage_mult * char_ranged
	var n: int = 6 + lv + player.amount
	var vr := get_viewport_rect().size
	var cam := player.position
	# 적 위치 근처에 떨어지게 조준 (완전 랜덤이라 하나도 안 맞던 문제).
	# 적이 낙하 수보다 적으면 순환 + 산포, 적이 없으면 화면 랜덤 폴백.
	var targets := _enemies_and_boss()
	targets.shuffle()
	for i in n:
		var st := SkyStrike.new()
		if targets.size() > 0 and is_instance_valid(targets[i % targets.size()]):
			st.target = (targets[i % targets.size()] as Node2D).position \
				+ Vector2(randf_range(-42.0, 42.0), randf_range(-42.0, 42.0))
		else:
			st.target = cam + Vector2(randf_range(-vr.x * 0.5, vr.x * 0.5),
				randf_range(-vr.y * 0.5, vr.y * 0.5))
		st.fall_time = 0.25 + randf() * 0.5
		st.dmg = dmg
		st.radius = (48.0 + lv * 4.0) * player.area_mult * WPN_AREA
		st.col = Color(0.82, 0.88, 1.0)
		st.fx_name = ""
		# 월광답게: 낙하 점·파란 링 대신 하늘에서 내리쬐는 달빛 기둥 + 초승달 호
		st.hide_fall = true
		st.show_ring = false
		st.impact_kind = "moonbeam"
		add_child(st)


# 전투도끼: 위로 던져 포물선으로 떨어지는 고화력 관통 도끼
func _fire_axe() -> void:
	var lv: int = weapons["axe"]
	var dmg := (22.0 + lv * 7.0) * player.damage_mult * char_melee
	player.play_attack()
	var n: int = 1 + int((lv - 1) / 3.0) + player.amount
	for i in n:
		var off := (i - (n - 1) / 2.0) * 0.22
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = 4 + int(lv / 2.0)
		a.radius = 11.0
		a.sprite_path = "res://assets/items/icon_axe.png"
		a.anim_dir = "res://assets/anim/proj_axe"
		a.spin = 18.0   # 빙글빙글 도는 도끼
		a.scale_mul = 1.4
		a.gravity = 900.0   # 포물선 낙하
		a.fx_hit = "fx_explosion"   # 도끼: 육중한 강타 폭발 (검 모양 fx_slash는 도끼에 안 맞아 되돌림)
		a.life = 1.8 * char_range
		a.position = player.position
		a.velocity = Vector2(off * 320.0, -1).normalized() * randf_range(520.0, 640.0)
		add_child(a)


# ─── 신규 무기 웨이브 5 ───
# 유도해골: 적을 끝까지 쫓는 유도 해골탄
func _fire_homing_skull() -> void:
	var lv: int = weapons["homing_skull"]
	var dmg := (12.0 + lv * 4.0) * player.damage_mult * char_ranged
	player.play_attack()
	var n: int = 1 + int((lv - 1) / 2.0) + player.amount
	for i in n:
		var ang := TAU * i / float(n) + randf_range(-0.3, 0.3)
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = int(lv / 3.0)
		a.radius = 8.0
		a.homing = 8.0
		a.sprite_path = "res://assets/items/icon_homingskull.png"
		a.anim_dir = "res://assets/anim/proj_homingskull"
		a.upright = true   # 유도해골은 회전 없이 부유
		a.scale_mul = 1.25
		a.trail = true
		a.trail_col = Color(0.5, 1.0, 0.6)
		a.fx_hit = "fx_shadow"
		a.life = 2.4 * char_range
		a.position = player.position
		a.velocity = Vector2.from_angle(ang) * 340.0
		add_child(a)


# 가시분출: 플레이어 주위로 짧은 사거리 가시를 사방 분출 (근접 링)
func _fire_thorn_burst() -> void:
	var lv: int = weapons["thorn_burst"]
	var dmg := (11.0 + lv * 3.8) * player.damage_mult * char_melee
	player.play_attack()
	# 매직완드식: 가까운 적들을 하나씩 조준하는 유도 가시탄
	var n: int = 2 + int(lv / 2.0) + player.amount
	var targets := _nearest_list()
	var basedir: Vector2 = player._last_dir if player else Vector2(0, -1)
	for i in n:
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = 2
		a.radius = 9.0
		a.homing = 7.0
		a.sprite_path = "res://assets/items/icon_thornburst.png"
		a.anim_dir = "res://assets/anim/proj_thornburst"   # 회전 가시 고리 프레임 애니
		a.spin = 20.0
		a.fx_hit = "fx_quake_spike"   # 땅가시(Foozle Earth_Spike)
		a.life = 0.7 * char_range
		a.position = player.position
		a.velocity = _seek_dir(i, basedir, targets) * 600.0
		add_child(a)


# 연쇄뇌전: 가장 가까운 여러 적에게 순차로 벼락을 내리꽂음
func _fire_chain_bolt() -> void:
	var lv: int = weapons["chain_bolt"]
	var dmg := (17.0 + lv * 5.5) * player.damage_mult * char_ranged
	var targets := _enemies_and_boss()
	targets.sort_custom(func(a, b): return player.position.distance_to((a as Node2D).position) < player.position.distance_to((b as Node2D).position))
	var n: int = min(3 + lv + player.amount, targets.size())
	for i in n:
		var e = targets[i]
		if not is_instance_valid(e):
			continue
		var st := SkyStrike.new()
		st.target = (e as Node2D).position
		st.fall_time = 0.08 + i * 0.06
		st.dmg = dmg
		st.radius = (44.0 + lv * 4.0) * player.area_mult * WPN_AREA
		st.col = Color(0.7, 0.85, 1.0)
		# fx_lightning 아트가 번개가 아니라 '회색 기둥'으로 보여 폐기 — 코드 지그재그 낙뢰로.
		st.fx_name = ""
		st.bolt_fx = true
		st.show_ring = false   # 파란 경고 링/버스트도 제거 (지저분)
		add_child(st)


# 서리고리: 사방으로 퍼지는 둔화 서리탄 링 (군중 제어)
func _fire_frost_ring() -> void:
	var lv: int = weapons["frost_ring"]
	var dmg := (9.0 + lv * 3.0) * player.damage_mult * char_ranged
	player.play_attack()
	# 매직완드식: 가까운 적들을 하나씩 조준하는 유도 서리탄 (둔화)
	var n: int = 2 + int(lv / 2.0) + player.amount
	var targets := _nearest_list()
	var basedir: Vector2 = player._last_dir if player else Vector2(0, -1)
	for i in n:
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = 2
		a.radius = 8.0
		a.homing = 6.0
		a.slow_amount = 0.45
		a.slow_time = 1.6
		a.sprite_path = "res://assets/items/icon_frostring.png"
		a.anim_dir = "res://assets/anim/proj_frostring"   # 회전 얼음 고리 프레임 애니
		a.spin = 12.0
		a.fx_hit = "fx_absolzero"   # 서리고리: 절대영도 (얼음창과 구분)
		a.life = 0.85 * char_range   # 짧게
		a.position = player.position
		a.velocity = _seek_dir(i, basedir, targets) * 560.0
		add_child(a)


# 흡혈검: 던졌다 되돌아오는 흡혈 대검 (부메랑 왕복 = 갈 때·올 때 2회 타격 + 흡혈)
# 흡혈검: 검기와 같은 근접 베기 — 아트는 붉은 크레센트.
# (예전엔 회전하며 날아갔다 돌아오는 부메랑 투사체라 '흡혈검'과 안 맞았음)
# 성장축은 검기와 반대: 1랩부터 범위가 넓고, 레벨업하면 흡혈율·피해가 오른다.
#   검기 = 범위 성장 / 흡혈검 = 흡혈·화력 성장 → 둘이 같은 근접이어도 역할이 갈림
func _fire_blood_sword() -> void:
	var lv: int = weapons["blood_sword"]
	var evo: bool = evolved.get("blood_sword", false)
	var dir: Vector2 = player._last_dir
	var kt = _nearest_enemy(player.position)
	if kt:
		dir = ((kt as Node2D).position - player.position).normalized()
	# 1랩부터 넓게(검기 Lv1의 ~1.6배), 레벨당 증가폭은 작게
	var rad := (95.0 + lv * 4.0) * char_range * player.area_mult * WPN_AREA * (1.35 if evo else 1.0)
	var dmg := (20.0 + lv * 9.0) * player.damage_mult * char_melee * (1.6 if evo else 1.0)
	var ls: float = min(0.18 if evo else 0.10, 0.015 + lv * 0.011)   # 흡혈 성장 (진화 시 상한↑)
	var healed := 0.0
	for e in _enemies_and_boss():
		if not is_instance_valid(e):
			continue
		var to: Vector2 = (e as Node2D).position - player.position
		if to.length() <= rad + e.radius and to.normalized().dot(dir) > 0.30:
			e.take_damage(dmg)
			healed += dmg * ls
	if healed > 0.0:
		player.hp = min(player.max_hp, player.hp + healed)
		# 벤 자리에서 피가 플레이어로 빨려오는 연출
		var df := Effect.new()
		df.kind = "drain"
		df.position = player.position + dir * rad * 0.6
		df.from_global = player.position
		df.rad = 18.0
		df.life = 0.34
		df.max_life = df.life
		add_child(df)
	_break_near(player.position + dir * rad * 0.5, rad * 0.7, dmg)
	spawn_fx("fx_cleave_blood", player.position, rad * 1.55, dir.angle() + SLASH_ART_FIX, 24.0)
	player.play_attack()
	play_sfx("shoot", -12.0, 0.08)


# 독날(베놈): 맹독 단검 투척 → 둔화 + 착탄 독무
func _fire_venom() -> void:
	var lv: int = weapons["venom"]
	var evo: bool = evolved.get("venom", false)
	var dmg := (9.0 + lv * 3.0) * player.damage_mult * char_ranged * (1.4 if evo else 1.0)
	var t = _nearest_enemy(player.position)
	var dir := player._last_dir
	if t:
		dir = ((t as Node2D).position - player.position).normalized()
	var n := 1 + int((lv - 1) / 2.0) + (2 if evo else 0) + player.amount
	for i in n:
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = 1 + (1 if evo else 0)
		a.radius = 8.0
		a.life = 1.5 * char_range
		a.trail = true
		a.sprite_path = "res://assets/items/icon_venom.png"
		a.anim_dir = "res://assets/anim/proj_venom"
		a.slow_amount = 0.5 if evo else 0.35
		a.slow_time = 1.6
		a.fx_hit = "fx_plague" if evo else "fx_poison"
		a.fx_hit_size = 66.0
		# 조합 「맹독 화염」: 명중 시 화염 폭발 추가
		if combos.has("venom_fire"):
			a.explode_radius = 42.0 * player.area_mult * WPN_AREA
			a.explode_damage = dmg * 0.7
		a.position = player.position
		a.velocity = dir.rotated((i - (n - 1) / 2.0) * 0.18) * 700.0
		add_child(a)


# 채찍(휩): 바라보는 방향 전방 부채꼴 광역 + 넉백
func _fire_whip() -> void:
	var lv: int = weapons["whip"]
	var evo: bool = evolved.get("whip", false)
	var dmg := (16.0 + lv * 6.0) * player.damage_mult * char_melee * (1.4 if evo else 1.0)
	# 뱀서 채찍은 좌우로만 후려친다 (위/아래로는 안 나감) → 조준을 수평으로 스냅.
	var hx := 1.0
	if player._last_dir.x < -0.01:
		hx = -1.0
	elif player._last_dir.x > 0.01:
		hx = 1.0
	else:
		hx = -1.0 if player._dir == "w" else 1.0   # 상/하로만 움직일 땐 마지막 좌우 방향
	var dir := Vector2(hx, 0.0)
	var reach := (120.0 + lv * 12.0) * char_range * (1.25 if evo else 1.0)
	if combos.has("whip_boomerang"):
		reach *= 1.3
	var halfarc := 1.1 if evo else 0.9
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			var to: Vector2 = e.position - player.position
			if to.length() <= reach + e.radius and abs(to.angle_to(dir)) < halfarc:
				e.take_damage(dmg)
				if is_instance_valid(e):
					e.position += to.normalized() * 24.0
	if boss and is_instance_valid(boss):
		var tob: Vector2 = boss.position - player.position
		if tob.length() <= reach + boss.radius and abs(tob.angle_to(dir)) < halfarc:
			boss.take_damage(dmg)
	_break_near(player.position + dir * reach * 0.5, reach * 0.6, dmg)   # 채찍 범위 내 파괴물도 부숨
	# 채찍 모션: 검기와 같은 tbbk 크레센트를 응용 — 아트를 가로로 구워두고(90°)
	# stretch로 세로를 강하게 눌러 '길고 얇은 가닥'으로 만든다. 같은 소스지만
	# 검기(둥근 호)와 채찍(납작한 가닥)이 확실히 구분됨.
	# 뱀서 채찍은 플레이어를 감싸는 원호가 아니라 옆으로 뻗는 가로 형태 → 앞쪽에 배치.
	spawn_fx("fx_whip_evo" if evo else "fx_whip",
		player.position + dir * reach * 0.5, reach * 1.0, dir.angle(),
		24.0, Vector2(1.0, 0.34))
	play_sfx("dash", -16.0, 0.1)


# --- 로그/프리스트 전용 스킬 ---


# --- 해금 특수무기 (업적 보상) ---

# 엑스칼리버: 최근접 적에게 거대 신성 검격 (대관통 + 폭발)
func _fire_excalibur() -> void:
	var lv: int = weapons["excalibur"]
	var t = _nearest_enemy(player.position)
	var dir := player._last_dir
	if t:
		dir = ((t as Node2D).position - player.position).normalized()
	var a := Arrow.new()
	a.damage = (30.0 + lv * 12.0) * player.damage_mult * char_ranged
	a.pierce = 99
	a.radius = 16.0
	a.life = 1.4 * char_range
	a.trail = true
	a.sprite_path = "res://assets/items/icon_excalibur.png"
	a.anim_dir = "res://assets/anim/proj_excalibur"
	a.explode_radius = (50.0 + lv * 6.0) * player.area_mult * WPN_AREA
	a.explode_damage = (18.0 + lv * 6.0) * player.damage_mult * char_ranged
	a.fx_hit = "bolt"   # 벼락창: 코드 지그재그 낙뢰 (fx_thunder 기둥 아트 폐기)
	a.fx_hit_size = 84.0
	a.position = player.position
	a.velocity = dir * 700.0
	add_child(a)
	shake_t = max(shake_t, 0.05)


# 공허구: 적 무리 중심에 블랙홀 생성 → 끌어당기며 지속 피해
func _fire_void_orb() -> void:
	var lv: int = weapons["void_orb"]
	var t = _nearest_enemy(player.position)
	var center: Vector2 = player.position + player._last_dir * 180.0
	if t:
		center = (t as Node2D).position
	var vz := VoidZone.new()
	vz.position = center
	vz.radius = (120.0 + lv * 16.0) * player.area_mult * WPN_AREA
	vz.dps = (16.0 + lv * 6.0) * player.damage_mult * char_ranged
	vz.life = 2.0 + lv * 0.2
	add_child(vz)
	play_sfx("ult", -16.0, 0.1)


# --- 거너 전용 스킬 ---

# 3점사: 최근접 적에게 3연발 빠른 탄
# 총구 화염 이펙트 (픽셀 애니 + 즉시 도형 플래시)
func _muzzle(pos: Vector2, dir: Vector2, size: float = 44.0) -> void:
	spawn_fx("fx_gunburst", pos, size, dir.angle())
	var fx := Effect.new()
	fx.kind = "burst"
	fx.position = pos
	fx.col = Color(1.0, 0.85, 0.4)
	fx.life = 0.14
	fx.max_life = 0.14
	add_child(fx)


# ---------------------------------------------------------------------
#  검기(cleave): 나이트 시작무기 — 전방 반투명 부채꼴 베기 (가시성 높은 검기)
# ---------------------------------------------------------------------
func _fire_cleave() -> void:
	var lv: int = weapons["cleave"]
	var dir: Vector2 = player._last_dir
	var kt = _nearest_enemy(player.position)
	if kt:
		dir = ((kt as Node2D).position - player.position).normalized()
	var rad := (60.0 + lv * 11.0) * char_range * player.area_mult * WPN_AREA   # 초반 좁게 → 레벨로 확장
	var dmg := (16.0 + lv * 6.0) * player.damage_mult * char_melee
	# 부채꼴 범위 내 적/보스 타격 (넉백 포함)
	for e in _enemies_and_boss():
		if not is_instance_valid(e):
			continue
		var to: Vector2 = (e as Node2D).position - player.position
		if to.length() <= rad + e.radius and to.normalized().dot(dir) > 0.30:
			e.take_damage(dmg)
	# 검기 모션: tbbk 도트 크레센트. 조준 방향으로 호를 그으며 벤다.
	_break_near(player.position + dir * rad * 0.5, rad * 0.7, dmg)   # 검기 범위 내 파괴물도 부숨
	spawn_fx("fx_cleave", player.position, rad * 1.55, dir.angle() + SLASH_ART_FIX, 24.0)
	player.play_attack()
	play_sfx("shoot", -12.0, 0.08)


# 범위 무기 헬퍼 (area_mult + 진화 반영)
func _aura_radius() -> float:
	var lv: int = weapons.get("aura", 0)
	var r := (44.0 + lv * 13.0) * player.area_mult * WPN_AREA   # 초반 좁게(정통 마늘) → 레벨로 확장
	if evolved.get("aura", false):
		r *= 1.5
	if combos.has("blade_aura"):
		r *= 1.15
	return r

func _aura_dps() -> float:
	var lv: int = weapons.get("aura", 0)
	var d := (10.0 + lv * 5.0) * player.damage_mult * char_melee * _weapon_level_scale(lv)
	if evolved.get("aura", false):
		d *= 1.6
	return d

func _blade_count() -> int:
	var c: int = weapons.get("blade", 0) + 1
	if evolved.get("blade", false):
		c += 2
	if combos.has("blade_aura"):
		c += 1
	return c

func _blade_orbit() -> float:
	return 72.0 * player.area_mult * WPN_AREA

func _blade_dps() -> float:
	var lv: int = weapons.get("blade", 0)
	var d := (16.0 + lv * 6.0) * player.damage_mult * char_melee * _weapon_level_scale(lv)
	if evolved.get("blade", false):
		d *= 1.5
	if combos.has("blade_lightning"):
		d *= 1.4
	return d


func _fire_arrow() -> void:
	var lv: int = weapons["arrow"]
	var evo: bool = evolved.get("arrow", false)
	var dmg := (10.0 + lv * 4.0) * player.damage_mult * char_ranged
	if evo:
		dmg *= 1.5
	var n := 1 + int((lv - 1) / 2.0) + player.amount   # 뱀서식: 1발 시작 → 2레벨마다 +1
	if evo:
		n += 2
	var basedir: Vector2 = player._last_dir if player else Vector2(0, -1)
	# 뱀서 매직완드식: 부채꼴 분사 대신 가까운 적들을 하나씩 조준하는 '유도 단발'
	var targets := _enemies_and_boss()
	targets.sort_custom(func(a, b): return player.position.distance_to((a as Node2D).position) < player.position.distance_to((b as Node2D).position))
	player.play_attack()
	for i in n:
		var a := Arrow.new()
		a.damage = dmg
		a.pierce = int(lv / 2)
		a.homing = 7.0   # 유도: 적을 향해 휘어 날아감
		# 탄마다 서로 다른 가까운 적을 겨냥 (적이 적으면 최근접 반복)
		var dir := basedir
		if targets.size() > 0:
			var tgt = targets[i % targets.size()]
			if is_instance_valid(tgt):
				dir = ((tgt as Node2D).position - player.position).normalized()
		if evo:
			a.anim_dir = "res://assets/anim/proj_tempest"
			a.visual_kind = "tempest"
			a.trail = true
			a.trail_col = Color(0.3, 0.85, 1.0)
		else:
			a.anim_dir = "res://assets/anim/proj_arrow"
			a.visual_kind = "arrow"
		a.radius = 6.0
		if lv >= MAX_WLEVEL or evo:
			a.explode_radius = 42.0
			a.explode_damage = dmg * 0.6
		if evo:
			a.pierce = 99
			a.fx_hit = "bolt"   # 코드 지그재그 낙뢰 (fx_thunder 기둥 아트 폐기)
			a.fx_hit_size = 64.0
		if combos.has("arrow_frost"):
			a.slow_amount = 0.35
			a.slow_time = 1.2
		# 조합 「폭렬 화살」: 소형 폭발 추가
		if combos.has("arrow_fireball"):
			a.explode_radius = max(a.explode_radius, 34.0)
			a.explode_damage = max(a.explode_damage, dmg * 0.5)
			a.fx_hit = "fx_explosion"
			a.fx_hit_size = 52.0
		a.life = 1.1 * char_range   # 짧게: 조준→슉→소멸
		a.position = player.position
		a.velocity = dir * 640.0   # 조준 방향으로 빠르게 발사 후 유도로 휘어감
		add_child(a)


func _fire_lightning() -> void:
	var lv: int = weapons["lightning"]
	var evo: bool = evolved.get("lightning", false)
	var dmg := (16.0 + lv * 5.0) * player.damage_mult * char_ranged
	if evo:
		dmg *= 1.5
	# 뱀서 매직완드식: 랜덤이 아니라 가장 가까운 적부터 조준 (안정적). 기본 1타겟 + 복제 패시브.
	var targets := _enemies_and_boss()
	targets.sort_custom(func(a, b): return player.position.distance_to((a as Node2D).position) < player.position.distance_to((b as Node2D).position))
	var want := 1 + int((lv - 1) / 2.0) + player.amount   # 뱀서식: 레벨업마다 타겟 증가
	if evo:
		want += 2   # 진화: 추가 연쇄 타겟
	if combos.has("blade_lightning"):
		want += 1
	var n: int = min(want, targets.size())
	var previous_pos := player.position
	for i in n:
		var e = targets[i]
		if is_instance_valid(e):
			e.take_damage(dmg)
			if combos.has("lightning_frost") and is_instance_valid(e) and e.has_method("apply_slow"):
				e.apply_slow(0.4, 1.5)
			if evo:
				_spawn_proc_fx("bolt", e.position, 64.0, Color(0.45, 0.9, 1.0), 0.22, Vector2.ZERO, previous_pos)
				spawn_fx("fx_chainimpact", e.position, 46.0)
				previous_pos = e.position
			else:
				_spawn_bolt(e.position)


func _fire_frost() -> void:
	var lv: int = weapons["frost"]
	var evo: bool = evolved.get("frost", false)
	var rad := (90.0 + lv * 16.0) * player.area_mult * WPN_AREA * char_range
	var dmg := (12.0 + lv * 5.0) * player.damage_mult * char_ranged
	var st := 1.4 + lv * 0.2
	if evo:
		rad *= 1.4
		dmg *= 1.6
		st += 1.0
	# 서리 파열은 '맞은 적' 위에서 작게 터짐 (최대 6개 — 자연스러운 연출)
	var fx_count := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and player.position.distance_to(e.position) <= rad:
			e.take_damage(dmg)
			if is_instance_valid(e):
				e.apply_slow(0.5, st)
				if fx_count < 6:
					spawn_fx("fx_absolzero" if evo else "fx_frost", e.position, 52.0)
					if evo:
						_spawn_proc_fx("shatter", e.position, 48.0, Color(0.62, 0.9, 1.0), 0.34)
						spawn_fx("fx_glacialshatter", e.position, 48.0)
					fx_count += 1
	if boss and is_instance_valid(boss) and player.position.distance_to(boss.position) <= rad:
		boss.take_damage(dmg)
		spawn_fx("fx_absolzero" if evo else "fx_frost", boss.position, 80.0)
		if evo:
			_spawn_proc_fx("shatter", boss.position, 68.0, Color(0.62, 0.9, 1.0), 0.34)
			spawn_fx("fx_glacialshatter", boss.position, 68.0)
	var fx := Effect.new()
	fx.kind = "ring"
	fx.position = player.position
	fx.rad = rad
	fx.col = Color(0.6, 0.85, 1.0)
	fx.life = 0.4
	fx.max_life = 0.4
	add_child(fx)


func _spawn_bolt(pos: Vector2) -> void:
	# fx_lightning/fx_thunder 아트는 '회색 기둥'으로 보여 폐기 — 코드 지그재그 낙뢰만 사용.
	var fx := Effect.new()
	fx.kind = "bolt"
	fx.position = pos
	fx.from_global = pos + Vector2(40, -340)   # 화면 위에서 내리꽂히는 짧은 낙뢰 (지그재그 밀도 확보)
	fx.col = Color(0.8, 0.9, 1.0)
	fx.life = 0.22
	fx.max_life = 0.22
	add_child(fx)


func _enemies_and_boss() -> Array:
	var arr: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			arr.append(e)
	if boss and is_instance_valid(boss):
		arr.append(boss)
	return arr


# ---------------------------------------------------------------------
#  피해 적용 (화살 — 폭발/관통)
# ---------------------------------------------------------------------
# 무기 발사 순간 섬광 (발사 루프에서 중앙 호출). 무기별 색·스타일로 생동감 부여.
func _weapon_muzzle(kind: String) -> void:
	if not WMUZZLE.has(kind):
		return
	var def: Array = WMUZZLE[kind]
	var col: Color = def[0]
	var style: String = def[1]
	var dir: Vector2 = player._last_dir if player else Vector2(0, -1)
	var e := Effect.new()
	e.kind = style
	e.col = col
	e.position = player.position
	match style:
		"slash":
			e.rad = 60.0 * player.area_mult * WPN_AREA
			e.from_global = player.position + dir * 60.0   # 전방 부채꼴 방향
			e.life = 0.16
			e.max_life = 0.16
		"spin":
			e.rad = 70.0 * player.area_mult * WPN_AREA
			e.life = 0.22
			e.max_life = 0.22
		"ring":
			e.rad = 64.0 * player.area_mult * WPN_AREA
			e.life = 0.24
			e.max_life = 0.24
		_:   # burst
			e.rad = 40.0
			e.life = 0.20
			e.max_life = 0.20
	add_child(e)


func _apply_arrow_hit(a, target) -> void:
	# 치명타 판정 (플레이어 패시브와 투사체 고유 보정 중 높은 값을 사용).
	# Arrow의 crit 필드는 예전부터 있었지만 실제 판정에서 빠져 있어 단검 액티브가 활용하지 못했다.
	var projectile_crit_chance := maxf(player.crit_chance, float(a.crit_chance))
	var projectile_crit_mult := maxf(player.crit_mult, float(a.crit_mult))
	var is_crit: bool = projectile_crit_chance > 0.0 and randf() < projectile_crit_chance
	var dmg: float = a.damage * (projectile_crit_mult if is_crit else 1.0)
	target.take_damage(dmg, is_crit)
	play_sfx("hit", -18.0, 0.07)
	# 모든 명중에 방향성 임팩트 스파크(때리는 맛 v2). 진행방향으로 샤드가 튀고 흰 코어가 팝.
	var hf := Effect.new()
	hf.kind = "spark"
	hf.position = a.position
	hf.dir = a.velocity.normalized() if a.velocity.length() > 1.0 else Vector2.ZERO
	hf.col = Color(1.0, 0.85, 0.3) if is_crit else Color(1.0, 1.0, 0.92)
	hf.rad = (22.0 if is_crit else 13.0)
	hf.life = (0.20 if is_crit else 0.14)
	hf.max_life = hf.life
	add_child(hf)
	# 흡혈: 무기 자체 흡혈 + 모든 명중에 적용되는 유물 흡혈
	var ls: float = a.lifesteal + global_lifesteal
	if ls > 0.0:
		player.hp = min(player.max_hp, player.hp + dmg * ls)
	# 흡혈 연출: 피가 적에게서 플레이어로 빨려감.
	# 무기 자체 흡혈에만 연출을 붙인다. 유물 흡혈까지 매 명중마다 연출하면
	# 투사체가 많은 빌드에서 이펙트가 폭증한다.
	if a.lifesteal > 0.0:
		var df := Effect.new()
		df.kind = "drain"
		df.position = a.position
		df.from_global = player.position
		df.rad = 16.0
		df.life = 0.34
		df.max_life = df.life
		add_child(df)
	# 조합: 스톰 애로우 — 명중 시 30% 번개 연쇄
	if combos.has("arrow_lightning") and randf() < 0.3 and is_instance_valid(target):
		target.take_damage(a.damage * 0.8)
		_spawn_bolt(target.position)
	if a.slow_amount > 0.0 and is_instance_valid(target) and target.has_method("apply_slow"):
		target.apply_slow(a.slow_amount, a.slow_time)
	if a.explode_radius > 0.0:
		_explode(a.position, a.explode_radius, a.explode_damage, target)
	# 무기별 명중 이펙트 (파이어볼 폭발, 독무 등)
	if a.fx_hit != "":
		spawn_fx(a.fx_hit, a.position, a.fx_hit_size)


func _explode(pos: Vector2, rad: float, dmg: float, exclude) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e != exclude and pos.distance_to(e.position) <= rad:
			e.take_damage(dmg)
	if boss and is_instance_valid(boss) and boss != exclude and pos.distance_to(boss.position) <= rad:
		boss.take_damage(dmg)
	for b in get_tree().get_nodes_in_group("breakables"):
		if is_instance_valid(b) and pos.distance_to(b.position) <= rad:
			b.take_damage(dmg)


# 지정 범위의 파괴 오브젝트(촛대·항아리·상자)를 부숨 — 모든 근접/AOE 공격 공용
func _break_near(pos: Vector2, rad: float, dmg: float) -> void:
	for b in get_tree().get_nodes_in_group("breakables"):
		if is_instance_valid(b) and pos.distance_to(b.position) <= rad + b.radius:
			b.take_damage(dmg)


# 프레임 애니메이션 이펙트 스폰 (프레임 없으면 무시 → 기존 도형 이펙트 유지)
func spawn_fx(dir_name: String, pos: Vector2, size_px: float = 72.0, rot: float = 0.0,
		fps: float = 16.0, stretch: Vector2 = Vector2.ONE) -> void:
	if fx_level == 0:
		return
	# 센티널 "bolt": 프레임 아트 대신 코드 지그재그 낙뢰.
	# (fx_lightning/fx_thunder 아트가 번개가 아니라 회색 기둥으로 보여 폐기)
	if dir_name == "bolt":
		_spawn_bolt(pos)
		return
	if Assets.frames("res://assets/anim/" + dir_name).is_empty():
		return
	size_px *= wfx_boost   # 무기 성장 시각 배율 (발사 중 동기 호출만 적용, 평시 1.0)
	var fx := FxAnim.new()
	fx.frames_dir = "res://assets/anim/" + dir_name
	fx.size_px = size_px
	fx.rot = rot
	fx.fps = fps
	fx.stretch = stretch
	fx.position = pos
	# 진화 무기 발사 중이면 이펙트를 시그니처 색으로 물들임 (진화가 한눈에 보이게)
	if _evo_spawn and _evo_kind != "":
		fx.modulate = _evo_tint(_evo_kind)
	add_child(fx)


func _spawn_proc_fx(kind: String, pos: Vector2, rad: float, col: Color, life: float = 0.35,
		dir: Vector2 = Vector2.ZERO, from_global: Vector2 = Vector2.ZERO) -> void:
	if fx_level == 0:
		return
	var fx := Effect.new()
	fx.kind = kind
	fx.position = pos
	fx.rad = rad
	fx.col = col
	fx.life = life
	fx.max_life = life
	fx.dir = dir
	fx.from_global = from_global
	add_child(fx)


func _nearest_enemy(from: Vector2):
	var best = null
	var best_d := 1e9
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d := from.distance_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	if boss and is_instance_valid(boss):
		if from.distance_to(boss.position) < best_d:
			best = boss
	return best


# 튕김용: 이미 맞힌 적(a.hit)을 제외한 가장 가까운 적 (같은 적 재타격 방지)
func _nearest_unhit_enemy(a):
	var best = null
	var best_d := 1e9
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or a.hit.has(e):
			continue
		var d: float = a.position.distance_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best


# ---------------------------------------------------------------------
#  스폰 / 젬
# ---------------------------------------------------------------------
func _spawn_wave() -> void:
	# 동시 상한: 초반부터 빽빽하게 (뱀서식 밀도 = 쓸어담는 재미의 핵심)
	var density := float(_current_wave.get("density", 1.0))
	# 밀도 상향 2차 (사장님 피드백): 초반 54→72→90, 시간 계수 0.52→0.62→0.75
	var cap: int = min(MAX_ENEMIES, int((90 + time_survived * 0.75) * density))
	if boss_spawned and diff_label == "쉬움":
		cap = int(cap * 0.6)
	var cur := get_tree().get_nodes_in_group("enemies").size()
	if cur >= cap:
		return
	# 웨이브 규모: 초반 10 → 시간당 증가. 런 중 위협 효과로 밀도 증가.
	var cnt: int = min(84, int((10 + int(time_survived / 8.0)) * run_pressure_mult * density))
	cnt = min(cnt, cap - cur)
	for i in cnt:
		_spawn_one()


func _clear_easy_boss_arena() -> void:
	if diff_label != "쉬움" or player == null:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.elite and e.position.distance_to(player.position) < 460.0:
			e.queue_free()


func _spawn_one() -> void:
	_make_enemy(_stage_spawn_pos(), false, _themed_tier())


# Maps pressure the player from visibly different directions.  Layout validation
# prevents a formation from materializing inside an impassable area.
func _stage_spawn_pos() -> Vector2:
	if player == null or map_stage <= 0:
		return _ring_pos(player.position)
	var mode := str(GameConfig.stage_spawn_profile(map_stage).get("mode", "wide"))
	for _try in 12:
		var pos := _edge_pos(_stage_pressure_angle(mode), randf_range(45.0, 150.0))
		if stage_layout == null or stage_layout.is_walkable(pos, 18.0):
			return pos
	return _ring_pos(player.position)


func _stage_pressure_angle(mode: String) -> float:
	match mode:
		"bridge":
			# 가로 회랑 — 좌우에서만 밀려온다.
			return (0.0 if randf() < 0.5 else PI) + randf_range(-0.20, 0.20)
		"tower":
			# 세로 탑 — 위아래에서만. 좌우로 뽑으면 벽에 박혀 스폰이 실패한다.
			return (PI * 0.5 if randf() < 0.5 else -PI * 0.5) + randf_range(-0.20, 0.20)
		"cross", "cardinal", "castle":
			return (PI * 0.5 * randi_range(0, 3)) + randf_range(-0.18, 0.18)
	return randf() * TAU


# 테마 스폰: 분 단위 표에 지정된 주력/보조 몬스터를 정해진 비율로 혼합한다.
func _themed_tier(force_featured := false) -> Dictionary:
	var key := str(_current_wave.get("primary", featured_enemy))
	if not force_featured and randf() < float(_current_wave.get("mix", 0.25)):
		key = str(_current_wave.get("secondary", key))
	return GameConfig.tier_by_key(key)


# 지정 위치에 적 1마리 생성 (시간강화 + 엘리트 처리). 이벤트/웨이브 공용.
# despawn>0 이면 그 시간 뒤 자동 소멸, hold=true면 제자리 고정 (정적 포위 원 등).
func _make_enemy(pos: Vector2, force_elite := false, tier_override = null, despawn := 0.0, hold := false) -> void:
	var e := Enemy.new()
	var tier: Dictionary = tier_override if tier_override != null else GameConfig.pick_enemy_tier(level, stage_num)
	e.position = pos
	e.setup(tier, time_survived)
	_apply_enemy_run_scaling(e, time_survived)
	# 자연 엘리트 확률은 분 단위 웨이브 표에 따라 1% → 10%로 상승한다.
	if force_elite or randf() < float(_current_wave.get("elite", 0.05)):
		e.elite = true
		e.hp *= 6.0
		e.radius *= 1.5
		e.speed *= 0.85
		e.xp_value *= 5
		e.touch_damage *= 1.5
	if despawn > 0.0:
		e.despawn_t = despawn
	if hold:
		e.hold = true
	e.max_hp = e.hp   # 모든 강화(시간·엘리트) 적용 후 최종 hp를 HP바 기준으로 캡처
	add_child(e)


func _apply_enemy_run_scaling(e: Enemy, at_time: float) -> void:
	# 시간 경과 강화 (30분 기준): 웨이브 티어/밀도와 중복 폭증하지 않는 완만한 마감 보정.
	var tprog: float = clampf(at_time / RUN_TIME, 0.0, 1.0)
	e.hp *= diff_enemy_hp * (1.0 + tprog * 0.85) * run_pressure_mult   # 최대 +85% HP
	e.touch_damage *= (1.0 + tprog * 0.22)                             # 최대 +22% 접촉피해
	e.speed *= diff_enemy_speed * (1.0 + tprog * 0.08 + (run_pressure_mult - 1.0) * 0.5)  # 최대 +8% 속도


# 적은 막힌 지형을 넘지 않고, 직접 경로가 막히면 각도를 바꿔 우회한다.
func stage_enemy_step(from: Vector2, target: Vector2, distance: float, radius: float) -> Vector2:
	if stage_layout == null:
		return from.move_toward(target, distance)
	return stage_layout.steer_toward(from, target, distance, radius)


# 이벤트가 지금 추가로 스폰 가능한 마리 수 (스파이크 여유 포함)
func _spawn_budget(spike: int = 100) -> int:
	return max(0, MAX_ENEMIES + spike - get_tree().get_nodes_in_group("enemies").size())


func _ring_pos(center: Vector2) -> Vector2:
	# 화면 밖 둘레에서 스폰 (플레이어를 향해 몰려옴). 줌 반영해 화면 바로 밖에서 스폰.
	var view := get_viewport_rect().size
	var z: float = player.cam.zoom.x if player and player.cam else 1.0
	var dist: float = max(view.x, view.y) / z * 0.58 + 70.0
	# 뱀서식 전방위 포위: 진행 방향 상관없이 360° 전 둘레에서 스폰 (도망칠 틈 없음).
	for _try in 18:
		var ang := randf() * TAU
		var p := center + Vector2(cos(ang), sin(ang)) * dist
		p.x = clamp(p.x, 10.0, WORLD.x - 10.0)
		p.y = clamp(p.y, 10.0, WORLD.y - 10.0)
		if stage_layout == null or stage_layout.is_walkable(p, 18.0):
			return p
	var fallback := center + Vector2.RIGHT * dist
	return stage_layout.nearest_walkable(fallback, 18.0) if stage_layout else fallback


# 조형물 소품 틴트. 회색 DCSS 석재를 스테이지 분위기로 물들인다(묘지=이끼, 빙하=얼음, 공허=보라).
const STAGE_SCATTER_TINTS := [
	Color(0.90, 0.94, 0.86),   # 묘지
	Color(1.02, 0.82, 0.78),   # 지옥
	Color(0.74, 0.88, 1.06),   # 빙하
	Color(0.96, 0.76, 1.14),   # 공허
	Color(0.86, 0.90, 1.00),   # 마성
]


# 스테이지 조형물 스캐터 (텍스처 없으면 표시 안 됨)
func _gen_decorations() -> void:
	# 뱀서식 하나의 맵: 최초 1회만 생성해 전 구간 동일 유지 (스테이지마다 안 바뀜)
	if not decorations.is_empty():
		return
	var decor_stage := map_stage if map_stage > 0 else 1
	var stage_dirs := {1: "graveyard", 2: "hell_bridge", 3: "glacier", 4: "void_altar", 5: "demon_castle"}
	var stage_dir := str(stage_dirs.get(decor_stage, ""))
	# CC0 조형물 소품(바닥 타일과 같은 DCSS 소스). 회색 석재라 스테이지 색으로 물들인다.
	var scatter: Array = []
	for i in 16:   # 소품이 늘어도 파일만 추가하면 되게 여유 상한
		var sp := "res://assets/maps/%s/scatter/%02d.png" % [stage_dir, i]
		if FileAccess.file_exists(sp):
			scatter.append(sp)
	# 소품 틴트(빙하=얼음빛, 공허=보라 등). 회색 석상을 스테이지 분위기에 맞춘다.
	var scatter_tint: Color = STAGE_SCATTER_TINTS[clampi(decor_stage - 1, 0, STAGE_SCATTER_TINTS.size() - 1)]

	# 조형물은 의도적 배열 패턴만 사용한다(랜덤 스캐터는 제외). 뱀서 맵처럼 회랑을 따라
	# 늘어선 열주·대칭 정렬·랜드마크 둘레 원형으로 인공 구조물 느낌을 준다.
	if not scatter.is_empty() and stage_layout:
		_add_decor_patterns(decor_stage, scatter, scatter_tint)

	# 맵별 시그니처 조형물 하나를 랜드마크 자리에.
	var signature_path := "res://assets/maps/%s/landmark.png" % stage_dir
	if stage_layout and FileAccess.file_exists(signature_path):
		decorations.append({
			"pos": stage_layout.landmark_position,
			"tex": signature_path,
			"s": 1.7,
			"flip": false,
		})


# 스테이지 지형에 맞춘 조형물 정렬 패턴. 열주 소품 인덱스는 다운로드 순서 기준.
const STAGE_PILLAR_IDX := {1: 0, 2: 1, 3: 0, 4: 3, 5: 5}
func _add_decor_patterns(stage: int, scatter: Array, tint: Color) -> void:
	var pillar_i: int = clampi(int(STAGE_PILLAR_IDX.get(stage, 0)), 0, scatter.size() - 1)
	var pillar: String = scatter[pillar_i]
	match stage:
		1:
			# 묘지(개활): 랜드마크 둘레 원형 + 짧은 열주 참배로.
			_decor_ring(stage_layout.landmark_position, 360.0, 12, scatter[3], 1.0, tint)
			_decor_line(Vector2(1400, 700), Vector2(1400, 1080), 130.0, pillar, 1.05, tint)
		2:
			# 지옥(가로 회랑): 회랑 위·아래 가장자리를 따라 열주 2줄.
			_decor_line(Vector2(280, 850), Vector2(2520, 850), 150.0, pillar, 1.2, tint)
			_decor_line(Vector2(280, 1950), Vector2(2520, 1950), 150.0, pillar, 1.2, tint)
		3:
			# 빙하(미로): 중앙 교차로 둘레 원형 + 세로 통로 열주.
			_decor_ring(stage_layout.landmark_position, 300.0, 12, scatter[3], 1.05, tint)
			_decor_line(Vector2(1400, 260), Vector2(1400, 840), 130.0, pillar, 1.1, tint)
		4:
			# 공허(세로 탑): 좌우 벽을 따라 대칭 열주 2줄.
			_decor_line(Vector2(900, 160), Vector2(900, 2640), 150.0, pillar, 1.2, tint)
			_decor_line(Vector2(1900, 160), Vector2(1900, 2640), 150.0, pillar, 1.2, tint)
		5:
			# 마성(열주 대홀): 중앙 통로에 석상 행렬 + 좌우 보조 열.
			_decor_line(Vector2(1400, 360), Vector2(1400, 2440), 190.0, scatter[3], 1.2, tint)
			_decor_line(Vector2(1120, 460), Vector2(1120, 2340), 210.0, pillar, 1.1, tint)
			_decor_line(Vector2(1680, 460), Vector2(1680, 2340), 210.0, pillar, 1.1, tint)


func _decor_line(from: Vector2, to: Vector2, spacing: float, tex: String, scale: float, tint: Color) -> void:
	var span := from.distance_to(to)
	var steps := int(span / spacing)
	if steps <= 0:
		return
	var dir := (to - from) / float(steps)
	for i in steps + 1:
		var p := from + dir * i
		if stage_layout.is_walkable(p, 26.0):
			decorations.append({"pos": p, "tex": tex, "s": scale, "flip": false, "tint": tint})


func _decor_ring(center: Vector2, radius: float, count: int, tex: String, scale: float, tint: Color) -> void:
	for i in count:
		var a := TAU * float(i) / float(count)
		var p := center + Vector2.from_angle(a) * radius
		if stage_layout.is_walkable(p, 26.0):
			decorations.append({"pos": p, "tex": tex, "s": scale, "flip": i % 2 == 0, "tint": tint})



# 맵에 숨겨진 아이템 스캐터
func _scatter_pickups(n: int) -> void:
	for i in n:
		_spawn_pickup_random()


# 맵 사방의 고정 패시브. 카드 6칸이 찬 뒤 주워도 별도 슬롯으로 획득 가능해
# 탐험이 빌드 확장으로 이어진다(VS의 스테이지 아이템 규칙).
func _spawn_stage_landmarks() -> void:
	var center := WORLD / 2.0
	# 스테이지 아이템은 맵 구조에 맞춘 실제 고정 좌표에 놓인다.
	var passive_keys: Array = ["candela", "tome", "wings", "armor"]
	if map_stage > 0:
		passive_keys = GameConfig.stage_info(map_stage).get("field_passives", passive_keys)
	var positions := [center + Vector2(820, 0), center + Vector2(-820, 0), center + Vector2(0, -820), center + Vector2(0, 820)]
	if stage_layout and stage_layout.item_positions.size() >= passive_keys.size():
		positions = stage_layout.item_positions
	for i in mini(passive_keys.size(), positions.size()):
		var pickup := Pickup.new()
		var passive_key := str(passive_keys[i])
		pickup.kind = "passive:" + passive_key
		pickup.icon_path = PICON.get(passive_key, "")
		pickup.position = positions[i]
		add_child(pickup)


# 파괴 오브젝트 1개 스폰 (지정 위치). hp는 시간 경과로 소폭 상승.
func _spawn_breakable(pos: Vector2, force_coffin := false) -> void:
	var b := Breakable.new()
	# 9% 확률로 숨김 관(coffin): 살짝 튼튼 + 강력 보상 (무기 약화에 맞춰 HP 하향 → 부술 수 있게)
	if force_coffin or randf() < 0.09:
		b.kind = "coffin"
		b.radius = 20.0
		b.hp = (28.0 + time_survived * 0.30)
	else:
		var kinds := ["barrel", "crate", "pot", "torch"]
		b.kind = kinds[randi() % kinds.size()]
		b.radius = 15.0 + randf() * 4.0
		b.hp = 24.0 + time_survived * 0.5
	b.position = Vector2(clamp(pos.x, 60.0, WORLD.x - 60.0), clamp(pos.y, 60.0, WORLD.y - 60.0))
	if stage_layout:
		b.position = stage_layout.nearest_walkable(b.position, b.radius)
	add_child(b)


func _scatter_breakables(n: int) -> void:
	for i in n:
		var spawn_pos := Vector2(randf_range(80.0, WORLD.x - 80.0), randf_range(80.0, WORLD.y - 80.0))
		if stage_layout:
			for attempt in 8:
				spawn_pos = stage_layout.random_walkable(48.0)
				if spawn_pos.distance_to(WORLD * 0.5) >= 420.0:
					break
		_spawn_breakable(spawn_pos)
	# 숨김 관 2개 확정 배치 (탐험 보상)
	for i in 2:
		_spawn_breakable(Vector2(randf_range(120.0, WORLD.x - 120.0), randf_range(120.0, WORLD.y - 120.0)), true)


# 뱀서식 바닥 아이템 랜덤 종류: 회복/자석/시계/은두야(화염)/드문 로자리 (폭탄 제거)
func _random_floor_item() -> String:
	# 은두야 제거 후 남은 4종에 그 몫(14%)을 원래 비율대로 재분배
	# (heart 40 / magnet 24 / clock 15 / rosary 7 → 합 86을 100으로 정규화)
	var roll := randf()
	if roll < 0.465:
		return "heart"     # 회복 (흔함)
	elif roll < 0.744:
		return "magnet"    # 자석
	elif roll < 0.919:
		return "clock"     # 시간정지
	else:
		return "rosary"    # 화면 전멸 (드묾)


func _spawn_pickup_random() -> void:
	var p := Pickup.new()
	p.kind = _random_floor_item()
	p.position = stage_layout.random_walkable(28.0) if stage_layout else Vector2(randf_range(80.0, WORLD.x - 80.0), randf_range(80.0, WORLD.y - 80.0))
	add_child(p)


func on_pickup(kind: String) -> void:
	if kind.begins_with("passive:"):
		var passive_key := kind.trim_prefix("passive:")
		var pdef: Dictionary = _passive_defs().get(passive_key, {})
		if passives.get(passive_key, 0) < MAX_PLEVEL:
			_add_passive(passive_key)
			_event_banner("◆ 스테이지 아이템 획득 — %s" % pdef.get("name", passive_key))
		else:
			run_gold += 25
			_event_banner("◆ 완성된 아이템이 골드 +25로 변환됐다")
		_refresh_inventory_ui()
		_update_ui()
		play_sfx("levelup", -5.0)
		_flash(Color(0.45, 0.85, 1.0, 0.45))
		return
	match kind:
		"heart":
			player.hp = min(player.max_hp, player.hp + 40.0)
		"chicken":
			# 통닭(뱀서 로스트 치킨): 체력 완전 회복 — 위기탈출 쾌감
			player.hp = player.max_hp
			_flash(Color(1.0, 0.55, 0.35, 0.5))
			shake_t = max(shake_t, 0.18)
			play_sfx("levelup", -6.0)
			# 회복 링 + 하트 버스트
			var hfx := Effect.new()
			hfx.kind = "ring"
			hfx.position = player.position
			hfx.rad = 140.0
			hfx.col = Color(1.0, 0.4, 0.45)
			hfx.life = 0.5
			hfx.max_life = 0.5
			add_child(hfx)
			_event_banner("🍗 통닭! — 체력 완전 회복")
		"magnet":
			# 전맵 즉시 흡수 → 6초간 흡수 범위 대폭 확대 버프
			player.magnet_t = 6.0
		"clock":
			# 오롤로기온: 모든 적 4초 시간정지 (완전 둔화) + 시안 플래시
			_flash(Color(0.5, 0.85, 1.0, 0.6))
			shake_t = max(shake_t, 0.2)
			play_sfx("levelup", -8.0)
			var cfx := Effect.new()
			cfx.kind = "ring"
			cfx.position = player.position
			cfx.rad = 900.0
			cfx.col = Color(0.6, 0.9, 1.0)
			cfx.life = 0.5
			cfx.max_life = 0.5
			add_child(cfx)
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and e.has_method("apply_slow"):
					e.apply_slow(1.0, 4.0)   # 100% 둔화 = 정지
		"rosary":
			# 화면의 모든 적 전멸 (뱀서 로자리)
			_flash(Color(1.0, 1.0, 0.95, 0.7))
			shake_t = max(shake_t, 0.35)
			play_sfx("levelup", -4.0)
			var rfx := Effect.new()
			rfx.kind = "ring"
			rfx.position = player.position
			rfx.rad = 1000.0
			rfx.col = Color(1.0, 0.95, 0.7)
			rfx.life = 0.6
			rfx.max_life = 0.6
			add_child(rfx)
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e):
					e.take_damage(99999.0)
		_:
			# chest: 회복 + 골드 → 진화 조건 충족 무기 있으면 진화, 없으면 보너스 카드
			player.hp = min(player.max_hp, player.hp + 15.0)
			run_gold += 5
			_chest_fanfare(1)   # 파밍 쾌감: 금화 분출 + 팡파레 + 흔들림 (기본 등급)
			if _try_evolve_from_chest():
				return
			if _try_union_from_chest():
				return
			# 뱀서식: 진화/유니온 없으면 1/3/5개 랜덤 보상 자동 지급 + 다중 룰렛
			_open_bonus_chest()


func _spawn_boss(forced_key: String = "") -> void:
	boss_spawned = true
	play_sfx("boss", -4.0)
	boss = Boss.new()
	var boss_theme := map_stage if map_stage > 0 else stage_num
	boss.key = forced_key if forced_key != "" else GameConfig.stage_info(boss_theme)["boss"]
	# 심연 모드: 보스 무작위 등장. 레트로 개편으로 재생산한 보스만 사용
	# (boss_lich·boss_spider는 옛 아트라 제외 — 패턴 코드는 남겨둠)
	if abyss_mode:
		var pool := ["boss_1", "boss_2", "boss_3", "boss_4", "boss_5"]
		boss.key = pool[randi() % pool.size()]
	boss.position = player.position + Vector2(0, -280)
	boss.max_hp = (850.0 + level * 95.0) * diff_enemy_hp
	boss.hp = boss.max_hp
	boss.move_speed = (58.0 + stage_num * 4.0) * diff_enemy_speed
	add_child(boss)
	_clear_easy_boss_arena()
	# 일반/어려움은 호드를 유지하고, 쉬움만 주변 일반 몬스터를 정리한다.
	# 등장 연출: 배너 + 플래시 + 흔들림 (처치하면 보물상자!)
	_event_banner("⚠ 보스 출현! — 처치하면 보물상자")
	_flash(Color(0.8, 0.2, 0.2, 0.5))
	shake_t = max(shake_t, 0.35)
	stage_banner_t = max(stage_banner_t, 2.5)


# 던전 목표 보스: 해당 던전 보스를 클라이맥스로 등장. 처치하면 클리어(on_boss_killed에서 처리).
func _spawn_dungeon_boss() -> void:
	_spawn_boss(str(GameConfig.stage_info(map_stage)["boss"]))
	_boss_is_objective = true
	if boss and is_instance_valid(boss):
		boss.weak = str(GameConfig.stage_info(map_stage).get("boss_weak", ""))
		boss.max_hp *= 1.6   # 목표 보스는 더 단단하게 (던전 클라이맥스)
		boss.hp = boss.max_hp
	var wk := str(GameConfig.stage_info(map_stage).get("boss_weak", ""))
	var hint := "  (약점: %s)" % str(ELEMENT_NAME.get(wk, "")) if wk != "" else ""
	_event_banner("⚠ 던전 보스 출현! — 처치하면 클리어%s" % hint)


const GEM_CAP := 120   # 젬 노드 상한 (성능). 초과 XP는 가까운 젬 병합/먼 젬 재활용으로 총량 유지.

func _spawn_gem(pos: Vector2, value: int) -> void:
	var gems := get_tree().get_nodes_in_group("gems")
	if gems.size() >= GEM_CAP:
		# 예전에는 플레이어에게서 가장 먼 젬에만 합쳐 레벨 25 전후부터
		# 새 처치 위치에 젬이 전혀 안 보이고 XP가 화면 밖에 고이는 문제가 있었다.
		var nearest: Gem = null
		var nearest_d: float = INF
		var recycle: Gem = null
		var farthest_d := -1.0
		for gg in gems:
			var gem := gg as Gem
			if gem == null:
				continue
			var spawn_d := gem.position.distance_squared_to(pos)
			if spawn_d < nearest_d:
				nearest_d = spawn_d
				nearest = gem
			var player_d := gem.position.distance_squared_to(player.position)
			if player_d > farthest_d:
				farthest_d = player_d
				recycle = gem
		# 현재 전투 위치 110px 안에 젬이 있으면 그 젬의 등급을 올린다.
		if nearest != null and nearest_d <= 110.0 * 110.0:
			nearest.value += value
			nearest.queue_redraw()
			return
		# 주변에 젬이 없으면 화면 밖의 가장 먼 젬을 현재 처치 위치로 옮긴다.
		# 기존 값도 함께 들고 오므로 XP 손실 없이 새 크리스탈이 계속 보인다.
		if recycle != null:
			recycle.value += value
			recycle.position = pos
			recycle.queue_redraw()
			return
	var g := Gem.new()
	g.value = value
	g.position = pos
	add_child(g)


func collect_gem(value: int) -> void:
	play_sfx("gem", -18.0, 0.06)
	_gain_xp(value)


# ---------------------------------------------------------------------
#  처치 / XP / 레벨업
# ---------------------------------------------------------------------
func _spawn_dmg_num(pos: Vector2, amount: int, crit: bool = false, kind: String = "", element: String = "phys") -> void:
	# 대량 피격 시 일반 숫자는 상한으로 스킵(크리·상성타는 항상 표시)
	if _dmgnum > 75 and not crit and kind == "":
		return
	var d := DamageNum.new()
	d.amount = amount
	d.crit = crit
	d.kind = kind   # ""=기본 / "weak"=약점(속성색·확대) / "resist"=저항(회색·축소)
	d.tint = ELEMENT_COL.get(element, Color(1, 1, 1)) if kind == "weak" else Color(0.62, 0.64, 0.68)
	d.position = pos + Vector2(randf_range(-8, 8), -14)
	d.tree_exited.connect(func() -> void: _dmgnum -= 1)
	_dmgnum += 1
	add_child(d)


const COIN_CAP := 60   # 코인 노드 상한 (성능). 초과 시 즉시 적립.
func _spawn_coin(pos: Vector2, value: int) -> void:
	# 골드를 바닥에 떨궈 자석으로 빨려오게 (뱀서식 파밍 쾌감). 상한 초과 시 즉시 적립.
	if get_tree().get_nodes_in_group("coins").size() >= COIN_CAP:
		run_gold += int(round(value * greed_mult * run_pressure_mult))
		return
	var c := Coin.new()
	c.value = value
	c.position = pos + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
	add_child(c)


# 보물상자 슬롯머신 (진화·유니온: 단일 보상). 보상은 이미 적용됨 — 순수 연출.
func _show_chest_roulette(final_icon: String, title: String, rname: String) -> void:
	_show_roulette([{"icon": Assets.tex(final_icon), "name": rname}], title)


# 다중 릴 룰렛 공개 (rewards = [{icon,name}]). 게임 일시정지 → 닫힐 때 해제.
func _show_roulette(rewards: Array, title: String, gold: float = 0.0) -> void:
	if ui_overlay == null or rewards.is_empty():
		return
	var cycle: Array = []
	for k in WICON.keys():
		var t: Texture2D = Assets.tex(WICON[k])
		if t:
			cycle.append(t)
	var r := ChestRoulette.new()
	r.setup(rewards, cycle, title,
		func() -> void: get_tree().paused = false,
		func() -> void: play_sfx("hit", -18.0, 0.12))
	r.gold_display = gold
	ui_overlay.add_child(r)
	get_tree().paused = true


# 보물상자 보너스 개봉 (뱀서식): 1/3/5개 랜덤 보상 자동 지급 + 다중 룰렛 공개.
func _open_bonus_chest() -> void:
	var roll := randf()
	var count := 1
	if roll > 0.97:
		count = 5      # 3% (뱀서식: 매우 드묾)
	elif roll > 0.85:
		count = 3      # 12%
	# else 1 (85%)
	# 뱀서식: 보물상자는 무기·패시브 둘 다 나옴 (진화/유니온은 별도 경로)
	var opts: Array = _card_options()
	var rewards: Array = []
	for i in count:
		if opts.is_empty():
			run_gold += 20
			rewards.append({"icon": Assets.tex(PICON.get("magnet", "")), "name": "골드 +20"})
			continue
		var c: Dictionary = _weighted_choice(opts)   # 보유 무기/패시브 우대(2.4배) — 레벨업과 동일
		(c["act"] as Callable).call()
		rewards.append({"icon": Assets.tex(c.get("icon", "")), "name": str(c.get("title", ""))})
		opts.erase(c)
	# 상자 골드 (뱀서식 "55.00" 연출용) — 실제 골드도 적립
	var chest_gold := float(count) * randf_range(12.0, 30.0) * greed_mult
	run_gold += int(round(chest_gold))
	_refresh_inventory_ui()
	_update_ui()
	_chest_fanfare(count)   # 1/3/5 등급별 연출 (좋을수록 화려)
	_show_roulette(rewards, "✦ 보물 상자 ✦", chest_gold)


# 화면 플래시 (레벨업·진화 순간). flash_overlay가 스스로 페이드.
func _flash(col: Color) -> void:
	if flash_overlay:
		flash_overlay.flash(col)


# 짧은 슬로우모션 (극적 순간). 실시간 기준으로 자동 복귀.
func _slowmo(scale: float, ms: int) -> void:
	Engine.time_scale = scale
	_slowmo_until = Time.get_ticks_msec() + ms


# 보물상자 개봉 연출 (뱀서식): 등급(1/3/5)이 높을수록 화려 — 금화·링·플래시·슬로우모션 스케일업
func _chest_fanfare(count: int) -> void:
	# 등급 계수: 1개=평범, 3개=화려, 5개=초호화
	var tier: int = 3 if count >= 5 else (2 if count >= 3 else 1)
	play_sfx("levelup", -6.0 + tier * 1.0)
	shake_t = max(shake_t, 0.18 + tier * 0.10)
	var gold_col := Color(1.0, 0.88, 0.45, 0.30 + tier * 0.12)
	_flash(gold_col)
	# 5개(최고 등급): 극적 슬로우모션 + 화면 골드 섬광
	if tier >= 3:
		_slowmo(0.45, 420)
		_flash(Color(1.0, 0.95, 0.7, 0.66))
	# 금화 분수 — 등급별 양 증가
	var coins := 8 + tier * 9   # 1→17, 2→26, 3→35
	for i in coins:
		var ang := TAU * i / float(coins) + randf_range(-0.15, 0.15)
		_spawn_coin(player.position + Vector2.from_angle(ang) * randf_range(30.0, 60.0 + tier * 20.0), 3)
	# 다중 확산 링 (등급별 개수·크기)
	var rings := tier + 1
	for k in rings:
		var fx := Effect.new()
		fx.kind = "ring"
		fx.position = player.position
		fx.rad = 120.0 + k * (60.0 + tier * 20.0)
		fx.col = Color(1.0, 0.85, 0.35) if tier < 3 else Color(1.0, 0.93, 0.55)
		fx.life = 0.5 + k * 0.12
		fx.max_life = fx.life
		fx.delay = k * 0.08
		add_child(fx)
	# 반짝임 파티클 버스트
	var burst := Effect.new()
	burst.kind = "burst"
	burst.position = player.position
	burst.col = Color(1.0, 0.9, 0.5)
	burst.life = 0.45 + tier * 0.12
	burst.max_life = burst.life
	add_child(burst)
	# 최고 등급엔 신성 폭발 이펙트까지
	if tier >= 3:
		spawn_fx("fx_divine", player.position, 300.0)
	_event_banner("✦  보물 상자!  ✦" if tier < 3 else "✦✦  대박 보물!  ✦✦")


func collect_coin(value: int) -> void:
	run_gold += int(round(value * greed_mult * run_pressure_mult))
	play_sfx("coin", -12.0, 0.08)


# 전투 통계는 표시용 피해량이 아니라 실제로 감소한 체력만 기록한다.
func record_damage_dealt(amount: float) -> void:
	run_damage_dealt += maxf(0.0, amount)


func apply_player_damage(amount: float) -> float:
	if player == null or amount <= 0.0:
		return 0.0
	var actual_damage := minf(maxf(0.0, player.hp), amount)
	player.hp -= amount
	run_damage_taken += actual_damage
	return actual_damage


# 사수 몬스터 투사체 (#27)
func spawn_enemy_arrow(pos: Vector2, dir: Vector2, dmg: float, chill: bool) -> void:
	var ea := EnemyArrow.new()
	ea.position = pos
	ea.velocity = dir * 220.0
	ea.damage = dmg
	ea.chill = chill
	add_child(ea)
	play_sfx("hit", -22.0, 0.15)


# 몹 종류 → 죽음 버스트 이펙트 이름 (4타입: 소울/피/재/얼음)
const DEATH_FX := {
	"skeleton": "fx_death_soul", "zombie": "fx_death_soul", "wraith_knight": "fx_death_soul",
	"dark_knight": "fx_death_soul", "void_wraith": "fx_death_soul",
	"goblin": "fx_death_blood", "orc": "fx_death_blood", "mushroom": "fx_death_blood",
	"slime": "fx_death_blood", "spider": "fx_death_blood", "bat": "fx_death_blood",
	"fire_imp": "fx_death_ember", "hellhound": "fx_death_ember", "gargoyle": "fx_death_ember",
	"demon": "fx_death_ember",
	"ice_wisp": "fx_death_ice", "frost_golem": "fx_death_ice",
	# 신규 몹 5종 (스테이지 테마)
	"ghoul": "fx_death_blood", "lava_toad": "fx_death_ember",
	"frost_spider": "fx_death_ice", "eye_mass": "fx_death_soul", "cultist": "fx_death_blood",
}
func _death_fx_for(key: String) -> String:
	return DEATH_FX.get(key, "fx_death_blood")


func on_enemy_killed(e: Enemy) -> void:
	kills += 1
	# 궁극기 게이지 충전 (엘리트는 크게). 처치 = 게이지 → "쌓아서 터뜨리는" 능동 루프.
	ult_gauge = minf(1.0, ult_gauge + (0.05 if e.elite else 0.008))
	_refresh_ult_bar()
	_maybe_drop_gear(e.position, e.elite)   # 장비 드롭 (엘리트 확정급, 일반 저확률)
	var enemy_key := str(e.tier.get("key", "unknown"))
	var enemy_kills: Dictionary = meta.get_or_add("enemy_kills", {})
	enemy_kills[enemy_key] = int(enemy_kills.get(enemy_key, 0)) + 1
	play_sfx("kill", -12.0, 0.06)
	# 몹 종류별 죽음 버스트 이펙트 (PixelLab). 프레임 없으면 spawn_fx가 조용히 무시.
	spawn_fx(_death_fx_for(str(e.tier.get("key", ""))), e.position, (e.radius * 3.2) + (24.0 if e.elite else 0.0))
	# 행동별 사망 처리 (#27): 자폭=광역피해, 분열=새끼 소환
	match e.behavior:
		"exploder":
			var fx0 := Effect.new()
			fx0.kind = "ring"
			fx0.position = e.position
			fx0.rad = 95.0
			fx0.col = Color(1.0, 0.55, 0.2)
			fx0.life = 0.4
			fx0.max_life = 0.4
			add_child(fx0)
			shake_t = max(shake_t, 0.12)
			if player and player.invuln <= 0.0 and e.position.distance_to(player.position) < 95.0:
				apply_player_damage(max(1.0, e.touch_damage * 2.2 - player.armor))
				player.invuln = 0.6
				player.play_hurt()
		"splitter":
			if not e.is_split:
				for i in 2:
					var child := Enemy.new()
					var ct: Dictionary = e.tier.duplicate()
					ct["behavior"] = ""   # 새끼는 재분열 안함
					child.position = e.position + Vector2(randf_range(-16, 16), randf_range(-16, 16))
					child.setup(ct, time_survived)
					child.hp *= 0.4 * diff_enemy_hp
					child.radius *= 0.62
					child.xp_value = max(1, int(e.xp_value / 3))
					child.is_split = true
					add_child(child)
	_spawn_gem(e.position, e.xp_value)
	# 골드 드랍. 뱀서식: 보물상자는 보스 전용 → 엘리트는 골드·젬만 확정, 상자 없음.
	if e.elite:
		_spawn_coin(e.position, 5 + stage_num * 2)
	elif randf() < 0.3:
		_spawn_coin(e.position, 1 + int(e.xp_value / 4.0))
	# 처치 파티클
	var fx := Effect.new()
	fx.kind = "burst"
	fx.position = e.position
	fx.col = e.color
	fx.life = 0.35
	fx.max_life = 0.35
	add_child(fx)


# 캐릭터 고유 특성 (런 시작 시 1회). 스탯 배수를 넘는 개성.
# 캐릭터 고유 특성 — 뱀서식 레벨 성장형.
# 예전엔 런 시작 시 고정 보너스 1회였으나, 뱀서는 레벨이 오를수록 자란다
# (안토니오 "10레벨마다 피해 +10%, 최대 +50%"). 런 내내 캐릭터가 크는 감각을 준다.
# 시작 시점의 개성은 GameConfig의 기본 스탯 배수(hp/speed/cd/range/melee/ranged)가 담당.
# _gain_xp에서 레벨이 오를 때마다 호출 → 도달한 단계만큼 델타를 적용.
# [개발 도구] --growth 검증용: 성장 스탯의 현재값을 읽어옴
func _growth_probe(stat: String) -> float:
	match stat:
		"damage": return player.damage_mult
		"area": return player.area_mult
		"cooldown": return player.cooldown_mult
		"crit": return player.crit_chance
		"regen": return player.regen
		"armor": return player.armor
		"amount": return float(player.amount)
		"speed": return player.speed
		"xp": return xp_mult
		"greed": return greed_mult
		"magnet": return player.pickup_radius
	return 0.0


func _apply_char_growth() -> void:
	if player == null:
		return
	var g: Dictionary = sel_char.get("growth", {})
	if g.is_empty():
		return
	var per: int = max(1, int(g.get("per", 10)))
	var maxt: int = int(g.get("max", 5))
	var tier: int = min(level / per, maxt)
	if tier <= _growth_tier:
		return
	var steps: int = tier - _growth_tier
	_growth_tier = tier
	var amt: float = float(g.get("amt", 0.0)) * steps
	match str(g.get("stat", "")):
		"damage":
			player.damage_mult += amt
		"area":
			player.area_mult += amt
		"cooldown":
			player.cooldown_mult = max(0.35, player.cooldown_mult - amt)
		"crit":
			player.crit_chance += amt
		"regen":
			player.regen += amt
		"armor":
			player.armor += amt
		"amount":
			player.amount += int(round(amt))
		"speed":
			player.speed += _base_speed * amt   # 기준 속도 대비 % (배수 누적 왜곡 방지)
		"xp":
			xp_mult += amt
		"greed":
			greed_mult += amt
		"magnet":
			player.pickup_radius += amt


# 파괴 오브젝트 처치 → 전리품 분출 (뱀서식 촛대 파밍)
func on_breakable_destroyed(b) -> void:
	var pos: Vector2 = b.position
	# 숨김 관(coffin): 강력 보상 — 팡파레 + 보너스 상자(무기/패시브) + 금화 폭발
	if b.kind == "coffin":
		_flash(Color(1.0, 0.85, 0.4, 0.5))
		shake_t = max(shake_t, 0.3)
		_event_banner("⚰ 숨겨진 관을 열었다!")
		play_sfx("levelup", -4.0)
		for i in (10 + stage_num * 2):
			_spawn_coin(pos + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 60.0), 3 + stage_num)
		_spawn_gem(pos, 12 + stage_num * 3)
		# 뱀서식: 관에서 '보물상자 픽업'이 튀어나와 바닥에 놓임 → 걸어가 주우면 개봉(획득감)
		var pc := Pickup.new()
		pc.kind = "chest"
		pc.position = pos
		add_child(pc)
		return
	play_sfx("coin", -10.0, 0.1)
	shake_t = max(shake_t, 0.08)
	# 파편 파티클
	var fx := Effect.new()
	fx.kind = "burst"
	fx.position = pos
	fx.col = Color(0.7, 0.5, 0.3)
	fx.life = 0.35
	fx.max_life = 0.35
	add_child(fx)
	# 골드 분출 (다발) + 런 위협/탐욕은 collect_coin에서 반영
	var coins: int = 2 + randi() % 3 + int(stage_num)
	for i in coins:
		_spawn_coin(pos + Vector2.from_angle(randf() * TAU) * randf_range(6.0, 26.0), 1 + int(stage_num / 2))
	# 확률 전리품: 젬 / 바닥 아이템 (뱀서식: 대부분 골드만, 가끔 아이템 — '안 나올 수도 있다'는 전제)
	var luck: float = 1.0 + (diff_loot - 1.0) * 0.5
	if randf() < 0.30 * luck:
		_spawn_gem(pos, 3 + stage_num)
	# 통닭(전체회복): 기본 낮음 + 체력이 낮을수록 확 오름 (뱀서 히든 메커닉 — 위기 구원)
	var hp_frac: float = clamp(player.hp / max(1.0, player.max_hp), 0.0, 1.0)
	var chicken_chance: float = (0.02 + (1.0 - hp_frac) * 0.16) * luck   # 2%(만피) → ~18%(빈사)
	if randf() < chicken_chance:
		var ck := Pickup.new()
		ck.kind = "chicken"
		ck.position = pos
		add_child(ck)
	elif randf() < 0.22 * luck:   # ~22%만 아이템 드랍 (78%는 안 나옴 → 원하는 템 찾아 계속 부수는 파밍)
		var p := Pickup.new()
		p.kind = _random_floor_item()
		p.position = pos
		add_child(p)


func on_boss_killed() -> void:
	# 던전 목표 보스 처치 = 던전 클리어 (B블렌드 승리조건)
	if _boss_is_objective:
		_boss_is_objective = false
		var bpos: Vector2 = boss.position if (boss and is_instance_valid(boss)) else player.position
		boss = null
		boss_spawned = false
		run_bosses += 1
		# 클리어 보상: 확정 장비 2개(_found → 런 종료 시 보관함행) + 골드
		inventory.append(_roll_gear())
		inventory.append(_roll_gear())
		run_gold += 40 * map_stage
		# 다음 던전 해금
		if not cheated and map_stage >= int(meta.get("stage_unlocked", 1)) and map_stage < FINAL_STAGE:
			meta["stage_unlocked"] = map_stage + 1
		_slowmo(0.4, 360)
		_flash(Color(1.0, 0.9, 0.6, 0.5))
		shake_t = max(shake_t, 0.35)
		if state == State.PLAYING:
			state = State.VICTORY
			get_tree().paused = true
			_show_end("⚔ 던전 클리어! — %s 정복" % str(GameConfig.stage_info(map_stage)["name"]), true)
		return
	run_gold += 15 * stage_num   # 보스 보상
	# 보스 = 장비 전리품 확정 2개
	if boss and is_instance_valid(boss):
		_spawn_gear_pickup(boss.position + Vector2(-18, 0), _roll_gear())
		_spawn_gear_pickup(boss.position + Vector2(18, 0), _roll_gear())
	boss = null
	run_bosses += 1
	boss_spawned = false
	# 보스 처치 연출: 짧은 슬로우모션 + 플래시 + 흔들림
	_slowmo(0.35, 340)
	_flash(Color(1.0, 0.9, 0.6, 0.42))
	shake_t = max(shake_t, 0.3)
	# 보스 처치 보상: 회복 + 보너스 카드
	player.hp = min(player.max_hp, player.hp + player.max_hp * 0.35)
	if abyss_mode:
		# 심연: 다음 보스 예약 + 무한 강화
		next_boss_time = time_survived + BOSS_TIME
		diff_enemy_hp *= 1.25
		diff_enemy_speed *= 1.04
		stage_num += 1
		_gen_decorations()
		if stage_label:
			stage_label.text = "심연 %d층" % stage_num
			stage_label.visible = true
		stage_banner_t = 2.5
	# 보스 처치 = 상자 드랍 (진화 기회 또는 보너스 카드) — 뱀서식
	var pc := Pickup.new()
	pc.kind = "chest"
	pc.position = player.position + Vector2(0, -48)
	add_child(pc)


# 시간 기반 스테이지 전환 (배경·난이도 상승, 소량 회복)
func _advance_stage(n: int) -> void:
	stage_num = n
	# 적 종류·밀도·엘리트 확률이 이미 분 단위 웨이브에서 상승한다.
	# 난이도 배수를 또 누적하지 않아 30분 후반의 삼중 스케일링을 방지한다.
	player.hp = min(player.max_hp, player.hp + player.max_hp * 0.15)
	_gen_decorations()
	if stage_label:
		var theme_stage := map_stage if map_stage > 0 else stage_num
		var prefix := "위험도" if map_stage > 0 else "STAGE"
		stage_label.text = "%s %d — %s" % [prefix, stage_num, GameConfig.stage_info(theme_stage)["name"]]
		stage_label.visible = true
	stage_banner_t = 2.5
	play_sfx("boss", -14.0, 0.0)


func _event_banner(txt: String) -> void:
	if stage_label:
		stage_label.text = txt
		stage_label.visible = true
	stage_banner_t = 2.2
	play_sfx("boss", -8.0)
	shake_t = max(shake_t, 0.16)


func _edge_pos(ang: float, extra := 0.0) -> Vector2:
	var view := get_viewport_rect().size
	var z: float = player.cam.zoom.x if player and player.cam else 1.0
	var dist: float = max(view.x, view.y) / z * 0.58 + extra
	var p := player.position + Vector2(cos(ang), sin(ang)) * dist
	p.x = clamp(p.x, 10.0, WORLD.x - 10.0)
	p.y = clamp(p.y, 10.0, WORLD.y - 10.0)
	if stage_layout and not stage_layout.is_walkable(p, 18.0):
		p = stage_layout.nearest_walkable(p, 18.0)
	return p


# 분당 이벤트 스파이크: 종류를 순환하며 리듬감 있는 웨이브 (뱀서식)
func _spawn_event(scheduled_type: int = -1) -> void:
	var event_type := scheduled_type if scheduled_type >= 0 else _event_idx % 6
	# Bosses remain simple chasers.  Only normal wave formations vary by map.
	if map_stage > 0:
		var cycle: Array = GameConfig.stage_spawn_profile(map_stage).get("events", [])
		if not cycle.is_empty():
			event_type = int(cycle[_event_idx % cycle.size()])
	match event_type:
		0: _event_static_ring()
		1: _spawn_horde()
		2: _event_pincer()
		3: _event_wall()
		4: _event_encircle()
		5: _event_elite_pack()
	_event_idx += 1


# 벽 돌격: 한쪽 변 전체에서 긴 줄(벽)로 밀려온다 (VS 시그니처 물결 웨이브)
func _event_wall() -> void:
	var tt := _themed_tier(true)
	var side := randf() * TAU                       # 몰려올 방향
	var perp := Vector2.from_angle(side).orthogonal()
	var view := get_viewport_rect().size
	var half: float = max(view.x, view.y) * 0.7
	var n: int = min(_spawn_budget(), 26 + stage_num * 7)
	for i in n:
		var t := (i / float(max(1, n - 1)) - 0.5) * 2.0   # -1..1
		var base := _edge_pos(side, randf_range(20.0, 120.0))
		_make_enemy(base + perp * t * half, false, tt)
	_event_banner("⚠ %s 벽이 밀려온다!" % tt.get("name", ""))


# 대규모 호드: 한 방향에서 떼로 몰려오는 무리
func _spawn_horde() -> void:
	var tt := _themed_tier(true)
	var base_ang := randf() * TAU
	var n: int = min(_spawn_budget(), 20 + stage_num * 6)
	for i in n:
		var ang := base_ang + randf_range(-0.65, 0.65)
		_make_enemy(_edge_pos(ang, randf_range(60.0, 280.0)), false, tt)
	_event_banner("⚠ %s 무리 출현!" % tt.get("name", "대규모"))


# 포위망: 사방 링으로 둘러싸고 조여옴
func _event_encircle() -> void:
	var tt := _themed_tier(true)
	var n: int = min(_spawn_budget(), 44 + stage_num * 8)
	for i in n:
		var ang := TAU * i / float(max(1, n)) + randf_range(-0.05, 0.05)
		_make_enemy(_edge_pos(ang, randf_range(20.0, 90.0)), false, tt)
	_event_banner("⚠ %s 포위망!" % tt.get("name", ""))


# 정적 포위 원 (뱀서식): 플레이어 주위 고정 반경에 촘촘한 원으로 나타나 천천히 조여오다
# 일정 시간 뒤 스르륵 소멸. 틈으로 빠져나가는 컨트롤을 요구.
func _event_static_ring() -> void:
	var tt := _themed_tier(true)
	var n: int = min(_spawn_budget(), 40 + stage_num * 6)
	var rad := 360.0 + stage_num * 12.0
	var base := randf() * TAU
	for i in n:
		var ang := base + TAU * i / float(max(1, n))
		var pos := player.position + Vector2(cos(ang), sin(ang)) * rad
		pos.x = clamp(pos.x, 40.0, WORLD.x - 40.0)
		pos.y = clamp(pos.y, 40.0, WORLD.y - 40.0)
		_make_enemy(pos, false, tt, 13.0, true)   # 13초 뒤 소멸 + 제자리 고정(안 움직임)
	_event_banner("⚠ %s 원진(圓陣)! — 틈으로 빠져나가라" % tt.get("name", ""))


# 양방향 협공: 반대쪽 두 벽
func _event_pincer() -> void:
	var tt := _themed_tier(true)
	var base := randf() * TAU
	var per: int = min(_spawn_budget() / 2, 16 + stage_num * 4)
	for side in [base, base + PI]:
		for i in per:
			_make_enemy(_edge_pos(side + randf_range(-0.5, 0.5), randf_range(60.0, 240.0)), false, tt)
	_event_banner("⚠ %s 양방향 협공!" % tt.get("name", ""))


# 정예 무리: 엘리트 여럿이 한 방향에서 (미니보스 순간)
func _event_elite_pack() -> void:
	var tt := _themed_tier(true)
	var ang := randf() * TAU
	var cnt: int = min(_spawn_budget(), 3 + stage_num)
	for i in cnt:
		_make_enemy(_edge_pos(ang + randf_range(-0.4, 0.4), randf_range(40.0, 160.0)), true, tt)
	_event_banner("⚠ 정예 %s 무리!" % tt.get("name", ""))


func _gain_xp(amount: int) -> void:
	# 런 위협 효과는 이미 적 수를 늘려 젬을 더 뿌린다. 젬당 XP까지 곱하면
	# 성장 속도가 이중으로 폭증하므로 경험치에는 xp_mult만 적용한다.
	xp += int(round(amount * xp_mult))
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = _xp_requirement(level)
		pending_levelups += 1
		stat_points += 1   # RPG 능력치 포인트: 레벨업마다 1점 (인벤토리 I에서 분배)
	if player:
		player.set_stage(GameConfig.hero_stage_for_level(level))
	_refresh_equip_hud()   # HUD의 스탯 포인트 표시 갱신
	_apply_char_growth()   # 뱀서식: 레벨이 오르면 캐릭터 고유 특성도 자란다
	if pending_levelups > 0 and state == State.PLAYING:
		_start_levelup()


# 현재 레벨에서 다음 레벨까지 필요한 XP.
# Lv25에서 943까지 뛰던 2차식 대신 뱀서식 선형 성장 + Lv20 이후 완만한 보정을 사용한다.
func _xp_requirement(current_level: int) -> int:
	var late_level: int = maxi(0, current_level - 20)
	# 레벨업 속도 하향(사장님 요청, 재상향): 요구 XP 2.5배. 위협 효과의 XP 이중 적용도 제거.
	return int((8 + current_level * 5 + int(pow(float(late_level), 1.35) * 0.65)) * 2.5)


func _start_levelup() -> void:
	state = State.LEVELUP
	_flash(Color(1.0, 0.85, 0.4, 0.34))   # 레벨업 골드 플래시
	get_tree().paused = true
	play_sfx("levelup", -8.0)
	levelup_title.text = Loc.t("levelup") % level
	_banish_mode = false
	_populate_levelup()
	_update_levelup_buttons()
	levelup_panel.visible = true
	# 카드 등장 애니: 시차를 두고 페이드 + 팝인 (레벨업 순간 리듬감)
	for i in 3:
		var cd: Button = cards[i]
		cd.pivot_offset = cd.size / 2.0
		cd.modulate = Color(1, 1, 1, 0)
		cd.scale = Vector2(0.92, 0.92)
		var tw := cd.create_tween().set_parallel(true)
		tw.tween_property(cd, "modulate", Color(1, 1, 1, 1), 0.2).set_delay(i * 0.07)
		tw.tween_property(cd, "scale", Vector2.ONE, 0.26).set_delay(i * 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	cards[0].grab_focus()   # 컨트롤러 방향키로 카드 선택 가능


# 카드 3장 채우기 (리롤/밴 시 재호출)
const RARITY_COL := {
	"common": Color(0.88, 0.88, 0.9), "rare": Color(0.5, 0.78, 1.0),
	"epic": Color(0.82, 0.55, 1.0), "legendary": Color(1.0, 0.82, 0.4)}
const RARITY_ORDER := {"common": 1, "rare": 2, "epic": 3, "legendary": 4}


# 레벨업 카드·장비 등급 뽑기. 영구 럭과 호출부의 추가 럭이 높을수록 상위 등급 확률↑.
# 기본: legendary 2.5% · epic 8% · rare 24% · 나머지 common.
func _roll_rarity(bonus_luck: float = 0.0) -> String:
	var luck := float(int(meta.get("up", {}).get("luck", 0))) + bonus_luck
	var leg := 0.025 + luck * 0.004
	var epi := 0.08 + luck * 0.008
	var rar := 0.24 + luck * 0.010
	var r := randf()
	if r < leg:
		return "legendary"
	if r < leg + epi:
		return "epic"
	if r < leg + epi + rar:
		return "rare"
	return "common"


# ── 장비 시스템 (Phase 3: 핵앤슬래시 드롭) ─────────────────────────────
const EQUIP_SLOTS := ["weapon", "armor", "trinket"]
const EQUIP_SLOT_NAME := {"weapon": "무기", "armor": "방어구", "trinket": "장신구"}
const GEAR_NOUNS := {
	"weapon": ["검", "도끼", "지팡이", "단검", "창"],
	"armor": ["갑옷", "로브", "비늘갑주", "망토"],
	"trinket": ["반지", "부적", "목걸이", "인장"]}
const GEAR_ADJ := ["맹독의", "불타는", "얼어붙은", "강철의", "고대의", "저주받은", "빛나는", "심연의"]
# 장비 무기 명사 → 실제 전투 무기 키. 무기 슬롯 장비가 캐릭터 주무기(weapon1)를 대체한다.
# ponytail: 무기 비주얼은 속성별 변형이 없어 '얼어붙은 지팡이'도 혼탄 이펙트다. 데미지 상성은 정확.
const GEAR_NOUN_ATTACK := {
	"검": "cleave", "도끼": "axe", "지팡이": "soul_bolt", "단검": "knife", "창": "spear"}
# 장비 접두어 → 속성. 무기 슬롯 장비의 이 속성이 곧 내 공격 속성이 된다(상성 판정).
const GEAR_ADJ_ELEMENT := {
	"맹독의": "dark", "불타는": "fire", "얼어붙은": "ice", "강철의": "phys",
	"고대의": "phys", "저주받은": "dark", "빛나는": "holy", "심연의": "dark"}
# 속성 5종 색(데미지 숫자·연출 공용). phys는 기본 흰색 취급.
const ELEMENT_COL := {
	"phys": Color(1, 1, 1), "fire": Color(1.0, 0.5, 0.15), "ice": Color(0.5, 0.85, 1.0),
	"holy": Color(1.0, 0.95, 0.6), "dark": Color(0.78, 0.5, 1.0)}
const ELEMENT_NAME := {"phys": "물리", "fire": "화염", "ice": "냉기", "holy": "신성", "dark": "암흑"}
const WEAK_MULT := 1.5     # 약점 히트 배수
const RESIST_MULT := 0.6   # 저항 히트 배수
const GEAR_NOUN_ICON := {
	"검": "res://assets/items/gear_sword.png", "도끼": "res://assets/items/gear_axe.png",
	"지팡이": "res://assets/items/gear_staff.png", "단검": "res://assets/items/gear_dagger.png",
	"창": "res://assets/items/gear_spear.png", "갑옷": "res://assets/items/gear_plate.png",
	"로브": "res://assets/items/gear_robe.png", "비늘갑주": "res://assets/items/gear_scale.png",
	"망토": "res://assets/items/gear_cloak.png", "반지": "res://assets/items/gear_ring.png",
	"부적": "res://assets/items/gear_amulet.png", "목걸이": "res://assets/items/gear_necklace.png",
	"인장": "res://assets/items/gear_sigil.png"}
# 어픽스 풀: player의 가산형 스탯만 (교체 시 diff 제거가 깔끔한 필드).
const GEAR_AFFIXES := [
	{"stat": "damage_mult", "name": "공격력", "per": 0.06, "pct": true},
	{"stat": "max_hp", "name": "최대체력", "per": 14.0, "pct": false},
	{"stat": "armor", "name": "방어", "per": 1.0, "pct": false},
	{"stat": "area_mult", "name": "범위", "per": 0.05, "pct": true},
	{"stat": "pickup_radius", "name": "자석", "per": 18.0, "pct": false},
	{"stat": "regen", "name": "재생", "per": 0.3, "pct": false},
]
const GEAR_AFFIX_COUNT := {"common": 1, "rare": 1, "epic": 2, "legendary": 3}
const GEAR_POWER := {"common": 1.0, "rare": 1.5, "epic": 2.2, "legendary": 3.2}
const RARITY_TAG := {"common": "", "rare": "[레어]", "epic": "◆에픽◆", "legendary": "★레전더리★"}

# Phase 5 대장간: 장비 하나당 최대 5회, 강화마다 모든 어픽스가 +12%씩 강해진다.
# 런 골드가 초반 영구 강화와 함께 자연스럽게 소모되도록 등급별 비용을 별도로 둔다.
const FORGE_MAX_LEVEL := 5
const FORGE_LEVEL_BONUS := 0.12
const FORGE_UPGRADE_BASE_COST := {"common": 18, "rare": 40, "epic": 85, "legendary": 175}
const FORGE_SALVAGE_BASE := {"common": 5, "rare": 12, "epic": 28, "legendary": 60}


# 랜덤 장비 1개 생성 (등급은 _roll_rarity 재활용 → 럭 반영)
func _roll_gear() -> Dictionary:
	var slot: String = EQUIP_SLOTS[randi() % EQUIP_SLOTS.size()]
	var rarity := _roll_rarity(diff_rarity_luck)
	var pool: Array = GEAR_AFFIXES.duplicate()
	pool.shuffle()
	var affs: Array = []
	for i in mini(int(GEAR_AFFIX_COUNT[rarity]), pool.size()):
		var a: Dictionary = pool[i]
		var v: float = float(a["per"]) * float(GEAR_POWER[rarity]) * randf_range(0.8, 1.2)
		affs.append({"stat": a["stat"], "name": a["name"], "value": v, "base_value": v, "pct": bool(a["pct"])})
	var adj: String = GEAR_ADJ[randi() % GEAR_ADJ.size()]
	var noun: String = GEAR_NOUNS[slot][randi() % GEAR_NOUNS[slot].size()]
	var nm := "%s %s" % [adj, noun]
	# _found: 런 중 주운 표식 → 런 종료 시 이 장비만 마을 보관함으로 이월. lvl: 대장간 강화 레벨.
	# element: 접두어에서 결정. 무기 슬롯이면 이 속성이 곧 내 공격 속성.
	# weapon_kind: 무기 슬롯이면 실제 전투 무기 키 (주무기 대체). 다른 슬롯은 "".
	return {"slot": slot, "rarity": rarity, "affixes": affs, "name": nm, "icon": GEAR_NOUN_ICON.get(noun, ""), "element": GEAR_ADJ_ELEMENT.get(adj, "phys"), "weapon_kind": GEAR_NOUN_ATTACK.get(noun, ""), "_found": true, "gear_id": _new_gear_id(), "lvl": 0}


# 처치 지점에서 확률적으로 장비 드롭 (엘리트/보스는 높게)
func _maybe_drop_gear(pos: Vector2, elite: bool) -> void:
	var drop_chance := (0.35 if elite else 0.02) * diff_gear_drop
	if randf() < minf(0.90, drop_chance):
		_spawn_gear_pickup(pos, _roll_gear())


func _spawn_gear_pickup(pos: Vector2, it: Dictionary) -> void:
	var ord: int = RARITY_ORDER.get(str(it["rarity"]), 0)
	var col: Color = RARITY_COL.get(str(it["rarity"]), Color.WHITE)
	var p := Pickup.new()
	p.kind = "gear"
	p.item = it
	p.gear_col = col
	p.gear_tier = 2 if ord >= 4 else (1 if ord >= 3 else 0)   # 에픽1·레전더리2
	p.position = pos
	add_child(p)
	# 고등급 드롭 순간 연출 (필드에서 '떴다!'가 보이게)
	if ord >= 3:
		_spawn_proc_fx("burst", pos, 70.0, col, 0.45)
		_spawn_proc_fx("ring", pos, 110.0, col, 0.4)
		play_sfx("levelup", -12.0)
		if ord >= 4:
			_flash(Color(col.r, col.g, col.b, 0.3))


# 장비 획득: 현재 슬롯보다 등급이 같거나 높으면 장착, 아니면 골드로 분해.
func _pickup_gear(it: Dictionary) -> void:
	var slot := str(it["slot"])
	var ord: int = RARITY_ORDER.get(str(it["rarity"]), 0)
	play_sfx("levelup", -12.0)
	# 에픽·레전더리 획득 순간 화려하게 (플래시 + 버스트 + 흔들림, 레전더리는 슬로우모)
	if ord >= 3:
		var col: Color = RARITY_COL.get(str(it["rarity"]), Color.WHITE)
		_flash(Color(col.r, col.g, col.b, 0.5))
		_spawn_proc_fx("burst", player.position, 130.0, col, 0.45)
		_spawn_proc_fx("ring", player.position, 200.0, col, 0.4)
		play_sfx("ult", -8.0)
		shake_t = maxf(shake_t, 0.16)
		if ord >= 4:
			_slowmo(0.5, 220)
	# 빈 슬롯이면 바로 장착(맨손 방지), 아니면 가방으로 → 인벤토리에서 직접 교체.
	if equipped.get(slot, {}).is_empty():
		equipped[slot] = it
		_apply_equipment()
		_gear_toast(it)
	else:
		inventory.append(it)
		_bag_toast(it)
		if inventory_panel and inventory_panel.visible:
			_refresh_inventory_screen()


# 장착 아이템 어픽스를 player 스탯에 반영 (이전 적용분 제거 후 재계산 → 교체 정확).
func _apply_equipment() -> void:
	if player == null:
		return
	for stat in _equip_applied.keys():
		_equip_stat(str(stat), -float(_equip_applied[stat]))
	var totals := {}
	for slot in EQUIP_SLOTS:
		var it: Dictionary = equipped.get(slot, {})
		for a in it.get("affixes", []):
			totals[a["stat"]] = float(totals.get(a["stat"], 0.0)) + float(a["value"])
	for stat in totals.keys():
		_equip_stat(str(stat), float(totals[stat]))
	_equip_applied = totals
	# 공격 속성 = 장착 무기 속성. 무기가 없으면 캐릭터의 고유 시작 속성을 사용한다.
	# Q는 장비와 무관하게 언제나 캐릭터 고유 속성을 유지한다.
	var equipped_weapon: Dictionary = equipped.get("weapon", {})
	attack_element = str(equipped_weapon.get("element", _char_skill_element()))
	_refresh_equip_hud()
	_refresh_skill_hud()


func _equip_stat(stat: String, v: float) -> void:
	if player == null:
		return
	match stat:
		"damage_mult": player.damage_mult += v
		"max_hp":
			player.max_hp += v
			player.hp = clampf(player.hp + maxf(0.0, v), 0.0, player.max_hp)
		"armor": player.armor += v
		"area_mult": player.area_mult += v
		"pickup_radius": player.pickup_radius += v
		"regen": player.regen += v


func _gear_toast(it: Dictionary) -> void:
	if ach_toast == null:
		return
	var parts: Array = []
	for a in it["affixes"]:
		var vs := ("%d%%" % round(float(a["value"]) * 100.0)) if bool(a["pct"]) else ("%d" % round(float(a["value"])))
		parts.append("%s +%s" % [a["name"], vs])
	var tag := str(RARITY_TAG.get(str(it["rarity"]), ""))
	ach_toast.text = "%s %s  [%s]" % [tag, str(it["name"]), ", ".join(parts)]
	ach_toast.add_theme_color_override("font_color", RARITY_COL.get(str(it["rarity"]), Color.WHITE))
	ach_toast.visible = true
	ach_toast_t = 2.6


func _refresh_equip_hud() -> void:
	if equip_hud_label == null:
		return
	var lines: Array = []
	lines.append("공격 속성: %s" % str(ELEMENT_NAME.get(attack_element, "물리")))
	for slot in EQUIP_SLOTS:
		var it: Dictionary = equipped.get(slot, {})
		if it.is_empty():
			lines.append("%s: —" % EQUIP_SLOT_NAME[slot])
		else:
			lines.append("%s: %s%s" % [EQUIP_SLOT_NAME[slot], str(RARITY_TAG.get(str(it["rarity"]), "")), str(it["name"])])
	var inv_line := "[ I ] 인벤토리 (%d)" % inventory.size()
	if stat_points > 0:
		inv_line += "  ◆스탯 %d" % stat_points
	lines.append(inv_line)
	equip_hud_label.text = "\n".join(lines)


# ── 능력치 분배 (Phase 2: RPG 스탯 포인트) ────────────────────────────
# 포인트당 효과는 전부 player의 가산형 필드로 → 장비 어픽스와 같은 통에 합산.
const STAT_DEFS := [
	{"key": "str", "name": "힘",   "desc": "공격력 +3%"},
	{"key": "agi", "name": "민첩", "desc": "공격속도·이동속도 ↑"},
	{"key": "vit", "name": "체력", "desc": "최대체력 +10·재생"},
	{"key": "foc", "name": "집중", "desc": "공격범위 +3%·방어 +0.5"},
]


# 인벤토리에는 "이번 런에 총 얼마가 바뀌는가"를 보여 준다.
# 기존의 포인트당 설명은 길어서 작은 창에서 버튼/상세 정보와 겹쳤다.
func _stat_summary(key: String, lv: int) -> String:
	match key:
		"str":
			return "공격 +%d%%" % (lv * 3)
		"agi":
			return "이속 +%d · 공속 +%d%%" % [lv * 3, lv]
		"vit":
			return "체력 +%d · 재생 +%.1f" % [lv * 10, float(lv) * 0.1]
		"foc":
			return "범위 +%d%% · 방어 +%.1f" % [lv * 3, float(lv) * 0.5]
	return ""


func _gear_icon_path(item: Dictionary, slot_hint: String = "") -> String:
	var icon_path := str(item.get("icon", ""))
	if not icon_path.is_empty():
		return icon_path
	var slot := str(item.get("slot", ""))
	if slot.is_empty():
		slot = slot_hint
	match slot:
		"weapon":
			return "res://assets/items/gear_sword.png"
		"armor":
			return "res://assets/items/gear_plate.png"
		"trinket":
			return "res://assets/items/gear_ring.png"
	return ""


func _gear_slot_symbol(slot: String) -> String:
	match slot:
		"weapon":
			return "⚔"
		"armor":
			return "🛡"
		"trinket":
			return "✦"
	return "•"


func _gear_icon_socket(item: Dictionary, slot_hint: String = "", icon_size: Vector2 = Vector2(36.0, 36.0)) -> Panel:
	var socket := Panel.new()
	socket.custom_minimum_size = icon_size
	socket.add_theme_stylebox_override("panel", _slot_style())
	socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture := Assets.tex(_gear_icon_path(item, slot_hint))
	if texture:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.set_anchors_preset(Control.PRESET_FULL_RECT)
		image.offset_left = 3.0
		image.offset_top = 3.0
		image.offset_right = -3.0
		image.offset_bottom = -3.0
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		socket.add_child(image)
	else:
		var fallback := Label.new()
		fallback.text = _gear_slot_symbol(slot_hint)
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 16)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		socket.add_child(fallback)
	return socket


func _gear_equipped_card(item: Dictionary, slot: String, row_width: float) -> Control:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(maxf(52.0, (row_width - 8.0) / float(EQUIP_SLOTS.size())), 82.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _flatbox(Color(0.035, 0.04, 0.07, 0.88), 4.0))
	card.tooltip_text = _gear_detail_text(item)
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 3.0
	content.offset_top = 3.0
	content.offset_right = -3.0
	content.offset_bottom = -3.0
	content.add_theme_constant_override("separation", 1)
	card.add_child(content)
	var icon_center := CenterContainer.new()
	icon_center.custom_minimum_size = Vector2(0.0, 38.0)
	icon_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_center.add_child(_gear_icon_socket(item, slot, Vector2(36.0, 36.0)))
	content.add_child(icon_center)
	var label := Label.new()
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	var forge_tag := " +%d" % _gear_level(item) if _gear_level(item) > 0 else ""
	label.text = "%s\n%s%s" % [str(EQUIP_SLOT_NAME.get(slot, slot)), str(item.get("name", "비어 있음")), forge_tag]
	label.add_theme_color_override("font_color", RARITY_COL.get(str(item.get("rarity", "")), Color(0.7, 0.72, 0.78)) if not item.is_empty() else Color(0.6, 0.62, 0.68))
	content.add_child(label)
	return card


func _apply_gear_button_icon(button: Button, item: Dictionary) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 28)
	var texture := Assets.tex(_gear_icon_path(item))
	if texture:
		button.icon = texture


func _gear_slot_text(it: Dictionary) -> String:
	if it.is_empty():
		return "— 비어 있음"
	var forge_tag := " +%d" % _gear_level(it) if _gear_level(it) > 0 else ""
	return "%s %s%s" % [str(RARITY_TAG.get(str(it.get("rarity", "")), "")), str(it.get("name", "장비")), forge_tag]


func _gear_detail_text(it: Dictionary) -> String:
	if it.is_empty():
		return "비어 있음"
	var forge_tag := " +%d" % _gear_level(it) if _gear_level(it) > 0 else ""
	var lines := [
		"%s %s%s" % [str(RARITY_TAG.get(str(it.get("rarity", "")), "")), str(it.get("name", "장비")), forge_tag],
		"%s" % str(EQUIP_SLOT_NAME.get(str(it.get("slot", "")), "장비")),
	]
	if str(it.get("slot", "")) == "weapon":
		var weapon_kind := str(it.get("weapon_kind", ""))
		var active_def := _weapon_active_def_for_kind(weapon_kind)
		lines.append("자동공격  %s · %s 속성" % [
			str(WNAMES.get(weapon_kind, "기본 공격")),
			str(ELEMENT_NAME.get(str(it.get("element", "phys")), "물리")),
		])
		lines.append("E %s %s  (기본 %.1f초)" % [
			str(active_def.get("glyph", "•")),
			str(active_def.get("name", "무기 스킬")),
			float(active_def.get("cd", 0.0)),
		])
		lines.append(str(active_def.get("desc", "")))
	for raw_affix in it.get("affixes", []):
		if not (raw_affix is Dictionary):
			continue
		var affix := raw_affix as Dictionary
		var value_text := "%d%%" % round(float(affix.get("value", 0.0)) * 100.0) if bool(affix.get("pct", false)) else "%d" % round(float(affix.get("value", 0.0)))
		lines.append("• %s +%s" % [str(affix.get("name", "효과")), value_text])
	return "\n".join(lines)


func _gear_compare_text(selected: Dictionary, current: Dictionary) -> String:
	var lines := [
		"[color=#ffb6d4][b]선택 장비[/b][/color]",
		_gear_detail_text(selected),
		"",
		"[color=#8fcfff][b]현재 장비[/b][/color]",
		_gear_detail_text(current),
	]
	var delta := {}
	var names := {}
	for raw_affix in selected.get("affixes", []):
		if raw_affix is Dictionary:
			var affix := raw_affix as Dictionary
			var key := str(affix.get("stat", ""))
			delta[key] = float(delta.get(key, 0.0)) + float(affix.get("value", 0.0))
			names[key] = str(affix.get("name", "효과"))
	for raw_affix in current.get("affixes", []):
		if raw_affix is Dictionary:
			var affix := raw_affix as Dictionary
			var key := str(affix.get("stat", ""))
			delta[key] = float(delta.get(key, 0.0)) - float(affix.get("value", 0.0))
			names[key] = str(affix.get("name", "효과"))
	var changes: Array[String] = []
	for key in delta.keys():
		var value := float(delta[key])
		if is_zero_approx(value):
			continue
		var pct: bool = key in ["damage_mult", "area_mult"]
		var value_text := "%+.0f%%" % (value * 100.0) if pct else "%+.1f" % value
		var arrow := "▲" if value > 0.0 else "▼"
		var color := "#79eca3" if value > 0.0 else "#ff8296"
		changes.append("[color=%s]%s %s %s[/color]" % [color, arrow, str(names.get(key, "효과")), value_text])
	if not changes.is_empty():
		lines.append("")
		lines.append("[color=#ffd36d][b]교체 변화[/b][/color]")
		lines.append_array(changes)
	return "\n".join(lines)


func _apply_stat_point(key: String) -> void:
	if player == null:
		return
	match key:
		"str":
			player.damage_mult += 0.03
		"agi":
			player.cooldown_mult = maxf(0.3, player.cooldown_mult - 0.01)
			player.speed += 3.0
		"vit":
			player.max_hp += 10.0
			player.hp = minf(player.max_hp, player.hp + 10.0)
			player.regen += 0.1
		"foc":
			player.area_mult += 0.03
			player.armor += 0.5


func _spend_stat_point(key: String) -> void:
	if stat_points <= 0 or not char_stats.has(key):
		return
	stat_points -= 1
	char_stats[key] = int(char_stats[key]) + 1
	assert(stat_points >= 0)   # 불변식: 분배 포인트는 음수가 될 수 없음
	_apply_stat_point(key)
	play_sfx("select", -12.0)
	_refresh_stat_box()
	_refresh_equip_hud()
	_update_ui()


func _refresh_stat_box() -> void:
	if inv_stat_box == null:
		return
	for c in inv_stat_box.get_children():
		c.queue_free()
	var hdr := Label.new()
	hdr.text = "분배 포인트 %d  ·  이번 런 전용" % stat_points
	hdr.custom_minimum_size = Vector2(0, 22)
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4) if stat_points > 0 else Color(0.6, 0.62, 0.68))
	inv_stat_box.add_child(hdr)
	for d in STAT_DEFS:
		var key := str(d["key"])
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 26)
		row.add_theme_constant_override("separation", 6)
		var lb := Label.new()
		lb.custom_minimum_size = Vector2(inv_stat_label_width, 26)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.clip_text = true
		lb.add_theme_font_size_override("font_size", 12)
		var lv := int(char_stats[key])
		lb.text = "%s Lv%d · %s" % [str(d["name"]), lv, _stat_summary(key, lv)]
		lb.tooltip_text = "%s\n포인트당 %s" % [str(d["name"]), str(d["desc"])]
		row.add_child(lb)
		var btn := Button.new()
		btn.text = "+"
		btn.custom_minimum_size = Vector2(34, 26)
		btn.disabled = stat_points <= 0
		btn.tooltip_text = "%s에 포인트 투자" % str(d["name"])
		_style_button(btn, "res://assets/ui/button.png", 10.0, 1.0)
		btn.pressed.connect(_spend_stat_point.bind(key))
		row.add_child(btn)
		inv_stat_box.add_child(row)


# ── 인벤토리 (Phase 3b: 직접 장착/비교 UI) ─────────────────────────────
func _gear_line(it: Dictionary) -> String:
	if it.is_empty():
		return "—"
	var parts: Array = []
	for a in it["affixes"]:
		var vs := ("%d%%" % round(float(a["value"]) * 100.0)) if bool(a["pct"]) else ("%d" % round(float(a["value"])))
		parts.append("%s+%s" % [str(a["name"]), vs])
	var lv := _gear_level(it)
	var forge_tag := " +%d" % lv if lv > 0 else ""
	# 무기 장비: 속성 + 발동 무기를 함께 표기(장착 시 주공격이 바뀜을 알림).
	var wk := str(it.get("weapon_kind", ""))
	var extra := ""
	if str(it.get("slot", "")) == "weapon" and wk != "":
		extra = "  [%s·%s]" % [str(ELEMENT_NAME.get(str(it.get("element", "phys")), "물리")), str(WNAMES.get(wk, wk))]
	return "%s %s%s%s  (%s)" % [str(RARITY_TAG.get(str(it["rarity"]), "")), str(it["name"]), forge_tag, extra, ", ".join(parts)]


func _bag_toast(it: Dictionary) -> void:
	if ach_toast == null:
		return
	ach_toast.text = "🎒 가방에 담김: %s%s  [I]" % [str(RARITY_TAG.get(str(it["rarity"]), "")), str(it["name"])]
	ach_toast.add_theme_color_override("font_color", RARITY_COL.get(str(it["rarity"]), Color.WHITE))
	ach_toast.visible = true
	ach_toast_t = 2.2


func _gear_gold_value(it: Dictionary) -> int:
	return {"common": 3, "rare": 6, "epic": 12, "legendary": 25}.get(str(it.get("rarity", "")), 3)


# ── 마을 대장간 (Phase 5: 영구 보관·로드아웃·강화) ─────────────────────
# 장비 ID는 보관함과 로드아웃의 같은 아이템을 연결한다. 이름/어픽스가 같은 드롭도 구분해야
# 강화·분해가 의도한 한 개에만 적용된다.
func _new_gear_id() -> String:
	return "%x-%08x" % [Time.get_ticks_usec(), randi()]


func _gear_level(it: Dictionary) -> int:
	return clampi(int(it.get("lvl", 0)), 0, FORGE_MAX_LEVEL)


func _is_valid_gear(it: Dictionary) -> bool:
	return str(it.get("slot", "")) in EQUIP_SLOTS and RARITY_ORDER.has(str(it.get("rarity", ""))) and it.has("affixes")


# 저장용 장비를 정규화한다. base_value를 남겨 강화값을 누적 오차 없이 재계산하고,
# 중단된 Phase 5 세이브나 구버전 드롭에도 ID/강화 레벨을 보완한다.
func _normalize_persistent_gear(it: Dictionary) -> Dictionary:
	var normalized: Dictionary = it.duplicate(true)
	if not _is_valid_gear(normalized):
		return {}
	if str(normalized.get("gear_id", "")).begins_with("active-preview-"):
		return {}
	normalized.erase("_found")
	var lv := _gear_level(normalized)
	normalized["lvl"] = lv
	if str(normalized.get("gear_id", "")).is_empty():
		normalized["gear_id"] = _new_gear_id()
	# 속성 백필: 구 세이브·프리뷰 장비는 element가 없으니 이름 접두어로 보완.
	if str(normalized.get("element", "")).is_empty():
		normalized["element"] = GEAR_ADJ_ELEMENT.get(str(normalized.get("name", "")).split(" ")[0], "phys")
	# 무기 키 백필: 무기 슬롯인데 weapon_kind가 없으면 이름 명사(둘째 단어)로 보완.
	if str(normalized.get("slot", "")) == "weapon" and str(normalized.get("weapon_kind", "")).is_empty():
		var parts: PackedStringArray = str(normalized.get("name", "")).split(" ")
		normalized["weapon_kind"] = GEAR_NOUN_ATTACK.get(parts[1] if parts.size() > 1 else "", "")
	var affixes: Array = []
	for raw_affix in normalized.get("affixes", []):
		if not (raw_affix is Dictionary):
			continue
		var affix: Dictionary = (raw_affix as Dictionary).duplicate(true)
		var scale := 1.0 + FORGE_LEVEL_BONUS * float(lv)
		var base_value: float
		if affix.has("base_value"):
			base_value = float(affix["base_value"])
		else:
			base_value = float(affix.get("value", 0.0)) / scale
		affix["base_value"] = base_value
		affix["value"] = base_value * scale
		affixes.append(affix)
	normalized["affixes"] = affixes
	return normalized


func _same_gear(a: Dictionary, b: Dictionary) -> bool:
	var a_id := str(a.get("gear_id", ""))
	var b_id := str(b.get("gear_id", ""))
	if not a_id.is_empty() and not b_id.is_empty():
		return a_id == b_id
	# ID 도입 전 저장을 한 번만 정리할 때의 폴백. 이후에는 항상 ID로 비교한다.
	return str(a.get("slot", "")) == str(b.get("slot", "")) and str(a.get("rarity", "")) == str(b.get("rarity", "")) and str(a.get("name", "")) == str(b.get("name", "")) and a.get("affixes", []) == b.get("affixes", [])


func _forge_find_stash_index(stash: Array, it: Dictionary) -> int:
	for i in range(stash.size()):
		var candidate = stash[i]
		if candidate is Dictionary and _same_gear(candidate as Dictionary, it):
			return i
	return -1


# meta.cfg의 장비 데이터를 정리하고, 로드아웃은 반드시 보관함의 같은 아이템을 참조하게 만든다.
func _ensure_gear_meta() -> bool:
	var clean_stash: Array = []
	var removed_dev_preview_gear := false
	var raw_stash = meta.get("stash", [])
	if raw_stash is Array:
		for raw in raw_stash:
			if raw is Dictionary:
				if str((raw as Dictionary).get("gear_id", "")).begins_with("active-preview-"):
					removed_dev_preview_gear = true
					continue
				var stash_item := _normalize_persistent_gear(raw as Dictionary)
				if not stash_item.is_empty() and _forge_find_stash_index(clean_stash, stash_item) < 0:
					clean_stash.append(stash_item)
	var clean_loadout := {"weapon": {}, "armor": {}, "trinket": {}}
	var raw_loadout = meta.get("loadout", {})
	if raw_loadout is Dictionary:
		for slot in EQUIP_SLOTS:
			var raw = (raw_loadout as Dictionary).get(slot, {})
			if raw is Dictionary and not (raw as Dictionary).is_empty():
				if str((raw as Dictionary).get("gear_id", "")).begins_with("active-preview-"):
					removed_dev_preview_gear = true
					continue
				var loadout_item := _normalize_persistent_gear(raw as Dictionary)
				if not loadout_item.is_empty() and str(loadout_item["slot"]) == slot:
					var loadout_idx := _forge_find_stash_index(clean_stash, loadout_item)
					if loadout_idx < 0:
						clean_stash.append(loadout_item)
						loadout_idx = clean_stash.size() - 1
					clean_loadout[slot] = (clean_stash[loadout_idx] as Dictionary).duplicate(true)
	meta["stash"] = clean_stash
	meta["loadout"] = clean_loadout
	return removed_dev_preview_gear


func _forge_upgrade_cost(it: Dictionary, at_level: int = -1) -> int:
	var lv := _gear_level(it) if at_level < 0 else at_level
	return int(FORGE_UPGRADE_BASE_COST.get(str(it.get("rarity", "")), 18)) * (lv + 1)


func _forge_salvage_value(it: Dictionary) -> int:
	var value := int(FORGE_SALVAGE_BASE.get(str(it.get("rarity", "")), 5))
	for upgraded_level in range(_gear_level(it)):
		value += int(round(_forge_upgrade_cost(it, upgraded_level) * 0.5))
	return value


# _found 표식이 있는 장비만 런 종료 시 영구 보관한다. 표식은 런타임 장비에서도 제거해
# 30분 승리 뒤 심연 모드로 이어가도 같은 아이템이 두 번 보관되지 않게 한다.
func _bank_found_gear() -> int:
	_ensure_gear_meta()
	var stash: Array = meta["stash"]
	var banked := 0
	for slot in EQUIP_SLOTS:
		var equipped_item: Dictionary = equipped.get(slot, {})
		if not bool(equipped_item.get("_found", false)):
			continue
		var saved := _normalize_persistent_gear(equipped_item)
		if saved.is_empty():
			continue
		var equipped_idx := _forge_find_stash_index(stash, saved)
		if equipped_idx < 0:
			stash.append(saved)
		else:
			stash[equipped_idx] = saved
		equipped_item.erase("_found")
		equipped_item["gear_id"] = saved["gear_id"]
		equipped_item["lvl"] = saved["lvl"]
		equipped_item["affixes"] = (saved["affixes"] as Array).duplicate(true)
		equipped[slot] = equipped_item
		banked += 1
	for i in range(inventory.size()):
		var inventory_item: Dictionary = inventory[i]
		if not bool(inventory_item.get("_found", false)):
			continue
		var saved := _normalize_persistent_gear(inventory_item)
		if saved.is_empty():
			continue
		var inventory_idx := _forge_find_stash_index(stash, saved)
		if inventory_idx < 0:
			stash.append(saved)
		else:
			stash[inventory_idx] = saved
		inventory_item.erase("_found")
		inventory_item["gear_id"] = saved["gear_id"]
		inventory_item["lvl"] = saved["lvl"]
		inventory_item["affixes"] = (saved["affixes"] as Array).duplicate(true)
		inventory[i] = inventory_item
		banked += 1
	meta["stash"] = stash
	return banked


func _open_forge() -> void:
	_ensure_gear_meta()
	_forge_sel = -1
	_refresh_forge()
	forge_panel.visible = true


func _select_forge_item(idx: int) -> void:
	_forge_sel = idx
	_refresh_forge()


func _forge_selected_item() -> Dictionary:
	var stash: Array = meta.get("stash", [])
	if _forge_sel < 0 or _forge_sel >= stash.size() or not (stash[_forge_sel] is Dictionary):
		return {}
	return stash[_forge_sel] as Dictionary


func _forge_item_equipped(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	var loadout: Dictionary = meta.get("loadout", {})
	var current = loadout.get(str(it.get("slot", "")), {})
	return current is Dictionary and _same_gear(current as Dictionary, it)


func _refresh_forge() -> void:
	if forge_panel == null:
		return
	_ensure_gear_meta()
	var stash: Array = meta["stash"]
	forge_gold_label.text = "보유 골드 %d G  ·  장착 장비는 다음 런부터 적용" % int(meta.get("gold", 0))
	if forge_stash_label:
		forge_stash_label.text = "[ 보관함 ]  %d개" % stash.size()
	for child in forge_loadout_box.get_children():
		child.queue_free()
	var loadout: Dictionary = meta["loadout"]
	for slot in EQUIP_SLOTS:
		var item: Dictionary = loadout.get(slot, {})
		forge_loadout_box.add_child(_gear_equipped_card(item, slot, forge_loadout_width))
	for child in forge_list_box.get_children():
		child.queue_free()
	if stash.is_empty():
		var empty := Label.new()
		empty.text = "🎁 보관함이 비어 있습니다.\n\n다음 런에서 엘리트와 보스를 처치해\n영구 장비를 획득하세요."
		empty.custom_minimum_size = Vector2(forge_list_item_width, 118)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.62, 0.65, 0.72))
		forge_list_box.add_child(empty)
	for i in range(stash.size()):
		var item: Dictionary = stash[i]
		var button := Button.new()
		var equipped_mark := " [장착]" if _forge_item_equipped(item) else ""
		var selected_mark := "▶ " if i == _forge_sel else ""
		var forge_tag := " +%d" % _gear_level(item) if _gear_level(item) > 0 else ""
		button.text = "%s[%s] %s%s%s" % [selected_mark, str(EQUIP_SLOT_NAME.get(str(item.get("slot", "")), "장비")), str(item.get("name", "장비")), forge_tag, equipped_mark]
		button.custom_minimum_size = Vector2(forge_list_item_width, 42)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 12)
		button.modulate = RARITY_COL.get(str(item.get("rarity", "")), Color.WHITE)
		_style_button(button, "res://assets/ui/button.png", 12.0, 2.0)
		_apply_gear_button_icon(button, item)
		button.tooltip_text = _gear_detail_text(item)
		button.pressed.connect(_select_forge_item.bind(i))
		forge_list_box.add_child(button)
	var selected := _forge_selected_item()
	if selected.is_empty():
		forge_detail_label.text = "장비를 선택하면 여기서 비교와 강화를 진행합니다.\n\n[ 대장간 안내 ]\n• 장착: 다음 런 시작부터 적용\n• 강화: 최대 5단계, 모든 어픽스 +12%\n• 분해: 장비를 골드로 환원"
		forge_equip_btn.disabled = true
		forge_upgrade_btn.disabled = true
		forge_discard_btn.disabled = true
		forge_equip_btn.text = "장비 선택"
		forge_upgrade_btn.text = "강화 +1"
		forge_discard_btn.text = "분해"
		return
	var lv := _gear_level(selected)
	var is_equipped := _forge_item_equipped(selected)
	var upgrade_cost := _forge_upgrade_cost(selected)
	var current_bonus := int(round(lv * FORGE_LEVEL_BONUS * 100.0))
	var next_text := "최대 강화" if lv >= FORGE_MAX_LEVEL else "다음 Lv +%d%%" % int(round((lv + 1) * FORGE_LEVEL_BONUS * 100.0))
	forge_detail_label.text = "%s\n\n[ 강화 ]\nLv%d/%d  ·  현재 어픽스 +%d%%\n%s\n\n[ 적용 ]\n%s" % [_gear_detail_text(selected), lv, FORGE_MAX_LEVEL, current_bonus, next_text, "현재 로드아웃에 장착 중입니다." if is_equipped else "장착하면 다음 런 시작부터 적용됩니다."]
	forge_equip_btn.disabled = false
	forge_equip_btn.text = "장착 해제" if is_equipped else "장착 ▶"
	forge_upgrade_btn.disabled = lv >= FORGE_MAX_LEVEL or int(meta.get("gold", 0)) < upgrade_cost
	forge_upgrade_btn.text = "최대 강화" if lv >= FORGE_MAX_LEVEL else "강화 +1 (%d G)" % upgrade_cost
	forge_discard_btn.disabled = false
	forge_discard_btn.text = "분해 (+%d G)" % _forge_salvage_value(selected)


func _forge_toggle_equip() -> void:
	var selected := _forge_selected_item()
	if selected.is_empty():
		return
	var slot := str(selected["slot"])
	var loadout: Dictionary = meta["loadout"]
	if _forge_item_equipped(selected):
		loadout[slot] = {}
	else:
		loadout[slot] = selected.duplicate(true)
	meta["loadout"] = loadout
	Meta.save_data(meta)
	play_sfx("select", -12.0)
	_refresh_forge()


func _forge_upgrade_selected() -> void:
	var selected := _forge_selected_item()
	if selected.is_empty() or _gear_level(selected) >= FORGE_MAX_LEVEL:
		return
	var cost := _forge_upgrade_cost(selected)
	if int(meta.get("gold", 0)) < cost:
		return
	meta["gold"] = int(meta["gold"]) - cost
	selected["lvl"] = _gear_level(selected) + 1
	selected = _normalize_persistent_gear(selected)
	var stash: Array = meta["stash"]
	stash[_forge_sel] = selected
	meta["stash"] = stash
	var slot := str(selected["slot"])
	var loadout: Dictionary = meta["loadout"]
	var current = loadout.get(slot, {})
	if current is Dictionary and _same_gear(current as Dictionary, selected):
		loadout[slot] = selected.duplicate(true)
		meta["loadout"] = loadout
	Meta.save_data(meta)
	play_sfx("levelup", -12.0)
	_refresh_forge()


func _forge_discard_selected() -> void:
	var selected := _forge_selected_item()
	if selected.is_empty():
		return
	var reward := _forge_salvage_value(selected)
	var slot := str(selected["slot"])
	var stash: Array = meta["stash"]
	stash.remove_at(_forge_sel)
	meta["stash"] = stash
	var loadout: Dictionary = meta["loadout"]
	var current = loadout.get(slot, {})
	if current is Dictionary and _same_gear(current as Dictionary, selected):
		loadout[slot] = {}
		meta["loadout"] = loadout
	meta["gold"] = int(meta["gold"]) + reward
	_forge_sel = mini(_forge_sel, stash.size() - 1)
	Meta.save_data(meta)
	play_sfx("coin", -8.0)
	_refresh_forge()


func _toggle_inventory() -> void:
	if inventory_panel == null:
		return
	if inventory_panel.visible:
		inventory_panel.visible = false
		get_tree().paused = false
	elif state == State.PLAYING and not (pause_panel and pause_panel.visible):
		inventory_panel.visible = true
		get_tree().paused = true
		_inv_sel = -1
		_refresh_inventory_screen()
		play_sfx("select", -14.0)


func _refresh_inventory_screen() -> void:
	if inv_equip_box == null:
		return
	_refresh_stat_box()
	if inv_bag_label:
		inv_bag_label.text = "[ 가방 ]  %d개" % inventory.size()
	# 좌: 이번 런 장착 3슬롯
	for c in inv_equip_box.get_children():
		c.queue_free()
	for slot in EQUIP_SLOTS:
		var it: Dictionary = equipped.get(slot, {})
		inv_equip_box.add_child(_gear_equipped_card(it, slot, inv_equip_width))
	# 가운데: 가방 목록
	for c in inv_list_box.get_children():
		c.queue_free()
	if inventory.is_empty():
		var empty := Label.new()
		empty.text = "가방이 비어 있습니다.\n\n엘리트와 보스를 처치해\n새 장비를 획득하세요."
		empty.custom_minimum_size = Vector2(inv_list_item_width, 106)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.62, 0.65, 0.72))
		inv_list_box.add_child(empty)
	else:
		for i in inventory.size():
			var it2: Dictionary = inventory[i]
			var b := Button.new()
			var selected_mark := "▶ " if i == _inv_sel else ""
			var forge_tag := " +%d" % _gear_level(it2) if _gear_level(it2) > 0 else ""
			b.text = "%s[%s] %s%s" % [selected_mark, str(EQUIP_SLOT_NAME.get(str(it2.get("slot", "")), "장비")), str(it2.get("name", "장비")), forge_tag]
			b.custom_minimum_size = Vector2(inv_list_item_width, 40)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_theme_font_size_override("font_size", 12)
			b.modulate = RARITY_COL.get(str(it2.get("rarity", "")), Color.WHITE)
			_style_button(b, "res://assets/ui/button.png", 12.0, 2.0)
			_apply_gear_button_icon(b, it2)
			b.tooltip_text = _gear_detail_text(it2)
			var idx := i
			b.pressed.connect(func() -> void: _select_inv_item(idx))
			inv_list_box.add_child(b)
	# 우: 선택 장비와 현재 장비 비교
	if _inv_sel >= 0 and _inv_sel < inventory.size():
		var sel: Dictionary = inventory[_inv_sel]
		var slot := str(sel["slot"])
		inv_detail_label.text = _gear_compare_text(sel, equipped.get(slot, {})) + "\n\n장착하면 기존 %s는 가방으로 이동합니다." % str(EQUIP_SLOT_NAME[slot])
		inv_equip_btn.disabled = false
		inv_discard_btn.disabled = false
		inv_equip_btn.text = "장착 ▶"
		inv_discard_btn.text = "분해 (+%d G)" % _gear_gold_value(sel)
	else:
		inv_detail_label.text = "가방에서 장비를 선택하세요.\n\n선택한 장비의 어픽스와 현재 장비 대비 변화량을 여기서 확인할 수 있습니다."
		inv_equip_btn.disabled = true
		inv_discard_btn.disabled = true
		inv_equip_btn.text = "장착 ▶"
		inv_discard_btn.text = "분해"


func _select_inv_item(idx: int) -> void:
	_inv_sel = idx
	_refresh_inventory_screen()


func _equip_from_inventory(idx: int) -> void:
	if idx < 0 or idx >= inventory.size():
		return
	var it: Dictionary = inventory[idx]
	var slot := str(it["slot"])
	var old: Dictionary = equipped.get(slot, {})
	equipped[slot] = it
	inventory.remove_at(idx)
	if not old.is_empty():
		inventory.append(old)   # 교체된 장비는 가방으로
	_apply_equipment()
	_inv_sel = -1
	play_sfx("levelup", -12.0)
	_refresh_inventory_screen()


func _discard_inv_item(idx: int) -> void:
	if idx < 0 or idx >= inventory.size():
		return
	run_gold += _gear_gold_value(inventory[idx])
	inventory.remove_at(idx)
	_inv_sel = -1
	play_sfx("hit", -16.0)
	_refresh_inventory_screen()
	_update_ui()


func _build_inventory_ui(s: Vector2, overlay: CanvasLayer) -> void:
	inventory_panel = Control.new()
	inventory_panel.visible = false
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(inventory_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.06, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_panel.add_child(dim)
	var modal := _modal_rect(s)
	var frame := Panel.new()
	frame.position = modal.position
	frame.size = modal.size
	# menu_panel.png의 큰 오너먼트가 내부 3패널 위까지 읽혀 정보가 묻히므로, 여기서는 단정한 금테를 쓴다.
	frame.add_theme_stylebox_override("panel", _hud_style())
	inventory_panel.add_child(frame)
	var ttl := Label.new()
	ttl.text = "🎒 인벤토리"
	ttl.position = Vector2(0, 13)
	ttl.size = Vector2(modal.size.x, 32)
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.add_theme_font_size_override("font_size", 24)
	ttl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	frame.add_child(ttl)
	var sub := Label.new()
	sub.text = "이번 런 장비와 능력치 · 런 종료 시 초기화됩니다"
	sub.position = Vector2(0, 45)
	sub.size = Vector2(modal.size.x, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.67, 0.7, 0.8))
	frame.add_child(sub)

	var inner_x := 18.0
	var inner_w := modal.size.x - inner_x * 2.0
	var content_top := 88.0
	var footer_y := modal.size.y - 61.0
	var content_h := maxf(150.0, footer_y - content_top - 12.0)
	var gap := clampf(modal.size.x * 0.018, 10.0, 18.0)
	var left_w := clampf(inner_w * 0.25, 195.0, 270.0)
	var mid_w := clampf(inner_w * 0.29, 220.0, 340.0)
	var right_w := inner_w - left_w - mid_w - gap * 2.0
	if right_w < 220.0:
		var recover := 220.0 - right_w
		var take_mid := minf(recover, maxf(0.0, mid_w - 190.0))
		mid_w -= take_mid
		recover -= take_mid
		left_w -= minf(recover, maxf(0.0, left_w - 175.0))
		right_w = inner_w - left_w - mid_w - gap * 2.0
	inv_equip_width = maxf(120.0, left_w - 24.0)
	inv_stat_label_width = maxf(84.0, left_w - 68.0)
	inv_list_item_width = maxf(150.0, mid_w - 20.0)

	var left := Panel.new()
	left.position = Vector2(inner_x, content_top)
	left.size = Vector2(left_w, content_h)
	left.add_theme_stylebox_override("panel", _section_style(Color(0.33, 0.63, 0.83, 0.9)))
	frame.add_child(left)
	var lh := Label.new()
	lh.text = "⚔ 장착 장비"
	lh.position = Vector2(12, 10)
	lh.size = Vector2(left_w - 24.0, 22)
	lh.add_theme_font_size_override("font_size", 15)
	lh.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	left.add_child(lh)
	inv_equip_box = HBoxContainer.new()
	inv_equip_box.position = Vector2(12, 40)
	inv_equip_box.size = Vector2(left_w - 24.0, 84)
	inv_equip_box.add_theme_constant_override("separation", 4)
	left.add_child(inv_equip_box)
	var stat_y := 142.0 if content_h >= 355.0 else maxf(132.0, content_h - 164.0)
	var sh := Label.new()
	sh.text = "✦ 능력치 분배"
	sh.position = Vector2(12, stat_y)
	sh.size = Vector2(left_w - 24.0, 22)
	sh.add_theme_font_size_override("font_size", 15)
	sh.add_theme_color_override("font_color", Color(1.0, 0.68, 0.84))
	left.add_child(sh)
	inv_stat_box = VBoxContainer.new()
	inv_stat_box.position = Vector2(12, stat_y + 28.0)
	inv_stat_box.size = Vector2(left_w - 24.0, maxf(100.0, content_h - stat_y - 36.0))
	inv_stat_box.add_theme_constant_override("separation", 4)
	left.add_child(inv_stat_box)

	var mid := Panel.new()
	mid.position = Vector2(inner_x + left_w + gap, content_top)
	mid.size = Vector2(mid_w, content_h)
	mid.add_theme_stylebox_override("panel", _section_style(Color(0.72, 0.56, 0.28, 0.9)))
	frame.add_child(mid)
	inv_bag_label = Label.new()
	inv_bag_label.position = Vector2(12, 10)
	inv_bag_label.size = Vector2(mid_w - 24.0, 22)
	inv_bag_label.add_theme_font_size_override("font_size", 15)
	inv_bag_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	mid.add_child(inv_bag_label)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 42)
	scroll.size = Vector2(mid_w - 16.0, content_h - 50.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	inv_list_box = VBoxContainer.new()
	inv_list_box.add_theme_constant_override("separation", 4)
	scroll.add_child(inv_list_box)

	var right := Panel.new()
	right.position = Vector2(inner_x + left_w + gap + mid_w + gap, content_top)
	right.size = Vector2(right_w, content_h)
	right.add_theme_stylebox_override("panel", _section_style(Color(0.78, 0.48, 0.65, 0.9)))
	frame.add_child(right)
	var dh := Label.new()
	dh.text = "◇ 선택 장비 · 비교"
	dh.position = Vector2(12, 10)
	dh.size = Vector2(right_w - 24.0, 22)
	dh.add_theme_font_size_override("font_size", 15)
	dh.add_theme_color_override("font_color", Color(1.0, 0.72, 0.86))
	right.add_child(dh)
	inv_detail_label = RichTextLabel.new()
	inv_detail_label.position = Vector2(12, 42)
	inv_detail_label.size = Vector2(right_w - 24.0, content_h - 54.0)
	inv_detail_label.bbcode_enabled = true
	inv_detail_label.scroll_active = false
	inv_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inv_detail_label.add_theme_font_size_override("normal_font_size", 13)
	inv_detail_label.add_theme_color_override("default_color", Color(0.92, 0.94, 0.98))
	right.add_child(inv_detail_label)

	var close_btn := Button.new()
	close_btn.text = "닫기 (I / ESC)"
	close_btn.position = Vector2(18, footer_y + 6.0)
	close_btn.size = Vector2(162, 44)
	_style_button(close_btn, "res://assets/ui/button.png")
	close_btn.pressed.connect(_toggle_inventory)
	frame.add_child(close_btn)
	inv_equip_btn = Button.new()
	inv_equip_btn.text = "장착 ▶"
	inv_equip_btn.position = Vector2(modal.size.x - 18.0 - 168.0 - 10.0 - 148.0, footer_y + 6.0)
	inv_equip_btn.size = Vector2(148, 44)
	_style_button(inv_equip_btn, "res://assets/ui/button.png")
	inv_equip_btn.pressed.connect(func() -> void: _equip_from_inventory(_inv_sel))
	frame.add_child(inv_equip_btn)
	inv_discard_btn = Button.new()
	inv_discard_btn.text = "분해 (+골드)"
	inv_discard_btn.position = Vector2(modal.size.x - 18.0 - 168.0, footer_y + 6.0)
	inv_discard_btn.size = Vector2(168, 44)
	_style_button(inv_discard_btn, "res://assets/ui/button.png")
	inv_discard_btn.pressed.connect(func() -> void: _discard_inv_item(_inv_sel))
	frame.add_child(inv_discard_btn)


func _populate_levelup() -> void:
	_fill_lvl_inv()
	_fill_lvl_stats()
	var picks: Array = _pick3(_card_options())
	_cur_picks = picks
	var top_rarity := ""   # 이번 판 카드 중 최고 등급 (등장 연출용)
	for i in 3:
		var c: Dictionary = picks[i]
		# 카드 등급 뽑기 (뽑기운!): 보유 강화 카드에만 굴림. 신규·조합은 자체 등급 유지.
		# 럭 스탯이 높을수록 상위 등급 확률↑. epic/legendary는 강화 레벨을 추가로 얹는다.
		if bool(c.get("owned", false)):
			var rr := _roll_rarity()
			c["r"] = rr
			c["rbonus"] = {"legendary": 2, "epic": 1}.get(rr, 0)
			if rr == "legendary" or rr == "epic":
				c["title"] = "%s %s" % ["★레전더리★" if rr == "legendary" else "◆에픽◆", str(c["title"])]
		if RARITY_ORDER.get(str(c.get("r", "")), 0) > RARITY_ORDER.get(top_rarity, 0):
			top_rarity = str(c["r"])
		# 뱀서식 행: 이름·레벨(윗줄) + 설명(아랫줄). 아이콘은 왼쪽.
		cards[i].text = "%s\n%s" % [c["title"], c["desc"]]
		cards[i].icon = Assets.tex(c.get("icon", ""))
		if i < _card_badges.size():
			_card_badges[i].visible = bool(c.get("new", false))
		var rcol: Color = RARITY_COL.get(str(c["r"]), Color.WHITE)
		cards[i].add_theme_color_override("font_color", rcol)
		cards[i].add_theme_color_override("font_hover_color", rcol.lightened(0.2))
		cards[i].add_theme_color_override("font_focus_color", rcol.lightened(0.2))
		for con in cards[i].pressed.get_connections():
			cards[i].pressed.disconnect(con["callable"])
		var idx := i
		cards[i].pressed.connect(func() -> void: _card_clicked(idx))
	# 상위 등급 등장 연출 (뽑기 잭팟): 화면 섬광 + 팡파레
	if top_rarity == "legendary":
		_flash(Color(1.0, 0.85, 0.4, 0.5))
		play_sfx("ult", -6.0, 0.05)
	elif top_rarity == "epic":
		_flash(Color(0.82, 0.55, 1.0, 0.34))
		play_sfx("levelup", -8.0)


# 레벨업 좌측 스탯 패널 채우기 (뱀서식 능력치 목록). 미변동 스탯은 "-".
func _fill_lvl_stats() -> void:
	if lvl_stats_box != null and player != null:
		_fill_stats_grid(lvl_stats_box)


# 스탯 아이콘 그리드 채우기 (레벨업·일시정지 공용)
func _fill_stats_grid(box: GridContainer) -> void:
	if box == null or player == null:
		return
	for ch in box.get_children():
		ch.queue_free()
	var II := "res://assets/items/"
	var haste: int = int(round((1.0 - player.cooldown_mult) * 100.0))
	var crit: int = int(round(player.crit_chance * 100.0))
	_stat_row(box, II + "icon_voidheart.png", "최대 체력", "%d" % int(player.max_hp))
	_stat_row(box, II + "icon_vitality.png", "재생", "-" if player.regen <= 0.0 else "%.1f" % player.regen)
	_stat_row(box, II + "icon_armor.png", "방어", "-" if player.armor <= 0.0 else str(int(player.armor)))
	_stat_row(box, II + "icon_wings.png", "이동속도", _stat_pct(player.speed / 125.0))
	_stat_row(box, II + "icon_spinach.png", "위력", _stat_pct(player.damage_mult))
	_stat_row(box, II + "icon_candela.png", "범위", _stat_pct(player.area_mult))
	_stat_row(box, II + "icon_clone.png", "추가 발사", "-" if player.amount <= 0 else "+%d" % player.amount)
	_stat_row(box, II + "icon_tome.png", "쿨감", "-" if haste == 0 else "+%d%%" % haste)
	_stat_row(box, II + "icon_keeneye.png", "치명", "-" if crit == 0 else "%d%%" % crit)
	_stat_row(box, II + "icon_crown.png", "성장", _stat_pct(xp_mult))
	_stat_row(box, II + "coin.png", "탐욕", _stat_pct(greed_mult))
	_stat_row(box, II + "magnet.png", "자석", "%d" % int(player.pickup_radius))
	if run_pressure_mult > 1.0:
		_stat_row(box, II + "icon_skull.png", "위협", _stat_pct(run_pressure_mult))


# 스탯 한 줄(아이콘·이름·값)을 그리드에 추가 (뱀서식 스탯 패널)
func _stat_row(box: GridContainer, icon_path: String, sname: String, value: String) -> void:
	var tr := TextureRect.new()
	tr.texture = Assets.tex(icon_path)
	tr.custom_minimum_size = Vector2(18, 18)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tr)
	var nl := Label.new()
	nl.text = sname
	nl.custom_minimum_size = Vector2(112, 0)
	nl.add_theme_font_size_override("font_size", 14)
	nl.add_theme_constant_override("outline_size", 3)
	nl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	nl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(nl)
	var vl := Label.new()
	vl.text = value
	vl.add_theme_font_size_override("font_size", 14)
	vl.add_theme_constant_override("outline_size", 3)
	vl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	vl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62) if value == "-" else Color(1.0, 0.9, 0.55))
	vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vl)


# 배수(기준 1.0) → "+X%" / 변동 없으면 "-"
func _stat_pct(mult: float) -> String:
	var p: int = int(round((mult - 1.0) * 100.0))
	return "-" if p == 0 else "%+d%%" % p


# 레벨업 상단: 보유 무기·패시브·유니온 아이콘 줄 (뱀서식)
func _fill_lvl_inv() -> void:
	if lvl_inv == null:
		return
	for ch in lvl_inv.get_children():
		ch.queue_free()
	for kind in weapons.keys():
		_lvl_inv_icon(WICON.get(kind, ""), evolved.get(kind, false))
	for u in unions.keys():
		var ud := UNION_DEFS.filter(func(x): return x["key"] == u)
		if ud.size() > 0:
			_lvl_inv_icon(ud[0].get("icon", ""), true)
	for pkey in passives.keys():
		_lvl_inv_icon(PICON.get(pkey, ""), false)


# 일시정지: 무기·패시브 아이콘 슬롯 채우기 (뱀서식 인벤토리 그리드)
func _fill_pause_icons() -> void:
	if pause_weap_box:
		for ch in pause_weap_box.get_children():
			ch.queue_free()
		for k in weapons.keys():
			var wlv: int = weapons[k]
			var wtip := "%s Lv%d\n%s" % [WNAMES.get(k, k), wlv, _weapon_lv_desc(k, mini(wlv + 1, MAX_WLEVEL))]
			if wlv >= MAX_WLEVEL and not evolved.get(k, false):
				var h := _evo_hint(k)
				if h != "": wtip = "%s Lv%d\n%s" % [WNAMES.get(k, k), wlv, h]
			_pause_slot(pause_weap_box, WICON.get(k, ""), wlv, evolved.get(k, false), 8, wtip)
		for u in unions.keys():
			var ud := UNION_DEFS.filter(func(x): return x["key"] == u)
			if ud.size() > 0:
				_pause_slot(pause_weap_box, ud[0].get("icon", ""), 8, true, 8, "%s (유니온)" % ud[0].get("name", u))
	if pause_pass_box:
		for ch in pause_pass_box.get_children():
			ch.queue_free()
		var pdefs := _passive_defs()
		for k in passives.keys():
			var pd: Dictionary = pdefs.get(k, {})
			var ptip := "%s Lv%d\n%s" % [pd.get("name", k), passives[k], pd.get("desc", "")]
			_pause_slot(pause_pass_box, PICON.get(k, ""), passives[k], false, MAX_PLEVEL, ptip)
	# 유물 「은하 지도」: 해금 시 일시정지에 플레이어·남은 아이템 미니맵 표시.
	var show_map := _has_relic("milky_map") and stage_layout != null
	if pause_map_rect:
		pause_map_rect.visible = show_map
		if show_map:
			pause_map_rect.texture = _build_minimap_texture()
	if pause_map_title:
		pause_map_title.visible = show_map


# 「은하 지도」용 미니맵 텍스처. 보행 실루엣 + 플레이어(초록) + 남은 픽업(노랑) + 유물/랜드마크(청록).
func _build_minimap_texture() -> Texture2D:
	var size := 145
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.05, 0.08, 1.0))
	var sc := float(size) / WORLD.x
	# 보행 영역 실루엣
	for py in size:
		for px in size:
			var wp := Vector2(px / sc, py / sc)
			if stage_layout.is_walkable(wp, 0.0):
				img.set_pixel(px, py, Color(0.24, 0.28, 0.24, 1.0))
	# 남은 필드 아이템·유물 (노랑), 파괴물 상자 (주황)
	for node in get_tree().get_nodes_in_group("pickups"):
		if is_instance_valid(node):
			_minimap_dot(img, node.position * sc, Color(1.0, 0.86, 0.3), 2)
	if stage_layout.relic_position != Vector2.ZERO:
		_minimap_dot(img, stage_layout.relic_position * sc, Color(0.5, 0.95, 1.0), 3)
	_minimap_dot(img, stage_layout.landmark_position * sc, Color(0.8, 0.6, 1.0), 2)
	# 플레이어 (초록, 크게)
	if player:
		_minimap_dot(img, player.position * sc, Color(0.3, 1.0, 0.4), 3)
	return ImageTexture.create_from_image(img)


func _minimap_dot(img: Image, p: Vector2, col: Color, r: int) -> void:
	var cx := int(p.x)
	var cy := int(p.y)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r * r:
				continue
			var x := cx + dx
			var y := cy + dy
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				img.set_pixel(x, y, col)


func _pause_slot(box: HBoxContainer, path: String, lv: int, glow: bool, max_pips: int = 8, tip: String = "") -> void:
	var t: Texture2D = Assets.tex(path)
	if t == null:
		return
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	var tr := TextureRect.new()
	tr.texture = t
	if tip != "":
		tr.tooltip_text = tip   # 네이티브 호버 툴팁: 현재 스탯 + 다음 진화 조건
	tr.custom_minimum_size = Vector2(46, 46)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if glow:
		tr.modulate = Color(1.3, 1.2, 0.7)
	vb.add_child(tr)
	# 진화/유니온이면 ★ 라벨, 아니면 뱀서식 핍(칸) 채우기
	if glow:
		var lb := Label.new()
		lb.text = "★"
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 12)
		lb.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
		vb.add_child(lb)
	else:
		var pips := _level_pips(lv, max_pips)
		pips.custom_minimum_size = Vector2(46, 5)
		vb.add_child(pips)
	box.add_child(vb)


func _lvl_inv_icon(path: String, glow: bool) -> void:
	var t: Texture2D = Assets.tex(path)
	if t == null:
		return
	var tr := TextureRect.new()
	tr.texture = t
	tr.custom_minimum_size = Vector2(34, 34)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if glow:
		tr.modulate = Color(1.3, 1.2, 0.7)   # 진화/유니온 강조
	lvl_inv.add_child(tr)


func _card_clicked(i: int) -> void:
	if i < 0 or i >= _cur_picks.size():
		return
	# 밴 모드: 선택 대신 해당 항목을 이번 판 풀에서 제거
	if _banish_mode and run_banishes > 0:
		run_banishes -= 1
		banished[str(_cur_picks[i].get("title", ""))] = true
		_banish_mode = false
		play_sfx("select", -12.0)
		_populate_levelup()
		_update_levelup_buttons()
		return
	_choose_card(_cur_picks[i])


func _do_reroll() -> void:
	if run_rerolls <= 0:
		return
	run_rerolls -= 1
	_banish_mode = false
	play_sfx("select", -12.0)
	_populate_levelup()
	_update_levelup_buttons()


func _toggle_banish() -> void:
	if run_banishes <= 0 and not _banish_mode:
		return
	_banish_mode = not _banish_mode
	_update_levelup_buttons()


# 스킵: 카드를 고르지 않고 넘김 + 소량 회복 (뱀서식)
func _do_skip() -> void:
	if run_skips <= 0:
		return
	run_skips -= 1
	_banish_mode = false
	play_sfx("select", -12.0)
	if player:
		player.hp = min(player.max_hp, player.hp + player.max_hp * 0.10)
	levelup_panel.visible = false
	pending_levelups -= 1
	if pending_levelups > 0:
		_start_levelup()
	else:
		state = State.PLAYING
		get_tree().paused = false
	_update_ui()


func _update_levelup_buttons() -> void:
	if reroll_btn:
		reroll_btn.text = "↻ 리롤 (%d)" % run_rerolls
		reroll_btn.disabled = run_rerolls <= 0
	if banish_btn:
		banish_btn.text = "✖ 밴 취소" if _banish_mode else "✖ 밴 (%d)" % run_banishes
		banish_btn.disabled = run_banishes <= 0 and not _banish_mode
		banish_btn.modulate = Color(1.0, 0.6, 0.6) if _banish_mode else Color.WHITE
	if skip_btn:
		skip_btn.text = "» 스킵 (%d)" % run_skips
		skip_btn.disabled = run_skips <= 0


func _choose_card(c: Dictionary) -> void:
	play_sfx("select", -10.0)
	(c["act"] as Callable).call()
	# 카드 등급 보너스: epic +1 · legendary +2 추가 강화 (뽑기 잭팟 — 같은 강화를 더 얹음)
	var rbonus := int(c.get("rbonus", 0))
	if rbonus > 0:
		for _b in rbonus:
			(c["act"] as Callable).call()
		_flash(RARITY_COL.get(str(c.get("r", "")), Color(1, 1, 1)))
		play_sfx("ult", -10.0, 0.05)
	_refresh_inventory_ui()
	levelup_panel.visible = false
	pending_levelups -= 1
	if pending_levelups > 0:
		_start_levelup()
	else:
		state = State.PLAYING
		get_tree().paused = false
	_update_ui()


# 무기 레벨 시간 소프트캡 (사장님 요청): 한 무기에 픽을 몰아도 Lv8을
# 10분(진화 해금)쯤에야 찍도록 경과 시간으로 상한을 건다. 픽업/신규 무기·패시브는 무관.
#   t=0    → Lv2 (첫 강화는 바로)
#   +99초당 +1  → Lv8은 약 t=594s(9.9분)에 해금 (EVO_START_TIME=600과 정렬)
func _weapon_time_cap() -> int:
	return clampi(2 + int(time_survived / 99.0), 2, MAX_WLEVEL)


func _card_options() -> Array:
	var opts: Array = []

	# (진화는 레벨업 카드가 아니라 보스 상자 개봉 시 발동 — _try_evolve_from_chest)

	# (조합은 유니온으로 대체 — 레벨업 카드가 아니라 두 무기 만렙 후 보스 상자에서 합체)

	# 2) 무기 레벨업 / 신규
	var wcap := _weapon_time_cap()   # 무기 레벨 시간 소프트캡 (10분에 Lv8)
	for kind in ALL_WEAPONS:
		if weapons.has(kind):
			var lv: int = weapons[kind]
			if lv < MAX_WLEVEL and lv + 1 <= wcap:
				var k1: String = kind
				# 무기별 레벨업 명세 (뱀서식: 이 레벨에 실제 오르는 능력)
				var udesc := _weapon_lv_desc(kind, lv + 1)
				# MAX 도달 강화면 진화 조건을 우선 안내
				if lv + 1 >= MAX_WLEVEL:
					var h := _evo_hint(kind)
					if h != "":
						udesc = h
				opts.append({"r": "rare", "t": "w", "key": kind, "owned": true, "title": "%s Lv%d" % [WNAMES[kind], lv + 1],
					"desc": udesc, "icon": WICON.get(kind, ""),
					"act": func() -> void: _upgrade_weapon(k1)})
		elif weapons.size() < MAX_WEAPONS:
			if not (kind in POOL_WEAPONS):
				continue   # 뱀서식 핵심 20종만 신규 카드로 제안 (겹치는 무기 제거)
			if UNLOCK_WEAPONS.has(kind) and not meta.get("ach", {}).get(UNLOCK_WEAPONS[kind], false):
				continue   # 해금 무기 — 해당 업적 달성 필요
			# 빌드 강제: 무기 4개 이상 보유 시 새 무기는 25% 확률로만 제시
			if weapons.size() >= FREE_WEAPON_SLOTS and randf() > 0.25:
				continue
			var k2: String = kind
			opts.append({"r": "rare", "t": "w", "key": kind, "new": true, "title": "[신규 무기] " + WNAMES[kind],
				"desc": _weapon_desc(kind), "icon": WICON.get(kind, ""),
				"act": func() -> void: _add_weapon(k2)})

	# 3) 패시브 아이템 레벨업 / 신규
	var pdefs := _passive_defs()
	for pkey in pdefs.keys():
		var pd: Dictionary = pdefs[pkey]
		var evo_weapon: String = _evo_weapon_for_passive(pkey)
		var evo_match: bool = evo_weapon != ""
		var evo_desc: String = "\n[%s 진화 재료]" % WNAMES.get(evo_weapon, evo_weapon) if evo_match else ""
		if passives.has(pkey):
			if passives[pkey] < MAX_PLEVEL:
				var pk1: String = pkey
				opts.append({"r": "common", "t": "p", "key": pkey, "owned": true, "evo_match": evo_match,
					"title": "%s Lv%d" % [pd["name"], passives[pkey] + 1],
					"desc": pd["desc"] + evo_desc, "icon": PICON.get(pkey, ""),
					"act": func() -> void: _add_passive(pk1)})
		elif passives.size() < MAX_PASSIVES:
			var pk2: String = pkey
			opts.append({"r": "common", "t": "p", "key": pkey, "new": true, "evo_match": evo_match,
				"title": ("[진화 재료] " if evo_match else "[신규] ") + pd["name"],
				"desc": pd["desc"] + evo_desc, "icon": PICON.get(pkey, ""),
				"act": func() -> void: _add_passive(pk2)})

	# 이번 판 밴된 카드 제외 (3장 이상 남을 때만)
	if banished.size() > 0:
		var filtered: Array = []
		for o in opts:
			if not banished.has(str(o.get("title", ""))):
				filtered.append(o)
		if filtered.size() >= 3:
			opts = filtered
	# 옵션 부족 시(모두 만렙) → 리밋 브레이크: 무한 영구 강화 카드 (뱀서 Limit Break)
	var lb_used := {}
	while opts.size() < 3:
		var lb := _limit_break_card(lb_used)
		lb_used[lb["title"]] = true
		opts.append(lb)
	return opts


# 리밋 브레이크 카드 풀 (중복 회피). 모든 성장 소진 후 레벨업이 낭비되지 않게.
func _limit_break_card(used: Dictionary) -> Dictionary:
	var pool := [
		{"title": "⟡ 리밋: 힘", "desc": "공격력 +6%", "icon": "res://assets/items/icon_spinach.png",
			"act": func() -> void: player.damage_mult += 0.06},
		{"title": "⟡ 리밋: 신속", "desc": "쿨다운 -4%", "icon": "res://assets/items/icon_tome.png",
			"act": func() -> void: player.cooldown_mult = max(0.3, player.cooldown_mult * 0.96)},
		{"title": "⟡ 리밋: 확장", "desc": "효과 범위 +8%", "icon": "res://assets/items/icon_candela.png",
			"act": func() -> void: player.area_mult += 0.08},
		{"title": "⟡ 리밋: 활력", "desc": "최대체력 +25 · 회복", "icon": "res://assets/items/icon_voidheart.png",
			"act": func() -> void: _p_hp()},
		{"title": "⟡ 리밋: 예리", "desc": "치명타 확률 +4%", "icon": "res://assets/items/icon_keeneye.png",
			"act": func() -> void: player.crit_chance += 0.04},
		{"title": "⟡ 리밋: 재생", "desc": "재생 +0.5/초", "icon": "res://assets/items/icon_tomato.png",
			"act": func() -> void: player.regen += 0.5},
	]
	pool.shuffle()
	for c in pool:
		if not used.has(c["title"]):
			c["r"] = "rare"
			return c
	# 다 쓰면 힘 반복
	return {"r": "rare", "title": "⟡ 리밋: 힘", "desc": "공격력 +6%",
		"icon": "res://assets/items/icon_spinach.png",
		"act": func() -> void: player.damage_mult += 0.06}


func _passive_defs() -> Dictionary:
	return {
		"spinach": {"name": "시금치", "desc": "공격력 +10%"},
		"armor": {"name": "갑옷", "desc": "방어력 +1"},
		"wings": {"name": "날개", "desc": "이동속도 +10%"},
		"tome": {"name": "빈 마도서", "desc": "쿨다운 -8%"},
		"candela": {"name": "촛대", "desc": "범위 +12%"},
		"heart": {"name": "공허의 심장", "desc": "최대체력 +25"},
		"magnet": {"name": "자석돌", "desc": "자석 범위 +25"},
		"tomato": {"name": "토마토", "desc": "재생 +0.8/초"},
		"duplicator": {"name": "복제의 룬", "desc": "투사체 +1 (뱀서 핵심)"},
		"spellbinder": {"name": "봉인의 서", "desc": "효과 범위 +12%"},
		"crown": {"name": "왕관", "desc": "경험치 획득 +8%"},
		"stone_mask": {"name": "돌가면", "desc": "골드 획득 +12%"},
		"clover": {"name": "네잎클로버", "desc": "행운 +10% (전리품·상자)"},
		"keen_eye": {"name": "매의 눈", "desc": "치명타 확률 +6%"},
		"berserker": {"name": "광전사의 인장", "desc": "치명타 피해 +30%"},
		"vitality": {"name": "생명력", "desc": "최대체력 +12%"},
		"iron_will": {"name": "강철의지", "desc": "방어력 +1 · 재생 +0.4/초"},
		"swiftness": {"name": "표범의 발", "desc": "이동속도 +8% · 자석범위 +15"},
		"skull": {"name": "[저주] 해골", "desc": "저주 +12% (적 강화 · 경험치·골드 증가)"},
	}


func _add_passive(key: String) -> void:
	passives[key] = passives.get(key, 0) + 1
	match key:
		"spinach":
			player.damage_mult += 0.10
		"armor":
			player.armor += 1.0
		"wings":
			player.speed *= 1.10
		"tome":
			player.cooldown_mult = max(0.4, player.cooldown_mult * 0.92)
		"candela":
			player.area_mult += 0.12
		"heart":
			player.max_hp += 25.0
			player.hp += 25.0
		"magnet":
			player.pickup_radius += 25.0
		"tomato":
			player.regen += 0.8
		"duplicator":
			player.amount += 1
		"spellbinder":
			player.area_mult += 0.12
		"crown":
			xp_mult += 0.08
		"stone_mask":
			greed_mult += 0.12
		"clover":
			diff_loot += 0.10
		"keen_eye":
			player.crit_chance += 0.06
		"berserker":
			player.crit_mult += 0.30
		"vitality":
			var add := player.max_hp * 0.12
			player.max_hp += add
			player.hp += add
		"iron_will":
			player.armor += 1.0
			player.regen += 0.4
		"swiftness":
			player.speed *= 1.08
			player.pickup_radius += 15.0
		"skull":
			run_pressure_mult += 0.12


# 진화 조건 안내 문구
func _evo_hint(kind: String) -> String:
	if EVO_RECIPE.has(kind):
		var pn: String = _passive_defs().get(EVO_RECIPE[kind]["passive"], {}).get("name", "")
		return "Lv%d 만렙 + [%s] → 10:00 이후 보스 상자에서 진화!" % [MAX_WLEVEL, pn]
	return ""


# 현재 보유한 미진화 무기 중 이 패시브를 진화 재료로 쓰는 무기.
func _evo_weapon_for_passive(pkey: String) -> String:
	for kind in weapons.keys():
		if EVO_RECIPE.has(kind) and not evolved.get(kind, false):
			if str(EVO_RECIPE[kind]["passive"]) == pkey:
				return str(kind)
	return ""


# 무기별 성장 명세 (뱀서식): 각 무기가 레벨업으로 실제 강해지는 축을 표기.
# 짝수 성장 무기는 해당 레벨에 "투사체 +1"을 강조, 그 외 레벨은 무기별 성장 문구.
const WGROW := {
	"arrow": "투사체 +1 · 관통 증가", "knife": "투사체 +1 · 사거리",
	"aura": "범위 확장 · 지속피해↑", "lightning": "낙뢰 대상 +1 · 피해↑",
	"spread_shot": "탄 수 증가 · 피해↑", "cleave": "범위 확장 · 피해↑",
	"blade": "회전검 +1 · 궤도 확대", "whip": "타격 폭 확대 · 피해↑",
	"frost": "범위 확장 · 둔화 강화", "holy": "심판 낙뢰 +1 · 피해↑",
	"fireball": "투사체 +1 · 폭발 범위↑", "boomerang": "투사체 +1 · 관통",
	"axe": "투사체 +1 · 관통 증가", "crossbow": "볼트 +1 · 관통 강화",
	"blood_sword": "피해량↑↑ · 흡혈율↑", "chakram": "튕김 +1 · 피해↑",
	"frost_ring": "유도 서리탄 +1 · 둔화↑", "homing_skull": "유도탄 +1 · 관통",
	"moonlight": "낙하 수 +1 · 범위↑", "holy_cross": "유도 성탄 +1 · 관통",
	"soul_bolt": "동시 조준 +1 · 관통", "holy_beam": "빛기둥 확대 · 관통",
	"bone_spiral": "유도 뼈탄 +1 · 관통", "ice_lance": "창 수 +1 · 둔화↑",
	"venom": "투사체 +1 · 중독 강화", "spear": "관통 · 낙뢰 강화",
	"thorn_burst": "유도 가시탄 +1 · 관통",
	"poison_cloud": "구름 범위↑ · 중첩 한계↑",
}
func _weapon_lv_desc(kind: String, _next_lv: int) -> String:
	return WGROW.get(kind, "피해 증가 · 쿨타임 감소")


# 보스 상자 개봉 시: 만렙+필수패시브 충족한 무기를 진화시킴 (하나)
func _ready_evolution_kind() -> String:
	for kind in EVO_RECIPE.keys():
		if weapons.get(kind, 0) >= MAX_WLEVEL and not evolved.get(kind, false):
			if passives.get(EVO_RECIPE[kind]["passive"], 0) >= 1:
				return str(kind)
	return ""


func _can_evolve_from_chest() -> bool:
	return (abyss_mode or time_survived >= EVO_START_TIME) and _ready_evolution_kind() != ""


func _try_evolve_from_chest() -> bool:
	# VS 기본 규칙에 맞춰 첫 진화는 10분 이후 상자부터 허용한다.
	# 그 전에 조건을 완성했다면 상자는 일반 성장 보상을 주고 준비 완료를 안내한다.
	if not abyss_mode and time_survived < EVO_START_TIME:
		if _ready_evolution_kind() != "":
			_event_banner("★ 진화 준비 완료 — 10:00 이후 보스 상자를 노려라!")
		return false
	var kind := _ready_evolution_kind()
	if kind == "":
		return false
	_evolve(kind)
	if stage_label:
		stage_label.text = "★진화★ %s!" % EVO_RECIPE[kind]["name"]
		stage_label.visible = true
	stage_banner_t = 2.6
	play_sfx("levelup", -4.0)
	shake_t = max(shake_t, 0.2)
	spawn_fx("fx_divine", player.position, 300.0)
	_grant_ach("legend_weapon")
	_flash(Color(1.0, 1.0, 0.95, 0.62))   # 진화 화이트 플래시
	_show_chest_roulette(WICON.get(kind, ""), "★ 무기 진화 ★", EVO_RECIPE[kind]["name"])
	return true


# 보스 상자: 두 재료 무기가 모두 만렙이면 유니온(합체 신규 무기) 발동
func _try_union_from_chest() -> bool:
	for u in UNION_DEFS:
		if unions.has(u["key"]):
			continue
		if weapons.get(u["a"], 0) >= MAX_WLEVEL and weapons.get(u["b"], 0) >= MAX_WLEVEL:
			unions[u["key"]] = true
			meta.get_or_add("union_seen", {})[u["key"]] = true
			Meta.save_data(meta)
			wtimer[u["key"]] = 0.0   # 발사 루프에 등록
			if stage_label:
				stage_label.text = "★유니온★ %s!" % u["name"]
				stage_label.visible = true
			stage_banner_t = 2.6
			play_sfx("levelup", -4.0)
			shake_t = max(shake_t, 0.2)
			spawn_fx("fx_divine", player.position, 320.0)
			_grant_ach("legend_weapon")
			_flash(Color(0.75, 0.9, 1.0, 0.62))   # 유니온 블루 플래시
			_show_chest_roulette(u.get("icon", ""), "★ 유니온 합체 ★", u["name"])
			return true
	return false


func _evolve(kind: String) -> void:
	evolved[kind] = true
	meta.get_or_add("evo_known", {})[kind] = true
	meta.get_or_add("evo_seen", {})[kind] = true
	Meta.save_data(meta)

func _add_combo(key: String) -> void:
	combos[key] = true


func _weapon_desc(kind: String) -> String:
	match kind:
		"arrow":
			return "가장 가까운 적에게 자동 발사"
		"blade":
			return "주위를 도는 검으로 접촉 피해"
		"aura":
			return "주변 적에게 지속 피해"
		"lightning":
			return "무작위 적에게 번개 강타"
		"frost":
			return "광역 서리 폭발 + 둔화"
		"knife":
			return "[해금 무기] 빠른 연사 투척 칼"
		"fireball":
			return "착탄 시 폭발하는 화염구 (광역)"
		"boomerang":
			return "회전하며 적을 관통하는 부메랑"
		"holy":
			return "적 머리 위로 신성한 빛 강타"
		"venom":
			return "맹독 단검 · 둔화 + 착탄 독무"
		"whip":
			return "바라보는 방향 전방 광역 채찍질"
		"chakram":
			return "사방으로 회전 날붙이를 방사 (관통)"
		"spear":
			return "가까운 적을 꿰뚫는 강력한 관통 창"
		"starfall":
			return "무작위 적 위로 유성 낙하 (광역)"
		"flamethrower":
			return "전방에 근거리 불꽃을 부채꼴로 분사"
		"ice_lance":
			return "가까운 적을 관통하는 서리창 + 둔화"
		"crossbow":
			return "강력한 단발 대관통 볼트 (고화력)"
		"holy_cross":
			return "사방으로 성스러운 십자 탄 발사"
		"poison_cloud":
			return "독구름 장판 — 안에 오래 머물수록 중첩되어 아파짐"
		"quake":
			return "주변을 대지 강타로 연쇄 (광역+흔들림)"
		"spread_shot":
			return "전방으로 넓게 퍼지는 관통 산탄"
		"soul_bolt":
			return "가까운 여러 적에게 유령탄 동시 조준"
		"holy_beam":
			return "상하로 뻗는 긴 관통 빛기둥 (라인 청소)"
		"bone_spiral":
			return "각도를 돌려 뿌리는 나선형 뼈탄"
		"moonlight":
			return "화면 전역에 달빛 폭격 낙하 (광역 소탕)"
		"axe":
			return "위로 던져 포물선으로 떨어지는 고화력 도끼"
		"homing_skull":
			return "적을 끝까지 쫓는 유도 해골탄"
		"thorn_burst":
			return "주위로 가시를 사방 분출 (근접 링)"
		"chain_bolt":
			return "가까운 여러 적에게 순차 벼락"
		"frost_ring":
			return "사방으로 퍼지는 둔화 서리탄 링"
		"blood_sword":
			return "넓게 베어 피해의 일부를 체력으로 회복 (레벨↑ = 화력·흡혈↑)"
		"cleave":
			return "전방을 반투명 검기로 부채꼴 베기 (근접)"
		"excalibur":
			return "[해금] 관통하는 거대 신성 검격 + 폭발"
		"void_orb":
			return "[해금] 적을 빨아들이는 블랙홀 (지속 피해)"
		_:
			return ""


func _upgrade_weapon(k: String) -> void:
	weapons[k] = weapons.get(k, 1) + 1

func _add_weapon(k: String) -> void:
	weapons[k] = 1
	if k in TIMED_WEAPONS:
		wtimer[k] = 0.0
	# 한 번이라도 획득한 무기의 레시피는 이후 도감에서 재료까지 공개한다.
	if EVO_RECIPE.has(k) and not meta.get("evo_known", {}).get(k, false):
		meta.get_or_add("evo_known", {})[k] = true
		# 자동 캡처·회귀 검사는 실제 사용자 세이브를 절대 변경하지 않는다.
		if not "--autoshot" in OS.get_cmdline_user_args():
			Meta.save_data(meta)

func _p_hp() -> void:
	player.max_hp += 25.0
	player.hp += 25.0


func _pick3(opts: Array) -> Array:
	var copy := opts.duplicate()
	var picks: Array = []
	# 전설(진화/조합) 카드가 있으면 1장 보장
	var legends: Array = []
	for o in copy:
		if o["r"] == "legend":
			legends.append(o)
	if legends.size() > 0:
		var ce: Dictionary = legends[randi() % legends.size()]
		picks.append(ce)
		copy.erase(ce)
	# 넓은 카드 풀에서도 플레이어가 선택한 빌드를 집중 성장시킬 수 있도록
	# 보유 무기 강화 1장을 선택지에 보장한다. 선택 자체는 여전히 플레이어 몫이다.
	if picks.size() < 3:
		var owned_weapon_opts: Array = []
		for o in copy:
			if o.get("owned", false) and o.get("t", "") != "p":
				owned_weapon_opts.append(o)
		if not owned_weapon_opts.is_empty():
			var wu: Dictionary = _weighted_choice(owned_weapon_opts)
			picks.append(wu)
			copy.erase(wu)
	# 패시브 1장 보장. 보유 무기의 진화 재료가 있으면 그 후보를 우선한다.
	if picks.size() < 3:
		var passive_opts: Array = []
		var evo_passive_opts: Array = []
		for o in copy:
			if o.get("t", "") == "p":
				passive_opts.append(o)
				if o.get("evo_match", false):
					evo_passive_opts.append(o)
		if passive_opts.size() > 0:
			var passive_pool: Array = evo_passive_opts if not evo_passive_opts.is_empty() else passive_opts
			var pe: Dictionary = _weighted_choice(passive_pool)
			picks.append(pe)
			copy.erase(pe)
	while picks.size() < 3 and copy.size() > 0:
		var total := 0.0
		for u in copy:
			total += _opt_weight(u)
		var roll := randf() * total
		var acc := 0.0
		var chosen: Dictionary = copy[0]
		for u in copy:
			acc += _opt_weight(u)
			if roll <= acc:
				chosen = u
				break
		picks.append(chosen)
		copy.erase(chosen)
	return picks


# 가중치 추첨: _opt_weight 기준으로 배열에서 1개 선택 (레벨업·상자 공통)
func _weighted_choice(arr: Array) -> Dictionary:
	if arr.is_empty():
		return {}
	var total := 0.0
	for u in arr:
		total += _opt_weight(u)
	var roll := randf() * total
	var acc := 0.0
	for u in arr:
		acc += _opt_weight(u)
		if roll <= acc:
			return u
	return arr[arr.size() - 1]


# 카드 최종 가중치: 등급 기본값 × 보유 우대 (뱀서식 — 든 무기/패시브를 착착 레벨업)
func _opt_weight(u: Dictionary) -> float:
	var w := _rarity_weight(u["r"])
	if u.get("owned", false):
		w *= 3.2   # 핵심 빌드 집중: 첫 진화가 10~12분 보스 상자에 맞도록 유도
	if u.get("evo_match", false):
		w *= 2.5   # 현재 무기의 필수 진화 재료는 패시브 슬롯에서 우선 제안
	return w


func _rarity_weight(r: String) -> float:
	match r:
		"legend":
			return 4.0
		"epic":
			return 13.0
		"rare":
			return 28.0
		_:
			return 55.0


func _rarity_color(r: String) -> Color:
	match r:
		"legend":
			return Color(1.0, 0.82, 0.25)   # 금
		"epic":
			return Color(0.8, 0.5, 1.0)     # 보라
		"rare":
			return Color(0.5, 0.75, 1.0)    # 파랑
		_:
			return Color(0.85, 0.88, 0.92)  # 회백


# ---------------------------------------------------------------------
#  난이도 / 종료
# ---------------------------------------------------------------------
func _apply_unlocked_relic_effects() -> void:
	# 해금된 유물의 영구 패시브를 런에 적용한다(설계 결정 #2: 조건 달성 시 자동, 매 런 적용).
	# _start_run에서 무기 추가·스탯 계산이 끝난 뒤 호출된다. yellow_sign(도감)·milky_map(지도)는
	# 각각 도감/일시정지 화면에서 처리하므로 여기서는 스탯형 유물만 다룬다.
	if _has_relic("witch_tear"):
		run_pressure_mult *= 1.12                    # 런 위협 +12% (고위험 고보상)
		xp_mult *= 1.12                              # 경험치 +12%
		greed_mult *= 1.12                           # 골드 +12%
	if _has_relic("golden_mask"):
		greed_mult *= 1.15                           # 골드 획득 +15%
	if player == null:
		return
	if _has_relic("silver_ring"):
		player.area_mult += 0.10                     # 모든 무기 범위 +10%
	if _has_relic("metaglio"):
		player.armor += 1.0                          # 방어력 +1
		player.regen += 0.25                         # 재생 +0.25/초
	if _has_relic("black_chalice"):
		global_lifesteal += 0.015                    # 모든 피해에 흡혈 1.5%
	if _has_relic("abyss_eye"):
		xp_mult *= 1.10                              # 경험치 +10%
	if _has_relic("soul_lantern"):
		player.pickup_radius += 30.0                 # 자석 범위 +30
	if _has_relic("fallen_halo"):
		player.speed *= 1.08                         # 이동속도 +8%
	if _has_relic("hungry_heart"):
		player.max_hp *= 1.15                        # 최대 체력 +15%
		player.hp = player.max_hp                    # 런 시작 시점 호출이라 풀피로 갱신
	# great_gospel(시작 무기 +1레벨)은 무기가 추가된 뒤라야 해 _start_run 무기 블록에서 처리한다.


# 던전 선택 화면의 가호 버튼. 클릭할 때마다 가호를 순환한다.
func _refresh_stage_blessing() -> void:
	if map_blessing_button == null:
		return
	var m: Dictionary = sel_modifier
	if m.is_empty() or str(m.get("key", "none")) == "none":
		map_blessing_button.text = "가호: 없음 · 클릭해 변경"
		map_blessing_button.tooltip_text = "추가 효과 없이 원정합니다."
		map_blessing_button.modulate = Color(0.72, 0.74, 0.8)
	else:
		var blessing_name := str(m.get("name", "")).replace("[축복] ", "")
		map_blessing_button.text = "가호: %s · %s" % [blessing_name, str(m.get("desc", ""))]
		map_blessing_button.tooltip_text = str(m.get("desc", ""))
		map_blessing_button.modulate = m.get("color", Color(0.6, 0.85, 1.0))


func _cycle_stage_blessing() -> void:
	var current_key := str(sel_modifier.get("key", "none"))
	var current_index := 0
	for i in MODIFIERS.size():
		if str(MODIFIERS[i].get("key", "none")) == current_key:
			current_index = i
			break
	sel_modifier = MODIFIERS[(current_index + 1) % MODIFIERS.size()]
	play_sfx("hit", -18.0, 0.1)
	_refresh_stage_blessing()


# 유물 세트 3종을 모두 해금했는지
func _has_relic_set(relics: Array) -> bool:
	for k in relics:
		if not _has_relic(str(k)):
			return false
	return true


# 유물 세트 시너지 보너스 적용 (개별 유물 효과 뒤, player 보장 시점에 호출)
func _apply_relic_set_effects() -> void:
	if _has_relic_set(RELIC_SETS[0]["relics"]):        # 심연의 계약
		run_pressure_mult *= 1.15
		xp_mult *= 1.12
		if player: player.speed *= 1.05
	if _has_relic_set(RELIC_SETS[1]["relics"]):        # 연금술사의 보고
		greed_mult *= 1.20
		if player:
			player.pickup_radius += 40.0
			player.area_mult += 0.08
	if _has_relic_set(RELIC_SETS[2]["relics"]):        # 불멸의 심장
		global_lifesteal += 0.02
		if player:
			player.max_hp *= 1.12
			player.hp = player.max_hp
			player.regen += 0.5
	if _has_relic_set(RELIC_SETS[3]["relics"]):        # 예언자의 유산
		xp_mult *= 1.12
		greed_mult *= 1.12


func _prepare_selected_stage() -> bool:
	map_stage = clampi(sel_stage, 1, FINAL_STAGE)
	stage_layout = StageLayoutData.make(map_stage, Color(GameConfig.stage_info(map_stage)["tint"]))
	# 톤 보정은 렌더러 안에서 경계 타일에만 굽는다. 채움 팩은 이미 어두워 보정하면 뭉개진다.
	stage_map_texture = StageTiles.build(stage_layout, map_stage, WORLD,
		STAGE_TILE_MODULATES[clampi(map_stage - 1, 0, STAGE_TILE_MODULATES.size() - 1)])
	if player:
		player.stage_layout = stage_layout
	return stage_layout != null and int(stage_layout.stage_id) == map_stage and stage_map_texture != null


func _apply_difficulty_profile(d: Dictionary) -> void:
	var profile := d if not d.is_empty() else _difficulty_by_key("normal")
	sel_diff = profile.duplicate(true)
	diff_enemy_hp = float(profile.get("enemy_hp", 1.0))
	diff_enemy_speed = float(profile.get("enemy_speed", 1.0))
	diff_spawn = float(profile.get("spawn", 1.0))
	diff_loot = float(profile.get("loot", 1.0))
	diff_gold_reward = float(profile.get("gold", 1.0))
	diff_xp_reward = float(profile.get("xp", 1.0))
	diff_gear_drop = float(profile.get("gear", 1.0))
	diff_rarity_luck = float(profile.get("rarity_luck", 0.0))
	diff_label = str(profile.get("label", "보통"))


func _start_game(d: Dictionary) -> void:
	if not _prepare_selected_stage():
		push_error("Selected stage failed to initialize: %d" % sel_stage)
	decorations.clear()
	# 던전 모드: 선택 던전 번호를 난이도 티어로 고정(빙하=3층 몹 등). 캠페인/심연은 1에서 시작.
	stage_num = map_stage if map_stage > 0 else 1
	_apply_difficulty_profile(d)
	# 가호 적용
	var mod := sel_modifier
	diff_enemy_hp *= float(mod.get("enemy_hp", 1.0))
	diff_enemy_speed *= float(mod.get("enemy_speed", 1.0))
	diff_spawn *= float(mod.get("spawn", 1.0))
	diff_loot *= float(mod.get("loot", 1.0))
	# 영구 강화 적용
	var up: Dictionary = meta["up"]
	player.damage_mult += 0.04 * up.get("dmg", 0)
	player.max_hp += 10.0 * up.get("hp", 0)
	player.speed *= 1.0 + 0.03 * up.get("speed", 0)
	player.cooldown_mult *= 1.0 - 0.02 * up.get("cd", 0)
	player.pickup_radius += 12.0 * up.get("magnet", 0)
	player.regen += 0.2 * up.get("regen", 0)
	player.armor += 1.0 * up.get("armor", 0)
	player.area_mult += 0.05 * up.get("area", 0)
	player.amount += int(up.get("amount", 0)) / 2   # 추가 투사체: 2Lv당 +1 (뱀서 Amount PowerUp)
	diff_loot *= 1.0 + 0.08 * up.get("luck", 0)      # 상자·전리품 확률
	greed_mult = ((1.0 + 0.12 * up.get("greed", 0))
		* float(mod.get("gold", 1.0)) * diff_gold_reward)
	xp_mult = ((1.0 + 0.08 * up.get("xp", 0))
		* float(mod.get("xp", 1.0)) * diff_xp_reward)
	revives = int(up.get("revive", 0))
	run_pressure_mult = 1.0   # 패시브·유물의 런 중 추가 위협은 매 원정 초기화
	global_lifesteal = 0.0
	# 캐릭터 적용 (특화 배수 포함)
	player.stages_data = GameConfig.char_stages(sel_char["key"])
	player.set_stage(0)
	player.max_hp *= float(sel_char["hp"])
	player.speed *= float(sel_char["speed"])
	player.cooldown_mult *= float(sel_char["cd"])
	char_melee = float(sel_char.get("melee", 1.0))
	char_ranged = float(sel_char.get("ranged", 1.0))
	char_range = float(sel_char.get("range", 1.0))
	# 가호 플레이어 보정 (이동속도·투사체는 성장 baseline 캡처 전에 적용)
	player.speed *= float(mod.get("player_speed", 1.0))
	player.amount += int(mod.get("player_amount", 0))
	# 성장 특성 초기화 (speed 성장은 이 기준 속도의 %로 더함)
	_growth_tier = 0
	_base_speed = player.speed
	player.max_hp *= float(sel_diff.get("player_hp", 1.0))
	player.max_hp *= float(mod.get("player_hp", 1.0))   # 가호 최대 체력 보정
	player.hp = player.max_hp
	_apply_unlocked_relic_effects()
	_apply_relic_set_effects()
	cheated = false
	cheat_invincible = false
	run_gold = 0
	ult_gauge = 0.0
	skill_e_cd = 0.0
	player.dodge_t = 0.0
	player.dodge_cd = 0.0
	player.invuln = 0.0
	# 런 시작: 마을 로드아웃(장착 세트)을 깊은복사로 이월. 런 중 변경이 마을 원본을 오염시키지 않음.
	_ensure_gear_meta()
	equipped = {"weapon": {}, "armor": {}, "trinket": {}}
	var lo: Dictionary = meta.get("loadout", {})
	for slot in EQUIP_SLOTS:
		var g = lo.get(slot, {})
		if g is Dictionary and not g.is_empty():
			equipped[slot] = (g as Dictionary).duplicate(true)
	_equip_applied = {}
	inventory = []
	_inv_sel = -1
	stat_points = 0
	char_stats = {"str": 0, "agi": 0, "vit": 0, "foc": 0}   # 런 시작: 능력치 분배 초기화
	if inventory_panel:
		inventory_panel.visible = false
	_apply_equipment()   # 이월된 로드아웃 어픽스를 player에 반영 (HUD도 내부 갱신)
	_refresh_ult_bar()
	_refresh_skill_hud()
	run_damage_dealt = 0.0
	run_damage_taken = 0.0
	run_bosses = 0
	_wave_minute = -1
	_current_wave = {}
	featured_enemy = ""
	used_revive = false
	run_rerolls = 3
	run_banishes = 2
	run_skips = 2
	banished.clear()
	# HUD 뱃지 초상화를 선택 캐릭터로 갱신 (빌드 시점엔 미선택이라 기본값이었음)
	if hud_portrait:
		var pk: String = sel_char.get("key", "corvius")
		var pt := Assets.tex("res://assets/ui/portrait_%s.png" % pk)
		if pt == null:
			pt = Assets.tex("res://assets/hero/%s_1.png" % pk)
		hud_portrait.texture = pt
	# 뱀서식: 기본공격 없음 — 시작무기만 지급 (아래 _add_weapon)
	weapons = {}
	wtimer = {}
	passives = {}
	evolved = {}
	combos = {}
	unions = {}
	reaper_warned = false
	_boss_is_objective = false
	# B블렌드: 장착한 무기 장비가 캐릭터 주무기(weapon1)를 대체. 없으면 캐릭터 기본 무기.
	# (캐릭터 고유 2번째 무기 weapon2는 유지 → 캐릭터 정체성 일부 보존)
	var gear_wpn := str(equipped.get("weapon", {}).get("weapon_kind", ""))
	var sw := gear_wpn if gear_wpn != "" and WNAMES.has(gear_wpn) else str(sel_char.get("weapon", "arrow"))
	_add_weapon(sw)
	# 캐릭터 고유 2번째 시작 무기 (예: 나이트 = 검기 + 회전검 '방패')
	var sw2 := str(sel_char.get("weapon2", ""))
	if sw2 != "":
		_add_weapon(sw2)
	# 가호 「축복받은 시작」: 시작 무기를 추가 레벨로
	if mod.has("start_weapon"):
		for j in int(mod["start_weapon"]) - 1:
			_upgrade_weapon(sw)
	# 유물 「위대한 복음」: 시작 무기 +1레벨 (무기가 추가된 뒤에 적용)
	if _has_relic("great_gospel") and weapons.has(sw):
		_upgrade_weapon(sw)
	pickup_timer = 10.0
	_scatter_pickups(int(4 + 8 * diff_loot))
	_spawn_stage_landmarks()
	breakable_timer = 6.0
	var stage_breakables := 10
	if map_stage > 0:
		stage_breakables = int(GameConfig.stage_spawn_profile(map_stage).get("breakables", stage_breakables))
	_scatter_breakables(stage_breakables)   # stage-dependent initial placement
	if stage_label and map_stage > 0:
		stage_label.text = "[%s]  탐험 시작" % str(GameConfig.stage_info(map_stage)["name"])
		stage_label.visible = true
		stage_banner_t = 3.0
	_apply_char_growth()   # 캐릭터 성장 특성 (Lv1 시점 — per가 1이면 즉시 반영)
	_gen_decorations()
	_refresh_inventory_ui()
	_start_bgm()
	play_sfx("select", -10.0)
	title_panel.visible = false
	if char_panel:
		char_panel.visible = false
	if stage_select_panel:
		stage_select_panel.visible = false
	state = State.PLAYING
	get_tree().paused = false
	_update_ui()

	# UI QA 전용: 런 중 핵심 오버레이도 메뉴 화면과 같은 방식으로 캡처한다.
	# 일반 플레이에서는 어떤 상태도 바꾸지 않는다.
	var launch_args := OS.get_cmdline_user_args()
	if "--screen=levelup" in launch_args:
		pending_levelups = 1
		_start_levelup()
		await get_tree().create_timer(0.6, true, false, true).timeout
		var levelup_image := get_viewport().get_texture().get_image()
		levelup_image.save_png("user://autoshot.png")
		print("AUTOSHOT SAVED: ", ProjectSettings.globalize_path("user://autoshot.png"))
		get_tree().quit()
		return
	if "--screen=pause" in launch_args:
		_toggle_pause()
		await get_tree().create_timer(0.4, true, false, true).timeout
		var pause_image := get_viewport().get_texture().get_image()
		pause_image.save_png("user://autoshot.png")
		print("AUTOSHOT SAVED: ", ProjectSettings.globalize_path("user://autoshot.png"))
		get_tree().quit()
		return


func _game_over() -> void:
	if state == State.GAMEOVER:
		return
	Engine.time_scale = 1.0   # 슬로우모션 잔여 복구
	# 영구강화 「부활」: 남은 부활이 있으면 그 자리에서 되살아남
	if revives > 0:
		revives -= 1
		used_revive = true
		player.hp = player.max_hp * 0.5
		player.invuln = 2.5
		# 주변 적 정리 + 연출
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and player.position.distance_to(e.position) < 260.0:
				e.queue_free()
		spawn_fx("fx_divine", player.position, 360.0)
		var fx := Effect.new()
		fx.kind = "ring"
		fx.position = player.position
		fx.rad = 260.0
		fx.col = Color(1.0, 0.9, 0.5)
		fx.life = 0.6
		fx.max_life = 0.6
		add_child(fx)
		shake_t = max(shake_t, 0.2)
		play_sfx("levelup", -6.0)
		if stage_label:
			stage_label.text = "✨ 부활! (남은 부활 %d)" % revives
			stage_label.visible = true
		stage_banner_t = 2.0
		return
	state = State.GAMEOVER
	player.play_death()
	get_tree().paused = true
	_show_end(Loc.t("gameover"), false)


func _show_end(title: String, win: bool) -> void:
	# 승리 관련 업적 판정
	if win:
		_grant_ach("first_win")
		_grant_ach("win_" + str(sel_char.get("key", "corvius")))
		if str(sel_diff.get("key", "")) in ["hard", "nightmare"]:
			_grant_ach("hard_clear")
		if not used_revive:
			_grant_ach("no_revive")
		# 현재 공용 무기 풀 기준: 보통 이상에서 원거리 빌드를 충분히 구성하면 투척 칼 해금.
		if diff_label != "쉬움":
			var ranged_count := 0
			for k in weapons.keys():
				if k in RANGED_WEAPONS:
					ranged_count += 1
			if ranged_count >= 4:
				_grant_ach("knife_thrower")
	_check_achievements()
	# 독립 스테이지 클리어 시 다음 맵 해금. 캠페인(0)은 기존 진행을 보존한다.
	# 치트 런은 해금·기록·골드 전부 미반영 (cheated).
	var newly_unlocked := 0
	if win and map_stage > 0 and map_stage < FINAL_STAGE and not cheated:
		var current_unlock := int(meta.get("stage_unlocked", 1))
		if current_unlock <= map_stage:
			newly_unlocked = map_stage + 1
			meta["stage_unlocked"] = newly_unlocked
	# 난이도별 최고 기록을 런 종료 시점에 갱신한다. (치트 런은 표시만 하고 저장하지 않음)
	var mode_key := "campaign" if map_stage == 0 else "stage_%d" % map_stage
	var record_key := "%s|%s" % [mode_key, diff_label if diff_label != "" else "기본"]
	var records: Dictionary = meta.get_or_add("records", {})
	var record: Dictionary = records.get(record_key, {})
	var banked_gear := 0
	if not cheated:
		record["best_time"] = maxf(float(record.get("best_time", 0.0)), time_survived)
		record["best_kills"] = maxi(int(record.get("best_kills", 0)), kills)
		record["best_level"] = maxi(int(record.get("best_level", 0)), level)
		record["best_damage"] = maxf(float(record.get("best_damage", 0.0)), run_damage_dealt)
		if win:
			record["clears"] = int(record.get("clears", 0)) + 1
		records[record_key] = record
		# 골드 영구 저장 (심연 모드로 이어가도 중복 적립 안 되게 리셋)
		meta["gold"] = int(meta["gold"]) + run_gold
		banked_gear = _bank_found_gear()   # 런 중 주운 장비(_found)를 마을 보관함으로 이월
		Meta.save_data(meta)
	var earned := run_gold if not cheated else 0
	run_gold = 0
	abyss_btn.visible = win
	play_sfx("win" if win else "lose", -6.0)
	end_title.text = title
	end_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4) if win else Color(0.95, 0.38, 0.38))
	var mm2 := int(time_survived) / 60
	var ss2 := int(time_survived) % 60
	var best_time := int(float(record.get("best_time", 0.0)))
	var run_dps := run_damage_dealt / maxf(1.0, time_survived)
	var mode_name := "5막 캠페인" if map_stage == 0 else str(GameConfig.stage_info(map_stage)["name"])
	var unlock_text := "   ·   다음 맵 해금!" if newly_unlocked > 0 else ""
	var forge_text := "   ·   대장간 보관 +%d" % banked_gear if banked_gear > 0 else ""
	end_label.text = "%s   ·   Lv %d   ·   처치 %d\n생존 %02d:%02d   ·   [%s]   ·   골드 +%d%s%s\n총 피해 %d   ·   DPS %.1f   ·   받은 피해 %d\n최고 %02d:%02d   ·   최고 Lv%d   ·   최고 처치 %d   ·   최고 피해 %d   ·   클리어 %d회\n보유 %d G" % [
		mode_name, level, kills, mm2, ss2, diff_label, earned, unlock_text,
		forge_text,
		int(round(run_damage_dealt)), run_dps, int(round(run_damage_taken)),
		best_time / 60, best_time % 60, int(record.get("best_level", 0)),
		int(record.get("best_kills", 0)), int(round(float(record.get("best_damage", 0.0)))),
		int(record.get("clears", 0)), int(meta["gold"])]
	_populate_end_build()
	end_panel.visible = true


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# 심연 모드: 승리 후 무한 스케일링으로 계속
func _continue_abyss() -> void:
	end_panel.visible = false
	abyss_mode = true   # 30분 승리 후 무한 모드 진입 (시간 승리 판정 중단)
	boss_spawned = false
	stage_num += 1
	next_boss_time = time_survived + BOSS_TIME
	diff_enemy_hp *= 1.5
	diff_enemy_speed *= 1.05
	_gen_decorations()
	if stage_label:
		stage_label.text = "심연 STAGE %d — %s" % [stage_num, GameConfig.stage_info(stage_num)["name"]]
		stage_label.visible = true
	stage_banner_t = 2.5
	state = State.PLAYING
	get_tree().paused = false
	play_sfx("boss", -8.0)


# ---------------------------------------------------------------------
#  일시정지 (ESC)
# ---------------------------------------------------------------------
# E 스킬과 Space 회피 HUD 갱신 (준비=체크, 쿨=남은 초)
func _refresh_skill_hud() -> void:
	if skill_hud_label == null:
		return
	var active_def := _current_weapon_active_def()
	var active_label := "%s %s" % [
		str(active_def.get("glyph", "•")),
		str(active_def.get("name", "무기 스킬")),
	]
	var et := "E %s ✓" % active_label if skill_e_cd <= 0.0 else "E %s %.1f" % [active_label, skill_e_cd]
	var dodge_cd := player.dodge_cd if player else 0.0
	var st := "Space 회피 ✓" if dodge_cd <= 0.0 else "Space 회피 %.1f" % dodge_cd
	skill_hud_label.text = "%s     %s" % [et, st]


# 궁극 게이지 바 갱신 (가볍게 — 처치마다 호출)
func _refresh_ult_bar() -> void:
	if ult_bar == null:
		return
	ult_bar.value = ult_gauge
	if ult_bar_label:
		var un := str(ULT_NAME.get(_char_ult(), "궁극기"))
		if ult_gauge >= 1.0:
			ult_bar_label.text = "★ Q  %s  READY ★" % un
			ult_bar_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
		else:
			ult_bar_label.text = "Q  %s  %d%%" % [un, int(ult_gauge * 100.0)]
			ult_bar_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))


# E 스킬샷: 마우스 방향으로 강력한 관통 빔 (히트스캔 코리도어). RPG식 조준 스킬.
# 캐릭터별 고유 스킬: ult=궁극기 아키타입, element=스킬 3종의 속성(색·상성).
# GameConfig를 안 건드리고 여기 한 곳에서 분기 (character key 기준).
const CHAR_SKILLS := {
	"corvius":   {"ult": "blast",    "element": "dark"},   # 역병의사 — 비전 폭발
	"gustavo":   {"ult": "reap",     "element": "phys"},   # 정육점 탱커 — 흡혈 수확
	"serafina":  {"ult": "judgment", "element": "holy"},   # 수녀 — 신성 심판+자힐
	"valentino": {"ult": "reap",     "element": "dark"},   # 뱀파이어 — 흡혈 수확
	"pixie":     {"ult": "meteor",   "element": "fire"},   # 마녀 — 운석비
	"django":    {"ult": "blast",    "element": "phys"},   # 노상강도 — 비전 폭발
	"bolt":      {"ult": "blast",    "element": "dark"},    # 해골 — 비전 폭발
	"morgana":   {"ult": "blizzard", "element": "ice"},    # 유령 — 빙결 결계
	"isolde":    {"ult": "blizzard", "element": "ice"},    # 서리 마녀 — 빙결 결계
	"grimble":   {"ult": "blast",    "element": "dark"},    # 부두술사 — 비전 폭발
	"mordek":    {"ult": "reap",     "element": "phys"},   # 처형인 — 흡혈 수확
}
const ULT_NAME := {"blast": "비전 폭발", "meteor": "운석비", "blizzard": "빙결 결계", "judgment": "신성 심판", "reap": "암흑 수확"}


func _char_ult() -> String:
	return str((CHAR_SKILLS.get(str(sel_char.get("key", "")), {}) as Dictionary).get("ult", "blast"))


func _char_skill_element() -> String:
	return str((CHAR_SKILLS.get(str(sel_char.get("key", "")), {}) as Dictionary).get("element", "phys"))


func _primary_weapon_kind() -> String:
	var equipped_weapon: Dictionary = equipped.get("weapon", {})
	var gear_kind := str(equipped_weapon.get("weapon_kind", ""))
	if gear_kind != "" and WEAPON_ACTIVE_ARCHETYPE.has(gear_kind):
		return gear_kind
	var starting_kind := str(sel_char.get("weapon", "soul_bolt"))
	return starting_kind if WEAPON_ACTIVE_ARCHETYPE.has(starting_kind) else "soul_bolt"


func _weapon_active_archetype(kind: String) -> String:
	return str(WEAPON_ACTIVE_ARCHETYPE.get(kind, "staff"))


func _weapon_active_def_for_kind(kind: String) -> Dictionary:
	return WEAPON_ACTIVE_DEFS.get(_weapon_active_archetype(kind), WEAPON_ACTIVE_DEFS["staff"])


func _current_weapon_active_def() -> Dictionary:
	var weapon_kind := _primary_weapon_kind()
	var active_def := _weapon_active_def_for_kind(weapon_kind).duplicate(true)
	if equipped.get("weapon", {}).is_empty() and STARTING_WEAPON_ACTIVE_VARIANTS.has(weapon_kind):
		var variant: Dictionary = STARTING_WEAPON_ACTIVE_VARIANTS[weapon_kind]
		for key in variant:
			active_def[key] = variant[key]
	return active_def


func _weapon_active_cooldown() -> float:
	var active_def := _current_weapon_active_def()
	var cooldown_mult := player.cooldown_mult if player else 1.0
	return maxf(1.0, float(active_def.get("cd", 6.0)) * cooldown_mult)


func _active_skill_element() -> String:
	var equipped_weapon: Dictionary = equipped.get("weapon", {})
	return str(equipped_weapon.get("element", _char_skill_element()))


func _skill_aim_direction() -> Vector2:
	if player == null:
		return Vector2.RIGHT
	var dir := get_global_mouse_position() - player.position
	if dir.length_squared() < 64.0:
		dir = player._last_dir
	return dir.normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT


func _skill_target_point(max_range: float = 520.0) -> Vector2:
	var dir := _skill_aim_direction()
	var to_mouse := get_global_mouse_position() - player.position
	var distance := clampf(to_mouse.length(), 110.0, max_range)
	var target := player.position + dir * distance
	if stage_layout:
		target = stage_layout.nearest_walkable(target, 4.0)
	return target


func _weapon_active_damage(base_damage: float, melee: bool) -> float:
	var role_mult := char_melee if melee else char_ranged
	var run_scale := 1.0 + minf(time_survived / 600.0, 3.0)
	return base_damage * player.damage_mult * role_mult * run_scale


func _damage_active_target(target, damage: float, element: String, crit: bool = false) -> void:
	if target is Boss:
		target.take_damage(damage, crit, element)
	else:
		target.take_damage(damage, crit, false, element)


func _fire_weapon_active() -> bool:
	if player == null:
		return false
	var dir := _skill_aim_direction()
	player._face_direction(dir)
	match _weapon_active_archetype(_primary_weapon_kind()):
		"sword":
			_fire_sword_active(dir)
		"axe":
			_fire_axe_active()
		"dagger":
			_fire_dagger_active(dir)
		"spear":
			_fire_spear_active(dir)
		_:
			_fire_staff_active()
	return true


# 검 — 반격의 호: 짧은 무적과 넓은 전방 베기로 위험한 근접전을 뒤집는다.
func _fire_sword_active(dir: Vector2) -> void:
	var element := _active_skill_element()
	var col: Color = ELEMENT_COL.get(element, Color.WHITE)
	var reach := 180.0 * player.area_mult
	var damage := _weapon_active_damage(108.0, true)
	var blood_variant: bool = equipped.get("weapon", {}).is_empty() and _primary_weapon_kind() == "blood_sword"
	var blood_heal := 0.0
	player.invuln = maxf(player.invuln, 0.42)
	player.play_attack()
	for target in _enemies_and_boss():
		if not is_instance_valid(target):
			continue
		var to: Vector2 = (target as Node2D).position - player.position
		if to.length() <= reach + float(target.radius) and to.normalized().dot(dir) > 0.22:
			_damage_active_target(target, damage, element)
			if blood_variant:
				blood_heal += damage * 0.06
			if target.has_method("shove"):
				target.shove(player.position, 240.0)
	if blood_heal > 0.0:
		player.hp = minf(player.max_hp, player.hp + minf(blood_heal, player.max_hp * 0.12))
	_break_near(player.position + dir * reach * 0.45, reach * 0.75, damage)
	_spawn_proc_fx("cleave", player.position, reach, col, 0.34, dir, player.position + dir * reach)
	play_sfx("shoot", -7.0, 0.08)
	shake_t = maxf(shake_t, 0.12)


# 도끼 — 파쇄 강타: 주변을 확실히 비우는 느리고 강한 군중 제어기.
func _fire_axe_active() -> void:
	var element := _active_skill_element()
	var col: Color = ELEMENT_COL.get(element, Color(0.9, 0.65, 0.3))
	var radius := 172.0 * player.area_mult
	var damage := _weapon_active_damage(152.0, true)
	player.play_attack()
	for target in _enemies_and_boss():
		if not is_instance_valid(target):
			continue
		if player.position.distance_to((target as Node2D).position) <= radius + float(target.radius):
			_damage_active_target(target, damage, element)
			if target.has_method("apply_slow"):
				target.apply_slow(0.72, 1.8)
			if target.has_method("shove"):
				target.shove(player.position, 330.0)
	_break_near(player.position, radius, damage)
	_spawn_proc_fx("ring", player.position, radius, col, 0.46)
	_spawn_proc_fx("burst", player.position, radius * 0.7, col, 0.32)
	spawn_fx("fx_quake_spike", player.position, radius * 0.95)
	play_sfx("ult", -9.0, 0.10)
	shake_t = maxf(shake_t, 0.22)


# 지팡이 — 원소 폭발: 같은 조작이어도 장비 접두 속성에 따라 부가효과가 바뀐다.
func _fire_staff_active(target_override: Vector2 = Vector2.ZERO) -> void:
	var element := _active_skill_element()
	var col: Color = ELEMENT_COL.get(element, Color(0.65, 0.85, 1.0))
	var character_weapon: bool = equipped.get("weapon", {}).is_empty()
	var primary_kind := _primary_weapon_kind()
	var target_point := target_override if target_override != Vector2.ZERO else _skill_target_point()
	if character_weapon and primary_kind == "aura":
		target_point = player.position
	var radius := 118.0 * player.area_mult
	var damage := _weapon_active_damage(126.0, false)
	if element == "fire":
		damage *= 1.15
	elif element == "holy":
		player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.06)
	player.play_attack()
	for target in _enemies_and_boss():
		if not is_instance_valid(target):
			continue
		if target_point.distance_to((target as Node2D).position) <= radius + float(target.radius):
			_damage_active_target(target, damage, element)
			if element == "ice" and target.has_method("apply_slow"):
				target.apply_slow(0.62, 2.4)
			elif element == "dark" and target.has_method("apply_slow"):
				target.apply_slow(0.38, 1.8)
			elif element == "phys" and target.has_method("shove"):
				target.shove(target_point, 190.0)
	_break_near(target_point, radius, damage)
	_spawn_proc_fx("ring", target_point, radius, col, 0.42)
	_spawn_proc_fx("burst", target_point, radius * 0.72, col, 0.36)
	match element:
		"fire":
			spawn_fx("fx_explosion", target_point, radius * 1.25)
		"ice":
			spawn_fx("fx_absolzero", target_point, radius * 1.35)
		"holy":
			spawn_fx("fx_judgment", target_point, radius * 1.35)
		"dark":
			spawn_fx("fx_plague", target_point, radius * 1.35)
		_:
			spawn_fx("fx_quake_spike", target_point, radius * 1.15)
	play_sfx("ult", -10.0, 0.08)
	shake_t = maxf(shake_t, 0.14)


# 단검 — 그림자 난무: 좁은 부채꼴에 고유 치명타 보정을 가진 단검을 쏟아낸다.
func _fire_dagger_active(dir: Vector2) -> void:
	var element := _active_skill_element()
	var col: Color = ELEMENT_COL.get(element, Color(0.85, 0.9, 1.0))
	var shots := 7 + mini(player.amount, 3)
	var damage := _weapon_active_damage(27.0, false)
	var primary_kind := _primary_weapon_kind()
	player.play_attack()
	for i in shots:
		var dagger := Arrow.new()
		dagger.damage = damage
		dagger.pierce = 0
		dagger.radius = 6.0
		dagger.crit_chance = 0.55
		dagger.crit_mult = 2.2
		match primary_kind:
			"spread_shot":
				dagger.anim_dir = "res://assets/anim/proj_bullet"
				dagger.sprite_path = "res://assets/items/icon_spreadshot.png"
				dagger.scale_mul = 0.85
			"arrow":
				dagger.anim_dir = "res://assets/anim/proj_arrow"
				dagger.sprite_path = "res://assets/items/arrow.png"
			"venom":
				dagger.anim_dir = "res://assets/anim/proj_venom"
				dagger.sprite_path = "res://assets/items/icon_venom.png"
			"boomerang":
				dagger.anim_dir = "res://assets/anim/proj_boomerang"
				dagger.sprite_path = "res://assets/items/icon_boomerang.png"
				dagger.spin = 20.0
			"chakram":
				dagger.anim_dir = "res://assets/anim/proj_chakram"
				dagger.sprite_path = "res://assets/items/icon_chakram.png"
				dagger.spin = 22.0
			_:
				dagger.anim_dir = "res://assets/anim/proj_knife"
				dagger.sprite_path = "res://assets/items/sword.png"
				dagger.spin = 24.0
				dagger.scale_mul = 0.95
		dagger.trail = true
		dagger.trail_col = col
		dagger.life = 0.92 * char_range
		dagger.position = player.position + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
		var spread := (float(i) - float(shots - 1) / 2.0) * 0.105
		dagger.velocity = dir.rotated(spread + randf_range(-0.025, 0.025)) * 920.0
		add_child(dagger)
	_spawn_proc_fx("burst", player.position + dir * 22.0, 42.0, col, 0.20, dir)
	play_sfx("shoot", -10.0, 0.06)
	shake_t = maxf(shake_t, 0.07)


# 창 — 돌파 찌르기: 짧은 무적 돌진 뒤 일직선의 적을 모두 관통한다.
func _fire_spear_active(dir: Vector2) -> void:
	var element := _active_skill_element()
	var col: Color = ELEMENT_COL.get(element, Color(0.8, 0.9, 1.0))
	var ice_variant: bool = equipped.get("weapon", {}).is_empty() and _primary_weapon_kind() == "ice_lance"
	var lunge_target := player.position + dir * 78.0
	if stage_layout:
		lunge_target = stage_layout.resolve_move(player.position, lunge_target, player.radius)
	else:
		lunge_target.x = clampf(lunge_target.x, player.radius, player.world_size.x - player.radius)
		lunge_target.y = clampf(lunge_target.y, player.radius, player.world_size.y - player.radius)
	player.position = lunge_target
	player.invuln = maxf(player.invuln, 0.24)
	player.play_attack()
	var spear := Arrow.new()
	spear.damage = _weapon_active_damage(146.0, false)
	spear.pierce = 99
	spear.radius = 11.0
	spear.anim_dir = "res://assets/anim/proj_icelance" if ice_variant else "res://assets/anim/proj_spear"
	spear.sprite_path = "res://assets/items/icon_icelance.png" if ice_variant else "res://assets/items/icon_spear.png"
	spear.scale_mul = 1.65
	spear.trail = true
	spear.trail_col = col
	if ice_variant:
		spear.slow_amount = 0.58
		spear.slow_time = 2.2
		spear.fx_hit = "fx_frost"
	spear.life = 1.05 * char_range
	spear.position = player.position
	spear.velocity = dir * 980.0
	add_child(spear)
	_spawn_proc_fx("slash", player.position, 92.0, col, 0.22, dir, player.position + dir * 92.0)
	play_sfx("dash", -8.0, 0.08)
	shake_t = maxf(shake_t, 0.11)


# 궁극기: 화면 전역 대형 폭발 (능동 스킬 Phase 1). 게이지 소모.
func _fire_ultimate() -> void:
	if state != State.PLAYING or player == null:
		return
	ult_gauge = 0.0
	# 캐릭터별 고유 궁극기. 시간이 지날수록 강해짐(후반 탱커 정리).
	var base: float = 80.0 * player.damage_mult * (1.0 + time_survived / 240.0)
	var elem := _char_skill_element()
	var col: Color = ELEMENT_COL.get(elem, Color(0.82, 0.45, 1.0))
	match _char_ult():
		"meteor": _ult_meteor(base, elem, col)
		"blizzard": _ult_blizzard(base, elem, col)
		"judgment": _ult_judgment(base, elem, col)
		"reap": _ult_reap(base, elem, col)
		_: _ult_blast(base, elem, col)
	play_sfx("ult", -4.0)
	_refresh_ult_bar()


# 비전 폭발: 화면 전역 균등 대형 폭발 (기본형).
func _ult_blast(base: float, elem: String, col: Color) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.take_damage(base, true, false, elem)
			e.shove(player.position, 260.0)
	if boss and is_instance_valid(boss):
		boss.take_damage(base * 4.0, true, elem)
	_flash(Color(col.r, col.g, col.b, 0.6))
	shake_t = maxf(shake_t, 0.4)
	_slowmo(0.4, 260)
	_spawn_proc_fx("ring", player.position, 540.0, col, 0.6)
	_spawn_proc_fx("burst", player.position, 240.0, col.lightened(0.35), 0.5)


# 운석비: 랜덤 지점에 다중 폭발. 겹치는 곳은 큰 피해 (픽시 유리대포).
func _ult_meteor(base: float, elem: String, col: Color) -> void:
	var targets := get_tree().get_nodes_in_group("enemies")
	for i in 10:
		var pos: Vector2 = player.position + Vector2(randf_range(-320, 320), randf_range(-320, 320))
		if targets.size() > 0:
			var t = targets[randi() % targets.size()]
			if is_instance_valid(t):
				pos = t.position
		var rad := 120.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and pos.distance_to(e.position) <= rad:
				e.take_damage(base * 1.4, true, false, elem)
		if boss and is_instance_valid(boss) and pos.distance_to(boss.position) <= rad:
			boss.take_damage(base * 1.4, true, elem)
		_spawn_proc_fx("burst", pos, rad, col, 0.4)
	_flash(Color(col.r, col.g, col.b, 0.4))
	shake_t = maxf(shake_t, 0.36)


# 빙결 결계: 전역 냉기 피해 + 강한 둔화 (이졸데·모르가나 컨트롤형).
func _ult_blizzard(base: float, elem: String, col: Color) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.take_damage(base * 0.8, true, false, elem)
			e.apply_slow(0.7, 4.0)
	if boss and is_instance_valid(boss):
		boss.take_damage(base * 3.0, true, elem)
	_flash(Color(col.r, col.g, col.b, 0.42))
	shake_t = maxf(shake_t, 0.3)
	_spawn_proc_fx("ring", player.position, 660.0, col, 0.7)
	_spawn_proc_fx("burst", player.position, 260.0, col.lightened(0.4), 0.5)


# 신성 심판: 전역 피해 + 자기 회복 (세라피나 서포터).
func _ult_judgment(base: float, elem: String, col: Color) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.take_damage(base * 1.1, true, false, elem)
			e.shove(player.position, 200.0)
	if boss and is_instance_valid(boss):
		boss.take_damage(base * 3.5, true, elem)
	player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.3)   # 심판의 가호: 30% 회복
	_flash(Color(col.r, col.g, col.b, 0.55))
	shake_t = maxf(shake_t, 0.34)
	_spawn_proc_fx("ring", player.position, 560.0, col, 0.6)
	_spawn_proc_fx("burst", player.position, 220.0, Color(1.0, 1.0, 0.82), 0.55)


# 암흑 수확: 전역 피해 + 흡혈 (구스타보·발렌티노·모르덱 근접 탱커/뱀파이어).
func _ult_reap(base: float, elem: String, col: Color) -> void:
	var dealt := 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			dealt += minf(maxf(0.0, e.hp), base * 1.2)
			e.take_damage(base * 1.2, true, false, elem)
			e.shove(player.position, 240.0)
	if boss and is_instance_valid(boss):
		boss.take_damage(base * 4.0, true, elem)
	player.hp = minf(player.max_hp, player.hp + dealt * 0.15)   # 수확 흡혈: 가한 피해의 15% 회복
	_flash(Color(col.r, col.g, col.b, 0.58))
	shake_t = maxf(shake_t, 0.4)
	_slowmo(0.4, 260)
	_spawn_proc_fx("ring", player.position, 540.0, col, 0.6)
	_spawn_proc_fx("burst", player.position, 240.0, col.lightened(0.3), 0.5)


func _unhandled_input(event: InputEvent) -> void:
	# I: 인벤토리 토글. 인벤 열린 상태에서 ESC도 닫기.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			_toggle_inventory()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and inventory_panel and inventory_panel.visible:
			_toggle_inventory()
			get_viewport().set_input_as_handled()
			return
	# Q: 궁극기 발동 (게이지 가득 찼을 때만, 플레이 중)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		if state == State.PLAYING and ult_gauge >= 1.0:
			_fire_ultimate()
			get_viewport().set_input_as_handled()
	# E: 현재 주무기 아키타입 액티브 / Space: 이동 방향 회피
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if state == State.PLAYING and skill_e_cd <= 0.0:
			if _fire_weapon_active():
				skill_e_cd = _weapon_active_cooldown()
				get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if state == State.PLAYING and player and player.try_dodge():
			play_sfx("dash", -10.0, 0.08)
			get_viewport().set_input_as_handled()
	# F3: 성능 카운터 토글
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		show_perf = not show_perf
		if perf_label:
			perf_label.visible = show_perf
		get_viewport().set_input_as_handled()
	# F4: 레트로 도트 후처리 프리셋 순환 (원본 → 640p → 480p → 427p)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		if postfx:
			postfx.cycle()
		get_viewport().set_input_as_handled()


# 치트 진입점 (PauseCatcher 시그널 — 타이틀·일시정지에서도 동작).
# 백쿼트(`) 또는 F12로 모드 토글. 한글 IME가 백쿼트를 먹는 경우 대비 F12 병행.
func _on_cheat_key(keycode: int) -> void:
	if keycode == KEY_QUOTELEFT or keycode == KEY_F12:
		cheat_mode = not cheat_mode
		_cheat_toast("치트 모드 " + ("ON — F1골드 F2렙업 F5회복 F6무적 F7+1분 F8상자 F9전멸 F10보스/해금" if cheat_mode else "OFF"))
		return
	if cheat_mode:
		_handle_cheat_key(keycode)


# 치트 실행. 플레이 중 치트는 cheated 플래그를 세워 그 런의 업적·기록·보상을 잠근다.
# F1(메타 골드)과 전체 해금은 의도적 치트라 즉시 저장한다.
func _handle_cheat_key(keycode: int) -> void:
	# 메뉴에서: F10 = 캐릭터·유물 전체 해금 (저장 후 타이틀 재시작으로 UI 반영)
	# 일시정지 중에는 제외 — 재시작으로 진행 중인 런이 날아가는 사고 방지.
	if state == State.PAUSED:
		return
	if state != State.PLAYING:
		if keycode == KEY_F10:
			for character in GameConfig.characters():
				meta.get_or_add("unlocked_chars", {})[str(character["key"])] = true
			for relic in RELIC_DEFS:
				meta.get_or_add("unlocked_relics", {})[str(relic["key"])] = true
			meta["stage_unlocked"] = FINAL_STAGE
			Meta.save_data(meta)
			get_tree().reload_current_scene()   # 선택창 잠금 UI는 생성 시점 고정이라 재시작으로 반영
		return
	match keycode:
		KEY_F1:
			meta["gold"] = int(meta["gold"]) + 1000
			Meta.save_data(meta)
			_cheat_toast("골드 +1000 (보유 %d)" % int(meta["gold"]))
		KEY_F2:
			cheated = true
			_gain_xp(maxi(1, xp_to_next - xp))
			_cheat_toast("레벨업")
		KEY_F5:
			cheated = true
			player.hp = player.max_hp
			_cheat_toast("체력 회복")
		KEY_F6:
			cheated = true
			cheat_invincible = not cheat_invincible
			player.invuln = 999999.0 if cheat_invincible else 0.0
			_cheat_toast("무적 " + ("ON" if cheat_invincible else "OFF"))
		KEY_F7:
			cheated = true
			time_survived += 60.0
			_cheat_toast("+1분 (%02d:%02d)" % [int(time_survived) / 60, int(time_survived) % 60])
		KEY_F8:
			cheated = true
			_open_bonus_chest()
			_cheat_toast("보물상자")
		KEY_F9:
			cheated = true
			var n := 0
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e):
					e.take_damage(999999.0)
					n += 1
			_cheat_toast("적 %d마리 처치" % n)
		KEY_F10:
			cheated = true
			_spawn_boss()
			_cheat_toast("보스 소환")


func _cheat_toast(text: String) -> void:
	if ach_toast:
		ach_toast.text = "⚙ " + text
		ach_toast.visible = true
		ach_toast_t = 2.0


func _toggle_pause() -> void:
	# 옵션 창이 열려 있으면 ESC로 옵션만 닫기
	if options_panel and options_panel.visible:
		Meta.save_data(meta)
		options_panel.visible = false
		return
	if state == State.PLAYING:
		state = State.PAUSED
		get_tree().paused = true
		_fill_pause_icons()
		_fill_stats_grid(pause_stats_box)
		pause_panel.visible = true
		play_sfx("select", -12.0)
	elif state == State.PAUSED:
		state = State.PLAYING
		get_tree().paused = false
		pause_panel.visible = false


func _build_pause_info() -> String:
	var t := "[ 스탯 ]\n"
	t += "체력 %d/%d   공격력 x%.2f   이속 %d\n" % [int(player.hp), int(player.max_hp), player.damage_mult, int(player.speed)]
	t += "방어 %d   재생 %.1f/s   쿨다운 x%.2f\n\n" % [int(player.armor), player.regen, player.cooldown_mult]
	# (무기/패시브는 위 아이콘 줄로 표시 — 텍스트는 스탯 위주)
	# 진화 조건 / 유니온 표는 제거 — 추후 '유물' 획득 시에만 공개 예정 (뱀서식 도감 언락)
	return t


# ---------------------------------------------------------------------
#  영구 강화 상점
# ---------------------------------------------------------------------
# 메뉴 화면 전환 (페이드 + 슬라이드 입장 연출)
func _goto_screen(target: Control) -> void:
	play_sfx("select", -12.0)
	for p in [title_panel, char_panel, stage_select_panel]:
		if p:
			p.visible = (p == target)
	target.modulate = Color(1, 1, 1, 0)
	target.position = Vector2(0, 26)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(target, "modulate:a", 1.0, 0.22)
	tw.tween_property(target, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 컨트롤러: 캐릭터 화면 진입 시 첫 카드에 포커스
	if target == char_panel and char_buttons.size() > 0:
		char_buttons[0].grab_focus()


func _select_char(c: Dictionary) -> void:
	if not _is_char_unlocked(c):
		return
	sel_char = c
	_update_char_buttons()
	_goto_screen(stage_select_panel)


func _select_stage(stage: int) -> void:
	sel_stage = clampi(stage, 1, FINAL_STAGE)
	if sel_diff.is_empty():
		sel_diff = _difficulty_by_key("normal")
	_start_game(sel_diff)


func _difficulty_by_key(key: String) -> Dictionary:
	var difficulties := GameConfig.difficulties()
	if difficulties.is_empty():
		return {}
	var fallback: Dictionary = difficulties[0]
	for difficulty in difficulties:
		if str(difficulty.get("key", "")) == "normal":
			fallback = difficulty
		if str(difficulty.get("key", "")) == key:
			return difficulty
	return fallback


func _choose_stage_difficulty(key: String) -> void:
	sel_diff = _difficulty_by_key(key)
	_refresh_stage_selection()
	play_sfx("select", -12.0)


func _choose_stage_card(stage: int) -> void:
	if stage < 1 or stage > FINAL_STAGE:
		return
	sel_stage = stage
	_refresh_stage_selection()
	play_sfx("select", -12.0)


func _confirm_stage_selection() -> void:
	_select_stage(sel_stage)


func _run_map_mouse_click_test() -> bool:
	unlocked_stage_count = FINAL_STAGE
	sel_stage = 1
	_refresh_stage_selection()
	_goto_screen(stage_select_panel)
	await get_tree().process_frame
	await get_tree().process_frame
	var errors: Array[String] = []
	if map_difficulty_buttons.size() != GameConfig.difficulties().size():
		errors.append("difficulty buttons were not built")
	else:
		map_difficulty_buttons[-1].emit_signal("pressed")
		await get_tree().process_frame
		if str(sel_diff.get("key", "")) != "nightmare":
			errors.append("difficulty button did not select nightmare")
	if map_blessing_button == null:
		errors.append("blessing button was not built")
	else:
		map_blessing_button.emit_signal("pressed")
		await get_tree().process_frame
		if str(sel_modifier.get("key", "none")) == "none":
			errors.append("blessing button did not advance the blessing")
	for requested_stage in range(2, FINAL_STAGE + 1):
		var target := map_cards[requested_stage - 1]
		var click_pos := target.get_global_rect().get_center()
		var move := InputEventMouseMotion.new()
		move.position = click_pos
		move.global_position = click_pos
		Input.parse_input_event(move)
		await get_tree().process_frame
		var hovered := get_viewport().gui_get_hovered_control()
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = click_pos
		press.global_position = click_pos
		Input.parse_input_event(press)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = click_pos
		release.global_position = click_pos
		Input.parse_input_event(release)
		await get_tree().process_frame
		var hover_name := hovered.get_path() if hovered else NodePath("<none>")
		print("MAP_MOUSE_CLICK stage=%d hover=%s selected=%d" % [requested_stage, hover_name, sel_stage])
		if sel_stage != requested_stage:
			errors.append("stage %d hover=%s selected=%d" % [requested_stage, hover_name, sel_stage])
	var enter_pos := map_confirm_button.get_global_rect().get_center()
	var enter_press := InputEventMouseButton.new()
	enter_press.button_index = MOUSE_BUTTON_LEFT
	enter_press.pressed = true
	enter_press.position = enter_pos
	enter_press.global_position = enter_pos
	Input.parse_input_event(enter_press)
	var enter_release := InputEventMouseButton.new()
	enter_release.button_index = MOUSE_BUTTON_LEFT
	enter_release.pressed = false
	enter_release.position = enter_pos
	enter_release.global_position = enter_pos
	Input.parse_input_event(enter_release)
	await get_tree().process_frame
	print("MAP_ENTER_CLICK selected=%d state=%d" % [sel_stage, state])
	if state != State.PLAYING:
		errors.append("map enter button did not start the run")
	var passed := errors.is_empty()
	print("MAP_MOUSE_CLICK_TEST %s" % ["PASS" if passed else "FAIL"])
	for error in errors:
		push_error(error)
	return passed


func _refresh_stage_selection() -> void:
	if sel_diff.is_empty():
		sel_diff = _difficulty_by_key("normal")
	if map_cards.is_empty():
		return
	sel_stage = clampi(sel_stage if sel_stage > 0 else 1, 1, FINAL_STAGE)
	var selected_data: Dictionary = GameConfig.stage_info(sel_stage)
	var difficulty: Dictionary = sel_diff
	# 던전별 몹 테마 안내 (stage_roster와 일치).
	var mob_themes := ["언데드", "화염", "냉기", "공허", "마족"]
	if map_detail_label:
		var wk := str(selected_data.get("boss_weak", ""))
		var weak_hint := "보스 약점: %s" % str(ELEMENT_NAME.get(wk, "")) if wk != "" else "보스 약점: 없음"
		var spawn_rate := 1.0 / maxf(0.01, float(difficulty.get("spawn", 1.0)))
		map_detail_label.text = "%d. %s · %s 몹 · %s · 5분 후 보스\n[%s] 적 HP ×%.2f · 출현 ×%.2f  /  골드 ×%.2f · 장비 ×%.2f" % [
			sel_stage, selected_data["name"], mob_themes[sel_stage - 1], weak_hint,
			difficulty.get("label", "보통"), difficulty.get("enemy_hp", 1.0), spawn_rate,
			difficulty.get("gold", 1.0), difficulty.get("gear", 1.0)
		]
	if map_confirm_button:
		map_confirm_button.disabled = sel_stage > unlocked_stage_count
		map_confirm_button.text = "%s 입장" % str(selected_data["name"])
	var selected_difficulty_key := str(difficulty.get("key", "normal"))
	for difficulty_index in map_difficulty_buttons.size():
		var difficulty_button := map_difficulty_buttons[difficulty_index]
		var difficulty_data: Dictionary = GameConfig.difficulties()[difficulty_index]
		var is_difficulty_selected := str(difficulty_data.get("key", "")) == selected_difficulty_key
		difficulty_button.text = "%s%s · %s" % [
			"◆ " if is_difficulty_selected else "",
			difficulty_data.get("label", ""),
			difficulty_data.get("reward_tag", "")
		]
		difficulty_button.modulate = (difficulty_data.get("color", Color.WHITE)
			if is_difficulty_selected else Color(0.56, 0.57, 0.64))
	for card_index in map_cards.size():
		var stage_no := card_index + 1
		var card := map_cards[card_index]
		var unlocked := stage_no <= unlocked_stage_count
		var is_selected := stage_no == sel_stage and unlocked
		card.modulate = Color.WHITE if unlocked else Color(0.42, 0.42, 0.48)
		card.add_theme_color_override("font_color", Color(1.0, 0.91, 0.52) if is_selected else Color(0.95, 0.9, 0.76))
		map_selection_borders[card_index].visible = is_selected
		map_selection_badges[card_index].visible = is_selected


func _stage_record_summary(stage: int) -> String:
	var mode_key := "campaign" if stage == 0 else "stage_%d" % stage
	var best_time := 0.0
	var total_clears := 0
	for record_key in meta.get("records", {}).keys():
		if not str(record_key).begins_with(mode_key + "|"):
			continue
		var record: Dictionary = meta.get("records", {}).get(record_key, {})
		best_time = maxf(best_time, float(record.get("best_time", 0.0)))
		total_clears += int(record.get("clears", 0))
	if best_time <= 0.0 and total_clears <= 0:
		return "기록 없음"
	return "최고 %02d:%02d · 클리어 %d회" % [int(best_time) / 60, int(best_time) % 60, total_clears]


func _update_char_buttons() -> void:
	# 선택된 타일만 밝게 (뱀서: 선택 타일이 강조되고 좌측 스탯·하단 상세가 그 캐릭터를 가리킴)
	var chars := GameConfig.characters()
	for i in char_buttons.size():
		var on: bool = i < chars.size() and chars[i].get("key", "") == sel_char.get("key", "")
		var unlocked: bool = i < chars.size() and _is_char_unlocked(chars[i])
		char_buttons[i].modulate = (Color(1.45, 1.4, 1.1) if on else Color(0.72, 0.72, 0.78)) if unlocked else Color(0.72, 0.72, 0.78)


# 캐릭터 타일 미리보기 (확정 아님): 좌측 세부 스탯 + 하단 상세 갱신.
func _preview_char(c: Dictionary) -> void:
	if c.is_empty() or not _is_char_unlocked(c):
		return
	sel_char = c
	_update_char_buttons()
	if char_det_name:
		var col: Color = GameConfig.char_stages(c["key"])[0]["color"]
		char_det_name.text = c["name"]
		char_det_name.add_theme_color_override("font_color", col.lerp(Color(1, 1, 1), 0.72))
	if char_det_spr:
		var pt := Assets.tex("res://assets/ui/portrait_%s.png" % c["key"])
		if pt == null:
			pt = Assets.tex("res://assets/hero/%s_1.png" % c["key"])
		char_det_spr.texture = pt
	if char_det_wicon:
		char_det_wicon.texture = Assets.tex(WICON.get(c.get("weapon", ""), ""))
	if char_det_desc:
		var t: String = str(c.get("desc", ""))
		if c.has("trait"):
			t += "\n★ %s — %s" % [c["trait"], c.get("trait_desc", "")]
		char_det_desc.text = t
	_fill_char_stats(c)


# 캐릭터 선택 좌측 세부 스탯 (뱀서식): 기준 대비 증감을 전부 나열.
func _fill_char_stats(c: Dictionary) -> void:
	if char_stats_box == null:
		return
	for ch in char_stats_box.get_children():
		ch.queue_free()
	var II := "res://assets/items/"
	var hp_mul := float(c.get("hp", 1.0))
	_stat_row(char_stats_box, II + "icon_voidheart.png", "최대 체력", "%d" % int(round(150.0 * hp_mul)))
	_stat_row(char_stats_box, II + "icon_wings.png", "이동 속도", _stat_pct(float(c.get("speed", 1.0))))
	# cd는 낮을수록 빠름 → 쿨감으로 환산해 표기
	var cdv := float(c.get("cd", 1.0))
	_stat_row(char_stats_box, II + "icon_tome.png", "쿨타임", "-" if is_equal_approx(cdv, 1.0) else "%+d%%" % int(round((cdv - 1.0) * 100.0)))
	_stat_row(char_stats_box, II + "icon_candela.png", "공격 범위", _stat_pct(float(c.get("range", 1.0))))
	_stat_row(char_stats_box, II + "icon_spinach.png", "근접 피해", _stat_pct(float(c.get("melee", 1.0))))
	_stat_row(char_stats_box, II + "icon_keeneye.png", "원거리 피해", _stat_pct(float(c.get("ranged", 1.0))))
	var wk: String = str(c.get("weapon", ""))
	_stat_row(char_stats_box, WICON.get(wk, ""), "시작 무기", str(WNAMES.get(wk, wk)))
	if c.has("weapon2"):
		var w2: String = str(c["weapon2"])
		_stat_row(char_stats_box, WICON.get(w2, ""), "추가 무기", str(WNAMES.get(w2, w2)))


func _open_shop() -> void:
	_refresh_shop()
	shop_panel.visible = true


func _refresh_shop() -> void:
	shop_gold_label.text = "보유 골드: %d G" % meta["gold"]
	for i in Meta.UPGRADES.size():
		var u: Dictionary = Meta.UPGRADES[i]
		var lv: int = meta["up"].get(u["key"], 0)
		var b: Button = shop_buttons[i]
		if lv >= int(u["max"]):
			b.text = "%s  Lv %d/%d  [최대]\n%s" % [u["name"], lv, u["max"], _up_summary(u["key"], lv)]
			b.disabled = true
		else:
			var c := Meta.cost(u, lv)
			b.text = "%s  Lv %d/%d  [%d G]\n%s" % [u["name"], lv, u["max"], c, _up_summary(u["key"], lv)]
			b.disabled = int(meta["gold"]) < c


# 강화 현재값 → 다음값 요약 (가시성). max 도달 시 현재값만.
func _up_summary(key: String, lv: int) -> String:
	var atmax: bool = lv >= int(Meta.UPGRADES[_up_idx(key)]["max"])
	match key:
		"amount":
			return "투사체 +%d%s" % [lv / 2, "" if atmax else " → +%d" % ((lv + 1) / 2)]
		"revive":
			return "부활 %d회%s" % [lv, "" if atmax else " → %d회" % (lv + 1)]
	var unit := {"dmg": 4.0, "hp": 10.0, "speed": 3.0, "cd": -2.0, "magnet": 12.0,
		"regen": 0.2, "armor": 1.0, "area": 5.0, "greed": 12.0, "xp": 8.0, "luck": 8.0}
	if not unit.has(key):
		return ""
	var u: float = unit[key]
	var pct: bool = key in ["dmg", "speed", "cd", "area", "greed", "xp", "luck"]
	var suf: String = "%" if pct else ""
	var cur: float = u * lv
	var nxt: float = u * (lv + 1)
	if key == "regen":
		return "현재 +%.1f%s" % [cur, suf] if atmax else "현재 +%.1f → +%.1f%s" % [cur, nxt, suf]
	return "현재 %+d%s" % [int(cur), suf] if atmax else "현재 %+d → %+d%s" % [int(cur), int(nxt), suf]


func _up_idx(key: String) -> int:
	for i in Meta.UPGRADES.size():
		if Meta.UPGRADES[i]["key"] == key:
			return i
	return 0


func _buy_upgrade(idx: int) -> void:
	var u: Dictionary = Meta.UPGRADES[idx]
	var lv: int = meta["up"].get(u["key"], 0)
	if lv >= int(u["max"]):
		return
	var c := Meta.cost(u, lv)
	if int(meta["gold"]) < c:
		return
	meta["gold"] = int(meta["gold"]) - c
	meta["up"][u["key"]] = lv + 1
	Meta.save_data(meta)
	if title_gold_label:
		title_gold_label.text = "보유 골드: %d G" % meta["gold"]
	_refresh_shop()


# 영구 강화 전체 초기화 + 구매한 골드 전액 환불
func _reset_upgrades() -> void:
	var refund := 0
	for u in Meta.UPGRADES:
		var lv: int = meta["up"].get(u["key"], 0)
		for i in lv:
			refund += Meta.cost(u, i)   # i→i+1 강화 비용 = 실제 소모액
		meta["up"][u["key"]] = 0
	meta["gold"] = int(meta["gold"]) + refund
	Meta.save_data(meta)
	play_sfx("coin", -8.0)
	_refresh_shop()


# --- 업적 시스템 ---
func _ach_by_key(key: String) -> Dictionary:
	for a in ACHIEVEMENTS:
		if a["key"] == key:
			return a
	return {}


func _is_char_unlocked(character: Dictionary) -> bool:
	var key := str(character.get("key", ""))
	if str(character.get("unlock", "")) == "":
		return true
	return bool(meta.get("unlocked_chars", {}).get(key, false))


func _has_relic(key: String) -> bool:
	return bool(meta.get("unlocked_relics", {}).get(key, false))


# 이미 달성한 업적도 로드 시 동기화하여 구버전 저장의 해금 누락을 복구한다.
func _sync_meta_unlocks() -> Array[String]:
	var newly_unlocked: Array[String] = []
	var unlocked_chars: Dictionary = meta.get_or_add("unlocked_chars", {})
	var achievements: Dictionary = meta.get_or_add("ach", {})
	for character in GameConfig.characters():
		var character_key := str(character["key"])
		var requirement := str(character.get("unlock", ""))
		if requirement == "":
			unlocked_chars[character_key] = true
		elif achievements.get(requirement, false) and not unlocked_chars.get(character_key, false):
			unlocked_chars[character_key] = true
			newly_unlocked.append("캐릭터: " + str(character["name"]))
	# 유물도 업적 달성 시 영구 해금한다(캐릭터와 동일 규칙). 이전에는 캐릭터만 동기화돼
	# yellow_sign·milky_map 등이 조건을 채워도 해금되지 않았다.
	var unlocked_relics: Dictionary = meta.get_or_add("unlocked_relics", {})
	for relic in RELIC_DEFS:
		var relic_key := str(relic["key"])
		var relic_req := str(relic.get("unlock", ""))
		if relic_req != "" and achievements.get(relic_req, false) and not unlocked_relics.get(relic_key, false):
			unlocked_relics[relic_key] = true
			newly_unlocked.append("유물: " + str(relic["name"]))
	return newly_unlocked


func _achievement_unlock_rewards(achievement_key: String) -> Array[String]:
	var rewards: Array[String] = []
	for character in GameConfig.characters():
		if str(character.get("unlock", "")) == achievement_key:
			rewards.append(str(character["name"]))
	return rewards


func _grant_ach(key: String) -> void:
	if cheated:
		return   # 치트 런에서는 업적·해금 잠금
	if meta.get("ach", {}).get(key, false):
		return
	if not meta.has("ach"):
		meta["ach"] = {}
	meta["ach"][key] = true
	var a := _ach_by_key(key)
	meta["gold"] = int(meta["gold"]) + int(a.get("gold", 0))
	var new_unlocks := _sync_meta_unlocks()
	Meta.save_data(meta)
	play_sfx("levelup", -6.0)
	if ach_toast:
		ach_toast.text = "★ 업적 달성: %s  (+%d G)" % [a.get("name", key), int(a.get("gold", 0))]
		if not new_unlocks.is_empty():
			ach_toast.text += "\n해금 — " + " · ".join(new_unlocks)
		ach_toast.visible = true
		ach_toast_t = 3.5

# 매 프레임 판정 (플레이 중)
func _check_achievements() -> void:
	if kills >= 800:
		_grant_ach("slayer")
	if time_survived >= 900.0:
		_grant_ach("survivor")
	if level >= 75:
		_grant_ach("evolved")
	if unions.size() >= 1:
		_grant_ach("combo_master")
	if run_bosses >= 4:
		_grant_ach("boss_slayer")
	if int(meta.get("gold", 0)) + run_gold >= 3000:
		_grant_ach("rich")
	if abyss_mode and stage_num >= FINAL_STAGE + 5:
		_grant_ach("abyss")
	for k in evolved.keys():
		if evolved[k]:
			_grant_ach("legend_weapon")
			break


# ---------------------------------------------------------------------
#  UI 스타일 헬퍼 (assets/ui/*.png 있으면 자동 적용, 없으면 기본)
#  뱀서 메뉴는 파란회색 패널 + 금테 오르네이트가 정답 — 플랫로 갔다가 되돌림.
# ---------------------------------------------------------------------
func _sbtex(path: String, m: float, cm_v: float = -1.0) -> StyleBoxTexture:
	var t := Assets.tex(path)
	if t == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	# 상하 내용 여백: cm_v>=0이면 그 값을 사용(버튼 최소높이↓ → 버튼 간격 확보). 기본은 m.
	var v: float = m if cm_v < 0.0 else cm_v
	sb.content_margin_left = m + 6.0
	sb.content_margin_right = m + 6.0
	sb.content_margin_top = v
	sb.content_margin_bottom = v
	return sb


func _style_button(b: Button, path: String, m: float = 22.0, cm_v: float = -1.0) -> void:
	var sb := _sbtex(path, m, cm_v)
	if sb == null:
		return
	b.add_theme_stylebox_override("normal", sb)
	var sbh := _sbtex(path, m, cm_v)
	sbh.modulate_color = Color(1.2, 1.2, 1.2)
	b.add_theme_stylebox_override("hover", sbh)
	var sbp := _sbtex(path, m, cm_v)
	sbp.modulate_color = Color(0.8, 0.8, 0.8)
	b.add_theme_stylebox_override("pressed", sbp)
	# 포커스(컨트롤러)용도 hover와 동일 프레임
	var sbf := _sbtex(path, m, cm_v)
	sbf.modulate_color = Color(1.3, 1.3, 1.1)
	b.add_theme_stylebox_override("focus", sbf)
	# 잠김/최대 강화 버튼도 기본 Godot 테마로 빠지지 않게 같은 프레임을 유지한다.
	# 이전에는 disabled 스타일이 없어 스테이지·캐릭터·상점 카드가 배경과 섞였다.
	var sbd := _sbtex(path, m, cm_v)
	sbd.modulate_color = Color(0.48, 0.48, 0.54, 1.0)
	b.add_theme_stylebox_override("disabled", sbd)
	b.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.9))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 0.9))
	b.add_theme_color_override("font_disabled_color", Color(0.68, 0.68, 0.74))


# HUD 패널 스타일 (다크 네이비 + 금 테두리 — 뱃지/게이지와 통일)
func _hud_style() -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.08, 0.92)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.55, 0.43, 0.22)
	sb.set_corner_radius_all(7)
	return sb


# 메뉴 창 배경 (오르네이트 픽셀 패널 9-slice, 없으면 금테 폴백)
func _menu_style() -> StyleBox:
	var sb := _sbtex("res://assets/ui/menu_panel.png", 88.0)
	if sb:
		return sb
	return _hud_style()


# 캐릭터 선택 타일 (뱀서: 창틀만 오르네이트, 타일은 단순 금테 상자 — 파란회색 채움).
# card_rare.png 같은 장식 프레임을 쓰면 상단 장식이 이름을 덮는다.
func _style_tile(b: Button) -> void:
	var mk := func(bg: Color, bc: Color, bw: int) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_border_width_all(bw)
		sb.border_color = bc
		sb.set_corner_radius_all(4)
		return sb
	b.add_theme_stylebox_override("normal", mk.call(Color(0.20, 0.22, 0.32, 0.96), Color(0.62, 0.50, 0.24), 2))
	b.add_theme_stylebox_override("hover", mk.call(Color(0.28, 0.30, 0.42, 0.98), Color(0.95, 0.80, 0.38), 3))
	b.add_theme_stylebox_override("pressed", mk.call(Color(0.32, 0.34, 0.46, 1.0), Color(1.0, 0.88, 0.45), 3))
	b.add_theme_stylebox_override("focus", mk.call(Color(0.28, 0.30, 0.42, 0.98), Color(0.95, 0.80, 0.38), 3))
	b.add_theme_stylebox_override("disabled", mk.call(Color(0.075, 0.08, 0.12, 0.98), Color(0.32, 0.30, 0.38), 2))


# 인벤토리 아이콘 슬롯 스타일 (작은 금테 소켓)
func _slot_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.09, 0.13, 0.96)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.5, 0.4, 0.22)
	sb.set_corner_radius_all(5)
	return sb


func _make_hud_panel(pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.add_theme_stylebox_override("panel", _hud_style())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _bar_bg() -> StyleBoxFlat:
	# HUD 게이지 배경 (다크 + 금 테두리)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.08)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.62, 0.48, 0.24)
	sb.set_corner_radius_all(5)
	return sb


func _fill_box(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(4)
	return sb


func _flatbox(bg: Color, corner: float = 4.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = corner
	sb.corner_radius_top_right = corner
	sb.corner_radius_bottom_left = corner
	sb.corner_radius_bottom_right = corner
	return sb


# 모달 창 공통 규칙: 작은 창에서도 화면 밖으로 나가지 않도록 현재 뷰포트 안에 맞춘다.
# 기존 인벤토리/대장간은 920×600 절대 좌표라 작은 창에서 하단 버튼과 상세 정보가 겹쳤다.
func _modal_rect(view: Vector2, preferred: Vector2 = Vector2(1120, 640), margin: float = 24.0) -> Rect2:
	var max_size := Vector2(maxf(1.0, view.x - margin * 2.0), maxf(1.0, view.y - margin * 2.0))
	var panel_size := Vector2(minf(preferred.x, max_size.x), minf(preferred.y, max_size.y))
	return Rect2((view - panel_size) * 0.5, panel_size)


# 인벤토리/대장간 내부 섹션 공통 카드. 금 테두리는 창틀보다 약하게 두어 정보 계층을 만든다.
func _section_style(accent: Color = Color(0.34, 0.31, 0.43, 0.9)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.042, 0.07, 0.82)
	sb.set_border_width_all(1)
	sb.border_color = accent
	sb.set_corner_radius_all(5)
	return sb


func _inv_slot(icon_path: String, lvl: String, fallback: String, evolvable: bool = false, max_pips: int = 8) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	# 아이콘 슬롯 (다크 + 금테 소켓)
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(32, 32)
	slot.add_theme_stylebox_override("panel", _slot_style())
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 진화 가능: 슬롯을 금빛으로 맥동시켜 "진화 준비 완료" 신호
	if evolvable:
		var tw := create_tween().set_loops()
		tw.tween_property(slot, "modulate", Color(1.7, 1.45, 0.7), 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(slot, "modulate", Color(1.0, 1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	var t := Assets.tex(icon_path)
	if t:
		var tr := TextureRect.new()
		tr.texture = t
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 3.0
		tr.offset_top = 3.0
		tr.offset_right = -3.0
		tr.offset_bottom = -3.0
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tr)
	else:
		var nl := Label.new()
		nl.text = fallback
		nl.set_anchors_preset(Control.PRESET_FULL_RECT)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nl.add_theme_font_size_override("font_size", 10)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(nl)
	v.add_child(slot)
	# 레벨 표기: 진화 준비면 "▲진화", 숫자면 뱀서식 핍(칸) 채우기, 그 외(★ 등)는 라벨
	if evolvable:
		var el := Label.new()
		el.text = "▲진화"
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		el.add_theme_font_size_override("font_size", 9)
		el.add_theme_constant_override("outline_size", 3)
		el.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		el.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		v.add_child(el)
	elif lvl.is_valid_int() and max_pips > 0:
		v.add_child(_level_pips(lvl.to_int(), max_pips))
	else:
		var l := Label.new()
		l.text = lvl
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_constant_override("outline_size", 3)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5) if lvl == "★" else Color(0.92, 0.92, 0.96))
		v.add_child(l)
	return v


# 뱀서식 레벨 핍: 최대치만큼 칸을 만들고 현재 레벨만큼 금색으로 채움 (만렙이면 초록빛)
func _level_pips(lvl: int, max_pips: int) -> Control:
	var filled: int = clampi(lvl, 0, max_pips)
	var at_max: bool = filled >= max_pips
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(32, 5)
	var pw: float = 3.0 if max_pips > 6 else 4.0
	for i in max_pips:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(pw, 4)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < filled:
			pip.color = Color(0.55, 0.95, 0.55) if at_max else Color(1.0, 0.83, 0.32)   # 채움: 금색(만렙=초록)
		else:
			pip.color = Color(0.18, 0.17, 0.22)   # 빈 칸: 어두움
		row.add_child(pip)
	return row


func _populate_end_build() -> void:
	# 결과창 최종 빌드: 무기 행 + 패시브 행 (뱀서식 리뷰)
	if end_build_box == null:
		return
	for c in end_build_box.get_children():
		c.queue_free()
	var pdefs := _passive_defs()
	var wrow := HBoxContainer.new()
	wrow.alignment = BoxContainer.ALIGNMENT_CENTER
	wrow.add_theme_constant_override("separation", 4)
	for kind in ALL_WEAPONS:
		if weapons.has(kind):
			var lvl := "★" if evolved.get(kind, false) else str(weapons[kind])
			wrow.add_child(_inv_slot(WICON.get(kind, ""), lvl, str(kind).substr(0, 2)))
	end_build_box.add_child(wrow)
	if passives.size() > 0:
		var prow := HBoxContainer.new()
		prow.alignment = BoxContainer.ALIGNMENT_CENTER
		prow.add_theme_constant_override("separation", 4)
		for key in passives.keys():
			prow.add_child(_inv_slot(PICON.get(key, ""), str(passives[key]), pdefs[key]["name"].substr(0, 2), false, MAX_PLEVEL))
		end_build_box.add_child(prow)


func _is_evolvable(kind: String) -> bool:
	# 진화 준비 완료: 만렙 + 미진화 + 요구 패시브 보유 (보물상자에서 진화 발동 조건)
	if not EVO_RECIPE.has(kind):
		return false
	if evolved.get(kind, false):
		return false
	if weapons.get(kind, 0) < MAX_WLEVEL:
		return false
	return passives.get(EVO_RECIPE[kind]["passive"], 0) >= 1


func _refresh_inventory_ui() -> void:
	for c in inv_weapons_box.get_children():
		c.queue_free()
	for c in inv_passives_box.get_children():
		c.queue_free()
	var wnames := {"arrow": "화살", "blade": "검", "aura": "오라", "lightning": "번개", "frost": "서리", "knife": "칼",
		"fireball": "파이어", "boomerang": "부메랑", "holy": "천벌", "venom": "독날", "whip": "채찍", "excalibur": "엑스칼리버", "void_orb": "공허구"}
	var pdefs := _passive_defs()
	var wcount := 0
	for kind in ALL_WEAPONS:
		if weapons.has(kind):
			var lvl := "★" if evolved.get(kind, false) else str(weapons[kind])
			inv_weapons_box.add_child(_inv_slot(WICON.get(kind, ""), lvl, wnames.get(kind, kind), _is_evolvable(kind)))
			wcount += 1
	var pcount := 0
	for key in passives.keys():
		var pname: String = pdefs[key]["name"].substr(0, 2)
		inv_passives_box.add_child(_inv_slot(PICON.get(key, ""), str(passives[key]), pname, false, MAX_PLEVEL))
		pcount += 1
	# 뱀서식: 좌상단(전폭 XP 바 아래) 무기 줄 + 패시브 줄
	inv_weapons_box.position = Vector2(14, 30)
	inv_passives_box.position = Vector2(14, 84)
	# 인벤토리 배경 패널 (내용에 딱 맞게)
	var maxc: int = max(wcount, pcount)
	inv_bg.position = Vector2(6, 24)
	inv_bg.size = Vector2(maxc * 36.0 + 20.0, 114 if pcount > 0 else 58)
	inv_bg.visible = true


# ---------------------------------------------------------------------
#  UI
# ---------------------------------------------------------------------
func _build_ui(s: Vector2) -> void:
	# 레트로 후처리(레버2): 월드(layer0) 위, HUD 아래에 얹어 월드만 픽셀화. 기본 OFF.
	postfx = PostFX.new()
	add_child(postfx)

	var hud := CanvasLayer.new()
	hud.layer = 2   # PostFX(1) 위 → HUD는 항상 선명
	add_child(hud)

	# ─ 뱀서식 HUD ─
	# 최상단 전폭 XP 바 · 상단 중앙 대형 타이머 · 좌상단 아이콘 2줄 · 우상단 수치.
	# (옛 좌상단 오르네이트 뱃지 클러스터/하단 바는 제거 — 뱀서엔 없음)
	inv_bg = Panel.new()
	inv_bg.add_theme_stylebox_override("panel", _hud_style())
	inv_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_bg.visible = false
	hud.add_child(inv_bg)

	# XP 게이지 — 화면 최상단 전폭 (뱀서 시그니처)
	var xh := 18.0
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.max_value = xp_to_next
	xp_bar.value = xp
	xp_bar.add_theme_stylebox_override("background", _bar_bg())
	xp_bar.add_theme_stylebox_override("fill", _fill_box(Color(0.30, 0.70, 1.0)))
	xp_bar.position = Vector2.ZERO
	xp_bar.size = Vector2(s.x, xh)
	hud.add_child(xp_bar)

	# 궁극기 게이지 (하단 중앙 어빌리티 바 — RPG식 능동 스킬)
	ult_bar = ProgressBar.new()
	ult_bar.show_percentage = false
	ult_bar.max_value = 1.0
	ult_bar.value = 0.0
	ult_bar.add_theme_stylebox_override("background", _bar_bg())
	ult_bar.add_theme_stylebox_override("fill", _fill_box(Color(0.72, 0.42, 1.0)))
	ult_bar.size = Vector2(300, 18)
	ult_bar.position = Vector2(s.x / 2.0 - 150, s.y - 34)
	hud.add_child(ult_bar)
	ult_bar_label = Label.new()
	ult_bar_label.position = Vector2(s.x / 2.0 - 150, s.y - 34)
	ult_bar_label.size = Vector2(300, 18)
	ult_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ult_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ult_bar_label.add_theme_font_size_override("font_size", 12)
	ult_bar_label.add_theme_constant_override("outline_size", 3)
	ult_bar_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	ult_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ult_bar_label)
	# 현재 무기 E 이름 / Space 회피 상태 표시 (궁극 바 위)
	skill_hud_label = Label.new()
	skill_hud_label.position = Vector2(s.x / 2.0 - 240, s.y - 54)
	skill_hud_label.size = Vector2(480, 18)
	skill_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_hud_label.add_theme_font_size_override("font_size", 12)
	skill_hud_label.add_theme_constant_override("outline_size", 3)
	skill_hud_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	skill_hud_label.add_theme_color_override("font_color", Color(0.7, 0.95, 1.0))
	skill_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(skill_hud_label)
	# 장착 장비 3슬롯 (좌하단)
	equip_hud_label = Label.new()
	equip_hud_label.position = Vector2(10, s.y - 78)
	equip_hud_label.size = Vector2(280, 68)
	equip_hud_label.add_theme_font_size_override("font_size", 12)
	equip_hud_label.add_theme_constant_override("outline_size", 3)
	equip_hud_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	equip_hud_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
	equip_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(equip_hud_label)

	# 레벨 표기 (XP 바 안쪽 좌측)
	lv_label = Label.new()
	lv_label.position = Vector2(8, 0)
	lv_label.size = Vector2(120, xh)
	lv_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv_label.add_theme_font_size_override("font_size", 12)
	lv_label.add_theme_constant_override("outline_size", 4)
	lv_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lv_label.add_theme_color_override("font_color", Color(1, 1, 1))
	lv_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(lv_label)

	# 생존 타이머 — 상단 중앙 대형 (뱀서 시그니처)
	timer_label = Label.new()
	timer_label.position = Vector2(0, xh + 6.0)
	timer_label.size = Vector2(s.x, 44)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 34)
	timer_label.add_theme_constant_override("outline_size", 6)
	timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	timer_label.add_theme_color_override("font_color", Color(1, 1, 1))
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(timer_label)

	# HP는 뱀서처럼 캐릭터 발밑 바로 표시(Player._draw) → HUD 게이지는 숨김.
	# 참조는 유지: _update_ui 등 기존 코드가 그대로 값을 씀.
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	hp_bar.visible = false
	hud.add_child(hp_bar)
	hp_text = Label.new()
	hp_text.visible = false
	hud.add_child(hp_text)

	# 우상단 수치 (스테이지·처치·골드)
	info_label = Label.new()
	info_label.position = Vector2(s.x - 240.0, xh + 6.0)
	info_label.size = Vector2(228.0, 46)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_constant_override("outline_size", 4)
	info_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	info_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(info_label)

	# 인벤토리 (우상단: 무기 줄 + 패시브 줄)
	inv_weapons_box = HBoxContainer.new()
	inv_weapons_box.add_theme_constant_override("separation", 4)
	hud.add_child(inv_weapons_box)
	inv_passives_box = HBoxContainer.new()
	inv_passives_box.add_theme_constant_override("separation", 4)
	hud.add_child(inv_passives_box)

	# 국면 표시 (타이머 바로 아래 중앙 — 보스전/심연층)
	skill_label = Label.new()
	skill_label.position = Vector2(20, 68)
	skill_label.size = Vector2(s.x - 40, 22)
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skill_label.add_theme_font_size_override("font_size", 13)
	skill_label.add_theme_constant_override("outline_size", 4)
	skill_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	skill_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	hud.add_child(skill_label)

	# 업적 달성 토스트 (상단 중앙, 잠시 표시 후 사라짐)
	ach_toast = Label.new()
	ach_toast.position = Vector2(0, 150)   # 좌상단 아이콘 2줄 아래
	ach_toast.size = Vector2(s.x, 30)
	ach_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ach_toast.add_theme_font_size_override("font_size", 18)
	ach_toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	ach_toast.add_theme_constant_override("outline_size", 5)
	ach_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	ach_toast.visible = false
	ach_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ach_toast)

	# 스테이지 전환 배너
	stage_label = Label.new()
	stage_label.visible = false
	stage_label.position = Vector2(0, 300)
	stage_label.size = Vector2(s.x, 60)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.add_theme_font_size_override("font_size", 42)
	stage_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	hud.add_child(stage_label)

	# 성능 카운터 (우상단, 부하 테스트용)
	perf_label = Label.new()
	perf_label.position = Vector2(s.x - 190.0, 78.0)   # 전폭 XP 바·우상단 수치와 겹치지 않게
	perf_label.size = Vector2(180.0, 44.0)
	perf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	perf_label.add_theme_font_size_override("font_size", 16)
	perf_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	perf_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	perf_label.add_theme_constant_override("outline_size", 4)
	perf_label.visible = show_perf
	hud.add_child(perf_label)

	var overlay := CanvasLayer.new()
	ui_overlay = overlay   # 런타임 오버레이(룰렛 등) 추가용 참조
	overlay.layer = 10
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	flash_overlay = FlashOverlay.new()
	overlay.add_child(flash_overlay)
	_build_inventory_ui(s, overlay)   # 인벤토리 패널 (I 토글)
	add_child(overlay)

	# 레벨업 패널
	levelup_panel = Control.new()
	levelup_panel.visible = false
	overlay.add_child(levelup_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.position = Vector2.ZERO
	dim.size = s
	levelup_panel.add_child(dim)

	levelup_title = Label.new()
	levelup_title.position = Vector2(0, 100)
	levelup_title.size = Vector2(s.x, 44)
	levelup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	levelup_title.add_theme_font_size_override("font_size", 28)
	levelup_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	levelup_panel.add_child(levelup_title)

	# 뱀서식: 상단 보유 무기·패시브 아이콘 줄
	lvl_inv = HBoxContainer.new()
	lvl_inv.position = Vector2(0, 150)
	lvl_inv.size = Vector2(s.x, 40)
	lvl_inv.alignment = BoxContainer.ALIGNMENT_CENTER
	lvl_inv.add_theme_constant_override("separation", 6)
	lvl_inv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	levelup_panel.add_child(lvl_inv)

	# 좌측 스탯 패널 (뱀서식 — 현재 능력치 전체)
	var stats_bg := Panel.new()
	stats_bg.position = Vector2(14, 196)
	stats_bg.size = Vector2(236, 372)
	stats_bg.add_theme_stylebox_override("panel", _slot_style())
	stats_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	levelup_panel.add_child(stats_bg)
	lvl_stats_box = GridContainer.new()
	lvl_stats_box.columns = 3
	lvl_stats_box.position = Vector2(28, 206)
	lvl_stats_box.add_theme_constant_override("h_separation", 8)
	lvl_stats_box.add_theme_constant_override("v_separation", 5)
	lvl_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	levelup_panel.add_child(lvl_stats_box)

	# 뱀서식: 세로 리스트 행 (아이콘 왼쪽 + 이름·레벨·설명). 카드형 대신.
	var row_w := 680.0
	var row_h := 92.0
	var row_x := s.x / 2.0 - row_w / 2.0
	for i in 3:
		var b := Button.new()
		b.position = Vector2(row_x, 200 + i * 104)
		b.size = Vector2(row_w, row_h)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("icon_max_width", 68)
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_constant_override("outline_size", 5)
		b.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.06, 1.0))
		_style_button(b, "res://assets/ui/button.png", 22.0, 12.0)
		levelup_panel.add_child(b)
		cards.append(b)
		# "신규!" 뱃지 (우상단, 안 가진 무기/패시브에만 표시)
		var badge := Label.new()
		badge.text = "✦ 신규!"
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32))
		badge.add_theme_constant_override("outline_size", 4)
		badge.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 0.95))
		badge.position = Vector2(row_w - 128.0, 8.0)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.visible = false
		b.add_child(badge)
		_card_badges.append(badge)

	# 리롤 / 스킵 / 밴 버튼 (카드 아래, 3열)
	reroll_btn = Button.new()
	reroll_btn.position = Vector2(s.x / 2.0 - 348, 556)
	reroll_btn.size = Vector2(224, 52)
	reroll_btn.focus_mode = Control.FOCUS_NONE
	_style_button(reroll_btn, "res://assets/ui/button.png")
	reroll_btn.pressed.connect(_do_reroll)
	levelup_panel.add_child(reroll_btn)

	skip_btn = Button.new()
	skip_btn.position = Vector2(s.x / 2.0 - 112, 556)
	skip_btn.size = Vector2(224, 52)
	skip_btn.focus_mode = Control.FOCUS_NONE
	_style_button(skip_btn, "res://assets/ui/button.png")
	skip_btn.pressed.connect(_do_skip)
	levelup_panel.add_child(skip_btn)

	banish_btn = Button.new()
	banish_btn.position = Vector2(s.x / 2.0 + 124, 556)
	banish_btn.size = Vector2(224, 52)
	banish_btn.focus_mode = Control.FOCUS_NONE
	_style_button(banish_btn, "res://assets/ui/button.png")
	banish_btn.pressed.connect(_toggle_banish)
	levelup_panel.add_child(banish_btn)


	# 종료 패널
	end_panel = Control.new()
	end_panel.visible = false
	overlay.add_child(end_panel)

	var dim2 := ColorRect.new()
	dim2.color = Color(0, 0, 0, 0.78)
	dim2.position = Vector2.ZERO
	dim2.size = s
	end_panel.add_child(dim2)

	# 큰 타이틀 (승리/사망)
	end_title = Label.new()
	end_title.position = Vector2(0, 118)
	end_title.size = Vector2(s.x, 76)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_title.add_theme_font_size_override("font_size", 46)
	end_title.add_theme_constant_override("outline_size", 6)
	end_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	end_panel.add_child(end_title)

	end_label = Label.new()
	end_label.position = Vector2(0, 210)
	end_label.size = Vector2(s.x, 170)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 18)
	end_label.add_theme_constant_override("outline_size", 3)
	end_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	end_panel.add_child(end_label)

	# 최종 빌드 (무기·패시브 아이콘 행)
	end_build_box = VBoxContainer.new()
	end_build_box.position = Vector2(0, 380)
	end_build_box.size = Vector2(s.x, 90)
	end_build_box.alignment = BoxContainer.ALIGNMENT_CENTER
	end_build_box.add_theme_constant_override("separation", 6)
	end_panel.add_child(end_build_box)

	var restart_btn := Button.new()
	restart_btn.text = Loc.t("restart")
	restart_btn.position = Vector2(s.x / 2.0 - 90, 480)
	restart_btn.size = Vector2(180, 56)
	restart_btn.pressed.connect(_restart)
	_style_button(restart_btn, "res://assets/ui/button.png")
	end_panel.add_child(restart_btn)

	# 심연 모드 (승리 시에만 표시 — 무한 스케일링 엔들리스)
	abyss_btn = Button.new()
	abyss_btn.text = Loc.t("abyss")
	abyss_btn.position = Vector2(s.x / 2.0 - 90, 548)
	abyss_btn.size = Vector2(180, 50)
	abyss_btn.visible = false
	abyss_btn.pressed.connect(_continue_abyss)
	_style_button(abyss_btn, "res://assets/ui/button.png")
	end_panel.add_child(abyss_btn)

	# 일시정지 패널
	pause_panel = Control.new()
	pause_panel.visible = false
	overlay.add_child(pause_panel)

	var pdim := ColorRect.new()
	pdim.color = Color(0, 0, 0, 0.72)
	pdim.position = Vector2.ZERO
	pdim.size = s
	pause_panel.add_child(pdim)

	# 중앙 패널 (다크 + 금테)
	var pbg := Panel.new()
	pbg.position = Vector2(s.x / 2.0 - 350.0, 56)
	pbg.size = Vector2(700, 636)
	pbg.add_theme_stylebox_override("panel", _hud_style())
	pbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_panel.add_child(pbg)

	var pttl := Label.new()
	pttl.text = Loc.t("paused")
	pttl.position = Vector2(0, 70)
	pttl.size = Vector2(s.x, 40)
	pttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pttl.add_theme_font_size_override("font_size", 28)
	pttl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	pause_panel.add_child(pttl)

	# 뱀서식: 무기 / 패시브 아이콘 줄 (상단)
	var pw_lbl := Label.new()
	pw_lbl.text = "무기"
	pw_lbl.position = Vector2(s.x / 2.0 - 322, 116)
	pw_lbl.add_theme_font_size_override("font_size", 14)
	pw_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	pause_panel.add_child(pw_lbl)
	pause_weap_box = HBoxContainer.new()
	pause_weap_box.position = Vector2(s.x / 2.0 - 322, 138)
	pause_weap_box.add_theme_constant_override("separation", 6)
	pause_panel.add_child(pause_weap_box)

	var pp_lbl := Label.new()
	pp_lbl.text = "패시브"
	pp_lbl.position = Vector2(s.x / 2.0 - 322, 200)
	pp_lbl.add_theme_font_size_override("font_size", 14)
	pp_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	pause_panel.add_child(pp_lbl)
	pause_pass_box = HBoxContainer.new()
	pause_pass_box.position = Vector2(s.x / 2.0 - 322, 222)
	pause_pass_box.add_theme_constant_override("separation", 6)
	pause_panel.add_child(pause_pass_box)
	# 하단 버튼 3개 가로 정렬 (간격 확보). 스탯 스크롤 높이 계산에 쓰이므로 먼저 정의.
	var pby := 604.0
	var pbw := 200.0
	var pgap := 18.0
	var pbx0 := s.x / 2.0 - (pbw * 3.0 + pgap * 2.0) / 2.0

	# 스탯 패널: 레벨업 화면과 동일한 아이콘 그리드 (아이콘·이름·값 3열)
	var pstat_lbl := Label.new()
	pstat_lbl.text = "[ 스탯 ]"
	pstat_lbl.position = Vector2(s.x / 2.0 - 322, 286)
	pstat_lbl.add_theme_font_size_override("font_size", 14)
	pstat_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	pause_panel.add_child(pstat_lbl)
	# 스크롤 컨테이너: 스탯이 많아 넘쳐도 스크롤로 확인 (짤림 방지).
	# 높이는 반드시 버튼 줄 위에서 끝나야 함 — s.y 기준으로 잡으면 버튼과 겹쳐
	# 마지막 스탯 줄이 버튼에 가림.
	var pstat_top := 312.0
	var pstat_scroll := ScrollContainer.new()
	pstat_scroll.position = Vector2(s.x / 2.0 - 322, pstat_top)
	pstat_scroll.size = Vector2(360, pby - pstat_top - 12.0)
	pstat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pstat_scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.add_child(pstat_scroll)
	pause_stats_box = GridContainer.new()
	pause_stats_box.columns = 3
	pause_stats_box.add_theme_constant_override("h_separation", 8)
	pause_stats_box.add_theme_constant_override("v_separation", 5)
	pstat_scroll.add_child(pause_stats_box)

	# 유물 「은하 지도」 미니맵 — 패널 오른쪽 빈 공간. 해금 시에만 표시(_fill_pause_icons에서 갱신).
	pause_map_title = Label.new()
	pause_map_title.text = "은하 지도"
	pause_map_title.position = Vector2(s.x / 2.0 + 40, 116)
	pause_map_title.add_theme_font_size_override("font_size", 14)
	pause_map_title.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	pause_map_title.visible = false
	pause_panel.add_child(pause_map_title)
	pause_map_rect = TextureRect.new()
	pause_map_rect.position = Vector2(s.x / 2.0 + 40, 138)
	pause_map_rect.size = Vector2(290, 290)
	pause_map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pause_map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pause_map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pause_map_rect.visible = false
	pause_panel.add_child(pause_map_rect)

	var pause_controls := Label.new()
	pause_controls.text = "[ 조작 ]\nWASD / 방향키  이동\nSpace  회피 · E  무기 스킬\nQ  궁극기 · I  인벤토리"
	pause_controls.position = Vector2(s.x / 2.0 + 40, 452)
	pause_controls.size = Vector2(290, 104)
	pause_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_controls.add_theme_font_size_override("font_size", 13)
	pause_controls.add_theme_color_override("font_color", Color(0.82, 0.84, 0.92))
	pause_panel.add_child(pause_controls)

	var resume_btn := Button.new()
	resume_btn.text = Loc.t("resume")
	resume_btn.position = Vector2(pbx0, pby)
	resume_btn.size = Vector2(pbw, 52)
	_style_button(resume_btn, "res://assets/ui/button.png")
	resume_btn.pressed.connect(_toggle_pause)
	pause_panel.add_child(resume_btn)

	var pause_opt_btn := Button.new()
	pause_opt_btn.text = Loc.t("options")
	pause_opt_btn.position = Vector2(pbx0 + (pbw + pgap), pby)
	pause_opt_btn.size = Vector2(pbw, 52)
	_style_button(pause_opt_btn, "res://assets/ui/button.png")
	pause_opt_btn.pressed.connect(func() -> void: options_panel.visible = true)
	pause_panel.add_child(pause_opt_btn)

	var quit_btn := Button.new()
	quit_btn.text = Loc.t("to_title")
	quit_btn.position = Vector2(pbx0 + (pbw + pgap) * 2.0, pby)
	quit_btn.size = Vector2(pbw, 52)
	_style_button(quit_btn, "res://assets/ui/button.png")
	quit_btn.pressed.connect(_restart)
	pause_panel.add_child(quit_btn)

	# ─────────────────────────────────────────
	#  타이틀 플로우: 타이틀 → 캐릭터 선택 → 던전·난이도·가호 선택
	# ─────────────────────────────────────────
	title_panel = Control.new()
	overlay.add_child(title_panel)

	var tdim := ColorRect.new()
	tdim.color = Color(0.03, 0.03, 0.06, 1.0)
	tdim.size = s
	title_panel.add_child(tdim)

	# 가로 배경 아트 (title_bg_wide 우선, 세로 구버전 폴백)
	var tbg := Assets.tex("res://assets/ui/title_bg_wide.png")
	if tbg == null:
		tbg = Assets.tex("res://assets/ui/title_bg.png")
	if tbg:
		var tbg_rect := TextureRect.new()
		tbg_rect.texture = tbg
		tbg_rect.stretch_mode = TextureRect.STRETCH_SCALE
		tbg_rect.size = s
		tbg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_panel.add_child(tbg_rect)

	# 로고 (그림자 + 본체 이중 레이어)
	var logo_sh := Label.new()
	logo_sh.text = "ARROW SURVIVORS"
	logo_sh.position = Vector2(5, 105)
	logo_sh.size = Vector2(s.x, 90)
	logo_sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_sh.add_theme_font_size_override("font_size", 62)
	logo_sh.add_theme_color_override("font_color", Color(0, 0, 0, 0.75))
	title_panel.add_child(logo_sh)
	var logo := Label.new()
	logo.text = "ARROW SURVIVORS"
	logo.position = Vector2(0, 100)
	logo.size = Vector2(s.x, 90)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 62)
	logo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	title_panel.add_child(logo)

	var start_btn := Button.new()
	start_btn.text = Loc.t("start")
	start_btn.position = Vector2(s.x / 2.0 - 140, 360)
	start_btn.size = Vector2(280, 64)
	start_btn.add_theme_font_size_override("font_size", 20)
	_style_button(start_btn, "res://assets/ui/button.png")
	start_btn.pressed.connect(func() -> void: _goto_screen(char_panel))
	title_panel.add_child(start_btn)

	var shop_btn := Button.new()
	shop_btn.text = Loc.t("shop")
	shop_btn.position = Vector2(s.x / 2.0 - 250, 450)
	shop_btn.size = Vector2(240, 52)
	_style_button(shop_btn, "res://assets/ui/button.png")
	shop_btn.pressed.connect(_open_shop)
	title_panel.add_child(shop_btn)

	var forge_btn := Button.new()
	forge_btn.text = "대장간"
	forge_btn.position = Vector2(s.x / 2.0 + 10, 450)
	forge_btn.size = Vector2(240, 52)
	_style_button(forge_btn, "res://assets/ui/button.png")
	forge_btn.pressed.connect(_open_forge)
	title_panel.add_child(forge_btn)

	var collection_btn := Button.new()
	collection_btn.text = "도감"
	collection_btn.position = Vector2(s.x / 2.0 - 250, 514)
	collection_btn.size = Vector2(240, 52)
	_style_button(collection_btn, "res://assets/ui/button.png")
	collection_btn.pressed.connect(_open_collection)
	title_panel.add_child(collection_btn)

	var opt_btn := Button.new()
	opt_btn.text = Loc.t("options")
	opt_btn.position = Vector2(s.x / 2.0 + 10, 514)
	opt_btn.size = Vector2(240, 52)
	_style_button(opt_btn, "res://assets/ui/button.png")
	opt_btn.pressed.connect(func() -> void: options_panel.visible = true)
	title_panel.add_child(opt_btn)

	var ach_btn := Button.new()
	ach_btn.text = "업적"
	ach_btn.position = Vector2(s.x / 2.0 - 120, 578)
	ach_btn.size = Vector2(240, 52)
	_style_button(ach_btn, "res://assets/ui/button.png")
	ach_btn.pressed.connect(_open_achievements)
	title_panel.add_child(ach_btn)

	# 보유 골드는 상점 안에서만 표시 (타이틀에서는 숨김)
	title_gold_label = Label.new()
	title_gold_label.visible = false
	title_panel.add_child(title_gold_label)

	var ver := Label.new()
	ver.text = "v0.9 prototype"
	ver.position = Vector2(0, s.y - 34)
	ver.size = Vector2(s.x - 16, 24)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.add_theme_font_size_override("font_size", 11)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	title_panel.add_child(ver)

	# ── 캐릭터 선택 화면 (뱀서 구조: 좌측 세부 스탯 · 중앙 타일 그리드 · 하단 상세) ──
	char_panel = Control.new()
	char_panel.visible = false
	overlay.add_child(char_panel)
	var cdim := ColorRect.new()
	cdim.color = Color(0.04, 0.03, 0.07, 0.97)
	cdim.size = s
	char_panel.add_child(cdim)

	# 좌측: 선택 캐릭터의 세부 스탯 패널
	var st_bg := Panel.new()
	st_bg.position = Vector2(18, 84)
	st_bg.size = Vector2(252, 552)
	st_bg.add_theme_stylebox_override("panel", _slot_style())
	st_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_panel.add_child(st_bg)
	var st_ttl := Label.new()
	st_ttl.text = "[ 세부 스탯 ]"
	st_ttl.position = Vector2(34, 96)
	st_ttl.size = Vector2(220, 24)
	st_ttl.add_theme_font_size_override("font_size", 15)
	st_ttl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	char_panel.add_child(st_ttl)
	char_stats_box = GridContainer.new()
	char_stats_box.columns = 3
	char_stats_box.position = Vector2(34, 126)
	char_stats_box.add_theme_constant_override("h_separation", 8)
	char_stats_box.add_theme_constant_override("v_separation", 6)
	char_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_panel.add_child(char_stats_box)

	# 중앙: 그리드 패널. 큰 오르네이트 창틀은 4×2 타일의 내부를 덮으므로 사용하지 않는다.
	var grid_bg := Panel.new()
	grid_bg.position = Vector2(292, 62)
	grid_bg.size = Vector2(644, 396)
	grid_bg.add_theme_stylebox_override("panel", _hud_style())
	grid_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_panel.add_child(grid_bg)
	var cttl := Label.new()
	cttl.text = Loc.t("char_select")
	cttl.position = Vector2(292, 84)
	cttl.size = Vector2(644, 40)
	cttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cttl.add_theme_font_size_override("font_size", 28)
	cttl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	cttl.add_theme_constant_override("outline_size", 5)
	cttl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	char_panel.add_child(cttl)

	# 저주 다이얼이 있던 자리는 선택 영웅의 정체성을 보여주는 RPG 상세 패널로 사용한다.
	var char_detail_bg := Panel.new()
	char_detail_bg.position = Vector2(292, 470)
	char_detail_bg.size = Vector2(644, 148)
	char_detail_bg.add_theme_stylebox_override("panel", _slot_style())
	char_detail_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_panel.add_child(char_detail_bg)

	char_det_spr = TextureRect.new()
	char_det_spr.position = Vector2(310, 482)
	char_det_spr.size = Vector2(92, 118)
	char_det_spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	char_det_spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	char_det_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	char_det_spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_panel.add_child(char_det_spr)

	char_det_name = Label.new()
	char_det_name.position = Vector2(420, 480)
	char_det_name.size = Vector2(410, 34)
	char_det_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	char_det_name.add_theme_font_size_override("font_size", 22)
	char_det_name.add_theme_constant_override("outline_size", 4)
	char_det_name.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
	char_panel.add_child(char_det_name)

	char_det_desc = Label.new()
	char_det_desc.position = Vector2(420, 518)
	char_det_desc.size = Vector2(410, 82)
	char_det_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	char_det_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	char_det_desc.add_theme_font_size_override("font_size", 14)
	char_det_desc.add_theme_color_override("font_color", Color(0.86, 0.88, 0.95))
	char_det_desc.add_theme_constant_override("outline_size", 3)
	char_det_desc.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
	char_panel.add_child(char_det_desc)

	char_det_wicon = TextureRect.new()
	char_det_wicon.position = Vector2(850, 500)
	char_det_wicon.size = Vector2(58, 58)
	char_det_wicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	char_det_wicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	char_det_wicon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	char_det_wicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_panel.add_child(char_det_wicon)
	var char_weapon_caption := Label.new()
	char_weapon_caption.text = "시작 무기"
	char_weapon_caption.position = Vector2(830, 564)
	char_weapon_caption.size = Vector2(98, 24)
	char_weapon_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_weapon_caption.add_theme_font_size_override("font_size", 13)
	char_weapon_caption.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	char_panel.add_child(char_weapon_caption)

	# 뱀서식 타일 그리드: 4열, 타일 = 금테 프레임 + 이름 + 스프라이트 + 시작무기 아이콘.
	# 타일을 누르면 좌측 스탯 패널과 하단 상세가 갱신됨 (확정은 [확인]).
	var chars := GameConfig.characters()
	var n := chars.size()
	# 타일은 창틀(menu_panel 9-slice, 테두리 ~58px) 안쪽에 들어가야 금장식이 가려지지 않음
	# 로스터가 늘며 열을 확장 (11종부터 5열도 3줄 → 6열). 3줄이 되면 하단 상세 패널을 침범한다.
	var cols := 6
	var tw := 100.0
	var th := 118.0
	var tgap := 8.0
	var gx0 := 292.0 + (644.0 - (cols * tw + (cols - 1) * tgap)) / 2.0
	var gy0 := 140.0
	for i in n:
		var c: Dictionary = chars[i]
		var ckey: String = c["key"]
		var unlocked := _is_char_unlocked(c)
		var col: Color = GameConfig.char_stages(ckey)[0]["color"]
		var cb := Button.new()
		cb.position = Vector2(gx0 + (i % cols) * (tw + tgap), gy0 + (i / cols) * (th + tgap))
		cb.size = Vector2(tw, th)
		cb.focus_mode = Control.FOCUS_ALL
		cb.disabled = not unlocked
		_style_tile(cb)
		char_panel.add_child(cb)

		var nm := Label.new()
		nm.text = c["name"]
		nm.position = Vector2(6.0, 5.0)
		nm.size = Vector2(tw - 12.0, 22.0)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 15)
		nm.add_theme_color_override("font_color", col.lerp(Color(1, 1, 1), 0.72))
		nm.add_theme_constant_override("outline_size", 5)
		nm.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cb.add_child(nm)

		var spr := TextureRect.new()
		var ptex := Assets.tex("res://assets/ui/portrait_%s.png" % ckey)
		if ptex == null:
			ptex = Assets.tex("res://assets/hero/%s_1.png" % ckey)
		spr.texture = ptex
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2(tw * 0.5 - 38.0, 26.0)
		spr.size = Vector2(76.0, 76.0)
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not unlocked:
			spr.modulate = Color(0.04, 0.04, 0.055, 0.95)
		cb.add_child(spr)

		# 시작 무기 아이콘 (타일 우하단 — 뱀서와 동일)
		var wi := TextureRect.new()
		wi.texture = Assets.tex(WICON.get(c.get("weapon", ""), ""))
		wi.position = Vector2(tw - 36.0, th - 36.0)
		wi.size = Vector2(28.0, 28.0)
		wi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		wi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wi.visible = unlocked
		cb.add_child(wi)

		if not unlocked:
			# 자물쇠 아이콘 — 실루엣 위에 얹어 잠금을 한눈에 (뱀서식 어포던스).
			var lock_icon := TextureRect.new()
			lock_icon.texture = Assets.tex("res://assets/ui/lock.png")
			lock_icon.position = Vector2(tw * 0.5 - 14.0, 40.0)
			lock_icon.size = Vector2(28.0, 28.0)
			lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			lock_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cb.add_child(lock_icon)
			# 자물쇠 아이콘이 잠금을 알리므로 라벨은 해금 조건만.
			var lock_label := Label.new()
			lock_label.text = str(c.get("unlock_desc", "업적 달성으로 해금"))
			lock_label.position = Vector2(5, 74)
			lock_label.size = Vector2(tw - 10, 40)
			lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lock_label.add_theme_font_size_override("font_size", 11)
			lock_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48))
			lock_label.add_theme_constant_override("outline_size", 6)
			lock_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cb.add_child(lock_label)

		var cc := c
		cb.pressed.connect(func() -> void: _preview_char(cc))
		char_buttons.append(cb)
	_preview_char(sel_char)

	var cback := Button.new()
	cback.text = Loc.t("back")
	cback.position = Vector2(30, s.y - 76)
	cback.size = Vector2(140, 48)
	_style_button(cback, "res://assets/ui/button.png")
	cback.pressed.connect(func() -> void: _goto_screen(title_panel))
	char_panel.add_child(cback)

	# 던전 준비 화면으로 이동한다. 난이도와 가호는 다음 화면에서 함께 확정한다.
	var cok := Button.new()
	cok.text = "맵 선택 ▶"
	cok.position = Vector2(s.x - 210.0, s.y - 76)
	cok.size = Vector2(180, 48)
	_style_button(cok, "res://assets/ui/button.png")
	cok.pressed.connect(func() -> void: _select_char(sel_char))
	char_panel.add_child(cok)

	# ── 맵 선택: 5개 독립 스테이지. 기존 5막 캠페인은 선택 목록에서 제외한다. ──
	stage_select_panel = Control.new()
	stage_select_panel.visible = false
	overlay.add_child(stage_select_panel)
	# 부모 overlay에 붙인 뒤 앵커를 계산해야 실제 뷰포트 크기를 받는다.
	stage_select_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stdim := ColorRect.new()
	stage_select_backdrop = stdim
	stdim.color = Color(0.025, 0.02, 0.045, 1.0)
	stdim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stdim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_select_panel.add_child(stdim)
	var frame_tex := TextureRect.new()
	frame_tex.texture = Assets.tex("res://assets/ui/map_select_frame_clean.png")
	var frame_scale := minf((s.x - 50.0) / 688.0, (s.y - 36.0) / 384.0)
	var frame_size := Vector2(688.0, 384.0) * frame_scale
	var frame_pos := (s - frame_size) * 0.5
	frame_tex.position = frame_pos
	frame_tex.size = frame_size
	frame_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_tex.stretch_mode = TextureRect.STRETCH_SCALE
	frame_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_select_panel.add_child(frame_tex)
	var stttl := Label.new()
	stttl.text = "던전 선택"
	stttl.position = Vector2(frame_pos.x + 210.0 * frame_scale, frame_pos.y + 17.0 * frame_scale)
	stttl.size = Vector2(268.0 * frame_scale, 34.0 * frame_scale)
	stttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stttl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stttl.add_theme_font_size_override("font_size", maxi(18, int(22.0 * frame_scale)))
	stttl.add_theme_color_override("font_color", Color(0.96, 0.79, 0.46))
	stttl.add_theme_constant_override("outline_size", 4)
	stttl.add_theme_color_override("font_outline_color", Color(0.07, 0.045, 0.06))
	stage_select_panel.add_child(stttl)
	# 독립 맵 선택은 해금 게이트가 아니라 플레이 모드 선택으로 둔다.
	# 저장 데이터의 stage_unlocked는 기존 캠페인 진행 기록용으로만 보존한다.
	unlocked_stage_count = FINAL_STAGE
	sel_stage = clampi(sel_stage if sel_stage > 0 else 1, 1, FINAL_STAGE)
	map_cards.clear()
	map_selection_borders.clear()
	map_selection_badges.clear()
	var slot_rects := [
		Rect2(55, 86, 100, 147), Rect2(174, 86, 102, 147), Rect2(294, 86, 101, 147),
		Rect2(412, 86, 102, 147), Rect2(531, 86, 100, 147)
	]
	for stage_index in range(1, FINAL_STAGE + 1):
		var stage_button := Button.new()
		var slot: Rect2 = slot_rects[stage_index - 1]
		stage_button.position = frame_pos + slot.position * frame_scale
		stage_button.size = slot.size * frame_scale
		stage_button.flat = true
		stage_button.clip_contents = true   # 미니맵이 카드 밖으로 삐져나오지 않게 클리핑
		stage_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stage_button.add_theme_font_size_override("font_size", maxi(12, int(14.0 * frame_scale)))
		stage_button.add_theme_color_override("font_color", Color(0.95, 0.9, 0.76))
		stage_button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.56))
		var stage_data: Dictionary = GameConfig.stage_info(stage_index)
		var preview_bg := TextureRect.new()
		var preview_floor := "res://assets/maps/%s/preview.png" % STAGE_MAP_DIRS[stage_index - 1]
		preview_bg.texture = Assets.tex(preview_floor)
		preview_bg.position = Vector2(5, 5) * frame_scale
		preview_bg.size = slot.size * frame_scale - Vector2(10, 10) * frame_scale
		preview_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		preview_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# 미니맵 썸네일에 스테이지 톤을 이미 구워 넣었으므로 여기서 감광하지 않는다.
		preview_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_button.add_child(preview_bg)
		stage_button.move_child(preview_bg, 0)
		# 보스 아이콘 뒤 어두운 원판 — 밝은 미니맵(빙하·공허)에서도 대비를 확보한다.
		var boss_disc := Panel.new()
		boss_disc.position = Vector2(slot.size.x * 0.5 - 24.0, 34.0) * frame_scale
		boss_disc.size = Vector2(48, 48) * frame_scale
		var disc_style := StyleBoxFlat.new()
		disc_style.bg_color = Color(0.05, 0.04, 0.07, 0.52)
		disc_style.set_corner_radius_all(maxi(12, int(24.0 * frame_scale)))
		boss_disc.add_theme_stylebox_override("panel", disc_style)
		boss_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_button.add_child(boss_disc)
		var boss_preview := TextureRect.new()
		boss_preview.texture = Assets.tex("res://assets/boss/%s.png" % stage_data["boss"])
		boss_preview.position = Vector2(slot.size.x * 0.5 - 18.0, 40.0) * frame_scale
		boss_preview.size = Vector2(36, 36) * frame_scale
		boss_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		boss_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		boss_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		boss_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_button.add_child(boss_preview)
		# 스테이지 이름표 — ASCII 기호(+, =, *…) 대신 미니맵 위에 이름을 얹는다.
		var map_mark := Label.new()
		map_mark.text = str(stage_data["name"])
		map_mark.position = Vector2(4, slot.size.y - 30.0) * frame_scale
		map_mark.size = Vector2(slot.size.x - 8, 22) * frame_scale
		map_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		map_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		map_mark.add_theme_font_size_override("font_size", maxi(12, int(15.0 * frame_scale)))
		map_mark.add_theme_color_override("font_color", Color(0.96, 0.90, 0.74))
		map_mark.add_theme_constant_override("outline_size", 5)
		map_mark.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06))
		map_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_button.add_child(map_mark)
		var selection_border := Panel.new()
		selection_border.position = Vector2(1, 1) * frame_scale
		selection_border.size = slot.size * frame_scale - Vector2(2, 2) * frame_scale
		var border_style := StyleBoxFlat.new()
		border_style.bg_color = Color(1.0, 0.78, 0.18, 0.24)
		border_style.border_color = Color(1.0, 0.82, 0.28, 1.0)
		border_style.set_border_width_all(maxi(4, int(5.0 * frame_scale)))
		border_style.corner_radius_top_left = maxi(4, int(6.0 * frame_scale))
		border_style.corner_radius_top_right = maxi(4, int(6.0 * frame_scale))
		border_style.corner_radius_bottom_left = maxi(4, int(6.0 * frame_scale))
		border_style.corner_radius_bottom_right = maxi(4, int(6.0 * frame_scale))
		selection_border.add_theme_stylebox_override("panel", border_style)
		selection_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_button.add_child(selection_border)
		map_selection_borders.append(selection_border)
		var selected_badge := Label.new()
		selected_badge.text = "✓ 선택됨"
		selected_badge.position = Vector2(8, 75) * frame_scale
		selected_badge.size = Vector2(slot.size.x - 16, 24) * frame_scale
		selected_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		selected_badge.add_theme_font_size_override("font_size", maxi(12, int(14.0 * frame_scale)))
		selected_badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
		selected_badge.add_theme_constant_override("outline_size", 5)
		selected_badge.add_theme_color_override("font_outline_color", Color(0.06, 0.035, 0.01))
		selected_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_button.add_child(selected_badge)
		map_selection_badges.append(selected_badge)
		stage_button.text = "\n\n%d\n%s" % [stage_index, stage_data["name"]]
		if stage_index > unlocked_stage_count:
			stage_button.text = "\n\n🔒\n잠김"
			stage_button.modulate = Color(0.48, 0.48, 0.55)
		stage_button.pressed.connect(_choose_stage_card.bind(stage_index))
		stage_select_panel.add_child(stage_button)
		map_cards.append(stage_button)

	# 던전과 같은 화면에서 난이도를 확정한다. spawn은 낮을수록 출현이 빠르다.
	map_difficulty_buttons.clear()
	var difficulty_options := GameConfig.difficulties()
	var difficulty_gap := 6.0
	var difficulty_row_width := 576.0
	var difficulty_button_width := (
		difficulty_row_width - difficulty_gap * float(difficulty_options.size() - 1)
	) / float(difficulty_options.size())
	for difficulty_index in difficulty_options.size():
		var difficulty_data: Dictionary = difficulty_options[difficulty_index]
		var difficulty_button := Button.new()
		difficulty_button.position = frame_pos + Vector2(
			55.0 + difficulty_index * (difficulty_button_width + difficulty_gap), 238.0
		) * frame_scale
		difficulty_button.size = Vector2(difficulty_button_width, 23.0) * frame_scale
		difficulty_button.add_theme_font_size_override("font_size", maxi(10, int(12.0 * frame_scale)))
		difficulty_button.tooltip_text = (
			"%s\n플레이어 HP ×%.2f · 적 HP ×%.2f · 속도 ×%.2f · 출현 ×%.2f\n"
			+ "골드 ×%.2f · 경험치 ×%.2f · 장비 ×%.2f"
		) % [
			difficulty_data.get("desc", ""),
			difficulty_data.get("player_hp", 1.0),
			difficulty_data.get("enemy_hp", 1.0),
			difficulty_data.get("enemy_speed", 1.0),
			1.0 / maxf(0.01, float(difficulty_data.get("spawn", 1.0))),
			difficulty_data.get("gold", 1.0),
			difficulty_data.get("xp", 1.0),
			difficulty_data.get("gear", 1.0),
		]
		_style_button(difficulty_button, "res://assets/ui/button.png", 10.0, 2.0)
		difficulty_button.pressed.connect(
			_choose_stage_difficulty.bind(str(difficulty_data.get("key", "normal")))
		)
		stage_select_panel.add_child(difficulty_button)
		map_difficulty_buttons.append(difficulty_button)

	map_detail_label = Label.new()
	map_detail_label.position = frame_pos + Vector2(55, 263) * frame_scale
	map_detail_label.size = Vector2(576, 62) * frame_scale
	map_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_detail_label.add_theme_font_size_override("font_size", maxi(11, int(12.0 * frame_scale)))
	map_detail_label.add_theme_color_override("font_color", Color(0.90, 0.93, 1.0))
	map_detail_label.add_theme_constant_override("outline_size", 3)
	map_detail_label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06))
	stage_select_panel.add_child(map_detail_label)

	var stback := Button.new()
	stback.text = Loc.t("back")
	stback.position = frame_pos + Vector2(55, 330) * frame_scale
	stback.size = Vector2(90, 27) * frame_scale
	stback.add_theme_font_size_override("font_size", maxi(12, int(14.0 * frame_scale)))
	_style_button(stback, "res://assets/ui/button.png", 12.0, 2.0)
	stback.pressed.connect(func() -> void: _goto_screen(char_panel))
	stage_select_panel.add_child(stback)

	map_blessing_button = Button.new()
	map_blessing_button.position = frame_pos + Vector2(154, 330) * frame_scale
	map_blessing_button.size = Vector2(338, 27) * frame_scale
	map_blessing_button.add_theme_font_size_override("font_size", maxi(10, int(11.0 * frame_scale)))
	map_blessing_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_style_button(map_blessing_button, "res://assets/ui/button.png", 12.0, 2.0)
	map_blessing_button.pressed.connect(_cycle_stage_blessing)
	stage_select_panel.add_child(map_blessing_button)

	map_confirm_button = Button.new()
	map_confirm_button.position = frame_pos + Vector2(501, 330) * frame_scale
	map_confirm_button.size = Vector2(130, 27) * frame_scale
	map_confirm_button.add_theme_font_size_override("font_size", maxi(12, int(14.0 * frame_scale)))
	_style_button(map_confirm_button, "res://assets/ui/button.png", 12.0, 2.0)
	map_confirm_button.pressed.connect(_confirm_stage_selection)
	stage_select_panel.add_child(map_confirm_button)
	if sel_diff.is_empty():
		sel_diff = _difficulty_by_key("normal")
	_refresh_stage_blessing()
	_refresh_stage_selection()

	# 상점 패널
	shop_panel = Control.new()
	shop_panel.visible = false
	overlay.add_child(shop_panel)

	var sdim := ColorRect.new()
	sdim.color = Color(0.03, 0.03, 0.06, 0.9)
	sdim.position = Vector2.ZERO
	sdim.size = s
	shop_panel.add_child(sdim)

	# 금테 다크 패널 배경
	var shop_bg := Panel.new()
	shop_bg.position = Vector2(20, 22)
	shop_bg.size = Vector2(s.x - 40, s.y - 30)
	shop_bg.add_theme_stylebox_override("panel", _hud_style())
	shop_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_panel.add_child(shop_bg)

	var sttl := Label.new()
	sttl.text = "영구 강화 상점"
	sttl.position = Vector2(0, 60)
	sttl.size = Vector2(s.x, 40)
	sttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sttl.add_theme_font_size_override("font_size", 28)
	sttl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	shop_panel.add_child(sttl)

	shop_gold_label = Label.new()
	shop_gold_label.position = Vector2(0, 98)
	shop_gold_label.size = Vector2(s.x, 26)
	shop_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	shop_panel.add_child(shop_gold_label)

	for i in Meta.UPGRADES.size():
		var ub := Button.new()
		# 2열 배치 (가로 화면)
		var col := i % 2
		var row := int(i / 2.0)
		ub.position = Vector2(s.x / 2.0 - 592 + col * 604, 120 + row * 76)
		ub.size = Vector2(576, 52)
		ub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# 상하 여백 6 → 버튼 최소높이↓ → 버튼 사이 간격(24px) 실제로 보이게
		_style_button(ub, "res://assets/ui/button.png", 22.0, 6.0)
		var idx := i
		ub.pressed.connect(func() -> void: _buy_upgrade(idx))
		shop_panel.add_child(ub)
		shop_buttons.append(ub)

	var sby := 120 + int(ceil(Meta.UPGRADES.size() / 2.0)) * 76 + 4
	# 초기화(환불) 버튼
	var reset_btn := Button.new()
	reset_btn.text = "↺ 초기화 (전액 환불)"
	reset_btn.position = Vector2(s.x / 2.0 - 260, sby)
	reset_btn.size = Vector2(210, 50)
	_style_button(reset_btn, "res://assets/ui/button.png")
	reset_btn.add_theme_color_override("font_color", Color(1.0, 0.72, 0.6))
	reset_btn.pressed.connect(_reset_upgrades)
	shop_panel.add_child(reset_btn)

	var back_btn := Button.new()
	back_btn.text = "← 돌아가기"
	back_btn.position = Vector2(s.x / 2.0 + 50, sby)
	back_btn.size = Vector2(210, 50)
	_style_button(back_btn, "res://assets/ui/button.png")
	back_btn.pressed.connect(func() -> void: shop_panel.visible = false)
	shop_panel.add_child(back_btn)

	# ── 대장간: 인벤토리와 같은 3패널 구조(로드아웃 / 보관함 / 상세)로 정리한다. ──
	forge_panel = Control.new()
	forge_panel.visible = false
	forge_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(forge_panel)
	var fdim := ColorRect.new()
	fdim.color = Color(0.03, 0.03, 0.06, 0.92)
	fdim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	forge_panel.add_child(fdim)
	var forge_modal := _modal_rect(s)
	var fbg := Panel.new()
	fbg.position = forge_modal.position
	fbg.size = forge_modal.size
	# 대장간도 장비 정보가 주인공이므로 배경 장식보다 얇은 금테를 우선한다.
	fbg.add_theme_stylebox_override("panel", _hud_style())
	forge_panel.add_child(fbg)
	var fttl := Label.new()
	fttl.text = "⚒ 대장간 — 영구 장비"
	fttl.position = Vector2(0, 13)
	fttl.size = Vector2(forge_modal.size.x, 32)
	fttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fttl.add_theme_font_size_override("font_size", 24)
	fttl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	fbg.add_child(fttl)
	forge_gold_label = Label.new()
	forge_gold_label.position = Vector2(0, 45)
	forge_gold_label.size = Vector2(forge_modal.size.x, 20)
	forge_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forge_gold_label.add_theme_font_size_override("font_size", 12)
	forge_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	fbg.add_child(forge_gold_label)

	var inner_x := 18.0
	var inner_w := forge_modal.size.x - inner_x * 2.0
	var content_top := 88.0
	var footer_y := forge_modal.size.y - 61.0
	var content_h := maxf(150.0, footer_y - content_top - 12.0)
	var gap := clampf(forge_modal.size.x * 0.018, 10.0, 18.0)
	var left_w := clampf(inner_w * 0.25, 195.0, 270.0)
	var mid_w := clampf(inner_w * 0.31, 225.0, 350.0)
	var right_w := inner_w - left_w - mid_w - gap * 2.0
	if right_w < 220.0:
		var recover := 220.0 - right_w
		var take_mid := minf(recover, maxf(0.0, mid_w - 195.0))
		mid_w -= take_mid
		recover -= take_mid
		left_w -= minf(recover, maxf(0.0, left_w - 175.0))
		right_w = inner_w - left_w - mid_w - gap * 2.0
	forge_loadout_width = maxf(120.0, left_w - 24.0)
	forge_list_item_width = maxf(155.0, mid_w - 20.0)

	var loadout_panel := Panel.new()
	loadout_panel.position = Vector2(inner_x, content_top)
	loadout_panel.size = Vector2(left_w, content_h)
	loadout_panel.add_theme_stylebox_override("panel", _section_style(Color(0.33, 0.63, 0.83, 0.9)))
	fbg.add_child(loadout_panel)
	var flh := Label.new()
	flh.text = "⚔ 현재 로드아웃"
	flh.position = Vector2(12, 10)
	flh.size = Vector2(left_w - 24.0, 22)
	flh.add_theme_font_size_override("font_size", 15)
	flh.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	loadout_panel.add_child(flh)
	forge_loadout_box = HBoxContainer.new()
	forge_loadout_box.position = Vector2(12, 40)
	forge_loadout_box.size = Vector2(left_w - 24.0, 84)
	forge_loadout_box.add_theme_constant_override("separation", 4)
	loadout_panel.add_child(forge_loadout_box)
	var ftip := Label.new()
	ftip.text = "[ 영구 장비 ]\n장착 효과는 다음 런부터 적용됩니다.\n\n강화는 최대 5단계이며\n모든 어픽스가 단계마다 +12% 강해집니다."
	ftip.position = Vector2(12, 142)
	ftip.size = Vector2(left_w - 24.0, maxf(100.0, content_h - 154.0))
	ftip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ftip.add_theme_font_size_override("font_size", 12)
	ftip.add_theme_color_override("font_color", Color(0.72, 0.75, 0.84))
	loadout_panel.add_child(ftip)

	var stash_panel := Panel.new()
	stash_panel.position = Vector2(inner_x + left_w + gap, content_top)
	stash_panel.size = Vector2(mid_w, content_h)
	stash_panel.add_theme_stylebox_override("panel", _section_style(Color(0.72, 0.56, 0.28, 0.9)))
	fbg.add_child(stash_panel)
	forge_stash_label = Label.new()
	forge_stash_label.position = Vector2(12, 10)
	forge_stash_label.size = Vector2(mid_w - 24.0, 22)
	forge_stash_label.add_theme_font_size_override("font_size", 15)
	forge_stash_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	stash_panel.add_child(forge_stash_label)
	var fscroll := ScrollContainer.new()
	fscroll.position = Vector2(8, 42)
	fscroll.size = Vector2(mid_w - 16.0, content_h - 50.0)
	fscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stash_panel.add_child(fscroll)
	forge_list_box = VBoxContainer.new()
	forge_list_box.add_theme_constant_override("separation", 4)
	fscroll.add_child(forge_list_box)

	var detail_panel := Panel.new()
	detail_panel.position = Vector2(inner_x + left_w + gap + mid_w + gap, content_top)
	detail_panel.size = Vector2(right_w, content_h)
	detail_panel.add_theme_stylebox_override("panel", _section_style(Color(0.78, 0.48, 0.65, 0.9)))
	fbg.add_child(detail_panel)
	var fdh := Label.new()
	fdh.text = "◇ 장비 상세 · 강화"
	fdh.position = Vector2(12, 10)
	fdh.size = Vector2(right_w - 24.0, 22)
	fdh.add_theme_font_size_override("font_size", 15)
	fdh.add_theme_color_override("font_color", Color(1.0, 0.72, 0.86))
	detail_panel.add_child(fdh)
	forge_detail_label = Label.new()
	forge_detail_label.position = Vector2(12, 42)
	forge_detail_label.size = Vector2(right_w - 24.0, content_h - 54.0)
	forge_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	forge_detail_label.add_theme_font_size_override("font_size", 13)
	forge_detail_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	detail_panel.add_child(forge_detail_label)

	var fback := Button.new()
	fback.text = "← 돌아가기"
	fback.position = Vector2(18, footer_y + 6.0)
	fback.size = Vector2(150, 44)
	_style_button(fback, "res://assets/ui/button.png")
	fback.pressed.connect(func() -> void: forge_panel.visible = false)
	fbg.add_child(fback)
	forge_equip_btn = Button.new()
	forge_equip_btn.position = Vector2(forge_modal.size.x - 18.0 - 154.0 - 10.0 - 160.0 - 10.0 - 136.0, footer_y + 6.0)
	forge_equip_btn.size = Vector2(136, 44)
	_style_button(forge_equip_btn, "res://assets/ui/button.png")
	forge_equip_btn.pressed.connect(_forge_toggle_equip)
	fbg.add_child(forge_equip_btn)
	forge_upgrade_btn = Button.new()
	forge_upgrade_btn.position = Vector2(forge_modal.size.x - 18.0 - 154.0 - 10.0 - 160.0, footer_y + 6.0)
	forge_upgrade_btn.size = Vector2(160, 44)
	_style_button(forge_upgrade_btn, "res://assets/ui/button.png")
	forge_upgrade_btn.pressed.connect(_forge_upgrade_selected)
	fbg.add_child(forge_upgrade_btn)
	forge_discard_btn = Button.new()
	forge_discard_btn.position = Vector2(forge_modal.size.x - 18.0 - 154.0, footer_y + 6.0)
	forge_discard_btn.size = Vector2(154, 44)
	_style_button(forge_discard_btn, "res://assets/ui/button.png")
	forge_discard_btn.add_theme_color_override("font_color", Color(1.0, 0.72, 0.6))
	forge_discard_btn.pressed.connect(_forge_discard_selected)
	fbg.add_child(forge_discard_btn)

	# ── 옵션 패널 (음악/효과음 볼륨, 전체화면) ──
	options_panel = Control.new()
	options_panel.visible = false
	options_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.add_child(options_panel)

	var odim := ColorRect.new()
	odim.color = Color(0.03, 0.03, 0.06, 0.9)
	odim.size = s
	options_panel.add_child(odim)

	# 중앙 패널 (다크 + 금테)
	var obg := Panel.new()
	obg.position = Vector2(s.x / 2.0 - 330.0, 128)
	obg.size = Vector2(660, 452)
	obg.add_theme_stylebox_override("panel", _hud_style())
	obg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options_panel.add_child(obg)

	var ottl := Label.new()
	ottl.text = Loc.t("opt_title")
	ottl.position = Vector2(0, 146)
	ottl.size = Vector2(s.x, 44)
	ottl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ottl.add_theme_font_size_override("font_size", 30)
	ottl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	options_panel.add_child(ottl)

	var ox := s.x / 2.0 - 280.0
	# 음악 볼륨
	var ml := Label.new()
	ml.text = Loc.t("music_vol")
	ml.position = Vector2(ox, 216)
	ml.size = Vector2(180, 40)
	ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	options_panel.add_child(ml)
	var msl := HSlider.new()
	msl.min_value = 0.0
	msl.max_value = 1.0
	msl.step = 0.05
	msl.value = float(meta.get("music_vol", 0.7))
	msl.position = Vector2(ox + 200, 224)
	msl.custom_minimum_size = Vector2(340, 28)
	msl.size = Vector2(340, 28)
	msl.value_changed.connect(func(v: float) -> void:
		meta["music_vol"] = v
		_apply_audio_settings())
	options_panel.add_child(msl)

	# 효과음 볼륨
	var sl := Label.new()
	sl.text = Loc.t("sfx_vol")
	sl.position = Vector2(ox, 284)
	sl.size = Vector2(180, 40)
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	options_panel.add_child(sl)
	var ssl := HSlider.new()
	ssl.min_value = 0.0
	ssl.max_value = 1.0
	ssl.step = 0.05
	ssl.value = float(meta.get("sfx_vol", 0.8))
	ssl.position = Vector2(ox + 200, 292)
	ssl.custom_minimum_size = Vector2(340, 28)
	ssl.size = Vector2(340, 28)
	ssl.value_changed.connect(func(v: float) -> void:
		meta["sfx_vol"] = v
		_apply_audio_settings()
		play_sfx("select", -10.0, 0.15))
	options_panel.add_child(ssl)

	# 2열 배치 (이펙트 설정 2개가 늘어 세로로는 패널을 넘침)
	var colL := s.x / 2.0 - 280.0
	var colR := s.x / 2.0 + 12.0
	var bw := 268.0

	# 이펙트 강도 (순환) — 파티클 수·스프라이트 이펙트 on/off에 반영
	var fx_btn := Button.new()
	fx_btn.position = Vector2(colL, 348)
	fx_btn.size = Vector2(bw, 50)
	_style_button(fx_btn, "res://assets/ui/button.png")
	var fx_names := ["끔", "약함", "보통", "화려함"]
	fx_btn.text = "이펙트: %s" % fx_names[clamp(fx_level, 0, 3)]
	fx_btn.pressed.connect(func() -> void:
		fx_level = (fx_level + 1) % 4
		meta["fx_level"] = fx_level
		Effect.fx_level = fx_level
		fx_btn.text = "이펙트: %s" % fx_names[fx_level])
	options_panel.add_child(fx_btn)

	# 화면 흔들림 토글 (멀미 대응)
	var shk_btn := Button.new()
	shk_btn.position = Vector2(colR, 348)
	shk_btn.size = Vector2(bw, 50)
	_style_button(shk_btn, "res://assets/ui/button.png")
	shk_btn.text = "화면 흔들림: %s" % ("켬" if shake_enabled else "끔")
	shk_btn.pressed.connect(func() -> void:
		shake_enabled = not shake_enabled
		meta["screen_shake"] = shake_enabled
		shk_btn.text = "화면 흔들림: %s" % ("켬" if shake_enabled else "끔"))
	options_panel.add_child(shk_btn)

	# 전체화면 토글
	var fs_btn := Button.new()
	fs_btn.toggle_mode = true
	fs_btn.button_pressed = bool(meta.get("fullscreen", false))
	fs_btn.text = Loc.t("fullscreen_on") if fs_btn.button_pressed else Loc.t("fullscreen_off")
	fs_btn.position = Vector2(colL, 410)
	fs_btn.size = Vector2(bw, 50)
	_style_button(fs_btn, "res://assets/ui/button.png")
	fs_btn.toggled.connect(func(on: bool) -> void:
		meta["fullscreen"] = on
		fs_btn.text = Loc.t("fullscreen_on") if on else Loc.t("fullscreen_off")
		_apply_fullscreen())
	options_panel.add_child(fs_btn)

	# 언어 토글 (변경 시 저장 후 씬 리로드로 UI 재구성)
	var lang_btn := Button.new()
	lang_btn.text = Loc.t("lang_btn")
	lang_btn.position = Vector2(colR, 410)
	lang_btn.size = Vector2(bw, 50)
	_style_button(lang_btn, "res://assets/ui/button.png")
	lang_btn.pressed.connect(func() -> void:
		Loc.toggle()
		meta["lang"] = Loc.lang
		Meta.save_data(meta)
		get_tree().paused = false
		get_tree().reload_current_scene())
	options_panel.add_child(lang_btn)

	var oclose := Button.new()
	oclose.text = Loc.t("close")
	oclose.position = Vector2(s.x / 2.0 - 100, 484)
	oclose.size = Vector2(200, 50)
	_style_button(oclose, "res://assets/ui/button.png")
	oclose.pressed.connect(func() -> void:
		Meta.save_data(meta)
		options_panel.visible = false)
	options_panel.add_child(oclose)

	# ── 업적 패널 (오르네이트 프레임) ──
	achievements_panel = Control.new()
	achievements_panel.visible = false
	achievements_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.add_child(achievements_panel)
	var achdim := ColorRect.new()
	achdim.color = Color(0.03, 0.03, 0.06, 0.92)
	achdim.size = s
	achievements_panel.add_child(achdim)
	var achbg := TextureRect.new()
	achbg.texture = Assets.tex("res://assets/ui/codex_window_v2.png")
	achbg.position = Vector2(34, 18)
	achbg.size = Vector2(s.x - 68, s.y - 36)
	achbg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	achbg.stretch_mode = TextureRect.STRETCH_SCALE
	achbg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	achbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	achievements_panel.add_child(achbg)
	var achttl := Label.new()
	achttl.text = "업 적"
	achttl.position = Vector2(0, 30)
	achttl.size = Vector2(s.x, 38)
	achttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	achttl.add_theme_font_size_override("font_size", 30)
	achttl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	achievements_panel.add_child(achttl)
	ach_progress_label = Label.new()
	ach_progress_label.position = Vector2(0, 96)
	ach_progress_label.size = Vector2(s.x, 26)
	ach_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ach_progress_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
	achievements_panel.add_child(ach_progress_label)
	var ascroll := ScrollContainer.new()
	ascroll.position = Vector2(s.x / 2.0 - 486.0, 142)
	ascroll.size = Vector2(972, s.y - 274)
	ascroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ascroll.process_mode = Node.PROCESS_MODE_ALWAYS
	achievements_panel.add_child(ascroll)
	ach_list_box = GridContainer.new()
	ach_list_box.columns = 2
	ach_list_box.custom_minimum_size = Vector2(948, 0)
	ach_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_list_box.add_theme_constant_override("h_separation", 8)
	ach_list_box.add_theme_constant_override("v_separation", 8)
	ascroll.add_child(ach_list_box)
	var achclose := Button.new()
	achclose.text = Loc.t("close")
	achclose.position = Vector2(s.x / 2.0 - 100, s.y - 70)
	achclose.size = Vector2(200, 52)
	_style_button(achclose, "res://assets/ui/button.png")
	achclose.pressed.connect(func() -> void: achievements_panel.visible = false)
	achievements_panel.add_child(achclose)

	# ── 진화 도감 패널: 획득한 무기의 레시피와 실제 진화 발견 여부를 영구 기록 ──
	collection_panel = Control.new()
	collection_panel.visible = false
	collection_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.add_child(collection_panel)
	var coldim := ColorRect.new()
	coldim.color = Color(0.03, 0.03, 0.06, 0.94)
	coldim.size = s
	collection_panel.add_child(coldim)
	var colbg := TextureRect.new()
	colbg.texture = Assets.tex("res://assets/ui/codex_window_v2.png")
	colbg.position = Vector2(34, 18)
	colbg.size = Vector2(s.x - 68, s.y - 36)
	colbg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	colbg.stretch_mode = TextureRect.STRETCH_SCALE
	colbg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	colbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	collection_panel.add_child(colbg)
	var colttl := Label.new()
	colttl.text = "수 집  도 감"
	colttl.position = Vector2(0, 30)
	colttl.size = Vector2(s.x, 38)
	colttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colttl.add_theme_font_size_override("font_size", 30)
	colttl.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
	collection_panel.add_child(colttl)
	collection_progress_label = Label.new()
	collection_progress_label.position = Vector2(0, 96)
	collection_progress_label.size = Vector2(s.x, 26)
	collection_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collection_progress_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	collection_panel.add_child(collection_progress_label)
	var tab_names := {"evolutions":"진화", "unions":"유니온", "relics":"유물", "enemies":"몬스터"}
	var tab_order := ["evolutions", "unions", "relics", "enemies"]
	collection_tab_buttons.clear()
	for tab_index in tab_order.size():
		var tab_key: String = tab_order[tab_index]
		var tab_btn := Button.new()
		tab_btn.text = tab_names[tab_key]
		tab_btn.position = Vector2(s.x / 2.0 - 330 + tab_index * 168, 126)
		tab_btn.size = Vector2(156, 42)
		_style_button(tab_btn, "res://assets/ui/button.png")
		var selected_tab := tab_key
		tab_btn.pressed.connect(func() -> void:
			collection_tab = selected_tab
			_refresh_collection())
		collection_tab_buttons[tab_key] = tab_btn
		collection_panel.add_child(tab_btn)
	var colscroll := ScrollContainer.new()
	# 탭 버튼의 9-slice 외곽/그림자와 첫 카드 테두리가 맞닿지 않도록 여백을 둔다.
	colscroll.position = Vector2(s.x / 2.0 - 486.0, 188)
	colscroll.size = Vector2(972, s.y - 318)
	colscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	colscroll.process_mode = Node.PROCESS_MODE_ALWAYS
	collection_panel.add_child(colscroll)
	collection_list_box = GridContainer.new()
	collection_list_box.columns = 2
	collection_list_box.custom_minimum_size = Vector2(948, 0)
	collection_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_list_box.add_theme_constant_override("h_separation", 8)
	collection_list_box.add_theme_constant_override("v_separation", 8)
	colscroll.add_child(collection_list_box)
	var colclose := Button.new()
	colclose.text = Loc.t("close")
	colclose.position = Vector2(s.x / 2.0 - 100, s.y - 70)
	colclose.size = Vector2(200, 52)
	_style_button(colclose, "res://assets/ui/button.png")
	colclose.pressed.connect(func() -> void: collection_panel.visible = false)
	collection_panel.add_child(colclose)


func _open_achievements() -> void:
	_refresh_achievements()
	achievements_panel.visible = true


func _open_collection() -> void:
	_refresh_collection()
	collection_panel.visible = true


func _ui_crop(path: String, region: Rect2) -> Texture2D:
	var source := Assets.tex(path)
	if source == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	return atlas


func _codex_card_style(frame_path: String) -> StyleBoxFlat:
	# PixelLab 프레임은 외곽 창에만 사용한다. 카드 내부까지 장식 이미지를 늘리면
	# 임의의 문양/초상화가 실제 아이콘과 겹쳐 정보 화면이 깨져 보인다.
	var bg := Color(0.075, 0.09, 0.15, 0.98)
	var border := Color(0.30, 0.63, 0.78, 0.92)
	if frame_path.contains("evolution"):
		bg = Color(0.105, 0.075, 0.16, 0.98)
		border = Color(0.68, 0.46, 0.86, 0.95)
	elif frame_path.contains("achievement"):
		bg = Color(0.11, 0.095, 0.13, 0.98)
		border = Color(0.78, 0.61, 0.30, 0.95)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _ui_card(frame_path: String, crop: Rect2, height: float) -> Control:
	# crop은 기존 호출부 호환용. 카드 자체는 이미지 크롭 대신 안전한 코드 스타일을 쓴다.
	var card := Panel.new()
	card.custom_minimum_size = Vector2(466, height)
	card.add_theme_stylebox_override("panel", _codex_card_style(frame_path))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _ui_card_icon(parent: Control, path: String, pos: Vector2, icon_size: Vector2, dimmed := false) -> void:
	var icon := TextureRect.new()
	icon.texture = Assets.tex(path)
	icon.position = pos
	icon.size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(0.12, 0.12, 0.16, 0.75) if dimmed else Color.WHITE
	parent.add_child(icon)


func _ui_icon_socket(parent: Control, pos: Vector2, socket_size: Vector2) -> void:
	var socket := Panel.new()
	socket.position = pos
	socket.size = socket_size
	socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.075, 1.0)
	style.border_color = Color(0.82, 0.58, 0.24, 0.95)
	style.set_border_width_all(2)
	var radius := int(minf(socket_size.x, socket_size.y) / 2.0)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	socket.add_theme_stylebox_override("panel", style)
	parent.add_child(socket)


func _ui_card_label(parent: Control, text_value: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = label_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _relic_icon_path(relic: Dictionary) -> String:
	var generated := str(relic.get("icon", ""))
	if generated != "":
		return generated
	return str(PICON.get(relic.get("icon_key", ""), ""))


func _make_relic_codex_card(relic: Dictionary) -> Control:
	var unlocked := _has_relic(str(relic["key"]))
	var card := _ui_card("res://assets/ui/card_relic.png", Rect2(52, 64, 410, 96), 96)
	if unlocked:
		_ui_icon_socket(card, Vector2(14, 14), Vector2(68, 68))
	_ui_card_icon(card, _relic_icon_path(relic), Vector2(19, 19), Vector2(58, 58), not unlocked)
	_ui_card_label(card, str(relic["name"]) if unlocked else "???", Vector2(96, 7), Vector2(350, 26), 17, Color(0.55, 0.94, 1.0) if unlocked else Color(0.52, 0.54, 0.62))
	var detail := str(relic["desc"]) if unlocked else "해금 조건: " + str(_ach_by_key(str(relic["unlock"])).get("desc", relic["unlock"]))
	_ui_card_label(card, detail, Vector2(96, 32), Vector2(350, 54), 13, Color(0.82, 0.9, 0.96) if unlocked else Color(0.48, 0.5, 0.57))
	return card


# 유물 세트 시너지 카드 (도감 유물 탭 하단). 3종 다 모으면 발동 표시.
func _make_relic_set_card(set_def: Dictionary) -> Control:
	var relics: Array = set_def["relics"]
	var owned := 0
	for k in relics:
		if _has_relic(str(k)): owned += 1
	var active := owned >= relics.size()
	var scol: Color = set_def["color"]
	var card := _ui_card("res://assets/ui/card_relic.png", Rect2(52, 64, 410, 96), 96)
	var head := "◆ %s  (%d/%d)" % [set_def["name"], owned, relics.size()]
	if active: head += "  ✦발동✦"
	_ui_card_label(card, head, Vector2(18, 7), Vector2(428, 26), 17,
		scol if active else Color(0.6, 0.62, 0.7))
	_ui_card_label(card, str(set_def["desc"]), Vector2(18, 34), Vector2(428, 52), 13,
		Color(0.88, 0.92, 0.98) if active else Color(0.5, 0.52, 0.6))
	if not active:
		card.modulate = Color(0.7, 0.7, 0.74)
	return card


func _make_evolution_codex_card(kind: String, known: bool, seen: bool) -> Control:
	var recipe: Dictionary = EVO_RECIPE[kind]
	var card := _ui_card("res://assets/ui/card_evolution.png", Rect2(42, 22, 438, 154), 132)
	_ui_card_icon(card, str(WICON.get(kind, "")), Vector2(22, 43), Vector2(58, 58), not known)
	_ui_card_label(card, "+", Vector2(82, 50), Vector2(25, 42), 20, Color(0.88, 0.72, 1.0))
	_ui_card_icon(card, str(PICON.get(recipe["passive"], "")), Vector2(108, 51), Vector2(42, 42), not known)
	_ui_icon_socket(card, Vector2(376, 31), Vector2(80, 80))
	if seen:
		var result_icon := str(recipe.get("icon", WICON.get(kind, "")))
		_ui_card_icon(card, result_icon, Vector2(384, 39), Vector2(64, 64))
	else:
		_ui_card_label(card, "?", Vector2(376, 31), Vector2(80, 80), 30, Color(0.48, 0.46, 0.58)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var result_name := str(recipe["name"]) if seen else ("???" if known else "미발견 레시피")
	_ui_card_label(card, result_name, Vector2(164, 29), Vector2(210, 34), 17, Color(1.0, 0.78, 0.38) if seen else Color(0.66, 0.6, 0.76))
	var material_name := str(_passive_defs().get(recipe["passive"], {}).get("name", recipe["passive"]))
	var recipe_text := "%s Lv%d + %s" % [WNAMES.get(kind, kind), MAX_WLEVEL, material_name] if known else "무기를 획득하면 재료 공개"
	_ui_card_label(card, recipe_text, Vector2(164, 64), Vector2(210, 52), 12, Color(0.76, 0.82, 0.92))
	return card


func _make_union_codex_card(union_data: Dictionary, known: bool, seen: bool) -> Control:
	var card := _ui_card("res://assets/ui/card_evolution.png", Rect2(42, 22, 438, 154), 132)
	_ui_card_icon(card, str(WICON.get(union_data["a"], "")), Vector2(22, 43), Vector2(52, 52), not known)
	_ui_card_label(card, "+", Vector2(78, 50), Vector2(25, 42), 20, Color(0.62, 0.8, 1.0))
	_ui_card_icon(card, str(WICON.get(union_data["b"], "")), Vector2(106, 43), Vector2(52, 52), not known)
	_ui_card_icon(card, str(union_data.get("icon", "")), Vector2(385, 39), Vector2(64, 64), not seen)
	_ui_card_label(card, str(union_data["name"]) if seen else "???", Vector2(168, 29), Vector2(205, 34), 17, Color(0.64, 0.84, 1.0) if seen else Color(0.58, 0.62, 0.72))
	var info := "%s + %s" % [WNAMES.get(union_data["a"], union_data["a"]), WNAMES.get(union_data["b"], union_data["b"])] if known else "두 무기를 발견하면 공개"
	_ui_card_label(card, info, Vector2(168, 64), Vector2(205, 52), 12, Color(0.76, 0.82, 0.92))
	return card


func _make_enemy_codex_card(tier: Dictionary, kill_count: int) -> Control:
	var seen := kill_count > 0
	var card := _ui_card("res://assets/ui/card_relic.png", Rect2(52, 64, 410, 96), 96)
	_ui_card_icon(card, str(tier.get("sprite", "")), Vector2(19, 19), Vector2(58, 58), not seen)
	_ui_card_label(card, str(tier["name"]) if seen else "???", Vector2(96, 7), Vector2(350, 26), 17, Color(tier["color"]).lightened(0.25) if seen else Color(0.5, 0.52, 0.58))
	var detail := "누적 처치 %d · 체력 x%.1f · 경험치 %d" % [kill_count, float(tier["hp_mult"]), int(tier["xp"])] if seen else "아직 만나지 못한 몬스터"
	_ui_card_label(card, detail, Vector2(96, 32), Vector2(350, 54), 13, Color(0.82, 0.86, 0.92))
	return card


func _refresh_collection() -> void:
	if collection_list_box == null:
		return
	for child in collection_list_box.get_children():
		child.queue_free()
	for tab_key in collection_tab_buttons.keys():
		var selected := str(tab_key) == collection_tab
		collection_tab_buttons[tab_key].modulate = Color(1.25, 1.2, 0.9) if selected else Color(0.68, 0.72, 0.8)
	var known_data: Dictionary = meta.get("evo_known", {})
	var seen_data: Dictionary = meta.get("evo_seen", {})
	var union_seen_data: Dictionary = meta.get("union_seen", {})
	var enemy_data: Dictionary = meta.get("enemy_kills", {})
	# 유물 「노란 표식」: 보유 시 도감의 모든 진화·유니온 재료 공개 (P4 연동)
	var yellow_sign := _has_relic("yellow_sign")
	match collection_tab:
		"evolutions":
			for kind in EVO_RECIPE.keys():
				var known := yellow_sign or bool(known_data.get(kind, false))
				collection_list_box.add_child(_make_evolution_codex_card(str(kind), known, bool(seen_data.get(kind, false))))
		"unions":
			for union_data in UNION_DEFS:
				var known: bool = yellow_sign or (bool(known_data.get(union_data["a"], false)) and bool(known_data.get(union_data["b"], false)))
				collection_list_box.add_child(_make_union_codex_card(union_data, known, bool(union_seen_data.get(union_data["key"], false))))
		"relics":
			for relic in RELIC_DEFS:
				collection_list_box.add_child(_make_relic_codex_card(relic))
			for set_def in RELIC_SETS:
				collection_list_box.add_child(_make_relic_set_card(set_def))
		"enemies":
			for tier in GameConfig.enemy_tiers():
				collection_list_box.add_child(_make_enemy_codex_card(tier, int(enemy_data.get(tier["key"], 0))))
	var char_count := 0
	for character in GameConfig.characters():
		if _is_char_unlocked(character): char_count += 1
	var evolution_count := 0
	for kind in EVO_RECIPE.keys():
		if seen_data.get(kind, false): evolution_count += 1
	var union_count := 0
	for union_data in UNION_DEFS:
		if union_seen_data.get(union_data["key"], false): union_count += 1
	var enemy_count := 0
	for tier in GameConfig.enemy_tiers():
		if int(enemy_data.get(tier["key"], 0)) > 0: enemy_count += 1
	var relic_count := 0
	for relic in RELIC_DEFS:
		if _has_relic(str(relic["key"])): relic_count += 1
	collection_progress_label.text = "캐릭터 %d/%d · 진화 %d/%d · 유니온 %d/%d · 유물 %d/%d · 몬스터 %d/%d" % [char_count, GameConfig.characters().size(), evolution_count, EVO_RECIPE.size(), union_count, UNION_DEFS.size(), relic_count, RELIC_DEFS.size(), enemy_count, GameConfig.enemy_tiers().size()]


func _achievement_icon_path(achievement: Dictionary) -> String:
	var key := str(achievement["key"])
	if key.begins_with("win_"):
		return "res://assets/hero/%s_1.png" % key.trim_prefix("win_")
	if achievement.has("unlock"):
		return str(WICON.get(achievement["unlock"], "res://assets/items/icon_blessing.png"))
	var icons := {
		"first_win":"res://assets/items/icon_blessing.png", "survivor":"res://assets/items/icon_vitality.png",
		"slayer":"res://assets/items/icon_skull.png", "evolved":"res://assets/items/icon_meteor.png",
		"combo_master":"res://assets/items/icon_clone.png", "legend_weapon":"res://assets/items/icon_excalibur.png",
		"boss_slayer":"res://assets/items/icon_axe.png", "rich":"res://assets/items/coin.png",
		"hard_clear":"res://assets/items/icon_berserker.png", "no_revive":"res://assets/items/icon_ironwill.png",
		"abyss":"res://assets/items/icon_voidorb.png", "knife_thrower":"res://assets/items/sword.png",
	}
	return str(icons.get(key, "res://assets/items/icon_blessing.png"))


func _make_achievement_card(achievement: Dictionary, unlocked: bool) -> Control:
	var card := _ui_card("res://assets/ui/card_achievement.png", Rect2(86, 52, 350, 108), 102)
	if unlocked:
		_ui_icon_socket(card, Vector2(386, 17), Vector2(64, 64))
	_ui_card_icon(card, _achievement_icon_path(achievement), Vector2(393, 24), Vector2(50, 50), not unlocked)
	_ui_card_label(card, ("✓ " if unlocked else "◇ ") + str(achievement["name"]), Vector2(26, 7), Vector2(342, 25), 16, Color(1.0, 0.84, 0.42) if unlocked else Color(0.58, 0.6, 0.68))
	_ui_card_label(card, str(achievement["desc"]), Vector2(26, 31), Vector2(342, 36), 12, Color(0.84, 0.86, 0.92) if unlocked else Color(0.48, 0.5, 0.57))
	var reward_text := "+%d G" % int(achievement.get("gold", 0))
	var meta_rewards := _achievement_unlock_rewards(str(achievement["key"]))
	if achievement.has("unlock"):
		reward_text += " · 무기"
	if not meta_rewards.is_empty():
		reward_text += " · " + " · ".join(meta_rewards)
	_ui_card_label(card, reward_text, Vector2(26, 75), Vector2(342, 18), 11, Color(0.55, 0.92, 1.0) if unlocked else Color(0.52, 0.48, 0.58))
	return card


func _refresh_achievements() -> void:
	if ach_list_box == null:
		return
	for child in ach_list_box.get_children():
		child.queue_free()
	var done := 0
	for achievement in ACHIEVEMENTS:
		var unlocked := bool(meta.get("ach", {}).get(achievement["key"], false))
		if unlocked: done += 1
		ach_list_box.add_child(_make_achievement_card(achievement, unlocked))
	if ach_progress_label:
		ach_progress_label.text = "달성 %d / %d  ·  완료율 %d%%" % [done, ACHIEVEMENTS.size(), int(round(done * 100.0 / max(1, ACHIEVEMENTS.size())))]


func _nearest_landmark_hint() -> String:
	return ""


func _update_ui() -> void:
	if player and state == State.PLAYING:
		_check_achievements()
	if perf_label and perf_label.visible:
		var fps := Engine.get_frames_per_second()
		var ec := get_tree().get_nodes_in_group("enemies").size()
		perf_label.text = "%d FPS · 적 %d" % [fps, ec]
		perf_label.add_theme_color_override("font_color",
			Color(0.6, 1.0, 0.6) if fps >= 55 else (Color(1.0, 0.9, 0.4) if fps >= 40 else Color(1.0, 0.4, 0.4)))
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	if hp_text:
		hp_text.text = "%d / %d" % [int(max(0.0, player.hp)), int(player.max_hp)]
	xp_bar.max_value = xp_to_next
	xp_bar.value = xp
	var mm := int(time_survived) / 60
	var ss := int(time_survived) % 60
	# 타이머: 상단 중앙 대형. 국면은 그 아래 한 줄.
	timer_label.text = "%02d:%02d" % [mm, ss]
	if lv_label:
		lv_label.text = "LV %d" % level
	var phase := ""
	if boss_spawned:
		phase = "⚔ 보스전!"
	elif abyss_mode:
		phase = "심연 %d층" % stage_num
	var landmark_hint := _nearest_landmark_hint()
	if landmark_hint != "":
		phase += ("  ·  " if phase != "" else "") + landmark_hint
	skill_label.text = phase
	skill_label.add_theme_color_override("font_color",
		Color(1.0, 0.4, 0.4) if boss_spawned else Color(0.8, 0.65, 1.0))
	var map_name := "캠페인" if map_stage == 0 else str(GameConfig.stage_info(map_stage)["name"])
	info_label.text = "%s · 위험도 %d · [%s]\n처치 %d\n골드 %d" % [map_name, stage_num, diff_label, kills, run_gold]


# 바닥 장식물 텍스처(있는 것만) 1회 로드 후 캐시
func _floor_decor_textures() -> Array:
	if not _decor_loaded:
		_decor_loaded = true
		for nm in ["decor_flower1", "decor_flower2", "decor_bush", "decor_moss"]:
			var t := Assets.tex("res://assets/bg/%s.png" % nm)
			if t:
				_decor_cache.append(t)
	return _decor_cache


# ---------------------------------------------------------------------
#  배경 + 무기 비주얼 (오라 / 회전 검)
# ---------------------------------------------------------------------
func _draw_stage_layout_overlay() -> void:
	if stage_layout == null or map_stage <= 0:
		return
	var blocked := Color(0.008, 0.01, 0.018, 0.74)
	var ground := Color(stage_layout.tint.r * 0.42, stage_layout.tint.g * 0.42, stage_layout.tint.b * 0.42, 0.48)
	var edge := Color(stage_layout.tint.r * 0.9, stage_layout.tint.g * 0.9, stage_layout.tint.b * 0.9, 0.66)
	draw_rect(Rect2(Vector2.ZERO, WORLD), blocked)
	# 고리부터 깔고 중앙 원형 방을 위에 그려 제단 구역을 보존한다.
	for shape in stage_layout.shapes:
		if str(shape["kind"]) == "ring":
			var ring_center: Vector2 = shape["center"]
			var outer := float(shape["outer"])
			var inner := float(shape["inner"])
			draw_circle(ring_center, outer, ground)
			draw_circle(ring_center, inner, blocked)
			draw_arc(ring_center, outer, 0.0, TAU, 64, edge, 5.0)
			draw_arc(ring_center, inner, 0.0, TAU, 64, edge, 5.0)
	for shape in stage_layout.shapes:
		match str(shape["kind"]):
			"rect":
				var layout_rect: Rect2 = shape["rect"]
				draw_rect(layout_rect, ground)
				draw_rect(layout_rect, edge, false, 5.0)
			"circle":
				var circle_center: Vector2 = shape["center"]
				var circle_radius := float(shape["radius"])
				draw_circle(circle_center, circle_radius, ground)
				draw_arc(circle_center, circle_radius, 0.0, TAU, 64, edge, 5.0)
	for block in stage_layout.blocked_circles:
		var block_center: Vector2 = block["center"]
		var block_radius := float(block["radius"])
		draw_circle(block_center, block_radius, blocked)
		draw_arc(block_center, block_radius, 0.0, TAU, 64, edge.darkened(0.35), 5.0)
	_draw_stage_obstacle_art()
	_draw_stage_identity_marks(edge)


# 장애물 자리에 스테이지 전용 조형물 아트를 얹는다.
# 아트(mausoleum·lava_fissure·ice_lake 등)는 생성돼 있었지만 코드에 연결이 안 돼
# 맵이 '빈 벌판에 반투명 도형 4개'로 보였다. 뱀서는 조형물이 공간을 만든다.
const STAGE_OBSTACLE_ART := {
	1: ["tomb_cluster", "mausoleum"],
	2: ["lava_fissure", "obsidian_pillar"],
	3: ["ice_ruin"],   # 미로 벽이라 호수(ice_lake)는 안 맞는다
	4: ["void_monoliths", "ritual_altar"],
	5: ["wall_chamber"],
}
func _draw_stage_obstacle_art() -> void:
	var dirs := {1: "graveyard", 2: "hell_bridge", 3: "glacier", 4: "void_altar", 5: "demon_castle"}
	var dir_name := str(dirs.get(map_stage, ""))
	var names: Array = STAGE_OBSTACLE_ART.get(map_stage, [])
	if dir_name == "" or names.is_empty():
		return
	var i := 0
	# 사각 장애물: 영역을 꽉 채우도록 타일링 (한 장을 늘이면 뭉개짐)
	for r: Rect2 in stage_layout.blocked_rects:
		var tex := Assets.tex("res://assets/maps/%s/%s.png" % [dir_name, names[i % names.size()]])
		i += 1
		if tex == null:
			continue
		var cell := 128.0
		var cols := int(ceil(r.size.x / cell))
		var rows := int(ceil(r.size.y / cell))
		for cx in cols:
			for cy in rows:
				var p: Vector2 = r.position + Vector2(cx * cell, cy * cell)
				var w: float = min(cell, r.position.x + r.size.x - p.x)
				var h: float = min(cell, r.position.y + r.size.y - p.y)
				draw_texture_rect_region(tex, Rect2(p, Vector2(w, h)),
					Rect2(Vector2.ZERO, Vector2(w, h)))
	# 원형 장애물: 중앙에 한 장 (지름에 맞춤)
	for c in stage_layout.blocked_circles:
		var tex2 := Assets.tex("res://assets/maps/%s/%s.png" % [dir_name, names[i % names.size()]])
		i += 1
		if tex2 == null:
			continue
		var ctr: Vector2 = c["center"]
		var d := float(c["radius"]) * 2.1
		draw_texture_rect(tex2, Rect2(ctr - Vector2(d, d) * 0.5, Vector2(d, d)), false)


# Low-contrast map marks make a location readable before bespoke tiles are ready.
# They stay beneath actors, gems and projectiles.
func _draw_stage_identity_marks(edge: Color) -> void:
	match map_stage:
		1:
			var path_col := Color(edge.r, edge.g, edge.b, 0.22)
			draw_line(Vector2(1400, 330), Vector2(1400, 2470), path_col, 22.0)
			draw_line(Vector2(330, 1400), Vector2(2470, 1400), path_col, 22.0)
			for x in range(1060, 1800, 148):
				for y in [1080, 1720]:
					draw_rect(Rect2(x, y, 18, 30), Color(0.05, 0.06, 0.08, 0.42))
		2:
			var ember := Color(0.72, 0.22, 0.12, 0.25)
			for y in [1275, 1525]:
				draw_line(Vector2(190, y), Vector2(2610, y), ember, 9.0)
			for x in range(300, 2580, 260):
				draw_line(Vector2(x, 1330), Vector2(x + 90, 1470), ember, 5.0)
		3:
			for lake in stage_layout.blocked_circles:
				var c: Vector2 = lake["center"]
				var r := float(lake["radius"])
				draw_arc(c, r * 0.76, 0.0, TAU, 40, Color(0.38, 0.72, 0.95, 0.18), 12.0)
				draw_line(c + Vector2(-r * 0.42, 0), c + Vector2(r * 0.42, 0), Color(0.65, 0.88, 1.0, 0.12), 4.0)
		4:
			var core := Vector2(1400, 1400)
			var rune := Color(0.64, 0.38, 0.92, 0.28)
			draw_arc(core, 210, 0.0, TAU, 48, rune, 5.0)
			draw_arc(core, 125, 0.0, TAU, 32, rune, 3.0)
			for i in 8:
				var a := TAU * float(i) / 8.0
				draw_line(core + Vector2.from_angle(a) * 138, core + Vector2.from_angle(a) * 196, rune, 5.0)
		5:
			var tile := Color(0.70, 0.56, 0.38, 0.16)
			for p in range(1104, 1700, 80):
				draw_line(Vector2(p, 1080), Vector2(p, 1720), tile, 2.0)
				draw_line(Vector2(1080, p), Vector2(1720, p), tile, 2.0)


func _draw() -> void:
	var view := get_viewport_rect().size
	var center: Vector2 = player.position if player else view / 2.0
	var ts := 64.0
	var left: float = floor((center.x - view.x / 2.0 - ts) / ts) * ts
	var top: float = floor((center.y - view.y / 2.0 - ts) / ts) * ts
	var right: float = center.x + view.x / 2.0 + ts
	var bottom: float = center.y + view.y / 2.0 + ts

	draw_rect(Rect2(Vector2(left, top), Vector2(right - left, bottom - top)), Color(0.04, 0.04, 0.06))
	# 독립 맵은 기존 타일을 임시 장판으로 쓰고, 최종 PixelLab 장판으로 교체한다.
	var floor_path := "res://assets/bg/floor.png" if map_stage <= 1 else "res://assets/bg/floor_%d.png" % map_stage
	var floor_tex := Assets.tex(floor_path)
	if floor_tex:
		var tint := Color(0.86, 0.92, 0.82)   # 캠페인 기본 초록 풀밭 톤
		if map_stage > 0:
			tint = tint.lerp(Color(GameConfig.stage_info(map_stage)["tint"]), 0.42)
		# 타일 변형(_b, _c)이 있으면 셀 좌표 해시로 섞어 깔기 (약 60/22/18%)
		var variants: Array = [floor_tex]
		for suf in ["_b", "_c"]:
			var vt := Assets.tex(floor_path.replace(".png", suf + ".png"))
			if vt:
				variants.append(vt)
		var y := top
		while y < bottom:
			var x := left
			while x < right:
				var cell := Vector2i(int(x / ts), int(y / ts))
				var h: int = abs(hash(cell))
				var idx := 0
				if variants.size() > 1:
					var r: int = h % 100
					if variants.size() >= 3 and r >= 82:
						idx = 2
					elif r >= 60:
						idx = 1
				# 타일마다 밝기 미세 편차 → 반복감 완화 (얼룩덜룩한 자연스러움)
				var jit: float = 1.0 + (float((h / 100) % 13) - 6.0) * 0.012
				var ct := Color(tint.r * jit, tint.g * jit, tint.b * jit)
				draw_texture_rect(variants[idx], Rect2(Vector2(x, y), Vector2(ts, ts)), false, ct)
				x += ts
			y += ts

	_draw_stage_layout_overlay()
	# Final stage art replaces the prototype floor/mask while preserving the same
	# geometry for rendering and collision. Missing sets safely keep the prototype.
	if stage_map_texture:
		draw_texture(stage_map_texture, Vector2.ZERO)

	# 바닥 장식물 산포 (뼈/깨진돌/이끼/묘비) — 투명 오브젝트, 결정론적 배치로 반복감 제거
	var decors: Array = _floor_decor_textures()
	if decors.size() > 0 and stage_map_texture == null:
		var dc := 176.0   # 장식 셀(성글게)
		var dl: float = floor((center.x - view.x / 2.0 - dc) / dc) * dc
		var dt: float = floor((center.y - view.y / 2.0 - dc) / dc) * dc
		var dr: float = center.x + view.x / 2.0 + dc
		var db: float = center.y + view.y / 2.0 + dc
		var gy := dt
		while gy < db:
			var gx := dl
			while gx < dr:
				var hh: int = abs(hash(Vector2i(int(gx / dc) * 7 + 3, int(gy / dc) * 13 + 5)))
				if hh % 100 < 34:   # 약 34% 셀에 장식
					var dtex: Texture2D = decors[(hh / 100) % decors.size()]
					if dtex:
						var ox: float = float((hh / 7) % 110)
						var oy: float = float((hh / 11) % 110)
						var dw: float = 34.0 + float((hh / 3) % 14)
						var da: float = 0.72 + float((hh / 5) % 20) * 0.008
						draw_texture_rect(dtex,
							Rect2(Vector2(gx + ox, gy + oy), Vector2(dw, dw)), false,
							Color(0.82, 0.82, 0.86, da))
				gx += dc
			gy += dc

	# 월드 경계
	draw_rect(Rect2(Vector2.ZERO, WORLD), Color(0.4, 0.3, 0.5, 0.6), false, 4.0)

	# 스테이지 조형물 (화면 근처만 그림 — 컬링)
	for d in decorations:
		var dp: Vector2 = d["pos"]
		if abs(dp.x - center.x) > view.x / 2.0 + 80.0 or abs(dp.y - center.y) > view.y / 2.0 + 80.0:
			continue
		var dt := Assets.tex(d["tex"])
		if dt == null:
			continue
		var sc: float = d["s"]
		var w := dt.get_width() * sc
		var h := dt.get_height() * sc
		var rect := Rect2(dp - Vector2(w / 2.0, h * 0.7), Vector2(-w if d["flip"] else w, h))
		if d["flip"]:
			rect.position.x = dp.x + w / 2.0
		draw_texture_rect(dt, rect, false, d.get("tint", Color.WHITE))

	if player == null:
		return

	# 신성 오라 표시 (진화 시 지옥불 오라 아트)
	if weapons.has("aura"):
		var ar := _aura_radius()
		var inferno: Array = []
		if evolved.get("aura", false):
			inferno = Assets.frames("res://assets/anim/fx_inferno_evo")
			if inferno.is_empty():
				inferno = Assets.frames("res://assets/anim/fx_inferno")
		if inferno.size() > 0:
			var it: Texture2D = inferno[int(_blade_angle * 3.0) % inferno.size()]
			var isz := ar * 2.15
			draw_texture_rect(it, Rect2(player.position - Vector2(isz / 2.0, isz / 2.0), Vector2(isz, isz)), false, Color(1, 1, 1, 0.9))
		else:
			draw_circle(player.position, ar, Color(1.0, 0.95, 0.6, 0.10))
			# (금색 링 테두리 제거 — 구려서 뺌. 부드러운 채움 글로우만 유지)

	# 회전 검 표시 (진화 시 사신의 대검 아트).
	# 정적 스프라이트만 돌리면 죽어 보임 → 궤도 잔광 링 + 검마다 잔상 3겹 + 칼끝 섬광으로 속도감.
	if weapons.has("blade"):
		var cnt := _blade_count()
		var orad := _blade_orbit()
		var evo_b: bool = evolved.get("blade", false)
		var reaper: Array = Assets.frames("res://assets/anim/proj_reaper") if evo_b else []
		var sword_tex := Assets.tex("res://assets/items/sword.png")
		var bcol: Color = Color(1.0, 0.55, 0.35) if evo_b else Color(0.75, 0.9, 1.0)
		var bsz: float = 19.0 if evo_b else 12.0   # 크기 축소 (26/16 → 너무 컸음)
		# 궤도 잔광 링 — 검이 훑고 지나간 자리
		draw_arc(player.position, orad, 0.0, TAU, 64, Color(bcol.r, bcol.g, bcol.b, 0.09), 3.0)
		for i in cnt:
			var ang := _blade_angle + i * TAU / cnt
			var btex: Texture2D = null
			if evo_b and reaper.is_empty():
				# 전용 사신 스프라이트가 아직 없어도 기본 검으로 되돌아가지 않음.
				# 아래 procedural crescent fallback이 진화 무기의 실루엣을 담당한다.
				btex = null
			elif reaper.size() > 0:
				btex = reaper[int(_blade_angle * 4.0 + i) % reaper.size()]
			else:
				btex = sword_tex
			if btex:
				# 잔상: 지나온 궤적에 3겹 (뒤로 갈수록 옅고 작게)
				for k in range(3, 0, -1):
					var ta: float = ang - k * 0.15
					var tp: Vector2 = player.position + Vector2(cos(ta), sin(ta)) * orad
					var tsz: float = bsz * (1.0 - 0.07 * k)
					draw_set_transform(tp, ta + PI / 2.0 + BLADE_ART_FIX, Vector2.ONE)
					draw_texture_rect(btex, Rect2(Vector2(-tsz, -tsz), Vector2(tsz * 2.0, tsz * 2.0)), false,
						Color(bcol.r, bcol.g, bcol.b, 0.32 - k * 0.08))
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var bpos := player.position + Vector2(cos(ang), sin(ang)) * orad
			draw_circle(bpos, bsz * 0.34, Color(bcol.r, bcol.g, bcol.b, 0.20))
			if btex:
				draw_set_transform(bpos, ang + PI / 2.0 + BLADE_ART_FIX, Vector2.ONE)
				draw_texture_rect(btex, Rect2(Vector2(-bsz, -bsz), Vector2(bsz * 2.0, bsz * 2.0)), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				if evo_b:
					draw_circle(bpos, bsz * 0.34, Color(1.0, 0.25, 0.12, 0.45))
					draw_arc(bpos, bsz * 0.86, ang - 1.05, ang + 1.05, 18, bcol, 4.0)
					draw_arc(bpos, bsz * 0.62, ang - 0.72, ang + 0.72, 14, Color(1.0, 0.9, 0.55), 2.0)
				else:
					draw_circle(bpos, 6.0, Color(0.85, 0.95, 1.0))
					draw_line(bpos + Vector2(0, 8), bpos + Vector2(0, -10), Color(0.8, 0.9, 1.0), 3.0)

	# 나침반: 화면 밖 보스 방향만 표시 (아이템 위치 화살표는 제거 — 추후 '노란 표식' 유물로만 공개)
	if state == State.PLAYING:
		var half := view * 0.5
		var edge: float = min(half.x, half.y) - 34.0
		if boss and is_instance_valid(boss):
			var tb: Vector2 = boss.position - player.position
			if abs(tb.x) >= half.x or abs(tb.y) >= half.y:
				_draw_compass_arrow(player.position + tb.normalized() * edge, tb.angle(), Color(1.0, 0.25, 0.25))


func _draw_compass_arrow(pos: Vector2, ang: float, col: Color) -> void:
	draw_set_transform(pos, ang, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, 0), Vector2(-6, -7), Vector2(-6, 7)]), Color(col.r, col.g, col.b, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
