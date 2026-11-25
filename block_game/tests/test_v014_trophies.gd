extends SceneTree
## Тесты версии 0.14: кубки залов и полка славы.
##   10 разных кубков (названия en/ru, 3D-сборка: у каждого свой «отпечаток», камни/свечение есть);
##   полка славы во всех 4 домах (10 мест, силуэты и кубки по прогрессу, таблички, подлёт к кубку);
##   кубок = пройденный зал (из max_level), дата вручения, старые сохранения («Пройден» без даты);
##   вручение только за первое прохождение 10-го, 20-го … 100-го уровня; экран победы «Новый кубок!»;
##   смена героя кубки не трогает; показ новых кубков на полке (один раз); запасной 2D-дом — полка 2D.
## Запуск: godot --headless --path block_game -s tests/test_v014_trophies.gd

var failed := 0
var frame := 0
var g
var had_save := false
var save_bytes := PackedByteArray()
var drawn := 0
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const Home3D := preload("res://scripts/home3d/home3d.gd")
const Art := preload("res://scripts/home3d/trophy_art3d.gd")
const Trophies := preload("res://scripts/trophies.gd")
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
	Home3D.force = true
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
		_test_texts()
		_test_unique_3d()
		_test_shelves()
		_test_save()
		_test_switch_hero()
		_test_win(g)
		_test_home_3d(g)
		_test_home_2d(g)
		_start_drawing()
		return false
	if frame < 8:
		return false
	if drawn > 0:
		check(true, "все 10 кубков (и силуэты) нарисованы в 2D без ошибок; экраны победы и полки 2D — тоже")
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


func _step(gm, secs: float) -> void:
	var t := 0.0
	while t < secs:
		gm._process(1.0 / 30.0)
		gm.home3d._process(1.0 / 30.0)
		if gm.home3d.room:
			gm.home3d.room._process(1.0 / 30.0)
			gm.home3d.room.cam._process(1.0 / 30.0)
			if gm.home3d.room.shelf:
				gm.home3d.room.shelf._process(1.0 / 30.0)
		t += 1.0 / 30.0


# ---------- Правила ----------

func _test_rules() -> void:
	print("— кубки: правила")
	check(Meta.trophy_count(1) == 0 and Meta.trophy_count(10) == 0 and Meta.trophy_count(11) == 1, "кубок зала 1 — после прохождения 10-го уровня (открыт 11-й)")
	check(Meta.trophy_count(61) == 6 and Meta.trophy_count(101) == 10 and Meta.trophy_count(250) == 10, "6 залов — 6 кубков; дальше 10 не бывает (Бесконечные глубины)")
	check(Meta.trophies(35) == [1, 2, 3], "кубки — номера пройденных залов")
	for n in range(1, 11):
		check(Meta.hall_done(n, n * 10 + 1) == (Meta.trophy_count(n * 10 + 1) >= n), "кубок %d совпадает с «зал пройден»" % n)
	check(Meta.trophy_for_win(10, 10) == 1 and Meta.trophy_for_win(20, 20) == 2 and Meta.trophy_for_win(100, 100) == 10, "вручение: 10-й → кубок 1, 20-й → 2, 100-й → 10")
	check(Meta.trophy_for_win(10, 11) == 0 and Meta.trophy_for_win(10, 40) == 0, "повторная победа на 10-м уровне — кубок не вручается снова")
	check(Meta.trophy_for_win(15, 15) == 0 and Meta.trophy_for_win(9, 9) == 0 and Meta.trophy_for_win(110, 110) == 0, "не последний уровень зала и «Бесконечные глубины» — без кубка")
	var m = Meta.new()
	check(m.award_trophy(30, 30, "2026-11-25") == 3 and m.trophy_date(3) == "2026-11-25", "дата вручения запоминается")
	check(m.award_trophy(30, 31) == 0 and m.trophy_date(3) == "2026-11-25", "повтор не меняет дату")
	var today: String = Time.get_date_string_from_system()
	check(m.award_trophy(40, 40) == 4 and m.trophy_date(4) == today, "без даты в вызове — сегодняшняя")
	I18n.set_lang("ru")
	check(m.trophy_done_text(3) == "Пройден: 25.11.2026", "ru: «Пройден: 25.11.2026»")
	check(m.trophy_done_text(1) == "Пройден", "дата неизвестна (зал пройден до 0.14) — просто «Пройден»")
	I18n.set_lang("en")
	check(m.trophy_done_text(3) == "Completed: Nov 25, 2026" and m.trophy_done_text(1) == "Completed", "en: «Completed: Nov 25, 2026» / «Completed»")
	I18n.set_lang("ru")
	m.trophy_seen = 0
	check(m.trophies_pending(41) == [1, 2, 3, 4], "не показанные на полке кубки — по порядку")
	m.mark_trophies_seen(41)
	check(m.trophies_pending(41).is_empty() and m.trophies_pending(51) == [5], "после показа — только новые")


func _test_texts() -> void:
	print("— кубки: тексты")
	var names_ru := {}
	var names_en := {}
	for n in range(1, 11):
		I18n.set_lang("ru")
		names_ru[Meta.trophy_name(n)] = true
		check(I18n.has("trophy_%d" % n) and Meta.trophy_name(n) != "trophy_%d" % n, "есть название кубка %d: %s" % [n, Meta.trophy_name(n)])
		I18n.set_lang("en")
		names_en[Meta.trophy_name(n)] = true
	I18n.set_lang("ru")
	check(names_ru.size() == 10 and names_en.size() == 10, "10 разных названий на обоих языках")
	for k in ["trophy_new", "trophy_for", "trophy_done", "trophy_done_on", "trophy_locked", "trophy_shelf", "trophy_button", "trophy_on_shelf", "trophy_tap"]:
		check(I18n.STR["en"].has(k) and I18n.STR["ru"].has(k), "текст «%s» есть на en и ru" % k)
	check(I18n.missing_keys().is_empty(), "все ключи переведены")
	check(Trophies.GLOW.size() == 10, "у каждого кубка свой цвет свечения")
	var gl := {}
	for c in Trophies.GLOW:
		gl[c] = true
	check(gl.size() == 10, "цвета свечения не повторяются")


## Отпечаток 3D-кубка: сколько деталей, какие сетки и цвета — у разных кубков он разный
func _signature(n: int, ghost := false) -> Dictionary:
	var art = Art.new()
	root.add_child(art)
	var p := Node3D.new()
	art.add_child(p)
	art.trophy(p, n, ghost, Color(0.8, 0.8, 1.0))
	var parts := 0
	var gems := 0
	var glow := 0
	var ghosts := 0
	var sig := []
	var top := 0.0
	for mi in p.find_children("*", "MeshInstance3D", true, false):
		parts += 1
		var m: Material = (mi as MeshInstance3D).material_override
		if m == Art.gem_mat():
			gems += 1
		if m == Art.ghost_mat():
			ghosts += 1
		if m is StandardMaterial3D and (m as StandardMaterial3D).emission_enabled:
			glow += 1
		var aabb: AABB = (mi as MeshInstance3D).get_aabb()
		sig.append("%d:%.3f" % [(mi as MeshInstance3D).mesh.get_surface_count(), aabb.size.length()])
		top = maxf(top, Art._rel_xf(p, mi).origin.y)
	sig.sort()
	var out := {"parts": parts, "gems": gems, "glow": glow, "ghosts": ghosts, "sig": ",".join(sig), "top": top}
	art.free()
	return out


func _test_unique_3d() -> void:
	print("— кубки: 10 разных 3D-кубков")
	var sigs := {}
	for n in range(1, 11):
		var s := _signature(n)
		sigs[s.sig] = n
		check(s.parts >= 6, "кубок %d собран (%d деталей)" % [n, s.parts])
		check(s.gems + s.glow >= 1, "у кубка %d есть камень или свечение (%d/%d)" % [n, s.gems, s.glow])
		check(s.top > 0.05 and s.top < 0.45, "кубок %d размером с кубок на полке" % n)
		var gh := _signature(n, true)
		check(gh.ghosts == gh.parts and gh.parts > 0, "силуэт кубка %d — весь полупрозрачный" % n)
	check(sigs.size() == 10, "все 10 кубков разные по форме")


# ---------- Полки в 4 домах ----------

func _new_room(kind: String, done: Array, hidden := [], hq := true) -> Node3D:
	var vp := SubViewport.new()
	vp.size = Vector2i(360, 640)
	vp.own_world_3d = true
	root.add_child(vp)
	var r = Home3D.ROOMS[kind].new()
	r.setup(kind, 3, {}, {}, hq)
	r.trophies_done = done
	r.trophies_hidden = hidden
	vp.add_child(r)
	r.build()
	return r


func _shelf_aabb(sh: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for gi in sh.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (gi as MeshInstance3D).global_transform * (gi as MeshInstance3D).get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


func _drop(r: Node3D) -> void:
	var vp := r.get_parent()
	root.remove_child(vp)
	vp.free()


func _test_shelves() -> void:
	print("— полка славы во всех домах")
	for kind in Meta.HEROES:
		var r = _new_room(kind, [1, 2, 3])
		var sh = r.shelf
		check(sh != null and sh.style == kind, "%s: полка славы есть, стиль дома" % kind)
		if sh == null:
			_drop(r)
			continue
		check(sh.slots.size() == 10, "%s: 10 мест" % kind)
		var ok := true
		for n in range(1, 11):
			if sh.content.get_node_or_null("slot_%d/trophy_%d" % [n, n]) == null:
				ok = false
		check(ok, "%s: на каждом месте — кубок или силуэт" % kind)
		check(sh.has_trophy(1) and sh.has_trophy(3) and not sh.has_trophy(4) and not sh.has_trophy(10), "%s: кубки 1–3 стоят, 4–10 — силуэты" % kind)
		check(sh.labels.size() == 10 and sh.labels[1].text == Meta.hall_name(0) and sh.labels[7].text == "7", "%s: таблички — название зала / номер" % kind)
		# верхний ряд — залы 1–5
		check(sh.slot_center(1).y > sh.slot_center(6).y, "%s: залы 1–5 — в верхнем ряду" % kind)
		# полка не на месте украшений
		var far := true
		for s in Meta.SPOTS:
			if r.spots.has(s) and Vector2(r.spot_point(s).x, r.spot_point(s).z).distance_to(Vector2(sh.center().x, sh.center().z)) < 1.0:
				far = false
		check(far, "%s: полка не занимает места украшений" % kind)
		# полка не загораживает места украшений с камеры по умолчанию
		r.cam.reset_view()
		var box := _shelf_aabb(sh)
		var clear := true
		for s in Meta.SPOTS:
			if r.spots.has(s) and box.intersects_segment(r.cam.global_position, r.spot_point(s)) != null:
				clear = false
				print("    загорожено место ", s)
		check(clear, "%s: полка не загораживает места украшений в обычном обзоре" % kind)
		# касание кубка: в списке кандидатов pick и подлёт
		r.focus_trophy(2)
		check(r.focused_trophy() == 2 and sh.spin_hall == 2, "%s: подлёт к кубку 2 — он поворачивается на подставке" % kind)
		r.focus_trophy(5)
		check(r.focused_trophy() == 5 and sh.spin_hall == 0, "%s: к силуэту тоже можно подлететь (не крутится)" % kind)
		r.focus_shelf()
		check(r.focused_shelf() and r.focused_trophy() == 0, "%s: подлёт ко всей полке" % kind)
		# камера у кубка — внутри дома
		check(r._inside(sh.slot_center(1) + sh.slot_dir(1) * r.shelf_def.focus_d), "%s: камера у кубка не в стене" % kind)
		# новый зал — кубок появляется без перестройки полки
		var frame_node = sh.frame_n
		r.set_trophies([1, 2, 3, 4], [])
		check(sh.has_trophy(4) and sh.frame_n == frame_node, "%s: новый кубок встаёт на полку (полка не перестраивается)" % kind)
		r.set_trophies([1, 2, 3, 4, 5], [5])
		check(not sh.has_trophy(5), "%s: ещё не показанный кубок — пока силуэт" % kind)
		r.reveal_trophies([5])
		check(sh.has_trophy(5) and sh.appear.has(5) and r.focused_shelf(), "%s: показ — кубок появляется, камера у полки" % kind)
		# простое качество — без анимаций кубков
		r.set_quality(false)
		check(not sh.high and sh.anims.filter(func(a): return sh.content.is_ancestor_of(a.n)).is_empty(), "%s: простое качество — кубки неподвижны" % kind)
		r.set_quality(true)
		_drop(r)
	# все 10 кубков сразу и ни одного
	for kind in Meta.HEROES:
		var r = _new_room(kind, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
		var all := true
		for n in range(1, 11):
			all = all and r.shelf.has_trophy(n)
		check(all, "%s: все 10 кубков на полке" % kind)
		_drop(r)
		r = _new_room(kind, [])
		var none := true
		for n in range(1, 11):
			none = none and not r.shelf.has_trophy(n)
		check(none, "%s: в начале — только силуэты" % kind)
		_drop(r)


# ---------- Сохранение ----------

func _test_save() -> void:
	print("— кубки: сохранение")
	var m = Meta.new()
	m.hero = "owl"
	m.trophy_dates = {1: "2026-11-20", 2: "2026-11-25"}
	m.trophy_seen = 2
	var cfg := ConfigFile.new()
	m.save_to(cfg)
	var m2 = Meta.new()
	m2.load_from(cfg)
	check(m2.trophy_dates == {1: "2026-11-20", 2: "2026-11-25"} and m2.trophy_seen == 2, "даты и «показано» сохраняются")
	# старое сохранение (0.13) — без полей
	var old := ConfigFile.new()
	old.set_value("progress", "max_level", 45)
	old.set_value("meta", "hero", "kitten")
	old.set_value("meta", "shards", 50)
	var m3 = Meta.new()
	m3.load_from(old)
	check(m3.trophy_dates.is_empty() and m3.trophy_seen == 0, "старое сохранение: дат нет, кубки ещё не показаны")
	check(Meta.trophy_count(45) == 4 and m3.trophy_done_text(2) == "Пройден", "старое сохранение: 4 кубка из пройденных залов, «Пройден» без даты")
	check(m3.trophies_pending(45) == [1, 2, 3, 4], "старое сохранение: при первом входе домой полка покажется со всеми кубками")
	# испорченные данные
	var bad := ConfigFile.new()
	bad.set_value("meta", "trophy_dates", {0: "2026-11-20", 11: "2026-11-20", 3: "вчера", 4: 5, "5": "2026-02-30", 6: "2026-13-01"})
	bad.set_value("meta", "trophy_seen", "много")
	var m4 = Meta.new()
	m4.load_from(bad)
	check(m4.trophy_dates.keys() == [5] and m4.trophy_seen == 0, "испорченные даты и счётчик отбрасываются")


func _test_switch_hero() -> void:
	print("— кубки общие для всех героев")
	var m = Meta.new()
	m.set_hero("owl")
	m.trophy_dates = {1: "2026-11-20", 2: "2026-11-21"}
	m.trophy_seen = 2
	m.shards = 500
	m.buy("ow_mortarboard", 99, 99)
	m.switch_hero("puppy")
	check(m.hero == "puppy" and m.trophy_dates == {1: "2026-11-20", 2: "2026-11-21"} and m.trophy_seen == 2, "смена героя: даты кубков и показ не сбрасываются")
	m.switch_hero("kitten")
	m.switch_hero("owl")
	check(m.trophy_dates.size() == 2, "после нескольких смен — кубки на месте")


# ---------- Победа ----------

func _test_win(gm) -> void:
	print("— вручение кубка на экране победы")
	gm.meta.set_hero("owl")
	gm.meta.trophy_dates = {}
	gm.meta.trophy_seen = 0
	if gm.trophy_ui == null:
		gm.trophy_ui = load("res://scripts/trophy_ui.gd").new(gm)
	if gm.screens == null:
		gm.screens = load("res://scripts/screens.gd").new(gm)
	for case in [[10, 10, 1], [20, 20, 2], [50, 50, 5], [100, 100, 10]]:
		gm.max_level = case[1]
		gm.start_level(case[0])
		gm._win()
		check(gm.trophy_ui.win_trophy == case[2] and gm.meta.trophy_dates.has(case[2]), "победа на %d-м уровне — «Новый кубок!» (%s), дата запомнена" % [case[0], Meta.trophy_name(case[2])])
	gm.max_level = 30
	gm.start_level(10)
	gm._win()
	check(gm.trophy_ui.win_trophy == 0, "повтор 10-го уровня — без кубка")
	gm.max_level = 34
	gm.start_level(34)
	gm._win()
	check(gm.trophy_ui.win_trophy == 0, "обычный уровень — без кубка")
	gm.max_level = 30
	gm.start_level(30)
	gm._win()
	check(gm.trophy_ui.ceremony() and gm.trophy_ui.tap_win(Vector2(360, 900)) and not gm.trophy_ui.ceremony(), "касание во время показа — показ сворачивается в плашку (кнопки не нажимаются)")
	check(not gm.trophy_ui.tap_win(Vector2(360, 900)), "после показа касания идут кнопкам победы")
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	check(cfg.get_value("meta", "trophy_dates", {}).has(3), "дата кубка сразу в save.cfg")


# ---------- Дом: 3D и 2D ----------

func _test_home_3d(gm) -> void:
	print("— экран «Дом»: показ новых кубков, подлёт, подпись")
	var h = gm.home3d
	h.quality_manual = true
	h.set_quality("high", true)
	gm.meta.set_hero("axolotl")
	gm.max_level = 21
	gm.meta.trophy_seen = 1
	gm.go_home()
	_step(gm, 0.2)
	check(h.showing() and h.room.shelf != null, "дом построен, полка на месте")
	check(h.room.shelf.has_trophy(1) and not h.room.shelf.has_trophy(2), "новый кубок 2 до показа — силуэт")
	_step(gm, 1.2)
	check(h.revealing() and h.reveal_halls == [2] and h.room.focused_shelf(), "через секунду камера сама летит к полке, кубок 2 появляется")
	check(gm.meta.trophy_seen == 2 and gm.meta.trophies_pending(gm.max_level).is_empty(), "показ запомнен (не повторится)")
	_step(gm, 6.0)
	check(not h.revealing() and h.room.shelf.has_trophy(2), "показ закончился, кубок стоит")
	# повторный вход — без показа
	gm.start_level(1)
	_step(gm, 0.1)
	gm.go_home()
	_step(gm, 1.6)
	check(not h.revealing(), "повторный вход домой — без показа")
	# тап по кубку — подлёт и подпись
	h.focus_trophy(1)
	_step(gm, 0.1)
	check(h.trophy_focus == 1, "подлёт к кубку 1 — подпись с названием и датой")
	h.focus_trophy(7)
	_step(gm, 0.1)
	check(h.trophy_focus == 7, "к силуэту — подпись «Пройди зал 7…»")
	# кнопка «Кубки»: к полке и обратно
	h.room.cam.fly_home()
	_step(gm, 0.1)
	var br: Rect2 = gm.trophy_ui._button_rect()
	check(gm.trophy_ui.tap_home(br.get_center()) and h.room.focused_shelf(), "кнопка «Кубки» — камера к полке")
	_step(gm, 0.1)
	check(h.shelf_focus, "у полки — подпись «Полка славы»")
	gm.trophy_ui.tap_home(br.get_center())
	_step(gm, 0.1)
	check(not h.room.cam.focused, "ещё раз — обратно к обзору")
	# двойной тап по кубку на экране
	h.room.focus_shelf()
	_step(gm, 3.0)
	var p: Vector2 = h.room.cam.unproject_position(h.room.shelf.slot_center(1))
	var c: Dictionary = h.room.pick(p)
	check(c.get("type", "") == "trophy" and c.get("hall", 0) == 1, "под пальцем на полке — кубок 1")
	h.room.cam.double_tapped.emit(p)
	check(h.room.focused_trophy() == 1, "двойной тап — подлёт к кубку")
	# смена героя — кубки в новом доме те же
	gm.meta.switch_hero("kitten")
	_step(gm, 0.3)
	check(h.kind == "kitten" and h.room.shelf.has_trophy(1) and h.room.shelf.has_trophy(2) and not h.room.shelf.has_trophy(3), "у другого героя на полке те же кубки")


func _test_home_2d(gm) -> void:
	print("— запасной 2D-дом: полка славы 2D")
	var h = gm.home3d
	h.set_quality("2d", true)
	gm.meta.set_hero("puppy")
	gm.max_level = 31
	gm.meta.trophy_seen = 2
	gm.trophy_ui.panel_open = false
	gm.trophy_ui._auto_done = false
	gm.go_home()
	_step(gm, 0.1)
	check(not h.showing(), "2D-дом")
	gm.state_time = 1.0
	# draw_home вне рисования не вызываем; правило автопоказа проверяем напрямую
	gm.trophy_ui.open_panel()
	check(gm.trophy_ui.panel_open and gm.trophy_ui.panel_new == [3] and gm.meta.trophies_pending(gm.max_level).is_empty(), "полка 2D открывается с новым кубком 3 и запоминает показ")
	var c: Vector2 = gm.trophy_ui._slot_center(2)
	gm.trophy_ui.rects["slot_2"] = Rect2(c - Vector2(62, 100), Vector2(124, 190))
	gm.trophy_ui.tap_home(c)
	check(gm.trophy_ui.panel_sel == 2, "касание кубка на полке 2D — подпись")
	check(gm.trophy_ui.back() and not gm.trophy_ui.panel_open, "«Назад» закрывает полку 2D")
	h.set_quality("high", true)


func _start_drawing() -> void:
	var node := Node2D.new()
	root.add_child(node)
	g.home3d.set_quality("2d", true)
	node.draw.connect(func():
		for n in range(1, 11):
			Trophies.draw(node, n, Vector2(360, 600), 200, 1.3)
			Trophies.draw(node, n, Vector2(360, 600), 60, 2.7, true)
			Trophies.draw_rays(node, n, Vector2(360, 600), 150, 1.0)
		drawn += 1)
	node.queue_redraw()
	# экран победы с кубком и полка 2D рисуются игрой в её _draw
	g.max_level = 40
	g.start_level(40)
	g._win()
	g.queue_redraw()
