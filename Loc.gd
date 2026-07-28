class_name Loc
extends RefCounted
# =====================================================================
#  로컬라이제이션 (한/영). Loc.lang = "ko" | "en" ; Loc.t("key")
#  메뉴/UI 핵심 문자열. 키가 없으면 키 자체를 반환(안전).
# =====================================================================

static var lang := "ko"

const TABLE := {
	# 타이틀 / 메뉴
	"start": {"ko": "게 임  시 작", "en": "START"},
	"shop": {"ko": "영구 강화 상점", "en": "UPGRADE SHOP"},
	"options": {"ko": "옵션", "en": "OPTIONS"},
	"gold_owned": {"ko": "보유 골드: %d G", "en": "Gold: %d G"},
	"char_select": {"ko": "— 캐릭터 선택 —", "en": "— SELECT CHARACTER —"},
	"diff_select": {"ko": "— 난이도 선택 —", "en": "— SELECT DIFFICULTY —"},
	"back": {"ko": "← 뒤로", "en": "← BACK"},
	# 옵션
	"opt_title": {"ko": "옵션", "en": "OPTIONS"},
	"music_vol": {"ko": "음악 볼륨", "en": "Music Volume"},
	"sfx_vol": {"ko": "효과음 볼륨", "en": "SFX Volume"},
	"fullscreen_on": {"ko": "전체화면: 켜짐", "en": "Fullscreen: ON"},
	"fullscreen_off": {"ko": "전체화면: 꺼짐", "en": "Fullscreen: OFF"},
	"lang_btn": {"ko": "언어: 한국어", "en": "Language: English"},
	"close": {"ko": "닫기", "en": "CLOSE"},
	# 일시정지 / 종료
	"paused": {"ko": "일시정지", "en": "PAUSED"},
	"resume": {"ko": "이어하기 (ESC)", "en": "RESUME (ESC)"},
	"to_title": {"ko": "타이틀로", "en": "TO TITLE"},
	"restart": {"ko": "다시 시작", "en": "RESTART"},
	"abyss": {"ko": "심연 모드로 계속", "en": "CONTINUE (ABYSS)"},
	"victory": {"ko": "승리!", "en": "VICTORY!"},
	"gameover": {"ko": "게임 오버", "en": "GAME OVER"},
	# 레벨업 / 등급
	"levelup": {"ko": "LEVEL UP!  (Lv %d)", "en": "LEVEL UP!  (Lv %d)"},
	"r_common": {"ko": "일반", "en": "Common"},
	"r_rare": {"ko": "희귀", "en": "Rare"},
	"r_epic": {"ko": "영웅", "en": "Epic"},
	"r_legend": {"ko": "전설", "en": "Legend"},
}

static func t(key: String) -> String:
	if TABLE.has(key):
		return TABLE[key].get(lang, TABLE[key]["ko"])
	return key

static func toggle() -> void:
	lang = "en" if lang == "ko" else "ko"
