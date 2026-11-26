extends RefCounted
## 0.18: «Совиное время» — одна отмена за попытку уровня.
## Перед фиксацией фигуры (game.gd hard_drop / _lock) делается общий снимок состояния игры:
## все переменные скрипта game.gd с простыми значениями (числа, флаги, векторы, строки, массивы,
## словари — копией) и состояние генератора фигур. Так в снимок сами попадают и новые счётчики
## (например, скорость и таймер уровня), если их добавят позже. Не входят в снимок эффекты,
## разметка экрана, ввод, настройки и прогресс игрока (SKIP).
## Отмена возвращает поле, следующую фигуру, счёт и счётчики к состоянию до фиксации; фигура
## снова появляется сверху. Одна отмена на попытку; после победы/поражения и во время
## анимации каскада — недоступна. Кнопка с песочными часами — в шапке уровня, рядом с паузой.

const I18n := preload("res://scripts/i18n.gd")

## Переменные game.gd, которые отмена не трогает
const SKIP := ["state", "state_time", "level", "max_level", "stars", "level_override", "last_stars", "last_reward",
	"particles", "popups", "motes", "shake", "score_bump", "t_total", "shown_score",
	"music_on", "sfx_on", "sfx", "players", "music_player", "H", "board_pos", "panel_x", "buttons",
	"pause_rect", "menu_buttons", "held", "repeat_left", "board_touch", "font", "sb",
	"has_piece", "piece_cells", "piece_pos", "fall_timer", "lock_timer", "lock_resets", "_snapped"]
const FLIP_TIME := 1.3      # анимация переворота часов и надпись «Совиное время!»
const HINT := "undo"        # подсказка один раз (ключ в списке показанного обучения, tutorial.gd UNDO_HINT)
const HINT_TIME := 4.5      # сколько секунд видна подсказка

var used := false
var snap := {}
var rect := Rect2(530, 48, 76, 76)  # слева от паузы (название игры — слева в шапке)
var flip := 99.0            # секунд с отмены
var hint_t := 0.0           # секунд показа подсказки


func reset() -> void:
	used = false
	snap = {}
	flip = 99.0


func update(g, delta: float) -> void:
	flip += delta
	if wants_hint(g):
		hint_t += delta
		if hint_t > HINT_TIME:
			hint_seen(g)
	else:
		hint_t = 0.0


## Снимок перед фиксацией фигуры.
func take(g) -> void:
	if used:
		return
	var s := {}
	for p in g.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n: String = p.name
		if SKIP.has(n):
			continue
		var v = g.get(n)
		match typeof(v):
			TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR2I:
				s[n] = v
			TYPE_ARRAY, TYPE_DICTIONARY:
				s[n] = v.duplicate(true)
	s["__rng"] = g.rng.state
	snap = s


## Можно ли отменить сейчас.
func can_undo(g) -> bool:
	return not used and not snap.is_empty() and g.state == g.State.PLAYING and g.pieces_used > int(snap.get("pieces_used", 0))


## Отменить последнюю фигуру. true — отменено.
func undo(g) -> bool:
	if not can_undo(g):
		return false
	for n in snap:
		if n == "__rng":
			g.rng.state = snap[n]
		else:
			var v = snap[n]
			g.set(n, v.duplicate(true) if v is Array or v is Dictionary else v)
	used = true
	snap = {}
	flip = 0.0
	hint_seen(g)
	g.shown_score = float(g.score)
	g.popups.clear()
	g.clearing_rows.clear()
	g.fall_dist.fill(0)
	g._respawn_same()
	return true


## Показать подсказку один раз: после первой поставленной фигуры, пока отмена доступна.
func wants_hint(g) -> bool:
	return g.tut.enabled and not g.tut.seen.has(HINT) and can_undo(g) and not g.tut.active()


func hint_seen(g) -> void:
	if g.tut.enabled and not g.tut.seen.has(HINT):
		g.tut.seen[HINT] = true
		g._save()


## Кнопка с песочными часами (гаснет, когда отмена недоступна), переворот часов и надпись после отмены, подсказка.
func draw(g) -> void:
	var on := can_undo(g)
	var k := clampf(flip / 0.6, 0.0, 1.0)
	if on:
		var pulse := 0.5 + 0.5 * sin(g.t_total * 3.0)
		g._rbox(rect.grow(4), Color(g.ACCENT, 0.2 + 0.25 * pulse), 22)
	g._rbox(rect, g.BTN if on else Color(g.BTN, 0.45), 18)
	var c := rect.get_center()
	var ang := k * PI if flip < 99.0 else 0.0
	hourglass(g, c, 1.0, ang, 1.0 if on else 0.35, (1.0 - k) if flip < 99.0 else 1.0)
	if used:
		# погасшая кнопка: косая черта
		g.draw_line(rect.position + Vector2(14, 14), rect.end - Vector2(14, 14), Color(g.DIM, 0.5), 4.0, true)
	if flip < FLIP_TIME:
		var a := clampf((FLIP_TIME - flip) / 0.4, 0.0, 1.0)
		var sc := 0.6 + minf(flip / 0.15, 1.0) * 0.4
		var size := int(56 * sc)
		var y: float = g.board_pos.y + g.ROWS * g.CELL * 0.3
		var w: float = g.board_pos.x * 2 + g.COLS * g.CELL
		hourglass(g, Vector2(w / 2.0, y - size - 50), 2.2, ang, a, 1.0 - k)
		for o in [Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4), Vector2(0, 4)]:
			g.draw_string(g.font, Vector2(0, y) + o, I18n.t("owl_time"), HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(0.07, 0.04, 0.14, a))
		g.draw_string(g.font, Vector2(0, y), I18n.t("owl_time"), HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(g.CRYSTAL_COL, a))
	if wants_hint(g):
		var r := Rect2(minf(rect.position.x, g.W - 316.0), rect.end.y + 14, 300, 58)
		var a2 := clampf(hint_t / 0.3, 0.0, 1.0)
		g._rbox(r.grow(3), Color(g.ACCENT, 0.5 * a2), 18)
		g._rbox(r, Color(0.16, 0.09, 0.3, 0.97 * a2), 16)
		var tip := Vector2(rect.get_center().x, r.position.y)
		g.draw_colored_polygon(PackedVector2Array([tip + Vector2(-10, 1), tip + Vector2(10, 1), tip + Vector2(0, -12)]), Color(0.16, 0.09, 0.3, 0.97 * a2))
		var txt := I18n.t("owl_time_hint")
		var fs: int = g.assist_ui.fit(txt, 22, r.size.x - 20)
		g.draw_string(g.font, Vector2(r.position.x, r.get_center().y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color(g.TEXT, a2))


## Песочные часы кодом: c — центр, s — масштаб, ang — поворот, a — прозрачность,
## sand — доля песка в верхней колбе (1 — весь сверху).
static func hourglass(g, c: Vector2, s: float, ang: float, a: float, sand: float) -> void:
	g.draw_set_transform(c, ang, Vector2(s, s))
	var wood := Color("#C98A4B", a)
	var glass := Color("#9FF6FF", 0.22 * a)
	var edge := Color("#F4EEFF", 0.85 * a)
	var gold := Color("#FFB547", a)
	# колбы
	var top := PackedVector2Array([Vector2(-15, -20), Vector2(15, -20), Vector2(3, -2), Vector2(-3, -2)])
	var bot := PackedVector2Array([Vector2(-3, 2), Vector2(3, 2), Vector2(15, 20), Vector2(-15, 20)])
	g.draw_colored_polygon(top, glass)
	g.draw_colored_polygon(bot, glass)
	# песок: сверху — треугольник, снизу — горка
	var st := clampf(sand, 0.0, 1.0)
	if st > 0.02:
		var hy := -2.0 - 16.0 * st
		var hw := 3.0 + 11.0 * st
		g.draw_colored_polygon(PackedVector2Array([Vector2(-hw, hy), Vector2(hw, hy), Vector2(1.5, -2), Vector2(-1.5, -2)]), gold)
	var sb := 1.0 - st
	if sb > 0.02:
		g.draw_colored_polygon(PackedVector2Array([Vector2(-14 * sqrt(sb), 19), Vector2(14 * sqrt(sb), 19), Vector2(0, 19 - 12 * sb)]), gold)
	if st > 0.02 and sb > 0.02:
		g.draw_line(Vector2(0, -2), Vector2(0, 19 - 12 * sb), gold, 2.0)
	for poly in [top, bot]:
		var pl: PackedVector2Array = poly.duplicate()
		pl.append(poly[0])
		g.draw_polyline(pl, edge, 2.0, true)
	# рамка: крышка и донце, стойки
	g._rbox(Rect2(-20, -27, 40, 8), wood, 3)
	g._rbox(Rect2(-20, 19, 40, 8), wood, 3)
	g.draw_line(Vector2(-18, -20), Vector2(-18, 20), wood, 3.0)
	g.draw_line(Vector2(18, -20), Vector2(18, 20), wood, 3.0)
	g.draw_set_transform(Vector2.ZERO)
