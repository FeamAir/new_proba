extends SceneTree
## Тесты версии 0.18: жалобы с телефона.
##   свайп / тап по ленте карточек (scripts/swipe.gd): тап — при отпускании, свайп листает и ничего не покупает
##   и не надевает (гардероб, режим украшения, полка 2D);
##   «Родной окрас» / «Без вещи» в гардеробе: снять вещь любого слота, купленное остаётся во владении
##   (и после ковки в кузнице, и после покупки из кузницы);
##   полка кубков в 3D: тап и лёгкое движение пальца не выводят из режима полки, свайп — соседний кубок,
##   стрелки ◀ ▶, «Вся полка», щипок, «Закрыть» и «Назад».
## Запуск: godot --headless --path block_game -s tests/test_v018.gd

var failed := 0
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const Swipe := preload("res://scripts/swipe.gd")
const Home3D := preload("res://scripts/home3d/home3d.gd")
const SAVE := "user://save.cfg"
var had_save := false
var save_bytes := PackedByteArray()
var g
var frame := 0
var started := false


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
	if frame < 3 or started:
		return false
	started = true
	_run()
	return false


func _run() -> void:
	I18n.set_lang("ru")
	g.tut.enabled = false
	g.assist.track = false
	g.tour.enabled = false  # экскурсия по дому не мешает касаниям
	_test_texts()
	_test_swipe_rules()
	_test_bare_meta()
	_test_bare_wardrobe()
	await _test_wardrobe_swipe()
	await _test_decor_swipe()
	_test_shelf_3d()
	_test_shelf_2d()
	if had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	I18n.set_lang("ru")
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)


func _step(sec: float) -> void:
	var t := 0.0
	while t < sec:
		g.home3d._process(0.05)
		if g.home3d.room:
			g.home3d.room._process(0.05)
			g.home3d.room.cam._process(0.05)
		g.screens.update(0.05)
		t += 0.05


func _draw_once() -> void:
	g.queue_redraw()
	await process_frame
	await process_frame


func _fresh(kind := "kitten", shards := 2000) -> Meta:
	var m := Meta.new()
	m.set_hero(kind)
	m.shards = shards
	return m


## Касание пальцем от a до b (через несколько шагов) — как на телефоне
func _finger(a: Vector2, b: Vector2) -> void:
	g._touch_down(0, a)
	for i in range(1, 6):
		var p := a.lerp(b, i / 5.0)
		g._touch_drag(0, p, (b - a) / 5.0)
	g._touch_up(0, b)


# ---------- Тексты ----------

func _test_texts() -> void:
	print("— тексты 0.18")
	var keys := ["card_natural", "card_bare", "card_bare_on", "card_take_off", "card_restore", "natural_back", "shelf_all", "shelf_close", "shelf_hint"]
	var miss := []
	for l in ["en", "ru"]:
		for k in keys:
			if not I18n.has_in(l, k):
				miss.append(l + ":" + k)
	check(miss.is_empty(), "новые тексты есть на en и ru %s" % str(miss))
	check(I18n.missing_keys().is_empty(), "ни одного непереведённого ключа")
	I18n.set_lang("ru")
	check(I18n.t("card_natural") == "Родной окрас", "ru: «Родной окрас»")
	I18n.set_lang("en")
	check(I18n.t("card_natural") == "Natural look", "en: «Natural look»")
	I18n.set_lang("ru")


# ---------- Свайп / тап ----------

func _test_swipe_rules() -> void:
	print("— свайп и тап: правила")
	check(Swipe.classify(Vector2(0, 0)) == Swipe.TAP and Swipe.classify(Vector2(10, -12)) == Swipe.TAP, "палец почти не сдвинулся — тап")
	check(Swipe.classify(Vector2(-120, 10)) == Swipe.NEXT, "палец влево — следующая страница")
	check(Swipe.classify(Vector2(120, -15)) == Swipe.PREV, "палец вправо — предыдущая")
	check(Swipe.classify(Vector2(40, 5)) == Swipe.NONE, "повёл немного (не тап и не свайп) — ничего")
	check(Swipe.classify(Vector2(80, 140)) == Swipe.NONE, "повёл вниз — не свайп")
	check(Swipe.classify(Vector2(5, 0), 90.0) == Swipe.NONE, "увёл и вернул палец — не тап (ничего не покупается)")
	var s = Swipe.new()
	s.press(0, Vector2(300, 1000))
	s.move(0, Vector2(200, 1000))
	check(s.release(0, Vector2(150, 1004)) == Swipe.NEXT and not s.active(), "лента: свайп влево распознан, палец отпущен")
	s.press(0, Vector2(300, 1000))
	check(s.release(1, Vector2(300, 1000)) == Swipe.NONE and s.active(), "чужой палец не завершает касание ленты")
	check(s.release(0, Vector2(305, 998)) == Swipe.TAP, "свой — тап")


# ---------- «Родной окрас» и снять вещь ----------

func _test_bare_meta() -> void:
	print("— купленное всегда остаётся: снять / надеть, ковка")
	var m := _fresh("kitten", 2000)
	var rc: Dictionary = Meta.recipe_for_set(Meta.set_index("kit_cozy"))
	for id in rc.needs:
		check(m.buy_item(id, 999, 10) == "bought", "куплено " + id)
	check(m.equipped.get("skin", "") == "ki_skin_tabby", "окраска из набора котёнка надета (котик поменял цвет)")
	m.unequip("skin")
	check(not m.equipped.has("skin") and m.is_owned("ki_skin_tabby"), "окраску можно снять — она остаётся купленной")
	check(m.tap_item("ki_skin_tabby") == "on" and m.equipped.skin == "ki_skin_tabby", "и снова надеть")
	var before: Array = m.owned.duplicate()
	check(m.forge(rc.id, 10) == "forged", "легенда набора выкована")
	check(m.owned == before and rc.needs.all(func(id): return m.is_owned(id)), "после ковки все вещи набора — во владении")
	check(m.equipped.get("companion", "") == rc.id and m.equipped.get("skin", "") == "ki_skin_tabby", "выкованное надето, окраска на месте")
	for slot in Meta.SLOTS:
		m.unequip(slot)
	check(m.equipped.is_empty() and m.is_owned(rc.id) and rc.needs.all(func(id): return m.is_owned(id)), "всё снято — всё купленное и выкованное в рюкзаке")
	# супер-эксклюзив снимает вещи своих слотов, но не забирает их
	m.forged.append("ki_starry")
	m.equip("ki_pompom_hat")
	m.equip("ki_starry")
	check(not m.equipped.has("head") and m.is_owned("ki_pompom_hat"), "супер-эксклюзив снял шапку, шапка осталась у игрока")
	m.equip("ki_pompom_hat")
	check(m.equipped.get("head", "") == "ki_pompom_hat" and not m.equipped.has("aura") and m.forged.has("ki_starry"), "шапка снова надета (супер-эксклюзив снят, остался выкованным)")


func _test_bare_wardrobe() -> void:
	print("— гардероб: карточка «Родной окрас» / «Без вещи» во всех слотах")
	g.meta = _fresh("kitten", 2000)
	g.max_level = 61
	var sc = g.screens
	for slot in Meta.SLOTS:
		sc.tab = slot
		var items: Array = sc._wr_items("kitten")
		check(items.size() > 0 and items[0].id == sc.BARE and items[0].slot == slot, "%s: первая карточка — «%s»" % [slot, I18n.t("card_natural") if slot == "skin" else I18n.t("card_bare")])
		check(sc.page_count(items.size()) == 1, "%s: все вещи на одной странице" % slot)
	# каждый слот: надеть купленное -> «Без вещи» снимает, вещь остаётся
	for slot in Meta.SLOTS:
		var list: Array = Meta.items_in(slot, "kitten").filter(func(it): return not it.has("covers"))
		if list.is_empty():
			continue
		var id: String = list[0].id
		if Meta.is_forge(id):
			g.meta.forged.append(id)
		else:
			g.meta.owned.append(id)
		g.meta.equip(id)
		sc.tab = slot
		sc.tryon.clear()
		sc.tap_card(sc.BARE, "kitten")
		check(not g.meta.equipped.has(slot) and g.meta.is_owned(id), "%s: «%s» снимает %s, вещь в рюкзаке" % [slot, I18n.t("card_natural") if slot == "skin" else I18n.t("card_bare"), id])
		sc.tap_card(id, "kitten")
		check(g.meta.equipped.get(slot, "") == id, "%s: касание вещи снова надевает" % slot)
	# окраска: примерка чужой окраски и «Родной окрас»
	sc.tab = "skin"
	g.meta.unequip("skin")
	sc.tap_card("ki_skin_siamese", "kitten")
	check(sc.tryon.id == "ki_skin_siamese" and not g.meta.equipped.has("skin"), "некупленная окраска — примерка")
	sc.tap_card(sc.BARE, "kitten")
	check(not sc.tryon.active() and not g.meta.equipped.has("skin") and g.meta.shards == 2000, "«Родной окрас» снимает примерку, ничего не тратится")
	check(not sc.tryon.outfit(g.meta).has("skin"), "герой — в родном окрасе")


# ---------- Свайп в гардеробе: тап — это тап, свайп — это свайп ----------

func _test_wardrobe_swipe() -> void:
	print("— гардероб: свайп по ленте не надевает и не снимает")
	g.home3d.set_quality("2d", true)
	g.meta = _fresh("kitten", 2000)
	g.max_level = 61
	g.meta.owned.append("ki_skin_tabby")
	g.meta.equip("ki_skin_tabby")
	var sc = g.screens
	sc.open_wardrobe("skin")
	await _draw_once()
	check(sc.rects.has("item_" + sc.BARE) and sc.rects.has("item_ki_skin_tabby"), "карточки окраски нарисованы, «Родной окрас» — тоже")
	var bare: Vector2 = sc.rects["item_" + sc.BARE].get_center()
	g._touch_down(0, bare)
	check(g.meta.equipped.get("skin", "") == "ki_skin_tabby", "касание карточки ещё ничего не меняет (решает отпускание)")
	g._touch_up(0, bare + Vector2(-150, 6))
	check(g.meta.equipped.get("skin", "") == "ki_skin_tabby", "свайп с «Родного окраса» — окраска не снята")
	_finger(bare, bare + Vector2(30, 40))
	check(g.meta.equipped.get("skin", "") == "ki_skin_tabby", "повёл пальцем и отпустил — ничего")
	_finger(bare, bare + Vector2(4, 3))
	check(not g.meta.equipped.has("skin") and g.meta.is_owned("ki_skin_tabby"), "тап по «Родной окрас» — котик снова в своём цвете, окраска куплена")
	await _draw_once()
	var tab: Vector2 = sc.rects["item_ki_skin_tabby"].get_center()
	_finger(tab, tab + Vector2(160, 0))
	check(not g.meta.equipped.has("skin") and not sc.tryon.active(), "свайп по купленной окраске — не надета")
	_finger(tab, tab)
	check(g.meta.equipped.get("skin", "") == "ki_skin_tabby", "тап — надета")
	await _draw_once()
	var sia: Vector2 = sc.rects["item_ki_skin_siamese"].get_center()
	_finger(sia, sia + Vector2(-140, 0))
	check(not sc.tryon.active() and g.meta.shards == 2000, "свайп по некупленной — ни примерки, ни покупки")
	# вкладки и стрелки — по-прежнему сразу
	g._touch_down(0, sc.rects["tab_head"].get_center())
	g._touch_up(0, sc.rects["tab_head"].get_center())
	check(sc.tab == "head", "вкладка переключается касанием, как раньше")
	check(sc.flip_page(1) == false and sc.page == 0, "одна страница — листать некуда")
	g.go_home()


func _test_decor_swipe() -> void:
	print("— режим украшения: свайп по ленте листает, ничего не ставит")
	g.home3d.set_quality("2d", true)
	g.meta = _fresh("owl", 300)
	g.max_level = 61
	g.go_home()
	var du = g.decor_ui
	du.open()
	await _draw_once()
	check(du.active and du.rects.has("strip") and du.pages() > 1, "лента карточек есть, страниц больше одной")
	var first: String = ""
	for n in du.rects:
		if String(n).begins_with("card_"):
			first = String(n)
			break
	var c: Vector2 = du.rects[first].get_center()
	_finger(c, c + Vector2(-180, 8))
	check(du.page == 1 and not du.tryon.active() and g.meta.shards == 300, "свайп влево — страница 2, примерки и покупки нет")
	_finger(c, c + Vector2(-180, 0))
	check(du.page == mini(2, du.pages() - 1), "ещё свайп — дальше")
	_finger(c, c + Vector2(180, 0))
	_finger(c, c + Vector2(180, 0))
	_finger(c, c + Vector2(180, 0))
	check(du.page == 0, "свайпы вправо — назад к первой (дальше первой — никуда)")
	await _draw_once()
	_finger(c, c + Vector2(3, 2))
	check(du.tryon.active() and du.tryon.id == first.substr(5) and g.meta.shards == 300, "тап по карточке — примерка (как раньше)")
	du.close()
	g.home3d.set_quality("high", true)


# ---------- Полка кубков в 3D ----------

func _test_shelf_3d() -> void:
	print("— полка кубков 3D: листать, не вылетать")
	g.meta = _fresh("owl", 100)
	g.max_level = 41
	g.meta.trophy_seen = 4
	var h = g.home3d
	h.set_quality("high", true)
	g.go_home()
	_step(0.3)
	check(h.showing() and h.room.shelf != null, "3D-дом с полкой")
	var cam = h.room.cam
	h.focus_trophy(2)
	_step(3.0)
	check(h.room.focused_trophy() == 2 and cam.hold_focus, "у кубка 2 — камера «держит» полку")
	# лёгкий тап с дрожанием пальца (раньше уводил к обзору)
	var p := Vector2(360, 640)
	h.touch(0, p, true)
	h.drag(0, p + Vector2(14, 6), Vector2(14, 6))
	h.drag(0, p + Vector2(22, 9), Vector2(8, 3))
	h.touch(0, p + Vector2(22, 9), false)
	_step(0.3)
	check(h.room.focused_trophy() == 2, "лёгкое касание с движением пальца — остаёмся у кубка")
	cam.tapped.emit(Vector2(5, 5))
	cam.double_tapped.emit(Vector2(5, 5))
	_step(0.2)
	check(h.in_shelf() and h.room.focused_trophy() == 2, "тап и двойной тап мимо кубков — из режима полки не выводят")
	# свайп влево — следующий кубок
	h.touch(0, p, true)
	for i in 5:
		h.drag(0, p + Vector2(-30 * (i + 1), 0), Vector2(-30, 0))
	h.touch(0, p + Vector2(-150, 0), false)
	_step(0.1)
	check(h.room.focused_trophy() == 3, "свайп влево — к кубку 3 (плавный подлёт)")
	h.touch(0, p, true)
	for i in 5:
		h.drag(0, p + Vector2(30 * (i + 1), 0), Vector2(30, 0))
	h.touch(0, p + Vector2(150, 0), false)
	_step(3.0)
	check(h.room.focused_trophy() == 2, "свайп вправо — обратно к кубку 2")
	# медленный поворот пальцем — панорама в пределах, без выхода
	h.touch(0, p, true)
	for i in 20:
		h.drag(0, p + Vector2(-25 * (i + 1), 0), Vector2(-25, 0))
	cam._press_time = cam._clock - 2.0  # палец вёл долго — это не свайп
	h.touch(0, p + Vector2(-500, 0), false)
	_step(0.1)
	var off: float = absf(angle_difference(cam.focus_yaw, cam.yaw))
	check(h.room.focused_trophy() == 2 and off > 0.05 and off <= cam.PAN_LIMIT + 0.001, "медленно повёл пальцем — камера чуть повернулась (%.2f рад), осталась у кубка" % off)
	# стрелки
	h.step_trophy(1)
	check(h.room.focused_trophy() == 3, "стрелка ▶ — следующий кубок")
	h.step_trophy(-1)
	h.step_trophy(-1)
	check(h.room.focused_trophy() == 1, "◀ ◀ — кубок 1")
	h.step_trophy(-1)
	check(h.room.focused_trophy() == 10, "от первого ◀ — к последнему (по кругу)")
	h.step_trophy(1)
	check(h.room.focused_trophy() == 1, "от последнего ▶ — к первому")
	# кнопки на экране (касание по прямоугольникам кнопок)
	var tu = g.trophy_ui
	var R: Dictionary = tu.shelf_rects()
	_step(0.1)
	check(tu.tap_home(R.sh_next.get_center()) and h.room.focused_trophy() == 2, "кнопка ▶ на экране")
	check(tu.tap_home(R.sh_prev.get_center()) and h.room.focused_trophy() == 1, "кнопка ◀ на экране")
	check(tu.tap_home(R.sh_all.get_center()) and h.room.focused_shelf(), "«Вся полка» — камера отдаляется ко всей полке")
	_step(2.0)
	h._on_pinch(0.5)
	check(h.room.focused_trophy() == 1, "щипок «ближе» у всей полки — к последнему кубку")
	h._on_pinch(1.6)
	check(h.room.focused_shelf(), "щипок «дальше» у кубка — вся полка")
	h._on_pinch(1.0)
	check(h.room.focused_shelf(), "щипок без изменения — ничего")
	# щипок двумя пальцами через камеру
	h.focus_trophy(4)
	_step(3.0)
	h.touch(0, Vector2(300, 640), true)
	h.touch(1, Vector2(420, 640), true)
	for i in 6:
		h.drag(0, Vector2(300 + i * 9, 640), Vector2(9, 0))
		h.drag(1, Vector2(420 - i * 9, 640), Vector2(-9, 0))
	h.touch(1, Vector2(375, 640), false)
	h.touch(0, Vector2(345, 640), false)
	check(h.room.focused_shelf(), "свёл два пальца у кубка — видна вся полка")
	# выход — только «Закрыть» / «Назад» / кнопка «Кубки»
	_step(0.2)
	check(tu.tap_home(R.sh_close_c.get_center()) and not h.in_shelf() and not cam.focused, "«Закрыть» — обратно к обзору дома")
	_step(0.2)
	check(not cam.hold_focus, "вне полки камера крутится как раньше")
	h.focus_trophy(3)
	_step(0.2)
	check(tu.tap_home(R.sh_close.get_center()) and not h.in_shelf(), "«Закрыть» у кубка — к обзору")
	h.focus_trophy(3)
	_step(0.2)
	g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not h.in_shelf() and g.state == g.State.HOME, "«Назад» телефона — от полки к обзору, остаёмся дома")
	# вне полки палец по сцене крутит камеру и тап по-прежнему работает
	_step(0.5)
	var y0: float = cam.yaw
	h.touch(0, p, true)
	for i in 6:
		h.drag(0, p + Vector2(-30 * (i + 1), 0), Vector2(-30, 0))
	h.touch(0, p + Vector2(-180, 0), false)
	check(absf(cam.yaw - y0) > 0.3 and not h.in_shelf(), "в обзоре свайп крутит камеру (не листает кубки)")


# ---------- Полка 2D ----------

func _test_shelf_2d() -> void:
	print("— полка 2D (простая графика): листается")
	var h = g.home3d
	h.set_quality("2d", true)
	g.meta = _fresh("puppy", 100)
	g.max_level = 31
	g.meta.trophy_seen = 3
	g.go_home()
	var tu = g.trophy_ui
	tu.open_panel()
	tu.panel_sel = 2
	var c: Vector2 = tu._slot_center(4)
	tu.rects["slot_4"] = Rect2(c - Vector2(62, 100), Vector2(124, 190))
	g._touch_down(0, c)
	check(tu.panel_sel == 2, "касание полки 2D — решает отпускание")
	g._touch_up(0, c + Vector2(-140, 0))
	check(tu.panel_sel == 3 and tu.panel_open, "свайп влево по полке 2D — следующий кубок, полка открыта")
	_finger(c, c + Vector2(150, 0))
	check(tu.panel_sel == 2, "свайп вправо — предыдущий")
	_finger(c, c)
	check(tu.panel_sel == 4, "тап по кубку — он выбран")
	tu.panel_sel = 10
	tu.step_panel(1)
	check(tu.panel_sel == 1, "стрелка ▶ от 10 — к 1")
	tu.step_panel(-1)
	check(tu.panel_sel == 10, "стрелка ◀ от 1 — к 10")
	tu.rects["p_prev"] = Rect2(40, 900, 70, 80)
	tu.tap_home(Vector2(70, 940))
	check(tu.panel_sel == 9, "кнопка ◀ в подписи полки 2D")
	check(tu.back() and not tu.panel_open, "«Назад» закрывает полку 2D")
	h.set_quality("high", true)
