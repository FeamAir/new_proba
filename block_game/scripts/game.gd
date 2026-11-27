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
const BOMB := 9      # 0.18: огненный кристалл в камне — взрыв 3×3 при очистке ряда (Specials.BOMB)
const PET := 10      # 0.18: кротёнок — довести до нижнего ряда (Specials.PET)
const CHEST := 11    # 0.18: янтарный тайник 2×2 (Specials.CHEST)

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
## Тексты на разных языках (английский, русский): scripts/i18n.gd
const I18n := preload("res://scripts/i18n.gd")
## 0.9: обучение (scripts/tutorial.gd), помощь и счётчик попыток (scripts/assist.gd, assist_ui.gd)
const Tutorial := preload("res://scripts/tutorial.gd")
const Assist := preload("res://scripts/assist.gd")
const AssistUI := preload("res://scripts/assist_ui.gd")
## 0.12: Кристальная кузница (scripts/forge_ui.gd)
const ForgeUI := preload("res://scripts/forge_ui.gd")
## 0.12b: окно «Гардероб обновлён», окно имени, 0.16: подсказка о своём гардеробе (scripts/notice_ui.gd)
const NoticeUI := preload("res://scripts/notice_ui.gd")
const Home3D := preload("res://scripts/home3d/home3d.gd")  # 0.12: 3D-дома
const TrophyUI := preload("res://scripts/trophy_ui.gd")  # 0.14: кубки залов
const DecorateUI := preload("res://scripts/decorate_ui.gd")  # 0.15: режим украшения комнаты
## 0.17: герой рядом с полем (scripts/play_hero.gd) и «Удобство» (scripts/access.gd, access_ui.gd)
const PlayHero := preload("res://scripts/play_hero.gd")
const Access := preload("res://scripts/access.gd")
const AccessUI := preload("res://scripts/access_ui.gd")
## Ссылка на политику конфиденциальности в паузе (адрес — Privacy.URL)
const Privacy := preload("res://scripts/privacy.gd")
## 0.17: после победы/поражения герой на панели празднует/грустит, затем появляется окно итога
const RESULT_BEAT := 0.75
const HomeTour := preload("res://scripts/home_tour.gd")  # 0.17: экскурсия по главному экрану
## 0.18: праздник каскада (scripts/juice.gd), облачко героя (hero_say.gd), «Совиное время» — отмена
## фигуры (owl_time.gd), строка «до 3 звёзд» на панели (star_goal.gd)
const Juice := preload("res://scripts/juice.gd")
const HeroSay := preload("res://scripts/hero_say.gd")
const OwlTime := preload("res://scripts/owl_time.gd")
const StarGoal := preload("res://scripts/star_goal.gd")
## 0.18: новинки уровней — кристалл-бомба, цель «Спаси кротёнка», «Янтарный тайник»
## (правила — scripts/specials.gd, рисование — scripts/specials_draw.gd)
const Specials := preload("res://scripts/specials.gd")
const SpecialsDraw := preload("res://scripts/specials_draw.gd")
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
	"combo1", "combo2", "combo3", "combo4", "combo5", "crystal", "levelup", "gameover", "click", "pause", "boom"]

enum State { SPLASH, HOME, PLAYING, PAUSED, CLEARING, SETTLE, WIN, LOSE, PICK_HERO, WARDROBE, MAP, FORGE }

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
var speed_step := 1       # ступень скорости: база зала + разгон по времени (Levels.speed_at)
var level_time := 0.0     # 0.18: секунды игры в уровне (без паузы, каскада и шагов обучения)
var speed_base := 1       # 0.18: ступень на старте уровня (Levels.base_speed)
var speed_ramp := 15.0    # 0.18: секунд на одну ступень разгона (Levels.ramp_sec / поле ramp)
var level_override := {}  # для инструментов (робот-тестер): заменяет поля строки таблицы
var last_stars := 0
var score := 0
var shown_score := 0.0
var chain := 0
var big_chains := 0        # цепочек ×3 и выше в этой партии (за них — осколки)
var last_reward := {}      # начисление осколков за последнюю победу (Meta.win_reward)
var meta = Meta.new()
var screens
var tut = Tutorial.new()      # 0.9: обучение
var tour = HomeTour.new()     # 0.17: экскурсия по главному экрану
var assist = Assist.new()     # 0.9: помощь, попытки, подарок новичку
var assist_ui
var forge_ui                  # 0.12: Кристальная кузница
var notice_ui                 # 0.12b: сообщение об обновлении гардероба, имя друга; 0.16: подсказка при первой смене друга
var home3d                    # 0.12: 3D-дом на экране «Дом» (scripts/home3d/home3d.gd)
var trophy_ui                 # 0.14: «Новый кубок!», кнопка «Кубки», полка славы 2D
var decor_ui                  # 0.15: режим украшения комнаты (scripts/decorate_ui.gd)
var play_hero = PlayHero.new()  # 0.17: герой на панели уровня
var access = Access.new()       # 0.17: настройки «Удобство»
var access_ui                   # 0.17: окно «Удобство» в паузе
var privacy                     # ссылка «Конфиденциальность» в паузе (scripts/privacy.gd)
var juice                       # 0.18: праздник каскада
var say = HeroSay.new()         # 0.18: облачко с фразой героя
var owl = OwlTime.new()         # 0.18: «Совиное время» — одна отмена за попытку
var _snapped := false           # 0.18: снимок для отмены уже сделан (сброс фигуры)
var boom_fx = SpecialsDraw.new()  # 0.18: вспышки взрывов и открытия тайника (только эффекты)

# 0.18: цель уровня и новинки (простые значения — «Совиное время» их снимает и возвращает)
var goal := "crystals"          # "crystals" — освободить кристаллы, "pet" — кротёнок на дне, "chest" — открыть тайник
var bombs_total := 0            # кристаллов-бомб на старте
var bombs_blown := 0            # взорвалось в этой попытке
var chest_total := 0            # клеток тайника на старте (4 или 0 — тайника нет)
var chest_left := 0             # клеток тайника на поле
var chest_open := false
var chest_shards := 0           # осколков в тайнике (3–5), прибавляются к награде за победу
var blast_cells: Array = []     # клетки вне очищаемых рядов, которые выбьет взрыв (на время CLEARING)
var blast_bombs: Array = []     # центры взорвавшихся бомб (Vector2i)

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


func _init() -> void:
	juice = Juice.new(self)  # 0.18: и без _ready (тесты, робот-тестер)


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
	assist_ui = AssistUI.new(self)
	forge_ui = ForgeUI.new(self)
	notice_ui = NoticeUI.new(self)
	trophy_ui = TrophyUI.new(self)
	decor_ui = DecorateUI.new(self)
	access_ui = AccessUI.new(self)
	privacy = Privacy.new(self)
	play_hero.setup(self)  # 0.17: картинка героя панели (перерисовывается 20–30 раз в секунду)
	home3d = Home3D.new()
	home3d.name = "Home3D"
	add_child(home3d)
	home3d.setup(self)
	_load()
	_setup_audio()
	for i in 28:
		motes.append({"p": Vector2(randf() * W, randf() * 2000.0), "v": randf_range(8, 22), "r": randf_range(1, 3), "a": randf_range(0.1, 0.3)})
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	H = maxf(1280.0, get_viewport_rect().size.y) if is_inside_tree() else 1280.0
	var btn_h := 116.0
	var btn_y := H - btn_h - 20.0
	var top := 160.0
	var avail := btn_y - 16.0 - top
	board_pos = Vector2(24, top + maxf(0.0, (avail - ROWS * CELL) / 2.0))
	panel_x = board_pos.x + COLS * CELL + 24.0
	# 0.17: «для левшей» — зеркально: поворот и сброс слева, стрелки справа
	var names := ["rotate", "hard", "soft", "left", "right"] if access.lefty else ["left", "right", "soft", "hard", "rotate"]
	var w := (W - 32.0 - 4 * 12.0) / 5.0
	for i in names.size():
		buttons[names[i]] = Rect2(16 + i * (w + 12), btn_y, w, btn_h)
	var mw := 480.0
	var y0 := H * 0.5 - 330.0
	var items := ["resume", "music", "sound", "language", "graphics", "access", "tutorial", "restart", "menu"]
	menu_buttons.clear()
	for i in items.size():
		menu_buttons[items[i]] = Rect2((W - mw) / 2.0, y0 + i * 86.0, mw, 74)


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
	speed_base = p.base
	speed_ramp = p.ramp
	level_time = 0.0
	speed_step = Levels.speed_at(speed_base, speed_ramp, 0.0)
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
	# 0.18: бомбы, кротёнок, тайник — своим генератором случайных чисел после всей прежней раскладки
	var sp: Dictionary = Specials.place(board, p, COLS, ROWS)
	goal = Specials.goal_of(p)
	if (goal == Specials.GOAL_PET and sp.pet < 0) or (goal == Specials.GOAL_CHEST and sp.chest < 0):
		goal = Specials.GOAL_CRYSTALS  # не поместилось — обычная цель (тест следит, чтобы такого не было)
	bombs_total = sp.bombs
	bombs_blown = 0
	chest_shards = sp.shards
	chest_open = false
	blast_cells = []
	blast_bombs = []
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
	_apply_assist(n, sp.chest % COLS if sp.chest >= 0 else -1)
	# тайник держится одной группой (падает целиком)
	Specials.tag_chest(board, piece_ids)
	chest_left = Specials.count(board, CHEST)
	chest_total = 4 if chest_left > 0 else 0
	boom_fx.reset()
	if goal != Specials.GOAL_CRYSTALS:
		_popup(I18n.t("goal_" + goal + "_start"), board_pos + Vector2(COLS * CELL / 2.0, 5 * CELL), ACCENT, 38)
	play_hero.reset()
	juice.reset()
	say.reset()
	owl.reset()
	_snapped = false
	tut.on_start(self)
	if tut.wants_first_piece(n):
		next_type = Tutorial.FIRST_PIECE
	_set_state(State.PLAYING)
	_spawn()


## 0.9: попытка засчитывается; принятая «Подсказка кристалла» убирает нижние ряды камня.
## 0.18: на уровне «открой тайник» остаются хотя бы 2 ряда камня, а убранный вместе с рядами
## тайник снова встаёт в два нижних ряда (chest_x — его колонка).
func _apply_assist(n: int, chest_x := -1) -> void:
	var rows: int = assist.on_start(n)
	if rows <= 0:
		return
	var keep := 2 if goal == Specials.GOAL_CHEST else 1
	var res: Dictionary = Assist.apply_boost(board, COLS, ROWS, EMPTY, CRYSTAL, rows, crystals_total, keep, STONE)
	if goal == Specials.GOAL_CHEST and chest_x >= 0 and Specials.count(board, CHEST) < 4:
		for i in board.size():
			if board[i] == CHEST:
				board[i] = STONE
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			board[(ROWS - 2 + d.y) * COLS + chest_x + d.x] = CHEST
	crystals_left = Specials.count(board, CRYSTAL)
	if res.rows > 0:
		_popup(I18n.t("boost_popup"), board_pos + Vector2(COLS * CELL / 2.0, (ROWS - 4) * CELL), CRYSTAL_COL, 34)


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


## 0.18: разгон внутри уровня. Время идёт только в состоянии PLAYING (пауза, каскад
## и шаги обучения не считаются); каждые speed_ramp секунд — ступень быстрее, до Levels.SPEED_CAP.
func _tick_speed(delta: float) -> void:
	level_time += delta
	var s: int = Levels.speed_at(speed_base, speed_ramp, level_time)
	if s > speed_step:
		speed_step = s
		_popup(I18n.t("faster"), board_pos + Vector2(COLS * CELL / 2.0, 3 * CELL), ACCENT, 34)


func fall_interval() -> float:
	return access.fall(maxf(0.14, 0.9 * pow(0.94, speed_step - 1)))  # 0.17: «медленное падение» ×0.7


## 0.17: поле почти заполнено — блоки в трёх верхних рядах (красная подсветка, испуг героя)
func in_danger() -> bool:
	for i in COLS * 3:
		if board.size() > i and board[i] != EMPTY:
			return true
	return false


func _set_state(s: State) -> void:
	if s != State.HOME and decor_ui and decor_ui.active:
		decor_ui.active = false  # 0.15: ушли с экрана «Дом» — режим украшения закрывается
		decor_ui.tryon.clear()
		decor_ui.spot = ""
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
	else:
		tut.on_spawn(self)


## 0.18: после отмены («Совиное время») — та же фигура снова сверху (следующая не меняется).
func _respawn_same() -> void:
	piece_cells = SHAPES[piece_type].cells.duplicate()
	var w := 0
	for c in piece_cells:
		w = maxi(w, c.x + 1)
	piece_pos = Vector2i((COLS - w) / 2, 0)
	fall_timer = 0.0
	lock_timer = 0.0
	lock_resets = 0
	has_piece = true
	_set_state(State.PLAYING)


## 0.18: «Совиное время» — отменить последнюю фигуру (кнопка с песочными часами). true — отменено.
func undo_piece() -> bool:
	if not owl.undo(self):
		return false
	particles.clear()
	juice.reset()
	play_hero.reset()
	play("rotate", 0.7)
	play("crystal", 0.6, -6.0)
	return true


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
		tut.on_action(self, "move")
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
			tut.on_action(self, "rotate")
			return true
	return false


func soft_drop() -> bool:
	if state != State.PLAYING or not has_piece:
		return false
	if fits(piece_cells, piece_pos + Vector2i(0, 1)):
		piece_pos.y += 1
		fall_timer = 0.0
		tut.on_action(self, "soft")
		return true
	return false


func hard_drop() -> void:
	if state != State.PLAYING or not has_piece:
		return
	owl.take(self)  # 0.18: снимок до очков за сброс
	_snapped = true
	juice.on_drop()
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
	if not _snapped:
		owl.take(self)  # 0.18: снимок для «Совиного времени» — до фиксации
	_snapped = false
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
	tut.on_action(self, "lock")
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
	# 0.18: бомбы в очищаемых рядах взрываются (3×3, цепочкой) — клетки вне рядов тоже исчезают.
	# Каждый взрыв — ещё одно звено каскада (Specials.links): ряд с бомбой — уже ×2.
	var bl: Dictionary = Specials.blast(board, clearing_rows, COLS, ROWS, EMPTY)
	blast_cells = bl.cells
	blast_bombs = bl.bombs
	for k in Specials.links(blast_bombs.size()):
		chain += 1
		if chain == 3:
			big_chains += 1
	var n := clearing_rows.size()
	var gained: int = LINE_SCORES[mini(n, 4)] * chain
	var freed := 0
	var last_at := Vector2.ZERO
	var gone: Array = []
	for y in clearing_rows:
		for x in COLS:
			gone.append(y * COLS + x)
	gone.append_array(blast_cells)
	var chest_gone := 0
	for i in gone:
		var v: int = board[i]
		var center := board_pos + Vector2(i % COLS + 0.5, i / COLS + 0.5) * CELL
		if v == CRYSTAL:
			freed += 1
			last_at = center
			_burst(center, CRYSTAL_COL, 16, 420.0)
			if goal == Specials.GOAL_CRYSTALS:
				juice.fly(center)  # 0.18: кристалл летит к счётчику на панели
		elif v == PET:
			continue  # кротёнок не исчезает: ряд очищается вокруг него
		elif v == CHEST:
			chest_gone += 1
			_burst(center, SpecialsDraw.AMBER, 10, 320.0)
		else:
			_burst(center, _cell_color(v), 6, 260.0)
	crystals_left -= freed
	if freed > 0 and crystals_left <= 0 and goal == Specials.GOAL_CRYSTALS:
		juice.on_last_crystal(last_at)  # 0.18: последний кристалл уровня — маленький праздник
	gained += freed * 150
	if not blast_bombs.is_empty():
		_on_boom()
		gained += 100 * blast_bombs.size()
	if chest_gone > 0 and chest_total > 0 and not chest_open:
		chest_left -= chest_gone
		if chest_left <= 0:
			_on_chest_open()
	score += gained
	score_bump = 1.0
	shake = maxf(shake, 3.0 + 3.0 * (n - 1) + 3.0 * (chain - 1))
	var mid_y: float = board_pos.y + (clearing_rows[0] + 0.5) * CELL
	var px := board_pos.x + COLS * CELL / 2.0
	play_hero.on_cascade(chain)  # 0.17: ×2 — радость, ×3+ — прыжок с искорками
	juice.on_cascade(chain)  # 0.18: ×3+ — замедление, вспышка, «Супер!» / «Мега!»; вибрация
	if chain >= 2:
		_popup(I18n.t("cascade") % chain, Vector2(px, mid_y - 50), ACCENT, 46)
		var snd: Array = Juice.chain_sound(chain)  # 0.18: каждое звено — на ступень выше
		play(snd[0], snd[1])
		tut.on_cascade(self)
		hero_says("cascade")
	elif freed > 0:
		hero_says("crystal")
	else:
		play("line%d" % mini(n, 4))
	_popup("+%d" % gained, Vector2(px, mid_y), TEXT, 38)
	if freed > 0:
		play("crystal")
		_popup(I18n.t("crystal_one") if freed == 1 else I18n.t("crystal_many") % freed, Vector2(px, mid_y + 50), CRYSTAL_COL, 36)
	_set_state(State.CLEARING)
	clear_timer = CLEAR_TIME
	return true


func _finish_clear() -> void:
	var lowest: int = clearing_rows.max()
	for i in blast_cells:
		lowest = maxi(lowest, i / COLS)
	# 0.18: кротёнок остаётся на месте, клетки взрыва исчезают вместе с рядами
	Specials.clear(board, piece_ids, clearing_rows, blast_cells, COLS, EMPTY)
	blast_cells = []
	blast_bombs = []
	# Каскад, «липкая» гравитация (scripts/gravity.gd): клетки одной фигуры (и тайник) держатся
	# вместе, камень, кристаллы, бомбы и кротёнок падают поодиночке. Все группы поля падают, пока могут.
	var fall := Gravity.settle(board, piece_ids, COLS, ROWS, EMPTY, Specials.LOOSE, -1 if FALL_ALL else lowest)
	var moved := false
	for i in fall.size():
		fall_dist[i] = fall[i]
		if fall[i] > 0:
			moved = true
	clearing_rows.clear()
	_set_state(State.SETTLE)
	settle_timer = SETTLE_TIME if moved else 0.0


## 0.18: взрыв бомб — большая вспышка, тряска, частицы, звук.
func _on_boom() -> void:
	bombs_blown += blast_bombs.size()
	for c in blast_bombs:
		var at := board_pos + Vector2(c.x + 0.5, c.y + 0.5) * CELL
		boom_fx.boom(at)
		_burst(at, SpecialsDraw.BOMB_COL, 26, 620.0)
		_burst(at, SpecialsDraw.BOMB_CORE, 14, 380.0)
	var c0: Vector2i = blast_bombs[0]
	var at0 := board_pos + Vector2(c0.x + 0.5, c0.y + 0.5) * CELL
	shake = maxf(shake, 14.0 + 4.0 * mini(blast_bombs.size(), 4))
	juice.on_boom(blast_bombs.size())
	play("boom", 1.0 if blast_bombs.size() == 1 else 0.85)
	_popup(I18n.t("bomb_boom") if blast_bombs.size() == 1 else I18n.t("bomb_chain") % blast_bombs.size(), at0 + Vector2(0, -150), SpecialsDraw.BOMB_COL, 44)


## 0.18: тайник открыт — осколки прибавятся к награде за победу.
func _on_chest_open() -> void:
	chest_open = true
	chest_left = 0
	var at := board_pos + Vector2(COLS * CELL / 2.0, (ROWS - 3) * CELL)
	boom_fx.open(at, chest_shards)
	_burst(at, SpecialsDraw.AMBER, 24, 480.0)
	play("levelup", 1.3, -4.0)
	_popup(I18n.t("chest_open") % chest_shards, at + Vector2(0, -40), SpecialsDraw.AMBER, 40)


## 0.18: цель уровня выполнена? Кристаллы — все освобождены; кротёнок — в самом нижнем ряду;
## тайник — открыт.
func goal_done() -> bool:
	match goal:
		Specials.GOAL_PET:
			return Specials.pet_row(board, COLS) == ROWS - 1
		Specials.GOAL_CHEST:
			return chest_open
	return crystals_left <= 0


## 0.18: сколько рядов кротёнку до дна (0 — на дне, -1 — его нет).
func pet_depth() -> int:
	var y := Specials.pet_row(board, COLS)
	return -1 if y < 0 else ROWS - 1 - y


## 0.18: строка итога поражения: кристаллы, глубина кротёнка или тайник.
func goal_status() -> String:
	match goal:
		Specials.GOAL_PET:
			return I18n.t("lose_pet") % pet_depth()
		Specials.GOAL_CHEST:
			return I18n.t("lose_chest") % [chest_total - chest_left, chest_total]
	return I18n.t("lose_crystals") % [crystals_total - crystals_left, crystals_total]


func _after_chain() -> void:
	if goal_done():
		_win()
	else:
		_set_state(State.PLAYING)
		_spawn()


func _win() -> void:
	has_piece = false
	last_stars = 3 if pieces_used <= par else (2 if pieces_used <= int(par * 1.4) else 1)
	last_reward = Meta.win_reward(not stars.has(level), stars.get(level, 0), last_stars, big_chains, level)
	# 0.9: «Подарок новичку» за самую первую победу в игре
	var gift: int = assist.take_gift(total_stars())
	if gift > 0:
		last_reward.gift = gift
		last_reward.total += gift
	if chest_open and chest_shards > 0:
		last_reward.chest = chest_shards  # 0.18: осколки из янтарного тайника
		last_reward.total += chest_shards
	assist.on_win(level, pieces_used, access.slow)  # 0.17: победа с медленным падением отмечается в статистике
	meta.shards += last_reward.total
	stars[level] = maxi(stars.get(level, 0), last_stars)
	if trophy_ui:
		trophy_ui.on_win(meta.award_trophy(level, max_level))  # 0.14: последний уровень зала — кубок
	else:
		meta.award_trophy(level, max_level)
	max_level = maxi(max_level, level + 1)
	_save()
	_set_state(State.WIN)
	state_time = -RESULT_BEAT  # 0.17: сначала герой на панели празднует, потом окно победы
	play_hero.on_win()
	hero_says("win")
	if screens:
		screens.poke_hero()
	play("levelup")
	for i in 60:
		var c: Color = GEMS[i % GEMS.size()]
		particles.append({"p": Vector2(randf() * W, H * 0.35), "v": Vector2(randf_range(-200, 200), randf_range(-500, -100)),
			"col": c, "life": randf_range(1.0, 1.8), "max": 1.8, "rot": randf() * TAU, "s": randf_range(5, 10)})


func _lose() -> void:
	has_piece = false
	assist.on_lose(level)
	if assist.track:
		_save()
	_set_state(State.LOSE)
	state_time = -RESULT_BEAT  # 0.17: сначала герой на панели грустит, потом окно поражения
	play_hero.on_lose()
	play("gameover")


## 0.18: фраза героя у поля на событие ev ("cascade", "crystal", "win"), не чаще раза в ~3 с.
func hero_says(ev: String) -> bool:
	var kind: String = meta.hero if meta.hero != "" else "owl"
	return say.on_event(kind, meta.gender_of(kind), ev)


func step(delta: float) -> void:
	state_time += delta
	match state:
		State.SPLASH:
			if state_time > 2.0:
				go_home()
		State.PLAYING:
			if not has_piece:
				return
			if not tut.holds_fall():
				_tick_speed(delta)
			if fits(piece_cells, piece_pos + Vector2i(0, 1)):
				lock_timer = 0.0
				if tut.holds_fall():  # 0.9: пока на экране шаг обучения, фигура сама не падает
					return
				fall_timer += delta
				if fall_timer >= fall_interval():
					fall_timer = 0.0
					piece_pos.y += 1
			else:
				lock_timer += delta
				if lock_timer >= LOCK_DELAY:
					_lock()
		State.CLEARING:
			if tut.is_info():  # 0.9: каскад «замирает», пока на экране пояснение обучения
				return
			clear_timer -= delta
			if clear_timer <= 0.0:
				_finish_clear()
		State.SETTLE:
			if tut.is_info():
				return
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
	access.load_from(cfg)  # 0.17: «Удобство»; в старом сохранении — всё выключено
	# язык: из [settings] language; в старом сохранении его нет — по языку телефона
	I18n.load_from(cfg, OS.get_locale_language())
	if home3d:
		home3d.load_from(cfg)  # 0.12: качество графики [settings] graphics
	meta.load_from(cfg)  # старое сохранение без [meta] — значения по умолчанию
	# 0.9: [tutorial] и [stats]; в старом сохранении их нет — значения по умолчанию
	tut.load_from(cfg, max_level)
	tour.load_from(cfg)  # 0.17: [tour]; нет раздела — экскурсия впереди (и у старых игроков)
	assist.load_from(cfg)
	if not cfg.has_section("stats") and total_stars() > 0:
		assist.gift_given = true  # игрок с прогрессом — не новичок
	# Подарок игрокам версий до 0.6: осколки за уже пройденное (один раз, пока нет раздела [meta]).
	if not cfg.has_section("meta") and max_level > 1:
		meta.shards += legacy_gift(total_stars())
		_save()
	elif meta.migrated > 0:
		_save()  # 0.12b: старые общие вещи вернулись осколками — сразу запомнить
	level = max_level


## Переключить язык (по кругу: en -> ru -> en) и запомнить выбор в save.cfg.
func toggle_language() -> void:
	set_language(I18n.next_lang())


func set_language(l: String) -> void:
	if I18n.set_lang(l):
		_save()


## 0.17: переключатель «Удобства» (k — ключ из Access.KEYS); сразу применяется и сохраняется.
func set_access(k: String, on: bool) -> void:
	if not Access.KEYS.has(k):
		return
	access.set(k, on)
	if k == "lefty":
		_layout()
	_save()


static func legacy_gift(total: int) -> int:
	return 30 + total * 5


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "max_level", max_level)
	cfg.set_value("progress", "stars", stars)
	cfg.set_value("settings", "music", music_on)
	cfg.set_value("settings", "sfx", sfx_on)
	access.save_to(cfg)
	I18n.save_to(cfg)
	meta.save_to(cfg)
	tut.save_to(cfg)
	tour.save_to(cfg)
	assist.save_to(cfg)
	if home3d:
		home3d.save_to(cfg)
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
	var hold_popups: bool = tut.is_info() and state == State.CLEARING  # 0.9: «КАСКАД ×2» видно, пока идёт пояснение
	for p in popups:
		if hold_popups and p.life < 0.6:
			continue
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
	juice.update(delta)  # 0.18: эффекты праздника — в настоящем времени
	say.update(delta)
	owl.update(self, delta)
	boom_fx.update(delta)
	var k: float = juice.time_k() if state in [State.PLAYING, State.CLEARING, State.SETTLE] else 1.0
	step(delta * k)  # 0.18: на ×3+ — короткое замедление
	_update_effects(delta * k)
	screens.update(delta)
	tut.update(delta)
	tour.update(self, delta)
	assist_ui.update(delta)
	play_hero.update(delta, in_danger() and state in [State.PLAYING, State.CLEARING, State.SETTLE, State.PAUSED])
	if forge_ui:
		forge_ui.update(delta)
	if notice_ui:
		notice_ui.update(delta)
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
		if notice_ui and notice_ui.active():
			notice_ui.back()
			return
		if state == State.HOME and tour.back(self):
			return  # 0.17: «Назад» — пропустить экскурсию
		if state == State.HOME and decor_ui and decor_ui.back():
			return
		if state == State.HOME and trophy_ui and trophy_ui.back():
			return
		match state:
			State.PLAYING, State.CLEARING, State.SETTLE:
				_set_state(State.PAUSED)
			State.WARDROBE:
				if not screens.cancel_try():  # сначала снимается примерка
					go_home()
			State.FORGE:
				forge_ui.back()
			State.PAUSED when assist_ui.stats_open:
				assist_ui.stats_open = false
			State.PAUSED when access_ui and access_ui.open:
				access_ui.close()
			State.PAUSED, State.WIN, State.LOSE, State.MAP:
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
		_touch_drag(event.index, event.position, event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)


func _key(e: InputEventKey) -> void:
	if notice_ui and notice_ui.active():
		return  # 0.13: открыто окно (например, ввод имени) — клавиши не управляют игрой
	match e.keycode:
		KEY_LEFT: _press("left")
		KEY_RIGHT: _press("right")
		KEY_DOWN: _press("soft")
		KEY_UP: _press("rotate")
		KEY_SPACE: _press("hard")
		KEY_Z, KEY_BACKSPACE: undo_piece()  # 0.18: «Совиное время» с клавиатуры
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
	if notice_ui and notice_ui.active():
		notice_ui.tap(pos)  # 0.12b: открытое окно забирает касания
		return
	match state:
		State.SPLASH:
			go_home()
			return
		State.HOME:
			if tour.tap(self, pos):
				return  # 0.17: экскурсия забирает касания (кнопки и камера 3D-дома их не получают)
			if decor_ui and decor_ui.active:
				# 0.15: режим украшения: панель и полоса — свои касания, остальное — камера 3D-дома
				# (0.18: по ленте карточек — тап при отпускании, свайп листает)
				if decor_ui.strip_down(idx, pos):
					return
				if not decor_ui.tap(pos) and home3d:
					home3d.touch(idx, pos, true)
				return
			if trophy_ui and trophy_ui.press(idx, pos):
				return  # 0.18: полка 2D: тап при отпускании, свайп — соседний кубок
			if trophy_ui and trophy_ui.tap_home(pos):
				return
			if not assist_ui.tap_home(pos) and not screens.tap_home(pos) and home3d:
				home3d.touch(idx, pos, true)  # 0.12: мимо кнопок — камера 3D-дома
			return
		State.PICK_HERO:
			screens.tap_pick(pos)
			return
		State.WARDROBE:
			tut.wardrobe_tap(self)
			screens.wardrobe_down(idx, pos)  # 0.18: по сетке вещей — тап при отпускании, свайп листает
			return
		State.MAP:
			screens.map_down(idx, pos)
			return
		State.FORGE:
			forge_ui.tap(pos)
			return
		State.WIN, State.LOSE:
			if state_time < 0.0:
				state_time = 0.0  # 0.17: касание пропускает паузу с реакцией героя
				return
			if state == State.LOSE and assist_ui.tap_lose(pos):
				return
			if state == State.WIN and trophy_ui and trophy_ui.tap_win(pos):
				return
			screens.tap_end(pos)
			return
		State.PAUSED:
			if access_ui and access_ui.tap(pos):
				return
			if privacy and not assist_ui.stats_open and privacy.tap(pos):
				return
			if not assist_ui.tap_pause(pos):
				_pause_menu_tap(pos)
			return
	if tut.on_tap(self, pos):  # 0.9: шаг-пояснение обучения закрывается касанием
		return
	if pause_rect.grow(12).has_point(pos):
		if state == State.PLAYING:
			play("pause")
			_set_state(State.PAUSED)
		return
	if owl.rect.grow(12).has_point(pos):
		undo_piece()  # 0.18: «Совиное время»; во время каскада и после итога — не срабатывает
		return
	for n in buttons:
		if buttons[n].has_point(pos):
			held[idx] = n
			repeat_left[idx] = REPEAT_DELAY
			_press(n)
			return
	if pos.y < buttons["left"].position.y - 8:
		# 0.17: касание героя на панели — его реакция; провести пальцем от героя всё так же двигает фигуру
		var on_hero: bool = state in [State.PLAYING, State.CLEARING, State.SETTLE] and play_hero.hit(pos)
		if on_hero:
			play_hero.poke()
		board_touch[idx] = {"start": pos, "ax": pos.x, "ay": pos.y, "t": Time.get_ticks_msec() / 1000.0, "moved": false, "hero": on_hero}


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
				"language": toggle_language()
				"graphics":  # 0.12: качество 3D-дома: высокое -> простое -> 2D
					home3d.cycle_quality()
					_save()
				"access":  # 0.17: окно «Удобство»
					if access_ui:
						access_ui.show()
				"tutorial":  # 0.9: повтор обучения — уровень 1 с первыми шагами
					tut.replay()
					tour.replay()  # 0.17: и экскурсия по дому — при следующем возвращении домой
					_save()
					start_level(1)
				"restart": start_level(level)
				"menu": go_home()
			return


func _touch_drag(idx: int, pos: Vector2, rel := Vector2.ZERO) -> void:
	if state == State.HOME:
		if decor_ui:
			decor_ui.strip.move(idx, pos)
		if trophy_ui:
			trophy_ui.strip.move(idx, pos)
		if home3d and not tour.active():
			home3d.drag(idx, pos, rel)
		return
	if state == State.WARDROBE:
		screens.wardrobe_drag(idx, pos)
		return
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
	if home3d:
		home3d.touch(idx, pos, false)
	if state == State.HOME:
		if decor_ui:
			decor_ui.strip_up(idx, pos)
		if trophy_ui:
			trophy_ui.release(idx, pos)
	if state == State.WARDROBE:
		screens.wardrobe_up(idx, pos)
		return
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
	elif not t.moved and d.length() < 24 and not t.get("hero", false):
		rotate_piece()


# ---------- Отрисовка ----------

func _cell_color(v: int) -> Color:
	if v == STONE:
		return STONE_COL
	if v == CRYSTAL:
		return CRYSTAL_COL
	if v == BOMB:
		return SpecialsDraw.BOMB_COL
	if v == PET:
		return SpecialsDraw.PET_FUR
	if v == CHEST:
		return SpecialsDraw.AMBER
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
			if decor_ui and decor_ui.active:
				return  # 0.15: в режиме украшения — только его полоса и панель (рисует screens.draw_home)
			assist_ui.draw_home_goal()
			if trophy_ui:
				trophy_ui.draw_home()
			tour.draw(self)  # 0.17: экскурсия по главному экрану — поверх всего
			return
		State.FORGE:
			_draw_background()
			forge_ui.draw()
			return
		State.PICK_HERO, State.WARDROBE, State.MAP:
			_draw_background()
			if state == State.PICK_HERO:
				screens.draw_pick()
			elif state == State.WARDROBE:
				screens.draw_wardrobe()
				_draw_wardrobe_hint()
			else:
				screens.draw_map()
			return
	_draw_background()
	var off := Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) if shake > 0.0 else Vector2.ZERO
	draw_set_transform(off)
	_draw_header()
	var z: Array = juice.board_zoom()  # 0.18: последний кристалл — лёгкое приближение поля
	draw_set_transform(off + z[1] * (1.0 - z[0]), 0.0, Vector2(z[0], z[0]))
	_draw_board()
	draw_set_transform(off)
	_draw_panel()
	draw_set_transform(Vector2.ZERO)
	_draw_controls()
	_draw_effects()
	boom_fx.draw(self)  # 0.18: взрывы бомб, открытие тайника
	juice.draw()  # 0.18: вспышка, летящие кристаллы, «Супер!» / «Мега!»
	if state in [State.PLAYING, State.CLEARING, State.SETTLE, State.WIN, State.LOSE]:
		owl.draw(self)  # 0.18: кнопка «Совиное время»
	if state in [State.PLAYING, State.CLEARING, State.SETTLE]:
		tut.draw(self)
	_draw_overlay()


## 0.9: подсказка при первом заходе в гардероб — на первой карточке вещи.
func _draw_wardrobe_hint() -> void:
	if not tut.wardrobe_hint() or screens.tryon.active():
		return
	var first := Rect2()
	for k in screens.rects:
		if String(k).begins_with("item_"):
			var r: Rect2 = screens.rects[k]
			if first.size.x <= 0 or r.position.y < first.position.y or (r.position.y == first.position.y and r.position.x < first.position.x):
				first = r
	tut.draw_wardrobe(self, first)


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
			if v == CHEST:  # 0.18: клетки тайника сливаются в один сундук
				var i := y * COLS + x
				SpecialsDraw.draw_chest_cell(self, board_pos + Vector2(x, y - dy) * CELL, CELL,
					x > 0 and board[i - 1] == CHEST, x < COLS - 1 and board[i + 1] == CHEST,
					y > 0 and board[i - COLS] == CHEST, y < ROWS - 1 and board[i + COLS] == CHEST)
				continue
			_draw_block(board_pos + Vector2(x, y - dy) * CELL, CELL, v)
	_draw_chest_lock(settle_k)

	if state == State.CLEARING:
		var k := clampf(clear_timer / CLEAR_TIME, 0.0, 1.0)
		for y in clearing_rows:
			var h := CELL * k
			draw_rect(Rect2(board_pos + Vector2(0, y * CELL + (CELL - h) / 2.0), Vector2(bsize.x, h)), Color(1, 1, 1, 0.85 * k))
		for i in blast_cells:  # 0.18: клетки, которые выбивает взрыв, — огненная вспышка
			var cp := board_pos + Vector2(i % COLS, i / COLS) * CELL
			draw_rect(Rect2(cp, Vector2(CELL, CELL)).grow(-4.0 * (1.0 - k)), Color(SpecialsDraw.BOMB_CORE, 0.8 * k))
		for y in clearing_rows:  # кротёнок виден поверх вспышки ряда
			for x in COLS:
				if board[y * COLS + x] == PET:
					SpecialsDraw.draw_pet(self, board_pos + Vector2(x, y) * CELL, CELL)

	if has_piece and state != State.LOSE:
		for c in piece_cells:
			var p := Vector2i(c.x + piece_pos.x, c.y + piece_pos.y)
			if p.y >= 0:
				_draw_block(board_pos + Vector2(p) * CELL, CELL, piece_type, true)


## 0.18: замок на сундуке — в середине оставшихся клеток тайника.
func _draw_chest_lock(settle_k: float) -> void:
	if chest_left <= 0:
		return
	var sum := Vector2.ZERO
	var n := 0
	for i in board.size():
		if board[i] == CHEST:
			sum += Vector2(i % COLS + 0.5, i / COLS + 0.5 - fall_dist[i] * settle_k * settle_k)
			n += 1
	if n > 0:
		SpecialsDraw.draw_lock(self, board_pos + sum / n * CELL, CELL * 1.5)


func _draw_block(p: Vector2, s: float, v: int, glow := false) -> void:
	if v == BOMB:
		SpecialsDraw.draw_bomb(self, p, s)
		return
	if v == PET:
		SpecialsDraw.draw_pet(self, p, s)
		return
	if v == CHEST:
		SpecialsDraw.draw_chest_cell(self, p, s, false, false, false, false)
		return
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
	if access.symbols:  # 0.17: знак цвета для дальтоников (у кристалла и камня форма своя)
		Access.draw_sign(self, r.get_center() + Vector2(0, -1.5), s, v)


## Правая панель: «Далее», кристаллы, счёт/уровень/фигуры; 0.17: внизу — герой (scripts/play_hero.gd).
## Кристаллы — на y+220 (на них показывает обучение, scripts/tutorial.gd).
func _draw_panel() -> void:
	var pw := W - panel_x - 20.0
	var y := board_pos.y + 4.0
	var lab := access.fs(22)
	draw_string(font, Vector2(panel_x, y + 20), I18n.t("panel_next"), HORIZONTAL_ALIGNMENT_LEFT, pw, lab, DIM)
	var box := Rect2(panel_x, y + 34, pw, 124)
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
	if goal == Specials.GOAL_CRYSTALS:
		draw_string(font, Vector2(panel_x, y), I18n.t("panel_crystals"), HORIZONTAL_ALIGNMENT_LEFT, pw, lab, DIM)
		# 0.18: счётчик прибавляет кристалл, когда тот долетает, и «подпрыгивает»
		var jb: float = juice.bump
		var cs := 56.0 * (1.0 + 0.22 * jb)
		_draw_block(Vector2(panel_x - 6 + 28, y + 38) - Vector2(cs, cs) / 2.0 - Vector2(0, 10 * jb), cs, CRYSTAL)
		var got := maxi(0, crystals_total - crystals_left - juice.in_flight())
		draw_string(font, Vector2(panel_x + 52, y + 52 - 8 * jb), "%d/%d" % [got, crystals_total], HORIZONTAL_ALIGNMENT_LEFT, pw - 52, int(access.fs(38) * (1.0 + 0.2 * jb)), CRYSTAL_COL)
		if chest_total > 0:  # 0.18: бонусный тайник — значок справа от счётчика
			SpecialsDraw.chest_icon(self, Vector2(panel_x + pw - 14, y + 36), 32, chest_open)
	else:
		_draw_goal_panel(y, pw, lab)

	var bump := 1.0 + 0.25 * score_bump
	var val := access.fs(40)
	var stats := [[I18n.t("panel_score"), str(int(shown_score)), val * bump], [I18n.t("panel_level"), str(level), val], [I18n.t("panel_pieces"), "%d" % pieces_used, val]]
	var step_y := 86.0 if access.big else 80.0
	var sy := y + 104.0
	for i in stats.size():
		sy = y + 104.0 + i * step_y
		draw_string(font, Vector2(panel_x, sy), stats[i][0], HORIZONTAL_ALIGNMENT_LEFT, pw, lab, DIM)
		draw_string(font, Vector2(panel_x, sy + val + 2), stats[i][1], HORIZONTAL_ALIGNMENT_LEFT, pw, int(stats[i][2]), ACCENT if i == 0 else TEXT)
	# 0.18: под числом фигур — «до 3 звёзд» (звёздочки и сколько фигур ещё можно)
	var gy := sy + val + 2.0 + access.fs(24) + 12.0
	var gh: float = StarGoal.draw(self, panel_x, gy, pw, access.fs(24))
	# 0.17: герой в своём наряде — от последней строки до низа поля
	var top := sy + val + 24.0 + gh
	var bottom := board_pos.y + ROWS * CELL
	if bottom - top > 120.0:
		var kind: String = meta.hero if meta.hero != "" else "owl"
		play_hero.draw_on(self, kind, meta.outfit(), Rect2(panel_x - 8, top, pw + 16, bottom - top))
		say.draw(self, Rect2(panel_x - 8, top - 4.0, pw + 16, bottom - top), board_pos.x + COLS * CELL + 10.0)  # 0.18: облачко героя


## 0.18: цель «кротёнок» / «тайник» на панели — вместо счётчика кристаллов.
func _draw_goal_panel(y: float, pw: float, lab: int) -> void:
	var big := access.fs(38)
	if goal == Specials.GOAL_PET:
		draw_string(font, Vector2(panel_x, y), I18n.t("panel_pet"), HORIZONTAL_ALIGNMENT_LEFT, pw, lab, DIM)
		SpecialsDraw.draw_pet(self, Vector2(panel_x - 6, y + 8), 60)
		var d := maxi(pet_depth(), 0)
		var ax := panel_x + 70.0
		var bob := 4.0 * sin(t_total * 4.0)
		draw_colored_polygon(PackedVector2Array([Vector2(ax, y + 30 + bob), Vector2(ax + 20, y + 30 + bob), Vector2(ax + 10, y + 50 + bob)]), ACCENT)
		draw_rect(Rect2(ax + 6, y + 14 + bob, 8, 18), ACCENT)
		draw_string(font, Vector2(ax + 26, y + 52), str(d), HORIZONTAL_ALIGNMENT_LEFT, pw - 96, big, ACCENT if d <= 1 else TEXT)
	else:
		draw_string(font, Vector2(panel_x, y), I18n.t("panel_chest"), HORIZONTAL_ALIGNMENT_LEFT, pw, lab, DIM)
		SpecialsDraw.chest_icon(self, Vector2(panel_x + 22, y + 38), 50, chest_open)
		draw_string(font, Vector2(panel_x + 56, y + 52), "%d/%d" % [chest_total - chest_left, chest_total], HORIZONTAL_ALIGNMENT_LEFT, pw - 56, big, SpecialsDraw.AMBER)


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
		var size := int(p.size * sc * (Access.TEXT_K if access.big else 1.0))
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
			_center_text(I18n.t("pause_title"), menu_buttons["resume"].position.y - 40, access.fs(60), TEXT)
			var labels := pause_labels()
			for n in menu_buttons:
				var r: Rect2 = menu_buttons[n]
				_rbox(r, ACCENT if n == "resume" else BTN, 24)
				var fsz: int = assist_ui.fit(labels[n], access.fs(32), r.size.x - 24)
				draw_string(font, Vector2(r.position.x, r.get_center().y + fsz * 0.36), labels[n], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fsz, Color("#2A1A0A") if n == "resume" else TEXT)
			assist_ui.draw_pause_version()
			if privacy:
				privacy.draw()
			if assist_ui.stats_open:
				assist_ui.draw_stats()
			elif access_ui and access_ui.open:
				access_ui.draw()
		State.WIN when state_time < 0.0:
			pass  # 0.17: герой на панели празднует — окно победы чуть позже
		State.LOSE when state_time < 0.0:
			pass
		State.WIN:
			screens.draw_win()
			if trophy_ui:
				trophy_ui.draw_win()
		State.LOSE:
			if assist_ui.offers(level):
				assist_ui.draw_lose()
			else:
				screens.draw_lose()


## Подписи пунктов паузы (0.17: «Удобство»).
func pause_labels() -> Dictionary:
	return {"resume": I18n.t("pause_resume"), "music": I18n.t("pause_music") % I18n.t("on" if music_on else "off"),
		"sound": I18n.t("pause_sound") % I18n.t("on" if sfx_on else "off"), "language": I18n.t("pause_lang") % I18n.lang_name(),
		"restart": I18n.t("pause_restart"), "menu": I18n.t("home"), "tutorial": I18n.t("pause_tutorial"),
		"graphics": I18n.t("pause_graphics") % I18n.t("gfx_" + home3d.quality), "access": I18n.t("pause_access")}


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
