extends RefCounted
## Таблица уровней Cascado. Здесь живёт кривая сложности; правила игры — в game.gd.
## Каждый уровень всегда одинаковый: раскладка строится из зерна `seed`.
##
## Поля строки:
##   rows  — рядов камня внизу (1..7). С версии 0.18 старт свободный: в залах 1–2 не больше
##           3 рядов (вместе с висячим блоком занято не выше 4 рядов из 14, ~29% высоты),
##           дальше 4–5 рядов, на всех уровнях занято не выше 6 рядов из 14 (~43%)
##   h2    — доля рядов с двумя дырами (остальные с одной)
##   c     — кристаллов (не больше 8)
##   deep  — сколько кристаллов обязательно в самом нижнем ряду камня
##   ramp  — секунд игры на одну ступень разгона (по умолчанию ramp_sec(n)). Скорость падения
##           с 0.18 не зависит от номера уровня: старт спокойный (base_speed — небольшая
##           база зала), затем каждые ramp секунд на ступень быстрее, до SPEED_CAP, см. speed_at().
##           Пауза, каскад и шаги обучения время не двигают. Поля speed в строках больше нет:
##           params() отдаёт speed = стартовая ступень (для game.gd fall_interval())
##   hang  — пар рядов «колодец + прикрытая дыра» с висячим блоком сверху (0..3),
##           заготовка каскада, см. add_hang() ниже
##   h3    — доля нижних рядов камня (ниже пар с висячим блоком), где добавляется ещё
##           одна дыра (0..1, по умолчанию 0), см. _add_holes() ниже. Главный рычаг
##           сложности при «липкой» гравитации: осыпавшийся камень сам заделывает дыры
##   par   — фигур на 3 звезды (2 звезды: до par×1.4)
##   rest  — «отдыхающий» уровень (легче соседей), только для справки
## Новинки 0.18 (правила и раскладка — scripts/specials.gd, своим генератором случайных чисел
## после всей прежней раскладки: камень, дыры и кристаллы остаются прежними; кроме уровней-тайников,
## где сундук встаёт в два нижних ряда и кристалл/дыра с его места переезжают — число кристаллов
## и дыр в каждом ряду то же):
##   goal  — цель уровня: нет поля — освободить все кристаллы; "pet" — «Спаси кротёнка»
##           (довести до нижнего ряда; кристаллы — только очки), "chest" — «Открой янтарный
##           тайник» (сундук 2×2 в двух нижних рядах камня; кристаллы — только очки).
##           С зала 2: кротёнок 2–3 уровня на зал, тайник 1–2. Уровни выбраны роботом так,
##           чтобы новая цель была не легче прежней (фигур на победу столько же или больше)
##   chest — 1: бонусный тайник на обычном уровне (в случайной паре рядов камня), 3–5 осколков
##   bomb  — кристаллов-бомб в камне (1–2), с зала 3 на ~40% уровней: очищен ряд с бомбой —
##           взрыв 3×3 (ещё одно звено каскада), бомбы рядом взрываются цепочкой
##   par уровней с новинками пересчитан роботом tools/level_bot.gd (он знает новые правила):
##   200 партий «хорошей игры» (--tuck=1), par — столько фигур, сколько хватило в 40% побед робота.
## Приёмы раскладки уровней 51–100 (версия 0.10; у уровней 1–50 нет well, isl, ic, а h3 до 1,5):
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
## Версия 0.18 (свободный старт): ряды камня сокращены до 2–5, островки не выше ряда
## ISLAND_TOP; сложность — разгон по времени, лишние дыры h3, двойные дыры h2, глубокие
## кристаллы, колодцы и островки; колодец не доходит до нижнего ряда (well < rows).
## Зёрна заново подобраны роботом в режиме «человек» (--tuck=1 --err=0.05 --pace=3:
## 16–40 зёрен по 20 партий, лучшие 4 по 60) под плавную кривую числа фигур
## (≈3,5 + 18,5·((n−1)/99)^0,8; отдых ×0,6; рубежи 30/60/90 ×1,15). par — по 200 партиям
## «хорошей игры» (--tuck=1 без ошибок): 3 звезды примерно в 40–50% побед на обычных
## уровнях и ~65–70% на уровнях 1–5 и «отдыхающих».
## Пересчитывать par после любой правки строки уровня.

const LEVELS := [
	# 1–5: обучение (висячий блок даёт каскад с первого уровня)
	{"rows": 2, "h2": 0.0, "c": 2, "deep": 0, "hang": 1, "par": 2, "seed": 426848},
	{"rows": 3, "h2": 0.0, "c": 2, "deep": 0, "hang": 1, "par": 4, "seed": 434767},
	{"rows": 3, "h2": 0.35, "c": 3, "deep": 0, "hang": 1, "par": 4, "seed": 1071060},
	{"rows": 3, "h2": 0.35, "c": 3, "deep": 0, "hang": 1, "par": 4, "seed": 974250},
	{"rows": 3, "h2": 0.4, "c": 4, "deep": 1, "hang": 1, "h3": 1.0, "par": 5, "seed": 877440},
	# 6: отдых
	{"rows": 2, "h2": 0.2, "c": 3, "deep": 0, "hang": 1, "par": 3, "seed": 47527, "rest": true},
	# 7–11: рост
	{"rows": 3, "h2": 0.4, "c": 4, "deep": 0, "hang": 1, "par": 2, "seed": 683820},
	{"rows": 3, "h2": 0.45, "c": 5, "deep": 1, "hang": 1, "par": 3, "seed": 3414693},
	{"rows": 3, "h2": 0.5, "c": 5, "deep": 1, "hang": 1, "par": 5, "seed": 280742},
	{"rows": 3, "h2": 0.45, "c": 5, "deep": 1, "hang": 1, "par": 4, "seed": 917035},
	{"rows": 3, "h2": 0.5, "c": 6, "deep": 1, "hang": 0, "h3": 0.5, "par": 4, "seed": 3752637},
	# 12: отдых
	{"rows": 2, "h2": 0.3, "c": 4, "deep": 0, "hang": 1, "par": 2, "seed": 1037602, "rest": true},
	# 13–16
	{"rows": 3, "h2": 0.55, "c": 6, "deep": 1, "hang": 0, "goal": "pet", "par": 4, "seed": 1569166, "h3": 0.5},
	{"rows": 3, "h2": 0.6, "c": 6, "deep": 2, "hang": 1, "h3": 1.0, "par": 3, "seed": 215608},
	{"rows": 3, "h2": 0.5, "c": 6, "deep": 1, "hang": 1, "h3": 1.0, "par": 4, "seed": 642443},
	{"rows": 3, "h2": 0.55, "c": 7, "deep": 1, "hang": 0, "h3": 0.5, "goal": "chest", "par": 3, "seed": 964549},
	# 17: отдых
	{"rows": 2, "h2": 0.4, "c": 5, "deep": 0, "hang": 1, "par": 4, "seed": 2857590, "rest": true},
	# 18–22
	{"rows": 3, "h2": 0.6, "c": 7, "deep": 1, "hang": 1, "h3": 1.0, "chest": 1, "par": 4, "seed": 980387},
	{"rows": 3, "h2": 0.6, "c": 7, "deep": 2, "hang": 1, "h3": 1.0, "goal": "pet", "par": 5, "seed": 1407222},
	{"rows": 3, "h2": 0.65, "c": 7, "deep": 2, "hang": 1, "h3": 1.0, "par": 4, "seed": 786767},
	{"rows": 3, "h2": 0.7, "c": 8, "deep": 2, "hang": 0, "h3": 1.0, "goal": "chest", "par": 5, "seed": 2679808},
	{"rows": 3, "h2": 0.75, "c": 8, "deep": 2, "hang": 1, "h3": 1.0, "bomb": 1, "goal": "pet", "par": 3, "seed": 1535708},
	# 23: отдых
	{"rows": 3, "h2": 0.5, "c": 6, "deep": 1, "hang": 1, "h3": 0.5, "par": 5, "seed": 601066, "rest": true},
	# 24–28
	{"rows": 3, "h2": 0.75, "c": 8, "deep": 2, "hang": 1, "par": 5, "seed": 1342088, "h3": 1.0},
	{"rows": 3, "h2": 0.8, "c": 8, "deep": 2, "hang": 1, "bomb": 1, "goal": "pet", "par": 5, "seed": 302717, "h3": 1.0},
	{"rows": 4, "h2": 0.85, "c": 8, "deep": 3, "hang": 1, "h3": 1.0, "par": 3, "seed": 415365},
	{"rows": 4, "h2": 0.9, "c": 8, "deep": 3, "hang": 1, "h3": 1.0, "bomb": 1, "goal": "pet", "par": 6, "seed": 946929},
	{"rows": 4, "h2": 0.9, "c": 8, "deep": 3, "hang": 1, "par": 3, "seed": 326474, "h3": 1.0},
	# 29: отдых
	{"rows": 3, "h2": 0.5, "c": 6, "deep": 1, "hang": 1, "h3": 0.5, "par": 5, "seed": 229664, "rest": true},
	# 30: рубеж
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 3, "hang": 0, "h3": 1.0, "bomb": 1, "par": 7, "seed": 2541621},
	# 31–35: двойные дыры во всех рядах, глубже кристаллы
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 3, "hang": 1, "h3": 1.5, "chest": 1, "par": 3, "seed": 2025895},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 3, "hang": 1, "h3": 1.5, "par": 4, "seed": 462879},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 4, "hang": 1, "h3": 1.5, "bomb": 1, "goal": "pet", "par": 6, "seed": 261340},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 4, "hang": 1, "h3": 1.5, "par": 5, "seed": 1316549},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 4, "hang": 1, "h3": 1.5, "bomb": 2, "par": 9, "seed": 2371758},
	# 36: отдых
	{"rows": 3, "h2": 0.6, "c": 6, "deep": 1, "hang": 1, "par": 7, "seed": 1751303, "rest": true},
	# 37–41
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 4, "hang": 1, "h3": 1.5, "goal": "chest", "par": 7, "seed": 293016},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 4, "hang": 1, "h3": 1.5, "bomb": 1, "goal": "pet", "par": 4, "seed": 1871870},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 5, "hang": 1, "par": 7, "seed": 2193976, "h3": 1.5},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 5, "hang": 1, "h3": 1.5, "par": 9, "seed": 1154605},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 5, "hang": 1, "h3": 1.5, "bomb": 1, "par": 7, "seed": 2105085},
	# 42: отдых
	{"rows": 3, "h2": 0.7, "c": 7, "deep": 2, "hang": 1, "h3": 0.5, "par": 8, "seed": 437340, "rest": true},
	# 43–47
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 5, "hang": 1, "bomb": 2, "par": 9, "seed": 1911465, "h3": 1.5},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 5, "hang": 1, "h3": 1.5, "bomb": 1, "goal": "pet", "par": 11, "seed": 976823},
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 1.5, "par": 6, "seed": 1508387},
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 1.5, "bomb": 1, "goal": "pet", "par": 9, "seed": 678474},
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 1.5, "chest": 1, "par": 4, "seed": 581664},
	# 48: отдых
	{"rows": 3, "h2": 0.8, "c": 7, "deep": 2, "hang": 1, "h3": 0.5, "par": 9, "seed": 1741602, "rest": true},
	# 49–50: финал зала
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 1.5, "bomb": 1, "goal": "chest", "par": 9, "seed": 1330605},
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 7, "hang": 1, "h3": 1.5, "goal": "pet", "par": 11, "seed": 710150},
	# 51–54: Сапфировый грот — «островки» камня над полем (поле isl), h3 больше 1
	{"rows": 4, "h2": 0.9, "c": 8, "deep": 3, "hang": 1, "h3": 2.0, "isl": 2, "chest": 1, "par": 3, "seed": 3231565},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 5, "hang": 1, "h3": 2.0, "isl": 1, "bomb": 1, "goal": "chest", "par": 5, "seed": 2820568},
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "goal": "pet", "par": 19, "seed": 1676468},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 5, "hang": 1, "h3": 2.0, "isl": 2, "bomb": 2, "par": 12, "seed": 4197883},
	# 55: отдых (низкое поле, островки осыпаются каскадом)
	{"rows": 3, "h2": 0.7, "c": 7, "deep": 2, "hang": 1, "h3": 1.0, "isl": 2, "par": 9, "seed": 749745, "rest": true},
	# 56–60: островки, узкий колодец (поле well); 60 — рубеж
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "isl": 1, "goal": "chest", "par": 16, "seed": 1386038},
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "well": 4, "bomb": 2, "par": 6, "seed": 451396},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "isl": 2, "ic": 1, "goal": "pet", "par": 8, "seed": 1297147},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "isl": 1, "par": 13, "seed": 1095608},
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 7, "hang": 0, "h3": 2.0, "bomb": 1, "par": 13, "seed": 998798},
	# 61: отдых. Янтарные копи — кристаллы на островках (поле ic)
	{"rows": 3, "h2": 0.8, "c": 7, "deep": 2, "hang": 1, "h3": 1.0, "isl": 2, "ic": 2, "par": 9, "seed": 1844549, "rest": true},
	# 62–65
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 5, "hang": 1, "h3": 2.0, "isl": 2, "ic": 1, "bomb": 2, "par": 4, "seed": 1747739},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 5, "hang": 1, "h3": 2.0, "isl": 2, "ic": 2, "par": 7, "seed": 1860387},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "isl": 1, "ic": 1, "goal": "pet", "par": 11, "seed": 1239932},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "isl": 2, "ic": 2, "chest": 1, "bomb": 2, "par": 15, "seed": 724206},
	# 66: отдых
	{"rows": 3, "h2": 0.8, "c": 7, "deep": 2, "hang": 1, "h3": 1.0, "isl": 3, "ic": 2, "par": 9, "seed": 1360499, "rest": true},
	# 67–70
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "isl": 1, "ic": 1, "par": 9, "seed": 2625166},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "well": 3, "isl": 2, "ic": 2, "bomb": 1, "goal": "chest", "par": 8, "seed": 852692},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "isl": 2, "ic": 2, "goal": "pet", "par": 13, "seed": 2117359},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 7, "hang": 1, "h3": 2.0, "isl": 3, "ic": 3, "bomb": 2, "goal": "chest", "par": 9, "seed": 1706362},
	# 71: Лунное озеро — узкие колодцы
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 5, "hang": 1, "h3": 2.0, "well": 4, "chest": 1, "bomb": 1, "par": 19, "seed": 562262},
	# 72: отдых
	{"rows": 3, "h2": 0.8, "c": 7, "deep": 2, "hang": 1, "h3": 1.0, "well": 2, "isl": 2, "ic": 1, "par": 6, "seed": 1722200, "rest": true},
	# 73–76
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "well": 4, "bomb": 2, "goal": "pet", "par": 10, "seed": 997016},
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 6, "hang": 0, "h3": 2.0, "well": 4, "goal": "chest", "par": 15, "seed": 1738038},
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "well": 4, "goal": "pet", "par": 13, "seed": 1536499},
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 6, "hang": 2, "h3": 2.0, "well": 4, "bomb": 2, "par": 10, "seed": 1230231},
	# 77: отдых
	{"rows": 3, "h2": 0.9, "c": 8, "deep": 3, "hang": 1, "h3": 1.0, "isl": 3, "ic": 2, "par": 9, "seed": 1552337, "rest": true},
	# 78–80
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 6, "hang": 0, "h3": 2.0, "well": 4, "goal": "pet", "par": 17, "seed": 1455527},
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 7, "hang": 1, "h3": 2.0, "well": 4, "bomb": 1, "par": 11, "seed": 939801},
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 7, "hang": 0, "h3": 2.0, "well": 4, "goal": "chest", "par": 12, "seed": 1576094},
	# 81–82: Гнездо светлячков — всё вместе
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "well": 3, "isl": 1, "ic": 1, "chest": 1, "bomb": 2, "par": 12, "seed": 1165097},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "isl": 2, "ic": 2, "par": 10, "seed": 649371},
	# 83: отдых
	{"rows": 3, "h2": 0.9, "c": 8, "deep": 3, "hang": 1, "h3": 1.0, "isl": 3, "ic": 3, "par": 10, "seed": 762019, "rest": true},
	# 84–87
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "isl": 1, "bomb": 2, "goal": "pet", "par": 11, "seed": 1712499},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 7, "hang": 1, "h3": 2.0, "well": 3, "isl": 1, "ic": 1, "goal": "chest", "par": 11, "seed": 1720418},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "well": 3, "isl": 2, "ic": 2, "par": 14, "seed": 1099963},
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 7, "hang": 1, "h3": 2.0, "well": 4, "bomb": 1, "par": 10, "seed": 1003153},
	# 88: отдых
	{"rows": 3, "h2": 1.0, "c": 8, "deep": 3, "hang": 1, "h3": 1.0, "well": 2, "isl": 2, "ic": 2, "par": 14, "seed": 1848904, "rest": true},
	# 89–90
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 7, "hang": 1, "h3": 2.0, "well": 3, "isl": 1, "ic": 1, "bomb": 2, "goal": "pet", "par": 10, "seed": 1647365},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 7, "hang": 1, "h3": 2.0, "well": 3, "isl": 1, "ic": 1, "bomb": 1, "par": 15, "seed": 817452},
	# 91–92: Корона кристаллов
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 6, "hang": 1, "h3": 2.0, "well": 3, "isl": 1, "ic": 1, "chest": 1, "par": 13, "seed": 1767932},
	{"rows": 5, "h2": 1.0, "c": 8, "deep": 7, "hang": 0, "h3": 2.0, "well": 4, "bomb": 2, "par": 9, "seed": 833290},
	# 93: отдых
	{"rows": 3, "h2": 1.0, "c": 8, "deep": 4, "hang": 1, "h3": 1.0, "isl": 3, "ic": 3, "par": 10, "seed": 1155396, "rest": true},
	# 94–97 (с 95-го — круг «Бесконечных глубин»)
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 7, "hang": 1, "h3": 2.0, "well": 3, "isl": 2, "ic": 2, "goal": "pet", "par": 19, "seed": 1163315},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 7, "hang": 1, "h3": 2.0, "well": 3, "isl": 1, "ic": 1, "bomb": 1, "goal": "chest", "par": 12, "seed": 2323253},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 7, "hang": 1, "h3": 2.0, "well": 3, "isl": 2, "ic": 1, "goal": "chest", "par": 13, "seed": 1283882},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 7, "hang": 1, "h3": 2.0, "well": 3, "isl": 1, "ic": 1, "bomb": 2, "goal": "pet", "par": 19, "seed": 1396530},
	# 98: отдых
	{"rows": 3, "h2": 1.0, "c": 8, "deep": 4, "hang": 1, "h3": 1.0, "isl": 3, "ic": 2, "bomb": 1, "par": 7, "seed": 1404449, "rest": true},
	# 99–100: финал
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 7, "hang": 1, "h3": 2.0, "well": 3, "isl": 1, "ic": 1, "chest": 1, "par": 13, "seed": 2040742},
	{"rows": 4, "h2": 1.0, "c": 8, "deep": 7, "hang": 1, "h3": 2.0, "well": 3, "isl": 2, "ic": 2, "bomb": 2, "par": 8, "seed": 1420287},
]


## Предел скорости: ступень 21 = 0,26 с на клетку (старый предел; разгон его не достигает).
const MAX_SPEED := 21

## 0.18: разгон внутри уровня. Ступень → интервал (game.gd fall_interval): 1 — 0,90 с на клетку,
## 3 — 0,80, 6 — 0,66, 11 — 0,49, 18 — 0,32 с.
const RAMP_START := 15.0  # секунд на ступень на уровнях 1–20; каждые 20 уровней на 1 с меньше
const RAMP_MIN := 10.0    # ...но не меньше (уровни 101+ и дальше)
const RAMP_REST := 4.0    # «отдыхающим» уровням — на столько секунд дольше
const SPEED_CAP := 18    # потолок разгона: 0,32 с на клетку
const BASE_MAX := 5      # база зала растёт на 1 каждые 20 уровней, но не выше 5 (0,70 с)

## Самый высокий ряд (сверху, с 0), где может висеть островок камня (поле isl).
## 0.18: 8 — островок не выше 6-го ряда снизу (занято не больше ~43% высоты поля);
## поэтому на уровнях с островками камня не больше 4 рядов.
const ISLAND_TOP := 8


## Параметры уровня n (с 1). После таблицы («Бесконечные глубины») уровни по кругу
## повторяют раскладки последних шести — 95–100 (95–97 трудные, 98 отдых, 99–100 финал).
## Скорость (0.18): base — стартовая ступень (base_speed), ramp — секунд на ступень разгона;
## speed = base (старт уровня). Уровень 1000 по скорости такой же, как 100-й.
static func params(n: int) -> Dictionary:
	var p: Dictionary
	if n <= LEVELS.size():
		p = LEVELS[n - 1].duplicate()
	else:
		var extra := n - LEVELS.size()
		var cycle := 6
		p = LEVELS[LEVELS.size() - cycle + (extra - 1) % cycle].duplicate()
	if not p.has("seed"):
		p.seed = n * 7919 + 13
	p.base = base_speed(n)
	p.ramp = float(p.get("ramp", ramp_sec(n) + (RAMP_REST if p.get("rest", false) else 0.0)))
	p.speed = p.base
	return p


## Стартовая ступень скорости уровня n: 1 на уровнях 1–20, +1 каждые 20 уровней, не выше BASE_MAX.
static func base_speed(n: int) -> int:
	return 1 + clampi((n - 1) / 20, 0, BASE_MAX - 1)


## Секунд на ступень разгона на уровне n: 15 на уровнях 1–20, затем на 1 с меньше
## каждые 20 уровней, не меньше RAMP_MIN.
static func ramp_sec(n: int) -> float:
	return maxf(RAMP_MIN, RAMP_START - float((n - 1) / 20))


## Ступень скорости через t секунд игры в уровне: база + ступень за каждые ramp секунд,
## не выше SPEED_CAP (и не ниже базы).
static func speed_at(base: int, ramp: float, t: float) -> int:
	return clampi(base + int(maxf(t, 0.0) / maxf(ramp, 1.0)), base, maxi(base, SPEED_CAP))


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
## выше верхнего ряда камня, но не выше ряда ISLAND_TOP (0.18: при 4 рядах камня — ровно на 2
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
