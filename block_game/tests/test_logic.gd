extends SceneTree
## Запуск: godot --headless --path block_game -s tests/test_logic.gd

var failed := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)

func make_game() -> Node2D:
	var g: Node2D = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.new_game()
	return g

func _initialize() -> void:
	var g := make_game()
	check(g.state == g.State.PLAYING, "игра стартует")
	check(g.has_piece, "появилась фигура")

	# Стенки: фигура не уходит за край
	for i in 20:
		g.move(-1)
	var min_x := 99
	for c in g.piece_cells:
		min_x = mini(min_x, c.x + g.piece_pos.x)
	check(min_x == 0, "упор в левую стенку")

	# Очистка линии: заполняем нижний ряд кроме одной клетки, кидаем I вертикально
	g.board.fill(-1)
	for x in range(1, g.COLS):
		g.board[(g.ROWS - 1) * g.COLS + x] = 3
	g.next_type = 0
	g._spawn()
	g.rotate_piece()  # I вертикально
	for i in 20:
		g.move(-1)
	g.hard_drop()
	check(g.state == g.State.CLEARING, "полный ряд уходит в очистку")
	g.step(1.0)
	check(g.lines == 1, "засчитана 1 линия")
	check(g.score >= 100, "очки за линию")
	var bottom_filled := 0
	for x in g.COLS:
		if g.board[(g.ROWS - 1) * g.COLS + x] != -1:
			bottom_filled += 1
	check(bottom_filled == 1, "после очистки внизу осталась часть I-фигуры")

	# Конец игры: забиваем верх
	g.board.fill(0)
	for y in range(g.ROWS - 1):
		g.board[y * g.COLS] = -1
	g._spawn()
	check(g.state == g.State.GAME_OVER, "конец игры при переполнении")

	# Поворот O ничего не меняет, поворот 4 раза возвращает фигуру
	g.new_game()
	g.board.fill(-1)
	g.next_type = 2
	g._spawn()
	var before: Array = g.piece_cells.duplicate()
	for i in 4:
		g.rotate_piece()
	check(g.piece_cells == before, "4 поворота = исходная фигура")

	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)
