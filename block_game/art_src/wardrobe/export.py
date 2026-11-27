# -*- coding: utf-8 -*-
"""Этап 2: из исходников art_src/wardrobe/ собрать файлы для игры assets/wardrobe_art/.

    python3 export.py

Что делает:
1. Свечения сияний (<id>_glow.png) рисует программой (мягкий радиальный ореол в цветах сияния) — без нейросети.
2. Слои вещей (все file из fit.json) -> assets/wardrobe_art/<герой>/<file>.webp, сторона до 384 px, WebP с прозрачностью.
3. Иконки карточек гардероба и кузницы — по одной на КАЖДУЮ вещь каталога scripts/meta.gd (76 шт.)
   -> assets/wardrobe_art/<герой>/icons/<id>.webp, 160x160:
   - обычная вещь — её картинка (у вещей из нескольких слоёв — главные слои вместе, см. ICON_PARTS);
   - сияние — нарисованная иконка art_src/wardrobe/<герой>/<id>.png;
   - окрас — голова героя этого окраса из этапа 1 (облик «мальчик»; для девочки — <id>_girl.webp).
"""
import os, re, json, math
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "wardrobe_art")
HEROES = os.path.join(ROOT, "art_src", "heroes")
FIT = json.load(open(os.path.join(HERE, "fit.json"), encoding="utf-8"))
ANCH = json.load(open(os.path.join(HEROES, "anchors.json"), encoding="utf-8"))["images"]
PREFIX = {"ow": "owl", "ax": "axolotl", "pu": "puppy", "ki": "kitten"}
LAYER_MAX = 384
ICON = 160
Q = 86

# цвета мягкого ореола сияний (центр, кольцо)
GLOW = {
    "ow_aura_starfall": ["#FFE9A0", "#9FB4FF"], "ow_page_whirl": ["#FFE2A0", "#FFCB6B"], "ow_stargazer": ["#8C9BFF", "#C08BFF"],
    "ax_aura_bubbles": ["#BDF3FF", "#FFC2E4"], "ax_plankton": ["#7FF0E4", "#FF9AD8"], "ax_abyssal": ["#3FE0D0", "#6C7BFF"],
    "pu_petal_rainbow": ["#FFF2C2", "rainbow"], "pu_aura_bolts": ["#FFF08A", "#6CB8FF"], "pu_hero": ["#FFD36B", "#FF5F6D"],
    "ki_clue_trail": ["#FFE6A8", "#FFC85A"], "ki_aura_fireworks": ["#FFC2DC", "#B9A4FF"], "ki_starry": ["#D8CCFF", "#9FE8FF"],
}
# иконка вещи из нескольких слоёв: какие файлы и как сложить (сдвиг в долях иконки, масштаб)
ICON_PARTS = {
    "ax_gill_pearls": [("ax_gill_pearl", -0.22, 0.05, 0.5), ("ax_gill_pearl", 0.22, 0.05, 0.5), ("ax_gill_pearl", 0.0, -0.12, 0.55)],
    "ax_shell_pack": [("ax_shell_pack", 0, 0, 1.0)],
    "ax_wave_cape": [("ax_wave_cape", 0, 0.06, 0.9), ("ax_wave_clasp", 0, -0.33, 0.5)],
    "pu_jetpack": [("pu_jetpack", 0, 0, 1.0)],
    "ki_trench": [("ki_trench", 0, 0.05, 0.95), ("ki_trench_collar", 0, -0.12, 0.45)],
    "ki_ball_cloak": [("ki_ball_cloak", 0, 0.04, 0.95), ("ki_ball_clasp", 0, -0.3, 0.45)],
}


# тонкие широкие вещи (цепочки, ошейники) на маленькой иконке плохо читаются — берём главную часть крупнее
ICON_FOCUS = {
    "ax_black_pearl": (0.28, 0.0, 0.72, 1.0), "ow_astrolabe": (0.18, 0.0, 0.82, 1.0), "ki_cameo": (0.22, 0.0, 0.78, 1.0),
    "ki_sleuth_badge": (0.22, 0.0, 0.78, 1.0), "ki_bell_bow": (0.18, 0.0, 0.82, 1.0), "pu_bolt_band": (0.1, 0.0, 0.85, 1.0),
    "pu_daisy_wreath": (0.18, 0.0, 0.82, 1.0), "ax_coral_beads": (0.15, 0.0, 0.85, 1.0), "pu_whistle": (0.15, 0.0, 0.85, 1.0),
}


def halo(im, color=(255, 246, 255), alpha=0.42, grow=5):
    """Светлая мягкая кайма по силуэту — чтобы тёмные вещи читались на тёмной карточке."""
    a = im.getchannel("A").point(lambda v: 255 if v > 24 else 0)
    big = a.filter(ImageFilter.MaxFilter(grow * 2 + 1)).filter(ImageFilter.GaussianBlur(grow * 0.8))
    lay = Image.new("RGBA", im.size, color + (0,))
    lay.putalpha(big.point(lambda v: int(v * alpha)))
    lay.alpha_composite(im)
    return lay


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def make_glow(c1, c2, size=512):
    """Мягкий ореол: радиальный градиент от центра + светлое кольцо (для радуги — кольцо из цветов)."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = im.load()
    cx = cy = size / 2
    rain = [hexc(c) for c in ("#FF9AA8", "#FFD27A", "#FFF2A0", "#A8F0C0", "#A8D8FF", "#C8B4FF")]
    a1 = hexc(c1)
    for y in range(size):
        for x in range(size):
            dx, dy = (x - cx) / cx, (y - cy) / cy
            r = math.hypot(dx, dy)
            if r >= 1.0:
                continue
            core = max(0.0, 1.0 - r) ** 1.6 * 0.55
            ring = math.exp(-((r - 0.72) / 0.12) ** 2) * 0.45
            if c2 == "rainbow":
                ang = (math.atan2(dy, dx) / (2 * math.pi) + 0.5) * len(rain)
                i = int(ang) % len(rain)
                j = (i + 1) % len(rain)
                f = ang - int(ang)
                rc = tuple(rain[i][k] * (1 - f) + rain[j][k] * f for k in range(3))
            else:
                rc = hexc(c2)[:3]
            a = core + ring
            if a <= 0.004:
                continue
            col = tuple(int((a1[k] * core + rc[k] * ring) / a) for k in range(3))
            px[x, y] = col + (int(min(1.0, a) * 255),)
    return im.filter(ImageFilter.GaussianBlur(size / 64))


def catalog():
    src = open(os.path.join(ROOT, "scripts", "meta.gd"), encoding="utf-8").read()
    items = []
    for m in re.finditer(r'\{"id": "([a-z_]+)", "hero": "(\w+)", "slot": "(\w+)"[^}]*\}', src):
        items.append({"id": m.group(1), "hero": m.group(2), "slot": m.group(3), "raw": m.group(0)})
    return items


def fit_square(im, size, fill=0.9):
    im = im.copy()
    bb = im.getbbox()
    if bb:
        im = im.crop(bb)
    k = size * fill / max(im.size)
    im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(im, ((size - im.width) // 2, (size - im.height) // 2))
    return out


def save_webp(im, path, max_side):
    if max(im.size) > max_side:
        k = max_side / max(im.size)
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, "WEBP", quality=Q, method=6, exact=False)


def skin_head(hero, skin_file, gender):
    key = f"{hero}/{gender}_{skin_file}_idle"
    im = Image.open(os.path.join(HEROES, key + ".png")).convert("RGBA")
    a = ANCH[key]
    W, H = im.size
    U = (a["neck"][1] - a["head"][1]) * H
    cx = a["eyes"][0] * W
    top = max(0, a["head"][1] * H - 0.25 * U)
    bot = min(H, a["neck"][1] * H + 0.1 * U)
    half = (bot - top) * 0.62
    im = im.crop((int(max(0, cx - half)), int(top), int(min(W, cx + half)), int(bot)))
    # мягкий овал: края кадра (лапки, хвост, плечи) уходят в прозрачность
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).ellipse((im.width * 0.02, im.height * 0.0, im.width * 0.98, im.height * 1.05), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(im.width * 0.035))
    a = Image.composite(im.getchannel("A"), Image.new("L", im.size, 0), m)
    im.putalpha(a)
    return im


def main():
    from compose import SKIN_FILE
    # 1. свечения
    for aid, (c1, c2) in GLOW.items():
        p = os.path.join(HERE, PREFIX[aid[:2]], aid + "_glow.png")
        if not os.path.exists(p):
            make_glow(c1, c2).save(p)
    # 2. слои
    files = set()
    for iid, it in FIT["items"].items():
        for L in it["layers"]:
            files.add((PREFIX[iid[:2]], L["file"]))
    for hero, f in sorted(files):
        save_webp(Image.open(os.path.join(HERE, hero, f + ".png")).convert("RGBA"), os.path.join(OUT, hero, f + ".webp"), LAYER_MAX)
    # 3. иконки
    n = 0
    for it in catalog():
        hero, iid, slot = it["hero"], it["id"], it["slot"]
        dst = os.path.join(OUT, hero, "icons", iid + ".webp")
        if slot == "skin":
            sk = SKIN_FILE[iid]
            for g, suf in (("boy", ""), ("girl", "_girl")):
                save_webp(fit_square(skin_head(hero, sk, g), ICON, 0.96), os.path.join(OUT, hero, "icons", iid + suf + ".webp"), ICON)
            n += 1
            continue
        if slot == "aura" or "covers" in it["raw"]:
            im = Image.open(os.path.join(HERE, hero, iid + ".png")).convert("RGBA")
            save_webp(halo(fit_square(im, ICON, 0.9)), dst, ICON)
            n += 1
            continue
        parts = ICON_PARTS.get(iid)
        if parts is None:
            im = Image.open(os.path.join(HERE, hero, FIT["items"][iid]["layers"][0]["file"] + ".png")).convert("RGBA")
            if iid in ICON_FOCUS:
                x0, y0, x1, y1 = ICON_FOCUS[iid]
                im = im.crop((int(x0 * im.width), int(y0 * im.height), int(x1 * im.width), int(y1 * im.height)))
            save_webp(halo(fit_square(im, ICON, 0.88)), dst, ICON)
        else:
            S = 640
            can = Image.new("RGBA", (S, S), (0, 0, 0, 0))
            for f, dx, dy, k in parts:
                im = fit_square(Image.open(os.path.join(HERE, hero, f + ".png")).convert("RGBA"), int(S * k), 1.0)
                can.alpha_composite(im, (int(S / 2 + dx * S - im.width / 2), int(S / 2 + dy * S - im.height / 2)))
            save_webp(halo(fit_square(can, ICON, 0.88)), dst, ICON)
        n += 1
    print("icons", n)


if __name__ == "__main__":
    main()
