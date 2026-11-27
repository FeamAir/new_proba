extends "res://scripts/home3d/kit.gd"
## Общая часть 3D-дома (Cascado 0.12): места украшений, герой-«картонка», камера, метки «+»,
## кольцо примерки, анимации, качество графики. Сам дом и его 10 украшений строят наследники:
##   room_owl.gd — дупло совёнка, room_axolotl.gd — подводный грот,
##   room_puppy.gd — будка в ночном саду, room_kitten.gd — чердак котика.
##
## Места украшений — те же 6, что в 2D-доме (scripts/meta.gd SPOTS): floor_l, floor_r, wall_l,
## wall_r, hang, near. Поэтому купленное, поставленное и примерка (tryon.gd) переносятся как есть.
## Пол / рядом: вещь стоит на полу. Стена: в доме есть полочка-уступ; «плоские» вещи (скворечник,
## картина, табличка, звезда) висят на стене над ней, остальные стоят на ней.
## Сверху: на нитке/верёвке с покачиванием (hang_style = "rope") или на высокой полке ("shelf").
##
## 0.15 (украшение комнаты): мест в доме может быть до 16 — список и их типы в каталоге
## (scripts/decor_data/<дом>.gd SPOTS), координаты — в комнате (spots в _init наследника):
##   spots[id] = {"pos": Vector3 (точка, где вещь стоит / крепится), "yaw": поворот (+Z — в комнату),
##                "mark": точка метки «+» (в координатах места, по умолчанию (0, 0.3, 0)),
##                "stand": где на полочке стоит вещь (для wall / shelf)}
## Типы мест: floor / near / big — на полу; wall — полочка на стене (плоские вещи висят на стене);
## shelf — полочка (_ledge), вещь всегда стоит; hang — сверху (hang_style); window — на подоконнике
## (полочку не строим: подоконник — часть комнаты; вещь стоит, sk = "ledge").
## Поворот вещи (шаги по 45°) — set_placed(pl, rot). Стиль комнаты — set_style({walls, floor, light}):
## вызывает apply_walls(id) / apply_floor(id) / apply_light(id). Базовые версии красят то, что комната
## отметила в wall_parts / floor_parts (оттенок tint из каталога), и меняют свет (ambient, energy, lamp).
## Комната может переопределить их и сделать свои варианты (другие сетки, узоры) — см. room_kitten.gd.
## Метки «+» пустых мест видны только в режиме украшения (set_markers(true)).

const HeroCard := preload("res://scripts/home3d/hero_card.gd")
const TrophyShelf := preload("res://scripts/home3d/trophy_shelf.gd")
const OrbitCam := preload("res://scripts/home3d/orbit_camera.gd")
const Meta := preload("res://scripts/meta.gd")
const Catalog := preload("res://scripts/decor_catalog.gd")

## Вещи, которые висят на стене (не стоят на полочке)
const FLAT_WALL := ["owl_birdhouse", "owl_hammock", "axo_starfish", "pup_sign", "kit_picture", "pup_pinwheel"]
## Вещи со своей верёвкой/креплением сверху (точка места — точка подвеса)
const SELF_HUNG := ["owl_swing", "owl_moon", "owl_garland", "axo_lily", "pup_kite"]
## Высота вещи, которая вешается на нитку (верх вещи — на конце нитки)
const HANG_H := {"owl_lantern": 0.6, "axo_bubble": 0.62, "pup_lamp": 0.62}
## Размер пикселя «картонки» героя (м) при картинке 512: совёнок ~0.8 м
const HPS := 0.0024
## Сколько точечных светильников горит одновременно (в GL Compatibility каждый свет — ещё один проход
## по освещённым предметам): главный + несколько; остальные светящиеся вещи светятся сами (сияние)
const LIGHTS_HIGH := 4
const LIGHTS_SIMPLE := 2

var kind := "owl"
var stage := 0
var placed := {}
## 0.15: повороты вещей на местах (место -> шаги по 45°)
var rots := {}
## 0.15: стиль комнаты (слой -> id варианта) и что красить: детали стен и пола (их не склеивают с остальным)
var style := {}
var wall_parts: Array = []
var floor_parts: Array = []
## Исходный свет окружения (до стиля «свет»)
var _env0 := {}
var _light_k := 1.0
var _lamp_tint := Color(1, 1, 1)
var outfit := {}
var high := true
var markers_on := false
var highlight := ""
var hang_style := "rope"
## Длина нитки для подвеса
var rope_len := 0.55

var cam: Camera3D
var card: Node2D
var card_vp: SubViewport
var hero_sprite: Sprite3D
var hero_feet := Vector3.ZERO
var hero_bob := 0.0
var env: Environment
var world_env: WorldEnvironment
## Свет, который отбрасывает тень в высоком качестве
var shadow_light: Light3D
## Места: spot -> {pos: Vector3, yaw: float, mark: Vector3 (точка метки «+» в координатах места)}
var spots := {}
var spot_nodes := {}
var spot_anims := {}
var spot_lights := {}
## spot -> [центр вещи (мир), расстояние камеры]
var spot_focus := {}
var markers := {}
var ring: MeshInstance3D
## Другие интересные места для двойного тапа: [точка, расстояние, имя]
var features := []
var built := false
## Мягкий свет «от камеры»: включается, когда камера подлетела к вещи (вещь в тёмном углу видно)
var cam_light: OmniLight3D
var _t := 0.0
var _house: Node3D
## 0.14: полка славы (scripts/home3d/trophy_shelf.gd). shelf_def задаёт комната в _init:
## {style, pos (у стены, на полу), yaw (+Z — в комнату), rows [[высота, радиус стены]], room_r, spacing, scale,
##  depth, focus_d — с какого расстояния смотреть на один кубок, view_d — на всю полку;
##  0.18: look_d — где стоять в обзоре от первого лица (от середины полки), щипком — от LOOK_D_MIN до view_d}
var shelf_def := {}
var shelf
## 0.18: кубок, выбранный касанием в обзоре полки (подпись сверху; 0 — нет)
var look_hall := 0
const LOOK_D := 1.25
## Глаза чуть выше середины полки: полка — посередине между подписью сверху и кнопками снизу
const LOOK_EYE := 0.05
const LOOK_D_MIN := 0.75
## Полученные кубки (номера залов) и ещё не «появившиеся» (показ при возвращении домой)
var trophies_done: Array = []
var trophies_hidden: Array = []
## Яркость кубков в этой комнате (кубки светятся сами, без ламп)
var trophy_light := 1.0


# ---------- То, что задают наследники ----------

func _environment() -> void:
	pass


func _build_house(_root: Node3D) -> void:
	pass


## Построить украшение id в узле n (начало координат — точка, где вещь стоит / крепится).
## sk — вид места: "floor", "wall", "hang", "near".
func _decor(_id: String, _n: Node3D, _sk: String) -> void:
	pass


func _setup_camera(_c: Camera3D) -> void:
	pass


func _inside(_p: Vector3) -> bool:
	return true


## Откуда смотреть на точку при подлёте (по умолчанию — из центра комнаты наружу к стене)
func _view_dir(at: Vector3, is_hero := false, turn := 0.55) -> Vector3:
	if is_hero:
		return cam.global_position - at
	var side := cam.global_position - at
	side.y = 0
	if Vector2(at.x, at.z).length() < 1.4:
		var out := Vector3(at.x, 0, at.z).normalized()
		return (out + side.normalized()).normalized()
	# к стене — из глубины комнаты, но чуть сбоку, чтобы герой в центре не загораживал
	var inward := Vector3(-at.x, 0, -at.z).normalized()
	return inward.rotated(Vector3.UP, turn if inward.cross(side).y > 0.0 else -turn)


# ---------- Сборка ----------

func setup(k: String, st: int, pl: Dictionary, of: Dictionary, hq: bool, rt := {}, sty := {}) -> void:
	kind = k
	stage = clampi(st, 0, 3)
	placed = pl.duplicate()
	rots = rt.duplicate()
	style = sty.duplicate()
	outfit = of.duplicate()
	high = hq


## 0.15: места этого дома, которые есть и в каталоге, и в комнате (порядок — как в каталоге)
func spot_list() -> Array:
	return Catalog.spot_ids(kind).filter(func(s): return spots.has(s))


func build() -> void:
	_environment()
	_house = node(self)
	_house.name = "house"
	_build_house(_house)
	_hero()
	var moving := []
	for a in anims:
		moving.append(a.n)
	# 0.15: стены и пол склеиваются отдельно (их красит стиль комнаты)
	for p in wall_parts + floor_parts:
		if is_instance_valid(p):
			merge_static(p, moving)
			moving.append(p)
	merge_static(_house, moving)
	_capture_env()
	for spot in spot_list():
		_place(spot)
	_markers()
	_build_shelf()
	_camera()
	built = true
	var sty := style.duplicate()
	style = {}
	set_style(sty)
	set_quality(high)


## Сменить украшения (примерка, покупка, поворот): перестраиваются только изменившиеся места
func set_placed(pl: Dictionary, rt = null) -> void:
	for spot in spot_list():
		var id: String = pl.get(spot, "")
		var r := int(rt.get(spot, 0)) if rt is Dictionary else int(rots.get(spot, 0))
		if id != placed.get(spot, "") or r != int(rots.get(spot, 0)):
			placed[spot] = id
			if r == 0:
				rots.erase(spot)
			else:
				rots[spot] = r
			_place(spot)
			_update_markers()


# ---------- 0.15: стиль комнаты ----------

## Сменить стиль комнаты: вызываются apply_* только у изменившихся слоёв
func set_style(st: Dictionary) -> void:
	for l in Catalog.LAYERS:
		var id: String = st.get(l, "")
		if id == "":
			id = Catalog.default_room(kind).get(l, "")
		if id != style.get(l, "") or not style.has(l):
			style[l] = id
			if built:
				call("apply_" + l, id)


## Стены: базово — оттенок tint на деталях wall_parts
func apply_walls(id: String) -> void:
	_tint_parts(wall_parts, Catalog.room_item(id).get("tint", Color(1, 1, 1)), "tint")


## Пол: базово — оттенок tint на деталях floor_parts
func apply_floor(id: String) -> void:
	_tint_parts(floor_parts, Catalog.room_item(id).get("tint", Color(1, 1, 1)), "tint")


## Свет: оттенок и яркость рассеянного света, оттенок и яркость ламп дома и украшений
func apply_light(id: String) -> void:
	var it := Catalog.room_item(id)
	var amb: Color = it.get("ambient", Color(1, 1, 1))
	_light_k = float(it.get("energy", 1.0))
	_lamp_tint = it.get("lamp", Color(1, 1, 1))
	if env and not _env0.is_empty():
		env.ambient_light_color = _env0.amb * amb
		env.ambient_light_energy = _env0.amb_e * _light_k
		env.fog_light_color = _env0.fog * amb
	_tint_lights()


func _capture_env() -> void:
	if env:
		_env0 = {"amb": env.ambient_light_color, "amb_e": env.ambient_light_energy, "fog": env.fog_light_color}


## Окрасить детали: StandardMaterial3D — копия с albedo × tint; ShaderMaterial — копия с параметром param
## (в шейдере должен быть uniform vec3 <param>). Исходный материал хранится в meta "m0" детали.
func _tint_parts(parts: Array, tint: Color, param: String) -> void:
	for p in parts:
		if not is_instance_valid(p):
			continue
		var list: Array = [p] if p is GeometryInstance3D else []
		list.append_array((p as Node).find_children("*", "GeometryInstance3D", true, false))
		for gi in list:
			var g3 := gi as GeometryInstance3D
			if not g3.has_meta("m0"):
				if g3.material_override == null:
					continue
				g3.set_meta("m0", g3.material_override)
			g3.material_override = _tinted(g3.get_meta("m0"), tint, param)


static var _tint_cache := {}


static func _tinted(m0: Material, tint: Color, param: String) -> Material:
	if tint == Color(1, 1, 1):
		return m0
	var key := [m0, tint, param]
	if _tint_cache.has(key):
		return _tint_cache[key]
	var m: Material = m0.duplicate()
	if m is StandardMaterial3D:
		(m as StandardMaterial3D).albedo_color = (m0 as StandardMaterial3D).albedo_color * tint
	elif m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter(param, Vector3(tint.r, tint.g, tint.b))
	_tint_cache[key] = m
	return m


## Лампы дома и украшений: исходные цвет и яркость (meta "c0", "e0") × оттенок и яркость стиля «свет»
func _tint_lights() -> void:
	var lists: Array = [lights]
	for s in spot_lights:
		lists.append(spot_lights[s])
	for list in lists:
		for l in list:
			var light: Light3D = l[0]
			if not light.has_meta("e0"):
				light.set_meta("e0", float(l[1]))
			l[1] = float(light.get_meta("e0")) * _light_k
	var all: Array = _house.find_children("*", "Light3D", true, false) if _house else []
	for s in spot_nodes:
		if is_instance_valid(spot_nodes[s]):
			all.append_array((spot_nodes[s] as Node).find_children("*", "Light3D", true, false))
	for light in all:
		if not light.has_meta("c0"):
			light.set_meta("c0", light.light_color)
		if not light.has_meta("e0"):
			light.set_meta("e0", light.light_energy)
		light.light_color = (light.get_meta("c0") as Color) * _lamp_tint
		light.light_energy = float(light.get_meta("e0")) * _light_k


func set_outfit(of: Dictionary) -> void:
	outfit = of.duplicate()
	if card:
		card.outfit = outfit


func set_highlight(spot: String) -> void:
	highlight = spot
	if ring:
		ring.visible = spot != "" and spots.has(spot)
		if ring.visible:
			ring.position = spot_point(spot)
		_update_markers()


## 0.15: метки «+» пустых мест (и полочки новых мест-полок) — только в режиме украшения
func set_markers(on: bool) -> void:
	if markers_on == on:
		return
	markers_on = on
	if built:
		for spot in spot_list():
			if placed.get(spot, "") == "" and spot_kind(spot) == "shelf":
				_place(spot)
	_update_markers()


func set_quality(hq: bool) -> void:
	high = hq
	if env:
		env.glow_enabled = hq
	for l in find_children("*", "Light3D", true, false):
		(l as Light3D).shadow_enabled = hq and l == shadow_light
	_light_budget()
	_shadow_casters()
	TrophyShelf.set_trophy_quality(hq, trophy_light)
	if shelf:
		shelf.set_high(hq)
	if card_vp:
		var sz := 512 if hq else 320
		card_vp.size = Vector2i(sz, sz)
		card.size = sz
		hero_sprite.pixel_size = HPS * 512.0 / sz
		_place_hero_sprite()


func poke_hero() -> void:
	if card:
		card.poke()


# ---------- Места украшений ----------

func spot_kind(spot: String) -> String:
	return Catalog.spot_kind(spot, kind)


## Точка метки «+» / кольца примерки / центр вещи на месте (мир)
func spot_point(spot: String) -> Vector3:
	if spot_focus.has(spot):
		return spot_focus[spot][0]
	var sp: Dictionary = spots[spot]
	var b := Basis(Vector3.UP, sp.yaw)
	return sp.pos + b * (sp.get("mark", Vector3(0, 0.3, 0)) as Vector3)


func _clear_spot(spot: String) -> void:
	if spot_nodes.has(spot):
		var n: Node = spot_nodes[spot]
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.queue_free()
		spot_nodes.erase(spot)
	spot_anims.erase(spot)
	spot_lights.erase(spot)
	spot_focus.erase(spot)


## Полочка-уступ на стене (у котика — и высокая полка «сверху»): своя у каждого дома
func _ledge(_n: Node3D, _spot: String) -> void:
	pass


## Висит ли вещь на стене этого места (иначе стоит на полочке). 0.15: или "flat" в каталоге
func _is_flat(id: String, _spot: String) -> bool:
	return FLAT_WALL.has(id) or Meta.item(id).get("flat", false)


func _place(spot: String) -> void:
	_clear_spot(spot)
	if not spots.has(spot):
		return
	var id: String = placed.get(spot, "")
	if id != "" and Meta.item(id).get("home", "") != kind:
		id = ""
	var sp: Dictionary = spots[spot]
	var sk := spot_kind(spot)
	var shelf := sk == "wall" or sk == "shelf" or (sk == "hang" and hang_style == "shelf")
	# полочки пустых новых мест-полок видны только в режиме украшения (иначе пустые полочки загромождают стены);
	# старые места («стена», верхняя полка котика) — как раньше: полочка всегда, она часть дома
	if id == "" and not (shelf and (sk != "shelf" or markers_on or Meta.SPOTS.has(spot))):
		return
	var n := node(self, sp.pos, sp.yaw)
	n.name = "spot_" + spot
	spot_nodes[spot] = n
	var saved_a := anims
	var saved_l := lights
	anims = []
	lights = []
	var flat := id != "" and sk == "wall" and _is_flat(id, spot)
	if shelf and not flat:
		_ledge(n, spot)
	if id != "":
		var item := n
		var turn := int(rots.get(spot, 0)) * PI / 4.0
		var it_data := Meta.item(id)
		if sk == "hang" and hang_style == "rope" and not (SELF_HUNG.has(id) or it_data.get("self_hung", false)):
			# нитка от точки подвеса; вещь покачивается вместе с ней (0.15: высота вещи — "hang_h" в каталоге)
			var pend := node(n)
			anim(pend, "pendulum", {"amp": 0.05, "spd": 1.1})
			var hl: float = HANG_H.get(id, float(it_data.get("hang_h", 0.5)))
			put(pend, cyl(0.008, 0.008, rope_len, 4), mat(Color("#C9B88A"), 1.0, 0.0, false), Vector3(0, -rope_len * 0.5, 0))
			item = node(pend, Vector3(0, -rope_len - hl, 0), turn)
		elif shelf and not flat:
			item = node(n, sp.get("stand", Vector3(0, 0.06, 0.22)), turn)
			sk = "ledge"  # стоит на полочке
		elif sk == "window":
			item = node(n, sp.get("stand", Vector3.ZERO), turn)
			sk = "ledge"  # стоит на подоконнике
		elif not flat and turn != 0.0:
			item = node(n, Vector3.ZERO, turn)
		var kids := item.get_child_count()
		_decor(id, item, sk)
		if item.get_child_count() == kids:
			_placeholder(id, item)  # 0.15: у новой вещи ещё нет 3D — коробочка цвета её стиля
	var moving := []
	for a in anims:
		moving.append(a.n)
	merge_static(n, moving)
	spot_anims[spot] = anims
	spot_lights[spot] = lights
	anims = saved_a
	lights = saved_l
	if id != "":
		# центр вещи и расстояние для подлёта — по её рамке
		var box_ := _local_aabb(n)
		var c := n.transform * box_.get_center()
		var d := clampf(box_.size.length() * 1.5, 1.0, 2.2)
		spot_focus[spot] = [c, d]
	if built:
		_tint_lights()
		_light_budget()
		_shadow_casters()
		set_highlight(highlight)


## Заготовка вещи без своего 3D (данные в каталоге уже есть, рисунка ещё нет): коробочка с лентой цвета стиля
func _placeholder(id: String, n: Node3D) -> void:
	var col := Catalog.style_col(Meta.item(id).get("style", ""))
	put(n, box(Vector3(0.3, 0.26, 0.3)), mat(col.darkened(0.1)), Vector3(0, 0.13, 0))
	put(n, box(Vector3(0.32, 0.27, 0.07)), mat(col.lightened(0.45)), Vector3(0, 0.135, 0))
	put(n, sphere(0.06, 10), mat(Color("#FFE9B0"), 0.6, 0.6, false), Vector3(0, 0.3, 0))


func _local_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for gi in n.find_children("*", "GeometryInstance3D", true, false):
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh is QuadMesh:
			continue  # сияние-«картонка» не считается
		var bb: AABB = (gi as VisualInstance3D).get_aabb()
		var xf := _rel_xf(n, gi)
		var tb := xf * bb
		if first:
			out = tb
			first = false
		else:
			out = out.merge(tb)
	if first:
		return AABB(Vector3(-0.2, 0, -0.2), Vector3(0.4, 0.4, 0.4))
	return out


## Меткам и кольцу нужен шейдер с «всегда к камере»; у каждой метки — свой материал (мигание)
func _markers() -> void:
	for spot in spot_list():
		var m := Shaders.material("marker", {"col": Color(1.0, 0.9, 0.55, 0.9), "mode": 0.0, "px": 0.046})
		var mi := put(self, quad(Vector2(1, 1)), m, Vector3.ZERO)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 2.0
		mi.name = "mark_" + spot
		markers[spot] = mi
	var rm := Shaders.material("marker", {"col": Color(1.0, 0.84, 0.4, 0.95), "mode": 1.0, "px": 0.11})
	ring = put(self, quad(Vector2(1, 1)), rm, Vector3.ZERO)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.extra_cull_margin = 2.0
	ring.name = "tryon_ring"
	ring.visible = false
	_update_markers()


func _update_markers() -> void:
	for spot in markers:
		var mi: MeshInstance3D = markers[spot]
		mi.visible = markers_on and placed.get(spot, "") == "" and spot != highlight
		if mi.visible:
			mi.position = spot_point(spot)  # метки — прямые дети комнаты (комната в начале координат)


# ---------- Полка славы (0.14) ----------

func _build_shelf() -> void:
	if shelf_def.is_empty():
		return
	shelf = TrophyShelf.new()
	shelf.name = "trophy_shelf"
	shelf.position = shelf_def.pos
	shelf.rotation.y = shelf_def.yaw
	shelf.setup(shelf_def, trophies_done, high)
	shelf.hidden = trophies_hidden.duplicate()
	add_child(shelf)
	shelf.build()


## Кубки изменились (новый зал пройден, показ закончился): перестраиваются только кубки, не полка
func set_trophies(done: Array, hidden_: Array) -> void:
	trophies_done = done.duplicate()
	trophies_hidden = hidden_.duplicate()
	if shelf:
		shelf.set_done(done, hidden_)


## Показ: кубки появляются с блеском, камера подлетает к полке
func reveal_trophies(halls: Array) -> void:
	if shelf == null:
		return
	for n in halls:
		trophies_hidden.erase(n)
	shelf.reveal(halls)
	focus_shelf()


## 0.18: обзор полки от первого лица: камера встаёт перед серединой полки и смотрит на неё
## (уже стоит — взгляд плавно прямо, выбор кубка снят)
func focus_shelf() -> void:
	if shelf == null:
		return
	shelf.set_spin(0)
	look_hall = 0
	var v := look_view()
	cam.look_enter(shelf.center(), shelf.facing(), v.x, v.y, v.z, LOOK_EYE)


## Где стоять в обзоре: (расстояние от середины полки, ближе всего, дальше всего) — только внутри комнаты
func look_view() -> Vector3:
	var c: Vector3 = shelf.center() + Vector3(0, LOOK_EYE, 0)
	var back: Vector3 = shelf.facing()
	back.y = 0.0
	back = back.normalized()
	var far_d: float = shelf_def.get("view_d", 1.9)
	var d: float = shelf_def.get("look_d", LOOK_D)
	var guard := 0
	while not _inside(c + back * far_d) and far_d > LOOK_D_MIN and guard < 60:
		far_d -= 0.03
		guard += 1
	d = minf(d, far_d)
	while not _inside(c + back * d) and d > 0.4 and guard < 120:
		d -= 0.03
		guard += 1
	return Vector3(d, minf(LOOK_D_MIN, d), maxf(far_d, d))


## Кубок зала n: в обзоре полки — его название в подписи, взгляд плавно поворачивается к нему (без перелёта),
## кубок медленно крутится на подставке. Из обычного обзора дома — сначала встаём к полке.
func focus_trophy(n: int) -> void:
	if shelf == null:
		return
	if not cam.look_mode:
		focus_shelf()
	look_hall = clampi(n, 1, 10)
	shelf.set_spin(look_hall if shelf.has_trophy(look_hall) else 0)
	cam.look_toward(shelf.slot_center(look_hall))


## Какой кубок выбран в обзоре полки (0 — никакой)
func focused_trophy() -> int:
	if shelf == null or not cam.look_mode:
		return 0
	return look_hall


## Камера у полки (обзор от первого лица)
func focused_shelf() -> bool:
	return shelf != null and cam.look_mode


## 0.18: кнопка «Прямо»: взгляд плавно в середину полки (выбранный кубок остаётся в подписи)
func look_center() -> void:
	if shelf != null and cam.look_mode:
		cam.look_center()


## Кубок под пальцем (только кубки — для обзора полки); нет — пусто
func pick_trophy(pos: Vector2, radius := 110.0) -> Dictionary:
	var best := {}
	var best_d := radius
	if shelf == null:
		return best
	for n in range(1, 11):
		var p: Vector3 = shelf.slot_center(n)
		if cam.is_position_behind(p):
			continue
		var d := cam.unproject_position(p).distance_to(pos)
		if d < best_d:
			best_d = d
			best = {"type": "trophy", "hall": n, "at": p}
	return best


# ---------- Герой ----------

func _hero() -> void:
	card_vp = SubViewport.new()
	card_vp.size = Vector2i(512, 512)
	card_vp.transparent_bg = true
	card_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	card_vp.disable_3d = true
	add_child(card_vp)
	card = HeroCard.new()
	card.kind = kind
	card.outfit = outfit
	card_vp.add_child(card)
	hero_sprite = Sprite3D.new()
	hero_sprite.texture = card_vp.get_texture()
	hero_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	hero_sprite.pixel_size = HPS
	hero_sprite.shaded = false
	hero_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	hero_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	hero_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hero_sprite.modulate = Color(1.0, 0.97, 0.94)
	hero_sprite.name = "hero"
	add_child(hero_sprite)
	_place_hero_sprite()
	# мягкая тень под героем
	var g := Gradient.new()
	g.set_color(0, Color(0.08, 0.04, 0.12, 0.6))
	g.set_color(1, Color(0.08, 0.04, 0.12, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.8, 0.6)
	var sh := put(self, pm, m, hero_feet + Vector3(0, 0.02 - hero_bob * 0.0, 0))
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sh.name = "hero_shadow"


func _place_hero_sprite() -> void:
	if hero_sprite == null:
		return
	var sz := float(card_vp.size.y)
	hero_sprite.position = hero_feet + Vector3(0, (HeroCard.FEET - 0.5) * sz * hero_sprite.pixel_size, 0)


func hero_center() -> Vector3:
	return hero_feet + Vector3(0, 0.38, 0)


# ---------- Камера и касания ----------

func _camera() -> void:
	cam = Camera3D.new()
	cam.set_script(OrbitCam)
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 60.0
	cam.inside = _inside
	_setup_camera(cam)
	add_child(cam)
	cam.current = true
	cam.reset_view()
	cam_light = OmniLight3D.new()
	cam_light.light_color = Color("#FFF1E0")
	cam_light.light_energy = 0.0
	cam_light.omni_range = 3.2
	cam_light.omni_attenuation = 1.5
	cam_light.visible = false
	cam_light.name = "cam_light"
	cam.add_child(cam_light)


## Что под пальцем: {"type": "hero"/"spot"/"feature", "spot", "at", "d"}; пусто — ничего
func pick(pos: Vector2, radius := 110.0) -> Dictionary:
	var best := {}
	var best_d := radius
	var cands := []
	cands.append({"type": "hero", "at": hero_center(), "d": 1.45})
	for spot in spots:
		if placed.get(spot, "") == "" and not markers_on:
			continue
		var f: Array = spot_focus.get(spot, [spot_point(spot), 1.3])
		cands.append({"type": "spot", "spot": spot, "at": f[0], "d": f[1]})
	for f in features:
		cands.append({"type": "feature", "name": f[2], "at": f[0], "d": f[1]})
	if shelf:
		for n in range(1, 11):
			cands.append({"type": "trophy", "hall": n, "at": shelf.slot_center(n), "d": shelf_def.get("focus_d", 0.7)})
	for c in cands:
		var p: Vector3 = c.at
		if cam.is_position_behind(p):
			continue
		var d := cam.unproject_position(p).distance_to(pos)
		# герой крупный: его «зона» шире
		if c.type == "hero":
			d *= 0.6
		if d < best_d:
			best_d = d
			best = c
	return best


func focus(c: Dictionary) -> void:
	if c.is_empty():
		cam.fly_home()
		return
	if c.get("spot", "") != "":
		focus_spot(c.spot)
		return
	if c.type == "trophy":
		focus_trophy(c.hall)
		return
	if shelf:
		shelf.set_spin(0)
	cam.fly_to(c.at, _view_dir(c.at, c.type == "hero"), c.d)


## С какой стороны смотреть на вещь «сверху» (камера под ней): по умолчанию — со стороны центра комнаты
func _hang_view_dir(at: Vector3) -> Vector3:
	var to_c := Vector3(-at.x, 0, -at.z)
	if to_c.length() < 0.3:
		to_c = cam.global_position - at
	return to_c


## Подлететь к месту: к подвесу — снизу (камера ниже вещи и смотрит вверх)
func focus_spot(spot: String) -> void:
	if not spots.has(spot):
		return
	var f: Array = spot_focus.get(spot, [spot_point(spot), 1.3])
	var sk := spot_kind(spot)
	if sk == "hang" and hang_style == "rope":
		# подвес — снизу, со стороны центра комнаты (камера ниже вещи и смотрит вверх)
		var at: Vector3 = f[0]
		cam.fly_to(at, _hang_view_dir(at), maxf(f[1], 2.0), -0.42)
	elif sk == "floor" or sk == "near":
		# на пол смотрим чуть сверху и вдоль стены — чтобы ковёр и мелочи на полу не заслоняли вещь
		cam.fly_to(f[0], _view_dir(f[0], false, 1.05), maxf(f[1], 1.45), 0.42)
	else:
		cam.fly_to(f[0], _view_dir(f[0]), maxf(f[1], 1.3), 0.14)


func is_focused_on(at: Vector3) -> bool:
	return cam.focused and cam.goal_pivot.distance_to(at) < 0.05


## Где место украшения на картинке (пиксели SubViewport); за камерой — Vector2(-1, -1)
func spot_screen(spot: String) -> Vector2:
	var p := spot_point(spot)
	if cam == null or cam.is_position_behind(p):
		return Vector2(-1, -1)
	return cam.unproject_position(p)


## Включены: главный свет, потом свет дома, потом свет украшений — пока не кончится запас
func _light_budget() -> void:
	var order := []
	if shadow_light != null:
		order.append(shadow_light)
	for l in _house.find_children("*", "Light3D", true, false) if _house else []:
		if not order.has(l):
			order.append(l)
	for spot in spot_list():
		if spot_nodes.has(spot) and is_instance_valid(spot_nodes[spot]):
			for l in (spot_nodes[spot] as Node).find_children("*", "Light3D", true, false):
				order.append(l)
	var left := LIGHTS_HIGH if high else LIGHTS_SIMPLE
	for l in order:
		if l is DirectionalLight3D:
			l.visible = true
			continue
		l.visible = left > 0
		left -= 1


# ---------- Тени ----------

func _shadow_casters() -> void:
	for gi in find_children("*", "GeometryInstance3D", true, false):
		var on := false
		if high and shadow_light != null:
			for c in casters:
				if is_instance_valid(c) and (c == gi or (c as Node).is_ancestor_of(gi)):
					on = true
					break
			if not on:
				for s in spot_nodes.values():
					if is_instance_valid(s) and (s as Node).is_ancestor_of(gi) and gi is MeshInstance3D and not (gi as MeshInstance3D).mesh is QuadMesh:
						on = true
						break
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------- Анимация ----------

func _process(delta: float) -> void:
	_t += delta
	_animate(anims)
	for s in spot_anims:
		_animate(spot_anims[s])
	if shelf:
		_animate(shelf.anims)
		if shelf.spin_hall != 0 and focused_trophy() != shelf.spin_hall:
			shelf.set_spin(0)
	_light_anim(lights)
	for s in spot_lights:
		_light_anim(spot_lights[s])
	if cam_light:
		cam_light.light_energy = move_toward(cam_light.light_energy, 0.55 if cam.focused else 0.0, delta * 1.5)
		cam_light.visible = cam_light.light_energy > 0.01
	if hero_sprite and cam:
		# камера вплотную к «картонке» — прячем её, чтобы не закрывала экран
		hero_sprite.visible = cam.global_position.distance_to(hero_center()) > 0.5
	if hero_sprite and hero_bob > 0.0:
		_place_hero_sprite()
		hero_sprite.position.y += sin(_t * 1.4) * hero_bob
	if ring and ring.visible:
		var m: ShaderMaterial = ring.material_override
		m.set_shader_parameter("pulse", 0.5 + 0.5 * sin(_t * 5.0))
	for spot in markers:
		var mi: MeshInstance3D = markers[spot]
		if mi.visible:
			var m: ShaderMaterial = mi.material_override
			m.set_shader_parameter("col", Color(1.0, 0.9, 0.55, 0.62 + 0.3 * sin(_t * 2.5 + spot.length())))


func _light_anim(list: Array) -> void:
	for l in list:
		var light: Light3D = l[0]
		var base: float = l[1]
		match l[2]:
			"flicker":
				light.light_energy = base * (1.0 + 0.06 * sin(_t * 11.0) + 0.04 * sin(_t * 23.0))
			"pulse":
				light.light_energy = base * (1.0 + 0.15 * sin(_t * 2.0))
			"slow":
				light.light_energy = base * (1.0 + 0.1 * sin(_t * 0.8))


func _animate(list: Array) -> void:
	var t := _t
	for a in list:
		var nd: Node3D = a.n
		if not is_instance_valid(nd):
			continue
		var ph: float = a.p
		var b: Transform3D = a.base
		match a.k:
			"flame":
				var s := 1.0 + 0.12 * sin(t * 13.0 + ph) + 0.06 * sin(t * 31.0 + ph)
				nd.transform = Transform3D(b.basis * Basis.from_scale(Vector3(s, 1.0 + (s - 1.0) * 1.5, s)), b.origin)
			"pulse":
				var amp: float = a.get("amp", 0.03)
				nd.transform = Transform3D(b.basis * Basis.from_scale(Vector3.ONE * (1.0 + amp * sin(t * a.get("spd", 2.0) + ph))), b.origin)
			"sway":
				var amp: float = a.get("amp", 0.06)
				var spd: float = a.get("spd", 1.1)
				nd.transform = Transform3D(b.basis * Basis.from_euler(Vector3(amp * 0.6 * sin(t * spd * 0.8 + ph + 1.0), 0, amp * sin(t * spd + ph))), b.origin)
			"pendulum":
				var amp: float = a.get("amp", 0.06)
				var spd: float = a.get("spd", 1.2)
				nd.transform = Transform3D(b.basis * Basis.from_euler(Vector3(amp * 0.5 * sin(t * spd * 0.7 + ph), 0, amp * sin(t * spd + ph))), b.origin)
			"swing":
				var amp: float = a.get("amp", 0.25)
				nd.transform = Transform3D(b.basis * Basis(Vector3.RIGHT, amp * sin(t * a.get("spd", 1.6) + ph)), b.origin)
			"spin":
				var ax: Vector3 = a.get("axis", Vector3.UP)
				nd.transform = Transform3D(b.basis * Basis(ax, t * a.get("spd", 1.0) + ph), b.origin)
			"wiggle":
				var ax: Vector3 = a.get("axis", Vector3.UP)
				nd.transform = Transform3D(b.basis * Basis(ax, a.get("amp", 0.3) * sin(t * a.get("spd", 0.9) + ph)), b.origin)
			"bob":
				nd.transform = Transform3D(b.basis, b.origin + Vector3(0, a.get("amp", 0.03) * sin(t * a.get("spd", 1.5) + ph), 0))
			"hop":
				var u := absf(sin(t * a.get("spd", 2.2) + ph))
				var hgt: float = a.get("h", 0.12)
				var sq := 1.0 - 0.18 * smoothstep(0.25, 0.0, u)
				nd.transform = Transform3D(b.basis * Basis.from_scale(Vector3(2.0 - sq, sq, 2.0 - sq)), b.origin + Vector3(0, u * hgt, 0))
			"hinge":
				var o := clampf(sin(t * a.get("spd", 0.8) + ph) * 2.0, 0.0, 1.0)
				var ax: Vector3 = a.get("axis", Vector3.RIGHT)
				nd.transform = Transform3D(b.basis * Basis(ax, -o * a.get("ang", 1.0)), b.origin)
			"peek":
				var pk := clampf(sin(t * a.get("spd", 0.7) + ph) * 3.0 - 1.5, 0.0, 1.0)
				nd.transform = Transform3D(b.basis, b.origin + Vector3(0, (pk - 1.0) * a.get("h", 0.12), 0))
				nd.visible = pk > 0.02
			"orbit":
				var r: float = a.get("r", 0.08)
				var spd: float = a.get("spd", 0.9)
				var ang := t * spd + ph
				nd.transform = Transform3D(Basis(Vector3.UP, -ang + (PI if spd > 0.0 else 0.0)) * b.basis, b.origin + Vector3(cos(ang) * r, 0.015 * sin(t * 2.0 + ph), sin(ang) * r))
			"drift":
				var am: Vector3 = a.get("amp", Vector3(0.15, 0.1, 0.05))
				var off := Vector3(am.x * sin(t * 0.9 + ph), am.y * cos(t * 1.2 + ph), am.z * sin(t * 0.7 + ph))
				nd.transform = Transform3D(b.basis * Basis(Vector3.FORWARD, a.get("tilt", 0.12) * sin(t * 1.1 + ph)), b.origin + off)
			"roll":
				var u := sin(t * a.get("spd", 0.8) + ph)
				var dx: float = a.get("dx", 0.06)
				nd.transform = Transform3D(Basis(Vector3.BACK, -u * dx / a.get("r", 0.1)) * b.basis, b.origin + Vector3(u * dx, 0, 0))
			"flag":
				nd.transform = Transform3D(b.basis * Basis.from_scale(Vector3(1.0 + 0.18 * sin(t * 6.0 + ph), 1.0, 1.0)) * Basis(Vector3.UP, 0.25 * sin(t * 4.0 + ph)), b.origin)
			"bulb":
				var m: StandardMaterial3D = (nd as MeshInstance3D).material_override
				m.emission_energy_multiplier = a.get("e0", 1.6) + a.get("e1", 1.0) * sin(t * a.get("spd", 2.2) + ph * 1.3)
			"rise":
				# пузырёк: поднимается от base на h и появляется снова
				var hgt: float = a.get("h", 0.4)
				var u := fposmod(t * a.get("spd", 0.3) + ph, 1.0)
				nd.transform = Transform3D(b.basis * Basis.from_scale(Vector3.ONE * (0.4 + 0.6 * u)), b.origin + Vector3(0.02 * sin(t * 3.0 + ph * 5.0), u * hgt, 0))
				nd.visible = u < 0.92
			"blink_eye":
				var bl := 1.0 if fposmod(t + ph, 4.0) > 0.15 else 0.1
				nd.transform = Transform3D(b.basis * Basis.from_scale(Vector3(1, bl, 1)), b.origin)
			"call":
				(a.f as Callable).call(nd, t, a)
