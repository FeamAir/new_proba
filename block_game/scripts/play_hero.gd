extends RefCounted
## 0.17: герой рядом с полем — текущий друг в своём наряде внизу правой панели уровня.
## Реакции на игру:
##   обычно — покачивается и дышит (как везде, scripts/hero.gd);
##   каскад ×2 — радуется (реакция касания);  ×3 и больше — подпрыгивает, вокруг искорки;
##   поле почти заполнено — пугается: глаза шире, дрожит, капелька пота;
##   победа — праздник (прыжки, искорки);  поражение — грустит (глаза-«полуопущены», слезинка);
##   касание героя — его обычная реакция.
## Рисует на узле игры (scripts/game.gd), правила игры не меняет.

const Hero := preload("res://scripts/hero.gd")

const JUMP_TIME := 1.4      # прыжок с искорками (каскад ×3+)
const FEAR_IN := 4.0        # как быстро появляется / уходит испуг (1/с)
## Масштаб героя относительно места (у аксолотля шире жабры — чуть меньше)
const KIND_K := {"owl": 1.0, "axolotl": 0.92, "puppy": 1.0, "kitten": 1.0}
const GOLD := Color("#FFB547")
const ICE := Color("#9FF6FF")
const DROP := Color("#7FD6FF")

var hero = Hero.new()
var t := 0.0
var react := 99.0      # секунд с радости / касания
var jump := 99.0       # секунд с прыжка (каскад ×3+)
var jump_chain := 0
var fear := 0.0        # 0..1 — сглаженная опасность
var mood := ""         # "", "win", "lose"
var mood_t := 0.0
var rect := Rect2()    # место героя на панели (заполняется при рисовании; касание — по нему)
var drawn := 0         # сколько раз нарисован (для тестов)


func reset() -> void:
	react = 99.0
	jump = 99.0
	jump_chain = 0
	fear = 0.0
	mood = ""
	mood_t = 0.0


func update(delta: float, danger: bool) -> void:
	t += delta
	react += delta
	jump += delta
	mood_t += delta
	fear = move_toward(fear, 1.0 if danger and mood == "" else 0.0, delta * FEAR_IN)


func on_cascade(chain: int) -> void:
	if mood != "":
		return
	if chain >= 3:
		jump = 0.0
		jump_chain = chain
		react = 0.0
	elif chain == 2:
		react = 0.0


func on_win() -> void:
	mood = "win"
	mood_t = 0.0
	react = 0.0


func on_lose() -> void:
	mood = "lose"
	mood_t = 0.0
	react = 99.0
	jump = 99.0


## Касание героя: обычная реакция (повторное касание не сбивает уже идущую).
func poke() -> void:
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


## Глаза: >1 — распахнуты (испуг), <1 — полуопущены (грусть).
func eye_k() -> float:
	match current():
		"lose":
			return 0.6
		"fear":
			return 1.0 + 0.22 * fear
	return 1.0


## Нарисовать героя kind в наряде outfit в прямоугольнике r на ci.
func draw(ci: CanvasItem, kind: String, outfit: Dictionary, r: Rect2) -> void:
	rect = r
	drawn += 1
	var cur := current()
	var sc: float = minf(r.size.x / 230.0, r.size.y / 285.0) * KIND_K.get(kind, 1.0)
	var feet := Vector2(r.get_center().x, r.end.y - 10.0)
	# мягкий «пьедестал» — свечение под лапками
	var glow := GOLD if cur in ["win", "jump"] else (Color("#FF6B8A") if cur == "fear" else Color("#B46CFF"))
	_ellipse(ci, feet + Vector2(0, -2), 74.0 * sc / 0.75, 14.0 * sc / 0.75, Color(glow, 0.22))
	_ellipse(ci, feet + Vector2(0, -2), 50.0 * sc / 0.75, 8.0 * sc / 0.75, Color(0, 0, 0, 0.28))
	var pos := feet - Vector2(0, 118.0 * sc)
	var rv := 99.0
	match cur:
		"jump":
			var k := clampf(jump / 0.6, 0.0, 1.0)
			pos.y -= sin(k * PI) * 52.0 * sc
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
	hero.draw(ci, kind, pos, sc, outfit, t, rv)
	hero.eye_k = 1.0
	var head := pos + Vector2(0, -50.0 * sc)
	if cur == "fear" or (fear > 0.3 and cur == "joy"):
		_sweat(ci, head + Vector2(70.0, -42.0) * sc, sc, fear)
	if cur == "lose":
		var k2 := fmod(mood_t, 1.6) / 1.6
		_drop(ci, pos + Vector2(-40.0, -10.0 + k2 * 40.0) * sc, 7.0 * sc / 0.75, Color(DROP, 0.9 * (1.0 - k2)))
	if cur == "jump":
		_sparkles(ci, pos + Vector2(0, -10.0 * sc), sc, jump / JUMP_TIME, 6 + mini(jump_chain - 3, 3) * 2)
	elif cur == "win":
		_sparkles(ci, pos + Vector2(0, -10.0 * sc), sc, fmod(mood_t, 1.2) / 1.2, 8)


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
	var s := 9.0 * sc / 0.75
	_drop(ci, c + Vector2(0, slide * 16.0 * sc), s, Color(DROP, 0.95 * k * (1.0 - slide * 0.6)))
	# «нервные» чёрточки над головой
	var a := Color(1, 1, 1, 0.55 * k)
	for i in 3:
		var ang := -PI / 2.0 + (i - 1) * 0.42
		var p0 := c + Vector2(-58.0 * sc, -40.0 * sc) + Vector2(cos(ang), sin(ang)) * 16.0 * sc
		ci.draw_line(p0, p0 + Vector2(cos(ang), sin(ang)) * 12.0 * sc, a, maxf(2.0, 3.0 * sc), true)


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
