extends RefCounted
## Мета-слой Cascado (версия 0.6; щенок и котик — 0.9; редкости, наборы, кузница — 0.12):
## герой, осколки, гардероб, залы карты.
## Только данные и правила, без рисования (рисование — scripts/hero.gd и scripts/screens.gd).
## Сохраняется в тот же user://save.cfg, раздел [meta]; старые сохранения без него
## загружаются со значениями по умолчанию.

const I18n := preload("res://scripts/i18n.gd")

const HEROES := ["owl", "axolotl", "puppy", "kitten"]

## 0.12: спутник (маленький друг летает рядом) и сияние (эффект позади/вокруг героя)
const SLOTS := ["head", "eyes", "neck", "back", "skin", "companion", "aura"]

## 0.12: редкости вещей (от простой к самой ценной). Цвета рамок и эффекты — scripts/rarity.gd.
const RARITIES := ["common", "rare", "epic", "legendary", "super"]

## Вещи гардероба. price — цена в осколках; stars — нужно звёзд всего;
## hall — нужно пройти зал с этим номером (1 = Аметистовый, ... 10 = Корона кристаллов).
## Названия вещей, украшений, залов, героев — в scripts/i18n.gd (ключи item_<id>, hall_<n>...).
## rarity — редкость (RARITIES); set — номер набора 1..5 (SETS); forge — награда кузницы
## (не продаётся, куётся по рецепту RECIPES; hall у неё — зал, после которого открыт рецепт).
const ITEMS := [
	{"id": "bow", "slot": "head", "price": 20, "rarity": "common"},
	{"id": "cap", "slot": "head", "price": 30, "rarity": "common"},
	{"id": "miner", "slot": "head", "price": 60, "rarity": "rare"},
	{"id": "wreath", "slot": "head", "price": 80, "hall": 2, "rarity": "rare"},
	{"id": "crown", "slot": "head", "price": 150, "stars": 60, "rarity": "epic"},
	{"id": "sunglasses", "slot": "eyes", "price": 40, "rarity": "common"},
	{"id": "crystal_glasses", "slot": "eyes", "price": 50, "rarity": "common"},
	{"id": "monocle", "slot": "eyes", "price": 70, "stars": 30, "rarity": "rare"},
	{"id": "bowtie", "slot": "neck", "price": 30, "rarity": "common"},
	{"id": "scarf", "slot": "neck", "price": 35, "rarity": "common"},
	{"id": "necklace", "slot": "neck", "price": 90, "hall": 1, "rarity": "rare"},
	{"id": "backpack", "slot": "back", "price": 45, "rarity": "common"},
	{"id": "cape", "slot": "back", "price": 120, "hall": 3, "rarity": "epic"},
	{"id": "skin_mint", "slot": "skin", "price": 60, "rarity": "rare"},
	{"id": "skin_moon", "slot": "skin", "price": 80, "rarity": "rare"},
	{"id": "skin_gold", "slot": "skin", "price": 200, "stars": 100, "rarity": "epic"},
	# 0.12: набор 1 «Сад светлячков» (после зала 1)
	{"id": "acorn_cap", "slot": "head", "price": 30, "hall": 1, "set": 1, "rarity": "common"},
	{"id": "leaf_scarf", "slot": "neck", "price": 35, "hall": 1, "set": 1, "rarity": "common"},
	{"id": "daisy_glasses", "slot": "eyes", "price": 70, "hall": 1, "set": 1, "rarity": "rare"},
	{"id": "firefly", "slot": "companion", "price": 80, "hall": 1, "set": 1, "rarity": "rare"},
	{"id": "dragonfly_wings", "slot": "back", "price": 90, "hall": 1, "set": 1, "rarity": "rare"},
	{"id": "skin_moss", "slot": "skin", "price": 150, "hall": 1, "set": 1, "rarity": "epic"},
	{"id": "bluebell_hat", "slot": "head", "price": 160, "hall": 1, "set": 1, "rarity": "epic"},
	{"id": "aura_pollen", "slot": "aura", "price": 180, "hall": 1, "set": 1, "rarity": "epic"},
	# набор 2 «Подводные сокровища» (после зала 2)
	{"id": "shell_clip", "slot": "head", "price": 40, "hall": 2, "set": 2, "rarity": "common"},
	{"id": "dive_mask", "slot": "eyes", "price": 45, "hall": 2, "set": 2, "rarity": "common"},
	{"id": "pearl_necklace", "slot": "neck", "price": 90, "hall": 2, "set": 2, "rarity": "rare"},
	{"id": "bubble_pet", "slot": "companion", "price": 90, "hall": 2, "set": 2, "rarity": "rare"},
	{"id": "fin_cape", "slot": "back", "price": 100, "hall": 2, "set": 2, "rarity": "rare"},
	{"id": "skin_pearl", "slot": "skin", "price": 180, "hall": 2, "set": 2, "rarity": "epic"},
	{"id": "coral_tiara", "slot": "head", "price": 180, "hall": 2, "set": 2, "rarity": "epic"},
	{"id": "aura_bubbles", "slot": "aura", "price": 200, "hall": 2, "set": 2, "rarity": "epic"},
	# набор 3 «Лунный бал» (после зала 3)
	{"id": "moth_tie", "slot": "neck", "price": 40, "hall": 3, "set": 3, "rarity": "common"},
	{"id": "masquerade", "slot": "eyes", "price": 45, "hall": 3, "set": 3, "rarity": "common"},
	{"id": "top_hat", "slot": "head", "price": 100, "hall": 3, "set": 3, "rarity": "rare"},
	{"id": "moon_moth", "slot": "companion", "price": 100, "hall": 3, "set": 3, "rarity": "rare"},
	{"id": "ball_cloak", "slot": "back", "price": 110, "hall": 3, "set": 3, "rarity": "rare"},
	{"id": "star_lorgnette", "slot": "eyes", "price": 180, "hall": 3, "set": 3, "rarity": "epic"},
	{"id": "skin_midnight", "slot": "skin", "price": 200, "hall": 3, "set": 3, "rarity": "epic"},
	{"id": "aura_moonbeam", "slot": "aura", "price": 220, "hall": 3, "set": 3, "rarity": "epic"},
	# набор 4 «Звёздный путешественник» (после зала 4)
	{"id": "flight_goggles", "slot": "eyes", "price": 50, "hall": 4, "set": 4, "rarity": "common"},
	{"id": "comet_scarf", "slot": "neck", "price": 50, "hall": 4, "set": 4, "rarity": "common"},
	{"id": "mini_planet", "slot": "companion", "price": 110, "hall": 4, "set": 4, "rarity": "rare"},
	{"id": "space_helmet", "slot": "head", "price": 120, "hall": 4, "set": 4, "rarity": "rare"},
	{"id": "rocket_pack", "slot": "back", "price": 120, "hall": 4, "set": 4, "rarity": "rare"},
	{"id": "star_compass", "slot": "neck", "price": 200, "hall": 4, "set": 4, "rarity": "epic"},
	{"id": "skin_nebula", "slot": "skin", "price": 220, "hall": 4, "set": 4, "rarity": "epic"},
	{"id": "aura_starfall", "slot": "aura", "price": 240, "hall": 4, "set": 4, "rarity": "epic"},
	# набор 5 «Кристальный король» (после зала 5; в рецепт входит и корона)
	{"id": "amethyst_monocle", "slot": "eyes", "price": 60, "hall": 5, "set": 5, "rarity": "common"},
	{"id": "ermine_collar", "slot": "neck", "price": 60, "hall": 5, "set": 5, "rarity": "common"},
	{"id": "float_crystal", "slot": "companion", "price": 130, "hall": 5, "set": 5, "rarity": "rare"},
	{"id": "crystal_diadem", "slot": "head", "price": 130, "hall": 5, "set": 5, "rarity": "rare"},
	{"id": "royal_mantle", "slot": "back", "price": 140, "hall": 5, "set": 5, "rarity": "rare"},
	{"id": "skin_amethyst", "slot": "skin", "price": 240, "hall": 5, "set": 5, "rarity": "epic"},
	{"id": "aura_facets", "slot": "aura", "price": 260, "hall": 5, "set": 5, "rarity": "epic"},
	# награды Кристальной кузницы: легендарные и супер-эксклюзив (не продаются)
	{"id": "firefly_crown", "slot": "head", "hall": 1, "set": 1, "rarity": "legendary", "forge": true},
	{"id": "seahorse", "slot": "companion", "hall": 2, "set": 2, "rarity": "legendary", "forge": true},
	{"id": "fullmoon_mantle", "slot": "back", "hall": 3, "set": 3, "rarity": "legendary", "forge": true},
	{"id": "skin_constellation", "slot": "skin", "hall": 4, "set": 4, "rarity": "legendary", "forge": true},
	{"id": "mountain_heart", "slot": "neck", "hall": 5, "set": 5, "rarity": "legendary", "forge": true},
	{"id": "wings_cascado", "slot": "aura", "hall": 5, "rarity": "super", "forge": true},
]

## 0.12: наборы (названия — i18n set_<id>); col — цвет значка набора.
const SETS := [
	{"id": "firefly", "hall": 1, "col": Color("#C6F04A")},
	{"id": "sunken", "hall": 2, "col": Color("#3FE0D0")},
	{"id": "moon", "hall": 3, "col": Color("#B9C4FF")},
	{"id": "voyager", "hall": 4, "col": Color("#FF7AD9")},
	{"id": "crystal", "hall": 5, "col": Color("#C08BFF")},
]

## Рецепты кузницы: needs — вещи (не тратятся, остаются у игрока), cost — осколки,
## hall — нужно пройти зал. Последний — супер-эксклюзив из пяти легендарных.
const RECIPES := [
	{"id": "firefly_crown", "set": 1, "hall": 1, "cost": 50, "needs": ["leaf_scarf", "daisy_glasses", "firefly"]},
	{"id": "seahorse", "set": 2, "hall": 2, "cost": 80, "needs": ["shell_clip", "dive_mask", "pearl_necklace", "bubble_pet"]},
	{"id": "fullmoon_mantle", "set": 3, "hall": 3, "cost": 100, "needs": ["masquerade", "top_hat", "moon_moth", "ball_cloak"]},
	{"id": "skin_constellation", "set": 4, "hall": 4, "cost": 140, "needs": ["flight_goggles", "comet_scarf", "mini_planet", "space_helmet", "rocket_pack"]},
	{"id": "mountain_heart", "set": 5, "hall": 5, "cost": 180, "needs": ["amethyst_monocle", "ermine_collar", "float_crystal", "royal_mantle", "crown"]},
	{"id": "wings_cascado", "set": 0, "hall": 5, "cost": 300, "needs": ["firefly_crown", "seahorse", "fullmoon_mantle", "skin_constellation", "mountain_heart"]},
]
## 0.12: доход за глубокие залы — +2 осколка к первой победе за каждый зал глубже первого
const HALL_BONUS := 2

## Украшения дома: у каждого героя свой дом и свой набор. spots — куда можно поставить:
## floor (пол слева/справа), wall (стена или ветка слева/справа), hang (подвес сверху;
## у котика — верхняя полка), near (рядом с героем).
const SPOTS := ["floor_l", "floor_r", "wall_l", "wall_r", "hang", "near"]
const DECOR := [
	{"id": "owl_nest", "home": "owl", "price": 10, "spots": ["near", "floor"]},
	{"id": "owl_lantern", "home": "owl", "price": 15, "spots": ["hang", "wall", "near"]},
	{"id": "owl_garland", "home": "owl", "price": 20, "spots": ["hang"]},
	{"id": "owl_mushrooms", "home": "owl", "price": 20, "spots": ["floor"]},
	{"id": "owl_birdhouse", "home": "owl", "price": 25, "spots": ["wall"]},
	{"id": "owl_books", "home": "owl", "price": 30, "spots": ["wall", "near"]},
	{"id": "owl_swing", "home": "owl", "price": 30, "spots": ["hang"]},
	{"id": "owl_hammock", "home": "owl", "price": 35, "spots": ["wall", "floor"]},
	{"id": "owl_moon", "home": "owl", "price": 40, "spots": ["hang"], "stars": 25},
	{"id": "owl_nightlight", "home": "owl", "price": 50, "spots": ["floor", "near"], "hall": 1},
	{"id": "axo_starfish", "home": "axolotl", "price": 10, "spots": ["wall"]},
	{"id": "axo_coral", "home": "axolotl", "price": 15, "spots": ["wall", "floor"]},
	{"id": "axo_anchor", "home": "axolotl", "price": 20, "spots": ["floor", "wall"]},
	{"id": "axo_shell", "home": "axolotl", "price": 25, "spots": ["floor", "near"]},
	{"id": "axo_lily", "home": "axolotl", "price": 25, "spots": ["hang"]},
	{"id": "axo_bubble", "home": "axolotl", "price": 30, "spots": ["hang", "near"]},
	{"id": "axo_tree", "home": "axolotl", "price": 35, "spots": ["floor"]},
	{"id": "axo_sofa", "home": "axolotl", "price": 40, "spots": ["near"]},
	{"id": "axo_castle", "home": "axolotl", "price": 50, "spots": ["floor"], "hall": 2},
	{"id": "axo_chest", "home": "axolotl", "price": 60, "spots": ["floor", "near"], "stars": 40},
	{"id": "pup_ball", "home": "puppy", "price": 10, "spots": ["floor", "near"]},
	{"id": "pup_bone", "home": "puppy", "price": 15, "spots": ["near"]},
	{"id": "pup_bowl", "home": "puppy", "price": 20, "spots": ["near", "floor"]},
	{"id": "pup_sign", "home": "puppy", "price": 20, "spots": ["wall"]},
	{"id": "pup_flowerbed", "home": "puppy", "price": 25, "spots": ["floor"]},
	{"id": "pup_pinwheel", "home": "puppy", "price": 30, "spots": ["wall", "floor"]},
	{"id": "pup_lamp", "home": "puppy", "price": 35, "spots": ["hang", "wall", "floor"]},
	{"id": "pup_bed", "home": "puppy", "price": 45, "spots": ["near"]},
	{"id": "pup_kite", "home": "puppy", "price": 50, "spots": ["hang"], "stars": 25},
	{"id": "pup_teddy", "home": "puppy", "price": 60, "spots": ["near", "floor"], "hall": 1},
	{"id": "kit_yarn", "home": "kitten", "price": 10, "spots": ["floor", "near"]},
	{"id": "kit_mouse", "home": "kitten", "price": 15, "spots": ["near"]},
	{"id": "kit_pillow", "home": "kitten", "price": 20, "spots": ["near"]},
	{"id": "kit_picture", "home": "kitten", "price": 20, "spots": ["wall"]},
	{"id": "kit_catnip", "home": "kitten", "price": 25, "spots": ["hang", "wall", "floor"]},
	{"id": "kit_box", "home": "kitten", "price": 30, "spots": ["floor", "near"]},
	{"id": "kit_scratcher", "home": "kitten", "price": 35, "spots": ["floor"]},
	{"id": "kit_lamp", "home": "kitten", "price": 40, "spots": ["floor"]},
	{"id": "kit_aquarium", "home": "kitten", "price": 50, "spots": ["hang", "wall", "near"], "stars": 30},
	{"id": "kit_tree", "home": "kitten", "price": 60, "spots": ["floor"], "hall": 2},
]

# Начисление осколков за победу
const WIN_FIRST := 10
const WIN_REPEAT := 3
const PER_NEW_STAR := 5
const PER_BIG_CHAIN := 3     # за каждую цепочку ×3 и выше в партии
const CHAIN_CAP := 12        # не больше 12 за цепочки

# Залы: по 10 уровней, 10 залов (100 уровней таблицы scripts/levels.gd). После 100-го —
# «Бесконечные глубины» (последняя строка HALLS), нумерация продолжается.
# Названия — scripts/i18n.gd, ключи hall_0 ... hall_10.
const HALL_SIZE := 10
const HALLS := [
	{"col": Color("#B46CFF")},  # 1 Аметистовый зал
	{"col": Color("#3DDC97")},  # 2 Изумрудный зал
	{"col": Color("#FF7A3D")},  # 3 Огненный зал
	{"col": Color("#7FE3FF")},  # 4 Ледяной зал
	{"col": Color("#FF4D6D")},  # 5 Сердце горы
	{"col": Color("#4D7CFF")},  # 6 Сапфировый грот
	{"col": Color("#FFB547")},  # 7 Янтарные копи
	{"col": Color("#D8E2FF")},  # 8 Лунное озеро
	{"col": Color("#C6F04A")},  # 9 Гнездо светлячков
	{"col": Color("#FF8AD8")},  # 10 Корона кристаллов
	{"col": Color("#9C8FD6")},  # Бесконечные глубины
]
## Залов с уровнями таблицы (без «Бесконечных глубин»).
const HALL_COUNT := 10
## Последний уровень таблицы; дальше — «Бесконечные глубины».
const LAST_LEVEL := HALL_COUNT * HALL_SIZE
## Ступени богатства дома: сколько залов надо пройти для ступени 1, 2, 3.
const HOME_STAGE_HALLS := [1, 3, 6]
const METERS_PER_LEVEL := 12

enum Buy { OK, OWNED, LOCKED, POOR, UNKNOWN }

var hero := ""               # "" — ещё не выбран (первый запуск)
var shards := 0
var owned: Array = []        # id купленных вещей
var equipped: Dictionary = {}  # слот -> id
var decor_owned: Array = []    # id купленных украшений (свои для каждого дома)
var decor_placed: Dictionary = {"owl": {}, "axolotl": {}, "puppy": {}, "kitten": {}}  # дом -> {место -> id}
var forged: Array = []         # 0.12: id скованных в кузнице вещей


# ---------- Залы ----------

static func hall_index(level: int) -> int:
	return clampi((level - 1) / HALL_SIZE, 0, HALLS.size() - 1)


static func hall(level: int) -> Dictionary:
	return HALLS[hall_index(level)]


## Название зала по номеру 0..10 (10 — «Бесконечные глубины») на текущем языке (тексты — scripts/i18n.gd).
static func hall_name(h: int) -> String:
	return I18n.t("hall_%d" % clampi(h, 0, HALLS.size() - 1))


static func hero_name(kind: String) -> String:
	return I18n.t("hero_" + kind)


static func slot_name(slot: String) -> String:
	return I18n.t("slot_" + slot)


static func spot_name(spot: String) -> String:
	return I18n.t("spot_" + spot)


## kind — герой: у окрасок для разных героев свои названия (ключ item_<id>_<герой>, если есть).
static func item_name(id: String, kind := "") -> String:
	if kind != "" and I18n.has("item_%s_%s" % [id, kind]):
		return I18n.t("item_%s_%s" % [id, kind])
	return I18n.t("item_" + id)


static func depth(level: int) -> int:
	return level * METERS_PER_LEVEL


## Пройден ли зал номер n (1..10): открыт уровень после его последнего.
static func hall_done(n: int, max_level: int) -> bool:
	return max_level > n * HALL_SIZE


# ---------- Осколки ----------

## Награда за победу. first — уровень пройден впервые; old_stars — прежний рекорд звёзд;
## new_stars — звёзды этой партии; big_chains — сколько цепочек ×3+ было в партии.
## level — номер уровня (0.12): за первую победу +HALL_BONUS за каждый зал глубже первого
## (зал 1 — 10, зал 2 — 12, ... зал 10 — 28; в «Бесконечных глубинах» — как в зале 10).
static func win_reward(first: bool, old_stars: int, new_stars: int, big_chains: int, level := 1) -> Dictionary:
	var r := {}
	r.win = (WIN_FIRST + hall_bonus(level)) if first else WIN_REPEAT
	r.first = first
	r.stars = PER_NEW_STAR * maxi(0, new_stars - old_stars)
	r.chains = mini(CHAIN_CAP, PER_BIG_CHAIN * maxi(0, big_chains))
	r.total = r.win + r.stars + r.chains
	return r


## 0.12: прибавка к первой победе за глубину зала.
static func hall_bonus(level: int) -> int:
	return HALL_BONUS * mini(hall_index(level), HALL_COUNT - 1)


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


## Ступень богатства дома (0..3) по пройденным залам: 1 зал — ступень 1,
## 3 зала — ступень 2, 6 залов — ступень 3 (HOME_STAGE_HALLS).
static func home_stage(max_level: int) -> int:
	var halls := clampi((max_level - 1) / HALL_SIZE, 0, HALL_COUNT)
	var stage := 0
	for need in HOME_STAGE_HALLS:
		if halls >= need:
			stage += 1
	return stage


static func items_in(slot: String) -> Array:
	return ITEMS.filter(func(it): return it.slot == slot)


## Пустая строка — условие выполнено; иначе — почему вещь закрыта.
static func lock_reason(id: String, total_stars: int, max_level: int) -> String:
	var it := item(id)
	if it.is_empty():
		return "?"
	if it.has("stars") and total_stars < int(it.stars):
		return I18n.t("lock_stars") % it.stars
	if it.has("hall") and not hall_done(int(it.hall), max_level):
		return I18n.t("lock_hall") % hall_name(int(it.hall) - 1)
	if it.get("forge", false):
		return I18n.t("lock_forge")
	return ""


# ---------- 0.12: редкости, наборы, кузница, коллекция ----------

static func rarity(id: String) -> String:
	return item(id).get("rarity", "common")


static func rarity_name(r: String) -> String:
	return I18n.t("rarity_" + r)


static func is_forge(id: String) -> bool:
	return item(id).get("forge", false)


## Номер набора вещи (0 — не из набора).
static func set_of(id: String) -> int:
	return int(item(id).get("set", 0))


static func set_info(n: int) -> Dictionary:
	return SETS[n - 1] if n >= 1 and n <= SETS.size() else {}


static func set_title(n: int) -> String:
	return I18n.t("set_" + SETS[n - 1].id) if n >= 1 and n <= SETS.size() else ""


## Вещи набора n (без награды кузницы), в порядке таблицы.
static func set_items(n: int) -> Array:
	return ITEMS.filter(func(it): return int(it.get("set", 0)) == n and not it.get("forge", false))


static func recipe(id: String) -> Dictionary:
	for r in RECIPES:
		if r.id == id:
			return r
	return {}


## Рецепт набора n (1..5); 0 — супер-эксклюзив «Крылья Каскада».
static func recipe_for_set(n: int) -> Dictionary:
	for r in RECIPES:
		if int(r.set) == n:
			return r
	return {}


## Всего вещей в коллекции (гардероб, без украшений дома).
static func collection_total() -> int:
	return ITEMS.size()


## Сколько вещей коллекции у игрока (купленные и скованные).
func collection_count() -> int:
	var n := 0
	for it in ITEMS:
		if is_owned(it.id):
			n += 1
	return n


## Сколько вещей рецепта уже есть у игрока.
func recipe_have(id: String) -> int:
	var n := 0
	for need in recipe(id).get("needs", []):
		if is_owned(need):
			n += 1
	return n


## Состояние рецепта: "done" — уже скован, "hall" — зал не пройден, "items" — не хватает вещей,
## "poor" — не хватает осколков, "ok" — можно ковать, "unknown" — нет такого рецепта.
func forge_status(id: String, max_level: int) -> String:
	var r := recipe(id)
	if r.is_empty():
		return "unknown"
	if forged.has(id):
		return "done"
	if not hall_done(int(r.hall), max_level):
		return "hall"
	if recipe_have(id) < r.needs.size():
		return "items"
	if shards < int(r.cost):
		return "poor"
	return "ok"


## Все вещи рецепта собраны (осколков может не хватать) — силуэт награды пульсирует.
func recipe_complete(id: String, max_level: int) -> bool:
	return forge_status(id, max_level) in ["ok", "poor"]


## Есть ли рецепт, который можно сковать прямо сейчас (метка «Можно сковать!»).
func forge_ready_any(max_level: int) -> bool:
	for r in RECIPES:
		if forge_status(r.id, max_level) == "ok":
			return true
	return false


## Сковать награду: тратятся только осколки, вещи рецепта остаются у игрока; награда сразу надевается.
## Возвращает "forged" или причину отказа (как forge_status).
func forge(id: String, max_level: int) -> String:
	var st := forge_status(id, max_level)
	if st != "ok":
		return st
	shards -= int(recipe(id).cost)
	forged.append(id)
	equip(id)
	return "forged"


func is_owned(id: String) -> bool:
	return owned.has(id) or decor_owned.has(id) or forged.has(id)


func is_equipped(id: String) -> bool:
	var it := item(id)
	return it.has("slot") and equipped.get(it.slot, "") == id


func buy(id: String, total_stars: int, max_level: int) -> int:
	var it := item(id)
	if it.is_empty():
		return Buy.UNKNOWN
	if is_owned(id):
		return Buy.OWNED
	if lock_reason(id, total_stars, max_level) != "" or it.get("forge", false):
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
	if not (owned.has(id) or forged.has(id)):
		return false
	equipped[item(id).slot] = id
	return true


func unequip(slot: String) -> void:
	equipped.erase(slot)


## Нажатие на вещь в гардеробе: надета — снять; куплена — надеть; не куплена — "try"
## (примерка: ничего не покупается, решает игрок в панели — buy_item()).
## Возвращает: "off", "on", "try", "locked" (не вещь гардероба).
func tap_item(id: String) -> String:
	if not item(id).has("slot"):
		return "locked"
	if is_equipped(id):
		unequip(item(id).slot)
		return "off"
	if is_owned(id):
		equip(id)
		return "on"
	return "try"


## Купить вещь и сразу надеть (кнопка «Купить» в панели примерки).
## Возвращает: "bought", "owned", "poor", "locked".
func buy_item(id: String, total_stars: int, max_level: int) -> String:
	if not item(id).has("slot"):
		return "locked"
	match buy(id, total_stars, max_level):
		Buy.OK:
			equip(id)
			return "bought"
		Buy.OWNED:
			equip(id)
			return "owned"
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


## Нажатие на украшение для места: стоит тут — убрать; куплено — поставить;
## не куплено — "try" (примерка, покупка — buy_decor()); чужой дом / не то место — "locked".
func tap_decor(home: String, spot: String, id: String) -> String:
	if placed_at(home, spot) == id:
		remove_decor(home, spot)
		return "off"
	if decor_owned.has(id):
		return "on" if place(home, spot, id) else "locked"
	if not fits_spot(home, spot, id):
		return "locked"
	return "try"


func fits_spot(home: String, spot: String, id: String) -> bool:
	var it := item(id)
	return it.get("home", "") == home and SPOTS.has(spot) and it.spots.has(spot_kind(spot))


## Купить украшение и сразу поставить на место. Возвращает: "bought", "owned", "poor", "locked".
func buy_decor(home: String, spot: String, id: String, total_stars: int, max_level: int) -> String:
	if not fits_spot(home, spot, id):
		return "locked"
	match buy(id, total_stars, max_level):
		Buy.OK:
			place(home, spot, id)
			return "bought"
		Buy.OWNED:
			place(home, spot, id)
			return "owned"
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
	cfg.set_value("meta", "forged", forged)


func load_from(cfg: ConfigFile) -> void:
	var h = cfg.get_value("meta", "hero", "")
	hero = h if h is String and HEROES.has(h) else ""
	var s = cfg.get_value("meta", "shards", 0)
	shards = maxi(0, int(s)) if (s is int or s is float) else 0
	owned = []
	var o = cfg.get_value("meta", "owned", [])
	if o is Array:
		for id in o:
			if id is String and not item(id).is_empty() and not item(id).has("home") and not is_forge(id) and not owned.has(id):
				owned.append(id)
	# 0.12: скованные в кузнице; в старом сохранении поля нет — пусто
	forged = []
	var fg = cfg.get_value("meta", "forged", [])
	if fg is Array:
		for id in fg:
			if id is String and is_forge(id) and not forged.has(id):
				forged.append(id)
	decor_owned = []
	var dow = cfg.get_value("meta", "decor_owned", [])
	if dow is Array:
		for id in dow:
			if id is String and item(id).has("home") and not decor_owned.has(id):
				decor_owned.append(id)
	decor_placed = {}
	for home in HEROES:
		decor_placed[home] = {}
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
			if id is String and (owned.has(id) or forged.has(id)) and item(id).get("slot", "") == slot:
				equipped[slot] = id
