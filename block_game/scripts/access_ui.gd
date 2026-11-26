extends RefCounted
## 0.17: окно «Удобство» в паузе — переключатели (0.18: и «Вибрация») (scripts/access.gd) и кнопка «Назад».
## Рисует на узле игры (g — scripts/game.gd), касания — tap().

const I18n := preload("res://scripts/i18n.gd")

const ROW_H := 132.0
const ROW_GAP := 18.0

var g
var open := false
var rects := {}     # "opt_<ключ>" и "back"


func _init(game) -> void:
	g = game


func show() -> void:
	open = true
	_layout()


func close() -> void:
	open = false


func _layout() -> void:
	rects.clear()
	var keys: Array = g.access.KEYS
	var total: float = keys.size() * ROW_H + (keys.size() - 1) * ROW_GAP
	var y0: float = g.H * 0.5 - total / 2.0 - 30.0
	for i in keys.size():
		rects["opt_" + keys[i]] = Rect2(40, y0 + i * (ROW_H + ROW_GAP), g.W - 80, ROW_H)
	rects["back"] = Rect2((g.W - 460) / 2.0, y0 + total + 40.0, 460, 90)


## true — касание обработано (окно открыто).
func tap(pos: Vector2) -> bool:
	if not open:
		return false
	_layout()
	for k in g.access.KEYS:
		if rects["opt_" + k].has_point(pos):
			g.play("click")
			g.set_access(k, not g.access.get_opt(k))
			return true
	if rects["back"].has_point(pos):
		g.play("click")
		close()
	return true


func draw() -> void:
	if not open:
		return
	_layout()
	var a = g.access
	g.draw_rect(Rect2(0, 0, g.W, g.H), Color(0.04, 0.02, 0.09, 0.99))
	var first: Rect2 = rects["opt_" + a.KEYS[0]]
	g._center_text(I18n.t("access_title"), first.position.y - 44, a.fs(54), g.TEXT)
	for k in a.KEYS:
		var r: Rect2 = rects["opt_" + k]
		var on: bool = a.get_opt(k)
		g._rbox(r, g.BTN_DOWN if on else g.BTN, 24)
		# значок слева
		_icon(k, Vector2(r.position.x + 56, r.get_center().y), on)
		var tx := r.position.x + 104
		var tw := r.size.x - 104 - 130
		var title := I18n.t("access_" + k)
		var ts: int = g.assist_ui.fit(title, a.fs(32), tw)
		g.draw_string(g.font, Vector2(tx, r.position.y + 54), title, HORIZONTAL_ALIGNMENT_LEFT, tw, ts, g.TEXT)
		var desc := I18n.t("access_" + k + "_desc")
		var ds: int = g.assist_ui.fit(desc, a.fs(21), tw)
		g.draw_string(g.font, Vector2(tx, r.position.y + 96), desc, HORIZONTAL_ALIGNMENT_LEFT, tw, ds, g.DIM)
		_switch(Rect2(r.end.x - 116, r.get_center().y - 24, 92, 48), on)
	var b: Rect2 = rects["back"]
	g._rbox(b, g.ACCENT, 24)
	g.draw_string(g.font, Vector2(b.position.x, b.get_center().y + 13), I18n.t("access_back"), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, a.fs(34), Color("#2A1A0A"))


func _switch(r: Rect2, on: bool) -> void:
	g._rbox(r, Color("#3DDC97") if on else Color("#4A3B6B"), 24)
	var k := r.size.y / 2.0
	var c := Vector2(r.end.x - k if on else r.position.x + k, r.get_center().y)
	g.draw_circle(c, k - 6, Color.WHITE, true, -1.0, true)


func _icon(k: String, c: Vector2, on: bool) -> void:
	var col: Color = g.TEXT if on else g.DIM
	match k:
		"symbols":
			# блок с треугольником
			g._draw_block(c - Vector2(28, 28), 56, 1)
			g.Access.draw_sign(g, c, 56, 1)
		"lefty":
			# мини-ряд кнопок: поворот слева, стрелка справа
			for i in 2:
				var bc := c + Vector2(-17 + i * 34, 0)
				g._rbox(Rect2(bc - Vector2(15, 17), Vector2(30, 34)), Color(col, 0.22), 8)
			var rc := c + Vector2(-17, 0)
			g.draw_arc(rc, 8, deg_to_rad(-60), deg_to_rad(220), 14, col, 3.0, true)
			var ac := c + Vector2(17, 0)
			g.draw_colored_polygon(PackedVector2Array([ac + Vector2(8, 0), ac + Vector2(-5, -8), ac + Vector2(-5, 8)]), col)
		"slow":
			# часы-«черепашка»: циферблат и стрелки
			g.draw_arc(c, 22, 0, TAU, 28, col, 4.0, true)
			g.draw_line(c, c + Vector2(0, -14), col, 4.0, true)
			g.draw_line(c, c + Vector2(10, 4), col, 4.0, true)
		"vibrate":
			# телефон с «дрожащими» дужками
			g._rbox(Rect2(c - Vector2(11, 20), Vector2(22, 40)), col, 5)
			g._rbox(Rect2(c - Vector2(7, 15), Vector2(14, 26)), Color(g.BTN, 0.9), 3)
			for sx in [-1.0, 1.0]:
				g.draw_arc(c + Vector2(sx * 6, 0), 16, -0.6 if sx > 0 else PI - 0.6, 0.6 if sx > 0 else PI + 0.6, 8, col, 3.0, true)
				g.draw_arc(c + Vector2(sx * 6, 0), 24, -0.5 if sx > 0 else PI - 0.5, 0.5 if sx > 0 else PI + 0.5, 8, Color(col, 0.6), 3.0, true)
		"big":
			g.draw_string(g.font, c + Vector2(-30, 14), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)
			g.draw_string(g.font, c + Vector2(-8, 16), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, col)
