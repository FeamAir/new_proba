extends RefCounted
## Ссылка «Конфиденциальность» в меню паузы (требование Google Play: политика доступна в приложении).
## Неброская строка под номером версии; касание открывает страницу политики в браузере.
## Адрес политики — только здесь (Privacy.URL).

const I18n := preload("res://scripts/i18n.gd")

const URL := "https://feamair.github.io/cascado-privacy/"

var g
var opened := 0  # сколько раз открывали (для теста)


func _init(game) -> void:
	g = game


## Место ссылки: под номером версии (scripts/assist_ui.gd version_rect).
func rect() -> Rect2:
	var vr: Rect2 = g.assist_ui.version_rect()
	return Rect2(g.W / 2.0 - 180, vr.end.y + 4.0, 360, 56)


func draw() -> void:
	var r := rect()
	var text := I18n.t("privacy_link")
	var col := Color(g.DIM, 0.85)
	var fsz := 24
	var y := r.position.y + 34
	g.draw_string(g.font, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fsz, col)
	var tw: float = g.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	var cx := r.get_center().x
	g.draw_line(Vector2(cx - tw / 2.0, y + 6), Vector2(cx + tw / 2.0, y + 6), Color(col, 0.6), 1.5)


## Касание в паузе. true — попали по ссылке (страница открывается в браузере).
func tap(pos: Vector2) -> bool:
	if not rect().has_point(pos):
		return false
	g.play("click")
	opened += 1
	if DisplayServer.get_name() != "headless":
		OS.shell_open(URL)
	return true
