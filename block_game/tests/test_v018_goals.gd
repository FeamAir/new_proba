extends SceneTree
## Тесты версии 0.18 (новые цели и клетки, scripts/specials.gd):
##   кристалл-бомба: взрыв 3×3 (камень, кристаллы — засчитываются, части фигур), цепочка бомб;
##   «Спаси кротёнка»: зверёк не пропадает при очистке ряда и при взрыве, падает дальше, на дне — победа;
##   «Янтарный тайник»: 2×2 падает целиком, открывается, когда исчезли все 4 клетки, осколки к награде;
##   «Совиное время» возвращает бомбы, зверька и тайник; «до 3 звёзд» и «Подсказка кристалла» на новых целях;
##   робот (Specials.resolve) разыгрывает так же, как игра; уровни одинаковы при повторе (отпечаток);
##   таблица: на каких уровнях новинки; подсказки при первой встрече; тексты en/ru.
## Запуск: godot --headless --path block_game -s tests/test_v018_goals.gd

var failed := 0
var frame := 0
var g
var had_save := false
var save_bytes := PackedByteArray()
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const Access := preload("res://scripts/access.gd")
const Levels := preload("res://scripts/levels.gd")
const Specials := preload("res://scripts/specials.gd")
const StarGoal := preload("res://scripts/star_goal.gd")
const Tutorial := preload("res://scripts/tutorial.gd")
const SAVE := "user://save.cfg"
## Отпечаток полных раскладок 1–100 вместе с новинками (бомбы, кротёнок, тайник).
## Менять только вместе с осознанной правкой таблицы уровней или раскладки новинок.
## 0.18 (финальная подстройка сложности): обновлён намеренно — у 86 уровней из 11–100 новые зёрна
## (подобраны роботом с моделью «спешки»), у 21 уровня hang 2 вместо 1. Правила и генератор
## раскладки не менялись. Прежний отпечаток: 0e7a0d7cc72a25f2e12d06b22baceb3f.
const GOLDEN_GOALS := "f2a699de138cda14f40863d78516f437"


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)


func _initialize() -> void:
	had_save = FileAccess.file_exists(SAVE)
	save_bytes = FileAccess.get_file_as_bytes(SAVE) if had_save else PackedByteArray()
	g = load("res://scripts/game.gd").new()
	root.add_child(g)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		_run()
	return false


func _finish() -> void:
	if had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	I18n.set_lang("ru")
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)


func _run() -> void:
	I18n.set_lang("ru")
	g.tut.enabled = false
	g.assist.track = false
	g.tour.enabled = false
	g.access = Access.new()
	g.meta = Meta.new()
	g.meta.set_hero("owl")
	g._layout()
	_test_texts()
	_test_table()
	_test_layouts()
	_test_blast_unit()
	_test_bomb_game()
	_test_bomb_chain_game()
	_test_pet()
	_test_chest()
	_test_undo()
	_test_assist()
	_test_bot_same()
	_test_tutorial()
	await _test_drawing()
	_finish()


# ---------- Помощники ----------

func idx(x: int, y: int) -> int:
	return y * g.COLS + x


## Пустое поле с заданной целью; фигура — «двойка» (горизонтальная) в колонках 0–1 наверху.
func _blank(goal := "crystals", crystals := 1) -> void:
	g.start_level(3)
	g.board.fill(g.EMPTY)
	g.piece_ids.fill(0)
	g.fall_dist.fill(0)
	g.goal = goal
	g.crystals_total = crystals
	g.crystals_left = crystals
	g.chest_total = 0
	g.chest_left = 0
	g.chest_open = false
	g.chest_shards = 4
	g.bombs_total = 0
	g.bombs_blown = 0
	g.pieces_used = 0
	g.par = 5
	g.owl.reset()
	_piece(0)


func _piece(t: int) -> void:
	g.piece_type = t
	g.piece_cells = g.SHAPES[t].cells.duplicate()
	g.piece_pos = Vector2i(0, 0)
	g.has_piece = true
	g._set_state(g.State.PLAYING)


## Ряд y — камень в колонках 2..7 (дыра в 0–1).
func _row(y: int) -> void:
	for x in range(2, g.COLS):
		g.board[idx(x, y)] = g.STONE


func _chest_at(x: int, y: int) -> void:
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		g.board[idx(x + d.x, y + d.y)] = g.CHEST
	Specials.tag_chest(g.board, g.piece_ids)
	g.chest_total = 4
	g.chest_left = 4


func _settle() -> void:
	for i in 60:
		if g.state not in [g.State.CLEARING, g.State.SETTLE]:
			return
		g.step(0.1)


func _drop_and_settle() -> void:
	g.hard_drop()
	_settle()


func _holes_by_row() -> Array:
	var out: Array = []
	for y in g.ROWS:
		var k := 0
		for x in g.COLS:
			if g.board[idx(x, y)] == g.EMPTY:
				k += 1
		out.append(k)
	return out


func _board_str() -> String:
	var s := ""
	for v in g.board:
		s += str(v) + ","
	return s


# ---------- Тексты ----------

func _test_texts() -> void:
	print("— тексты новинок (en/ru)")
	var keys := ["goal_pet_start", "goal_chest_start", "bomb_boom", "bomb_chain", "chest_open", "panel_pet",
		"panel_chest", "lose_pet", "lose_chest", "win_chest", "tut_bomb", "tut_pet", "tut_chest"]
	var miss := []
	for l in ["en", "ru"]:
		for k in keys:
			if not I18n.has_in(l, k):
				miss.append(l + ":" + k)
	check(miss.is_empty(), "тексты новинок есть на en и ru %s" % str(miss))
	check(I18n.missing_keys().is_empty(), "ни одного непереведённого ключа")
	check(I18n.t("goal_pet_start") == "Спаси кротёнка!", "ru: «Спаси кротёнка!»")
	check(I18n.t("chest_open") % 4 == "ТАЙНИК! +4" and I18n.t("bomb_boom") == "БУМ!", "ru: «ТАЙНИК! +4», «БУМ!»")


# ---------- Таблица уровней ----------

func _test_table() -> void:
	print("— таблица: где новинки")
	var pets := {}
	var chests := {}
	var bombs := 0
	var bomb_ok := true
	var early_ok := true
	var bonus := 0
	for n in range(1, 101):
		var p: Dictionary = Levels.params(n)
		var h := (n - 1) / 10
		var gl := Specials.goal_of(p)
		if gl == "pet":
			pets[h] = int(pets.get(h, 0)) + 1
		if gl == "chest":
			chests[h] = int(chests.get(h, 0)) + 1
		if int(p.get("chest", 0)) > 0:
			bonus += 1
		var b := int(p.get("bomb", 0))
		if b > 0:
			bombs += 1
			if b > 2:
				bomb_ok = false
		if (n <= 20 and b > 0) or (n <= 10 and (gl != "crystals" or p.has("chest"))):
			early_ok = false
	var halls_ok := true
	for h in range(1, 10):
		if int(pets.get(h, 0)) < 2 or int(pets.get(h, 0)) > 3 or int(chests.get(h, 0)) < 1 or int(chests.get(h, 0)) > 2:
			halls_ok = false
			printerr("    зал ", h + 1, ": кротёнок ", pets.get(h, 0), ", тайник ", chests.get(h, 0))
	check(early_ok, "зал 1 — без новинок, бомбы — с 21-го уровня")
	check(halls_ok, "залы 2–10: кротёнок на 2–3 уровнях, тайник-цель на 1–2")
	check(bonus >= 5, "бонусный тайник на обычных уровнях изредка (%d)" % bonus)
	var share := bombs / 80.0
	check(bomb_ok and share >= 0.3 and share <= 0.5, "бомбы по 1–2 на %d%% уровней 21–100" % int(share * 100))


func _test_layouts() -> void:
	print("— раскладка новинок")
	var all := ""
	var same := true
	var pet_ok := true
	var chest_ok := true
	var bomb_ok := true
	var goal_ok := true
	for n in range(1, 101):
		var p: Dictionary = Levels.params(n)
		g.start_level(n)
		var a := _board_str()
		var ids_a: Array = g.piece_ids.duplicate()
		var gl := Specials.goal_of(p)
		if g.goal != gl:
			goal_ok = false
			printerr("    уровень ", n, ": цель ", g.goal, " вместо ", gl)
		var nb := Specials.count(g.board, g.BOMB)
		if nb != int(p.get("bomb", 0)) or g.bombs_total != nb:
			bomb_ok = false
			printerr("    уровень ", n, ": бомб ", nb)
		var np := Specials.count(g.board, g.PET)
		if gl == "pet":
			var y := Specials.pet_row(g.board, g.COLS)
			var x: int = g.board.find(g.PET) % g.COLS
			if np != 1 or y >= g.ROWS - 1 or g.board[idx(x, y + 1)] == g.EMPTY:
				pet_ok = false
				printerr("    уровень ", n, ": кротёнок не на камне")
		elif np != 0:
			pet_ok = false
		var nc := Specials.count(g.board, g.CHEST)
		var want_chest: bool = gl == "chest" or int(p.get("chest", 0)) > 0
		if want_chest:
			var i0: int = g.board.find(g.CHEST)
			var square: bool = nc == 4 and g.board[i0 + 1] == g.CHEST and g.board[i0 + g.COLS] == g.CHEST and g.board[i0 + g.COLS + 1] == g.CHEST
			if not square or g.chest_total != 4 or g.chest_left != 4 or g.piece_ids[i0] != Specials.CHEST_ID:
				chest_ok = false
				printerr("    уровень ", n, ": тайник не 2×2")
			if gl == "chest" and i0 / g.COLS != g.ROWS - 2:
				chest_ok = false
				printerr("    уровень ", n, ": тайник-цель не в двух нижних рядах")
			if g.chest_shards < Specials.CHEST_MIN or g.chest_shards > Specials.CHEST_MAX:
				chest_ok = false
		elif nc != 0 or g.chest_total != 0:
			chest_ok = false
		g.start_level(n)
		if _board_str() != a or g.piece_ids != ids_a:
			same = false
			printerr("    уровень ", n, ": раскладка не повторяется")
		all += a
	check(goal_ok, "цель уровня — из таблицы (новинки всегда помещаются)")
	check(bomb_ok, "бомб на поле столько, сколько в поле bomb")
	check(pet_ok, "кротёнок один, сидит на камне, не на дне")
	check(chest_ok, "тайник — квадрат 2×2 (цель — в двух нижних рядах), внутри 3–5 осколков")
	check(same, "уровни 1–100 с новинками всегда одинаковые")
	var h := all.md5_text()
	if h != GOLDEN_GOALS:
		printerr("    отпечаток 1–100 с новинками: ", h)
	check(h == GOLDEN_GOALS, "отпечаток раскладок 1–100 с новинками не изменился")
	# тайник-цель встаёт в два нижних ряда: дыр в каждом ряду и кристаллов на поле — столько же,
	# сколько в той же раскладке без тайника
	var keep_ok := true
	for n in range(1, 101):
		if Specials.goal_of(Levels.params(n)) != "chest":
			continue
		g.level_override = {"goal": "crystals"}
		g.start_level(n)
		var h1 := _holes_by_row()
		var c1 := Specials.count(g.board, g.CRYSTAL)
		g.level_override = {}
		g.start_level(n)
		if _holes_by_row() != h1 or Specials.count(g.board, g.CRYSTAL) != c1:
			keep_ok = false
			printerr("    уровень ", n, ": тайник изменил дыры или кристаллы")
	g.level_override = {}
	check(keep_ok, "тайник-цель: дыр в каждом ряду и кристаллов столько же, сколько без него")
	# бонусный тайник и бомбы не меняют прежнюю раскладку: под ними камень, кристаллы на месте
	g.start_level(31)
	check(Specials.count(g.board, g.CRYSTAL) == g.crystals_total, "кристаллы на месте (бомба и тайник — только на камне)")


# ---------- Бомба ----------

func _test_blast_unit() -> void:
	print("— взрыв 3×3 (Specials.blast)")
	var b: Array = []
	b.resize(8 * 6)
	b.fill(-1)
	# ряд 5 полный, бомба в (3,5); сверху камень, кристалл, кротёнок; вторая бомба в (4,4)
	for x in 8:
		b[5 * 8 + x] = 7
	b[5 * 8 + 3] = Specials.BOMB
	b[4 * 8 + 2] = 7
	b[4 * 8 + 3] = Specials.PET
	b[4 * 8 + 4] = 7
	var r := Specials.blast(b, [5], 8, 6)
	check(r.bombs.size() == 1 and r.cells == [4 * 8 + 2, 4 * 8 + 4], "бомба в ряду: выбит квадрат 3×3 вокруг (вне ряда — 2 клетки), кротёнок цел")
	b[4 * 8 + 4] = Specials.BOMB
	b[3 * 8 + 5] = 8
	r = Specials.blast(b, [5], 8, 6)
	check(r.bombs.size() == 2 and r.cells.has(3 * 8 + 5) and r.cells.has(4 * 8 + 4), "бомба во взрыве взрывается следом (цепочка): её 3×3 тоже выбит")
	check(not r.cells.has(4 * 8 + 3), "кротёнок не выбивается и цепочкой")
	var t := Specials.tally(b, [5], r.cells, 8)
	check(t.crystals == 1 and t.low == 5, "кристалл во взрыве засчитывается")
	r = Specials.blast(b, [], 8, 6)
	check(r.bombs.is_empty() and r.cells.is_empty(), "без очищенного ряда бомба не взрывается")


func _test_bomb_game() -> void:
	print("— бомба в игре: взрыв, кристаллы, осыпание")
	_blank("crystals", 2)
	_row(13)
	g.board[idx(4, 13)] = g.BOMB
	g.board[idx(3, 12)] = g.STONE
	g.board[idx(4, 12)] = g.CRYSTAL
	g.board[idx(5, 12)] = 2  # часть фигуры
	g.piece_ids[idx(5, 12)] = 77
	g.board[idx(7, 12)] = g.CRYSTAL
	g.board[idx(7, 11)] = g.STONE
	g.hard_drop()
	check(g.state == g.State.CLEARING and g.blast_cells.size() == 3 and g.blast_bombs.size() == 1, "очищен ряд с бомбой — взрыв (3 клетки над рядом)")
	check(g.crystals_left == 1, "кристалл в зоне взрыва засчитан освобождённым")
	check(g.shake >= 14.0 and g.boom_fx.booms.size() == 1, "вспышка и сильная тряска")
	_settle()
	check(g.board[idx(3, 12)] == g.EMPTY and g.board[idx(4, 12)] == g.EMPTY and g.board[idx(5, 12)] == g.EMPTY, "камень, кристалл и часть фигуры в зоне исчезли")
	check(g.board[idx(7, 13)] == g.CRYSTAL and g.board[idx(7, 12)] == g.STONE, "сверху всё осыпалось (кристалл и камень за зоной)")
	check(g.bombs_blown == 1 and g.state == g.State.PLAYING, "взорвалась одна бомба, игра идёт")


func _test_bomb_chain_game() -> void:
	print("— цепочка бомб в игре")
	_blank("crystals", 3)
	_row(13)
	g.board[idx(4, 13)] = g.BOMB
	g.board[idx(5, 12)] = g.BOMB
	g.board[idx(6, 11)] = g.CRYSTAL
	g.board[idx(7, 11)] = g.STONE
	g.board[idx(0, 5)] = g.CRYSTAL  # ещё кристаллы далеко — уровень не кончается
	g.board[idx(1, 5)] = g.CRYSTAL
	g.board[idx(0, 6)] = g.STONE
	g.board[idx(1, 6)] = g.STONE
	g.piece_pos = Vector2i(0, 12)  # колонки 0–1 заняты сверху — двойка сразу у дыры
	g.hard_drop()
	check(g.blast_bombs.size() == 2, "вторая бомба в зоне взрыва взрывается цепочкой")
	check(g.blast_cells.has(idx(6, 11)) and not g.blast_cells.has(idx(7, 11)), "квадрат второй бомбы тоже выбит")
	check(g.crystals_left == 2, "кристалл во взрыве второй бомбы засчитан")
	_settle()
	check(g.bombs_blown == 2 and g.board[idx(7, 13)] == g.STONE, "после цепочки — осыпание")
	var pops := false
	for p in g.popups:
		if String(p.text) == I18n.t("bomb_chain") % 2:
			pops = true
	check(pops, "надпись «БУМ ×2!»")


# ---------- Кротёнок ----------

func _test_pet() -> void:
	print("— «Спаси кротёнка»")
	_blank("pet", 1)
	g.board[idx(7, 3)] = g.CRYSTAL  # кристалл далеко — на этой цели не нужен
	_row(13)
	_row(12)
	g.board[idx(4, 12)] = g.PET
	_piece(3)  # квадрат 2×2 закрывает дыры обоих рядов
	check(g.pet_depth() == 1 and not g.goal_done(), "кротёнок на глубине 1, цель не выполнена")
	g.pieces_used = g.par - 1
	g.hard_drop()
	check(g.state == g.State.CLEARING and g.clearing_rows.size() == 2, "очищаются оба ряда, в одном — кротёнок")
	g.step(g.CLEAR_TIME + 0.01)
	check(Specials.count(g.board, g.PET) == 1, "после очистки ряда кротёнок не пропал")
	_settle()
	check(g.board[idx(4, 13)] == g.PET, "кротёнок упал на самое дно")
	check(g.state == g.State.WIN, "кротёнок на дне — победа (кристалл не нужен)")
	check(g.last_stars == 3 and g.pieces_used == g.par, "звёзды за победу как обычно (par фигур — 3 звезды)")
	check(StarGoal.goal(g.par, g.par - 1) == [3, 1], "строка «до 3 звёзд» на уровне с кротёнком")
	# кротёнок во взрыве цел, падает дальше
	_blank("pet", 1)
	_row(13)
	g.board[idx(5, 13)] = g.BOMB
	_row(12)
	g.board[idx(4, 12)] = g.PET
	_row(11)
	g.board[idx(4, 11)] = g.EMPTY
	g.board[idx(4, 10)] = g.STONE  # камень над кротёнком
	g.hard_drop()  # двойка — в дыру ряда 13
	check(g.blast_bombs.size() == 1 and not g.blast_cells.has(idx(4, 12)), "взрыв рядом не трогает кротёнка")
	_settle()
	check(Specials.count(g.board, g.PET) == 1 and g.board[idx(4, 13)] == g.PET and g.state == g.State.WIN, "после взрыва кротёнок осыпался на дно — победа")
	# зверька нельзя «потерять» и в стопке рядов: много очисток подряд
	_blank("pet", 1)
	for y in range(9, 14):
		_row(y)
	g.board[idx(3, 8)] = g.PET
	g.board[idx(3, 7)] = g.STONE
	for k in 5:
		if g.state != g.State.PLAYING:
			break
		_piece(0)
		g.hard_drop()
		_settle()
	check(Specials.count(g.board, g.PET) == 1 and g.state == g.State.WIN, "5 рядов под кротёнком очищены по одному — он на дне, победа")


# ---------- Тайник ----------

func _test_chest() -> void:
	print("— «Янтарный тайник»")
	_blank("chest", 1)
	g.board[idx(7, 3)] = g.CRYSTAL
	_row(13)
	_row(12)
	_chest_at(4, 12)
	g.board[idx(3, 11)] = g.STONE
	_piece(0)
	g.hard_drop()  # двойка закрывает только ряд 13
	_settle()
	check(g.chest_left == 2 and not g.chest_open, "очищен один ряд тайника — половина, ещё закрыт")
	check(g.board[idx(4, 13)] == g.CHEST and g.board[idx(5, 13)] == g.CHEST and g.piece_ids[idx(4, 13)] == Specials.CHEST_ID, "верх тайника упал целиком (одна группа)")
	check(g.state == g.State.PLAYING, "цель ещё не выполнена")
	# дыры ряда 13 снова: верхний ряд камня осыпался
	for x in g.COLS:
		if g.board[idx(x, 13)] == g.EMPTY and x > 1:
			g.board[idx(x, 13)] = g.STONE
	g.board[idx(0, 13)] = g.EMPTY
	g.board[idx(1, 13)] = g.EMPTY
	var shards_before: int = g.meta.shards
	_piece(0)
	g.hard_drop()
	_settle()
	check(g.chest_open and g.chest_left == 0, "все 4 клетки исчезли — тайник открыт")
	check(g.state == g.State.WIN, "цель «тайник» — победа")
	check(int(g.last_reward.get("chest", 0)) == g.chest_shards and g.meta.shards - shards_before == int(g.last_reward.total), "осколки тайника прибавлены к награде")
	# бонусный тайник на обычном уровне
	_blank("crystals", 1)
	_row(13)
	_row(12)
	_chest_at(2, 12)
	g.board[idx(7, 12)] = g.CRYSTAL
	_piece(3)
	g.hard_drop()
	_settle()
	check(g.state == g.State.WIN and g.chest_open and int(g.last_reward.get("chest", 0)) == 4, "бонусный тайник: открыт вместе с победой — +4 осколка")
	_blank("crystals", 1)
	_row(13)
	g.board[idx(7, 13)] = g.CRYSTAL
	_chest_at(2, 11)
	_piece(0)
	g.hard_drop()
	_settle()
	check(g.state == g.State.WIN and not g.chest_open and not g.last_reward.has("chest"), "тайник не открыт — без его осколков")


# ---------- «Совиное время» ----------

func _test_undo() -> void:
	print("— «Совиное время» возвращает бомбы, зверька и тайник")
	_blank("crystals", 2)
	_row(13)
	g.board[idx(6, 13)] = g.BOMB
	g.bombs_total = 1
	_chest_at(2, 12)
	g.board[idx(4, 12)] = g.CRYSTAL
	g.board[idx(6, 12)] = g.STONE
	g.board[idx(7, 2)] = g.CRYSTAL
	var before := _board_str()
	var ids_before: Array = g.piece_ids.duplicate()
	g.hard_drop()
	_settle()
	check(g.state == g.State.PLAYING and g.bombs_blown == 1 and g.chest_left == 2, "ход: взрыв, тайник наполовину")
	check(g.undo_piece(), "отмена доступна")
	check(_board_str() == before and g.piece_ids == ids_before, "поле, бомба и тайник (с номером группы) вернулись")
	check(g.bombs_blown == 0 and g.chest_left == 4 and not g.chest_open and g.crystals_left == 2, "счётчики бомб, тайника и кристаллов вернулись")
	check(g.blast_cells.is_empty() and g.blast_bombs.is_empty(), "после отмены нет «висящего» взрыва")
	# кротёнок
	_blank("pet", 1)
	_row(13)
	_row(12)
	g.board[idx(4, 11)] = g.PET
	g.hard_drop()
	_settle()
	check(g.pet_depth() == 1 and g.state == g.State.PLAYING, "ход: кротёнок опустился на ряд")
	check(g.undo_piece() and g.pet_depth() == 2 and g.board[idx(4, 11)] == g.PET, "отмена вернула кротёнка на место")
	# тайник открыт и отменён
	_blank("crystals", 2)
	g.board[idx(6, 2)] = g.CRYSTAL
	g.board[idx(7, 2)] = g.CRYSTAL
	_row(13)
	_row(12)
	_chest_at(3, 12)
	_piece(3)
	g.hard_drop()
	_settle()
	check(g.chest_open and g.state == g.State.PLAYING, "ход: тайник открыт (уровень продолжается)")
	check(g.undo_piece() and not g.chest_open and g.chest_left == 4 and Specials.count(g.board, g.CHEST) == 4, "отмена закрыла тайник обратно")


# ---------- «Подсказка кристалла» ----------

func _first(goal: String) -> int:
	for n in range(1, 101):
		if Specials.goal_of(Levels.params(n)) == goal:
			return n
	return -1


func _test_assist() -> void:
	print("— «Подсказка кристалла» на новых целях")
	var pet_ok := true
	var chest_ok := true
	for n in range(1, 101):
		var gl := Specials.goal_of(Levels.params(n))
		if gl == "crystals":
			continue
		for rows in [1, 2]:
			g.assist.boost_level = n
			g.assist.boost_rows = rows
			g.start_level(n)
			if gl == "pet" and (Specials.count(g.board, g.PET) != 1 or g.pet_depth() <= 0 or g.goal_done()):
				pet_ok = false
				printerr("    уровень ", n, ": кротёнок после помощи — глубина ", g.pet_depth())
			if gl == "chest":
				var i0: int = g.board.find(g.CHEST)
				if Specials.count(g.board, g.CHEST) != 4 or i0 / g.COLS != g.ROWS - 2 or g.chest_left != 4 or g.goal_done():
					chest_ok = false
					printerr("    уровень ", n, ": тайник после помощи")
	check(pet_ok, "кротёнок остаётся на камне, не на дне — победа не дарится")
	check(chest_ok, "тайник остаётся целым в двух нижних рядах")
	var n := _first("pet")
	g.start_level(n)
	g.pieces_used = 2
	g._lose()
	check(g.goal_status() == I18n.t("lose_pet") % g.pet_depth(), "итог поражения: «Кротёнку до дна: N»")


# ---------- Робот ----------

## Робот разыгрывает цепочку мгновенно (Specials.resolve) — результат должен совпасть с игрой.
func _test_bot_same() -> void:
	print("— робот разыгрывает новинки так же, как игра")
	var same := true
	var cases := 0
	for n in range(11, 101):
		var p: Dictionary = Levels.params(n)
		if Specials.goal_of(p) == "crystals" and int(p.get("bomb", 0)) == 0 and int(p.get("chest", 0)) == 0:
			continue
		g.start_level(n)
		for k in 6:
			if g.state != g.State.PLAYING:
				break
			# фигура — в самую левую колонку, где помещается
			var b := PackedInt32Array(g.board)
			var ids := PackedInt32Array(g.piece_ids)
			var pos: Vector2i = g.piece_pos
			pos.x = (k * 3) % (g.COLS - 2)
			if not g.fits(g.piece_cells, pos):
				break
			g.piece_pos = pos
			while g.fits(g.piece_cells, g.piece_pos + Vector2i(0, 1)):
				g.piece_pos.y += 1
			for c in g.piece_cells:
				b[(c.y + g.piece_pos.y) * g.COLS + c.x + g.piece_pos.x] = g.piece_type
				ids[(c.y + g.piece_pos.y) * g.COLS + c.x + g.piece_pos.x] = g.next_piece_id + 1
			Specials.resolve(b, ids, g.COLS, g.ROWS, g.EMPTY, g.FALL_ALL)
			g.hard_drop()
			_settle()
			cases += 1
			if Array(b) != g.board:
				same = false
				printerr("    уровень ", n, ", ход ", k, ": поле робота и игры разное")
	check(same and cases > 50, "поле после хода у робота и в игре совпадает (%d ходов)" % cases)


# ---------- Подсказки при первой встрече ----------

func _test_tutorial() -> void:
	print("— подсказки при первой встрече")
	g.tut.enabled = true
	g.tut.seen = {}
	for s in Tutorial.STEPS:
		if s.has("level"):
			g.tut.seen[s.id] = true
	g.tut.seen[Tutorial.UNDO_HINT] = true
	var nb := -1
	for n in range(1, 101):
		if int(Levels.params(n).get("bomb", 0)) > 0 and Specials.goal_of(Levels.params(n)) == "crystals" and int(Levels.params(n).get("chest", 0)) == 0:
			nb = n
			break
	g.start_level(nb)
	check(g.tut.cur == "sp_bomb" and g.tut.is_info(), "первая бомба — пояснение «Огненный кристалл…»")
	check(Tutorial.special_rect(g, g.BOMB).size.x > 0, "окно подсказки — на бомбе")
	g.tut.t = 1.0
	g.tut.on_tap(g, Vector2.ZERO)
	check(g.tut.cur == "" and g.tut.seen.has("sp_bomb"), "касание закрывает подсказку")
	g.start_level(nb)
	check(g.tut.cur != "sp_bomb", "второй раз не показывается")
	g.start_level(_first("pet"))
	check(g.tut.cur == "sp_pet", "первый кротёнок — «Спаси кротёнка…»")
	g.tut.seen["sp_pet"] = true
	g.start_level(_first("chest"))
	check(g.tut.cur == "sp_chest", "первый тайник — «Очисти оба ряда тайника…»")
	g.tut.seen["sp_chest"] = true
	g.tut.replay()
	check(not g.tut.seen.has("sp_bomb"), "«Обучение» в паузе показывает их снова")
	g.tut.enabled = false
	g.tut.cur = ""


# ---------- Рисование ----------

func _test_drawing() -> void:
	print("— рисование новинок")
	g.max_level = 60
	for n in [_first("pet"), _first("chest"), 31]:
		g.start_level(n)
		g.queue_redraw()
		await process_frame
		await process_frame
	g._set_state(g.State.MAP)
	g.queue_redraw()
	await process_frame
	g.start_level(_first("pet"))
	g._lose()
	g.state_time = 2.0
	g.queue_redraw()
	await process_frame
	check(true, "поле, панель, карта и итог с новинками рисуются без ошибок")
