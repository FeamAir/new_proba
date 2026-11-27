extends RefCounted
## 0.17: герой рядом с полем — текущий друг в своём наряде внизу правой панели уровня.
## Реакции на игру:
##   обычно — покачивается и дышит (как везде, scripts/hero.gd);
##   каскад ×2 — радуется (реакция касания);  ×3 и больше — подпрыгивает, вокруг искорки;
##   поле почти заполнено — пугается: глаза шире, дрожит, капелька пота;
##   победа — праздник (прыжки, искорки);  поражение — грустит (глаза-«полуопущены», слезинка);
##   касание героя — его обычная реакция.
## 0.18: нарисованный герой меняет позу (pose()): idle — обычно, happy — каскад ×3+ и победа,
##   wow — каскад ×2, кристалл и касание, worried — поле почти полное, sad — поражение.
## Рисует на узле игры (scripts/game.gd), правила игры не меняет.
## Производительность: герой — много мелких деталей (~2–5 мс на кадр), поэтому он рисуется в свою
## картинку (SubViewport) 20–30 раз в секунду, а в кадре уровня рисуется одна готовая картинка.
## Без setup() (тесты без экрана) — рисуется прямо на узле игры.

const Hero := preload("res://scripts/hero.gd")
const HeroArt := preload("res://scripts/hero_art.gd")

const JUMP_TIME := 1.4      # прыжок с искорками (каскад ×3+)
const WOW_TIME := 1.1       # 0.18: «Ого!» после кристалла
const FEAR_IN := 4.0        # как быстро появляется / уходит испуг (1/с)
## Масштаб героя относительно места (у аксолотля шире жабры — чуть меньше)
const KIND_K := {"owl": 1.0, "axolotl": 0.92, "puppy": 1.0, "kitten": 1.0}
const GOLD := Color("#FFB547")
const ICE := Color("#9FF6FF")
const DROP := Color("#7FD6FF")
const FPS := 30.0           # как часто перерисовывается картинка героя во время реакции
const FPS_CALM := 20.0      # ... и когда герой просто дышит (покачивание медленное)
## Запас картинки вокруг места героя: прыжок и искорки — вверх, спутник — вбок
const PAD_TOP := 90.0
const PAD_SIDE := 14.0
const PAD_BOTTOM := 26.0

var hero = Hero.new()
var t := 0.0
var react := 99.0      # секунд с радости / касания
var jump := 99.0       # секунд с прыжка (каскад ×3+)
var jump_chain := 0
var wow := 99.0        # 0.18: секунд с освобождённого кристалла
var fear := 0.0        # 0..1 — сглаженная опасность
var mood := ""         # "", "win", "lose"
var mood_t := 0.0
var rect := Rect2()    # место героя на панели (заполняется при рисовании; касание — по нему)
var drawn := 0         # сколько раз нарисован (для тестов)
var draw_us := 0.0     # сглаженное время рисования героя, мкс (замер производительности)
# картинка героя (кэш)
var vp: SubViewport
var canvas: Node2D
var renders := 0       # сколько раз картинка перерисована
var _kind := "owl"
var _outfit := {}
var _area := Rect2()
var _res := 1.0
var _since := 99.0
var _wanted := false


## Создать картинку героя (SubViewport) — вызывается из game.gd _ready().
func setup(parent: Node) -> void:
	vp = SubViewport.new()
	vp.name = "PlayHeroViewport"
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.gui_disable_input = true
	vp.handle_input_locally = false
	vp.audio_listener_enable_2d = false
	vp.size = Vector2i(8, 8)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	canvas = Node2D.new()
	canvas.name = "HeroCanvas"
	vp.add_child(canvas)
	canvas.draw.connect(_on_canvas_draw)
	parent.add_child(vp)


## Нарисовать героя на панели уровня (из game.gd _draw_panel): готовая картинка или напрямую.
func draw_on(ci: CanvasItem, kind: String, outfit: Dictionary, r: Rect2) -> void:
	if vp == null:
		draw(ci, kind, outfit, r)
		return
	rect = r
	_wanted = true
	if kind != _kind or outfit != _outfit:
		_kind = kind
		_outfit = outfit.duplicate()
		_since = 99.0
	var res := clampf(ci.get_viewport().get_final_transform().get_scale().x, 1.0, 3.0) if ci.is_inside_tree() else 1.0
	var area := Rect2(r.position - Vector2(PAD_SIDE, PAD_TOP), r.size + Vector2(PAD_SIDE * 2.0, PAD_TOP + PAD_BOTTOM))
	if area != _area or absf(res - _res) > 0.01:
		_area = area
		_res = res
		vp.size = Vector2i(ceili(area.size.x * res), ceili(area.size.y * res))
		canvas.scale = Vector2(res, res)
		canvas.position = -area.position * res
		_since = 99.0
	if renders > 0:
		draw_base(ci, kind, outfit, r)  # полупрозрачное свечение — прямо на экран (в картинке оно темнеет)
		ci.draw_texture_rect(vp.get_texture(), _area, false)


func _on_canvas_draw() -> void:
	draw(canvas, _kind, _outfit, rect, false)
	renders += 1


## Перерисовать картинку героя (не чаще FPS, сразу — при событии); только пока панель на экране.
func _refresh(delta: float) -> void:
	if vp == null:
		return
	_since += delta
	var fps := FPS_CALM if current() in ["idle", "lose"] else FPS
	if _wanted and _since >= 1.0 / fps:
		_since = 0.0
		canvas.queue_redraw()
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_wanted = false


func reset() -> void:
	react = 99.0
	jump = 99.0
	jump_chain = 0
	wow = 99.0
	fear = 0.0
	mood = ""
	mood_t = 0.0


func update(delta: float, danger: bool) -> void:
	t += delta
	react += delta
	jump += delta
	wow += delta
	mood_t += delta
	fear = move_toward(fear, 1.0 if danger and mood == "" else 0.0, delta * FEAR_IN)
	_refresh(delta)


func on_cascade(chain: int) -> void:
	if mood != "":
		return
	_since = 99.0
	if chain >= 3:
		jump = 0.0
		jump_chain = chain
		react = 0.0
	elif chain == 2:
		react = 0.0


## 0.18: освобождён кристалл — «Ого!» (поза wow), если нет реакции сильнее
func on_crystal() -> void:
	if mood != "":
		return
	if wow >= WOW_TIME:
		_since = 99.0
	wow = 0.0


func on_win() -> void:
	_since = 99.0
	mood = "win"
	mood_t = 0.0
	react = 0.0


func on_lose() -> void:
	_since = 99.0
	mood = "lose"
	mood_t = 0.0
	react = 99.0
	jump = 99.0


## Касание героя: обычная реакция (повторное касание не сбивает уже идущую).
func poke() -> void:
	_since = 99.0
	if mood == "lose":
		react = 99.0
		return
	if react > 0.35:
		react = 0.0


## Текущая реакция: "win", "lose", "jump", "joy", "fear" или "idle".
func current() -> String:
	if mood != "":
		return mood
	if jump < JUMP_TIME:
		return "jump"
	if react < Hero.REACT_TIME:
		return "joy"
	if fear > 0.5:
		return "fear"
	return "idle"


## 0.18: поза нарисованного героя по текущей реакции
func pose() -> String:
	match current():
		"jump", "win":
			return "happy"
		"joy":
			return "wow"
		"fear":
			return "worried"
		"lose":
			return "sad"
	return "wow" if wow < WOW_TIME else "idle"


## Глаза: >1 — распахнуты (испуг), <1 — полуопущены (грусть).
func eye_k() -> float:
	match current():
		"lose":
			return 0.6
		"fear":
			return 1.0 + 0.22 * fear
	return 1.0


## Нарисовать героя kind в наряде outfit в прямоугольнике r на ci.
## Масштаб и точка под лапками героя в прямоугольнике r.
## Спутник (книжка, мячик, клубок...) летает справа — тогда герой меньше и левее, чтобы всё влезло.
static func place(kind: String, outfit: Dictionary, r: Rect2) -> Array:
	var comp: bool = outfit.get("companion", "") != ""
	# 0.18: у нарисованного героя спутник висит дальше вправо — место под него шире
	var art := HeroArt.available(kind, outfit)
	var cw := 310.0 if art else 275.0
	var sc: float = minf(r.size.x / (cw if comp else 235.0), r.size.y / 285.0) * KIND_K.get(kind, 1.0)
	var feet := Vector2(r.position.x + (100.0 if art else 108.0) * sc + 2.0 if comp else r.get_center().x, r.end.y - 10.0)
	return [sc, feet]


## Мягкий «пьедестал» — свечение и тень под лапками (цвет — по настроению).
func draw_base(ci: CanvasItem, kind: String, outfit: Dictionary, r: Rect2) -> void:
	var pl := place(kind, outfit, r)
	var sc: float = pl[0]
	var feet: Vector2 = pl[1]
	var cur := current()
	var glow := GOLD if cur in ["win", "jump"] else (Color("#FF6B8A") if cur == "fear" else Color("#B46CFF"))
	_ellipse(ci, feet + Vector2(0, -2), 74.0 * sc / 0.75, 14.0 * sc / 0.75, Color(glow, 0.22))
	_ellipse(ci, feet + Vector2(0, -2), 50.0 * sc / 0.75, 8.0 * sc / 0.75, Color(0, 0, 0, 0.28))


## Нарисовать героя прямо на ci (with_base — и «пьедестал»).
func draw(ci: CanvasItem, kind: String, outfit: Dictionary, r: Rect2, with_base := true) -> void:
	rect = r
	drawn += 1
	var t0 := Time.get_ticks_usec()
	var cur := current()
	var pl := place(kind, outfit, r)
	var sc: float = pl[0]
	var feet: Vector2 = pl[1]
	if with_base:
		draw_base(ci, kind, outfit, r)
	var pos := feet - Vector2(0, 118.0 * sc)
	var rv := 99.0
	match cur:
		"jump":
			var k := clampf(jump / 0.6, 0.0, 1.0)
			pos.y -= sin(k * PI) * 40.0 * sc
			rv = jump
		"joy":
			rv = react
		"win":
			pos.y -= absf(sin(mood_t * 6.0)) * 22.0 * sc
			rv = fmod(mood_t, Hero.REACT_TIME * 0.9)
		"lose":
			pos.y += 6.0 * sc
	if fear > 0.05:
		pos.x += sin(t * 52.0) * 2.4 * fear  # дрожит
	hero.eye_k = eye_k()
	hero.draw(ci, kind, pos, sc, outfit, t, rv, false, pose())
	hero.eye_k = 1.0
	var head := pos + Vector2(0, -50.0 * sc)
	if cur == "fear" or (fear > 0.3 and cur == "joy"):
		_sweat(ci, head + Vector2(84.0, -6.0) * sc, sc, fear)
	if cur == "lose":
		var k2 := fmod(mood_t, 1.6) / 1.6
		_drop(ci, pos + Vector2(-40.0, -10.0 + k2 * 40.0) * sc, 8.0 * sc / 0.75, Color(DROP, 0.95 * (1.0 - k2)))
		# 0.18: у нарисованного героя голова (и шапка) выше — тучка тоже
		_cloud(ci, pos + Vector2(sin(t * 1.3) * 6.0, -190.0 if HeroArt.available(kind, outfit) else -160.0) * sc, sc)
	if cur == "jump":
		_sparkles(ci, pos + Vector2(0, -10.0 * sc), sc, jump / JUMP_TIME, 6 + mini(jump_chain - 3, 3) * 2)
	elif cur == "win":
		_sparkles(ci, pos + Vector2(0, -10.0 * sc), sc, fmod(mood_t, 1.2) / 1.2, 8)
	var us := float(Time.get_ticks_usec() - t0)
	draw_us = us if drawn == 1 else lerpf(draw_us, us, 0.05)


func hit(pos: Vector2) -> bool:
	return rect.size.x > 0.0 and rect.has_point(pos)


# ---------- Рисование эффектов ----------

static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


## Капля (пот, слеза): круглая снизу, острая сверху
static func _drop(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if col.a <= 0.01:
		return
	var pts := PackedVector2Array([c + Vector2(0, -r * 2.1)])
	for i in 13:
		var a := -0.15 * PI + i * (1.3 * PI) / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.2), r * 0.28, Color(1, 1, 1, 0.75 * col.a), true, -1.0, true)


func _sweat(ci: CanvasItem, c: Vector2, sc: float, k: float) -> void:
	var slide := fmod(t, 1.1) / 1.1
	var s := 11.0 * sc / 0.75
	_drop(ci, c + Vector2(0, slide * 16.0 * sc), s, Color(DROP, 0.95 * k * (1.0 - slide * 0.6)))
	# «нервные» чёрточки над головой
	var a := Color(1, 1, 1, 0.55 * k)
	for i in 3:
		var ang := -PI / 2.0 + (i - 1) * 0.42
		var p0 := c + Vector2(-84.0 * sc, -76.0 * sc) + Vector2(cos(ang), sin(ang)) * 16.0 * sc
		ci.draw_line(p0, p0 + Vector2(cos(ang), sin(ang)) * 12.0 * sc, a, maxf(2.0, 3.0 * sc), true)


## Грустная тучка с капельками над головой (поражение)
func _cloud(ci: CanvasItem, c: Vector2, sc: float) -> void:
	var col := Color("#8C86A8")
	for b in [[Vector2(-26, 4), 18.0], [Vector2(0, -6), 24.0], [Vector2(26, 4), 17.0], [Vector2(0, 10), 18.0]]:
		ci.draw_circle(c + b[0] * sc, b[1] * sc, col, true, -1.0, true)
	for i in 3:
		var k := fmod(t * 1.4 + i * 0.33, 1.0)
		_drop(ci, c + Vector2(-20.0 + i * 20.0, 30.0 + k * 34.0) * sc, 4.5 * sc / 0.75, Color(DROP, 0.9 * (1.0 - k)))


## Искорки разлетаются кольцом; k — 0..1 фаза
func _sparkles(ci: CanvasItem, c: Vector2, sc: float, k: float, n: int) -> void:
	var a := clampf(1.2 - k, 0.0, 1.0)
	for i in n:
		var ang := i * TAU / n + t * 0.8
		var rr := (70.0 + k * 70.0) * sc
		var p := c + Vector2(cos(ang) * rr, sin(ang) * rr * 0.85)
		var s := (9.0 + 4.0 * sin(t * 9.0 + i)) * sc
		var col := GOLD if i % 2 == 0 else ICE
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.3, -s * 0.3), p + Vector2(s, 0), p + Vector2(s * 0.3, s * 0.3),
			p + Vector2(0, s), p + Vector2(-s * 0.3, s * 0.3), p + Vector2(-s, 0), p + Vector2(-s * 0.3, -s * 0.3)]), Color(col, a))
