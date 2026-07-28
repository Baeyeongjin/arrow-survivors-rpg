#!/bin/bash
# 사용법: bash dl_dir.sh <charid> <keyword> <keymotion>
#   keyword=애니폴더명에 포함된 문자열(설명 일부). north 하위폴더가 있는(=방향생성된) 애니만 선택.
# 결과: <keymotion>_n / <keymotion>_e
ANIM="/c/Users/kpo02/OneDrive/바탕 화면/개인폴더/claude ai Team/AI 팀(개발 , 디자인)/output/arrow-a-row/assets/anim"
cd "/c/Users/kpo02/AppData/Local/Temp/claude/C--Users-kpo02-OneDrive------------claude-ai-Team-AI------------/82e7e78b-1f25-4228-ba82-e56b5c66b7dc/scratchpad" || exit 1
charid=$1; kw=$2; km=$3
td="dtmp_${km}"; rm -rf "$td"; mkdir -p "$td"
curl -sL "https://api.pixellab.ai/mcp/characters/$charid/download" -o "d_${km}.zip"
unzip -oq "d_${km}.zip" -d "$td" 2>/dev/null || { echo "$km ZIP FAIL"; exit 1; }
# north 하위폴더가 있는 애니 중 키워드 포함 폴더 (=이번 방향 생성분)
adir=$(find "$td" -type d -path "*/animations/*${kw}*/north" | head -1)
if [ -z "$adir" ]; then echo "  MISS ${km} (kw=$kw, 렌더중?)"; exit 0; fi
base=$(dirname "$adir")   # .../animations/<descfolder>
for dir in north east; do
  suf="_n"; [ "$dir" = "east" ] && suf="_e"
  src="$base/$dir"
  if [ ! -d "$src" ]; then echo "  MISS ${km}${suf}"; continue; fi
  dst="$ANIM/${km}${suf}"; mkdir -p "$dst"; rm -f "$dst"/*.png
  n=0; for f in $(ls "$src"/frame_*.png 2>/dev/null | sort); do cp "$f" "$dst/$n.png"; n=$((n+1)); done
  echo "  ${km}${suf}: ${n}f"
done
