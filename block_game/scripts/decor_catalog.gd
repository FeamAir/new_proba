extends RefCounted
## Каталог украшений и стилей комнат Cascado (0.15). Только данные и поиск по ним — без состояния игрока
## (купленное, расстановки, настроения — в scripts/meta.gd).
##
## Данные лежат по домам — у каждого дома свой файл (дизайнеры работают параллельно, не мешая друг другу):
##   scripts/decor_data/owl.gd, axolotl.gd, puppy.gd, kitten.gd
## В каждом файле пять констант:
##   SPOTS  — места: {"id", "kind", "p2d"?}. id уникален в доме; у шести старых — прежние id
##            (floor_l, floor_r, wall_l, wall_r, hang, near). kind — тип места из KINDS.
##            p2d — [Vector2 точка, масштаб] в запасном 2D-доме (нет — место в 2D не показывается).
##   STYLES — стили вещей дома (ровно 3): {"id", "col"} (col — цвет значка).
##   DECOR  — украшения: {"id", "home", "style", "spots": [типы мест], "price", "stars"?, "hall"?, "flat"?}
##            id — уникален во всей игре (с приставкой дома: owl_, axo_, pup_, kit_).
##   WALLS, FLOORS, LIGHTS — варианты слоёв стиля комнаты: {"id", "price", ...}; первый — бесплатный,
##            стоит с начала. walls/floor: "tint" (Color); light: "ambient" (Color), "energy" (×), "lamp" (Color).
##            Условия "stars" / "hall" — как у украшений.
## Названия — в scripts/i18n.gd (блок «0.15»): item_<id> (украшение), dstyle_<id> (стиль), room_<id> (вариант слоя),
## spot_<id> — по желанию (нет — «Полка 2», «Пол 3»... по типу места).

const OwlData := preload("res://scripts/decor_data/owl.gd")
const AxolotlData := preload("res://scripts/decor_data/axolotl.gd")
const PuppyData := preload("res://scripts/decor_data/puppy.gd")
const KittenData := preload("res://scripts/decor_data/kitten.gd")

## Небольшой общий набор типов мест.
##   floor — на полу у стены; near — на полу рядом с героем; wall — на стене (плоские вещи висят, прочие — на полочке);
##   shelf — на полке (вещь стоит); hang — сверху (на нитке или высокой полке, как решит комната);
##   window — на подоконнике (вещь стоит).
const KINDS := ["floor", "near", "wall", "shelf", "hang", "window"]
## Слои стиля комнаты
const LAYERS := ["walls", "floor", "light"]
## Сколько мест на дом самое большее (интерфейс и производительность рассчитаны на это)
const MAX_SPOTS := 16

const DATA := {"owl": OwlData, "axolotl": AxolotlData, "puppy": PuppyData, "kitten": KittenData}
## Все украшения всех домов (старый Meta.DECOR — тот же список)
const DECOR := OwlData.DECOR + AxolotlData.DECOR + PuppyData.DECOR + KittenData.DECOR

static var _room_cache := {}
static var _spot_cache := {}


static func homes() -> Array:
	return DATA.keys()


static func _data(home: String):
	return DATA.get(home, null)


# ---------- Места ----------

static func spots(home: String) -> Array:
	var d = _data(home)
	return d.SPOTS if d != null else []


static func spot_ids(home: String) -> Array:
	return spots(home).map(func(s): return s.id)


static func has_spot(home: String, spot: String) -> bool:
	return _spot_map(home).has(spot)


static func _spot_map(home: String) -> Dictionary:
	if not _spot_cache.has(home):
		var m := {}
		for s in spots(home):
			m[s.id] = s
		_spot_cache[home] = m
	return _spot_cache[home]


static func spot(home: String, id: String) -> Dictionary:
	return _spot_map(home).get(id, {})


## Тип места. Без дома (старые вызовы) — по любому дому, где такое место есть; иначе — по имени (floor_l -> floor).
static func spot_kind(id: String, home := "") -> String:
	if home != "":
		return spot(home, id).get("kind", "")
	for h in DATA:
		var s := spot(h, id)
		if not s.is_empty():
			return s.kind
	return id.trim_suffix("_l").trim_suffix("_r")


# ---------- Стили вещей ----------

static func styles(home: String) -> Array:
	var d = _data(home)
	return d.STYLES if d != null else []


static func style_ids(home: String) -> Array:
	return styles(home).map(func(s): return s.id)


static func style_col(style_id: String) -> Color:
	for h in DATA:
		for s in styles(h):
			if s.id == style_id:
				return s.col
	return Color.WHITE


# ---------- Украшения ----------

static func decor(home: String) -> Array:
	var d = _data(home)
	return d.DECOR if d != null else []


static func decor_item(id: String) -> Dictionary:
	for it in DECOR:
		if it.id == id:
			return it
	return {}


## Украшения дома, которые подходят месту (spot "" — все), стиля style ("" / "all" — любого).
static func decor_for(home: String, spot_id := "", style := "") -> Array:
	var k := spot_kind(spot_id, home) if spot_id != "" else ""
	return decor(home).filter(func(it):
		return (k == "" or it.spots.has(k)) and (style == "" or style == "all" or it.get("style", "") == style))


## Подходит ли украшение месту дома
static func fits(home: String, spot_id: String, id: String) -> bool:
	var it := decor_item(id)
	if it.is_empty() or it.get("home", "") != home or not has_spot(home, spot_id):
		return false
	return it.spots.has(spot_kind(spot_id, home))


## Можно ли поворачивать вещь на месте: плоскую вещь на стене — нет
static func can_rotate(home: String, spot_id: String, id: String) -> bool:
	if id == "" or not fits(home, spot_id, id):
		return false
	return not (spot_kind(spot_id, home) == "wall" and decor_item(id).get("flat", false))


# ---------- Стиль комнаты (стены / пол / свет) ----------

static func layer_items(home: String, layer: String) -> Array:
	var d = _data(home)
	if d == null:
		return []
	match layer:
		"walls": return d.WALLS
		"floor": return d.FLOORS
		"light": return d.LIGHTS
	return []


## Вариант слоя по id: словарь из данных + "home" нет (чтобы не путать с украшением), есть "house" и "layer"
static func room_item(id: String) -> Dictionary:
	if _room_cache.is_empty():
		for h in DATA:
			for l in LAYERS:
				for it in layer_items(h, l):
					var c: Dictionary = it.duplicate()
					c["house"] = h
					c["layer"] = l
					_room_cache[it.id] = c
	return _room_cache.get(id, {})


static func is_room_item(id: String) -> bool:
	return not room_item(id).is_empty()


## Стиль комнаты по умолчанию: первые (бесплатные) варианты слоёв
static func default_room(home: String) -> Dictionary:
	var out := {}
	for l in LAYERS:
		var list := layer_items(home, l)
		out[l] = list[0].id if not list.is_empty() else ""
	return out


static func is_free(id: String) -> bool:
	var it := room_item(id)
	return not it.is_empty() and int(it.get("price", 0)) == 0
