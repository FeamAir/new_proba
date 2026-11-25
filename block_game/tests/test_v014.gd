extends SceneTree
## Тесты версии 0.14: тексты после вычитки (без «скую», «Вернулось %d», «friend»; термины кузницы,
## ключи *_girl / *_boy в обоих языках, название наборов в сообщении по полу),
## покупка вещи набора прямо из кузницы (примерка без трат, «Купить», нехватка, закрытый набор,
## надеть/снять купленную, «Можно выковать!»), возврат домой после покупки / размещения украшения,
## если гардероб открыт «+» с экрана «Дом» (3D-камера подлетает к новой вещи), обычный вход —
## остаёмся в гардеробе; касание по пустому месту гардероба — домой.
## Запуск: godot --headless --path block_game -s tests/test_v014.gd

var failed := 0
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const Home3D := preload("res://scripts/home3d/home3d.gd")
const SAVE := "user://save.cfg"
var had_save := false
var save_bytes := PackedByteArray()
var g
var frame := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)


func _initialize() -> void:
	had_save = FileAccess.file_exists(SAVE)
	save_bytes = FileAccess.get_file_as_bytes(SAVE) if had_save else PackedByteArray()
	Home3D.force = true
	g = load("res://scripts/game.gd").new()
	root.add_child(g)


func _process(_d: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	I18n.set_lang("ru")
	g.tut.enabled = false
	g.assist.track = false
	_test_texts()
	_test_forge_buy()
	_test_decor_return_2d()
	_test_decor_return_3d()
	if had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	I18n.set_lang("ru")
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)
	return true


func _step(sec: float) -> void:
	var t := 0.0
	while t < sec:
		g.home3d._process(0.05)
		if g.home3d.room:
			g.home3d.room._process(0.05)
			g.home3d.room.cam._process(0.05)
		g.screens.update(0.05)
		g.forge_ui.update(0.05)
		t += 0.05


# ---------- Тексты ----------

func _test_texts() -> void:
	print("— тексты (вычитка 0.14)")
	var ru: Dictionary = I18n.STR["ru"]
	var en: Dictionary = I18n.STR["en"]
	var bad_ru: Array = []
	for k in ru:
		var v := String(ru[k])
		if v.to_lower().contains("скую") or v.contains("Вернулось %d") or v.contains("Сков") or v.contains("сковать"):
			bad_ru.append(k)
	check(bad_ru.is_empty(), "ru: нет «скую», «Вернулось %%d», «сковать» %s" % str(bad_ru))
	var bad_en: Array = []
	for k in en:
		if String(en[k]).to_lower().contains("friend"):
			bad_en.append(k)
	check(bad_en.is_empty(), "en: нигде нет «friend» (только buddy) %s" % str(bad_en))
	var miss: Array = []
	for l in ["en", "ru"]:
		var other: Dictionary = I18n.STR["ru" if l == "en" else "en"]
		for k in I18n.STR[l]:
			if (String(k).ends_with("_girl") or String(k).ends_with("_boy")) and not other.has(k):
				miss.append(k)
	check(miss.is_empty() and I18n.missing_keys().is_empty(), "ключи *_girl / *_boy и все остальные — в обоих языках %s" % str(miss))
	I18n.set_lang("ru")
	check(I18n.t("forge_btn") % 120 == "Выковать за 120" and I18n.t("forge_can") == "Можно выковать!" and I18n.t("forge_done") == "Выковано" and I18n.t("forge_got") % "Шарф" == "Выковано: Шарф!", "ru: «Выковать за N», «Можно выковать!», «Выковано»")
	check(I18n.t("forge_say_start_owl_girl") == "Собери набор, дружок, — выкую тебе совиное чудо!" and I18n.t("forge_say_start_owl") == I18n.t("forge_say_start_owl_girl"), "ru: реплика Уха — «выкую тебе совиное чудо»")
	check(I18n.t("switch_text") % Meta.hero_gen("owl", "girl") == "Вещи и украшения Совушки вернутся осколками" and I18n.t("switch_text_named") % "Луна" == "Луна: вещи и украшения вернутся осколками", "ru: окно смены — «вернутся осколками»")
	check(I18n.t("switch_done") % [1, I18n.forms("shards_forms", 1)] == "Возвращено: 1 осколок", "ru: «Возвращено: 1 осколок»")
	check(Meta.rarity_name("super") == "Эксклюзивная" and I18n.t("boost_title") == "Помощь кристалла", "ru: «Эксклюзивная», «Помощь кристалла»")
	check(Meta.item_name("pu_skin_dalmatian", "puppy", "girl") == "Далматинка" and Meta.item_name("pu_skin_dalmatian", "puppy", "boy") == "Далматинец", "ru: Далматинка / Далматинец")
	check(Meta.item_name("ki_starry", "kitten", "girl") == "Звёздная кошечка" and Meta.item_name("ki_starry", "kitten", "boy") == "Звёздный котик", "ru: Звёздная кошечка / Звёздный котик")
	# сообщение о новых наборах — название по полу котика
	var nu = g.notice_ui
	g.meta = Meta.new()
	g.meta.set_hero("kitten")
	g.meta.set_gender("kitten", "girl")
	var mt: String = I18n.t("migrate_sets_text") % [Meta.set_title(Meta.set_index("kit_detective"), g.meta.gender_of("kitten")), Meta.set_title(Meta.set_index("pup_picnic"), "boy")]
	check(mt.contains("«Кошка-детектив»") and mt.contains("«Цветочный пикник»") and nu != null, "ru: новые наборы для кошечки — «Кошка-детектив»")
	I18n.set_lang("en")
	check(I18n.t("forge_can") == "Ready to forge!" and Meta.rarity_name("super") == "Exclusive" and I18n.t("switch_title") == "Switch buddy?", "en: Ready to forge!, Exclusive, Switch buddy?")
	check(Meta.item_name("ki_starry", "kitten", "girl") == "Starry Kitten" and Meta.item_name("ki_starry", "kitten", "boy") == "Starry Kitten", "en: Starry Kitten для обоих")
	I18n.set_lang("ru")


# ---------- Покупка из кузницы ----------

func _test_forge_buy() -> void:
	print("— покупка вещи набора в кузнице")
	var f = g.forge_ui
	var b = f.buy
	var sc = g.screens
	g.meta = Meta.new()
	g.meta.set_hero("puppy")
	g.max_level = 1
	g.meta.shards = 100
	f.open()
	var n1: int = Meta.hero_sets("puppy")[0]
	var n2: int = Meta.hero_sets("puppy")[1]
	# касание по ячейке «Бейсболки» (через экран кузницы — как пальцем)
	f.rects["need_%d_0" % n1] = Rect2(200, 500, 80, 80)
	f.tap(Vector2(240, 540))
	check(b.active() and b.tryon.id == "pu_cap", "ячейка некупленной вещи — примерка и панель покупки")
	check(g.meta.shards == 100 and not g.meta.is_owned("pu_cap") and not g.meta.is_equipped("pu_cap"), "без подтверждения ничего не потрачено и не куплено")
	check(b.tryon.outfit(g.meta).get("head", "") == "pu_cap", "герой примеряет вещь")
	_step(0.3)
	b.rects = {"panel": Rect2(14, 1000, 692, 244), "buy": Rect2(272, 1160, 420, 62), "cancel": Rect2(28, 1160, 230, 62)}
	f.tap(Vector2(140, 1190))
	check(not b.active() and g.meta.shards == 100 and not g.meta.is_owned("pu_cap"), "«Отмена» — панель закрыта, осколки на месте")
	f.tap(Vector2(240, 540))
	_step(0.3)
	b.rects = {"panel": Rect2(14, 1000, 692, 244), "buy": Rect2(272, 1160, 420, 62), "cancel": Rect2(28, 1160, 230, 62)}
	f.tap(Vector2(400, 1190))
	check(g.meta.is_owned("pu_cap") and g.meta.is_equipped("pu_cap") and g.meta.shards == 80 and not b.active(), "«Купить за 20» — куплено, надето, списано 20")
	check(b.lit_i == 0 and b.lit_n == n1 and b.lit_t < 0.1 and sc.toast == I18n.t("bought") % Meta.item_name("pu_cap", "puppy", "boy"), "ячейка загорается, подсказка «Куплено»")
	# повторное касание купленной — снять / надеть
	f.tap(Vector2(240, 540))
	check(not b.active() and not g.meta.is_equipped("pu_cap") and sc.toast == I18n.t("forge_took_off") % "Бейсболка", "купленная вещь: касание снимает («Снято: …»)")
	f.tap(Vector2(240, 540))
	check(g.meta.is_equipped("pu_cap") and sc.toast == I18n.t("forge_worn") % "Бейсболка", "второе касание надевает («Надето: …»)")
	# нехватка осколков
	g.meta.shards = 5
	b.tap_cell(n1, 4)  # Корги, 120
	_step(0.3)
	check(b.active() and b.tryon.status(g.meta, g.total_stars(), g.max_level) == "poor" and b.tryon.shortage(g.meta) == 115, "нехватка: панель открыта, не хватает 115 осколков")
	check(b.confirm() == "poor" and b.active() and g.meta.shards == 5 and not g.meta.is_owned("pu_skin_corgi"), "«Купить» при нехватке — ничего не куплено, панель остаётся")
	check(sc.toast == "Не хватает 115 осколков", "подсказка «Не хватает 115 осколков»")
	f.back()
	check(not b.active() and g.state == g.State.FORGE, "«Назад» сначала закрывает панель, кузница остаётся")
	# закрытый залом набор
	b.tap_cell(n2, 0)
	check(not b.active() and sc.toast == "Откроется после зала 3", "закрытый набор — «Откроется после зала 3», панели нет")
	# последняя вещь набора — «Можно выковать!»
	for id in ["pu_whistle", "pu_visor", "pu_ball"]:
		g.meta.owned.append(id)
	g.meta.shards = 120 + 120
	b.tap_cell(n1, 4)
	check(b.confirm() == "bought" and g.meta.shards == 120, "последняя вещь куплена")
	check(g.meta.forge_status("pu_frisbee", g.max_level) == "ok" and sc.toast == I18n.t("forge_can"), "набор собран и осколков хватает — «Можно выковать!»")
	check(not g.meta.forged.has("pu_frisbee"), "покупка вещи не выковывает награду сама")
	f.back()
	check(g.state == g.State.HOME, "«Назад» из кузницы — домой")


# ---------- Украшения: возврат домой ----------

func _decor_for(kind: String, sp: String) -> String:
	for it in Meta.decor_for(kind, sp):
		if not it.has("stars") and not it.has("hall"):
			return it.id
	return ""


func _test_decor_return_2d() -> void:
	print("— украшение: возврат домой (2D-дом)")
	var sc = g.screens
	var h = g.home3d
	h.set_quality("2d", true)
	g.meta = Meta.new()
	g.meta.set_hero("owl")
	g.max_level = 1
	g.meta.shards = 500
	g.go_home()
	_step(0.1)
	# «+» у места на экране «Дом» (2D): касание по месту
	sc.spot = "floor_l"
	sc.open_wardrobe("home")
	check(g.state == g.State.WARDROBE and sc.tab == "home" and sc.from_home_spot, "«+» с экрана «Дом» — гардероб, вкладка «Дом»")
	var id := _decor_for("owl", "floor_l")
	sc.tap_card(id, "owl")
	check(sc.tryon.active() and g.state == g.State.WARDROBE and g.meta.shards == 500, "примерка украшения — остаёмся, ничего не потрачено")
	sc._confirm_try()
	check(g.state == g.State.HOME and g.meta.placed_at("owl", "floor_l") == id and g.meta.shards < 500, "после «Купить» — сразу домой, украшение стоит")
	# «Разместить» уже купленное — тоже домой
	g.meta.remove_decor("owl", "floor_l")
	sc.open_wardrobe("home")
	sc.tap_card(id, "owl")
	check(g.state == g.State.HOME and g.meta.placed_at("owl", "floor_l") == id, "«Разместить» купленное — сразу домой")
	# обычный вход кнопкой «Гардероб» — остаёмся
	sc.open_wardrobe("head")
	check(not sc.from_home_spot, "кнопка «Гардероб» — обычный вход")
	sc.tab = "home"
	sc.spot = "floor_r"
	var id2 := _decor_for("owl", "floor_r")
	if id2 == id:
		g.meta.remove_decor("owl", "floor_l")
	sc.tap_card(id2, "owl")
	if sc.tryon.active():
		sc._confirm_try()
	check(g.state == g.State.WARDROBE and g.meta.placed_at("owl", "floor_r") == id2, "обычный вход: после покупки / размещения остаёмся в гардеробе")
	# касание по пустому месту сцены — домой; промах между карточками — нет
	var L: Dictionary = sc._wr_layout()
	sc.rects.clear()
	sc.tap_wardrobe(Vector2(L.grid_y * 0 + 360, L.grid_y + L.card_h + 7))  # щель между рядами карточек
	check(g.state == g.State.WARDROBE, "щель между карточками — остаёмся")
	sc.tap_wardrobe(L.stage.get_center())
	check(g.state == g.State.HOME, "касание по пустой сцене — домой")
	sc.open_wardrobe("head")
	sc.tap_card("ow_mortarboard", "owl")
	sc.tap_wardrobe(L.stage.get_center())
	check(g.state == g.State.WARDROBE and not sc.tryon.active(), "во время примерки касание мимо панели сначала снимает примерку")
	sc.tap_wardrobe(Vector2(360, 60))
	check(g.state == g.State.HOME, "касание по шапке (мимо кнопок) — домой")


func _test_decor_return_3d() -> void:
	print("— украшение: возврат домой (3D-дом, камера у новой вещи)")
	var sc = g.screens
	var h = g.home3d
	h.set_quality("high", true)
	g.meta = Meta.new()
	g.meta.set_hero("owl")
	g.max_level = 35
	g.meta.shards = 500
	g.go_home()
	_step(0.3)
	check(h.showing(), "3D-дом на экране «Дом»")
	var target := "floor_r"
	sc.spot = target
	sc.open_wardrobe("home")
	_step(0.3)
	check(h.showing_stage() and sc.from_home_spot, "гардероб по «+»: 3D-дом в окне сцены")
	var id := _decor_for("owl", target)
	sc.tap_card(id, "owl")
	sc._confirm_try()
	check(g.state == g.State.HOME and h.show_spot == target, "после покупки — домой, камере задано место новой вещи")
	_step(0.1)
	var at: Vector3 = h.room.spot_focus.get(target, [h.room.spot_point(target)])[0]
	check(h.showing() and h.show_spot == "" and h.room.cam.focused and h.room.cam.goal_pivot.distance_to(at) < 0.01, "камера подлетает к новой вещи (а не к герою)")
	check(h.room.placed.get(target, "") == id, "новая вещь стоит в 3D-доме")
	# обычный путь (без покупки): из гардероба «Назад» — камера возвращается к герою
	sc.open_wardrobe("home")
	_step(0.3)
	g.go_home()
	_step(0.1)
	check(h.showing() and not h.room.cam.focused, "«Назад» без покупки — камера к герою, как раньше")
