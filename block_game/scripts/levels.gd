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
	{"rows": 2, "h2": 0.0, "c": 2, "deep": 0, "speed": 1, "hang": 1, "par": 2, "seed": 426848},
	{"rows": 4, "h2": 0.0, "c": 2, "deep": 0, "speed": 1, "hang": 1, "par": 3, "seed": 3262450},
	{"rows": 4, "h2": 0.35, "c": 3, "deep": 0, "speed": 2, "hang": 1, "par": 4, "seed": 2746724},
	{"rows": 4, "h2": 0.35, "c": 3, "deep": 0, "speed": 2, "hang": 1, "par": 4, "seed": 3801933},
	{"rows": 4, "h2": 0.4, "c": 4, "deep": 1, "speed": 3, "hang": 1, "h3": 1.0, "par": 4, "seed": 1296356},
	# 6: отдых
	{"rows": 4, "h2": 0.2, "c": 3, "deep": 0, "speed": 2, "hang": 1, "par": 3, "seed": 1618462, "rest": true},
	# 7–11: рост
	{"rows": 5, "h2": 0.4, "c": 4, "deep": 0, "speed": 4, "hang": 2, "par": 6, "seed": 998007},
	{"rows": 5, "h2": 0.45, "c": 5, "deep": 1, "speed": 5, "hang": 2, "par": 8, "seed": 901197},
	{"rows": 5, "h2": 0.5, "c": 5, "deep": 1, "speed": 5, "hang": 2, "par": 8, "seed": 1642219},
	{"rows": 6, "h2": 0.45, "c": 5, "deep": 1, "speed": 6, "hang": 1, "par": 13, "seed": 3744718},
	{"rows": 6, "h2": 0.5, "c": 6, "deep": 1, "speed": 7, "hang": 0, "h3": 0.5, "par": 12, "seed": 2705347},
	# 12: отдых
	{"rows": 4, "h2": 0.3, "c": 4, "deep": 0, "speed": 5, "hang": 1, "par": 8, "seed": 932873, "rest": true},
	# 13–16
	{"rows": 6, "h2": 0.55, "c": 6, "deep": 1, "speed": 8, "hang": 0, "par": 17, "seed": 417147},
	{"rows": 6, "h2": 0.6, "c": 6, "deep": 2, "speed": 8, "hang": 1, "h3": 1.0, "par": 11, "seed": 3881123},
	{"rows": 7, "h2": 0.5, "c": 6, "deep": 1, "speed": 9, "hang": 2, "h3": 1.0, "par": 20, "seed": 2737023},
	{"rows": 7, "h2": 0.55, "c": 7, "deep": 1, "speed": 10, "hang": 0, "h3": 0.5, "par": 16, "seed": 2954400},
	# 17: отдых
	{"rows": 5, "h2": 0.4, "c": 5, "deep": 0, "speed": 7, "hang": 1, "par": 6, "seed": 2543403, "rest": true},
	# 18–22
	{"rows": 7, "h2": 0.6, "c": 7, "deep": 1, "speed": 11, "hang": 2, "h3": 1.0, "par": 13, "seed": 3179696},
	{"rows": 7, "h2": 0.6, "c": 7, "deep": 2, "speed": 11, "hang": 1, "h3": 1.0, "par": 15, "seed": 4444363},
	{"rows": 7, "h2": 0.65, "c": 7, "deep": 2, "speed": 12, "hang": 2, "h3": 1.0, "par": 18, "seed": 1729328},
	{"rows": 7, "h2": 0.7, "c": 8, "deep": 2, "speed": 12, "hang": 0, "h3": 0.5, "par": 21, "seed": 1108873},
	{"rows": 7, "h2": 0.75, "c": 8, "deep": 2, "speed": 13, "hang": 1, "h3": 1.0, "par": 18, "seed": 488418},
	# 23: отдых
	{"rows": 5, "h2": 0.5, "c": 6, "deep": 1, "speed": 10, "hang": 1, "h3": 1.0, "par": 12, "seed": 182150, "rest": true},
	# 24–28
	{"rows": 7, "h2": 0.75, "c": 8, "deep": 2, "speed": 14, "hang": 1, "par": 18, "seed": 1237359},
	{"rows": 7, "h2": 0.8, "c": 8, "deep": 2, "speed": 14, "hang": 1, "par": 22, "seed": 2292568},
	{"rows": 7, "h2": 0.85, "c": 8, "deep": 3, "speed": 15, "hang": 1, "h3": 0.5, "par": 21, "seed": 1776842},
	{"rows": 7, "h2": 0.9, "c": 8, "deep": 3, "speed": 15, "hang": 1, "h3": 1.0, "par": 22, "seed": 423284},
	{"rows": 7, "h2": 0.9, "c": 8, "deep": 3, "speed": 16, "hang": 1, "par": 21, "seed": 2944699},
	# 29: отдых
	{"rows": 6, "h2": 0.5, "c": 6, "deep": 1, "speed": 12, "hang": 2, "h3": 1.0, "par": 14, "seed": 1172225, "rest": true},
	# 30: рубеж
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 3, "speed": 17, "hang": 0, "h3": 0.5, "par": 18, "seed": 237583},
	# 31–35: всё поле в камне, глубже кристаллы
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 3, "speed": 17, "hang": 0, "h3": 0.5, "par": 21, "seed": 1188063},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 3, "speed": 17, "hang": 1, "h3": 1.0, "par": 25, "seed": 1300711},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 4, "speed": 18, "hang": 1, "h3": 0.5, "par": 21, "seed": 889714},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 4, "speed": 18, "hang": 0, "par": 25, "seed": 1002362},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 4, "speed": 18, "hang": 1, "h3": 1.0, "par": 25, "seed": 5094712},
	# 36: отдых
	{"rows": 6, "h2": 0.6, "c": 6, "deep": 1, "speed": 14, "hang": 0, "par": 16, "seed": 494555, "rest": true},
	# 37–41
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 4, "speed": 18, "hang": 0, "h3": 1.0, "par": 21, "seed": 3958531},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 4, "speed": 19, "hang": 1, "h3": 1.0, "par": 23, "seed": 1348225},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 19, "hang": 0, "par": 25, "seed": 1460873},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 19, "hang": 1, "h3": 1.0, "par": 23, "seed": 316773},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 19, "hang": 1, "h3": 1.0, "par": 26, "seed": 3257104},
	# 42: отдых
	{"rows": 6, "h2": 0.7, "c": 7, "deep": 2, "speed": 15, "hang": 1, "h3": 0.5, "par": 13, "seed": 1798817, "rest": true},
	# 43–47
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 20, "hang": 1, "par": 28, "seed": 340530},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 20, "hang": 1, "h3": 1.0, "par": 28, "seed": 3071403},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 20, "hang": 1, "h3": 1.0, "par": 22, "seed": 1822574},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 20, "hang": 1, "h3": 1.0, "par": 28, "seed": 1621035},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 1.0, "par": 27, "seed": 4247179},
	# 48: отдых
	{"rows": 6, "h2": 0.8, "c": 7, "deep": 2, "speed": 16, "hang": 1, "h3": 1.0, "par": 12, "seed": 1113228, "rest": true},
	# 49–50: финал (скорость 21 — 0,26 с на клетку, быстрее не бывает)
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 1.0, "par": 27, "seed": 2377895},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 1, "h3": 1.0, "par": 32, "seed": 4270936},
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
	_add_holes(board, p, lr, cols, rows_total, stone, stone_rows - 2 * maxi(k, 0))
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


## Лишние дыры (поле `h3` строки уровня, доля 0..1): в каждом из нижних `free_rows`
## рядов камня (ниже пар с висячим блоком) с вероятностью h3 одна клетка простого
## камня (не кристалл) становится дырой. Больше дыр — больше работы: при «липкой»
## гравитации осыпавшийся камень сам заделывает дыры, и без этого поздние уровни
## проходятся слишком быстро. Без поля h3 генератор случайных чисел не трогается —
## раскладки остальных уровней не меняются.
static func _add_holes(board: Array, p: Dictionary, lr: RandomNumberGenerator, cols: int, rows_total: int, stone: int, free_rows: int) -> void:
	var h3: float = p.get("h3", 0.0)
	if h3 <= 0.0:
		return
	for r in free_rows:
		var y := rows_total - 1 - r
		if lr.randf() >= h3:
			continue
		var cand: Array = []
		for x in cols:
			if board[y * cols + x] == stone:
				cand.append(x)
		if cand.size() > 0:
			board[y * cols + cand[lr.randi_range(0, cand.size() - 1)]] = -1
