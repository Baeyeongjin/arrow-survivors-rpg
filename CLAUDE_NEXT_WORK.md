# Claude 다음 작업 인수인계 — 탐사 맵 확대와 M5-C 공허

> 작성일: 2026-07-29
> 기준 브랜치: `master`
> 기준 커밋: `c51c259 docs: Codex 인수인계 갱신`
> 저장소: `Baeyeongjin/arrow-survivors-rpg`

## Claude에게 바로 전달할 요청문

아래 문장을 Claude에게 그대로 전달하면 된다.

> `CLAUDE_NEXT_WORK.md`를 처음부터 끝까지 읽고, M5-B 빙하 완료 상태를 보존하면서 **1순위 작업인 던전 탐사 맵 크기 확대만** 구현해줘. 이번 커밋에서 M5-C 공허까지 동시에 시작하지 말고, 5개 맵의 연결성과 목표 좌표를 자동 테스트한 뒤 실제 맵 렌더 스크린샷으로 이동 밀도까지 확인해줘. 완료하면 `feat: 던전 탐사 맵 확장`으로 커밋하고 `origin/master`에 푸시해줘.

---

## 완료 기반 요약 — M5-A 묘지 이후의 누적 상태

1순위 작업만 구현했다. 지옥 슬라이스는 건드리지 않았다(HellSliceTest 회귀 통과).

- **영혼 봉인비**(`GraveSeal.gd`): 파괴가 아닌 점령형(범위 안 10초 누적, 밖이면 정지·비초기화). 좌표 3개는 `StageLayout.make(1)`의 `objective_positions`, 스폰 시 `묘지 파수꾼`(정예) 동반. 00:40/01:35/03:20.
- **무덤 기사**(중간보스, 02:30): `graveyard_midboss_tier`(dark_knight), 돌진 예고. 처치 전 최종 관문 잠금(HUD 경고). 처치 시 묘지 전용 장비 확정.
- **묘지 수호자**(최종보스, `Boss.gd` `configure_grave_final`/`_process_grave`): 접촉 피해 없이 예고 3패턴(부채꼴 뼈파동·지연 묘지폭발·직선 영혼돌진). 체력 60%에 영혼 방패, 핵 수 `max(1, 4-완료 봉인)`, 어떤 무기·속성도 파괴, 전부 파괴 시 5초 딜타임(피해 1.7배).
- **묘지 전용 장비 3종**(`GRAVE_GEAR_SPECIALS`, `dungeon_tag="graveyard"`): 장송의 무기(`requiem_interrupt`), 수의의 가호(`burial_shroud`), 혼령의 메아리(`grave_echo`). `_gear_detail_text`에 `[묘지 전용]` 표기. 효과는 실제 런에 연결.
- **HUD/텔레메트리**: 기존 상단 목표 재사용(봉인 n/3·중간보스·방패 핵·취약 시간). `run_floor_stats`에 `objective_key`/`objectives_completed`/`objectives_total` 추가. 층 전환 시 `_reset_grave_floor_state`로 완전 초기화.
- **파일 분리**: 묘지 로직을 `Main.gd`에 통째로 복사하지 않고 `GraveSeal.gd`/보스 상태머신으로 분리(다음 던전이 따를 최소 수명주기).

검증: 파싱 clean · `GRAVEYARD_SLICE_OK` · 회귀 `HELL_SLICE_OK`/Expedition/Difficulty/Mastery/Element · `--telemetry-test`/`--map-selection-test`/`--expedition-flow-test` PASS · `--graveyard-preview=seal|midboss|boss` 실제 렌더 캡처 확인.

이월(ponytail): 무덤 기사의 2번째 전조 패턴(부채꼴 베기)은 완료조건 밖이라 돌진 예고 1패턴으로 시작. 봉인 보상·보스 핵 HP 수치는 플레이테스트 후 조정. 나머지 4개 던전(M5-B~E)은 이 문서 8절 순서대로 별도 진행.

---

## ✅ 완료 (2026-07-29, Codex) — M5-B 빙하 세로 슬라이스

묘지의 수명주기를 템플릿으로 사용하되, 빙하는 “안전 거점을 직접 늘리며 환경 압박을 관리”하는 던전으로 분리했다.

- **얼어붙은 화로**(`GlacierBrazier.gd`): 00:45/01:45/03:25에 3곳 등장. 모든 무기·속성으로 해빙 가능하고 화염만 2.5배, 냉기도 0.55배로 진행 가능하다. 점화 후 사라지지 않고 반경 184의 온기 지대로 남는다. 64px `brazier.png`를 정수 2배로 렌더한다.
- **누적 냉기**: 온기 밖에서 초당 1.05 상승, 안에서 초당 24 감소. 40/75에서 이동속도가 90%/78%로 낮아지고 100에서는 최대 체력 5%의 동상 피해 후 82로 내려간다. 층 전환 시 이동 배수까지 완전 초기화된다.
- **서리 감시자·빙벽 골렘**: 화로마다 둔화 투사체 정예가 동반되고, 02:35에 돌진형 중간보스가 등장한다. 중간보스 생존 중에는 최종 관문이 잠기며 처치 시 빙하 전용 장비를 확정한다.
- **빙결 거상**(`Boss.gd::configure_glacier_final`): 접촉 피해 대신 고드름 부채·빙결 고리·지연 분출 3개 예고 패턴을 순환한다. 체력 70%/35%에서 얼음 갑옷이 생기며 화염 2.5배, 냉기 0.55배, 나머지 1배로 모두 파쇄 가능하다. 파쇄 후 5초 동안 피해 1.7배. 미점화 화로는 갑옷을 강화하고, 보스전 중 늦게 점화해도 현재·다음 갑옷이 즉시 약해진다.
- **빙하 전용 장비 3종**: 해빙의 칼날(`thawbreaker`), 설원의 수호(`winterward`), 난롯불의 메아리(`hearth_echo`). `dungeon_tag="glacier"`와 `[빙하 전용]` 상세를 사용하고, 파괴 피해·냉기/보스 피해·화로 보상에 실제 연결했다.
- **전투 목표 공통화**: 투사체뿐 아니라 오라·회전검·범위기·E·궁극기도 지옥 균열과 빙하 화로를 모두 타격한다. 화염 캐릭터나 특정 무기 없이는 진행할 수 없는 상황을 막았다.
- **HUD/텔레메트리/프리뷰**: 화로 n/3·냉기 %·온기 여부·중간보스·갑옷 %·취약 시간을 기존 상단 HUD에 표시한다. 층 기록은 `glacier_braziers`, 피해 원인은 `glacier_cold`/`glacier_boss`로 남긴다. `--glacier-preview=brazier|midboss|boss`를 추가했다.

검증: 신규 `tests/GlacierSliceTest.gd` 포함 독립 테스트 19개 전부 통과 · `--telemetry-test`/`--map-selection-test`/`--expedition-flow-test` PASS · 화로/중간보스/보스 실제 1280×720 렌더 캡처 확인 · 기존 `GRAVEYARD_SLICE_OK`/`HELL_SLICE_OK` 유지.

이월(ponytail): 냉기 누적률·온기 반경·갑옷 HP는 아직 수동 원정 표본이 없으므로 대폭 조정하지 않았다. 빙벽 골렘은 기존의 읽기 쉬운 돌진 1패턴으로 시작한다. 맵 확대 뒤 화로 사이 이동 시간이 달라지므로 냉기 수치는 그때 다시 플레이테스트한다.

---

## 🎬 진행 중 — 공격 모션 (4/33) + 진화무기 범위 재설계 (미착수)

### 공격 모션: 코드는 준비됨, 아트만 채우면 된다
`Player._mframes("attack")`(0.45초)과 `Enemy._frames_attack`(12fps)이 **이미**
`assets/anim/<key>_attack/0.png..N.png`를 자동 재생한다. **코드 수정 불필요.**

완료(각 7프레임): `corvius_1_attack` `gustavo_1_attack` `serafina_1_attack` `valentino_1_attack`

남은 대상:
- 캐릭터 7: pixie, django, bolt, morgana, isolde, grimble, mordek → `<key>_1_attack`
- 몬스터 22: slime goblin bat spider zombie ghoul skeleton mushroom fire_imp orc
  lava_toad hellhound gargoyle demon frost_spider ice_wisp frost_golem eye_mass
  void_wraith wraith_knight cultist dark_knight → `<key>_attack`
- 정예·중간보스 6종은 **생성하지 말고 프레임 복사**(같은 스프라이트 재사용):
  ember_stalker←hellhound, hell_enforcer←demon, grave_warden←wraith_knight,
  tomb_knight←dark_knight, frost_sentry←ice_wisp, icewall_golem←frost_golem

작업 레시피(검증됨):
1. `tools/`가 아닌 스크래치에 있던 색축소 스크립트를 쓴다. PixelLab `animate_image`의
   인라인 base64는 ~1800자에서 잘린다(도구가 경고). 32x32 스프라이트를 8~24색으로
   quantize + optimize 하면 1100~1440자로 줄어 통과한다. 알파는 이진 마스크로 보존.
2. **한 번에 하나씩** 파일에서 base64를 읽어 그대로 `animate_image`에 넘긴다.
   여러 개를 한꺼번에 옮기면 전사 오류가 난다(이번에 2회 발생).
   인자: `frame_count=6`, `no_background=true` → 결과 7프레임(0=원본).
3. 결과를 `assets/anim/<key>_attack/<i>.png`로 다운로드 → `--import`.
4. 비용 1 generation/개. 잔량은 `get_balance`로 확인(작업 시점 103).

더 나은 길: `PIXELLAB_API_TOKEN` 환경변수가 설정돼 있다. MCP 래퍼의 REST 계약을
확인할 수 있으면 스크립트로 파일에서 직접 올려 base64 전사 문제를 없앨 수 있다.

### 진화무기: 범위 대신 특수 효과로 (사장님 요청, 미착수)
로그라이크(뱀서)를 벗어난 지금 넓은 범위는 재미가 없다는 피드백. 문제는
`player.area_mult`가 **8곳에서 곱으로 누적**된다는 것:
숙련 분기 4종(0.12~0.35) · 패시브 촛대/봉인의서(각 +12%) · 스탯 집중(+3%/pt) ·
장비 어픽스 · 진화 배수(1.35~1.5x). 게다가 진화 효과 상당수가 `explode_radius`·
`radius` 확대뿐이라 "특별함"이 없다.

방향: `EVO_FX`가 이미 `pierce`/`slow`/`explode`/`chain` 슬롯을 갖고 있으니 범위 배수를
그쪽으로 옮긴다. 후보 축 — 관통·다중타격 / 상태이상(빙결·중독·표식) /
처형·흡혈(저체력 즉살) / 연쇄·유도. 22종 재설계라 사장님 플레이 피드백 후 착수.

---

## 📌 다음 작업 인수인계 (2026-07-29 갱신) — 여기부터 시작

### 이번 세션에서 완료된 것 (전부 master 푸시됨)

| 커밋 | 내용 |
|---|---|
| `53b3e49` | **M5-A 묘지 세로 슬라이스** (아래 상세 참조) |
| `8d61805` | 던전 목표 오브젝트 4종 아트 (화로·봉인비·공허닻·성문), 64px 규격 |
| `9707f47` | **던전 지형 5종 RPG형 재설계** (방+복도) + `tests/StageLayoutTest.gd` |
| `16b472f` | 던전 조형물 8종 64px 고전 도트 교체 + 정수배 확대 렌더 |
| `이번 커밋` | **M5-B 빙하 세로 슬라이스** + `tests/GlacierSliceTest.gd` |

**아트 규격(중요, 앞으로 이걸 지킬 것)**: 맵은 `CELL=32` 격자, 몹 32×32.
맵 오브젝트·조형물은 **64px 캔버스 + low detail + flat shading + single color outline**으로
PixelLab 생성하고, 코드에서 **정수배 확대**해 얹는다. 128px로 뽑으면 바닥 타일보다
도트가 촘촘해 혼자 고화질로 보인다(이번에 전부 교체함).
`_draw_stage_obstacle_art`는 텍스처 크기에서 확대율을 자동 계산하므로 64px 아트를 그냥 넣으면 된다.

### 다음 작업 우선순위

**1순위 — 맵 크기 확대 (사장님 요청, 미착수)**
"맵이 탐사하기엔 좀 작다, RPG 느낌 살리려면 더 크게". 현재 `StageLayout.WORLD = 2800×2800`.
- 권장: `WORLD`를 키우고 `make()` 좌표를 같은 비율로 스케일(예: 1.4배 → 3920).
  좌표를 손으로 다 고치기보다 `make()` 끝에서 일괄 스케일하는 편이 안전.
- 반드시 `StageLayoutTest` 통과 확인(목표 좌표 walkable + 전 구역 연결성).
- 맵이 커지면 몹 스폰 밀도·이동 시간이 같이 늘어나므로 `stage_spawn_profile`과
  `DUNGEON_BOSS_TIME`(현재 300초) 재검토 필요.
- 빙하 화로 간격이 넓어지면 현재 냉기 초당 1.05가 과해질 수 있다. 먼저 지형만 비례 확대하고,
  실제 한 바퀴 이동 시간을 측정한 뒤 냉기율·화로 등장 시각을 함께 판단한다.

**2순위 이후** — M5-C 공허(닻·중력장), M5-D 마왕성(성문 관문), M5-E 통계 기반 밸런스.
공허 닻(`void_anchor.png`)·마왕성 성문(`castle_gate.png`) 아트는 이미 준비돼 있다.

### 하지 말 것
- 지옥 슬라이스 리팩터링(회귀 위험). `HellSliceTest`는 항상 통과 상태 유지.
- 통계 표본(`user://run_telemetry.json`) 없이 난이도 수치 대폭 변경.
- 128px 이상 캔버스로 맵 오브젝트 생성(고화질 도트 문제 재발).

---

## ✅ 완료 (2026-07-29, Claude) — M5-A 묘지 세로 슬라이스

현재 게임은 RPG 전환의 기반 공사가 끝난 상태다.

| 마일스톤 | 상태 | 핵심 결과 |
|---|---|---|
| M0 시스템 통합 | 완료 | 아르카나 제거, 저주를 난이도로 통합, 가호 단일화 |
| M1 능동 전투 | 완료 | 자동공격 + `E` 무기 스킬 + `Space` 회피 + `Q` 궁극기 |
| M2 성장 분기 | 완료 | 주무기 숙련 2단계 분기, 정예/층 보상 스탯, 숙련 최종 진화 |
| M3 지옥 세로 슬라이스 | 완료 | 균열, 전용 정예/중간보스, 패턴 보스, 지옥 장비 |
| M4 전리품과 원정 | 완료 | 3층 원정, 경로 선택, 2개 추출, 자동 분해, 보스 파편 |
| M5 로컬 통계 | 완료 | 피해 비중, 사망 원인, 층 기록, 경로, 추출 결과 저장 |
| M5 던전 확장 | 진행 중 | 지옥·묘지·빙하 세로 슬라이스 완료, 공허·마왕성 남음 |
| UI 정리 | 완료 | 데미지 폰트로 통일, 이모지 제거, PixelLab 아이콘/경로 UI |

M5-B 완료 기준으로 독립 테스트 19개와 메인 흐름 테스트 3개가 모두 통과했다.
Claude 작업 후에도 최소한 이 기준을 유지해야 한다.

다음 핵심은 신규 캐릭터나 무기 추가가 아니다.

**지옥에서 검증한 “고유 목표 → 중간보스 → 읽을 수 있는 최종보스 → 던전 전용 장비” 구조를 나머지 던전에 한 곳씩 확장해야 한다.**

---

## 2. 코드 기준으로 확인한 실제 미완료

### 2.1 공허와 마왕성은 아직 완성형 던전이 아니다

- 지옥·묘지·빙하는 각각 고유 목표, 고정 시간표, 전용 정예·중간보스,
  전조형 최종보스, 던전 장비와 회귀 테스트까지 갖춘 세로 슬라이스다.
- 공허·마왕성은 서로 다른 레이아웃·로스터·배경·보스 스프라이트와 약점은 있지만,
  아직 5분 생존 뒤 등장하는 단순 추격형 보스 단계다.
- 다음 던전 구현은 `GraveSeal.gd`, `GlacierBrazier.gd`처럼 목표 노드를 분리하고,
  `Boss.gd`에는 해당 보스의 작은 상태 머신만 추가하는 구조를 따른다.

### 2.2 지금은 통계 기반 수치 조정을 할 때가 아니다

- `user://run_telemetry.json` 파일이 아직 없다.
- 즉, 실제 수동 원정 표본이 0회다.
- `RunTelemetry.gd::aggregate()`도 전체 클리어율만 계산하고 난이도·시작 던전별로 묶지 않는다.

따라서 지금 수치를 감으로 크게 바꾸면 안 된다.
먼저 던전 구조를 확장하고 수동 플레이 기록을 쌓은 뒤 밸런스 패스를 해야 한다.

### 2.3 `Main.gd`가 이미 매우 크다

지옥 코드를 그대로 복사해 `grave_*`, `glacier_*`, `void_*`, `castle_*` 분기를 모두 `Main.gd`에 넣으면 유지보수가 급격히 나빠진다.

묘지와 빙하 작업에서 다음 던전들이 따를 수 있는 작은 실행 단위를 만들었다.

이미 적용된 파일 구성:

- `GraveSeal.gd`: 점령형 목표 노드
- `GlacierBrazier.gd`: 파괴·점화형 목표 및 온기 지역
- `Boss.gd`: 묘지·빙하 수호자의 상태 머신과 전조
- `Main.gd`: 각 층의 시간표와 공통 수명주기 연결
- `tests/GraveyardSliceTest.gd`: 묘지 규칙 회귀 검사
- `tests/GlacierSliceTest.gd`: 빙하 규칙 회귀 검사

공허와 마왕성도 목표 노드·테스트를 분리하고, 던전 로직 전체를 `Main.gd`에 길게 복사하는 방식은 피한다.

---

## 3. 1순위 구현 작업 — M5-A 묘지 던전 세로 슬라이스

### 3.1 목표

첫 해금 던전인 묘지를 게임의 튜토리얼형 RPG 던전으로 완성한다.

`GameConfig.stages()[0]`의 표시 이름도 현재의 포괄적인 `던전`에서 `묘지`로 바꾸고, 규칙 설명을 실제 봉인 목표에 맞게 갱신한다.

플레이어가 한 층에서 다음 리듬을 경험해야 한다.

```text
자동공격으로 성장
→ 안전하지 않은 위치 목표를 직접 점령
→ 전조 공격을 회피하며 중간보스 처치
→ 사전 목표 수행량이 최종보스 난도에 반영
→ 패턴을 읽고 약점 시간에 능동 스킬 집중
→ 규칙을 바꾸는 전용 장비 획득
```

### 3.2 확정 진행안

| 층 경과 시간 | 사건 |
|---:|---|
| 00:40 | 첫 번째 영혼 봉인비 활성화 |
| 01:35 | 두 번째 영혼 봉인비 활성화 |
| 02:30 | 중간보스 `무덤 기사` 등장 |
| 03:20 | 세 번째 영혼 봉인비 활성화 |
| 04:15 | 최종보스 경고 |
| 05:00 | `묘지 수호자` 등장 |

#### 영혼 봉인비

- `StageLayout.make(1)`에 이동 가능한 `objective_positions` 3개를 추가한다.
- 플레이어가 봉인 범위 안에 누적 10초 머무르면 완료된다.
- 범위를 벗어나면 진행이 멈추되 즉시 초기화하지 않는다.
- 봉인 중에는 주변에서 적이 몰려오고 전용 정예 `묘지 파수꾼`이 한 마리 등장한다.
- 완료 보상은 `8 G + 최대 체력 4% 회복` 정도로 시작한다.
- 모든 공격 속성과 무기가 정상적으로 진행할 수 있어야 한다.
- 봉인을 무시해도 5분 보스는 등장한다. 다만 최종보스의 영혼 방패가 강해진다.

#### 중간보스 — 무덤 기사

- 기존 `wraith_knight` 또는 `dark_knight` 아트를 우선 재사용한다.
- 일반 접촉 피해만 주는 큰 적으로 끝내지 않는다.
- 최소 2개 전조 패턴을 가진다.
  - 전방 부채꼴 베기
  - 직선 돌진 경로 고정
- 5분까지 살아 있으면 최종보스 관문이 잠기며, HUD로 원인을 알려야 한다.
- 처치 시 묘지 전용 장비 1개와 소량 회복을 확정 지급한다.

#### 최종보스 — 묘지 수호자

- 일반 접촉 피해를 끄고 전조가 있는 패턴 피해만 사용한다.
- 최소 3개 패턴을 순환한다.
  - 부채꼴 뼈 파동: 옆으로 회피
  - 플레이어 위치에 지연 묘지 폭발: 계속 이동
  - 직선 영혼 돌진: 경로를 보고 대시
- 체력 60%에서 영혼 방패 국면을 시작한다.
- 방패 핵 수는 `max(1, 4 - 완료한 봉인비 수)`로 한다.
- 핵은 어떤 무기와 속성으로도 파괴할 수 있다.
- 모든 핵 파괴 후 5초 동안 기절하고 받는 피해가 증가한다.
- 등장 배너나 방패 안내가 보이는 동안 즉시 공격하지 않는다.

묘지는 입문 던전이므로 특정 속성을 강제하지 않는다.
지옥의 냉기 상성처럼 “정답 장비가 없으면 불편한” 장치는 묘지에 넣지 않는다.

### 3.3 묘지 전용 장비

지옥처럼 슬롯별 특수 효과 1개를 둔다. 단순 공격력 누적 대신 조작 방식이나 생존 규칙을 바꾼다.

| 슬롯 | 이름 제안 | 특수 키 | 효과 제안 |
|---|---|---|---|
| 무기 | 장송의 무기 | `requiem_interrupt` | 전조 중인 정예/보스에게 `E` 적중 시 8초에 한 번 공격 취소 |
| 방어구 | 수의의 가호 | `burial_shroud` | 층마다 처음 치명 피해를 1 HP로 버티고 1.5초 무적 |
| 장신구 | 혼령의 메아리 | `grave_echo` | 정예 처치 시 `E` 재사용 1.5초 감소, 궁극기 게이지 소량 충전 |

구현 시:

- `dungeon_tag = "graveyard"`를 사용한다.
- 기존 장비의 `special` 딕셔너리 구조를 재사용한다.
- 모든 몬스터와 무기에 새 태그를 전수 추가하지 않는다.
- 키 충돌을 피하고 `_has_gear_special()`을 재사용한다.

### 3.4 HUD와 텔레메트리

- 기존 상단 목표/HUD 영역을 재사용한다. 새 모달 창은 만들지 않는다.
- HUD에 최소한 다음을 보여준다.
  - 봉인비 완료 수 `n/3`
  - 중간보스 생존 여부
  - 보스 영혼 방패 핵 수
  - 보스 취약 시간
- `run_floor_stats`에 아래와 같은 범용 목표 기록을 추가한다.
  - `objective_key`
  - `objectives_completed`
  - `objectives_total`
- 피해 원인 이름에 묘지 목표·중간보스·최종보스 패턴을 구분해 기록한다.
- 자동 캡처와 치트 런은 기존처럼 영구 통계에서 제외한다.

---

## 4. 완료 조건

다음 조건을 전부 만족해야 묘지 세로 슬라이스 완료다.

### 기능

- [ ] 00:40 / 01:35 / 03:20 봉인비가 중복 없이 정확히 등장
- [ ] 봉인 진행은 범위 안에서만 오르고 범위를 벗어나면 일시정지
- [ ] 봉인 좌표 3개가 실제 이동 가능 영역
- [ ] 02:30 무덤 기사 등장 및 처치 전 최종 관문 잠금
- [ ] 봉인 수행량이 보스 방패 핵 수에 반영
- [ ] 묘지 수호자 3개 패턴 모두 사전 전조 제공
- [ ] 방패 핵 파괴 후 5초 취약 시간 작동
- [ ] 중간/최종보스가 묘지 전용 장비 지급
- [ ] 층 전환 시 묘지 목표·투사체·위험 지역·보스 상태 완전 초기화
- [ ] 3층 원정, 경로 선택, 추출, 파편 제작이 그대로 작동

### 테스트

- [ ] `tests/GraveyardSliceTest.gd` 추가
- [ ] 이벤트 시간 순서 검사
- [ ] 목표 좌표 이동 가능 여부 검사
- [ ] 봉인 진행/정지/완료 검사
- [ ] 보스 방패 핵 수 공식 검사
- [ ] 보스 전조 패턴 3개 검사
- [ ] 전용 장비 3종 실제 효과 검사
- [ ] 기존 독립 테스트 전부 통과
- [ ] `--telemetry-test` 통과
- [ ] `--map-selection-test` 통과
- [ ] `--expedition-flow-test` 통과

### 시각 검증

다음 개발용 캡처 인자를 추가하는 것을 권장한다.

```text
--graveyard-preview=seal
--graveyard-preview=midboss
--graveyard-preview=boss
```

각 화면에서 확인할 것:

- 전조 범위가 배경과 구분되는가
- 보스·몹·목표가 서로 겹쳐도 읽히는가
- HUD 텍스트가 1280×720 화면 밖으로 나가지 않는가
- 봉인 진행과 보스 취약 상태를 색만이 아니라 형태/문구로도 구분하는가

---

## 5. 코드 탐색 시작점

라인 번호는 계속 이동하므로 심볼명으로 찾는다.

| 파일/심볼 | 참고 목적 |
|---|---|
| `RPG_ROGUELIKE_EVOLUTION_PLAN.md` | 현재 확정 RPG 로드맵 |
| `Main.gd::_update_hell_encounter` | 고유 던전 시간표 참고 |
| `Main.gd::_spawn_hell_fissure` | 목표 + 수호 정예 스폰 참고 |
| `Main.gd::_spawn_hell_midboss` | 중간보스 참고 |
| `Main.gd::_spawn_dungeon_boss` | 최종보스 설정 진입점 |
| `Main.gd::_clear_floor_runtime` | 층 전환 정리 그룹 |
| `Main.gd::_transition_to_expedition_floor` | 다음 층 상태 초기화 |
| `Main.gd::_record_current_floor` | 층별 텔레메트리 |
| `Main.gd::_roll_boss_reward` | 던전 전용 장비 분기 |
| `Main.gd::HELL_GEAR_SPECIALS` | 전용 장비 구조 참고 |
| `Boss.gd::configure_hell_final` | 패턴 보스 설정 참고 |
| `Boss.gd::_process_hell` | 보스 상태 머신 참고 |
| `HellFissure.gd` | 월드 목표 노드 참고 |
| `StageLayout.gd::make` | 목표 좌표와 이동 가능 영역 |
| `tests/HellSliceTest.gd` | 새 세로 슬라이스 테스트 형식 |

지옥 구현을 전면 리팩터링하는 작업은 이번 범위가 아니다.
묘지를 추가하면서 필요한 최소 공통 수명주기만 분리하고, 지옥 회귀를 우선한다.

---

## 6. UI·아트 규칙

- 모든 UI 폰트는 `UiTypography.gd`를 사용한다.
- 사용자에게 보이는 문자열에 이모지를 직접 넣지 않는다.
- 아이콘이나 UI 골격이 필요하면 PixelLab을 적극 사용한다.
- 새 UI 자산은 현재의 다크 네이비·앤티크 골드·고딕 픽셀 스타일을 따른다.
- UI PNG는 투명 배경과 `TEXTURE_FILTER_NEAREST`를 기본으로 한다.
- 단, 묘지 세로 슬라이스는 새 모달 UI보다 기존 HUD와 월드 오브젝트를 우선한다.
- 기존 스프라이트로 기능을 먼저 검증하고, 구분이 안 되는 오브젝트만 PixelLab로 생성한다.
- PixelLab 생성 자산은 원본 PNG와 새 `.import` 파일만 커밋한다.

---

## 7. 이번에 하지 않을 것

- 나머지 4개 던전을 한 커밋에서 전부 구현
- 모든 몬스터·무기에 복잡한 속성/행동 태그 전수 추가
- 신규 캐릭터·무기·맵 추가
- 절차 생성 지형
- 새로운 재화 추가
- 순수 공격력 영구 강화 추가
- 통계 표본 없이 난이도 수치를 대폭 변경
- 오래된 `ROADMAP.md`, `NEXT_SESSION.md`, `PENDING_ART.md`의 미완료 항목을 현재 우선순위로 간주

`ROADMAP.md`와 `NEXT_SESSION.md`에는 이미 완료되었거나 방향이 바뀐 과거 계획이 섞여 있다.
현재 RPG 방향의 기준 문서는 `RPG_ROGUELIKE_EVOLUTION_PLAN.md`와 이 문서다.

---

## 8. 현재 이후 작업 순서

1. **던전 탐사 맵 크기 확대**
   - `StageLayout.WORLD`와 모든 지형·목표 좌표를 같은 비율로 확대
   - 연결성·목표 접근성 자동 테스트와 실제 이동 밀도 렌더 확인
   - 이동 시간 측정 뒤에만 몹 밀도·빙하 냉기율·보스 시간을 조정
2. **M5-C 공허**
   - 공허 닻과 중력장
   - 위치 선정과 이동 경로 왜곡
   - 시선 원뿔, 회전 광선, 분신/핵 파괴 보스
3. **M5-D 마왕성**
   - 열주 대홀의 지휘관과 성문 관문
   - 정예 연속전과 최종 빌드 검증
   - 처형선, 소환 지휘, 다단계 마왕 보스
4. **M5-E 통계 기반 밸런스**
   - `RunTelemetry.aggregate()`를 난이도·시작 던전별로 집계
   - 난이도마다 최소 5회, 권장 10회 수동 원정 기록 확보
   - 클리어율, 사망 층, 평균 획득 골드, 추출 등급, 경로 선택률 비교
   - 쉬움 70~85%, 보통 45~65%, 어려움 20~40%, 악몽 5~20%를 초기 목표로 검토
   - 한 경로 선택률이 55% 이상이면 비용/보상을 재검토
   - 능동 전투 목표상 `E + Q` 피해 비중도 함께 확인

모든 던전 확장과 1차 밸런스가 끝난 뒤에야 신규 캐릭터·무기·맵을 논의한다.

---

## 9. 검증 명령 예시

현재 확인된 Godot 콘솔 실행 파일:

```powershell
$godotExe = 'C:\Users\kpo02\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe'
```

새 단위 테스트:

```powershell
& $godotExe --headless --path . --script res://tests/GraveyardSliceTest.gd
& $godotExe --headless --path . --script res://tests/GlacierSliceTest.gd
```

핵심 메인 흐름:

```powershell
& $godotExe --headless --path . -- --autoshot --telemetry-test
& $godotExe --headless --path . -- --autoshot --map-selection-test
& $godotExe --headless --path . -- --autoshot --expedition-flow-test
```

시각 검증:

```powershell
& $godotExe --path . --rendering-method gl_compatibility -- --autoshot --graveyard-preview=seal
& $godotExe --path . --rendering-method gl_compatibility -- --autoshot --graveyard-preview=midboss
& $godotExe --path . --rendering-method gl_compatibility -- --autoshot --graveyard-preview=boss
& $godotExe --path . --rendering-method gl_compatibility -- --autoshot --glacier-preview=brazier
& $godotExe --path . --rendering-method gl_compatibility -- --autoshot --glacier-preview=midboss
& $godotExe --path . --rendering-method gl_compatibility -- --autoshot --glacier-preview=boss
```

주의:

- Intel 환경에서 `gl_compatibility`를 유지한다.
- 기존 `_retro_backup` 중복 UID 경고와 종료 시 일부 리소스 leak 경고는 현재도 존재한다.
- 새 파서 오류나 새 리소스 누락과 기존 경고를 구분한다.
- 커밋 전 `git diff --check`와 `git status -sb`를 확인한다.
- `RPG_ROGUELIKE_EVOLUTION_PLAN.md`의 M5 전체 체크는 공허·마왕성·1차 밸런스까지 끝나기 전에 완료 처리하지 않는다.
