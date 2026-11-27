# -*- coding: utf-8 -*-
"""Сборка наряда из картинок (этап 2 перерисовки): герой + поза + список вещей -> одна картинка.

Это образец логики для игры: программист повторяет её в Godot (Sprite2D/TextureRect на каждый слой).

Запуск из командной строки:
    python3 compose.py <герой> <поза> [вещь ...] [--girl] [--skin=<id окраса>] [--out=файл.png] [--marks]
    пример: python3 compose.py owl idle ow_mortarboard ow_halfglasses ow_book --out=/tmp/owl.png

КАК СЧИТАЕТСЯ ПОСАДКА (подробно — fit.json, поле _about):
1. Картинка героя: art_src/heroes/<герой>/<облик>_<окрас>_<поза>.png, точки — art_src/heroes/anchors.json
   (доли ширины/высоты картинки героя).
2. Единица размера U = (neck.y - head.y) * высота картинки героя, в пикселях — «высота головы».
   Она одинаково ведёт себя во всех позах и окрасах, поэтому вещи масштабируются от неё.
3. Слой вещи (fit.json -> items -> <id> -> layers[]):
   file   — имя картинки вещи (art_src/wardrobe/<герой>/<file>.png; в игре assets/wardrobe_art/<герой>/<file>.webp);
   anchor — точка героя: head, eyes, neck, back, ground;
   pivot  — точка крепления на самой картинке вещи (доли её ширины/высоты);
   offset — сдвиг от точки героя, в U (x вправо, y вниз);
   width  — ширина вещи в U (высота — по пропорции картинки);
   rot    — поворот в градусах вокруг pivot, по часовой стрелке (как rotation_degrees в Godot);
   flip   — отразить по горизонтали (pivot тоже отражается);
   z      — "behind" (позади героя) или "front" (поверх); order — порядок среди слоёв (меньше — раньше);
   gender — если указан, слой только для этого облика ("boy"/"girl");
   poses  — поправки для поз: {"happy": {"dx":0.05, "dy":-0.1, "scale":1.1, "rot":-5}} (dx, dy в U, прибавляются
            к offset; scale умножает width; rot прибавляется).
   Кроме того, fit.json -> pose_fix -> <герой> -> <поза> -> <anchor> — такая же поправка для ВСЕХ слоёв на этой
   точке героя в этой позе (например, у котика в прыжке шея ниже). Сначала pose_fix, потом poses слоя.
4. Порядок рисования: слои z="behind" (по order) -> герой -> слои z="front" (по order).
"""
import os, sys, json
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
HEROES_SRC = os.path.join(ROOT, "art_src", "heroes")
FIT = json.load(open(os.path.join(HERE, "fit.json"), encoding="utf-8"))
ANCH = json.load(open(os.path.join(HEROES_SRC, "anchors.json"), encoding="utf-8"))["images"]

# окрас (id вещи из meta.gd) -> часть имени файла героя (art_src/heroes/README.md)
SKIN_FILE = {
    "ow_skin_snowy": "ow_skin_snowy", "ow_skin_starry": "skin_constellation",
    "ax_skin_pearl": "skin_pearl", "ax_skin_abyss": "skin_midnight",
    "pu_skin_corgi": "skin_moon", "pu_skin_dalmatian": "skin_gold", "pu_skin_cotton": "pu_skin_cotton",
    "ki_skin_tabby": "skin_mint", "ki_skin_siamese": "skin_moon",
}

_cache = {}


def _img(path):
    if path not in _cache:
        _cache[path] = Image.open(path).convert("RGBA")
    return _cache[path]


def item_path(hero, file, game=False):
    if game:
        return os.path.join(ROOT, "assets", "wardrobe_art", hero, file + ".webp")
    return os.path.join(HERE, hero, file + ".png")


def hero_key(hero, pose, gender="boy", skin=None):
    return f"{hero}/{gender}_{SKIN_FILE.get(skin, 'base') if skin else 'base'}_{pose}"


def layers_for(hero, items, gender="boy"):
    """Все слои надетых вещей (с учётом облика), уже отсортированные: behind..., front..."""
    out = []
    for iid in items:
        it = FIT["items"].get(iid)
        if not it:
            continue
        for L in it["layers"]:
            if L.get("gender") and L["gender"] != gender:
                continue
            out.append(dict(L, item=iid))
    out.sort(key=lambda L: (0 if L.get("z") == "behind" else 1, L.get("order", 0)))
    return out


def place(L, anchors, W, H, pose, hero=""):
    """Где и каким размером рисовать слой: (центр-pivot в px героя, ширина px, поворот, flip)."""
    U = (anchors["neck"][1] - anchors["head"][1]) * H
    ax, ay = anchors[L["anchor"]]
    ox, oy = L.get("offset", [0, 0])
    w = L["width"]
    rot = L.get("rot", 0.0)
    # общая поправка позы героя для всех вещей на этой точке (fit.json -> pose_fix), потом — поправка слоя
    for p in (FIT.get("pose_fix", {}).get(hero, {}).get(pose, {}).get(L["anchor"], {}), L.get("poses", {}).get(pose, {})):
        ox += p.get("dx", 0.0)
        oy += p.get("dy", 0.0)
        w *= p.get("scale", 1.0)
        rot += p.get("rot", 0.0)
    return (ax * W + ox * U, ay * H + oy * U), w * U, rot, U


def draw_layer(canvas, L, hero, at, width_px, rot, game=False):
    src = _img(item_path(hero, L["file"], game))
    k = width_px / src.width
    im = src.resize((max(1, round(src.width * k)), max(1, round(src.height * k))), Image.LANCZOS)
    px, py = L.get("pivot", [0.5, 0.5])
    if L.get("flip"):
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
        px = 1.0 - px
    if L.get("alpha", 1.0) < 1.0:
        a = im.getchannel("A").point(lambda v: int(v * L["alpha"]))
        im.putalpha(a)
    pvx, pvy = px * im.width, py * im.height
    # квадрат с pivot в центре -> поворот вокруг центра
    r = int(max(((x - pvx) ** 2 + (y - pvy) ** 2) ** 0.5 for x in (0, im.width) for y in (0, im.height))) + 2
    sq = Image.new("RGBA", (2 * r, 2 * r), (0, 0, 0, 0))
    sq.alpha_composite(im, (int(round(r - pvx)), int(round(r - pvy))))
    if rot:
        sq = sq.rotate(-rot, resample=Image.BICUBIC)
    canvas.alpha_composite(sq, (int(round(at[0] - r)), int(round(at[1] - r))))


def compose(hero, pose="idle", items=(), gender="boy", skin=None, marks=False, margin=0.55, game=False):
    """Вернёт картинку RGBA: герой в наряде, поля вокруг — прозрачные (обрезаны по содержимому)."""
    key = hero_key(hero, pose, gender, skin)
    himg = _img(os.path.join(HEROES_SRC, key + ".png"))
    W, H = himg.size
    anchors = ANCH[key]
    mx, my = int(W * margin), int(H * margin)
    canvas = Image.new("RGBA", (W + 2 * mx, H + 2 * my), (0, 0, 0, 0))
    Ls = layers_for(hero, items, gender)
    for L in [L for L in Ls if L.get("z") == "behind"]:
        (x, y), wp, rot, U = place(L, anchors, W, H, pose, hero)
        draw_layer(canvas, L, hero, (x + mx, y + my), wp, rot, game)
    canvas.alpha_composite(himg, (mx, my))
    for L in [L for L in Ls if L.get("z") != "behind"]:
        (x, y), wp, rot, U = place(L, anchors, W, H, pose, hero)
        draw_layer(canvas, L, hero, (x + mx, y + my), wp, rot, game)
    if marks:
        d = ImageDraw.Draw(canvas)
        for n, c in (("head", "red"), ("eyes", "cyan"), ("neck", "yellow"), ("back", "lime"), ("ground", "magenta")):
            x, y = anchors[n][0] * W + mx, anchors[n][1] * H + my
            d.ellipse((x - 6, y - 6, x + 6, y + 6), outline=c, width=3)
    bb = canvas.getbbox()
    return canvas.crop(bb) if bb else canvas


if __name__ == "__main__":
    a = sys.argv[1:]
    opts = {x.split("=")[0]: (x.split("=", 1)[1] if "=" in x else True) for x in a if x.startswith("--")}
    pos = [x for x in a if not x.startswith("--")]
    hero, pose, items = pos[0], pos[1], pos[2:]
    skin = opts.get("--skin")
    im = compose(hero, pose, items, "girl" if opts.get("--girl") else "boy", skin, bool(opts.get("--marks")))
    out = opts.get("--out", f"/tmp/{hero}_{pose}.png")
    im.save(out)
    print(out, im.size)
