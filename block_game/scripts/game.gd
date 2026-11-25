extends Node2D
## Cascado: падающие блоки с кристаллами и каскадами.
## Цель уровня: освободить все кристаллы, вмурованные в нижние ряды.
## После очистки линии фигуры падают целиком («липкая» гравитация, scripts/gravity.gd),
## камень и кристаллы — поодиночке; так собираются новые линии (каскад ×2, ×3...).
## Всё рисуется через _draw(), сторонних картинок нет.

const COLS := 8
const ROWS := 14
const CELL := 60
const W := 720.0

const EMPTY := -1
const STONE := 7
const CRYSTAL := 8

const CLEAR_TIME := 0.22
const SETTLE_TIME := 0.16
const LOCK_DELAY := 0.5
const MAX_LOCK_RESETS := 15
const REPEAT_DELAY := 0.17
const REPEAT_RATE := 0.06
const LINE_SCORES := [0, 100, 250, 450, 700]
const SAVE_PATH := "user://save.cfg"
const Levels := preload("res://scripts/levels.gd")
const Gravity := preload("res://scripts/gravity.gd")
## Мета-слой 0.6: герой, осколки, гардероб, дома (данные — meta.gd, экраны — screens.gd)
const Meta := preload("res://scripts/meta.gd")
const Screens := preload("res://scripts/screens.gd")
## true — после очистки падают все группы поля (и камень уровня над дырами ниже линии);
## false — только то, что выше нижней очищенной линии (ниже неё поле не трогается).
const FALL_ALL := false

const GEMS := [
	Color("#B46CFF"), Color("#FF4D6D"), Color("#FFB547"), Color("#3DDC97"),
	Color("#3FD0FF"), Color("#FF8FD8"), Color("#E8F05A"),
]
const STONE_COL := Color("#4A3B6B")
const CRYSTAL_COL := Color("#9FF6FF")
const BG_TOP := Color("#120B24")
const BG_BOTTOM := Color("#1E1238")
const FIELD := Color(0.047, 0.031, 0.098, 0.85)
const TEXT := Color("#F4EEFF")
const DIM := Color("#A79BC9")
const ACCENT := Color("#FFB547")
const BTN := Color("#2A1A4F")
const BTN_DOWN := Color("#46307A")

# Фигуры из 2, 3, 4 и 5 клеток. box — квадрат поворота (0 = не вращается), w — как часто выпадает.
const SHAPES := [
	{"cells": [Vector2i(0, 0), Vector2i(1, 0)], "box": 2, "w": 3},
	{"cells": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], "box": 3, "w": 3},
	{"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)], "box": 2, "w": 3},
	{"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], "box": 0, "w": 2},
	{"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)], "box": 3, "w": 1},
	{"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)], "box": 3, "w": 1},
	{"cells": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], "box": 3, "w": 1},
]
const KICKS := [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -1)]
const SFX_NAMES := ["move", "rotate", "land", "drop", "line1", "line2", "line3", "line4",
	"combo1", "combo2", "combo3", "combo4", "combo5", "crystal", "levelup", "gameover", "click", "pause"]

enum State { SPLASH, HOME, PLAYING, PAUSED, CLEARING, SETTLE, WIN, LOSE, PICK_HERO, WARDROBE, MAP }

var state := State.SPLASH
var state_time := 0.0
var board: Array = []
var fall_dist: Array = []
var piece_ids: Array = []  # номер уложенной фигуры для каждой клетки (0 — камень/кристалл/пусто)
var next_piece_id := 0
var has_piece := false
var piece_type := 0
var piece_cells: Array = []
var piece_pos := Vector2i.ZERO
var next_type := 0
var rng := RandomNumberGenerator.new()

# Уровень
var level := 1
var max_level := 1
var stars: Dictionary = {}       # номер уровня -> звёзды
var crystals_total := 0
var crystals_left := 0
var pieces_used := 0
var par := 0
var speed_step := 1       # ступень скорости из таблицы уровней
var level_override := {}  # для инструментов (робот-тестер): заменяет поля строки таблицы
var last_stars := 0
var score := 0
var shown_score := 0.0
var chain := 0
var big_chains := 0        # цепочек ×3 и выше в этой партии (за них — осколки)
var last_reward := {}      # начисление осколков за последнюю победу (Meta.win_reward)
var meta = Meta.new()
var screens

var fall_timer := 0.0
var lock_timer := 0.0
var lock_resets := 0
var clearing_rows: Array = []
var clear_timer := 0.0
var settle_timer := 0.0

# Эффекты
var particles: Array = []
var popups: Array = []
var motes: Array = []
var shake := 0.0
var score_bump := 0.0
var t_total := 0.0

# Звук
var music_on := true
var sfx_on := true
var sfx: Dictionary = {}
var players: Array = []
var music_player: AudioStreamPlayer

# Разметка экрана
var H := 1280.0
var board_pos := Vector2(24, 190)
var panel_x := 528.0
var buttons := {}
var pause_rect := Rect2(620, 48, 76, 76)
var menu_buttons := {}
var held := {}
var repeat_left := {}
var board_touch := {}
var sb := StyleBoxFlat.new()
var font: Font


func _ready() -> void:
	randomize()
	get_tree().set_quit_on_go_back(false)
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.5
	font = fv
	board.resize(ROWS * COLS)
	board.fill(EMPTY)
	fall_dist.resize(ROWS * COLS)
	fall_dist.fill(0)
	piece_ids.resize(ROWS * COLS)
	piece_ids.fill(0)
	screens = Screens.new(self)
	_load()
	_setup_audio()
	for i in 28:
		motes.append({"p": Vector2(randf() * W, randf() * 2000.0), "v": randf_range(8, 22), "r": randf_range(1, 3), "a": randf_range(0.1, 0.3)})
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	H = maxf(1280.0, get_viewport_rect().size.y)
	var btn_h := 116.0
	var btn_y := H - btn_h - 20.0
	var top := 160.0
	var avail := btn_y - 16.0 - top
	board_pos = Vector2(24, top + maxf(0.0, (avail - ROWS * CELL) / 2.0))
	panel_x = board_pos.x + COLS * CELL + 24.0
	var names := ["left", "right", "soft", "hard", "rotate"]
	var w := (W - 32.0 - 4 * 12.0) / 5.0
	for i in names.size():
		buttons[names[i]] = Rect2(16 + i * (w + 12), btn_y, w, btn_h)
	var mw := 460.0
	var y0 := H * 0.5 - 160.0
	var items := ["resume", "music", "sound", "restart", "menu"]
	for i in items.size():
		menu_buttons[items[i]] = Rect2((W - mw) / 2.0, y0 + i * 104.0, mw, 88)


# ---------- Звук ----------

func _setup_audio() -> void:
	for n in SFX_NAMES:
		sfx[n] = load("res://assets/sounds/%s.wav" % n)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	var m: AudioStreamOggVorbis = load("res://assets/sounds/music.ogg")
	m.loop = true
	music_player.stream = m
	music_player.volume_db = -9.0
	add_child(music_player)
	_update_music()


func play(n: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not sfx_on or players.is_empty() or not sfx.has(n):
		return
	for p in players:
		if not p.playing:
			p.stream = sfx[n]
			p.pitch_scale = pitch
			p.volume_db = vol_db
			p.play()
			return


func _update_music() -> void:
	if music_player == null:
		return
	if music_on and not music_player.playing:
		music_player.play()
	elif not music_on:
		music_player.stop()


# ---------- Уровни ----------

func start_level(n: int) -> void:
	level = n
	board.resize(ROWS * COLS)
	board.fill(EMPTY)
	fall_dist.resize(ROWS * COLS)
	fall_dist.fill(0)
	piece_ids.resize(ROWS * COLS)
	piece_ids.fill(0)
	# Параметры уровня берутся из таблицы scripts/levels.gd (кривая сложности).
	var p: Dictionary = Levels.params(n)
	p.merge(level_override, true)
	var lr := RandomNumberGenerator.new()
	lr.seed = p.seed
	var rows: int = clampi(p.rows, 1, 7)
	crystals_total = clampi(p.c, 1, 8)
	speed_step = p.speed
	for r in rows:
		var y := ROWS - 1 - r
		var holes: Array = []
		var count := 2 if lr.randf() < p.h2 else 1
		while holes.size() < count:
			var hx := lr.randi_range(0, COLS - 1)
			if not holes.has(hx):
				holes.append(hx)
		for x in COLS:
			if not holes.has(x):
				board[y * COLS + x] = STONE
	# Сначала кристаллы в самом нижнем ряду (deep), остальные — в любом камне.
	var bottom: Array = []
	var stones: Array = []
	for i in board.size():
		if board[i] == STONE:
			if i >= (ROWS - 1) * COLS:
				bottom.append(i)
			else:
				stones.append(i)
	_shuffle(bottom, lr)
	var deep: int = mini(p.deep, mini(bottom.size(), crystals_total))
	for i in deep:
		board[bottom[i]] = CRYSTAL
	stones.append_array(bottom.slice(deep))
	_shuffle(stones, lr)
	for i in crystals_total - deep:
		board[stones[i]] = CRYSTAL
	# Висячие блоки над дырами (поле hang таблицы уровней) — заготовка каскада.
	Levels.add_hang(board, p, lr, COLS, ROWS, STONE)
	# Камень и кристаллы — без номера фигуры: каждая клетка падает сама по себе.
	next_piece_id = 0
	crystals_left = crystals_total
	par = p.par
	pieces_used = 0
	score = 0
	shown_score = 0.0
	chain = 0
	big_chains = 0
	last_reward = {}
	clearing_rows.clear()
	particles.clear()
	popups.clear()
	rng.seed = randi()
	next_type = _pick_type(-1)
	_set_state(State.PLAYING)
	_spawn()


func _shuffle(a: Array, lr: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := lr.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


func _pick_type(avoid: int) -> int:
	var total := 0
	for s in SHAPES:
		total += s.w
	for attempt in 2:
		var r := rng.randi_range(0, total - 1)
		for i in SHAPES.size():
			r -= SHAPES[i].w
			if r < 0:
				if i != avoid or attempt == 1:
					return i
				break
	return 0


func fall_interval() -> float:
	return maxf(0.14, 0.9 * pow(0.94, speed_step - 1))


func _set_state(s: State) -> void:
	state = s
	state_time = 0.0


# ---------- Фигура ----------

func _spawn() -> void:
	piece_type = next_type
	next_type = _pick_type(piece_type)
	piece_cells = SHAPES[piece_type].cells.duplicate()
	var w := 0
	for c in piece_cells:
		w = maxi(w, c.x + 1)
	piece_pos = Vector2i((COLS - w) / 2, 0)
	fall_timer = 0.0
	lock_timer = 0.0
	lock_resets = 0
	has_piece = true
	if not fits(piece_cells, piece_pos):
		_lose()


func fits(cells: Array, pos: Vector2i) -> bool:
	for c in cells:
		var x: int = c.x + pos.x
		var y: int = c.y + pos.y
		if x < 0 or x >= COLS or y >= ROWS:
			return false
		if y >= 0 and board[y * COLS + x] != EMPTY:
			return false
	return true


func move(dx: int) -> bool:
	if state != State.PLAYING or not has_piece:
		return false
	if fits(piece_cells, piece_pos + Vector2i(dx, 0)):
		piece_pos.x += dx
		_moved()
		play("move", randf_range(0.97, 1.03), -4.0)
		return true
	return false


func rotate_piece() -> bool:
	if state != State.PLAYING or not has_piece:
		return false
	var n: int = SHAPES[piece_type].box
	if n == 0:
		return false
	var rotated: Array = []
	for c in piece_cells:
		rotated.append(Vector2i(n - 1 - c.y, c.x))
	for k in KICKS:
		if fits(rotated, piece_pos + k):
			piece_cells = rotated
			piece_pos += k
			_moved()
			play("rotate")
			return true
	return false


func soft_drop() -> bool:
	if state != State.PLAYING or not has_piece:
		return false
	if fits(piece_cells, piece_pos + Vector2i(0, 1)):
		piece_pos.y += 1
		fall_timer = 0.0
		return true
	return false


func hard_drop() -> void:
	if state != State.PLAYING or not has_piece:
		return
	var start_y := piece_pos.y
	while fits(piece_cells, piece_pos + Vector2i(0, 1)):
		piece_pos.y += 1
	var dist := piece_pos.y - start_y
	score += 2 * dist
	if dist > 0:
		for c in piece_cells:
			var x: float = board_pos.x + (c.x + piece_pos.x + 0.5) * CELL
			var y1: float = board_pos.y + (c.y + start_y) * CELL
			var y2: float = board_pos.y + (c.y + piece_pos.y) * CELL
			particles.append({"trail": true, "x": x, "y1": y1, "y2": y2, "col": GEMS[piece_type], "life": 0.15, "max": 0.15})
	shake = maxf(shake, 4.0)
	play("drop")
	_lock(true)


func landing_y() -> int:
	var y := piece_pos.y
	while fits(piece_cells, Vector2i(piece_pos.x, y + 1)):
		y += 1
	return y


func _moved() -> void:
	if lock_timer > 0.0 and lock_resets < MAX_LOCK_RESETS:
		lock_timer = 0.0
		lock_resets += 1


func _lock(silent := false) -> void:
	has_piece = false
	pieces_used += 1
	next_piece_id += 1
	for c in piece_cells:
		var x: int = c.x + piece_pos.x
		var y: int = c.y + piece_pos.y
		if y < 0:
			_lose()
			return
		board[y * COLS + x] = piece_type
		piece_ids[y * COLS + x] = next_piece_id
	if not silent:
		play("land")
	chain = 0
	if not _check_lines():
		_after_chain()


# ---------- Линии и каскад ----------

func _check_lines() -> bool:
	clearing_rows.clear()
	for y in ROWS:
		var full := true
		for x in COLS:
			if board[y * COLS + x] == EMPTY:
				full = false
				break
		if full:
			clearing_rows.append(y)
	if clearing_rows.is_empty():
		return false
	chain += 1
	if chain == 3:
		big_chains += 1
	var n := clearing_rows.size()
	var gained: int = LINE_SCORES[mini(n, 4)] * chain
	var freed := 0
	for y in clearing_rows:
		for x in COLS:
			var v: int = board[y * COLS + x]
			var center := board_pos + Vector2(x + 0.5, y + 0.5) * CELL
			if v == CRYSTAL:
				freed += 1
				_burst(center, CRYSTAL_COL, 16, 420.0)
			else:
				_burst(center, _cell_color(v), 6, 260.0)
	crystals_left -= freed
	gained += freed * 150
	score += gained
	score_bump = 1.0
	shake = maxf(shake, 3.0 + 3.0 * (n - 1) + 3.0 * (chain - 1))
	var mid_y: float = board_pos.y + (clearing_rows[0] + 0.5) * CELL
	var px := board_pos.x + COLS * CELL / 2.0
	if chain >= 2:
		_popup("КАСКАД ×%d" % chain, Vector2(px, mid_y - 50), ACCENT, 46)
		play("combo%d" % mini(chain - 1, 5))
	else:
		play("line%d" % mini(n, 4))
	_popup("+%d" % gained, Vector2(px, mid_y), TEXT, 38)
	if freed > 0:
		play("crystal")
		_popup("КРИСТАЛЛ!" if freed == 1 else "КРИСТАЛЛЫ ×%d" % freed, Vector2(px, mid_y + 50), CRYSTAL_COL, 36)
	_set_state(State.CLEARING)
	clear_timer = CLEAR_TIME
	return true


func _finish_clear() -> void:
	var lowest: int = clearing_rows.max()
	Gravity.clear_rows(board, piece_ids, clearing_rows, COLS, EMPTY)
	# Каскад, «липкая» гравитация (scripts/gravity.gd): клетки одной фигуры держатся
	# вместе, камень и кристаллы падают поодиночке. Все группы поля падают, пока могут.
	var fall := Gravity.settle(board, piece_ids, COLS, ROWS, EMPTY, [STONE, CRYSTAL], -1 if FALL_ALL else lowest)
	var moved := false
	for i in fall.size():
		fall_dist[i] = fall[i]
		if fall[i] > 0:
			moved = true
	clearing_rows.clear()
	_set_state(State.SETTLE)
	settle_timer = SETTLE_TIME if moved else 0.0


func _after_chain() -> void:
	if crystals_left <= 0:
		_win()
	else:
		_set_state(State.PLAYING)
		_spawn()


func _win() -> void:
	has_piece = false
	last_stars = 3 if pieces_used <= par else (2 if pieces_used <= int(par * 1.4) else 1)
	last_reward = Meta.win_reward(not stars.has(level), stars.get(level, 0), last_stars, big_chains)
	meta.shards += last_reward.total
	stars[level] = maxi(stars.get(level, 0), last_stars)
	max_level = maxi(max_level, level + 1)
	_save()
	_set_state(State.WIN)
	if screens:
		screens.poke_hero()
	play("levelup")
	for i in 60:
		var c: Color = GEMS[i % GEMS.size()]
		particles.append({"p": Vector2(randf() * W, H * 0.35), "v": Vector2(randf_range(-200, 200), randf_range(-500, -100)),
			"col": c, "life": randf_range(1.0, 1.8), "max": 1.8, "rot": randf() * TAU, "s": randf_range(5, 10)})


func _lose() -> void:
	has_piece = false
	_set_state(State.LOSE)
	play("gameover")


func step(delta: float) -> void:
	state_time += delta
	match state:
		State.SPLASH:
			if state_time > 2.0:
				go_home()
		State.PLAYING:
			if not has_piece:
				return
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
		State.SETTLE:
			settle_timer -= delta
			if settle_timer <= 0.0:
				fall_dist.fill(0)
				if not _check_lines():
					_after_chain()


# ---------- Сохранение ----------

## Домой; при первом запуске (герой не выбран) — экран «Выбери друга».
func go_home() -> void:
	_set_state(State.HOME if meta.hero != "" else State.PICK_HERO)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		max_level = cfg.get_value("progress", "max_level", 1)
		stars = cfg.get_value("progress", "stars", {})
		music_on = cfg.get_value("settings", "music", true)
		sfx_on = cfg.get_value("settings", "sfx", true)
	meta.load_from(cfg)  # старое сохранение без [meta] — значения по умолчанию
	# Подарок игрокам версий до 0.6: осколки за уже пройденное (один раз, пока нет раздела [meta]).
	if not cfg.has_section("meta") and max_level > 1:
		meta.shards += legacy_gift(total_stars())
		_save()
	level = max_level


static func legacy_gift(total: int) -> int:
	return 30 + total * 5


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "max_level", max_level)
	cfg.set_value("progress", "stars", stars)
	cfg.set_value("settings", "music", music_on)
	cfg.set_value("settings", "sfx", sfx_on)
	meta.save_to(cfg)
	cfg.save(SAVE_PATH)


func total_stars() -> int:
	var t := 0
	for k in stars:
		t += stars[k]
	return t


# ---------- Эффекты ----------

func _burst(at: Vector2, col: Color, count: int, speed: float) -> void:
	for i in count:
		var a := randf() * TAU
		particles.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(speed * 0.3, speed),
			"col": col, "life": randf_range(0.4, 0.7), "max": 0.7, "rot": randf() * TAU, "s": randf_range(4, 9)})


func _popup(text: String, at: Vector2, col: Color, size: int) -> void:
	popups.append({"text": text, "p": at, "col": col, "size": size, "life": 0.9})


func _update_effects(delta: float) -> void:
	t_total += delta
	shake = maxf(0.0, shake - delta * 30.0)
	score_bump = maxf(0.0, score_bump - delta * 4.0)
	shown_score = move_toward(shown_score, score, maxf(5.0, absf(score - shown_score) * delta * 8.0))
	for p in particles:
		p.life -= delta
		if not p.has("trail"):
			p.v.y += 900.0 * delta
			p.p += p.v * delta
			p.rot += delta * 6.0
	particles = particles.filter(func(p): return p.life > 0.0)
	for p in popups:
		p.life -= delta
		p.p.y -= 50.0 * delta
	popups = popups.filter(func(p): return p.life > 0.0)
	var speed := 1.0 + (2.0 if chain >= 2 else 0.0)
	for m in motes:
		m.p.y -= m.v * speed * delta
		if m.p.y < -10:
			m.p = Vector2(randf() * W, H + 10)


# ---------- Ввод ----------

func _process(delta: float) -> void:
	step(delta)
	_update_effects(delta)
	screens.update(delta)
	for idx in held.keys():
		var n: String = held[idx]
		if n in ["left", "right", "soft"]:
			repeat_left[idx] -= delta
			if repeat_left[idx] <= 0.0:
				repeat_left[idx] = REPEAT_RATE
				_press(n)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if state == State.PLAYING:
			_set_state(State.PAUSED)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		match state:
			State.PLAYING, State.CLEARING, State.SETTLE:
				_set_state(State.PAUSED)
			State.PAUSED, State.WIN, State.LOSE, State.MAP, State.WARDROBE:
				go_home()
			State.PICK_HERO:
				if meta.hero != "":
					go_home()
				else:
					get_tree().quit()
			_:
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
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)


func _key(e: InputEventKey) -> void:
	match e.keycode:
		KEY_LEFT: _press("left")
		KEY_RIGHT: _press("right")
		KEY_DOWN: _press("soft")
		KEY_UP: _press("rotate")
		KEY_SPACE: _press("hard")
		KEY_P, KEY_ESCAPE:
			if state == State.PLAYING:
				_set_state(State.PAUSED)
			elif state == State.PAUSED:
				_set_state(State.PLAYING)
		KEY_ENTER:
			if state == State.HOME:
				start_level(max_level)


func _press(n: String) -> void:
	match n:
		"left": move(-1)
		"right": move(1)
		"soft": soft_drop()
		"hard": hard_drop()
		"rotate": rotate_piece()


func _touch_down(idx: int, pos: Vector2) -> void:
	match state:
		State.SPLASH:
			go_home()
			return
		State.HOME:
			screens.tap_home(pos)
			return
		State.PICK_HERO:
			screens.tap_pick(pos)
			return
		State.WARDROBE:
			screens.tap_wardrobe(pos)
			return
		State.MAP:
			screens.map_down(idx, pos)
			return
		State.WIN, State.LOSE:
			screens.tap_end(pos)
			return
		State.PAUSED:
			_pause_menu_tap(pos)
			return
	if pause_rect.grow(12).has_point(pos):
		if state == State.PLAYING:
			play("pause")
			_set_state(State.PAUSED)
		return
	for n in buttons:
		if buttons[n].has_point(pos):
			held[idx] = n
			repeat_left[idx] = REPEAT_DELAY
			_press(n)
			return
	if pos.y < buttons["left"].position.y - 8:
		board_touch[idx] = {"start": pos, "ax": pos.x, "ay": pos.y, "t": Time.get_ticks_msec() / 1000.0, "moved": false}


func _pause_menu_tap(pos: Vector2) -> void:
	for n in menu_buttons:
		if menu_buttons[n].has_point(pos):
			play("click")
			match n:
				"resume": _set_state(State.PLAYING)
				"music":
					music_on = not music_on
					_update_music()
					_save()
				"sound":
					sfx_on = not sfx_on
					_save()
				"restart": start_level(level)
				"menu": go_home()
			return


func _touch_drag(idx: int, pos: Vector2) -> void:
	if state == State.MAP:
		screens.map_drag(idx, pos)
		return
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
	if state == State.MAP:
		screens.map_up(idx, pos)
		return
	if not board_touch.has(idx):
		return
	var t: Dictionary = board_touch[idx]
	board_touch.erase(idx)
	var d: Vector2 = pos - t.start
	var dt: float = Time.get_ticks_msec() / 1000.0 - t.t
	if d.y > 140 and dt < 0.3 and absf(d.y) > absf(d.x) * 2:
		hard_drop()
	elif not t.moved and d.length() < 24:
		rotate_piece()


# ---------- Отрисовка ----------

func _cell_color(v: int) -> Color:
	if v == STONE:
		return STONE_COL
	if v == CRYSTAL:
		return CRYSTAL_COL
	return GEMS[v]


func _rbox(r: Rect2, col: Color, radius: float) -> void:
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.draw(get_canvas_item(), r)


func _draw() -> void:
	if state == State.SPLASH:
		_draw_splash()
		return
	match state:
		State.HOME:
			screens.draw_home()
			return
		State.PICK_HERO, State.WARDROBE, State.MAP:
			_draw_background()
			if state == State.PICK_HERO:
				screens.draw_pick()
			elif state == State.WARDROBE:
				screens.draw_wardrobe()
			else:
				screens.draw_map()
			return
	_draw_background()
	var off := Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) if shake > 0.0 else Vector2.ZERO
	draw_set_transform(off)
	_draw_header()
	_draw_board()
	_draw_panel()
	draw_set_transform(Vector2.ZERO)
	_draw_controls()
	_draw_effects()
	_draw_overlay()


func _draw_background() -> void:
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	var c := board_pos + Vector2(COLS, ROWS) * CELL / 2.0
	for i in 5:
		draw_circle(c, 520.0 - i * 90.0, Color(0.165, 0.102, 0.31, 0.12))
	for m in motes:
		draw_circle(m.p, m.r, Color(0.85, 0.8, 1.0, m.a))


func _draw_title(at: Vector2, size: int, wave: float) -> void:
	var word := "CASCADO"
	var total := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := at.x - total / 2.0 if at.x > 0 else 24.0
	for i in word.length():
		var ch := word[i]
		var y := at.y + sin(t_total * 3.0 + i * 0.7) * wave
		draw_string(font, Vector2(x + 2, y + 3), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.35))
		draw_string(font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, GEMS[i % GEMS.size()])
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _draw_header() -> void:
	_draw_title(Vector2(-1, 100), 52, 0.0)
	_rbox(pause_rect, BTN, 18)
	var pc := pause_rect.get_center()
	draw_rect(Rect2(pc + Vector2(-14, -16), Vector2(10, 32)), TEXT)
	draw_rect(Rect2(pc + Vector2(4, -16), Vector2(10, 32)), TEXT)


func _draw_board() -> void:
	var bsize := Vector2(COLS * CELL, ROWS * CELL)
	_rbox(Rect2(board_pos - Vector2(8, 8), bsize + Vector2(16, 16)), Color(0.27, 0.19, 0.48, 0.5), 18)
	_rbox(Rect2(board_pos - Vector2(4, 4), bsize + Vector2(8, 8)), FIELD, 14)
	for x in range(1, COLS):
		draw_line(board_pos + Vector2(x * CELL, 0), board_pos + Vector2(x * CELL, bsize.y), Color(1, 1, 1, 0.04), 1.0)
	for y in range(1, ROWS):
		draw_line(board_pos + Vector2(0, y * CELL), board_pos + Vector2(bsize.x, y * CELL), Color(1, 1, 1, 0.04), 1.0)

	# Опасность: блоки близко к верху
	var danger := false
	for i in COLS * 3:
		if board.size() > i and board[i] != EMPTY:
			danger = true
			break
	if danger:
		var a := 0.15 + 0.1 * sin(t_total * 6.0)
		draw_polygon(PackedVector2Array([board_pos, board_pos + Vector2(bsize.x, 0), board_pos + Vector2(bsize.x, CELL * 3), board_pos + Vector2(0, CELL * 3)]),
			PackedColorArray([Color(1, 0.3, 0.43, a), Color(1, 0.3, 0.43, a), Color(1, 0.3, 0.43, 0), Color(1, 0.3, 0.43, 0)]))

	# Подсветка колонок, куда упадёт фигура
	if has_piece and state == State.PLAYING:
		var ly := landing_y()
		var col: Color = GEMS[piece_type]
		var cols := {}
		for c in piece_cells:
			cols[c.x] = maxi(cols.get(c.x, -99), c.y)
		for cx in cols:
			var top_y: float = piece_pos.y + cols[cx] + 1
			var bot_y: float = ly + cols[cx] + 1
			if bot_y > top_y:
				var x: float = board_pos.x + (cx + piece_pos.x) * CELL
				draw_rect(Rect2(x + 4, board_pos.y + top_y * CELL, CELL - 8, (bot_y - top_y) * CELL), Color(col, 0.08))
				draw_rect(Rect2(x + 6, board_pos.y + bot_y * CELL - 5, CELL - 12, 4), Color(col, 0.5))

	var settle_k := clampf(settle_timer / SETTLE_TIME, 0.0, 1.0) if state == State.SETTLE else 0.0
	for y in ROWS:
		for x in COLS:
			var v: int = board[y * COLS + x]
			if v == EMPTY:
				continue
			var dy: float = fall_dist[y * COLS + x] * settle_k * settle_k
			_draw_block(board_pos + Vector2(x, y - dy) * CELL, CELL, v)

	if state == State.CLEARING:
		var k := clampf(clear_timer / CLEAR_TIME, 0.0, 1.0)
		for y in clearing_rows:
			var h := CELL * k
			draw_rect(Rect2(board_pos + Vector2(0, y * CELL + (CELL - h) / 2.0), Vector2(bsize.x, h)), Color(1, 1, 1, 0.85 * k))

	if has_piece and state != State.LOSE:
		for c in piece_cells:
			var p := Vector2i(c.x + piece_pos.x, c.y + piece_pos.y)
			if p.y >= 0:
				_draw_block(board_pos + Vector2(p) * CELL, CELL, piece_type, true)


func _draw_block(p: Vector2, s: float, v: int, glow := false) -> void:
	var col := _cell_color(v)
	var r := Rect2(p + Vector2(3, 3), Vector2(s - 6, s - 6))
	var rad := s * 0.18
	if v == CRYSTAL:
		_rbox(r, Color("#2B2148"), rad)
		var c := r.get_center()
		var pulse := 0.5 + 0.5 * sin(t_total * 4.0 + p.x * 0.05)
		draw_circle(c, s * 0.42, Color(CRYSTAL_COL, 0.10 + 0.08 * pulse))
		var hs := s * 0.3
		var gem := PackedVector2Array([c + Vector2(0, -hs), c + Vector2(hs * 0.75, -hs * 0.2), c + Vector2(0, hs), c + Vector2(-hs * 0.75, -hs * 0.2)])
		draw_colored_polygon(gem, CRYSTAL_COL)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -hs), c + Vector2(hs * 0.75, -hs * 0.2), c + Vector2(0, -hs * 0.05)]), Color(1, 1, 1, 0.6))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, hs), c + Vector2(hs * 0.75, -hs * 0.2), c + Vector2(0, -hs * 0.05)]), Color(0, 0.3, 0.45, 0.35))
		var sp := c + Vector2(-hs * 0.55, -hs * 0.65)
		var sl := 3.0 + 4.0 * pulse
		draw_line(sp - Vector2(sl, 0), sp + Vector2(sl, 0), Color(1, 1, 1, 0.9), 2.0)
		draw_line(sp - Vector2(0, sl), sp + Vector2(0, sl), Color(1, 1, 1, 0.9), 2.0)
		return
	if glow:
		_rbox(r.grow(5), Color(col, 0.16), rad + 5)
	_rbox(r, col.darkened(0.35), rad)
	_rbox(Rect2(r.position, r.size - Vector2(0, 5)), col, rad)
	if v == STONE:
		draw_line(r.position + Vector2(10, 14), r.position + Vector2(22, 24), Color(0, 0, 0, 0.25), 2.0)
		return
	var tl := r.position + Vector2(rad * 0.6, rad * 0.6)
	draw_colored_polygon(PackedVector2Array([tl, tl + Vector2(r.size.x * 0.45, 0), tl + Vector2(0, r.size.y * 0.45)]), Color(1, 1, 1, 0.28))
	var bl := r.position + Vector2(r.size.x * 0.72, r.size.y * 0.22)
	draw_colored_polygon(PackedVector2Array([bl + Vector2(0, -4), bl + Vector2(4, 0), bl + Vector2(0, 4), bl + Vector2(-4, 0)]), Color(1, 1, 1, 0.75))


func _draw_panel() -> void:
	var pw := W - panel_x - 20.0
	var y := board_pos.y + 4.0
	draw_string(font, Vector2(panel_x, y + 20), "ДАЛЕЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, DIM)
	var box := Rect2(panel_x, y + 34, pw, 130)
	_rbox(box, BTN, 18)
	if true:
		var s: Dictionary = SHAPES[next_type]
		var mn := Vector2(99, 99)
		var mx := Vector2(-99, -99)
		for c in s.cells:
			mn = mn.min(Vector2(c))
			mx = mx.max(Vector2(c))
		var cs := 30.0
		var origin := box.get_center() - (mx - mn + Vector2.ONE) * cs / 2.0 - mn * cs
		for c in s.cells:
			_draw_block(origin + Vector2(c) * cs, cs, next_type)

	y += 220.0
	draw_string(font, Vector2(panel_x, y), "КРИСТАЛЛЫ", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, DIM)
	_draw_block(Vector2(panel_x - 6, y + 10), 56, CRYSTAL)
	draw_string(font, Vector2(panel_x + 52, y + 52), "%d/%d" % [crystals_total - crystals_left, crystals_total], HORIZONTAL_ALIGNMENT_LEFT, -1, 38, CRYSTAL_COL)

	var bump := 1.0 + 0.25 * score_bump
	var stats := [["СЧЁТ", str(int(shown_score)), 40 * bump], ["УРОВЕНЬ", str(level), 40], ["ФИГУРЫ", "%d" % pieces_used, 40]]
	for i in stats.size():
		var sy := y + 130.0 + i * 100.0
		draw_string(font, Vector2(panel_x, sy), stats[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, DIM)
		draw_string(font, Vector2(panel_x, sy + 46), stats[i][1], HORIZONTAL_ALIGNMENT_LEFT, pw, int(stats[i][2]), ACCENT if i == 0 else TEXT)


func _draw_controls() -> void:
	var pressed := held.values()
	for n in buttons:
		var r: Rect2 = buttons[n]
		_rbox(r, BTN_DOWN if pressed.has(n) else BTN, 22)
		var c := r.get_center()
		var s := 22.0
		match n:
			"left":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(s * 0.7, -s), c + Vector2(s * 0.7, s)]), TEXT)
			"right":
				draw_colored_polygon(PackedVector2Array([c + Vector2(s, 0), c + Vector2(-s * 0.7, -s), c + Vector2(-s * 0.7, s)]), TEXT)
			"soft":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, s), c + Vector2(-s, -s * 0.7), c + Vector2(s, -s * 0.7)]), TEXT)
			"hard":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.4), c + Vector2(-s, -s), c + Vector2(s, -s)]), ACCENT)
				draw_rect(Rect2(c + Vector2(-s, s * 0.7), Vector2(2 * s, 7)), ACCENT)
			"rotate":
				var rad := s * 0.85
				draw_arc(c, rad, deg_to_rad(-60), deg_to_rad(220), 24, TEXT, 6.0, true)
				var a := deg_to_rad(220)
				var p := c + Vector2(cos(a), sin(a)) * rad
				var t := Vector2(-sin(a), cos(a))
				var nn := Vector2(cos(a), sin(a))
				draw_colored_polygon(PackedVector2Array([p + t * 13, p + nn * 11, p - nn * 11]), TEXT)


func _draw_effects() -> void:
	for p in particles:
		var a: float = clampf(p.life / p.max, 0.0, 1.0)
		if p.has("trail"):
			draw_rect(Rect2(p.x - 6, p.y1, 12, p.y2 - p.y1), Color(p.col, 0.35 * a))
			continue
		var s: float = p.s
		var pts := PackedVector2Array()
		for k in 4:
			var ang: float = p.rot + k * PI / 2.0
			pts.append(p.p + Vector2(cos(ang), sin(ang)) * (s if k % 2 == 0 else s * 0.55))
		draw_colored_polygon(pts, Color(p.col, a))
	for p in popups:
		var age: float = 0.9 - p.life
		var sc: float = 0.6 + minf(age / 0.12, 1.0) * 0.55
		if age > 0.12:
			sc = 1.15 - minf((age - 0.12) / 0.1, 1.0) * 0.15
		var size := int(p.size * sc)
		var a: float = clampf(p.life / 0.4, 0.0, 1.0)
		var pos := Vector2(0, p.p.y)
		for o in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3)]:
			draw_string(font, pos + o, p.text, HORIZONTAL_ALIGNMENT_CENTER, board_pos.x * 2 + COLS * CELL, size, Color(0.07, 0.04, 0.14, a))
		draw_string(font, pos, p.text, HORIZONTAL_ALIGNMENT_CENTER, board_pos.x * 2 + COLS * CELL, size, Color(p.col, a))


func _draw_star(c: Vector2, r: float, filled: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * (r if i % 2 == 0 else r * 0.45))
	if filled:
		draw_colored_polygon(pts, ACCENT)
	else:
		pts.append(pts[0])
		draw_polyline(pts, Color(DIM, 0.6), 3.0, true)


func _center_text(text: String, y: float, size: int, col: Color) -> void:
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, W, size, col)


func _draw_overlay() -> void:
	match state:
		State.PAUSED:
			draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.03, 0.1, 0.85))
			_center_text("ПАУЗА", menu_buttons["resume"].position.y - 50, 60, TEXT)
			var labels := {"resume": "Продолжить", "music": "Музыка: " + ("вкл" if music_on else "выкл"),
				"sound": "Звуки: " + ("вкл" if sfx_on else "выкл"), "restart": "Начать уровень заново", "menu": "Домой"}
			for n in menu_buttons:
				var r: Rect2 = menu_buttons[n]
				_rbox(r, ACCENT if n == "resume" else BTN, 24)
				draw_string(font, Vector2(r.position.x, r.get_center().y + 13), labels[n], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, Color("#2A1A0A") if n == "resume" else TEXT)
		State.WIN:
			screens.draw_win()
		State.LOSE:
			screens.draw_lose()


func _draw_splash() -> void:
	draw_rect(Rect2(0, 0, W, H), BG_TOP)
	var a := clampf(state_time / 0.3, 0.0, 1.0) * clampf((2.0 - state_time) / 0.3, 0.0, 1.0)
	var c := Vector2(W / 2.0, H * 0.42)
	draw_circle(c, 150, Color(0.165, 0.102, 0.31, a))
	# Брови-«ушки» совы
	draw_colored_polygon(PackedVector2Array([c + Vector2(-120, -70), c + Vector2(-40, -78), c + Vector2(-105, -140)]), Color(DIM, a))
	draw_colored_polygon(PackedVector2Array([c + Vector2(120, -70), c + Vector2(40, -78), c + Vector2(105, -140)]), Color(DIM, a))
	# Глаза: моргают в 0.7 с
	var blink := 1.0
	if state_time > 0.7 and state_time < 0.9:
		blink = absf(state_time - 0.8) / 0.1
	var lit := clampf((state_time - 0.9) / 0.3, 0.0, 1.0)
	for sx in [-1.0, 1.0]:
		var e: Vector2 = c + Vector2(sx * 58, -10)
		draw_set_transform(e, 0.0, Vector2(1, maxf(blink, 0.05)))
		draw_arc(Vector2.ZERO, 44, 0, TAU, 48, Color(TEXT, a), 8.0, true)
		draw_circle(Vector2.ZERO, 16, Color(ACCENT, a * (0.4 + 0.6 * lit)))
		draw_circle(Vector2.ZERO, 26, Color(ACCENT, a * 0.25 * lit))
		draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 40), c + Vector2(12, 40), c + Vector2(0, 62)]), Color(ACCENT, a))
	draw_string(font, Vector2(0, c.y + 250), "OWLIGHT", HORIZONTAL_ALIGNMENT_CENTER, W, 64, Color(TEXT, a))
	draw_string(font, Vector2(0, c.y + 300), "G A M E S", HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(DIM, a))
