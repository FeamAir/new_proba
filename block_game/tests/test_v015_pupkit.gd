extends SceneTree
## Тесты 0.15, этап 2 — дома щенка и котика: все места каталога (по 15) есть в 3D и стоят свободно;
## у всех украшений есть своё 3D на всех своих типах мест (без коробочки-заготовки), вещь разумного размера
## и строится на каждом подходящем месте; варианты забора / стен, земли / пола и света заметно меняют комнату;
## тексты en/ru и 2D-значки новых вещей есть.
## Запуск: godot --headless --path block_game -s tests/test_v015_pupkit.gd

var failed := 0
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const Catalog := preload("res://scripts/decor_catalog.gd")
const Home3D := preload("res://scripts/home3d/home3d.gd")
const HOMES := ["puppy", "kitten"]
## Новые вещи 0.15 (по каталогу сценариста): по 20 на дом
const NEW := {
	"puppy": ["pup_sunflowers", "pup_picnic", "pup_birdbath", "pup_gazebo", "pup_pennants", "pup_binoculars", "pup_backpack",
		"pup_trailmap", "pup_canoe", "pup_tent", "pup_campfire", "pup_cones", "pup_spray", "pup_headphones", "pup_skateboard",
		"pup_hoop", "pup_graffiti", "pup_boombox", "pup_neon", "pup_ramp"],
	"kitten": ["kit_tea", "kit_windowseat", "kit_stove", "kit_headphones", "kit_poster", "kit_mic", "kit_beanbag", "kit_vinyl",
		"kit_amp", "kit_disco", "kit_neon", "kit_guitar", "kit_drums", "kit_paints", "kit_vase", "kit_cranes", "kit_plants",
		"kit_starlamp", "kit_easel", "kit_stainedglass"],
}
var frame := 0
var started := false


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)


func _process(_d: float) -> bool:
	frame += 1
	if frame < 3 or started:
		return false
	started = true
	_run()
	return false


func _run() -> void:
	I18n.set_lang("ru")
	_test_catalog()
	_test_texts_icons()
	for kind in HOMES:
		_test_room(kind)
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)


func _test_catalog() -> void:
	print("— каталог щенка и котика")
	for kind in HOMES:
		check(Catalog.spot_ids(kind).size() == 15, "%s: 15 мест (%d)" % [kind, Catalog.spot_ids(kind).size()])
		var per := {}
		for it in Catalog.decor(kind):
			per[it.style] = per.get(it.style, 0) + 1
		var ok := per.size() == 3
		for s in per:
			ok = ok and per[s] == 10
		check(ok, "%s: 3 стиля по 10 украшений %s" % [kind, str(per)])
		var have := true
		for id in NEW[kind]:
			have = have and not Catalog.decor_item(id).is_empty()
		check(have, "%s: все 20 новых украшений в каталоге" % kind)
		var wows := Catalog.decor(kind).filter(func(it): return it.spots.has("big") or it.id in ["kit_stainedglass"])
		check(not wows.is_empty(), "%s: есть вещи для больших мест" % kind)


func _test_texts_icons() -> void:
	print("— тексты и 2D-значки")
	var miss := []
	for l in ["en", "ru"]:
		for kind in HOMES:
			for it in Catalog.decor(kind):
				if not I18n.has_in(l, "item_" + it.id):
					miss.append("%s:item_%s" % [l, it.id])
			for layer in Catalog.LAYERS:
				for it in Catalog.layer_items(kind, layer):
					if not I18n.has_in(l, "room_" + it.id):
						miss.append("%s:room_%s" % [l, it.id])
	check(miss.is_empty(), "названия вещей и вариантов комнаты en/ru %s" % str(miss))
	var no_icon := []
	for kind in HOMES:
		var src: String = (load("res://scripts/decor_data/%s_icons.gd" % kind) as GDScript).source_code
		for id in NEW[kind]:
			if not src.contains('"%s":' % id):
				no_icon.append(id)
	check(no_icon.is_empty(), "у всех новых вещей свой 2D-значок %s" % str(no_icon))


func _new_room(kind: String, placed := {}, sty := {}, hq := true) -> Node3D:
	var vp := SubViewport.new()
	vp.size = Vector2i(360, 640)
	vp.own_world_3d = true
	root.add_child(vp)
	var r = Home3D.ROOMS[kind].new()
	r.setup(kind, 2, placed, {}, hq, {}, sty)
	vp.add_child(r)
	r.build()
	return r


func _drop(r: Node3D) -> void:
	var vp := r.get_parent()
	root.remove_child(vp)
	vp.free()


## Вид места для _decor: как в room.gd _place (стена: плоская вещь — "wall", иначе — стоит на полочке)
func _sk(r, kind: String, spot: String, id: String) -> String:
	var k := Catalog.spot_kind(spot, kind)
	if k == "wall":
		return "wall" if r._is_flat(id, spot) else "ledge"
	if k == "shelf" or k == "window":
		return "ledge"
	return k


func _test_room(kind: String) -> void:
	print("— 3D: ", kind)
	var r = _new_room(kind)
	var ids: Array = r.spot_list()
	check(ids.size() == 15, "%s: все 15 мест каталога есть в комнате" % kind)
	# места внутри сцены, не налезают друг на друга, на полку славы и на героя
	var bad := []
	for i in ids.size():
		var p: Vector3 = r.spots[ids[i]].pos
		if Vector2(p.x - r.hero_feet.x, p.z - r.hero_feet.z).length() < 0.55 and p.y < 1.0:
			bad.append("hero:" + ids[i])
		if r.shelf and p.distance_to(r.shelf_def.pos) < 0.9:
			bad.append("shelf:" + ids[i])
		for j in range(i + 1, ids.size()):
			if p.distance_to(r.spots[ids[j]].pos) < 0.45:
				bad.append("%s~%s" % [ids[i], ids[j]])
	check(bad.is_empty(), "%s: места свободны (герой, полка кубков, соседи) %s" % [kind, str(bad)])
	# у каждой вещи — своё 3D на каждом своём типе места (без заготовки)
	var no3d := []
	var saved_a: Array = r.anims
	var saved_l: Array = r.lights
	for it in Catalog.decor(kind):
		for sk_kind in it.spots:
			var spot := ""
			for s in ids:
				if Catalog.spot_kind(s, kind) == sk_kind:
					spot = s
					break
			var holder := Node3D.new()
			r.add_child(holder)
			var n := Node3D.new()
			n.name = "spot_" + spot
			holder.add_child(n)
			var item := Node3D.new()
			n.add_child(item)
			r.anims = []
			r.lights = []
			r._decor(it.id, item, _sk(r, kind, spot, it.id))
			if item.get_child_count() == 0:
				no3d.append("%s@%s" % [it.id, sk_kind])
			r.remove_child(holder)
			holder.free()
	r.anims = saved_a
	r.lights = saved_l
	check(no3d.is_empty(), "%s: у всех вещей своё 3D на всех типах мест (без коробочки) %s" % [kind, str(no3d)])
	# каждая вещь на каждом подходящем месте строится, разумного размера, рядом с местом
	var odd := []
	var count := 0
	for s in ids:
		for it in Catalog.decor_for(kind, s):
			r.set_placed({s: it.id})
			count += 1
			var n = r.spot_nodes.get(s)
			if n == null or not r.spot_focus.has(s):
				odd.append("%s@%s" % [it.id, s])
				continue
			var bb: AABB = r._local_aabb(n)
			var c: Vector3 = r.spot_focus[s][0]
			if bb.size.length() > 4.2 or bb.size.length() < 0.05 or c.distance_to(r.spot_point(s)) > 2.5 or c.y < -0.2 or c.y > 4.2:
				odd.append("%s@%s %s" % [it.id, s, str(bb.size)])
	r.set_placed({})
	check(odd.is_empty(), "%s: %d сочетаний «вещь × место» строятся, размер и положение разумные %s" % [kind, count, str(odd)])
	# комната полностью обставлена — без ошибок; лампочек-источников не больше бюджета
	var full := {}
	var used := []
	for s in ids:
		for it in Catalog.decor_for(kind, s):
			if not used.has(it.id):
				used.append(it.id)
				full[s] = it.id
				break
	r.set_placed(full)
	r.set_quality(false)
	var lit := 0
	for l in r.find_children("*", "OmniLight3D", true, false):
		if (l as Light3D).visible and l != r.cam_light:
			lit += 1
	check(full.size() == ids.size() and lit <= r.LIGHTS_SIMPLE, "%s: всё обставлено (%d вещей), в простом качестве ламп-источников %d" % [kind, full.size(), lit])
	r.set_quality(true)
	_drop(r)
	_test_style(kind)


func _test_style(kind: String) -> void:
	var r = _new_room(kind)
	var ok := true
	var seen := {}
	for layer in Catalog.LAYERS:
		for it in Catalog.layer_items(kind, layer):
			r.set_style({layer: it.id})
			if r.style.get(layer, "") != it.id:
				ok = false
			seen[layer + it.id] = _signature(r, kind, layer)
	check(ok, "%s: все варианты стен / пола / света применяются" % kind)
	# варианты одного слоя заметно различаются (не только оттенком): разный набор видимых узлов / параметров
	var differ := true
	for layer in Catalog.LAYERS:
		var sigs := {}
		for it in Catalog.layer_items(kind, layer):
			sigs[str(seen[layer + it.id])] = true
		if sigs.size() != Catalog.layer_items(kind, layer).size():
			differ = false
			printerr("    одинаковые варианты: ", layer)
	check(differ, "%s: все варианты каждого слоя различаются" % kind)
	# простое качество — россыпи реже
	r.set_style({"walls": Catalog.layer_items(kind, "walls")[2].id, "floor": Catalog.layer_items(kind, "floor")[1].id, "light": Catalog.layer_items(kind, "light")[2].id})
	r.set_quality(false)
	var halved := true
	for mmi in r._hq_counts:
		if is_instance_valid(mmi) and (mmi as MultiMeshInstance3D).is_visible_in_tree():
			if (mmi as MultiMeshInstance3D).multimesh.visible_instance_count > int(r._hq_counts[mmi]) / 2:
				halved = false
	check(halved, "%s: в простом качестве россыпи стиля комнаты — вдвое реже" % kind)
	_drop(r)


## Что видно от слоя: какие узлы-варианты включены и параметры шейдеров (для сравнения вариантов)
func _signature(r, kind: String, layer: String) -> Array:
	var out := []
	if kind == "puppy":
		var nodes: Dictionary = {"walls": r._wall_nodes, "floor": r._floor_nodes, "light": r._light_nodes}[layer]
		for k in nodes:
			if (nodes[k] as Node3D).visible:
				out.append(k)
		if layer == "light":
			out.append(r._sky_mat.get_shader_parameter("low_col"))
	else:
		var m: ShaderMaterial = r._shell_mat
		if layer == "walls":
			out.append(m.get_shader_parameter("wall_mode"))
		elif layer == "floor":
			out.append(m.get_shader_parameter("floor_mode"))
		else:
			for k in r._light_nodes:
				if (r._light_nodes[k] as Node3D).visible:
					out.append(k)
	out.append(r.env.ambient_light_color)
	return out
