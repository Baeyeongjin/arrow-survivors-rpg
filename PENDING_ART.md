# 인수인계 (2026-07-03 갱신) — M1/M2 대부분 완료

## ✅ 나이트 자동조준 + 업적 시스템 + 특수무기 — 완료
- 나이트 기본공격(_basic_knight): 방향키 → 최근접 적 자동조준.
- 업적 17종(ACHIEVEMENTS 상수) + Meta [ach] 섹션 저장(구 ach_knife 마이그레이션). 매프레임 _check_achievements(_update_ui) + 승리 판정(_show_end). 골드 보상 즉시 지급 + 상단 토스트(ach_toast).
- 업적 화면: achievements_panel = 오르네이트 menu_panel.png 프레임 + ScrollContainer 목록(_refresh_achievements) + 타이틀 「업적」 버튼. 프레임 코너장식 피해 제목/진행/닫기 중앙정렬 → 겹침 없음(PIL 검증).
- 해금 특수무기 2종: excalibur(성검, 하드클리어 해금) icon_excalibur.png / void_orb(공허구, 800킬 해금) icon_voidorb.png + VoidZone.gd(흡입+DoT 블랙홀). UNLOCK_WEAPONS로 카드풀 게이팅(knife 포함 일반화).
- ⚠️ 신규 class_name 스크립트(VoidZone) 추가 시 `godot --headless --import`로 전역클래스 캐시 갱신 필요(안 하면 "Identifier not declared").

## ✅ 밸런스 개편(도전적) + 진화 5단계 — 완료
- 밸런스: XP곡선 5+lv*3+lv²*0.7(후반 가파름), 적 시간계수 +180%, 스테이지HP×1.35, 웨이브 최대20, 조합조건 Lv4.
- 진화 5단계: GameConfig char_stages 5개 + hero_stage_for_level Lv10/30/50/75 + stage_power[1,1.12,1.26,1.42,1.62]. Player.set_stage에서 진화 시 damage_mult·max_hp 강화(중복방지 _evo) + 소량회복.
- 5단계 아트: create_character_state(베이스/4단계에서)로 5명 생성 → v3 walk(6f)/attack(8f) 애니 → assets/hero/<key>_5.png + assets/anim/<key>_5_walk(7f)/_5_attack(9f). 로드테스트 0 NULL.
  - 5단계 캐릭터 ID: archer 91e1c3ad / knight 9332876d / mage b51210a0 / rogue 4072f27b / priest 88854cfe
- 오르네이트 menu_panel.png는 밀집 메뉴엔 부적합(코너장식 침범) → 업적 화면용으로 보류.

## ✅ 메뉴 창 개편 (일시정지/상점/옵션) — 완료
- 오르네이트 메뉴 패널: assets/ui/menu_panel.png (create_ui_asset 512x512, 금/네이비 테두리+코너 문양, 다크 내부). _menu_style()=_sbtex(menu_panel, 88) 9-slice. 테두리 두께 ~58px, margin 88로 코너 문양 온전히 캡처.
- 세 창 배경에 적용: 일시정지 pbg, 옵션 obg, 상점 shop_bg(신규). PIL 9-slice 프리뷰로 넓은 상점(1232px)에서도 왜곡 0 확인.
- 일시정지: 스탯/도감 텍스트를 ScrollContainer(process_mode ALWAYS)에 담아 스크롤 가능. 하단 버튼 3개 가로 균등+간격.
- 상점: 초기화(전액 환불) 버튼 추가(_reset_upgrades: 소모 골드 합 환불+up 0), 버튼 간격 확대(row 82/height 66), reset/back 하단 나란히.

## ✅ 아이콘 임포트 수정 + 로그/프리스트 흉상 — 완료
- ⚠️ 함정: 애니 프레임을 cp로 items/icon_*.png에 덮어쓰면 Godot 임포트가 `valid=false`로 깨져 .ctex 미생성 → Assets.tex가 null → 카드 아이콘 빈칸. icon_boomerang/fireball/holy/whip 4개가 그랬음.
  해결: `.png.import` + `.godot/imported/<name>.png-*.{md5,ctex}` 삭제 후 `godot --headless --import`. Godot 로드 테스트 18/18 통과.
  → 앞으로 아이콘은 덮어쓰기 후 반드시 강제 재임포트 + `grep -rl valid=false assets --include=*.import`로 확인.
- 로그/프리스트 HUD 흉상: create_map_object(view=side, 128px, "front facing portrait bust ...")로 생성 → assets/ui/portrait_rogue.png, portrait_priest.png. HUD 뱃지가 portrait_<key> 우선 사용이라 자동 연동. 5명 전원 흉상 통일.
  (base64 character_to_portrait는 여전히 전송 손상으로 불가 → map object 방식으로 우회 성공.)

## ✅ 궁극기 확장 + 부메랑 수정 — 완료
- 로그/프리스트 전용 궁극기 신설: _ult_rogue「그림자 처형」(0.8s 무적+반경360 다중 치명타), _ult_priest「신의 심판」(60% 대회복+반경260 폭발+낙뢰12). _ultimate() 분기 + ult_names 추가.
- 궁 이펙트 애니 3종: fx_shadowstorm(로그), fx_divine(프리스트) 신규 + fx_arrowstorm(아처) 재생성(기존 빈약본→화살 소용돌이로 교체). 각 9프레임 128px.
- 부메랑 수정: 기존이 "곡괭이"처럼 나오고 카드 아이콘이 스핀 0프레임(흐릿)이라 안 보였음 → V자 목재 부메랑으로 재생성. proj_boomerang(스핀 9f) 교체 + icon_boomerang은 깨끗한 베이스 스프라이트로 교체.
- 헤드리스 빌드 에러 0, 필름스트립 검증.

## ✅ 무기/스킬/조합 심화 개선 — 완료
- 로그/프리스트 전용 스킬 6종 신설(아트+코드): 표창난무(shuriken)/그림자습격(shadow_strike)/맹독도포(venom_coat·패시브) / 성역(sanctuary)/심판(smite)/축복(blessing·패시브).
  - 아트: proj_shuriken, fx_shadow, fx_sanctuary(각 9프레임) + icon_shuriken/shadow/venomcoat/sanctuary/smite/blessing.
  - CHAR_SKILLS/SKILL_INFO/BASIC_ICON(로그·프리스트)/TIMED·RANGED_WEAPONS 등록, 쿨다운·_fire_* 4종, venom_coat(명중 둔화)·blessing(재생+방어) 패시브 처리.
- 신규 무기 6종 진화 추가: EVO_SOLO(knife/fireball/boomerang/holy/venom/whip) = Lv5 단독 진화(패시브 불필요). 각 _fire_*에 evolved 분기(피해/개수/범위↑).
- 신규 조합 5종: fire_frost(증기폭발)/venom_fire(맹독화염)/holy_lightning(천벌강림)/whip_boomerang(난무)/arrow_fireball(폭렬화살) + 각 효과 코드.
- 사용성: 무기 강화 카드가 MAX 근접 시 진화 조건 안내(_evo_hint), 도감(스탯창)에 "진화 조건" 섹션 추가.
- 헤드리스 빌드 에러 0, 필름스트립 검증.

## ✅ HUD 디자인 개편 — 완료
- 캐릭터 초상화 뱃지: assets/ui/hud_portrait_badge.png (PixelLab create_ui_asset 256x256, 금/청 프레임+룬젬). 생성물의 흰 배경을 PIL로 다크 슬레이트 치환 후 사용. HUD 좌상단에 뱃지+캐릭터 초상화(흉상 우선, 없으면 스프라이트).
- HP/XP 게이지: 코드 스타일링(_bar_bg 다크+금테두리 / _fill_box). HP=빨강+"현재/최대" 수치(hp_text), XP=파랑 얇게. 정렬 리스크 0.
- HUD 코드: _build_ui의 상단 클러스터 재작성(뱃지 gx 기준 게이지 배치), _update_ui에 hp_text 갱신. 기존 hp_frame.png(해골)는 미사용 처리.
- ⚠️ 버그 수정: _refresh_inventory_ui의 wnames에 신규무기 5종 누락 → 획득 시 KeyError 크래시였음. wnames.get(kind, kind)로 방어 + 5종 추가.

## ✅ M2 20분 런 구조 재설계 — 완료
- 진행이 "보스 처치"→"시간 기반"으로 전환: 5스테이지 × 4분 = 20분 (RUN_TIME 1200, STAGE_TIME 240).
- 스테이지 자동 전환(_advance_stage): 4/8/12/16분에 배경·난이도(적 HP×1.28/속도×1.05)·소량회복.
- 보스: 각 스테이지 종반 45초 전 등장(3:15/7:15/11:15/15:15/19:15), boss_1~5. 처치=회복+보너스카드. 스테이지 진행과 분리.
- 승리: 20:00 생존(_victory) 또는 보스5 조기 처치. 승리 후 심연(abyss_mode) 무한 지속.
- VS 시그니처 호드 이벤트(_spawn_horde): 140초마다 한 방향에서 20+6*stage 마리 떼거리 + 배너/셰이크.
- 시간 난이도 램프: 스폰 웨이브 최대 16마리, 간격 최소 0.45초; 적 HP 시간계수(최대 +120%).
- HUD: "생존 MM:SS / 20:00" 표시, 심연 모드는 "심연 N층".
- 헤드리스 구동 에러 0.

## ✅ M2 신규 무기 5종 — 완료 (아트+애니+이펙트+코드)
파이어볼/부메랑/천벌(holy)/독날(venom)/채찍(whip). PixelLab create_map_object + animate_object(v3, 1gen/dir)로 생성.
- 투사체 애니: assets/anim/proj_fireball, proj_boomerang (각 9프레임, Arrow.anim_dir 루프)
- 이펙트 애니: assets/anim/fx_holy, fx_poison, fx_whip (각 9프레임, spawn_fx 1회재생). 파이어볼은 기존 fx_explosion 재사용.
- 아이콘: assets/items/icon_fireball/boomerang/venom/holy/whip.png (독날 아이콘=투사체 스프라이트 겸용)
- 코드(Main.gd): ALL/TIMED/RANGED_WEAPONS 등록, WICON, _weapon_cooldown, _fire_weapon, _fire_fireball/boomerang/holy/venom/whip, wnames, _weapon_desc.
  - Arrow.gd: fx_hit/fx_hit_size 필드 추가(명중 이펙트). SkyStrike.gd: fx_name 필드(천벌=fx_holy).
  - 파이어볼=착탄폭발AoE, 부메랑=99관통 스핀, 천벌=SkyStrike 낙하, 독날=둔화+독무fx, 채찍=전방부채꼴 근접+넉백.
  - 전부 일반 풀(모든 캐릭터 획득 가능). 헤드리스 구동 에러 0, 필름스트립 검증 완료.
- 오브젝트 ID(8h 후 자동삭제): fireball 0699485e / boomerang 2b65b17d / venom 788c0a7b / holy 7c605735 / poison 550637ef / whip 71a27c18

## ✅ M2 신규 몬스터 6종 — 완료
헬하운드/파이어임프/프로스트골렘/아이스위습/좀비/고블린: 스프라이트+걷기애니+GameConfig 티어 등록 끝 (스테이지별 배치).

## ✅ M2 신규 캐릭터 로그/프리스트 — 완료
- 로그(암살자): rogue_1~4 스프라이트 + 걷기/공격 애니 4단계 + GameConfig 등록 (이속1.25/치명특화, 시작무기 knife)
- 프리스트(성직자): priest_1~4 스프라이트 + 걷기/공격 애니 4단계 + GameConfig 등록 (체력1.15/재생·오라, 시작무기 aura)
- 캐릭터 선택 화면 5명 동적 배치 완료
- ✅ 캐릭터 선택 카드 재설계 완료:
  - 전용 세로형 카드 프레임을 PixelLab로 생성해 적용: assets/ui/card_char.png (384x688, 다크 인테리어 + 금/청 룬 테두리). ui_asset_id=f529509c-df4e-4bbd-a57e-fbb6d06295ef
  - 프레임은 9-slice 대신 **비율 고정 STRETCH_SCALE**(카드 ch=cw*688/384)로 붙여 왜곡 0. 내부 여백 측정치 가로 8.6~91% / 세로 11~87.5%.
  - 배치 비율: 스프라이트 isz=cw*0.78 @y=ch*0.12, 이름 @y=ch*0.60(24px), 설명 @y=ch*0.71(14px). 전부 밝은색+어두운 outline으로 가독성 확보.
  - 5명 전원 동일 전신 스프라이트(<key>_1.png)로 통일. 포커스/호버 시 프레임 밝아짐.
  - PIL 합성 프리뷰로 배치 검증 후 값 확정.
- ❌ AI 흉상(portrait) 업로드 결론: **이 채팅 인터페이스에서는 create_portrait_character의 base64 이미지 전달이 구조적으로 불가능.**
  검증: rogue_1.png(1004B) base64를 붙였더니 디코딩 결과 1002B, 125번째 문자에서 손상 → "broken data stream". 32px로 줄여도 580자라 손상 지속. 툴 인자는 내 토큰 생성으로만 채워져 고엔트로피 base64를 무손실 재현 불가.
  → 흉상이 정말 필요하면: PixelLab 웹앱에서 직접 생성해 portrait_<key>.png를 assets/ui/에 넣으면 카드 코드가 자동으로 흉상을 우선 사용하도록 되돌릴 수 있음(현재는 통일감 위해 전신 사용). 아처/나이트/메이지 흉상 3장이 됐던 건 base64가 우연히 무손실이었던 것.

## ✅ M1 완료
- 가로 1280x720 + 순차 메뉴 플로우(타이틀→캐릭터→난이도)
- 옵션 메뉴 (음악/효과음 볼륨, 전체화면, 언어) — Meta 영구저장, 오디오 버스
- 컨트롤러 지원 (스틱 이동, A/RB 대시, X/LB 궁, 카드 포커스)
- 한/영 로컬라이제이션 기반: Loc.gd 번역 테이블 + 옵션 언어 토글(변경 시 씬 리로드)
  - 번역 완료: 메뉴 흐름(타이틀/캐릭터선택/난이도/옵션/일시정지/종료/레벨업 헤더/등급명)
  - ⚠️ 미번역(한국어 고정): GameConfig의 캐릭터/난이도/무기/스킬/패시브 이름·설명, 조합/업적 텍스트, HUD 스탯줄.
    → 다음 작업: 이들 데이터에 _en 필드 추가 + Loc 헬퍼로 조회

## 🎨 UI 수정 완료 (이번 세션)
- 전역 nearest 필터(카드/아이콘 화질), 카드 9-slice 여백 44(프레임 왜곡 수정)
- 타이틀 버튼 세로 간격 재배치(옵션/골드 겹침 해결)

## 다음 로드맵 (ROADMAP.md 참고)
- M2 잔여: 무기 12종 확대, 런 20분 재설계, 업적 20종
- M3 폴리시: 보스 인트로, 사망 애니, 환경 파티클, (초상화 재생성)
- M4 출시: 스토어 캡슐 아트/트레일러/데모

## 기존 주요 ID
- 아처 155fe28c / 나이트 cdd50035 / 메이지 34d99b0e
- 로그 012dd4c5(1) 96931b78(2) dc932afb(3) 4de2af6c(4)
- 프리스트 00a55976(1) a3d3a9ee(2) 1cde1f20(3) 21326ada(4)
- 보스 bd03c69c/e2f834ed/f73316a8/feea124c
