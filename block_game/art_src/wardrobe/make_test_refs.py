# -*- coding: utf-8 -*-
"""Эталоны посадки для теста tests/test_v018_art.gd: сборка compose.py из ИГРОВЫХ картинок
(assets/heroes_art высотой 512 и assets/wardrobe_art), как их видит Godot.

    python3 art_src/wardrobe/make_test_refs.py   (из папки block_game)

Наряды — те же, что в CASES теста (tests/test_v018_art.gd); пишет tests/data/fit_ref_<n>.png.
"""
import os
import compose

ROOT = compose.ROOT
OUT = os.path.join(ROOT, "tests", "data")
# герой — из игровых картинок (webp, высота 512), а не из исходников art_src
compose.HEROES_SRC = os.path.join(ROOT, "assets", "heroes_art")
_orig = compose._img


def _img(path):
    if path.startswith(compose.HEROES_SRC) and path.endswith(".png"):
        path = path[:-4] + ".webp"
    return _orig(path)


compose._img = _img

# герой, поза, облик, окрас, вещи — повторено в tests/test_v018_art.gd (CASES)
CASES = [
    ("kitten", "happy", "boy", None, ["ki_feather_hat", "ki_bell_bow", "ki_yarn", "ki_trench"]),
    ("axolotl", "idle", "girl", "ax_skin_pearl", ["ax_starfish", "ax_porthole", "ax_gill_pearls", "ax_shell_pack"]),
    ("owl", "wow", "boy", "ow_skin_snowy", ["ow_halfglasses", "ow_book", "ow_stargazer"]),
    ("puppy", "sad", "girl", None, ["pu_daisy_specs", "pu_flower_scarf", "pu_jetpack", "pu_robo"]),
]

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for i, (hero, pose, gender, skin, items) in enumerate(CASES):
        im = compose.compose(hero, pose, items, gender, skin, game=True)
        p = os.path.join(OUT, "fit_ref_%d.png" % i)
        im.save(p)
        print(p, im.size)
