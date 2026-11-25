extends RefCounted
## Cascado 0.14: покупка вещи набора прямо из Кристальной кузницы (scripts/forge_ui.gd).
## Нажатие на ячейку вещи в карточке набора:
##   - набор закрыт залом — подсказка «Откроется после зала N»;
##   - вещь уже куплена — надеть / снять (как в гардеробе), подсказка «Надето: …» / «Снято: …»;
##   - вещь не куплена — герой её примеряет (scripts/tryon.gd, как в гардеробе), снизу панель
##     «Отмена» / «Купить за N». Ничего не тратится, пока игрок не нажал «Купить».
##     Не хватает осколков — кнопка неактивна, в панели «Не хватает N осколков».
## После покупки вещь сразу надета, ячейка загорается; если набор собран и осколков хватает —
## подсказка «Можно выковать!».

const Meta := preload("res://scripts/meta.gd")
const I18n := preload("res://scripts/i18n.gd")
const Rarity := preload("res://scripts/rarity.gd")
const TryOn := preload("res://scripts/tryon.gd")

const DARK_TEXT := Color("#2A1A0A")
const BAD_COL := Color("#FF6B8A")
## Сколько секунд горит ячейка после покупки
const LIT_TIME := 1.2

var g                     # узел игры (scripts/game.gd)
var f                     # экран кузницы (scripts/forge_ui.gd)
var tryon = TryOn.new()   # примеряемая вещь ("" — панели нет)
var set_n := 0            # набор, из которого вещь
var cell := -1            # номер ячейки в карточке
var t := 0.0              # секунд с открытия панели
var rects := {}
var lit_n := 0            # ячейка, которая горит после покупки
var lit_i := -1
var lit_t := 99.0


func _init(game, forge) -> void:
	g = game
	f = forge


func active() -> bool:
	return tryon.active()


func update(delta: float) -> void:
	t += delta
	lit_t += delta


func close() -> void:
	tryon.clear()
	set_n = 0
	cell = -1


## «Отмена», касание мимо панели, «Назад» на телефоне
func cancel() -> void:
	if not active():
		return
	close()
	g.play("click", 0.9)


func _name(id: String) -> String:
	return Meta.item_name(id, f.kind(), f._gen())


## Нажатие на ячейку i в карточке набора n
func tap_cell(n: int, i: int) -> void:
	var rc: Dictionary = Meta.recipe_for_set(n)
	var needs: Array = rc.get("needs", [])
	if i < 0 or i >= needs.size():
		return
	var id: String = needs[i]
	var sc = g.screens
	if g.meta.forge_status(rc.id, g.max_level) == "hall":
		g.play("click", 0.8)
		sc.say(I18n.t("forge_hall_hint") % int(Meta.set_info(n).hall))
		return
	if g.meta.is_owned(id):
		match g.meta.tap_item(id):
			"on":
				g.play("crystal")
				sc.say(I18n.t("forge_worn") % _name(id))
				g._save()
			"off":
				g.play("click")
				sc.say(I18n.t("forge_took_off") % _name(id))
				g._save()
			_:
				g.play("click", 0.8)
				sc.say(I18n.t("forge_buy_have"))
		return
	var why := Meta.lock_reason(id, g.total_stars(), g.max_level)
	if why != "":
		g.play("click", 0.7)
		sc.say(why)
		return
	tryon.start_item(id)
	set_n = n
	cell = i
	t = 0.0
	f.react = 0.0
	g.play("crystal", 1.25, -6.0)


## «Купить за N»: покупает и надевает. Возвращает то же, что tryon.confirm ("bought", "poor", ...)
func confirm() -> String:
	if not active():
		return "locked"
	var id: String = tryon.id
	var n := set_n
	var i := cell
	var res: String = tryon.confirm(g.meta, g.total_stars(), g.max_level)
	var sc = g.screens
	match res:
		"bought", "owned":
			close()
			g._save()
			lit_n = n
			lit_i = i
			lit_t = 0.0
			f.react = 0.0
			sc.poke_hero()
			var rid: String = Meta.recipe_for_set(n).id
			if g.meta.forge_status(rid, g.max_level) == "ok":
				g.play("levelup", 1.1, -4.0)
				sc.say(I18n.t("forge_can"))
			else:
				g.play("crystal")
				sc.say(I18n.t("bought") % _name(id))
		"poor":
			g.play("gameover", 1.3, -8.0)
			var need: int = tryon.shortage(g.meta)
			sc.say(I18n.t("poor_n") % [need, I18n.forms("shards_gen_forms", need)])
		_:
			g.play("click", 0.7)
			sc.say(Meta.lock_reason(id, g.total_stars(), g.max_level))
	return res


func tap(pos: Vector2) -> void:
	if t < 0.15:
		return  # защита от двойного касания по ячейке
	if rects.get("buy", Rect2()).has_point(pos):
		confirm()
	elif rects.get("cancel", Rect2()).has_point(pos) or not rects.get("panel", Rect2()).has_point(pos):
		cancel()


# ---------- Рисование ----------

## Горящая ячейка после покупки (рисуется поверх карточки)
func draw_lit(cell_rects: Dictionary) -> void:
	if lit_t >= LIT_TIME or lit_i < 0:
		return
	var cr: Rect2 = cell_rects.get("need_%d_%d" % [lit_n, lit_i], Rect2())
	if cr.size.x <= 0.0:
		return
	var k := lit_t / LIT_TIME
	var a := 1.0 - k
	var col: Color = Meta.set_info(lit_n).get("col", g.CRYSTAL_COL)
	Rarity.soft_disc(g, cr.get_center(), cr.size.x * (0.7 + 0.5 * k), Color(col.lerp(Color.WHITE, 0.4), 0.7 * a))
	g.draw_arc(cr.get_center(), cr.size.x * (0.45 + 0.6 * k), 0, TAU, 32, Color(1, 1, 1, a), 4.0 * a + 1.0, true)


## Примерка на весь экран: герой в вещи, снизу панель покупки
func draw() -> void:
	if not active():
		return
	var sc = g.screens
	var H: float = g.H
	var id: String = tryon.id
	var kind: String = f.kind()
	var it: Dictionary = Meta.item(id)
	var rar := Meta.rarity(id)
	var rcol := Rarity.col(rar)
	var k := clampf(t / 0.2, 0.0, 1.0)
	g.draw_rect(Rect2(0, 0, g.W, H), Color(0.03, 0.015, 0.08, k))
	# название набора сверху и ярлык «Примерка»
	var scol: Color = Meta.set_info(set_n).get("col", g.TEXT)
	var st := Meta.set_title(set_n, f._gen())
	sc._ctext(g.W / 2.0, 150, st, sc.fit_size(st, 640, 40), scol, 660)
	sc._badge(Vector2(g.W / 2.0, 176), I18n.t("try_on"), 24)
	# герой в примеряемой вещи
	var y0 := minf(H - 430.0, 760.0)
	Rarity.soft_disc(g, Vector2(360, y0 - 150), 300, Color(rcol, 0.3))
	g.draw_colored_polygon(sc._ellipse(Vector2(360, y0 + 20), 200, 26), Color(0.2, 0.12, 0.36, 0.9))
	var hs := 1.25 if not it.has("covers") else 1.05
	sc.hero.draw(g, kind, Vector2(360, y0 + 20 - 112 * hs), hs, tryon.outfit(g.meta), g.t_total, f.react)
	g.draw_set_transform(Vector2.ZERO)
	_panel(kind, it, rar)
	sc._toast(H - 330)


func _panel(kind: String, it: Dictionary, rar: String) -> void:
	var sc = g.screens
	var H: float = g.H
	var id: String = tryon.id
	var r := Rect2(14, H - 262, g.W - 28, 244)
	rects["panel"] = r
	g._rbox(r.grow(6), Color(0.02, 0.01, 0.06, 0.55), 34)
	g._rbox(r, Color("#2E1D58"), 30)
	g.draw_polyline(sc._rr_outline(r.grow(-2), 28), Color(g.ACCENT, 0.85), 3.0, true)
	# значок вещи
	var ic := r.position + Vector2(52, 52)
	g.draw_circle(ic, 36, Color(0.08, 0.04, 0.16, 0.9), true, -1.0, true)
	sc.hero.draw_item_icon(g, id, it.slot, kind, ic, 66, g.t_total, f._gen())
	g.draw_set_transform(Vector2.ZERO)
	# цена справа
	var price := str(tryon.price())
	var pw: float = g.font.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	var pr := Rect2(r.end.x - pw - 82, r.position.y + 14, pw + 64, 50)
	sc._pill(pr, Color(0.08, 0.04, 0.16, 0.9))
	var st: String = tryon.status(g.meta, g.total_stars(), g.max_level)
	sc.shard_icon(pr.position + Vector2(28, 25), 15)
	sc._text(pr.position + Vector2(50, 37), price, 32, BAD_COL if st == "poor" else g.CRYSTAL_COL)
	# название, редкость, подсказка
	var tx: float = r.position.x + 106
	var tw: float = pr.position.x - tx - 10
	var nm: String = _name(id)
	sc._text(Vector2(tx, r.position.y + 44), nm, sc.fit_size(nm, tw, 30), g.TEXT, tw)
	var line := I18n.t("try_hint")
	var col: Color = g.DIM
	if st == "poor":
		var n: int = tryon.shortage(g.meta)
		line = I18n.t("poor_n") % [n, I18n.forms("shards_gen_forms", n)]
		col = BAD_COL
	elif st == "locked":
		line = Meta.lock_reason(id, g.total_stars(), g.max_level)
		col = Color("#FFB86B")
	sc._text(Vector2(tx, r.position.y + 78), line, sc.fit_size(line, r.end.x - tx - 20, 22), col, r.end.x - tx - 20)
	var rl := Meta.rarity_name(rar)
	sc._text(Vector2(r.position.x + 16, r.position.y + 122), rl, sc.fit_size(rl, r.size.x - 32, 20), Rarity.frame_col(rar, g.t_total), r.size.x - 32)
	# кнопки
	var by: float = r.end.y - 76
	sc._button("fb_cancel", Rect2(r.position.x + 14, by, 230, 62), I18n.t("cancel"), false, 30)
	rects["cancel"] = sc.rects["fb_cancel"]
	var br := Rect2(r.position.x + 258, by, r.size.x - 272, 62)
	var ok := st == "ok"
	sc._button("fb_buy", br, "", ok, 32, ok)
	rects["buy"] = br
	var label := I18n.t("buy_for") % tryon.price()
	var fs: int = sc.fit_size(label, br.size.x - 60, 30)
	var lw: float = g.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0: float = br.get_center().x - (lw + 40) / 2.0
	sc._text(Vector2(x0, br.get_center().y + 11), label, fs, DARK_TEXT if ok else Color(g.TEXT, 0.45))
	sc.shard_icon(Vector2(x0 + lw + 24, br.get_center().y), 15)
	if not ok:
		g._rbox(br, Color(0.1, 0.06, 0.2, 0.35), 26)
