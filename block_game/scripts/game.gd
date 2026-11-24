extends Node2D
## Падающие блоки: вся игра в одном узле. Рисуем через _draw(), чтобы не зависеть
## от шрифтов с особыми символами и от сторонних ассетов.

const COLS := 10
const ROWS := 20
const CELL := 48
const VIEW := Vector2(720, 1280)
const BOARD_POS := Vector2(24, 170)
const PANEL_X := 528.0
const PANEL_W := 168.0

const LOCK_DELAY := 0.5
const MAX_LOCK_RESETS := 15
const CLEAR_TIME := 0.25
const REPEAT_DELAY := 0.17
const REPEAT_RATE := 0.06
const LINE_SCORES := [0, 100, 300, 500, 800]
const SAVE_PATH := "user://save.cfg"

const BG := Color("#14172b")
const BOARD_BG := Color("#1d2140")
const GRID := Color("#262b52")
const TEXT := Color("#e8eaf6")
const DIM := Color("#8a90b8")
const BTN := Color("#2a3060")
const BTN_DOWN := Color("#3f4890")

const COLORS := [
	Color("#4dd0e1"), Color("#ffd54f"), Color("#ba68c8"), Color("#81c784"),
	Color("#e57373"), Color("#64b5f6"), Color("#ffb74d"),
]

# Клетки фигуры и размер квадрата, внутри которого она поворачивается.
const SHAPES := [
	{"cells": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], "box": 4},
	{"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], "box": 2},
	{"cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], "box": 3},
	{"cells": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)], "box": 3},
	{"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)], "box": 3},
	{"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], "box": 3},
	{"cells": [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], "box": 3},
]
const KICKS := [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -1)]

enum State { MENU, PLAYING, PAUSED, CLEARING, GAME_OVER }

var state := State.MENU
var board: Array = []  # ROWS*COLS, -1 = пусто, иначе номер фигуры
var has_piece := false
var piece_type := 0
var piece_cells: Array = []
var piece_pos := Vector2i.ZERO
var next_type := 0
var bag: Array = []

var score := 0
var best := 0
var lines := 0
var level := 1

var fall_timer := 0.0
var lock_timer := 0.0
var lock_resets := 0
var clearing_rows: Array = []
var clear_timer := 0.0
var game_over_at := 0.0

# Управление касаниями
var buttons := {}        # имя -> Rect2
var held := {}           # номер касания -> имя кнопки
var repeat_left := {}    # номер касания -> секунды до повтора
var board_touch := {}    # номер касания -> данные свайпа
var pause_rect := Rect2(620, 50, 76, 76)
var btn_style: StyleBoxFlat
var btn_style_down: StyleBoxFlat


func _ready() -> void:
	randomize()
	get_tree().set_quit_on_go_back(false)
	board.resize(ROWS * COLS)
	board.fill(-1)
	_load()
	var names := ["left", "right", "soft", "hard", "rotate"]
	var w := (VIEW.x - 32.0 - 4 * 12.0) / 5.0
	for i in names.size():
		buttons[names[i]] = Rect2(16 + i * (w + 12), 1148, w, 116)
	btn_style = _make_style(BTN)
	btn_style_down = _make_style(BTN_DOWN)


func _make_style(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(18)
	return sb


# ---------- Игровая логика ----------

func new_game() -> void:
	board.resize(ROWS * COLS)
	board.fill(-1)
	score = 0
	lines = 0
	level = 1
	bag.clear()
	clearing_rows.clear()
	next_type = _from_bag()
	state = State.PLAYING
	_spawn()


func _from_bag() -> int:
	if bag.is_empty():
		bag = [0, 1, 2, 3, 4, 5, 6]
		bag.shuffle()
	return bag.pop_back()


func _spawn() -> void:
	piece_type = next_type
	next_type = _from_bag()
	piece_cells = SHAPES[piece_type].cells.duplicate()
	piece_pos = Vector2i((COLS - SHAPES[piece_type].box) / 2, 0)
	fall_timer = 0.0
	lock_timer = 0.0
	lock_resets = 0
	has_piece = true
	if not fits(piece_cells, piece_pos):
		_game_over()


func fits(cells: Array, pos: Vector2i) -> bool:
	for c in cells:
		var x: int = c.x + pos.x
		var y: int = c.y + pos.y
		if x < 0 or x >= COLS or y >= ROWS:
			return false
		if y >= 0 and board[y * COLS + x] != -1:
			return false
	return true


func fall_interval() -> float:
	return maxf(0.07, 0.85 * pow(0.85, level - 1))


func move(dx: int) -> bool:
	if state != State.PLAYING or not has_piece:
		return false
	if fits(piece_cells, piece_pos + Vector2i(dx, 0)):
		piece_pos.x += dx
		_moved()
		return true
	return false


func rotate_piece() -> bool:
	if state != State.PLAYING or not has_piece:
		return false
	var n: int = SHAPES[piece_type].box
	if n == 2:
		return false
	var rotated: Array = []
	for c in piece_cells:
		rotated.append(Vector2i(n - 1 - c.y, c.x))
	for k in KICKS:
		if fits(rotated, piece_pos + k):
			piece_cells = rotated
			piece_pos += k
			_moved()
			return true
	return false


func soft_drop() -> bool:
	if state != State.PLAYING or not has_piece:
		return false
	if fits(piece_cells, piece_pos + Vector2i(0, 1)):
		piece_pos.y += 1
		score += 1
		fall_timer = 0.0
		return true
	return false


func hard_drop() -> void:
	if state != State.PLAYING or not has_piece:
		return
	var n := 0
	while fits(piece_cells, piece_pos + Vector2i(0, 1)):
		piece_pos.y += 1
		n += 1
	score += 2 * n
	_lock()


func ghost_y() -> int:
	var y := piece_pos.y
	while fits(piece_cells, Vector2i(piece_pos.x, y + 1)):
		y += 1
	return y


func _moved() -> void:
	# Сдвиг на земле даёт немного времени до фиксации, но не бесконечно.
	if lock_timer > 0.0 and lock_resets < MAX_LOCK_RESETS:
		lock_timer = 0.0
		lock_resets += 1


func step(delta: float) -> void:
	match state:
		State.PLAYING:
			if fits(piece_cells, piece_pos + Vector2i(0, 1)):
				lock_timer = 0.0
				fall_timer += delta
				if fall_timer >= fall_interval():
					fall_timer = 0.0
					piece_pos.y += 1
			else:
				lock_timer += delta
				if lock_timer >= LOCK_DELAY:
					_lock()
		State.CLEARING:
			clear_timer -= delta
			if clear_timer <= 0.0:
				_finish_clear()


func _lock() -> void:
	has_piece = false
	for c in piece_cells:
		var x: int = c.x + piece_pos.x
		var y: int = c.y + piece_pos.y
		if y < 0:
			_game_over()
			return
		board[y * COLS + x] = piece_type
	clearing_rows.clear()
	for y in ROWS:
		var full := true
		for x in COLS:
			if board[y * COLS + x] == -1:
				full = false
				break
		if full:
			clearing_rows.append(y)
	if clearing_rows.is_empty():
		_spawn()
	else:
		state = State.CLEARING
		clear_timer = CLEAR_TIME


func _finish_clear() -> void:
	var kept: Array = []
	for y in ROWS:
		if not clearing_rows.has(y):
			kept.append(board.slice(y * COLS, (y + 1) * COLS))
	board.fill(-1)
	var start := ROWS - kept.size()
	for i in kept.size():
		for x in COLS:
			board[(start + i) * COLS + x] = kept[i][x]
	var n := clearing_rows.size()
	lines += n
	score += LINE_SCORES[n] * level
	level = lines / 10 + 1
	clearing_rows.clear()
	state = State.PLAYING
	_spawn()


func _game_over() -> void:
	state = State.GAME_OVER
	has_piece = false
	game_over_at = _now()
	if score > best:
		best = score
		_save()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best = cfg.get_value("stats", "best", 0)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "best", best)
	cfg.save(SAVE_PATH)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# ---------- Ввод ----------

func _process(delta: float) -> void:
	step(delta)
	for idx in held.keys():
		var name: String = held[idx]
		if name in ["left", "right", "soft"]:
			repeat_left[idx] -= delta
			if repeat_left[idx] <= 0.0:
				repeat_left[idx] = REPEAT_RATE
				_press(name)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if state == State.PLAYING:
			state = State.PAUSED
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == State.PLAYING or state == State.CLEARING:
			state = State.PAUSED
		else:
			get_tree().quit()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		event = make_input_local(event)
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index, event.position)
	elif event is InputEventScreenDrag:
		_touch_drag(event.index, event.position)
	elif event is InputEventKey and event.pressed:
		_key(event)


func _key(e: InputEventKey) -> void:
	match e.keycode:
		KEY_LEFT: _press("left")
		KEY_RIGHT: _press("right")
		KEY_DOWN: _press("soft")
		KEY_UP: _press("rotate")
		KEY_SPACE: _press("hard")
		KEY_P, KEY_ESCAPE: _toggle_pause()
		KEY_ENTER:
			if state == State.MENU or state == State.GAME_OVER:
				new_game()


func _press(name: String) -> void:
	match name:
		"left": move(-1)
		"right": move(1)
		"soft": soft_drop()
		"hard": hard_drop()
		"rotate": rotate_piece()


func _toggle_pause() -> void:
	if state == State.PLAYING:
		state = State.PAUSED
	elif state == State.PAUSED:
		state = State.PLAYING


func _touch_down(idx: int, pos: Vector2) -> void:
	if state == State.MENU:
		new_game()
		return
	if state == State.GAME_OVER:
		if _now() - game_over_at > 0.8:
			new_game()
		return
	if pause_rect.grow(10).has_point(pos):
		_toggle_pause()
		return
	if state == State.PAUSED:
		state = State.PLAYING
		return
	for name in buttons:
		if buttons[name].has_point(pos):
			held[idx] = name
			repeat_left[idx] = REPEAT_DELAY
			_press(name)
			return
	if pos.y < 1140:
		board_touch[idx] = {"start": pos, "ax": pos.x, "ay": pos.y, "t": _now(), "moved": false}


func _touch_drag(idx: int, pos: Vector2) -> void:
	if not board_touch.has(idx):
		return
	var t: Dictionary = board_touch[idx]
	var step_x := CELL * 0.8
	while pos.x - t.ax >= step_x:
		move(1)
		t.ax += step_x
		t.moved = true
	while t.ax - pos.x >= step_x:
		move(-1)
		t.ax -= step_x
		t.moved = true
	while pos.y - t.ay >= CELL:
		soft_drop()
		t.ay += CELL
		t.moved = true


func _touch_up(idx: int, pos: Vector2) -> void:
	held.erase(idx)
	repeat_left.erase(idx)
	if not board_touch.has(idx):
		return
	var t: Dictionary = board_touch[idx]
	board_touch.erase(idx)
	var d: Vector2 = pos - t.start
	var dt := _now() - float(t.t)
	if d.y > 140 and dt < 0.3 and absf(d.y) > absf(d.x) * 2:
		hard_drop()
	elif not t.moved and d.length() < 24:
		rotate_piece()


# ---------- Отрисовка ----------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, VIEW), BG)
	draw_string(font, Vector2(24, 108), "BLOCK DROP", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, TEXT)

	# Поле
	var bsize := Vector2(COLS * CELL, ROWS * CELL)
	draw_rect(Rect2(BOARD_POS - Vector2(4, 4), bsize + Vector2(8, 8)), GRID)
	draw_rect(Rect2(BOARD_POS, bsize), BOARD_BG)
	for x in range(1, COLS):
		draw_line(BOARD_POS + Vector2(x * CELL, 0), BOARD_POS + Vector2(x * CELL, bsize.y), GRID, 1.0)
	for y in range(1, ROWS):
		draw_line(BOARD_POS + Vector2(0, y * CELL), BOARD_POS + Vector2(bsize.x, y * CELL), GRID, 1.0)
	for y in ROWS:
		for x in COLS:
			var v: int = board[y * COLS + x]
			if v != -1:
				_draw_cell(BOARD_POS + Vector2(x, y) * CELL, CELL, COLORS[v])

	if has_piece and state != State.GAME_OVER:
		var col: Color = COLORS[piece_type]
		var gy := ghost_y()
		for c in piece_cells:
			var gp := Vector2i(c.x + piece_pos.x, c.y + gy)
			if gp.y >= 0:
				var r := Rect2(BOARD_POS + Vector2(gp) * CELL + Vector2(3, 3), Vector2(CELL - 6, CELL - 6))
				draw_rect(r, Color(col, 0.45), false, 3.0)
		for c in piece_cells:
			var p := Vector2i(c.x + piece_pos.x, c.y + piece_pos.y)
			if p.y >= 0:
				_draw_cell(BOARD_POS + Vector2(p) * CELL, CELL, col)

	if state == State.CLEARING:
		var a := clampf(clear_timer / CLEAR_TIME, 0.0, 1.0)
		for y in clearing_rows:
			draw_rect(Rect2(BOARD_POS + Vector2(0, y * CELL), Vector2(bsize.x, CELL)), Color(1, 1, 1, a * 0.8))

	_draw_panel(font)
	_draw_controls()
	_draw_overlay(font)


func _draw_cell(p: Vector2, size: float, col: Color) -> void:
	var r := Rect2(p + Vector2(2, 2), Vector2(size - 4, size - 4))
	draw_rect(r, col)
	draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.22)), col.lightened(0.35))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.8), Vector2(r.size.x, r.size.y * 0.2)), col.darkened(0.3))


func _draw_panel(font: Font) -> void:
	draw_string(font, Vector2(PANEL_X, 200), "ДАЛЕЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, DIM)
	var box := Rect2(PANEL_X, 214, PANEL_W, 120)
	draw_style_box(btn_style, box)
	if state != State.MENU:
		var s: Dictionary = SHAPES[next_type]
		var mn := Vector2(99, 99)
		var mx := Vector2(-99, -99)
		for c in s.cells:
			mn = mn.min(Vector2(c))
			mx = mx.max(Vector2(c))
		var cs := 32.0
		var origin := box.get_center() - (mx - mn + Vector2.ONE) * cs / 2.0 - mn * cs
		for c in s.cells:
			_draw_cell(origin + Vector2(c) * cs, cs, COLORS[next_type])

	var stats := [["СЧЁТ", score], ["РЕКОРД", best], ["УРОВЕНЬ", level], ["ЛИНИИ", lines]]
	for i in stats.size():
		var y := 400.0 + i * 100.0
		draw_string(font, Vector2(PANEL_X, y), stats[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, DIM)
		draw_string(font, Vector2(PANEL_X, y + 44), str(stats[i][1]), HORIZONTAL_ALIGNMENT_LEFT, PANEL_W, 40, TEXT)

	# Кнопка паузы
	draw_style_box(btn_style, pause_rect)
	var pc := pause_rect.get_center()
	draw_rect(Rect2(pc + Vector2(-14, -16), Vector2(10, 32)), TEXT)
	draw_rect(Rect2(pc + Vector2(4, -16), Vector2(10, 32)), TEXT)


func _draw_controls() -> void:
	var pressed := held.values()
	for name in buttons:
		var r: Rect2 = buttons[name]
		draw_style_box(btn_style_down if pressed.has(name) else btn_style, r)
		var c := r.get_center()
		var s := 22.0
		match name:
			"left":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(s * 0.7, -s), c + Vector2(s * 0.7, s)]), TEXT)
			"right":
				draw_colored_polygon(PackedVector2Array([c + Vector2(s, 0), c + Vector2(-s * 0.7, -s), c + Vector2(-s * 0.7, s)]), TEXT)
			"soft":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, s), c + Vector2(-s, -s * 0.7), c + Vector2(s, -s * 0.7)]), TEXT)
			"hard":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.4), c + Vector2(-s, -s), c + Vector2(s, -s)]), TEXT)
				draw_rect(Rect2(c + Vector2(-s, s * 0.7), Vector2(2 * s, 7)), TEXT)
			"rotate":
				var rad := s * 0.85
				draw_arc(c, rad, deg_to_rad(-60), deg_to_rad(220), 24, TEXT, 6.0, true)
				var a := deg_to_rad(220)
				var p := c + Vector2(cos(a), sin(a)) * rad
				var t := Vector2(-sin(a), cos(a))
				var n := Vector2(cos(a), sin(a))
				draw_colored_polygon(PackedVector2Array([p + t * 13, p + n * 11, p - n * 11]), TEXT)


func _draw_overlay(font: Font) -> void:
	var lines_text: Array = []
	match state:
		State.MENU:
			lines_text = [["BLOCK DROP", 64, TEXT], ["Нажмите, чтобы начать", 32, DIM]]
		State.PAUSED:
			lines_text = [["ПАУЗА", 64, TEXT], ["Нажмите, чтобы продолжить", 32, DIM]]
		State.GAME_OVER:
			lines_text = [["ИГРА ОКОНЧЕНА", 56, TEXT], ["Счёт: %d" % score, 40, TEXT], ["Нажмите, чтобы сыграть ещё", 30, DIM]]
		_:
			return
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.65))
	var y := 560.0
	for l in lines_text:
		draw_string(font, Vector2(0, y), l[0], HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, l[1], l[2])
		y += l[1] * 1.8
