extends SceneTree
## Тесты версии 0.18: жалобы с телефона.
##   свайп / тап по ленте карточек (scripts/swipe.gd): тап — при отпускании, свайп листает и ничего не покупает
##   и не надевает (гардероб, режим украшения, полка 2D);
##   «Родной окрас» / «Без вещи» в гардеробе: снять вещь любого слота, купленное остаётся во владении
##   (и после ковки в кузнице, и после покупки из кузницы);
##   полка кубков в 3D — обзор от первого лица: палец поворачивает «голову» (положение камеры то же),
##   углы ограничены, тап по кубку — подпись, тап мимо не выводит, «Прямо», щипок, «Закрыть» и «Назад».
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
	var keys := ["card_natural", "card_bare", "card_bare_on", "card_take_off", "card_restore", "natural_back", "shelf_center", "shelf_close", "shelf_hint"]
	var miss := []
	for l in ["en", "ru"]:
		for k in keys:
			if not I18n.has_in(l, k):
				miss.append(l + ":" + k)
	check(miss.is_empty(), "новые тексты есть на en и ru %s" % str(miss))
	check(I18n.missing_keys().is_empty(), "ни одного непереведённого ключа")
	I18n.set_lang("ru")
	check(I18n.t("card_natural") == "Родной окрас", "ru: «Родной окрас»")
	check(I18n.t("shelf_hint") == "Веди пальцем — осматривайся" and I18n.t("shelf_center") == "Прямо", "ru: подсказка обзора и «Прямо»")
	I18n.set_lang("en")
	check(I18n.t("card_natural") == "Natural look", "en: «Natural look»")
	check(I18n.t("shelf_hint") == "Drag to look around" and I18n.t("shelf_center") == "Center", "en: подсказка обзора и «Center»")
	check(not I18n.has_in("en", "shelf_all") and not I18n.has_in("ru", "shelf_all"), "старого текста «Вся полка» нет")
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
	print("— полка кубков 3D: обзор от первого лица (поворот «головы»)")
	g.meta = _fresh("owl", 100)
	g.max_level = 41
	g.meta.trophy_seen = 4
	var h = g.home3d
	h.set_quality("high", true)
	g.go_home()
	_step(0.3)
	check(h.showing() and h.room.shelf != null, "3D-дом с полкой")
	var cam = h.room.cam
	var tu = g.trophy_ui
	# вход: кнопка «Кубки» на экране «Дом»
	var br: Rect2 = tu._button_rect()
	check(tu.tap_home(br.get_center()) and h.in_shelf() and cam.look_mode, "«Кубки» — камера встаёт к полке, обзор от первого лица")
	_step(2.0)
	var sh = h.room.shelf
	var fwd: Vector3 = -cam.global_transform.basis.z
	var to_c: Vector3 = (sh.center() - cam.global_position).normalized()
	check(fwd.dot(to_c) > 0.995, "камера смотрит на середину полки")
	var dist_c: float = Vector2(cam.global_position.x - sh.center().x, cam.global_position.z - sh.center().z).length()
	check(dist_c > 0.7 and dist_c < 2.0 and h.room._inside(cam.global_position), "стоит перед полкой на разумном расстоянии (%.2f м), внутри дома" % dist_c)
	# поворот пальцем влево: взгляд влево, положение то же
	var pos0: Vector3 = cam.global_position
	var p := Vector2(360, 700)
	h.touch(0, p, true)
	for i in 6:
		h.drag(0, p + Vector2(-30 * (i + 1), 0), Vector2(-30, 0))
		cam._process(1.0 / 60.0)  # палец ведёт по кадрам, как на телефоне
	h.touch(0, p + Vector2(-180, 0), false)
	var fwd_l: Vector3 = -cam.global_transform.basis.z
	var left: Vector3 = Vector3.UP.cross(fwd)
	check(cam.look_yaw > 0.3 and fwd_l.dot(left) > 0.3, "палец влево — голова повернулась влево (%.0f°)" % rad_to_deg(cam.look_yaw))
	check(cam.global_position.distance_to(pos0) < 0.001, "положение камеры не изменилось — вращается вокруг себя, не облетает")
	check(h.in_shelf(), "поворот не выводит из обзора")
	# инерция: после отпускания ещё немного доворачивает
	var y1: float = cam.look_yaw
	_step(0.3)
	check(cam.look_yaw > y1 + 0.02 and cam.look_yaw < y1 + 0.6, "лёгкая инерция после отпускания (+%.0f°)" % rad_to_deg(cam.look_yaw - y1))
	_step(1.0)
	var y2: float = cam.look_yaw
	_step(0.5)
	check(absf(cam.look_yaw - y2) < 0.01, "инерция затухает")
	# до упора влево и дальше: угол ограничен, мягко возвращается к границе
	h.touch(0, p, true)
	for i in 40:
		h.drag(0, p + Vector2(-40 * (i + 1), 0), Vector2(-40, 0))
	check(cam.look_yaw <= cam.LOOK_YAW_MAX + cam.LOOK_OVER + 0.001, "за упор не уходит дальше чуть-чуть (%.0f°)" % rad_to_deg(cam.look_yaw))
	h.touch(0, p + Vector2(-1600, 0), false)
	_step(1.5)
	check(absf(cam.look_yaw - cam.LOOK_YAW_MAX) < 0.02, "отпустил — мягко встал на границу %.0f°" % rad_to_deg(cam.LOOK_YAW_MAX))
	check(cam.LOOK_YAW_MAX >= deg_to_rad(60.0) and cam.LOOK_YAW_MAX <= deg_to_rad(95.0), "влево / вправо — примерно до 90°")
	check(cam.global_position.distance_to(pos0) < 0.001, "и после упора камера на том же месте")
	# вправо до упора
	h.touch(0, p, true)
	for i in 80:
		h.drag(0, p + Vector2(40 * (i + 1), 0), Vector2(40, 0))
	h.touch(0, p + Vector2(3200, 0), false)
	_step(1.5)
	check(absf(cam.look_yaw + cam.LOOK_YAW_MAX) < 0.02, "вправо — до границы −%.0f°" % rad_to_deg(cam.LOOK_YAW_MAX))
	var fwd_r: Vector3 = -cam.global_transform.basis.z
	check(fwd_r.dot(-left) > 0.8, "взгляд повернулся вправо")
	# вверх / вниз — немного
	h.touch(0, p, true)
	for i in 40:
		h.drag(0, p + Vector2(0, -40 * (i + 1)), Vector2(0, -40))
	h.touch(0, p + Vector2(0, -1600), false)
	_step(1.5)
	check(cam.look_pitch > 0.2 and cam.look_pitch <= cam.LOOK_PITCH_MAX + 0.02 and cam.LOOK_PITCH_MAX <= deg_to_rad(26.0), "палец вверх — взгляд вверх, не больше %.0f°" % rad_to_deg(cam.LOOK_PITCH_MAX))
	h.touch(0, p, true)
	for i in 80:
		h.drag(0, p + Vector2(0, 40 * (i + 1)), Vector2(0, 40))
	h.touch(0, p + Vector2(0, 3200), false)
	_step(1.5)
	check(cam.look_pitch < -0.2 and cam.look_pitch >= -cam.LOOK_PITCH_MAX - 0.02, "вниз — тоже немного")
	check(cam.global_position.distance_to(pos0) < 0.001, "наклоны головы не двигают камеру")
	# «Прямо» — взгляд в центр
	var R: Dictionary = tu.shelf_rects()
	check(not R.has("sh_prev") and not R.has("sh_next") and not R.has("sh_all"), "стрелок ◀ ▶ и «Вся полка» больше нет")
	check(tu.tap_home(R.sh_center.get_center()) and h.in_shelf(), "кнопка «Прямо»")
	_step(2.0)
	fwd = -cam.global_transform.basis.z
	check(absf(cam.look_yaw) < 0.01 and absf(cam.look_pitch) < 0.01 and fwd.dot((sh.center() - cam.global_position).normalized()) > 0.995, "«Прямо» — взгляд плавно вернулся в середину полки")
	# тап мимо — ничего; тап по кубку — подпись и взгляд к нему
	cam.tapped.emit(Vector2(5, 5))
	cam.double_tapped.emit(Vector2(5, 5))
	_step(0.2)
	check(h.in_shelf() and h.trophy_focus == 0 and cam.global_position.distance_to(pos0) < 0.001, "тап и двойной тап мимо кубков — ничего, из обзора не выводят")
	var sp: Vector2 = cam.unproject_position(sh.slot_center(1))
	cam.tapped.emit(sp)
	_step(0.1)
	check(h.trophy_focus == 1 and h.in_shelf(), "тап по кубку 1 — его название в подписи")
	_step(2.0)
	fwd = -cam.global_transform.basis.z
	check(fwd.dot((sh.slot_center(1) - cam.global_position).normalized()) > 0.995 and cam.global_position.distance_to(pos0) < 0.001, "взгляд плавно повернулся к кубку, камера не перелетела")
	# лёгкий тап с дрожанием пальца — тоже тап, не выход
	sp = cam.unproject_position(sh.slot_center(9))
	h.touch(0, sp * Vector2(g.W, g.H) / Vector2(h.vp.size), true)
	h.touch(0, sp * Vector2(g.W, g.H) / Vector2(h.vp.size), false)
	_step(0.1)
	check(h.trophy_focus == 9 and h.in_shelf(), "касание пальцем по кубку 9 — подпись кубка 9")
	tu.tap_home(R.sh_center.get_center())
	_step(0.1)
	check(h.trophy_focus == 9, "«Прямо» не сбрасывает подпись выбранного кубка")
	# щипок — шаг ближе / дальше, в пределах комнаты
	_step(2.0)
	var d0: float = cam.look_d
	h.touch(0, Vector2(300, 700), true)
	h.touch(1, Vector2(420, 700), true)
	for i in 8:
		h.drag(0, Vector2(300 - (i + 1) * 12, 700), Vector2(-12, 0))
		h.drag(1, Vector2(420 + (i + 1) * 12, 700), Vector2(12, 0))
	h.touch(1, Vector2(516, 700), false)
	h.touch(0, Vector2(204, 700), false)
	_step(2.0)
	check(cam.look_d < d0 - 0.05 and cam.look_d >= cam.look_d_min - 0.001 and h.in_shelf(), "развёл пальцы — шаг ближе к полке (%.2f → %.2f м)" % [d0, cam.look_d])
	check(h.trophy_focus == 9, "щипок — не тап (подпись та же)")
	cam.zoom(10.0)
	_step(3.0)
	check(cam.look_d <= cam.look_d_max + 0.001 and h.room._inside(cam.global_position), "дальше — не за стену (%.2f м)" % cam.look_d)
	# обзор во всех домах: камера внутри, по краям видно крайние кубки
	for kind in ["owl", "axolotl", "puppy", "kitten"]:
		g.meta.set_hero(kind)
		_step(0.3)
		var r = h.room
		r.focus_shelf()
		_step(2.0)
		var c = r.cam
		var ok_in := true
		for zd in [c.look_d_min, c.look_d_max]:
			if not r._inside(c.look_anchor + c.look_back * zd):
				ok_in = false
		check(r._inside(c.global_position) and ok_in, "%s: камера обзора и пределы щипка — внутри дома" % kind)
		var edge_ok := true
		for n in [1, 5, 6, 10]:
			var a: Vector2 = c.look_angles(r.shelf.slot_center(n))
			if absf(a.x) > c.LOOK_YAW_MAX or absf(a.y) > c.LOOK_PITCH_MAX + deg_to_rad(40.0):
				edge_ok = false
		check(edge_ok, "%s: к крайним кубкам можно повернуть голову" % kind)
	# выход: «Закрыть», «Назад», повторно «Кубки»
	g.meta.set_hero("owl")
	_step(0.3)
	cam = h.room.cam
	h.focus_shelf()
	_step(1.0)
	check(tu.tap_home(R.sh_close.get_center()) and not h.in_shelf() and not cam.focused and not cam.look_mode, "«✕ Закрыть» — обратно к обзору дома")
	_step(0.5)
	h.focus_shelf()
	_step(0.5)
	g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not h.in_shelf() and g.state == g.State.HOME, "«Назад» телефона — от полки к обзору, остаёмся дома")
	tu.tap_home(br.get_center())
	_step(0.5)
	check(h.in_shelf(), "«Кубки» — снова у полки")
	tu.tap_home(br.get_center())
	check(not h.in_shelf(), "ещё раз «Кубки» — обратно к обзору дома")
	# выход без рывка: орбита начинается с того места, где стояла камера
	h.focus_shelf()
	_step(2.0)
	var before: Vector3 = cam.global_position
	h.close_shelf()
	cam._process(0.001)
	check(cam.global_position.distance_to(before) < 0.05, "выход из обзора — плавный, без скачка камеры")
	# вне полки палец по сцене крутит камеру по кругу, как раньше
	_step(2.5)
	var y0: float = cam.yaw
	h.touch(0, p, true)
	for i in 6:
		h.drag(0, p + Vector2(-30 * (i + 1), 0), Vector2(-30, 0))
	h.touch(0, p + Vector2(-180, 0), false)
	check(absf(cam.yaw - y0) > 0.3 and not h.in_shelf(), "в обзоре дома свайп крутит камеру по кругу, как раньше")


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
