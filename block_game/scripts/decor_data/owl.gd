extends RefCounted
## Каталог дома совёнка (дупло): места, стили, украшения, варианты стен / пола / света (Cascado 0.15).
## Формат — см. scripts/decor_catalog.gd (шапка файла). Названия — в scripts/i18n.gd, блок «0.15», раздел «owl».
## 3D-места (координаты) — scripts/home3d/room_owl.gd, функция _init (spots); 3D-вещи — там же, _decor().

## Места: id (у старых шести — прежние id), kind — тип места (decor_catalog.gd KINDS).
## p2d — точка и масштаб в запасном 2D-доме (scripts/home.gd); у старых шести — там же, в home.gd SPOTS.
const SPOTS := [
	{"id": "floor_l", "kind": "floor"},
	{"id": "floor_r", "kind": "floor"},
	{"id": "wall_l", "kind": "wall"},
	{"id": "wall_r", "kind": "wall"},
	{"id": "hang", "kind": "hang"},
	{"id": "near", "kind": "near"},
	# 0.15: заготовки (дизайнер может передвинуть и добавить ещё до 14–16)
	{"id": "window", "kind": "window", "p2d": [Vector2(372, 300), 0.6]},
	{"id": "shelf_1", "kind": "shelf", "p2d": [Vector2(230, 520), 0.7]},
	{"id": "floor_b", "kind": "floor", "p2d": [Vector2(236, 760), 0.75]},
]

## Стили вещей (фильтр «Все / стиль 1 / 2 / 3»). col — цвет значка стиля.
const STYLES := [
	{"id": "owl_forest", "col": Color("#7FC46A")},
	{"id": "owl_night", "col": Color("#8E9BFF")},
	{"id": "owl_cozy", "col": Color("#FFB866")},
]

## Украшения. spots — типы мест (kind), куда вещь можно поставить. flat — висит плоско на стене (картина):
## на месте «стена» её не поворачивают. stars / hall — условие (звёзд всего / пройден зал).
const DECOR := [
	{"id": "owl_nest", "home": "owl", "style": "owl_cozy", "price": 10, "spots": ["near", "floor"]},
	{"id": "owl_lantern", "home": "owl", "style": "owl_cozy", "price": 15, "spots": ["hang", "wall", "near", "shelf", "window"]},
	{"id": "owl_garland", "home": "owl", "style": "owl_night", "price": 20, "spots": ["hang"]},
	{"id": "owl_mushrooms", "home": "owl", "style": "owl_forest", "price": 20, "spots": ["floor"]},
	{"id": "owl_birdhouse", "home": "owl", "style": "owl_forest", "price": 25, "spots": ["wall"], "flat": true},
	{"id": "owl_books", "home": "owl", "style": "owl_cozy", "price": 30, "spots": ["wall", "near", "shelf", "window"]},
	{"id": "owl_swing", "home": "owl", "style": "owl_forest", "price": 30, "spots": ["hang"]},
	{"id": "owl_hammock", "home": "owl", "style": "owl_cozy", "price": 35, "spots": ["wall", "floor"], "flat": true},
	{"id": "owl_moon", "home": "owl", "style": "owl_night", "price": 40, "spots": ["hang"], "stars": 25},
	{"id": "owl_nightlight", "home": "owl", "style": "owl_night", "price": 50, "spots": ["floor", "near", "window"], "hall": 1},
]

## Стиль комнаты: три слоя. Первый вариант слоя — бесплатный и стоит с начала.
## walls / floor: tint — во сколько раз умножается цвет стен / пола (Color(1,1,1) — как есть).
## light: ambient — оттенок рассеянного света, energy — яркость (×), lamp — оттенок ламп и огоньков.
const WALLS := [
	{"id": "owl_walls_bark", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "owl_walls_moss", "price": 25, "tint": Color("#B9E6A2")},
	{"id": "owl_walls_dusk", "price": 35, "tint": Color("#C9B6FF")},
	{"id": "owl_walls_honey", "price": 45, "tint": Color("#FFD99C"), "stars": 20},
]
const FLOORS := [
	{"id": "owl_floor_straw", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "owl_floor_moss", "price": 20, "tint": Color("#A8E08E")},
	{"id": "owl_floor_petal", "price": 30, "tint": Color("#FFC2DA")},
	{"id": "owl_floor_frost", "price": 40, "tint": Color("#C4E4FF"), "hall": 1},
]
const LIGHTS := [
	{"id": "owl_light_warm", "price": 0, "ambient": Color(1, 1, 1), "energy": 1.0, "lamp": Color(1, 1, 1)},
	{"id": "owl_light_moon", "price": 25, "ambient": Color("#B4C8FF"), "energy": 1.12, "lamp": Color("#C4D6FF")},
	{"id": "owl_light_firefly", "price": 35, "ambient": Color("#D6FFB4"), "energy": 1.05, "lamp": Color("#E2FF9E")},
	{"id": "owl_light_candle", "price": 45, "ambient": Color("#FFC890"), "energy": 0.88, "lamp": Color("#FFB070")},
]
