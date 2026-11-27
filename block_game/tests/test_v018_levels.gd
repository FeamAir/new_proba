extends SceneTree
## Тесты версии 0.18 (уровни): свободный старт и разгон скорости внутри уровня.
##   Стартовая заполненность: в залах 1–2 камень и висячие блоки занимают не выше 4 рядов
##   из 14 (~29% высоты), на всех уровнях 1–100 и в «Бесконечных глубинах» — не выше 6 (~43%);
##   по клеткам — не больше 30% поля.
##   Скорость не зависит от номера уровня: старт — база зала (растёт медленно и ограничена),
##   затем ступень каждые ramp секунд до потолка; уровень 1000 по скорости как 100-й;
##   на «отдыхающих» уровнях разгон медленнее.
##   Если в game.gd подключён разгон по времени (поле level_time), проверяется и он:
##   время идёт только в игре (не на паузе и не во время каскада), «медленное падение» замедляет.
## Запуск: godot --headless --path block_game -s tests/test_v018_levels.gd

var failed := 0
const Levels := preload("res://scripts/levels.gd")
const Access := preload("res://scripts/access.gd")
const SAVE := "user://save.cfg"


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

	_test_fill(g)
	_test_speed_formula()
	_test_speed_game(g)

	if had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	g.free()
	quit(1 if failed else 0)


# Высота занятой части поля (рядов снизу до самой верхней занятой клетки) и число занятых клеток.
func _fill(g) -> Array:
	var top: int = g.ROWS
	var cells := 0
	for i in g.board.size():
		if g.board[i] != g.EMPTY:
			cells += 1
			top = mini(top, i / g.COLS)
	return [g.ROWS - top, cells]


func _test_fill(g) -> void:
	print("— свободный старт")
	var early_ok := true
	var all_ok := true
	var cells_ok := true
	var max_h := 0
	for n in range(1, 131):
		g.start_level(n)
		var f := _fill(g)
		max_h = maxi(max_h, f[0])
		if n <= 20 and f[0] > 4:
			early_ok = false
			printerr("    уровень ", n, ": занято ", f[0], " рядов")
		if f[0] > 6:
			all_ok = false
			printerr("    уровень ", n, ": занято ", f[0], " рядов")
		if f[1] > g.COLS * g.ROWS * 0.30:
			cells_ok = false
			printerr("    уровень ", n, ": занято ", f[1], " клеток")
	check(early_ok, "залы 1–2: занято не выше 4 рядов из 14 (~29%)")
	check(all_ok, "уровни 1–130: занято не выше 6 рядов из 14 (~43%%), самое высокое — %d" % max_h)
	check(cells_ok, "уровни 1–130: занято не больше 30% клеток поля")
	var rows_ok := true
	for i in Levels.LEVELS.size():
		var p: Dictionary = Levels.LEVELS[i]
		if int(p.rows) > (3 if i < 20 else 5) or p.has("speed"):
			rows_ok = false
	check(rows_ok, "в таблице: залы 1–2 — до 3 рядов камня, дальше до 5; поля speed в строках нет")


func _test_speed_formula() -> void:
	print("— формула скорости")
	check(Levels.base_speed(1) == 1 and Levels.base_speed(20) == 1 and Levels.base_speed(21) == 2, "база: ступень 1 на уровнях 1–20, дальше +1 каждые 20")
	check(Levels.base_speed(100) == Levels.BASE_MAX and Levels.base_speed(1000) == Levels.BASE_MAX, "база ограничена: уровень 1000 стартует как 100-й")
	check(Levels.ramp_sec(1) == Levels.RAMP_START and Levels.ramp_sec(1000) == Levels.RAMP_MIN, "темп разгона: 15 с на ступень в начале, не меньше 10 с дальше")
	var p1000: Dictionary = Levels.params(1000)
	var p100: Dictionary = Levels.params(100)
	check(p1000.base == p100.base and p1000.ramp == Levels.RAMP_MIN and p1000.speed == p1000.base, "уровень 1000: та же база, speed = стартовая ступень")
	check(Levels.speed_at(1, 15.0, 0.0) == 1 and Levels.speed_at(1, 15.0, 14.9) == 1 and Levels.speed_at(1, 15.0, 15.0) == 2, "ступень быстрее через каждые ramp секунд")
	check(Levels.speed_at(1, 15.0, 30.0) == 3 and Levels.speed_at(1, 15.0, 60.0) == 5 and Levels.speed_at(1, 15.0, 120.0) == 9, "уровень 1: 30 с — ступень 3, 60 с — 5, 120 с — 9")
	check(Levels.speed_at(5, 10.0, 1.0e6) == Levels.SPEED_CAP and Levels.speed_at(1, 15.0, -5.0) == 1, "потолок разгона SPEED_CAP, отрицательное время — старт")
	var mono := true
	for t in range(0, 600, 3):
		if Levels.speed_at(3, 12.0, t + 3.0) < Levels.speed_at(3, 12.0, t):
			mono = false
	check(mono, "скорость со временем только растёт")
	var rest_ok := true
	var slow_ok := true
	for n in range(1, 101):
		var p: Dictionary = Levels.params(n)
		if p.get("rest", false) and p.ramp <= Levels.ramp_sec(n):
			rest_ok = false
		if 0.9 * pow(0.94, p.base - 1) < 0.69:
			slow_ok = false
	check(rest_ok, "на «отдыхающих» уровнях разгон медленнее")
	check(slow_ok, "старт каждого уровня спокойный: не быстрее 0,7 с на клетку")


func _test_speed_game(g) -> void:
	print("— разгон в игре")
	g.access = Access.new()
	g.start_level(1)
	check(g.speed_step == 1 and is_equal_approx(g.fall_interval(), 0.9), "уровень 1 стартует со ступени 1 (0,9 с на клетку)")
	g.start_level(100)
	check(g.speed_step == Levels.base_speed(100), "уровень 100 стартует с базы зала")
	if not ("level_time" in g):
		print("  (разгон по времени в game.gd ещё не подключён — проверки игры пропущены)")
		return
	g.start_level(21)
	var ramp: float = Levels.params(21).ramp
	var s0: int = g.speed_step
	for i in int(ramp / 0.5) + 2:
		g.state = g.State.PLAYING
		g.has_piece = true
		g.piece_pos.y = 0
		g.step(0.5)
	check(g.speed_step == s0 + 1, "через ramp секунд игры — ступень быстрее (%d → %d)" % [s0, g.speed_step])
	var t: float = g.level_time
	g.state = g.State.PAUSED
	g.step(60.0)
	check(is_equal_approx(g.level_time, t), "пауза время не двигает")
	g.state = g.State.CLEARING
	g.clear_timer = 100.0
	g.step(5.0)
	check(is_equal_approx(g.level_time, t), "каскад время не двигает")
	var base: float = g.fall_interval()
	g.access.slow = true
	check(is_equal_approx(g.fall_interval(), base / 0.7), "медленное падение по-прежнему замедляет и после разгона")
	g.access.slow = false
	g.start_level(21)
	check(is_zero_approx(g.level_time) and g.speed_step == s0, "новая попытка — снова спокойный старт")
