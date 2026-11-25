extends SceneTree
## Запуск: godot --headless --path block_game -s tests/test_logic.gd

var failed := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)

func count(g, v: int) -> int:
	var n := 0
	for c in g.board:
		if c == v:
			n += 1
	return n

func run(g, sec: float) -> void:
	var t := 0.0
	while t < sec:
		g.step(0.02)
		t += 0.02

func _initialize() -> void:
	# Тест «Победа» сохраняет прогресс — бережём настоящее сохранение игрока.
	var save_path := "user://save.cfg"
	var had_save := FileAccess.file_exists(save_path)
	var save_bytes := FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()

	var g: Node2D = load("res://scripts/game.gd").new()
	root.add_child(g)

	g.start_level(1)
	check(g.state == g.State.PLAYING and g.has_piece, "уровень 1 стартует, есть фигура")
	check(count(g, g.CRYSTAL) == g.crystals_total and g.crystals_total >= 2, "кристаллы расставлены")
	var crystals_l1: Array = []
	for i in g.board.size():
		if g.board[i] == g.CRYSTAL:
			crystals_l1.append(i)
	g.start_level(1)
	var again: Array = []
	for i in g.board.size():
		if g.board[i] == g.CRYSTAL:
			again.append(i)
	check(crystals_l1 == again, "уровень всегда одинаковый")
	g.start_level(20)
	check(g.crystals_total <= 8 and count(g, g.CRYSTAL) == g.crystals_total, "поздний уровень корректен")

	# Висячие блоки (поле hang): над верхним рядом камня висит блок, под ним дыра,
	# кристаллов столько же, сколько в таблице
	var lv: Script = load("res://scripts/levels.gd")
	var hang_ok := true
	for n in range(1, lv.LEVELS.size() + 1):
		var p: Dictionary = lv.params(n)
		if p.get("hang", 0) <= 0:
			continue
		g.start_level(n)
		var top: int = g.ROWS - clampi(p.rows, 1, 7)
		var hanging := 0
		for x in g.COLS:
			if g.board[(top - 1) * g.COLS + x] == g.STONE and g.board[top * g.COLS + x] == -1:
				hanging += 1
		if hanging != 1 or count(g, g.CRYSTAL) != g.crystals_total:
			hang_ok = false
	check(hang_ok, "висячий блок над дырой на всех уровнях с hang")
	var speed_ok := true
	for n in range(1, 80):
		if lv.params(n).speed > lv.MAX_SPEED:
			speed_ok = false
	check(speed_ok, "скорость не выше 0,26 с на клетку (ступень 21) и после 50-го")

	# Уровень 1: вертикальная фигура в колодец даёт каскад
	g.start_level(1)
	var shaft := -1
	for x in g.COLS:
		if g.board[(g.ROWS - 1) * g.COLS + x] == -1:
			shaft = x
	g.next_type = 1  # палочка из трёх
	g._spawn()
	g.rotate_piece()
	var guard := 0
	while guard < 10:
		var minx := 99
		for c in g.piece_cells:
			minx = mini(minx, c.x + g.piece_pos.x)
		if minx == shaft or not g.move(1 if shaft > minx else -1):
			break
		guard += 1
	g.hard_drop()
	var max_chain: int = g.chain
	for i in 60:
		g.step(0.02)
		max_chain = maxi(max_chain, g.chain)
	check(max_chain >= 2, "уровень 1: каскад ×2 с первой фигуры")

	# Стенки
	g.start_level(1)
	for i in 20:
		g.move(-1)
	var min_x := 99
	for c in g.piece_cells:
		min_x = mini(min_x, c.x + g.piece_pos.x)
	check(min_x == 0, "упор в левую стенку")

	# Поворот 4 раза = исходная фигура (для всех вращаемых)
	var ok := true
	for t in g.SHAPES.size():
		g.start_level(1)
		g.board.fill(-1)
		g.next_type = t
		g._spawn()
		var before: Array = g.piece_cells.duplicate()
		for i in 4:
			g.rotate_piece()
		if g.piece_cells != before:
			ok = false
	check(ok, "4 поворота возвращают любую фигуру")

	# Линия с кристаллом: кристалл собирается
	g.start_level(1)
	g.board.fill(-1)
	var y: int = g.ROWS - 1
	for x in range(2, g.COLS):
		g.board[y * g.COLS + x] = g.STONE
	g.board[y * g.COLS + 5] = g.CRYSTAL
	g.board[(g.ROWS - 2) * g.COLS + 3] = g.CRYSTAL  # второй кристалл, чтобы уровень не закончился
	g.crystals_total = 2
	g.crystals_left = 2
	g.next_type = 0  # домино горизонтально
	g._spawn()
	for i in 10:
		g.move(-1)
	g.hard_drop()
	check(g.state == g.State.CLEARING, "полная линия уходит в очистку")
	check(g.crystals_left == 1, "кристалл в линии собран")
	run(g, 1.0)
	check(g.board[(g.ROWS - 1) * g.COLS + 3] == g.CRYSTAL, "каскад: верхний кристалл осыпался вниз")
	check(g.state == g.State.PLAYING, "после очистки игра продолжается")

	# Каскад-цепочка: после осыпания собирается вторая линия
	g.start_level(1)
	g.board.fill(-1)
	var b: int = g.ROWS - 1
	for x in range(1, g.COLS):
		g.board[b * g.COLS + x] = g.STONE           # нижний ряд: дыра в x=0
	for x in range(2, g.COLS):
		g.board[(b - 1) * g.COLS + x] = g.STONE     # ряд выше: дыры в x=0,1
	g.board[(b - 3) * g.COLS + 1] = g.STONE         # висящий блок над дырой (x=1)
	g.crystals_total = 1
	g.crystals_left = 1
	g.board[0 * g.COLS + 7] = g.CRYSTAL             # кристалл далеко, чтобы не выиграть
	# вертикальная I3 в колонку 0: закрывает дыры в нижних двух рядах и ещё одну клетку
	g.next_type = 1
	g._spawn()
	g.rotate_piece()
	for i in 10:
		g.move(-1)
	g.hard_drop()
	check(g.chain == 1, "первая линия")
	run(g, 1.0)
	check(g.chain >= 2 or g.score >= 100 + 250, "каскад дал вторую линию (цепочка)")

	# Победа: последний кристалл
	g.start_level(1)
	g.board.fill(-1)
	for x in range(2, g.COLS):
		g.board[(g.ROWS - 1) * g.COLS + x] = g.STONE
	g.board[(g.ROWS - 1) * g.COLS + 4] = g.CRYSTAL
	g.crystals_total = 1
	g.crystals_left = 1
	g.next_type = 0
	g._spawn()
	for i in 10:
		g.move(-1)
	g.hard_drop()
	run(g, 1.0)
	check(g.state == g.State.WIN and g.last_stars >= 1, "все кристаллы — уровень пройден")

	# Поражение
	g.start_level(1)
	for i in g.board.size():
		g.board[i] = g.STONE if i % g.COLS != 0 else -1
	g._spawn()
	check(g.state == g.State.LOSE, "переполнение — поражение")

	if had_save:
		var f := FileAccess.open(save_path, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)
