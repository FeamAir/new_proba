extends RefCounted
## Cascado 0.12b: окна поверх любого экрана (свой слой CanvasLayer — видно и над 3D-домом):
##  • «Сменить друга?» — при выборе другого героя в гардеробе (или на экране выбора): вещи,
##    скованное и украшения дома прежнего героя снимаются, потраченное возвращается осколками
##    (сумма — meta.gd, refund_value). «Отмена» ничего не меняет.
##  • «Гардероб обновлён!» — один раз после загрузки старого сохранения (0.6–0.12): общие вещи
##    убраны, их цена и плата за ковку вернулись осколками (meta.gd, notice_refund).

const Meta := preload("res://scripts/meta.gd")
const I18n := preload("res://scripts/i18n.gd")

const DARK_TEXT := Color("#2A1A0A")
const PANEL := Color("#2E1D58")

var g
var layer: CanvasLayer
var node: Node2D
var mode := ""        # "" — окна нет; "switch" — смена друга; "migrated" — гардероб обновлён
var to := ""          # на кого меняем
var refund := 0       # сколько осколков вернётся / вернулось
var t := 0.0
var rects := {}
var sb := StyleBoxFlat.new()


func _init(game) -> void:
	g = game
	layer = CanvasLayer.new()
	layer.layer = 20
	node = Node2D.new()
	node.draw.connect(_draw)
	layer.add_child(node)
	g.add_child(layer)
	node.visible = false


func active() -> bool:
	return mode != ""


## Спросить о смене друга на h (окно с возвратом осколков).
func ask_switch(h: String) -> void:
	mode = "switch"
	to = h
	refund = g.meta.refund_value(g.meta.hero)
	t = 0.0


## Сообщение о вернувшихся за старые вещи осколках показывается на спокойных экранах.
func _calm() -> bool:
	return g.state in [g.State.HOME, g.State.WARDROBE, g.State.MAP, g.State.FORGE]


func update(delta: float) -> void:
	if mode == "" and g.meta.notice_refund > 0 and _calm():
		mode = "migrated"
		refund = g.meta.notice_refund
		t = 0.0
	t += delta
	node.visible = mode != ""
	if node.visible:
		node.queue_redraw()


func tap(pos: Vector2) -> void:
	if t < 0.25:
		return  # защита от случайного двойного касания
	match mode:
		"switch":
			if rects.get("yes", Rect2()).has_point(pos):
				confirm()
			elif rects.get("no", Rect2()).has_point(pos) or not rects.get("panel", Rect2()).has_point(pos):
				back()
		"migrated":
			if rects.get("ok", Rect2()).has_point(pos):
				back()


## «Сменить»: прежнему герою — возврат, новый — с нуля.
func confirm() -> void:
	if mode != "switch":
		return
	mode = ""
	var n: int = g.meta.switch_hero(to)
	g.play("levelup")
	g.screens.switched(n)
	if g.state == g.State.PICK_HERO:
		g.go_home()


## «Отмена» / «Назад» на телефоне. Для сообщения об обновлении — закрыть (больше не покажется).
func back() -> void:
	if mode == "migrated":
		g.meta.notice_refund = 0
		g._save()
		g.play("crystal")
	else:
		g.play("click", 0.9)
	mode = ""


# ---------- Рисование ----------

func _box(r: Rect2, col: Color, rad: float) -> void:
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	sb.draw(node.get_canvas_item(), r)


func _text(cx: float, y: float, s: String, size: int, col: Color, width := 600.0) -> void:
	var fs := size
	while fs > 14 and g.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	node.draw_string(g.font, Vector2(cx - width / 2.0, y), s, HORIZONTAL_ALIGNMENT_CENTER, width, fs, col)


func _shard(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r * 1.25), c + Vector2(r * 0.85, -r * 0.25), c + Vector2(0, r * 1.25), c + Vector2(-r * 0.85, -r * 0.25)])
	node.draw_colored_polygon(pts, g.CRYSTAL_COL)
	node.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], c + Vector2(0, -r * 0.1)]), Color(1, 1, 1, 0.7))
	node.draw_colored_polygon(PackedVector2Array([pts[3], c + Vector2(0, -r * 0.1), pts[2]]), g.CRYSTAL_COL.darkened(0.25))


func _button(name: String, r: Rect2, label: String, primary: bool) -> void:
	rects[name] = r
	if primary:
		var pulse := 0.5 + 0.5 * sin(t * 4.0)
		_box(r.grow(3 + 3 * pulse), Color(g.ACCENT, 0.25), 32)
	_box(r, g.ACCENT if primary else g.BTN, 28)
	_box(Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, r.size.y * 0.42)), Color(1, 1, 1, 0.1), 22)
	_text(r.get_center().x, r.get_center().y + 12, label, 34, DARK_TEXT if primary else g.TEXT, r.size.x - 24)


## Строка «Вернётся N осколков» с кристаллом
func _refund_line(cy: float, key: String) -> void:
	var label := I18n.t(key) % [refund, I18n.forms("shards_forms", refund)]
	var fs := 34
	var w: float = g.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while w > 520.0 and fs > 20:
		fs -= 1
		w = g.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0: float = g.W / 2.0 - (w + 44) / 2.0
	var pill := Rect2(x0 - 22, cy - 40, w + 88, 60)
	_box(pill, Color(0.08, 0.04, 0.16, 0.9), 30)
	_shard(Vector2(x0 + 12, cy - 10), 13)
	node.draw_string(g.font, Vector2(x0 + 40, cy + 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, g.CRYSTAL_COL)


func _draw() -> void:
	rects.clear()
	if mode == "":
		return
	var H: float = g.H
	var k := clampf(t / 0.2, 0.0, 1.0)
	node.draw_rect(Rect2(0, 0, g.W, H), Color(0.02, 0.01, 0.06, 0.72 * k))
	if mode == "switch":
		_draw_switch(H, k)
	else:
		_draw_migrated(H, k)


func _draw_switch(H: float, k: float) -> void:
	var old: String = g.meta.hero
	var r := Rect2(28, H * 0.5 - 330 + (1.0 - k) * 40.0, g.W - 56, 640)
	rects["panel"] = r
	_box(r.grow(6), Color(0.02, 0.01, 0.06, 0.6), 40)
	_box(r, PANEL, 36)
	node.draw_polyline(_outline(r.grow(-2), 34), Color(g.ACCENT, 0.85), 3.0, true)
	_text(r.get_center().x, r.position.y + 70, I18n.t("switch_title"), 46, g.TEXT, r.size.x - 40)
	# прежний друг в наряде → новый друг
	var y := r.position.y + 190
	var hero = g.screens.hero
	hero.draw_avatar(node, old, Vector2(g.W / 2.0 - 150, y), 74, g.meta.outfit(), g.t_total, g.DIM)
	hero.draw_avatar(node, to, Vector2(g.W / 2.0 + 150, y), 74, {}, g.t_total + 1.3, g.ACCENT, 0.4 + fposmod(t, 3.0))
	var ax: float = g.W / 2.0
	var bob := sin(t * 4.0) * 6.0
	node.draw_colored_polygon(PackedVector2Array([Vector2(ax - 26 + bob, y - 18), Vector2(ax + 8 + bob, y - 18), Vector2(ax + 8 + bob, y - 34),
		Vector2(ax + 40 + bob, y), Vector2(ax + 8 + bob, y + 34), Vector2(ax + 8 + bob, y + 18), Vector2(ax - 26 + bob, y + 18)]), g.ACCENT)
	_text(g.W / 2.0 - 150, y + 116, Meta.hero_name(old), 28, g.DIM, 260)
	_text(g.W / 2.0 + 150, y + 116, Meta.hero_name(to), 28, g.ACCENT, 260)
	var body := I18n.t("switch_text") % I18n.t("hero_gen_" + old)
	node.draw_multiline_string(g.font, Vector2(r.position.x + 30, r.position.y + 368), body, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 60, 28, 2, g.TEXT)
	_refund_line(r.position.y + 470, "switch_refund")
	_text(r.get_center().x, r.position.y + 520, I18n.t("switch_keep"), 22, g.DIM, r.size.x - 40)
	var by := r.end.y - 92
	_button("no", Rect2(r.position.x + 24, by, 250, 72), I18n.t("cancel"), false)
	_button("yes", Rect2(r.position.x + 290, by, r.size.x - 314, 72), I18n.t("switch_yes"), true)


func _draw_migrated(H: float, k: float) -> void:
	var r := Rect2(28, H * 0.5 - 300 + (1.0 - k) * 40.0, g.W - 56, 590)
	rects["panel"] = r
	_box(r.grow(6), Color(0.02, 0.01, 0.06, 0.6), 40)
	_box(r, PANEL, 36)
	node.draw_polyline(_outline(r.grow(-2), 34), Color(g.ACCENT, 0.85), 3.0, true)
	_text(r.get_center().x, r.position.y + 72, I18n.t("migrate_title"), 46, g.TEXT, r.size.x - 40)
	var hero = g.screens.hero
	for i in Meta.HEROES.size():
		var c := Vector2(r.position.x + 92 + i * ((r.size.x - 184) / 3.0), r.position.y + 175 + sin(t * 3.0 + i) * 5.0)
		# каждый друг — в своей супер-награде (шляпа, корона, маска, тиара)
		hero.draw_avatar(node, Meta.HEROES[i], c, 56, {"aura": Meta.super_recipe(Meta.HEROES[i]).id}, g.t_total + i * 0.9, [Color("#B46CFF"), Color("#FF8FD8"), Color("#FFB547"), Color("#7FE3FF")][i])
	node.draw_multiline_string(g.font, Vector2(r.position.x + 30, r.position.y + 290), I18n.t("migrate_text"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 60, 28, 3, g.TEXT)
	_refund_line(r.position.y + 420, "migrate_refund")
	_button("ok", Rect2(g.W / 2.0 - 170, r.end.y - 100, 340, 76), I18n.t("forge_great"), true)
	# искры
	for i in 8:
		var ph := fposmod(t * 0.6 + i / 8.0, 1.0)
		var p := Vector2(r.position.x + 40 + fposmod(i * 97.0, r.size.x - 80), r.end.y - 120 - ph * 260.0)
		var a := sin(ph * PI)
		var s := 6.0 * a
		node.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.25, -s * 0.25), p + Vector2(s, 0), p + Vector2(s * 0.25, s * 0.25),
			p + Vector2(0, s), p + Vector2(-s * 0.25, s * 0.25), p + Vector2(-s, 0), p + Vector2(-s * 0.25, -s * 0.25)]), Color(1.0, 0.95, 0.7, a))


func _outline(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs := [r.position + Vector2(r.size.x - rad, rad), r.position + r.size - Vector2(rad, rad),
		r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
	for q in 4:
		for i in 7:
			var ang := -PI / 2.0 + q * PI / 2.0 + i * (PI / 2.0) / 6.0
			pts.append(cs[q] + Vector2(cos(ang), sin(ang)) * rad)
	pts.append(pts[0])
	return pts
