extends RefCounted
## 0.18: «праздник каскада» — эффекты поверх игры (правила игры не меняет):
##   звук звена цепочки — на ступень выше (combo1..combo5, дальше — тот же звук выше по pitch_scale);
##   ×3 и выше — короткое замедление времени, вспышка поля и крупная надпись «Супер!», ×4+ — «Мега!»;
##   освобождённые кристаллы летят к счётчику на панели, счётчик «подпрыгивает»;
##   последний кристалл уровня — вспышка, лёгкое приближение поля и конфетти;
##   лёгкая вибрация телефона на сброс фигуры и каскад (выключатель «Вибрация» в «Удобстве»).
## g — узел игры (scripts/game.gd). Время эффектов — настоящее (update(real_delta)).

const I18n := preload("res://scripts/i18n.gd")

const SLOW_TIME := 0.26     # замедление на ×3+ (секунд настоящего времени)
const SLOW_K := 0.3         # во сколько раз медленнее идёт игра в замедлении
const FLASH_TIME := 0.28
const BANNER_TIME := 1.1
const FLY_TIME := 0.6       # полёт кристалла к счётчику
const ZOOM_TIME := 0.7      # приближение на последнем кристалле
const ZOOM_K := 0.05
const STEP_SEMITONES := 2.0  # combo1..5 сделаны лестницей через тон (tools/make_sounds.py)
const VIBE_DROP := 20       # мс вибрации на сброс
const VIBE_CASCADE := 35    # мс на каскад (+10 мс за звено)

var g
var slow := 0.0             # осталось замедления, с
var flash := 0.0
var flash_col := Color.WHITE
var banner := ""
var banner_t := 99.0
var banner_col := Color("#FFB547")
var flyers: Array = []      # {"from", "to", "t", "delay"}
var bump := 0.0             # «подпрыгивание» счётчика кристаллов 0..1
var zoom := 0.0             # 0..1 приближение (последний кристалл)
var zoom_at := Vector2.ZERO
var vibes: Array = []       # мс каждой вибрации (для тестов)


func _init(game) -> void:
	g = game


func reset() -> void:
	slow = 0.0
	flash = 0.0
	banner = ""
	banner_t = 99.0
	flyers.clear()
	bump = 0.0
	zoom = 0.0


## Звук звена цепочки chain (>=2): [имя звука, pitch_scale]. Каждое звено — на ступень выше.
static func chain_sound(chain: int) -> Array:
	var k := maxi(1, chain - 1)
	if k <= 5:
		return ["combo%d" % k, 1.0]
	return ["combo5", pow(2.0, (k - 5) * STEP_SEMITONES / 12.0)]


## Надпись на цепочку: "" (до ×2), «Супер!» (×3), «Мега!» (×4 и больше).
static func banner_key(chain: int) -> String:
	if chain >= 4:
		return "juice_mega"
	if chain >= 3:
		return "juice_super"
	return ""


## Множитель времени игры (замедление на ×3+).
func time_k() -> float:
	return SLOW_K if slow > 0.0 else 1.0


func update(delta: float) -> void:
	slow = maxf(0.0, slow - delta)
	flash = maxf(0.0, flash - delta)
	banner_t += delta
	bump = maxf(0.0, bump - delta * 3.5)
	zoom = maxf(0.0, zoom - delta / ZOOM_TIME)
	for f in flyers:
		f.t += delta
		if f.t >= f.delay + FLY_TIME and not f.done:
			f.done = true
			bump = 1.0
			g.play("click", 1.6 + 0.1 * (f.n % 4), -10.0)
	flyers = flyers.filter(func(f): return not f.done)


## Вибрация телефона ms миллисекунд (если включена в «Удобстве»).
func vibrate(ms: int) -> void:
	if not g.access.vibrate:
		return
	vibes.append(ms)
	if vibes.size() > 20:
		vibes.pop_front()
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, 0.5)


func on_drop() -> void:
	vibrate(VIBE_DROP)


## Звено цепочки chain (вызывается из game.gd _check_lines).
func on_cascade(chain: int) -> void:
	if chain >= 2:
		vibrate(VIBE_CASCADE + 10 * mini(chain, 6))
	var key := banner_key(chain)
	if key == "":
		return
	slow = SLOW_TIME
	flash = FLASH_TIME
	flash_col = Color(1, 1, 1) if chain == 3 else Color("#FFE3A3")
	banner = I18n.t(key)
	banner_t = 0.0
	banner_col = Color("#FFB547") if chain == 3 else Color("#FF8FD8")


## 0.18: взрыв кристалла-бомбы (n — сколько бомб взорвалось цепочкой): огненная вспышка поля,
## короткое замедление, вибрация посильнее.
func on_boom(n: int) -> void:
	flash = maxf(flash, FLASH_TIME * 1.4)
	flash_col = Color("#FF9A3C")
	slow = maxf(slow, SLOW_TIME * 0.7)
	vibrate(50 + 15 * mini(n, 4))


## Освобождённый кристалл в точке from летит к счётчику на панели.
func fly(from: Vector2) -> void:
	flyers.append({"from": from, "to": counter_pos(), "t": 0.0, "delay": 0.06 * flyers.size(), "done": false, "n": flyers.size()})


## Кристаллов ещё в полёте (счётчик на панели прибавляет их по прилёту).
func in_flight() -> int:
	return flyers.size()


## Центр значка кристалла на панели (game.gd _draw_panel).
func counter_pos() -> Vector2:
	return Vector2(g.panel_x - 6 + 28, g.board_pos.y + 4.0 + 220.0 + 10.0 + 28.0)


## Последний кристалл уровня освобождён: вспышка, приближение, конфетти.
func on_last_crystal(at: Vector2) -> void:
	flash = maxf(flash, FLASH_TIME * 1.5)
	flash_col = Color("#9FF6FF")
	zoom = 1.0
	zoom_at = at
	vibrate(60)
	for i in 50:
		var a := randf() * TAU
		g.particles.append({"p": at, "v": Vector2(cos(a), sin(a) - 0.8) * randf_range(150, 560),
			"col": g.GEMS[i % g.GEMS.size()], "life": randf_range(0.9, 1.6), "max": 1.6, "rot": randf() * TAU, "s": randf_range(5, 10)})


## Масштаб поля (приближение на последнем кристалле): [масштаб, точка].
func board_zoom() -> Array:
	var k := sin(zoom * PI) * ZOOM_K
	return [1.0 + k, zoom_at]


## Нарисовать вспышку, летящие кристаллы и надпись (поверх поля, из game.gd _draw).
func draw() -> void:
	var bsize: Vector2 = Vector2(g.COLS, g.ROWS) * g.CELL
	if flash > 0.0:
		var a := flash / FLASH_TIME * 0.32
		g.draw_rect(Rect2(g.board_pos, bsize), Color(flash_col, minf(a, 0.45)))
	for f in flyers:
		var k := clampf((f.t - f.delay) / FLY_TIME, 0.0, 1.0)
		if f.t < f.delay:
			continue
		var e := k * k * (3.0 - 2.0 * k)
		var mid: Vector2 = (f.from + f.to) / 2.0 + Vector2(0, -160)
		var p: Vector2 = f.from.lerp(mid, e).lerp(mid.lerp(f.to, e), e)
		var s := 40.0 - 12.0 * e
		g.draw_circle(p, s * 0.55, Color(g.CRYSTAL_COL, 0.25))
		g._draw_block(p - Vector2(s, s) / 2.0, s, g.CRYSTAL)
	if banner != "" and banner_t < BANNER_TIME:
		var age := banner_t
		var sc := 0.5 + minf(age / 0.14, 1.0) * 0.7
		if age > 0.14:
			sc = 1.2 - minf((age - 0.14) / 0.12, 1.0) * 0.2
		var a := clampf((BANNER_TIME - age) / 0.3, 0.0, 1.0)
		var size := int(96 * sc)
		var w: float = g.board_pos.x * 2 + bsize.x
		var y: float = g.board_pos.y + bsize.y * 0.36
		for o in [Vector2(-5, 0), Vector2(5, 0), Vector2(0, -5), Vector2(0, 5), Vector2(4, 6)]:
			g.draw_string(g.font, Vector2(0, y) + o, banner, HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(0.07, 0.04, 0.14, a))
		g.draw_string(g.font, Vector2(0, y), banner, HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(banner_col, a))
		g.draw_string(g.font, Vector2(0, y - size * 0.06), banner, HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(1, 1, 1, 0.25 * a))
