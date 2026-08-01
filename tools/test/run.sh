#!/usr/bin/env bash
# 회귀 테스트 러너.
#
# GDScript에는 예외가 없다. SceneTree 테스트가 _initialize() 도중 오류를 만나면
# 그 자리에서 중단되는데, quit()에 닿지 못하면 트리가 계속 살아 있는다.
# 그래서 '실패'가 '무한 대기'로 둔갑하고, 실패 하나가 10분을 잡아먹는다.
# 실제로 이것 때문에 5개가 무한 대기로 보였고 전부 그냥 실패였다.
#
# 여기서 타임아웃을 걸어 그 둔갑을 막는다. 종료코드 124(타임아웃)는 실패로 센다.
#
# 사용법:
#   tools/test/run.sh              # 전체
#   tools/test/run.sh Glacier      # 이름에 Glacier가 들어간 것만
#   TEST_TIMEOUT=60 tools/test/run.sh
#
# 종료코드: 실패가 하나라도 있으면 1.

set -u
cd "$(dirname "$0")/../.." || exit 1

GODOT="${GODOT:-C:/Users/user/Godot/Godot_v4.7-stable_win64_console.exe}"
TIMEOUT="${TEST_TIMEOUT:-30}"
FILTER="${1:-}"

if [ ! -f "$GODOT" ]; then
	echo "Godot 실행파일을 찾을 수 없다: $GODOT"
	echo "GODOT 환경변수로 경로를 지정하라."
	exit 1
fi

pass=0
fail=0
failed_names=""

for t in tests/*.gd; do
	name="$(basename "$t" .gd)"
	if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then
		continue
	fi
	out="$(timeout "$TIMEOUT" "$GODOT" --headless --path . --script "res://$t" 2>&1)"
	code=$?
	if [ $code -eq 0 ]; then
		pass=$((pass + 1))
		printf 'PASS  %s\n' "$name"
		continue
	fi
	fail=$((fail + 1))
	failed_names="$failed_names $name"
	if [ $code -eq 124 ]; then
		# 타임아웃은 대개 "실패했는데 quit()에 못 닿은" 경우다. 무한 루프가 아니라
		# 중단이므로, 직전 오류 메시지가 진짜 원인이다.
		printf 'HANG  %s (%ss 초과 — quit() 미도달로 추정)\n' "$name" "$TIMEOUT"
	else
		printf 'FAIL  %s (exit %d)\n' "$name" "$code"
	fi
	# 원인 한 줄만. 전체 로그는 직접 돌려 보면 된다.
	printf '%s\n' "$out" | grep -iE 'ERROR|실패|아님|없음|되살아났다' | head -2 | sed 's/^/        /'
done

echo "----------------------------------------"
printf '통과 %d · 실패 %d\n' "$pass" "$fail"
if [ $fail -gt 0 ]; then
	printf '실패:%s\n' "$failed_names"
	exit 1
fi
