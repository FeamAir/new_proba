extends RefCounted
## Таблица уровней Cascado. Здесь живёт кривая сложности; правила игры — в game.gd.
## Каждый уровень всегда одинаковый: раскладка строится из зерна `seed`.
##
## Поля строки:
##   rows  — рядов камня внизу (1..7)
##   h2    — доля рядов с двумя дырами (остальные с одной)
##   c     — кристаллов (не больше 8)
##   deep  — сколько кристаллов обязательно в самом нижнем ряду камня
##   speed — ступень скорости падения (1 = самая медленная), см. game.gd fall_interval();
##           не выше 21 (0,26 с на клетку)
##   hang  — пар рядов «колодец + прикрытая дыра» с висячим блоком сверху (0..3),
##           заготовка каскада, см. add_hang() ниже
##   par   — фигур на 3 звезды (2 звезды: до par×1.4)
##   rest  — «отдыхающий» уровень (легче соседей), только для справки
## Зёрна и par подобраны роботом tools/level_bot.gd (100 партий на уровень): par = столько
## фигур, сколько робот укладывает примерно в 40% побед (в первых трёх и «отдыхающих»
## уровнях — щедрее, 60% и больше). Пересчитывать par после любой правки строки уровня.

const LEVELS := [
	# 1–5: обучение (висячий блок даёт каскад с первого уровня)
	{"rows": 2, "h2": 0.0, "c": 2, "deep": 0, "speed": 1, "hang": 1, "par": 2, "seed": 112661},
	{"rows": 3, "h2": 0.0, "c": 2, "deep": 0, "speed": 1, "hang": 1, "par": 3, "seed": 15851},
	{"rows": 3, "h2": 0.35, "c": 3, "deep": 0, "speed": 2, "hang": 1, "par": 4, "seed": 233228},
	{"rows": 4, "h2": 0.35, "c": 3, "deep": 0, "speed": 2, "hang": 1, "par": 4, "seed": 1393166},
	{"rows": 4, "h2": 0.4, "c": 4, "deep": 1, "speed": 3, "hang": 2, "par": 4, "seed": 144337},
	# 6: отдых
	{"rows": 3, "h2": 0.2, "c": 3, "deep": 0, "speed": 2, "hang": 1, "par": 3, "seed": 47527, "rest": true},
	# 7–11: рост
	{"rows": 5, "h2": 0.4, "c": 4, "deep": 0, "speed": 4, "hang": 2, "par": 6, "seed": 474362},
	{"rows": 5, "h2": 0.45, "c": 5, "deep": 1, "speed": 5, "hang": 2, "par": 8, "seed": 1739029},
	{"rows": 5, "h2": 0.5, "c": 5, "deep": 1, "speed": 5, "hang": 2, "par": 8, "seed": 1118574},
	{"rows": 6, "h2": 0.45, "c": 5, "deep": 1, "speed": 6, "hang": 2, "par": 13, "seed": 3849447},
	{"rows": 6, "h2": 0.5, "c": 6, "deep": 1, "speed": 7, "hang": 3, "par": 12, "seed": 1867515},
	# 12: отдых
	{"rows": 4, "h2": 0.3, "c": 4, "deep": 0, "speed": 5, "hang": 2, "par": 8, "seed": 304499, "rest": true},
	# 13–16
	{"rows": 6, "h2": 0.55, "c": 6, "deep": 1, "speed": 8, "hang": 2, "par": 17, "seed": 2930643},
	{"rows": 6, "h2": 0.6, "c": 6, "deep": 2, "speed": 8, "hang": 3, "par": 11, "seed": 948711},
	{"rows": 7, "h2": 0.5, "c": 6, "deep": 1, "speed": 9, "hang": 2, "par": 20, "seed": 956630},
	{"rows": 7, "h2": 0.55, "c": 7, "deep": 1, "speed": 10, "hang": 3, "par": 16, "seed": 755091},
	# 17: отдых
	{"rows": 5, "h2": 0.4, "c": 5, "deep": 0, "speed": 7, "hang": 2, "par": 6, "seed": 1077197, "rest": true},
	# 18–22
	{"rows": 7, "h2": 0.6, "c": 7, "deep": 1, "speed": 11, "hang": 3, "par": 13, "seed": 980387},
	{"rows": 7, "h2": 0.6, "c": 7, "deep": 2, "speed": 11, "hang": 2, "par": 15, "seed": 464661},
	{"rows": 7, "h2": 0.65, "c": 7, "deep": 2, "speed": 12, "hang": 3, "par": 18, "seed": 891496},
	{"rows": 7, "h2": 0.7, "c": 8, "deep": 2, "speed": 12, "hang": 2, "par": 21, "seed": 689957},
	{"rows": 7, "h2": 0.75, "c": 8, "deep": 2, "speed": 13, "hang": 3, "par": 18, "seed": 3630288},
	# 23: отдых
	{"rows": 5, "h2": 0.5, "c": 6, "deep": 1, "speed": 10, "hang": 2, "par": 12, "seed": 705795, "rest": true},
	# 24–28
	{"rows": 7, "h2": 0.75, "c": 8, "deep": 2, "speed": 14, "hang": 2, "par": 18, "seed": 2179920},
	{"rows": 7, "h2": 0.8, "c": 8, "deep": 2, "speed": 14, "hang": 3, "par": 22, "seed": 1559465},
	{"rows": 7, "h2": 0.85, "c": 8, "deep": 3, "speed": 15, "hang": 2, "par": 21, "seed": 3976151},
	{"rows": 7, "h2": 0.9, "c": 8, "deep": 3, "speed": 15, "hang": 3, "par": 22, "seed": 737471},
	{"rows": 7, "h2": 0.9, "c": 8, "deep": 3, "speed": 16, "hang": 2, "par": 21, "seed": 954848},
	# 29: отдых
	{"rows": 6, "h2": 0.5, "c": 6, "deep": 1, "speed": 12, "hang": 3, "par": 14, "seed": 1067496, "rest": true},
	# 30: рубеж
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 3, "speed": 17, "hang": 2, "par": 18, "seed": 1075415},
	# 31–35: всё поле в камне, глубже кристаллы
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 3, "speed": 17, "hang": 3, "par": 21, "seed": 1292792},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 3, "speed": 17, "hang": 2, "par": 25, "seed": 1614898},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 4, "speed": 18, "hang": 3, "par": 21, "seed": 4345771},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 4, "speed": 18, "hang": 2, "par": 25, "seed": 3411129},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 4, "speed": 18, "hang": 2, "par": 25, "seed": 591365},
	# 36: отдых
	{"rows": 6, "h2": 0.6, "c": 6, "deep": 1, "speed": 14, "hang": 3, "par": 16, "seed": 1856032, "rest": true},
	# 37–41
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 4, "speed": 18, "hang": 3, "par": 21, "seed": 921390},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 4, "speed": 19, "hang": 2, "par": 23, "seed": 4280637},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 19, "hang": 3, "par": 25, "seed": 1460873},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 19, "hang": 2, "par": 23, "seed": 1573521},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 19, "hang": 2, "par": 26, "seed": 638879},
	# 42: отдых
	{"rows": 6, "h2": 0.7, "c": 7, "deep": 2, "speed": 15, "hang": 3, "par": 13, "seed": 2322462, "rest": true},
	# 43–47
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 20, "hang": 3, "par": 28, "seed": 2120923},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 20, "hang": 2, "par": 28, "seed": 662636},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 20, "hang": 3, "par": 22, "seed": 2450948},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 20, "hang": 2, "par": 28, "seed": 992661},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 2, "par": 27, "seed": 581664},
	# 48: отдых
	{"rows": 6, "h2": 0.8, "c": 7, "deep": 2, "speed": 16, "hang": 3, "par": 12, "seed": 2055789, "rest": true},
	# 49–50: финал (скорость 21 — 0,26 с на клетку, быстрее не бывает)
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 2, "par": 27, "seed": 2273166},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 2, "par": 32, "seed": 919608},
]


## Предел скорости: ступень 21 = 0,26 с на клетку.
const MAX_SPEED := 21


## Параметры уровня n (с 1). После таблицы уровни по кругу повторяют раскладки
## уровней 45–50 (45–47 трудные, 48 отдых, 49–50 финал). Скорость при повторе
## чуть растёт, но не выше MAX_SPEED.
static func params(n: int) -> Dictionary:
	var p: Dictionary
	if n <= LEVELS.size():
		p = LEVELS[n - 1].duplicate()
	else:
		var extra := n - LEVELS.size()
		var cycle := 6
		p = LEVELS[LEVELS.size() - cycle + (extra - 1) % cycle].duplicate()
		p.speed = mini(p.speed + 1 + extra / cycle, MAX_SPEED)
	if not p.has("seed"):
		p.seed = n * 7919 + 13
	return p


## «Висячие» блоки (поле `hang` в строке уровня) — заготовка каскада.
## hang = k: верхние 2k рядов камня собираются парами «ряд с двумя дырами над рядом
## с одной дырой». Одна дыра у обоих рядов пары общая — колодец в колонке s, вторая
## дыра верхнего ряда пары прикрыта: в самой верхней паре — висячим блоком камня,
## в нижних парах — камнем ряда выше. У каждой пары свой колодец (shaft: 1 — один
## общий колодец сквозь все пары; так уровень заметно легче). Игрок кидает вертикальную фигуру в колодец,
## нижний ряд пары очищается, и камень/висячий блок осыпается в прикрытую дыру —
## верхний ряд дополняется сам: КАСКАД ×2.
## Кристаллы при перестановке дыр остаются в своём ряду (их число не меняется).
## Вызывается из game.gd start_level() после расстановки кристаллов, тем же
## генератором случайных чисел — уровни без `hang` не меняются.
static func add_hang(board: Array, p: Dictionary, lr: RandomNumberGenerator, cols: int, rows_total: int, stone: int) -> void:
	var k: int = p.get("hang", 0)
	var stone_rows: int = clampi(p.rows, 1, 7)
	k = mini(k, stone_rows / 2)
	if k <= 0:
		return
	var y0 := rows_total - stone_rows  # верхний ряд камня
	# колонка колодца: одна из дыр второго ряда (у него точно есть дыра)
	var s := -1
	for x in cols:
		if board[(y0 + 1) * cols + x] == -1:
			s = x
			break
	var prev_h := -1
	var top_h := -1
	var shared: bool = p.get("shaft", 0) == 1
	for i in k:
		if i > 0 and not shared:
			var prev_s := s
			while s == prev_s:
				s = lr.randi_range(0, cols - 1)
			prev_h = prev_s
		var hu := -1
		while hu < 0 or hu == s or hu == prev_h:
			hu = lr.randi_range(0, cols - 1)
		_set_holes(board, y0 + 2 * i, [s, hu], lr, cols, stone)
		_set_holes(board, y0 + 2 * i + 1, [s], lr, cols, stone)
		if i == 0:
			top_h = hu
		prev_h = hu
	board[(y0 - 1) * cols + top_h] = stone


## Переставляет дыры ряда y на holes; камень и кристаллы ряда сохраняются,
## лишние клетки (если дыр стало меньше) заполняются камнем.
static func _set_holes(board: Array, y: int, holes: Array, lr: RandomNumberGenerator, cols: int, stone: int) -> void:
	var gems: Array = []
	for x in cols:
		var v: int = board[y * cols + x]
		if v != -1 and v != stone:
			gems.append(v)
	var free: Array = []
	for x in cols:
		if holes.has(x):
			board[y * cols + x] = -1
		else:
			board[y * cols + x] = stone
			free.append(x)
	# кристаллы ряда заново раскладываются по его камню
	for i in range(free.size() - 1, 0, -1):
		var j := lr.randi_range(0, i)
		var t = free[i]
		free[i] = free[j]
		free[j] = t
	for i in gems.size():
		board[y * cols + free[i]] = gems[i]
