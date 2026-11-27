extends Camera3D
## Камера 3D-дома (Cascado 0.12): орбита вокруг центра комнаты (у сада щенка — вокруг будки).
##   один палец — поворот на 360° и ограниченный наклон; после отпускания — инерция;
##   два пальца (щипок) — ближе / дальше; одиночный тап — сигнал tapped, двойной — double_tapped.
## Касания передаёт экран «Дом» (scripts/home3d/home3d.gd): кнопки интерфейса камеру не крутят.
## Координаты касаний — в пикселях картинки 3D (SubViewport).
## 0.18: «обзор от первого лица» (look_mode — у полки кубков): камера стоит на месте перед полкой и
##   поворачивается вокруг себя, как голова: палец влево / вправо — взгляд до ±LOOK_YAW_MAX, вверх / вниз —
##   немного (±LOOK_PITCH_MAX); лёгкая инерция и мягкий упор на границах; щипок — шаг ближе / дальше
##   (в пределах комнаты). Тапы — как обычно (сигналы tapped / double_tapped).

signal tapped(pos: Vector2)
signal double_tapped(pos: Vector2)

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

## 0.18: обзор от первого лица. Камера — в точке look_anchor + look_back * look_d (+ look_eye по высоте),
## «прямо» — взгляд на look_anchor. look_yaw (+ — влево) и look_pitch (+ — вверх) — поворот «головы» от «прямо».
var look_mode := false
var look_anchor := Vector3.ZERO
var look_back := Vector3(0, 0, 1)
var look_eye := 0.0
var look_d := 1.25
var look_goal_d := 1.25
var look_d_min := 0.75
var look_d_max := 1.8
var look_yaw := 0.0
var look_pitch := 0.0
var look_goal_yaw = null
var look_goal_pitch = null
## Игрок уже поворачивал голову (подсказку можно спрятать)
var look_used := false
const LOOK_YAW_MAX := 1.31      # ~75°: крайние кубки видны с запасом, дальше — стены по бокам
const LOOK_PITCH_MAX := 0.38    # ~22°
const LOOK_OVER := 0.14         # насколько можно «пережать» упор пальцем (потом мягко возвращается)
const LOOK_TURN := 0.0042       # радиан на пиксель экрана 720 (весь экран — ~170°)
const LOOK_TILT := 0.0032
## Плавный переход в обзор: откуда (поза камеры при входе) и сколько пройдено (1 — на месте)
var _look_from := Transform3D()
var _look_blend := 1.0
var _look_vy := 0.0
var _look_vp := 0.0
var _look_acc := Vector2.ZERO   # поворот пальцем за текущий кадр
const LOOK_SPIN_MAX := 3.0      # предел скорости инерции, рад/с
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
	look_mode = false
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
	look_mode = false
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
			_look_vy = 0.0
			_look_vp = 0.0
		elif _touches.size() == 2:
			_pinch_d = _pinch_dist()
			_moved = 999.0  # два пальца — уже не тап
	else:
		if not _touches.has(idx):
			return
		_touches.erase(idx)
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
		if look_mode:
			_look_turn(rel)
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


## 0.18: обзор: палец ведёт «голову» (влево — взгляд влево, вверх — вверх); за упором — с сопротивлением
func _look_turn(rel: Vector2) -> void:
	look_goal_yaw = null
	look_goal_pitch = null
	look_used = true
	var dy: float = -rel.x / px_scale * LOOK_TURN
	var dp: float = -rel.y / px_scale * LOOK_TILT
	var ny := _soft(look_yaw, dy, LOOK_YAW_MAX)
	var np := _soft(look_pitch, dp, LOOK_PITCH_MAX)
	# скорость для инерции считается раз в кадр (_look_process): касаний за кадр бывает несколько
	_look_acc += Vector2(ny - look_yaw, np - look_pitch)
	look_yaw = ny
	look_pitch = np


## Шаг d от значения v при упоре ±lim: за упором — втрое туже, дальше LOOK_OVER — нельзя
static func _soft(v: float, d: float, lim: float) -> float:
	var n := v + d
	if absf(n) > lim and signf(d) == signf(n):
		n = v + d * 0.3
	return clampf(n, -lim - LOOK_OVER, lim + LOOK_OVER)


func _pinch_dist() -> float:
	var ps: Array = _touches.values()
	if ps.size() < 2:
		return 0.0
	return (ps[0] as Vector2).distance_to(ps[1])


func zoom(f: float) -> void:
	if look_mode:
		look_goal_d = clampf(look_goal_d * f, look_d_min, look_d_max)
		return
	goal_dist = clampf(goal_dist * f, dist_min, dist_max)


# ---------- 0.18: обзор от первого лица (полка кубков) ----------

## Встать перед точкой anchor (на расстоянии d по горизонтали back) и смотреть на неё; камера переходит плавно.
## d_min / d_max — пределы щипка (уже проверены комнатой: внутри стен). eye — подъём глаз над anchor.
func look_enter(anchor: Vector3, back: Vector3, d: float, d_min: float, d_max: float, eye := 0.0) -> void:
	back.y = 0.0
	if back.length() < 0.01:
		back = Vector3(0, 0, 1)
	var was := look_mode
	look_anchor = anchor
	look_back = back.normalized()
	look_eye = eye
	look_d_min = minf(d_min, d)
	look_d_max = maxf(d_max, d)
	look_goal_d = d
	focused = true
	_look_vy = 0.0
	_look_vp = 0.0
	_vel_yaw = 0.0
	_vel_pitch = 0.0
	goal_yaw = null
	goal_pitch = null
	if was:
		look_center()
		return
	_look_from = global_transform if is_inside_tree() else Transform3D(Basis(), anchor + look_back * d)
	look_mode = true
	look_d = d
	look_yaw = 0.0
	look_pitch = 0.0
	look_goal_yaw = null
	look_goal_pitch = null
	look_used = false
	_look_blend = 0.0


## Плавно повернуть взгляд прямо (на середину полки)
func look_center() -> void:
	look_goal_yaw = 0.0
	look_goal_pitch = 0.0
	_look_vy = 0.0
	_look_vp = 0.0


## Плавно повернуть голову к точке p (без перелёта; за упор — не дальше упора)
func look_toward(p: Vector3) -> void:
	var a := look_angles(p)
	look_goal_yaw = clampf(a.x, -LOOK_YAW_MAX, LOOK_YAW_MAX)
	look_goal_pitch = clampf(a.y, -LOOK_PITCH_MAX, LOOK_PITCH_MAX)
	_look_vy = 0.0
	_look_vp = 0.0


## Углы (yaw — влево +, pitch — вверх +) взгляда на точку p из точки обзора (после щипка — из конечной)
func look_angles(p: Vector3) -> Vector2:
	var v := p - (look_anchor + look_back * look_goal_d + Vector3(0, look_eye, 0))
	var fwd := -look_back
	var left := Vector3.UP.cross(fwd)
	var h := Vector2(v.dot(fwd), v.dot(left))
	return Vector2(atan2(h.y, h.x), atan2(v.y, h.length()))


## Где стоит камера в обзоре (сейчас)
func look_pos() -> Vector3:
	return look_anchor + look_back * look_d + Vector3(0, look_eye, 0)


## Куда смотрит камера в обзоре
func look_basis() -> Basis:
	var base := atan2(look_back.x, look_back.z)
	return Basis(Vector3.UP, base + look_yaw) * Basis(Vector3.RIGHT, look_pitch)


## Выйти из обзора к обычной орбите — без рывка: орбита начинается ровно с текущего положения камеры
func _leave_look() -> void:
	if not look_mode:
		return
	look_mode = false
	var tr := global_transform if is_inside_tree() else Transform3D(look_basis(), look_pos())
	var fwd := -tr.basis.z
	var d := clampf(look_d, dist_min, dist_max)
	pivot = tr.origin + fwd * d
	dist = d
	var off := -fwd
	yaw = atan2(off.x, off.z)
	pitch = asin(clampf(off.y, -1.0, 1.0))


func _look_process(delta: float) -> void:
	var k := 1.0 - exp(-5.0 * delta)
	if not _touches.is_empty() and delta > 0.0:
		var v := _look_acc / delta
		_look_vy = clampf(lerpf(_look_vy, v.x, 0.5), -LOOK_SPIN_MAX, LOOK_SPIN_MAX)
		_look_vp = clampf(lerpf(_look_vp, v.y, 0.5), -LOOK_SPIN_MAX, LOOK_SPIN_MAX)
	_look_acc = Vector2.ZERO
	if _touches.is_empty():
		look_yaw += _look_vy * delta
		look_pitch += _look_vp * delta
		_look_vy *= exp(-8.0 * delta)
		_look_vp *= exp(-10.0 * delta)
		# мягкий упор: за границей — плавно назад к ней
		if absf(look_yaw) > LOOK_YAW_MAX:
			_look_vy = 0.0
			look_yaw = lerpf(look_yaw, signf(look_yaw) * LOOK_YAW_MAX, minf(1.0, k * 2.0))
		if absf(look_pitch) > LOOK_PITCH_MAX:
			_look_vp = 0.0
			look_pitch = lerpf(look_pitch, signf(look_pitch) * LOOK_PITCH_MAX, minf(1.0, k * 2.0))
		look_yaw = clampf(look_yaw, -LOOK_YAW_MAX - LOOK_OVER, LOOK_YAW_MAX + LOOK_OVER)
		look_pitch = clampf(look_pitch, -LOOK_PITCH_MAX - LOOK_OVER, LOOK_PITCH_MAX + LOOK_OVER)
	if look_goal_yaw != null:
		look_yaw = lerpf(look_yaw, look_goal_yaw, k)
		if absf(look_yaw - look_goal_yaw) < 0.002:
			look_goal_yaw = null
	if look_goal_pitch != null:
		look_pitch = lerpf(look_pitch, look_goal_pitch, k)
		if absf(look_pitch - look_goal_pitch) < 0.002:
			look_goal_pitch = null
	look_d = lerpf(look_d, look_goal_d, k)
	if _look_blend < 1.0:
		_look_blend = minf(1.0, _look_blend + delta / 0.9)
	_apply_look()


func _apply_look() -> void:
	if not is_inside_tree():
		return
	var tr := Transform3D(look_basis(), look_pos())
	if _look_blend < 1.0:
		var e := _look_blend * _look_blend * (3.0 - 2.0 * _look_blend)
		var q := _look_from.basis.get_rotation_quaternion().slerp(tr.basis.get_rotation_quaternion(), e)
		tr = Transform3D(Basis(q), _look_from.origin.lerp(tr.origin, e))
	global_transform = tr


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
	_leave_look()
	focused = true
	goal_pivot = at
	goal_dist = d
	from_dir.y = 0.0
	if from_dir.length() < 0.01:
		from_dir = Vector3(sin(yaw), 0, cos(yaw))
	from_dir = from_dir.normalized()
	goal_yaw = atan2(from_dir.x, from_dir.z)
	goal_pitch = p
	_vel_yaw = 0.0
	_vel_pitch = 0.0


func fly_home() -> void:
	_leave_look()
	focused = false
	goal_pivot = home_pivot
	goal_dist = home_dist
	goal_pitch = home_pitch
	goal_yaw = null


func _process(delta: float) -> void:
	_clock += delta
	_sway_t += delta
	if look_mode:
		_look_process(delta)
		return
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
	_apply()


func _apply() -> void:
	if look_mode:
		_apply_look()
		return
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
