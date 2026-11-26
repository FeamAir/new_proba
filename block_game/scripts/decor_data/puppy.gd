extends RefCounted
## Каталог дома щенка (будка в ночном саду) — Cascado 0.15. Формат — scripts/decor_catalog.gd.
## 3D-места и вещи — scripts/home3d/room_puppy.gd; названия — scripts/i18n.gd, блок «0.15», раздел «puppy».
## «Стены» у щенка — забор и будка, «пол» — земля и трава. Задумка — docs/decor_catalog_0_15.md.

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
	{"id": "tree", "kind": "hang", "p2d": [Vector2(250, 470), 0.85]},
	{"id": "near_2", "kind": "near", "p2d": [Vector2(196, 880), 0.68]},
]

const STYLES := [
	{"id": "pup_picnic", "col": Color("#8EDB6A")},
	{"id": "pup_camp", "col": Color("#FF9A4C")},
	{"id": "pup_skate", "col": Color("#6CC8FF")},
]

const DECOR := [
	{"id": "pup_bowl", "home": "puppy", "style": "pup_picnic", "price": 20, "spots": ["near", "floor"]},
	{"id": "pup_sign", "home": "puppy", "style": "pup_picnic", "price": 20, "spots": ["wall"], "flat": true},
	{"id": "pup_flowerbed", "home": "puppy", "style": "pup_picnic", "price": 25, "spots": ["floor"]},
	{"id": "pup_pinwheel", "home": "puppy", "style": "pup_picnic", "price": 30, "spots": ["wall", "floor"], "flat": true},
	{"id": "pup_bed", "home": "puppy", "style": "pup_picnic", "price": 45, "spots": ["near"]},
	{"id": "pup_teddy", "home": "puppy", "style": "pup_picnic", "price": 60, "spots": ["near", "floor"], "hall": 1},
	{"id": "pup_bone", "home": "puppy", "style": "pup_camp", "price": 15, "spots": ["near"]},
	{"id": "pup_lamp", "home": "puppy", "style": "pup_camp", "price": 35, "spots": ["hang", "wall", "floor"]},
	{"id": "pup_kite", "home": "puppy", "style": "pup_camp", "price": 50, "spots": ["hang"], "stars": 25},
	{"id": "pup_ball", "home": "puppy", "style": "pup_skate", "price": 10, "spots": ["floor", "near"]},
]

const WALLS := [
	{"id": "pup_walls_picket", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "pup_walls_logs", "price": 40, "tint": Color(1.1, 0.8, 0.6)},
	{"id": "pup_walls_ivy", "price": 35, "tint": Color(0.8, 1.15, 0.8)},
	{"id": "pup_walls_paint", "price": 50, "tint": Color(1.3, 0.85, 1.25), "stars": 30},
]
const FLOORS := [
	{"id": "pup_floor_lawn", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "pup_floor_meadow", "price": 35, "tint": Color(1.2, 1.25, 0.8)},
	{"id": "pup_floor_pine", "price": 40, "tint": Color(0.95, 0.8, 0.55)},
	{"id": "pup_floor_court", "price": 50, "tint": Color(0.85, 0.85, 1.1), "hall": 1},
]
const LIGHTS := [
	{"id": "pup_light_stars", "price": 0, "ambient": Color(1, 1, 1), "energy": 1.0, "lamp": Color(1, 1, 1)},
	{"id": "pup_light_sunset", "price": 40, "ambient": Color(1.5, 1.0, 0.7), "energy": 1.15, "lamp": Color(1.4, 0.9, 0.55)},
	{"id": "pup_light_party", "price": 50, "ambient": Color(1.2, 0.9, 1.3), "energy": 1.1, "lamp": Color(1.4, 0.85, 1.3)},
	{"id": "pup_light_neon", "price": 60, "ambient": Color(0.75, 0.9, 1.5), "energy": 1.05, "lamp": Color(0.6, 1.2, 1.5)},
]
