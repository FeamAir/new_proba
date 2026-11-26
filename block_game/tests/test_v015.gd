extends SceneTree
## Тесты версии 0.15 — украшение комнаты (каркас): каталог (места и их типы, стили, украшения, варианты
## стен / пола / света), совместимость старых сохранений, поворот вещи, стиль комнаты (покупка, примерка,
## применение в 3D и 2D), настроения (переключение, сохранение, редактирование), смена героя (0.16: дом остаётся у героя),
## режим украшения (вход / выход, касания, «Назад»), 3D: все места каталога есть в комнатах, вещи
## строятся на новых местах, метки «+» только в режиме украшения.
## Запуск: godot --headless --path block_game -s tests/test_v015.gd

var failed := 0
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const Catalog := preload("res://scripts/decor_catalog.gd")
const Home3D := preload("res://scripts/home3d/home3d.gd")
const HomeS := preload("res://scripts/home.gd")
const SAVE := "user://save.cfg"
var had_save := false
var save_bytes := PackedByteArray()
var g
var frame := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)


func _initialize() -> void:
	had_save = FileAccess.file_exists(SAVE)
	save_bytes = FileAccess.get_file_as_bytes(SAVE) if had_save else PackedByteArray()
	Home3D.force = true
	g = load("res://scripts/game.gd").new()
	root.add_child(g)


var started := false


func _process(_d: float) -> bool:
	frame += 1
	if frame < 3 or started:
		return false
	started = true
	_run()
	return false


func _run() -> void:
	I18n.set_lang("ru")
	g.tut.enabled = false
	g.assist.track = false
	_test_catalog()
	_test_texts()
	_test_spots_meta()
	_test_rotation()
	_test_room_style()
	_test_moods()
	_test_old_save()
	_test_refund()
	await _test_decorate_ui_2d()
	_test_rooms_3d()
	_test_decorate_ui_3d()
	if had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	I18n.set_lang("ru")
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)


func _step(sec: float) -> void:
	var t := 0.0
	while t < sec:
		g.home3d._process(0.05)
		if g.home3d.room:
			g.home3d.room._process(0.05)
			g.home3d.room.cam._process(0.05)
		g.screens.update(0.05)
		t += 0.05


func _fresh(kind := "owl", shards := 500) -> Meta:
	var m := Meta.new()
	m.set_hero(kind)
	m.shards = shards
	return m


## Первая вещь дома без условий, подходящая месту
func _free_for(kind: String, sp: String) -> String:
	for it in Catalog.decor_for(kind, sp):
		if not it.has("stars") and not it.has("hall"):
			return it.id
	return ""


# ---------- Каталог ----------

func _test_catalog() -> void:
	print("— каталог украшений и стилей")
	check(Meta.DECOR.size() == Catalog.DECOR.size() and Meta.DECOR.size() >= 40, "Meta.DECOR — это каталог (старые 40 украшений на месте)")
	var ids := {}
	var uniq := true
	for it in Catalog.DECOR:
		if ids.has(it.id):
			uniq = false
		ids[it.id] = true
	for h in Catalog.homes():
		for l in Catalog.LAYERS:
			for it in Catalog.layer_items(h, l):
				if ids.has(it.id):
					uniq = false
				ids[it.id] = true
	check(uniq, "id украшений и вариантов стиля комнаты уникальны во всей игре")
	for h in Meta.HEROES:
		var sp: Array = Catalog.spot_ids(h)
		var kinds_ok := true
		var seen := {}
		for s in Catalog.spots(h):
			if not Catalog.KINDS.has(s.kind) or seen.has(s.id):
				kinds_ok = false
			seen[s.id] = true
		var legacy := true
		for s in Meta.SPOTS:
			var k0: String = "shelf" if h == "kitten" and s == "hang" else s.trim_suffix("_l").trim_suffix("_r")  # у котика «сверху» — полка
			if not sp.has(s) or Catalog.spot_kind(s, h) != k0:
				legacy = false
		check(kinds_ok and sp.size() <= Catalog.MAX_SPOTS and sp.size() > 6, "%s: %d мест, типы из общего набора, id не повторяются" % [h, sp.size()])
		check(legacy, "%s: шесть старых мест на месте, с прежними типами" % h)
		var st: Array = Catalog.style_ids(h)
		var dec_ok := true
		for it in Catalog.decor(h):
			if it.home != h or not st.has(it.get("style", "")) or int(it.price) <= 0 or it.spots.is_empty():
				dec_ok = false
			for k in it.spots:
				if not Catalog.KINDS.has(k):
					dec_ok = false
		check(st.size() == 3 and dec_ok, "%s: 3 стиля; у каждой вещи — свой дом, стиль, цена, типы мест" % h)
		var fit_ok := true
		for s in sp:
			if Catalog.decor_for(h, s).is_empty():
				fit_ok = false
		check(fit_ok, "%s: на каждое место есть что поставить" % h)
		var lay_ok := true
		for l in Catalog.LAYERS:
			var list: Array = Catalog.layer_items(h, l)
			if list.size() < 3 or list.size() > 4 or int(list[0].price) != 0 or not Catalog.is_free(list[0].id):
				lay_ok = false
			for i in range(1, list.size()):
				if int(list[i].price) <= 0:
					lay_ok = false
		check(lay_ok, "%s: стены / пол / свет — по 3–4 варианта, первый бесплатный, остальные платные" % h)
		var def: Dictionary = Catalog.default_room(h)
		check(def.walls == Catalog.layer_items(h, "walls")[0].id and def.light == Catalog.layer_items(h, "light")[0].id, "%s: стиль комнаты по умолчанию — первые варианты" % h)
	var by_style: Array = Catalog.decor_for("owl", "", "owl_stars")
	check(not by_style.is_empty() and by_style.all(func(it): return it.style == "owl_stars"), "фильтр по стилю: только вещи этого стиля")
	var win_pot: Array = Catalog.decor_for("owl", "window", "owl_potions")
	check(Catalog.decor_for("owl", "window").all(func(it): return it.spots.has("window")) and not win_pot.is_empty() and win_pot.all(func(it): return it.style == "owl_potions" and it.spots.has("window")) and win_pot.size() < Catalog.decor_for("owl", "window").size(), "фильтр по месту и стилю вместе")
	check(Catalog.room_item("owl_walls_moss").layer == "walls" and Catalog.room_item("owl_walls_moss").house == "owl" and not Catalog.room_item("owl_walls_moss").has("home"), "вариант слоя: дом и слой (не путается с украшением)")


func _test_texts() -> void:
	print("— тексты 0.15")
	var ok := true
	var miss := []
	for l in I18n.LANGS:
		for h in Meta.HEROES:
			for s in Catalog.style_ids(h):
				if not I18n.has_in(l, "dstyle_" + s):
					miss.append(l + ":dstyle_" + s)
			for it in Catalog.decor(h):
				if not I18n.has_in(l, "item_" + it.id):
					miss.append(l + ":item_" + it.id)
			for ly in Catalog.LAYERS:
				for it in Catalog.layer_items(h, ly):
					if not I18n.has_in(l, "room_" + it.id):
						miss.append(l + ":room_" + it.id)
		for k in Catalog.KINDS:
			if not I18n.has_in(l, "spot_kind_" + k):
				miss.append(l + ":spot_kind_" + k)
		for k in ["decorate", "dec_done", "dec_tab_items", "dec_tab_room", "dec_all", "mood_n", "dec_pick_spot", "dec_remove", "layer_walls", "layer_floor", "layer_light"]:
			if not I18n.has_in(l, k):
				miss.append(l + ":" + k)
	check(miss.is_empty() and I18n.missing_keys().is_empty(), "названия стилей, вещей, вариантов, типов мест и кнопок — на обоих языках %s" % str(miss))
	for k in I18n.STR_015.en:
		var a: String = I18n.STR_015.en[k]
		var b: String = I18n.STR_015.ru.get(k, "")
		if a.count("%d") != b.count("%d") or a.count("%s") != b.count("%s") or a.to_lower().contains("friend"):
			ok = false
	check(ok, "блок 0.15: подстановки %d/%s совпадают, без «friend»")
	I18n.set_lang("ru")
	check(I18n.t("decorate") == "Украсить" and I18n.t("mood_n") % 2 == "Настроение 2" and I18n.t("dec_done") == "Готово", "ru: «Украсить», «Настроение 2», «Готово»")
	check(Meta.spot_name("floor_l", "owl") == "Пол слева" and Meta.spot_name("shelf_l", "owl") == "Полка" and Meta.spot_name("near_2", "axolotl") == "Рядом 2", "названия мест: старые — свои, новые — по типу и номеру")
	I18n.set_lang("en")
	check(I18n.t("decorate") == "Decorate" and I18n.t("mood_n") % 3 == "Mood 3" and Meta.spot_name("window", "owl") == "Window sill", "en: Decorate, Mood 3, Window sill")
	I18n.set_lang("ru")


# ---------- Места ----------

func _test_spots_meta() -> void:
	print("— места и типы мест")
	var m := _fresh("owl")
	check(Meta.spot_kind("floor_l") == "floor" and Meta.spot_kind("window", "owl") == "window" and Meta.spot_kind("shelf_l", "owl") == "shelf", "тип места: старые и новые")
	check(m.buy_decor("owl", "window", "owl_books", 0, 1) == "bought" and m.placed_at("owl", "window") == "owl_books", "книжки — на подоконник (новое место)")
	check(m.tap_decor("owl", "shelf_l", "owl_books") == "on" and m.placed_at("owl", "shelf_l") == "owl_books" and m.placed_at("owl", "window") == "", "книжки переезжают на полку")
	check(m.tap_decor("owl", "window", "owl_swing") == "locked" and not m.place("owl", "shelf_l", "owl_garland"), "качели не на подоконник, гирлянда не на полку")
	check(not m.place("owl", "nowhere", "owl_books") and not m.place("axolotl", "window", "owl_books"), "нет такого места / чужой дом — нельзя")
	check(m.tap_decor("puppy", "window", "pup_lamp") == "locked", "у щенка нет подоконника — нельзя")


# ---------- Поворот ----------

func _test_rotation() -> void:
	print("— поворот вещи на месте")
	var m := _fresh("owl")
	m.buy_decor("owl", "near", "owl_books", 0, 1)
	check(m.rot_at("owl", "near") == 0, "новая вещь стоит без поворота")
	check(m.rotate_decor("owl", "near", 1) and m.rot_at("owl", "near") == 1, "⟳ — 45°")
	m.rotate_decor("owl", "near", -3)
	check(m.rot_at("owl", "near") == 6, "⟲ ×3 — по кругу (шаги 0..7)")
	m.rotate_decor("owl", "near", 2)
	check(m.rot_at("owl", "near") == 0 and not m.decor_rot.owl.has("near"), "полный круг — без поворота")
	m.rotate_decor("owl", "near", 3)
	var cfg := ConfigFile.new()
	m.save_to(cfg)
	var m2 := Meta.new()
	m2.load_from(cfg)
	check(m2.rot_at("owl", "near") == 3 and m2.placed_at("owl", "near") == "owl_books", "поворот сохраняется")
	m2.tap_decor("owl", "window", "owl_books")
	check(m2.rot_at("owl", "window") == 0 and m2.rot_at("owl", "near") == 0, "вещь переехала — поворот сначала, старое место без поворота")
	m2.rotate_decor("owl", "window", 2)
	m2.remove_decor("owl", "window")
	check(m2.rot_at("owl", "window") == 0 and not m2.rotate_decor("owl", "window", 1), "убрали — поворота нет, пустое место не вращается")
	m2.buy_decor("owl", "wall_r", "owl_birdhouse", 0, 1)
	check(not m2.rotate_decor("owl", "wall_r", 1) and not Catalog.can_rotate("owl", "wall_r", "owl_birdhouse"), "плоскую вещь на стене не вращают")
	check(Catalog.can_rotate("owl", "floor_l", "owl_hammock") and not Catalog.can_rotate("owl", "wall_l", "owl_hammock"), "гамак на полу вращается, на стене — нет")


# ---------- Стиль комнаты ----------

func _test_room_style() -> void:
	print("— стиль комнаты: стены / пол / свет")
	var m := _fresh("owl", 40)
	check(m.room_of("owl") == Catalog.default_room("owl"), "по умолчанию — первые варианты")
	check(m.tap_room("owl", "owl_walls_bark") == "on" and m.room_is_owned("owl_walls_bark"), "бесплатный вариант уже есть")
	check(m.tap_room("owl", "owl_walls_moss") == "try" and m.room_of("owl").walls == "owl_walls_bark" and m.shards == 40, "платный — примерка, ничего не меняется и не тратится")
	check(not m.set_room("owl", "owl_walls_moss"), "некупленный вариант не выбрать")
	var TryOn: Script = load("res://scripts/tryon.gd")
	var tr = TryOn.new()
	tr.start_room("owl", "owl_walls_moss")
	check(tr.is_room() and not tr.is_decor() and tr.room(m, "owl").walls == "owl_walls_moss" and tr.room(m, "owl").floor == m.room_of("owl").floor, "примерка: стены другие, остальное как было")
	check(tr.room(m, "axolotl") == m.room_of("axolotl") and m.room_of("owl").walls == "owl_walls_bark", "примерка не трогает чужой дом и сохранённое")
	check(tr.price() == 30 and tr.status(m, 0, 1) == "ok", "цена 30, хватает")
	check(tr.confirm(m, 0, 1) == "bought" and m.room_of("owl").walls == "owl_walls_moss" and m.shards == 10 and not tr.active(), "«Купить»: выбрано, −30, примерка закончена")
	tr.start_room("owl", "owl_walls_starry")
	check(tr.status(m, 0, 1) == "poor" and tr.shortage(m) == 40 and tr.confirm(m, 0, 1) == "poor" and not m.room_is_owned("owl_walls_starry"), "нехватка — покупки нет")
	m.shards = 200
	check(m.buy_room("owl", "owl_walls_runes", 0, 1) == "locked" and m.buy_room("owl", "owl_walls_runes", 30, 1) == "bought", "светящиеся руны — после 30 звёзд")
	check(m.buy_room("owl", "owl_floor_roots", 99, 1) == "locked" and m.buy_room("owl", "owl_floor_roots", 0, 11) == "bought", "светящиеся корни — после 1-го зала")
	check(m.buy_room("owl", "axo_walls_coral", 99, 99) == "locked" and m.tap_room("owl", "pup_light_dawn") == "locked", "чужие варианты — нельзя")
	check(m.tap_room("owl", "owl_walls_moss") == "on" and m.room_of("owl").walls == "owl_walls_moss", "купленный выбирается сразу")
	var cfg := ConfigFile.new()
	m.save_to(cfg)
	var m2 := Meta.new()
	m2.load_from(cfg)
	check(m2.room_of("owl").walls == "owl_walls_moss" and m2.room_of("owl").floor == "owl_floor_roots" and m2.room_is_owned("owl_walls_runes") and m2.room_owned.size() == 3, "стиль и купленные варианты сохраняются")
	# 2D: стиль — оттенком (рисование не падает, места новых вещей есть)
	check(HomeS.spot_def("owl", "window").size() == 2 and HomeS.spot_def("owl", "floor_l").size() == 2 and HomeS.spot_def("owl", "nope").is_empty(), "2D: точки старых и новых мест")


# ---------- Настроения ----------

func _test_moods() -> void:
	print("— настроения (3 расстановки на дом)")
	var m := _fresh("owl", 500)
	m.buy_decor("owl", "near", "owl_nest", 0, 1)
	m.buy_decor("owl", "hang", "owl_lantern", 0, 1)
	m.rotate_decor("owl", "near", 2)
	m.buy_room("owl", "owl_light_lamp", 0, 1)
	check(m.mood_of("owl") == 0 and m.mood_empty("owl", 1) and m.mood_empty("owl", 2) and m.mood_count("owl", 0) == 2, "сначала — настроение 1, остальные пустые")
	check(m.switch_mood("owl", 1) and m.mood_of("owl") == 1 and m.placed_at("owl", "near") == "owl_nest" and m.rot_at("owl", "near") == 2 and m.room_of("owl").light == "owl_light_lamp", "новое настроение — копия текущего")
	# редактирование меняет только текущее
	m.remove_decor("owl", "hang")
	m.tap_decor("owl", "window", "owl_lantern")
	m.set_room("owl", "owl_light_moon")
	m.buy_room("owl", "owl_walls_starry", 0, 1)
	check(m.placed_at("owl", "window") == "owl_lantern" and m.placed_at("owl", "hang") == "" and m.room_of("owl").walls == "owl_walls_starry", "настроение 2 изменено")
	var shards: int = m.shards
	m.switch_mood("owl", 0)
	check(m.placed_at("owl", "hang") == "owl_lantern" and m.placed_at("owl", "window") == "" and m.rot_at("owl", "near") == 2 and m.room_of("owl").light == "owl_light_lamp" and m.room_of("owl").walls == "owl_walls_bark", "настроение 1 — как было")
	check(m.shards == shards and m.decor_owned.size() == 2 and m.room_is_owned("owl_walls_starry"), "переключение ничего не тратит и не продаёт")
	check(m.mood_room("owl", 1).walls == "owl_walls_starry" and m.mood_count("owl", 1) == 2 and m.mood_room("owl", 2) == Catalog.default_room("owl"), "значки: стиль и число вещей каждого настроения")
	check(not m.switch_mood("owl", 3) and not m.switch_mood("owl", -1) and m.switch_mood("owl", 0), "нет 4-го настроения; текущее — без изменений")
	# сохранение
	m.switch_mood("owl", 1)
	var cfg := ConfigFile.new()
	m.save_to(cfg)
	var m2 := Meta.new()
	m2.load_from(cfg)
	check(m2.mood_of("owl") == 1 and m2.placed_at("owl", "window") == "owl_lantern" and m2.room_of("owl").walls == "owl_walls_starry", "текущее настроение сохраняется")
	m2.switch_mood("owl", 0)
	check(m2.placed_at("owl", "hang") == "owl_lantern" and m2.rot_at("owl", "near") == 2 and m2.room_of("owl").light == "owl_light_lamp", "и другие — тоже")
	check(m2.mood_empty("owl", 2) and m2.mood_of("axolotl") == 0, "пустое настроение остаётся пустым; у других домов — свои")
	# испорченные данные настроений
	var bad := ConfigFile.new()
	m.save_to(bad)
	bad.set_value("meta", "decor_moods", {"owl": [{"placed": {"near": "owl_moon", "hang": "axo_lily", "window": "owl_lantern", "floor_l": "owl_lantern"}, "rot": {"window": 99, "near": "x"}, "room": {"walls": "owl_walls_honey", "light": 5}}, "junk", {}]})
	bad.set_value("meta", "decor_mood_cur", {"owl": 7})
	var m3 := Meta.new()
	m3.load_from(bad)
	var pl: Dictionary = m3.decor_placed.owl
	check(m3.mood_of("owl") == 2 or m3.mood_of("owl") == 0, "номер настроения вне 0..2 — в пределах")
	m3.switch_mood("owl", 0)
	pl = m3.decor_placed.owl
	check(not pl.has("near") and not pl.has("hang") and pl.values().count("owl_lantern") == 1 and m3.rot_at("owl", "window") in [0, 3], "некупленное, чужое и повторы отброшены; поворот — в 0..7")
	check(m3.room_of("owl").walls == "owl_walls_bark" and m3.room_of("owl").light == Catalog.default_room("owl").light, "некупленный стиль и мусор — по умолчанию")


func _test_old_save() -> void:
	print("— старое сохранение (0.14)")
	var old := ConfigFile.new()
	old.set_value("meta", "hero", "owl")
	old.set_value("meta", "decor_owned", ["owl_lantern", "owl_nest", "pup_ball"])
	old.set_value("meta", "decor_placed", {"owl": {"hang": "owl_lantern", "near": "owl_nest"}, "puppy": {"floor_l": "pup_ball"}})
	var m := Meta.new()
	m.load_from(old)
	check(m.mood_of("owl") == 0 and m.placed_at("owl", "hang") == "owl_lantern" and m.placed_at("owl", "near") == "owl_nest" and m.placed_at("puppy", "floor_l") == "pup_ball", "текущая расстановка стала «Настроением 1»")
	check(m.mood_empty("owl", 1) and m.mood_empty("owl", 2) and m.room_of("owl") == Catalog.default_room("owl") and m.room_owned.is_empty() and m.decor_rot.owl.is_empty(), "настроения 2 и 3 пустые, стиль по умолчанию, без поворотов")
	var cfg := ConfigFile.new()
	m.save_to(cfg)
	check(cfg.has_section_key("meta", "decor_moods") and cfg.get_value("meta", "decor_placed").owl.hang == "owl_lantern", "в новом сохранении — настроения и прежнее поле расстановки")


func _test_refund() -> void:
	print("— 0.16: смена героя — украшения, настроения и стиль комнаты остаются у дома")
	var m := _fresh("owl", 500)
	m.buy_decor("owl", "near", "owl_nest", 0, 1)            # 10
	m.buy_decor("owl", "window", "owl_books", 0, 1)         # 30
	m.buy_room("owl", "owl_walls_moss", 0, 1)                # 30
	m.buy_room("owl", "owl_light_lamp", 0, 1)                # 30
	m.switch_mood("owl", 1)
	m.remove_decor("owl", "near")
	m.decor_owned.append("pup_ball")
	m.decor_placed.puppy = {"near": "pup_ball"}
	m._store_mood("puppy")
	var room0: Dictionary = m.room_of("owl")
	var placed0: Dictionary = m.decor_placed.owl.duplicate()
	var mood1: Dictionary = m.mood_room("owl", 0)
	var sh: int = m.shards
	check(m.switch_hero("axolotl") and m.shards == sh, "смена героя — осколки не меняются (ничего не возвращается)")
	check(m.room_owned.size() == 2 and m.decor_owned.size() == 3 and m.room_of("owl") == room0, "варианты и украшения совёнка остались, стиль комнаты тот же")
	check(m.mood_of("owl") == 1 and m.decor_placed.owl == placed0 and m.mood_room("owl", 0) == mood1 and not m.mood_empty("owl", 0), "настроения дома совёнка на месте (текущее — второе)")
	check(m.placed_at("puppy", "near") == "pup_ball", "дом щенка не тронут")
	m.switch_hero("owl")
	check(m.mood_of("owl") == 1 and m.placed_at("owl", "window") == "owl_books" and m.room_of("owl") == room0 and m.room_is_owned("owl_walls_moss"), "вернулись к совёнку — дом как был")


# ---------- Режим украшения (2D-дом) ----------

func _test_decorate_ui_2d() -> void:
	print("— режим украшения (2D-дом)")
	var h = g.home3d
	h.set_quality("2d", true)
	g.meta = _fresh("owl", 300)
	g.max_level = 1
	g.go_home()
	var du = g.decor_ui
	var sc = g.screens
	await _draw_once()
	# кнопка «Украсить» на главном экране
	check(sc.rects.has("decorate") and sc.rects.has("map") and sc.rects.has("wardrobe"), "на главном экране кнопки «Карта», «Украсить», «Гардероб»")
	g._touch_down(0, sc.rects["decorate"].get_center())
	check(du.active and du.spot == "" and du.tab == "items", "кнопка «Украсить» — режим украшения")
	await _draw_once()
	for k in ["done", "mood_0", "mood_1", "mood_2", "tab_items", "tab_room", "style_all", "panel"]:
		if not du.rects.has(k):
			check(false, "нет кнопки " + k)
	check(du.rects.has("card_" + Catalog.decor("owl")[0].id) and sc.rects.has("spot_window") and sc.rects.has("spot_floor_l"), "панель нарисована: карточки вещей; в 2D — места, и новые тоже")
	# касание по панели мимо кнопок — ничего
	g._touch_down(0, Vector2(700, g.H - 30))
	check(du.active, "касание по панели мимо кнопок — остаёмся")
	# фильтр по стилю
	g._touch_down(0, du.rects["style_owl_stars"].get_center())
	check(du.style_filter == "owl_stars" and du.items().all(func(it): return it.style == "owl_stars"), "фильтр «Звездочёт»")
	g._touch_down(0, du.rects["style_all"].get_center())
	# место в 2D-доме
	await _draw_once()
	g._touch_down(0, sc.rects["spot_near"].get_center())
	check(du.spot == "near" and du.items().all(func(it): return it.spots.has("near")), "тап по месту — выбрано, вещи только для него")
	await _draw_once()
	var id := _free_for("owl", "near")
	g._touch_down(0, du.rects["card_" + id].get_center())
	g._touch_up(0, du.rects["card_" + id].get_center())  # 0.18: карточка ленты срабатывает при отпускании
	check(du.tryon.active() and du.tryon.id == id and g.meta.placed_at("owl", "near") == "" and g.meta.shards == 300, "тап по вещи — примерка на месте, ничего не потрачено")
	await _draw_once()
	check(du.rects.has("buy") and du.rects.has("cancel"), "при примерке — «Купить за N» и «Отмена»")
	g._touch_down(0, du.rects["cancel"].get_center())
	check(not du.tryon.active() and du.active and du.spot == "near", "«Отмена» — примерки нет, место выбрано")
	await _draw_once()
	g._touch_down(0, du.rects["card_" + id].get_center())
	g._touch_up(0, du.rects["card_" + id].get_center())  # 0.18: карточка ленты срабатывает при отпускании
	await _draw_once()
	g._touch_down(0, du.rects["buy"].get_center())
	check(g.meta.placed_at("owl", "near") == id and g.meta.decor_owned.has(id) and g.meta.shards < 300 and du.active, "«Купить» — стоит, режим не закрылся")
	await _draw_once()
	check(du.rects.has("rot_l") and du.rects.has("rot_r") and du.rects.has("remove"), "у поставленной — ⟲ ⟳ и «Убрать»")
	g._touch_down(0, du.rects["rot_r"].get_center())
	g._touch_down(0, du.rects["rot_r"].get_center())
	g._touch_down(0, du.rects["rot_l"].get_center())
	check(g.meta.rot_at("owl", "near") == 1, "⟳ ⟳ ⟲ — поворот на 45°")
	# касание мимо (по дому, не по месту) — снимает выбор, из режима не выходим
	g._touch_down(0, Vector2(600, 600))
	check(du.active and du.spot == "", "касание мимо — выбор снят, режим остаётся")
	# вещь без выбранного места: место подбирается само
	await _draw_once()
	g._touch_down(0, du.rects["card_" + id].get_center())
	g._touch_up(0, du.rects["card_" + id].get_center())  # 0.18: карточка ленты срабатывает при отпускании
	check(du.spot == "near", "тап по поставленной вещи без места — выбирается её место")
	du.deselect()
	du.tap_item("owl_lantern")
	check(du.spot != "" and Catalog.fits("owl", du.spot, "owl_lantern") and g.meta.placed_at("owl", du.spot) == "" and du.tryon.id == "owl_lantern", "некупленная вещь без места — свободное подходящее место, примерка")
	# вкладка «Комната»
	await _draw_once()
	g._touch_down(0, du.rects["tab_room"].get_center())
	check(du.tab == "room" and not du.tryon.active(), "вкладка «Комната» (примерка вещи снята)")
	await _draw_once()
	g._touch_down(0, du.rects["layer_light"].get_center())
	await _draw_once()
	g._touch_down(0, du.rects["card_owl_light_lamp"].get_center())
	g._touch_up(0, du.rects["card_owl_light_lamp"].get_center())  # 0.18: карточка ленты срабатывает при отпускании
	check(du.tryon.is_room() and du.tryon.room(g.meta, "owl").light == "owl_light_lamp" and g.meta.room_of("owl").light == "owl_light_moon", "свет: примерка до покупки")
	await _draw_once()
	g._touch_down(0, du.rects["buy"].get_center())
	check(g.meta.room_of("owl").light == "owl_light_lamp" and g.meta.room_is_owned("owl_light_lamp"), "свет куплен и выбран")
	await _draw_once()
	g._touch_down(0, du.rects["card_owl_light_moon"].get_center())
	g._touch_up(0, du.rects["card_owl_light_moon"].get_center())  # 0.18: карточка ленты срабатывает при отпускании
	check(g.meta.room_of("owl").light == "owl_light_moon", "бесплатный свет — сразу")
	# настроения
	await _draw_once()
	g._touch_down(0, du.rects["mood_1"].get_center())
	check(g.meta.mood_of("owl") == 1 and g.meta.placed_at("owl", "near") == id, "кнопка «2» — настроение 2 (копия)")
	g.meta.remove_decor("owl", "near")
	await _draw_once()
	g._touch_down(0, du.rects["mood_0"].get_center())
	check(g.meta.mood_of("owl") == 0 and g.meta.placed_at("owl", "near") == id, "кнопка «1» — прежняя расстановка")
	# «Назад»: примерка -> место -> выход
	du.select("floor_l")
	du.tap_item("owl_mushrooms")
	g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(du.active and not du.tryon.active() and du.spot == "floor_l", "«Назад» — сначала снимает примерку")
	g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(du.active and du.spot == "", "потом — выбор места")
	g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not du.active and g.state == g.State.HOME, "потом — выход из режима, остаёмся дома")
	# «Готово»
	du.open("floor_l")
	await _draw_once()
	g._touch_down(0, du.rects["done"].get_center())
	check(not du.active and du.spot == "", "«Готово» — выход")
	# уход с экрана «Дом» закрывает режим
	du.open()
	g.screens.open_map()
	check(not du.active, "уход на карту — режим закрыт")
	g.go_home()
	# вкладка «Дом» гардероба и цель «Можно купить»
	g.screens.open_wardrobe("home")
	check(g.state == g.State.HOME and du.active, "вкладка «Дом» гардероба — режим украшения")
	du.close()
	g.assist_ui.rects["goal"] = Rect2(0, 0, 10, 10)
	var gl: Dictionary = g.assist_ui.goal()
	if gl.get("home", "") != "":
		g.assist_ui.tap_home(Vector2(5, 5))
		check(du.active and du.tryon.id == gl.id, "цель «Можно купить» с украшением — режим, вещь примеряется")
		du.close()


## Кадр отрисовки: экран «Дом» рисуется и заполняет прямоугольники кнопок
func _draw_once() -> void:
	g.queue_redraw()
	await process_frame
	await process_frame


# ---------- 3D ----------

func _new_room(kind: String, placed: Dictionary, rot := {}, sty := {}) -> Node3D:
	var vp := SubViewport.new()
	vp.size = Vector2i(360, 640)
	vp.own_world_3d = true
	root.add_child(vp)
	var r = Home3D.ROOMS[kind].new()
	r.setup(kind, 2, placed, {}, true, rot, sty)
	vp.add_child(r)
	r.build()
	return r


func _drop(r: Node3D) -> void:
	var vp := r.get_parent()
	root.remove_child(vp)
	vp.free()


func _test_rooms_3d() -> void:
	print("— 3D: места каталога, новые типы мест, поворот, стиль комнаты")
	for kind in Meta.HEROES:
		var r = _new_room(kind, {})
		var sp_ok := true
		for s in Catalog.spot_ids(kind):
			if not r.spots.has(s):
				sp_ok = false
				continue
			var p: Vector3 = r.spot_point(s)
			if not p.is_finite() or Vector2(p.x, p.z).length() > 6.5 or p.y < -0.1 or p.y > 4.6:
				sp_ok = false
		check(sp_ok and r.spot_list().size() == Catalog.spot_ids(kind).size(), "%s: все %d мест каталога есть в 3D и внутри сцены" % [kind, Catalog.spot_ids(kind).size()])
		# места не налезают друг на друга и на полку славы
		var apart := true
		var ids: Array = r.spot_list()
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				if (r.spots[ids[i]].pos as Vector3).distance_to(r.spots[ids[j]].pos) < 0.45:
					apart = false
					printerr("    близко: ", ids[i], " ", ids[j])
			if r.shelf and (r.spots[ids[i]].pos as Vector3).distance_to(r.shelf_def.pos) < 0.9:
				apart = false
				printerr("    у полки славы: ", ids[i])
		check(apart, "%s: места не налезают друг на друга и на полку кубков" % kind)
		# каждая вещь на каждом новом месте строится
		var bad := []
		for s in ids:
			if Meta.SPOTS.has(s):
				continue
			for it in Catalog.decor_for(kind, s):
				r.set_placed({s: it.id})
				var n = r.spot_nodes.get(s)
				if n == null or n.find_children("*", "MeshInstance3D", true, false).size() < 1 or not r.spot_focus.has(s):
					bad.append("%s@%s" % [it.id, s])
		check(bad.is_empty(), "%s: вещи на новых местах строятся %s" % [kind, str(bad)])
		# метки: вне режима — нет, в режиме — у всех пустых мест
		r.set_placed({})
		var vis := 0
		for s in r.markers:
			vis += 1 if r.markers[s].visible else 0
		r.set_markers(true)
		var vis2 := 0
		for s in r.markers:
			vis2 += 1 if r.markers[s].visible else 0
		check(vis == 0 and vis2 == ids.size(), "%s: метки «+» только в режиме украшения (%d)" % [kind, vis2])
		# поворот: узел вещи повернут на 45° × шаги
		var fs := ""
		var fid := ""
		for s in ids:
			if Catalog.spot_kind(s, kind) in ["floor", "near"]:
				fs = s
				fid = Catalog.decor_for(kind, s)[0].id
				break
		r.set_placed({fs: fid}, {})
		var n0: Node3D = r.spot_nodes[fs]
		var b0 := _first_mesh_basis(n0)
		r.set_placed({fs: fid}, {fs: 2})
		var n1: Node3D = r.spot_nodes[fs]
		var b1 := _first_mesh_basis(n1)
		check(n1 != n0 and absf(b0.get_euler().y - b1.get_euler().y) > 0.1, "%s: поворот перестраивает вещь, она повёрнута" % kind)
		# стиль комнаты: стены / пол меняют материал, свет — окружение и лампы
		var amb0: Color = r.env.ambient_light_color
		var mat0 = _style_mat(r)
		var walls: Array = Catalog.layer_items(kind, "walls")
		var lights: Array = Catalog.layer_items(kind, "light")
		r.set_style({"walls": walls[1].id, "light": lights[1].id})
		var mat1 = _style_mat(r)
		check(r.style.walls == walls[1].id and not _same(mat1, mat0), "%s: apply_walls — стены перекрашены" % kind)
		check(r.env.ambient_light_color != amb0, "%s: apply_light — другой свет окружения" % kind)
		r.set_style({})
		check(r.style.walls == walls[0].id and _same(_style_mat(r), mat0) and r.env.ambient_light_color.is_equal_approx(amb0), "%s: стиль по умолчанию — как было" % kind)
		# вещь без своего 3D (дизайнер добавил только данные) — коробочка-заготовка
		var ph := Node3D.new()
		r.add_child(ph)
		r._placeholder(Catalog.decor(kind)[0].id, ph)
		check(ph.get_child_count() >= 2, "%s: заготовка для вещи без 3D строится" % kind)
		_drop(r)


## Одно и то же ли (материал или [материал, параметр]; разные типы — разное)
func _same(a, b) -> bool:
	return typeof(a) == typeof(b) and a == b


## Материал (или его параметр) стен комнаты — чтобы увидеть смену стиля
func _style_mat(r) -> Variant:
	var p = r.wall_parts[0]
	var gi: GeometryInstance3D = p if p is GeometryInstance3D else p.find_children("*", "GeometryInstance3D", true, false)[0]
	var m: Material = gi.material_override
	if m is ShaderMaterial:
		return [m, (m as ShaderMaterial).get_shader_parameter("wall_tint")]
	return m


func _first_mesh_basis(n: Node3D) -> Basis:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var p: Node = mi
		while p != n:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		return xf.basis
	return Basis()


func _test_decorate_ui_3d() -> void:
	print("— режим украшения (3D-дом)")
	var h = g.home3d
	h.set_quality("high", true)
	g.meta = _fresh("owl", 300)
	g.max_level = 1
	g.go_home()
	_step(0.3)
	var du = g.decor_ui
	check(h.showing() and not h.room.markers_on, "3D-дом: вне режима метки скрыты")
	du.open()
	_step(0.1)
	check(h.room.markers_on and h.room.highlight == "", "режим украшения: метки видны")
	# тап по месту
	var target := ""
	var sp := Vector2.ZERO
	for s in Catalog.spot_ids("owl"):
		var q: Vector2 = h.room.cam.unproject_position(h.room.spot_point(s))
		var c: Dictionary = h.room.pick(q)
		if c.get("spot", "") == s and not h.room.cam.is_position_behind(h.room.spot_point(s)):
			target = s
			sp = q
			break
	check(target != "", "место видно и выбирается касанием")
	if target != "":
		h.room.cam.tapped.emit(sp)
		_step(0.1)
		check(du.spot == target and h.room.highlight == target and h.room.cam.focused, "тап по месту — выбрано, кольцо, камера подлетает")
		var id := _free_for("owl", target)
		du.tap_item(id)
		_step(0.1)
		check(h.room.placed.get(target, "") == id and g.meta.placed_at("owl", target) == "", "примерка видна в 3D")
		du.confirm()
		_step(0.1)
		check(h.room.placed.get(target, "") == id and g.meta.placed_at("owl", target) == id, "куплено — стоит")
		if Catalog.can_rotate("owl", target, id):
			du.rotate(1)
			_step(0.1)
			check(int(h.room.rots.get(target, 0)) == 1, "поворот виден в 3D")
		# тап мимо — снять выбор
		h.room.cam.tapped.emit(Vector2(5, 5))
		_step(0.1)
		check(du.active and du.spot == "" and h.room.highlight == "", "тап мимо — выбор снят, режим остаётся")
	# стиль комнаты: примерка видна в 3D
	du.tab = "room"
	du.layer = "walls"
	du.tap_room("owl_walls_starry")
	_step(0.1)
	check(h.room.style.walls == "owl_walls_starry" and g.meta.room_of("owl").walls == "owl_walls_bark", "примерка стен — в 3D, не куплено")
	du.tryon.clear()
	_step(0.1)
	check(h.room.style.walls == "owl_walls_bark", "отмена — стены как были")
	# настроение 2 — другая расстановка в 3D
	du.set_mood(1)
	g.meta.remove_decor("owl", target)
	_step(0.1)
	check(h.room.placed.get(target, "") == "", "настроение 2: вещь убрана в 3D")
	du.set_mood(0)
	_step(0.1)
	check(target == "" or h.room.placed.get(target, "") != "", "настроение 1: вещь снова стоит")
	du.close()
	_step(0.1)
	check(not h.room.markers_on and not du.active, "«Готово» — метки скрыты")
	# касание по вещи вне режима — режим украшения с этим местом
	if target != "":
		var at: Vector2 = h.room.cam.unproject_position(h.room.spot_focus.get(target, [h.room.spot_point(target)])[0])
		h.room.cam.fly_home()
		_step(1.0)
		at = h.room.cam.unproject_position(h.room.spot_focus.get(target, [h.room.spot_point(target)])[0])
		h.room.cam.tapped.emit(at)
		_step(0.8)
		check(du.active and du.spot == target, "тап по вещи вне режима — режим украшения, её место выбрано")
		du.close()
