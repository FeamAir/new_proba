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
##   h3    — доля нижних рядов камня (ниже пар с висячим блоком), где добавляется ещё
##           одна дыра (0..1, по умолчанию 0), см. _add_holes() ниже. Главный рычаг
##           сложности при «липкой» гравитации: осыпавшийся камень сам заделывает дыры
##   par   — фигур на 3 звезды (2 звезды: до par×1.4)
##   rest  — «отдыхающий» уровень (легче соседей), только для справки
## Приёмы раскладки уровней 51–100 (версия 0.10, у уровней 1–50 этих полей нет):
##   h3 > 1 — в ряду может быть вторая лишняя дыра (см. _add_holes)
##   well  — глубина узкого колодца сверху вниз сквозь ряды камня (0..6), см. _add_well()
##   isl   — до стольких «островков» камня над полем (0..3; сколько поместится), см. _add_islands()
##   ic    — сколько кристаллов перенести на островки (кристаллы «в середине поля»)
## Настройка под «липкую» гравитацию (FALL_ALL = false). Раскладки (hang, h3, seed)
## подобраны роботом tools/level_bot.gd (перебор зёрен --seeds, проверка 60–100 партий),
## чтобы число фигур росло по уровням, а цепочка ×3 и длиннее случалась в 30–90% партий.
## par посчитан по 200 партиям робота: 3 звезды примерно в 42% партий на обычных
## уровнях, ~55% на уровнях 7–11 и ~68% на уровнях 1–5 и «отдыхающих».
## Уровни 51–100 подобраны так же, но робот играл с --tuck=1 (умеет подсовывать фигуру
## под островок, как человек): перебор 16–32 зёрен по 30 партий, лучшие 3–4 зерна по
## 100 партий, par по 200 партиям: 3 звезды примерно в 40% побед на обычных уровнях
## и ~65% на «отдыхающих» (55, 61, 66, 72, 77, 83, 88, 93, 98).
## Пересчитывать par после любой правки строки уровня.

const LEVELS := [
	# 1–5: обучение (висячий блок даёт каскад с первого уровня)
	{"rows": 2, "h2": 0.0, "c": 2, "deep": 0, "speed": 1, "hang": 1, "par": 2, "seed": 426848},
	{"rows": 4, "h2": 0.0, "c": 2, "deep": 0, "speed": 1, "hang": 1, "par": 7, "seed": 3262450},
	{"rows": 4, "h2": 0.35, "c": 3, "deep": 0, "speed": 2, "hang": 1, "par": 7, "seed": 2746724},
	{"rows": 4, "h2": 0.35, "c": 3, "deep": 0, "speed": 2, "hang": 1, "par": 7, "seed": 3801933},
	{"rows": 4, "h2": 0.4, "c": 4, "deep": 1, "speed": 3, "hang": 1, "h3": 1.0, "par": 11, "seed": 1296356},
	# 6: отдых
	{"rows": 4, "h2": 0.2, "c": 3, "deep": 0, "speed": 2, "hang": 1, "par": 6, "seed": 1618462, "rest": true},
	# 7–11: рост
	{"rows": 5, "h2": 0.4, "c": 4, "deep": 0, "speed": 4, "hang": 2, "par": 9, "seed": 998007},
	{"rows": 5, "h2": 0.45, "c": 5, "deep": 1, "speed": 5, "hang": 2, "par": 9, "seed": 901197},
	{"rows": 5, "h2": 0.5, "c": 5, "deep": 1, "speed": 5, "hang": 2, "par": 11, "seed": 1642219},
	{"rows": 6, "h2": 0.45, "c": 5, "deep": 1, "speed": 6, "hang": 1, "par": 13, "seed": 3744718},
	{"rows": 6, "h2": 0.5, "c": 6, "deep": 1, "speed": 7, "hang": 0, "h3": 0.5, "par": 13, "seed": 2705347},
	# 12: отдых
	{"rows": 4, "h2": 0.3, "c": 4, "deep": 0, "speed": 5, "hang": 1, "par": 11, "seed": 932873, "rest": true},
	# 13–16
	{"rows": 6, "h2": 0.55, "c": 6, "deep": 1, "speed": 8, "hang": 0, "par": 12, "seed": 417147},
	{"rows": 6, "h2": 0.6, "c": 6, "deep": 2, "speed": 8, "hang": 1, "h3": 1.0, "par": 13, "seed": 3881123},
	{"rows": 7, "h2": 0.5, "c": 6, "deep": 1, "speed": 9, "hang": 2, "h3": 1.0, "par": 13, "seed": 2737023},
	{"rows": 7, "h2": 0.55, "c": 7, "deep": 1, "speed": 10, "hang": 0, "h3": 0.5, "par": 16, "seed": 2954400},
	# 17: отдых
	{"rows": 5, "h2": 0.4, "c": 5, "deep": 0, "speed": 7, "hang": 1, "par": 15, "seed": 2543403, "rest": true},
	# 18–22
	{"rows": 7, "h2": 0.6, "c": 7, "deep": 1, "speed": 11, "hang": 2, "h3": 1.0, "par": 14, "seed": 3179696},
	{"rows": 7, "h2": 0.6, "c": 7, "deep": 2, "speed": 11, "hang": 1, "h3": 1.0, "par": 16, "seed": 4444363},
	{"rows": 7, "h2": 0.65, "c": 7, "deep": 2, "speed": 12, "hang": 2, "h3": 1.0, "par": 11, "seed": 1729328},
	{"rows": 7, "h2": 0.7, "c": 8, "deep": 2, "speed": 12, "hang": 0, "h3": 0.5, "par": 17, "seed": 1108873},
	{"rows": 7, "h2": 0.75, "c": 8, "deep": 2, "speed": 13, "hang": 1, "h3": 1.0, "par": 19, "seed": 488418},
	# 23: отдых
	{"rows": 5, "h2": 0.5, "c": 6, "deep": 1, "speed": 10, "hang": 1, "h3": 1.0, "par": 17, "seed": 182150, "rest": true},
	# 24–28
	{"rows": 7, "h2": 0.75, "c": 8, "deep": 2, "speed": 14, "hang": 1, "par": 17, "seed": 1237359},
	{"rows": 7, "h2": 0.8, "c": 8, "deep": 2, "speed": 14, "hang": 1, "par": 14, "seed": 2292568},
	{"rows": 7, "h2": 0.85, "c": 8, "deep": 3, "speed": 15, "hang": 1, "h3": 0.5, "par": 13, "seed": 1776842},
	{"rows": 7, "h2": 0.9, "c": 8, "deep": 3, "speed": 15, "hang": 1, "h3": 1.0, "par": 21, "seed": 423284},
	{"rows": 7, "h2": 0.9, "c": 8, "deep": 3, "speed": 16, "hang": 1, "par": 17, "seed": 8809523},
	# 29: отдых
	{"rows": 6, "h2": 0.5, "c": 6, "deep": 1, "speed": 12, "hang": 2, "h3": 1.0, "par": 14, "seed": 1172225, "rest": true},
	# 30: рубеж
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 3, "speed": 17, "hang": 0, "h3": 0.5, "par": 27, "seed": 237583},
	# 31–35: всё поле в камне, глубже кристаллы
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 3, "speed": 17, "hang": 0, "h3": 0.5, "par": 27, "seed": 1188063},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 3, "speed": 17, "hang": 1, "h3": 1.0, "par": 21, "seed": 1300711},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 4, "speed": 18, "hang": 1, "h3": 0.5, "par": 17, "seed": 889714},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 4, "speed": 18, "hang": 1, "h3": 1.0, "par": 22, "seed": 7600289},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 4, "speed": 18, "hang": 1, "h3": 1.0, "par": 18, "seed": 5094712},
	# 36: отдых
	{"rows": 6, "h2": 0.6, "c": 6, "deep": 1, "speed": 14, "hang": 1, "par": 18, "seed": 7720856, "rest": true},
	# 37–41
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 4, "speed": 18, "hang": 0, "h3": 1.0, "par": 23, "seed": 3958531},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 4, "speed": 19, "hang": 1, "h3": 1.0, "par": 23, "seed": 5432656},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 19, "hang": 0, "par": 26, "seed": 1460873},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 19, "hang": 1, "h3": 1.0, "par": 18, "seed": 316773},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 19, "hang": 1, "h3": 1.0, "par": 19, "seed": 3257104},
	# 42: отдых
	{"rows": 6, "h2": 0.7, "c": 7, "deep": 2, "speed": 15, "hang": 1, "h3": 0.5, "par": 21, "seed": 1798817, "rest": true},
	# 43–47
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 20, "hang": 1, "par": 18, "seed": 340530},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 20, "hang": 1, "h3": 1.0, "par": 30, "seed": 3071403},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 20, "hang": 1, "h3": 1.0, "par": 24, "seed": 1822574},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 20, "hang": 1, "h3": 0.5, "par": 25, "seed": 5496008},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 1.0, "par": 25, "seed": 4247179},
	# 48: отдых
	{"rows": 6, "h2": 0.8, "c": 7, "deep": 2, "speed": 16, "hang": 1, "h3": 1.0, "par": 23, "seed": 1113228, "rest": true},
	# 49–50: финал (скорость 21 — 0,26 с на клетку, быстрее не бывает)
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 1.0, "par": 21, "seed": 2377895},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 1, "h3": 1.0, "par": 23, "seed": 4270936},
	# 51–54: Сапфировый грот — «островки» камня над полем (поле isl), h3 больше 1
	{"rows": 6, "h2": 0.9, "c": 8, "deep": 3, "speed": 20, "hang": 1, "h3": 1.0, "isl": 2, "par": 13, "seed": 1555901},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 20, "hang": 1, "h3": 1.0, "isl": 1, "par": 21, "seed": 1982736},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 1.5, "par": 21, "seed": 1990655},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 21, "hang": 1, "h3": 1.0, "isl": 2, "par": 22, "seed": 532368},
	# 55: отдых (низкое поле, островки осыпаются каскадом)
	{"rows": 6, "h2": 0.7, "c": 7, "deep": 2, "speed": 17, "hang": 1, "h3": 1.0, "isl": 2, "par": 18, "seed": 1378119, "rest": true},
	# 56–60: островки, узкий колодец (поле well); 60 — рубеж
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 1.5, "isl": 1, "par": 25, "seed": 862393},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 1.0, "well": 5, "par": 19, "seed": 1812873},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 1.5, "isl": 2, "ic": 1, "par": 24, "seed": 1087689},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 1.5, "isl": 1, "par": 17, "seed": 1305066},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 0, "h3": 1.5, "par": 27, "seed": 1836630},
	# 61: отдых. Янтарные копи — кристаллы на островках (поле ic)
	{"rows": 6, "h2": 0.8, "c": 7, "deep": 2, "speed": 17, "hang": 1, "h3": 1.0, "isl": 2, "ic": 2, "par": 20, "seed": 1949278, "rest": true},
	# 62–65
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 21, "hang": 1, "h3": 1.0, "isl": 2, "ic": 1, "par": 22, "seed": 1852468},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 21, "hang": 1, "h3": 1.5, "isl": 2, "ic": 2, "par": 26, "seed": 1965116},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 1.5, "isl": 1, "ic": 1, "par": 25, "seed": 1868306},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 2.0, "isl": 2, "ic": 2, "par": 27, "seed": 724206},
	# 66: отдых
	{"rows": 6, "h2": 0.8, "c": 7, "deep": 2, "speed": 18, "hang": 2, "h3": 1.0, "isl": 3, "ic": 2, "par": 16, "seed": 1674686, "rest": true},
	# 67–70
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 2.0, "isl": 1, "ic": 1, "par": 23, "seed": 1473147},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 1.5, "well": 4, "isl": 2, "ic": 2, "par": 27, "seed": 2109440},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 1.5, "isl": 2, "ic": 2, "par": 28, "seed": 2117359},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 1, "h3": 2.0, "isl": 3, "ic": 3, "par": 25, "seed": 1392175},
	# 71: Лунное озеро — узкие колодцы
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 5, "speed": 21, "hang": 1, "h3": 1.0, "well": 4, "par": 21, "seed": 2133197},
	# 72: отдых
	{"rows": 6, "h2": 0.8, "c": 7, "deep": 2, "speed": 18, "hang": 1, "h3": 1.0, "well": 3, "isl": 2, "ic": 1, "par": 23, "seed": 1617471, "rest": true},
	# 73–76
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 1.5, "well": 5, "par": 30, "seed": 1939577},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 0, "h3": 1.0, "well": 6, "par": 27, "seed": 1842767},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 2.0, "well": 4, "par": 26, "seed": 1955415},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 2, "h3": 1.5, "well": 6, "par": 26, "seed": 601857},
	# 77: отдых
	{"rows": 6, "h2": 0.9, "c": 8, "deep": 3, "speed": 18, "hang": 1, "h3": 1.0, "isl": 3, "ic": 2, "par": 15, "seed": 1761795, "rest": true},
	# 78–80
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 0, "h3": 1.5, "well": 5, "par": 29, "seed": 722424},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 1, "h3": 2.0, "well": 5, "par": 26, "seed": 1044530},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 0, "h3": 2.0, "well": 6, "par": 30, "seed": 1471365},
	# 81–82: Гнездо светлячков — всё вместе
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 1.5, "well": 4, "isl": 1, "ic": 1, "par": 24, "seed": 1793471},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 2.0, "isl": 2, "ic": 2, "par": 28, "seed": 649371},
	# 83: отдых
	{"rows": 6, "h2": 0.9, "c": 8, "deep": 3, "speed": 18, "hang": 2, "h3": 1.0, "isl": 3, "ic": 3, "par": 23, "seed": 1914038, "rest": true},
	# 84–87
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 2.0, "isl": 1, "par": 30, "seed": 1398312},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 1, "h3": 1.5, "well": 5, "isl": 1, "ic": 1, "par": 28, "seed": 2139334},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 1.5, "well": 6, "isl": 2, "ic": 2, "par": 31, "seed": 995234},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 1, "h3": 2.0, "well": 6, "par": 31, "seed": 2155172},
	# 88: отдых
	{"rows": 6, "h2": 1.0, "c": 8, "deep": 3, "speed": 18, "hang": 1, "h3": 1.0, "well": 4, "isl": 2, "ic": 2, "par": 31, "seed": 2058362, "rest": true},
	# 89–90
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 1, "h3": 1.5, "well": 5, "isl": 1, "ic": 1, "par": 32, "seed": 1752094},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 1, "h3": 2.0, "well": 6, "isl": 1, "ic": 1, "par": 30, "seed": 1026910},
	# 91–92: Корона кристаллов
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 6, "speed": 21, "hang": 1, "h3": 2.0, "well": 5, "isl": 1, "ic": 1, "par": 32, "seed": 2815222},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 0, "h3": 2.0, "well": 5, "par": 28, "seed": 1147477},
	# 93: отдых
	{"rows": 6, "h2": 1.0, "c": 8, "deep": 4, "speed": 18, "hang": 2, "h3": 1.0, "isl": 3, "ic": 3, "par": 22, "seed": 3249976, "rest": true},
	# 94–97 (с 95-го — круг «Бесконечных глубин»)
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 1, "h3": 1.5, "well": 6, "isl": 2, "ic": 2, "par": 32, "seed": 2210605},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 1, "h3": 2.0, "well": 6, "isl": 1, "ic": 1, "par": 29, "seed": 2323253},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 1, "h3": 2.0, "well": 6, "isl": 2, "ic": 1, "par": 29, "seed": 2121714},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 1, "h3": 2.0, "well": 5, "isl": 1, "ic": 1, "par": 29, "seed": 2234362},
	# 98: отдых
	{"rows": 6, "h2": 1.0, "c": 8, "deep": 4, "speed": 18, "hang": 1, "h3": 1.5, "isl": 3, "ic": 2, "par": 28, "seed": 2451739, "rest": true},
	# 99–100: финал
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 1, "h3": 2.0, "well": 5, "isl": 1, "ic": 1, "par": 32, "seed": 993452},
	{"rows": 7, "h2": 1.0, "c": 8, "deep": 7, "speed": 21, "hang": 1, "h3": 2.0, "well": 5, "isl": 2, "ic": 2, "par": 32, "seed": 4038512},
]


## Предел скорости: ступень 21 = 0,26 с на клетку.
const MAX_SPEED := 21

## Самый высокий ряд (сверху, с 0), где может висеть островок камня (поле isl).
const ISLAND_TOP := 5


## Параметры уровня n (с 1). После таблицы («Бесконечные глубины») уровни по кругу
## повторяют раскладки последних шести — 95–100 (95–97 трудные, 98 отдых, 99–100 финал).
## Скорость при повторе чуть растёт, но не выше MAX_SPEED.
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
	var shaft_x := -1
	var top_h := -1
	if k > 0:
		var r := _hang_pairs(board, p, lr, cols, rows_total, stone, k, stone_rows)
		shaft_x = r[0]
		top_h = r[1]
	# Приёмы 0.10 (уровни 51+). Без полей well/isl генератор не трогается —
	# раскладки уровней 1–50 остаются прежними.
	_add_well(board, p, lr, cols, rows_total, stone, stone_rows, shaft_x, top_h)
	_add_islands(board, p, lr, cols, rows_total, stone, stone_rows)


## Пары «колодец + прикрытая дыра» с висячим блоком (см. add_hang).
## Возвращает [колонка колодца верхней пары, колонка висячего блока].
static func _hang_pairs(board: Array, p: Dictionary, lr: RandomNumberGenerator, cols: int, rows_total: int, stone: int, k: int, stone_rows: int) -> Array:
	var y0 := rows_total - stone_rows  # верхний ряд камня
	# колонка колодца: одна из дыр второго ряда (у него точно есть дыра)
	var s := -1
	for x in cols:
		if board[(y0 + 1) * cols + x] == -1:
			s = x
			break
	var prev_h := -1
	var top_h := -1
	var top_s := -1
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
			top_s = s
		prev_h = hu
	board[(y0 - 1) * cols + top_h] = stone
	return [top_s, top_h]


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


## Лишние дыры (поле `h3` строки уровня, доля 0..2): в каждом из нижних `free_rows`
## рядов камня (ниже пар с висячим блоком) с вероятностью h3 одна клетка простого
## камня (не кристалл) становится дырой. Больше дыр — больше работы: при «липкой»
## гравитации осыпавшийся камень сам заделывает дыры, и без этого поздние уровни
## проходятся слишком быстро. h3 > 1 — в ряду может быть и вторая лишняя дыра
## (вероятность h3 − 1). Без поля h3 генератор случайных чисел не трогается —
## раскладки остальных уровней не меняются.
static func _add_holes(board: Array, p: Dictionary, lr: RandomNumberGenerator, cols: int, rows_total: int, stone: int, free_rows: int) -> void:
	var h3: float = p.get("h3", 0.0)
	if h3 <= 0.0:
		return
	for r in free_rows:
		var y := rows_total - 1 - r
		if lr.randf() >= h3:
			continue
		_hole_in_row(board, lr, cols, stone, y)
		# h3 больше 1 (уровни 51+): вторая лишняя дыра в ряду с вероятностью h3 − 1
		if h3 > 1.0 and lr.randf() < h3 - 1.0:
			_hole_in_row(board, lr, cols, stone, y)


static func _hole_in_row(board: Array, lr: RandomNumberGenerator, cols: int, stone: int, y: int) -> void:
	var cand: Array = []
	for x in cols:
		if board[y * cols + x] == stone:
			cand.append(x)
	if cand.size() > 0:
		board[y * cols + cand[lr.randi_range(0, cand.size() - 1)]] = -1


## Узкий колодец (поле `well`, 0..7): в верхних `well` рядах камня одна и та же колонка —
## дыра. Колодец открыт сверху; при висячем блоке он продолжает колодец верхней пары
## вглубь. Заполнить его можно только стоячими фигурами (палочка 1×3, домино), а пока он
## пуст, ни один из этих рядов не очистится. Кристалл с клетки колодца переезжает
## на камень того же ряда (число кристаллов не меняется).
static func _add_well(board: Array, p: Dictionary, lr: RandomNumberGenerator, cols: int, rows_total: int, stone: int, stone_rows: int, shaft_x: int, top_h: int) -> void:
	var d: int = mini(p.get("well", 0), stone_rows)
	if d <= 0:
		return
	var w := shaft_x
	while w < 0 or w == top_h:
		w = lr.randi_range(0, cols - 1)
	var y0 := rows_total - stone_rows
	for y in range(y0, y0 + d):
		var v: int = board[y * cols + w]
		if v == -1:
			continue
		board[y * cols + w] = -1
		if v != stone:
			var free: Array = []
			for x in cols:
				if board[y * cols + x] == stone:
					free.append(x)
			if free.is_empty():
				board[y * cols + w] = v  # некуда переложить кристалл — клетка остаётся
			else:
				board[y * cols + free[lr.randi_range(0, free.size() - 1)]] = v


## «Островки» камня (поле `isl`, 0..3): до isl полок по 2–3 клетки висят в воздухе на 2–3 ряда
## выше верхнего ряда камня, но не выше ряда ISLAND_TOP (при 7 рядах камня — ровно на 2
## ряда выше, иначе поле слишком тесное). Фигура ложится на них сверху, а под полкой остаётся пустота;
## осыплются они, только когда очистится линия ниже. `ic` — сколько кристаллов
## перенести из камня на островки («кристаллы в середине поля»): их забирают либо
## линией на высоте островка, либо обрушив островок очисткой ряда под ним.
static func _add_islands(board: Array, p: Dictionary, lr: RandomNumberGenerator, cols: int, rows_total: int, stone: int, stone_rows: int) -> void:
	var n: int = clampi(p.get("isl", 0), 0, 3)
	if n <= 0:
		return
	var y0 := rows_total - stone_rows
	var cells: Array = []
	var tries := 0
	var made := 0
	while made < n and tries < 50:
		tries += 1
		var y := maxi(y0 - 2 - lr.randi_range(0, 1), ISLAND_TOP)
		var w := lr.randi_range(2, 3)
		var x0 := lr.randi_range(0, cols - w)
		var ok := true
		for x in range(x0 - 1, x0 + w + 1):  # островки не слипаются
			if x < 0 or x >= cols:
				continue
			for yy in range(y - 1, y + 2):
				if board[yy * cols + x] != -1:
					ok = false
		if not ok:
			continue
		for x in range(x0, x0 + w):
			board[y * cols + x] = stone
			cells.append(y * cols + x)
		made += 1
	var ic: int = mini(p.get("ic", 0), cells.size())
	if ic <= 0:
		return
	# кристаллы из камня (сверху вниз по случайному порядку) переезжают на островки
	var gems: Array = []
	for i in range(y0 * cols, rows_total * cols):
		if board[i] != -1 and board[i] != stone:
			gems.append(i)
	for i in ic:
		if gems.is_empty():
			break
		var gi := lr.randi_range(0, gems.size() - 1)
		var ci := lr.randi_range(0, cells.size() - 1)
		board[cells[ci]] = board[gems[gi]]
		board[gems[gi]] = stone
		gems.remove_at(gi)
		cells.remove_at(ci)
