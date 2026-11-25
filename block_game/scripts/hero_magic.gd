extends RefCounted
## Cascado 0.12: «живые» вещи героя — спутники, сияния (ауры), узоры окрасок наборов,
## эффекты редкости на герое и наряд мастера-филина Уха (кузница).
## Рисует через помощников героя h (scripts/hero.gd) в координатах героя.
## Точки героя (a — hero.gd, _anchors): comp — где летает спутник, center/size — середина и
## «радиус» героя для сияний, hp — поворот головы (для узоров на голове), top — макушка.

const Meta := preload("res://scripts/meta.gd")
const Rarity := preload("res://scripts/rarity.gd")
const Sets := preload("res://scripts/hero_sets.gd")


## Узоры окрасок: где на теле героя (включить эллипсы) и где нельзя (мордочка)
const SKIN_ZONES := {
	"owl": {"in": [[Vector2(0, 14), 86.0, 90.0]], "out": [[Vector2(-37, -30), 52.0, 52.0], [Vector2(37, -30), 52.0, 52.0], [Vector2(0, 112), 70.0, 20.0]], "head_y": -24.0},
	"axolotl": {"in": [[Vector2(0, -26), 92.0, 62.0], [Vector2(0, 66), 54.0, 40.0]], "out": [[Vector2(0, -18), 74.0, 34.0], [Vector2(-60, 98), 22.0, 22.0], [Vector2(60, 98), 22.0, 22.0]], "head_y": 30.0},
	"puppy": {"in": [[Vector2(0, -44), 84.0, 64.0], [Vector2(0, 66), 56.0, 44.0]], "out": [[Vector2(0, -26), 64.0, 40.0], [Vector2(-27, 100), 24.0, 26.0], [Vector2(27, 100), 24.0, 26.0]], "head_y": 30.0},
	"kitten": {"in": [[Vector2(0, -44), 82.0, 62.0], [Vector2(0, 66), 50.0, 42.0]], "out": [[Vector2(0, -26), 64.0, 40.0], [Vector2(-23, 100), 22.0, 26.0], [Vector2(23, 100), 22.0, 26.0]], "head_y": 30.0},
}

static var _pts_cache := {}
static var _pairs_cache := {}


## Пары звёзд для линий созвездия (по ближайшей соседке), один раз на героя
static func _pairs(kind: String) -> Array:
	if _pairs_cache.has(kind):
		return _pairs_cache[kind]
	var pts := skin_points(kind)
	var n := pts.size()
	var out: Array = []
	for i in n:
		var best := -1
		var bd := 82.0
		for j in n:
			var d: float = (pts[i][0] as Vector2).distance_to(pts[j][0])
			if j != i and d < bd:
				bd = d
				best = j
		if best > i or (best >= 0 and i % 3 == 0):
			out.append([i, best])
	_pairs_cache[kind] = out
	return out


static func hs(i: float, k := 0.0) -> float:
	return fposmod(sin(i * 12.9898 + k * 78.233) * 43758.5453, 1.0)


static func _in_ell(p: Vector2, e: Array) -> bool:
	var d: Vector2 = p - e[0]
	return pow(d.x / e[1], 2) + pow(d.y / e[2], 2) <= 1.0


## Точки узора на теле героя (одни и те же между кадрами): [точка, на голове ли]
static func skin_points(kind: String) -> Array:
	if _pts_cache.has(kind):
		return _pts_cache[kind]
	var z: Dictionary = SKIN_ZONES.get(kind, SKIN_ZONES.owl)
	var out: Array = []
	var i := 0
	while out.size() < 18 and i < 3000:
		i += 1
		var p := Vector2((hs(i, 1) - 0.5) * 200.0, (hs(i, 2) - 0.5) * 260.0)
		var ok := false
		for e in z.in:
			if _in_ell(p, e):
				ok = true
		for e in z.out:
			if _in_ell(p, e):
				ok = false
		for q in out:
			if (q[0] as Vector2).distance_to(p) < 30.0:
				ok = false
		if ok:
			out.append([p, p.y < float(z.head_y)])
	_pts_cache[kind] = out
	return out


## Точки узора в координатах героя с учётом поворота головы
static func _skin_pts_now(kind: String, a: Dictionary) -> Array:
	var res: Array = []
	for e in skin_points(kind):
		var p: Vector2 = e[0]
		if e[1] and a.has("hp"):
			p = a.hp.call(p)
		res.append(p)
	return res


# ==================== Узоры окрасок ====================

static func skin_fx(h, outfit: Dictionary, a: Dictionary, t: float, head_only: bool) -> void:
	var sk: String = Meta.draw_key(outfit.get("skin", ""))
	if sk == "" or a.kind == "icon":
		return
	var kind: String = a.kind
	var pts := _skin_pts_now(kind, a)
	if head_only:
		# аватарка: только точки головы
		var hp: Array = []
		for i in pts.size():
			if skin_points(kind)[i][1]:
				hp.append(pts[i])
		pts = hp
	h._T = Transform2D.IDENTITY
	match sk:
		"skin_pearl":
			for i in mini(pts.size(), 6):
				var hh := fposmod(t * 0.1 + i * 0.13, 1.0)
				var c := Sets.hsv(0.5 + 0.4 * sin(hh * TAU) * 0.5 + 0.1, 0.35, 1.0, 0.22)
				h._glow(pts[i], 30, 26, Sets.q(c))
			var ph := fposmod(t / 3.2, 1.0)
			if ph < 0.45:
				var k := ph / 0.45
				var c2: Vector2 = a.center + Vector2(lerpf(-a.size * 1.1, a.size * 1.1, k), lerpf(-a.size * 0.6, a.size * 0.4, k))
				h._glow(c2, a.size * 0.25, a.size * 0.85, Color(1, 1, 1, snappedf(0.4 * sin(k * PI), 0.04)), -0.6)
		"skin_midnight":
			for i in pts.size():
				var tw := 0.5 + 0.5 * sin(t * (1.5 + hs(i, 3) * 2.0) + i * 1.9)
				var r := 2.5 + 4.0 * tw * (0.6 + hs(i, 4) * 0.6)
				h._sparkle(pts[i], r, Color(1.0, 0.96, 0.75, 0.35 + 0.65 * tw))
				h._dot(pts[i], 1.2, Color(1, 1, 1, 0.9))
		"skin_constellation":
			_constellation(h, pts, t, kind, not head_only)
		"pu_skin_cotton":
			# 0.13: «Сахарная вата» — пастельные пятнышки-облачка и сахарные искорки
			for i in pts.size():
				var p: Vector2 = pts[i]
				if i % 2 == 0:
					h._glow(p, 14, 11, Color(0.75, 0.85, 1.0, 0.3) if i % 4 == 0 else Color(0.85, 0.7, 1.0, 0.28))
				var ph := fposmod(t * 0.5 + hs(i, 7) * 2.0, 2.0)
				if ph < 0.6:
					h._sparkle(p + Vector2(3, -4), 5.0 * sin(ph / 0.6 * PI), Color(1, 1, 1, 0.9))
		"ow_skin_snowy":
			# 0.12b: полярная сова — тёмные крапинки-«галочки» и редкие снежинки-искры
			for i in pts.size():
				var p: Vector2 = pts[i]
				h._T = Transform2D(-0.1 + hs(i, 5) * 0.2, p)
				h._arc(Vector2.ZERO, 5.5, 3.5, 0.15 * PI, 0.85 * PI, Color("#3A3550", 0.7), 2.6, 6)
				h._T = Transform2D.IDENTITY
				var ph := fposmod(t * 0.35 + hs(i, 6) * 3.0, 3.0)
				if i % 3 == 0 and ph < 0.5:
					h._sparkle(p + Vector2(4, -6), 6.0 * sin(ph / 0.5 * PI), Color(0.85, 0.95, 1.0, 0.9))


## Окраска СОЗВЕЗДИЕ: линии созвездий по телу, звёзды загораются по очереди
static func _constellation(h, pts: Array, t: float, kind: String, lines: bool) -> void:
	var n := pts.size()
	# линии созвездий: каждая звезда — к ближайшей соседке (короткие, не через мордочку);
	# пары считаются один раз на героя
	if lines:
		for pr in _pairs(kind):
			h.ci.draw_line(pts[pr[0]], pts[pr[1]], Color(0.75, 0.85, 1.0, 0.5), 1.8, true)
	for i in n:
		var ph := fposmod(t * 0.9 - i * 0.2, n * 0.2 + 0.6)
		var lit := maxf(0.0, 1.0 - ph * 1.8)
		var p: Vector2 = pts[i]
		h._glow(p, 10 + 14 * lit, 10 + 14 * lit, Color(1.0, 0.9, 0.5, snappedf(0.22 + 0.5 * lit, 0.05)))
		h._sparkle(p, 3.5 + 7.0 * lit, Color(1.0, 0.95, 0.7, 0.75 + 0.25 * lit))
		h._dot(p, 1.8, Color.WHITE)


# ==================== Спутники ====================

## Где сейчас спутник (для эффекта редкости и порядка рисования)
static func comp_pos(id: String, a: Dictionary, t: float) -> Vector2:
	var b: Vector2 = a.comp
	match id:
		"firefly":
			return b + Vector2(sin(t * 1.3) * 34, sin(t * 2.6) * 14)
		"bubble_pet":
			return b + Vector2(sin(t * 0.7) * 10, sin(t * 1.5) * 6)
		"moon_moth":
			return b + Vector2(sin(t * 0.9) * 18, sin(t * 1.7) * 10 - 6)
		"mini_planet":
			var ang := t * 0.8
			return a.center + Vector2(cos(ang) * a.size * 1.25, a.size * 0.42 + sin(ang) * a.size * 0.22)
		"seahorse":
			return b + Vector2(sin(t * 0.8) * 8, sin(t * 1.4) * 9)
	return b


## Спутник позади героя? (мини-планета облетает вокруг)
static func comp_behind(id: String, t: float) -> bool:
	return id == "mini_planet" and sin(t * 0.8) < 0.0


static func companion(h, id: String, a: Dictionary, t: float, react: float, front: bool) -> void:
	if id == "" or comp_behind(id, t) == front:
		return
	var p := comp_pos(id, a, t)
	h._T = Transform2D.IDENTITY
	match id:
		"firefly": _firefly(h, a, p, t)
		"bubble_pet": _bubble_pet(h, p, t)
		"moon_moth": _moon_moth(h, p, t)
		"mini_planet": _mini_planet(h, p, t)
		"seahorse": _seahorse(h, p, t, react)
	h._T = Transform2D.IDENTITY


## Светлячок: жёлтая точка с ореолом, летает восьмёркой и мерцает
static func _firefly(h, a: Dictionary, p: Vector2, t: float) -> void:
	var fl := 0.55 + 0.45 * sin(t * 7.0 + sin(t * 2.3) * 2.0)
	for k in range(1, 7):
		var tp := comp_pos("firefly", a, t - k * 0.07)
		h._dot(tp, 3.4 - k * 0.4, Color(0.95, 1.0, 0.5, 0.45 * (1.0 - k / 7.0)))
	h._glow(p, 26 + 20 * fl, 26 + 20 * fl, Color(0.92, 1.0, 0.4, snappedf(0.3 + 0.35 * fl, 0.04)))
	var wf := absf(sin(t * 30.0))
	h._T = Transform2D(0.0, Vector2(1.4, 1.4), 0.0, p)
	h._oval(Vector2(-4, -6), 6, 2.5 + 2.5 * wf, Color(1, 1, 1, 0.7), -0.5)
	h._oval(Vector2(1, -7), 6, 2.5 + 2.5 * wf, Color(1, 1, 1, 0.6), 0.4)
	h._ball(Vector2(-4, -1), 4.5, 3.6, Color("#4A3A58"), 0.3, 1.0, 0.4, 0.8)
	h._ball(Vector2(3, 1), 5.5, 5, Color("#F5FF6A").lerp(Color.WHITE, fl * 0.45), 0.0, 1.0, 0.8, 0.8)
	h._dot(Vector2(-6.5, -2.5), 1.2, Color.WHITE)
	h._T = Transform2D.IDENTITY
	h._sparkle(p + Vector2(3, 1), 4.0 + 6.0 * fl, Color(1, 1, 0.85, 0.5 + 0.5 * fl))


## Пузырёк: прозрачный шар с крошечной рыбкой; иногда лопается и надувается снова
static func _bubble_pet(h, p: Vector2, t: float) -> void:
	var ph := fposmod(t, 7.0)
	var sc := 1.0
	if ph > 6.0 and ph < 6.3:
		sc = 0.0
		var k := (ph - 6.0) / 0.3
		for i in 8:
			var ang := i * TAU / 8.0 + 0.3
			h._dot(p + Vector2(cos(ang), sin(ang)) * (24 + k * 26), 3.0 * (1.0 - k) + 0.5, Color(0.8, 0.97, 1.0, 1.0 - k))
	elif ph >= 6.3:
		sc = smoothstep(6.3, 7.0, ph)
	var r := 26.0 * sc
	if r > 1.0:
		h.ci.draw_circle(p, r, Color(0.6, 0.9, 1.0, 0.14), true, -1.0, true)
	# рыбка
	var fx := sin(t * 1.1) * 8.0
	var dir := -1.0 if cos(t * 1.1) > 0.0 else 1.0
	var fp := p + Vector2(fx, 3 + (1.0 - sc) * 6.0)
	h._T = Transform2D(0.0, Vector2(dir, 1.0), 0.0, fp)
	h._fill(PackedVector2Array([Vector2(7, 0), Vector2(14, -6), Vector2(13, 6)]), Color("#FF6A2E"))
	h._ball(Vector2.ZERO, 9, 6.5, Color("#FF8A3D"), 0.0, 1.0, 0.7, 1.0)
	h._dot(Vector2(-4.5, -1.5), 1.8, Color("#1A0E30"))
	h._dot(Vector2(-5, -2), 0.7, Color.WHITE)
	h._T = Transform2D.IDENTITY
	if r > 1.0:
		var hh := fposmod(t * 0.2, 1.0)
		h._arc(p, r, r, 0, TAU, Color(0.85, 0.98, 1.0, 0.75), 2.4, 28)
		h._arc(p, r - 1.5, r - 1.5, 0.1 * PI, 0.6 * PI, Sets.hsv(hh, 0.5, 1.0, 0.7), 2.4, 10)
		h._arc(p, r - 1.5, r - 1.5, 1.6 * PI, 1.9 * PI, Sets.hsv(hh + 0.4, 0.5, 1.0, 0.6), 2.0, 8)
		h._oval(p + Vector2(-r * 0.4, -r * 0.45), r * 0.24, r * 0.14, Color(1, 1, 1, 0.9), -0.6)
		h._dot(p + Vector2(r * 0.35, r * 0.4), r * 0.07, Color(1, 1, 1, 0.7))


## Лунный мотылёк: мятные крылья с хвостиками, сиреневые «глазки», машет крыльями
static func _moon_moth(h, p: Vector2, t: float) -> void:
	var k := 0.4 + 0.6 * absf(sin(t * 6.0))
	h._glow(p, 34, 30, Color(0.85, 0.95, 1.0, 0.25))
	h._T = Transform2D(0.0, Vector2(k, 1.0), 0.0, p)
	for sx in [-1.0, 1.0]:
		var tail := PackedVector2Array([Vector2(sx * 3, 2), Vector2(sx * 16, 6), Vector2(sx * 18, 16), Vector2(sx * 12, 30), Vector2(sx * 14, 40), Vector2(sx * 8, 32), Vector2(sx * 4, 12)])
		h._shape(["moth_tail", sx], h._chaikin(tail, 1), Vector2(sx * 10, 14), Color("#B8F0D8"), 1.2, 0.4, 1.0)
		h._ball(Vector2(sx * 15, -8), 15, 11, Color("#D2FAE8"), sx * -0.5, 1.2, 0.5, 1.0)
		h._ball(Vector2(sx * 17, -9), 4.5, 4.5, Color("#B9A4FF"), 0.0, 1.0, 0.7, 0.6)
		h._dot(Vector2(sx * 17, -9), 1.6, Color("#4A2A7A"))
		h._arc(Vector2(sx * 15, -8), 14, 10, PI * (1.1 if sx < 0 else 1.65), PI * (1.35 if sx < 0 else 1.9), Color("#FFE680", 0.8), 1.6, 6)
	h._T = Transform2D(0.0, p)
	h._ball(Vector2(0, 0), 4, 11, Color("#FFFFFF"), 0.0, 1.1, 0.4, 1.0)
	for sx in [-1.0, 1.0]:
		h._line(PackedVector2Array([Vector2(sx * 1.5, -9), Vector2(sx * 6, -18), Vector2(sx * 10, -20)]), Color("#E8D8A0"), 1.6)
		for m in 3:
			var q := Vector2(sx * (3 + m * 2.5), -12 - m * 2.8)
			h._line(PackedVector2Array([q, q + Vector2(sx * 2.5, -1)]), Color("#E8D8A0", 0.8), 1.0)
	h._T = Transform2D.IDENTITY
	h._sparkle(p + Vector2(18, -16), 2.5 + 2.0 * sin(t * 5.0), Color(1, 1, 1, 0.85))


## Мини-планета: фиолетовый шарик с кольцом облетает героя
static func _mini_planet(h, p: Vector2, t: float) -> void:
	var z := sin(t * 0.8)
	var s := 0.85 + 0.2 * z
	h._T = Transform2D(0.0, Vector2(s, s), 0.0, p)
	var rr := PackedVector2Array()
	for i in 25:
		var ang := PI + PI * i / 24.0
		rr.append(Vector2(cos(ang) * 30, sin(ang) * 8).rotated(-0.35))
	h._line(rr, Color("#FFC2EC", 0.9), 4.0)
	h._glow(Vector2.ZERO, 26, 26, Color(0.75, 0.5, 1.0, 0.3))
	h._ball(Vector2.ZERO, 16, 16, Color("#9A5CE8"), 0.0, 1.0, 0.6)
	h._arc(Vector2(0, -4), 15, 5, 0.1 * PI, 0.9 * PI, Color("#C7A2FF", 0.7), 3.0, 8)
	h._arc(Vector2(0, 5), 14, 5, 0.15 * PI, 0.85 * PI, Color("#6A34B8", 0.6), 3.0, 8)
	var rf := PackedVector2Array()
	for i in 25:
		var ang := PI * i / 24.0
		rf.append(Vector2(cos(ang) * 30, sin(ang) * 8).rotated(-0.35))
	h._line(rf, Color("#FFE0F6"), 4.0)
	h._line(rf.slice(3, 10), Color(1, 1, 1, 0.8), 1.6)
	var ma := t * 2.2
	h._ball(Vector2(cos(ma) * 24, sin(ma) * 10 - 10), 3.4, 3.4, Color("#F4F0FF"), 0.0, 1.0, 0.6, 0.8)
	h._T = Transform2D.IDENTITY


## МОРСКОЙ КОНЁК-СТРАЖ (легендарный): золотой конёк с плавником-веером и следом пузырьков;
## при победе (касании) делает сальто
static func _seahorse(h, p: Vector2, t: float, react: float) -> void:
	# пузырьки
	for i in 6:
		var ph := fposmod(t * 0.55 + i / 6.0, 1.0)
		var bp := p + Vector2(16 + sin(ph * 7.0 + i) * 5.0, 26 - ph * 70.0)
		h._arc(bp, 2.5 + ph * 3.0, 2.5 + ph * 3.0, 0, TAU, Color(0.8, 0.97, 1.0, 0.75 * (1.0 - ph)), 1.4, 10)
	var rot := 0.0
	if react >= 0.0 and react < 1.0:
		rot = -TAU * smoothstep(0.0, 1.0, react)
	h._glow(p, 50, 60, Color(1.0, 0.85, 0.35, 0.3))
	h._T = Transform2D(rot + sin(t * 1.4) * 0.06, Vector2(1.35, 1.35), 0.0, p)
	# плавник-веер на спине колышется
	var fan := PackedVector2Array([Vector2(7, -10)])
	for i in 9:
		var ang := lerpf(-1.2, 0.9, i / 8.0) + sin(t * 4.0 + i * 0.6) * 0.06
		fan.append(Vector2(7, -2) + Vector2(cos(ang), sin(ang)) * (17 + sin(i * 1.7) * 1.5))
	fan.append(Vector2(8, 8))
	var fc := PackedColorArray()
	for i in fan.size():
		fc.append(Color(1.0, 0.92, 0.6, 0.55 if i == 0 or i == fan.size() - 1 else 0.85))
	h.ci.draw_polygon(h._T * fan, fc)
	for i in range(1, 9, 2):
		h._line(PackedVector2Array([Vector2(7, -2), fan[i]]), Color("#E0A020", 0.6), 1.0)
	# тело: цепочка шариков от головы к закрученному хвосту
	var spine := [Vector2(-2, -22), Vector2(3, -13), Vector2(5, -3), Vector2(3, 7), Vector2(-1, 15), Vector2(-2, 22), Vector2(2, 28), Vector2(8, 28), Vector2(9, 22), Vector2(5, 20)]
	var rads := [9.5, 7.5, 8.5, 8.5, 7.0, 5.5, 4.5, 3.6, 3.0, 2.4]
	var gold := Color("#FFC23A")
	for i in range(spine.size() - 1, -1, -1):
		h._ball(spine[i], rads[i], rads[i] * 0.95, gold if i % 2 == 0 else gold.lerp(Color("#FFE08A"), 0.3), 0.0, 1.0, 0.75, 1.0)
	for i in range(1, 5):
		h._arc(spine[i] + Vector2(-2, 0), rads[i] * 0.8, rads[i] * 0.4, 0.55 * PI, 1.05 * PI, Color("#B8771A", 0.7), 1.6, 6)
	# мордочка-трубочка, корона, глаз
	h._ball(Vector2(-13, -19), 8, 3.6, gold.lerp(Color("#FFE08A"), 0.2), -0.2, 1.0, 0.7, 1.0)
	for k in 3:
		h._ball(Vector2(-3 + k * 4, -31 + absf(k - 1) * 2), 2.2, 3.6, Color("#FFE89A"), (k - 1) * 0.4, 1.0, 0.9, 0.8)
	h._ball(Vector2(-3, -24), 3.4, 3.4, Color.WHITE, 0.0, 1.0, 0.4, 0.8)
	h._dot(Vector2(-3.5, -24), 2.0, Color("#1A0E30"))
	h._dot(Vector2(-4.3, -25), 0.8, Color.WHITE)
	h._dot(Vector2(-1, -15), 2.2, Color(1.0, 0.5, 0.6, 0.6))
	h._T = Transform2D.IDENTITY
	h._sparkle(p + Vector2(-10, -30), 3 + 3 * (0.5 + 0.5 * sin(t * 4.0)), Color.WHITE)


# ==================== Сияния (ауры) ====================

static func aura(h, id: String, a: Dictionary, t: float, react: float, front: bool) -> void:
	if id == "":
		return
	h._T = Transform2D.IDENTITY
	var c: Vector2 = a.center
	var R: float = a.size
	match id:
		"aura_bubbles": _bubbles(h, c, R, t, front)
		"aura_starfall": _starfall(h, c, R, t, front)


## Пузырьки поднимаются вокруг героя (сияние аксолотля «Пузырьки»)
static func _bubbles(h, c: Vector2, R: float, t: float, front: bool) -> void:
	if not front:
		h._glow(c, R * 1.3, R * 1.35, Color(0.45, 0.9, 1.0, 0.18))
	for i in 12:
		if (i % 2 == 1) != front:
			continue
		var per := 3.5 + hs(i, 1) * 2.5
		var ph := fposmod(t / per + hs(i, 2), 1.0)
		var x := c.x + (hs(i, 3) - 0.5) * R * 2.5 + sin(t * 1.4 + i) * 9.0
		var y := c.y + R * 1.05 - ph * R * 2.5
		var al := sin(ph * PI)
		var p := Vector2(x, y)
		var r := 4.0 + hs(i, 4) * 8.0
		h._arc(p, r, r, 0, TAU, Color(0.8, 0.97, 1.0, 0.75 * al), 1.8, 16)
		h.ci.draw_circle(p, r, Color(0.6, 0.9, 1.0, 0.1 * al), true, -1.0, true)
		h._oval(p + Vector2(-r * 0.4, -r * 0.4), r * 0.3, r * 0.18, Color(1, 1, 1, 0.85 * al), -0.6)


## Звездопад: косые падающие звёзды с хвостами
static func _starfall(h, c: Vector2, R: float, t: float, front: bool) -> void:
	if not front:
		h._glow(c, R * 1.3, R * 1.35, Color(0.85, 0.45, 1.0, 0.16))
		h._glow(c + Vector2(0, -R * 0.3), R * 0.9, R * 0.8, Color(1.0, 0.5, 0.85, 0.1))
	var dir := Vector2(-0.55, 1.0).normalized()
	for i in 7:
		if (i % 2 == 1) != front:
			continue
		var per := 1.8 + hs(i, 1) * 1.6
		var ph := fposmod(t / per + hs(i, 2), 1.0)
		var start := c + Vector2(R * (0.2 + hs(i, 3) * 1.4), -R * 1.6)
		var p := start + dir * ph * R * 3.0
		var al := sin(ph * PI)
		var tail := p - dir * R * 0.55
		h.ci.draw_polyline_colors(PackedVector2Array([tail, p]), PackedColorArray([Color(1.0, 0.5, 0.9, 0.0), Color(1.0, 0.95, 0.8, 0.95 * al)]), 4.5, true)
		h._glow(p, 18, 18, Color(1.0, 0.85, 0.6, snappedf(0.55 * al, 0.05)))
		h._sparkle(p, 10.0 * al + 1.0, Color(1.0, 0.98, 0.85, al))
		h._dot(p, 2.5 * al + 0.5, Color.WHITE)


static func closed(p: PackedVector2Array) -> PackedVector2Array:
	var o := p.duplicate()
	o.append(p[0])
	return o


# ==================== Эффект редкости на герое ====================

static func rarity_fx(h, outfit: Dictionary, a: Dictionary, t: float) -> void:
	if a.kind == "icon":
		return
	h._T = Transform2D.IDENTITY
	var k: float = a.top_w / 100.0
	for slot in ["head", "eyes", "neck", "back", "companion"]:
		var id: String = outfit.get(slot, "")
		if id == "" or id.begins_with("_"):
			continue
		var rar := Meta.rarity(id)
		if rar == "common":
			continue
		var c := Vector2.ZERO
		var rad := 30.0
		match slot:
			"head":
				c = a.top + Vector2(0, -22 * k).rotated(a.tilt)
				rad = a.top_w * 0.48
			"eyes":
				c = (a.eye_l + a.eye_r) / 2.0
				rad = (a.eye_l as Vector2).distance_to(a.eye_r) * 0.7
			"neck":
				c = a.neck + Vector2(0, 8)
				rad = a.neck_w * 0.34
			"back":
				c = a.back + Vector2(-a.back_w * 0.62, a.back_w * 0.28)
				rad = a.back_w * 0.22
			"companion":
				c = comp_pos(Meta.draw_key(id), a, t)
				rad = 26.0
		var seed := float(slot.hash() % 97) * 0.1
		if rar == "epic":
			var hh := fposmod(t * 0.14 + seed, 1.0)
			h._glow(c, rad * 1.1, rad * 0.9, Sets.q(Sets.hsv(hh, 0.55, 1.0, 0.2)))
		elif rar == "legendary":
			var pulse := 0.5 + 0.5 * sin(t * 2.0 + seed)
			h._glow(c, rad * 1.35, rad * 1.2, Color(1.0, 0.86, 0.4, snappedf(0.16 + 0.12 * pulse, 0.04)))
		Rarity.on_hero(h.ci, rar, c, rad, t, seed)
	var sk: String = outfit.get("skin", "")
	if sk != "" and not sk.begins_with("_") and Meta.rarity(sk) == "legendary":
		Rarity.on_hero(h.ci, "legendary", a.center, a.size * 0.95, t, 4.0)


# ==================== Мастер-филин Ух (кузница) ====================

## Очки-половинки в тонкой золотой оправе, откинутая лупа и пушистые белые брови
static func master_eyes(h, a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad * 0.95
	for i in 2:
		var e: Vector2 = [a.eye_l, a.eye_r][i]
		h._T = Transform2D(a.tilt, e + Vector2(0, r * 0.2))
		var lens := PackedVector2Array()
		for k in 15:
			var ang := lerpf(-0.12, PI + 0.12, k / 14.0)
			lens.append(Vector2(cos(ang) * r, sin(ang) * r * 0.85))
		h._vgrad(lens, Color(0.85, 0.95, 1.0, 0.12), Color(0.7, 0.85, 1.0, 0.25), false)
		var cl := lens.duplicate()
		cl.append(lens[0])
		h._line(cl, GOLDC, r * 0.1)
		h._line(PackedVector2Array([Vector2(-r * 0.6, r * 0.2), Vector2(-r * 0.3, r * 0.55)]), Color(1, 1, 1, 0.6), r * 0.08)
	h._T = Transform2D.IDENTITY
	var l: Vector2 = a.eye_l + Vector2(r, r * 0.15).rotated(a.tilt)
	var rr: Vector2 = a.eye_r - Vector2(r, -r * 0.15).rotated(a.tilt)
	h._line(PackedVector2Array([l, (l + rr) / 2.0 + Vector2(0, -r * 0.15), rr]), GOLDC, r * 0.1)
	# лупа ювелира, откинутая вверх на правом глазу
	var lp: Vector2 = a.eye_r + Vector2(r * 0.55, -r * 1.25).rotated(a.tilt)
	h._T = Transform2D(a.tilt - 0.5, lp)
	h._shape(["ux_loupe"], h._rrect(Rect2(-r * 0.42, -r * 0.5, r * 0.84, r * 0.95), r * 0.2), Vector2.ZERO, Color("#3A2A55"), 1.2, 0.6)
	h._ball(Vector2(0, -r * 0.52), r * 0.42, r * 0.16, Color("#9FF6FF"), 0.0, 1.0, 1.0, 1.0)
	h._T = Transform2D.IDENTITY
	# брови
	for sx in [-1.0, 1.0]:
		var e: Vector2 = a.eye_l if sx < 0 else a.eye_r
		for k in 4:
			var bp: Vector2 = e + Vector2(sx * (r * 0.2 + k * r * 0.28), -r * 1.08 - k * r * 0.12).rotated(a.tilt)
			h._ball(bp, r * 0.3, r * 0.16, Color("#FFFFFF"), sx * (0.35 + k * 0.15), 1.2, 0.3, 1.0)
	h._sparkle(a.eye_l + Vector2(-r * 0.5, r * 0.3), r * 0.15 * (0.5 + 0.5 * sin(t * 3.0)), Color.WHITE)


const GOLDC := Color("#E0A63C")


## Кожаный фартук ювелира с кармашком: молоточек и кристалл
static func master_apron(h, a: Dictionary, t: float) -> void:
	var n: Vector2 = a.neck
	var pts: PackedVector2Array = h._rrect(Rect2(n.x - 52, n.y + 6, 104, 92), 26)
	h._T = Transform2D.IDENTITY
	h._shape(["ux_apron"], pts, n + Vector2(0, 50), Color("#9A5A34"), 2.0, 0.35)
	h.ci.draw_polyline(closed(pts), Color("#5E3018"), 2.0, true)
	for sx in [-1.0, 1.0]:
		h._line(PackedVector2Array([n + Vector2(sx * 44, 12), n + Vector2(sx * 62, -6)]), Color("#7A4424"), 6.0)
	var pk: PackedVector2Array = h._rrect(Rect2(n.x - 30, n.y + 46, 60, 34), 10)
	h._vgrad(pk, Color("#B56E40"), Color("#8A4A26"))
	h.ci.draw_polyline(closed(pk), Color("#E8B888", 0.6), 1.4, true)
	for i in 6:
		h._dot(pk[i * 4] + (n + Vector2(0, 63) - pk[i * 4]) * 0.15, 1.2, Color("#FFE0B0", 0.6))
	# молоточек
	h._line(PackedVector2Array([n + Vector2(-16, 50), n + Vector2(-8, 26)]), Color("#C08A50"), 4.0)
	h._T = Transform2D(-0.35, n + Vector2(-8, 24))
	h._shape(["ux_hammer"], h._rrect(Rect2(-11, -5, 22, 10), 3), Vector2.ZERO, Color("#B8C0DA"), 1.2, 0.8)
	h._T = Transform2D.IDENTITY
	h._gem(n + Vector2(12, 40), 9.0, Color("#3FE0D0"))
	h._sparkle(n + Vector2(18, 33), 3.5 + 2.5 * sin(t * 4.0), Color.WHITE)
