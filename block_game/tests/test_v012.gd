extends SceneTree
## Тесты версии 0.12 / 0.12b: редкости, слоты «Спутник» и «Сияние», ГАРДЕРОБ ПО ГЕРОЯМ (у каждого
## друга 19 своих вещей: 3 набора × 5, 3 легендарные, супер-эксклюзив), Кристальная кузница по героям,
## нельзя надеть чужую вещь, смена друга с возвратом осколков (точная сумма, без двойного возврата,
## «Отмена» ничего не меняет), обновление старых сохранений, доход и путь до супер-награды,
## сохранение, примерка, рисование всех вещей на своих героях.
## Запуск: godot --headless --path block_game -s tests/test_v012.gd

var failed := 0
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const TryOn := preload("res://scripts/tryon.gd")
const Assist := preload("res://scripts/assist.gd")
const Rarity := preload("res://scripts/rarity.gd")
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

	_test_rarities()
	_test_catalogs()
	_test_forge_rules()
	_test_collection()
	_test_income(g)
	_test_switch(g)
	_test_migration(g)
	_test_save()
	_test_tryon()
	_test_forge_screen(g)
	g.free()  # до первого кадра: игра не успевает запустить музыку
	await _test_drawing()

	if had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)


func _test_rarities() -> void:
	print("— редкости")
	var ok := true
	for it in Meta.ITEMS:
		if not Meta.RARITIES.has(it.get("rarity", "")):
			ok = false
			printerr("    нет редкости: ", it.id)
	check(ok, "у каждой вещи гардероба есть редкость из пяти")
	var forge_only := true
	for it in Meta.ITEMS:
		if (it.rarity in ["legendary", "super"]) != it.get("forge", false):
			forge_only = false
		if it.get("forge", false) and it.has("price"):
			forge_only = false
	check(forge_only, "легендарные и супер-эксклюзив — только из кузницы, без цены в магазине")
	var cols_ok := true
	for r in Meta.RARITIES:
		if not Rarity.COL.has(r) or not Rarity.WIDTH.has(r) or not I18n.has("rarity_" + r):
			cols_ok = false
	check(cols_ok, "у каждой редкости есть цвет рамки, толщина и название")
	var dist := true
	var cs := []
	for r in Meta.RARITIES:
		cs.append(Rarity.col(r))
	for i in cs.size():
		for j in range(i + 1, cs.size()):
			var a: Color = cs[i]
			var b: Color = cs[j]
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.35:
				dist = false
	check(dist, "цвета рамок редкостей хорошо различаются")


## 0.12b: у каждого героя свой каталог
func _test_catalogs() -> void:
	print("— каталоги по героям")
	check(Meta.SLOTS.has("companion") and Meta.SLOTS.has("aura"), "в гардеробе есть слоты «Спутник» и «Сияние»")
	check(Meta.ITEMS.size() == 76, "всего вещей 76 (19 × 4 друга)")
	check(not Meta.ITEMS.any(func(it): return not it.has("hero") or not Meta.HEROES.has(it.hero)), "общих вещей нет: у каждой вещи свой друг")
	check(not Meta.ITEMS.any(func(it): return it.id == "wings_cascado") and Meta.item("wings_cascado").is_empty(), "Крыльев Каскада больше нет")
	for h in Meta.HEROES:
		var its: Array = Meta.hero_items(h)
		var sets: Array = Meta.hero_sets(h)
		var buy := its.filter(func(it): return not it.get("forge", false))
		var leg := its.filter(func(it): return it.rarity == "legendary")
		var sup := its.filter(func(it): return it.rarity == "super")
		check(its.size() == 19 and buy.size() == 15 and leg.size() == 3 and sup.size() == 1, "%s: 19 вещей — 15 в наборах, 3 легендарные, 1 супер" % h)
		check(sets.size() == 3 and sets.all(func(n): return Meta.set_items(n).size() == 5), "%s: 3 набора по 5 вещей" % h)
		var halls: Array = sets.map(func(n): return int(Meta.set_info(n).hall))
		check(halls == [0, 3, 5], "%s: наборы открываются с начала / после зала 3 / после зала 5" % h)
		var skins := its.filter(func(it): return it.slot == "skin").size()
		check(skins >= 1 and skins <= 3, "%s: окрасок 1–3 (%d)" % [h, skins])
		var slots_ok := true
		for sl in Meta.SLOTS:
			if Meta.items_in(sl, h).is_empty():
				slots_ok = false
		check(slots_ok, "%s: в каждой вкладке гардероба есть вещи" % h)
		var rar_ok := true
		for n in sets:
			var rs: Array = Meta.set_items(n).map(func(it): return it.rarity)
			if rs.count("common") != 2 or rs.count("rare") != 2 or rs.count("epic") != 1:
				rar_ok = false
		check(rar_ok, "%s: в наборе 2 обычные, 2 редкие, 1 эпическая" % h)
		# рецепты: награда набора — из всех 5 его вещей; супер — из трёх легендарных
		var rec_ok := true
		for n in sets:
			var rc: Dictionary = Meta.recipe_for_set(n)
			var ids: Array = Meta.set_items(n).map(func(it): return it.id)
			if rc.is_empty() or rc.needs != ids or rc.hero != h or Meta.item(rc.id).rarity != "legendary" or int(rc.hall) != int(Meta.set_info(n).hall):
				rec_ok = false
		var sr: Dictionary = Meta.super_recipe(h)
		check(rec_ok, "%s: рецепт награды набора — все 5 вещей набора" % h)
		var leg_ids: Array = leg.map(func(it): return it.id)
		check(sr.needs == leg_ids and Meta.item(sr.id).rarity == "super" and Meta.item(sr.id).slot == "aura", "%s: супер-эксклюзив — из трёх легендарных" % h)
		check(int(buy.map(func(it): return int(it.price)).min()) == 20, "%s: первая вещь — 20 осколков (хватает после подарка новичку)" % h)
	check(Meta.SETS.size() == 12 and Meta.RECIPES.size() == 16, "наборов 12, рецептов 16")
	var ids := {}
	var uniq := true
	for it in Meta.ITEMS + Meta.DECOR:
		if ids.has(it.id):
			uniq = false
		ids[it.id] = true
	check(uniq, "id всех вещей и украшений уникальны")
	var tr_ok := true
	for l in I18n.LANGS:
		for st in Meta.SETS:
			if not I18n.STR[l].has("set_" + st.id):
				tr_ok = false
		for it in Meta.ITEMS:
			if not I18n.STR[l].has("item_" + it.id):
				tr_ok = false
		for k in ["switch_title", "switch_text", "switch_refund", "switch_keep", "switch_yes", "switch_done", "migrate_title", "migrate_text", "migrate_refund", "forge_say_super", "forge_legends"]:
			if not I18n.STR[l].has(k):
				tr_ok = false
		for h in Meta.HEROES:
			if not I18n.STR[l].has("hero_gen_" + h) or not I18n.STR[l].has("forge_say_start_" + h):
				tr_ok = false
	check(tr_ok, "названия вещей, наборов и окон 0.12b — на обоих языках")
	I18n.set_lang("ru")
	check(Meta.item_name("ow_stargazer") == "Мантия звездочёта" and Meta.item_name("ax_abyssal") == "Сияние глубин" and Meta.item_name("pu_hero") == "Пёс-герой" and Meta.item_name("ki_starry", "kitten", "boy") == "Звёздный кот" and Meta.item_name("ki_starry", "kitten", "girl") == "Звёздная кошка", "супер-награды: Мантия звездочёта, Сияние глубин, Пёс-герой, Звёздный кот / Звёздная кошка (0.13: по полу)")
	# чужую вещь нельзя купить и надеть
	var m = Meta.new()
	m.set_hero("puppy")
	m.shards = 1000
	check(m.buy_item("ki_pompom_hat", 0, 99) == "locked" and not m.is_owned("ki_pompom_hat"), "щенку не купить шапочку котика")
	m.owned.append("ki_pompom_hat")  # даже если вещь как-то оказалась у игрока
	check(not m.equip("ki_pompom_hat") and m.tap_item("ki_pompom_hat") == "locked" and m.outfit().is_empty(), "чужую вещь не надеть")
	check(m.buy_item("pu_cap", 0, 1) == "bought" and m.is_equipped("pu_cap"), "свою — можно")
	# супер-эксклюзив занимает свои слоты
	var o := {"head": "ow_mortarboard", "eyes": "ow_halfglasses", "back": "ow_lantern"}
	Meta.put_on(o, "ow_stargazer")
	check(o == {"eyes": "ow_halfglasses", "aura": "ow_stargazer"}, "Мантия звездочёта снимает шапку и фонарь (голова, спина)")
	Meta.put_on(o, "ow_quill")
	check(o == {"eyes": "ow_halfglasses", "head": "ow_quill"}, "вещь на голову снимает Мантию звездочёта")


func _test_forge_rules() -> void:
	print("— кузница по героям")
	var m = Meta.new()
	m.set_hero("axolotl")
	var r1: Dictionary = Meta.recipe("ax_seahorse")
	check(r1.needs == ["ax_starfish", "ax_dive_mask", "ax_coral_beads", "ax_bubble_pet", "ax_coral_tiara"] and r1.cost == 120, "рецепт конька-стража: 5 вещей «Кораллового рифа» + 120")
	check(m.forge_status("ax_seahorse", 1) == "items" and m.forge_status("ax_wave_cape", 1) == "hall", "набор 1 — с начала, набор 2 — после зала 3")
	check(m.forge_status("ow_page_whirl", 99) == "hero" and m.forge("ow_page_whirl", 99) == "hero", "рецепт другого друга не куётся")
	m.shards = 1000
	check(m.forge("ax_seahorse", 1) == "items", "без всех вещей сковать нельзя")
	m.owned.append_array(["ax_starfish", "ax_dive_mask", "ax_coral_beads", "ax_bubble_pet"])
	check(m.forge("ax_seahorse", 1) == "items" and m.recipe_have("ax_seahorse") == 4, "четырёх вещей из пяти мало")
	m.owned.append("ax_coral_tiara")
	m.shards = 119
	check(m.forge_status("ax_seahorse", 1) == "poor" and m.forge("ax_seahorse", 1) == "poor", "без осколков (119 из 120) сковать нельзя")
	check(m.recipe_complete("ax_seahorse", 1) and not m.forge_ready_any(1), "всё собрано, но осколков мало — метки «Можно сковать!» нет")
	m.shards = 140
	check(m.forge_ready_any(1), "хватает — метка «Можно сковать!»")
	check(m.forge("ax_seahorse", 1) == "forged" and m.shards == 20, "сковано, списано 120")
	check(m.owned.size() == 5, "ковка не тратит вещи — они остаются у игрока")
	check(m.forged == ["ax_seahorse"] and m.equipped.get("companion", "") == "ax_seahorse", "награда у игрока и сразу надета")
	check(m.forge("ax_seahorse", 1) == "done" and m.shards == 20, "второй раз не куётся")
	check(m.buy("ax_wave_cape", 999, 999) == Meta.Buy.LOCKED and m.tap_item("ax_wave_cape") == "try", "награду кузницы нельзя купить, но можно примерить")
	# метка «Можно сковать!» — только по рецептам текущего героя
	var k = Meta.new()
	k.set_hero("kitten")
	k.shards = 9999
	k.owned.append_array(Meta.set_items(Meta.hero_sets("owl")[0]).map(func(it): return it.id))
	check(not k.forge_ready_any(99), "вещи совёнка не включают метку у котика")
	# супер-эксклюзив
	var w = Meta.new()
	w.set_hero("owl")
	w.shards = 10000
	w.owned.append_array(Meta.hero_items("owl").filter(func(it): return it.has("price")).map(func(it): return it.id))
	check(w.forge("ow_stargazer", 999) == "items", "супер нельзя сковать без трёх легендарных")
	check(w.forge("ow_page_whirl", 999) == "forged" and w.forge("ow_skin_starry", 999) == "forged", "две легендарные")
	check(w.forge("ow_stargazer", 999) == "items" and w.legends_forged() == 2, "с двумя легендарными — нельзя")
	check(w.forge("ow_comet", 999) == "forged" and w.legends_forged() == 3, "третья легендарная")
	check(w.forge_status("ow_stargazer", 50) == "hall", "супер — только после зала 5")
	check(w.forge("ow_stargazer", 999) == "forged" and w.equipped.aura == "ow_stargazer", "три легендарные + 450 — Мантия звездочёта скована и надета")
	check(w.forged.size() == 4 and w.is_owned("ow_comet"), "легендарные не тратятся на супер-награду")
	# цель «до следующей вещи» — только вещи своего героя и не награды кузницы
	var a = Meta.new()
	a.set_hero("owl")
	var gl: Dictionary = Assist.next_goal(a, "owl", 0, 1)
	check(Meta.owner_of(gl.id) == "owl" or gl.home == "owl", "цель на главном — вещь или украшение своего друга (%s)" % gl.id)
	a.owned.append_array(Meta.hero_items("owl").filter(func(it): return it.has("price")).map(func(it): return it.id))
	check(Assist.next_goal(a, "owl", 999, 999).get("slot", "home") == "home", "цель на главном — не награда кузницы (её не купить)")


func _test_collection() -> void:
	print("— коллекция")
	var m = Meta.new()
	m.set_hero("puppy")
	check(Meta.collection_total("puppy") == 19, "в коллекции друга 19 вещей")
	check(m.collection_count() == 0, "у нового игрока 0")
	m.owned.append_array(["pu_cap", "pu_whistle"])
	m.decor_owned.append("pup_ball")
	check(m.collection_count() == 2, "украшения дома в коллекцию гардероба не входят (2)")
	m.forged.append("pu_frisbee")
	check(m.collection_count() == 3, "скованные считаются (3)")
	check(I18n.t("collection") % [3, 19] == "Коллекция: 3 из 19", "подпись счётчика: «Коллекция: 3 из 19»")


func _test_income(g) -> void:
	print("— доход и путь до супер-награды")
	check(Meta.win_reward(true, 0, 0, 0, 1).win == 10 and Meta.win_reward(true, 0, 0, 0, 10).win == 10, "зал 1: первая победа 10")
	check(Meta.win_reward(true, 0, 0, 0, 11).win == 12 and Meta.win_reward(true, 0, 0, 0, 21).win == 14, "зал 2 — 12, зал 3 — 14")
	check(Meta.win_reward(true, 0, 0, 0, 100).win == 28 and Meta.win_reward(true, 0, 0, 0, 250).win == 28, "зал 10 — 28, в глубинах — как в зале 10")
	check(Meta.win_reward(false, 3, 3, 0, 95).win == Meta.WIN_REPEAT, "повторная победа — по-прежнему +3")
	g.meta = Meta.new()
	g.stars = {}
	g.assist.gift_given = true
	g.start_level(21)
	g.pieces_used = 999
	g._win()
	check(g.last_reward.win == 14 and g.last_reward.first, "победа на уровне 21 (зал 3): +14 за первую победу")
	# путь одного друга до супер-награды: 15 вещей + ковка трёх легендарных + ковка супер
	for h in Meta.HEROES:
		var path := 0
		for it in Meta.hero_items(h):
			path += int(it.get("price", 0))
		for r in Meta.RECIPES:
			if r.hero == h:
				path += int(r.cost)
		check(path == 2395, "%s: путь до супер-награды — вещи 1395 + ковка 1000 = 2395 (%d)" % [h, path])
	var path := 2395
	# доход за первые прохождения L уровней при s звёздах в среднем
	var inc := func(L: int, s: float) -> float:
		var n := 0.0
		for lv in range(1, L + 1):
			n += Meta.win_reward(true, 0, 0, 0, lv).win + s * Meta.PER_NEW_STAR
		return n
	check(inc.call(80, 2.0) < path and inc.call(90, 2.0) >= path, "при 2 звёздах в среднем путь — между 80 и 90 уровнями (%d / %d)" % [inc.call(80, 2.0), inc.call(90, 2.0)])
	check(inc.call(90, 1.5) < path and inc.call(100, 1.5) >= path, "при 1,5 звезды — между 90 и 100 уровнями")
	check(inc.call(100, 1.0) >= path, "даже при 1 звезде — укладывается в 100 уровней (%d)" % inc.call(100, 1.0))
	# набор 3 открывается после зала 5: на уровнях 51–100 хватает на него, его ковку и супер
	var late := 0.0
	for lv in range(51, 101):
		late += Meta.win_reward(true, 0, 0, 0, lv).win + 2.0 * Meta.PER_NEW_STAR
	var tail := 0
	for it in Meta.set_items(Meta.hero_sets("owl")[2]):
		tail += int(it.price)
	tail += int(Meta.recipe_for_set(Meta.hero_sets("owl")[2]).cost) + int(Meta.super_recipe("owl").cost)
	check(late >= tail, "уровни 51–100 (%d) покрывают набор 3, его ковку и супер (%d)" % [late, tail])


## 0.12b: смена друга — потраченное на прежнего возвращается осколками
func _test_switch(g) -> void:
	print("— смена друга с возвратом")
	var m = Meta.new()
	check(not m.switch_asks("owl") and m.switch_hero("owl") == 0 and m.hero == "owl", "первый выбор новичка — без окна и без возврата")
	m.shards = 1000
	for id in ["ow_mortarboard", "ow_halfglasses", "ow_scholar_scarf", "ow_book", "ow_skin_snowy"]:
		m.buy_item(id, 0, 1)
	check(m.forge("ow_page_whirl", 1) == "forged", "сковано: Вихрь страниц")
	m.buy_decor("owl", "near", "owl_nest", 0, 1)
	m.buy_decor("owl", "hang", "owl_lantern", 0, 1)
	m.buy_decor("puppy", "near", "pup_ball", 0, 1)  # украшение другого дома остаётся
	var spent := 290 + 120 + 10 + 15
	check(m.shards == 1000 - spent - 10, "потрачено 445 на совёнка и 10 на дом щенка (%d)" % m.shards)
	check(m.refund_value("owl") == spent and m.switch_asks("kitten"), "вернётся ровно 435: вещи 290 + ковка 120 + украшения 25")
	var before: int = m.shards
	check(m.switch_hero("kitten") == spent and m.shards == before + spent and m.hero == "kitten", "смена на котика: +435 осколков")
	check(m.owned.is_empty() and m.forged.is_empty() and m.equipped.is_empty() and m.decor_placed.owl.is_empty(), "у совёнка сняты вещи, наряд, скованное и украшения дома")
	check(m.decor_owned == ["pup_ball"] and m.placed_at("puppy", "near") == "pup_ball", "украшения другого дома не тронуты")
	check(not m.switch_asks("owl") and m.switch_hero("owl") == 0 and m.shards == before + spent, "обратно на совёнка — котик ничего не купил, второго возврата нет")
	check(m.collection_count() == 0, "совёнок наряжается заново")
	check(m.switch_hero("owl") == 0 and m.switch_hero("dragon") == -1, "тот же друг / неизвестный — ничего")
	# через экран: окно подтверждения, «Отмена» ничего не меняет
	if g.screens == null:
		g.screens = load("res://scripts/screens.gd").new(g)
	if g.notice_ui == null:
		g.notice_ui = load("res://scripts/notice_ui.gd").new(g)
	var w = Meta.new()
	w.switch_hero("puppy")
	w.shards = 500
	w.buy_item("pu_cap", 0, 1)
	w.buy_item("pu_whistle", 0, 1)
	g.meta = w
	g.max_level = 1
	g.stars = {}
	g._set_state(g.State.WARDROBE)
	g.screens.request_switch("axolotl")
	check(g.notice_ui.active() and g.notice_ui.mode == "switch" and g.notice_ui.refund == 50 and w.hero == "puppy", "в гардеробе — окно «Сменить друга?», вернётся 50")
	g.notice_ui.t = 1.0
	g.notice_ui.back()
	check(not g.notice_ui.active() and w.hero == "puppy" and w.shards == 450 and w.owned.size() == 2 and w.is_equipped("pu_whistle"), "«Отмена» — ничего не изменилось")
	g.screens.request_switch("axolotl")
	g.notice_ui.t = 1.0
	g.notice_ui.confirm()
	check(not g.notice_ui.active() and w.hero == "axolotl" and w.shards == 500 and w.owned.is_empty(), "«Сменить» — аксолотль, 50 осколков вернулись")
	g.screens.request_switch("kitten")
	check(not g.notice_ui.active() and w.hero == "kitten" and w.shards == 500, "нечего снимать — смена сразу, без окна")
	I18n.set_lang("ru")
	check(I18n.t("switch_text") % I18n.t("hero_gen_owl") == "Вещи и украшения Совёнка будут сняты" and I18n.t("switch_refund") % [435, I18n.forms("shards_forms", 435)] == "Вернётся 435 осколков", "текст окна по-русски")
	I18n.set_lang("en")
	check(I18n.t("switch_text") % I18n.t("hero_gen_puppy") == "Puppy's items and decorations will be taken off", "текст окна по-английски")
	I18n.set_lang("ru")


## 0.12b: старые сохранения (0.6–0.12) — общие вещи возвращаются осколками, один раз сообщение
func _test_migration(g) -> void:
	print("— обновление старого сохранения")
	var old := ConfigFile.new()
	old.set_value("progress", "max_level", 33)
	old.set_value("progress", "stars", {1: 3, 2: 3})
	old.set_value("meta", "hero", "owl")
	old.set_value("meta", "shards", 100)
	old.set_value("meta", "owned", ["bow", "crown", "firefly", "nope"])
	old.set_value("meta", "forged", ["firefly_crown", "wings_cascado"])
	old.set_value("meta", "equipped", {"head": "crown", "aura": "wings_cascado"})
	old.set_value("meta", "decor_owned", ["owl_nest"])
	old.set_value("meta", "decor_placed", {"owl": {"near": "owl_nest"}})
	var m = Meta.new()
	m.load_from(old)
	var back := 20 + 150 + 80 + 50 + 300
	check(m.migrated == back and m.shards == 100 + back and m.notice_refund == back, "вернулось %d: вещи 250 + ковка 350" % back)
	check(m.owned.is_empty() and m.forged.is_empty() and m.equipped.is_empty() and m.hero == "owl", "старые вещи сняты, друг тот же")
	check(m.decor_owned == ["owl_nest"] and m.placed_at("owl", "near") == "owl_nest", "украшения домов не тронуты")
	var cfg := ConfigFile.new()
	m.save_to(cfg)
	var m2 = Meta.new()
	m2.load_from(cfg)
	check(m2.migrated == 0 and m2.shards == 100 + back and m2.notice_refund == back, "после сохранения второго возврата нет, сообщение ещё ждёт")
	# через игру: сразу сохраняется, сообщение один раз
	old.save(SAVE)
	g.meta = Meta.new()
	g._load()
	check(g.meta.shards == 100 + back and g.meta.owned.is_empty(), "игра: старое сохранение обновлено")
	var cfg2 := ConfigFile.new()
	cfg2.load(SAVE)
	check(cfg2.get_value("meta", "owned", ["x"]) == [] and int(cfg2.get_value("meta", "shards", 0)) == 100 + back, "игра: обновлённое сохранение сразу записано")
	if g.notice_ui == null:
		g.notice_ui = load("res://scripts/notice_ui.gd").new(g)
	g._set_state(g.State.HOME)
	g.notice_ui.mode = ""
	g.notice_ui.update(0.1)
	check(g.notice_ui.mode == "migrated" and g.notice_ui.refund == back, "на главном экране — «Гардероб обновлён!»")
	g.notice_ui.back()
	g.notice_ui.update(0.1)
	check(not g.notice_ui.active() and g.meta.notice_refund == 0, "сообщение закрыто и больше не показывается")
	g.meta = Meta.new()
	g._load()
	check(g.meta.notice_refund == 0 and g.meta.shards == 100 + back, "после перезапуска — ни сообщения, ни второго возврата")


func _test_save() -> void:
	print("— сохранение")
	var m = Meta.new()
	m.set_hero("kitten")
	m.shards = 77
	m.owned.append_array(["ki_yarn", "ki_bell_bow"])
	m.forged.append("ki_teacup")
	m.equip("ki_bell_bow")
	m.equip("ki_teacup")
	var cfg := ConfigFile.new()
	m.save_to(cfg)
	var m2 = Meta.new()
	m2.load_from(cfg)
	check(m2.forged == ["ki_teacup"] and m2.owned.size() == 2 and m2.migrated == 0, "скованные вещи сохраняются отдельно (поле forged)")
	check(m2.equipped.get("companion", "") == "ki_teacup" and m2.equipped.get("neck", "") == "ki_bell_bow", "надетые награда и бант восстанавливаются")
	# подделка: награда кузницы в купленных, мусор в forged
	var bad := ConfigFile.new()
	bad.set_value("meta", "hero", "kitten")
	bad.set_value("meta", "owned", ["ki_teacup", "ki_yarn"])
	bad.set_value("meta", "forged", ["ki_yarn", "nope", "ki_teacup", 5])
	bad.set_value("meta", "equipped", {"companion": "ki_teacup", "aura": "ki_starry"})
	var m4 = Meta.new()
	m4.load_from(bad)
	check(m4.owned == ["ki_yarn"] and m4.forged == ["ki_teacup"], "награда кузницы не попадает в «купленные», мусор в forged отброшен")
	check(m4.equipped.get("companion", "") == "ki_teacup" and not m4.equipped.has("aura"), "надеть можно только то, что есть")


func _test_tryon() -> void:
	print("— примерка")
	var m = Meta.new()
	m.set_hero("owl")
	m.shards = 500
	var tr = TryOn.new()
	tr.start_item("ow_book")
	check(tr.outfit(m).get("companion", "") == "ow_book", "примерка спутника — в слоте «спутник»")
	check(tr.confirm(m, 0, 1) == "bought" and m.equipped.companion == "ow_book" and not tr.active(), "покупка спутника и сразу надет")
	tr.start_item("ow_aura_starfall")
	check(tr.status(m, 0, 50) == "locked" and tr.status(m, 0, 51) == "ok", "вещь набора 3: до зала 5 закрыта, после — можно купить")
	tr.start_item("ax_starfish")
	check(tr.status(m, 0, 99) == "locked", "вещь другого друга — не купить")
	m.owned.append("ow_mortarboard")
	m.equip("ow_mortarboard")
	tr.start_item("ow_stargazer")
	check(tr.outfit(m).get("aura", "") == "ow_stargazer" and not tr.outfit(m).has("head") and m.equipped.head == "ow_mortarboard", "примерка супер-награды: шапочка на время снята, наряд не тронут")
	check(tr.status(m, 999, 999) == "locked" and tr.confirm(m, 999, 999) == "locked" and not m.is_owned("ow_stargazer"), "супер-награду можно примерить, но не купить")


func _test_forge_screen(g) -> void:
	print("— экран кузницы")
	if g.screens == null:
		g.screens = load("res://scripts/screens.gd").new(g)
	if g.forge_ui == null:
		g.forge_ui = load("res://scripts/forge_ui.gd").new(g)
	var f = g.forge_ui
	g.meta = Meta.new()
	g.meta.set_hero("puppy")
	g.max_level = 1
	g.meta.shards = 130
	g.meta.owned.append_array(Meta.set_items(Meta.hero_sets("puppy")[0]).map(func(it): return it.id))
	f.open()
	check(g.state == g.State.FORGE, "кузница открывается")
	check(f.kind() == "puppy" and Meta.super_recipe(f.kind()).id == "pu_hero", "кузница щенка: главная цель — Пёс-герой")
	f._try_forge("pu_frisbee", Meta.hero_sets("puppy")[0])
	check(f.anim_id == "pu_frisbee" and g.meta.forged.has("pu_frisbee") and g.meta.shards == 10, "«Сковать» запускает анимацию, награда сохранена")
	f.update(1.0)
	check(f.anim_id != "" and not f.result, "через 1 с анимация ещё идёт")
	f.tap(Vector2(360, 640))
	check(f.anim_id == "" and f.result, "касание пропускает анимацию — показ награды на герое")
	f.update(1.0)
	f.tap(Vector2(10, 10))
	check(not f.result, "касание закрывает показ")
	f.start_try("pu_hero")
	check(f.try_id == "pu_hero", "примерка супер-награды")
	f.update(5.2)
	check(f.try_id == "", "примерка заканчивается сама через 5 секунд")
	f._try_forge("pu_petal_rainbow", Meta.hero_sets("puppy")[1])
	check(f.anim_id == "" and not g.meta.forged.has("pu_petal_rainbow"), "без зала 3 и вещей — не куётся")
	f._try_forge("ow_page_whirl", 1)
	check(f.anim_id == "" and not g.meta.forged.has("ow_page_whirl"), "рецепт другого друга не куётся")
	f.back()
	check(g.state == g.State.HOME, "«Назад» — на главный экран")


## Рисование: все вещи на своих героях, аватарки и значки — без ошибок скрипта
func _test_drawing() -> void:
	print("— рисование")
	var Hero = load("res://scripts/hero.gd")
	var node := Node2D.new()
	root.add_child(node)
	node.draw.connect(func():
		var h = Hero.new()
		for kind in Meta.HEROES:
			var full := {}
			for it in Meta.hero_items(kind):
				var o := {it.slot: it.id}
				h.draw(node, kind, Vector2(360, 600), 1.0, o, 1.7, 0.3)
				h.draw(node, kind, Vector2(360, 600), 1.0, o, 1.7, 0.3, true)
				h.draw_item_icon(node, it.id, it.slot, kind, Vector2(100, 100), 120, 1.7)
				h.draw_item_icon(node, it.id, it.slot, kind, Vector2(100, 100), 60, 0.0)
				Meta.put_on(full, it.id)
			h.draw(node, kind, Vector2(360, 600), 1.0, full, 2.3, 0.5)
			h.draw_avatar(node, kind, Vector2(200, 200), 80, full, 2.3, Color.WHITE, 0.4)
		h.draw_master(node, Vector2(100, 300), 0.6, 1.0)
		drawn += 1)
	node.queue_redraw()
	for i in 4:
		await process_frame
	if drawn > 0:
		check(true, "все вещи нарисованы на своих героях и значками без ошибок")
	else:
		print("  (рисование в режиме без экрана пропущено)")
	node.free()
