# 다음 작업 노트 (다른 PC에서 이어갈 때 이 문서부터 읽기)

> 2026-07-14 세션 정리. 이전 아트 개편은 `RETRO_OVERHAUL_NOTES.md` 참고.

## ✅ 이번 세션 완료 (커밋 d8f4c2b, main에 push됨)

**버그 수정**
- **방향 반전 버그**: 스프라이트 기본이 '왼쪽 향함'인데 코드가 '오른쪽 전제'라 플레이어·적이 이동/타겟 **반대쪽을 보던 것** 교정. `Player.gd` sx, `Enemy.gd` sx 부호 반전.
- **보스 데미지 '0' 표시**: 적은 이미 지속피해 누적 처리돼 있었고, 보스만 `int(round(d))`라 0 뜸 → `Boss.gd`에 `_dmg_accum`/`_dmg_flush` 누적 방식 추가.

**스케일 (전부 그리기 크기만, 충돌 반경은 유지)**
- 캐릭터: `Player.gd` BASE_RADIUS 20→15→**10.5**
- 몬스터: `Enemy.gd` 그리기 `radius×3.05 → ×2.14` (일반+죽음 애니)
- 투사체: `Arrow.gd` 그리기 상한 38→26→**13**, base 30/17→7. 진화 후광도 축소.
- 픽업: `Pickup.gd` 텍스처 32→**16**, radius 14→8, 글로우↓ (크리스탈급)

**타격감/이펙트**
- 명중 임팩트 스파크 v2: `Effect.gd`에 `spark` 종류 추가(진행방향 샤드+흰 코어 플래시), `_apply_arrow_hit`에서 사용.
- 적 걷기 붕뜸(bob) 완화: `Enemy.gd` bob 0.028→0.012, wob 0.05→0.02.
- **월광 착탄 fx_magic**(큰 보라 원) 제거: `_fire_moonlight`에서 `st.fx_name = ""`.
- **오라 금색 링 테두리** 제거: Main `_draw`의 aura `draw_arc` 삭제.

**게임플레이**
- 픽업 스폰 빈도↓ (22→34초, 화면 상한↓)
- **파괴물(촛대 등) 모든 공격으로 파괴**: `_break_near(pos,rad,dmg)` 헬퍼 추가 → 오라·회전검·채찍(_fire_whip)·검기(_fire_cleave)에 적용. (투사체는 자동조준, 폭발은 이미 됨)

**발사체 프레임 애니 (PixelLab, `upright` 회전 없음)**
- 완료 4종: **파이어볼·혼탄(soul_bolt)·성광선(holy_beam)·유도해골(homing_skull)**
- `Arrow.gd`에 `upright` 플래그 추가(원소 이펙트는 진행방향 회전 안 함). 해당 무기 발사부에서 `a.upright = true`.

## 🔲 남은 작업 / 확인 필요

1. **발사체 애니 더 뽑기** (원소 계열): 얼음창·독안개·공허구·번개·달빛 등. 단 회전형(칼·도끼·차크람·성십자·뼈나선·부메랑)은 코드 스핀으로 이미 처리 → 애니 불필요. 직진형(창·볼트)도 정적 OK. **모양 변하는 원소만** 애니 대상.
2. **노란 테두리 잔여 확인**: 오라 링은 제거함. 하늘폭격(별똥별·천벌) 착탄 **경고 링**, 성수/성십자 발사 **노란 링 섬광**도 뺄지 유저 확인 필요(경고 링은 예고 기능이라 주의).
3. **#2 상/하 방향 스프라이트** (보류/결정 필요): 현재 옆모습만 좌우반전(VS 정석). 상하 전용 스프라이트는 대규모 작업(플레이어8+적17×방향). 유저가 원하면 PixelLab 8방향에서 뽑기.
4. 유저가 export 후 피드백 예정: 투사체/픽업/캐릭터 크기 최종 미세조정, 타격감.

## 🎨 PixelLab 발사체 애니 파이프라인 (다른 PC에서 재현법)

**⚠️ 다른 PC에선 pixellab MCP 재연결 필요**: `%APPDATA%\Claude\claude_desktop_config.json`의 `mcpServers`에 아래 추가 후 앱 재시작. (앱 커넥터 UI는 OAuth만 지원 → Bearer 토큰 못 넣으니 **반드시 config 파일 방식**. 파일은 BOM 없이 저장 — Node `fs.writeFileSync` 사용.)
```json
"pixellab": { "command":"npx", "args":["mcp-remote@latest","https://api.pixellab.ai/mcp","--transport","http-only","--header","Authorization:${AUTH_HEADER}"], "env":{"AUTH_HEADER":"Bearer <유저 토큰>"} }
```
토큰은 유저 본인 PixelLab 계정 것. MCP 없이 **HTTP 직접 호출도 가능**(`curl POST https://api.pixellab.ai/mcp`, Authorization 헤더).

**핵심 절차** (게임 아이콘과 스타일 일치가 관건):
1. 게임의 `assets/items/icon_<무기>.png`와 **바이트 크기가 같은** PixelLab object를 찾아야 함(엉뚱한 오브젝트 애니하면 스타일 어긋남). `retro-wicon` 태그 오브젝트가 게임 아이콘의 원본(16종). 그 외는 `list_objects`로 찾아 다운받아 바이트 비교.
2. `animate_object(object_id, animation_description="<움직임 묘사>", frame_count=8)` → v3 모드, 1방향=1 generation. **~7분** 소요.
3. 완료되면 `get_object`가 애니 프레임 URL 제공: `.../animations/<group>/unknown/{i}.png` (i=0..8, keep_first_frame로 9장).
4. **backblaze URL은 User-Agent(Mozilla) 헤더 붙여 curl로 다운** (없으면 403). → `assets/anim/proj_<무기>/0.png..8.png`.
5. 해당 무기 발사부에 `a.upright = true` (원소 이펙트 회전 방지).
6. Godot `--headless --path <p> --import`로 .import 생성 후 `--quit`로 검증.

**계정 잔량**: 2026-07-14 기준 ~760 generations (Tier 2). 발사체 아이콘 32×32는 retro-wicon 태그.

## ⚠️ 지켜야 할 제약 (이전 노트 계승)
- 렌더러 **gl_compatibility 유지** (Intel Vulkan Forward+ TDR freeze 방지, 되돌리지 말 것). `project.godot`은 줄바꿈만 바뀐 걸로 뜨면 `git checkout` 으로 되돌릴 것.
- 빌드는 **유저가 직접 export** (재내보내기 X). 소스 편집 후 유저가 export해야 반영.
- `.import` 파일은 재임포트로 노이즈 뜸 → 커밋 전 `git checkout -- '*.import'`로 정리(자동 재생성됨). 새 에셋의 .import만 커밋.
