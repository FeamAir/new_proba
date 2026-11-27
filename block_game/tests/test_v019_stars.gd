extends SceneTree
## 0.19: понятные звёзды. Из закрытого теста: живые игроки почти всегда получали 1 звезду
## (нормы par были подобраны под «хорошую игру» робота). Теперь:
##   - общая формула (scripts/star_goal.gd stars/limit): 3 звезды — до ceil(par × K3) фигур,
##     2 — до ceil(par × K2); ей пользуются победа (game.gd _win), счётчик «★★★ ещё N» и экран победы;
##   - на экране победы строка «★★★ — за 15 фигур и меньше · у тебя 20» (при 3 звёздах — похвала);
##   - обучение: один раз «Меньше фигур — больше звёзд! Смотри счётчик справа» (со 2-го уровня).
## Запуск: godot --headless --path block_game -s tests/test_v019_stars.gd

const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const Access := preload("res://scripts/access.gd")
const StarGoal := preload("res://scripts/star_goal.gd")
const Tutorial := preload("res://scripts/tutorial.gd")
const Levels := preload("res://scripts/levels.gd")
const FILES := ["user://save.cfg", "user://home3d_guard.cfg"]

var failed := 0
var frame := 0
var g
var kept := {}


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)


func _initialize() -> void:
	for f in FILES:
		kept[f] = FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else null
	g = load("res://scripts/game.gd").new()
	root.add_child(g)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		_run()
	return false


func _run() -> void:
	I18n.set_lang("ru")
	g.tut.enabled = false
	g.assist.track = false
	g.tour.enabled = false
	g.access = Access.new()
	g.meta = Meta.new()
	g.meta.set_hero("owl")
	g._layout()
	_test_formula()
	_test_win_uses_formula()
	_test_texts()
	await _test_win_screen()
	_test_tutorial()
	_finish()


# ---------- Формула ----------

func _test_formula() -> void:
	print("— формула звёзд")
	check(StarGoal.limit(10, 3) == 15 and StarGoal.limit(10, 2) == 30, "par 10: 3★ — до 15 фигур, 2★ — до 30")
	check(StarGoal.limit(7, 3) == 11 and StarGoal.limit(7, 2) == 21, "par 7: округление вверх — 3★ до 11 (10,5), 2★ до 21")
	check(StarGoal.limit(13, 3) == 20 and StarGoal.limit(13, 2) == 39, "par 13: 3★ до 20 (19,5 вверх), 2★ до 39")
	check(StarGoal.limit(20, 3) == 30 and StarGoal.limit(11, 3) == 17, "par 20 — ровно 30, без лишней фигуры от округления; par 11 — 17")
	check(StarGoal.stars(10, 1) == 3 and StarGoal.stars(10, 15) == 3, "1 и 15 фигур при par 10 — 3★")
	check(StarGoal.stars(10, 16) == 2 and StarGoal.stars(10, 30) == 2, "16 и 30 фигур — 2★")
	check(StarGoal.stars(10, 31) == 1 and StarGoal.stars(10, 200) == 1, "31 фигура и больше — 1★")
	var bad := []
	for par in range(1, 60):
		var l3 := StarGoal.limit(par, 3)
		var l2 := StarGoal.limit(par, 2)
		if l3 < par or l2 < l3 or (par >= 2 and l2 <= l3):
			bad.append(par)
		for used in range(0, 150):
			var s := StarGoal.stars(par, used)
			var want := 3 if used <= l3 else (2 if used <= l2 else 1)
			if s != want or (used > 0 and s > StarGoal.stars(par, used - 1)):
				bad.append("%d/%d" % [par, used])
	check(bad.is_empty(), "для любого par: par фигур — всегда 3★, меньше фигур — не меньше звёзд %s" % str(bad))
	# мягче прежних норм: никто не теряет звёзды
	var worse := []
	for par in range(1, 60):
		for used in range(0, 150):
			var was := 3 if used <= par else (2 if used <= int(par * 1.4) else 1)
			if StarGoal.stars(par, used) < was:
				worse.append("%d/%d" % [par, used])
	check(worse.is_empty(), "новые нормы не строже прежних (par и par × 1,4) %s" % str(worse))
	# счётчик «★★★ ещё N» на панели считает по той же формуле
	var mism := []
	for par in [3, 4, 7, 10, 13, 22]:
		for used in 60:
			var gl: Array = StarGoal.goal(par, used)
			var shown: int = gl[0] if gl[0] > 0 else 1
			if shown != StarGoal.stars(par, used + 1):
				mism.append("%d/%d" % [par, used])
	check(mism.is_empty(), "«★★★ ещё N» совпадает со звёздами за победу следующей фигурой %s" % str(mism))
	check(StarGoal.goal(10, 0) == [3, 15] and StarGoal.goal(10, 15) == [2, 15], "par 10: в начале «★★★ ещё 15», после 15 фигур — «★★ ещё 15»")


func _test_win_uses_formula() -> void:
	print("— звёзды за победу в игре")
	g.start_level(5)
	var par: int = g.par
	var ok := true
	for used in [1, par, StarGoal.limit(par, 3), StarGoal.limit(par, 3) + 1, StarGoal.limit(par, 2), StarGoal.limit(par, 2) + 1]:
		g.start_level(5)
		g.pieces_used = used
		g._win()
		if g.last_stars != StarGoal.stars(par, used):
			ok = false
	check(ok, "game.gd _win даёт звёзды по общей формуле (par уровня 5 = %d)" % par)
	g.start_level(5)
	g.pieces_used = StarGoal.limit(par, 3) + 1
	g._win()
	check(g.last_stars == 2, "на фигуру больше нормы 3★ — 2 звезды")


# ---------- Тексты ----------

func _test_texts() -> void:
	print("— строка под звёздами на экране победы")
	I18n.set_lang("ru")
	check(StarGoal.win_line(10, 20) == "— за 15 фигур и меньше · у тебя 20", "ru, 2★: «— за 15 фигур и меньше · у тебя 20»")
	check(StarGoal.win_line(10, 40) == "— за 15 фигур и меньше · у тебя 40", "ru, 1★: та же норма 3★")
	check(StarGoal.win_line(14, 30) == "— за 21 фигуру и меньше · у тебя 30", "ru: «за 21 фигуру»")
	check(StarGoal.win_line(15, 30) == "— за 23 фигуры и меньше · у тебя 30", "ru: «за 23 фигуры»")
	check(StarGoal.win_line(10, 15) == I18n.t("win_perfect") and I18n.t("win_perfect") == "Отлично! Все три звезды!", "ru, 3★ — похвала")
	check(I18n.t("tut_stars") == "Меньше фигур — больше звёзд! Смотри счётчик справа", "ru: подсказка обучения")
	I18n.set_lang("en")
	check(StarGoal.win_line(10, 20) == "— 15 pieces or fewer · you used 20", "en, 2★: «— 15 pieces or fewer · you used 20»")
	check(StarGoal.win_line(10, 5) == "Perfect! All three stars!", "en, 3★ — похвала")
	check(I18n.t("tut_stars") == "Fewer pieces — more stars! Watch the counter on the right", "en: подсказка обучения")
	var miss := []
	for k in ["win_need3", "win_pieces_forms", "win_perfect", "tut_stars"]:
		for l in I18n.LANGS:
			if not I18n.has_in(l, k):
				miss.append("%s:%s" % [l, k])
	check(miss.is_empty(), "новые строки есть в en и ru %s" % str(miss))
	I18n.set_lang("ru")


func _test_win_screen() -> void:
	print("— экран победы")
	for used_k in [0, 1, 2]:
		g.start_level(5)
		var par: int = g.par
		g.pieces_used = [par, StarGoal.limit(par, 3) + 1, StarGoal.limit(par, 2) + 3][used_k]
		g._win()
		g.state_time = 3.0
		for i in 3:
			g.queue_redraw()
			await process_frame
	check(g.state == g.State.WIN and g.last_stars == 1, "экран победы с 3, 2 и 1 звездой рисуется без ошибок")
	for l in I18n.LANGS:
		I18n.set_lang(l)
		for used in [g.par + 5, 199]:
			var txt := StarGoal.win_line(g.par, used)
			var fs: int = g.assist_ui.fit(txt, 28, g.W - 60.0 - 3 * (9.0 * 28 / 22.0 * 2 + 2) - 8)
			check(fs >= 24, "%s: строка «%s» помещается в ширину экрана (шрифт %d)" % [l, txt, fs])
	I18n.set_lang("ru")
	g.go_home()


# ---------- Обучение ----------

func _play_piece_ready(n: int, used: int) -> void:
	g.start_level(n)
	g.pieces_used = used
	g.tut.cur = ""
	g.tut.on_spawn(g)


func _test_tutorial() -> void:
	print("— подсказка «Меньше фигур — больше звёзд»")
	g.tut.enabled = true
	g.tut.seen = {}
	for s in Tutorial.STEPS:
		if s.id != Tutorial.STARS:
			g.tut.seen[s.id] = true
	g.tut.seen[Tutorial.UNDO_HINT] = true
	_play_piece_ready(1, 3)
	check(g.tut.cur == "", "на 1-м уровне не показывается")
	_play_piece_ready(2, 0)
	check(g.tut.cur == "", "на 2-м уровне — не на первой фигуре")
	_play_piece_ready(2, 1)
	check(g.tut.cur == Tutorial.STARS, "на 2-м уровне со второй фигуры — подсказка про звёзды")
	check(I18n.t(Tutorial.step_by_id(Tutorial.STARS).text) == I18n.t("tut_stars"), "текст подсказки — tut_stars")
	check(g.tut.holds_fall() and g.tut.is_info(), "пока подсказка на экране, фигура не падает (шаг-пояснение)")
	g.queue_redraw()
	await process_frame
	await process_frame
	var r: Rect2 = g.tut.target(g, "star_goal")
	check(r.size.x > 0 and r.position.x >= g.panel_x - 20, "окно подсказки — на счётчике справа %s" % str(r))
	g.tut.t = 1.0
	check(g.tut.on_tap(g, Vector2(360, 600)) and g.tut.seen.has(Tutorial.STARS), "касание закрывает подсказку")
	_play_piece_ready(3, 2)
	check(g.tut.cur == "", "больше не показывается")
	# игрок со старым сохранением (уже дальше 2-го уровня) увидит её на ближайшем уровне
	g.tut.seen.erase(Tutorial.STARS)
	_play_piece_ready(14, 1)
	check(g.tut.cur == Tutorial.STARS, "со старым прогрессом — на любом уровне от 2-го")
	# три звезды уже не получить — подсказка ждёт другого уровня
	g.tut.cur = ""
	_play_piece_ready(14, StarGoal.limit(g.par, 2) + 1)
	check(g.tut.cur == "", "строка звёзд спрятана — подсказка не показывается")
	g.tut.replay()
	check(not g.tut.seen.has(Tutorial.STARS), "«Обучение» в паузе — покажется снова")
	g.tut.enabled = false


func _finish() -> void:
	g.queue_free()
	for f in FILES:
		if kept[f] != null:
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_buffer(kept[f])
			fa.close()
		elif FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	I18n.set_lang("ru")
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)
