extends SceneTree
## Запуск: godot --headless --path block_game -s tests/test_logic.gd

var failed := 0
const I18n := preload("res://scripts/i18n.gd")

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)

func count(g, v: int) -> int:
	var n := 0
	for c in g.board:
		if c == v:
			n += 1
	return n

func run(g, sec: float) -> void:
	var t := 0.0
	while t < sec:
		g.step(0.02)
		t += 0.02

func _initialize() -> void:
	# Тест «Победа» сохраняет прогресс — бережём настоящее сохранение игрока.
	var save_path := "user://save.cfg"
	var had_save := FileAccess.file_exists(save_path)
	var save_bytes := FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()

	var g: Node2D = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.tut.enabled = false  # 0.9: обучение проверяется в tests/test_v09.gd

	g.start_level(1)
	check(g.state == g.State.PLAYING and g.has_piece, "уровень 1 стартует, есть фигура")
	check(count(g, g.CRYSTAL) == g.crystals_total and g.crystals_total >= 2, "кристаллы расставлены")
	var crystals_l1: Array = []
	for i in g.board.size():
		if g.board[i] == g.CRYSTAL:
			crystals_l1.append(i)
	g.start_level(1)
	var again: Array = []
	for i in g.board.size():
		if g.board[i] == g.CRYSTAL:
			again.append(i)
	check(crystals_l1 == again, "уровень всегда одинаковый")
	g.start_level(20)
	check(g.crystals_total <= 8 and count(g, g.CRYSTAL) == g.crystals_total, "поздний уровень корректен")

	# Висячие блоки (поле hang): над верхним рядом камня висит блок, под ним дыра,
	# кристаллов столько же, сколько в таблице
	var lv: Script = load("res://scripts/levels.gd")
	var hang_ok := true
	for n in range(1, lv.LEVELS.size() + 1):
		var p: Dictionary = lv.params(n)
		if p.get("hang", 0) <= 0:
			continue
		g.start_level(n)
		var top: int = g.ROWS - clampi(p.rows, 1, 7)
		var hanging := 0
		for x in g.COLS:
			if g.board[(top - 1) * g.COLS + x] == g.STONE and g.board[top * g.COLS + x] == -1:
				hanging += 1
		if hanging != 1 or count(g, g.CRYSTAL) != g.crystals_total:
			hang_ok = false
	check(hang_ok, "висячий блок над дырой на всех уровнях с hang")
	var speed_ok := true
	for n in range(1, 160):
		if lv.params(n).speed > lv.MAX_SPEED:
			speed_ok = false
	check(speed_ok, "скорость не выше 0,26 с на клетку (ступень 21) и после 100-го")

	# Уровень 1: вертикальная фигура в колодец даёт каскад
	g.start_level(1)
	var shaft := -1
	for x in g.COLS:
		if g.board[(g.ROWS - 1) * g.COLS + x] == -1:
			shaft = x
	g.next_type = 1  # палочка из трёх
	g._spawn()
	g.rotate_piece()
	var guard := 0
	while guard < 10:
		var minx := 99
		for c in g.piece_cells:
			minx = mini(minx, c.x + g.piece_pos.x)
		if minx == shaft or not g.move(1 if shaft > minx else -1):
			break
		guard += 1
	g.hard_drop()
	var max_chain: int = g.chain
	for i in 60:
		g.step(0.02)
		max_chain = maxi(max_chain, g.chain)
	check(max_chain >= 2, "уровень 1: каскад ×2 с первой фигуры")

	# Стенки
	g.start_level(1)
	for i in 20:
		g.move(-1)
	var min_x := 99
	for c in g.piece_cells:
		min_x = mini(min_x, c.x + g.piece_pos.x)
	check(min_x == 0, "упор в левую стенку")

	# Поворот 4 раза = исходная фигура (для всех вращаемых)
	var ok := true
	for t in g.SHAPES.size():
		g.start_level(1)
		g.board.fill(-1)
		g.next_type = t
		g._spawn()
		var before: Array = g.piece_cells.duplicate()
		for i in 4:
			g.rotate_piece()
		if g.piece_cells != before:
			ok = false
	check(ok, "4 поворота возвращают любую фигуру")

	# Линия с кристаллом: кристалл собирается
	g.start_level(1)
	g.board.fill(-1)
	var y: int = g.ROWS - 1
	for x in range(2, g.COLS):
		g.board[y * g.COLS + x] = g.STONE
	g.board[y * g.COLS + 5] = g.CRYSTAL
	g.board[(g.ROWS - 2) * g.COLS + 3] = g.CRYSTAL  # второй кристалл, чтобы уровень не закончился
	g.crystals_total = 2
	g.crystals_left = 2
	g.next_type = 0  # домино горизонтально
	g._spawn()
	for i in 10:
		g.move(-1)
	g.hard_drop()
	check(g.state == g.State.CLEARING, "полная линия уходит в очистку")
	check(g.crystals_left == 1, "кристалл в линии собран")
	run(g, 1.0)
	check(g.board[(g.ROWS - 1) * g.COLS + 3] == g.CRYSTAL, "каскад: верхний кристалл осыпался вниз")
	check(g.state == g.State.PLAYING, "после очистки игра продолжается")

	# Каскад-цепочка: после осыпания собирается вторая линия
	g.start_level(1)
	g.board.fill(-1)
	var b: int = g.ROWS - 1
	for x in range(1, g.COLS):
		g.board[b * g.COLS + x] = g.STONE           # нижний ряд: дыра в x=0
	for x in range(2, g.COLS):
		g.board[(b - 1) * g.COLS + x] = g.STONE     # ряд выше: дыры в x=0,1
	g.board[(b - 3) * g.COLS + 1] = g.STONE         # висящий блок над дырой (x=1)
	g.crystals_total = 1
	g.crystals_left = 1
	g.board[0 * g.COLS + 7] = g.CRYSTAL             # кристалл далеко, чтобы не выиграть
	# вертикальная I3 в колонку 0: закрывает дыры в нижних двух рядах и ещё одну клетку
	g.next_type = 1
	g._spawn()
	g.rotate_piece()
	for i in 10:
		g.move(-1)
	g.hard_drop()
	check(g.chain == 1, "первая линия")
	run(g, 1.0)
	check(g.chain >= 2 or g.score >= 100 + 250, "каскад дал вторую линию (цепочка)")

	# «Липкая» гравитация: фигура над дырой не проваливается в неё по клеткам
	g.start_level(1)
	g.board.fill(-1)
	g.piece_ids.fill(0)
	b = g.ROWS - 1
	for x in range(0, 7):
		g.board[b * g.COLS + x] = g.STONE           # нижний ряд: дыра в x=7
		if x != 3:
			g.board[(b - 1) * g.COLS + x] = g.STONE  # ряд выше: дыры в x=3 и x=7
	for x in range(2, 5):                            # лежачая палочка над дырой x=3
		g.board[(b - 2) * g.COLS + x] = 1
		g.piece_ids[(b - 2) * g.COLS + x] = 500
	g.crystals_total = 1
	g.crystals_left = 1
	g.next_type = 0  # домино вертикально в колонку 7
	g._spawn()
	g.rotate_piece()
	for i in 10:
		g.move(1)
	g.hard_drop()
	check(g.state == g.State.CLEARING and g.chain == 1, "липкая: нижний ряд очищается")
	var max_fall := 0
	for i in 60:
		g.step(0.02)
		if g.state == g.State.SETTLE:
			for f in g.fall_dist:
				max_fall = maxi(max_fall, f)
	var bridge_ok: bool = g.board[b * g.COLS + 3] == -1
	for x in range(2, 5):
		bridge_ok = bridge_ok and g.board[(b - 1) * g.COLS + x] == 1 and g.piece_ids[(b - 1) * g.COLS + x] == 500
		bridge_ok = bridge_ok and g.board[(b - 2) * g.COLS + x] == -1
	check(bridge_ok, "липкая: фигура упала целиком на 1 ряд и висит над дырой")
	check(max_fall == 1, "липкая: анимация падения (fall_dist) задана")
	check(g.state == g.State.PLAYING, "липкая: игра продолжается")

	# Цепочка ×3: после второй очистки камень падает в дыру, которую прикрывало домино
	g.start_level(1)
	g.board.fill(-1)
	g.piece_ids.fill(0)
	b = g.ROWS - 1
	for x in range(1, 8):
		g.board[b * g.COLS + x] = g.STONE                 # ряд 0: дыра x=0
	for x in [1, 2, 3, 4, 6, 7]:
		g.board[(b - 1) * g.COLS + x] = g.STONE           # ряд 1: дыры x=0, x=5
	for x in [2, 3, 4, 7]:
		g.board[(b - 2) * g.COLS + x] = g.STONE           # ряд 2: дыры x=0, x=1
	for x in [5, 6]:
		g.board[(b - 2) * g.COLS + x] = 2                 # домино прикрывает дыру x=5
		g.piece_ids[(b - 2) * g.COLS + x] = 600
	g.board[(b - 3) * g.COLS + 1] = g.STONE               # висячий камень над дырой x=1
	g.board[(b - 3) * g.COLS + 5] = g.STONE               # камень лежит на домино
	g.crystals_total = 1
	g.crystals_left = 1
	# та же позиция в мгновенной симуляции робота (tools/level_bot.gd)
	var sb := PackedInt32Array(g.board)
	var sids := PackedInt32Array(g.piece_ids)
	for yy in [b, b - 1, b - 2]:
		sb[yy * g.COLS] = 1
		sids[yy * g.COLS] = 900
	var sim: Dictionary = g.Gravity.resolve(sb, sids, g.COLS, g.ROWS, g.EMPTY, [g.STONE, g.CRYSTAL], g.CRYSTAL, g.FALL_ALL)
	check(sim.chain == 3 and sim.lines == 3, "симуляция робота тоже даёт ×3")
	g.next_type = 1  # палочка из трёх вертикально в колонку 0
	g._spawn()
	g.rotate_piece()
	for i in 10:
		g.move(-1)
	g.hard_drop()
	max_chain = g.chain
	var combo_popup := false
	for i in 100:
		g.step(0.02)
		max_chain = maxi(max_chain, g.chain)
		for pp in g.popups:
			if String(pp.get("text", "")) == I18n.t("cascade") % 3:
				combo_popup = true
	check(max_chain == 3, "построенная позиция даёт цепочку ×3 (вышло ×%d)" % max_chain)
	check(combo_popup, "надпись «КАСКАД ×3» (на текущем языке: %s)" % (I18n.t("cascade") % 3))
	check(g.state == g.State.PLAYING, "после цепочки ×3 игра продолжается")

	# Разрезанная очисткой фигура падает частями
	g.start_level(1)
	g.board.fill(-1)
	g.piece_ids.fill(0)
	b = g.ROWS - 1
	for x in [0, 1, 2, 3, 5]:
		g.board[b * g.COLS + x] = g.STONE                 # ряд 0: дыры x=4, x=6, x=7
	for x in [0, 1, 5, 6]:
		g.board[(b - 1) * g.COLS + x] = g.STONE           # ряд 1: фигура в x=2..4, дыра x=7
	for c in [Vector2i(2, b - 1), Vector2i(3, b - 1), Vector2i(4, b - 1), Vector2i(2, b - 2), Vector2i(4, b - 2)]:
		g.board[c.y * g.COLS + c.x] = 6                   # «U»: перекладина в ряду 1, ножки над ней
		g.piece_ids[c.y * g.COLS + c.x] = 700
	g.crystals_total = 1
	g.crystals_left = 1
	g.next_type = 0  # домино вертикально в колонку 7
	g._spawn()
	g.rotate_piece()
	for i in 10:
		g.move(1)
	g.hard_drop()
	check(g.chain == 1 and g.clearing_rows == [b - 1], "разрез: очищается ряд с перекладиной")
	run(g, 1.0)
	var split_ok: bool = g.board[(b - 1) * g.COLS + 2] == 6 and g.board[b * g.COLS + 4] == 6
	split_ok = split_ok and g.board[(b - 1) * g.COLS + 4] == -1 and g.board[(b - 2) * g.COLS + 2] == -1
	check(split_ok, "разрез: левая ножка упала на 1, правая — на 2 (в дыру)")
	check(g.chain == 1 and g.state == g.State.PLAYING, "разрез: лишних линий нет")

	# Победа: последний кристалл
	g.start_level(1)
	g.board.fill(-1)
	for x in range(2, g.COLS):
		g.board[(g.ROWS - 1) * g.COLS + x] = g.STONE
	g.board[(g.ROWS - 1) * g.COLS + 4] = g.CRYSTAL
	g.crystals_total = 1
	g.crystals_left = 1
	g.next_type = 0
	g._spawn()
	for i in 10:
		g.move(-1)
	g.hard_drop()
	run(g, 1.0)
	check(g.state == g.State.WIN and g.last_stars >= 1, "все кристаллы — уровень пройден")

	# Поражение
	g.start_level(1)
	for i in g.board.size():
		g.board[i] = g.STONE if i % g.COLS != 0 else -1
	g._spawn()
	check(g.state == g.State.LOSE, "переполнение — поражение")

	_test_meta(g, max_chain)
	_test_i18n(g)
	_test_new_heroes(g)

	if had_save:
		var f := FileAccess.open(save_path, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	# Подарок старым игрокам: 30 + 5 за звезду
	var GameScript = load("res://scripts/game.gd")
	check(GameScript.legacy_gift(0) == 30 and GameScript.legacy_gift(10) == 80, "подарок за старый прогресс")

	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)


# ---------- Мета-слой 0.6: осколки, гардероб, герои, дома ----------

func _test_meta(g, _chain3: int) -> void:
	var Meta: Script = load("res://scripts/meta.gd")

	# Начисление осколков
	var r: Dictionary = Meta.win_reward(true, 0, 1, 0)
	check(r.total == 15 and r.win == 10 and r.stars == 5, "первая победа на 1 звезду: +10 и +5 (=15)")
	r = Meta.win_reward(false, 1, 3, 0)
	check(r.total == 3 + 10, "повторная победа, 1→3 звезды: +3 и +10")
	r = Meta.win_reward(false, 3, 2, 0)
	check(r.total == 3 and r.stars == 0, "повторная без новых звёзд: только +3")
	r = Meta.win_reward(false, 3, 3, 2)
	check(r.chains == 6 and r.total == 9, "две цепочки ×3+: +6")
	r = Meta.win_reward(true, 0, 3, 9)
	check(r.chains == 12 and r.total == 10 + 15 + 12, "за цепочки не больше +12")

	# Победа в игре начисляет осколки; цепочка ×3 считается
	g.meta = Meta.new()
	g.stars = {}
	g.start_level(3)
	g.big_chains = 2
	g.pieces_used = 1
	g._win()
	check(g.meta.shards == 10 + 15 + 6, "победа в игре: первая, 3 звезды, 2 цепочки = 31 осколок (вышло %d)" % g.meta.shards)
	g.start_level(3)
	g.pieces_used = 1
	g._win()
	check(g.meta.shards == 31 + 3, "повторная победа на тот же рекорд: +3")
	check(g.last_reward.total == 3, "last_reward для экрана победы")
	# цепочка ×3 в настоящей партии (та же позиция, что в тесте выше)
	g.start_level(1)
	g.board.fill(-1)
	g.piece_ids.fill(0)
	var b: int = g.ROWS - 1
	for x in range(1, 8):
		g.board[b * g.COLS + x] = g.STONE
	for x in [1, 2, 3, 4, 6, 7]:
		g.board[(b - 1) * g.COLS + x] = g.STONE
	for x in [2, 3, 4, 7]:
		g.board[(b - 2) * g.COLS + x] = g.STONE
	for x in [5, 6]:
		g.board[(b - 2) * g.COLS + x] = 2
		g.piece_ids[(b - 2) * g.COLS + x] = 600
	g.board[(b - 3) * g.COLS + 1] = g.STONE
	g.board[(b - 3) * g.COLS + 5] = g.STONE
	g.crystals_total = 1
	g.crystals_left = 1
	g.board[0 * g.COLS + 7] = g.CRYSTAL
	g.next_type = 1
	g._spawn()
	g.rotate_piece()
	for i in 10:
		g.move(-1)
	g.hard_drop()
	run(g, 2.0)
	check(g.big_chains == 1, "цепочка ×3 засчитана для осколков (big_chains = %d)" % g.big_chains)

	# Покупка (0.12b: у каждого друга свои вещи — покупаются только вещи своего героя)
	var m = Meta.new()
	check(m.hero == "" and m.set_hero("owl") and m.hero == "owl", "выбор совёнка")
	check(not m.set_hero("dragon") and m.hero == "owl", "неизвестный герой не выбирается")
	m.shards = 25
	check(m.buy("ow_mortarboard", 0, 1) == Meta.Buy.OK and m.shards == 5 and m.is_owned("ow_mortarboard"), "покупка: хватает осколков")
	check(m.buy("ow_halfglasses", 0, 1) == Meta.Buy.POOR and m.shards == 5 and not m.is_owned("ow_halfglasses"), "покупка: не хватает — ничего не списано")
	check(m.buy("ow_mortarboard", 0, 1) == Meta.Buy.OWNED, "второй раз не покупается")
	m.shards = 500
	check(m.buy("ow_quill", 999, 30) == Meta.Buy.LOCKED and m.shards == 500, "перо закрыто до прохождения 3-го зала")
	check(m.buy("ow_quill", 0, 31) == Meta.Buy.OK, "перо открыто после 3-го зала")
	check(m.buy("ow_dome_hat", 999, 50) == Meta.Buy.LOCKED and m.buy("ow_dome_hat", 0, 51) == Meta.Buy.OK, "шапка-обсерватория — после 5-го зала")
	check(m.buy("ax_starfish", 0, 99) == Meta.Buy.LOCKED and not m.is_owned("ax_starfish"), "вещь другого друга не покупается")
	check(m.buy("nope", 0, 1) == Meta.Buy.UNKNOWN, "неизвестная вещь не покупается")

	# Надеть / снять
	check(not m.equip("ow_halfglasses"), "некупленное не надевается")
	check(m.equip("ow_mortarboard") and m.is_equipped("ow_mortarboard"), "надеть шапочку")
	check(m.equip("ow_quill") and m.is_equipped("ow_quill") and not m.is_equipped("ow_mortarboard"), "перо заменяет шапочку в слоте головы")
	m.unequip("head")
	check(not m.is_equipped("ow_quill") and m.outfit().is_empty(), "снять")
	m.shards = 30
	check(m.tap_item("ow_halfglasses") == "try" and not m.is_owned("ow_halfglasses") and m.shards == 30, "нажатие на некупленное — примерка, осколки целы")
	check(m.buy_item("ow_halfglasses", 0, 1) == "bought" and m.is_equipped("ow_halfglasses") and m.shards == 0, "купить и сразу надеть")
	check(m.tap_item("ow_halfglasses") == "off" and not m.is_equipped("ow_halfglasses"), "нажатие на надетое — снять")
	check(m.tap_item("ow_halfglasses") == "on", "нажатие на купленное — надеть")
	check(m.buy_item("ow_night_goggles", 0, 1) == "locked" and m.buy_item("ow_scholar_scarf", 0, 1) == "poor" and not m.is_owned("ow_scholar_scarf"), "покупка: закрыто / не хватает")
	check(m.tap_item("owl_lantern") == "locked", "украшение не надевается")
	check(m.tap_item("ax_starfish") == "locked" and not m.equip("ax_starfish"), "вещь другого друга не надевается")

	# Украшения дома
	m.shards = 100
	check(m.tap_decor("owl", "hang", "owl_lantern") == "try" and m.shards == 100 and not m.is_owned("owl_lantern") and m.placed_at("owl", "hang") == "", "украшение: нажатие — примерка, без покупки")
	check(m.buy_decor("owl", "hang", "owl_lantern", 0, 1) == "bought" and m.placed_at("owl", "hang") == "owl_lantern" and m.shards == 85, "украшение: купить и повесить")
	check(m.tap_decor("owl", "wall_l", "owl_lantern") == "on" and m.placed_at("owl", "wall_l") == "owl_lantern" and m.placed_at("owl", "hang") == "", "украшение переезжает на другое место")
	check(m.tap_decor("owl", "wall_l", "owl_lantern") == "off" and m.placed_at("owl", "wall_l") == "", "украшение: убрать")
	check(m.tap_decor("owl", "floor_l", "owl_swing") == "locked" and m.buy_decor("owl", "floor_l", "owl_swing", 0, 1) == "locked" and not m.is_owned("owl_swing"), "качели не ставятся на пол")
	check(m.tap_decor("axolotl", "floor_l", "owl_mushrooms") == "locked", "украшение совёнка не ставится в грот")
	check(not m.place("axolotl", "hang", "owl_lantern"), "купленное для дупла нельзя поставить в грот")
	check(m.tap_decor("axolotl", "floor_r", "axo_castle") == "try" and m.buy_decor("axolotl", "floor_r", "axo_castle", 99, 1) == "locked", "замок: примерить можно, купить — после 2-го зала")
	check(m.buy_decor("axolotl", "floor_r", "axo_anchor", 0, 1) == "bought" and m.placed_at("axolotl", "floor_r") == "axo_anchor", "украшение в гроте")
	m.place("owl", "near", "owl_lantern")
	check(m.placed_at("owl", "near") == "owl_lantern" and m.placed_at("axolotl", "near") == "", "у каждого дома свои места")
	check(m.decor_for("owl", "hang").size() >= 4 and m.decor_for("owl", "hang").all(func(d): return d.spots.has("hang")) and m.decor_for("axolotl", "floor_l").all(func(d): return d.spots.has("floor")), "наборы украшений по местам: только вещи для этого места")
	check(Meta.home_stage(1) == 0 and Meta.home_stage(11) == 1 and Meta.home_stage(41) == 2 and Meta.home_stage(71) == 3 and Meta.home_stage(151) == 3, "ступени богатства дома")
	check(Meta.hall_index(10) == 0 and Meta.hall_index(11) == 1 and Meta.hall_index(50) == 4 and Meta.hall_index(77) == 7 and Meta.hall_index(100) == 9 and Meta.hall_index(101) == 10 and Meta.depth(10) == 120, "залы и глубина")

	_test_tryon(g)

	# Сохранение и загрузка мета-данных
	var cfg := ConfigFile.new()
	m.save_to(cfg)
	var m2 = Meta.new()
	m2.load_from(cfg)
	check(m2.hero == "owl" and m2.shards == m.shards and m2.owned == m.owned and m2.equipped == m.equipped, "мета: сохранение и загрузка (герой, осколки, вещи)")
	check(m2.decor_owned == m.decor_owned and m2.placed_at("owl", "near") == "owl_lantern" and m2.placed_at("axolotl", "floor_r") == "axo_anchor", "мета: украшения по домам сохраняются")
	# Через игру и настоящий файл
	g.meta = m
	g.max_level = 7
	g.stars = {1: 3, 2: 2}
	g._save()
	g.meta = Meta.new()
	g._load()
	check(g.meta.hero == "owl" and g.meta.shards == m.shards and g.meta.is_equipped("ow_halfglasses") and g.max_level == 7, "игра: сохранение в save.cfg и загрузка")
	# Старое сохранение без раздела [meta]
	var old := ConfigFile.new()
	old.set_value("progress", "max_level", 12)
	old.set_value("progress", "stars", {1: 3})
	old.set_value("settings", "music", false)
	old.set_value("settings", "sfx", true)
	old.save("user://save.cfg")
	g.meta = Meta.new()
	g.meta.shards = 77
	g._load()
	check(g.max_level == 12 and g.meta.hero == "" and g.meta.shards == 30 + 3 * 5 and g.meta.owned.is_empty() and g.meta.equipped.is_empty(), "старое сохранение: прогресс есть, мета по умолчанию + подарок")
	check(g.meta.decor_owned.is_empty() and g.meta.decor_placed.owl.is_empty() and g.meta.decor_placed.axolotl.is_empty(), "старое сохранение: дома пустые")
	g.go_home()
	check(g.state == g.State.PICK_HERO, "без героя — экран «Выбери друга»")
	g.meta.set_hero("axolotl")
	g.go_home()
	check(g.state == g.State.HOME, "с героем — домой")
	# Испорченные значения не роняют загрузку
	var bad := ConfigFile.new()
	bad.set_value("meta", "hero", 5)
	bad.set_value("meta", "shards", "много")
	bad.set_value("meta", "owned", ["ow_mortarboard", "nope", 3])
	bad.set_value("meta", "equipped", {"head": "ow_quill", "eyes": "ow_mortarboard"})
	bad.set_value("meta", "decor_placed", {"owl": {"hang": "axo_lily"}})
	var m3 = Meta.new()
	m3.load_from(bad)
	check(m3.hero == "" and m3.owned.is_empty() and m3.equipped.is_empty() and m3.decor_placed.owl.is_empty(), "испорченные мета-данные отбрасываются")
	check(m3.shards == 20 and m3.migrated == 20, "вещь без своего героя возвращается осколками (20)")


# ---------- Примерка 0.7 (scripts/tryon.gd + экран гардероба) ----------

func _test_tryon(g) -> void:
	var Meta: Script = load("res://scripts/meta.gd")
	var keep_meta = g.meta
	var keep_stars: Dictionary = g.stars
	var keep_max: int = g.max_level
	var m = Meta.new()
	m.set_hero("axolotl")
	m.shards = 150
	m.owned = ["ax_starfish"]
	m.equip("ax_starfish")
	g.meta = m
	g.stars = {}
	g.max_level = 1
	if g.screens == null:  # в тесте _ready() ещё не вызывался
		g.screens = load("res://scripts/screens.gd").new(g)
	var sc = g.screens
	sc.open_wardrobe("head")
	# примерка некупленной вещи: ничего не тратится, герой показан в ней
	sc.tap_card("ax_coral_tiara", "axolotl")
	check(sc.tryon.id == "ax_coral_tiara" and m.shards == 150 and not m.is_owned("ax_coral_tiara") and m.owned == ["ax_starfish"], "примерка: осколки и покупки не меняются")
	check(sc.tryon.outfit(m).head == "ax_coral_tiara" and m.equipped.head == "ax_starfish", "примерка: на герое тиара вместо заколки, наряд не тронут")
	check(sc.tryon.status(m, 0, 1) == "ok", "примерка: хватает — можно купить")
	# отмена — прежний наряд
	check(sc.cancel_try() and not sc.tryon.active() and sc.tryon.outfit(m) == {"head": "ax_starfish"} and m.shards == 150, "отмена: снова заколка, осколки целы")
	check(not sc.cancel_try(), "нечего отменять — false")
	# «Назад» на телефоне сначала снимает примерку
	g._set_state(g.State.WARDROBE)
	sc.tap_card("ax_dive_mask", "axolotl")
	g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(g.state == g.State.WARDROBE and not sc.tryon.active() and not m.is_owned("ax_dive_mask"), "«Назад»: примерка снята, остаёмся в гардеробе")
	# повторное нажатие на примеряемую — снять примерку
	sc.tap_card("ax_dive_mask", "axolotl")
	sc.tap_card("ax_dive_mask", "axolotl")
	check(not sc.tryon.active(), "повторное нажатие снимает примерку")
	# другая вещь — переключение примерки
	sc.tap_card("ax_dive_mask", "axolotl")
	sc.tap_card("ax_coral_tiara", "axolotl")
	check(sc.tryon.id == "ax_coral_tiara" and sc.tryon.outfit(m).head == "ax_coral_tiara", "нажатие на другую вещь — примеряется она")
	# подтверждение — покупка и надеть
	sc._confirm_try()
	check(m.is_owned("ax_coral_tiara") and m.is_equipped("ax_coral_tiara") and m.shards == 30 and not sc.tryon.active(), "«Купить»: куплено и надето, −120")
	# купленное — без подтверждения
	sc.tap_card("ax_starfish", "axolotl")
	check(m.is_equipped("ax_starfish") and not sc.tryon.active() and m.shards == 30, "купленное надевается сразу")
	# закрытая залом и нехватка осколков
	sc.tap_card("ax_angler", "axolotl")
	check(sc.tryon.status(m, 0, 1) == "locked", "фонарик до 5-го зала: примерить можно, купить нельзя")
	sc.tap_card("ax_bubble_pet", "axolotl")
	check(sc.tryon.status(m, 0, 1) == "poor" and sc.tryon.shortage(m) == 40, "не хватает 40 осколков")
	sc._confirm_try()
	check(not m.is_owned("ax_bubble_pet") and m.shards == 30 and not m.equipped.has("companion") and sc.tryon.active(), "нехватка: покупки нет, примерка остаётся")
	check(sc.tryon.confirm(m, 999, 99) == "poor", "confirm при нехватке — poor")
	sc.cancel_try()
	m.shards = 40
	# украшения дома (0.15: в режиме украшения, scripts/decorate_ui.gd; дом героя — грот аксолотля)
	if g.decor_ui == null:
		g.decor_ui = load("res://scripts/decorate_ui.gd").new(g)
	var du = g.decor_ui
	du.open("hang")
	check(du.active and du.spot == "hang" and not du.tryon.active(), "режим украшения: место выбрано, примерки нет")
	du.tap_item("axo_lily")
	check(du.tryon.is_decor() and du.tryon.placed(m, "axolotl").get("hang", "") == "axo_lily" and m.placed_at("axolotl", "hang") == "" and m.shards == 40 and not m.is_owned("axo_lily"), "украшение: примерка на месте, без покупки")
	check(du.tryon.placed(m, "owl").get("hang", "") == "", "примерка не попадает в чужой дом")
	du.tryon.clear()
	check(du.tryon.placed(m, "axolotl").is_empty(), "украшение: отмена — место снова пустое")
	du.tap_item("axo_lily")
	du.confirm()
	check(m.is_owned("axo_lily") and m.placed_at("axolotl", "hang") == "axo_lily" and m.shards == 15 and not du.tryon.active(), "украшение: «Купить» — куплено и повешено")
	du.select("floor_l")
	du.tap_item("axo_chest")
	du.confirm()
	check(not m.is_owned("axo_chest") and m.placed_at("axolotl", "floor_l") == "" and m.shards == 15, "украшение закрыто звёздами — не покупается")
	du.tryon.clear()
	du.tap_item("axo_tree")
	check(du.tryon.status(m, 0, 1) == "poor" and du.tryon.shortage(m) == 20, "украшение: не хватает 20")
	du.confirm()
	check(not m.is_owned("axo_tree") and m.placed_at("axolotl", "floor_l") == "" and m.shards == 15, "украшение: нехватка — покупки нет")
	du.close()
	# склонение «не хватает N осколков»
	var keep_lang: String = I18n.lang
	I18n.set_lang("ru")
	check(I18n.t("poor_n") % [1, I18n.forms("shards_gen_forms", 1)] == "Не хватает 1 осколка" and I18n.forms("shards_gen_forms", 5) == "осколков" and I18n.forms("shards_gen_forms", 22) == "осколков", "русский: не хватает 1 осколка / 5 осколков")
	I18n.set_lang("en")
	check(I18n.t("poor_n") % [1, I18n.forms("shards_gen_forms", 1)] == "Need 1 more shard" and I18n.t("buy_for") % 60 == "Buy for 60", "английский: Need 1 more shard, Buy for 60")
	I18n.set_lang(keep_lang)
	g.meta = keep_meta
	g.stars = keep_stars
	g.max_level = keep_max


# ---------- Локализация (scripts/i18n.gd) ----------

func _test_i18n(g) -> void:
	var Meta: Script = load("res://scripts/meta.gd")
	var Screens: Script = load("res://scripts/screens.gd")
	# Автоопределение по языку телефона
	check(I18n.detect("ru") == "ru", "язык телефона ru -> русский")
	check(I18n.detect("en") == "en" and I18n.detect("de") == "en" and I18n.detect("") == "en", "другой язык телефона -> английский")
	# Все ключи есть в обоих языках, и %d/%s совпадают
	var miss: Array = I18n.missing_keys()
	check(miss.is_empty(), "все ключи переведены во всех языках (пропуски: %s)" % [miss])
	var fmt_ok := true
	for k in I18n.STR[I18n.DEFAULT]:
		for l in I18n.LANGS:
			var a: String = I18n.STR[I18n.DEFAULT][k]
			var b: String = I18n.STR[l].get(k, "")
			if a.count("%d") != b.count("%d") or a.count("%s") != b.count("%s"):
				fmt_ok = false
				printerr("    формат различается: ", l, ":", k)
	check(fmt_ok, "подстановки %d/%s одинаковые во всех языках")
	# У каждой вещи, украшения, зала, героя, вкладки, места есть название
	var need: Array = []
	for it in Meta.ITEMS + Meta.DECOR:
		need.append("item_" + it.id)
	for h in Meta.HALLS.size():
		need.append("hall_%d" % h)
	for h in Meta.HEROES:
		need.append_array(["hero_" + h, "house_" + h, "pick_lives_" + h])
	for sl in Meta.SLOTS:
		need.append("slot_" + sl)
	for sp in Meta.SPOTS:
		need.append("spot_" + sp)
	var names_ok := true
	for l in I18n.LANGS:
		for k in need:
			if not I18n.has_in(l, k):  # 0.15: названия новых украшений — в блоке STR_015
				names_ok = false
				printerr("    нет перевода: ", l, ":", k)
	check(names_ok, "названия всех вещей, украшений, залов, героев и мест переведены")
	# Переключение языка
	check(I18n.set_lang("en") and I18n.t("cascade") % 3 == "CASCADE ×3" and Meta.hall_name(10) == "Endless Depths", "английский: CASCADE ×3, Endless Depths")
	check(Meta.lock_reason("ow_quill", 999, 1) == "Clear hall: Fire Hall" and Meta.item_name("ow_stargazer") == "Stargazer's Mantle", "английский: причина замка и название вещи")
	check(Screens.shards_word(1) == "shard" and Screens.shards_word(5) == "shards", "английский: shard / shards")
	check(I18n.set_lang("ru") and I18n.t("cascade") % 3 == "КАСКАД ×3" and Meta.hall_name(0) == "Аметистовый зал", "русский: КАСКАД ×3, Аметистовый зал")
	check(Screens.shards_word(1) == "осколок" and Screens.shards_word(3) == "осколка" and Screens.shards_word(11) == "осколков" and Screens.shards_word(21) == "осколок", "русский: осколок / осколка / осколков")
	check(not I18n.set_lang("xx") and I18n.lang == "ru", "неизвестный язык не ставится")
	check(I18n.t("no_such_key") == "no_such_key", "нет ключа — показывается сам ключ, без падения")
	# Выбор сохраняется в save.cfg ([settings] language)
	g.set_language("en")
	var cfg := ConfigFile.new()
	cfg.load("user://save.cfg")
	check(cfg.get_value("settings", "language", "") == "en", "язык записан в save.cfg")
	I18n.lang = "ru"
	g._load()
	check(I18n.lang == "en", "язык из сохранения загружается")
	g.toggle_language()
	I18n.lang = "en"
	g._load()
	check(I18n.lang == "ru", "переключатель: en -> ru, сохраняется")
	# Кнопка языка в меню паузы
	g._layout()  # раскладка кнопок меню (в тесте _ready мог ещё не сработать)
	g.start_level(1)
	g._set_state(g.State.PAUSED)
	g._pause_menu_tap(g.menu_buttons["language"].get_center())
	check(I18n.lang == "en" and g.state == g.State.PAUSED, "кнопка «Язык» в паузе переключает язык")
	# Старое сохранение без поля language — по языку телефона
	var old := ConfigFile.new()
	old.set_value("progress", "max_level", 3)
	old.set_value("settings", "music", true)
	old.save("user://save.cfg")
	I18n.lang = "xx"
	g._load()
	check(I18n.lang == I18n.detect(OS.get_locale_language()), "старое сохранение без языка — по языку телефона (%s)" % I18n.lang)
	var bad := ConfigFile.new()
	bad.set_value("settings", "language", 42)
	I18n.load_from(bad, "ru")
	check(I18n.lang == "ru", "испорченное поле языка — автоопределение")


# ---------- Щенок и котик (0.9) ----------

## Украшения щенка и котика из 0.9 (в 0.15 к ним добавились новые — их проверяет tests/test_v015_pupkit.gd)
const OLD_DECOR_09 := {
	"puppy": ["pup_ball", "pup_bone", "pup_bowl", "pup_sign", "pup_flowerbed", "pup_pinwheel", "pup_lamp", "pup_bed", "pup_kite", "pup_teddy"],
	"kitten": ["kit_yarn", "kit_mouse", "kit_pillow", "kit_picture", "kit_catnip", "kit_box", "kit_scratcher", "kit_lamp", "kit_aquarium", "kit_tree"],
}

func _test_new_heroes(g) -> void:
	var Meta: Script = load("res://scripts/meta.gd")
	var HomeS: Script = load("res://scripts/home.gd")
	var HeroS: Script = load("res://scripts/hero.gd")
	check(Meta.HEROES == ["owl", "axolotl", "puppy", "kitten"], "четыре друга: совёнок, аксолотль, щенок, котик")
	var m = Meta.new()
	check(m.set_hero("puppy") and m.hero == "puppy" and m.set_hero("kitten") and m.hero == "kitten", "выбор щенка и котика")
	# Данные домов и окрасок
	for h in ["puppy", "kitten"]:
		# 0.15: в доме 30 украшений; здесь — прежние 10 (0.9), у них есть 2D-рисунок (home.gd DECOR_H)
		var items: Array = Meta.DECOR.filter(func(it): return it.home == h and OLD_DECOR_09[h].has(it.id))
		var prices_ok := items.all(func(it): return int(it.price) >= 10 and int(it.price) <= 60)
		var cond := items.filter(func(it): return it.has("stars") or it.has("hall")).size()
		check(items.size() == 10 and prices_ok and cond >= 1 and cond <= 2, "%s: 10 украшений, цены 10–60, 1–2 с условием" % h)
		var spots_ok := true
		for sp in Meta.SPOTS:
			var n: int = Meta.decor_for(h, sp).filter(func(it): return OLD_DECOR_09[h].has(it.id)).size()
			if n < 1 or n > 6 or not HomeS.SPOTS[h].has(sp):
				spots_ok = false
		check(spots_ok and HomeS.HERO_AT.has(h), "%s: на каждом из 6 мест есть что поставить (и не больше 6)" % h)
		var draw_ok := true
		for it in items:
			if not HomeS.DECOR_H.has(it.id):
				draw_ok = false
		check(draw_ok, "%s: у каждого украшения задана высота для рисования" % h)
		var pal: Dictionary = HeroS.PALETTES.get(h, {})
		check(pal.has("") and Meta.items_in("skin", h).all(func(it): return pal.has(Meta.draw_key(it.id))), "%s: своя палитра для каждой окраски" % h)
	# Свои названия окрасок (0.12b: у каждого друга свои окраски)
	var keep_lang: String = I18n.lang
	I18n.set_lang("en")
	check(Meta.item_name("pu_skin_dalmatian") == "Dalmatian" and Meta.item_name("ki_skin_siamese") == "Siamese", "окраски: далматинец у щенка, сиамская у котика")
	I18n.set_lang("ru")
	check(Meta.item_name("pu_skin_corgi") == "Корги" and Meta.item_name("ki_skin_tabby") == "Полосатик" and Meta.hero_name("puppy") == "Щенок" and Meta.hero_name("kitten") == "Котик", "русский: Щенок, Котик, Корги, Полосатик")
	I18n.set_lang(keep_lang)
	# 0.12b: вещи свои — при смене друга вещи прежнего снимаются и возвращаются осколками
	m.shards = 500
	m.set_hero("puppy")
	check(m.buy_item("pu_cap", 0, 1) == "bought" and m.buy_item("pu_skin_corgi", 0, 1) == "bought" and m.shards == 360, "щенок: купить бейсболку и окраску")
	m.set_hero("kitten")
	check(m.outfit().is_empty() and m.owned.is_empty() and m.shards == 500, "смена на котика: вещи щенка сняты, 140 осколков вернулись")
	# Украшения: у каждого дома свои
	check(m.tap_decor("puppy", "hang", "pup_kite") == "try" and m.buy_decor("puppy", "hang", "pup_kite", 0, 1) == "locked", "змей: примерить можно, купить — за 25 звёзд")
	check(m.buy_decor("puppy", "hang", "pup_lamp", 0, 1) == "bought" and m.placed_at("puppy", "hang") == "pup_lamp", "щенок: фонарь повешен")
	check(m.tap_decor("kitten", "floor_l", "pup_ball") == "locked" and not m.place("kitten", "floor_l", "pup_lamp"), "украшение щенка не ставится на чердак")
	check(m.tap_decor("puppy", "floor_l", "kit_box") == "locked", "коробка котика не ставится в сад")
	check(m.buy_decor("kitten", "floor_r", "kit_box", 0, 1) == "bought" and m.placed_at("kitten", "floor_r") == "kit_box" and m.placed_at("puppy", "floor_r") == "", "котик: коробка на полу, в саду пусто")
	check(m.tap_decor("kitten", "near", "kit_box") == "on" and m.placed_at("kitten", "near") == "kit_box" and m.placed_at("kitten", "floor_r") == "", "коробка переезжает поближе к котику")
	check(m.buy_decor("kitten", "floor_l", "kit_tree", 99, 11) == "locked" and m.buy_decor("kitten", "floor_l", "kit_tree", 0, 21) == "bought", "кошачий домик — после 2-го зала")
	check(m.tap_decor("puppy", "wall_l", "pup_bone") == "locked", "косточка не вешается на забор")
	# Сохранение и загрузка
	var cfg := ConfigFile.new()
	m.save_to(cfg)
	var m2 = Meta.new()
	m2.load_from(cfg)
	check(m2.hero == "kitten" and m2.placed_at("puppy", "hang") == "pup_lamp" and m2.placed_at("kitten", "near") == "kit_box" and m2.placed_at("kitten", "floor_l") == "kit_tree", "щенок и котик: герой и украшения домов сохраняются")
	m.set_hero("puppy")
	m.buy_item("pu_cap", 0, 1)
	m.save_to(cfg)
	m2.load_from(cfg)
	check(m2.hero == "puppy" and m2.is_equipped("pu_cap"), "сохранение: выбран щенок в бейсболке")
	# Старое сохранение 0.8: в decor_placed только совёнок и аксолотль
	var old := ConfigFile.new()
	old.set_value("meta", "hero", "owl")
	old.set_value("meta", "decor_owned", ["owl_lantern"])
	old.set_value("meta", "decor_placed", {"owl": {"hang": "owl_lantern"}, "axolotl": {}})
	var m3 = Meta.new()
	m3.load_from(old)
	check(m3.placed_at("owl", "hang") == "owl_lantern" and m3.decor_placed.puppy.is_empty() and m3.decor_placed.kitten.is_empty(), "старое сохранение: дома щенка и котика пустые")
	var m4 = Meta.new()
	check(m4.decor_placed.has("puppy") and m4.decor_placed.has("kitten"), "новая игра: места для домов щенка и котика")
	# Экран выбора: на каждого друга — своя карточка, нажатие выбирает
	if g.screens == null:
		g.screens = load("res://scripts/screens.gd").new(g)
	var keep_meta = g.meta
	g.meta = Meta.new()
	g.screens.rects.clear()
	for i in Meta.HEROES.size():
		g.screens.rects["hero_" + Meta.HEROES[i]] = Rect2(24 + (i % 2) * 344, 236 + (i / 2) * 318, 328, 304)
	g.screens.tap_pick(Vector2(24 + 344 + 100, 236 + 318 + 100))
	check(g.screens.pick_choice == "kitten", "«Выбери друга»: нажатие на карточку котика")
	g.screens.tap_pick(Vector2(124, 236 + 318 + 100))
	check(g.screens.pick_choice == "puppy", "«Выбери друга»: нажатие на карточку щенка")
	g.meta = keep_meta
