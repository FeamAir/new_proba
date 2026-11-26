extends SceneTree
## Тесты 0.15 (дизайнер, дома совёнка и аксолотля): у каждой вещи этих домов — своё 3D на каждом типе места
## (не коробочка-заготовка), свой значок и названия en/ru; места каталога расставлены (внутри, не налезают),
## у всех вариантов стен / пола / света — свой вид; полностью обставленная комната не тяжелее нормы.
## Запуск: godot --headless --path block_game -s tests/test_v015_owl_axo.gd

const I18n := preload("res://scripts/i18n.gd")
const Catalog := preload("res://scripts/decor_catalog.gd")
const Home3D := preload("res://scripts/home3d/home3d.gd")
const HomeS := preload("res://scripts/home.gd")
const HOMES := ["owl", "axolotl"]
var failed := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)


func _initialize() -> void:
	_run()
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)


func _new_room(kind: String, placed := {}, hq := true) -> Node3D:
	var vp := SubViewport.new()
	vp.size = Vector2i(360, 640)
	vp.own_world_3d = true
	root.add_child(vp)
	var r = Home3D.ROOMS[kind].new()
	r.setup(kind, 2, placed, {}, hq)
	vp.add_child(r)
	r.build()
	return r


func _drop(r: Node3D) -> void:
	var vp := r.get_parent()
	root.remove_child(vp)
	vp.free()


## Вид места для _decor: как в room.gd _place (стена: плоская вещь висит, остальные стоят на полочке)
static func _sk(kind_: String, id: String, flat: bool) -> String:
	match kind_:
		"shelf", "window":
			return "ledge"
		"wall":
			return "wall" if flat else "ledge"
	return kind_


func _run() -> void:
	for h in HOMES:
		print("— ", h)
		var r = _new_room(h)
		# 1) у каждой вещи — своё 3D на каждом своём типе места (не заготовка)
		var no3d := []
		for it in Catalog.decor(h):
			for k in it.spots:
				var n := Node3D.new()
				r.add_child(n)
				var saved: Array = r.anims
				var saved_l: Array = r.lights
				r.anims = []
				r.lights = []
				r._decor(it.id, n, _sk(k, it.id, it.get("flat", false) or r.FLAT_WALL.has(it.id)))
				r.anims = saved
				r.lights = saved_l
				if n.find_children("*", "GeometryInstance3D", true, false).size() < 3:
					no3d.append("%s@%s" % [it.id, k])
				n.free()
		check(no3d.is_empty(), "%s: у всех %d вещей своё 3D на всех типах мест (без коробочек) %s" % [h, Catalog.decor(h).size(), str(no3d)])
		# 2) места: все из каталога, внутри комнаты, не ближе 0.45 м друг к другу и 0.9 м к полке славы
		var ids: Array = r.spot_list()
		var apart := true
		for i in ids.size():
			var p: Vector3 = r.spots[ids[i]].pos
			if Vector2(p.x, p.z).length() > r.R + 0.05 or p.y < -0.05 or p.y > r.TOP_H + 0.1:
				apart = false
				printerr("    снаружи: ", ids[i])
			for j in range(i + 1, ids.size()):
				if p.distance_to(r.spots[ids[j]].pos) < 0.45:
					apart = false
			if p.distance_to(r.shelf_def.pos) < 0.9:
				apart = false
		var want := 16 if h == "owl" else 15
		check(ids.size() == want and Catalog.spot_ids(h).size() == want and apart, "%s: %d мест, все в комнате, не налезают друг на друга и на полку славы" % [h, want])
		# 3) варианты стен / пола: у каждого — свой материал; свет — своё окружение
		var seen := {}
		var ok_style := true
		for it in Catalog.layer_items(h, "walls"):
			r.set_style({"walls": it.id})
			var m = r.wall_parts[0].material_override
			if seen.has(m):
				ok_style = false
			seen[m] = true
		seen = {}
		for it in Catalog.layer_items(h, "floor"):
			r.set_style({"floor": it.id})
			var m = r.floor_parts[0].material_override
			if seen.has(m):
				ok_style = false
			seen[m] = true
		var bgs := {}
		for it in Catalog.layer_items(h, "light"):
			r.set_style({"light": it.id})
			bgs[[r.env.ambient_light_color, r.env.background_color]] = true
		r.set_style({})
		check(ok_style and bgs.size() == Catalog.layer_items(h, "light").size(), "%s: 4 варианта стен, пола и света — каждый со своим видом" % h)
		_drop(r)
		# 4) значки и названия
		var miss := []
		for it in Catalog.decor(h):
			if not HomeS.DECOR_H.has(it.id):
				var m = HomeS._icon_mod(it.id)
				if m == null or not m.H.has(it.id):
					miss.append("icon:" + it.id)
			for l in ["en", "ru"]:
				if not I18n.has_in(l, "item_" + it.id):
					miss.append(l + ":" + it.id)
		check(miss.is_empty(), "%s: у всех вещей — значок и названия en/ru %s" % [h, str(miss)])
		# 5) полностью обставленная комната (все места, простое качество): деталей не больше нормы
		var full := {}
		var used := {}
		for s in Catalog.spot_ids(h):
			for it in Catalog.decor_for(h, s):
				if not used.has(it.id):
					full[s] = it.id
					used[it.id] = true
					break
		var r0 = _new_room(h, {}, false)
		var base := _count(r0)
		_drop(r0)
		var r1 = _new_room(h, full, false)
		var all_ := _count(r1)
		var per := float(all_ - base) / maxf(1.0, full.size())
		_drop(r1)
		check(full.size() == Catalog.spot_ids(h).size() and per < 14.0, "%s: обставлены все %d мест, в среднем %.1f сеток на вещь (склейка работает)" % [h, full.size(), per])


## Сколько сеток рисует комната (MeshInstance3D + MultiMesh), без света
func _count(r: Node) -> int:
	var n := 0
	for gi in r.find_children("*", "GeometryInstance3D", true, false):
		if (gi as GeometryInstance3D).visible:
			n += 1
	return n
