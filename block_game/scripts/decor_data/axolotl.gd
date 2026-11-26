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
	# 0.15: новые места (дизайнер): просвет в своде, большие места у задней стены, уступы, сталактит
	{"id": "window", "kind": "window", "p2d": [Vector2(360, 186), 0.6]},
	{"id": "big_back", "kind": "big", "p2d": [Vector2(250, 760), 0.62]},
	{"id": "big_corner", "kind": "big", "p2d": [Vector2(500, 740), 0.6]},
	{"id": "wall_back", "kind": "wall", "p2d": [Vector2(470, 330), 0.6]},
	{"id": "ledge_l", "kind": "shelf", "p2d": [Vector2(250, 470), 0.7]},
	{"id": "ledge_r", "kind": "shelf", "p2d": [Vector2(520, 560), 0.7]},
	{"id": "hang_2", "kind": "hang", "p2d": [Vector2(170, 236), 0.9]},
	{"id": "floor_front", "kind": "floor", "p2d": [Vector2(360, 960), 0.8]},
	{"id": "near_2", "kind": "near", "p2d": [Vector2(200, 840), 0.7]},
]

const STYLES := [
	{"id": "axo_coral", "col": Color("#FF8FB0")},
	{"id": "axo_ship", "col": Color("#FFD36B")},
	{"id": "axo_glow", "col": Color("#9F8CFF")},
]

const DECOR := [
	# А. «Коралловый сад» — розово-бирюзовый
	{"id": "axo_starfish", "home": "axolotl", "style": "axo_coral", "price": 10, "spots": ["wall", "shelf"], "flat": true},
	{"id": "axo_coral", "home": "axolotl", "style": "axo_coral", "price": 15, "spots": ["wall", "floor"]},
	{"id": "axo_shell", "home": "axolotl", "style": "axo_coral", "price": 25, "spots": ["floor", "near", "shelf"]},
	{"id": "axo_lily", "home": "axolotl", "style": "axo_coral", "price": 25, "spots": ["hang"]},
	{"id": "axo_tree", "home": "axolotl", "style": "axo_coral", "price": 35, "spots": ["floor"]},
	{"id": "axo_kelp", "home": "axolotl", "style": "axo_coral", "price": 35, "spots": ["wall", "window"], "flat": true},
	{"id": "axo_sofa", "home": "axolotl", "style": "axo_coral", "price": 40, "spots": ["near"]},
	{"id": "axo_seahorse", "home": "axolotl", "style": "axo_coral", "price": 45, "spots": ["hang", "wall"], "flat": true, "hang_h": 0.5},
	{"id": "axo_castle", "home": "axolotl", "style": "axo_coral", "price": 50, "spots": ["floor", "big"], "hall": 2},
	{"id": "axo_arch", "home": "axolotl", "style": "axo_coral", "price": 200, "spots": ["big"]},
	# Б. «Затонувший корабль» — дерево и золото (на флаге — ракушка)
	{"id": "axo_anchor", "home": "axolotl", "style": "axo_ship", "price": 20, "spots": ["floor", "wall"]},
	{"id": "axo_bottle", "home": "axolotl", "style": "axo_ship", "price": 20, "spots": ["floor", "shelf", "near"]},
	{"id": "axo_map", "home": "axolotl", "style": "axo_ship", "price": 30, "spots": ["wall"], "flat": true},
	{"id": "axo_spyglass", "home": "axolotl", "style": "axo_ship", "price": 30, "spots": ["shelf", "near"]},
	{"id": "axo_lantern", "home": "axolotl", "style": "axo_ship", "price": 35, "spots": ["hang", "wall"], "flat": true, "hang_h": 0.5},
	{"id": "axo_barrel", "home": "axolotl", "style": "axo_ship", "price": 40, "spots": ["floor", "near"]},
	{"id": "axo_flag", "home": "axolotl", "style": "axo_ship", "price": 40, "spots": ["wall", "window"], "flat": true},
	{"id": "axo_wheel", "home": "axolotl", "style": "axo_ship", "price": 45, "spots": ["wall"], "flat": true},
	{"id": "axo_chest", "home": "axolotl", "style": "axo_ship", "price": 60, "spots": ["floor", "near"], "stars": 40},
	{"id": "axo_ship", "home": "axolotl", "style": "axo_ship", "price": 220, "spots": ["big"]},
	# В. «Сияние бездны» — тёмный неон
	{"id": "axo_plankton", "home": "axolotl", "style": "axo_glow", "price": 25, "spots": ["hang", "wall"], "flat": true, "self_hung": true},
	{"id": "axo_bubble", "home": "axolotl", "style": "axo_glow", "price": 30, "spots": ["hang", "near"]},
	{"id": "axo_anemones", "home": "axolotl", "style": "axo_glow", "price": 30, "spots": ["floor", "shelf"]},
	{"id": "axo_vent", "home": "axolotl", "style": "axo_glow", "price": 40, "spots": ["floor"]},
	{"id": "axo_neonsquid", "home": "axolotl", "style": "axo_glow", "price": 40, "spots": ["wall", "window"], "flat": true},
	{"id": "axo_crystal", "home": "axolotl", "style": "axo_glow", "price": 45, "spots": ["floor", "shelf"]},
	{"id": "axo_angler", "home": "axolotl", "style": "axo_glow", "price": 50, "spots": ["floor", "near"]},
	{"id": "axo_pod", "home": "axolotl", "style": "axo_glow", "price": 55, "spots": ["near"]},
	{"id": "axo_jelly", "home": "axolotl", "style": "axo_glow", "price": 60, "spots": ["hang"], "self_hung": true},
	{"id": "axo_sub", "home": "axolotl", "style": "axo_glow", "price": 230, "spots": ["big"]},
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
