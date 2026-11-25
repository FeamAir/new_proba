extends RefCounted
## Таблица уровней Cascado. Здесь живёт кривая сложности; правила игры — в game.gd.
## Каждый уровень всегда одинаковый: раскладка строится из зерна `seed`.
##
## Поля строки:
##   rows  — рядов камня внизу (1..7)
##   h2    — доля рядов с двумя дырами (остальные с одной)
##   c     — кристаллов (не больше 8)
##   deep  — сколько кристаллов обязательно в самом нижнем ряду камня
##   speed — ступень скорости падения (1 = самая медленная), см. game.gd fall_interval()
##   par   — фигур на 3 звезды (2 звезды: до par×1.4)
##   rest  — «отдыхающий» уровень (легче соседей), только для справки
## Зёрна и par подобраны роботом tools/level_bot.gd: par = столько фигур, сколько робот
## укладывает примерно в 40% партий (в первых трёх и «отдыхающих» уровнях — щедрее, 55–70%).

const LEVELS := [
	# 1–5: обучение
	{"rows": 2, "h2": 0.0, "c": 2, "deep": 0, "speed": 1, "par": 3, "seed": 112661},
	{"rows": 3, "h2": 0.0, "c": 2, "deep": 0, "speed": 1, "par": 6, "seed": 748954},
	{"rows": 3, "h2": 0.35, "c": 3, "deep": 0, "speed": 2, "par": 7, "seed": 128499},
	{"rows": 4, "h2": 0.35, "c": 3, "deep": 0, "speed": 2, "par": 7, "seed": 31689},
	{"rows": 4, "h2": 0.4, "c": 4, "deep": 1, "speed": 3, "par": 10, "seed": 144337},
	# 6: отдых
	{"rows": 3, "h2": 0.2, "c": 3, "deep": 0, "speed": 2, "par": 5, "seed": 152256, "rest": true},
	# 7–11: рост
	{"rows": 5, "h2": 0.4, "c": 4, "deep": 0, "speed": 4, "par": 10, "seed": 683820},
	{"rows": 5, "h2": 0.45, "c": 5, "deep": 1, "speed": 5, "par": 15, "seed": 1110655},
	{"rows": 5, "h2": 0.5, "c": 5, "deep": 1, "speed": 5, "par": 19, "seed": 594929},
	{"rows": 6, "h2": 0.45, "c": 5, "deep": 1, "speed": 6, "par": 21, "seed": 917035},
	{"rows": 6, "h2": 0.5, "c": 6, "deep": 1, "speed": 7, "par": 22, "seed": 1239141},
	# 12: отдых
	{"rows": 4, "h2": 0.3, "c": 4, "deep": 0, "speed": 5, "par": 10, "seed": 618686, "rest": true},
	# 13–16
	{"rows": 6, "h2": 0.55, "c": 6, "deep": 1, "speed": 8, "par": 25, "seed": 207689},
	{"rows": 6, "h2": 0.6, "c": 6, "deep": 2, "speed": 8, "par": 27, "seed": 425066},
	{"rows": 7, "h2": 0.5, "c": 6, "deep": 1, "speed": 9, "par": 29, "seed": 1061359},
	{"rows": 7, "h2": 0.55, "c": 7, "deep": 1, "speed": 10, "par": 33, "seed": 650362},
	# 17: отдых
	{"rows": 5, "h2": 0.4, "c": 5, "deep": 0, "speed": 7, "par": 17, "seed": 448823, "rest": true},
	# 18–22
	{"rows": 7, "h2": 0.6, "c": 7, "deep": 1, "speed": 11, "par": 31, "seed": 770929},
	{"rows": 7, "h2": 0.6, "c": 7, "deep": 2, "speed": 11, "par": 36, "seed": 1093035},
	{"rows": 7, "h2": 0.65, "c": 7, "deep": 2, "speed": 12, "par": 32, "seed": 472580},
	{"rows": 7, "h2": 0.7, "c": 8, "deep": 2, "speed": 12, "par": 36, "seed": 1004144},
	{"rows": 7, "h2": 0.75, "c": 8, "deep": 2, "speed": 13, "par": 40, "seed": 802605},
	# 23: отдых
	{"rows": 5, "h2": 0.5, "c": 6, "deep": 1, "speed": 10, "par": 24, "seed": 286879, "rest": true},
	# 24–28
	{"rows": 7, "h2": 0.75, "c": 8, "deep": 2, "speed": 14, "par": 32, "seed": 1342088},
	{"rows": 7, "h2": 0.8, "c": 8, "deep": 2, "speed": 14, "par": 36, "seed": 1350007},
	{"rows": 7, "h2": 0.85, "c": 8, "deep": 3, "speed": 15, "par": 43, "seed": 520094},
	{"rows": 7, "h2": 0.9, "c": 8, "deep": 3, "speed": 15, "par": 38, "seed": 1156387},
	{"rows": 7, "h2": 0.9, "c": 8, "deep": 3, "speed": 16, "par": 43, "seed": 954848},
	# 29: отдых
	{"rows": 6, "h2": 0.5, "c": 6, "deep": 1, "speed": 12, "par": 28, "seed": 1172225, "rest": true},
	# 30: рубеж
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 3, "speed": 17, "par": 39, "seed": 761228},
]


## Параметры уровня n (с 1). После таблицы уровни повторяют последние 6
## (5 трудных + отдых), скорость растёт дальше, но медленно.
static func params(n: int) -> Dictionary:
	var p: Dictionary
	if n <= LEVELS.size():
		p = LEVELS[n - 1].duplicate()
	else:
		var extra := n - LEVELS.size()
		var cycle := 6
		p = LEVELS[LEVELS.size() - cycle + (extra - 1) % cycle].duplicate()
		p.speed = mini(p.speed + 1 + extra / cycle, 22)
	if not p.has("seed"):
		p.seed = n * 7919 + 13
	return p
