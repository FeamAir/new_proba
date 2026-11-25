extends Node3D
## Набор «игрушечных» 3D-деталей для домов (Cascado 0.12, развитие прототипа proto3d 0.11).
## Всё строится кодом из простых фигур Godot (шар, цилиндр, тор, коробка, призма) и своих сеток
## (трубка, тело вращения, вырезанная из «толстого картона» фигура). Стиль — «мягкая игрушка»:
## скруглённые формы, матовые материалы, тёмная обводка как у 2D-героев, светящиеся вещи сияют.
## Неподвижные детали в конце склеиваются по материалам (merge_static) — меньше вызовов отрисовки.

const Shaders := preload("res://scripts/home3d/shaders.gd")
const OUT := Color("#1E1236")

## Общие материалы и сетки на все комнаты (живут, пока идёт игра; это мегабайты, не десятки)
static var _mats := {}
static var _outline: StandardMaterial3D
static var _meshes := {}

## Детали, которые отбрасывают тень (остальные — нет: тень дорогая)
var casters := []
## Анимации: словари {n: узел, k: вид, p: фаза, ...}; base — исходное положение
var anims := []
## Светильники: [свет, базовая яркость, вид]
var lights := []


static func outline_mat() -> StandardMaterial3D:
	if _outline == null:
		_outline = StandardMaterial3D.new()
		_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline.grow = true
		_outline.grow_amount = 0.012
		_outline.albedo_color = OUT
	return _outline


static func mat(col: Color, rough := 0.85, emit := 0.0, outline := true, emit_col := Color(-1, 0, 0)) -> StandardMaterial3D:
	var key := [col, rough, emit, outline, emit_col]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic_specular = 0.25
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col if emit_col.r < 0.0 else emit_col
		m.emission_energy_multiplier = emit
	# мягкий «бархатный» край, как у игрушки
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	if outline:
		m.next_pass = outline_mat()
	_mats[key] = m
	return m


## Материал с цветом из вершин (стены, пол, сетки MultiMesh с цветами)
static func vmat(rough := 0.95, spec := 0.15) -> StandardMaterial3D:
	var key := ["v", rough, spec]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.metallic_specular = spec
	_mats[key] = m
	return m


static func glass(col: Color, emit: float) -> StandardMaterial3D:
	var key := ["g", col, emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = emit > 0.0
	m.emission = Color(col, 1.0)
	m.emission_energy_multiplier = emit
	m.roughness = 0.15
	m.metallic_specular = 0.7
	m.rim_enabled = true
	m.rim = 0.6
	_mats[key] = m
	return m


## Свечение без света (огонёк, лампочка): своя копия, если яркость будет меняться в анимации
static func glow_mat(col: Color, energy: float, own := false) -> StandardMaterial3D:
	if not own:
		return mat(col, 0.5, energy, false)
	var m := mat(col, 0.5, energy, false).duplicate()
	return m


func put(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func sphere(r: float, segs := 20) -> SphereMesh:
	var key := ["s", r, segs]
	if _meshes.has(key):
		return _meshes[key]
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(6, segs / 2)
	_meshes[key] = s
	return s


static func hemi(r: float, segs := 18) -> SphereMesh:
	var key := ["h", r, segs]
	if _meshes.has(key):
		return _meshes[key]
	var s := SphereMesh.new()
	s.radius = r
	s.height = r
	s.is_hemisphere = true
	s.radial_segments = segs
	s.rings = maxi(4, segs / 3)
	_meshes[key] = s
	return s


static func cyl(r_top: float, r_bot: float, h: float, segs := 18) -> CylinderMesh:
	var key := ["c", r_top, r_bot, h, segs]
	if _meshes.has(key):
		return _meshes[key]
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	_meshes[key] = c
	return c


static func box(size: Vector3) -> BoxMesh:
	var key := ["b", size]
	if _meshes.has(key):
		return _meshes[key]
	var b := BoxMesh.new()
	b.size = size
	_meshes[key] = b
	return b


static func prism(size: Vector3, left := 0.5) -> PrismMesh:
	var key := ["p", size, left]
	if _meshes.has(key):
		return _meshes[key]
	var p := PrismMesh.new()
	p.size = size
	p.left_to_right = left
	_meshes[key] = p
	return p


static func torus(r_in: float, r_out: float, segs := 28) -> TorusMesh:
	var key := ["t", r_in, r_out, segs]
	if _meshes.has(key):
		return _meshes[key]
	var t := TorusMesh.new()
	t.inner_radius = r_in
	t.outer_radius = r_out
	t.rings = segs
	t.ring_segments = 10
	_meshes[key] = t
	return t


static func capsule(r: float, h: float) -> CapsuleMesh:
	var key := ["k", r, h]
	if _meshes.has(key):
		return _meshes[key]
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 16
	c.rings = 6
	_meshes[key] = c
	return c


static func quad(size: Vector2) -> QuadMesh:
	var key := ["q", size]
	if _meshes.has(key):
		return _meshes[key]
	var q := QuadMesh.new()
	q.size = size
	_meshes[key] = q
	return q


func node(parent: Node3D, pos := Vector3.ZERO, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	return n


## Направление по кругу (угол a): точка на полу
static func dir(a: float) -> Vector3:
	return Vector3(cos(a), 0.0, sin(a))


## Поворот вокруг оси Y, при котором «перед» узла (+Z) смотрит в точку to (по горизонтали)
static func face_to(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, d.z)


static func face_center(a: float) -> float:
	var d := -dir(a)
	return atan2(d.x, d.z)


static func hash1(i: int, k: int) -> float:
	return fposmod(sin(i * 127.1 + k * 311.7) * 43758.5453, 1.0)


## Треугольник с нужной стороной «наружу» (Godot: лицевая сторона — по часовой стрелке)
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tv := b
		b = c
		c = tv
		var tc := cb
		cb = cc
		cc = tc
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


## Плоская фигура с толщиной (как вырезанная из толстого картона): звёзды, полумесяц, сердце
static func extrude(poly: PackedVector2Array, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(poly)
	var hz := depth * 0.5
	var w := Color.WHITE
	for s in [1.0, -1.0]:
		for i in range(0, idx.size(), 3):
			var a := Vector3(poly[idx[i]].x, poly[idx[i]].y, hz * s)
			var b := Vector3(poly[idx[i + 1]].x, poly[idx[i + 1]].y, hz * s)
			var c := Vector3(poly[idx[i + 2]].x, poly[idx[i + 2]].y, hz * s)
			tri(st, a, b, c, Vector3(0, 0, s), w, w, w)
	var ctr := Vector2.ZERO
	for p in poly:
		ctr += p
	ctr /= poly.size()
	for i in poly.size():
		var p0 := poly[i]
		var p1 := poly[(i + 1) % poly.size()]
		var mid := (p0 + p1) * 0.5
		var e := p1 - p0
		var n2 := Vector2(e.y, -e.x).normalized()
		if n2.dot(mid - ctr) < 0.0:
			n2 = -n2
		var n := Vector3(n2.x, n2.y, 0)
		var a := Vector3(p0.x, p0.y, hz)
		var b := Vector3(p1.x, p1.y, hz)
		var c := Vector3(p1.x, p1.y, -hz)
		var d := Vector3(p0.x, p0.y, -hz)
		tri(st, a, b, c, n, w, w, w)
		tri(st, a, c, d, n, w, w, w)
	st.index()
	st.generate_normals()
	return st.commit()


static func star_poly(r_out: float, r_in: float, n := 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := PI / 2.0 + i * PI / n
		var r := r_out if i % 2 == 0 else r_in
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


static func crescent_poly(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(-PI * 0.78, PI * 0.78, i / 16.0)
		pts.append(Vector2(-cos(a), sin(a)) * r)
	for i in range(16, -1, -1):
		var a := lerpf(-PI * 0.78, PI * 0.78, i / 16.0)
		pts.append(Vector2(-cos(a) * r * 0.5 - r * 0.25, sin(a) * r * 0.75))
	return pts


static func heart_poly(w: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var s := w / 16.0
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(Vector2(16.0 * pow(sin(a), 3), 13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a) + 3.0) * s)
	return pts


static func rrect_poly(w: float, h: float, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	rad = minf(rad, minf(w, h) * 0.49)
	var cs := [Vector2(w / 2 - rad, h / 2 - rad), Vector2(-w / 2 + rad, h / 2 - rad), Vector2(-w / 2 + rad, -h / 2 + rad), Vector2(w / 2 - rad, -h / 2 + rad)]
	for q in 4:
		for i in 6:
			var a := q * PI / 2.0 + i * (PI / 2.0) / 5.0
			pts.append(cs[q] + Vector2(cos(a), sin(a)) * rad)
	return pts


## Трубка по точкам (корни, верёвки, водоросли, ветки): одна сетка вместо десятков цилиндров.
## UV.y — доля длины от начала (0) до конца (1): по ней шейдер «sway» колышет кончик.
static func tube(pts: Array, r0: float, r1: float, sides := 6, col := Color.WHITE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var rings := []
	var norms := []
	var prev_side := Vector3.RIGHT
	for i in n:
		var p: Vector3 = pts[i]
		var fwd: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var side := fwd.cross(Vector3.UP)
		if side.length() < 0.1:
			side = prev_side
		side = side.normalized()
		prev_side = side
		var up := side.cross(fwd).normalized()
		var r := lerpf(r0, r1, float(i) / (n - 1))
		var ring := []
		var nr := []
		for k in sides + 1:
			var a := TAU * k / sides
			var d := side * cos(a) + up * sin(a)
			ring.append(p + d * r)
			nr.append(d)
		rings.append(ring)
		norms.append(nr)
	for i in n - 1:
		for k in sides:
			var quad_ := [[i, k], [i + 1, k], [i + 1, k + 1], [i, k + 1]]
			for t in [[0, 1, 2], [0, 2, 3]]:
				var vs := []
				var ns := []
				var uvs := []
				for q in t:
					vs.append(rings[quad_[q][0]][quad_[q][1]])
					ns.append(norms[quad_[q][0]][quad_[q][1]])
					uvs.append(Vector2(float(quad_[q][1]) / sides, float(quad_[q][0]) / (n - 1)))
				var fn: Vector3 = ns[0] + ns[1] + ns[2]
				if ((vs[1] as Vector3) - vs[0]).cross((vs[2] as Vector3) - vs[0]).dot(fn) > 0.0:
					vs = [vs[0], vs[2], vs[1]]
					ns = [ns[0], ns[2], ns[1]]
					uvs = [uvs[0], uvs[2], uvs[1]]
				for v in 3:
					st.set_color(col)
					st.set_uv(uvs[v])
					st.set_normal(ns[v])
					st.add_vertex(vs[v])
	return st.commit()


## Кривая Безье из 3 точек — для трубок
static func bez(a: Vector3, b: Vector3, c: Vector3, n := 9) -> Array:
	var out := []
	for k in n:
		var u := k / float(n - 1)
		out.append(a.lerp(b, u).lerp(b.lerp(c, u), u))
	return out


## Тело вращения по профилю [Vector2(радиус, высота)] снизу вверх: миски, горшки, абажуры, вазы
static func lathe(profile: Array, segs := 24, col := Color.WHITE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	for j in n - 1:
		var p0: Vector2 = profile[j]
		var p1: Vector2 = profile[j + 1]
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var A := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var B := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var C := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			var D := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			# наружная нормаль: от оси, с учётом наклона профиля
			var e := p1 - p0
			var nrm2 := Vector2(e.y, -e.x).normalized()
			var mid := (a0 + a1) * 0.5
			var nrm := Vector3(cos(mid) * nrm2.x, nrm2.y, sin(mid) * nrm2.x)
			if nrm.length() < 0.01:
				nrm = Vector3.UP
			for t in [[A, B, C], [A, C, D]]:
				if (t[1] - t[0]).cross(t[2] - t[0]).length() < 1e-9:
					continue
				tri(st, t[0], t[1], t[2], nrm, col, col, col)
	st.index()
	st.generate_normals()
	return st.commit()


## Много одинаковых мелочей одной сеткой (MultiMesh): один вызов отрисовки на всех
func scatter(parent: Node3D, mesh: Mesh, m: Material, xfs: Array, cols := []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if not cols.is_empty():
			mm.set_instance_color(i, cols[i % cols.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


## Частицы, которые двигает шейдер (пузырьки, светлячки, искры): count квадратов
func shader_swarm(parent: Node3D, shader_name: String, count: int, params := {}, aabb_size := 12.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad(Vector2(1, 1))
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Shaders.material(shader_name, params)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# частицы разлетаются далеко от исходной точки — сообщаем рамку, чтобы их не отсекало
	mmi.custom_aabb = AABB(Vector3(-aabb_size, -2, -aabb_size), Vector3(aabb_size * 2, aabb_size + 6, aabb_size * 2))
	parent.add_child(mmi)
	return mmi


## Мягкое сияние вокруг светящейся вещи — плоский круг, всегда повёрнутый к камере
static var _halo_tex: GradientTexture2D


func halo(parent: Node3D, p: Vector3, size: float, col: Color) -> MeshInstance3D:
	if _halo_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.4))
		_halo_tex = GradientTexture2D.new()
		_halo_tex.gradient = g
		_halo_tex.fill = GradientTexture2D.FILL_RADIAL
		_halo_tex.fill_from = Vector2(0.5, 0.5)
		_halo_tex.fill_to = Vector2(1.0, 0.5)
		_halo_tex.width = 64
		_halo_tex.height = 64
	var key := ["halo", col]
	var m: StandardMaterial3D = _mats.get(key)
	if m == null:
		m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = _halo_tex
		m.albedo_color = col
		m.disable_fog = true
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_mats[key] = m
	var mi := put(parent, quad(Vector2(size, size)), m, p)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Кристалл: шестигранная призма с острым верхом
func crystal(parent: Node3D, pos: Vector3, h: float, r: float, tilt: Vector3, col: Color, emit: float) -> Node3D:
	var c := node(parent, pos)
	c.rotation = tilt
	var m := mat(col, 0.25, emit)
	put(c, cyl(r, r * 0.9, h * 0.72, 6), m, Vector3(0, h * 0.36, 0))
	put(c, cyl(0.0, r, h * 0.28, 6), m, Vector3(0, h * 0.72 + h * 0.14, 0))
	return c


## Гроздь кристаллов (3–4 штуки) — светящийся акцент пещер
func crystal_cluster(parent: Node3D, pos: Vector3, k: float, col: Color, emit := 0.9, seed_ := 0) -> Node3D:
	var g := node(parent, pos)
	crystal(g, Vector3.ZERO, 0.42 * k, 0.07 * k, Vector3(0.05, 0, 0.0), col, emit)
	crystal(g, Vector3(-0.08, 0, 0.03) * k, 0.28 * k, 0.055 * k, Vector3(0.1, 0, 0.45), col.lightened(0.15), emit)
	crystal(g, Vector3(0.08, 0, -0.02) * k, 0.32 * k, 0.06 * k, Vector3(-0.15, 0, -0.38), col.darkened(0.1), emit)
	if seed_ % 2 == 0:
		crystal(g, Vector3(0.02, 0, 0.09) * k, 0.2 * k, 0.045 * k, Vector3(0.5, 0, 0.1), col.lightened(0.3), emit)
	return g


## Свет: точечный. shadow — может ли отбрасывать тень (включается только в высоком качестве)
func omni(parent: Node3D, pos: Vector3, col: Color, energy: float, rng: float, kind := "", shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	l.position = pos
	l.shadow_enabled = false
	l.set_meta("can_shadow", shadow)
	l.shadow_blur = 2.0
	parent.add_child(l)
	if kind != "":
		lights.append([l, energy, kind])
	return l


## Анимация узла. k — вид (см. room.gd _animate), остальное — параметры вида
func anim(n: Node3D, k: String, params := {}) -> void:
	var a := params.duplicate()
	a.n = n
	a.k = k
	a.base = n.transform
	if not a.has("p"):
		a.p = 0.0
	anims.append(a)


## Склейка неподвижных деталей поддерева root: детали с одинаковым материалом — в одну сетку.
## moving — узлы, которые двигаются (их и всё внутри не трогаем).
func merge_static(root: Node3D, moving: Array) -> void:
	var groups := {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: Material = mi.material_override
		if m == null or not mi.visible:
			continue
		if m is StandardMaterial3D:
			var sm := m as StandardMaterial3D
			if sm.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
		elif not (m is ShaderMaterial and m.has_meta("merge")):
			continue
		var skip := false
		for mv in moving:
			if is_instance_valid(mv) and (mv == mi or (mv as Node).is_ancestor_of(mi)):
				skip = true
				break
		if skip:
			continue
		var key := [m, mi.cast_shadow]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(mi)
	var inv := root.global_transform.affine_inverse() if root.is_inside_tree() else Transform3D.IDENTITY
	for key in groups:
		var list: Array = groups[key]
		if list.size() < 2:
			continue
		var st := SurfaceTool.new()
		for mi in list:
			var mesh: Mesh = mi.mesh
			var xf: Transform3D = (inv * mi.global_transform) if root.is_inside_tree() else _rel_xf(root, mi)
			for sidx in mesh.get_surface_count():
				st.append_from(mesh, sidx, xf)
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = key[0]
		merged.cast_shadow = key[1]
		root.add_child(merged)
		for mi in list:
			mi.get_parent().remove_child(mi)
			mi.queue_free()


## Положение узла относительно предка (если дерево ещё не в сцене)
static func _rel_xf(root: Node, n: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
