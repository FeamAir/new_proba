extends RefCounted
## 0.18: облачко с короткой фразой у героя рядом с полем (scripts/play_hero.gd).
## События: "cascade" (цепочка ×2 и больше), "crystal" (освобождён кристалл), "win" (победа).
## Фразы свои у каждого героя: ключи i18n say_<герой>_<событие>_<n>; у героини-девочки,
## где по-русски видно род, — ключ с окончанием _girl (say_owl_win_0_girl).
## Облачко не чаще раза в COOLDOWN секунд (победа — всегда) и рисуется только над панелью,
## поле оно не закрывает.

const I18n := preload("res://scripts/i18n.gd")

const HEROES := ["owl", "axolotl", "puppy", "kitten"]
const EVENTS := ["cascade", "crystal", "win"]
const COUNT := 3            # фраз на событие
const COOLDOWN := 3.0
const SHOW_TIME := 1.7

var text := ""
var t := 99.0               # секунд с появления облачка
var since := 99.0           # секунд с прошлого облачка
var last := {}              # событие -> номер прошлой фразы (не повторять подряд)


func reset() -> void:
	text = ""
	t = 99.0
	since = 99.0


func update(delta: float) -> void:
	t += delta
	since += delta


func visible() -> bool:
	return text != "" and t < SHOW_TIME


## Фраза героя kind (пол gender: "girl" / "boy") на событие ev, номер n.
static func phrase(kind: String, gender: String, ev: String, n: int) -> String:
	var key := "say_%s_%s_%d" % [kind, ev, n]
	if gender == "girl" and I18n.has(key + "_girl"):
		return I18n.t(key + "_girl")
	return I18n.t(key)


## Событие игры: показать фразу (если прошло COOLDOWN). true — облачко показано.
func on_event(kind: String, gender: String, ev: String) -> bool:
	if not HEROES.has(kind):
		kind = "owl"
	if ev != "win" and since < COOLDOWN:
		return false
	var n := randi() % COUNT
	if last.get(ev, -1) == n:
		n = (n + 1) % COUNT
	last[ev] = n
	text = phrase(kind, gender, ev, n)
	t = 0.0
	since = 0.0
	return true


## Облачко над героем: hero — место героя на панели, x_min — левая граница (край поля не заходит).
func draw(g, hero: Rect2, x_min: float) -> void:
	if not visible():
		return
	var a := clampf(t / 0.12, 0.0, 1.0) * clampf((SHOW_TIME - t) / 0.25, 0.0, 1.0)
	var pop := 0.85 + 0.15 * clampf(t / 0.12, 0.0, 1.0)
	var max_w: float = g.W - x_min - 8.0
	var size := 26
	while size > 16 and g.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w - 24.0:
		size -= 1
	var tw: float = g.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var w := minf(max_w, tw + 28.0) * pop
	var h := (size + 24.0) * pop
	var cx := clampf(hero.get_center().x, x_min + w / 2.0, g.W - 8.0 - w / 2.0)
	var r := Rect2(cx - w / 2.0, hero.position.y + 2.0, w, h)
	var col := Color(1, 1, 1, 0.96 * a)
	g._rbox(Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.25 * a), 18)
	g._rbox(r, col, 18)
	var tip := Vector2(cx + 10.0, r.end.y)
	g.draw_colored_polygon(PackedVector2Array([tip + Vector2(-12, -1), tip + Vector2(8, -1), tip + Vector2(-4, 16)]), col)
	g.draw_string(g.font, Vector2(r.position.x, r.position.y + h / 2.0 + size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(size * pop), Color(0.16, 0.09, 0.3, a))
