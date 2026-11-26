extends RefCounted
## Каталог дома котика (чердак) — Cascado 0.15. Формат — scripts/decor_catalog.gd.
## 3D-места и вещи — scripts/home3d/room_kitten.gd; названия — scripts/i18n.gd, блок «0.15», раздел «kitten».
## Старое место hang у котика — верхняя полка: id прежний, тип shelf. Задумка — docs/decor_catalog_0_15.md.

## Места: id (у старых шести — прежние id), kind — тип места (decor_catalog.gd KINDS).
## p2d — точка и масштаб в запасном 2D-доме (scripts/home.gd); у старых шести — там же, в home.gd SPOTS.
const SPOTS := [
	{"id": "floor_l", "kind": "floor"},
	{"id": "floor_r", "kind": "floor"},
	{"id": "wall_l", "kind": "wall"},
	{"id": "wall_r", "kind": "wall"},
	{"id": "hang", "kind": "shelf"},
	{"id": "near", "kind": "near"},
	# 0.15: заготовки
	{"id": "window", "kind": "window", "p2d": [Vector2(340, 470), 0.6]},
	{"id": "shelf_low", "kind": "shelf", "p2d": [Vector2(250, 540), 0.7]},
	{"id": "near_2", "kind": "near", "p2d": [Vector2(190, 880), 0.66]},
]

const STYLES := [
	{"id": "kit_cozy", "col": Color("#FFC27A")},
	{"id": "kit_rock", "col": Color("#FF6B9A")},
	{"id": "kit_studio", "col": Color("#9FD8FF")},
]

const DECOR := [
	{"id": "kit_yarn", "home": "kitten", "style": "kit_cozy", "price": 10, "spots": ["floor", "near"]},
	{"id": "kit_mouse", "home": "kitten", "style": "kit_cozy", "price": 15, "spots": ["near"]},
	{"id": "kit_pillow", "home": "kitten", "style": "kit_cozy", "price": 20, "spots": ["near"]},
	{"id": "kit_box", "home": "kitten", "style": "kit_cozy", "price": 30, "spots": ["floor", "near"]},
	{"id": "kit_scratcher", "home": "kitten", "style": "kit_cozy", "price": 35, "spots": ["floor"]},
	{"id": "kit_lamp", "home": "kitten", "style": "kit_cozy", "price": 40, "spots": ["floor"]},
	{"id": "kit_tree", "home": "kitten", "style": "kit_cozy", "price": 60, "spots": ["floor", "big"], "hall": 2},
	{"id": "kit_picture", "home": "kitten", "style": "kit_studio", "price": 20, "spots": ["wall"], "flat": true},
	{"id": "kit_catnip", "home": "kitten", "style": "kit_studio", "price": 25, "spots": ["shelf", "wall", "floor", "window"]},
	{"id": "kit_aquarium", "home": "kitten", "style": "kit_studio", "price": 50, "spots": ["shelf", "wall", "near", "window"], "stars": 30},
]

const WALLS := [
	{"id": "kit_walls_beams", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "kit_walls_floral", "price": 30, "tint": Color(1.3, 0.95, 1.05)},
	{"id": "kit_walls_brick", "price": 50, "tint": Color(1.35, 0.8, 0.65)},
	{"id": "kit_walls_night", "price": 50, "tint": Color(0.6, 0.65, 1.3), "stars": 30},
]
const FLOORS := [
	{"id": "kit_floor_planks", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "kit_floor_knit", "price": 25, "tint": Color(1.35, 1.0, 1.1)},
	{"id": "kit_floor_checker", "price": 45, "tint": Color(1.2, 1.2, 1.25)},
	{"id": "kit_floor_paint", "price": 40, "tint": Color(1.0, 1.15, 1.35), "hall": 1},
]
const LIGHTS := [
	{"id": "kit_light_lamp", "price": 0, "ambient": Color(1, 1, 1), "energy": 1.0, "lamp": Color(1, 1, 1)},
	{"id": "kit_light_moon", "price": 30, "ambient": Color(0.75, 0.9, 1.45), "energy": 1.05, "lamp": Color(0.8, 0.95, 1.35)},
	{"id": "kit_light_fairy", "price": 50, "ambient": Color(1.25, 0.95, 1.2), "energy": 1.12, "lamp": Color(1.4, 1.0, 1.2)},
	{"id": "kit_light_neon", "price": 60, "ambient": Color(1.1, 0.7, 1.45), "energy": 1.0, "lamp": Color(1.3, 0.6, 1.5)},
]
