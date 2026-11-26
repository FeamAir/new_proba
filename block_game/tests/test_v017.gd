extends SceneTree
## Тесты версии 0.17 (часть 1): герой рядом с полем и «Удобство».
##   Герой на панели уровня рисуется для всех 4 героев, обоих полов, всех окрасок и вещей, во всех реакциях;
##   реакции по событиям игры: каскад ×2 — радость, ×3 — прыжок, опасность — испуг, победа — праздник,
##   поражение — грусть, касание героя — реакция (и фигура при этом не поворачивается);
##   после победы/поражения — короткая пауза с реакцией героя, касание её пропускает;
##   «Удобство»: пункт паузы и окно, переключатели, сохранение в [settings], старые сохранения — всё выключено,
##   левша — кнопки на нужных местах, медленное падение меняет интервал (звёзды те же, в статистике отмечено),
##   знаки на блоках рисуются, крупный текст помещается в кнопки паузы.
## Запуск: godot --headless --path block_game -s tests/test_v017.gd

var failed := 0
var frame := 0
var g
var had_save := false
var save_bytes := PackedByteArray()
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const Access := preload("res://scripts/access.gd")
const PlayHero := preload("res://scripts/play_hero.gd")
const SAVE := "user://save.cfg"
const HEROES := ["owl", "axolotl", "puppy", "kitten"]


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
	if frame == 3:
		_run()
	return false


func _finish() -> void:
	if had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)


func _run() -> void:
	I18n.set_lang("ru")
	g.tut.enabled = false
	g.assist.track = false
	g.access = Access.new()
	g._layout()
	_test_texts()
	_test_reactions()
	_test_touch()
	_test_result_beat()
	_test_access_defaults()
	_test_lefty()
	_test_slow()
	_test_pause_menu()
	_test_save()
	await _test_drawing()
	_finish()


func _fresh_level(n := 3) -> void:
	g.meta = Meta.new()
	g.meta.set_hero("owl")
	g.start_level(n)


# ---------- Тексты ----------

func _test_texts() -> void:
	print("— тексты en/ru")
	var keys := ["pause_access", "access_title", "access_symbols", "access_symbols_desc", "access_lefty", "access_lefty_desc",
		"access_slow", "access_slow_desc", "access_big", "access_big_desc", "access_back", "stats_slow_note"]
	var ok := true
	for k in keys:
		if not (I18n.has_in("en", k) and I18n.has_in("ru", k)):
			ok = false
			printerr("    нет ключа ", k)
	check(ok, "все тексты 0.17 есть на английском и русском")
	check(I18n.missing_keys().is_empty(), "нет непереведённых ключей")
	I18n.set_lang("ru")
	check(I18n.t("pause_access") == "Удобство", "пункт паузы по-русски — «Удобство»")


# ---------- Реакции героя ----------

func _fill_row(y: int, v := 2) -> void:
	for x in g.COLS:
		g.board[y * g.COLS + x] = v


func _test_reactions() -> void:
	print("— реакции героя на панели")
	_fresh_level()
	var ph = g.play_hero
	check(ph.current() == "idle" and ph.eye_k() == 1.0, "в начале уровня герой просто дышит")
	# каскад ×2 — радость
	g.chain = 1
	_fill_row(5)
	g._check_lines()
	check(g.chain == 2 and ph.current() == "joy", "каскад ×2 — радость (реакция касания)")
	# каскад ×3 — прыжок с искорками
	g.state = g.State.PLAYING
	_fill_row(6)
	g._check_lines()
	check(g.chain == 3 and ph.current() == "jump" and ph.jump_chain == 3, "каскад ×3 — прыжок с искорками")
	ph.update(PlayHero.JUMP_TIME + 0.1, false)
	check(ph.current() == "idle", "после прыжка — снова спокоен")
	# одна линия (без каскада) — без реакции
	_fresh_level()
	ph = g.play_hero
	g.chain = 0
	_fill_row(6)
	g._check_lines()
	check(g.chain == 1 and ph.current() == "idle", "одна линия без каскада — без особой реакции")
	# опасность
	_fresh_level()
	ph = g.play_hero
	check(not g.in_danger(), "пустой верх поля — опасности нет")
	g.board[1 * g.COLS + 3] = 4
	check(g.in_danger(), "блок в трёх верхних рядах — опасность")
	g.state = g.State.PLAYING
	g._process(0.4)
	check(ph.current() == "fear" and ph.eye_k() > 1.1, "поле почти заполнено — герой пугается (глаза шире)")
	g.board[1 * g.COLS + 3] = g.EMPTY
	for i in 5:
		g._process(0.1)
	check(ph.current() == "idle", "опасность прошла — испуг прошёл")
	# победа и поражение
	_fresh_level()
	g._win()
	check(g.play_hero.current() == "win", "победа — праздник")
	g.play_hero.update(0.3, true)
	check(g.play_hero.current() == "win" and g.play_hero.fear == 0.0, "на празднике не пугается")
	_fresh_level()
	g._lose()
	check(g.play_hero.current() == "lose" and g.play_hero.eye_k() < 1.0, "поражение — грустит (глаза полуопущены)")
	g.start_level(3)
	check(g.play_hero.current() == "idle", "новый уровень — снова спокоен")


func _test_touch() -> void:
	print("— касание героя")
	_fresh_level()
	var ph = g.play_hero
	ph.rect = Rect2(g.panel_x - 8, 800, 190, 260)
	var cells: Array = g.piece_cells.duplicate()
	var pos: Vector2 = ph.rect.get_center()
	g._touch_down(0, pos)
	g._touch_up(0, pos)
	check(ph.current() == "joy", "касание героя — его реакция")
	check(g.piece_cells == cells, "касание героя не поворачивает фигуру")
	# провести пальцем от героя — фигура двигается как обычно
	var x0: int = g.piece_pos.x
	g._touch_down(1, pos)
	g._touch_drag(1, pos + Vector2(-g.CELL * 1.7, 0))
	g._touch_up(1, pos + Vector2(-g.CELL * 1.7, 0))
	check(g.piece_pos.x < x0, "движение пальцем от героя двигает фигуру")
	# касание поля — поворот как раньше
	g.start_level(3)
	g.next_type = 0
	g.piece_type = 1
	g.piece_cells = g.SHAPES[1].cells.duplicate()
	g.piece_pos = Vector2i(3, 2)
	var before: Array = g.piece_cells.duplicate()
	var bp: Vector2 = g.board_pos + Vector2(100, 300)
	g._touch_down(2, bp)
	g._touch_up(2, bp)
	check(g.piece_cells != before, "касание поля по-прежнему поворачивает фигуру")


func _test_result_beat() -> void:
	print("— пауза с реакцией героя после победы/поражения")
	_fresh_level()
	g._win()
	check(g.state == g.State.WIN and g.state_time < 0.0, "победа: сначала герой празднует (окно итога чуть позже)")
	g._touch_down(0, Vector2(360, 900))
	check(g.state == g.State.WIN and g.state_time == 0.0, "касание пропускает паузу, окно победы на месте")
	_fresh_level()
	g._lose()
	check(g.state == g.State.LOSE and g.state_time < 0.0, "поражение: сначала герой грустит")
	g.step(g.RESULT_BEAT + 0.9)
	check(g.state_time > 0.8, "через паузу окно поражения и кнопки появляются как раньше")


# ---------- Удобство ----------

func _test_access_defaults() -> void:
	print("— «Удобство»: по умолчанию всё выключено")
	var a := Access.new()
	check(not a.symbols and not a.lefty and not a.slow and not a.big, "новые настройки выключены")
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "music", false)  # старое сохранение без access_*
	a.symbols = true
	a.load_from(cfg)
	check(not a.symbols and not a.lefty and not a.slow and not a.big, "старое сохранение — всё выключено")
	cfg.set_value("settings", "access_slow", "да")
	cfg.set_value("settings", "access_big", 1)
	a.load_from(cfg)
	check(not a.slow and not a.big, "чужие значения в сохранении — выключено")
	check(Access.SIGNS.size() == g.GEMS.size(), "у каждого из %d цветов самоцвета свой знак" % g.GEMS.size())
	var uniq := {}
	for s in Access.SIGNS:
		uniq[s] = true
	check(uniq.size() == Access.SIGNS.size(), "знаки не повторяются")
	check(a.fs(40) == 40, "обычный текст — без изменений")
	a.big = true
	check(a.fs(40) == 48 and a.fs(22) == 26, "крупный текст — ×1.2")


func _test_lefty() -> void:
	print("— для левшей")
	g.access = Access.new()
	g._layout()
	var b: Dictionary = g.buttons
	check(b.left.position.x < b.right.position.x and b.right.position.x < b.rotate.position.x, "обычно: стрелки слева, поворот справа")
	g.set_access("lefty", true)
	b = g.buttons
	var xs := []
	for n in b:
		xs.append(b[n].position.x)
	check(b.rotate.position.x == xs.min() and b.hard.position.x < b.soft.position.x, "левша: поворот — крайний слева, сброс рядом")
	check(b.right.position.x == xs.max() and b.left.position.x > b.soft.position.x, "левша: стрелки — справа")
	check(b.size() == 5 and b.rotate.position.y == b.left.position.y, "кнопок по-прежнему 5, в один ряд")
	# кнопки работают на новых местах
	_fresh_level()
	g.piece_type = 1
	g.piece_cells = g.SHAPES[1].cells.duplicate()
	g.piece_pos = Vector2i(3, 2)
	var before: Array = g.piece_cells.duplicate()
	g._touch_down(0, b.rotate.get_center())
	g._touch_up(0, b.rotate.get_center())
	check(g.piece_cells != before, "касание левой кнопки (поворот) поворачивает фигуру")
	var x0: int = g.piece_pos.x
	g._touch_down(1, b.right.get_center())
	g._touch_up(1, b.right.get_center())
	check(g.piece_pos.x == x0 + 1, "касание правой кнопки (вправо) двигает фигуру вправо")
	g.set_access("lefty", false)
	check(g.buttons.left.position.x < g.buttons.rotate.position.x, "выключили — раскладка как была")


func _test_slow() -> void:
	print("— медленное падение")
	g.access = Access.new()
	g.speed_step = 5
	var base: float = g.fall_interval()
	check(is_equal_approx(base, maxf(0.14, 0.9 * pow(0.94, 4))), "без настройки интервал прежний")
	g.access.slow = true
	check(is_equal_approx(g.fall_interval(), base / 0.7), "медленное падение: интервал ÷0.7 (скорость ×0.7)")
	# фигура действительно падает реже
	_fresh_level()
	g.access.slow = false
	base = g.fall_interval()
	g.access.slow = true
	var y0: int = g.piece_pos.y
	g.step(base + 0.01)
	check(g.piece_pos.y == y0, "за обычный интервал фигура ещё не упала")
	g.step(base / 0.7 - base)
	check(g.piece_pos.y == y0 + 1, "упала через медленный интервал")
	# звёзды те же, в статистике отмечено
	g.assist.track = true
	g.assist.levels = {}
	_fresh_level(4)
	g.assist.track = true
	g.pieces_used = g.par
	g._win()
	check(g.last_stars == 3, "с медленным падением звёзды те же (3 за «норму» фигур)")
	check(int(g.assist.levels[4].get("slow", 0)) == 1, "в статистике отмечена победа с медленным падением")
	check(g.assist.csv().split("\n")[0] == "level,attempts,losses,wins,best_pieces,assists", "выгрузка CSV не изменилась")
	g.access.slow = false
	_fresh_level(4)
	g.pieces_used = g.par
	g._win()
	check(int(g.assist.levels[4].get("slow", 0)) == 1, "обычная победа отметку не добавляет")
	var cfg := ConfigFile.new()
	g.assist.save_to(cfg)
	var a2 = load("res://scripts/assist.gd").new()
	a2.load_from(cfg)
	check(int(a2.levels[4].get("slow", 0)) == 1, "отметка сохраняется в [stats]")
	g.assist.track = false
	g.assist.levels = {}


func _test_pause_menu() -> void:
	print("— пункт «Удобство» в паузе")
	g.access = Access.new()
	g._layout()
	_fresh_level()
	g._set_state(g.State.PAUSED)
	check(g.menu_buttons.has("access"), "в паузе есть пункт «Удобство»")
	var last: Rect2 = g.menu_buttons.menu
	check(last.end.y + 16.0 + 60.0 <= g.H, "все пункты паузы и номер версии помещаются на экране")
	var labels: Dictionary = g.pause_labels()
	for big in [false, true]:
		g.access.big = big
		var ok := true
		for n in g.menu_buttons:
			var r: Rect2 = g.menu_buttons[n]
			var sz: int = g.assist_ui.fit(labels[n], g.access.fs(32), r.size.x - 24)
			if g.font.get_string_size(labels[n], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > r.size.x - 20:
				ok = false
		check(ok, "надписи паузы помещаются в кнопки (%s текст)" % ("крупный" if big else "обычный"))
	g.access.big = false
	g._touch_down(0, g.menu_buttons.access.get_center())
	check(g.access_ui.open and g.state == g.State.PAUSED, "касание «Удобство» открывает окно настроек")
	g.access_ui._layout()
	var r: Rect2 = g.access_ui.rects.opt_symbols
	g._touch_down(1, r.get_center())
	check(g.access.symbols, "переключатель «Знаки на блоках» включается")
	g._touch_down(2, g.access_ui.rects.opt_big.get_center())
	check(g.access.big, "переключатель «Крупный текст» включается")
	g._touch_down(3, g.access_ui.rects.opt_big.get_center())
	check(not g.access.big, "и выключается")
	g._touch_down(4, Vector2(5, 5))
	check(g.access_ui.open, "касание мимо — окно не закрывается и пауза не меняется")
	g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not g.access_ui.open and g.state == g.State.PAUSED, "«Назад» телефона закрывает окно, пауза остаётся")
	g.access_ui.show()
	g._touch_down(5, g.access_ui.rects.back.get_center())
	check(not g.access_ui.open, "кнопка «Назад» закрывает окно")
	g.access.symbols = false


func _test_save() -> void:
	print("— сохранение настроек")
	g.access = Access.new()
	g.set_access("symbols", true)
	g.set_access("slow", true)
	var cfg := ConfigFile.new()
	check(cfg.load(SAVE) == OK and cfg.get_value("settings", "access_symbols", false) == true and cfg.get_value("settings", "access_slow", false) == true
		and cfg.get_value("settings", "access_lefty", true) == false, "переключатели сразу записаны в [settings]")
	var g2 = load("res://scripts/game.gd").new()
	g2._load()
	check(g2.access.symbols and g2.access.slow and not g2.access.lefty and not g2.access.big, "после перезапуска настройки те же")
	g2.free()
	g.set_access("symbols", false)
	g.set_access("slow", false)
	g.set_access("nope", true)
	check(g.access.get_opt("nope") == false, "неизвестная настройка не появляется")


# ---------- Рисование ----------

func _test_drawing() -> void:
	print("— рисование")
	var node := Node2D.new()
	root.add_child(node)
	var probe := func():
		node.set_meta("probe", true)
	node.draw.connect(probe)
	node.queue_redraw()
	for i in 3:
		await process_frame
	node.draw.disconnect(probe)
	if not node.has_meta("probe"):
		print("  (рисование в режиме без экрана пропущено)")
		node.free()
		return
	var pass_ := func():
		var ph = PlayHero.new()
		var r := Rect2(520, 780, 190, 280)
		var n := 0
		for kind in HEROES:
			var skins: Array = [""]
			var full := {}
			for it in Meta.hero_items(kind):
				if it.slot == "skin":
					skins.append(it.id)
				Meta.put_on(full, it.id)
			for gender in ["boy", "girl"]:
				for sk in skins:
					var o := {"gender": gender}
					if sk != "":
						o["skin"] = sk
					ph.draw(node, kind, o, r)
					n += 1
				for it in Meta.hero_items(kind):
					ph.draw(node, kind, {it.slot: it.id, "gender": gender}, r)
					n += 1
				var fo := full.duplicate()
				fo["gender"] = gender
				# все реакции
				for mood in ["idle", "joy", "jump", "fear", "win", "lose"]:
					ph.reset()
					match mood:
						"joy": ph.on_cascade(2)
						"jump": ph.on_cascade(4)
						"fear": ph.update(1.0, true)
						"win": ph.on_win()
						"lose": ph.on_lose()
					ph.update(0.2, mood == "fear")
					ph.draw(node, kind, fo, r)
					n += 1
				ph.draw_base(node, kind, fo, r)
		# знаки на блоках
		for v in Access.SIGNS.size():
			Access.draw_sign(node, Vector2(100 + v * 60, 100), 60, v)
		node.set_meta("n", n)
	node.draw.connect(pass_)
	node.queue_redraw()
	for i in 3:
		await process_frame
	node.draw.disconnect(pass_)
	var expect := 0
	for kind in HEROES:
		var skins := 1
		for it in Meta.hero_items(kind):
			if it.slot == "skin":
				skins += 1
		expect += 2 * (skins + Meta.hero_items(kind).size() + 6)
	check(node.get_meta("n", 0) == expect, "герой на панели: 4 героя × 2 пола × все окраски, вещи и реакции — нарисованы без ошибок (%d)" % expect)
	check(Hero_eye_reset(), "после рисования глаза героя — обычные (eye_k = 1)")
	node.free()
	# уровень целиком: герой на панели, знаки на блоках, крупный текст, левша, пауза с окном
	_fresh_level(6)
	g.meta.set_gender("owl", "girl")
	g.access.symbols = true
	g.access.big = true
	g.set_access("lefty", true)
	for y in range(9, 11):
		for x in g.COLS:
			if g.board[y * g.COLS + x] == g.EMPTY:
				g.board[y * g.COLS + x] = (x + y) % 7
	var d0: int = g.play_hero.drawn
	for i in 4:
		await process_frame
	check(g.play_hero.drawn > d0, "на экране уровня герой нарисован (картинка героя обновляется)")
	check(g.play_hero.rect.size.y > 120.0 and g.play_hero.rect.position.x >= g.panel_x - 10 and g.play_hero.rect.end.y <= g.board_pos.y + g.ROWS * g.CELL + 1,
		"место героя — внизу правой панели, под счётом, не ниже поля")
	g._set_state(g.State.PAUSED)
	g.access_ui.show()
	for i in 3:
		await process_frame
	check(true, "уровень со знаками, крупным текстом, раскладкой левши и окно «Удобство» — нарисованы без ошибок")
	g.access_ui.close()
	g.set_access("lefty", false)
	g.access = Access.new()
	g._save()
	g._set_state(g.State.PLAYING)
	g.play_hero.on_win()
	var r0: int = g.play_hero.renders
	for i in 3:
		await process_frame
	check(g.play_hero.renders > r0, "картинка героя перерисовывается по событию")


func Hero_eye_reset() -> bool:
	return g.play_hero.hero.eye_k == 1.0
