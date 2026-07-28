# 스테이지 맵 작업 인계

## 현재 반영 상태

- 5개 맵을 선택 화면에서 바로 선택·입장할 수 있도록 연결했다.
- 스테이지별 이동 가능 영역과 충돌은 `StageLayout.gd` 한 곳에서 관리한다.
- 모든 맵은 2800×2800의 열린 전장이다. 이전처럼 화면 가장자리에 검은 빈 공간이 생기거나 중앙 통로에만 갇히지 않는다.
- 각 맵은 전용 Wang 타일셋을 렌더링하며, 타일 렌더와 실제 충돌 판정이 같은 `StageLayout.is_walkable()`을 사용한다.
- 현재 충돌 지형은 스테이지별로 의도한 소수의 큰 장애물만 둔다.
  - 1 묘지: 네 개의 묘역
  - 2 지옥: 네 개의 용암 균열
  - 3 빙하: 네 개의 얼음 호수
  - 4 공허: 네 개의 부유 유적 구역
  - 5 마성: 네 개의 성채 방
- 랜덤 잡동사니 장식은 5개 이하로 축소했고, 시작 지점 주변에는 파괴물·잡동사니를 두지 않도록 했다.
- 맵 선택 프레임 PNG에 실제로 박혀 있던 체크무늬와 중앙 금테를 정리한 `assets/ui/map_select_frame_clean.png`을 사용한다. 원본은 보존한다.

## 새 맵 오브젝트 에셋

아래 5개는 PixelLab 생성 결과를 실제로 검수했고, 전용 장애물 아트로 사용할 수 있다.

- `assets/maps/graveyard/tomb_cluster.png`
- `assets/maps/graveyard/mausoleum.png`
- `assets/maps/hell_bridge/lava_fissure.png`
- `assets/maps/hell_bridge/obsidian_pillar.png`
- `assets/maps/glacier/ice_lake.png`

아래 4개는 생성·다운로드 단계까지 진행했지만, 이번 세션 종료 직전에 최종 파일 검수와 배치는 하지 않았다.

- `assets/maps/glacier/ice_ruin.png`
- `assets/maps/void_altar/ritual_altar.png`
- `assets/maps/void_altar/void_monoliths.png`
- `assets/maps/demon_castle/wall_chamber.png`

마성의 왕좌 오브젝트는 PixelLab 작업 ID
`c180c029-d844-4605-92d8-79065ecae957` 이며, 생성 완료 여부 확인 후 내려받아야 한다.

## 다음 작업 순서

1. 완료된 맵 오브젝트를 모두 실제 이미지로 검수한다. 자동 생성물이 부자연스럽거나 시인성이 낮으면 다시 생성한다.
2. `Main.gd`의 `_gen_decorations()`을 랜덤 장식 방식에서 스테이지별 고정 배치 테이블로 바꾼다.
   - 장애물 위치는 `StageLayout.gd`의 `blocked_rects`/`blocked_circles`와 일치시킨다.
   - 새 오브젝트는 확대·반전만 최소한으로 사용하고, 동일 조형물을 화면에 과도하게 반복하지 않는다.
3. 다섯 맵을 각각 실제 실행 화면으로 캡처해 확인한다.
   - 검은 빈 공간/클리핑 없음
   - 플레이어·적·투사체의 대비 확보
   - 맵마다 첫 화면에서 즉시 다른 장소로 인식 가능
4. 맵 선택 UI도 최종 실행 캡처로 검증한다.
   - 선택된 카드만 강조
   - 카드 2~5와 `N번 맵 입장` 버튼 모두 마우스 클릭 가능
   - 프레임 외곽에 체크무늬 없음

## 검증 명령

```powershell
& 'C:\Users\kpo02\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' --headless --path . -- --autoshot --stage-layout-test
& 'C:\Users\kpo02\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tests/StageTileRendererTest.gd
& 'C:\Users\kpo02\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' --path . -- --autoshot --map-mouse-click-test
```

`--autoshot --selected-stage=1`부터 `5`까지로 각 인게임 화면도 확인한다.

## 주의

- 유물 UI/인게임 획득 시스템은 재설계 전까지 비활성화 상태를 유지한다. 텍스트 목록이나 화살표 UI를 다시 추가하지 않는다.
- 보스 패턴은 의도적으로 넣지 않는다. 뱀서식 추적·압박 보스 방향을 유지한다.
- 화면상 품질 완료라고 말하기 전에 반드시 해당 화면 캡처를 확인한다.
