extends SceneTree
## Тесты версии 0.10: 100 уровней в 10 залах, новые приёмы раскладки (узкий колодец,
## островки камня, кристаллы на островках), «Бесконечные глубины» после 100-го,
## ступени богатства дома, карта.
## Запуск: godot --headless --path block_game -s tests/test_v010.gd

var failed := 0
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const Levels := preload("res://scripts/levels.gd")
const SAVE := "user://save.cfg"
## Отпечаток раскладок уровней 1–50. Случайная правка генератора не должна их менять.
## 0.18: раскладки пересобраны намеренно (свободный старт: меньше рядов камня, новые зёрна) —
## отпечаток обновлён; менять его только вместе с осознанной правкой таблицы уровней.
## 0.18 (новые цели): отпечаток считается по прежней раскладке без новинок (base_str). Обновлён
## намеренно: на уровнях «открой тайник» (из 1–50 — 16, 21, 37, 49) сундук встаёт в два нижних ряда,
## а кристалл или прикрытая дыра с его места переезжают на камень (дыра — в том же ряду); число
## кристаллов и дыр в каждом ряду то же. Остальные уровни 1–50 — как в прежнем отпечатке
## ee4044042784f8d50053618ee87548a6 (проверено сравнением по уровням).
## 0.18 (финальная подстройка сложности): обновлён намеренно — новые зёрна уровней 11–50 (кроме
## 12, 17 и 18) и hang 2 на части уровней; генератор не менялся.
## Прежний отпечаток: bf0792a5c4e1915f8b44cac38a4ff275.
const GOLDEN_1_50 := "7ec26aae6faa66535dc70699fa0a09a3"


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)


func board_str(g) -> String:
	var s := ""
	for v in g.board:
		s += str(v) + ","
	return s


## 0.18: прежняя раскладка без новинок (бомба и тайник стоят на клетках камня, кротёнок — на пустой
## клетке): по ней отпечаток GOLDEN_1_50 проверяет, что камень, дыры и кристаллы не сдвинулись.
## Полный отпечаток с новинками — в tests/test_v018_goals.gd.
func base_str(g) -> String:
	var s := ""
	for v in g.board:
		if v == g.BOMB or v == g.CHEST:
			v = g.STONE
		elif v == g.PET:
			v = g.EMPTY
		s += str(v) + ","
	return s


func count(g, v: int) -> int:
	var n := 0
	for c in g.board:
		if c == v:
			n += 1
	return n


func _initialize() -> void:
	var had_save := FileAccess.file_exists(SAVE)
	var save_bytes := FileAccess.get_file_as_bytes(SAVE) if had_save else PackedByteArray()

	var g: Node2D = load("res://scripts/game.gd").new()
	root.add_child(g)
	g._layout()
	g.tut.enabled = false
	g.assist.track = false
	I18n.set_lang("ru")

	_test_table(g)
	_test_layouts(g)
	_test_endless(g)
	_test_halls()
	_test_map(g)

	if had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	g.free()
	quit(1 if failed else 0)


func _test_table(g) -> void:
	print("— таблица уровней")
	check(Levels.LEVELS.size() == 100 and Meta.LAST_LEVEL == 100, "в таблице 100 уровней = 10 залов по 10")
	var fields_ok := true
	for p in Levels.LEVELS:
		if not (p.has("seed") and p.has("par") and int(p.par) > 0 and int(p.c) <= 8 and int(p.rows) <= 7):
			fields_ok = false
		if float(p.get("h3", 0.0)) > 2.0 or int(p.get("well", 0)) > 6 or int(p.get("isl", 0)) > 3:
			fields_ok = false
	check(fields_ok, "у каждого уровня есть seed и par, поля в допустимых пределах")
	# «Отдыхающие» уровни встречаются не реже чем через 7
	var prev := 0
	var gap_ok := true
	for i in Levels.LEVELS.size():
		if Levels.LEVELS[i].get("rest", false):
			if i + 1 - prev > 7:
				gap_ok = false
			prev = i + 1
	check(gap_ok and Levels.LEVELS.size() - prev <= 7, "отдыхающие уровни — не реже чем через 7")
	# Детерминизм: одинаковая раскладка при повторном запуске, кристаллов сколько в таблице
	var same := true
	var gems_ok := true
	var s50 := ""
	for n in range(1, 101):
		g.start_level(n)
		var a := board_str(g)
		if count(g, g.CRYSTAL) != g.crystals_total or g.crystals_total != mini(int(Levels.params(n).c), 8):
			gems_ok = false
			printerr("    уровень ", n, ": кристаллов ", count(g, g.CRYSTAL), " из ", g.crystals_total)
		g.start_level(n)
		if board_str(g) != a:
			same = false
			printerr("    уровень ", n, ": раскладка не повторяется")
		if n <= 50:
			s50 += base_str(g)
	check(same, "уровни 1–100 всегда одинаковые")
	check(gems_ok, "на уровнях 1–100 все кристаллы на месте")
	var h := s50.md5_text()
	if h != GOLDEN_1_50:
		printerr("    отпечаток 1–50: ", h)
	check(h == GOLDEN_1_50, "раскладки уровней 1–50 не изменились")
	# Скорость: не быстрее 0,25 с на клетку нигде, включая «Бесконечные глубины»
	var slow_ok := true
	for n in range(1, 161):
		g.start_level(n)
		if g.fall_interval() < 0.25 or Levels.params(n).speed > Levels.MAX_SPEED:
			slow_ok = false
			printerr("    уровень ", n, ": ", g.fall_interval(), " с на клетку")
	check(slow_ok, "скорость падения не быстрее 0,25 с на клетку на уровнях 1–160")


func _test_layouts(g) -> void:
	print("— новые приёмы раскладки")
	var isl_ok := true
	var ic_ok := true
	var well_ok := true
	var isl_levels := 0
	var well_levels := 0
	for n in range(1, 101):
		var p: Dictionary = Levels.params(n)
		g.start_level(n)
		var rows: int = clampi(p.rows, 1, 7)
		var y0: int = g.ROWS - rows
		# клетки камня/кристаллов над камнем, не считая ряда висячего блока
		var above := 0
		var gems_above := 0
		var top_ok := true
		var floating := false
		for y in range(0, y0 - 1):
			for x in g.COLS:
				var v: int = g.board[y * g.COLS + x]
				if v == g.EMPTY:
					continue
				above += 1
				if v == g.CRYSTAL:
					gems_above += 1
				if y < Levels.ISLAND_TOP:
					top_ok = false
				if g.board[(y + 1) * g.COLS + x] == g.EMPTY:
					floating = true
		var isl: int = p.get("isl", 0)
		if isl > 0:
			isl_levels += 1
			# островков столько, сколько поместилось (не больше isl): при 7 рядах камня
			# для них остаётся один ряд
			if above < 2 or above > 3 * isl or not top_ok or not floating:
				isl_ok = false
				printerr("    уровень ", n, ": островков не так (клеток ", above, ")")
			if gems_above != mini(int(p.get("ic", 0)), above):
				ic_ok = false
				printerr("    уровень ", n, ": кристаллов на островках ", gems_above)
		elif above != 0:
			isl_ok = false
			printerr("    уровень ", n, ": камень над полем без поля isl")
		var d: int = p.get("well", 0)
		if d > 0:
			well_levels += 1
			var found := false
			for x in g.COLS:
				var open := true
				for y in range(y0, y0 + d):
					if g.board[y * g.COLS + x] != g.EMPTY:
						open = false
				if open and g.board[(y0 - 1) * g.COLS + x] == g.EMPTY:
					found = true
			if not found:
				well_ok = false
				printerr("    уровень ", n, ": нет открытого колодца глубиной ", d)
	check(isl_levels >= 20 and isl_ok, "островки камня висят над полем не выше ряда ISLAND_TOP (%d уровней)" % isl_levels)
	check(ic_ok, "кристаллы на островках — сколько задано в поле ic")
	check(well_levels >= 15 and well_ok, "узкий колодец открыт сверху на всю глубину (%d уровней)" % well_levels)
	# уровни 1–50 без колодцев и островков; 0.18: лишних дыр h3 до 1,5 (вторая лишняя дыра
	# в ряду — вместо снятых рядов камня)
	var old_ok := true
	for n in range(1, 51):
		var p: Dictionary = Levels.params(n)
		if p.has("well") or p.has("isl") or p.has("ic") or float(p.get("h3", 0.0)) > 1.5:
			old_ok = false
	check(old_ok, "уровни 1–50 без колодцев и островков, h3 не больше 1,5")


func _test_endless(g) -> void:
	print("— «Бесконечные глубины»")
	var rep_ok := true
	for n in range(101, 131):
		var p: Dictionary = Levels.params(n)
		var src: Dictionary = Levels.params(95 + (n - 101) % 6)
		for k in ["rows", "h2", "c", "deep", "hang", "h3", "well", "isl", "ic", "par", "seed"]:
			if p.get(k) != src.get(k):
				rep_ok = false
		if p.speed < src.speed or p.speed > Levels.MAX_SPEED:
			rep_ok = false
	check(rep_ok, "после 100-го по кругу раскладки 95–100, скорость не выше предела")
	g.start_level(101)
	var a := board_str(g)
	g.start_level(95)
	check(a == board_str(g), "уровень 101 = раскладка 95")


func _test_halls() -> void:
	print("— залы")
	check(Meta.HALLS.size() == 11 and Meta.HALL_COUNT == 10, "10 залов и «Бесконечные глубины»")
	check(Meta.hall_index(1) == 0 and Meta.hall_index(51) == 5 and Meta.hall_index(91) == 9 and Meta.hall_index(100) == 9, "уровни 1–100 — в залах 1–10")
	check(Meta.hall_index(101) == 10 and Meta.hall_index(5000) == 10, "после 100-го — «Бесконечные глубины»")
	var names_ok := true
	var seen := {}
	for l in I18n.LANGS:
		I18n.set_lang(l)
		seen = {}
		for h in Meta.HALLS.size():
			var nm := Meta.hall_name(h)
			if nm == "" or nm.begins_with("hall_") or seen.has(nm):
				names_ok = false
			seen[nm] = true
	check(names_ok, "у всех 11 залов свои названия (en/ru)")
	I18n.set_lang("ru")
	check(Meta.hall_name(5) == "Сапфировый грот" and Meta.hall_name(9) == "Кристальная корона" and Meta.hall_name(10) == "Бесконечные глубины", "русские названия новых залов")
	var col_ok := true
	for a in Meta.HALLS.size():
		for b in range(a + 1, Meta.HALLS.size()):
			var ca: Color = Meta.HALLS[a].col
			var cb: Color = Meta.HALLS[b].col
			if Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length() < 0.2:
				col_ok = false
				printerr("    похожие цвета залов ", a, " и ", b)
	check(col_ok, "цвета залов различаются")
	# Ступени богатства дома: 1, 3, 6 пройденных залов
	var st := []
	for lv in [1, 10, 11, 21, 30, 31, 51, 60, 61, 100, 101, 500]:
		st.append(Meta.home_stage(lv))
	check(st == [0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 3], "ступени дома: после 1, 3 и 6 залов")
	var mono := true
	for lv in range(1, 200):
		if Meta.home_stage(lv + 1) < Meta.home_stage(lv):
			mono = false
	check(mono, "ступень дома не убывает с прогрессом")
	# Условия вещей «пройти зал N» по-прежнему про залы 1..10
	var cond_ok := true
	for it in Meta.ITEMS + Meta.DECOR:
		if it.has("hall") and not it.get("forge", false):  # 0.12: награды кузницы куются, а не покупаются
			var n: int = it.hall
			if n == 0:  # 0.12b: первый набор героя открыт с начала
				if Meta.lock_reason(it.id, 0, 1) != "":
					cond_ok = false
				continue
			if n < 1 or n > Meta.HALL_COUNT:
				cond_ok = false
			if Meta.lock_reason(it.id, 999, n * Meta.HALL_SIZE) == "" or Meta.lock_reason(it.id, 999, n * Meta.HALL_SIZE + 1) != "":
				cond_ok = false
	check(cond_ok, "вещи «пройти зал N» открываются ровно после зала N")
	check(Meta.hall_done(10, 101) and not Meta.hall_done(10, 100), "зал 10 пройден после 100-го уровня")
	check(I18n.t("map_locked") % Meta.LAST_LEVEL == "Откроются после 100-го уровня", "подпись закрытых глубин — после 100-го")


func _test_map(g) -> void:
	print("— карта")
	if g.screens == null:
		g.screens = load("res://scripts/screens.gd").new(g)
	var sc = g.screens
	g.max_level = 1
	check(sc.map_last() == 103, "на карте видны все 100 уровней и вход в глубины")
	var order_ok := true
	for n in range(1, 104):
		var h := Meta.hall_index(n)
		if n > 1 and sc.node_y(n) <= sc.node_y(n - 1):
			order_ok = false
		if sc.node_y(n) <= sc.hall_top(h) or (h < Meta.HALL_COUNT and sc.node_y(n) >= sc.hall_top(h + 1)):
			order_ok = false
	check(order_ok, "точки уровней идут вниз и лежат в полосе своего зала")
	# прокрутка до самого низа показывает последнюю точку
	sc.map_scroll = 1.0e9
	sc._clamp_scroll()
	var y_last: float = sc.node_y(sc.map_last()) - sc.map_scroll
	check(y_last > 0.0 and y_last < g.H, "прокрутка вниз доходит до последней точки")
	g.max_level = 87
	sc.open_map()
	var y87: float = sc.node_y(87) - sc.map_scroll
	check(y87 > 0.0 and y87 < g.H, "карта открывается на текущем уровне (87)")
	g.max_level = 1
	sc.open_map()
	check(sc.map_scroll == 0.0, "в начале карта сверху")
	g.max_level = 140
	check(sc.map_last() == 142, "в глубинах карта растёт вместе с прогрессом")
	g.max_level = 1
	g._set_state(g.State.HOME)
