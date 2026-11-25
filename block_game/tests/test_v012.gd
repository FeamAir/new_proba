extends SceneTree
## Тесты версии 0.12: редкости, новые слоты (спутник, сияние), пять наборов, Кристальная кузница
## (рецепты, ковка не тратит вещи, супер-эксклюзив только после 5 легендарных), счётчик коллекции,
## доход по залам и расчёт пути до Крыльев Каскада, сохранение, примерка, рисование всех вещей.
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
	_test_slots_and_sets()
	_test_forge_rules()
	_test_collection()
	_test_income(g)
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
	var want := {"common": ["bow", "cap", "sunglasses", "crystal_glasses", "bowtie", "scarf", "backpack"],
		"rare": ["miner", "wreath", "monocle", "necklace", "skin_mint", "skin_moon"],
		"epic": ["crown", "cape", "skin_gold"]}
	var old_ok := true
	for r in want:
		for id in want[r]:
			if Meta.rarity(id) != r:
				old_ok = false
				printerr("    ", id, ": ", Meta.rarity(id), " вместо ", r)
	check(old_ok, "16 старых вещей получили редкости по проекту (обычные / редкие / эпические)")
	var leg := Meta.ITEMS.filter(func(it): return it.rarity == "legendary").map(func(it): return it.id)
	leg.sort()
	check(leg == ["firefly_crown", "fullmoon_mantle", "mountain_heart", "seahorse", "skin_constellation"], "легендарных — 5, по одной на набор")
	var sup := Meta.ITEMS.filter(func(it): return it.rarity == "super")
	check(sup.size() == 1 and sup[0].id == "wings_cascado" and sup[0].slot == "aura", "супер-эксклюзив один — Крылья Каскада (сияние)")
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


func _test_slots_and_sets() -> void:
	print("— новые слоты и наборы")
	check(Meta.SLOTS.has("companion") and Meta.SLOTS.has("aura"), "в гардеробе есть слоты «Спутник» и «Сияние»")
	check(I18n.t("slot_companion") == "Спутник" and I18n.t("slot_aura") == "Сияние", "названия новых вкладок по-русски")
	check(Meta.items_in("companion").size() == 6 and Meta.items_in("aura").size() == 6, "спутников 6 (5 + конёк-страж), сияний 6 (5 + Крылья)")
	check(Meta.SETS.size() == 5, "наборов пять")
	var sizes := []
	for n in range(1, 6):
		sizes.append(Meta.set_items(n).size())
	check(sizes == [8, 8, 8, 8, 7], "в наборах 8/8/8/8/7 вещей (в 5-м рецепте ещё корона) (%s)" % [sizes])
	var hall_ok := true
	for n in range(1, 6):
		for it in Meta.set_items(n):
			if int(it.hall) != n:
				hall_ok = false
			# закрыты до прохождения зала N, открыты после
			if Meta.lock_reason(it.id, 999, n * Meta.HALL_SIZE) == "" or Meta.lock_reason(it.id, 999, n * Meta.HALL_SIZE + 1) != "":
				hall_ok = false
	check(hall_ok, "вещи набора N видны с замком «пройди зал N» и открываются после зала N")
	var prices := {"acorn_cap": 30, "leaf_scarf": 35, "daisy_glasses": 70, "firefly": 80, "dragonfly_wings": 90, "skin_moss": 150, "bluebell_hat": 160, "aura_pollen": 180,
		"shell_clip": 40, "dive_mask": 45, "pearl_necklace": 90, "bubble_pet": 90, "fin_cape": 100, "skin_pearl": 180, "coral_tiara": 180, "aura_bubbles": 200,
		"moth_tie": 40, "masquerade": 45, "top_hat": 100, "moon_moth": 100, "ball_cloak": 110, "star_lorgnette": 180, "skin_midnight": 200, "aura_moonbeam": 220,
		"flight_goggles": 50, "comet_scarf": 50, "mini_planet": 110, "space_helmet": 120, "rocket_pack": 120, "star_compass": 200, "skin_nebula": 220, "aura_starfall": 240,
		"amethyst_monocle": 60, "ermine_collar": 60, "float_crystal": 130, "crystal_diadem": 130, "royal_mantle": 140, "skin_amethyst": 240, "aura_facets": 260}
	var pr_ok := true
	for id in prices:
		if int(Meta.item(id).get("price", -1)) != prices[id]:
			pr_ok = false
			printerr("    цена ", id)
	check(pr_ok, "цены 39 вещей наборов — как в проекте сценариста")
	var ids := {}
	var uniq := true
	for it in Meta.ITEMS + Meta.DECOR:
		if ids.has(it.id):
			uniq = false
		ids[it.id] = true
	check(uniq, "id всех вещей и украшений уникальны")
	var en_ok := true
	for n in range(1, 6):
		for l in I18n.LANGS:
			if not I18n.STR[l].has("set_" + Meta.SETS[n - 1].id):
				en_ok = false
	check(en_ok, "названия наборов есть на обоих языках")


func _test_forge_rules() -> void:
	print("— кузница: рецепты")
	var m = Meta.new()
	var r1: Dictionary = Meta.recipe("firefly_crown")
	check(r1.needs == ["leaf_scarf", "daisy_glasses", "firefly"] and r1.cost == 50, "рецепт Венца: листик-шарф + очки-ромашки + светлячок + 50")
	check(Meta.recipe("mountain_heart").needs.has("crown"), "в рецепт «Сердца горы» входит корона")
	check(m.forge_status("firefly_crown", 1) == "hall", "до прохождения зала 1 — рецепт закрыт")
	check(m.forge("firefly_crown", 1) == "hall" and m.forged.is_empty(), "без зала сковать нельзя")
	m.shards = 1000
	check(m.forge("firefly_crown", 11) == "items", "без всех вещей сковать нельзя")
	m.owned.append_array(["leaf_scarf", "daisy_glasses"])
	check(m.forge("firefly_crown", 11) == "items" and m.recipe_have("firefly_crown") == 2, "двух вещей из трёх мало")
	m.owned.append("firefly")
	m.shards = 49
	check(m.forge_status("firefly_crown", 11) == "poor" and m.forge("firefly_crown", 11) == "poor", "без осколков (49 из 50) сковать нельзя")
	check(m.recipe_complete("firefly_crown", 11) and not m.forge_ready_any(11), "всё собрано, но осколков мало — силуэт пульсирует, метки «Можно сковать!» нет")
	m.shards = 70
	check(m.forge_ready_any(11), "хватает — метка «Можно сковать!»")
	check(m.forge("firefly_crown", 11) == "forged", "сковано")
	check(m.shards == 20, "списаны только осколки (70 - 50 = 20)")
	check(m.owned.has("leaf_scarf") and m.owned.has("daisy_glasses") and m.owned.has("firefly"), "ковка не тратит вещи — они остаются у игрока")
	check(m.forged == ["firefly_crown"] and m.is_owned("firefly_crown") and m.equipped.get("head", "") == "firefly_crown", "награда у игрока и сразу надета")
	check(m.forge("firefly_crown", 11) == "done" and m.shards == 20, "второй раз не куётся и осколки не берутся")
	check(m.buy("seahorse", 999, 999) == Meta.Buy.LOCKED and m.buy_item("seahorse", 999, 999) == "locked", "награду кузницы нельзя купить")
	check(m.tap_item("seahorse") == "try", "нескованную награду можно примерить")
	m.unequip("head")
	check(m.tap_item("firefly_crown") == "on" and m.equipped.head == "firefly_crown", "скованную — надеть из гардероба")
	# супер-эксклюзив
	var w = Meta.new()
	w.shards = 10000
	w.owned.append_array(Meta.ITEMS.filter(func(it): return it.has("price")).map(func(it): return it.id))
	check(w.forge("wings_cascado", 999) == "items", "Крылья нельзя сковать, пока нет пяти легендарных")
	for rid in ["firefly_crown", "seahorse", "fullmoon_mantle", "skin_constellation"]:
		check(w.forge(rid, 999) == "forged", "сковано: " + rid)
		check(w.forge_status("wings_cascado", 999) == "items", "после %s Крылья ещё закрыты" % rid)
	check(w.forge("wings_cascado", 999) == "items", "с четырьмя легендарными — нельзя")
	check(w.forge("mountain_heart", 999) == "forged", "пятая легендарная")
	check(w.forge_status("wings_cascado", 49) == "hall", "Крылья — только после зала 5")
	check(w.forge("wings_cascado", 999) == "forged" and w.equipped.aura == "wings_cascado", "пять легендарных + 300 — Крылья Каскада скованы и надеты")
	check(w.forged.size() == 6 and w.is_owned("seahorse") and w.is_owned("mountain_heart"), "легендарные не тратятся на Крылья")
	# цель «до следующей вещи» не предлагает награды кузницы
	var a = Meta.new()
	a.shards = 0
	a.owned.append_array(Meta.ITEMS.filter(func(it): return it.has("price")).map(func(it): return it.id))
	check(Assist.next_goal(a, "owl", 999, 999).get("slot", "home") == "home", "цель на главном — не награда кузницы (её не купить)")


func _test_collection() -> void:
	print("— коллекция")
	var m = Meta.new()
	check(Meta.collection_total() == Meta.ITEMS.size() and Meta.collection_total() == 61, "всего в коллекции 61 вещь (16 старых + 39 в наборах + 5 легендарных + Крылья)")
	check(m.collection_count() == 0, "у нового игрока 0")
	m.owned.append_array(["bow", "cap", "acorn_cap"])
	m.decor_owned.append("owl_nest")
	check(m.collection_count() == 3, "украшения дома в коллекцию гардероба не входят (3)")
	m.forged.append("seahorse")
	check(m.collection_count() == 4, "скованные считаются (4)")
	check(I18n.t("collection") % [34, 61] == "Коллекция: 34 из 61", "подпись счётчика: «Коллекция: 34 из 61»")


func _test_income(g) -> void:
	print("— доход по залам")
	check(Meta.win_reward(true, 0, 0, 0, 1).win == 10 and Meta.win_reward(true, 0, 0, 0, 10).win == 10, "зал 1: первая победа 10")
	check(Meta.win_reward(true, 0, 0, 0, 11).win == 12 and Meta.win_reward(true, 0, 0, 0, 21).win == 14, "зал 2 — 12, зал 3 — 14")
	check(Meta.win_reward(true, 0, 0, 0, 100).win == 28 and Meta.win_reward(true, 0, 0, 0, 250).win == 28, "зал 10 — 28, в глубинах — как в зале 10")
	check(Meta.win_reward(false, 3, 3, 0, 95).win == Meta.WIN_REPEAT, "повторная победа — по-прежнему +3")
	check(Meta.win_reward(true, 0, 1, 0).total == 15, "без номера уровня — как раньше (зал 1)")
	# в игре номер уровня передаётся
	g.meta = Meta.new()
	g.stars = {}
	g.assist.gift_given = true
	g.start_level(21)
	g.pieces_used = 999
	g._win()
	check(g.last_reward.win == 14 and g.last_reward.first, "победа на уровне 21 (зал 3): +14 за первую победу")
	# расчёт пути до Крыльев Каскада
	var path := 0
	for r in Meta.RECIPES:
		path += int(r.cost)
		if int(r.set) > 0:
			for id in r.needs:
				path += int(Meta.item(id).get("price", 0))
	check(path == 2645, "путь до Крыльев: вещи рецептов 1795 + ковка 850 = 2645 (%d)" % path)
	var base := 0
	for lv in range(1, 101):
		base += Meta.win_reward(true, 0, 0, 0, lv).win
	check(base == 1900, "за 100 первых побед без звёзд — 1900 (было бы 1000 без надбавки)")
	var two_stars := base + 100 * 2 * Meta.PER_NEW_STAR
	check(two_stars >= path and base + 100 * Meta.PER_NEW_STAR < path, "с двумя звёздами в среднем (2900) путь укладывается в 100 уровней, с одной (2400) — нет")


func _test_save() -> void:
	print("— сохранение")
	var m = Meta.new()
	m.set_hero("kitten")
	m.shards = 77
	m.owned.append_array(["firefly", "leaf_scarf"])
	m.forged.append("firefly_crown")
	m.equip("firefly")
	m.equip("firefly_crown")
	var cfg := ConfigFile.new()
	m.save_to(cfg)
	var m2 = Meta.new()
	m2.load_from(cfg)
	check(m2.forged == ["firefly_crown"] and m2.owned.size() == 2, "скованные вещи сохраняются отдельно (поле forged)")
	check(m2.equipped.get("head", "") == "firefly_crown" and m2.equipped.get("companion", "") == "firefly", "надетые награда и спутник восстанавливаются")
	# старое сохранение (0.11): нет поля forged
	var old := ConfigFile.new()
	old.set_value("meta", "hero", "owl")
	old.set_value("meta", "shards", 120)
	old.set_value("meta", "owned", ["bow", "crown"])
	old.set_value("meta", "equipped", {"head": "crown"})
	var m3 = Meta.new()
	m3.load_from(old)
	check(m3.forged.is_empty() and m3.owned == ["bow", "crown"] and m3.equipped.head == "crown" and m3.shards == 120, "старое сохранение без [meta] forged грузится")
	# подделка: награда кузницы в купленных, чужое в forged
	var bad := ConfigFile.new()
	bad.set_value("meta", "owned", ["seahorse", "bow"])
	bad.set_value("meta", "forged", ["bow", "nope", "seahorse", 5])
	bad.set_value("meta", "equipped", {"companion": "seahorse", "aura": "wings_cascado"})
	var m4 = Meta.new()
	m4.load_from(bad)
	check(m4.owned == ["bow"] and m4.forged == ["seahorse"], "награда кузницы не попадает в «купленные», мусор в forged отброшен")
	check(m4.equipped.get("companion", "") == "seahorse" and not m4.equipped.has("aura"), "надеть можно только то, что есть")


func _test_tryon() -> void:
	print("— примерка")
	var m = Meta.new()
	m.shards = 500
	var tr = TryOn.new()
	tr.start_item("firefly")
	check(tr.outfit(m).get("companion", "") == "firefly", "примерка спутника — в слоте «спутник»")
	check(tr.status(m, 0, 1) == "locked" and tr.status(m, 0, 11) == "ok", "вещь набора 1: до зала 1 закрыта, после — можно купить")
	check(tr.confirm(m, 0, 11) == "bought" and m.equipped.companion == "firefly" and not tr.active(), "покупка спутника и сразу надет")
	tr.start_item("aura_pollen")
	check(tr.outfit(m).get("aura", "") == "aura_pollen" and tr.confirm(m, 0, 11) == "bought", "сияние примеряется и покупается")
	tr.start_item("skin_moss")
	check(tr.outfit(m).get("skin", "") == "skin_moss", "окраска набора примеряется")
	tr.clear()
	tr.start_item("wings_cascado")
	check(tr.outfit(m).get("aura", "") == "wings_cascado" and tr.status(m, 999, 999) == "locked", "Крылья можно примерить, но не купить")
	check(tr.confirm(m, 999, 999) == "locked" and not m.is_owned("wings_cascado"), "«Купить» для награды кузницы не срабатывает")


func _test_forge_screen(g) -> void:
	print("— экран кузницы")
	if g.screens == null:
		g.screens = load("res://scripts/screens.gd").new(g)
	if g.forge_ui == null:
		g.forge_ui = load("res://scripts/forge_ui.gd").new(g)
	var f = g.forge_ui
	g.meta = Meta.new()
	g.meta.set_hero("owl")
	g.max_level = 11
	g.meta.shards = 60
	g.meta.owned.append_array(["leaf_scarf", "daisy_glasses", "firefly"])
	f.open()
	check(g.state == g.State.FORGE, "кузница открывается")
	f._try_forge("firefly_crown", 1)
	check(f.anim_id == "firefly_crown" and g.meta.forged.has("firefly_crown") and g.meta.shards == 10, "кнопка «Сковать» запускает анимацию, награда сохранена")
	f.update(1.0)
	check(f.anim_id != "" and not f.result, "через 1 с анимация ещё идёт")
	f.tap(Vector2(360, 640))
	check(f.anim_id == "" and f.result, "касание пропускает анимацию — показ награды на герое")
	f.update(1.0)
	f.tap(Vector2(10, 10))
	check(not f.result, "касание закрывает показ")
	f.start_try("seahorse")
	check(f.try_id == "seahorse", "примерка нескованной награды")
	f.update(Meta.RECIPES.size() * 0.0 + 5.2)
	check(f.try_id == "", "примерка заканчивается сама через 5 секунд")
	f._try_forge("seahorse", 2)
	check(f.anim_id == "" and not g.meta.forged.has("seahorse"), "без зала 2 и вещей — не куётся")
	f.back()
	check(g.state == g.State.HOME, "«Назад» — на главный экран")


## Рисование: все новые вещи на всех героях и все значки — без ошибок скрипта
func _test_drawing() -> void:
	print("— рисование")
	var Hero = load("res://scripts/hero.gd")
	var node := Node2D.new()
	root.add_child(node)
	node.draw.connect(func():
		var h = Hero.new()
		for kind in Meta.HEROES:
			for it in Meta.ITEMS:
				var o := {it.slot: it.id}
				h.draw(node, kind, Vector2(360, 600), 1.0, o, 1.7, 0.3)
				h.draw(node, kind, Vector2(360, 600), 1.0, o, 1.7, 0.3, true)
				h.draw_item_icon(node, it.id, it.slot, kind, Vector2(100, 100), 120, 1.7)
			h.draw(node, kind, Vector2(360, 600), 1.0, {"head": "firefly_crown", "eyes": "star_lorgnette", "neck": "mountain_heart", "back": "fullmoon_mantle",
				"skin": "skin_constellation", "companion": "seahorse", "aura": "wings_cascado"}, 2.3, 0.5)
		h.draw_master(node, Vector2(100, 300), 0.6, 1.0)
		drawn += 1)
	node.queue_redraw()
	for i in 4:
		await process_frame
	if drawn > 0:
		check(true, "все вещи нарисованы на всех героях и значками без ошибок")
	else:
		print("  (рисование в режиме без экрана пропущено)")
	node.free()
