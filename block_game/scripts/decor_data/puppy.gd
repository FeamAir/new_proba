extends RefCounted
## Каталог дома щенка (будка в ночном саду) — Cascado 0.15. Формат — scripts/decor_catalog.gd.
## 3D-места и вещи — scripts/home3d/room_puppy.gd; названия — scripts/i18n.gd, блок «0.15», раздел «puppy».
## «Стены» у щенка — забор и будка, «пол» — трава.

const SPOTS := [
	{"id": "floor_l", "kind": "floor"},
	{"id": "floor_r", "kind": "floor"},
	{"id": "wall_l", "kind": "wall"},
	{"id": "wall_r", "kind": "wall"},
	{"id": "hang", "kind": "hang"},
	{"id": "near", "kind": "near"},
	# 0.15: заготовки
	{"id": "floor_b", "kind": "floor", "p2d": [Vector2(250, 780), 0.7]},
	{"id": "near_2", "kind": "near", "p2d": [Vector2(196, 880), 0.68]},
	{"id": "hang_2", "kind": "hang", "p2d": [Vector2(250, 470), 0.85]},
]

const STYLES := [
	{"id": "pup_garden", "col": Color("#8EDB6A")},
	{"id": "pup_play", "col": Color("#FF8A5C")},
	{"id": "pup_cozy", "col": Color("#FFD27A")},
]

const DECOR := [
	{"id": "pup_ball", "home": "puppy", "style": "pup_play", "price": 10, "spots": ["floor", "near"]},
	{"id": "pup_bone", "home": "puppy", "style": "pup_play", "price": 15, "spots": ["near"]},
	{"id": "pup_bowl", "home": "puppy", "style": "pup_cozy", "price": 20, "spots": ["near", "floor"]},
	{"id": "pup_sign", "home": "puppy", "style": "pup_garden", "price": 20, "spots": ["wall"], "flat": true},
	{"id": "pup_flowerbed", "home": "puppy", "style": "pup_garden", "price": 25, "spots": ["floor"]},
	{"id": "pup_pinwheel", "home": "puppy", "style": "pup_garden", "price": 30, "spots": ["wall", "floor"], "flat": true},
	{"id": "pup_lamp", "home": "puppy", "style": "pup_garden", "price": 35, "spots": ["hang", "wall", "floor", "shelf", "window"]},
	{"id": "pup_bed", "home": "puppy", "style": "pup_cozy", "price": 45, "spots": ["near"]},
	{"id": "pup_kite", "home": "puppy", "style": "pup_play", "price": 50, "spots": ["hang"], "stars": 25},
	{"id": "pup_teddy", "home": "puppy", "style": "pup_cozy", "price": 60, "spots": ["near", "floor"], "hall": 1},
]

const WALLS := [
	{"id": "pup_walls_wood", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "pup_walls_sky", "price": 25, "tint": Color("#B8D8FF")},
	{"id": "pup_walls_berry", "price": 35, "tint": Color("#FFB8C8")},
	{"id": "pup_walls_mint", "price": 45, "tint": Color("#BFF2D2"), "stars": 20},
]
const FLOORS := [
	{"id": "pup_floor_grass", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "pup_floor_spring", "price": 20, "tint": Color("#D6FF9E")},
	{"id": "pup_floor_autumn", "price": 30, "tint": Color("#FFC98A")},
	{"id": "pup_floor_snow", "price": 40, "tint": Color("#E8F2FF"), "hall": 1},
]
const LIGHTS := [
	{"id": "pup_light_night", "price": 0, "ambient": Color(1, 1, 1), "energy": 1.0, "lamp": Color(1, 1, 1)},
	{"id": "pup_light_sunset", "price": 25, "ambient": Color("#FFC4A0"), "energy": 1.12, "lamp": Color("#FFB27A")},
	{"id": "pup_light_fairy", "price": 35, "ambient": Color("#E6C8FF"), "energy": 1.05, "lamp": Color("#FFB8F0")},
	{"id": "pup_light_dawn", "price": 45, "ambient": Color("#FFF2C8"), "energy": 1.25, "lamp": Color("#FFF0C0")},
]
