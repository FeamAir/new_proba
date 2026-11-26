extends RefCounted
## 0.17: «Удобство» (настройки доступности) — только данные и простые правила, рисование знаков.
##  - symbols: знаки на блоках (для дальтоников) — у каждого цвета самоцвета свой знак;
##    кристалл (ромб на тёмном) и камень (без блика) и так отличаются формой;
##  - lefty: «для левшей» — зеркальная раскладка кнопок (поворот и сброс слева, стрелки справа);
##  - slow: «медленное падение» — скорость падения ×0.7 (интервал ÷0.7); звёзды и награды
##    не меняются, в скрытой статистике отмечается победа с медленным падением;
##  - big: «крупный текст» — шрифты интерфейса уровня и паузы ×1.2 (где помещается).
## Хранится в user://save.cfg, раздел [settings] (access_*); в старом сохранении — всё выключено.
## Меню пункта — scripts/access_ui.gd.

const KEYS := ["symbols", "lefty", "slow", "big"]
const SLOW_K := 0.7     # во сколько раз медленнее падение (скорость ×0.7)
const TEXT_K := 1.2     # «крупный текст»
## Знаки по номеру цвета самоцвета (game.gd GEMS): круг, треугольник, ромб, крест, звезда, полоска, точка
const SIGNS := ["circle", "triangle", "diamond", "cross", "star", "bar", "dot"]

var symbols := false
var lefty := false
var slow := false
var big := false


func get_opt(k: String) -> bool:
	return bool(get(k)) if KEYS.has(k) else false


func toggle(k: String) -> bool:
	if not KEYS.has(k):
		return false
	set(k, not get_opt(k))
	return get_opt(k)


## Множитель шрифта интерфейса уровня/паузы.
func fs(size: float) -> int:
	return int(round(size * (TEXT_K if big else 1.0)))


## Интервал падения с учётом «медленного падения».
func fall(interval: float) -> float:
	return interval / SLOW_K if slow else interval


func save_to(cfg: ConfigFile) -> void:
	for k in KEYS:
		cfg.set_value("settings", "access_" + k, get_opt(k))


func load_from(cfg: ConfigFile) -> void:
	for k in KEYS:
		var v = cfg.get_value("settings", "access_" + k, false)
		set(k, v if v is bool else false)


## Знак цвета v (0..6) в клетке с центром c и размером s; рисует на ci.
static func draw_sign(ci: CanvasItem, c: Vector2, s: float, v: int) -> void:
	if v < 0 or v >= SIGNS.size():
		return
	var r := s * 0.2
	var col := Color(0.08, 0.04, 0.16, 0.62)
	var lw := maxf(2.0, s * 0.075)
	match SIGNS[v]:
		"circle":
			ci.draw_arc(c, r, 0, TAU, 24, col, lw, true)
		"triangle":
			var t := PackedVector2Array([c + Vector2(0, -r * 1.1), c + Vector2(r, r * 0.75), c + Vector2(-r, r * 0.75), c + Vector2(0, -r * 1.1)])
			ci.draw_polyline(t, col, lw, true)
		"diamond":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.15), c + Vector2(r * 0.8, 0), c + Vector2(0, r * 1.15), c + Vector2(-r * 0.8, 0)]), col)
		"cross":
			ci.draw_line(c + Vector2(-r, -r) * 0.85, c + Vector2(r, r) * 0.85, col, lw * 1.2, true)
			ci.draw_line(c + Vector2(r, -r) * 0.85, c + Vector2(-r, r) * 0.85, col, lw * 1.2, true)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (r * 1.2 if i % 2 == 0 else r * 0.5))
			ci.draw_colored_polygon(pts, col)
		"bar":
			ci.draw_rect(Rect2(c - Vector2(r * 1.1, lw * 0.75), Vector2(r * 2.2, lw * 1.5)), col)
		"dot":
			ci.draw_circle(c, r * 0.55, col, true, -1.0, true)
