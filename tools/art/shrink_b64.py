# PixelLab animate_image의 인라인 base64는 큰 PNG에서 전송 중 잘린다(도구가 경고).
# 32x32 스프라이트를 색 축소 + 최대 압축으로 다시 저장해 base64를 짧게 만든다.
# 알파는 보존해야 배경 투명이 유지된다.
import base64
import io
import sys
from PIL import Image

# 1400자대는 불안정하다(1432 통과 / 1388·1424 잘림). 1100자 이하는 안정적으로 통과했다.
LIMIT = 1100


def shrink(path: str) -> str:
    src = Image.open(path).convert("RGBA")
    alpha = src.split()[3]
    for colors in (32, 24, 16, 12, 8, 6, 4, 3):
        # 알파를 뺀 RGB만 팔레트화하고, 알파는 이진 마스크로 되돌린다.
        rgb = src.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT)
        out = rgb.convert("RGBA")
        out.putalpha(alpha.point(lambda a: 255 if a > 128 else 0))
        buf = io.BytesIO()
        out.save(buf, format="PNG", optimize=True)
        encoded = base64.b64encode(buf.getvalue()).decode("ascii")
        if len(encoded) <= LIMIT:
            return "%s\t%d\t%s" % (colors, len(encoded), encoded)
    return "FAIL\t%d\t" % len(encoded)


for arg in sys.argv[1:]:
    print(arg.rsplit("\\", 1)[-1].replace(".png", ""), shrink(arg), sep="\t")
