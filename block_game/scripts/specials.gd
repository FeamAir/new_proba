extends RefCounted
## 0.18: особые клетки и новые цели уровня. Общий код для игры (game.gd) и робота-тестера
## (tools/level_bot.gd); рисование — scripts/specials_draw.gd.
##
## Кристалл-бомба (BOMB, поле "bomb" строки уровня) — огненный кристалл в камне.
##   Взрывается, когда очищается ряд с ней (как обычный кристалл «освобождается» очисткой ряда),
##   и выбивает квадрат 3×3 вокруг себя: камень, кристаллы (они засчитываются освобождёнными),
##   части фигур и клетки тайника исчезают. Другая бомба в квадрате взрывается следом (цепочка).
##   Потом всё сверху осыпается по обычной «липкой» гравитации (gravity.gd) — может начаться каскад.
##   Каждый взрыв — отдельное звено каскада (links): очищен ряд с бомбой — «КАСКАД ×2».
##   Бомбы ставятся (place) прежде всего туда, где взрыв помогает каскаду: под рядами с висячим
##   блоком, над рядом, все дыры которого попадают в квадрат взрыва (их засыплет сверху).
## Кротёнок (PET, цель "goal": "pet") — одиночная клетка, сидит на камне и осыпается вниз,
##   как отдельный камешек. Очистка ряда и взрыв его не трогают: ряд очищается вокруг него.
##   Цель — довести его до самого нижнего ряда.
## Янтарный тайник (CHEST, цель "goal": "chest" или бонус "chest": 1) — сундук 2×2 в камне.
##   Держится одной группой (у клеток общий номер CHEST_ID в ids, падает целиком, как фигура).
##   Открывается, когда исчезли все 4 его клетки (очищены оба его ряда или взрыв); внутри
##   3–5 осколков к награде за уровень.
##
## Раскладка новинок (place) — отдельным генератором случайных чисел ПОСЛЕ всей прежней
## раскладки (levels.gd add_hang): прежние клетки камня, дыры и кристаллы не двигаются,
## бомба и тайник занимают клетки простого камня, кротёнок — пустую клетку над камнем.

const STONE := 7
const CRYSTAL := 8
const BOMB := 9
const PET := 10
const CHEST := 11
## Номер «фигуры» у клеток тайника (держатся вместе). Игровые фигуры нумеруются с 1, робот — с 1000000.
const CHEST_ID := 900000
## Отдельные клетки (падают поодиночке): камень, кристалл, бомба, кротёнок.
const LOOSE := [STONE, CRYSTAL, BOMB, PET]
const CHEST_MIN := 3
const CHEST_MAX := 5
## Цели уровня
const GOAL_CRYSTALS := "crystals"
const GOAL_PET := "pet"
const GOAL_CHEST := "chest"


## Цель уровня по строке таблицы.
static func goal_of(p: Dictionary) -> String:
	var gl := str(p.get("goal", GOAL_CRYSTALS))
	return gl if gl in [GOAL_PET, GOAL_CHEST] else GOAL_CRYSTALS


## Зерно отдельного потока случайных чисел для новинок (не трогает прежний генератор раскладки).
static func seed_of(p: Dictionary) -> int:
	return int(p.seed) * 7 + 180018


## Расставить новинки по строке уровня p на уже готовой раскладке board (EMPTY = -1).
## Возвращает {"bombs": сколько поставлено, "pet": индекс клетки или -1, "chest": верхний левый индекс или -1,
## "shards": осколков в тайнике}.
static func place(board: Array, p: Dictionary, cols: int, rows: int) -> Dictionary:
	var res := {"bombs": 0, "pet": -1, "chest": -1, "shards": 0}
	var goal := goal_of(p)
	var nb: int = clampi(int(p.get("bomb", 0)), 0, 4)
	var want_chest: bool = goal == GOAL_CHEST or int(p.get("chest", 0)) > 0
	if nb == 0 and goal == GOAL_CRYSTALS and not want_chest:
		return res
	var sr := RandomNumberGenerator.new()
	sr.seed = seed_of(p)
	var stone_rows: int = clampi(int(p.rows), 1, 7)
	var y0 := rows - stone_rows
	# Тайник-цель — в двух самых нижних рядах камня: на его место встают камень, кристалл или дыра
	# (кристалл переезжает на простой камень — сначала того же ряда, иначе ближайшего выше; дыра
	# меняется местами с камнем того же ряда, только ниже пар с висячим блоком). Число кристаллов
	# на поле и дыр в каждом ряду не меняется, а открыть тайник можно, только докопавшись до дна.
	# Бонусный тайник — в случайной паре рядов камня, только на простом камне.
	var hang: int = mini(int(p.get("hang", 0)), stone_rows / 2)
	var low := y0 + 2 * hang  # первый ряд ниже пар с висячим блоком
	if want_chest and stone_rows >= 2:
		var pairs: Array = []
		for y in range(rows - 2, y0 - 1, -1):
			pairs.append(y)
		var is_goal := goal == GOAL_CHEST
		if not is_goal:
			_shuffle(pairs, sr)
		for y in pairs:
			var xs: Array = []
			for x in cols - 1:
				if _chest_fits(board, x, y, cols, y0, low if is_goal else rows + 1, is_goal):
					xs.append(x)
			if xs.is_empty():
				continue
			var x: int = xs[sr.randi_range(0, xs.size() - 1)]
			var moved: Array = []  # [ряд, что было] — сначала дыры (только свой ряд), потом кристаллы
			for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var i: int = (y + d.y) * cols + x + d.x
				if board[i] == -1:
					moved.push_front([y + d.y, -1])
				elif board[i] == CRYSTAL:
					moved.push_back([y + d.y, CRYSTAL])
				board[i] = CHEST
			for m in moved:
				var j := _free_stone(board, x, m[0], m[0] if m[1] == -1 else y0, cols, sr)
				if j >= 0:
					board[j] = m[1]
			res.chest = y * cols + x
			res.shards = sr.randi_range(CHEST_MIN, CHEST_MAX)
			break
	# Бомбы — на клетках простого камня в рядах камня (не на островках и не на висячем блоке).
	# Сначала (tier 0) — клетки, под которыми ряд с дырами только в квадрате взрыва: после взрыва их
	# засыплет сверху и ряд может закрыться сам; затем (1) — ниже пар с висячим блоком (взрыв не
	# портит заготовку каскада); остальные (2) — в последнюю очередь.
	if nb > 0:
		var tiers: Array = [[], [], []]
		for i in range(y0 * cols, rows * cols):
			if board[i] != STONE:
				continue
			var x := i % cols
			var y := i / cols
			var tier := 2
			if y >= low:
				tier = 1
			if y + 1 < rows:
				var nh := 0
				var inside := true
				for xx in cols:
					if board[(y + 1) * cols + xx] == -1:
						nh += 1
						if absi(xx - x) > 1:
							inside = false
				if nh > 0 and inside:
					tier = 0
			tiers[tier].append(i)
		var cand: Array = []
		for t in tiers:
			_shuffle(t, sr)
			cand.append_array(t)
		for i in mini(nb, cand.size()):
			board[cand[i]] = BOMB
			res.bombs += 1
	# Кротёнок — на верхнем ряду камня: пустая клетка, под ней камень (не дыра), сверху открыто.
	# Из таких мест — где под ним в колонке меньше всего дыр: провалиться в дыру он не может,
	# опускается только когда под ним очищаются ряды (иначе цель была бы легче обычной).
	if goal == GOAL_PET:
		var spots: Array = []
		var best := 99
		for y in range(y0 - 1, 0, -1):
			for x in cols:
				var i := y * cols + x
				var below: int = board[(y + 1) * cols + x]
				if board[i] != -1 or below == -1 or below == CHEST or (y > 0 and board[(y - 1) * cols + x] != -1):
					continue
				var holes := 0
				for yy in range(y + 1, rows):
					if board[yy * cols + x] == -1:
						holes += 1
				if holes < best:
					best = holes
					spots.clear()
				if holes == best:
					spots.append(i)
			if not spots.is_empty():
				break
		if not spots.is_empty():
			res.pet = spots[sr.randi_range(0, spots.size() - 1)]
			board[res.pet] = PET
	return res


## Помещается ли тайник 2×2 с левым верхним углом (x, y). Простой камень — всегда; для цели
## (gems_ok) — и кристалл (если в рядах камня вне тайника есть простой камень, куда он переедет),
## и прикрытая сверху дыра в рядах не выше hole_from (если в том же ряду вне тайника есть камень для обмена).
static func _chest_fits(board: Array, x: int, y: int, cols: int, y0: int, hole_from: int, gems_ok: bool) -> bool:
	var gems := 0
	for dy in 2:
		var holes := 0
		for dx in 2:
			var v: int = board[(y + dy) * cols + x + dx]
			if v == STONE:
				continue
			if v == CRYSTAL and gems_ok:
				gems += 1
			elif v == -1 and gems_ok and y + dy >= hole_from and board[(y + dy - 1) * cols + x + dx] != -1:
				holes += 1  # только прикрытая дыра (не колодец и не открытая шахта)
			else:
				return false
		var free := 0
		for xx in cols:
			if (xx < x or xx > x + 1) and board[(y + dy) * cols + xx] == STONE:
				free += 1
		if free < holes:
			return false
	var spare := 0
	for i in range(y0 * cols, board.size()):
		var xx := i % cols
		var yy := i / cols
		if board[i] == STONE and not ((xx == x or xx == x + 1) and (yy == y or yy == y + 1)):
			spare += 1
	return spare >= gems + 2  # с запасом: дыры тоже меняются местами с камнем


## Простой камень вне тайника (колонки x, x+1) для переезда кристалла или дыры: в ряду y,
## а если там нет — в ближайшем ряду выше (не выше top).
static func _free_stone(board: Array, x: int, y: int, top: int, cols: int, sr: RandomNumberGenerator) -> int:
	for yy in range(y, top - 1, -1):
		var free: Array = []
		for xx in cols:
			if (xx < x or xx > x + 1) and board[yy * cols + xx] == STONE:
				free.append(yy * cols + xx)
		if not free.is_empty():
			return free[sr.randi_range(0, free.size() - 1)]
	return -1


static func _shuffle(a: Array, lr: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := lr.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## Номера фигур клеток тайника: все клетки CHEST держатся одной группой.
static func tag_chest(board, ids) -> void:
	for i in board.size():
		if board[i] == CHEST:
			ids[i] = CHEST_ID


static func count(board, v: int) -> int:
	var n := 0
	for c in board:
		if c == v:
			n += 1
	return n


## Ряд кротёнка (-1 — его нет на поле).
static func pet_row(board, cols: int) -> int:
	for i in board.size():
		if board[i] == PET:
			return i / cols
	return -1


## Взрывы при очистке рядов rows_list: бомбы в этих рядах взрываются, каждая выбивает 3×3;
## бомба, попавшая во взрыв, взрывается следом. Возвращает {"cells": индексы клеток ВНЕ
## очищаемых рядов, которые выбивает взрыв (кротёнок не выбивается), "bombs": центры
## взорвавшихся бомб (Vector2i) по порядку}.
static func blast(board, rows_list: Array, cols: int, rows: int, empty := -1) -> Dictionary:
	var in_rows := {}
	for y in rows_list:
		in_rows[y] = true
	var queue: Array = []
	var done := {}
	for y in rows_list:
		for x in cols:
			if board[y * cols + x] == BOMB:
				queue.append(Vector2i(x, y))
				done[y * cols + x] = true
	var cells := {}
	var order: Array = []
	var qi := 0
	while qi < queue.size():
		var c: Vector2i = queue[qi]
		qi += 1
		order.append(c)
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var x: int = c.x + dx
				var y: int = c.y + dy
				if x < 0 or x >= cols or y < 0 or y >= rows:
					continue
				var i := y * cols + x
				var v: int = board[i]
				if v == empty or v == PET:
					continue
				if v == BOMB and not done.has(i):
					done[i] = true
					queue.append(Vector2i(x, y))
				if not in_rows.has(y):
					cells[i] = true
	var out: Array = cells.keys()
	out.sort()
	return {"cells": out, "bombs": order}


## Что исчезнет при очистке рядов rows_list вместе со взрывом blast_cells:
## {"crystals", "chest" (клеток тайника), "low" (нижний ряд, где что-то исчезло)}.
static func tally(board, rows_list: Array, blast_cells: Array, cols: int) -> Dictionary:
	var crystals := 0
	var chest := 0
	var low: int = rows_list.max() if not rows_list.is_empty() else -1
	for y in rows_list:
		for x in cols:
			var v: int = board[y * cols + x]
			if v == CRYSTAL:
				crystals += 1
			elif v == CHEST:
				chest += 1
	for i in blast_cells:
		var v: int = board[i]
		if v == CRYSTAL:
			crystals += 1
		elif v == CHEST:
			chest += 1
		low = maxi(low, i / cols)
	return {"crystals": crystals, "chest": chest, "low": low}


## Сколько звеньев каскада даёт очистка рядов, при которой взорвалось bombs бомб:
## сама очистка — одно звено, каждый взрыв — ещё одно (ряд с бомбой — уже ×2, две бомбы цепочкой — ×3).
static func links(bombs: int) -> int:
	return 1 + maxi(bombs, 0)


## Очистить ряды (кроме кротёнка — он остаётся на месте) и клетки взрыва.
static func clear(board, ids, rows_list: Array, blast_cells: Array, cols: int, empty := -1) -> void:
	for y in rows_list:
		for x in cols:
			var i: int = y * cols + x
			if board[i] == PET:
				continue
			board[i] = empty
			ids[i] = 0
	for i in blast_cells:
		if board[i] == PET:
			continue
		board[i] = empty
		ids[i] = 0


## Мгновенный розыгрыш всей цепочки (для робота) с бомбами, кротёнком и тайником.
## Возвращает {"crystals", "lines", "chain", "chest" (клеток тайника исчезло), "bombs" (взрывов)}.
static func resolve(board, ids, cols: int, rows: int, empty: int, all_fall := false) -> Dictionary:
	const Gravity := preload("res://scripts/gravity.gd")
	var r := {"crystals": 0, "lines": 0, "chain": 0, "chest": 0, "bombs": 0}
	while true:
		var full: Array = Gravity.full_rows(board, cols, rows, empty)
		if full.is_empty():
			break
		r.lines += full.size()
		var bl: Dictionary = blast(board, full, cols, rows, empty)
		r.chain += links(bl.bombs.size())
		var t := tally(board, full, bl.cells, cols)
		r.crystals += t.crystals
		r.chest += t.chest
		r.bombs += bl.bombs.size()
		clear(board, ids, full, bl.cells, cols, empty)
		Gravity.settle(board, ids, cols, rows, empty, LOOSE, -1 if all_fall else int(t.low))
	return r
