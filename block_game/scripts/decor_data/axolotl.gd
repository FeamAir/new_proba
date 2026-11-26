extends RefCounted
## Каталог дома аксолотля (подводный грот) — Cascado 0.15. Формат — scripts/decor_catalog.gd.
## 3D-места и вещи — scripts/home3d/room_axolotl.gd; названия — scripts/i18n.gd, блок «0.15», раздел «axolotl».
## Задумка — docs/decor_catalog_0_15.md.

## Места: id (у старых шести — прежние id), kind — тип места (decor_catalog.gd KINDS).
## p2d — точка и масштаб в запасном 2D-доме (scripts/home.gd); у старых шести — там же, в home.gd SPOTS.
const SPOTS := [
	{"id": "floor_l", "kind": "floor"},
	{"id": "floor_r", "kind": "floor"},
	{"id": "wall_l", "kind": "wall"},
	{"id": "wall_r", "kind": "wall"},
	{"id": "hang", "kind": "hang"},
	{"id": "near", "kind": "near"},
	# 0.15: заготовки
	{"id": "ledge_l", "kind": "shelf", "p2d": [Vector2(250, 470), 0.7]},
	{"id": "big_back", "kind": "big", "p2d": [Vector2(470, 700), 0.6]},
	{"id": "near_2", "kind": "near", "p2d": [Vector2(200, 840), 0.7]},
]

const STYLES := [
	{"id": "axo_coral", "col": Color("#FF8FB0")},
	{"id": "axo_ship", "col": Color("#FFD36B")},
	{"id": "axo_glow", "col": Color("#9F8CFF")},
]

const DECOR := [
	{"id": "axo_starfish", "home": "axolotl", "style": "axo_coral", "price": 10, "spots": ["wall", "shelf"], "flat": true},
	{"id": "axo_coral", "home": "axolotl", "style": "axo_coral", "price": 15, "spots": ["wall", "floor"]},
	{"id": "axo_shell", "home": "axolotl", "style": "axo_coral", "price": 25, "spots": ["floor", "near", "shelf"]},
	{"id": "axo_lily", "home": "axolotl", "style": "axo_coral", "price": 25, "spots": ["hang"]},
	{"id": "axo_tree", "home": "axolotl", "style": "axo_coral", "price": 35, "spots": ["floor"]},
	{"id": "axo_sofa", "home": "axolotl", "style": "axo_coral", "price": 40, "spots": ["near"]},
	{"id": "axo_castle", "home": "axolotl", "style": "axo_coral", "price": 50, "spots": ["floor", "big"], "hall": 2},
	{"id": "axo_anchor", "home": "axolotl", "style": "axo_ship", "price": 20, "spots": ["floor", "wall"]},
	{"id": "axo_chest", "home": "axolotl", "style": "axo_ship", "price": 60, "spots": ["floor", "near"], "stars": 40},
	{"id": "axo_bubble", "home": "axolotl", "style": "axo_glow", "price": 30, "spots": ["hang", "near"]},
]

const WALLS := [
	{"id": "axo_walls_stone", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "axo_walls_pearl", "price": 40, "tint": Color(1.3, 1.15, 1.25)},
	{"id": "axo_walls_planks", "price": 50, "tint": Color(1.35, 1.0, 0.65)},
	{"id": "axo_walls_veins", "price": 60, "tint": Color(0.8, 0.75, 1.4), "stars": 30},
]
const FLOORS := [
	{"id": "axo_floor_sand", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "axo_floor_pink", "price": 30, "tint": Color(1.3, 0.85, 0.95)},
	{"id": "axo_floor_coins", "price": 50, "tint": Color(1.3, 1.15, 0.6)},
	{"id": "axo_floor_dark", "price": 45, "tint": Color(0.45, 0.45, 0.65), "hall": 1},
]
const LIGHTS := [
	{"id": "axo_light_sun", "price": 0, "ambient": Color(1, 1, 1), "energy": 1.0, "lamp": Color(1, 1, 1)},
	{"id": "axo_light_sunset", "price": 30, "ambient": Color(1.45, 0.95, 0.75), "energy": 1.05, "lamp": Color(1.4, 0.9, 0.6)},
	{"id": "axo_light_party", "price": 50, "ambient": Color(1.2, 0.85, 1.35), "energy": 1.1, "lamp": Color(1.3, 0.8, 1.4)},
	{"id": "axo_light_abyss", "price": 60, "ambient": Color(0.6, 0.6, 1.2), "energy": 0.7, "lamp": Color(0.7, 0.8, 1.5)},
]
