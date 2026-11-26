extends RefCounted
## 0.18: строка «до 3 звёзд» на панели уровня.
## Звёзды за победу (game.gd _win): 3 — фигур не больше par, 2 — не больше int(par * 1.4), иначе 1.
## Строка показывает, сколько фигур ещё можно поставить (вместе с той, что падает сейчас),
## чтобы получить 3 звезды; когда этот предел пройден — сколько до 2 звёзд; когда пройден
## и он — строка прячется.

const I18n := preload("res://scripts/i18n.gd")


## Предел фигур для звёзд n (3 или 2).
static func limit(par: int, n: int) -> int:
	return par if n >= 3 else int(par * 1.4)


## [звёзды, сколько фигур ещё можно] или [0, 0] — строка не нужна.
static func goal(par: int, used: int) -> Array:
	for n in [3, 2]:
		var left := limit(par, n) - used
		if left > 0:
			return [n, left]
	return [0, 0]


## Нарисовать строку на панели: звёздочки и «ещё N». Возвращает высоту строки (0 — не рисовалась).
static func draw(g, x: float, y: float, w: float, size: int) -> float:
	var gl := goal(g.par, g.pieces_used)
	if gl[0] == 0:
		return 0.0
	var r := 9.0 * size / 22.0
	for i in gl[0]:
		g._draw_star(Vector2(x + r + 2 + i * (r * 2 + 2), y - size * 0.36), r, true)
	var tx: float = x + gl[0] * (r * 2 + 2) + 8
	var txt := I18n.t("goal_left") % gl[1]
	var fs: int = g.assist_ui.fit(txt, size, w - (tx - x))
	var col: Color = g.TEXT if gl[0] == 3 else g.DIM
	if gl[1] <= 2:
		col = g.ACCENT
	g.draw_string(g.font, Vector2(tx, y), txt, HORIZONTAL_ALIGNMENT_LEFT, w - (tx - x), fs, col)
	return size + 12.0
