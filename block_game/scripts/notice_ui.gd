extends RefCounted
## Cascado 0.12b: окна поверх любого экрана (свой слой CanvasLayer — видно и над 3D-домом):
##  • 0.16: окна «Сменить друга?» больше нет — смена мгновенная, у каждого друга свои вещи и дом.
##    При первой смене в жизни игрока — ненавязчивая плашка-подсказка на 3 с (show_hint; касания
##    не забирает).
##  • «Гардероб обновлён!» — один раз после загрузки старого сохранения (0.6–0.12): общие вещи
##    убраны, их цена и плата за ковку вернулись осколками (meta.gd, notice_refund).
##    0.13: то же окно — о новых наборах «Кот-детектив» и «Цветочный пикник» (meta.gd, notice_sets).
##  • 0.13: «Как зовут друга?» — имя героя: поле ввода (LineEdit — на телефоне сама открывается
##    экранная клавиатура), до 12 знаков, кнопки «Готово» / «Отмена» (и «Без имени», если имя было).

const Meta := preload("res://scripts/meta.gd")
const I18n := preload("res://scripts/i18n.gd")

const DARK_TEXT := Color("#2A1A0A")
const PANEL := Color("#2E1D58")

var g
var layer: CanvasLayer
var node: Node2D
var mode := ""        # "" — окна нет; "migrated" — гардероб обновлён; "name" — имя
var refund := 0       # сколько осколков вернулось (старое сохранение)
## 0.16: плашка-подсказка при первой смене друга (не окно: касания проходят мимо)
const HINT_TIME := 3.0
var hint_t := 0.0     # сколько ещё показывать (0 — не видно)
var hint_kind := ""   # новый друг — его аватарка на плашке
var t := 0.0
var rects := {}
var sb := StyleBoxFlat.new()
var edit: LineEdit    # 0.13: поле ввода имени (видно только в окне имени)
var name_for := ""    # чьё имя вводим


func _init(game) -> void:
	g = game
	layer = CanvasLayer.new()
	layer.layer = 20
	node = Node2D.new()
	node.draw.connect(_draw)
	layer.add_child(node)
	g.add_child(layer)
	node.visible = false
	edit = LineEdit.new()
	edit.max_length = 12
	edit.visible = false
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.virtual_keyboard_enabled = true
	edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	edit.select_all_on_focus = true
	edit.context_menu_enabled = false
	edit.add_theme_font_size_override("font_size", 40)
	if g.font:
		edit.add_theme_font_override("font", g.font)
	edit.add_theme_color_override("font_color", Color("#FFF4E0"))
	edit.add_theme_color_override("caret_color", Color("#FFB547"))
	var es := StyleBoxFlat.new()
	es.bg_color = Color("#160C2E")
	es.set_corner_radius_all(22)
	es.set_border_width_all(3)
	es.border_color = Color("#FFB547")
	es.content_margin_left = 18
	es.content_margin_right = 18
	edit.add_theme_stylebox_override("normal", es)
	edit.add_theme_stylebox_override("focus", es)
	edit.text_changed.connect(_on_name_changed)
	edit.text_submitted.connect(func(_s): name_done())
	layer.add_child(edit)


func active() -> bool:
	return mode != ""


## 0.16: подсказка «У каждого друга свой гардероб и свой дом» (kind — новый друг).
func show_hint(kind: String) -> void:
	hint_kind = kind
	hint_t = HINT_TIME


func hint_showing() -> bool:
	return hint_t > 0.0


## 0.13: окно имени для героя kind (поле — с текущим именем; клавиатура открывается сама).
func ask_name(kind: String) -> void:
	mode = "name"
	name_for = kind
	t = 0.0
	edit.text = g.meta.name_of(kind)
	edit.visible = true
	edit.caret_column = edit.text.length()
	if edit.is_inside_tree():
		edit.call_deferred("grab_focus")
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(edit.text, Rect2(), DisplayServer.KEYBOARD_TYPE_DEFAULT, 12)


## Запрещённые знаки убираются сразу при вводе (буквы любого алфавита, цифры, пробел, дефис).
func _on_name_changed(txt: String) -> void:
	var re := RegEx.new()
	re.compile("[^\\p{L}\\p{N} \\-]")
	var c := re.sub(txt, "", true).replace("  ", " ").lstrip(" ")
	if c != txt:
		var col := edit.caret_column
		edit.text = c
		edit.caret_column = mini(col, c.length())


func _close_name() -> void:
	edit.visible = false
	if edit.is_inside_tree():
		edit.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	mode = ""


## «Готово»: пустое имя не принимается (кнопка неактивна).
func name_done() -> void:
	if mode != "name":
		return
	if not g.meta.set_hero_name(name_for, edit.text):
		g.play("click", 0.7)
		return
	_close_name()
	g._save()
	g.play("crystal", 1.2)
	g.screens.poke_hero()
	g.screens.say(I18n.t("name_hello") % g.meta.name_of(name_for))


## «Без имени»: снова Совёнок / Совушка...
func name_clear() -> void:
	g.meta.clear_hero_name(name_for)
	_close_name()
	g._save()
	g.play("click")


## Сообщение о вернувшихся за старые вещи осколках показывается на спокойных экранах.
func _calm() -> bool:
	return g.state in [g.State.HOME, g.State.WARDROBE, g.State.MAP, g.State.FORGE]


func update(delta: float) -> void:
	if mode == "" and g.meta.notice_refund > 0 and _calm():
		mode = "migrated"
		refund = g.meta.notice_refund
		t = 0.0
	t += delta
	hint_t = maxf(0.0, hint_t - minf(delta, 0.1))  # долгий кадр (строится 3D-дом) не съедает показ подсказки
	node.visible = mode != "" or hint_t > 0.0
	if edit.visible != (mode == "name"):
		edit.visible = mode == "name"
	if node.visible:
		node.queue_redraw()


func tap(pos: Vector2) -> void:
	if t < 0.25:
		return  # защита от случайного двойного касания
	match mode:
		"migrated":
			if rects.get("ok", Rect2()).has_point(pos):
				back()
		"name":
			if rects.get("name_ok", Rect2()).has_point(pos):
				name_done()
			elif rects.get("name_clear", Rect2()).has_point(pos):
				name_clear()
			elif rects.get("no", Rect2()).has_point(pos):
				back()
			elif rects.get("field", Rect2()).has_point(pos) and edit.is_inside_tree():
				edit.grab_focus()
				if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
					DisplayServer.virtual_keyboard_show(edit.text, Rect2(), DisplayServer.KEYBOARD_TYPE_DEFAULT, 12)


## «Отмена» / «Назад» на телефоне. Для сообщения об обновлении — закрыть (больше не покажется).
func back() -> void:
	if mode == "migrated":
		g.meta.notice_refund = 0
		g.meta.notice_sets = false
		g._save()
		g.play("crystal")
	elif mode == "name":
		_close_name()
		g.play("click", 0.9)
		return
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


## Строка «Возвращено: N осколков» с кристаллом
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
		if hint_t > 0.0:
			_draw_hint()
		return
	var H: float = g.H
	var k := clampf(t / 0.2, 0.0, 1.0)
	node.draw_rect(Rect2(0, 0, g.W, H), Color(0.02, 0.01, 0.06, 0.72 * k))
	if mode == "name":
		_draw_name(H, k)
	else:
		_draw_migrated(H, k)


## 0.16: плашка «У каждого друга свой гардероб и свой дом...» вверху экрана: аватарка нового друга
## и текст в две строки; плавно появляется и исчезает.
func _draw_hint() -> void:
	var a := clampf(minf((HINT_TIME - hint_t) / 0.25, hint_t / 0.4), 0.0, 1.0)
	var oy: float = (g.H - 1280.0) * 0.5
	var r := Rect2(24, 150 + oy - (1.0 - a) * 24.0, g.W - 48, 132)
	_box(r.grow(5), Color(0.02, 0.01, 0.06, 0.45 * a), 36)
	_box(r, Color(PANEL, 0.96 * a), 32)
	node.draw_polyline(_outline(r.grow(-2), 30), Color(g.ACCENT, 0.85 * a), 3.0, true)
	var kind := hint_kind if hint_kind != "" else String(g.meta.hero)
	if kind != "":
		g.screens.hero.draw_avatar(node, kind, Vector2(r.position.x + 70, r.get_center().y), 46, g.meta.outfit_for(kind), g.t_total, Color(g.ACCENT, a))
	var tx := r.position.x + 134
	var tw := r.end.x - tx - 22
	var txt := I18n.t("switch_hint")
	var fs := 28
	while fs > 18 and g.font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, tw, fs, 3).y > r.size.y - 24:
		fs -= 1
	var hgt: float = g.font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, tw, fs, 3).y
	node.draw_multiline_string(g.font, Vector2(tx, r.get_center().y - hgt / 2.0 + g.font.get_ascent(fs)), txt,
		HORIZONTAL_ALIGNMENT_CENTER, tw, fs, 3, Color(g.TEXT, a))


func _draw_migrated(H: float, k: float) -> void:
	var r := Rect2(28, H * 0.5 - 300 + (1.0 - k) * 40.0, g.W - 56, 590)
	rects["panel"] = r
	_box(r.grow(6), Color(0.02, 0.01, 0.06, 0.6), 40)
	_box(r, PANEL, 36)
	node.draw_polyline(_outline(r.grow(-2), 34), Color(g.ACCENT, 0.85), 3.0, true)
	_text(r.get_center().x, r.position.y + 72, I18n.t("migrate_title"), 46, g.TEXT, r.size.x - 40)
	var hero = g.screens.hero
	if g.meta.notice_sets:
		# 0.13: новые наборы — котик-детектив и щенок на цветочном пикнике
		var looks := [["kitten", {"head": "ki_sleuth_hat", "eyes": "ki_moustache"}, Color("#D9A86A")], ["puppy", {"head": "pu_daisy_wreath", "eyes": "pu_daisy_specs"}, Color("#8FE3A0")]]
		for i in 2:
			var hk: String = looks[i][0]
			var c := Vector2(g.W / 2.0 + (i * 2 - 1) * 120.0, r.position.y + 168 + sin(t * 3.0 + i) * 4.0)
			hero.draw_avatar(node, hk, c, 60, g.meta.look(hk).merged(looks[i][1]), g.t_total + i * 0.9, looks[i][2])
	for i in (0 if g.meta.notice_sets else Meta.HEROES.size()):
		var c := Vector2(r.position.x + 92 + i * ((r.size.x - 184) / 3.0), r.position.y + 175 + sin(t * 3.0 + i) * 5.0)
		# каждый друг — в своей супер-награде (шляпа, корона, маска, тиара)
		var hk: String = Meta.HEROES[i]
		hero.draw_avatar(node, hk, c, 56, g.meta.look(hk).merged({"aura": Meta.super_recipe(hk).id}), g.t_total + i * 0.9, [Color("#B46CFF"), Color("#FF8FD8"), Color("#FFB547"), Color("#7FE3FF")][i])
	# 0.14: названия новых наборов — по полу героя («Кот-детектив» / «Кошка-детектив»)
	var mt := I18n.t("migrate_text")
	if g.meta.notice_sets:
		mt = I18n.t("migrate_sets_text") % [Meta.set_title(Meta.set_index("kit_detective"), g.meta.gender_of("kitten")),
			Meta.set_title(Meta.set_index("pup_picnic"), g.meta.gender_of("puppy"))]
	node.draw_multiline_string(g.font, Vector2(r.position.x + 30, r.position.y + 282), mt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 60, 28, 3, g.TEXT)
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


## 0.13: «Как зовут друга?» — окно в верхней половине экрана (нижнюю закрывает клавиатура телефона)
func _draw_name(H: float, k: float) -> void:
	var has_name: bool = g.meta.name_of(name_for) != ""
	var r := Rect2(28, 110 + (1.0 - k) * 30.0, g.W - 56, 520 if has_name else 470)
	rects["panel"] = r
	_box(r.grow(6), Color(0.02, 0.01, 0.06, 0.6), 40)
	_box(r, PANEL, 36)
	node.draw_polyline(_outline(r.grow(-2), 34), Color(g.ACCENT, 0.85), 3.0, true)
	var hero = g.screens.hero
	var kind := name_for
	hero.draw_avatar(node, kind, Vector2(r.position.x + 96, r.position.y + 96), 56, g.meta.outfit_for(kind), g.t_total, g.ACCENT, 0.4 + fposmod(t, 3.0))
	_text(r.position.x + 96 + (r.size.x - 150) / 2.0 + 20, r.position.y + 82, I18n.t("name_title"), 40, g.TEXT, r.size.x - 190)
	_text(r.position.x + 96 + (r.size.x - 150) / 2.0 + 20, r.position.y + 124, Meta.hero_name(kind, g.meta.gender_of(kind)), 26, g.DIM, r.size.x - 190)
	# поле ввода (LineEdit) — поверх окна
	var fr := Rect2(r.position.x + 36, r.position.y + 180, r.size.x - 72, 84)
	rects["field"] = fr
	edit.position = fr.position
	edit.size = fr.size
	edit.modulate.a = k
	var clean: String = Meta.clean_name(edit.text)
	_text(r.get_center().x, fr.end.y + 40, I18n.t("name_hint") + "  ·  %d / %d" % [edit.text.length(), Meta.NAME_MAX], 22, g.DIM, r.size.x - 60)
	var by := r.end.y - (150 if has_name else 108)
	_button("no", Rect2(r.position.x + 24, by, 250, 76), I18n.t("cancel"), false)
	_button("name_ok", Rect2(r.position.x + 290, by, r.size.x - 314, 76), I18n.t("name_done"), clean != "")
	if clean == "":
		_box(rects["name_ok"], Color(0.1, 0.06, 0.2, 0.45), 28)
	if has_name:
		var cr := Rect2(r.get_center().x - 130, r.end.y - 62, 260, 40)
		rects["name_clear"] = Rect2(cr.position - Vector2(0, 8), cr.size + Vector2(0, 16))
		_text(cr.get_center().x, cr.position.y + 26, I18n.t("name_clear"), 24, Color(g.TEXT, 0.75), cr.size.x)
		var tw: float = minf(cr.size.x, g.font.get_string_size(I18n.t("name_clear"), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x)
		node.draw_line(Vector2(cr.get_center().x - tw / 2.0, cr.position.y + 32), Vector2(cr.get_center().x + tw / 2.0, cr.position.y + 32), Color(g.TEXT, 0.45), 1.5)
