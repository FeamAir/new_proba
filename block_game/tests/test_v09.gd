extends SceneTree
## Тесты версии 0.9: обучение, помощь на трудном уровне, цель «до следующей вещи»,
## подарок новичку, счётчик попыток и CSV, старые сохранения.
## Запуск: godot --headless --path block_game -s tests/test_v09.gd

var failed := 0
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const Assist := preload("res://scripts/assist.gd")
const Tutorial := preload("res://scripts/tutorial.gd")
const AssistUI := preload("res://scripts/assist_ui.gd")
const SAVE := "user://save.cfg"


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)


func run(g, sec: float) -> void:
	var t := 0.0
	while t < sec:
		g.step(0.02)
		g.tut.update(0.02)
		t += 0.02


func stone_rows(g) -> int:
	var n := 0
	for y in range(g.ROWS - 1, -1, -1):
		var k := 0
		for x in g.COLS:
			if g.board[y * g.COLS + x] != g.EMPTY:
				k += 1
		if k < g.COLS - 3:
			break
		n += 1
	return n


func fresh(g) -> void:
	g.meta = Meta.new()
	g.meta.set_hero("owl")
	g.stars = {}
	g.max_level = 1
	g.tut = Tutorial.new()
	g.assist = Assist.new()


func _initialize() -> void:
	var had_save := FileAccess.file_exists(SAVE)
	var save_bytes := FileAccess.get_file_as_bytes(SAVE) if had_save else PackedByteArray()
	if had_save:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var g: Node2D = load("res://scripts/game.gd").new()
	root.add_child(g)
	g._layout()
	if g.screens == null:  # в тесте _ready() ещё не вызывался
		g.screens = load("res://scripts/screens.gd").new(g)
		g.assist_ui = AssistUI.new(g)
	I18n.set_lang("en")

	_test_tutorial(g)
	_test_assist(g)
	_test_goal_gift(g)
	_test_stats(g)
	_test_saves(g)

	if had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	g.free()
	quit(1 if failed else 0)


# ---------- Обучение ----------

func _test_tutorial(g) -> void:
	fresh(g)
	g.start_level(1)
	check(g.tut.cur == "l1_move", "уровень 1: первый шаг «Двигай фигуру»")
	check(g.piece_type == Tutorial.FIRST_PIECE, "в обучении первая фигура — палочка")
	var y0: int = g.piece_pos.y
	run(g, 3.0)
	check(g.piece_pos.y == y0 and g.state == g.State.PLAYING, "пока шаг на экране, фигура не падает")
	g.rotate_piece()
	check(g.tut.cur == "l1_move", "шаг «Двигай» не закрывается поворотом")
	g.rotate_piece()  # обратно горизонтально (4 поворота = исходная, у палочки 2 — тоже)
	g.rotate_piece()
	g.rotate_piece()
	check(g.move(1) and g.tut.cur == "l1_rotate", "сдвиг закрывает шаг, дальше «Поверни»")
	check(g.tut.on_tap(g, Vector2(100, 100)) == false and g.tut.cur == "l1_rotate", "шаг-действие касанием не закрывается")
	g.rotate_piece()
	check(g.tut.cur == "l1_drop", "поворот закрывает шаг, дальше «Брось в колодец»")
	var w: Vector2i = Tutorial.well(g)
	check(w.x >= 0, "колодец уровня 1 найден (колонка %d)" % w.x)
	var guard := 0
	while guard < 12:
		var minx := 99
		for c in g.piece_cells:
			minx = mini(minx, c.x + g.piece_pos.x)
		if minx == w.x or not g.move(1 if w.x > minx else -1):
			break
		guard += 1
	g.hard_drop()
	check(g.tut.seen.has("l1_drop") and g.tut.cur == "", "фигура брошена — шаг «Брось» закрыт")
	run(g, 1.0)
	check(g.tut.cur == "l1_cascade", "каскад — шаг «Смотри — КАСКАД!»")
	check(g.tut.holds_fall() and g.tut.is_info(), "шаг-пояснение держит падение")
	check(g.state == g.State.CLEARING, "пока пояснение на экране, каскад «замер»")
	check(g.tut.on_tap(g, Vector2(360, 600)) and g.tut.seen.has("l1_cascade"), "касание закрывает пояснение")
	check(g.tut.cur == "l1_crystals", "дальше «Освободи все кристаллы»")
	g.tut.t = 1.0
	g._touch_down(0, Vector2(360, 600))
	check(g.tut.cur == "" and g.tut.seen.has("l1_crystals"), "шаги уровня 1 пройдены")
	run(g, 2.0)
	check(g.state == g.State.WIN, "каскад первой фигуры обучения проходит уровень 1")
	# флаг в save.cfg; второй раз обучение не показывается
	var cfg := ConfigFile.new()
	check(cfg.load(SAVE) == OK and Array(cfg.get_value("tutorial", "seen", [])).has("l1_move"), "показанные шаги записаны в save.cfg [tutorial]")
	g.tut = Tutorial.new()
	g._load()
	g.start_level(1)
	check(g.tut.cur == "" and g.tut.seen.has("l1_drop"), "после загрузки обучение уровня 1 не повторяется")
	run(g, 2.0)
	check(g.piece_pos.y > 0, "без обучения фигура падает как обычно")
	# Повтор из паузы
	g.start_level(4)
	g._set_state(g.State.PAUSED)
	g._pause_menu_tap(g.menu_buttons["tutorial"].get_center())
	check(g.level == 1 and g.state == g.State.PLAYING and g.tut.cur == "l1_move", "пауза → «Обучение»: уровень 1 с первого шага")
	check(I18n.t("pause_tutorial") == "Tutorial", "пункт паузы «Tutorial»")
	# Уровни 2 и 3: по одному пояснению, закрывается касанием или действием
	g.start_level(2)
	check(g.tut.cur == "l2_crumble", "уровень 2: «Ставь фигуры так, чтобы камень осыпался»")
	check(g.tut.on_tap(g, Vector2(10, 10)) and g.tut.cur == "l2_crumble", "касание в первые доли секунды не закрывает (случайное)")
	g.tut.t = 1.0
	g._touch_down(0, Vector2(360, 500))
	check(g.tut.cur == "" and g.tut.seen.has("l2_crumble"), "касание по полю закрывает пояснение")
	g.start_level(3)
	check(g.tut.cur == "l3_chain", "уровень 3: «Чем длиннее цепочка — тем больше осколков»")
	g.move(-1)
	check(g.tut.cur == "", "действие игрока закрывает пояснение")
	g.start_level(3)
	check(g.tut.cur == "", "уровень 3 второй раз — без пояснения")
	g.start_level(4)
	check(g.tut.cur == "", "на уровне 4 обучения нет")
	# Гардероб: одна подсказка
	check(g.tut.wardrobe_hint(), "гардероб: подсказка при первом заходе")
	g.screens.open_wardrobe("head")
	g._touch_down(0, Vector2(360, 1200))
	check(not g.tut.wardrobe_hint(), "касание в гардеробе убирает подсказку навсегда")
	# Выключенное обучение (робот-тестер)
	var t2 := Tutorial.new()
	t2.enabled = false
	check(not t2.wants_first_piece(1) and not t2.wardrobe_hint(), "выключенное обучение ничего не показывает")


# ---------- Помощь на трудном уровне ----------

func _test_assist(g) -> void:
	fresh(g)
	g.tut.enabled = false
	g.start_level(4)
	var rows0 := stone_rows(g)
	g._lose()
	check(g.assist.offer_rows(4) == 0 and not g.assist_ui.offers(4), "1 проигрыш — помощи ещё нет")
	g.start_level(4)
	g._lose()
	check(g.assist.offer_rows(4) == 1 and g.assist_ui.offers(4), "2 проигрыша подряд — предложение «Подсказка кристалла» (1 ряд)")
	check(g.assist.offer_rows(5) == 0, "на другом уровне помощи нет")
	# Отказ: «Нет, спасибо» — обычная попытка
	g.state_time = 1.0
	g.assist_ui.rects = {"retry": Rect2(0, 0, 50, 50), "boost": Rect2(100, 0, 50, 50)}
	g._touch_down(0, Vector2(10, 10))
	check(g.state == g.State.PLAYING and stone_rows(g) == rows0 and g.assist.levels[4].help == 0, "отказ: камень на месте, помощь не засчитана")
	g._lose()
	check(g.assist.offer_rows(4) == 2, "3 проигрыша подряд — убираются 2 ряда")
	# Согласие
	g.state_time = 1.0
	g.assist_ui.rects = {"retry": Rect2(0, 0, 50, 50), "boost": Rect2(100, 0, 50, 50)}
	g._touch_down(0, Vector2(110, 10))
	check(g.state == g.State.PLAYING and stone_rows(g) == rows0 - 2, "помощь: 2 нижних ряда камня убраны (%d → %d)" % [rows0, stone_rows(g)])
	check(g.crystals_left >= 1 and g.crystals_left <= g.crystals_total, "кристаллы из убранных рядов засчитаны освобождёнными")
	check(g.assist.levels[4].help == 1 and g.assist.boost_level == 0, "помощь засчитана и израсходована")
	g.start_level(4)
	check(stone_rows(g) == rows0, "следующая попытка — снова без помощи")
	# 1 ряд
	var a := Assist.new()
	a.streak[7] = 2
	check(a.accept(7) and a.on_start(7) == 1 and a.on_start(7) == 0, "помощь на 1 ряд, один раз")
	check(not a.accept(8), "без проигрышей помощь не принимается")
	# Победа с помощью: звёзды как обычно, счётчик сбрасывается
	g.assist.streak[4] = 2
	g.assist.accept(4)
	g.start_level(4)
	g.pieces_used = 1
	g._win()
	check(g.last_stars == 3, "с помощью звёзды даются как обычно")
	check(g.assist.offer_rows(4) == 0 and not g.assist.streak.has(4), "победа сбрасывает проигрыши подряд")
	# Убрать все кристаллы нельзя: один возвращается
	var b: Array = []
	b.resize(16)
	b.fill(-1)
	for x in 4:
		b[3 * 4 + x] = 8 if x < 2 else 7  # нижний ряд: 2 кристалла
		b[2 * 4 + x] = 7
	var res := Assist.apply_boost(b, 4, 4, -1, 8, 1, 2)
	check(res.rows == 1 and res.freed == 1 and b.count(8) == 1, "все кристаллы в убранном ряду — один остаётся на поле")
	var b2: Array = []
	b2.resize(16)
	b2.fill(-1)
	for x in 4:
		b2[3 * 4 + x] = 7
	check(Assist.apply_boost(b2, 4, 4, -1, 8, 2, 1).rows == 0, "последний ряд камня не убирается")


# ---------- Цель и подарок новичку ----------

func _test_goal_gift(g) -> void:
	fresh(g)
	var m = Meta.new()
	var gl := Assist.next_goal(m, "owl", 0, 1)
	check(gl.id == "owl_nest" and gl.price == 10 and gl.need == 10 and not gl.ready, "цель: самая дешёвая вещь (коврик-гнездо 10)")
	m.decor_owned.append("owl_nest")
	m.shards = 15
	gl = Assist.next_goal(m, "owl", 0, 1)
	check(gl.id == "owl_lantern" and gl.ready and gl.need == 0, "цель: следующая, хватает — «Можно купить»")
	check(Assist.next_goal(m, "axolotl", 0, 1).id == "axo_starfish", "украшения — только своего дома")
	m.shards = 0
	for it in Meta.ITEMS + Meta.DECOR:
		if it.price <= 30 and not m.is_owned(it.id):
			if it.has("home"):
				m.decor_owned.append(it.id)
			else:
				m.owned.append(it.id)
	gl = Assist.next_goal(m, "owl", 0, 1)
	check(gl.price > 30 and Meta.lock_reason(gl.id, 0, 1) == "", "закрытые вещи в цель не попадают (%s %d)" % [gl.id, gl.price])
	I18n.set_lang("ru")
	check(I18n.t("goal_next") % [5, I18n.forms("shards_forms", 5)] == "До следующей вещи: 5 осколков", "текст цели по-русски")
	I18n.set_lang("en")
	# Подарок новичку: первая победа даже на 1 звезду — хватает на бантик (20)
	g.start_level(1)
	g.pieces_used = 99
	g._win()
	check(g.last_reward.get("gift", 0) == Assist.NEWBIE_GIFT and g.meta.shards == 10 + 5 + 10, "подарок новичку +10 за первую победу (осколков %d)" % g.meta.shards)
	check(g.meta.shards >= Meta.item("bow").price, "после уровня 1 хватает на бантик")
	var before: int = g.meta.shards
	g.start_level(2)
	g.pieces_used = 99
	g._win()
	check(g.last_reward.get("gift", 0) == 0 and g.meta.shards == before + 15, "подарок только один раз")
	var a := Assist.new()
	check(a.take_gift(12) == 0 and a.gift_given, "у игрока с прогрессом подарка нет")


# ---------- Счётчик попыток и CSV ----------

func _test_stats(g) -> void:
	fresh(g)
	g.tut.enabled = false
	for i in 3:
		g.start_level(5)
	g._lose()
	g.start_level(5)
	g._lose()
	g.start_level(5)
	g.pieces_used = 14
	g._win()
	g.start_level(5)
	g.pieces_used = 9
	g._win()
	g.start_level(6)
	var r: Dictionary = g.assist.levels[5]
	check(r.tries == 6 and r.losses == 2 and r.wins == 2 and r.best == 9 and r.help == 0, "попытки уровня 5: 6 / 2 / 2, лучшее 9 фигур")
	check(g.assist.levels[6].tries == 1 and g.assist.levels[6].wins == 0, "уровень 6: попытка без итога")
	var csv: String = g.assist.csv()
	var lines := csv.strip_edges().split("\n")
	check(lines[0] == "level,attempts,losses,wins,best_pieces,assists" and lines[1] == "5,6,2,2,9,0" and lines[2] == "6,1,0,0,0,0", "CSV: заголовок и строки по уровням")
	# Скрытый экран: 5 касаний по номеру версии в паузе
	check(AssistUI.version() == str(ProjectSettings.get_setting("application/config/version")) and AssistUI.version() != "", "версия из настроек проекта: " + AssistUI.version())
	g._set_state(g.State.PAUSED)
	var vr: Vector2 = g.assist_ui.version_rect().get_center()
	for i in 4:
		g._touch_down(0, vr)
	check(not g.assist_ui.stats_open, "4 касания — экран не открыт")
	g._touch_down(0, vr)
	check(g.assist_ui.stats_open and g.state == g.State.PAUSED, "5 касаний по версии — экран статистики")
	g.assist_ui.rects = {"st_copy": Rect2(0, 0, 50, 50), "st_close": Rect2(100, 0, 50, 50)}
	g._touch_down(0, Vector2(10, 10))
	check(g.assist_ui.copied_t > 0.0, "кнопка «Скопировать» (CSV в буфер обмена)")
	g._touch_down(0, Vector2(110, 10))
	check(not g.assist_ui.stats_open, "«Закрыть» — обратно в паузу")
	g.assist.track = false
	g.start_level(5)
	check(g.assist.levels[5].tries == 6, "робот-тестер попытки не считает")
	g.assist.track = true


# ---------- Сохранения ----------

func _test_saves(g) -> void:
	fresh(g)
	g.assist.levels = {3: {"tries": 4, "losses": 2, "wins": 1, "best": 7, "help": 1}}
	g.assist.streak = {3: 1}
	g.assist.gift_given = true
	g.tut.seen = {"l1_move": true, "wardrobe": true}
	g.max_level = 4
	g.stars = {1: 3}
	g.meta.shards = 42
	g._save()
	var cfg := ConfigFile.new()
	check(cfg.load(SAVE) == OK and cfg.has_section("progress") and cfg.has_section("meta") and cfg.has_section("stats") and cfg.has_section("tutorial"), "save.cfg читается, все разделы на месте")
	fresh(g)
	g._load()
	check(g.max_level == 4 and g.meta.shards == 42 and g.assist.levels[3].best == 7 and g.assist.streak[3] == 1 and g.assist.gift_given, "статистика и помощь сохраняются и загружаются")
	check(g.tut.seen.has("l1_move") and not g.tut.seen.has("l1_rotate") and g.tut.seen.has("wardrobe"), "шаги обучения сохраняются")
	# Старое сохранение 0.8 (без [stats] и [tutorial])
	var old := ConfigFile.new()
	old.set_value("progress", "max_level", 9)
	old.set_value("progress", "stars", {1: 3, 2: 2})
	old.set_value("meta", "hero", "owl")
	old.set_value("meta", "shards", 33)
	old.save(SAVE)
	fresh(g)
	g._load()
	check(g.max_level == 9 and g.meta.shards == 33 and g.assist.levels.is_empty() and g.assist.streak.is_empty(), "старое сохранение: прогресс цел, счётчики пустые")
	check(g.assist.gift_given and g.tut.seen.has("l3_chain") and g.tut.seen.has("wardrobe"), "старый игрок: без подарка новичку и без обучения")
	g._save()
	cfg = ConfigFile.new()
	check(cfg.load(SAVE) == OK and cfg.get_value("progress", "max_level", 0) == 9 and cfg.get_value("meta", "shards", 0) == 33, "после пересохранения старые поля целы")
	# Совсем новый игрок (нет файла)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	fresh(g)
	g.tut.seen = {"x": true}
	g._load()
	check(g.tut.seen.is_empty() and not g.assist.gift_given, "новый игрок: обучение и подарок впереди")
	# Испорченные значения
	var bad := ConfigFile.new()
	bad.set_value("stats", "levels", {"a": 1, 2: "x", 3: {"tries": "много", "wins": 2}})
	bad.set_value("stats", "streak", [1, 2])
	bad.set_value("stats", "gift", "да")
	bad.set_value("tutorial", "seen", ["l1_move", 5, "nope"])
	var a := Assist.new()
	a.load_from(bad)
	check(a.levels.size() == 1 and a.levels[3].tries == 0 and a.levels[3].wins == 2 and a.streak.is_empty() and not a.gift_given, "испорченная статистика отбрасывается")
	var t := Tutorial.new()
	t.load_from(bad, 1)
	check(t.seen.size() == 1 and t.seen.has("l1_move"), "испорченный список обучения отбрасывается")
	# Полнота переводов
	check(I18n.missing_keys().is_empty(), "все ключи 0.9 переведены (en/ru)")
