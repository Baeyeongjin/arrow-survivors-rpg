# 애니메이션/디자인 전면 보강 — 진행 추적 (대작업)

## ✅ 보스 뱀서화 + 그로테스크 보스 8종 (완료)
- 엘리트 상자 제거 → **상자 보스 전용**(on_enemy_killed). 엘리트는 골드·젬만 확정.
- 보스 등장 뱀서식: `BOSS_INTERVAL=120s`마다 등장(next_boss_time), 처치 시 상자, **보스 중에도 호드 지속**(spawn_timer 게이트 제거, 보스 중 스폰 1.4배 완화). 사신은 20:00 그대로.
- 그로테스크 보스 8종(boss_1~5/reaper/boss_lich/boss_spider) 128px high detail 정적+걷기 교체(assets/boss/<key>.png + anim/<key>_walk). 옛 애니 제거, 원본 백업 _bak_boss/. Boss.gd는 anim walk→boss/<key>.png 순. 로드테스트 클린.
- 보스 object UUID: boss_1 dfefbc8a / boss_2 1f452908 / boss_3 36e36301 / boss_4 7634b233 / boss_5 593eec0f / reaper 3796313c / boss_lich adcecd2b / boss_spider 4d5030be.

## ▶▶ #32 무기 대폭 추가 (진행중) ◀◀
- base 무기 13→**35종 (목표 달성)**. 신규 22종(각 ALL_WEAPONS+_weapon_cooldown+_fire_weapon디스패치+_fire_함수+WICON+_weapon_desc+wnames3곳):
  - W1: chakram(방사날)/spear(관통창)/starfall(유성)/holy_water(장판)
  - W2: flamethrower(부채꼴불)/ice_lance(관통+둔화)/crossbow(단발대관통)/holy_cross(4~8방향십자)
  - W3: poison_cloud(독구름VoidZone)/quake(주변SkyStrike링)/spread_shot(산탄)/soul_bolt(다중조준)
  - W4: holy_beam(상하관통광선)/bone_spiral(회전방사뼈탄,Time기반각)/moonlight(화면전역SkyStrike폭격)/axe(포물선고화력, **Arrow.gravity 필드 신규**)
  - W5: homing_skull(유도)/magma_floor(발밑VoidZone,불흔적)/thorn_burst(근접방사링)/chain_bolt(다중SkyStrike낙뢰)/frost_ring(방사둔화)/blood_sword(**Arrow.lifesteal 배선 신규**, _apply_arrow_hit서 회복)
  - 전부 Arrow/SkyStrike/VoidZone 재사용. 아이콘 PixelLab 64px(assets/items/icon_*.png). 로드테스트 클린.
  - **VoidZone.col 필드 신규**: 장판 색 구분(용암=주황/독=초록/성수=금빛), pull>0(공허구)만 오브텍스처. 장판 채움 원 추가.
- 남음: 신규무기 EVO_RECIPE(진화)+유니온. 신규무기 아이콘 일부 작음(soulbolt/holycross/holybeam)—필요시 재생성.

## ▶▶ #33 패시브 대폭 추가 (진행중) ◀◀
- 패시브 10→**18종**. 신규 8종(PICON+_passive_defs+_add_passive, 레벨업 풀은 _passive_defs 전체 자동순회):
  - crown(경험치+8%,xp_mult)/stone_mask(골드+12%,greed_mult)/clover(행운+10%,diff_loot)/keen_eye(치명타확률+6%)/berserker(치명타피해+30%)/vitality(최대체력+12%)/iron_will(방어+1·재생+0.4)/swiftness(이속+8%·자석+15)
  - **치명타 시스템 신규 배선**: Player.crit_chance/crit_mult, _apply_arrow_hit서 판정→take_damage(dmg,is_crit). Boss.take_damage(d,_crit=true) 시그니처 확장. 흡혈도 크리 반영.
  - 아이콘 PixelLab 64px 8종(assets/items/icon_crown/stonemask/clover/keeneye/berserker/vitality/ironwill/swiftness.png). 로드테스트 클린.
- MAX_PASSIVES=6(뱀서 동일).

## ▶▶ #34 오롤로기온 + 저주 스탯 (진행중) ◀◀
- **오롤로기온(clock 픽업)**: 바닥 픽업 12%(로자리 12→10%로 조정). on_pickup "clock" → 전체 적 apply_slow(1.0,4.0)=완전정지 + 시안 플래시·링. Pickup.gd clock 비주얼(시안 시계)+글로우. 아이콘 clock.png(있으면 우선).
- **저주 스탯(curse_mult)**: skull 패시브 "[저주] 해골" +12%/Lv(19번째 패시브). curse_mult 배선 — 스폰밀도(cnt*curse, 상한48→60)·적체력(*curse)·적속도(*(1+.5(c-1)))·골드(collect_coin*curse)·경험치(_gain_xp*curse). 런시작 curse_mult=1.0 리셋. 리스크/리워드 파밍 노브.
- 아이콘: icon_skull.png(패시브), clock.png(픽업). 로드테스트 클린.

## ▶▶ 신규무기 발사 버그 수정 + 발사 섬광 ◀◀
- **[치명 버그 수정]** 신규 22종이 발사 안 됨 원인=`TIMED_WEAPONS` 상수 누락. `_add_weapon`은 `k in TIMED_WEAPONS`일 때만 wtimer 등록→발사루프 진입. 22종 전부 TIMED_WEAPONS에 추가. 런타임 검증 10/10 등록 확인. (blade/aura는 연속형이라 _process 직접처리, 제외 정상)
- **발사 섬광(WMUZZLE)**: 무기별 [색,스타일] 맵 22종. _weapon_muzzle(kind)를 발사루프에서 중앙 1회 호출→Effect(slash 전방부채꼴/spin 회전/ring 방사/burst 파티클) 스폰. 방향=player._last_dir. area_mult 반영. 로드테스트 클린.
- **투사체 차별화 완료**: Arrow에 spin(자체회전)/trail_col(트레일색)/scale_mul(크기) 필드 추가. Arrow기반 신규무기 전부 자기 아이콘 스프라이트로 발사 + 무기별 특수효과:
  - 회전(spin): 차크람16/성십자10/뼈나선13/도끼18/가시20/서리고리12
  - 트레일: 창격(청)/화염(주황)/얼음창(하늘)/석궁/산탄(금)/혼탄/성광선/유도해골(초록)/흡혈검(적)
  - fx_hit 보강: 얼음창 fx_frost 등. SkyStrike/VoidZone계열(별똥별·월광·대지·연쇄·성수·독안개·용암)은 col/fx로 이미 차별.
- PixelLab 플레이어 공격모션은 미착수(원하면 추가 가능).

## ▶▶ 애니 완성도 프로젝트 시작 — ① 몬스터 죽음 연출 ◀◀
- **죽음 시퀀스(코드, 전 몹 즉시 적용)**: Enemy에 _dying/_die_t/DIE_DUR(0.3). take_damage서 hp<=0→on_enemy_killed(보상) 후 즉시 free 대신 _dying=true+remove_from_group("enemies"). _process 최상단 죽음분기(AI정지, _die_t 소진 시 free). _draw 죽음분기: 흰빛 팝(1.28배)→수축→위로 떠오르며 페이드. 로드 클린.
- **남은 결정**: 코드 팝으로 충분한지 / PixelLab 죽음 버스트 이펙트(언데드=소울, 육체=피, 악마=재, 얼음=파편) 얹을지 / 몹별 전용 죽음 스프라이트(무거움). 사용자 확인 대기.
- 참고: 몹 오브젝트는 8h 자동삭제라 원본 없음 → 죽음 애니는 (a)스프라이트로 오브젝트 재생성+animate_object 또는 (b)공용 죽음 이펙트 오버레이 방식.
- **애니 완성도 전체 로드맵**(사용자 순차진행): ①몹죽음 ②피격반응강화 ③신규22무기 투사체애니 ④몹4방향걷기 ⑤프레임수↑ ⑥픽업애니 ⑦맵타일셋 ⑧진화전용비주얼 ⑨보스텔레그래프 ⑩캐릭터캐스팅.

## ▶▶ 최종 밸런스 확정 (뱀서 대조 + 사거리 + 킬타임/접촉 보정) ◀◀
- **무기 사거리/범위 3종 정의**: 투사체=Arrow.MAX_RANGE 720px 소멸(뱀서 화면끝), 장판/오라=area_mult 반경, 근접=콘/반경. _ready서 life=min(life,720/실속도)(유도 1.4배).
- **킬타임 유지**: 공속 -43%(WEAPON_CD_SCALE 1.75)에 맞춰 몹 후반 HP배율 2.2→1.8, 몹 base HP (11+t*0.6)→(9+t*0.45).
- **접촉 피해 완만화**(대시 없음 반영, 순삭 방지): (7+t*0.09)→(6+t*0.04). t=1200 기준 91→54.
- 확정 상수: Player.speed 125, Enemy 상한90/base20/+0.12, WEAPON_CD_SCALE 1.75, Arrow.SPEED_SCALE 0.82/MAX_RANGE 720, WORLD 2800, 무적 0.6s.

## ▶▶ 최종 밸런스 패스 (템포 대하향 + 사거리 상한 + 몹HP 보정) ◀◀
- **템포 노브 4종(전부 단일 상수)**: Player.speed 200→125 · Enemy 상한 90(base20,+0.12/s) · WEAPON_CD_SCALE 1.75(전무기 공속, _weapon_cooldown 래퍼) · Arrow.SPEED_SCALE 0.82(투사체, life/=0.82로 사거리 보존).
- **사거리 상한(뱀서식)**: Arrow.MAX_RANGE 720px — _ready서 life=min(life, 720/실속도). 유도탄만 1.4배 허용. 투사체가 화면 언저리서 소멸.
- **몹 체력·피해 보정(공속 -43%에 맞춤)**: hp (11+t*0.6)→(9+t*0.45), 후반배율 ×3.0→×2.2, touch (7+t*0.09)→(7+t*0.07).
- **동전 제거**: _spawn_coin=즉시 run_gold 적립(바닥 드랍 없음, 크리스탈만 줍기). Coin.gd 미사용.
- **맵 확대**: WORLD 1800→2800.
- 로드테스트 클린. 사용자=에디터 실행이라 export 불필요.

## ▶▶ 뱀서 기준 밸런스 대개편 (사용자: 느리고 묵직하게, 무기 순화) ◀◀
- **몹 공격행동 3종 제거**(뱀서 잡몹은 접촉만): GameConfig behavior "ranged"(fire_imp/ice_wisp)·"charge"(hellhound)·"exploder"(mushroom) 삭제 + shot_chill 제거. 이들 과속도 완화(1.30~1.48→1.0~1.05). splitter(slime)는 공격아님 → 유지.
- **속도 전반 하향(뱀서=느림+밀도)**: Player.speed 200→165. Enemy speed 상한145→118·base38→28·증가0.24→0.18. 캐릭터 speed/cd 완화(rogue 1.25/0.8→1.12/0.92, gunner 1.05/0.7→1.0/0.88, archer/mage cd↑).
- **공격속도 완화**: knife 1.0→1.2base, spear 1.0→1.25, venom 0.85→1.1.
- **무기 파워 순화(즉사 방지)**: 신규진화 일괄강화 ×1.7/+2/×1.35 → ×1.45/+1/×1.2. 아르카나 war+25%→18%, hunter 15/0.5→12/0.4, tyrant+2→+1, tempest-20%→-15%, abyss+40%→35%.
- **보물상자 화려하게**: ChestRoulette 회전 황금광선+중앙광휘+정착 확산링. _chest_reward_fanfare 금화22개+황금플래시+3중 시차링+버스트.
- 로드테스트 클린. **빌드 재export 필요**(권한 훅). [[arrow-survivors-rebuild-export]]

## ▶▶ 대시·궁극기 제거 + 빌드 재export (사용자: 뱀서엔 없음) ◀◀
- **대시 완전 제거**: Player.start_dash/dash_t/_dash_dir/대시이동·잔상·애니, Main 입력블록(SPACE), dash_cd/DASH_CD, shield_charge(대시의존 나이트스킬)+_charge_hit 삭제. _last_dir는 무기조준용 유지.
- **궁극기 완전 제거**: _ultimate/_ult_archer·knight·mage·rogue·priest·gunner(159줄), Q입력, ult_cd/ULT_CD 삭제. skill_label은 "골드 N"만 표시.
- **[중요] 빌드 stale 이슈**: .pck가 7/6판이라 이번 세션(7/9) 작업이 실플레이에 없었음(파란검기 등). Windows export 재실행(godot --headless --export-release "Windows Desktop")로 최신 반영. 웹빌드는 사용자가 중단 → 필요시 재export.
- 로드테스트 클린.

## ▶▶ 뱀서 3대 시스템 추가 (아르카나·리밋·관) + 보스경고 ◀◀
- **아르카나 6종**: Lv8/16/24 도달 시 레벨업이 운명카드 3장(전설)로 전환. war(공+25%·쿨-10%)/hunter(치명+15%·치피+50%)/tyrant(투사체+2·범위+20%)/sanguine(전체흡혈+5%,arcana_lifesteal)/tempest(쿨-20%)/abyss(저주+40%). _populate_levelup서 마일스톤 분기, _arcana_options/_take_arcana, 보라 플래시. 런시작 초기화.
- **리밋 브레이크**: 모든 성장 소진 후 회복카드 대신 무한강화(_limit_break_card: 힘/신속/확장/활력/예리/재생, 중복회피). 레벨업 낭비 방지.
- **숨김 관(coffin)**: Breakable에 coffin종(7%+런시작 확정2개). 튼튼(hp70+), 파괴 시 금화폭발+젬+_open_bonus_chest(무기/패시브 보너스)+배너. 석관+반짝이는 금십자 비주얼.
- **보스 출현 경고**: _spawn_boss에 "⚠ 보스 출현!—처치하면 보물상자" 배너+붉은플래시+흔들림 (기존엔 무경고라 못봄). 보스=1:00 첫등장, 2분마다.
- 로드테스트+런타임 검증 클린.

## ▶▶ 밸런스·시각 조정 + 신규무기 진화 (사용자 피드백 2차) ◀◀
- **검기 파란 fx_slash 제거**(사용자 지적): spawn_fx 제거 + 크레센트 은백색화.
- **검기(cleave) 재디자인**: Effect "slash"를 크레센트 스윙으로(옅은 채움+외곽호+진행에 따라 쓸고가는 밝은 칼날). 나이트 정체성 선명.
- **도적 차별화**: 칼 던지기=회전 단검 다발(n 2+lv/2, spin22, 약간 흩뿌림) → 아처의 정밀 단발과 대비.
- **공격속도 뱀서화**: arrow 0.85→1.15base, knife 0.55→1.0base, cleave→1.15base (너무 빠르던 기본공격 완화).
- **몬스터 속도↓**: Enemy speed 상한170→145, base45→38, 증가0.30→0.24.
- **투사체 축소**: Arrow 그리기 20→17배율, 상한46→38.
- **장판 연하게**: VoidZone 알파 0.55→0.34.
- **신규무기 진화 23종(EVO_RECIPE + NEW_EVO_WEAPONS)**: chakram/spear/starfall/holy_water/flamethrower/ice_lance/crossbow/holy_cross/poison_cloud/quake/spread_shot/soul_bolt/holy_beam/bone_spiral/moonlight/axe/homing_skull/magma_floor/thorn_burst/chain_bolt/frost_ring/blood_sword/cleave. 각 만렙+지정패시브→보스상자 진화. **중앙 강화**: _fire_weapon서 진화 무기면 피해×1.7·투사체+2·범위×1.35 후 원복(_fire_weapon_dispatch 분리). 개별 _fire 수정 0. 로드테스트 클린.
- 남은 옵션(미착수): 장판/검기 PixelLab 애니, 진화 무기 전용 비주얼.

## ▶▶ 기본공격 제거 → 순수 뱀서식 (사용자 피드백) ◀◀
- **기본공격 시스템 완전 제거**: _fire_basic/_basic_cooldown/_basic_archer·knight·mage·gunner, basic_lv/basic_timer, _process 틱, 레벨업 "기본공격 강화"카드, 인벤/일시정지 기본슬롯 전부 삭제. 뱀서엔 기본공격 없음 — 시작무기가 정체성.
- **캐릭터별 고유 시작무기(=정체성)**: archer=arrow / knight=**cleave(신규 검기)** / mage=lightning / rogue=knife / priest=aura / gunner=spread_shot. 각 캐릭터 다른 투사체(#1 해결).
- **검기(cleave) 신규무기**: 나이트용. 전방 반투명 부채꼴 2겹 슬래시(옅은 겉+밝은 안)+fx_slash. 근접 콘 피해. 7지점 등록. 가시성↑(#2 해결). ALL_WEAPONS 36종.
- **shadow_clone 독립화**: 기본공격 의존→_fire_shadow_clone 독립 타이머 무기(cd 1.1-lv), dispatch 등록.
- **투사체 크기 하향(#4)**: Arrow 그리기 배율 30→20 + 46px 상한. 화면 가림 방지, 뱀서 크기감.
- 런타임 검증: 시작무기 7종 발사등록 정상. 로드테스트 클린. (참고: 기본공격 없어 초반 DPS 낮음=뱀서 의도)

## ▶▶ #35 파괴 오브젝트 + 캐릭터 고유 특성 ◀◀
- **파괴 오브젝트(Breakable.gd 신규)**: barrel/crate/pot/torch 4종. hp=24+time*0.5, group "breakables". 투사체 충돌루프(arrows)·_explode(폭발/폭탄)에서 take_damage. 파괴 시 on_breakable_destroyed→골드다발(2~4+stage)+30%젬+16%픽업(하트/자석/폭탄)+버스트fx+흔들림. 뱀서식 촛대 파밍.
  - 스폰: 런시작 _scatter_breakables(10) 전역배치 + breakable_timer 5s마다 플레이어 주변(220~460px) 최대14개 유지. 아트 obj_barrel/crate/pot/torch.png(PixelLab), 없으면 도형 폴백.
- **캐릭터 고유 특성**: GameConfig characters()에 trait/trait_desc 추가, _apply_char_trait(key) 런시작 적용(스탯배수 위 개성):
  - archer 관통의명수(투사체+1)/knight 수호자(방어+3·체력+15%)/mage 비전폭주(쿨-12%·범위+10%)/rogue 그림자일격(치명+12%·치피+40%)/priest 성스러운가호(재생+1.2·자석+40)/gunner 속사(쿨-8%·투사체+1). 캐릭터 선택화면에 ★특성 표시.
- 로드테스트 클린.

## ✅ 로드맵 전체 완주 (#22~#31, #24 제외)
- #25 캐릭터·픽업 확장: 로자리 픽업(바닥 12%, 화면 전멸+플래시+흔들림, Pickup 십자가 비주얼) + 캐릭터 고유 시작무기 Lv1 지급(sel_char.weapon, 기존엔 빈슬롯 시작). 레벨업 UI 뱀서식 세로리스트+상단 보유아이콘줄(_fill_lvl_inv)로 재구성.
- 남은 선택: 출시준비(빌드 export·스팀), 추가 콘텐츠(캐릭터별 무기 차별화 등). 다음 세션은 실플레이 밸런스 피드백 기반 튜닝 권장.

## ▶▶ (완료) 로드맵 (우선순위, 사용자 확정) ◀◀
1. **#29 파밍 재미 + 뱀서 완전 동일** ✅완료: 상자 팡파레(금화 분출+링+흔들림) + ChestRoulette.gd **다중 릴 슬롯머신**(1/3/5개, N릴 순차 정착). 진화/유니온=단일릴, 보너스상자=`_open_bonus_chest`(1/3/5 가중 랜덤 보상 자동지급+룰렛, _card_options 재사용, 3+개면 플래시). 상자=보스전용, 보스 120s 주기.
2. **#27 몬스터 행동 다양화**: ✅완료. Enemy.behavior(tier "behavior")로 분기 — ranged(사수:사거리유지+EnemyArrow발사, fire_imp·ice_wisp[chill]), charge(돌진:접근→예열0.5s깜빡→고속돌진0.4s→쿨다운, hellhound), exploder(자폭:사망시 광역95px 피해, mushroom), splitter(분열:사망시 새끼2 소환, slime). Main.spawn_enemy_arrow + on_enemy_killed match. 로드테스트 클린.
3. **#23 레벨업 리롤/스킵/밴**: ✅완료. 리롤(run_rerolls3)·밴(run_banishes2, _banish_mode+banished set)은 기존, 스킵(run_skips2, _do_skip=카드넘김+체력10%회복) 신규. 레벨업 패널 3열 버튼. 로드테스트 클린.
4. **#31 남은 몹 그로테스크 통일**: ✅완료. slime(88)·bat(80)·void_wraith(96)·dark_knight(96) 그로테스크 정적+걷기 교체, 옛 애니 제거. 이제 전 몬스터 톤 통일.
   + **무기 밸런스 뱀서화**(사용자 "Lv8 빡셈" 지적): FREE_WEAPON_SLOTS 4→6(신규무기 억제 제거, 6칸 자유), XP곡선 level²×3.4→2.3·linear8→7(레벨업 더 자주→무기 육성 원활). MAX_WLEVEL 8은 뱀서와 동일 유지.
5. **#30 레벨업·진화 연출 심화**: ✅완료. FlashOverlay.gd(전체화면 플래시, PROCESS_MODE_ALWAYS 자가페이드) — 레벨업 골드/진화 화이트/유니온 블루 플래시. 보스처치 슬로우모션(Engine.time_scale 0.35, 340ms 실시간 복귀 _slowmo_until)+플래시+흔들림. 안전장치: _process 자동복구, _game_over time_scale=1. (덤: ChestRoulette PRESET_FULL_RECT+size 충돌 잠재버그 수정 — position/size 직접 지정으로).
6. #25 픽업 확장 / #24 맵 다양화(후순위).

## ✅ 완료: 몬스터 그로테스크 재디자인 (task #28) ◀◀
- ✅ 정적 스프라이트 13종 그로테스크 object로 교체(assets/enemies/<key>.png), 옛 walk/attack 애니 제거, GameConfig 크기 차등(fire_imp/ice_wisp 14·goblin 15·orc 23·gargoyle 22·demon 26·frost_golem 26·wraith_knight 24), 원본 백업 _bak_enemies/.
- ✅ 걷기 애니(v3, 1-dir, 7프레임) 13종 다운로드 완료 → anim/<key>_walk/. object download zip(`/mcp/objects/<id>/download`)에 animations/*/unknown/frame_*.png 들어있음(캐릭터와 달리 지연 無). 임포트·로드테스트 클린.
- 참고: 걷기는 1방향(정면)만 → Enemy._draw는 walk_n/_e 없으면 walk base 사용(서=반전). 4방향 원하면 추후 추가.
- 미변경(기존 유지 OK): slime/bat(object), void_wraith/dark_knight. 원하면 동일 방식으로 그로테스크화 가능.
- object UUID(=map object, 애니 group): skeleton 5715661e / goblin 908f1aa0 / orc 07672dbf / demon da46e8c3 / hellhound d7cacc31 / fire_imp 59b9c1f2 / frost_golem 82de9bfc / ice_wisp 2ca8683b / zombie 631546c9 / spider 9c375c4b / gargoyle be163e69 / mushroom 52072c32 / wraith_knight ea209a67
- 스타일 확정: create_map_object, medium detail, basic shading, single color outline, low top-down(spider=high), "full body ... margin around, centered", 중간 그로테스크. skeleton만 high detail/medium shading(더 무섭게).
- 아직 grotesque 안된 것: slime/bat(기존 object 유지 OK), void_wraith/dark_knight(기존 유지).


## ▶▶ 다음 세션 로드맵: 재미 강화 (task #26,27,23,25) — 여기부터 ◀◀
사용자 우선순위(위→아래). 새 세션은 "task 26부터 이어가자"로 시작.
1. **#26 타격 연출·Juice**: 데미지 숫자 팝업, 화면 흔들림(camera shake), 레벨업·진화 플래시/슬로우, 흡수 연출. → 즉각 쾌감, 가성비 최고.
2. **#27 몬스터 행동 다양화**: 원거리 사수/돌진/자폭/분열. GameConfig tier에 behavior 필드 + Enemy 분기.
3. **#23 레벨업 UX**: 리롤/스킵(체력회복)/밴. `Main.gd _pick3`(~2749) 개편 + 상점 통화로 횟수 구매. 메타상점(#22)과 연결.
4. **#25 캐릭터·픽업 확장**: 캐릭터별 고유 시작무기/패시브, 로자리(화면전멸)·보물상자 연출.
- (#24 맵 다양화는 후순위)
- 참고 현행: 메타상점 완성(Meta.gd UPGRADES 13종+_apply_upgrades~2826, _refresh_shop~3099 현재→다음값 표시, 상점버튼 _style_button cm_v=6 여백). 캐릭선택 카드=텍스트 플레이트+desc 상단정렬(~3925), 나이트 카드는 enemies/dark_knight.png 사용. 외형진화 제거(Player.set_stage _stage_data=stages_data[0] 고정, 능력치만 강화). 밸런스: 몹속도상한170·넉백230.

## (완료) 3일차: 몹걷기13종4방향 · 밸런스 · 메타상점보강 · 상점UI · 카드정리 · 외형진화제거

## (완료) 밸런스 3일차 미세조정
- 몹 속도 상한 210→170(플레이어200 카이팅 보장), 곡선 50+t*0.42→45+t*0.30. 넉백 150→230, 멈칫 0.06→0.08. 스폰 cap 90→72(t*0.55→0.45), cnt 8~60→6~48. priest_1 hurt 4방향 완료(=hurt 6/6). 임포트·로드테스트 클린.


## ✅✅ 완료: 4방향 애니 (task #21) — 3일차 마감 ◀◀
목표: 플레이어 기본외형 6캐릭터 × 6모션 북+동 생성(서=반전) + 캐릭터형 몹 13종 걷기. 코드는 **이미 완료**(Player `_mframes`+`_dir`, Enemy 걷기 `_dir`, south 폴백이라 부분 아트도 안전).

### ✅ 몹 걷기 13종 4방향 다운로드+임포트+로드테스트 완료 (3일차)
- **핵심 발견**: 방향 생성분 zip 폴더명이 `walking`이 아니라 **`walk_dir`**(north/east 하위) 였음 → 키워드 `walk_dir`로 `dl_dir.sh` 실행하니 전부 받아짐. (당일 zip 지연은 하루 지나니 해소됨 = 예상대로)
- 13종(skeleton/orc/demon/hellhound/fire_imp/frost_golem/ice_wisp/zombie/goblin/spider/gargoyle/mushroom/wraith_knight) × north/east 각 7f, `assets/anim/<key>_walk_n /_e`. 임포트 클린·valid=false 0·로드테스트 에러 0.
- 남은 선택사항: **몹 공격 4방향**(사용자 결정 대기), death 6·priest hurt(가성비 낮아 스킵 유지).

### 완료 (다운로드+임포트됨, assets/anim/<key>_<motion>_n / _e) — 2일차 갱신
- 플레이어 **walk** 6/6, **attack** 6/6, **idle** 6/6 완료 (archer_1/knight_1/mage_1/gunner_1/rogue_1/priest_1)
- 플레이어 **hurt** 5/6: archer/knight/mage/gunner/rogue 완료, **priest_1 미완**
- 플레이어 **dash** 1/6: archer_1만 완료
- 플레이어 **death** 0/6
- ⚠️ 2일차 아침 MCP 재연결 직후 큐한 death×6 + priest hurt가 **실제 생성 안 됨**(get_character에 north/east 없음). → **새로 생성 필요**

### 결정: death·dash 4방향 **스킵**(south+flip 유지)
- 이유: PixelLab download-zip이 death 애니를 export 안 함(get_character엔 있음). 우회하려면 캐릭터마다 get_character(응답 큼)=토큰↑. death는 게임오버 때 1회만 보여 가성비 낮음 → dash와 함께 스킵. (archer death/dash는 이미 받아둠, 무해)

### 남은 작업 = **몹 걷기 4방향 13종만** (walk는 설명 unique라 zip 안정적)
- ✅ **생성완료(다운로드만 남음, walking forward)**: 배치1 skeleton f156e374-dcd8-4021-a237-76f68cb51c6a / orc 57cc293b-36ff-466c-8ace-0c654ee07953 / demon 163aa36b-5895-4112-9390-73190bebbc0f / hellhound 7d629d34-4432-4329-b48a-94764a78e54e / 배치2 fire_imp 5e8da8fb-9f06-4b3a-beed-71d01bb04d5f / frost_golem 78025736-67af-4503-8205-15df1e6e8d01 / ice_wisp e3565c6a-0589-4006-ba64-133ecdaeecc8 / zombie 6f3a08af-a823-4771-b90b-461e62f68526
- ⏳ **아직 생성 안함(배치3)**: goblin 13747983-f47d-4b42-90c9-18474b034149 / spider 997b2db4-cdbb-46e3-9b57-617db38a5993 / gargoyle bc005c70-40df-4f3f-96e1-bc10b2349869 / mushroom 4e5ca2e6-50c8-4834-8fe8-fa95d4b1a157 / wraith_knight 4d899f4a-7c77-4028-8ecd-7582058c8e4e
- ✅ **13종 전부 생성 완료**(wraith_knight 포함, walk_dir north+east). 크레딧 소모·PixelLab 영구보존.
- ⚠️ **다운로드 대기**: PixelLab download-zip이 **당일 생성분을 export 안함(수시간 지연)**. death/monster walk 다 이 문제. → **내일(zip 갱신 후) `bash dl_dir.sh <uuid> walking <key>_walk`** 하면 받아짐. (어제 생성한 player walk/attack/idle/hurt는 오늘 정상 다운됨 = 지연만 있으면 됨)
- 즉시 받으려면: get_character(char) 프레임URL로 직접 curl (단 응답 큼=토큰↑). URL패턴 .../animations/<animuuid>/<dir>/<i>.png
- monster UUID 전부: skeleton f156e374-dcd8-4021-a237-76f68cb51c6a / orc 57cc293b-36ff-466c-8ace-0c654ee07953 / demon 163aa36b-5895-4112-9390-73190bebbc0f / hellhound 7d629d34-4432-4329-b48a-94764a78e54e / fire_imp 5e8da8fb-9f06-4b3a-beed-71d01bb04d5f / frost_golem 78025736-67af-4503-8205-15df1e6e8d01 / ice_wisp e3565c6a-0589-4006-ba64-133ecdaeecc8 / zombie 6f3a08af-a823-4771-b90b-461e62f68526 / goblin 13747983-f47d-4b42-90c9-18474b034149 / spider 997b2db4-cdbb-46e3-9b57-617db38a5993 / gargoyle bc005c70-40df-4f3f-96e1-bc10b2349869 / mushroom 4e5ca2e6-50c8-4834-8fe8-fa95d4b1a157 / wraith_knight 4d899f4a-7c77-4028-8ecd-7582058c8e4e
- 다운 후: 임포트 + valid=false 스캔 + 로드테스트. death 6종·priest hurt도 같이 재다운 가능(같은 지연문제).
- 끝나면: 임포트 + valid=false 스캔 + 로드테스트. (몹 공격 4방향은 사용자가 결과 보고 결정)
- priest_1 hurt도 zip이 안 실어주면 스킵(0.3s 플린치, 무시가능). 현재 hurt 5/6.

### 생성 방법 (animate_character, directions=["north","east"], 8슬롯/웨이브당 4콜=8잡, 대기 ~100~110s)
- 모션별 설명·frame_count: walk "walking forward" 6 / attack "attacking forward" 8 / idle "standing idle, breathing gently" 6 / hurt "flinching backward in pain, recoiling from a hit" 4 / death "collapsing and falling down defeated" 6 / dash "dashing forward quickly in a fast dodge roll burst" 6

### 다운로드 (프로젝트에 백업됨: output/arrow-a-row/dl_dir.sh)
- `bash dl_dir.sh <charid> <keyword> <keymotion>` — keyword는 north/ 하위폴더 가진 폴더명 일부. walk→walking, attack→attacking, idle→idle, hurt→flinch, death→collaps, dash→dash, 몹걷기→walking
- ⚠️ **함정**: idle/hurt/death/dash는 기존 south 애니와 설명이 같아 PixelLab이 새 방향본에 `-uuid` 접미사를 붙임 → 정확한 폴더명 대신 **키워드+north하위폴더 존재**로 매칭(스크립트가 처리). walk/attack은 설명이 달라 문제없음.

### UUID
- 플레이어: archer 155fe28c-8b6c-4058-953e-5239a97a3b0c / knight cdd50035-ae9e-4499-9845-4b4b13390f9d / mage 34d99b0e-18a3-47b6-a51e-0d75ad33bc82 / gunner 4a122e73-1da9-4d02-8daf-34735e5dce48 / rogue 012dd4c5-dbb2-4bfb-a22d-41686844b3c0 / priest 00a55976-1670-438f-9422-ff4e85249fe8 (→ 폴더 archer_1 등)
- 몹(캐릭터형 13, →폴더=key): skeleton f156e374 / orc 57cc293b / demon 163aa36b / hellhound 7d629d34 / fire_imp 5e8da8fb / frost_golem 78025736 / ice_wisp e3565c6a / zombie 6f3a08af / goblin 13747983 / spider 997b2db4 / gargoyle bc005c70 / mushroom 4e5ca2e6 / wraith_knight 4d899f4a
- 제외(object=8방향 불가, flip 유지): bat, slime, dark_knight, void_wraith / 진화단계(2~5)도 제외
- 캐릭터 애니는 PixelLab에 영구 보존 → 언제든 재다운 가능(맵오브젝트만 8h 삭제)

---


사용자 요청: 몬스터/보스 공격 애니 **전부**(몹17+보스8), 캐릭터 모션 **피격+사망+대기+대시** ×6캐릭터×**5단계 전부**,
디자인 어색한 것은 **내가 감사→개편안 제시→승인 후** PixelLab 요청. 요청문은 꼼꼼하게.

## ⚠️ PixelLab 제약
- **동시 작업 슬롯 8개**. 8개 큐→렌더대기(~30-60s/each)→다운로드→다음 8개.
- v3 공격: `frame_count=8`, `directions=["south"]`, keep_first_frame기본true → **9프레임 저장**. animation_name="attack".
- v3 걷기: `frame_count=6` → **7프레임 저장**. animation_name="walking".
- 프레임 URL: `https://backblaze.pixellab.ai/file/pixellab-characters/11f65880-77c9-451d-bca1-b0a1b26ec31f/<charid>/animations/<animuuid>/south/<i>.png`
- animuuid는 get_character의 animations 목록에서 확인. 다운로드 후 `godot --headless --import` + `grep -rl valid=false assets --include=*.import`.

## 에셋 배치 규칙
- 몬스터 공격: `assets/anim/<key>_attack/` (9f). 보스: `assets/anim/<bosskey>_attack/`.
- 걷기 누락 보충: `assets/anim/<key>_walk/` (7f).
- 캐릭터 모션: `assets/anim/<herokey>_<stage>_<motion>/` (hurt/death/idle=제자리, dash).

## 캐릭터/몬스터 UUID 맵
### 히어로 전체 UUID (6캐릭터×5단계) — md5 대조로 확정
- archer 1~5: 155fe28c / 1342117a / c48adc01 / 03c90abd / 91e1c3ad
- knight 1~5: cdd50035 / b380b374 / 5d9a7a30 / 3ac9b5b0 / 9332876d
- mage 1~5: 34d99b0e / 0e531f4e / 27391f8e / a5ca7fd6 / b51210a0
- gunner 1~5: 4a122e73 / b35ac32e / 860db2ab / 67ad0823 / f721eddc
- rogue 1~5: 012dd4c5 / 96931b78 / dc932afb / 4de2af6c / 4072f27b
- priest 1~5: 00a55976 / a3d3a9ee / 1cde1f20 / 21326ada / 88854cfe
- 진화 2~5단계 모션 진행표(idle/hurt/death/dash): 아래 "진행 상태"에 웨이브 기록

### 몬스터 (현행=1anim 버전)
- skeleton f156e374 / orc 57cc293b / demon(v2) 163aa36b / hellhound 7d629d34
- fire_imp 5e8da8fb / frost_golem 78025736 / ice_wisp(v2) e3565c6a / zombie(v2) 6f3a08af
- goblin(v2) 13747983 / spider 997b2db4 / gargoyle bc005c70 / mushroom 4e5ca2e6 / wraith_knight 4d899f4a
- dark_knight: base 5705ed88 / v2 26a45151 / v3 d3adb833(south로테이션無=404)
- void_wraith: base c3611ca1 / v2 9adf8851 / v3 ceffd8d1(south無=404)
- ⚠️ **bat, slime**: 캐릭터 아닌 **object**로 제작됨. bat obj=258b587d-07ea-4fbf-99cf-e9d3ede18422(1dir,52px,fly애니有), slime obj=ab60697b-d07a-4890-b4c2-16c3e3459479(1dir,56px,bounce애니有). animate_object로 공격 추가 가능.
- 🆕 **신규 object 몬스터 2종**(사용자 제작, 애니 無 → walk+attack 둘다 필요, GameConfig 미등록):
  - **결정: dark_knight/void_wraith 캐릭터는 전버전 south 404 → object로 교체 매핑**
  - black_knight obj=3458a811 → **dark_knight**(enemies/dark_knight.png + anim/dark_knight_walk/_attack 덮어씀). walk group=86dbe938
  - phantom obj=26438c4e → **void_wraith**(enemies/void_wraith.png + anim/void_wraith_walk/_attack 덮어씀). walk group=28db75c1
  - bat attack group=64469113 / slime attack group=0e94bbc2

### 보스 (현행=1anim)
- boss_1=Demon King v2 aeaed3ce / boss_2=Lava Golem bd03c69c / boss_3=Ice Queen e2f834ed
- boss_4=Void Horror f73316a8 / boss_5=Emperor v2 feea124c / boss_lich 60e21822 / boss_spider 261c50b0

## 진행 상태
### ✅ 공격 애니 24종 (몹17+보스7) — 완료
- 몹17: slime, goblin, bat, spider, zombie, skeleton, mushroom, fire_imp, orc, hellhound, gargoyle, demon, ice_wisp, frost_golem, void_wraith, wraith_knight, dark_knight (각 9f)
- 보스7: boss_1~5, boss_lich, boss_spider (각 9f)
- 코드: Enemy.gd(근접 시 attack 재생) + Boss.gd(발사/특수 시전 시 attack 재생). valid=false 0, 로드테스트 0에러.
- dark_knight=흑기사object / void_wraith=팬텀object로 스프라이트+걷기+공격 교체(404 우회). bat/slime=object animate_object로 공격 추가.

### 캐릭터 모션 (hurt/death/idle/dash ×6×5 = 120)
- ✅ 코드: Player 상태머신 완성(_draw 우선순위 사망>피격>대시>공격>걷기>대기), play_hurt/play_death, Main 트리거(피격3지점+게임오버). 대시는 기존 start_dash 재사용.
- ✅ **기본단계(stage1) 24종 완료**: archer_1/knight_1/mage_1/gunner_1/rogue_1/priest_1 각 idle(7f)/hurt(5f)/death(7f)/dash(7f). 임포트클린, 로드테스트0.
- ✅ **진화 2~5단계 96종 완료** (6캐릭터×4단계×4모션). md5대조로 UUID확정 후 캐릭터2명씩 12웨이브 생성. 총 120/120 임포트클린, 로드테스트0.
- (구주석) 진화 2~5단계 96종 남음 → 완료됨.
  - rogue 2~5: 96931b78 / dc932afb / 4de2af6c / 4072f27b
  - priest 2~5: a3d3a9ee / 1cde1f20 / 21326ada / 88854cfe
  - archer5 91e1c3ad / knight5 9332876d / mage5 b51210a0 (2~4단계 group멤버 미매핑)
  - 다운로드 시 zip 애니폴더 키워드 매칭: idle=*idle*, hurt=*flinch*|*pain*, death=*collaps*|*defeat*, dash=*dash*|*dodge*
  - 프레임수: idle7 hurt5 death7 dash7. 배치: assets/anim/<key>_<stage>_<motion>/

### 코드 연동
- [ ] 몬스터/보스 스크립트: 근접 공격 시 attack 애니 재생 (현재 walk만).
- [ ] Player: idle(정지시)/hurt(피격)/death(사망)/dash 재생 + 대시 입력·무적.

## 진화 무기 아트 (Phase 2, task#20) — object IDs (8h 자동삭제)
- tempest(폭풍화살,arrow evo) c40f89f4-7284-4f27-aed6-def982806279 → proj_tempest
- reaper(사신의대검,blade) 651fc2d5-3521-4eb8-b2f7-eadba55fda78 → proj_reaper
- thousandknife(천개의칼,knife) 4f1fdb71-df46-4ba3-ad8b-60b7353cd619 → proj_thousandknife
- scythe(사신의낫,boomerang) 99a6406c-3bfd-4aec-8c4d-80f35894ed30 → proj_scythe
- inferno(지옥불오라,aura) 7c0a382d-1366-48cc-a8a2-cad55bf2b0a2 → fx_inferno
- thunder(천둥의진노,lightning) 679110e9-b9c0-4c3f-a8aa-a5ab7096948a → fx_thunder
- absolzero(절대영도,frost) 41291adf-a2a2-48eb-90f8-44305e59f2fa → fx_absolzero
- meteorshower(운석우,fireball) dd3e4f93-31c7-4859-9236-82190eb9cb93 → fx_meteorshower
- judgment(신의심판,holy) 1f9e0584-5e13-4765-aa17-3c1ae45f7f7d → fx_judgment
- plague(역병,venom) d06935c9-c297-4ea5-a024-a14e2f07a4b2 → fx_plague
- bloodtear(피의눈물,whip) 1172b44b-9279-4b42-be2d-ab71884d9cca → fx_bloodtear
- ✅ **Phase 2 완료**: 11종 전부 생성·애니(spin/burst 9f)·다운로드·임포트(valid=false 0)·코드연동.
  - 연동: arrow→proj_tempest, knife→proj_thousandknife, boomerang→proj_scythe(anim_dir) / blade→proj_reaper·aura→fx_inferno(_draw) / fireball→fx_meteorshower, holy→fx_judgment, venom→fx_plague, whip→fx_bloodtear, lightning→fx_thunder(_spawn_bolt), frost→fx_absolzero (evolved 브랜치 조건부)
  - Phase 3 남음: 신규 패시브(투사체+1 duplicator/지속 spellbinder) + Lv8 밸런스
- 파이프라인: create_map_object → animate_object(v3 spin/burst) → download frames → proj_*/fx_* 폴더 → 각 _fire_* evolved 브랜치에서 새 아트 사용
- 레이트리밋: create_map_object 동시 ~4개. animate 8슬롯.

### 디자인 감사 (승인 후 요청)
- [ ] 초상화/HUD/카드/이펙트/UI 전수 점검 → 개편안 제시 → 승인 → 요청.
