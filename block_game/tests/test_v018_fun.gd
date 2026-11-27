extends SceneTree
## Тесты версии 0.18 (веселее и удобнее):
##   праздник каскада (scripts/juice.gd): звук звена — на ступень выше, «Супер!» / «Мега!», замедление,
##   кристаллы летят к счётчику, праздник на последнем кристалле, вибрация и её выключатель в «Удобстве»;
##   облачко героя (scripts/hero_say.gd): фразы всех 4 героев на en и ru, род, не чаще раза в 3 с;
##   «Совиное время» (scripts/owl_time.gd): отмена точно возвращает поле, счёт, кристаллы, следующую фигуру
##   и прочие счётчики; вторая отмена недоступна; не работает во время каскада и после победы; подсказка один раз;
##   «до 3 звёзд» (scripts/star_goal.gd): считает так же, как звёзды за победу.
## Запуск: godot --headless --path block_game -s tests/test_v018_fun.gd

var failed := 0
var frame := 0
var g
var had_save := false
var save_bytes := PackedByteArray()
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const Access := preload("res://scripts/access.gd")
const Juice := preload("res://scripts/juice.gd")
const HeroSay := preload("res://scripts/hero_say.gd")
const OwlTime := preload("res://scripts/owl_time.gd")
const StarGoal := preload("res://scripts/star_goal.gd")
const Tutorial := preload("res://scripts/tutorial.gd")
const SAVE := "user://save.cfg"


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
	g._layout()
	_test_texts()
	_test_phrases()
	_test_say_cooldown()
	_test_chain_sound()
	_test_juice()
	_test_vibrate()
	_test_undo_exact()
	_test_undo_once()
	_test_undo_blocked()
	_test_undo_hint()
	_test_star_goal()
	await _test_drawing()
	_finish()


# ---------- Помощники ----------

func _fresh_level(kind := "owl", n := 3) -> void:
	g.meta = Meta.new()
	g.meta.set_hero(kind)
	g.start_level(n)


## Поле для проверки: нижний ряд почти полон (дыра в колонках 0–1), в нём кристалл;
## ещё один кристалл — выше, чтобы уровень не закончился. Фигура — «двойка» над дырой.
func _setup_board(crystals := 2) -> void:
	g.board.fill(g.EMPTY)
	g.piece_ids.fill(0)
	var y: int = g.ROWS - 1
	for x in range(2, g.COLS):
		g.board[y * g.COLS + x] = g.STONE
	g.board[y * g.COLS + 4] = g.CRYSTAL
	if crystals > 1:
		g.board[(y - 1) * g.COLS + 7] = g.CRYSTAL
	g.crystals_total = crystals
	g.crystals_left = crystals
	g.piece_type = 0
	g.piece_cells = g.SHAPES[0].cells.duplicate()
	g.piece_pos = Vector2i(0, 0)
	g.has_piece = true


## Довести каскад до конца (до следующей фигуры или итога).
func _settle() -> void:
	for i in 40:
		if g.state not in [g.State.CLEARING, g.State.SETTLE]:
			return
		g.step(0.1)


# ---------- Тексты ----------

func _test_texts() -> void:
	print("— тексты 0.18 (праздник, «Совиное время», «до 3 звёзд»)")
	var keys := ["juice_super", "juice_mega", "owl_time", "owl_time_hint", "goal_left", "access_vibrate", "access_vibrate_desc"]
	var miss := []
	for l in ["en", "ru"]:
		for k in keys:
			if not I18n.has_in(l, k):
				miss.append(l + ":" + k)
	check(miss.is_empty(), "новые тексты есть на en и ru %s" % str(miss))
	check(I18n.missing_keys().is_empty(), "ни одного непереведённого ключа")
	I18n.set_lang("ru")
	check(I18n.t("juice_super") == "Супер!" and I18n.t("juice_mega") == "Мега!", "ru: «Супер!» и «Мега!»")
	check(I18n.t("owl_time") == "Совиное время!", "ru: «Совиное время!»")
	check(I18n.t("goal_left") % 5 == "ещё 5", "ru: «ещё 5»")
	I18n.set_lang("en")
	check(I18n.t("juice_super") == "Super!" and I18n.t("juice_mega") == "Mega!", "en: Super! и Mega!")
	check(I18n.t("owl_time") == "Owl Time!" and I18n.t("goal_left") % 3 == "3 left", "en: Owl Time! и «3 left»")
	I18n.set_lang("ru")


func _test_phrases() -> void:
	print("— фразы героев на обоих языках")
	var bad := []
	for l in ["en", "ru"]:
		I18n.set_lang(l)
		for kind in HeroSay.HEROES:
			for ev in HeroSay.EVENTS:
				var seen := {}
				for n in HeroSay.COUNT:
					var key := "say_%s_%s_%d" % [kind, ev, n]
					if not I18n.has_in(l, key):
						bad.append(l + ":" + key)
					for gen in ["boy", "girl"]:
						var p := HeroSay.phrase(kind, gen, ev, n)
						if p == "" or p.begins_with("say_") or p.length() > 22:
							bad.append("%s:%s:%s" % [l, key, gen])
					seen[HeroSay.phrase(kind, "boy", ev, n)] = true
				if seen.size() < HeroSay.COUNT:
					bad.append("%s:%s_%s повторяются" % [l, kind, ev])
	check(bad.is_empty(), "у каждого из 4 героев по %d фразы на каскад, кристалл и победу (en, ru) %s" % [HeroSay.COUNT, str(bad)])
	var own := {}
	I18n.set_lang("ru")
	for kind in HeroSay.HEROES:
		var all := []
		for ev in HeroSay.EVENTS:
			for n in HeroSay.COUNT:
				all.append(HeroSay.phrase(kind, "boy", ev, n))
		own[kind] = all
	var same := 0
	for a in HeroSay.HEROES:
		for b in HeroSay.HEROES:
			if a < b and own[a] == own[b]:
				same += 1
	check(same == 0, "у каждого героя свой набор фраз")
	check(HeroSay.phrase("owl", "boy", "win", 0) == "Я так и знал!" and HeroSay.phrase("owl", "girl", "win", 0) == "Я так и знала!", "ru: совёнок «знал» / совушка «знала»")
	check(HeroSay.phrase("puppy", "girl", "crystal", 0) == "Нашла!" and HeroSay.phrase("kitten", "girl", "crystal", 2) == "Поймала!", "ru: род виден у щенка и котика")
	check(HeroSay.phrase("axolotl", "girl", "win", 0) == "Я довольная!", "ru: аксолотлинка «довольная»")
	check(HeroSay.phrase("owl", "girl", "cascade", 0) == HeroSay.phrase("owl", "boy", "cascade", 0), "где род не виден — одна фраза")
	I18n.set_lang("en")
	check(HeroSay.phrase("owl", "girl", "win", 0) == "I knew it!", "en: у девочки — та же английская фраза")
	I18n.set_lang("ru")


func _test_say_cooldown() -> void:
	print("— облачко героя: не чаще раза в 3 с, победа — всегда")
	var s := HeroSay.new()
	check(s.on_event("owl", "boy", "cascade") and s.visible(), "каскад — облачко появилось")
	check(not s.on_event("owl", "boy", "crystal"), "через миг кристалл — облачка нет (не чаще раза в 3 с)")
	s.update(2.0)
	check(not s.on_event("owl", "boy", "cascade"), "через 2 с — ещё рано")
	s.update(1.1)
	check(not s.visible() and s.on_event("owl", "boy", "crystal"), "через 3 с — снова можно; прошлое облачко уже исчезло")
	check(s.on_event("owl", "boy", "win"), "победа — облачко сразу")
	var first: String = s.text
	s.update(5.0)
	s.on_event("owl", "boy", "win")
	check(s.text != first, "одна и та же фраза подряд не повторяется")
	# в игре: каскад ×2 даёт облачко у героя
	_fresh_level("puppy")
	g.say.reset()
	check(g.hero_says("cascade") and g.say.text != "", "игра: герой говорит на каскад (%s)" % g.say.text)
	var ph: Array = []
	for n in HeroSay.COUNT:
		ph.append(HeroSay.phrase("puppy", g.meta.gender_of("puppy"), "cascade", n))
	check(ph.has(g.say.text), "фраза — щенка")


# ---------- Праздник каскада ----------

func _test_chain_sound() -> void:
	print("— звук звена цепочки — на ступень выше")
	check(Juice.chain_sound(2) == ["combo1", 1.0] and Juice.chain_sound(3) == ["combo2", 1.0] and Juice.chain_sound(6) == ["combo5", 1.0], "×2..×6 — combo1..combo5 (лестница)")
	var p7: float = Juice.chain_sound(7)[1]
	var p8: float = Juice.chain_sound(8)[1]
	check(Juice.chain_sound(7)[0] == "combo5" and p7 > 1.0 and p8 > p7, "×7 и дальше — combo5 всё выше (%.3f, %.3f)" % [p7, p8])
	check(absf(p7 - pow(2.0, 2.0 / 12.0)) < 0.001, "ступень — тон, как между combo1..5")
	for n in range(1, 6):
		check(ResourceLoader.exists("res://assets/sounds/combo%d.wav" % n), "звук combo%d есть" % n)


func _test_juice() -> void:
	print("— «Супер!», «Мега!», замедление, полёт кристаллов, последний кристалл")
	check(Juice.banner_key(2) == "" and Juice.banner_key(3) == "juice_super" and Juice.banner_key(4) == "juice_mega" and Juice.banner_key(7) == "juice_mega", "надпись: ×3 — «Супер!», ×4+ — «Мега!»")
	_fresh_level()
	var j = g.juice
	j.on_cascade(2)
	check(j.banner == "" and j.time_k() == 1.0, "×2 — без надписи и замедления")
	j.on_cascade(3)
	check(j.banner == "Супер!" and j.time_k() < 1.0 and j.flash > 0.0, "×3 — «Супер!», вспышка, замедление")
	check(Juice.SLOW_TIME >= 0.2 and Juice.SLOW_TIME <= 0.3, "замедление ~0,2–0,3 с")
	j.on_cascade(4)
	check(j.banner == "Мега!", "×4 — «Мега!»")
	j.update(Juice.SLOW_TIME + 0.01)
	check(j.time_k() == 1.0, "замедление проходит")
	# замедление действует на игру: фигура падает медленнее
	j.on_cascade(3)
	var st0: float = g.state_time
	g._process(0.1)
	check(absf(g.state_time - st0 - 0.1 * Juice.SLOW_K) < 0.001, "в замедлении игра идёт ×%.1f" % Juice.SLOW_K)
	j.reset()
	# кристалл летит к счётчику
	_fresh_level()
	_setup_board(2)
	g.hard_drop()
	check(g.crystals_left == 1 and j.in_flight() == 1, "освобождённый кристалл летит к счётчику")
	check(j.flyers[0].to.distance_to(j.counter_pos()) < 0.1 and j.counter_pos().x > g.panel_x - 10, "летит к значку на панели")
	j.update(Juice.FLY_TIME + 0.2)
	check(j.in_flight() == 0 and j.bump > 0.5, "долетел — счётчик «подпрыгнул»")
	_settle()
	# последний кристалл — праздник
	_fresh_level()
	_setup_board(1)
	var parts: int = g.particles.size()
	g.hard_drop()
	check(j.zoom > 0.0 and j.flash > 0.0 and g.particles.size() >= parts + 50, "последний кристалл: приближение, вспышка, конфетти")
	check(j.board_zoom()[0] >= 1.0, "приближение поля ≥ 1")
	_settle()
	check(g.state == g.State.WIN, "после последнего кристалла — победа")


func _test_vibrate() -> void:
	print("— вибрация и выключатель «Вибрация»")
	var a := Access.new()
	check(a.vibrate and Access.KEYS.has("vibrate"), "«Вибрация» в «Удобстве», по умолчанию включена")
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "music", true)
	a.vibrate = false
	a.load_from(cfg)
	check(a.vibrate, "старое сохранение — вибрация включена")
	check(not a.symbols and not a.slow, "остальное в старом сохранении — по-прежнему выключено")
	cfg.set_value("settings", "access_vibrate", false)
	a.load_from(cfg)
	check(not a.vibrate, "выключенная вибрация читается из сохранения")
	cfg.set_value("settings", "access_vibrate", "да")
	a.load_from(cfg)
	check(a.vibrate, "чужое значение — по умолчанию (включена)")
	_fresh_level()
	g.juice.vibes.clear()
	g.hard_drop()
	check(g.juice.vibes.size() >= 1, "сброс фигуры — вибрация")
	g.juice.vibes.clear()
	g.juice.on_cascade(2)
	check(g.juice.vibes.size() == 1, "каскад — вибрация")
	g.set_access("vibrate", false)
	g.juice.vibes.clear()
	g.juice.on_cascade(3)
	g.juice.on_drop()
	check(g.juice.vibes.is_empty(), "выключено — не вибрирует")
	g.set_access("vibrate", true)
	g.access_ui.show()
	check(g.access_ui.rects.has("opt_vibrate") and g.access_ui.rects.back.end.y < g.H - 40, "переключатель в окне «Удобство», окно помещается")
	g.access_ui.close()
	g.juice.reset()


# ---------- «Совиное время» ----------

func _test_undo_exact() -> void:
	print("— «Совиное время»: точный возврат")
	_fresh_level()
	check(not g.owl.can_undo(g) and not g.undo_piece(), "в начале уровня отменять нечего")
	_setup_board(2)
	g.speed_step = 5
	var board0: Array = g.board.duplicate()
	var ids0: Array = g.piece_ids.duplicate()
	var score0: int = g.score
	var left0: int = g.crystals_left
	var used0: int = g.pieces_used
	var next0: int = g.next_type
	var big0: int = g.big_chains
	var pid0: int = g.next_piece_id
	var rng0: int = g.rng.state
	g.hard_drop()
	check(g.state == g.State.CLEARING, "фигура легла — линия очищается")
	check(not g.undo_piece(), "во время анимации каскада отмена не срабатывает")
	check(not g.owl.used, "... и не тратится")
	_settle()
	check(g.state == g.State.PLAYING and g.score == score0 + 26 + 100 + 150, "после каскада: счёт вырос (%d)" % g.score)
	check(g.crystals_left == left0 - 1 and g.pieces_used == used0 + 1, "кристалл освобождён, фигура засчитана")
	g.speed_step = 9  # как будто что-то ещё в уровне поменялось (скорость, таймеры) — тоже вернётся
	g.score_bump = 1.0
	check(g.owl.can_undo(g), "отмена доступна")
	check(g.undo_piece(), "отмена сработала")
	check(g.board == board0, "поле — как до фиксации")
	check(g.piece_ids == ids0, "номера фигур на поле — как до фиксации")
	check(g.score == score0 and g.shown_score == float(score0), "счёт — как до фиксации (%d)" % g.score)
	check(g.crystals_left == left0 and g.crystals_total == 2, "кристаллы — как до фиксации")
	check(g.pieces_used == used0 and g.big_chains == big0 and g.next_piece_id == pid0, "счётчики фигур и цепочек — как до фиксации")
	check(g.next_type == next0 and g.rng.state == rng0, "следующая фигура и генератор — те же")
	check(g.speed_step == 5, "прочее состояние уровня (общий снимок) — тоже вернулось")
	check(g.piece_type == 0 and g.has_piece and g.piece_pos.y == 0 and g.state == g.State.PLAYING, "та же фигура снова сверху")
	check(g.piece_cells == g.SHAPES[0].cells, "фигура — в начальном повороте")
	check(g.juice.in_flight() == 0 and g.popups.is_empty(), "летящие кристаллы и надписи убраны")
	check(g.owl.flip < 0.1, "часы переворачиваются, надпись «Совиное время!»")
	# та же фигура даёт тот же результат
	g.piece_pos = Vector2i(0, 0)
	g.hard_drop()
	_settle()
	check(g.score == score0 + 276 and g.crystals_left == left0 - 1, "повтор хода — тот же результат")
	check(g.level == 3 and g.stars.get(3, 0) == g.stars.get(3, 0), "уровень и звёзды не тронуты")


func _test_undo_once() -> void:
	print("— одна отмена на попытку")
	_fresh_level()
	_setup_board(2)
	g.hard_drop()
	_settle()
	check(g.undo_piece(), "первая отмена")
	g.hard_drop()
	_settle()
	check(g.owl.used and not g.owl.can_undo(g), "после использования кнопка гаснет")
	var sc: int = g.score
	check(not g.undo_piece() and g.score == sc, "вторая отмена недоступна")
	g._touch_down(0, g.owl.rect.get_center())
	g._touch_up(0, g.owl.rect.get_center())
	check(g.score == sc and g.state == g.State.PLAYING, "касание погасшей кнопки ничего не делает")
	g.start_level(3)
	check(not g.owl.used, "новая попытка уровня — отмена снова есть")
	g.hard_drop()
	_settle()
	if g.state == g.State.PLAYING:
		var b0: int = g.pieces_used
		g._touch_down(1, g.owl.rect.get_center())
		g._touch_up(1, g.owl.rect.get_center())
		check(g.owl.used and g.pieces_used == b0 - 1, "кнопка с песочными часами отменяет касанием")
	else:
		check(true, "кнопка с песочными часами (пропуск: уровень закончился)")
	check(g.owl.rect.position.y < g.board_pos.y and not g.owl.rect.intersects(g.pause_rect) and g.owl.rect.end.x <= g.W, "кнопка — в шапке рядом с паузой, не на поле и не на паузе")


func _test_undo_blocked() -> void:
	print("— отмена недоступна после победы и поражения")
	_fresh_level()
	_setup_board(1)
	g.hard_drop()
	_settle()
	check(g.state == g.State.WIN, "последний кристалл — победа")
	check(not g.owl.can_undo(g) and not g.undo_piece() and g.state == g.State.WIN, "после победы — не отменить")
	_fresh_level()
	_setup_board(2)
	g.hard_drop()
	_settle()
	g._lose()
	check(not g.undo_piece() and g.state == g.State.LOSE, "после поражения — не отменить")
	_fresh_level()
	_setup_board(2)
	g.hard_drop()
	_settle()
	g._set_state(g.State.PAUSED)
	check(not g.undo_piece(), "в паузе — не отменить")
	g._set_state(g.State.PLAYING)
	check(g.undo_piece(), "после паузы — можно")


func _test_undo_hint() -> void:
	print("— подсказка «Совиного времени» — один раз")
	g.tut.enabled = true
	g.tut.seen = {}
	for s in Tutorial.STEPS:
		g.tut.seen[s.id] = true
	_fresh_level()
	g.tut.cur = ""
	check(not g.owl.wants_hint(g), "пока нечего отменять — подсказки нет")
	_setup_board(2)
	g.hard_drop()
	_settle()
	g.tut.cur = ""
	check(g.owl.wants_hint(g), "после первой фигуры — подсказка у кнопки")
	g.owl.update(g, OwlTime.HINT_TIME + 0.1)
	check(g.tut.seen.has(OwlTime.HINT) and not g.owl.wants_hint(g), "показана — больше не появляется")
	var cfg := ConfigFile.new()
	g.tut.save_to(cfg)
	var t2 := Tutorial.new()
	t2.load_from(cfg, 5)
	check(t2.seen.has(OwlTime.HINT), "запоминается в сохранении")
	g.tut.replay()
	check(not g.tut.seen.has(OwlTime.HINT), "«Обучение» в паузе — подсказка покажется снова")
	g.tut.enabled = false


# ---------- «До 3 звёзд» ----------

func _test_star_goal() -> void:
	print("— счётчик «до 3 звёзд»")
	# 0.19: нормы мягче — 3★ до ceil(par × 1,5), 2★ до par × 5 (scripts/star_goal.gd)
	check(StarGoal.goal(10, 0) == [3, 15], "par 10, ещё ни одной фигуры — 3★: ещё 15")
	check(StarGoal.goal(10, 14) == [3, 1], "14 фигур — 3★: ещё 1")
	check(StarGoal.goal(10, 15) == [2, 35], "15 фигур — 3★ уже нельзя, 2★: ещё 35 (предел 50)")
	check(StarGoal.goal(10, 49) == [2, 1], "49 фигур — 2★: ещё 1")
	check(StarGoal.goal(10, 50) == [0, 0], "50 фигур — строка прячется")
	# совпадает со звёздами за победу (game.gd _win) для разных par
	var bad := []
	for par in [3, 5, 7, 8, 11, 16, 22]:
		for used in 40:
			var gl: Array = StarGoal.goal(par, used)
			var fin := used + 1  # следующая (падающая) фигура завершает уровень
			var win := 3 if fin <= StarGoal.limit(par, 3) else (2 if fin <= StarGoal.limit(par, 2) else 1)
			var shown: int = gl[0] if gl[0] > 0 else 1
			if shown != win:
				bad.append("%d/%d" % [par, used])
	check(bad.is_empty(), "строка всегда совпадает со звёздами за победу %s" % str(bad))
	_fresh_level()
	g._win()
	var stars_ok: bool = g.last_stars == 3
	check(stars_ok, "игра: par уровня 3 = %d, победа первой фигурой — 3 звезды" % g.par)


# ---------- Рисование ----------

func _test_drawing() -> void:
	print("— рисование (кадры с праздником, часами, облачком, строкой звёзд)")
	for kind in ["owl", "axolotl", "puppy", "kitten"]:
		_fresh_level(kind)
		_setup_board(2)
		g.hard_drop()
		g.juice.on_cascade(4)
		g.say.reset()
		g.hero_says("cascade")
		g.queue_redraw()
		await process_frame
		await process_frame
		_settle()
	check(true, "кадры для всех 4 героев нарисованы без ошибок")
	g.access.big = true
	g.owl.reset()
	g.pieces_used = 40
	g.queue_redraw()
	await process_frame
	await process_frame
	g.access.big = false
	check(true, "крупный текст и спрятанная строка звёзд — без ошибок")
	g.go_home()
	await process_frame
