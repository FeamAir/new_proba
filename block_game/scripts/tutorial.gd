extends RefCounted
## Версия 0.9: обучение на уровнях 1–3 прямо в игре и подсказка в гардеробе.
## По одному шагу: затемнение с «окном» на нужное место, анимированная рука-указатель
## (рисуется кодом) и одна короткая фраза. Шаг закрывается действием игрока
## (сдвинул, повернул, бросил фигуру; у шагов-пояснений — любое касание или действие).
## Пока шаг на экране, фигура сама не падает (game.gd step() спрашивает holds_fall()).
## Каждый шаг показывается один раз: список показанных — в user://save.cfg, раздел [tutorial].
## Повтор — пункт «Обучение» в паузе (replay()).

const I18n := preload("res://scripts/i18n.gd")

## Шаги. level — на каком уровне; after — после какого шага; on — особое событие
## (иначе шаг ждёт появления фигуры); close — какие действия его закрывают;
## hole — что открыто в затемнении; hand — как двигается рука; info — шаг-пояснение
## (пока он на экране, стоит и очистка линий — каскад «замирает»); then — сразу следом.
const ALL := ["move", "rotate", "soft", "lock", "tap"]
const STEPS := [
	{"id": "l1_move", "level": 1, "text": "tut_move", "close": ["move"], "hole": ["piece", "move_btns"], "hand": "swipe"},
	{"id": "l1_rotate", "level": 1, "text": "tut_rotate", "after": "l1_move", "close": ["rotate"], "hole": ["piece", "rotate_btn"], "hand": "tap_piece"},
	{"id": "l1_drop", "level": 1, "text": "tut_drop", "after": "l1_rotate", "close": ["lock"], "hole": ["piece", "well", "drop_btn"], "hand": "to_well"},
	{"id": "l1_cascade", "level": 1, "text": "tut_cascade", "on": "cascade", "then": "l1_crystals", "close": ALL, "hole": ["cascade"], "hand": "", "info": true},
	{"id": "l1_crystals", "level": 1, "text": "tut_crystals", "after": "l1_drop", "close": ALL, "hole": ["crystals"], "hand": "tap_crystals", "info": true},
	{"id": "l2_crumble", "level": 2, "text": "tut_crumble", "close": ALL, "hole": ["stone"], "hand": "tap_hang", "info": true},
	{"id": "l3_chain", "level": 3, "text": "tut_chain", "close": ALL, "hole": ["stone"], "hand": "tap_hang", "info": true},
	# 0.18: при первой встрече с новинкой (на любом уровне) — одно пояснение; special — что
	# должно быть на поле (game.gd: bomb — кристалл-бомба, pet — цель «кротёнок», chest — тайник)
	{"id": "sp_bomb", "special": "bomb", "text": "tut_bomb", "close": ALL, "hole": ["sp_bomb"], "hand": "tap_special", "info": true},
	{"id": "sp_pet", "special": "pet", "text": "tut_pet", "close": ALL, "hole": ["sp_pet", "crystals"], "hand": "tap_special", "info": true},
	{"id": "sp_chest", "special": "chest", "text": "tut_chest", "close": ALL, "hole": ["sp_chest"], "hand": "tap_special", "info": true},
]
const WARDROBE := "wardrobe"
const UNDO_HINT := "undo"  # 0.18: подсказка «Совиного времени» (scripts/owl_time.gd), один раз
const FIRST_PIECE := 1   # палочка из трёх: повернуть и бросить в колодец — каскад ×2

var enabled := true      # false — без обучения (робот-тестер)
var seen: Dictionary = {}  # id шага -> true
var cur := ""            # шаг на экране ("" — нет)
var queued := ""         # шаг-событие, ждущий своей очереди
var t := 0.0             # секунд на экране


static func step_by_id(id: String) -> Dictionary:
	for s in STEPS:
		if s.id == id:
			return s
	return {}


func active() -> bool:
	return enabled and cur != ""


## Фигура не падает сама, пока на экране шаг обучения.
func holds_fall() -> bool:
	return active()


func is_info() -> bool:
	return active() and step_by_id(cur).get("info", false)


## Первая фигура уровня 1 в обучении — палочка (чтобы сразу получился каскад).
func wants_first_piece(level: int) -> bool:
	return enabled and level == 1 and not seen.has("l1_drop")


func update(delta: float) -> void:
	t += delta


# ---------- События игры ----------

func on_start(_g) -> void:
	cur = ""
	queued = ""


## Новая фигура на поле: показать следующий шаг этого уровня, если есть.
func on_spawn(g) -> void:
	_next(g)


func on_cascade(g) -> void:
	if not enabled or g.level != 1 or seen.has("l1_cascade") or cur == "l1_cascade":
		return
	if cur == "":
		_show("l1_cascade")
	else:
		queued = "l1_cascade"


## Действие игрока: "move", "rotate", "soft", "lock" (фигура легла), "tap".
## true — шаг закрыт этим действием.
func on_action(g, kind: String) -> bool:
	if not active():
		return false
	if not step_by_id(cur).close.has(kind):
		return false
	var then: String = step_by_id(cur).get("then", "")
	seen[cur] = true
	cur = ""
	g._save()
	if then != "" and not seen.has(then):
		_show(then)
	else:
		_next(g)
	return true


## Касание во время игры: шаг-пояснение закрывается и касание «съедается».
func on_tap(g, _pos: Vector2) -> bool:
	if not is_info() or t < 0.35:
		return is_info()
	return on_action(g, "tap")


func _next(g) -> void:
	if not enabled or cur != "":
		return
	if queued != "" and not seen.has(queued):
		_show(queued)
		queued = ""
		return
	queued = ""
	if g.state != g.State.PLAYING or not g.has_piece:
		return
	for s in STEPS:
		if seen.has(s.id) or s.has("on"):
			continue
		if s.has("special"):
			if not has_special(g, s.special):
				continue
		elif s.level != g.level:
			continue
		if s.has("after") and not seen.has(s.after):
			continue
		_show(s.id)
		return


## 0.18: есть ли на поле новинка kind ("bomb", "pet", "chest") — для подсказки при первой встрече.
static func has_special(g, kind: String) -> bool:
	match kind:
		"bomb":
			return g.board.has(g.BOMB)
		"pet":
			return g.goal == "pet" and g.board.has(g.PET)
		"chest":
			return g.chest_left > 0
	return false


## 0.18: клетки новинки на экране (кротёнок, первая бомба, весь тайник).
static func special_rect(g, v: int) -> Rect2:
	var r := Rect2()
	for i in g.board.size():
		if g.board[i] != v:
			continue
		var c := Rect2(g.board_pos + Vector2(i % g.COLS, i / g.COLS) * g.CELL, Vector2(g.CELL, g.CELL))
		r = c if r.size.x <= 0 else r.merge(c)
		if v != g.CHEST:
			break
	return r.grow(8) if r.size.x > 0 else r


func _show(id: String) -> void:
	cur = id
	t = 0.0


## Повтор обучения из паузы: шаги уровней 1–3 покажутся снова.
func replay() -> void:
	for s in STEPS:
		seen.erase(s.id)
	seen.erase(UNDO_HINT)
	cur = ""
	queued = ""


# ---------- Гардероб: одна подсказка при первом заходе ----------

func wardrobe_hint() -> bool:
	return enabled and not seen.has(WARDROBE)


## Любое касание в гардеробе закрывает подсказку (и работает как обычно).
func wardrobe_tap(g) -> void:
	if wardrobe_hint():
		seen[WARDROBE] = true
		g._save()


# ---------- Сохранение: [tutorial] ----------

func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("tutorial", "seen", seen.keys())


## Старое сохранение без раздела: игрок с прогрессом уже знает игру — шаги пройденных
## уровней и подсказка гардероба считаются показанными.
func load_from(cfg: ConfigFile, max_level: int) -> void:
	seen = {}
	cur = ""
	queued = ""
	if not cfg.has_section("tutorial"):
		if max_level > 1:
			for s in STEPS:
				if s.has("level") and s.level < max_level:
					seen[s.id] = true
			seen[WARDROBE] = true
		return
	var a = cfg.get_value("tutorial", "seen", [])
	if a is Array:
		for id in a:
			if id is String and (id == WARDROBE or id == UNDO_HINT or not step_by_id(id).is_empty()):
				seen[id] = true


# ---------- Рисование ----------

## Прямоугольники на экране для целей шага.
func target(g, name: String) -> Rect2:
	var C: float = g.CELL
	match name:
		"piece":
			if not g.has_piece:
				return Rect2()
			var mn := Vector2i(99, 99)
			var mx := Vector2i(-99, -99)
			for c in g.piece_cells:
				var p: Vector2i = c + g.piece_pos
				mn = mn.min(p)
				mx = mx.max(p)
			mn.y = maxi(mn.y, 0)
			return Rect2(g.board_pos + Vector2(mn) * C, Vector2(mx - mn + Vector2i.ONE) * C).grow(8)
		"move_btns":
			return g.buttons["left"].merge(g.buttons["right"]).grow(6)
		"rotate_btn":
			return g.buttons["rotate"].grow(6)
		"drop_btn":
			return g.buttons["hard"].grow(6)
		"board":
			return Rect2(g.board_pos, Vector2(g.COLS, g.ROWS) * C).grow(8)
		"well":
			var w := well(g)
			if w.x < 0:
				return Rect2()
			return Rect2(g.board_pos + Vector2(w.x, w.y) * C, Vector2(1, g.ROWS - w.y) * C).grow(6)
		"cascade":
			var top: int = g.ROWS - 4
			if not g.clearing_rows.is_empty():
				top = g.clearing_rows.min() - 2
			top = clampi(top, 0, g.ROWS - 1)
			return Rect2(g.board_pos + Vector2(0, top) * C, Vector2(g.COLS, g.ROWS - top) * C).grow(8)
		"stone":
			var top := stone_top(g)
			return Rect2(g.board_pos + Vector2(0, top) * C, Vector2(g.COLS, g.ROWS - top) * C).grow(8)
		"sp_bomb":
			return special_rect(g, g.BOMB)
		"sp_pet":
			return special_rect(g, g.PET)
		"sp_chest":
			return special_rect(g, g.CHEST)
		"crystals":
			var y: float = g.board_pos.y + 4.0 + 220.0
			return Rect2(g.panel_x - 12, y - 30, g.W - g.panel_x - 8, 100)
	return Rect2()


## Колодец: колонка, пустая от верхнего ряда камня до дна. Vector2i(x, верх) или x = -1.
static func well(g) -> Vector2i:
	var top := -1
	for y in g.ROWS:
		var filled := 0
		for x in g.COLS:
			if g.board[y * g.COLS + x] != g.EMPTY:
				filled += 1
		if filled >= g.COLS - 3:
			top = y
			break
	if top < 0:
		return Vector2i(-1, 0)
	for x in g.COLS:
		var empty := true
		for y in range(top, g.ROWS):
			if g.board[y * g.COLS + x] != g.EMPTY:
				empty = false
				break
		if empty:
			return Vector2i(x, maxi(0, top - 1))
	return Vector2i(-1, 0)


## Верхний ряд, где есть камень (вместе с висячим блоком).
static func stone_top(g) -> int:
	for y in g.ROWS:
		for x in g.COLS:
			if g.board[y * g.COLS + x] == g.STONE:
				return y
	return g.ROWS - 1


## Висячий блок (самый верхний камень) — центр клетки на экране.
func hang_point(g) -> Vector2:
	var top := stone_top(g)
	for x in g.COLS:
		if g.board[top * g.COLS + x] == g.STONE:
			return g.board_pos + Vector2(x + 0.5, top + 0.5) * g.CELL
	return g.board_pos + Vector2(g.COLS / 2.0, top + 0.5) * g.CELL


func draw(g) -> void:
	if not active():
		return
	var s := step_by_id(cur)
	var holes: Array = []
	for h in s.hole:
		var r := target(g, h)
		if r.size.x > 0:
			holes.append(r)
	var a := clampf(t / 0.25, 0.0, 1.0)
	dim(g, holes, 0.7 * a)
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	for r in holes:
		g.draw_rect(r, Color(g.ACCENT, (0.45 + 0.45 * pulse) * a), false, 4.0)
	var anchor: Rect2 = holes[0] if holes.size() > 0 else Rect2(0, g.H / 2.0, g.W, 0)
	if s.id == "l1_drop" and holes.size() > 1:
		anchor = holes[1]
	bubble(g, I18n.t(s.text), anchor, I18n.t("tut_tap") if s.get("info", false) else "", a, s.hand != "")
	_hand_for(g, s)


func _hand_for(g, s: Dictionary) -> void:
	var piece := target(g, "piece")
	match s.hand:
		"swipe":
			if piece.size.x > 0:
				var c := piece.get_center()
				var k := sin(t * 2.6)
				hand(g, c + Vector2(k * 110.0, 20), 0.0, 0.0)
		"tap_piece":
			if piece.size.x > 0:
				_tap_hand(g, piece.get_center())
		"to_well":
			var w := target(g, "well")
			if piece.size.x > 0 and w.size.x > 0:
				var k := fmod(t, 2.2) / 2.2
				var start := piece.get_center()
				var mid := Vector2(w.get_center().x, start.y)
				var end := Vector2(w.get_center().x, w.end.y - 30)
				var p := start.lerp(mid, clampf(k / 0.4, 0.0, 1.0)) if k < 0.4 else mid.lerp(end, clampf((k - 0.4) / 0.45, 0.0, 1.0))
				hand(g, p, 0.0, 0.0)
		"tap_crystals":
			var cr := target(g, "crystals")
			_tap_hand(g, Vector2(cr.position.x + 44, cr.end.y - 22))
		"tap_hang":
			_tap_hand(g, hang_point(g))
		"tap_special":
			var sr := target(g, s.hole[0])
			if sr.size.x > 0:
				_tap_hand(g, sr.get_center())


func _tap_hand(g, at: Vector2) -> void:
	var k := fmod(t, 1.1) / 1.1
	var press := clampf(1.0 - absf(k - 0.3) / 0.15, 0.0, 1.0)
	if k > 0.3:
		var rk := (k - 0.3) / 0.7
		g.draw_arc(at, 14 + 46 * rk, 0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - rk)), 4.0, true)
	hand(g, at, press, 0.0)


## Затемнение всего экрана, кроме прямоугольников holes («окна»).
## Полосы по высоте: в каждой полосе закрашивается всё, что не попало в окна.
static func dim(g, holes: Array, alpha: float) -> void:
	var col := Color(0.03, 0.015, 0.07, alpha)
	var clipped: Array = []
	for h in holes:
		var r: Rect2 = h.intersection(Rect2(0, 0, g.W, g.H))
		if r.size.x > 0 and r.size.y > 0:
			clipped.append(Rect2(roundf(r.position.x), roundf(r.position.y), roundf(r.size.x), roundf(r.size.y)))
	var ys := [0.0, float(g.H)]
	for r in clipped:
		ys.append(r.position.y)
		ys.append(r.end.y)
	ys.sort()
	for i in ys.size() - 1:
		var y0: float = ys[i]
		var y1: float = ys[i + 1]
		if y1 - y0 <= 0.0:
			continue
		var my := (y0 + y1) / 2.0
		var spans: Array = []
		for r in clipped:
			if r.position.y <= my and r.end.y >= my:
				spans.append(Vector2(r.position.x, r.end.x))
		spans.sort_custom(func(p, q): return p.x < q.x)
		var x := 0.0
		for sp in spans:
			if sp.x > x:
				g.draw_rect(Rect2(x, y0, sp.x - x, y1 - y0), col)
			x = maxf(x, sp.y)
		if x < g.W:
			g.draw_rect(Rect2(x, y0, g.W - x, y1 - y0), col)


## Рука-указатель: кончик пальца в точке tip. press 0..1 — нажатие (рука чуть меньше).
static func hand(g, tip: Vector2, press: float, angle: float) -> void:
	var sc := 1.0 - 0.12 * press
	g.draw_set_transform(tip + Vector2(6, 4) * press, angle - 0.32, Vector2(sc, sc))
	var out := Color("#2A1A0A")
	var skin := Color("#FFF4E6")
	var shade := Color("#F2D7BD")
	# контур (чуть больше) и заливка
	for pass_ in 2:
		var o := 4.0 if pass_ == 0 else 0.0
		var col := out if pass_ == 0 else skin
		g._rbox(Rect2(-12 - o, -2 - o, 24 + 2 * o, 66 + 2 * o), col, 12 + o)            # указательный
		g._rbox(Rect2(-30 - o, 40 - o, 66 + 2 * o, 66 + 2 * o), col, 22 + o)            # ладонь
		for i in 3:                                                                       # согнутые пальцы
			g._rbox(Rect2(10 + i * 9 - o, 34 + i * 3 - o, 18 + 2 * o, 32 + 2 * o), col, 9 + o)
		g._rbox(Rect2(-44 - o, 58 - o, 30 + 2 * o, 20 + 2 * o), col, 10 + o)             # большой
	g.draw_line(Vector2(-6, 10), Vector2(6, 10), shade, 2.0, true)
	g._rbox(Rect2(-26, 104, 58, 18), Color("#FFB547"), 6)                                  # манжета
	g.draw_set_transform(Vector2.ZERO)


## Облачко с фразой над или под окном.
## with_hand — под окном рука-указатель: облачко ставится ниже, чтобы она его не закрывала.
static func bubble(g, text: String, anchor: Rect2, sub: String, a: float, with_hand := false) -> void:
	var size := 40
	while size > 26 and g.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > 600.0:
		size -= 2
	var tw: float = g.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var w := clampf(tw + 70.0, 360.0, 680.0)
	var h := 92.0 if sub == "" else 126.0
	var y: float
	if anchor.get_center().y > g.H * 0.5:
		y = anchor.position.y - h - 26.0
	else:
		y = anchor.end.y + (150.0 if with_hand else 26.0)
	y = clampf(y, 24.0, g.H - h - 24.0)
	var x := clampf(anchor.get_center().x - w / 2.0, 20.0, g.W - w - 20.0)
	var r := Rect2(x, y, w, h)
	g._rbox(r.grow(5), Color(g.ACCENT, 0.35 * a), 34)
	g._rbox(r, Color(0.16, 0.09, 0.3, 0.97 * a), 30)
	g.draw_string(g.font, Vector2(r.position.x, r.position.y + 58), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, Color(g.TEXT, a))
	if sub != "":
		g.draw_string(g.font, Vector2(r.position.x, r.position.y + 100), sub, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(g.DIM, a * (0.6 + 0.4 * sin(Time.get_ticks_msec() / 300.0))))


## Подсказка гардероба: окно на первой карточке вещи, рука нажимает на неё.
func draw_wardrobe(g, card: Rect2) -> void:
	if not wardrobe_hint() or card.size.x <= 0:
		return
	var r := card.grow(6)
	dim(g, [r], 0.65)
	g.draw_rect(r, Color(g.ACCENT, 0.6 + 0.3 * sin(t * 5.0)), false, 4.0)
	bubble(g, I18n.t("tut_wardrobe"), r, "", 1.0)
	_tap_hand(g, r.position + Vector2(r.size.x * 0.62, 70))
