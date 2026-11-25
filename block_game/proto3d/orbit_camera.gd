extends Camera3D
## ПРОТОТИП 3D-дома. Камера-орбита вокруг центра комнаты.
##   один палец / мышь — поворот на 360° по горизонтали и ограниченный наклон;
##   два пальца (щипок) / колесо мыши — приближение; после отпускания — инерция;
##   одиночный тап — сигнал tapped, двойной тап — сигнал double_tapped (комната решает, к чему лететь).

signal tapped(pos: Vector2)
signal double_tapped(pos: Vector2)

## Центр обзора и радиус, за который камера не выходит (стены комнаты)
var home_pivot := Vector3(0, 0.95, 0)
var home_dist := 2.45
var wall_radius := 2.7
var ceiling := 3.9

var yaw := 0.0
var pitch := 0.27
var dist := 2.45
var pivot := Vector3(0, 0.95, 0)

## Цели для плавного полёта (разворот к предмету)
var goal_pivot := Vector3(0, 0.95, 0)
var goal_dist := 2.45
var goal_yaw = null
var goal_pitch = null

const PITCH_MIN := 0.02
## Выше не даём: «картонка» героя сверху выглядит плоской
const PITCH_MAX := 0.62
const DIST_MIN := 0.9
const DIST_MAX := 2.6
const TURN := 0.0085  # радиан на пиксель
const TILT := 0.0055

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
var focused := false


func _ready() -> void:
	pivot = home_pivot
	goal_pivot = home_pivot
	dist = home_dist
	goal_dist = home_dist
	_apply()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
			if _touches.size() == 1:
				_press_time = _clock
				_press_pos = e.position
				_moved = 0.0
				_vel_yaw = 0.0
				_vel_pitch = 0.0
			elif _touches.size() == 2:
				_pinch_d = _pinch_dist()
		else:
			_touches.erase(e.index)
			if _touches.is_empty() and _moved < 18.0 and _clock - _press_time < 0.35:
				if _clock - _last_tap_time < 0.4 and e.position.distance_to(_last_tap_pos) < 80.0:
					_last_tap_time = -10.0
					double_tapped.emit(e.position)
				else:
					_last_tap_time = _clock
					_last_tap_pos = e.position
					tapped.emit(e.position)
	elif e is InputEventScreenDrag:
		_touches[e.index] = e.position
		_moved += e.relative.length()
		if _touches.size() == 1:
			if _moved < 10.0:
				return
			_user_turned()
			var dy: float = -e.relative.x * TURN
			var dp: float = e.relative.y * TILT
			yaw += dy
			pitch = clampf(pitch + dp, PITCH_MIN, PITCH_MAX)
			# скорость для инерции (сглаженная)
			var dt := maxf(get_process_delta_time(), 1.0 / 120.0)
			_vel_yaw = lerpf(_vel_yaw, dy / dt, 0.5)
			_vel_pitch = lerpf(_vel_pitch, dp / dt, 0.5)
		elif _touches.size() == 2:
			var d := _pinch_dist()
			if _pinch_d > 1.0 and d > 1.0:
				_zoom(_pinch_d / d)
			_pinch_d = d
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.1)
	elif e is InputEventMagnifyGesture:
		_zoom(1.0 / e.factor)


func _pinch_dist() -> float:
	var ps: Array = _touches.values()
	if ps.size() < 2:
		return 0.0
	return (ps[0] as Vector2).distance_to(ps[1])


func _zoom(f: float) -> void:
	goal_dist = clampf(goal_dist * f, DIST_MIN, DIST_MAX)


## Пользователь сам крутит камеру: отменяем полёт; если камера была у предмета — плавно возвращаемся к обзору
func _user_turned() -> void:
	goal_yaw = null
	goal_pitch = null
	if focused:
		focused = false
		goal_pivot = home_pivot
		goal_dist = home_dist


## Плавно развернуться к точке at: камера встаёт со стороны from_dir (обычно — от центра комнаты)
func fly_to(at: Vector3, from_dir: Vector3, d: float, p := 0.22) -> void:
	focused = true
	goal_pivot = at
	goal_dist = d
	from_dir.y = 0.0
	from_dir = from_dir.normalized()
	goal_yaw = atan2(from_dir.x, from_dir.z)
	goal_pitch = p
	_vel_yaw = 0.0
	_vel_pitch = 0.0


func fly_home() -> void:
	focused = false
	goal_pivot = home_pivot
	goal_dist = home_dist
	goal_pitch = 0.27
	goal_yaw = null


func _process(delta: float) -> void:
	_clock += delta
	var k := 1.0 - exp(-5.0 * delta)
	if _touches.is_empty():
		# инерция после отпускания пальца
		yaw += _vel_yaw * delta
		pitch = clampf(pitch + _vel_pitch * delta, PITCH_MIN, PITCH_MAX)
		var damp := exp(-3.2 * delta)
		_vel_yaw *= damp
		_vel_pitch *= exp(-6.0 * delta)
	if goal_yaw != null:
		yaw = lerp_angle(yaw, goal_yaw, k)
		if absf(angle_difference(yaw, goal_yaw)) < 0.002:
			goal_yaw = null
	if goal_pitch != null:
		pitch = lerpf(pitch, goal_pitch, k)
		if absf(pitch - goal_pitch) < 0.002:
			goal_pitch = null
	pivot = pivot.lerp(goal_pivot, k)
	dist = lerpf(dist, goal_dist, k)
	_apply()


func _apply() -> void:
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	# камера не проходит сквозь стены и потолок: укорачиваем «палку» до стены
	var d := dist
	var pos := pivot + off * d
	var guard := 0
	while (Vector2(pos.x, pos.z).length() > wall_radius or pos.y > ceiling) and d > 0.35 and guard < 60:
		d -= 0.04
		pos = pivot + off * d
		guard += 1
	global_position = pos
	look_at(pivot, Vector3.UP)
