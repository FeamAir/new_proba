extends RefCounted
## Мета-слой Cascado (версия 0.6): герой, осколки, гардероб, залы карты.
## Только данные и правила, без рисования (рисование — scripts/hero.gd и scripts/screens.gd).
## Сохраняется в тот же user://save.cfg, раздел [meta]; старые сохранения без него
## загружаются со значениями по умолчанию.

const HEROES := ["owl", "axolotl"]
const HERO_NAMES := {"owl": "Совёнок", "axolotl": "Аксолотль"}

const SLOTS := ["head", "eyes", "neck", "back", "skin"]
const SLOT_NAMES := {"head": "Голова", "eyes": "Глаза", "neck": "Шея", "back": "Спина", "skin": "Окраска"}

## Вещи гардероба. price — цена в осколках; stars — нужно звёзд всего;
## hall — нужно пройти зал с этим номером (1 = Аметистовый, ... 5 = Сердце горы).
const ITEMS := [
	{"id": "bow", "slot": "head", "name": "Бантик", "price": 20},
	{"id": "cap", "slot": "head", "name": "Колпачок", "price": 30},
	{"id": "miner", "slot": "head", "name": "Каска шахтёра", "price": 60},
	{"id": "wreath", "slot": "head", "name": "Грибной венок", "price": 80, "hall": 2},
	{"id": "crown", "slot": "head", "name": "Корона", "price": 150, "stars": 60},
	{"id": "sunglasses", "slot": "eyes", "name": "Тёмные очки", "price": 40},
	{"id": "crystal_glasses", "slot": "eyes", "name": "Очки-кристаллы", "price": 50},
	{"id": "monocle", "slot": "eyes", "name": "Монокль", "price": 70, "stars": 30},
	{"id": "bowtie", "slot": "neck", "name": "Бабочка", "price": 30},
	{"id": "scarf", "slot": "neck", "name": "Шарф в ромбик", "price": 35},
	{"id": "necklace", "slot": "neck", "name": "Ожерелье", "price": 90, "hall": 1},
	{"id": "backpack", "slot": "back", "name": "Рюкзак", "price": 45},
	{"id": "cape", "slot": "back", "name": "Звёздный плащ", "price": 120, "hall": 3},
	{"id": "skin_mint", "slot": "skin", "name": "Мятный", "price": 60},
	{"id": "skin_moon", "slot": "skin", "name": "Лунный", "price": 80},
	{"id": "skin_gold", "slot": "skin", "name": "Золотой", "price": 200, "stars": 100},
]

## Украшения дома: у каждого героя свой дом и свой набор. spots — куда можно поставить:
## floor (пол слева/справа), wall (стена или ветка слева/справа), hang (подвес сверху),
## near (рядом с героем).
const SPOTS := ["floor_l", "floor_r", "wall_l", "wall_r", "hang", "near"]
const SPOT_NAMES := {"floor_l": "Пол слева", "floor_r": "Пол справа", "wall_l": "Слева",
	"wall_r": "Справа", "hang": "Сверху", "near": "Рядом"}
const DECOR := [
	{"id": "owl_nest", "home": "owl", "name": "Коврик-гнездо", "price": 10, "spots": ["near", "floor"]},
	{"id": "owl_lantern", "home": "owl", "name": "Фонарик", "price": 15, "spots": ["hang", "wall", "near"]},
	{"id": "owl_garland", "home": "owl", "name": "Гирлянда", "price": 20, "spots": ["hang"]},
	{"id": "owl_mushrooms", "home": "owl", "name": "Грибы-лампы", "price": 20, "spots": ["floor"]},
	{"id": "owl_birdhouse", "home": "owl", "name": "Скворечник", "price": 25, "spots": ["wall"]},
	{"id": "owl_books", "home": "owl", "name": "Книжки", "price": 30, "spots": ["wall", "near"]},
	{"id": "owl_swing", "home": "owl", "name": "Качели", "price": 30, "spots": ["hang"]},
	{"id": "owl_hammock", "home": "owl", "name": "Гамак", "price": 35, "spots": ["wall", "floor"]},
	{"id": "owl_moon", "home": "owl", "name": "Луна-подвеска", "price": 40, "spots": ["hang"], "stars": 25},
	{"id": "owl_nightlight", "home": "owl", "name": "Кристалл-ночник", "price": 50, "spots": ["floor", "near"], "hall": 1},
	{"id": "axo_starfish", "home": "axolotl", "name": "Морская звезда", "price": 10, "spots": ["wall"]},
	{"id": "axo_coral", "home": "axolotl", "name": "Коралл", "price": 15, "spots": ["wall", "floor"]},
	{"id": "axo_anchor", "home": "axolotl", "name": "Якорь", "price": 20, "spots": ["floor", "wall"]},
	{"id": "axo_shell", "home": "axolotl", "name": "Жемчужница", "price": 25, "spots": ["floor", "near"]},
	{"id": "axo_lily", "home": "axolotl", "name": "Кувшинка", "price": 25, "spots": ["hang"]},
	{"id": "axo_bubble", "home": "axolotl", "name": "Лампа-пузырь", "price": 30, "spots": ["hang", "near"]},
	{"id": "axo_tree", "home": "axolotl", "name": "Кораллы-деревья", "price": 35, "spots": ["floor"]},
	{"id": "axo_sofa", "home": "axolotl", "name": "Камень-диван", "price": 40, "spots": ["near"]},
	{"id": "axo_castle", "home": "axolotl", "name": "Замок", "price": 50, "spots": ["floor"], "hall": 2},
	{"id": "axo_chest", "home": "axolotl", "name": "Сундук", "price": 60, "spots": ["floor", "near"], "stars": 40},
]

# Начисление осколков за победу
const WIN_FIRST := 10
const WIN_REPEAT := 3
const PER_NEW_STAR := 5
const PER_BIG_CHAIN := 3     # за каждую цепочку ×3 и выше в партии
const CHAIN_CAP := 12        # не больше 12 за цепочки

# Залы: по 10 уровней. После 50-го — «Бесконечные глубины», нумерация продолжается.
const HALL_SIZE := 10
const HALLS := [
	{"name": "Аметистовый зал", "col": Color("#B46CFF")},
	{"name": "Изумрудный зал", "col": Color("#3DDC97")},
	{"name": "Огненный зал", "col": Color("#FF7A3D")},
	{"name": "Ледяной зал", "col": Color("#7FE3FF")},
	{"name": "Сердце горы", "col": Color("#FF4D6D")},
	{"name": "Бесконечные глубины", "col": Color("#9C8FD6")},
]
const METERS_PER_LEVEL := 12

enum Buy { OK, OWNED, LOCKED, POOR, UNKNOWN }

var hero := ""               # "" — ещё не выбран (первый запуск)
var shards := 0
var owned: Array = []        # id купленных вещей
var equipped: Dictionary = {}  # слот -> id
var decor_owned: Array = []    # id купленных украшений (свои для каждого дома)
var decor_placed: Dictionary = {"owl": {}, "axolotl": {}}  # дом -> {место -> id}


# ---------- Залы ----------

static func hall_index(level: int) -> int:
	return clampi((level - 1) / HALL_SIZE, 0, HALLS.size() - 1)


static func hall(level: int) -> Dictionary:
	return HALLS[hall_index(level)]


static func depth(level: int) -> int:
	return level * METERS_PER_LEVEL


## Пройден ли зал номер n (1..5): открыт уровень после его последнего.
static func hall_done(n: int, max_level: int) -> bool:
	return max_level > n * HALL_SIZE


# ---------- Осколки ----------

## Награда за победу. first — уровень пройден впервые; old_stars — прежний рекорд звёзд;
## new_stars — звёзды этой партии; big_chains — сколько цепочек ×3+ было в партии.
static func win_reward(first: bool, old_stars: int, new_stars: int, big_chains: int) -> Dictionary:
	var r := {}
	r.win = WIN_FIRST if first else WIN_REPEAT
	r.stars = PER_NEW_STAR * maxi(0, new_stars - old_stars)
	r.chains = mini(CHAIN_CAP, PER_BIG_CHAIN * maxi(0, big_chains))
	r.total = r.win + r.stars + r.chains
	return r


# ---------- Вещи ----------

static func item(id: String) -> Dictionary:
	for it in ITEMS:
		if it.id == id:
			return it
	for it in DECOR:
		if it.id == id:
			return it
	return {}


static func spot_kind(spot: String) -> String:
	return spot.trim_suffix("_l").trim_suffix("_r")


static func decor_for(home: String, spot: String) -> Array:
	var k := spot_kind(spot)
	return DECOR.filter(func(it): return it.home == home and it.spots.has(k))


## Ступень богатства дома (0..3) по пройденным залам.
static func home_stage(max_level: int) -> int:
	var halls := clampi((max_level - 1) / HALL_SIZE, 0, 5)
	return [0, 1, 2, 2, 3, 3][halls]


static func items_in(slot: String) -> Array:
	return ITEMS.filter(func(it): return it.slot == slot)


## Пустая строка — условие выполнено; иначе — почему вещь закрыта.
static func lock_reason(id: String, total_stars: int, max_level: int) -> String:
	var it := item(id)
	if it.is_empty():
		return "?"
	if it.has("stars") and total_stars < int(it.stars):
		return "Нужно звёзд: %d" % it.stars
	if it.has("hall") and not hall_done(int(it.hall), max_level):
		return "Пройди: %s" % HALLS[int(it.hall) - 1].name
	return ""


func is_owned(id: String) -> bool:
	return owned.has(id) or decor_owned.has(id)


func is_equipped(id: String) -> bool:
	var it := item(id)
	return it.has("slot") and equipped.get(it.slot, "") == id


func buy(id: String, total_stars: int, max_level: int) -> int:
	var it := item(id)
	if it.is_empty():
		return Buy.UNKNOWN
	if is_owned(id):
		return Buy.OWNED
	if lock_reason(id, total_stars, max_level) != "":
		return Buy.LOCKED
	if shards < int(it.price):
		return Buy.POOR
	shards -= int(it.price)
	if it.has("home"):
		decor_owned.append(id)
	else:
		owned.append(id)
	return Buy.OK


func equip(id: String) -> bool:
	if not owned.has(id):
		return false
	equipped[item(id).slot] = id
	return true


func unequip(slot: String) -> void:
	equipped.erase(slot)


## Нажатие на вещь в гардеробе: надета — снять; куплена — надеть; иначе купить и надеть.
## Возвращает: "off", "on", "bought", "locked", "poor".
func tap_item(id: String, total_stars: int, max_level: int) -> String:
	if not item(id).has("slot"):
		return "locked"
	if is_equipped(id):
		unequip(item(id).slot)
		return "off"
	if is_owned(id):
		equip(id)
		return "on"
	match buy(id, total_stars, max_level):
		Buy.OK:
			equip(id)
			return "bought"
		Buy.POOR:
			return "poor"
	return "locked"


# ---------- Украшения дома ----------

func placed_at(home: String, spot: String) -> String:
	return decor_placed.get(home, {}).get(spot, "")


## Поставить купленное украшение на место своего дома (с прежнего места оно уходит).
func place(home: String, spot: String, id: String) -> bool:
	var it := item(id)
	if not decor_owned.has(id) or it.get("home", "") != home or not SPOTS.has(spot) or not it.spots.has(spot_kind(spot)):
		return false
	var d: Dictionary = decor_placed.get(home, {})
	for s in d.keys():
		if d[s] == id:
			d.erase(s)
	d[spot] = id
	decor_placed[home] = d
	return true


func remove_decor(home: String, spot: String) -> void:
	if decor_placed.has(home):
		decor_placed[home].erase(spot)


## Нажатие на украшение для места: стоит тут — убрать; куплено — поставить; иначе купить и поставить.
func tap_decor(home: String, spot: String, id: String, total_stars: int, max_level: int) -> String:
	if placed_at(home, spot) == id:
		remove_decor(home, spot)
		return "off"
	if decor_owned.has(id):
		return "on" if place(home, spot, id) else "locked"
	var it := item(id)
	if it.get("home", "") != home or not it.spots.has(spot_kind(spot)):
		return "locked"
	match buy(id, total_stars, max_level):
		Buy.OK:
			place(home, spot, id)
			return "bought"
		Buy.POOR:
			return "poor"
	return "locked"


func set_hero(h: String) -> bool:
	if not HEROES.has(h):
		return false
	hero = h
	return true


## Наряд для рисования: слот -> id (без героя).
func outfit() -> Dictionary:
	return equipped.duplicate()


# ---------- Сохранение ----------

func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("meta", "hero", hero)
	cfg.set_value("meta", "shards", shards)
	cfg.set_value("meta", "owned", owned)
	cfg.set_value("meta", "equipped", equipped)
	cfg.set_value("meta", "decor_owned", decor_owned)
	cfg.set_value("meta", "decor_placed", decor_placed)


func load_from(cfg: ConfigFile) -> void:
	var h = cfg.get_value("meta", "hero", "")
	hero = h if h is String and HEROES.has(h) else ""
	var s = cfg.get_value("meta", "shards", 0)
	shards = maxi(0, int(s)) if (s is int or s is float) else 0
	owned = []
	var o = cfg.get_value("meta", "owned", [])
	if o is Array:
		for id in o:
			if id is String and not item(id).is_empty() and not item(id).has("home") and not owned.has(id):
				owned.append(id)
	decor_owned = []
	var dow = cfg.get_value("meta", "decor_owned", [])
	if dow is Array:
		for id in dow:
			if id is String and item(id).has("home") and not decor_owned.has(id):
				decor_owned.append(id)
	decor_placed = {"owl": {}, "axolotl": {}}
	var dp = cfg.get_value("meta", "decor_placed", {})
	if dp is Dictionary:
		for home in HEROES:
			var d = dp.get(home, {})
			if d is Dictionary:
				for spot in d:
					if spot is String and d[spot] is String:
						place(home, spot, d[spot])
	equipped = {}
	var e = cfg.get_value("meta", "equipped", {})
	if e is Dictionary:
		for slot in e:
			var id = e[slot]
			if id is String and owned.has(id) and item(id).get("slot", "") == slot:
				equipped[slot] = id
