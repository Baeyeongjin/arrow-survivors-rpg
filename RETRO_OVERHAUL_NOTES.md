# 레트로 아트 개편 — 작업 정리 & 이어가기 노트

> 다른 PC에서 이어서 작업할 때 이 문서부터 읽으세요. (2026-07-14 기준)

## 지금까지 완료 (전부 push됨: main, ~e429cde)

**아트 전면 재생산 (16비트 뱀서풍, CC0 DCSS 스타일 앵커 기반)**
- **몹 17종**: 새 청크 스프라이트 + 걷기 애니(박쥐는 나는 모션). `assets/enemies/*.png`, `assets/anim/<key>_walk/`
- **캐릭터 8종 (새 오리지널 로스터)**: 코르비우스(역병의사)·구스타보(정육점)·세라피나(수녀)·발렌티노(뱀파이어)·픽시(마녀)·장고(총잡이)·볼트(태엽인형)·모르가나(유령). 32×32 통일. `assets/anim/<key>_1_idle|walk/`, `assets/hero/<key>_1.png`. GameConfig.characters() + `_apply_char_trait` 재배선.
- **보스 6종**: boss_1~5 + reaper, 64px. `assets/boss/`
- **아이템 11종**: 젬·코인·하트·자석·시계·로자리 + 파괴물(통/상자/항아리/횃불/관). `assets/items/`
- **무기 아이콘 35종 전부**: 카드+인벤토리+아이콘형 투사체. `assets/items/icon_*.png` (+ arrow/sword)
- **패시브 아이콘 18종**: `assets/items/icon_*` (저비용 map_object)
- **투사체**: `proj_*` 애니 폴더는 `assets/_retro_backup/`로 이동(=제거) → 투사체가 새 아이콘 스프라이트로 폴백. `zone_*`(장판)는 유지.
- **크기 통일**: 캐릭터 32px, 몹 radius 전반 ~20%↓, 보스 radius 56→42.
- **배경**: `assets/bg/floor.png` = 심리스 초록 풀 텍스처(PIL 생성), 톤 초록, 꽃/덤불 장식(`decor_flower1/2`, `decor_bush`).

**게임필**
- 무기 타격감 v1: 모든 명중에 청크 임팩트 스파크(치명타 크게/노랗게), 기본무기(화살/단검/화염구/부메랑) 발사 섬광, 수리검 회전. (Main.gd `_apply_arrow_hit`, `WMUZZLE`)

## 남은 작업 (다음 세션)

1. **★무기 공격 이펙트/모션 다듬기 (유저가 "가장 중요"로 지목, 진행 중 v1만 완료)**
   - export해서 플레이 느낌 확인 후 구체 피드백 반영 예정.
   - 인프라는 이미 완비: `WMUZZLE`(발사섬광), Arrow.gd(spin/trail/homing/fx_hit). 근접·오라류(채찍/검기/오라) 모션 다듬기, 트레일/임팩트 강도 조정 여지.
2. **UI 뱀서화**: 상단 HUD(무기·패시브 슬롯·골드·타이머)·프레임을 레퍼런스처럼. (유저가 export 후 구체 지정 예정)
3. (선택) zone_ 장판 3종, fx_ 타격이펙트 재스타일 — 저가치라 후순위.
4. **유물/해금 시스템** (대형, 오래 미뤄둠): `RELIC_UNLOCK_DESIGN.md` 참고. 시야 시스템은 제외 확정.

## PixelLab 아트 파이프라인 (재현 방법)

> 스크립트(`pl.py` 등)는 임시 scratchpad에 있어 **동기화 안 됨**. 다른 PC에선 아래로 재구성.

- **엔드포인트**: `https://api.pixellab.ai/mcp` (MCP-over-HTTP, JSON-RPC). 토큰은 `~/.claude.json`의 pixellab mcpServers `Authorization: Bearer ...` (유저 본인 계정). 또는 그냥 Claude의 pixellab MCP 툴 사용.
- **스타일 앵커(중요 에셋)**: CC0 DCSS `skeletal_warrior.png` (32x32)를 `style_images`로 넘겨 `create_1_direction_object` → 청크 뱀서 룩 상속. 출처: opengameart.org/content/dungeon-crawl-32x32-tiles (CC0), github crawl/crawl `crawl-ref/source/rltiles/mon/undead/skeletal_warrior.png`. 큰 몹/보스는 48~64px 시드로.
- **저비용(자잘한 UI/아이콘)**: `create_map_object`(건당 ~1-2 gen, 후보팩 없음) + low detail·flat·단색외곽. style_images는 건당 ~20 gen이라 아낌.
- **후보 팩 자동정리**: create_1_direction_object는 32px면 64후보 review 생성 → `select_object_frames(indices=[0])`로 1개 뽑고 **`delete_object(pack_id)`로 잔여 즉시 삭제**(계정 클러터 방지).
- **프레임 다운로드**: backblaze URL은 urllib이 403 → **User-Agent 헤더(Mozilla) 붙이거나 curl** 사용. 애니 프레임 URL은 get_object의 `unknown: .../{i}.png (i=0..N)`. 오브젝트 png: `/mcp/objects/<id>/download`, map-object: `/mcp/map-objects/<id>/download`.
- **동시 잡 10개 한도** (초과 시 rate limit → 웨이브로).
- **예산**: 2026-07-14 기준 잔량 ~800 (Tier 2, 총 3839). 남은 작업은 map_object 저비용 위주로.

## 배선 규칙 (코드)
- 몹: `assets/enemies/<key>.png` (또는 `assets/anim/<key>_walk/`) — GameConfig `enemy_tiers()`의 radius가 크기.
- 캐릭터: `assets/anim/<key>_1_idle|walk/`, 초상화 `assets/hero/<key>_1.png`. char_stages(key)가 `<key>_1` 폴더 자동 참조. 1방향+좌우반전(Player._mframes 남쪽 폴백).
- 무기 투사체: Arrow가 `anim_dir` 프레임 없으면 `sprite_path`(= `WICON[kind]` 아이콘)로 폴백.

## 환경 제약
- 렌더러 `gl_compatibility` 유지 (Intel Vulkan Forward+ TDR freeze 방지). 되돌리지 말 것.
- 빌드: 유저가 직접 export(재내보내기 하지 말 것). 소스 편집 후 유저가 export해야 반영됨.
- 구 에셋 백업은 `assets/_retro_backup/` (gitignore → 다른 PC엔 없음. 롤백 필요시 git history 사용).
