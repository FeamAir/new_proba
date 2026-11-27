extends SceneTree
## 0.19: «зависание» из закрытого теста 0.18. Пауза жестом «Назад» (или сворачиванием) во время
## анимации каскада, затем «Продолжить» — игра становилась PLAYING без фигуры: фигура не появлялась,
## кнопки не работали, помогал только выход из уровня. Теперь пауза запоминает, откуда ушли
## (game.gd paused_from), «Продолжить» возвращает в каскад, а PLAYING без фигуры сам доигрывает
## каскад и даёт новую фигуру (страховка). Ещё: после паузы не остаётся «зажатых» кнопок,
## замедление праздника идёт в настоящем времени, «прыгающие» надписи рисуются одним размером шрифта.
## Запуск: godot --headless --path block_game -s tests/test_v019_freeze.gd

const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const Access := preload("res://scripts/access.gd")
const Juice := preload("res://scripts/juice.gd")
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
	_test_back_in_clearing()
	_test_back_in_settle()
	_test_pause_button_in_cascade()
	_test_minimize_in_cascade()
	_test_keyboard_resume()
	_test_safety_net()
	_test_held_cleared()
	_test_slow_real_time()
	_test_tutorial_info_pause()
	_test_undo_keeps_pause_source()
	await _test_font_sizes()
	_finish()


# ---------- Помощники ----------

## Поле: нижний ряд полон, кроме колонок 0–1; в нём кристалл; над рядом — кристалл в колонке 7
## (после очистки он падает — есть осыпание SETTLE). Фигура — «двойка» над дырой.
func _setup() -> void:
	g.start_level(3)
	g.board.fill(g.EMPTY)
	g.piece_ids.fill(0)
	var y: int = g.ROWS - 1
	for x in range(2, g.COLS):
		g.board[y * g.COLS + x] = g.STONE
	g.board[y * g.COLS + 4] = g.CRYSTAL
	g.board[(y - 2) * g.COLS + 7] = g.CRYSTAL
	g.board[(y - 1) * g.COLS + 7] = g.STONE
	g.goal = "crystals"
	g.crystals_total = 2
	g.crystals_left = 2
	g.piece_type = 0
	g.piece_cells = g.SHAPES[0].cells.duplicate()
	g.piece_pos = Vector2i(0, 0)
	g.has_piece = true
	g._set_state(g.State.PLAYING)


func _tap(pos: Vector2) -> void:
	g._touch_down(1, pos)
	g._touch_up(1, pos)


func _resume_tap() -> void:
	_tap(g.menu_buttons["resume"].get_center())


## Кадры игры (как _process): k секунд по 1/60.
func _run_for(sec: float) -> void:
	for i in int(sec * 60.0):
		g._process(1.0 / 60.0)


## Игра «живая»: есть фигура, и она сама падает.
func _alive() -> bool:
	if g.state != g.State.PLAYING or not g.has_piece:
		return false
	var y0: int = g.piece_pos.y
	_run_for(g.fall_interval() + 0.1)
	return g.piece_pos.y > y0 or g.pieces_used > 1


# ---------- Пауза во время каскада ----------

func _test_back_in_clearing() -> void:
	print("— «Назад» во время очистки ряда, затем «Продолжить»")
	_setup()
	g.hard_drop()
	check(g.state == g.State.CLEARING, "бросок — ряд очищается (CLEARING)")
	g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(g.state == g.State.PAUSED, "«Назад» ставит паузу")
	_run_for(1.0)
	check(g.state == g.State.PAUSED and g.clearing_rows.size() == 1, "на паузе каскад стоит")
	_resume_tap()
	check(g.state == g.State.CLEARING, "«Продолжить» возвращает в очистку ряда, а не в игру без фигуры")
	_run_for(1.0)
	check(g.has_piece and g.crystals_left == 1, "каскад доигран: кристалл засчитан, новая фигура")
	check(_alive(), "новая фигура падает сама")
	check(g.move(1) or g.move(-1), "кнопки снова двигают фигуру")


func _test_back_in_settle() -> void:
	print("— «Назад» во время осыпания, затем «Продолжить»")
	_setup()
	g.hard_drop()
	g.step(g.CLEAR_TIME + 0.01)
	check(g.state == g.State.SETTLE and g.settle_timer > 0.0, "после очистки — осыпание (SETTLE)")
	var left: float = g.settle_timer
	g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(g.state == g.State.PAUSED, "«Назад» ставит паузу")
	_resume_tap()
	check(g.state == g.State.SETTLE and is_equal_approx(g.settle_timer, left), "«Продолжить» — осыпание с того же места")
	_run_for(1.0)
	check(_alive(), "после осыпания — новая фигура, она падает")


func _test_pause_button_in_cascade() -> void:
	print("— кнопка паузы во время каскада")
	_setup()
	g.hard_drop()
	_tap(g.pause_rect.get_center())
	check(g.state == g.State.PAUSED, "кнопка паузы работает и во время каскада")
	_resume_tap()
	check(g.state == g.State.CLEARING, "продолжение — в каскад")
	_run_for(1.0)
	check(_alive(), "игра идёт дальше")


func _test_minimize_in_cascade() -> void:
	print("— свернули приложение во время каскада")
	_setup()
	g.hard_drop()
	g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	g._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(g.state == g.State.PAUSED, "сворачивание ставит паузу и во время каскада")
	g._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	g._process(2.5)  # первый кадр после возврата — длинный
	check(g.state == g.State.PAUSED, "после возврата — пауза (игра не убегает сама)")
	_resume_tap()
	_run_for(1.0)
	check(_alive(), "«Продолжить» — каскад доигран, фигура падает")
	g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(g.state == g.State.PAUSED, "потеря фокуса в игре — пауза")
	_resume_tap()
	check(g.state == g.State.PLAYING and _alive(), "продолжение — та же фигура падает")


func _test_keyboard_resume() -> void:
	print("— Esc: пауза и продолжение во время каскада")
	_setup()
	g.hard_drop()
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	g._key(e)
	check(g.state == g.State.PAUSED, "Esc — пауза")
	g._key(e)
	check(g.state == g.State.CLEARING, "Esc ещё раз — назад в каскад")
	_run_for(1.0)
	check(_alive(), "игра идёт")


func _test_safety_net() -> void:
	print("— страховка: PLAYING без фигуры")
	_setup()
	g.hard_drop()
	g._set_state(g.State.PLAYING)  # то самое состояние из 0.18
	check(not g.has_piece, "PLAYING без фигуры (как после старого «Продолжить»)")
	g._process(1.0 / 60.0)
	check(g.state == g.State.CLEARING, "игра сама возвращается в очистку ряда")
	_run_for(1.0)
	check(_alive(), "каскад доигран, новая фигура падает")
	_setup()
	g.has_piece = false
	g.clearing_rows.clear()
	var used: int = g.pieces_used
	g._process(1.0 / 60.0)
	check(g.state == g.State.PLAYING and g.has_piece, "без каскада — сразу новая фигура")
	check(g.pieces_used == used, "страховка не считает лишнюю фигуру")
	# прежние тестовые сценарии: пауза, выставленная напрямую, продолжается в игру
	_setup()
	g._set_state(g.State.PAUSED)
	_resume_tap()
	check(g.state == g.State.PLAYING and g.has_piece, "пауза из игры — продолжение в игру")


func _test_held_cleared() -> void:
	print("— после паузы кнопка не остаётся «зажатой»")
	_setup()
	g.piece_pos = Vector2i(3, 0)
	g._touch_down(0, g.buttons["left"].get_center())
	check(g.held.size() == 1, "палец на кнопке «влево»")
	g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)  # отпускание пальца система не прислала
	check(g.held.is_empty() and g.board_touch.is_empty(), "пауза отпускает кнопки и касания поля")
	_resume_tap()
	var x: int = g.piece_pos.x
	_run_for(0.5)
	check(g.piece_pos.x == x, "после паузы фигура сама не едет в сторону")


func _test_slow_real_time() -> void:
	print("— замедление праздника и пауза")
	_setup()
	g.juice.on_cascade(4)
	check(g.juice.slow > 0.0 and g.juice.time_k() < 1.0, "×4 — замедление")
	g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_run_for(0.5)
	check(g.juice.slow == 0.0 and g.juice.time_k() == 1.0, "замедление идёт в настоящем времени и кончается и на паузе")
	check(Engine.time_scale == 1.0, "Engine.time_scale не трогается")
	_resume_tap()
	g.juice.on_boom(3)
	g.start_level(3)
	check(g.juice.slow == 0.0, "новая попытка снимает замедление")
	g.juice.on_cascade(3)
	g.go_home()
	_run_for(0.5)
	check(g.juice.slow == 0.0, "и уход домой тоже (время идёт)")


func _test_tutorial_info_pause() -> void:
	print("— пояснение обучения во время каскада и пауза")
	g.tut.enabled = true
	_setup()
	g.hard_drop()
	g.tut._show("l1_cascade")
	check(g.tut.is_info() and g.state == g.State.CLEARING, "пояснение держит каскад")
	g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_resume_tap()
	check(g.state == g.State.CLEARING and g.tut.is_info(), "после паузы — снова каскад с пояснением")
	for i in 4:  # за пояснением каскада идёт пояснение о кристаллах — оба закрываются касанием
		_run_for(0.5)
		_tap(g.board_pos + Vector2(100, 300))
	check(not g.tut.active(), "касания закрывают пояснения")
	_run_for(1.0)
	check(g.has_piece and g.state == g.State.PLAYING, "каскад доигран, есть фигура")
	g.tut.cur = ""
	g.tut.enabled = false


func _test_undo_keeps_pause_source() -> void:
	print("— «Совиное время» не возвращает старое «откуда пауза»")
	check(g.owl.SKIP.has("paused_from") and g.owl.SKIP.has("draw_off"), "paused_from и draw_off не входят в снимок отмены")
	_setup()
	g.hard_drop()
	g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_resume_tap()
	_run_for(1.0)
	check(g.undo_piece(), "отмена после каскада")
	check(g.state == g.State.PLAYING and g.has_piece, "после отмены — фигура сверху")
	_tap(g.pause_rect.get_center())
	_resume_tap()
	check(g.state == g.State.PLAYING and _alive(), "пауза и продолжение после отмены — игра идёт")


# ---------- Размеры шрифта ----------

## «Супер!», всплывающие очки, «Совиное время!», облачко героя и «подпрыгивающие» счётчики
## рисуются одним размером шрифта (масштабом): кэш шрифта не растёт на каждый кадр анимации.
func _test_font_sizes() -> void:
	print("— «прыгающие» надписи не плодят размеры шрифта")
	_setup()
	g.set_process(false)
	# прогреть: по одному показу каждой надписи
	await _animate(1)
	var m0 := OS.get_static_memory_usage()
	await _animate(4)
	var grow := (OS.get_static_memory_usage() - m0) / 1048576.0
	print("    рост памяти за 4 показа анимаций: %.1f МБ" % grow)
	check(grow < 12.0, "память почти не растёт (раньше «Супер!» на всех размерах — ~110 МБ)")
	g.set_process(true)


func _animate(rounds: int) -> void:
	for r in rounds:
		g.juice.on_cascade(3 + r % 2)
		g.owl.flip = 0.0
		g.say.on_event("owl", "boy", "win")
		g._popup("КАСКАД ×3", Vector2(300, 500), g.ACCENT, 46)
		g._popup("+1234", Vector2(300, 560), g.TEXT, 38)
		g.juice.bump = 1.0
		g.score_bump = 1.0
		for i in 70:
			# шаг чуть разный в каждом показе — попадаем на новые промежуточные размеры
			var dt := (1.0 + 0.13 * r) / 60.0
			g.juice.update(dt)
			g.owl.flip += dt
			g.say.update(dt)
			g._update_effects(dt)
			g.queue_redraw()
			await process_frame


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
