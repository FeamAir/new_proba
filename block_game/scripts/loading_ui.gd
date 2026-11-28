extends RefCounted
## Cascado 0.19: экран загрузки 3D-дома — «Строим домик», «Настраиваем графику».
## Рисуется, пока дом строится и прогреваются шейдеры по частям (scripts/home3d/home_loader.gd).
## Анимация идёт по НАСТОЯЩЕМУ времени (не по кадрам): даже если кадр на телефоне долгий
## (собирается шейдер), картинка в следующем кадре на своём месте — экран живой, а не застывший.
## Использование: LoadingUI.draw(game, прямоугольник, прозрачность 0..1, доля готового 0..1, ключ текста)

const I18n := preload("res://scripts/i18n.gd")


static func draw(g, r: Rect2, alpha: float, progress: float, text_key := "loading_home") -> void:
	if alpha <= 0.0:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var full: bool = r.size.y >= g.H - 1.0
	var bg := Color(g.BG_TOP, alpha)
	if full:
		g.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([bg, bg, Color(g.BG_BOTTOM, alpha), Color(g.BG_BOTTOM, alpha)]))
	else:
		g._rbox(r, Color(0.06, 0.035, 0.13, 0.96 * alpha), 30)
	if alpha < 0.99:
		return  # дом готов: гаснет только фон, дом проступает из-под него
	if full:
		g._draw_title(Vector2(g.W / 2.0, 200), 80, 6.0)  # как на экране «Дом» — заголовок на том же месте
	var s := clampf(minf(r.size.x / 720.0, r.size.y / 1100.0), 0.45, 1.0)
	var c := r.get_center() + Vector2(0, -60 * s)
	# мягкое свечение
	for k in 4:
		g.draw_circle(c, (210 - k * 40) * s, Color(0.45, 0.25, 0.8, (0.05 + k * 0.02) * alpha), true, -1.0, true)
	# герой в кружке подпрыгивает
	var kind: String = g.meta.hero if g.meta.hero != "" else "owl"
	var hop := absf(sin(t * 3.2)) * 26.0 * s
	g.draw_colored_polygon(_ellipse(c + Vector2(0, 112 * s), (70 - hop * 0.6) * s, 12 * s), Color(0, 0, 0, 0.25 * alpha))
	g.screens.hero.draw_avatar(g, kind, c - Vector2(0, hop), 92 * s, g.meta.outfit(), t, Color(g.ACCENT), 99.0)
	# кубики-самоцветы по очереди «падают» на место — как в игре
	var n := 5
	var bs := 34.0 * s
	var y0 := c.y + 170 * s
	var x0 := c.x - (n * bs + (n - 1) * 10 * s) / 2.0
	for i in n:
		var u := fposmod(t * 1.1 - i * 0.16, 1.6)
		var drop := 0.0 if u > 0.45 else (1.0 - u / 0.45)
		drop = drop * drop * 60.0 * s
		var a := alpha * (0.35 + 0.65 * clampf(u / 0.45, 0.0, 1.0))
		var col: Color = g.GEMS[i % g.GEMS.size()]
		var br := Rect2(x0 + i * (bs + 10 * s), y0 - drop, bs, bs)
		g._rbox(br, Color(col, a), int(8 * s))
		g._rbox(Rect2(br.position + Vector2(4, 3) * s, Vector2(bs - 8 * s, bs * 0.35)), Color(1, 1, 1, 0.22 * a), int(6 * s))
	# надпись и бегущие точки
	var txt := I18n.t(text_key)
	var fs := int(46 * s)
	var ty := y0 + 100 * s
	var tw: float = g.font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tx := c.x - (tw + 40 * s) / 2.0
	g.draw_string(g.font, Vector2(tx + 2, ty + 3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.35 * alpha))
	g.draw_string(g.font, Vector2(tx, ty), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(g.TEXT, alpha))
	for i in 3:
		var da := clampf(fposmod(t * 2.0 - i * 0.33, 1.4) / 0.4, 0.0, 1.0)
		g.draw_circle(Vector2(tx + tw + (10 + i * 13) * s, ty - 6 * s), 4.5 * s, Color(g.ACCENT, alpha * (0.25 + 0.75 * da)), true, -1.0, true)
	if text_key == "loading_home":
		var sub := I18n.t("house_" + kind)
		g.draw_string(g.font, Vector2(r.position.x, ty + 48 * s), sub, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(28 * s), Color(g.DIM, alpha))
	# полоска готовности
	var pw := minf(420.0 * s, r.size.x - 80)
	var pr := Rect2(c.x - pw / 2.0, ty + 84 * s, pw, 16 * s)
	g._rbox(pr, Color(1, 1, 1, 0.1 * alpha), int(8 * s))
	var fw := maxf(pr.size.y, pw * clampf(progress, 0.0, 1.0))
	g._rbox(Rect2(pr.position, Vector2(fw, pr.size.y)), Color(g.ACCENT, 0.9 * alpha), int(8 * s))
	# блик бежит по полоске (видно, что не зависло, даже если доля долго не меняется)
	var bx := pr.position.x + fposmod(t * 0.7, 1.0) * fw
	g.draw_circle(Vector2(bx, pr.get_center().y), pr.size.y * 0.45, Color(1, 1, 1, 0.5 * alpha), true, -1.0, true)


static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p
