extends RefCounted
## Локализация Cascado: свой словарь строк, без файлов импорта (надёжно работает в APK).
## Использование: const I18n := preload("res://scripts/i18n.gd"), затем I18n.t("ключ")
## или I18n.t("ключ") % [числа]. Текущий язык — I18n.lang (общий для всех скриптов).
##
## Как добавить новый язык (например, немецкий "de"):
##   1) дописать "de" в LANGS и название в LANG_NAMES ("Deutsch");
##   2) скопировать весь блок "en" в STR под ключом "de" и перевести значения
##      (ключи и %d/%s не менять);
##   3) при желании — правило множественного числа в plural_index();
##   4) запустить тесты: тест «все ключи есть во всех языках» покажет пропуски.
## Язык телефона подхватывается в detect(): если код языка есть в LANGS — берётся он.

const LANGS := ["en", "ru"]
const LANG_NAMES := {"en": "English", "ru": "Русский"}
const DEFAULT := "en"

static var lang := DEFAULT

const STR := {
	"en": {
		# игра
		"cascade": "CASCADE ×%d",
		"crystal_one": "CRYSTAL!",
		"crystal_many": "CRYSTALS ×%d",
		"panel_next": "NEXT",
		"panel_crystals": "CRYSTALS",
		"panel_score": "SCORE",
		"panel_level": "LEVEL",
		"panel_pieces": "PIECES",
		# пауза
		"pause_title": "PAUSED",
		"pause_resume": "Resume",
		"pause_music": "Music: %s",
		"pause_sound": "Sound: %s",
		"pause_lang": "Language: %s",
		"pause_restart": "Restart level",
		"on": "on",
		"off": "off",
		"home": "Home",
		# выбор героя
		"pick_title": "Choose your buddy",
		"pick_sub": "They'll explore the cave depths with you",
		"pick_lives_owl": "lives in a tree hollow",
		"pick_lives_axolotl": "lives in a sea grotto",
		"pick_ok": "LET'S GO!",
		"pick_hint": "You can switch buddies in the Wardrobe",
		"hero_owl": "Owlet",
		"hero_axolotl": "Axolotl",
		# дом
		"home_depth": "%s · depth %d m",
		"play": "PLAY",
		"level_n": "Level %d",
		"map": "Map",
		"wardrobe": "Wardrobe",
		# гардероб
		"tab_home": "Home",
		"slot_head": "Head",
		"slot_eyes": "Eyes",
		"slot_neck": "Neck",
		"slot_back": "Back",
		"slot_skin": "Color",
		"spot_floor_l": "Floor left",
		"spot_floor_r": "Floor right",
		"spot_wall_l": "Left",
		"spot_wall_r": "Right",
		"spot_hang": "Top",
		"spot_near": "Nearby",
		"house_owl": "Tree hollow",
		"house_axolotl": "Underwater grotto",
		"card_worn": "WORN",
		"card_placed": "PLACED",
		"card_wear": "Wear",
		"card_place": "Place",
		"card_hall": "Hall %d",
		"lock_stars": "Needs %d stars",
		"lock_hall": "Clear %s first",
		"bought": "Bought: %s",
		"poor": "Not enough shards: need %d more",
		# вещи
		"item_bow": "Bow",
		"item_cap": "Party hat",
		"item_miner": "Miner's helmet",
		"item_wreath": "Mushroom wreath",
		"item_crown": "Crown",
		"item_sunglasses": "Sunglasses",
		"item_crystal_glasses": "Crystal specs",
		"item_monocle": "Monocle",
		"item_bowtie": "Bow tie",
		"item_scarf": "Argyle scarf",
		"item_necklace": "Necklace",
		"item_backpack": "Backpack",
		"item_cape": "Starry cape",
		"item_skin_mint": "Mint",
		"item_skin_moon": "Moonlight",
		"item_skin_gold": "Golden",
		# украшения
		"item_owl_nest": "Nest rug",
		"item_owl_lantern": "Lantern",
		"item_owl_garland": "Garland",
		"item_owl_mushrooms": "Mushroom lamps",
		"item_owl_birdhouse": "Birdhouse",
		"item_owl_books": "Books",
		"item_owl_swing": "Swing",
		"item_owl_hammock": "Hammock",
		"item_owl_moon": "Hanging moon",
		"item_owl_nightlight": "Crystal lamp",
		"item_axo_starfish": "Starfish",
		"item_axo_coral": "Coral",
		"item_axo_anchor": "Anchor",
		"item_axo_shell": "Pearl shell",
		"item_axo_lily": "Water lily",
		"item_axo_bubble": "Bubble lamp",
		"item_axo_tree": "Coral trees",
		"item_axo_sofa": "Stone sofa",
		"item_axo_castle": "Castle",
		"item_axo_chest": "Treasure chest",
		# залы и карта
		"hall_0": "Amethyst Hall",
		"hall_1": "Emerald Hall",
		"hall_2": "Fire Hall",
		"hall_3": "Ice Hall",
		"hall_4": "Heart of the Mountain",
		"hall_5": "Endless Depths",
		"map_range": "Depth %d–%d m",
		"map_below": "Depth %d m and deeper",
		"map_locked": "Opens after level 50",
		"map_depth": "Depth %d m · %s",
		# победа и поражение
		"win_title": "LEVEL %d COMPLETE!",
		"win_stats": "Score: %d   Pieces: %d",
		"win_first": "first win +%d",
		"win_repeat": "win +%d",
		"win_stars": "stars +%d",
		"win_chains": "cascades +%d",
		"shards_forms": "shard|shards|shards",
		"next": "Next  ›",
		"lose_title": "BOARD FULL",
		"lose_crystals": "Crystals: %d of %d",
		"lose_hint": "Don't give up — try again!",
		"retry": "Try again",
	},
	"ru": {
		"cascade": "КАСКАД ×%d",
		"crystal_one": "КРИСТАЛЛ!",
		"crystal_many": "КРИСТАЛЛЫ ×%d",
		"panel_next": "ДАЛЕЕ",
		"panel_crystals": "КРИСТАЛЛЫ",
		"panel_score": "СЧЁТ",
		"panel_level": "УРОВЕНЬ",
		"panel_pieces": "ФИГУРЫ",
		"pause_title": "ПАУЗА",
		"pause_resume": "Продолжить",
		"pause_music": "Музыка: %s",
		"pause_sound": "Звуки: %s",
		"pause_lang": "Язык: %s",
		"pause_restart": "Начать уровень заново",
		"on": "вкл",
		"off": "выкл",
		"home": "Домой",
		"pick_title": "Выбери друга",
		"pick_sub": "Он пойдёт с тобой в глубины пещеры",
		"pick_lives_owl": "живёт в дупле",
		"pick_lives_axolotl": "живёт в гроте",
		"pick_ok": "ГОТОВО",
		"pick_hint": "Друга можно сменить в гардеробе",
		"hero_owl": "Совёнок",
		"hero_axolotl": "Аксолотль",
		"home_depth": "%s · глубина %d м",
		"play": "ИГРАТЬ",
		"level_n": "Уровень %d",
		"map": "Карта",
		"wardrobe": "Гардероб",
		"tab_home": "Дом",
		"slot_head": "Голова",
		"slot_eyes": "Глаза",
		"slot_neck": "Шея",
		"slot_back": "Спина",
		"slot_skin": "Окраска",
		"spot_floor_l": "Пол слева",
		"spot_floor_r": "Пол справа",
		"spot_wall_l": "Слева",
		"spot_wall_r": "Справа",
		"spot_hang": "Сверху",
		"spot_near": "Рядом",
		"house_owl": "Дупло",
		"house_axolotl": "Грот",
		"card_worn": "НАДЕТО",
		"card_placed": "СТОИТ",
		"card_wear": "Надеть",
		"card_place": "Поставить",
		"card_hall": "Зал %d",
		"lock_stars": "Нужно звёзд: %d",
		"lock_hall": "Пройди: %s",
		"bought": "Куплено: %s",
		"poor": "Не хватает осколков: нужно ещё %d",
		"item_bow": "Бантик",
		"item_cap": "Колпачок",
		"item_miner": "Каска шахтёра",
		"item_wreath": "Грибной венок",
		"item_crown": "Корона",
		"item_sunglasses": "Тёмные очки",
		"item_crystal_glasses": "Очки-кристаллы",
		"item_monocle": "Монокль",
		"item_bowtie": "Бабочка",
		"item_scarf": "Шарф в ромбик",
		"item_necklace": "Ожерелье",
		"item_backpack": "Рюкзак",
		"item_cape": "Звёздный плащ",
		"item_skin_mint": "Мятный",
		"item_skin_moon": "Лунный",
		"item_skin_gold": "Золотой",
		"item_owl_nest": "Коврик-гнездо",
		"item_owl_lantern": "Фонарик",
		"item_owl_garland": "Гирлянда",
		"item_owl_mushrooms": "Грибы-лампы",
		"item_owl_birdhouse": "Скворечник",
		"item_owl_books": "Книжки",
		"item_owl_swing": "Качели",
		"item_owl_hammock": "Гамак",
		"item_owl_moon": "Луна-подвеска",
		"item_owl_nightlight": "Кристалл-ночник",
		"item_axo_starfish": "Морская звезда",
		"item_axo_coral": "Коралл",
		"item_axo_anchor": "Якорь",
		"item_axo_shell": "Жемчужница",
		"item_axo_lily": "Кувшинка",
		"item_axo_bubble": "Лампа-пузырь",
		"item_axo_tree": "Кораллы-деревья",
		"item_axo_sofa": "Камень-диван",
		"item_axo_castle": "Замок",
		"item_axo_chest": "Сундук",
		"hall_0": "Аметистовый зал",
		"hall_1": "Изумрудный зал",
		"hall_2": "Огненный зал",
		"hall_3": "Ледяной зал",
		"hall_4": "Сердце горы",
		"hall_5": "Бесконечные глубины",
		"map_range": "Глубина %d–%d м",
		"map_below": "Глубина %d м и ниже",
		"map_locked": "Откроются после 50-го уровня",
		"map_depth": "Глубина %d м · %s",
		"win_title": "УРОВЕНЬ %d ПРОЙДЕН!",
		"win_stats": "Очки: %d   Фигуры: %d",
		"win_first": "первая победа +%d",
		"win_repeat": "победа +%d",
		"win_stars": "звёзды +%d",
		"win_chains": "каскады +%d",
		"shards_forms": "осколок|осколка|осколков",
		"next": "Дальше  ›",
		"lose_title": "ПОЛЕ ЗАПОЛНЕНО",
		"lose_crystals": "Кристаллы: %d из %d",
		"lose_hint": "Не сдавайся — попробуй ещё!",
		"retry": "Ещё раз",
	},
}


## Строка на текущем языке; нет перевода — английская; нет и её — сам ключ.
static func t(key: String) -> String:
	var d: Dictionary = STR.get(lang, {})
	if d.has(key):
		return d[key]
	return STR[DEFAULT].get(key, key)


## Язык по коду языка телефона (OS.get_locale_language()): знакомый — он, иначе английский.
static func detect(os_lang: String) -> String:
	var l := os_lang.to_lower().substr(0, 2)
	return l if LANGS.has(l) else DEFAULT


static func set_lang(l: String) -> bool:
	if not LANGS.has(l):
		return false
	lang = l
	return true


## Следующий язык по кругу (для кнопки-переключателя).
static func next_lang() -> String:
	return LANGS[(LANGS.find(lang) + 1) % LANGS.size()]


static func lang_name(l := "") -> String:
	return LANG_NAMES.get(l if l != "" else lang, l)


## Короткая подпись для кнопки: EN, RU.
static func lang_code() -> String:
	return lang.to_upper()


## Номер формы множественного числа: 0 — одна, 1 — несколько (2–4), 2 — много.
static func plural_index(n: int) -> int:
	if lang == "ru":
		var m10 := n % 10
		var m100 := n % 100
		if m10 == 1 and m100 != 11:
			return 0
		if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
			return 1
		return 2
	return 0 if n == 1 else 2


## Слово с формой по числу: forms("shards_forms", 5) -> «осколков» / «shards».
static func forms(key: String, n: int) -> String:
	var f := t(key).split("|")
	return f[mini(plural_index(n), f.size() - 1)]


## Ключи, которых нет в каком-то языке (для теста). Пусто — всё переведено.
static func missing_keys() -> Array:
	var all := {}
	for l in LANGS:
		for k in STR[l]:
			all[k] = true
	var out: Array = []
	for l in LANGS:
		for k in all:
			if not STR[l].has(k) or String(STR[l][k]).strip_edges() == "":
				out.append("%s:%s" % [l, k])
	return out


# ---------- Сохранение: user://save.cfg, [settings] language ----------

## Из сохранения; нет поля (старое сохранение) или чужое значение — по языку телефона.
static func load_from(cfg: ConfigFile, os_lang: String) -> void:
	var l = cfg.get_value("settings", "language", "")
	if not (l is String and LANGS.has(l)):
		l = detect(os_lang)
	lang = l


static func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("settings", "language", lang)
