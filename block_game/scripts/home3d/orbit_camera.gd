extends Camera3D
## Камера 3D-дома (Cascado 0.12): орбита вокруг центра комнаты (у сада щенка — вокруг будки).
##   один палец — поворот на 360° и ограниченный наклон; после отпускания — инерция;
##   два пальца (щипок) — ближе / дальше; одиночный тап — сигнал tapped, двойной — double_tapped.
## Касания передаёт экран «Дом» (scripts/home3d/home3d.gd): кнопки интерфейса камеру не крутят.
## Координаты касаний — в пикселях картинки 3D (SubViewport).
## 0.18: «держать предмет» (hold_focus — камера у полки кубков): палец не уводит камеру к обзору —
##   немного повернуться (до PAN_LIMIT от вида на предмет) можно, быстрый свайп по горизонтали — сигнал swiped
##   (соседний кубок), конец щипка — сигнал pinched (во сколько раз изменилось расстояние).

signal tapped(pos: Vector2)
signal double_tapped(pos: Vector2)
signal swiped(dir: int)
signal pinched(ratio: float)

## Центр обзора и расстояние «по умолчанию»
var home_pivot := Vector3(0, 0.95, 0)
var home_dist := 2.45
var home_pitch := 0.27
## Внутри ли точка (стены, потолок, земля): задаёт комната; камера «укорачивает палку» до стены
var inside: Callable

var yaw := 0.0
var pitch := 0.27
var dist := 2.45
var pivot := Vector3(0, 0.95, 0)

## Цели для плавного полёта (разворот к предмету)
var goal_pivot := Vector3(0, 0.95, 0)
var goal_dist := 2.45
var goal_yaw = null
var goal_pitch = null

## Ограничение поворота по кругу (радианы от вида спереди, 0 — без ограничения).
## У сада щенка герой сидит в будке: со спины будки его не видно, поэтому поворот ограничен.
var yaw_limit := 0.0

var pitch_min := 0.02
## Выше не даём: «картонка» героя сверху выглядит плоской
var pitch_max := 0.62
var dist_min := 0.9
var dist_max := 2.6
const TURN := 0.0085  # радиан на пиксель (на картинке шириной 720)
const TILT := 0.0055
const TAP_MOVE := 18.0
const TAP_TIME := 0.35
const DOUBLE_TIME := 0.4

## Пиксели картинки на пиксель экрана 720 (картинка бывает уменьшена — простое качество)
var px_scale := 1.0
var focused := false
## 0.18: камера «держит» предмет (полка кубков): касания не возвращают к обзору
var hold_focus := false
## Поворот вида на предмет (после fly_to); вокруг него — небольшая панорама пальцем
var focus_yaw := 0.0
const PAN_LIMIT := 0.38
const PAN_TURN := 0.55       # панорама у предмета — медленнее обычного поворота
const SWIPE_MIN := 70.0      # пикселей экрана 720 по горизонтали
const SWIPE_TIME := 0.6
## Медленный «облёт» в покое (заставка, гардероб)
var idle_sway := 0.0

var _touches := {}
var _vel_yaw := 0.0
var _vel_pitch := 0.0
var _press_time := 0.0
var _press_pos := Vector2.ZERO
var _moved := 0.0
var _last_tap_time := -10.0
var _last_tap_pos := Vector2.ZERO
var _pinch_d := 0.0
var _pinch_from := 0.0       # 0.18: goal_dist в начале щипка (0 — щипка не было)
var _clock := 0.0
var _sway_t := 0.0


func _ready() -> void:
	reset_view()


func reset_view() -> void:
	pivot = home_pivot
	goal_pivot = home_pivot
	dist = home_dist
	goal_dist = home_dist
	pitch = home_pitch
	goal_yaw = null
	goal_pitch = null
	focused = false
	_vel_yaw = 0.0
	_vel_pitch = 0.0
	_apply()


## Влёт при входе в дом: камера издалека и сбоку плавно встаёт на место
func intro(from_side := 0.9) -> void:
	var target := yaw
	yaw = target + from_side
	dist = minf(dist_max * 1.25, home_dist * 1.6)
	pitch = minf(pitch_max, home_pitch + 0.22)
	goal_yaw = target
	goal_pitch = home_pitch
	goal_dist = home_dist
	goal_pivot = home_pivot
	focused = false
	_apply()


func is_touching() -> bool:
	return not _touches.is_empty()


func release_all() -> void:
	_touches.clear()


func touch(idx: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		_touches[idx] = pos
		if _touches.size() == 1:
			_press_time = _clock
			_press_pos = pos
			_moved = 0.0
			_vel_yaw = 0.0
			_vel_pitch = 0.0
			_pinch_from = 0.0
		elif _touches.size() == 2:
			_pinch_d = _pinch_dist()
			_moved = 999.0  # два пальца — уже не тап
			if _pinch_from <= 0.0:
				_pinch_from = goal_dist
	else:
		if not _touches.has(idx):
			return
		_touches.erase(idx)
		if hold_focus and _touches.is_empty():
			# 0.18: у предмета: конец щипка — pinched; быстрый свайп одним пальцем — swiped (не тап)
			if _pinch_from > 0.0:
				var ratio := goal_dist / _pinch_from
				_pinch_from = 0.0
				pinched.emit(ratio)
				return
			var sw := swipe_dir(pos - _press_pos, _clock - _press_time)
			if sw != 0:
				swiped.emit(sw)
				return
		if _touches.is_empty() and _moved < TAP_MOVE * px_scale and _clock - _press_time < TAP_TIME:
			if _clock - _last_tap_time < DOUBLE_TIME and pos.distance_to(_last_tap_pos) < 80.0 * px_scale:
				_last_tap_time = -10.0
				double_tapped.emit(pos)
			else:
				_last_tap_time = _clock
				_last_tap_pos = pos
				tapped.emit(pos)


func drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	if not _touches.has(idx):
		return
	_touches[idx] = pos
	_moved += rel.length()
	if _touches.size() == 1:
		if _moved < 10.0 * px_scale:
			return
		if hold_focus:
			_pan(rel)
			return
		_user_turned()
		var dy: float = -rel.x / px_scale * TURN
		var dp: float = rel.y / px_scale * TILT
		yaw += dy
		pitch = clampf(pitch + dp, pitch_min, pitch_max)
		var dt := maxf(get_process_delta_time(), 1.0 / 120.0)
		_vel_yaw = lerpf(_vel_yaw, dy / dt, 0.5)
		_vel_pitch = lerpf(_vel_pitch, dp / dt, 0.5)
	elif _touches.size() == 2:
		var d := _pinch_dist()
		if _pinch_d > 1.0 and d > 1.0:
			zoom(_pinch_d / d)
		_pinch_d = d


## 0.18: свайп по картинке (d — смещение пальца в пикселях картинки, dt — за сколько секунд):
## +1 — палец влево (следующий), -1 — вправо (предыдущий), 0 — не свайп
func swipe_dir(d: Vector2, dt: float) -> int:
	var dx := d.x / maxf(0.01, px_scale)
	if dt > SWIPE_TIME or absf(dx) < SWIPE_MIN or absf(d.x) < absf(d.y) * 1.3:
		return 0
	return 1 if dx < 0.0 else -1


## 0.18: у предмета: небольшой поворот вокруг него, без инерции и без выхода к обзору
func _pan(rel: Vector2) -> void:
	_vel_yaw = 0.0
	_vel_pitch = 0.0
	var a0 := angle_difference(focus_yaw, yaw)
	if absf(a0) > PAN_LIMIT:
		return  # камера ещё разворачивается к предмету — не мешаем полёту
	goal_yaw = null
	goal_pitch = null
	yaw = focus_yaw + clampf(a0 - rel.x / px_scale * TURN * PAN_TURN, -PAN_LIMIT, PAN_LIMIT)
	pitch = clampf(pitch + rel.y / px_scale * TILT * PAN_TURN, pitch_min, pitch_max)


func _pinch_dist() -> float:
	var ps: Array = _touches.values()
	if ps.size() < 2:
		return 0.0
	return (ps[0] as Vector2).distance_to(ps[1])


func zoom(f: float) -> void:
	goal_dist = clampf(goal_dist * f, dist_min, dist_max)


## Пользователь сам крутит камеру: отменяем полёт; если камера была у предмета — плавно назад к обзору
func _user_turned() -> void:
	goal_yaw = null
	goal_pitch = null
	if focused:
		focused = false
		goal_pivot = home_pivot
		goal_dist = home_dist


## Плавно развернуться к точке at: камера встаёт со стороны from_dir
func fly_to(at: Vector3, from_dir: Vector3, d: float, p := 0.22) -> void:
	focused = true
	goal_pivot = at
	goal_dist = d
	from_dir.y = 0.0
	if from_dir.length() < 0.01:
		from_dir = Vector3(sin(yaw), 0, cos(yaw))
	from_dir = from_dir.normalized()
	goal_yaw = atan2(from_dir.x, from_dir.z)
	focus_yaw = goal_yaw
	goal_pitch = p
	_vel_yaw = 0.0
	_vel_pitch = 0.0


func fly_home() -> void:
	focused = false
	goal_pivot = home_pivot
	goal_dist = home_dist
	goal_pitch = home_pitch
	goal_yaw = null


func _process(delta: float) -> void:
	_clock += delta
	var k := 1.0 - exp(-5.0 * delta)
	if _touches.is_empty():
		yaw += _vel_yaw * delta
		if absf(_vel_pitch) > 0.0001:
			pitch = clampf(pitch + _vel_pitch * delta, pitch_min, pitch_max)
		_vel_yaw *= exp(-3.2 * delta)
		_vel_pitch *= exp(-6.0 * delta)
	if goal_yaw != null:
		yaw = lerp_angle(yaw, goal_yaw, k)
		if absf(angle_difference(yaw, goal_yaw)) < 0.002:
			goal_yaw = null
	if yaw_limit > 0.0 and not focused:  # подлёт к вещи за будкой разрешён
		var a := wrapf(yaw, -PI, PI)
		if absf(a) > yaw_limit:
			_vel_yaw = 0.0
			# мягкий упор: плавно возвращаемся к границе (без рывка после подлёта к вещи за будкой)
			var edge := signf(a) * yaw_limit
			yaw = lerp_angle(a, edge, minf(1.0, k * 3.0))
		else:
			yaw = a
	if goal_pitch != null:
		pitch = lerpf(pitch, goal_pitch, k)
		if absf(pitch - goal_pitch) < 0.002:
			goal_pitch = null
	pivot = pivot.lerp(goal_pivot, k)
	dist = lerpf(dist, goal_dist, k)
	_sway_t += delta
	_apply()


func _apply() -> void:
	var y := yaw + idle_sway * sin(_sway_t * 0.35)
	var off := Vector3(sin(y) * cos(pitch), sin(pitch), cos(y) * cos(pitch))
	var d := dist
	var pos := pivot + off * d
	if inside.is_valid() and not inside.call(pos):
		# мешает потолок / ветка: сначала пробуем опустить камеру (тот же поворот, ниже наклон)
		var p2 := pitch
		var found := false
		while p2 > pitch_min - 0.001:
			p2 -= 0.03
			var o2 := Vector3(sin(y) * cos(p2), sin(p2), cos(y) * cos(p2))
			if inside.call(pivot + o2 * d):
				off = o2
				pos = pivot + o2 * d
				found = true
				break
		# не помогло (стена) — укорачиваем «палку» до стены
		var guard := 0
		while not found and not inside.call(pos) and d > 0.35 and guard < 80:
			d -= 0.04
			pos = pivot + off * d
			guard += 1
	if not is_inside_tree():
		return
	global_position = pos
	look_at(pivot, Vector3.UP)
