# PixelLab 외곽 지형 타일

5개 던전의 이동 불가 외곽에 쓰는 PixelLab 원본과 재현 정보다.

## 공통 규칙

- 도구: PixelLab `tiles-pro`
- 원본: 테마당 6장, `128×128`, top-down square tile
- 저장: `assets/maps/<theme>/outer/00.png` ~ `05.png`
- 런타임: `StageTileRenderer.gd`가 원본을 nearest 방식으로 `64→128` 정수 확대한다.
- 배치: 1장을 사각 격자로 랜덤 반복하지 않고, 기본 재질 위에 다른 재질을 384px 단위의 불규칙 지질 패치로 섞는다.
- 미술 방향: 화면 가장자리까지 꽉 찬 저대비 지면 재질, 투명 여백·독립 오브젝트·텍스트·문양·체커·줄무늬·규칙 격자 금지.

## 생성 기록

| 테마 | PixelLab 작업 ID | 시드 | 핵심 프롬프트 |
|---|---|---:|---|
| 묘지 | `2664153e-3652-4505-a970-7c60e71e57e7` | 73101 | dark cemetery soil, mossy bedrock, dead roots, grave rubble |
| 지옥 | `d15a1bdd-5e5c-4ec7-a46d-90e4b628070f` | 73102 | obsidian crust, basalt, cooled lava, restrained ember fissures |
| 빙하 | `01a1ed72-cd2b-490b-9fa3-db97172d7cb1` | 73103 | navy glacier rock, fractured ice, packed snow, cyan cracks |
| 공허 | `518a8900-cede-4a78-a7db-2ba8f3952ce1` | 73104 | near-black violet abyss, voidstone, nebula wisps, sparse stars |
| 마왕성 | `b0774580-756e-4239-bc61-7fe5da6c2fc7` | 73105 | gothic foundation stone, broken masonry, burgundy dust, iron fragments |

공통 프롬프트의 시작은 다음과 같다.

> Four seamless edge-to-edge top-down pixel-art terrain tile variations for an IMPASSABLE [theme] exterior, each tile completely filled to all four edges with no border and no isolated object.

끝에는 각 테마 팔레트와 함께 다음 금지 조건을 넣었다.

> Organic irregular large shapes. No checkerboard, no stripes, no regular grid, no text, no symbols, no transparent gaps, no focal landmark.

PixelLab가 실제로 4장이 아닌 6개 변형을 반환했기 때문에 6장 모두 보존했다. 재생성할 때는 고해상도 배경화처럼 보이지 않도록 `chunky 16-bit pixel clusters, limited palette, readable 2px clusters`를 추가하거나, 현재처럼 런타임 64px 논리 해상도 처리를 유지한다.
