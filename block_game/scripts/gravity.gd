extends RefCounted
## «Липкая» гравитация Cascado: после очистки линий падают не отдельные клетки,
## а группы. Общий код для игры (game.gd) и робота-тестера (tools/level_bot.gd).
##
## board — тип/цвет клеток (EMPTY = пусто), ids — номер фигуры для каждой клетки
## (массив той же длины). Группа — связанные по соседству (вверх/вниз/влево/вправо)
## клетки с одинаковым номером > 0. Клетка с номером <= 0 или со значением из
## `loose` (камень, кристалл) — отдельная группа из одной клетки.
## Массивы могут быть Array или PackedInt32Array, меняются на месте.


## Очищает ряды: клетки становятся пустыми, номер фигуры сбрасывается.
static func clear_rows(board, ids, rows_list: Array, cols: int, empty: int) -> void:
	for y in rows_list:
		for x in cols:
			board[y * cols + x] = empty
			ids[y * cols + x] = 0


## Осыпает все группы поля: каждый проход сдвигает на 1 клетку вниз каждую группу,
## под всеми клетками которой пусто (или клетка той же группы); проходы повторяются,
## пока что-то движется. Группы обходятся снизу вверх, поэтому стопка падает за один
## проход. Возвращает, на сколько рядов упала каждая клетка (по новому месту клетки).
## only_above >= 0: группы целиком ниже ряда only_above (обычно нижней очищенной линии)
## остаются на месте и служат опорой; -1 — падать могут все группы поля.
static func settle(board, ids, cols: int, rows: int, empty: int, loose: Array, only_above := -1) -> PackedInt32Array:
	var n := cols * rows
	var fall := PackedInt32Array()
	fall.resize(n)
	fall.fill(0)
	var grp := PackedInt32Array()
	grp.resize(n)
	grp.fill(-1)
	var groups: Array = []  # у каждой группы — массив клеток Vector2i
	var bottoms: Array = []  # [нижний ряд, номер группы] для порядка обхода
	for i in n:
		if board[i] == empty or grp[i] >= 0:
			continue
		var gi := groups.size()
		var id: int = ids[i]
		var single: bool = id <= 0 or loose.has(board[i])
		var cells: Array = []
		var stack: Array = [i]
		grp[i] = gi
		var low := 0
		var top := rows
		while not stack.is_empty():
			var j: int = stack.pop_back()
			var cx := j % cols
			var cy := j / cols
			cells.append(Vector2i(cx, cy))
			low = maxi(low, cy)
			top = mini(top, cy)
			if single:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = cx + d.x
				var ny: int = cy + d.y
				if nx < 0 or nx >= cols or ny < 0 or ny >= rows:
					continue
				var k := ny * cols + nx
				if grp[k] >= 0 or board[k] == empty or ids[k] != id or loose.has(board[k]):
					continue
				grp[k] = gi
				stack.append(k)
		groups.append(cells)
		if only_above < 0 or top < only_above:
			bottoms.append([low, gi])
	bottoms.sort_custom(func(a, b): return a[0] > b[0])
	var drop := PackedInt32Array()
	drop.resize(groups.size())
	drop.fill(0)
	var moved := true
	while moved:
		moved = false
		for bt in bottoms:
			var gi: int = bt[1]
			var cells: Array = groups[gi]
			var ok := true
			for c in cells:
				if c.y + 1 >= rows:
					ok = false
					break
				var below: int = grp[(c.y + 1) * cols + c.x]
				if below != -1 and below != gi:
					ok = false
					break
			if not ok:
				continue
			var vals: Array = []
			var idv: Array = []
			for c in cells:
				var idx: int = c.y * cols + c.x
				vals.append(board[idx])
				idv.append(ids[idx])
				board[idx] = empty
				ids[idx] = 0
				grp[idx] = -1
			for k in cells.size():
				var c: Vector2i = cells[k] + Vector2i(0, 1)
				cells[k] = c
				var idx: int = c.y * cols + c.x
				board[idx] = vals[k]
				ids[idx] = idv[k]
				grp[idx] = gi
			drop[gi] += 1
			moved = true
	for gi in groups.size():
		if drop[gi] == 0:
			continue
		for c in groups[gi]:
			fall[c.y * cols + c.x] = drop[gi]
	return fall


## Полные ряды поля (сверху вниз).
static func full_rows(board, cols: int, rows: int, empty: int) -> Array:
	var out: Array = []
	for y in rows:
		var ok := true
		for x in cols:
			if board[y * cols + x] == empty:
				ok = false
				break
		if ok:
			out.append(y)
	return out


## Мгновенный розыгрыш всей цепочки (для робота): очистка → осыпание → снова,
## пока есть полные ряды. Возвращает собранные кристаллы, линии и длину цепочки.
static func resolve(board, ids, cols: int, rows: int, empty: int, loose: Array, crystal: int, all_fall := true) -> Dictionary:
	var crystals := 0
	var lines := 0
	var chain := 0
	while true:
		var full := full_rows(board, cols, rows, empty)
		if full.is_empty():
			break
		chain += 1
		lines += full.size()
		for y in full:
			for x in cols:
				if board[y * cols + x] == crystal:
					crystals += 1
		clear_rows(board, ids, full, cols, empty)
		settle(board, ids, cols, rows, empty, loose, -1 if all_fall else full.max())
	return {"crystals": crystals, "lines": lines, "chain": chain}
