extends SceneTree
## Тест ссылки «Конфиденциальность» в меню паузы (scripts/privacy.gd):
##   адрес политики, тексты en/ru, место на экране (не задевает пункты паузы), касание по ссылке.
## Запуск: godot --headless --path block_game -s tests/test_privacy.gd

var failed := 0
var frame := 0
var g
var had_save := false
var save_bytes := PackedByteArray()
const I18n := preload("res://scripts/i18n.gd")
const Privacy := preload("res://scripts/privacy.gd")
const SAVE := "user://save.cfg"


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)


func _initialize() -> void:
	had_save = FileAccess.file_exists(SAVE)
	save_bytes = FileAccess.get_file_as_bytes(SAVE) if had_save else PackedByteArray()
	g = load("res://scripts/game.gd").new()
	root.add_child(g)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		_run()
		_finish()
	return false


func _finish() -> void:
	if had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	I18n.set_lang("ru")
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)


func _run() -> void:
	check(Privacy.URL == "https://feamair.github.io/cascado-privacy/", "адрес политики конфиденциальности")
	check(I18n.has_in("en", "privacy_link") and I18n.has_in("ru", "privacy_link"), "ключ privacy_link есть на en и ru")
	I18n.set_lang("en")
	check(I18n.t("privacy_link") == "Privacy Policy", "en: Privacy Policy")
	I18n.set_lang("ru")
	check(I18n.t("privacy_link") == "Конфиденциальность", "ru: Конфиденциальность")
	check(I18n.missing_keys().is_empty(), "все ключи переведены")

	g.tut.enabled = false
	g.start_level(1)
	g._set_state(g.State.PAUSED)
	var r: Rect2 = g.privacy.rect()
	check(Rect2(0, 0, g.W, g.H).encloses(r), "ссылка в пределах экрана")
	var clash := false
	for n in g.menu_buttons:
		if g.menu_buttons[n].intersects(r):
			clash = true
	check(not clash and not g.assist_ui.version_rect().intersects(r), "ссылка не задевает пункты паузы и номер версии")
	g._touch_down(0, r.get_center())
	check(g.privacy.opened == 1 and g.state == g.State.PAUSED, "касание по ссылке открывает политику, пауза остаётся")
	g._touch_down(1, Vector2(10, 10))
	check(g.privacy.opened == 1, "касание мимо ссылки её не открывает")
