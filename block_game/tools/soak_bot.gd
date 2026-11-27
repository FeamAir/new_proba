extends RefCounted
## 0.19: «долгий прогон» — робот играет уровни подряд и всё время «мешает» игре, как живой
## человек на телефоне: жмёт паузу и снимает её, жест «Назад», отмена («Совиное время»),
## сворачивает и разворачивает приложение (уведомления движка), уходит в меню и возвращается,
## повторяет обучение, перезапускает уровень. Помехи чаще всего — в «интересные» моменты:
## каскад, замедление, взрыв бомбы, полёт кристаллов, облачко героя, шаг обучения, переворот часов.
##
## Сторож (watch) после каждого шага игры проверяет, что игра не «замёрзла»:
##   * PLAYING без фигуры дольше 0,5 с (фигура не появляется, ввод не принимается);
##   * фигура не двигается дольше max(4 с, 3 интервала падения) вне паузы и не по обучению;
##   * анимация каскада (CLEARING / SETTLE) идёт дольше 5 с без пояснения обучения;
##   * Engine.time_scale не 1, замедление праздника дольше положенного.
## Замеры: время шага игры (логика), время кадра (рисование), память, число объектов и узлов,
## размеры списков эффектов — по минутам игрового времени.
##
## Используют: tests/test_v019_soak.gd (короткий прогон в тестах и долгий с параметром --soak-sec).
## Ход фигуры — простой жадный выбор места с розыгрышем каскада Specials.resolve (как tools/level_bot.gd).

const Specials := preload("res://scripts/specials.gd")
const Juice := preload("res://scripts/juice.gd")
const HeroArt := preload("res://scripts/hero_art.gd")

const DT := 1.0 / 60.0

var g
var rng := RandomNumberGenerator.new()
var levels := Vector2i(1, 15)
var t := 0.0                 # игровое время прогона, с
var ticks := 0

# --- робот-игрок ---
var plan := {}               # {"rot", "x", "drop"} для текущей фигуры
var plan_key := ""
var sloppy := 0.0           # доля бросков «не глядя» в этой попытке
var act_wait := 0.0          # секунд до следующего действия
var rot_done := 0
var held_btn := ""           # кнопка, «зажатая» пальцем 0 (отпускается на следующем шаге)
var away := 0.0              # секунд «вне приложения» (шаги игры не идут, потом — большой кадр)
var away_kind := ""
var focus_back := 0.0        # секунд до возврата фокуса (FOCUS_IN), игра идёт
var state_wait := 0.0        # задержка решения на экранах паузы, победы, поражения, дома

# --- сторож ---
var mark := ""
var mark_t := 0.0
var pieceless_t := 0.0
var anim_t := 0.0
var stuck: Array = []        # [{t, kind, state, events}]
var events: Array = []       # последние помехи (для отчёта о зависании)
var counts := {}             # помеха -> сколько раз
var wins := 0
var loses := 0
var pieces := 0
var max_chain := 0
var max_slow := 0.0

# --- замеры ---
var minute := []             # строки по минутам
var _acc := {"tick_us": 0, "ticks": 0, "tick_max": 0}
var _min_i := 0


func _init(game, seed_v: int, lv := Vector2i(1, 15)) -> void:
	g = game
	rng.seed = seed_v
	levels = lv


# ---------------- шаг прогона ----------------

## Один шаг: робот действует, игра делает кадр DT (или «большой» кадр после возврата в приложение).
func tick() -> void:
	var dt := DT
	if away > 0.0:
		away -= DT
		t += DT
		if away > 0.0:
			return  # приложение свёрнуто: кадров нет
		dt = minf(rng.randf_range(0.2, 2.5), 3.0)  # первый кадр после возврата — длинный
		g._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		_ev("resume_" + away_kind)
	if focus_back > 0.0:
		focus_back -= DT
		if focus_back <= 0.0:
			g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_act()
	var t0 := Time.get_ticks_usec()
	g._process(dt)
	var us := Time.get_ticks_usec() - t0
	_acc.tick_us += us
	_acc.ticks += 1
	_acc.tick_max = maxi(_acc.tick_max, us)
	t += DT
	ticks += 1
	_watch(dt)


## Отметка минуты: draw_us — среднее время рисования кадра за минуту (мерит вызывающий).
func sample(draw_us: float) -> Dictionary:
	var row := {
		"min": _min_i, "level": g.level, "tick_us": float(_acc.tick_us) / maxi(_acc.ticks, 1), "tick_max": _acc.tick_max,
		"draw_us": draw_us, "mem": OS.get_static_memory_usage(),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"fx": g.particles.size() + g.popups.size() + g.juice.flyers.size() + g.boom_fx.booms.size() + g.boom_fx.opens.size(),
		"snap": g.owl.snap.size(), "tex": HeroArt._tex.size(), "time_scale": Engine.time_scale, "stuck": stuck.size()}
	minute.append(row)
	_min_i += 1
	_acc = {"tick_us": 0, "ticks": 0, "tick_max": 0}
	return row


static func row_text(r: Dictionary) -> String:
	return "мин %3d | ур %2d | шаг %6.0f мкс (макс %6d) | кадр %6.0f мкс | память %6.1f МБ | объектов %6d | узлов %4d | ресурсов %5d | сирот %d | эффектов %4d | снимок %2d | картинок %3d | time_scale %.2f | зависаний %d" % [
		r.min, r.level, r.tick_us, r.tick_max, r.draw_us, r.mem / 1048576.0, r.objects, r.nodes, r.resources, r.orphans, r.fx, r.snap, r.tex, r.time_scale, r.stuck]


# ---------------- сторож ----------------

func _watch(dt: float) -> void:
	if Engine.time_scale != 1.0:
		_stuck("time_scale")
	max_slow = maxf(max_slow, g.juice.slow)
	if g.juice.slow > Juice.SLOW_TIME + 0.001:
		_stuck("slow")
	max_chain = maxi(max_chain, g.chain)
	var s: int = g.state
	if s == g.State.PLAYING:
		anim_t = 0.0
		if not g.has_piece:
			pieceless_t += dt
			if pieceless_t > 0.5:
				_stuck("pieceless")
				return
		else:
			pieceless_t = 0.0
		var m := "%d|%d|%s|%d" % [g.level, g.pieces_used, str(g.piece_pos), int(g.has_piece)]
		if m != mark or g.tut.holds_fall():
			mark = m
			mark_t = 0.0
		else:
			mark_t += dt
			if mark_t > maxf(4.0, 3.0 * g.fall_interval() + g.LOCK_DELAY):
				_stuck("no_fall")
	elif s == g.State.CLEARING or s == g.State.SETTLE:
		pieceless_t = 0.0
		mark = ""
		if g.tut.is_info():
			anim_t = 0.0
		else:
			anim_t += dt
			if anim_t > 5.0:
				_stuck("anim")
	else:
		pieceless_t = 0.0
		anim_t = 0.0
		mark = ""


func _stuck(kind: String) -> void:
	stuck.append({"t": t, "kind": kind, "state": g.State.keys()[g.state], "level": g.level,
		"has_piece": g.has_piece, "clearing": g.clearing_rows.size(), "events": events.slice(-6)})
	# снять зависание, чтобы прогон шёл дальше: новая попытка уровня
	Engine.time_scale = 1.0
	pieceless_t = 0.0
	mark_t = 0.0
	anim_t = 0.0
	mark = ""
	g.start_level(g.level)


func _ev(n: String) -> void:
	counts[n] = counts.get(n, 0) + 1
	if g.state in [g.State.CLEARING, g.State.SETTLE]:
		counts["cascade:" + n] = counts.get("cascade:" + n, 0) + 1  # помеха во время каскада
	events.append("%.1f %s@%s" % [t, n, g.State.keys()[g.state]])
	if events.size() > 30:
		events.pop_front()


# ---------------- робот ----------------

## «Интересный» момент: каскад, замедление, взрыв, полёт кристаллов, облачко, обучение, часы.
func _hot() -> bool:
	return g.state in [g.State.CLEARING, g.State.SETTLE] or g.juice.slow > 0.0 or g.juice.flyers.size() > 0 \
		or g.boom_fx.booms.size() > 0 or g.boom_fx.opens.size() > 0 or g.say.visible() or g.tut.active() \
		or g.owl.flip < g.owl.FLIP_TIME or g.owl.wants_hint(g) or g.juice.banner_t < Juice.BANNER_TIME


func _tap(pos: Vector2, idx := 1) -> void:
	g._touch_down(idx, pos)
	g._touch_up(idx, pos)


func _act() -> void:
	if held_btn != "":
		var r: Rect2 = g.buttons[held_btn]
		g._touch_up(0, r.get_center())
		held_btn = ""
	if g.notice_ui and g.notice_ui.active():
		g.notice_ui.back()
		return
	var s: int = g.state
	var in_level: bool = s in [g.State.PLAYING, g.State.CLEARING, g.State.SETTLE]
	if in_level and rng.randf() < (0.03 if _hot() else 0.003):
		_chaos()
		return
	match s:
		g.State.PLAYING:
			_play()
		g.State.CLEARING, g.State.SETTLE:
			if g.tut.is_info() and g.tut.t > 0.5 and rng.randf() < 0.1:
				_tap(g.board_pos + Vector2(100, 300))
		g.State.PAUSED:
			_paused()
		g.State.WIN, g.State.LOSE:
			_result()
		g.State.HOME, g.State.MAP, g.State.PICK_HERO, g.State.SPLASH:
			_home()
		_:
			g.go_home()


func _chaos() -> void:
	var r := rng.randf()
	if r < 0.22:
		_ev("pause_btn")
		_tap(g.pause_rect.get_center())
	elif r < 0.42:
		_ev("back")
		g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	elif r < 0.55:
		_ev("minimize")
		g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		g._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		away = rng.randf_range(0.3, 4.0)
		away_kind = "minimize"
	elif r < 0.65:
		_ev("focus_out")  # шторка уведомлений, системное окно: кадры идут
		g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		focus_back = rng.randf_range(0.2, 2.0)
	elif r < 0.78:
		_ev("undo")
		_tap(g.owl.rect.get_center())
	elif r < 0.88:
		_ev("tap_board")
		_tap(g.board_pos + Vector2(rng.randf_range(0, g.COLS * g.CELL), rng.randf_range(0, g.ROWS * g.CELL)), 2)
	elif r < 0.95:
		_ev("tap_hero")
		_tap(g.play_hero.rect.get_center() if g.play_hero.rect.size.x > 0 else Vector2(620, 900), 2)
	else:
		_ev("swipe")
		var a: Vector2 = g.board_pos + Vector2(rng.randf_range(20, 460), rng.randf_range(100, 700))
		g._touch_down(3, a)
		g._touch_drag(3, a + Vector2(rng.randf_range(-150, 150), rng.randf_range(0, 200)))
		g._touch_up(3, a + Vector2(rng.randf_range(-150, 150), rng.randf_range(0, 200)))


func _press_btn(n: String) -> void:
	held_btn = n
	g._touch_down(0, g.buttons[n].get_center())


func _play() -> void:
	if not g.has_piece:
		return
	if g.tut.is_info():
		if g.tut.t > 0.5:
			_tap(g.board_pos + Vector2(100, 300))
		return
	var key := "%d|%d|%d" % [g.level, g.pieces_used, int(g.owl.used)]
	if key != plan_key:
		plan_key = key
		plan = {} if rng.randf() < sloppy else _choose()  # иногда — бросок наугад (будут и поражения)
		rot_done = 0
		act_wait = rng.randf_range(0.1, 0.5)
		pieces += 1
	act_wait -= DT
	if act_wait > 0.0:
		return
	act_wait = rng.randf_range(0.06, 0.2)
	if plan.is_empty():
		_press_btn("hard")
		return
	if rot_done < plan.rot:
		rot_done += 1
		_press_btn("rotate")
		return
	if g.piece_pos.x != plan.x:
		var dir: int = 1 if plan.x > g.piece_pos.x else -1
		if g.fits(g.piece_cells, g.piece_pos + Vector2i(dir, 0)):
			_press_btn("right" if dir > 0 else "left")
			return
	# на месте: бросить или дать упасть самой (обучение ждёт действия — бросок)
	if plan.drop or g.tut.active():
		_press_btn("hard")
	else:
		act_wait = 99.0  # ждём: фигура падает и ложится сама


func _paused() -> void:
	if state_wait <= 0.0:
		state_wait = rng.randf_range(0.2, 2.0)
	state_wait -= DT
	if state_wait > 0.0:
		return
	state_wait = 0.0
	if g.access_ui and g.access_ui.open:
		g.access_ui.close()
		return
	if g.assist_ui.stats_open:
		g.assist_ui.stats_open = false
		return
	var r := rng.randf()
	var item := "resume"
	if r > 0.97:
		item = "tutorial"
	elif r > 0.92:
		item = "menu"
	elif r > 0.87:
		item = "restart"
	_ev("pause_" + item)
	_tap(g.menu_buttons[item].get_center())


func _result() -> void:
	if g.state_time < 0.0:
		if rng.randf() < 0.01:
			_tap(Vector2(360, 640))
		return
	if state_wait <= 0.0:
		state_wait = rng.randf_range(0.9, 2.0)
	state_wait -= DT
	if state_wait > 0.0:
		return
	state_wait = 0.0
	if g.state == g.State.WIN:
		wins += 1
	else:
		loses += 1
	var nxt: int = g.level + 1 if g.state == g.State.WIN else g.level
	if nxt > levels.y:
		nxt = levels.x
	if rng.randf() < 0.2:
		_ev("result_back")
		g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		return
	_start(nxt)


## Новая попытка уровня: в каждой пятой робот играет небрежно (часть фигур бросает не глядя).
func _start(n: int) -> void:
	sloppy = 0.5 if rng.randf() < 0.2 else 0.0
	g.start_level(n)


func _home() -> void:
	if g.state == g.State.PICK_HERO or g.meta.hero == "":
		g.meta.set_hero("owl")
		g.go_home()
		return
	if state_wait <= 0.0:
		state_wait = rng.randf_range(0.3, 1.5)
	state_wait -= DT
	if state_wait > 0.0:
		return
	state_wait = 0.0
	var n: int = clampi(g.level, levels.x, levels.y)
	if g.state == g.State.HOME and rng.randf() < 0.5:
		n = clampi(g.max_level, levels.x, levels.y)
	_start(n)


# ---------------- выбор места фигуры ----------------

func _rots(cells: Array, box: int) -> Array:
	var out: Array = []
	var c := cells.duplicate()
	for r in (1 if box == 0 else 4):
		out.append(c)
		var nc: Array = []
		for p in c:
			nc.append(Vector2i(box - 1 - p.y, p.x))
		c = nc
	return out


func _fits(b: PackedInt32Array, cells: Array, pos: Vector2i) -> bool:
	for c in cells:
		var x: int = c.x + pos.x
		var y: int = c.y + pos.y
		if x < 0 or x >= g.COLS or y >= g.ROWS:
			return false
		if y >= 0 and b[y * g.COLS + x] != g.EMPTY:
			return false
	return true


func _choose() -> Dictionary:
	var C: int = g.COLS
	var R: int = g.ROWS
	var b0 := PackedInt32Array(g.board)
	var i0 := PackedInt32Array(g.piece_ids)
	var rots := _rots(g.piece_cells, g.SHAPES[g.piece_type].box)
	var best := {}
	var best_s := -INF
	var pet0 := Specials.pet_row(g.board, C)
	for r in rots.size():
		for ox in range(-3, C + 1):
			var p := Vector2i(ox, g.piece_pos.y)
			if not _fits(b0, rots[r], p):
				continue
			while _fits(b0, rots[r], p + Vector2i(0, 1)):
				p.y += 1
			var b := b0.duplicate()
			var ids := i0.duplicate()
			var top_out := false
			for c in rots[r]:
				var y: int = c.y + p.y
				if y < 0:
					top_out = true
				else:
					b[y * C + c.x + p.x] = g.piece_type
					ids[y * C + c.x + p.x] = 1000000
			var sim: Dictionary = Specials.resolve(b, ids, C, R, g.EMPTY, g.FALL_ALL)
			var s := -1e9 if top_out else 0.0
			s += 1000.0 * (sim.crystals + sim.chest) + 40.0 * sim.lines
			if g.goal == "pet":
				s += 1000.0 * maxi(0, Specials.pet_row(b, C) - pet0)
			var holes := 0
			var agg := 0
			var bump := 0
			var prev := -1
			for x in C:
				var h := 0
				var seen := false
				for y in R:
					if b[y * C + x] != g.EMPTY:
						if not seen:
							seen = true
							h = R - y
					elif seen:
						holes += 1
				agg += h
				if prev >= 0:
					bump += absi(h - prev)
				prev = h
			s += -45.0 * holes - 3.0 * agg - 4.0 * bump + rng.randf() * 2.0
			if s > best_s:
				best_s = s
				best = {"rot": r, "x": ox, "drop": rng.randf() < 0.75}
	return best
