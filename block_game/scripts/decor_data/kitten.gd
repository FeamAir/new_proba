extends RefCounted
## Каталог дома котика (чердак) — Cascado 0.15. Формат — scripts/decor_catalog.gd.
## 3D-места и вещи — scripts/home3d/room_kitten.gd; названия — scripts/i18n.gd, блок «0.15», раздел «kitten».

const SPOTS := [
	{"id": "floor_l", "kind": "floor"},
	{"id": "floor_r", "kind": "floor"},
	{"id": "wall_l", "kind": "wall"},
	{"id": "wall_r", "kind": "wall"},
	{"id": "hang", "kind": "hang"},
	{"id": "near", "kind": "near"},
	# 0.15: заготовки
	{"id": "shelf_1", "kind": "shelf", "p2d": [Vector2(250, 540), 0.7]},
	{"id": "floor_b", "kind": "floor", "p2d": [Vector2(240, 820), 0.72]},
	{"id": "near_2", "kind": "near", "p2d": [Vector2(190, 880), 0.66]},
]

const STYLES := [
	{"id": "kit_play", "col": Color("#FF9AC8")},
	{"id": "kit_cozy", "col": Color("#FFC27A")},
	{"id": "kit_dream", "col": Color("#9FD8FF")},
]

const DECOR := [
	{"id": "kit_yarn", "home": "kitten", "style": "kit_play", "price": 10, "spots": ["floor", "near"]},
	{"id": "kit_mouse", "home": "kitten", "style": "kit_play", "price": 15, "spots": ["near"]},
	{"id": "kit_pillow", "home": "kitten", "style": "kit_cozy", "price": 20, "spots": ["near"]},
	{"id": "kit_picture", "home": "kitten", "style": "kit_dream", "price": 20, "spots": ["wall"], "flat": true},
	{"id": "kit_catnip", "home": "kitten", "style": "kit_dream", "price": 25, "spots": ["hang", "wall", "floor", "shelf", "window"]},
	{"id": "kit_box", "home": "kitten", "style": "kit_play", "price": 30, "spots": ["floor", "near"]},
	{"id": "kit_scratcher", "home": "kitten", "style": "kit_play", "price": 35, "spots": ["floor"]},
	{"id": "kit_lamp", "home": "kitten", "style": "kit_cozy", "price": 40, "spots": ["floor"]},
	{"id": "kit_aquarium", "home": "kitten", "style": "kit_dream", "price": 50, "spots": ["hang", "wall", "near", "shelf", "window"], "stars": 30},
	{"id": "kit_tree", "home": "kitten", "style": "kit_cozy", "price": 60, "spots": ["floor"], "hall": 2},
]

const WALLS := [
	{"id": "kit_walls_plank", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "kit_walls_rose", "price": 25, "tint": Color("#FFC4D4")},
	{"id": "kit_walls_mint", "price": 35, "tint": Color("#C2F0D8")},
	{"id": "kit_walls_lilac", "price": 45, "tint": Color("#D4C2FF"), "stars": 20},
]
const FLOORS := [
	{"id": "kit_floor_boards", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "kit_floor_honey", "price": 20, "tint": Color("#FFD9A0")},
	{"id": "kit_floor_ash", "price": 30, "tint": Color("#D8D8E8")},
	{"id": "kit_floor_cherry", "price": 40, "tint": Color("#E8A8A0"), "hall": 1},
]
const LIGHTS := [
	{"id": "kit_light_lamp", "price": 0, "ambient": Color(1, 1, 1), "energy": 1.0, "lamp": Color(1, 1, 1)},
	{"id": "kit_light_moon", "price": 25, "ambient": Color("#B8C8FF"), "energy": 1.1, "lamp": Color("#C8D8FF")},
	{"id": "kit_light_pink", "price": 35, "ambient": Color("#FFC8E8"), "energy": 1.05, "lamp": Color("#FFB0D8")},
	{"id": "kit_light_sun", "price": 45, "ambient": Color("#FFF0C0"), "energy": 1.25, "lamp": Color("#FFE8B0")},
]
