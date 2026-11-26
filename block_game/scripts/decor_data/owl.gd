extends RefCounted
## Каталог дома совёнка (дупло): места, стили, украшения, варианты стен / пола / света (Cascado 0.15).
## Формат — scripts/decor_catalog.gd (шапка файла). Названия — scripts/i18n.gd, блок «0.15», раздел «owl».
## 3D-места (координаты) — scripts/home3d/room_owl.gd, _init (spots); 3D-вещи — там же, _decor().
## Задумка (id, стили, цены) — docs/decor_catalog_0_15.md (сценарист).

## Места: id (у старых шести — прежние id), kind — тип места (decor_catalog.gd KINDS).
## p2d — точка и масштаб в запасном 2D-доме (scripts/home.gd); у старых шести — там же, в home.gd SPOTS.
const SPOTS := [
	{"id": "floor_l", "kind": "floor"},
	{"id": "floor_r", "kind": "floor"},
	{"id": "wall_l", "kind": "wall"},
	{"id": "wall_r", "kind": "wall"},
	{"id": "hang", "kind": "hang"},
	{"id": "near", "kind": "near"},
	# 0.15: заготовки (дизайнер передвигает и добавляет остальные до 14–16, см. docs/decor_catalog_0_15.md)
	{"id": "window", "kind": "window", "p2d": [Vector2(372, 300), 0.6]},
	{"id": "shelf_l", "kind": "shelf", "p2d": [Vector2(230, 520), 0.7]},
	{"id": "near_2", "kind": "near", "p2d": [Vector2(236, 720), 0.62]},
]

## Стили вещей (фильтр «Все / стиль 1 / 2 / 3»). col — цвет значка стиля.
const STYLES := [
	{"id": "owl_nook", "col": Color("#FFB866")},
	{"id": "owl_stars", "col": Color("#8E9BFF")},
	{"id": "owl_potions", "col": Color("#7FD86A")},
]

## Украшения. spots — типы мест (kind), куда вещь можно поставить. flat — висит плоско на стене (картина):
## на месте «стена» её не поворачивают. stars / hall — условие (звёзд всего / пройден зал).
const DECOR := [
	{"id": "owl_nest", "home": "owl", "style": "owl_nook", "price": 10, "spots": ["near", "floor"]},
	{"id": "owl_lantern", "home": "owl", "style": "owl_nook", "price": 15, "spots": ["hang", "wall", "near", "shelf", "window"]},
	{"id": "owl_birdhouse", "home": "owl", "style": "owl_nook", "price": 25, "spots": ["wall"], "flat": true},
	{"id": "owl_books", "home": "owl", "style": "owl_nook", "price": 30, "spots": ["wall", "shelf", "near", "window"]},
	{"id": "owl_hammock", "home": "owl", "style": "owl_nook", "price": 35, "spots": ["wall", "floor"], "flat": true},
	{"id": "owl_garland", "home": "owl", "style": "owl_stars", "price": 20, "spots": ["hang"]},
	{"id": "owl_swing", "home": "owl", "style": "owl_stars", "price": 30, "spots": ["hang"]},
	{"id": "owl_moon", "home": "owl", "style": "owl_stars", "price": 40, "spots": ["hang"], "stars": 25},
	{"id": "owl_nightlight", "home": "owl", "style": "owl_stars", "price": 50, "spots": ["floor", "near", "window"], "hall": 1},
	{"id": "owl_mushrooms", "home": "owl", "style": "owl_potions", "price": 20, "spots": ["floor", "shelf"]},
]

## Стиль комнаты: три слоя. Первый вариант слоя — бесплатный и стоит с начала.
## walls / floor: tint — множитель цвета стен / пола (Color(1,1,1) — как есть; можно больше 1 — светлее).
## light: ambient — оттенок рассеянного света, energy — яркость (×), lamp — оттенок ламп и огоньков.
const WALLS := [
	{"id": "owl_walls_bark", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "owl_walls_moss", "price": 30, "tint": Color(0.85, 1.35, 0.7)},
	{"id": "owl_walls_starry", "price": 50, "tint": Color(0.75, 0.8, 1.45)},
	{"id": "owl_walls_runes", "price": 60, "tint": Color(0.8, 1.2, 1.35), "stars": 30},
]
const FLOORS := [
	{"id": "owl_floor_leaves", "price": 0, "tint": Color(1, 1, 1)},
	{"id": "owl_floor_rug", "price": 25, "tint": Color(1.3, 1.05, 0.75)},
	{"id": "owl_floor_stars", "price": 45, "tint": Color(0.75, 0.8, 1.5)},
	{"id": "owl_floor_roots", "price": 60, "tint": Color(0.8, 1.35, 1.2), "hall": 1},
]
const LIGHTS := [
	{"id": "owl_light_moon", "price": 0, "ambient": Color(1, 1, 1), "energy": 1.0, "lamp": Color(1, 1, 1)},
	{"id": "owl_light_lamp", "price": 30, "ambient": Color(1.45, 1.05, 0.65), "energy": 1.1, "lamp": Color(1.4, 1.0, 0.6)},
	{"id": "owl_light_firefly", "price": 50, "ambient": Color(0.95, 1.35, 0.7), "energy": 1.05, "lamp": Color(1.1, 1.4, 0.6)},
	{"id": "owl_light_aurora", "price": 70, "ambient": Color(0.6, 1.3, 1.25), "energy": 1.15, "lamp": Color(0.7, 1.3, 1.4)},
]
