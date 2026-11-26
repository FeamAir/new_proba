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
	# 0.15: новые места (координаты — room_kitten.gd _init): пол у сундука, два больших места (у задней стены
	# и под скосом), стена слева от окна, круглое окно, низкая полка, две балки, второе «рядом»
	{"id": "floor_front", "kind": "floor", "p2d": [Vector2(600, 980), 0.8]},
	{"id": "big_back", "kind": "big", "p2d": [Vector2(470, 700), 0.8]},
	{"id": "big_corner", "kind": "big", "p2d": [Vector2(640, 800), 0.8]},
	{"id": "wall_back", "kind": "wall", "p2d": [Vector2(220, 470), 0.7]},
	{"id": "window", "kind": "window", "p2d": [Vector2(340, 470), 0.6]},
	{"id": "shelf_low", "kind": "shelf", "p2d": [Vector2(250, 540), 0.7]},
	{"id": "beam", "kind": "hang", "p2d": [Vector2(250, 300), 0.7]},
	{"id": "beam_2", "kind": "hang", "p2d": [Vector2(450, 300), 0.7]},
	{"id": "near_2", "kind": "near", "p2d": [Vector2(190, 880), 0.66]},
]

const STYLES := [
	{"id": "kit_cozy", "col": Color("#FFC27A")},
	{"id": "kit_rock", "col": Color("#FF6B9A")},
	{"id": "kit_studio", "col": Color("#9FD8FF")},
]

## Украшения (docs/decor_catalog_0_15.md, раздел «Котик»). flat — висит плоско на стене;
## self_hung — своя верёвка с балки; hang_h — высота вещи на нитке. 3D — room_kitten.gd _decor(), значки — kitten_icons.gd.
const DECOR := [
	# «Уютный вечер»
	{"id": "kit_yarn", "home": "kitten", "style": "kit_cozy", "price": 10, "spots": ["floor", "near", "shelf"]},
	{"id": "kit_mouse", "home": "kitten", "style": "kit_cozy", "price": 15, "spots": ["near"]},
	{"id": "kit_pillow", "home": "kitten", "style": "kit_cozy", "price": 20, "spots": ["near"]},
	{"id": "kit_box", "home": "kitten", "style": "kit_cozy", "price": 30, "spots": ["floor", "near"]},
	{"id": "kit_scratcher", "home": "kitten", "style": "kit_cozy", "price": 35, "spots": ["floor"]},
	{"id": "kit_lamp", "home": "kitten", "style": "kit_cozy", "price": 40, "spots": ["floor"]},
	{"id": "kit_tree", "home": "kitten", "style": "kit_cozy", "price": 60, "spots": ["floor", "big"], "hall": 2},
	{"id": "kit_tea", "home": "kitten", "style": "kit_cozy", "price": 30, "spots": ["shelf", "window"]},
	{"id": "kit_windowseat", "home": "kitten", "style": "kit_cozy", "price": 50, "spots": ["window"]},
	{"id": "kit_stove", "home": "kitten", "style": "kit_cozy", "price": 200, "spots": ["big"]},
	# «Рок-чердак»
	{"id": "kit_headphones", "home": "kitten", "style": "kit_rock", "price": 20, "spots": ["shelf", "near"]},
	{"id": "kit_poster", "home": "kitten", "style": "kit_rock", "price": 25, "spots": ["wall"], "flat": true},
	{"id": "kit_mic", "home": "kitten", "style": "kit_rock", "price": 35, "spots": ["near", "floor"]},
	{"id": "kit_beanbag", "home": "kitten", "style": "kit_rock", "price": 40, "spots": ["near", "floor"]},
	{"id": "kit_vinyl", "home": "kitten", "style": "kit_rock", "price": 45, "spots": ["shelf", "floor"]},
	{"id": "kit_amp", "home": "kitten", "style": "kit_rock", "price": 50, "spots": ["floor", "near"]},
	{"id": "kit_disco", "home": "kitten", "style": "kit_rock", "price": 50, "spots": ["hang"], "hang_h": 0.42},
	{"id": "kit_neon", "home": "kitten", "style": "kit_rock", "price": 55, "spots": ["wall", "window"], "flat": true},
	{"id": "kit_guitar", "home": "kitten", "style": "kit_rock", "price": 60, "spots": ["wall", "near"], "flat": true},
	{"id": "kit_drums", "home": "kitten", "style": "kit_rock", "price": 220, "spots": ["big"]},
	# «Звёздная мастерская»
	{"id": "kit_picture", "home": "kitten", "style": "kit_studio", "price": 20, "spots": ["wall"], "flat": true},
	{"id": "kit_catnip", "home": "kitten", "style": "kit_studio", "price": 25, "spots": ["shelf", "wall", "floor", "window"]},
	{"id": "kit_aquarium", "home": "kitten", "style": "kit_studio", "price": 50, "spots": ["shelf", "wall", "near", "window"], "stars": 30},
	{"id": "kit_paints", "home": "kitten", "style": "kit_studio", "price": 20, "spots": ["shelf", "near"]},
	{"id": "kit_vase", "home": "kitten", "style": "kit_studio", "price": 25, "spots": ["shelf", "floor"]},
	{"id": "kit_cranes", "home": "kitten", "style": "kit_studio", "price": 30, "spots": ["hang"], "self_hung": true},
	{"id": "kit_plants", "home": "kitten", "style": "kit_studio", "price": 35, "spots": ["window", "shelf"]},
	{"id": "kit_starlamp", "home": "kitten", "style": "kit_studio", "price": 55, "spots": ["floor", "shelf"]},
	{"id": "kit_easel", "home": "kitten", "style": "kit_studio", "price": 60, "spots": ["floor", "near"]},
	{"id": "kit_stainedglass", "home": "kitten", "style": "kit_studio", "price": 180, "spots": ["window"]},
]

## Стиль комнаты: узоры рисует шейдер стен и пола (room_kitten.gd KIT_SHELL), tint — лёгкий оттенок досок и балок
const WALLS := [
	{"id": "kit_walls_beams", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "kit_walls_floral", "price": 30, "tint": Color(1.06, 0.98, 1.0)},
	{"id": "kit_walls_brick", "price": 50, "tint": Color(1.04, 0.95, 0.9)},
	{"id": "kit_walls_night", "price": 50, "tint": Color(0.82, 0.85, 1.12), "stars": 30},
]
const FLOORS := [
	{"id": "kit_floor_planks", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "kit_floor_knit", "price": 25, "tint": Color(1.02, 0.98, 1.0)},
	{"id": "kit_floor_checker", "price": 45, "tint": Color(1.0, 1.0, 1.02)},
	{"id": "kit_floor_paint", "price": 40, "tint": Color(1.03, 1.0, 1.02), "hall": 1},
]
const LIGHTS := [
	{"id": "kit_light_lamp", "price": 0, "ambient": Color(1, 1, 1), "energy": 1.0, "lamp": Color(1, 1, 1)},
	{"id": "kit_light_moon", "price": 30, "ambient": Color(0.75, 0.9, 1.45), "energy": 1.05, "lamp": Color(0.8, 0.95, 1.35)},
	{"id": "kit_light_fairy", "price": 50, "ambient": Color(1.25, 0.95, 1.2), "energy": 1.12, "lamp": Color(1.4, 1.0, 1.2)},
	{"id": "kit_light_neon", "price": 60, "ambient": Color(0.95, 0.75, 1.3), "energy": 0.95, "lamp": Color(1.15, 0.7, 1.35)},
]
