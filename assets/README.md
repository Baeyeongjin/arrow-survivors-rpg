# 에셋 폴더 — Kenney 픽셀 스프라이트 연동 가이드

이 폴더에 아래 **정확한 이름**으로 PNG를 넣으면 게임이 자동으로 그림으로 바꿔 그립니다.
파일이 없으면 도형 폴백으로 정상 실행되므로, **지금 당장 넣지 않아도 됩니다.**

## 폴더 / 파일 슬롯

```
assets/
├── hero/
│   ├── hero_1.png   ← 1단계 (Lv 1~2)
│   ├── hero_2.png   ← 2단계 (Lv 3~5)
│   ├── hero_3.png   ← 3단계 (Lv 6~8)
│   └── hero_4.png   ← 4단계 (Lv 9+)
├── enemies/
│   ├── slime.png      ← 티어1 (Lv 1~2)
│   ├── bat.png        ← 티어2 (Lv 3~4)
│   ├── skeleton.png   ← 티어3 (Lv 5~6)
│   ├── orc.png        ← 티어4 (Lv 7~8)
│   └── demon.png      ← 티어5 (Lv 9+)
├── boss/
│   └── boss.png
└── bg/
    └── floor.png   ← 스크롤 배경 (던전 바닥 타일, 64x64 seamless)
```

> 모든 스프라이트는 정사각형(예: 16×16, 32×32) 권장. Nearest 필터가 적용돼 확대해도 또렷합니다.

## 실제로 사용 중인 외부 에셋 (출처 기록 — 전부 CC0, 표기 의무는 없음)

| 에셋 | 용도 | 출처 |
|------|------|------|
| **Smoke Aura** (Beast) | 장판 3종 `anim/zone_holy·zone_lava·zone_poison` — 96px 축소 + 색조 곱하기(금/주황/녹)로 파생. 알파는 유지(포스터라이즈하면 딱딱해짐) | https://opengameart.org/content/smoke-aura |
| **Pixel Art Sword Slash Effect** (tbbk) | `anim/fx_cleave` · `anim/fx_whip`(가로로 구움) · `anim/fx_whip_evo`(핏빛). 9프레임. **확대는 반드시 NEAREST** — 도트가 또렷해야 캐릭터와 결이 맞음 | https://opengameart.org/content/pixel-art-sword-slash-effect |
| ~~Weapon Slash - Effect~~ (Cethiel) | 미사용 — 부드러운 에어브러시 글로우라 청크한 16비트 도트와 겉돌았음 (tbbk로 교체) | https://opengameart.org/content/weapon-slash-effect |
| **Pixel Magic Effects** (Foozle) | `anim/fx_*` 다수 — 색조 변환해 파생 | Foozle_2DE0001_Pixel_Magic_Effects |
| **Dungeon Crawl 32×32 Tiles** | PixelLab `style_images` 스타일 앵커(`skeletal_warrior.png`) — 16비트 뱀서 룩 상속용 | https://opengameart.org/content/dungeon-crawl-32x32-tiles |

## 추천 Kenney 팩 (모두 무료 · CC0 · 출처표기 불필요)

| 팩 | 용도 | 링크 |
|----|------|------|
| **Tiny Dungeon** | 주인공·슬라임·해골·몬스터 (16×16, 판타지) | https://kenney.nl/assets/tiny-dungeon |
| **Tiny Battle** | 추가 캐릭터/유닛 | https://kenney.nl/assets/tiny-battle |
| **Pixel Shmup** | 보스·탄막·발사체 느낌 | https://kenney.nl/assets/pixel-shmup |
| **1-Bit Pack** | 통일된 레트로 톤 다량 | https://kenney.nl/assets/1-bit-pack |

## 적용 순서
1. 위 팩 다운로드 → 압축 해제
2. 팩 안 `Tiles/` 폴더의 개별 PNG에서 마음에 드는 그림을 골라
   위 슬롯 이름으로 **복사·이름변경**해서 해당 폴더에 넣기
3. Godot 에디터를 다시 열면(또는 포커스를 주면) 자동 import 됨 → 바로 그림으로 표시
4. (픽셀 또렷하게) 파일별 import 설정에서 Filter를 끄거나, 코드에서 이미 Nearest 처리됨

## 슬롯 ↔ 코드 위치
- 경로 정의: `GameConfig.gd` (몬스터 `sprite`, 주인공 `sprite`), `Boss.gd` (`SPRITE`)
- 로더: `Assets.gd` (`Assets.tex(path)` — 파일 없으면 null → 도형 폴백)
