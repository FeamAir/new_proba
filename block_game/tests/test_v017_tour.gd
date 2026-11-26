extends SceneTree
## Тесты версии 0.17: экскурсия по главному экрану (scripts/home_tour.gd).
##   Показ один раз — при первом возвращении домой после первой победы; касание листает шаги;
##   «Пропустить» и «Назад» — больше не показывать; повтор из паузы («Обучение»);
##   все шаги указывают на кнопки главного экрана (в пределах экрана, облачко и «Пропустить» не
##   закрывают окно); касания и перетаскивание во время экскурсии не доходят до кнопок и 3D-камеры;
##   флаг [tour] done в save.cfg; старые сохранения — показать один раз.
## Запуск: godot --headless --path block_game -s tests/test_v017_tour.gd

var failed := 0
var frame := 0
var g
var had_save := false
var save_bytes := PackedByteArray()
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const Tutorial := preload("res://scripts/tutorial.gd")
const HomeTour := preload("res://scripts/home_tour.gd")
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
	if had_save:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	g = load("res://scripts/game.gd").new()
	root.add_child(g)


func _process(_d: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	I18n.set_lang("ru")
	g.assist.track = false
	_test_first_win()
	_test_steps_on_screen()
	_test_input_blocked()
	_test_skip_back()
	_test_replay()
	_test_play_last()
	_test_saves()
	_test_texts()
	if had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)
	return true


## Новый игрок: друг выбран, побед нет
func fresh() -> void:
	g.meta = Meta.new()
	g.meta.set_hero("owl")
	g.stars = {}
	g.max_level = 1
	g.tut = Tutorial.new()
	g.tour = HomeTour.new()
	g.trophy_ui.panel_open = false
	if g.decor_ui:
		g.decor_ui.active = false


## Домой и подождать, пока экскурсия может начаться
func home_wait(sec := 1.0) -> void:
	g.go_home()
	var t := 0.0
	while t < sec:
		g.state_time += 0.05
		g.tour.update(g, 0.05)
		t += 0.05


func tap_next() -> void:
	g.tour.t = 1.0
	g._touch_down(0, Vector2(360, 700))
	g._touch_up(0, Vector2(360, 700))


func _test_first_win() -> void:
	print("— показ один раз после первой победы")
	fresh()
	home_wait()
	check(not g.tour.active(), "новичок до первой победы: экскурсии нет")
	g.start_level(1)
	g._win()
	check(g.max_level == 2 and g.state == g.State.WIN, "первая победа на уровне 1")
	g.tour.update(g, 1.0)
	check(not g.tour.active(), "на экране победы экскурсии нет")
	g.go_home()
	g.tour.update(g, 0.05)
	check(not g.tour.active(), "сразу после перехода — ещё нет (затухание)")
	home_wait()
	check(g.tour.active() and g.tour.cur_id() == "shards", "первое возвращение домой — экскурсия, шаг 1 «Осколки»")
	g.tour.t = 0.1
	g._touch_down(0, Vector2(360, 700))
	check(g.tour.step == 0, "касание в первые доли секунды не листает (случайное)")
	var seen := [g.tour.cur_id()]
	for i in HomeTour.STEPS.size() - 1:
		tap_next()
		seen.append(g.tour.cur_id())
	check(seen == HomeTour.STEPS, "касания листают все %d шагов по порядку" % HomeTour.STEPS.size())
	check(seen.size() >= 7 and seen.size() <= 9, "шагов 7–9")
	tap_next()
	check(not g.tour.active() and g.tour.done and g.state == g.State.HOME, "последнее касание (мимо «Играть») — экскурсия закончена, остаёмся дома")
	var cfg := ConfigFile.new()
	check(cfg.load(SAVE) == OK and cfg.get_value("tour", "done", false) == true, "флаг [tour] done записан в save.cfg")
	home_wait(2.0)
	check(not g.tour.active(), "второй раз дома — экскурсии нет")
	g.start_level(2)
	g._win()
	home_wait()
	check(not g.tour.active(), "после следующих побед — тоже нет")


func _test_steps_on_screen() -> void:
	print("— шаги указывают на кнопки главного экрана")
	for h in [1280.0, 1560.0]:
		g.H = h
		fresh()
		g.max_level = 3
		home_wait()
		var screen := Rect2(0, 0, g.W, g.H)
		var L: Dictionary = g.screens.home_layout()
		for id in HomeTour.STEPS:
			check(L.has(id), "%s: кнопка «%s» есть на главном экране" % [h, id])
			var r: Rect2 = g.tour.target(g, id)
			check(r.size.x > 20 and r.size.y > 20 and screen.encloses(r), "%d: окно «%s» в пределах экрана %s" % [h, id, r])
			check(r.encloses(L[id]), "%d: окно «%s» закрывает кнопку целиком" % [h, id])
			g.tour.step = HomeTour.STEPS.find(id)
			var s: Rect2 = g.tour.skip_rect(g)
			check(screen.encloses(s) and not s.intersects(r), "%d: «Пропустить» на экране и не на окне «%s»" % [h, id])
			var b: Rect2 = g.tour.bubble_rect(g, r, I18n.t("tour_" + id))
			check(screen.encloses(b) and not b.intersects(r) and not b.intersects(s), "%d: облачко «%s» на экране, не на окне и не на «Пропустить»" % [h, id])
			var hp: Vector2 = g.tour.hand_point(r)
			var hb: Rect2 = g.tour.hand_box(r)
			check(r.grow(4).has_point(hp) and absf(hp.x - r.get_center().x) < 1.0, "%d: палец указывает на край окна «%s» посередине" % [h, id])
			check(not hb.intersects(r.grow(-6)) and not hb.intersects(b), "%d: рука не закрывает кнопку «%s» и текст" % [h, id])
	g.H = 1280.0
	g._layout()
	# окно совпадает с тем, куда реально нажимают
	fresh()
	g.max_level = 3
	g.go_home()
	var L2: Dictionary = g.screens.home_layout()
	check(L2.play.get_center().y > g.H * 0.5 and L2.shards.get_center().y < g.H * 0.5, "«Играть» внизу, осколки вверху")


func _test_input_blocked() -> void:
	print("— касания не проходят к кнопкам и 3D-дому")
	fresh()
	g.max_level = 2
	home_wait()
	check(g.tour.active(), "экскурсия на экране")
	var L: Dictionary = g.screens.home_layout()
	g.screens.rects = {"play": L.play, "map": L.map, "wardrobe": L.wardrobe, "decorate": L.decorate}
	g.trophy_ui.rects = {"trophies": L.trophies}
	for id in ["play", "map", "wardrobe", "decorate", "trophies", "forge", "lang"]:
		g.tour.t = 1.0
		var lang0 := I18n.lang
		g._touch_down(0, L[id].get_center())
		g._touch_up(0, L[id].get_center())
		if not g.tour.active():
			fresh()
			g.max_level = 2
			home_wait()
		check(g.state == g.State.HOME and I18n.lang == lang0 and not g.trophy_ui.panel_open, "касание по «%s» во время экскурсии не открывает его" % id)
	var room = g.home3d.room if g.home3d else null
	g._touch_down(0, Vector2(360, 640))
	g._touch_drag(0, Vector2(500, 660), Vector2(140, 20))
	if room != null:
		check(room.cam._touches.is_empty(), "камера 3D-дома касание не получила")
	else:
		print("  (3D-дом без экрана не строится — проверка камеры пропущена)")
	g._touch_up(0, Vector2(500, 660))
	check(g.state == g.State.HOME and g.tour.active(), "перетаскивание по дому — без ошибок, экскурсия на месте")
	# не начинается поверх режима украшения
	fresh()
	g.max_level = 2
	g.decor_ui.active = true
	home_wait()
	check(not g.tour.active(), "в режиме украшения экскурсия не начинается")
	g.decor_ui.active = false
	g.tour.update(g, 0.05)
	check(g.tour.active(), "после выхода из украшения — начинается")
	# робот-тестер (обучение выключено) — без экскурсии
	fresh()
	g.max_level = 2
	g.tut.enabled = false
	home_wait()
	check(not g.tour.active(), "обучение выключено — экскурсии нет")


func _test_skip_back() -> void:
	print("— «Пропустить» и «Назад»")
	fresh()
	g.max_level = 2
	home_wait()
	tap_next()
	check(g.tour.step == 1, "экскурсия на шаге 2")
	g.tour.t = 0.0
	g._touch_down(0, g.tour.skip_rect(g).get_center())
	check(not g.tour.active() and g.tour.done and g.state == g.State.HOME, "«Пропустить» — сразу, даже в первые доли секунды")
	var cfg := ConfigFile.new()
	check(cfg.load(SAVE) == OK and cfg.get_value("tour", "done", false) == true, "пропуск записан в save.cfg")
	home_wait(2.0)
	check(not g.tour.active(), "после пропуска больше не показывается")
	fresh()
	g.max_level = 2
	home_wait()
	g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not g.tour.active() and g.tour.done and g.state == g.State.HOME, "кнопка «Назад» телефона — пропустить экскурсию (игра не закрывается)")
	# ушли с главного экрана не касанием (например, клавишей) — начнётся заново
	fresh()
	g.max_level = 2
	home_wait()
	tap_next()
	g.start_level(2)
	g.tour.update(g, 0.05)
	check(not g.tour.active() and not g.tour.done, "уход с экрана — экскурсия прервана, но не пройдена")
	home_wait()
	check(g.tour.active() and g.tour.step == 0, "следующий заход домой — сначала")


func _test_replay() -> void:
	print("— повтор из паузы")
	fresh()
	g.max_level = 5
	g.tour.done = true
	g.tut.seen = {"l1_move": true}
	g.start_level(4)
	g._set_state(g.State.PAUSED)
	g._pause_menu_tap(g.menu_buttons["tutorial"].get_center())
	check(g.level == 1 and g.state == g.State.PLAYING and not g.tour.done, "пауза → «Обучение»: уровень 1, экскурсия снова впереди")
	var cfg := ConfigFile.new()
	check(cfg.load(SAVE) == OK and cfg.get_value("tour", "done", true) == false, "повтор записан в save.cfg")
	g.tour.update(g, 1.0)
	check(not g.tour.active(), "на уровне экскурсии нет")
	home_wait()
	check(g.tour.active() and g.tour.step == 0, "после уровня дома — экскурсия с первого шага")


func _test_play_last() -> void:
	print("— последний шаг «Играть»")
	fresh()
	g.max_level = 3
	home_wait()
	g.tour.step = HomeTour.STEPS.size() - 1
	check(g.tour.cur_id() == "play", "последний шаг — «Играть»")
	g.tour.t = 1.0
	g._touch_down(0, g.tour.target(g, "play").get_center())
	check(not g.tour.active() and g.tour.done and g.state == g.State.PLAYING and g.level == 3, "касание по «Играть» на последнем шаге — экскурсия закончена, уровень начат")


func _test_saves() -> void:
	print("— сохранения")
	var t := HomeTour.new()
	var empty := ConfigFile.new()
	t.load_from(empty)
	check(not t.done, "нет раздела [tour] — экскурсия впереди")
	t.done = true
	var cfg := ConfigFile.new()
	t.save_to(cfg)
	var t2 := HomeTour.new()
	t2.load_from(cfg)
	check(t2.done, "[tour] done сохраняется и читается")
	var bad := ConfigFile.new()
	bad.set_value("tour", "done", "да")
	t2.load_from(bad)
	check(not t2.done, "испорченное значение — экскурсия впереди")
	# старое сохранение 0.16 с прогрессом (без [tour]) — показать один раз
	var old := ConfigFile.new()
	old.set_value("progress", "max_level", 14)
	old.set_value("progress", "stars", {1: 3, 2: 2})
	old.set_value("meta", "hero", "kitten")
	old.set_value("meta", "shards", 120)
	old.set_value("meta", "trophy_seen", 1)
	old.set_value("tutorial", "seen", ["l1_move", "wardrobe"])
	old.save(SAVE)
	fresh()
	g._load()
	check(g.max_level == 14 and g.meta.hero == "kitten" and not g.tour.done, "старое сохранение: прогресс цел, экскурсия не пройдена")
	home_wait()
	check(g.tour.active(), "старый игрок — экскурсия при следующем входе")
	g._touch_down(0, g.tour.skip_rect(g).get_center())
	fresh()
	g._load()
	check(g.tour.done and g.max_level == 14 and g.meta.shards == 120, "после пропуска — пройдена, остальное цело")
	home_wait()
	check(not g.tour.active(), "старый игрок: больше не показывается")
	# новый игрок (нет файла)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	fresh()
	g.tour.done = true
	g._load()
	check(not g.tour.done and g.max_level == 1, "новый игрок: экскурсия впереди (после первой победы)")


func _test_texts() -> void:
	print("— тексты")
	for l in ["en", "ru"]:
		I18n.set_lang(l)
		var ok := true
		for id in HomeTour.STEPS:
			if not I18n.has_in(l, "tour_" + id) or I18n.t("tour_" + id).length() > 100:
				ok = false
		for k in ["tour_next", "tour_end", "tour_skip"]:
			ok = ok and I18n.has_in(l, k)
		check(ok, "%s: фразы всех шагов и кнопки есть" % l)
	check(I18n.missing_keys().is_empty(), "все ключи переведены")
	I18n.set_lang("en")
	check(I18n.t("tour_skip") == "Skip" and I18n.t("tour_forge").contains("Master Hoot"), "en: «Skip», Master Hoot")
	I18n.set_lang("ru")
	check(I18n.t("tour_skip") == "Пропустить" and I18n.t("tour_shards").contains("осколки"), "ru: «Пропустить», осколки")
