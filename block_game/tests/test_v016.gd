extends SceneTree
## Тесты версии 0.16: смена друга без возврата — у каждого из 4 друзей своё.
##   Смена не меняет осколки и не трогает имущество прежнего друга (вещи, наряд, скованное,
##   украшения дома, настроения, стили комнаты); новый друг пустой; вернулся — всё как было;
##   наряды хранятся по друзьям (и в сохранении); подсказка при первой смене — один раз;
##   окна «Сменить друга?» больше нет; старое сохранение (общий наряд) обновляется без потерь.
## Запуск: godot --headless --path block_game -s tests/test_v016.gd

var failed := 0
var frame := 0
var g
var had_save := false
var save_bytes := PackedByteArray()
var hint_drawn := 0
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const Catalog := preload("res://scripts/decor_catalog.gd")
const SAVE := "user://save.cfg"


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)


func _initialize() -> void:
	had_save = FileAccess.file_exists(SAVE)
	save_bytes = FileAccess.get_file_as_bytes(SAVE) if had_save else PackedByteArray()
	g = load("res://scripts/game.gd").new()
	root.add_child(g)


func _process(_d: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	if frame == 3:
		I18n.set_lang("ru")
		g.tut.enabled = false
		g.assist.track = false
		_test_rules()
		_test_return()
		_test_filters()
		_test_save()
		_test_migration()
		_test_texts()
		_test_ui()
		return false
	if frame < 8:
		return false
	if hint_drawn > 0:
		check(true, "плашка-подсказка нарисована без ошибок")
	else:
		print("  (рисование в режиме без экрана пропущено)")
	if had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)
	return true


## Котик: купленные вещи, скованная чашка, наряд, украшения, второе настроение, купленный стиль стен
func _rich_kitten() -> Meta:
	var m := Meta.new()
	m.set_hero("kitten")
	m.shards = 2000
	for id in ["ki_pompom_hat", "ki_bell_bow", "ki_yarn", "ki_sweater", "ki_skin_tabby"]:
		m.buy_item(id, 0, 1)
	m.forge("ki_teacup", 1)
	m.unequip("back")
	m.buy_decor("kitten", "near", "kit_mouse", 0, 1)
	m.buy_decor("kitten", "floor_l", "kit_yarn", 0, 1)
	m.switch_mood("kitten", 1)
	m.place("kitten", "near", "kit_mouse")
	m.rotate_decor("kitten", "near", 2)
	return m


## Первый платный вариант комнаты дома home (стены / пол / свет), доступный сразу
func _paid_room(home: String) -> String:
	for id in ["owl_walls_moss", "owl_light_lamp"]:
		if Catalog.room_item(id).get("house", "") == home:
			return id
	return ""


# ---------- Правила ----------

func _test_rules() -> void:
	print("— смена друга: ничего не возвращается и не снимается")
	var m := Meta.new()
	check(m.switch_hero("owl") and m.hero == "owl" and m.equipped.is_empty(), "первый выбор — совёнок, пусто")
	m.shards = 1500
	for id in ["ow_mortarboard", "ow_halfglasses", "ow_scholar_scarf", "ow_book", "ow_skin_snowy"]:
		m.buy_item(id, 0, 1)
	check(m.forge("ow_page_whirl", 1) == "forged", "совёнку скован Вихрь страниц")
	m.buy_decor("owl", "near", "owl_nest", 0, 1)
	m.buy_decor("owl", "hang", "owl_lantern", 0, 1)
	var walls := _paid_room("owl")
	check(walls != "" and m.buy_room("owl", walls, 0, 1) == "bought", "совёнку куплен стиль комнаты")
	m.switch_mood("owl", 2)
	m.place("owl", "near", "owl_nest")
	var sh: int = m.shards
	var owned0: Array = m.owned.duplicate()
	var forged0: Array = m.forged.duplicate()
	var dec0: Array = m.decor_owned.duplicate()
	var room0: Array = m.room_owned.duplicate()
	var eq0: Dictionary = m.equipped.duplicate()
	var placed0: Dictionary = m.decor_placed.owl.duplicate()
	var style0: Dictionary = m.room_of("owl")
	check(not eq0.is_empty(), "совёнок в наряде: %s" % str(eq0))
	check(m.switch_hero("puppy") and m.hero == "puppy" and m.shards == sh, "смена на щенка — осколки не изменились (%d)" % m.shards)
	check(m.owned == owned0 and m.forged == forged0 and m.decor_owned == dec0 and m.room_owned == room0, "вещи, скованное, украшения и стили совёнка не тронуты")
	check(m.decor_placed.owl == placed0 and m.mood_of("owl") == 2 and m.room_of("owl") == style0 and not m.mood_empty("owl", 0), "дом совёнка: расстановка, настроения и стиль на месте")
	check(m.outfit_of("owl") == eq0, "наряд совёнка хранится у него")
	# новый друг — пустой
	check(m.equipped.is_empty() and m.outfit() == m.look("puppy") and m.collection_count() == 0, "щенок пустой: без наряда, коллекция 0 из %d" % Meta.collection_total("puppy"))
	check(m.decor_placed.puppy.is_empty() and m.room_of("puppy") == Catalog.default_room("puppy") and m.mood_of("puppy") == 0, "дом щенка пустой, стиль по умолчанию")
	check(m.legends_forged() == 0 and m.forge_status("ow_page_whirl", 99) == "done" and m.forge_status("pu_frisbee", 99) == "items", "кузница щенка: своих наград нет, вещей для рецепта нет")
	# щенку можно купить своё; совёнку это не мешает
	check(m.buy_item("pu_cap", 0, 1) == "bought" and m.is_equipped("pu_cap"), "щенок купил кепку и надел")
	check(m.shards == sh - 20, "потрачено 20 — только на щенка")
	check(m.buy_item("ow_quill", 0, 99) == "locked" and not m.equip("ow_book") and m.tap_item("ow_book") == "locked", "вещи совёнка щенку не купить и не надеть")


func _test_return() -> void:
	print("— возврат к прежнему другу: всё как было")
	var m := _rich_kitten()
	var sh: int = m.shards
	var eq0: Dictionary = m.equipped.duplicate()
	var owned0: Array = m.owned.duplicate()
	var forged0: Array = m.forged.duplicate()
	var dec0: Array = m.decor_owned.duplicate()
	var mood0: int = m.mood_of("kitten")
	var placed0: Dictionary = m.decor_placed.kitten.duplicate()
	var rot0: Dictionary = m.decor_rot.kitten.duplicate()
	var mood_a: Dictionary = m.mood_room("kitten", 0)
	check(eq0.get("companion", "") == "ki_teacup" and not eq0.has("back"), "котик в наряде: %s" % str(eq0))
	check(m.mood_of("kitten") == 1 and m.rot_at("kitten", "near") == 2, "у котика второе настроение, мышка повёрнута")
	m.switch_hero("puppy")
	m.buy_item("pu_cap", 0, 1)
	m.buy_item("pu_whistle", 0, 1)
	m.unequip("head")
	var pu_eq: Dictionary = m.equipped.duplicate()
	m.buy_decor("puppy", "near", "pup_ball", 0, 1)
	m.switch_hero("owl")
	m.switch_hero("axolotl")
	check(m.equipped.is_empty(), "аксолотль пустой")
	m.switch_hero("kitten")
	check(m.equipped == eq0 and m.is_equipped("ki_teacup") and m.outfit().get("companion", "") == "ki_teacup", "котик снова в своём наряде (и скованная чашка)")
	check(owned0.all(func(id): return m.owned.has(id)) and m.forged == forged0 and m.collection_count() == 6, "вещи и скованное котика на месте (6 из %d)" % Meta.collection_total("kitten"))
	check(dec0.all(func(id): return m.decor_owned.has(id)) and m.mood_of("kitten") == mood0 and m.decor_placed.kitten == placed0 and m.decor_rot.kitten == rot0, "украшения, настроение и повороты котика на месте")
	check(m.mood_room("kitten", 0) == mood_a, "первое настроение котика не тронуто")
	check(m.shards == sh - 20 - 30 - int(Meta.item("pup_ball").price), "осколки тратились только на покупки щенка, возвратов нет")
	check(m.outfit_of("puppy") == pu_eq and m.outfit_for("puppy").get("neck", "") == "pu_whistle", "наряд щенка хранится отдельно (свисток без кепки)")
	m.switch_hero("puppy")
	check(m.equipped == pu_eq and m.outfit_of("kitten") == eq0, "наряды по друзьям: у щенка — свой, у котика — свой")
	# все четверо прокачиваются
	var counts := {}
	for h in Meta.HEROES:
		m.switch_hero(h)
		counts[h] = m.collection_count()
	check(counts == {"owl": 0, "axolotl": 0, "puppy": 2, "kitten": 6}, "коллекции у каждого свои: котик 6, щенок 2, совёнок и аксолотль 0 %s" % str(counts))


func _test_filters() -> void:
	print("— всё «текущего друга» считается только по нему")
	var m := _rich_kitten()
	check(m.forge_status("ki_teacup", 99) == "done" and m.legends_forged() == 1, "котик: чашка скована, 1 легендарная")
	m.switch_hero("owl")
	check(m.collection_count() == 0 and m.legends_forged() == 0 and not m.forge_ready_any(99), "совёнок: 0 вещей, 0 легендарных, ковать нечего")
	check(m.forge_status("ki_teacup", 99) == "done" and m.forge_status("ki_clue_trail", 99) == "hero", "рецепты котика — чужие для совёнка")
	check(m.forge_status("ow_page_whirl", 99) == "items" and m.recipe_have("ow_page_whirl") == 0, "рецепт совёнка: 0 из 5 вещей")
	check(not m.is_equipped("ki_teacup") and m.outfit().is_empty(), "на совёнке нет вещей котика")


func _test_save() -> void:
	print("— сохранение: наряды по друзьям")
	var m := _rich_kitten()
	var ki_eq: Dictionary = m.equipped.duplicate()
	m.switch_hero("puppy")
	m.buy_item("pu_cap", 0, 1)
	m.switch_hero("owl")
	check(m.take_switch_hint(false) and not m.take_switch_hint(false), "подсказка — только один раз")
	var cfg := ConfigFile.new()
	m.save_to(cfg)
	var m2 := Meta.new()
	m2.load_from(cfg)
	check(m2.hero == "owl" and m2.migrated == 0 and m2.shards == m.shards and m2.owned == m.owned and m2.forged == m.forged, "после загрузки: друг, осколки, вещи всех друзей — те же")
	check(m2.equipped.is_empty() and m2.outfit_of("kitten") == ki_eq and m2.outfit_of("puppy") == {"head": "pu_cap"}, "наряды котика и щенка загрузились")
	check(m2.switch_hint_seen and not m2.take_switch_hint(false), "подсказка не покажется снова после перезапуска")
	m2.switch_hero("kitten")
	check(m2.equipped == ki_eq and m2.mood_of("kitten") == 1 and m2.placed_at("kitten", "near") == "kit_mouse", "котик после загрузки — наряд и дом как были")
	# испорченные наряды других друзей
	var bad := ConfigFile.new()
	bad.set_value("meta", "hero", "owl")
	bad.set_value("meta", "owned", ["pu_cap", "ki_yarn", "ow_book"])
	bad.set_value("meta", "equipped", {"companion": "ow_book"})
	bad.set_value("meta", "equipped_by_hero", {"puppy": {"head": "pu_cap", "neck": "ki_yarn"}, "kitten": {"head": "pu_cap"}, "dragon": {"head": "x"}, "owl": {"head": "pu_cap"}, "axolotl": 5})
	var m3 := Meta.new()
	m3.load_from(bad)
	check(m3.equipped == {"companion": "ow_book"} and m3.outfit_of("puppy") == {"head": "pu_cap"} and m3.outfit_of("kitten").is_empty() and m3.outfit_of("axolotl").is_empty(), "в нарядах — только свои купленные вещи на своих слотах")
	check(not m3.equipped_by_hero.has("dragon") and not m3.equipped_by_hero.has("owl"), "мусор отброшен")


func _test_migration() -> void:
	print("— старое сохранение (0.15): общий наряд — наряд текущего друга")
	var old := ConfigFile.new()
	old.set_value("progress", "max_level", 20)
	old.set_value("meta", "hero", "kitten")
	old.set_value("meta", "shards", 345)
	old.set_value("meta", "owned", ["ki_pompom_hat", "ki_bell_bow", "pu_cap"])
	old.set_value("meta", "forged", ["ki_teacup"])
	old.set_value("meta", "equipped", {"head": "ki_pompom_hat", "neck": "ki_bell_bow", "companion": "ki_teacup", "eyes": "pu_cap"})
	old.set_value("meta", "decor_owned", ["kit_yarn", "owl_nest"])
	old.set_value("meta", "decor_placed", {"kitten": {"floor_l": "kit_yarn"}, "owl": {"near": "owl_nest"}})
	old.set_value("meta", "notice_refund", 0)
	var m := Meta.new()
	m.load_from(old)
	check(m.shards == 345 and m.migrated == 0 and m.notice_refund == 0, "осколки те же (345): ничего не начислено и не отнято")
	check(m.equipped == {"head": "ki_pompom_hat", "neck": "ki_bell_bow", "companion": "ki_teacup"}, "общий наряд стал нарядом котика (кепка щенка отброшена)")
	check(m.owned.has("pu_cap") and m.owned.size() == 3 and m.forged == ["ki_teacup"], "вещи не отняты (кепка щенка осталась у щенка)")
	check(m.equipped_by_hero.is_empty() and m.outfit_of("puppy").is_empty(), "у остальных друзей наряда нет")
	check(m.decor_owned.size() == 2 and m.placed_at("owl", "near") == "owl_nest" and m.placed_at("kitten", "floor_l") == "kit_yarn", "украшения обоих домов на месте")
	check(not m.switch_hint_seen, "подсказка о своём гардеробе ещё покажется")
	# раньше получил возврат — осколки просто остаются, повторно ничего не начисляется
	var old2 := ConfigFile.new()
	old2.set_value("meta", "hero", "puppy")
	old2.set_value("meta", "shards", 900)
	old2.set_value("meta", "owned", [])
	var m2 := Meta.new()
	m2.load_from(old2)
	check(m2.shards == 900 and m2.owned.is_empty() and m2.migrated == 0, "игрок, получивший возврат раньше, сохраняет осколки")


func _test_texts() -> void:
	print("— тексты")
	check(I18n.missing_keys().is_empty(), "все ключи есть на en и ru")
	I18n.set_lang("ru")
	check(I18n.t("switch_hint") == "У каждого друга свой гардероб и свой дом — всё, что купишь, останется у него", "ru: подсказка")
	I18n.set_lang("en")
	check(I18n.t("switch_hint") == "Each buddy has their own wardrobe and home — everything you buy stays with them", "en: подсказка")
	I18n.set_lang("ru")
	var gone := true
	for k in ["switch_title", "switch_text", "switch_text_named", "switch_refund", "switch_keep", "switch_yes", "switch_done"]:
		if I18n.has_in("en", k) or I18n.has_in("ru", k):
			gone = false
	check(gone, "тексты окна возврата удалены")


func _test_ui() -> void:
	print("— экраны: смена мгновенная, подсказка один раз")
	var sc = g.screens
	var nu = g.notice_ui
	g.meta = _rich_kitten()
	g.max_level = 1
	g.stars = {}
	var sh: int = g.meta.shards
	var eq0: Dictionary = g.meta.equipped.duplicate()
	g._set_state(g.State.WARDROBE)
	nu.hint_t = 0.0
	sc.request_switch("puppy")
	check(g.meta.hero == "puppy" and g.meta.shards == sh and not nu.active(), "гардероб: смена сразу, без окна, осколки те же")
	check(nu.hint_showing() and nu.hint_kind == "puppy" and g.meta.switch_hint_seen, "первая смена — плашка-подсказка")
	check(sc.fade > 0.0, "переход: затемнение при смене")
	nu.node.draw.connect(func(): hint_drawn += 1)
	nu.update(0.1)
	check(nu.node.visible and not nu.active(), "плашка видна, касания не забирает")
	nu.update(2.5)
	check(nu.hint_showing(), "долгий кадр (строится 3D-дом) не прячет плашку сразу")
	for i in 40:
		nu.update(0.1)
	check(not nu.hint_showing(), "плашка исчезает через %.0f с" % nu.HINT_TIME)
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	check(cfg.get_value("meta", "hero", "") == "puppy" and cfg.get_value("meta", "switch_hint_seen", false) == true, "смена и показ подсказки сразу сохранены")
	sc.request_switch("kitten")
	check(g.meta.hero == "kitten" and g.meta.equipped == eq0 and not nu.hint_showing(), "обратно к котику: наряд на месте, подсказки больше нет")
	# экран выбора друга
	g._set_state(g.State.PICK_HERO)
	sc.pick_choice = "axolotl"
	sc.rects.clear()
	sc.rects["ok"] = Rect2(160, 946, 400, 112)
	sc.tap_pick(Vector2(360, 1000))
	check(g.meta.hero == "axolotl" and g.meta.shards == sh and not nu.active() and not nu.hint_showing() and g.state == g.State.HOME, "выбор друга: смена сразу, без окна и без повторной подсказки")
	# новичок: первый выбор — не смена, подсказки нет; первая смена потом — есть
	g.meta = Meta.new()
	g._set_state(g.State.PICK_HERO)
	sc.pick_choice = "owl"
	sc.rects.clear()
	sc.rects["ok"] = Rect2(160, 946, 400, 112)
	sc.tap_pick(Vector2(360, 1000))
	check(g.meta.hero == "owl" and not nu.hint_showing() and not g.meta.switch_hint_seen, "первый выбор друга — без подсказки")
	g._set_state(g.State.PICK_HERO)
	sc.pick_choice = "kitten"
	sc.rects.clear()
	sc.rects["ok"] = Rect2(160, 946, 400, 112)
	sc.tap_pick(Vector2(360, 1000))
	check(g.meta.hero == "kitten" and nu.hint_showing() and nu.hint_kind == "kitten", "первая смена на экране выбора — подсказка")
	nu.update(0.5)
	g.queue_redraw()
