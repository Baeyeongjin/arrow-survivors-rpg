extends SceneTree
# 캐릭터 고유 패시브(성장 특성) 불변식 검증:
#  1) 모든 캐릭터가 gear 독립적인 growth 패시브를 갖는다(stat이 player 스탯 스케일링 집합 안).
#  2) tier 바닥값 1 → Lv1부터 패시브가 항상 켜진다(장비 무관 항상 유지). 상한 maxt 불변.
#  3) trait_desc가 장착무기(weapon1, gear가 대체)에 의존하는 문구를 갖지 않는다.
# _apply_char_growth의 stat match 분기와 KNOWN_STATS가 어긋나면 조용히 무효화되므로 여기서 잡는다.

const KNOWN_STATS = ["damage", "area", "cooldown", "crit", "regen",
	"armor", "amount", "speed", "xp", "greed", "magnet"]


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		quit(1)


# Main._apply_char_growth 와 동일한 tier 공식 (바닥 1, 상한 maxt).
func _tier(level: int, per: int, maxt: int) -> int:
	return clampi(level / max(1, per), 1, maxt)


func _initialize() -> void:
	for c in GameConfig.characters():
		var key := str(c["key"])
		var g: Dictionary = c.get("growth", {})
		_expect(not g.is_empty(), "캐릭터 %s 에 growth 패시브가 없음" % key)
		var stat := str(g.get("stat", ""))
		_expect(stat in KNOWN_STATS,
			"캐릭터 %s 의 growth stat '%s' 가 _apply_char_growth 분기에 없음(무효화됨)" % [key, stat])
		var per: int = int(g.get("per", 0))
		var maxt: int = int(g.get("max", 0))
		_expect(per >= 1, "캐릭터 %s per 은 1 이상이어야 함: %d" % [key, per])
		_expect(maxt >= 1, "캐릭터 %s max 는 1 이상이어야 함: %d" % [key, maxt])
		# Lv1부터 최소 1단계 = 장비 무관 항상 유지
		_expect(_tier(1, per, maxt) == 1, "캐릭터 %s 패시브가 Lv1에서 꺼져있음" % key)
		# 상한 보존: 충분히 높은 레벨에서 정확히 maxt
		_expect(_tier(maxt * per + per, per, maxt) == maxt,
			"캐릭터 %s 패시브 상한이 maxt(%d)와 다름" % [key, maxt])
		# gear가 대체하는 weapon1(시작무기) 이름을 특성 설명이 자동발동으로 주장하면 안 됨.
		# (weapon2는 gear와 무관하게 항상 유지되므로 허용)
		if c.has("trait_desc") and c.has("weapon"):
			var w1_kor: String = {
				"aura": "오라", "poison_cloud": "독안개", "cleave": "식칼",
				"blood_sword": "흡혈검", "fireball": "화염구",
			}.get(str(c["weapon"]), "")
			if w1_kor != "":
				_expect(not str(c["trait_desc"]).contains(w1_kor),
					"캐릭터 %s 특성이 gear로 대체되는 시작무기(%s)를 주장함" % [key, w1_kor])
	print("PASSIVE_OK")
	quit(0)
