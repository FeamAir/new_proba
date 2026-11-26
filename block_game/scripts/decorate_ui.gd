extends RefCounted
## Режим украшения комнаты (Cascado 0.15). Включается кнопкой «Украсить» на экране «Дом»
## (и вкладкой «Дом» гардероба, целью «Можно купить» с украшением, касанием по вещи в 3D-доме).
## Экран «Дом» остаётся (3D или запасной 2D), обычные кнопки прячутся:
##   вверху — осколки, переключатель настроений 1/2/3, «Готово»;
##   внизу — панель: вкладки «Вещи» (фильтр по стилю: Все / 3 стиля; если выбрано место — только то,
##   что ему подходит) и «Комната» (стены / пол / свет).
## Касание по месту в доме выбирает место (камера подлетает); касание мимо снимает выбор (из режима
## не выкидывает). Тап по вещи — примерка на месте («Купить за N» / «Отмена») или сразу «Поставить»,
## если куплена; у поставленной — ⟲ ⟳ (поворот на 45°) и «Убрать». Всё одной рукой: кнопки внизу.
## Данные — scripts/meta.gd (расстановка, настроения), каталог — scripts/decor_catalog.gd.

const Meta := preload("res://scripts/meta.gd")
const Catalog := preload("res://scripts/decor_catalog.gd")
const I18n := preload("res://scripts/i18n.gd")
const TryOn := preload("res://scripts/tryon.gd")
const Swipe := preload("res://scripts/swipe.gd")

const PANEL_H := 468.0
const TOP_H := 150.0
const PER_PAGE := 4
const DARK_TEXT := Color("#2A1A0A")
const OK_COL := Color("#3DDC97")
const BAD_COL := Color("#FF6B8A")
const PANEL_COL := Color(0.07, 0.04, 0.15, 0.96)
## Цвет стен / пола дома в 2D-значках вариантов (умножается на оттенок варианта)
const BASE_2D := {
	"owl": {"walls": Color("#9A6A50"), "floor": Color("#C49A5A")},
	"axolotl": {"walls": Color("#7A8AB8"), "floor": Color("#E2C79A")},
	"puppy": {"walls": Color("#D9CBE0"), "floor": Color("#3E7A48")},
	"kitten": {"walls": Color("#9C7660"), "floor": Color("#84604A")},
}

var g
var active := false
var spot := ""              # выбранное место ("" — нет)
var tab := "items"          # items / room
var style_filter := "all"   # all / id стиля
var layer := "walls"        # вкладка «Комната»: walls / floor / light
var page := 0
var tryon = TryOn.new()
var rects := {}
var _enter_t := 0.0
## 0.18: свайп по ленте карточек листает страницы (тап по карточке — при отпускании пальца)
var strip = Swipe.new()


func _init(game) -> void:
	g = game


func _home() -> String:
	return g.meta.hero if g.meta.hero != "" else "owl"


func _sc():
	return g.screens


# ---------- Вход, выход, выбор ----------

## Включить режим (на экране «Дом»). sp — сразу выбрать место; try_id — сразу примерить вещь.
func open(sp := "", try_id := "") -> void:
	if g.meta.hero == "":
		return
	if g.state != g.State.HOME:
		g.go_home()
	active = true
	tab = "items"
	page = 0
	tryon.clear()
	spot = ""
	_enter_t = g.t_total
	if g.trophy_ui:
		g.trophy_ui.panel_open = false
	if sp != "" and Catalog.has_spot(_home(), sp):
		select(sp)
	if try_id != "":
		tap_item(try_id)


## Выйти («Готово»): примерка снимается, камера — к обзору
func close() -> void:
	if not active:
		return
	active = false
	tryon.clear()
	spot = ""
	_fly_home()
	g._save()


## Выбрать место: камера подлетает, список вещей — для этого места
func select(sp: String) -> void:
	if not Catalog.has_spot(_home(), sp):
		return
	if tryon.active() and not (tryon.is_decor() and tryon.spot == sp):
		tryon.clear()
	spot = sp
	tab = "items"
	page = 0
	if g.home3d and g.home3d.room:
		g.home3d.room.focus_spot(sp)


## Снять выбор места (и примерку): касание мимо
func deselect() -> void:
	tryon.clear()
	if spot != "":
		spot = ""
		page = 0
		_fly_home()


func _fly_home() -> void:
	if g.home3d and g.home3d.room:
		g.home3d.room.cam.fly_home()


## Кнопка «Назад» телефона: примерка -> выбор места -> выход из режима. true — обработано.
func back() -> bool:
	if not active:
		return false
	if tryon.active():
		tryon.clear()
	elif spot != "":
		deselect()
	else:
		close()
	return true


# ---------- Списки ----------

func items() -> Array:
	return Catalog.decor_for(_home(), spot, style_filter)


func layer_items() -> Array:
	return Catalog.layer_items(_home(), layer)


func _list() -> Array:
	return items() if tab == "items" else layer_items()


func pages() -> int:
	return maxi(1, (_list().size() + PER_PAGE - 1) / PER_PAGE)


## Место для вещи, если место не выбрано: где она уже стоит, иначе первое свободное подходящее, иначе первое подходящее
func spot_for(id: String) -> String:
	var home := _home()
	var d: Dictionary = g.meta.decor_placed.get(home, {})
	for s in d:
		if d[s] == id:
			return s
	var first := ""
	for s in Catalog.spot_ids(home):
		if Catalog.fits(home, s, id):
			if first == "":
				first = s
			if d.get(s, "") == "":
				return s
	return first


# ---------- Действия ----------

## Тап по вещи в панели
func tap_item(id: String) -> void:
	var home := _home()
	if spot == "" or not Catalog.fits(home, spot, id):
		var s := spot_for(id)
		if s == "":
			return
		select(s)
		if g.meta.placed_at(home, s) == id:
			g.play("click")
			return  # уже стоит: просто показываем её место
	var res: String = g.meta.tap_decor(home, spot, id)
	match res:
		"try":
			if tryon.id == id:
				tryon.clear()
				g.play("click", 0.9)
				return
			tryon.start_decor(home, spot, id)
			g.play("crystal", 1.25, -6.0)
		"on":
			tryon.clear()
			g.play("crystal")
			g._save()
		"off":
			tryon.clear()
			g.play("click")
			g._save()
		_:
			g.play("click", 0.7)


## Тап по варианту стен / пола / света
func tap_room(id: String) -> void:
	match g.meta.tap_room(_home(), id):
		"on":
			tryon.clear()
			g.play("crystal", 1.1, -4.0)
			g._save()
		"try":
			if tryon.id == id:
				tryon.clear()
				g.play("click", 0.9)
				return
			tryon.start_room(_home(), id)
			g.play("crystal", 1.25, -6.0)
		_:
			g.play("click", 0.7)


func confirm() -> String:
	var id: String = tryon.id
	var res: String = tryon.confirm(g.meta, g.total_stars(), g.max_level)
	match res:
		"bought", "owned":
			g.play("crystal")
			_sc().say(I18n.t("bought") % _name(id))
			_sc().fx_t = 0.0
			_sc().fx_at = Vector2(g.W / 2.0, g.H - PANEL_H - 80.0)
			g._save()
		"poor":
			g.play("gameover", 1.3, -8.0)
		_:
			g.play("click", 0.7)
			_sc().say(Meta.lock_reason(id, g.total_stars(), g.max_level))
	return res


func rotate(steps: int) -> bool:
	if spot == "" or tryon.active():
		return false
	if g.meta.rotate_decor(_home(), spot, steps):
		g.play("click", 1.1 if steps > 0 else 0.95)
		g._save()
		return true
	return false


func remove() -> void:
	if spot == "" or g.meta.placed_at(_home(), spot) == "":
		return
	g.meta.remove_decor(_home(), spot)
	tryon.clear()
	g.play("click")
	g._save()


func set_mood(i: int) -> void:
	tryon.clear()
	if i == g.meta.mood_of(_home()):
		return
	g.meta.switch_mood(_home(), i)
	g.play("crystal", 0.9 + 0.1 * i, -4.0)
	g._save()


## Название слоя: у дома может быть своё (у щенка «Забор», «Земля»: ключ layer_<слой>_<дом>)
func layer_name(l: String) -> String:
	var k := "layer_%s_%s" % [l, _home()]
	return I18n.t(k) if I18n.has(k) else I18n.t("layer_" + l)


func _name(id: String) -> String:
	if Catalog.is_room_item(id):
		return I18n.t("room_" + id)
	return Meta.item_name(id, g.meta.hero, g.meta.gender_of(g.meta.hero))


# ---------- Касания ----------

## 0.18: касание ленты карточек — ждём отпускания (тап или свайп). true — касание забрала лента
func strip_down(idx: int, pos: Vector2) -> bool:
	if not active or not rects.get("strip", Rect2()).has_point(pos):
		return false
	strip.press(idx, pos)
	return true


func strip_up(idx: int, pos: Vector2) -> void:
	if not strip.active():
		return
	match strip.release(idx, pos):
		Swipe.TAP:
			tap(strip.start)
		Swipe.NEXT:
			flip_page(1)
		Swipe.PREV:
			flip_page(-1)


## Страница ленты вперёд (+1) / назад (-1); true — перелистнулась
func flip_page(dir: int) -> bool:
	var p := clampi(page + dir, 0, pages() - 1)
	if p == page:
		return false
	page = p
	g.play("click")
	return true


## true — касание забрала панель / верхняя полоса; false — оно для дома (3D-камера или 2D-места)
func tap(pos: Vector2) -> bool:
	if not active:
		return false
	for n in rects:
		if not (rects[n] as Rect2).has_point(pos):
			continue
		var name := String(n)
		if name == "done":
			g.play("click")
			close()
		elif name.begins_with("mood_"):
			set_mood(int(name.substr(5)))
		elif name == "tab_items" or name == "tab_room":
			g.play("click")
			tryon.clear()
			tab = name.substr(4)
			page = 0
		elif name.begins_with("style_"):
			g.play("click")
			style_filter = name.substr(6)
			page = 0
		elif name.begins_with("layer_"):
			g.play("click")
			tryon.clear()
			layer = name.substr(6)
			page = 0
		elif name.begins_with("card_"):
			var id := name.substr(5)
			if tab == "items":
				tap_item(id)
			else:
				tap_room(id)
		elif name == "rot_l":
			rotate(-1)
		elif name == "rot_r":
			rotate(1)
		elif name == "remove":
			remove()
		elif name == "unselect":
			g.play("click", 0.9)
			deselect()
		elif name == "buy":
			confirm()
		elif name == "cancel":
			tryon.clear()
			g.play("click", 0.9)
		elif name == "prev":
			if page > 0:
				page -= 1
				g.play("click")
		elif name == "next":
			if page < pages() - 1:
				page += 1
				g.play("click")
		else:
			continue  # подложки (панель, полоса) — ниже
		return true
	if rects.get("panel", Rect2()).has_point(pos) or rects.get("top", Rect2()).has_point(pos):
		return true  # мимо кнопок, но по панели — ничего
	# 2D-дом: места — прямоугольники на экране
	if not (g.home3d and g.home3d.showing()):
		for s in Catalog.spot_ids(_home()):
			if _sc().rects.get("spot_" + s, Rect2()).has_point(pos):
				g.play("click")
				select(s)
				return true
		deselect()
		return true
	return false


## Тап в 3D-доме (scripts/home3d/home3d.gd): место — выбрать, остальное — снять выбор
func tap_3d(c: Dictionary) -> void:
	if c.get("type", "") == "spot" and c.get("spot", "") != "":
		g.play("click")
		select(c.spot)
	else:
		if c.get("type", "") == "hero" and g.home3d.room:
			g.home3d.room.poke_hero()
		deselect()


# ---------- Рисование ----------

func panel_rect() -> Rect2:
	return Rect2(0, g.H - PANEL_H, g.W, PANEL_H)


## Часть экрана, где видно дом (для камеры)
func view_rect() -> Rect2:
	return Rect2(0, TOP_H, g.W, g.H - PANEL_H - TOP_H)


func draw() -> void:
	rects.clear()
	var sc = _sc()
	var home := _home()
	# верхняя полоса
	var top := Rect2(0, 0, g.W, TOP_H)
	rects["top"] = top
	g.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(g.W, 0), Vector2(g.W, TOP_H + 40), Vector2(0, TOP_H + 40)]),
		PackedColorArray([Color(0.04, 0.02, 0.1, 0.85), Color(0.04, 0.02, 0.1, 0.85), Color(0.04, 0.02, 0.1, 0), Color(0.04, 0.02, 0.1, 0)]))
	var shr := Rect2(18, 40, 140, 58)
	sc._pill(shr, Color(0.1, 0.06, 0.2, 0.85))
	sc.shard_icon(shr.position + Vector2(30, 29), 16)
	sc._text(shr.position + Vector2(54, 42), str(g.meta.shards), 32, g.CRYSTAL_COL)
	sc._button("done", Rect2(g.W - 176, 36, 158, 66), I18n.t("dec_done"), true, 32)
	rects["done"] = sc.rects["done"]
	_draw_moods(home)
	# панель
	var pr := panel_rect()
	rects["panel"] = pr
	g._rbox(Rect2(pr.position + Vector2(0, -6), pr.size + Vector2(0, 40)), Color(0.02, 0.01, 0.05, 0.5), 30)
	g._rbox(Rect2(pr.position, pr.size + Vector2(0, 30)), PANEL_COL, 28)
	g.draw_polyline(sc._rr_outline(Rect2(pr.position + Vector2(1, 1), pr.size + Vector2(-2, 30)), 27), Color(g.ACCENT, 0.35), 2.0, true)
	var y0 := pr.position.y
	# вкладки «Вещи» / «Комната»
	for i in 2:
		var t: String = ["items", "room"][i]
		var r := Rect2(20 + i * 344, y0 + 14, 336, 58)
		rects["tab_" + t] = r
		var sel := t == tab
		g._rbox(r, g.ACCENT if sel else g.BTN, 22)
		var lbl := I18n.t("dec_tab_" + t)
		sc._text(Vector2(r.position.x, r.position.y + 40), lbl, 30, DARK_TEXT if sel else g.TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if tab == "items":
		_draw_items_tab(home, y0)
	else:
		_draw_room_tab(home, y0)
	sc._toast(TOP_H + 20)


## Переключатель настроений: три кружка со значком стиля (стены / свет) и номером
func _draw_moods(home: String) -> void:
	var sc = _sc()
	var cur: int = g.meta.mood_of(home)
	for i in Meta.MOODS:
		var c := Vector2(g.W / 2.0 + (i - 1) * 92.0, 66)
		var r := Rect2(c - Vector2(40, 40), Vector2(80, 80))
		rects["mood_%d" % i] = r
		var sel := i == cur
		var empty: bool = g.meta.mood_empty(home, i) and not sel
		var st: Dictionary = g.meta.mood_room(home, i)
		if sel:
			g.draw_circle(c, 40, Color(g.ACCENT, 0.3), true, -1.0, true)
		g.draw_circle(c, 33, Color(0.1, 0.06, 0.2, 0.95), true, -1.0, true)
		# превью стиля: верх — стены, низ — пол, точка — свет
		var wc: Color = BASE_2D.get(home, BASE_2D.owl).walls * Catalog.room_item(st.walls).get("tint", Color.WHITE)
		var fc: Color = BASE_2D.get(home, BASE_2D.owl).floor * Catalog.room_item(st.floor).get("tint", Color.WHITE)
		var lc: Color = Catalog.room_item(st.light).get("lamp", Color.WHITE)
		var a := 0.45 if empty else 1.0
		g.draw_arc(c, 22, PI, TAU, 16, Color(wc, a), 14.0, true)
		g.draw_arc(c, 22, 0, PI, 16, Color(fc, a), 14.0, true)
		g.draw_circle(c + Vector2(19, -19), 7, Color(Color("#FFE9B0") * lc, a), true, -1.0, true)
		g.draw_arc(c, 33, 0, TAU, 32, g.ACCENT if sel else Color(g.TEXT, 0.35), 4.0 if sel else 2.0, true)
		sc._ctext(c.x, c.y + 11, str(i + 1), 30, g.TEXT if not empty else Color(g.TEXT, 0.5), 60)
	var label := I18n.t("mood_n") % (cur + 1)
	var lw: float = g.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 28.0
	sc._pill(Rect2(g.W / 2.0 - lw / 2.0, 114, lw, 30), Color(0.06, 0.03, 0.12, 0.8))
	sc._ctext(g.W / 2.0, 136, label, 20, Color(g.TEXT, 0.9), 300)


func _draw_items_tab(home: String, y0: float) -> void:
	var sc = _sc()
	# фильтр по стилю: «Все» поуже, названия стилей — в одну или две строки
	var ids := ["all"] + Catalog.style_ids(home)
	var aw := 96.0
	var cw: float = (g.W - 40.0 - aw - 3 * 8.0) / 3.0
	var x := 20.0
	for i in ids.size():
		var sid: String = ids[i]
		var w := aw if i == 0 else cw
		var r := Rect2(x, y0 + 84, w, 54)
		x += w + 8.0
		rects["style_" + sid] = r
		var sel := sid == style_filter
		g._rbox(r, Color("#46307A") if sel else Color(g.BTN, 0.9), 18)
		if sel:
			g.draw_polyline(sc._rr_outline(r.grow(-1), 17), g.ACCENT, 3.0, true)
		var lbl := I18n.t("dec_all") if sid == "all" else I18n.t("dstyle_" + sid)
		var tx := r.position.x + 6
		var tw := r.size.x - 12
		if sid != "all":
			g.draw_circle(r.position + Vector2(17, 27), 7, Catalog.style_col(sid), true, -1.0, true)
			tx += 18
			tw -= 18
		_chip_text(lbl, Rect2(tx, r.position.y, tw, r.size.y), g.ACCENT if sel else g.TEXT)
	# строка места: название, ⟲ ⟳, «Убрать» — или подсказка
	var ly := y0 + 146
	var placed: String = g.meta.placed_at(home, spot) if spot != "" else ""
	if tryon.active():
		_try_line(ly)
	elif spot == "":
		sc._text(Vector2(24, ly + 34), I18n.t("dec_pick_spot"), sc.fit_size(I18n.t("dec_pick_spot"), g.W - 48, 24), g.DIM, g.W - 48)
	else:
		var xr := Rect2(20, ly, 52, 52)
		rects["unselect"] = xr
		g._rbox(xr, g.BTN, 18)
		_cross(xr.get_center(), 11, g.TEXT)
		var nm := Meta.spot_name(spot, home)
		var right: float = g.W - 20.0
		if placed != "":
			var rmr := Rect2(right - 150, ly, 150, 52)
			sc._button("remove", rmr, I18n.t("dec_remove"), false, 24)
			rects["remove"] = rmr
			right -= 162
			if Catalog.can_rotate(home, spot, placed):
				for k in 2:
					var rr := Rect2(right - 64 - (1 - k) * 72, ly, 64, 52)
					var key: String = ["rot_l", "rot_r"][k]
					rects[key] = rr
					g._rbox(rr, g.BTN, 18)
					_rot_icon(rr.get_center(), 15, k == 1, g.TEXT)
				right -= 144
		var tw2: float = right - 92.0
		sc._text(Vector2(84, ly + 35), nm, sc.fit_size(nm, tw2, 26), g.ACCENT, tw2)
	# карточки
	_cards(items(), y0 + 208, home, true)
	_bottom_row(y0)


func _draw_room_tab(home: String, y0: float) -> void:
	var sc = _sc()
	var cw: float = (g.W - 40.0 - 2 * 8.0) / 3.0
	for i in Catalog.LAYERS.size():
		var l: String = Catalog.LAYERS[i]
		var r := Rect2(20 + i * (cw + 8), y0 + 84, cw, 50)
		rects["layer_" + l] = r
		var sel := l == layer
		g._rbox(r, Color("#46307A") if sel else Color(g.BTN, 0.9), 18)
		if sel:
			g.draw_polyline(sc._rr_outline(r.grow(-1), 17), g.ACCENT, 3.0, true)
		sc._text(Vector2(r.position.x, r.position.y + 34), layer_name(l), 24, g.ACCENT if sel else g.TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var ly := y0 + 146
	if tryon.active():
		_try_line(ly)
	else:
		var cur: String = g.meta.room_of(home).get(layer, "")
		var line := "%s: %s" % [layer_name(layer), I18n.t("room_" + cur)]
		sc._text(Vector2(24, ly + 34), line, sc.fit_size(line, g.W - 48, 24), g.DIM, g.W - 48)
	_cards(layer_items(), y0 + 208, home, false)
	_bottom_row(y0)


## Строка примерки: название и состояние (не хватает осколков / условие)
func _try_line(ly: float) -> void:
	var sc = _sc()
	var st: String = tryon.status(g.meta, g.total_stars(), g.max_level)
	var nm := _name(tryon.id)
	sc._badge(Vector2(24 + 70, ly + 4), I18n.t("try_on"), 20)
	var line := nm
	var col: Color = g.TEXT
	if st == "poor":
		var n: int = tryon.shortage(g.meta)
		line = nm + " · " + I18n.t("poor_n") % [n, I18n.forms("shards_gen_forms", n)]
		col = BAD_COL
	elif st == "locked":
		line = nm + " · " + Meta.lock_reason(tryon.id, g.total_stars(), g.max_level)
		col = Color("#FFB86B")
	sc._text(Vector2(180, ly + 34), line, sc.fit_size(line, g.W - 204, 24), col, g.W - 204)


## Нижняя строка: при примерке — «Отмена» / «Купить за N»; иначе — страницы
func _bottom_row(y0: float) -> void:
	var sc = _sc()
	var by := y0 + 392
	if tryon.active():
		sc._button("cancel", Rect2(20, by, 220, 62), I18n.t("cancel"), false, 28)
		rects["cancel"] = sc.rects["cancel"]
		var br := Rect2(252, by, g.W - 272, 62)
		var ok: bool = tryon.status(g.meta, g.total_stars(), g.max_level) == "ok"
		sc._button("buy", br, "", ok, 30, ok)
		rects["buy"] = br
		var label := I18n.t("buy_for") % tryon.price()
		var lw: float = g.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var x0: float = br.get_center().x - (lw + 40) / 2.0
		sc._text(Vector2(x0, br.get_center().y + 11), label, 30, DARK_TEXT if ok else Color(g.TEXT, 0.45))
		sc.shard_icon(Vector2(x0 + lw + 24, br.get_center().y), 15)
		return
	var n := pages()
	page = clampi(page, 0, n - 1)
	if n <= 1:
		return
	var lr := Rect2(20, by, 140, 56)
	var rr := Rect2(g.W - 160, by, 140, 56)
	rects["prev"] = lr
	rects["next"] = rr
	for k in 2:
		var r: Rect2 = [lr, rr][k]
		var on: bool = page > 0 if k == 0 else page < n - 1
		g._rbox(r, g.BTN if on else Color(g.BTN, 0.4), 20)
		var c := r.get_center()
		var sx := -1.0 if k == 0 else 1.0
		g.draw_colored_polygon(PackedVector2Array([c + Vector2(sx * 14, 0), c + Vector2(-sx * 8, -13), c + Vector2(-sx * 8, 13)]), Color(g.TEXT, 1.0 if on else 0.3))
	for i in n:
		var c := Vector2(g.W / 2.0 + (i - (n - 1) / 2.0) * 30.0, by + 28)
		g.draw_circle(c, 10 if i == page else 7, g.ACCENT if i == page else Color(g.TEXT, 0.3), true, -1.0, true)


func _cards(list: Array, y: float, home: String, decor: bool) -> void:
	var sc = _sc()
	rects["strip"] = Rect2(0, y - 8, g.W, 172.0 + 16.0)  # 0.18: лента карточек (свайп)
	if list.is_empty():
		var msg := I18n.t("dec_no_fit")
		sc._ctext(g.W / 2.0, y + 90, msg, sc.fit_size(msg, g.W - 60, 24), g.DIM, g.W - 60)
		return
	var cw: float = (g.W - 40.0 - 3 * 12.0) / 4.0
	var ch := 172.0
	var cur_room: Dictionary = g.meta.room_of(home)
	for j in PER_PAGE:
		var i := page * PER_PAGE + j
		if i >= list.size():
			break
		var it: Dictionary = list[i]
		var r := Rect2(20 + j * (cw + 12), y, cw, ch)
		rects["card_" + it.id] = r
		var trying: bool = tryon.id == it.id
		var here := false
		var owned := false
		if decor:
			# место не выбрано — «Стоит», если вещь стоит где-нибудь (тап покажет её место)
			here = g.meta.placed_at(home, spot) == it.id if spot != "" else _where(home, it.id) != ""
			owned = g.meta.decor_owned.has(it.id)
		else:
			here = cur_room.get(layer, "") == it.id
			owned = g.meta.room_is_owned(it.id)
		g._rbox(r, Color("#3A2668") if (here or trying) else Color("#22163F"), 20)
		if trying:
			g.draw_polyline(sc._rr_outline(r.grow(-1), 19), g.ACCENT, 4.0, true)
		elif here:
			g.draw_polyline(sc._rr_outline(r.grow(-1), 19), OK_COL, 3.0, true)
		var ic := r.position + Vector2(r.size.x / 2.0, 66)
		if decor:
			g.draw_rect(Rect2(r.position + Vector2(14, 8), Vector2(r.size.x - 28, 5)), Color(Catalog.style_col(it.get("style", "")), 0.9))
			sc.home.draw_decor_icon(g, it.id, ic, 104, g.t_total)
			g.draw_set_transform(Vector2.ZERO)
		else:
			_room_icon(home, Catalog.room_item(it.id), ic, 44)
		var nm := _name(it.id)
		sc._text(Vector2(r.position.x + 4, r.position.y + 132), nm, sc.fit_size(nm, r.size.x - 8, 18), g.TEXT, r.size.x - 8, HORIZONTAL_ALIGNMENT_CENTER)
		var sy := r.position.y + 160
		if here:
			sc._ctext(r.get_center().x, sy, I18n.t("dec_placed") if decor else I18n.t("dec_chosen"), 20, OK_COL, r.size.x)
		elif owned:
			var lbl := I18n.t("dec_choose")
			if decor:
				var where: String = _where(home, it.id)
				lbl = I18n.t("dec_move") if where != "" else I18n.t("dec_place")
			sc._ctext(r.get_center().x, sy, lbl, 20, g.ACCENT, r.size.x)
		else:
			var locked := Meta.lock_reason(it.id, g.total_stars(), g.max_level) != ""
			var p := str(int(it.get("price", 0)))
			var pw: float = g.font.get_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			var x0 := r.get_center().x - (pw + 26) / 2.0
			if locked:
				sc._lock_icon(Vector2(x0 - 8, sy - 8), 9, Color("#FFB86B"))
				x0 += 10
			sc.shard_icon(Vector2(x0 + 9, sy - 7), 9)
			sc._text(Vector2(x0 + 24, sy), p, 22, BAD_COL if int(it.get("price", 0)) > g.meta.shards else g.CRYSTAL_COL)


## Где вещь стоит в текущем настроении ("" — нигде)
func _where(home: String, id: String) -> String:
	var d: Dictionary = g.meta.decor_placed.get(home, {})
	for s in d:
		if d[s] == id:
			return s
	return ""


## Значок варианта слоя: стена (кирпичики), пол (доски) или лампа со светом
func _room_icon(home: String, it: Dictionary, c: Vector2, s: float) -> void:
	var base: Dictionary = BASE_2D.get(home, BASE_2D.owl)
	if it.layer == "light":
		var amb: Color = it.get("ambient", Color.WHITE)
		var lamp: Color = Color("#FFE9B0") * (it.get("lamp", Color.WHITE) as Color)
		var e := float(it.get("energy", 1.0))
		g.draw_circle(c, s, Color(Color("#3A2A66") * amb, 1.0), true, -1.0, true)
		for k in 4:
			g.draw_circle(c, s * (0.9 - k * 0.15), Color(lamp, 0.12 * e), true, -1.0, true)
		g.draw_circle(c, s * 0.32, lamp, true, -1.0, true)
		g.draw_line(c + Vector2(0, -s * 0.32), c + Vector2(0, -s), Color(g.TEXT, 0.6), 2.0, true)
		return
	var col: Color = base.get(it.layer, Color.GRAY) * (it.get("tint", Color.WHITE) as Color)
	var r := Rect2(c - Vector2(s, s * 0.8), Vector2(s * 2, s * 1.6))
	g._rbox(r, col, 10)
	var line := col.darkened(0.3)
	if it.layer == "walls":
		for k in 3:
			var yy := r.position.y + r.size.y * (k + 1) / 4.0
			g.draw_line(Vector2(r.position.x + 4, yy), Vector2(r.end.x - 4, yy), line, 2.0)
			var off := 0.25 if k % 2 == 0 else 0.6
			g.draw_line(Vector2(r.position.x + r.size.x * off, yy - r.size.y / 4.0), Vector2(r.position.x + r.size.x * off, yy), line, 2.0)
	else:
		for k in 3:
			var xx := r.position.x + r.size.x * (k + 1) / 4.0
			g.draw_line(Vector2(xx, r.position.y + 4), Vector2(xx, r.end.y - 4), line, 2.0)


## Подпись кнопки-фильтра: одна строка (не мельче 19), иначе две строки по словам
func _chip_text(lbl: String, r: Rect2, col: Color) -> void:
	var sc = _sc()
	var one: int = sc.fit_size(lbl, r.size.x, 22)
	var parts := lbl.split(" ", false)
	if one >= 19 or parts.size() < 2:
		sc._text(Vector2(r.position.x, r.get_center().y + one * 0.36), lbl, one, col, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	# делим по пробелу так, чтобы строки были поровну
	var best := 1
	var best_d := 1e9
	for k in range(1, parts.size()):
		var a := " ".join(parts.slice(0, k))
		var b := " ".join(parts.slice(k))
		var d := absf(float(a.length() - b.length()))
		if d < best_d:
			best_d = d
			best = k
	var l1 := " ".join(parts.slice(0, best))
	var l2 := " ".join(parts.slice(best))
	var fs: int = mini(sc.fit_size(l1, r.size.x, 19), sc.fit_size(l2, r.size.x, 19))
	sc._text(Vector2(r.position.x, r.get_center().y - 3), l1, fs, col, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	sc._text(Vector2(r.position.x, r.get_center().y + fs - 1), l2, fs, col, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _cross(c: Vector2, s: float, col: Color) -> void:
	g.draw_line(c - Vector2(s, s), c + Vector2(s, s), col, 4.0, true)
	g.draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, 4.0, true)


## Значок поворота: дуга со стрелкой (cw — по часовой)
func _rot_icon(c: Vector2, r: float, cw: bool, col: Color) -> void:
	var a0 := -PI * 0.85
	var a1 := PI * 0.35
	if not cw:
		var t := a0
		a0 = PI - a1
		a1 = PI - t
	g.draw_arc(c, r, a0, a1, 18, col, 4.0, true)
	var tip_a := a1 if cw else a0
	var tip := c + Vector2(cos(tip_a), sin(tip_a)) * r
	var tang := Vector2(-sin(tip_a), cos(tip_a)) * (1.0 if cw else -1.0)
	var nrm := Vector2(cos(tip_a), sin(tip_a))
	g.draw_colored_polygon(PackedVector2Array([tip + tang * 8.0, tip - tang * 2.0 + nrm * 7.0, tip - tang * 2.0 - nrm * 7.0]), col)
