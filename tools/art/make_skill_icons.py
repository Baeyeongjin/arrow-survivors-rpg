# -*- coding: utf-8 -*-
# 이미 산 VFX 팩에서 스킬 아이콘을 뽑는다. 새로 생성하지 않는다.
#
# 지금까지 아이콘이 흐렸던 이유 두 가지를 여기서 같이 고친다:
#   1) 코드가 무조건 프레임 2를 썼다. 그건 이펙트가 막 피어나는 순간이라
#      bolt는 점, impact는 흰 사각형이 잡혔다.
#      -> 2~4번 중 실제로 가장 많이 그려진(불투명 총량이 큰) 프레임을 고른다.
#         0·1을 후보에서 빼는 건 0은 거의 비어 있고 1은 플래시 프레임이기 때문.
#   2) 64px 캔버스 가운데 작게 그려져 있어 46px 슬롯에 넣으면 실제 그림은 20px뿐이었다.
#      -> 알파 여백을 잘라내고 32px에 꽉 채운다.
#
# 결과는 assets/skill_icons/<fx폴더이름>.png. fx 이름이 이미 형태+원소를 담고 있어
# 아키타입을 파일명에 넣을 필요가 없다(swing과 slash는 같은 그림을 공유).
from PIL import Image
import os
import sys

ROOT = (r"C:\Users\kpo02\OneDrive\바탕 화면\개인폴더\claude ai Team"
        r"\AI 팀(개발 , 디자인)\output\arrow-rpg")
ANIM = os.path.join(ROOT, "assets", "anim")
OUT = os.path.join(ROOT, "assets", "skill_icons")

# FxMatrix.gd 의 FORMS + HEAVY 와 같아야 한다. 어긋나면 아이콘 없는 스킬이 생긴다.
FORMS = {
    "cast": {"phys": "vfx_phys_005", "fire": "vfx_fire_flamme", "ice": "vfx_ice_claw",
             "dark": "vfx_dark_spin", "holy": "vfx_holy_wings", "water": "vfx_water_splash",
             "wind": "vfx_wind_gust", "earth": "vfx_earth_grow", "elec": "vfx_elec_spin"},
    "bolt": {"phys": "vfx_phys_001", "fire": "vfx_fire_ball", "ice": "vfx_ice_ball",
             "dark": "vfx_dark_ball", "holy": "vfx_holy_ball", "water": "vfx_water_ball",
             "wind": "vfx_wind_ball", "earth": "vfx_earth_ball", "elec": "vfx_elec_ball"},
    "impact": {"phys": "vfx_phys_002", "fire": "vfx_fire_explosion1", "ice": "vfx_ice_rock",
               "dark": "vfx_dark_explosion1", "holy": "vfx_holy_cross",
               "water": "vfx_water_explosion", "wind": "vfx_wind_explosion",
               "earth": "vfx_earth_lavabubble", "elec": "vfx_elec_explosion"},
    "slash": {"phys": "vfx_phys_003", "fire": "vfx_fire_slash", "ice": "vfx_ice_slash",
              "dark": "vfx_dark_slash", "holy": "vfx_holy_slash", "water": "vfx_water_slash",
              "wind": "vfx_wind_slash", "earth": "vfx_earth_spin", "elec": "vfx_elec_slash"},
    "zone": {"phys": "vfx_boom_05", "fire": "vfx_fire_pit", "ice": "vfx_ice_spike",
             "dark": "vfx_dark_portal", "holy": "vfx_holy_blessing",
             "water": "vfx_water_colomn", "wind": "vfx_wind_ground",
             "earth": "vfx_earth_lava", "elec": "vfx_elec_lighting1"},
    "ward": {"phys": "vfx_boom_07", "fire": "vfx_fire_shield", "ice": "vfx_ice_shield",
             "dark": "vfx_dark_shield", "holy": "vfx_holy_shield", "water": "vfx_water_shield",
             "wind": "vfx_wind_shield", "earth": "vfx_earth_shield", "elec": "vfx_elec_shield"},
}
HEAVY = {
    "impact": {"phys": "vfx_boom_03", "fire": "vfx_fire_explosion2", "ice": "vfx_ice_slam",
               "dark": "vfx_dark_explosion2", "holy": "vfx_holy_slash2",
               "water": "vfx_water_wave", "wind": "vfx_wind_spread",
               "earth": "vfx_earth_rock", "elec": "vfx_elec_lighting2"},
    "zone": {"phys": "vfx_boom_06", "fire": "vfx_fire_tornado", "ice": "vfx_ice_projectile",
             "dark": "vfx_dark_blackhole", "holy": "vfx_holy_projectile",
             "water": "vfx_water_cascade", "wind": "vfx_wind_turbine",
             "earth": "vfx_earth_heal", "elec": "vfx_elec_tornado"},
}

SIZE = 32          # 스킬바 슬롯(46) 안에 여백을 두고 1:1로 앉는 크기
CANDIDATES = (2, 3, 4)


def best_frame(folder):
    """2~4번 중 불투명 총량이 가장 큰 프레임. 이펙트가 제일 많이 그려진 순간이다."""
    best, best_mass = None, -1
    for i in CANDIDATES:
        p = os.path.join(ANIM, folder, "%d.png" % i)
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        mass = sum(im.getchannel("A").getdata())
        if mass > best_mass:
            best, best_mass = im, mass
    return best


def make_icon(folder, dest):
    im = best_frame(folder)
    if im is None:
        return False
    box = im.getchannel("A").getbbox()      # 알파 여백 잘라내기
    if box is None:
        return False
    im = im.crop(box)
    # 종횡비를 지키며 SIZE 안에 꽉 채운다. 확대는 정수배가 아니어도 니어리스트라 각이 산다.
    scale = min(SIZE / im.width, SIZE / im.height)
    w, h = max(1, int(round(im.width * scale))), max(1, int(round(im.height * scale)))
    im = im.resize((w, h), Image.NEAREST)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(im, ((SIZE - w) // 2, (SIZE - h) // 2))
    out.save(dest)
    return True


os.makedirs(OUT, exist_ok=True)
wanted = {}
for table in (FORMS, HEAVY):
    for row in table.values():
        for folder in row.values():
            wanted[folder] = True

ok, missing = 0, []
for folder in sorted(wanted):
    if not os.path.isdir(os.path.join(ANIM, folder)):
        missing.append(folder)
        continue
    if make_icon(folder, os.path.join(OUT, folder + ".png")):
        ok += 1
    else:
        missing.append(folder)

print("icons written: %d / %d" % (ok, len(wanted)))
if missing:
    print("MISSING (%d): %s" % (len(missing), ", ".join(missing)))
    sys.exit(1)
