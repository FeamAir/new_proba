extends RefCounted
## Каталог дома аксолотля (подводный грот) — Cascado 0.15. Формат — scripts/decor_catalog.gd.
## 3D-места и вещи — scripts/home3d/room_axolotl.gd; названия — scripts/i18n.gd, блок «0.15», раздел «axolotl».

const SPOTS := [
	{"id": "floor_l", "kind": "floor"},
	{"id": "floor_r", "kind": "floor"},
	{"id": "wall_l", "kind": "wall"},
	{"id": "wall_r", "kind": "wall"},
	{"id": "hang", "kind": "hang"},
	{"id": "near", "kind": "near"},
	# 0.15: заготовки
	{"id": "shelf_1", "kind": "shelf", "p2d": [Vector2(250, 470), 0.7]},
	{"id": "floor_b", "kind": "floor", "p2d": [Vector2(470, 700), 0.7]},
	{"id": "near_2", "kind": "near", "p2d": [Vector2(200, 840), 0.7]},
]

const STYLES := [
	{"id": "axo_reef", "col": Color("#FF8FB0")},
	{"id": "axo_treasure", "col": Color("#FFD36B")},
	{"id": "axo_cozy", "col": Color("#9FE8FF")},
]

const DECOR := [
	{"id": "axo_starfish", "home": "axolotl", "style": "axo_reef", "price": 10, "spots": ["wall"], "flat": true},
	{"id": "axo_coral", "home": "axolotl", "style": "axo_reef", "price": 15, "spots": ["wall", "floor", "shelf"]},
	{"id": "axo_anchor", "home": "axolotl", "style": "axo_treasure", "price": 20, "spots": ["floor", "wall", "shelf"]},
	{"id": "axo_shell", "home": "axolotl", "style": "axo_treasure", "price": 25, "spots": ["floor", "near", "shelf"]},
	{"id": "axo_lily", "home": "axolotl", "style": "axo_cozy", "price": 25, "spots": ["hang"]},
	{"id": "axo_bubble", "home": "axolotl", "style": "axo_cozy", "price": 30, "spots": ["hang", "near"]},
	{"id": "axo_tree", "home": "axolotl", "style": "axo_reef", "price": 35, "spots": ["floor"]},
	{"id": "axo_sofa", "home": "axolotl", "style": "axo_cozy", "price": 40, "spots": ["near"]},
	{"id": "axo_castle", "home": "axolotl", "style": "axo_treasure", "price": 50, "spots": ["floor"], "hall": 2},
	{"id": "axo_chest", "home": "axolotl", "style": "axo_treasure", "price": 60, "spots": ["floor", "near"], "stars": 40},
]

const WALLS := [
	{"id": "axo_walls_stone", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "axo_walls_coral", "price": 25, "tint": Color("#FFC0CC")},
	{"id": "axo_walls_deep", "price": 35, "tint": Color("#9CC4FF")},
	{"id": "axo_walls_pearl", "price": 45, "tint": Color("#FFF0D8"), "stars": 20},
]
const FLOORS := [
	{"id": "axo_floor_sand", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "axo_floor_pink", "price": 20, "tint": Color("#FFC6D8")},
	{"id": "axo_floor_moss", "price": 30, "tint": Color("#B4EAB0")},
	{"id": "axo_floor_night", "price": 40, "tint": Color("#9FA8E8"), "hall": 1},
]
const LIGHTS := [
	{"id": "axo_light_lagoon", "price": 0, "ambient": Color(1, 1, 1), "energy": 1.0, "lamp": Color(1, 1, 1)},
	{"id": "axo_light_sunny", "price": 25, "ambient": Color("#FFF0C0"), "energy": 1.15, "lamp": Color("#FFE6A8")},
	{"id": "axo_light_glow", "price": 35, "ambient": Color("#C8FFE8"), "energy": 1.0, "lamp": Color("#9CFFD8")},
	{"id": "axo_light_abyss", "price": 45, "ambient": Color("#A6A0FF"), "energy": 0.85, "lamp": Color("#C0A8FF")},
]
