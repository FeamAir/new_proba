extends RefCounted
## 0.18: рисование новинок кодом (scripts/specials.gd — правила): кристалл-бомба в камне,
## кротёнок в шахтёрской каске, янтарный тайник; значки цели для панели и карты; взрыв 3×3.
## Экземпляр (game.gd `boom_fx`) хранит только эффекты взрыва и открытия тайника —
## в снимок «Совиного времени» он не попадает (это объект, а не простое значение).

const BOMB_COL := Color("#FF7A2F")
const BOMB_CORE := Color("#FFE08A")
const PET_FUR := Color("#8A5A3C")
const PET_FACE := Color("#E8C29A")
const PET_NOSE := Color("#FF8FB1")
const HELMET := Color("#FFC93C")
const AMBER := Color("#E39B2D")
const AMBER_DARK := Color("#9A5A16")
const BOOM_TIME := 0.55
const OPEN_TIME := 1.2

var booms: Array = []   # {"c": центр клетки на экране, "t": секунд}
var opens: Array = []   # {"c": центр тайника, "t", "n": осколков}


func reset() -> void:
	booms.clear()
	opens.clear()


func boom(at: Vector2) -> void:
	booms.append({"c": at, "t": 0.0})


func open(at: Vector2, n: int) -> void:
	opens.append({"c": at, "t": 0.0, "n": n})


func update(delta: float) -> void:
	for b in booms:
		b.t += delta
	for o in opens:
		o.t += delta
	booms = booms.filter(func(b): return b.t < BOOM_TIME)
	opens = opens.filter(func(o): return o.t < OPEN_TIME)


## Вспышки взрывов (квадрат 3×3 и расходящееся кольцо) и открытие тайника — поверх поля.
func draw(g) -> void:
	var cs: float = g.CELL
	for b in booms:
		var k: float = b.t / BOOM_TIME
		var a := 1.0 - k
		var sq := Rect2(b.c - Vector2(cs, cs) * 1.5, Vector2(cs, cs) * 3.0).grow(6.0 * (1.0 - k))
		g._rbox(sq, Color(BOMB_CORE, 0.75 * a * a), 14)
		g.draw_circle(b.c, cs * (0.6 + 2.4 * k), Color(BOMB_COL, 0.35 * a), true, -1.0, true)
		g.draw_arc(b.c, cs * (0.8 + 2.6 * k), 0, TAU, 48, Color(1, 0.95, 0.7, a), 8.0 * a + 1.0, true)
		for i in 8:
			var ang: float = i * TAU / 8.0 + 0.3
			var r0 := cs * (0.4 + 1.6 * k)
			var r1 := r0 + cs * 0.6 * a
			g.draw_line(b.c + Vector2(cos(ang), sin(ang)) * r0, b.c + Vector2(cos(ang), sin(ang)) * r1, Color(BOMB_CORE, a), 5.0, true)
	for o in opens:
		var k: float = o.t / OPEN_TIME
		var a := clampf((1.0 - k) / 0.4, 0.0, 1.0)
		g.draw_circle(o.c, cs * (0.5 + 1.8 * k), Color(AMBER, 0.3 * a), true, -1.0, true)
		for i in 10:
			var ang: float = i * TAU / 10.0 + o.t * 2.0
			var p: Vector2 = o.c + Vector2(cos(ang), sin(ang)) * cs * (0.4 + 1.6 * k) + Vector2(0, -cs * k)
			g.draw_circle(p, 5.0, Color("#9FF6FF", a), true, -1.0, true)


# ---------- Клетки поля ----------

## Огненный кристалл в камне: камень, трещинки и пылающий кристалл в середине.
static func draw_bomb(g, p: Vector2, s: float) -> void:
	var r := Rect2(p + Vector2(3, 3), Vector2(s - 6, s - 6))
	var rad := s * 0.18
	var pulse := 0.5 + 0.5 * sin(g.t_total * 6.0 + p.x * 0.07)
	g._rbox(r.grow(2.0 + 2.0 * pulse), Color(BOMB_COL, 0.22 + 0.2 * pulse), rad + 3)
	g._rbox(r, g.STONE_COL.darkened(0.35), rad)
	g._rbox(Rect2(r.position, r.size - Vector2(0, 5)), g.STONE_COL.lerp(Color("#6B2F3A"), 0.45), rad)
	var c := r.get_center() + Vector2(0, -2)
	var hs := s * 0.27
	# огненные трещинки от кристалла к краям
	for d in [Vector2(-1, -0.8), Vector2(1, -0.6), Vector2(-0.7, 1), Vector2(0.9, 0.9)]:
		g.draw_line(c + d * hs * 0.6, c + d * hs * 1.35, Color(BOMB_COL, 0.55 + 0.4 * pulse), 2.5, true)
	g.draw_circle(c, s * 0.3, Color(BOMB_COL, 0.18 + 0.15 * pulse), true, -1.0, true)
	var gem := PackedVector2Array([c + Vector2(0, -hs), c + Vector2(hs * 0.75, -hs * 0.15), c + Vector2(0, hs), c + Vector2(-hs * 0.75, -hs * 0.15)])
	g.draw_colored_polygon(gem, BOMB_COL)
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -hs), c + Vector2(hs * 0.75, -hs * 0.15), c + Vector2(0, 0)]), BOMB_CORE)
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(0, hs), c + Vector2(-hs * 0.75, -hs * 0.15), c + Vector2(0, 0)]), Color("#C2361F"))
	# язычок пламени сверху
	var fl := 4.0 + 4.0 * pulse
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -hs + 2), c + Vector2(4, -hs + 2), c + Vector2(1, -hs - fl)]), Color(BOMB_CORE, 0.9))


## Кротёнок в шахтёрской каске (p — левый верхний угол клетки, s — размер клетки):
## бархатная шубка, розовый пятачок, крошечные глазки, широкие розовые лапки с коготками.
static func draw_pet(g, p: Vector2, s: float, bob := true) -> void:
	var k := s / 60.0
	var t: float = g.t_total
	var c := p + Vector2(s / 2.0, s * 0.6 - (absf(sin(t * 3.0)) * 2.0 * k if bob else 0.0))
	# мягкое свечение, чтобы зверька было видно среди камня
	g.draw_circle(c + Vector2(0, -2) * k, s * 0.52, Color(HELMET, 0.14), true, -1.0, true)
	# шубка: округлое тельце
	g.draw_set_transform(c, 0.0, Vector2(1.0, 0.92))
	g.draw_circle(Vector2.ZERO, 24 * k, PET_FUR.darkened(0.25), true, -1.0, true)
	g.draw_circle(Vector2(0, -1) * k, 22 * k, PET_FUR, true, -1.0, true)
	g.draw_set_transform(Vector2.ZERO)
	g.draw_circle(c + Vector2(-9, -6) * k, 7 * k, Color(1, 1, 1, 0.08), true, -1.0, true)
	# мордочка: светлая, вытянутая к пятачку
	g.draw_set_transform(c + Vector2(0, 7) * k, 0.0, Vector2(1.25, 1.0))
	g.draw_circle(Vector2.ZERO, 10 * k, PET_FACE, true, -1.0, true)
	g.draw_set_transform(Vector2.ZERO)
	# глазки-бусинки (моргают)
	var blink := 0.15 if fmod(t + p.x * 0.01, 3.7) < 0.12 else 1.0
	for sx in [-1.0, 1.0]:
		var e: Vector2 = c + Vector2(sx * 9, -3) * k
		g.draw_set_transform(e, 0.0, Vector2(1, blink))
		g.draw_circle(Vector2.ZERO, 2.6 * k, Color("#120A06"), true, -1.0, true)
		g.draw_circle(Vector2(-0.8, -0.9) * k, 0.9 * k, Color(1, 1, 1, 0.9), true, -1.0, true)
		g.draw_set_transform(Vector2.ZERO)
	# щёчки
	g.draw_circle(c + Vector2(-14, 4) * k, 3.5 * k, Color(PET_NOSE, 0.4), true, -1.0, true)
	g.draw_circle(c + Vector2(14, 4) * k, 3.5 * k, Color(PET_NOSE, 0.4), true, -1.0, true)
	# усики
	for sx in [-1.0, 1.0]:
		for dy in [-1.5, 1.5]:
			g.draw_line(c + Vector2(sx * 8, 7 + dy) * k, c + Vector2(sx * 17, 6 + dy * 2.2) * k, Color(1, 1, 1, 0.45), 1.0 * k, true)
	# пятачок
	g.draw_set_transform(c + Vector2(0, 4) * k, 0.0, Vector2(1.3, 1.0))
	g.draw_circle(Vector2.ZERO, 5 * k, PET_NOSE, true, -1.0, true)
	g.draw_set_transform(Vector2.ZERO)
	g.draw_circle(c + Vector2(-2, 3) * k, 1.6 * k, Color(1, 1, 1, 0.7), true, -1.0, true)
	g.draw_circle(c + Vector2(-2.5, 5) * k, 1.0 * k, Color("#B04A6A"), true, -1.0, true)
	g.draw_circle(c + Vector2(2.5, 5) * k, 1.0 * k, Color("#B04A6A"), true, -1.0, true)
	g.draw_arc(c + Vector2(0, 11) * k, 3.0 * k, 0.4, PI - 0.4, 8, Color("#5A3020"), 1.5 * k, true)
	# широкие лапки-лопатки с коготками
	for sx in [-1.0, 1.0]:
		var pc: Vector2 = c + Vector2(sx * 15, 18) * k
		g.draw_set_transform(pc, sx * 0.35, Vector2(1.0, 0.75))
		g.draw_circle(Vector2.ZERO, 7.5 * k, Color("#F2B8A0"), true, -1.0, true)
		g.draw_set_transform(Vector2.ZERO)
		for j in 3:
			var cx: float = (j - 1) * 4.0
			g.draw_line(pc + Vector2(cx, 3) * k, pc + Vector2(cx * 1.2, 7.5) * k, Color("#FFF4E6"), 1.8 * k, true)
	# каска: купол, козырёк, фонарик
	var hc := c + Vector2(0, -12) * k
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + i * PI / 12.0
		dome.append(hc + Vector2(cos(a) * 20, sin(a) * 15) * k)
	g.draw_colored_polygon(dome, HELMET)
	g.draw_line(hc + Vector2(0, -15) * k, hc + Vector2(0, -1) * k, HELMET.darkened(0.15), 3.0 * k, true)
	g._rbox(Rect2(hc + Vector2(-23, -2) * k, Vector2(46, 6) * k), HELMET.darkened(0.25), 3 * k)
	g.draw_line(hc + Vector2(-12, -11) * k, hc + Vector2(-6, -13) * k, Color(1, 1, 1, 0.6), 2.0 * k, true)
	var lamp := hc + Vector2(0, -8) * k
	var glow := 0.6 + 0.4 * sin(t * 4.0)
	g.draw_circle(lamp, 10 * k, Color(1, 1, 0.8, 0.2 * glow), true, -1.0, true)
	g.draw_circle(lamp, 5.5 * k, Color("#A0761E"), true, -1.0, true)
	g.draw_circle(lamp, 4 * k, Color("#FFFBE0"), true, -1.0, true)


## Клетка янтарного тайника. Соседние клетки тайника (left/right/up/down — там тоже тайник)
## сливаются в один сундук: доски, шов крышки, обивка и заклёпки по внешним краям.
static func draw_chest_cell(g, p: Vector2, s: float, left: bool, right: bool, up: bool, down: bool) -> void:
	var k := s / 60.0  # толщина обивки и заклёпок — по размеру клетки (на значке сундук маленький)
	var m := 3.0 * k
	var r := Rect2(p + Vector2(0.0 if left else m, 0.0 if up else m), Vector2(s - (0.0 if left else m) - (0.0 if right else m), s - (0.0 if up else m) - (0.0 if down else m)))
	g.draw_rect(r, AMBER_DARK)
	var inner := r.grow_individual(0.0 if left else -m, 0.0 if up else -m, 0.0 if right else -m, 0.0 if down else -5.0 * k)
	g.draw_rect(inner, AMBER)
	# доски
	for i in 2:
		var y: float = inner.position.y + inner.size.y * (0.33 + 0.33 * i)
		g.draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(AMBER_DARK, 0.55), maxf(1.0, 2.0 * k))
	# блик янтаря
	g.draw_line(inner.position + Vector2(6, 6) * k, inner.position + Vector2(16, 6) * k, Color(1, 1, 1, 0.35), maxf(1.0, 3.0 * k))
	# крышка: шов между верхним и нижним рядом сундука
	if up:
		g.draw_rect(Rect2(r.position.x, r.position.y - 3 * k, r.size.x, 7 * k), Color("#7A4512"))
		g.draw_rect(Rect2(r.position.x, r.position.y + 4 * k, r.size.x, 2 * k), Color(1, 0.85, 0.5, 0.35))
	# окованные края снаружи сундука и заклёпки по углам
	var band := Color("#6B3E10")
	var bw := 6.0 * k
	if not left:
		g.draw_rect(Rect2(r.position, Vector2(bw, r.size.y)), band)
	if not right:
		g.draw_rect(Rect2(Vector2(r.end.x - bw, r.position.y), Vector2(bw, r.size.y)), band)
	if not up:
		g.draw_rect(Rect2(r.position, Vector2(r.size.x, bw)), band)
	if not down:
		g.draw_rect(Rect2(Vector2(r.position.x, r.end.y - bw), Vector2(r.size.x, bw)), band)
	var rv := Color("#FFD36B")
	var ro := 9.0 * k
	if not left and not up:
		g.draw_circle(r.position + Vector2(ro, ro), 2.5 * k, rv, true, -1.0, true)
	if not right and not up:
		g.draw_circle(Vector2(r.end.x - ro, r.position.y + ro), 2.5 * k, rv, true, -1.0, true)
	if not left and not down:
		g.draw_circle(Vector2(r.position.x + ro, r.end.y - ro), 2.5 * k, rv, true, -1.0, true)
	if not right and not down:
		g.draw_circle(r.end - Vector2(ro, ro), 2.5 * k, rv, true, -1.0, true)


## Замок тайника в точке c (центр сундука).
static func draw_lock(g, c: Vector2, s: float) -> void:
	var k := s / 60.0
	g.draw_arc(c + Vector2(0, -6) * k, 8 * k, PI, TAU, 12, Color("#5A3A10"), 4 * k, true)
	g._rbox(Rect2(c + Vector2(-11, -6) * k, Vector2(22, 18) * k), Color("#FFD36B"), 4 * k)
	g.draw_circle(c + Vector2(0, 1) * k, 3 * k, Color("#5A3A10"), true, -1.0, true)
	g.draw_line(c + Vector2(0, 2) * k, c + Vector2(0, 8) * k, Color("#5A3A10"), 2.5 * k)


## Значок тайника (целый сундук 2×2) — для панели и карты. c — центр, s — сторона значка.
static func chest_icon(g, c: Vector2, s: float, opened := false) -> void:
	var h := s / 2.0
	var p := c - Vector2(h, h)
	draw_chest_cell(g, p, h, false, true, false, true)
	draw_chest_cell(g, p + Vector2(h, 0), h, true, false, false, true)
	draw_chest_cell(g, p + Vector2(0, h), h, false, true, true, false)
	draw_chest_cell(g, p + Vector2(h, h), h, true, false, true, false)
	if opened:
		g.draw_circle(c, s * 0.3, Color("#9FF6FF", 0.5), true, -1.0, true)
		g.draw_line(c + Vector2(-s * 0.18, 0), c + Vector2(-s * 0.04, s * 0.14), Color.WHITE, 4.0, true)
		g.draw_line(c + Vector2(-s * 0.04, s * 0.14), c + Vector2(s * 0.2, -s * 0.14), Color.WHITE, 4.0, true)
	else:
		draw_lock(g, c, s * 0.75)


## Значок цели уровня на карте (кротёнок / тайник) в правом верхнем углу точки; у обычной цели — ничего.
static func map_badge(g, c: Vector2, p: Dictionary) -> void:
	const Specials := preload("res://scripts/specials.gd")
	var gl := Specials.goal_of(p)
	if gl == Specials.GOAL_CRYSTALS:
		return
	var at := c + Vector2(40, -40)
	g.draw_circle(at, 24, Color(0.06, 0.035, 0.13, 0.92), true, -1.0, true)
	g.draw_arc(at, 24, 0, TAU, 32, Color(HELMET if gl == Specials.GOAL_PET else AMBER, 0.9), 3.0, true)
	if gl == Specials.GOAL_PET:
		draw_pet(g, at - Vector2(21, 23), 42, false)
	else:
		chest_icon(g, at, 30)
