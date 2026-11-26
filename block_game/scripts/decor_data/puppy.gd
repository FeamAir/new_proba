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
	# 0.15: новые места (координаты — room_puppy.gd _init): трава впереди, два больших места слева у забора,
	# второе место на заборе, стенка и крыша будки, полочка на заборе, ветка у ствола, второе «рядом»
	{"id": "floor_front", "kind": "floor", "p2d": [Vector2(430, 960), 0.9]},
	{"id": "big_back", "kind": "big", "p2d": [Vector2(196, 640), 0.8]},
	{"id": "big_side", "kind": "big", "p2d": [Vector2(110, 760), 0.85]},
	{"id": "wall_2", "kind": "wall", "p2d": [Vector2(214, 560), 0.6]},
	{"id": "house_wall", "kind": "wall", "p2d": [Vector2(470, 640), 0.6]},
	{"id": "roof", "kind": "shelf", "p2d": [Vector2(340, 470), 0.6]},
	{"id": "fence_top", "kind": "shelf", "p2d": [Vector2(64, 600), 0.6]},
	{"id": "tree", "kind": "hang", "p2d": [Vector2(250, 470), 0.85]},
	{"id": "near_2", "kind": "near", "p2d": [Vector2(196, 880), 0.68]},
]

const STYLES := [
	{"id": "pup_picnic", "col": Color("#8EDB6A")},
	{"id": "pup_camp", "col": Color("#FF9A4C")},
	{"id": "pup_skate", "col": Color("#6CC8FF")},
]

## Украшения (docs/decor_catalog_0_15.md, раздел «Щенок»). flat — висит плоско на заборе / стенке будки;
## self_hung — своя верёвка (точка места — точка подвеса). 3D — room_puppy.gd _decor(), значки — puppy_icons.gd.
const DECOR := [
	# «Сад и пикник»
	{"id": "pup_bowl", "home": "puppy", "style": "pup_picnic", "price": 20, "spots": ["near", "floor"]},
	{"id": "pup_sign", "home": "puppy", "style": "pup_picnic", "price": 20, "spots": ["wall"], "flat": true},
	{"id": "pup_flowerbed", "home": "puppy", "style": "pup_picnic", "price": 25, "spots": ["floor"]},
	{"id": "pup_pinwheel", "home": "puppy", "style": "pup_picnic", "price": 30, "spots": ["wall", "floor"], "flat": true},
	{"id": "pup_bed", "home": "puppy", "style": "pup_picnic", "price": 45, "spots": ["near"]},
	{"id": "pup_teddy", "home": "puppy", "style": "pup_picnic", "price": 60, "spots": ["near", "floor", "shelf"], "hall": 1},
	{"id": "pup_sunflowers", "home": "puppy", "style": "pup_picnic", "price": 35, "spots": ["wall", "floor"]},
	{"id": "pup_picnic", "home": "puppy", "style": "pup_picnic", "price": 40, "spots": ["floor", "near"]},
	{"id": "pup_birdbath", "home": "puppy", "style": "pup_picnic", "price": 45, "spots": ["floor"]},
	{"id": "pup_gazebo", "home": "puppy", "style": "pup_picnic", "price": 200, "spots": ["big"]},
	# «Поход»
	{"id": "pup_bone", "home": "puppy", "style": "pup_camp", "price": 15, "spots": ["near"]},
	{"id": "pup_lamp", "home": "puppy", "style": "pup_camp", "price": 35, "spots": ["hang", "wall", "floor"]},
	{"id": "pup_kite", "home": "puppy", "style": "pup_camp", "price": 50, "spots": ["hang"], "stars": 25},
	{"id": "pup_pennants", "home": "puppy", "style": "pup_camp", "price": 25, "spots": ["hang", "wall"], "flat": true, "self_hung": true},
	{"id": "pup_binoculars", "home": "puppy", "style": "pup_camp", "price": 25, "spots": ["near", "shelf"]},
	{"id": "pup_backpack", "home": "puppy", "style": "pup_camp", "price": 30, "spots": ["near", "floor"]},
	{"id": "pup_trailmap", "home": "puppy", "style": "pup_camp", "price": 30, "spots": ["wall"], "flat": true},
	{"id": "pup_canoe", "home": "puppy", "style": "pup_camp", "price": 60, "spots": ["floor", "big"]},
	{"id": "pup_tent", "home": "puppy", "style": "pup_camp", "price": 70, "spots": ["big", "floor"]},
	{"id": "pup_campfire", "home": "puppy", "style": "pup_camp", "price": 180, "spots": ["floor", "big"]},
	# «Скейт-парк» (без букв и логотипов: лапки, косточки, звёзды, молнии)
	{"id": "pup_ball", "home": "puppy", "style": "pup_skate", "price": 10, "spots": ["floor", "near"]},
	{"id": "pup_cones", "home": "puppy", "style": "pup_skate", "price": 15, "spots": ["floor", "shelf"]},
	{"id": "pup_spray", "home": "puppy", "style": "pup_skate", "price": 20, "spots": ["shelf"]},
	{"id": "pup_headphones", "home": "puppy", "style": "pup_skate", "price": 25, "spots": ["near", "shelf"]},
	{"id": "pup_skateboard", "home": "puppy", "style": "pup_skate", "price": 30, "spots": ["near", "floor"]},
	{"id": "pup_hoop", "home": "puppy", "style": "pup_skate", "price": 45, "spots": ["wall"], "flat": true},
	{"id": "pup_graffiti", "home": "puppy", "style": "pup_skate", "price": 50, "spots": ["wall"], "flat": true},
	{"id": "pup_boombox", "home": "puppy", "style": "pup_skate", "price": 55, "spots": ["floor", "near", "shelf"]},
	{"id": "pup_neon", "home": "puppy", "style": "pup_skate", "price": 60, "spots": ["wall", "shelf"], "flat": true},
	{"id": "pup_ramp", "home": "puppy", "style": "pup_skate", "price": 230, "spots": ["big"]},
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
