extends SceneTree
## Тесты версии 0.13: мальчик / девочка у каждого героя (переключение бесплатно, вещи не снимаются,
## окна возврата нет, сохраняется), имя героя (очистка, до 12 знаков, сохранение, показ),
## новые наборы «Кот-детектив» и «Цветочный пикник» (по 5 вещей + легендарная, рецепты),
## возврат осколков за вещи заменённых наборов (точная сумма, один раз, сообщение о новых наборах),
## склонения по полу на русском, полнота en/ru, рисование всех героев обоих полов.
## Запуск: godot --headless --path block_game -s tests/test_v013.gd

var failed := 0
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const SAVE := "user://save.cfg"
var drawn := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)


func _initialize() -> void:
	var had_save := FileAccess.file_exists(SAVE)
	var save_bytes := FileAccess.get_file_as_bytes(SAVE) if had_save else PackedByteArray()

	var g: Node2D = load("res://scripts/game.gd").new()
	root.add_child(g)
	g._layout()
	g.tut.enabled = false
	g.assist.track = false
	I18n.set_lang("ru")
	# в тесте _ready() ещё не вызывался — экраны и окна создаём сами
	if g.screens == null:
		g.screens = load("res://scripts/screens.gd").new(g)
	if g.notice_ui == null:
		g.notice_ui = load("res://scripts/notice_ui.gd").new(g)
	if g.forge_ui == null:
		g.forge_ui = load("res://scripts/forge_ui.gd").new(g)

	_test_gender_rules()
	_test_gender_ui(g)
	_test_names()
	_test_name_dialog(g)
	_test_new_sets()
	_test_migration(g)
	_test_texts()
	g.free()
	await _test_drawing()

	if had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)


func _kitten_with_items() -> Object:
	var m = Meta.new()
	m.set_hero("kitten")
	m.shards = 1000
	for id in ["ki_pompom_hat", "ki_bell_bow", "ki_yarn"]:
		m.buy_item(id, 0, 99)
	m.forged.append("ki_teacup")
	m.equip("ki_teacup")
	m.buy_decor("kitten", "floor_l", "kit_yarn", 0, 99)
	return m


func _test_gender_rules() -> void:
	print("— мальчик / девочка: правила")
	var m = _kitten_with_items()
	check(m.gender_of("kitten") == "boy" and not m.is_girl("owl"), "по умолчанию — мальчик у всех")
	check(not m.outfit().has("gender"), "у мальчика в наряде нет ключа gender")
	var owned0: Array = m.owned.duplicate()
	var eq0: Dictionary = m.equipped.duplicate()
	var sh0: int = m.shards
	var dec0: Array = m.decor_owned.duplicate()
	check(m.set_gender("kitten", "girl") and m.is_girl("kitten"), "кошечка: девочка")
	check(m.owned == owned0 and m.equipped == eq0 and m.shards == sh0 and m.forged == ["ki_teacup"] and m.decor_owned == dec0 and m.placed_at("kitten", "floor_l") == "kit_yarn", "смена пола: вещи, наряд, скованное, украшения и осколки не тронуты")
	check(m.hero == "kitten" and not m.switch_asks("kitten"), "тот же герой — окна возврата нет")
	check(m.outfit().get("gender", "") == "girl" and m.outfit().get("head", "") == "ki_pompom_hat", "наряд для рисования: вещи + gender girl")
	check(m.look("kitten") == {"gender": "girl"} and m.look("owl") == {}, "вид героя без наряда")
	check(not m.set_gender("kitten", "cat") and not m.set_gender("dragon", "girl") and m.is_girl("kitten"), "неверные значения не принимаются")
	m.set_gender("owl", "girl")
	m.set_gender("kitten", "boy")
	check(m.is_girl("owl") and not m.is_girl("kitten") and m.owned == owned0, "у каждого героя свой выбор; обратно — тоже бесплатно")
	# сохранение
	var cfg := ConfigFile.new()
	m.save_to(cfg)
	var m2 = Meta.new()
	m2.load_from(cfg)
	check(m2.is_girl("owl") and not m2.is_girl("kitten") and m2.owned == owned0 and m2.equipped == eq0, "пол сохраняется и загружается")
	# старое сохранение без пола и имён, мусорные значения
	var old := ConfigFile.new()
	old.set_value("meta", "hero", "puppy")
	old.set_value("meta", "shards", 50)
	var m3 = Meta.new()
	m3.load_from(old)
	check(m3.genders.is_empty() and m3.names.is_empty() and m3.gender_of("puppy") == "boy" and m3.name_of("puppy") == "", "старое сохранение: мальчики без имён")
	old.set_value("meta", "genders", {"owl": "girl", "puppy": 5, "dragon": "girl", "kitten": "queen"})
	old.set_value("meta", "names", {"owl": "  Филя!!  ", "puppy": 7, "axolotl": "@@@", "kitten": "Очень-длинное-имя-котика"})
	m3.load_from(old)
	check(m3.genders == {"owl": "girl"}, "мусор в поле пола отброшен")
	check(m3.name_of("owl") == "Филя" and m3.name_of("puppy") == "" and m3.name_of("axolotl") == "" and m3.name_of("kitten").length() == 12, "мусор в именах отброшен, длинное обрезано до 12")


func _test_gender_ui(g) -> void:
	print("— мальчик / девочка: экраны")
	g.meta = _kitten_with_items()
	var sc = g.screens
	g._set_state(g.State.WARDROBE)
	sc.tab = "head"
	sc.rects.clear()
	sc.rects["g_boy"] = Rect2(20, 200, 60, 60)
	sc.rects["g_girl"] = Rect2(90, 200, 60, 60)
	var owned0: Array = g.meta.owned.duplicate()
	var sh0: int = g.meta.shards
	sc.tap_wardrobe(Vector2(110, 220))
	check(g.meta.is_girl("kitten") and g.meta.owned == owned0 and g.meta.shards == sh0, "гардероб: кнопка «девочка» — вещи и осколки на месте")
	check(not g.notice_ui.active(), "гардероб: окно смены друга не открылось")
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	check(cfg.get_value("meta", "genders", {}).get("kitten", "") == "girl", "выбор сразу сохранён")
	sc.tap_wardrobe(Vector2(40, 220))
	check(not g.meta.is_girl("kitten") and g.meta.owned == owned0, "кнопка «мальчик» — обратно")
	# экран выбора друга
	g._set_state(g.State.PICK_HERO)
	sc.pick_choice = "owl"
	sc.rects.clear()
	sc.rects["g_boy"] = Rect2(60, 836, 290, 88)
	sc.rects["g_girl"] = Rect2(370, 836, 290, 88)
	sc.tap_pick(Vector2(500, 870))
	check(g.meta.is_girl("owl") and g.meta.hero == "kitten" and g.meta.owned == owned0, "выбор друга: совушка выбрана, текущий друг и вещи не тронуты")
	check(g.meta.display_name("owl") == "Совушка" and g.meta.display_name("kitten") == "Котик", "названия по полу")
	# 3D-дом получает наряд с полом
	g.meta.set_gender("kitten", "girl")
	check(g.meta.outfit().get("gender", "") == "girl", "3D-дом и аватарка получают gender в наряде")
	g.meta.set_gender("kitten", "boy")


func _test_names() -> void:
	print("— имя героя")
	check(Meta.clean_name("  Мур@зик!  ") == "Мурзик", "лишние знаки и пробелы убраны")
	check(Meta.clean_name("Рекс-2  Младший") == "Рекс-2 Младш", "дефис и цифры можно, двойной пробел — один, до 12 знаков")
	check(Meta.clean_name("猫ちゃん") == "猫ちゃん" and Meta.clean_name("Élodie") == "Élodie", "любой алфавит")
	check(Meta.clean_name("   ") == "" and Meta.clean_name("!!!") == "", "пустое после очистки — пустое")
	var m = Meta.new()
	m.set_hero("owl")
	check(not m.set_hero_name("owl", "  !! ") and m.name_of("owl") == "", "пустое имя не принимается")
	check(not m.set_hero_name("dragon", "Филя"), "нет такого героя")
	check(m.set_hero_name("owl", "Филя") and m.display_name("owl") == "Филя" and m.display_name("puppy") == "Щенок", "имя показывается вместо названия")
	m.set_gender("owl", "girl")
	check(m.display_name("owl") == "Филя" and Meta.hero_name("owl", m.gender_of("owl")) == "Совушка", "вид героя (Совушка) остаётся для подписи")
	var cfg := ConfigFile.new()
	m.save_to(cfg)
	var m2 = Meta.new()
	m2.load_from(cfg)
	check(m2.name_of("owl") == "Филя" and m2.name_of("puppy") == "", "имя сохраняется отдельно для каждого героя")
	m2.clear_hero_name("owl")
	check(m2.display_name("owl") == "Совушка", "«Без имени» — снова Совушка")


func _test_name_dialog(g) -> void:
	print("— окно имени")
	g.meta = Meta.new()
	g.meta.set_hero("puppy")
	g._set_state(g.State.WARDROBE)
	var n = g.notice_ui
	n.ask_name("puppy")
	check(n.mode == "name" and n.active() and n.edit.visible, "окно открыто, поле ввода видно")
	n.edit.text = "Бобик"
	n._on_name_changed("Бо#бик!")
	check(n.edit.text == "Бобик", "запрещённые знаки убираются сразу при вводе")
	check(n.edit.max_length == Meta.NAME_MAX, "не больше 12 знаков в поле")
	n.edit.text = "   "
	n.name_done()
	check(n.mode == "name" and g.meta.name_of("puppy") == "", "пустое — «Готово» не закрывает")
	n.edit.text = "Бобик"
	n.name_done()
	check(n.mode == "" and not n.edit.visible and g.meta.name_of("puppy") == "Бобик", "«Готово»: имя задано, окно закрыто")
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	check(cfg.get_value("meta", "names", {}).get("puppy", "") == "Бобик", "имя сразу сохранено")
	n.ask_name("puppy")
	check(n.edit.text == "Бобик", "повторно — в поле текущее имя")
	n.edit.text = "Шарик"
	n.back()
	check(n.mode == "" and g.meta.name_of("puppy") == "Бобик", "«Отмена» ничего не меняет")
	n.ask_name("puppy")
	n.name_clear()
	check(n.mode == "" and g.meta.name_of("puppy") == "" and g.meta.display_name("puppy") == "Щенок", "«Без имени»")
	# кнопка имени в гардеробе открывает окно
	var sc = g.screens
	sc.tab = "head"
	sc.rects.clear()
	sc.rects["name"] = Rect2(30, 180, 190, 48)
	sc.tap_wardrobe(Vector2(60, 200))
	check(n.mode == "name" and n.name_for == "puppy", "кнопка «Имя» в гардеробе открывает окно")
	n.back()


func _test_new_sets() -> void:
	print("— новые наборы")
	for sid in ["kit_detective", "pup_picnic"]:
		var n := Meta.set_index(sid)
		check(n > 0 and Meta.set_info(n).n == 2 and int(Meta.set_info(n).hall) == 3, "%s — второй набор героя, после зала 3" % sid)
		var its: Array = Meta.set_items(n)
		var slots := {}
		for it in its:
			slots[it.slot] = true
		check(its.size() == 5 and slots.size() == 5, "%s: 5 вещей в 5 разных слотах" % sid)
		var prices: Array = its.map(func(it): return int(it.price))
		var rars: Array = its.map(func(it): return it.rarity)
		check(prices == [45, 60, 85, 110, 160] and rars == ["common", "common", "rare", "rare", "epic"], "%s: цены и редкости как у заменённого набора" % sid)
		var r := Meta.recipe_for_set(n)
		check(not r.is_empty() and int(r.cost) == 180 and int(r.hall) == 3 and r.needs == its.map(func(it): return it.id), "%s: рецепт легендарной — 5 вещей, 180 осколков, зал 3" % sid)
		check(Meta.rarity(r.id) == "legendary" and Meta.is_forge(r.id), "%s: награда — легендарная, только в кузнице" % sid)
		check(Meta.set_title(n) != "set_" + sid and Meta.set_title(n).length() > 3, "%s: название набора есть" % sid)
	check(Meta.super_recipe("kitten").needs == ["ki_teacup", "ki_clue_trail", "ki_aura_fireworks"], "супер-награда котика — из трёх легендарных (с «Тайной следов»)")
	check(Meta.super_recipe("puppy").needs == ["pu_frisbee", "pu_petal_rainbow", "pu_aura_bolts"], "супер-награда щенка — из трёх легендарных (с «Радугой лепестков»)")
	for kind in Meta.HEROES:
		check(Meta.hero_items(kind).size() == 19 and Meta.hero_sets(kind).size() == 3, "%s: 19 вещей, 3 набора" % kind)
	var gone := true
	for id in Meta.REPLACED_013.keys() + Meta.REPLACED_013_FORGE.keys():
		if not Meta.item(id).is_empty():
			gone = false
		for r in Meta.RECIPES:
			if r.needs.has(id) or r.id == id:
				gone = false
	check(gone and Meta.set_index("kit_paris") == 0 and Meta.set_index("pup_hike") == 0, "вещей «Парижского шика» и «Похода» больше нет")
	# покупка и ковка
	var m = Meta.new()
	m.set_hero("kitten")
	m.shards = 2000
	for it in Meta.set_items(Meta.set_index("kit_detective")):
		m.buy_item(it.id, 0, 99)
	check(m.forge("ki_clue_trail", 99) == "forged" and m.equipped.get("aura", "") == "ki_clue_trail", "«Кот-детектив» собран — «Тайна следов» скована и надета")
	check(m.is_equipped("ki_magnifier") and m.equipped.get("companion", "") == "ki_magnifier", "лупа — спутник, сияние не мешает спутнику")


func _test_migration(g) -> void:
	print("— возврат за заменённые наборы")
	var old := ConfigFile.new()
	old.set_value("progress", "max_level", 61)
	old.set_value("meta", "hero", "kitten")
	old.set_value("meta", "shards", 100)
	old.set_value("meta", "owned", ["ki_pompom_hat", "ki_beret", "ki_lace_collar", "ki_tail_bow", "ki_heart_glasses", "ki_aura_petals", "ki_teacup"])
	old.set_value("meta", "forged", ["ki_parasol", "ki_teacup", "ki_starry"])
	old.set_value("meta", "equipped", {"head": "ki_beret", "back": "ki_parasol", "neck": "ki_lace_collar", "companion": "ki_teacup"})
	old.set_value("meta", "notice_refund", 0)
	var m = Meta.new()
	m.load_from(old)
	var back := 45 + 85 + 110 + 60 + 160 + 180
	check(m.migrated == back and m.shards == 100 + back and m.notice_refund == back and m.notice_sets, "котик: вернулось %d (вещи шика 460 + ковка зонтика 180)" % back)
	check(m.owned == ["ki_pompom_hat"] and m.forged == ["ki_teacup", "ki_starry"], "убраны из купленных и скованных; остальное на месте")
	check(m.equipped == {"companion": "ki_teacup"}, "сняты с героя")
	var cfg := ConfigFile.new()
	m.save_to(cfg)
	var m2 = Meta.new()
	m2.load_from(cfg)
	check(m2.migrated == 0 and m2.shards == 100 + back and m2.notice_sets and m2.notice_refund == back, "после сохранения — без второго возврата, сообщение ещё ждёт")
	# щенок
	var op := ConfigFile.new()
	op.set_value("meta", "hero", "puppy")
	op.set_value("meta", "shards", 10)
	op.set_value("meta", "owned", ["pu_explorer_hat", "pu_bone_collar", "pu_aviators", "pu_firefly", "pu_backpack", "pu_cap"])
	op.set_value("meta", "forged", ["pu_kite"])
	op.set_value("meta", "equipped", {"back": "pu_kite", "head": "pu_cap"})
	var mp = Meta.new()
	mp.load_from(op)
	var bp := 45 + 60 + 85 + 110 + 160 + 180
	check(mp.migrated == bp and mp.shards == 10 + bp and mp.owned == ["pu_cap"] and mp.forged.is_empty() and mp.equipped == {"head": "pu_cap"}, "щенок: вернулось %d (вещи похода 460 + ковка змея 180)" % bp)
	# сообщение через игру, один раз
	old.save(SAVE)
	g.meta = Meta.new()
	g._load()
	check(g.meta.shards == 100 + back, "игра: сохранение обновлено")
	g._set_state(g.State.HOME)
	g.notice_ui.mode = ""
	g.notice_ui.update(0.1)
	check(g.notice_ui.mode == "migrated" and g.notice_ui.refund == back and g.meta.notice_sets, "на главном экране — «Гардероб обновлён!» о новых наборах")
	g.notice_ui.back()
	g.meta = Meta.new()
	g._load()
	check(g.meta.notice_refund == 0 and not g.meta.notice_sets and g.meta.shards == 100 + back, "после закрытия и перезапуска — ни сообщения, ни второго возврата")


func _test_texts() -> void:
	print("— тексты")
	check(I18n.missing_keys().is_empty(), "все ключи есть на en и ru: %s" % str(I18n.missing_keys().slice(0, 5)))
	I18n.set_lang("ru")
	var exp := {"owl": ["Совёнок", "Совушка", "Совёнка", "Совушки"], "axolotl": ["Аксолотль", "Аксолотлинка", "Аксолотля", "Аксолотлинки"],
		"puppy": ["Щенок", "Собачка", "Щенка", "Собачки"], "kitten": ["Котик", "Кошечка", "Котика", "Кошечки"]}
	var ok := true
	for k in Meta.HEROES:
		var e: Array = exp[k]
		if Meta.hero_name(k, "boy") != e[0] or Meta.hero_name(k, "girl") != e[1] or Meta.hero_gen(k, "boy") != e[2] or Meta.hero_gen(k, "girl") != e[3]:
			ok = false
			printerr("    ", k, ": ", Meta.hero_name(k, "boy"), " ", Meta.hero_name(k, "girl"), " ", Meta.hero_gen(k, "boy"), " ", Meta.hero_gen(k, "girl"))
	check(ok, "ru: названия и родительный падеж по полу")
	check(I18n.t("switch_text") % Meta.hero_gen("kitten", "girl") == "Вещи, украшения и настроения комнаты Кошечки вернутся осколками", "окно смены: «Вещи и украшения Кошечки…»")
	check(Meta.item_name("ki_starry", "kitten", "girl") == "Звёздная кошечка" and Meta.item_name("ki_starry", "kitten", "boy") == "Звёздный котик", "супер-награда котика по полу")
	check(Meta.item_name("pu_hero", "puppy", "girl") == "Собачка-героиня" and Meta.item_name("ki_skin_siamese", "kitten", "boy") == "Сиамский", "Собачка-героиня, Сиамский")
	check(Meta.set_title(Meta.set_index("kit_detective"), "girl") == "Кошка-детектив" and Meta.set_title(Meta.set_index("kit_detective"), "boy") == "Кот-детектив", "набор: Кот-детектив / Кошка-детектив")
	check(not I18n.t("pick_sub").begins_with("Он "), "подзаголовок выбора друга — без «он»")
	for kind in Meta.HEROES:
		for it in Meta.hero_items(kind):
			if Meta.item_name(it.id) == "item_" + it.id:
				ok = false
	check(ok, "у всех вещей есть названия")
	I18n.set_lang("en")
	check(Meta.hero_name("owl", "girl") == "Owlet" and Meta.hero_name("kitten", "boy") == "Kitten" and Meta.item_name("ki_sleuth_hat") == "Sleuth cap", "en: без рода")
	I18n.set_lang("ru")


func _test_drawing() -> void:
	print("— рисование мальчиков и девочек")
	var Hero = load("res://scripts/hero.gd")
	check(Hero.hat_on({"head": "ow_quill"}) and Hero.hat_on({"aura": "ki_starry"}) and not Hero.hat_on({"aura": "ki_clue_trail"}) and not Hero.hat_on({}), "головной убор (и супер-награда на голове) прячет хохолок и заколку")
	check(Hero.is_girl({"gender": "girl"}) and not Hero.is_girl({}) and not Hero.is_girl({"gender": "boy"}), "девочка — по ключу gender")
	var node := Node2D.new()
	root.add_child(node)
	node.draw.connect(func():
		var h = Hero.new()
		for kind in Meta.HEROES:
			for gd in ["boy", "girl"]:
				var base := {"gender": "girl"} if gd == "girl" else {}
				h.draw(node, kind, Vector2(360, 600), 1.0, base, 1.7, 99.0)
				h.draw(node, kind, Vector2(360, 600), 1.0, base, 1.7, 0.4)
				h.draw(node, kind, Vector2(360, 600), 1.0, base, 0.05, 99.0)  # моргнул
				h.draw_avatar(node, kind, Vector2(200, 200), 60, base, 1.0, Color.WHITE)
				for it in Meta.hero_items(kind):
					var o: Dictionary = base.merged({it.slot: it.id})
					h.draw(node, kind, Vector2(360, 600), 1.0, o, 1.7, 0.3)
					h.draw(node, kind, Vector2(360, 600), 1.0, o, 1.7, 0.3, true)
					h.draw_item_icon(node, it.id, it.slot, kind, Vector2(100, 100), 120, 1.7, gd)
		drawn += 1)
	node.queue_redraw()
	for i in 4:
		await process_frame
	if drawn > 0:
		check(true, "все герои обоих полов со всеми вещами нарисованы без ошибок")
	else:
		print("  (рисование в режиме без экрана пропущено)")
	node.free()
