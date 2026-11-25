extends RefCounted
## Cascado 0.12b: гардероб АКСОЛОТЛЯ — житель глубин. Рисуется только на аксолотле
## (точки крепления — hero.gd, _anchors "axolotl"; жабры — h._gills, этап part_gills).
## Наборы: «Коралловый риф», «Жемчужная лагуна», «Тайны бездны»; награды кузницы — Морской конёк-страж,
## Плащ морской волны, Танец планктона; супер-эксклюзив — Сияние глубин (жабры светятся переливом,
## вокруг плавают медузы-фонарики, жемчужная корона).

const Sets := preload("res://scripts/hero_sets.gd")

const GOLD := Color("#FFC83A")
const GOLD_D := Color("#B8771A")
const PEARL := Color("#FFF6FA")
const CORAL := Color("#FF7A6B")


static func hs(i: float, k := 0.0) -> float:
	return Sets.hs(i, k)


static func item(h, id: String, stage: String, a: Dictionary, t: float) -> void:
	match id:
		"ax_starfish":
			if stage == "head":
				starfish(h, a, t)
		"ax_coral_beads":
			if stage == "neck":
				coral_beads(h, a, t)
		"ax_gill_pearls":
			if stage == "part_gills":
				gill_pearls(h, t)
		"ax_shell_pack":
			if stage == "back_b" or stage == "back_f":
				shell_pack(h, a, t, stage == "back_b")
		"ax_black_pearl":
			if stage == "neck":
				black_pearl(h, a, t)
		"ax_porthole":
			if stage == "eyes":
				porthole(h, a, t)
		"ax_angler":
			if stage == "head":
				angler(h, a, t)
		"ax_abyssal":
			if stage == "worn":
				pearl_crown(h, a, t)
				if a.kind == "axolotl":
					_glow_freckles(h, t)
			elif stage == "part_gills":
				glow_gills(h, t)


static func companion(h, id: String, a: Dictionary, t: float, react: float, front: bool) -> void:
	if id == "ax_squid" and front:
		squid(h, a.comp + Vector2(sin(t * 0.8) * 12.0, sin(t * 1.6) * 9.0), t, react)


static func aura(h, id: String, a: Dictionary, t: float, react: float, front: bool) -> void:
	match id:
		"ax_plankton":
			plankton(h, a, t, front)
		"ax_abyssal":
			jellies(h, a, t, front)


static func icon(h, id: String, slot: String, a: Dictionary, t: float) -> bool:
	match id:
		"ax_gill_pearls":
			# три жабры-веточки с жемчужинами на кончиках
			var gl: Array = []
			for i in 3:
				var ang := -2.2 + i * 0.55
				var pts := PackedVector2Array()
				for k in 7:
					pts.append(Vector2(20, 70) + Vector2(cos(ang), sin(ang)) * 110.0 * k / 6.0 + Vector2(0, sin(k * 0.6) * 6.0))
				gl.append(pts)
			for pts in gl:
				h.ci.draw_polyline(pts, Color("#FF6FA8"), 14.0, true)
				for k in range(1, 7):
					var d: Vector2 = (pts[k] - pts[k - 1]).normalized()
					h._ball(pts[k] + d.orthogonal() * 10.0, 9, 5, Color("#FFB0D0"), d.angle() + 0.6, 1.0, 0.3, 0.0)
					h._ball(pts[k] - d.orthogonal() * 10.0, 9, 5, Color("#FFB0D0"), d.angle() - 0.6, 1.0, 0.3, 0.0)
			h._gills = gl
			gill_pearls(h, t, 2.0)
			return true
		"ax_starfish":
			a.top = Vector2(-108, -48)
			a.top_w = 300.0
			starfish(h, a, t)
			return true
		"ax_angler":
			a.top = Vector2(-44, 62)
			a.top_w = 200.0
			angler(h, a, t)
			return true
		"ax_shell_pack":
			a.back = Vector2(-92, 50)
			a.back_w = 200.0
			shell_pack(h, a, t, true)
			return true
		"ax_black_pearl", "ax_coral_beads":
			a.neck = Vector2(0, -50)
			a.neck_w = 190.0
			item(h, id, "neck", a, t)
			return true
	return false


# ==================== Голова ====================

## Морская звезда-заколка: улыбчивая оранжевая звёздочка сбоку на голове, с жемчужинкой
static func starfish(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a) * Transform2D(0.35 + sin(t * 1.2) * 0.05, Vector2(36, 16))
	var key := ["ax_starfish"]
	var pts := PackedVector2Array()
	if not h._cache.has(key):
		pts = h._chaikin(Sets.star_pts(Vector2.ZERO, 24.0, 11.0, 5, 0.0), 2)
	h._shape(key, pts, Vector2(-2, -2), Color("#FF8A5C"), 1.3, 0.55)
	for k in 5:
		var d := Vector2(0, -1).rotated(k * TAU / 5.0)
		for m in 2:
			h._dot(d * (9.0 + m * 6.0), 2.0 - m * 0.4, Color("#FFD9B0"))
	# мордашка
	h._dot(Vector2(-4, -2), 1.8, Color("#4A1A2A"))
	h._dot(Vector2(4, -2), 1.8, Color("#4A1A2A"))
	h._arc(Vector2(0, 1), 3.0, 2.2, 0.15 * PI, 0.85 * PI, Color("#4A1A2A"), 1.3, 6)
	h._glow(Vector2(-7, 2), 3.0, 2.0, Color(1.0, 0.4, 0.5, 0.6))
	h._glow(Vector2(7, 2), 3.0, 2.0, Color(1.0, 0.4, 0.5, 0.6))
	h._ball(Vector2(14, 12), 4.5, 4.5, PEARL, 0.0, 1.0, 1.0, 1.0)
	h._T = Transform2D.IDENTITY
	h._sparkle(h._hv(a, Vector2(20, -6)), 3.0 + 2.0 * sin(t * 3.0), Color(1, 1, 1, 0.85))


## Жемчуг на жабрах: жемчужина в золотой шапочке на кончике каждой жабры
static func gill_pearls(h, t: float, k := 1.0) -> void:
	h._T = Transform2D.IDENTITY
	for i in h._gills.size():
		var pts: PackedVector2Array = h._gills[i]
		var n := pts.size()
		var d := (pts[n - 1] - pts[n - 2]).normalized()
		var p := pts[n - 1] + d * 10.0 * k
		h._ball(p, 7.5 * k, 7.5 * k, PEARL if i % 2 == 0 else Color("#FFE0F0"), 0.0, 1.0, 1.0, 1.0)
		h._ball(p - d * 5.0 * k, 3.6 * k, 2.4 * k, GOLD, d.angle() + PI / 2.0, 1.0, 0.9, 0.8)
		var tw := 0.5 + 0.5 * sin(t * 3.0 + i * 1.3)
		if tw > 0.7:
			h._sparkle(p + Vector2(-2, -3) * k, 4.0 * k * (tw - 0.5), Color.WHITE)


## Фонарик удильщика: стебелёк растёт со лба, на конце покачивается светящийся шарик
static func angler(h, a: Dictionary, t: float) -> void:
	var sw := sin(t * 1.5) * 0.12
	var pulse := 0.5 + 0.5 * sin(t * 2.6)
	h._T = h._head_T(a)
	var stalk := PackedVector2Array()
	for k in 9:
		var s := k / 8.0
		var p := Vector2(s * 40.0, 8.0 - sin(s * PI * 0.8) * 64.0 - s * 10.0)
		stalk.append(p.rotated(sw * s))
	h._line(stalk, Color("#E86A9E"), 6.0)
	h._line(stalk, Color("#FF9CC4"), 3.0)
	# плавничок-оборка на стебле
	for k in range(2, 6):
		var p: Vector2 = stalk[k]
		h._ball(p + Vector2(-4, -3), 5, 3, Color("#FFB0D0"), -0.6, 1.0, 0.4, 0.0)
	var lure: Vector2 = stalk[8] + Vector2(4, 8).rotated(sw)
	h._glow(lure, 30 + 6 * pulse, 30 + 6 * pulse, Color(0.4, 1.0, 0.9, snappedf(0.25 + 0.2 * pulse, 0.04)))
	h._ball(lure, 10, 10, Color("#9FFFE6").lerp(Color("#FFF6A0"), pulse * 0.5), 0.0, 1.0, 1.0, 1.0)
	h._dot(lure + Vector2(-3, -3), 3.0, Color(1, 1, 1, 0.9))
	h._T = Transform2D.IDENTITY
	for k in 3:
		var q := fposmod(t * 0.5 + k * 0.33, 1.0)
		var sp: Vector2 = h._hv(a, lure + Vector2(sin(q * 6.0 + k) * 8.0, -12.0 - q * 30.0))
		h._sparkle(sp, 3.0 * sin(q * PI) + 0.3, Color(0.7, 1.0, 0.95, sin(q * PI)))


## СИЯНИЕ ГЛУБИН — жемчужная корона: ободок из жемчуга, в центре светится большая жемчужина
static func pearl_crown(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a)
	var ring := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0
		ring.append(Vector2(cos(ang) * 52, 10 + sin(ang) * 13))
	h._line(ring, GOLD_D, 7.0)
	h._line(ring, GOLD, 3.5)
	# зубцы: жемчужины на золотых стебельках, к центру выше
	for k in 7:
		var s := k / 6.0
		var x := lerpf(-42, 42, s)
		var base := Vector2(x, 10 - sin(PI * (x + 52.0) / 104.0) * 13.0)
		var hgt := 16.0 + 22.0 * sin(s * PI)
		var top := base + Vector2(x * 0.1, -hgt)
		h._line(PackedVector2Array([base, top]), GOLD, 3.0)
		var pr := 4.5 + 2.5 * sin(s * PI)
		if k != 3:
			h._ball(top, pr, pr, PEARL if k % 2 == 0 else Color("#E8F4FF"), 0.0, 1.0, 1.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(t * 2.0)
	var big := Vector2(0, -36)
	h._glow(big, 26 + 4 * pulse, 26 + 4 * pulse, Color(0.6, 1.0, 1.0, snappedf(0.3 + 0.2 * pulse, 0.04)))
	h._ball(big, 11, 11, Color("#E8FFFF"), 0.0, 1.0, 1.0, 1.2)
	var hh := fposmod(t * 0.1, 1.0)
	h._arc(big, 8, 8, 1.1 * PI, 1.6 * PI, Sets.hsv(hh, 0.5, 1.0, 0.8), 2.2, 8)
	# ракушки по бокам
	for sx in [-1.0, 1.0]:
		var c := Vector2(sx * 30, -8)
		var fan := PackedVector2Array([c + Vector2(0, 7)])
		for k in 9:
			var ang := lerpf(PI * 1.1, PI * 1.9, k / 8.0)
			fan.append(c + Vector2(cos(ang), sin(ang) + 0.2) * 10.0)
		h._fill(fan, Color("#FFC2DA"))
		for k in 4:
			var ang := lerpf(PI * 1.2, PI * 1.8, k / 3.0)
			h._line(PackedVector2Array([c + Vector2(0, 6), c + Vector2(cos(ang), sin(ang) + 0.2) * 9.0]), Color("#E07AA0", 0.7), 1.2)
	h._T = Transform2D.IDENTITY
	h._sparkle(h._hv(a, big + Vector2(-6, -8)), 5.0 + 3.0 * pulse, Color.WHITE)


# ==================== Глаза ====================

## Очки-иллюминаторы: латунные кольца с болтиками, зеленоватое стекло, внутри поднимаются пузырьки
static func porthole(h, a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad * 1.2
	for i in 2:
		var e: Vector2 = [a.eye_l, a.eye_r][i]
		h._T = Transform2D(a.tilt, e)
		h._vgrad(h._ell(Vector2.ZERO, r, r, 0.0, 26), Color(0.6, 1.0, 0.9, 0.2), Color(0.2, 0.7, 0.8, 0.32), false)
		for k in 3:
			var q := fposmod(t * 0.4 + k * 0.33 + i * 0.2, 1.0)
			var bp := Vector2(sin(q * 5.0 + k) * r * 0.35, r * 0.6 - q * r * 1.2)
			h._arc(bp, r * 0.09, r * 0.09, 0, TAU, Color(0.9, 1.0, 1.0, 0.8 * sin(q * PI)), 1.2, 8)
		h._arc(Vector2.ZERO, r, r, 0, TAU, Color("#6A3E12"), r * 0.46, 30)
		h._arc(Vector2.ZERO, r, r, 0, TAU, Color("#D9A24A"), r * 0.32, 30)
		h._arc(Vector2.ZERO, r * 1.05, r * 1.05, 1.05 * PI, 1.5 * PI, Color("#FFE6A0"), r * 0.1, 10)
		for k in 6:
			var ang := k * TAU / 6.0
			h._ball(Vector2(cos(ang), sin(ang)) * r * 1.0, r * 0.1, r * 0.1, Color("#B8C0DA"), 0.0, 1.0, 0.9, 0.8)
		h._line(PackedVector2Array([Vector2(-r * 0.5, 0), Vector2(-r * 0.1, -r * 0.45)]), Color(1, 1, 1, 0.6), r * 0.12)
	h._T = Transform2D.IDENTITY
	var l: Vector2 = a.eye_l + Vector2(r, 0).rotated(a.tilt)
	var rr: Vector2 = a.eye_r - Vector2(r, 0).rotated(a.tilt)
	h._line(PackedVector2Array([l, (l + rr) / 2.0 + Vector2(0, -r * 0.2), rr]), Color("#6A3E12"), r * 0.3)
	h._line(PackedVector2Array([l, (l + rr) / 2.0 + Vector2(0, -r * 0.2), rr]), Color("#D9A24A"), r * 0.17)


# ==================== Шея ====================

## Коралловые бусы: бусины-кораллы, белые ракушечки и веточка коралла в центре
static func coral_beads(h, a: Dictionary, t: float) -> void:
	var w: float = a.neck_w * 0.84
	var n: Vector2 = a.neck
	var cnt := 15
	for i in cnt:
		var ang := lerpf(0.0, PI, i / float(cnt - 1))
		var p := n + Vector2(cos(ang) * w * 0.5, -6 + sin(ang) * w * 0.2)
		if i == cnt / 2:
			continue
		if i % 3 == 1:
			h._ball(p, 4.2, 3.2, PEARL, ang, 1.0, 0.9, 0.8)
		else:
			h._ball(p, 5.0, 5.0, CORAL if i % 2 == 0 else Color("#FF5E8A"), 0.0, 1.0, 0.8, 1.0)
	# веточка коралла
	var c := n + Vector2(0, -6 + w * 0.2 + 4)
	h._T = Transform2D(0.0, c)
	var col := Color("#FF5E6A")
	h._line(PackedVector2Array([Vector2(0, -4), Vector2(0, 12), Vector2(-2, 20)]), col, 5.0)
	h._line(PackedVector2Array([Vector2(0, 6), Vector2(-8, 0), Vector2(-11, -4)]), col, 4.0)
	h._line(PackedVector2Array([Vector2(0, 10), Vector2(9, 5), Vector2(12, 0)]), col, 4.0)
	for e in [Vector2(-11, -4), Vector2(12, 0), Vector2(-2, 20)]:
		h._ball(e, 3.4, 3.4, Color("#FF9AA0"), 0.0, 1.0, 0.8, 0.8)
	h._T = Transform2D.IDENTITY
	h._sparkle(c + Vector2(10, -6), 2.5 + 1.5 * sin(t * 3.5), Color.WHITE)


## Чёрная жемчужина: серебряная цепочка и большая тёмная жемчужина с бирюзовым отливом
static func black_pearl(h, a: Dictionary, t: float) -> void:
	var w: float = a.neck_w * 0.8
	var n: Vector2 = a.neck
	var chain := PackedVector2Array()
	for i in 17:
		var ang := lerpf(0.0, PI, i / 16.0)
		chain.append(n + Vector2(cos(ang) * w * 0.5, -6 + sin(ang) * w * 0.18))
	h.ci.draw_polyline(chain, Color("#8A93B8"), 3.0, true)
	h.ci.draw_polyline(chain, Color("#E4E9FA"), 1.4, true)
	for i in range(1, 16, 2):
		h._ball(chain[i], 2.6, 2.6, Color("#E4E9FA"), 0.0, 1.0, 1.0, 0.6)
	var pc: Vector2 = chain[8] + Vector2(0, 12)
	var pulse := 0.5 + 0.5 * sin(t * 1.7)
	h._glow(pc, 22, 22, Color(0.25, 0.9, 0.9, snappedf(0.18 + 0.14 * pulse, 0.04)))
	h._ball(pc + Vector2(0, -9), 4, 3, Color("#E4E9FA"), 0.0, 1.0, 0.9, 1.0)
	h._ball(pc, 12, 12, Color("#2E2A4A"), 0.0, 1.0, 1.0, 1.4)
	var hh := fposmod(t * 0.08, 1.0)
	h._arc(pc, 7, 7, 1.0 * PI, 1.55 * PI, Sets.hsv(0.45 + 0.2 * sin(hh * TAU), 0.6, 1.0, 0.8), 2.6, 8)
	h._arc(pc, 7, 7, 0.1 * PI, 0.45 * PI, Sets.hsv(0.8, 0.5, 1.0, 0.5), 2.0, 6)
	h._dot(pc + Vector2(-3.5, -4), 2.2, Color(1, 1, 1, 0.9))


# ==================== Спина ====================

## Ракушка-рюкзачок: большой розово-перламутровый гребешок за спиной, лямки из жемчуга
static func shell_pack(h, a: Dictionary, t: float, behind: bool) -> void:
	var w: float = a.back_w
	var b: Vector2 = a.back
	if behind:
		var c := b + Vector2(w * 0.46, -w * 0.2)
		var R := w * 0.36
		h._T = Transform2D(0.35, c)
		var fan := PackedVector2Array([Vector2(-R * 0.25, R * 0.55), Vector2(R * 0.25, R * 0.55)])
		for k in 15:
			var ang := lerpf(PI * 0.08, -PI * 1.08, k / 14.0)
			var rr := R * (1.0 + 0.06 * sin(k * PI))
			fan.append(Vector2(cos(ang), sin(ang) + 0.05) * rr)
		h._shape(["ax_shell", R], fan, Vector2(0, -R * 0.2), Color("#FFC2DA"), 1.4, 0.7)
		for k in 7:
			var ang := lerpf(-PI * 0.05, -PI * 0.95, k / 6.0)
			h._line(PackedVector2Array([Vector2(0, R * 0.45), Vector2(cos(ang), sin(ang)) * R * 0.92]), Color("#E07AA0", 0.55), 2.2)
		h._ball(Vector2(0, R * 0.5), R * 0.3, R * 0.14, Color("#FFB0CC"), 0.0, 1.0, 0.6, 1.0)
		var hh := fposmod(t * 0.1, 1.0)
		h._arc(Vector2(0, -R * 0.1), R * 0.7, R * 0.6, 1.2 * PI, 1.55 * PI, Sets.hsv(hh, 0.4, 1.0, 0.55), 3.0, 10)
		h._T = Transform2D.IDENTITY
		h._sparkle(c + Vector2(-R * 0.3, -R * 0.7), R * 0.12 * (0.6 + 0.4 * sin(t * 3.0)), Color.WHITE)
		return
	if a.kind == "icon":
		return
	var k := w / 128.0
	for sx in [-1.0, 1.0]:
		var top: Vector2 = b + Vector2(sx * 40, -22) * k
		var bot: Vector2 = b + Vector2(sx * 50, 26) * k
		for m in 6:
			var p := top.lerp(bot, m / 5.0) + Vector2(sx * sin(m / 5.0 * PI) * 4.0, 0)
			h._ball(p, 3.6, 3.6, PEARL, 0.0, 1.0, 1.0, 0.8)


# ==================== Спутник ====================

## Кальмарчик: розово-сиреневый, большие глаза, щупальца колышутся, светящиеся пятнышки
static func squid(h, p: Vector2, t: float, react: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	if react >= 0.0 and react < 1.0:
		p.y -= sin(react * PI) * 20.0  # при касании — рывок вверх
	h._glow(p, 34, 34, Color(0.7, 0.5, 1.0, 0.2))
	h._T = Transform2D(sin(t * 1.3) * 0.12, Vector2(1.0 - 0.06 * pulse, 1.0 + 0.06 * pulse), 0.0, p)
	# щупальца
	for k in 6:
		var x := -10.0 + k * 4.0
		var pts := PackedVector2Array()
		for m in 6:
			var s := m / 5.0
			pts.append(Vector2(x * (1.0 + s * 0.6) + sin(t * 4.0 + k + s * 3.0) * 3.0 * s, 8 + s * 20.0))
		h._line(pts, Color("#C77BE0"), 3.6 - absf(k - 2.5) * 0.3)
	# мантия-капелька
	var body := PackedVector2Array([Vector2(0, -30)])
	for k in 13:
		var ang := lerpf(-PI * 0.15, PI * 1.15, k / 12.0)
		body.append(Vector2(cos(ang) * 15.0, 4.0 + sin(ang) * 8.0))
	h._shape(["ax_squid"], h._chaikin(body, 2), Vector2(0, -4), Color("#E79BE8"), 1.3, 0.6)
	h._fill(PackedVector2Array([Vector2(-6, -24), Vector2(-16, -30), Vector2(-9, -18)]), Color("#D27FD8"))
	h._fill(PackedVector2Array([Vector2(6, -24), Vector2(16, -30), Vector2(9, -18)]), Color("#D27FD8"))
	for sp in [Vector2(-5, -14), Vector2(4, -19), Vector2(0, -8)]:
		h._dot(sp, 1.8, Color(0.6, 1.0, 1.0, 0.5 + 0.5 * pulse))
	# глазки
	for sx in [-1.0, 1.0]:
		h._ball(Vector2(sx * 6, 2), 4.5, 5.0, Color("#1A0E30"), 0.0, 1.0, 0.6, 0.0)
		h._dot(Vector2(sx * 6 - 1.5, 0), 1.6, Color.WHITE)
	h._glow(Vector2(-11, 7), 3.5, 2.2, Color(1.0, 0.45, 0.6, 0.6))
	h._glow(Vector2(11, 7), 3.5, 2.2, Color(1.0, 0.45, 0.6, 0.6))
	h._T = Transform2D.IDENTITY
	for k in 2:
		var q := fposmod(t * 0.5 + k * 0.5, 1.0)
		var bp := p + Vector2(10 + sin(q * 6.0) * 4.0, -20 - q * 36.0)
		h._arc(bp, 2.5 + q * 2.0, 2.5 + q * 2.0, 0, TAU, Color(0.8, 0.97, 1.0, 0.7 * (1.0 - q)), 1.2, 10)


# ==================== Сияния ====================

## ТАНЕЦ ПЛАНКТОНА (легендарное): две спирали светящихся точек медленно кружат вокруг
static func plankton(h, a: Dictionary, t: float, front: bool) -> void:
	var c: Vector2 = a.center
	var R: float = a.size
	if not front:
		h._glow(c, R * 1.4, R * 1.4, Color(0.1, 0.8, 0.8, 0.16))
		h._glow(c + Vector2(0, R * 0.6), R * 1.1, R * 0.4, Color(0.3, 0.6, 1.0, 0.12))
	var cols := [Color("#5CFFE0"), Color("#7FB8FF"), Color("#C6FF7A")]
	for arm in 2:
		for i in 14:
			var s := i / 13.0
			var ang := t * 0.7 + arm * PI + s * 3.2
			var z := sin(ang)
			if (z > 0.0) != front:
				continue
			var rr := R * (0.7 + 0.7 * s)
			var p := c + Vector2(cos(ang) * rr, R * 0.5 - s * R * 1.3 + z * R * 0.18)
			var tw := snappedf(0.5 + 0.5 * sin(t * 4.0 + i * 1.7 + arm), 0.25)
			var col: Color = cols[(i + arm) % 3]
			h._glow(p, 12.0 + 7.0 * tw, 12.0 + 7.0 * tw, Sets.q(Color(col, 0.4 * tw + 0.15)))
			h._dot(p, 3.0 + 1.6 * tw, Color(col.lerp(Color.WHITE, 0.4), 0.7 + 0.3 * tw))
			if i % 5 == 2:
				h._sparkle(p, 4.5 * tw, Color(1, 1, 1, tw))


## СИЯНИЕ ГЛУБИН — медузы-фонарики плавают вокруг (сзади — тёмно-бирюзовое свечение глубины)
static func jellies(h, a: Dictionary, t: float, front: bool) -> void:
	var c: Vector2 = a.center
	var R: float = a.size
	if not front and a.kind != "icon":
		h._glow(c, R * 1.5, R * 1.45, Color(0.1, 0.55, 0.9, 0.2))
		h._glow(c + Vector2(0, -R * 0.4), R * 1.0, R * 0.8, Color(0.4, 0.9, 1.0, 0.12))
	var cols := [Color("#7FE3FF"), Color("#FF9FE0"), Color("#B9A4FF"), Color("#9FFFD6")]
	for i in 4:
		var ang := t * 0.35 + i * TAU / 4.0
		var z := sin(ang)
		if (z > 0.0) != front:
			continue
		var bob := sin(t * 1.6 + i * 1.3)
		var p := c + Vector2(cos(ang) * R * 1.3, -R * 0.35 + i % 2 * R * 0.5 + bob * 10.0 + z * R * 0.12)
		_jelly(h, p, (0.85 + 0.25 * z) * (1.4 if a.kind != "icon" else 1.0), cols[i], t + i * 0.7)


static func _jelly(h, p: Vector2, s: float, col: Color, t: float) -> void:
	var sq := 0.5 + 0.5 * sin(t * 2.4)
	h._glow(p, 32 * s, 32 * s, Sets.q(Color(col, 0.5)))
	h._T = Transform2D(0.0, Vector2(s * (1.0 + 0.08 * sq), s * (1.0 - 0.08 * sq)), 0.0, p)
	for k in 4:
		var x := -9.0 + k * 6.0
		var pts := PackedVector2Array()
		for m in 5:
			var u := m / 4.0
			pts.append(Vector2(x + sin(t * 3.0 + k + u * 4.0) * 3.0 * u, 2 + u * 22.0))
		h._line(pts, Color(col.lerp(Color.WHITE, 0.3), 0.7), 2.0)
	var dome := PackedVector2Array()
	for k in 13:
		var ang := PI + PI * k / 12.0
		dome.append(Vector2(cos(ang) * 14.0, 3 + sin(ang) * 14.0))
	for k in 5:
		dome.append(Vector2(lerpf(14.0, -14.0, k / 4.0), 3 + (2.5 if k % 2 == 1 else 0.0)))
	h._vgrad(dome, Color(col.lerp(Color.WHITE, 0.55), 0.95), Color(col, 0.7))
	h._arc(Vector2(0, -2), 9, 6, 1.15 * PI, 1.5 * PI, Color(1, 1, 1, 0.8), 2.0, 6)
	h._dot(Vector2(-4, -3), 1.5, Color("#1A0E30"))
	h._dot(Vector2(4, -3), 1.5, Color("#1A0E30"))
	h._T = Transform2D.IDENTITY


## СИЯНИЕ ГЛУБИН — веснушки на щёчках светятся, как у глубоководных рыбок
static func _glow_freckles(h, t: float) -> void:
	for sx in [-1.0, 1.0]:
		for i in 3:
			var f: Vector2 = [Vector2(56, -8), Vector2(64, -11), Vector2(72, -7)][i]
			var tw := snappedf(0.5 + 0.5 * sin(t * 2.5 + i * 1.4 + sx), 0.25)
			h._glow(Vector2(sx * f.x, f.y), 6.0 + 4.0 * tw, 6.0 + 4.0 * tw, Color(0.4, 1.0, 0.95, snappedf(0.3 + 0.4 * tw, 0.05)))
			h._dot(Vector2(sx * f.x, f.y), 2.0, Color(0.8, 1.0, 1.0, 0.9))


## СИЯНИЕ ГЛУБИН — жабры светятся: по каждой бежит волна переливающегося света
static func glow_gills(h, t: float) -> void:
	h._T = Transform2D.IDENTITY
	for i in h._gills.size():
		var pts: PackedVector2Array = h._gills[i]
		for k in range(1, pts.size()):
			var wave := snappedf(0.5 + 0.5 * sin(t * 3.0 - k * 0.9 + i * 0.7), 0.25)
			var col := Sets.hsv(0.48 + 0.12 * sin(t * 0.5 + i + k * 0.3), 0.55, 1.0)
			h._glow(pts[k], 10.0 + 8.0 * wave, 10.0 + 8.0 * wave, Color(col, snappedf(0.2 + 0.4 * wave, 0.05)))
			if k == pts.size() - 1:
				h._dot(pts[k], 3.0 + 1.5 * wave, Color(col.lerp(Color.WHITE, 0.5), 0.9))
