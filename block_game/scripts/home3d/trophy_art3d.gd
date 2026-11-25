extends "res://scripts/home3d/kit.gd"
## 3D-кубки залов (Cascado 0.14) — тот же замысел, что у 2D-рисунков (scripts/trophies.gd).
## Кубок строится из простых фигур и тел вращения; размеры — в «единицах» 2D-рисунка
## (высота 100 единиц = 0,32 м, основание при y2d = 50), поэтому профили 2D и 3D совпадают.
##
## Как кубки остаются лёгкими для телефона:
##   * свои материалы-шейдеры БЕЗ источников света: металл, камень, стекло, силуэт — блеск, грани,
##     «бегущий» отблеск и мерцание граней считаются в шейдере по нормали (как matcap), свечение — яркостью;
##   * цвет каждой детали записан в цвет вершин, поэтому все неподвижные детали всех кубков с одним
##     материалом склеиваются в ОДНУ сетку (merge_static): вся полка — несколько вызовов отрисовки;
##   * сетки и материалы создаются один раз за игру (статический кэш).
## Цвет вершины .a — «характер» поверхности: металл 1.0, эмаль 0.55, бархат 0.15; у камня a < 0.6 — радуга.

const U := 0.0032
## Высота кубка (м) при масштабе 1
const TROPHY_H := 100.0 * U

static var _tm := {}
static var _paint := {}

## Силуэт непройденного зала: все детали — этим цветом и материалом «призрака»
var _ghost := false
var _ghost_col := Color(1, 1, 1)
## Детали, которые двигаются (их не склеиваем): узлы
var moving := []


# ---------- Материалы ----------

const SH_METAL := """
shader_type spatial;
render_mode unshaded;
uniform float glint = 1.0;
uniform float light = 1.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 base = COLOR.rgb;
	float sh = COLOR.a;
	// «хром» как у игрушки: светлое небо сверху, тонкая линия горизонта, тёмная полоса под ней, отсвет пола
	float up = n.y + 0.3 * n.x;
	vec3 ground = base * mix(0.62, 0.7, sh);
	vec3 dark = base * mix(0.55, 0.22, sh);
	vec3 sky = mix(base, vec3(1.0), 0.42 * sh);
	vec3 c = mix(ground, dark, smoothstep(-0.65, -0.25, up));
	c = mix(c, base * mix(0.85, 0.92, sh), smoothstep(-0.12, 0.18, up));
	c = mix(c, sky, smoothstep(0.38, 0.82, up));
	c += mix(base, vec3(1.0), 0.6) * 0.42 * sh * smoothstep(0.07, 0.0, abs(up + 0.05));
	vec3 hv = normalize(vec3(-0.35, 0.55, 0.75) + vec3(0.0, 0.0, 1.0));
	c += vec3(1.0) * pow(max(dot(n, hv), 0.0), mix(6.0, 70.0, sh)) * mix(0.12, 0.9, sh);
	float fr = 1.0 - clamp(n.z, 0.0, 1.0);
	c += mix(base, vec3(1.0), 0.3) * fr * fr * mix(0.5, 0.22, sh);
	float sweep = fract(TIME * 0.1 + (wp.x * 0.8 + wp.y * 0.55 + wp.z * 0.35) * 0.32);
	c += vec3(1.0, 0.95, 0.82) * smoothstep(0.03, 0.0, abs(sweep - 0.5)) * glint * sh;
	ALBEDO = min(c * light, vec3(1.25));
}
"""

const SH_GEM := """
shader_type spatial;
render_mode unshaded;
uniform float sparkle = 1.0;
uniform float light = 1.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
vec3 hue(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }
void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 base = COLOR.rgb;
	if (COLOR.a < 0.6) {
		base = mix(hue(fract(TIME * 0.07 + lp.x * 2.5 + lp.y * 1.5)), vec3(1.0), 0.22);
	}
	float f = dot(n, normalize(vec3(-0.35, 0.6, 0.7)));
	vec3 c = base * (0.5 + 0.7 * max(f, 0.0)) + base * 0.3;
	float fr = pow(1.0 - clamp(n.z, 0.0, 1.0), 2.0);
	c = mix(c, base * 1.6 + 0.12, fr * 0.6);
	float h = fract(sin(dot(floor(n * 4.0 + 0.5), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float tw = pow(max(0.0, sin(TIME * (1.1 + h * 2.0) + h * 40.0)), 18.0);
	c += vec3(1.0) * tw * 1.5 * sparkle;
	c += vec3(1.0) * pow(max(dot(n, normalize(vec3(-0.3, 0.45, 1.0))), 0.0), 36.0) * 1.1;
	ALBEDO = min(c * light, vec3(1.25));
}
"""

const SH_GLASS := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;
uniform float light = 1.0;
void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 base = COLOR.rgb;
	float fr = pow(1.0 - clamp(abs(n.z), 0.0, 1.0), 1.4);
	vec3 c = base * 0.9 + vec3(0.5) * fr;
	float sp = pow(max(dot(n, normalize(vec3(-0.4, 0.5, 0.9))), 0.0), 28.0);
	float streak = smoothstep(0.07, 0.0, abs(n.x + 0.5)) * smoothstep(-0.2, 0.3, n.z);
	c += vec3(1.0) * (sp * 1.4 + streak * 0.7);
	ALBEDO = min(c * light, vec3(1.25));
	ALPHA = clamp(COLOR.a * (0.55 + 0.45 * fr) + sp + streak * 0.5, 0.0, 1.0);
}
"""

const SH_GHOST := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform float light = 1.0;
void fragment() {
	vec3 n = normalize(NORMAL);
	float fr = pow(1.0 - clamp(n.z, 0.0, 1.0), 1.6);
	ALBEDO = (COLOR.rgb * 0.7 + vec3(0.3) * fr) * light;
	ALPHA = 0.2 + 0.5 * fr;
}
"""


static func _shader_mat(code: String, key: String) -> ShaderMaterial:
	if _tm.has(key):
		return _tm[key]
	var s := Shader.new()
	s.code = code
	var m := ShaderMaterial.new()
	m.shader = s
	m.set_meta("merge", true)
	_tm[key] = m
	return m


## Тонкая обводка кубков (у домов — 0.012 м; кубок маленький — тоньше)
static func trophy_outline() -> StandardMaterial3D:
	if _tm.has("outline"):
		return _tm["outline"]
	var o := StandardMaterial3D.new()
	o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o.cull_mode = BaseMaterial3D.CULL_FRONT
	o.grow = true
	o.grow_amount = 0.0045
	o.albedo_color = OUT
	_tm["outline"] = o
	return o


static func metal_mat() -> ShaderMaterial:
	var m := _shader_mat(SH_METAL, "metal")
	if m.next_pass == null:
		m.next_pass = trophy_outline()
	return m


static func gem_mat() -> ShaderMaterial:
	var m := _shader_mat(SH_GEM, "gem")
	if m.next_pass == null:
		m.next_pass = trophy_outline()
	return m


static func glass_mat() -> ShaderMaterial:
	return _shader_mat(SH_GLASS, "glass")


static func ghost_mat() -> ShaderMaterial:
	return _shader_mat(SH_GHOST, "ghost")


## Качество и яркость комнаты: в простом качестве без бегущего отблеска и мерцания граней
static func set_trophy_quality(high: bool, light := 1.0) -> void:
	metal_mat().set_shader_parameter("glint", 1.0 if high else 0.0)
	gem_mat().set_shader_parameter("sparkle", 1.0 if high else 0.35)
	for k in ["metal", "gem", "glass", "ghost"]:
		if _tm.has(k):
			(_tm[k] as ShaderMaterial).set_shader_parameter("light", light)


# ---------- Сетки с цветом в вершинах ----------

## Копия сетки с цветом col в каждой вершине (кэш)
static func painted(mesh: Mesh, col: Color) -> ArrayMesh:
	var key := [mesh, col, "p"]
	if _paint.has(key):
		return _paint[key]
	var am := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var n: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var cols := PackedColorArray()
		cols.resize(n)
		cols.fill(col)
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_TANGENT] = null
		_ensure_index(arr, n)
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_paint[key] = am
	return am


## У всех сеток кубков — массив индексов (склейка merge_static теряет треугольники, если у одних
## сеток индексы есть, а у других нет)
static func _ensure_index(arr: Array, n: int) -> void:
	var idx = arr[Mesh.ARRAY_INDEX]
	if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
		return
	var ix := PackedInt32Array()
	ix.resize(n)
	for i in n:
		ix[i] = i
	arr[Mesh.ARRAY_INDEX] = ix


## Гранёная копия сетки: каждая грань плоская (камни), цвет col (кэш)
static func faceted(mesh: Mesh, col: Color) -> ArrayMesh:
	var key := [mesh, col, "f"]
	if _paint.has(key):
		return _paint[key]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nv = arr[Mesh.ARRAY_NORMAL]
		var idx = arr[Mesh.ARRAY_INDEX]
		var order := PackedInt32Array()
		if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
			order = idx
		else:
			for i in v.size():
				order.append(i)
		for i in range(0, order.size() - 2, 3):
			var a := v[order[i]]
			var b := v[order[i + 1]]
			var c := v[order[i + 2]]
			var fn := (b - a).cross(c - a)
			if fn.length() < 1e-10:
				continue
			fn = fn.normalized()
			if nv is PackedVector3Array and (nv as PackedVector3Array).size() == v.size():
				var avg: Vector3 = nv[order[i]] + nv[order[i + 1]] + nv[order[i + 2]]
				if avg.dot(fn) < 0.0:
					fn = -fn
			for p in [a, b, c]:
				verts.append(p)
				norms.append(fn)
	var cols := PackedColorArray()
	cols.resize(verts.size())
	cols.fill(col)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = norms
	out[Mesh.ARRAY_COLOR] = cols
	_ensure_index(out, verts.size())
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	_paint[key] = am
	return am


## Профиль 2D-рисунка [Vector2(радиус, y2d)] (y2d вниз, основание 50) -> профиль для lathe (м, снизу вверх)
static func prof(pts: Array) -> Array:
	var out := []
	for p in pts:
		out.append(Vector2(p.x * U, (50.0 - p.y) * U))
	return out


static func lathe_u(pts: Array, segs := 24) -> ArrayMesh:
	var key := ["lu", pts, segs]
	if _tm.has(key):
		return _tm[key]
	var m := lathe(prof(pts), segs)
	_tm[key] = m
	return m


## Точка 2D-рисунка (x, y2d) в 3D (z — вперёд)
static func p3(x: float, y: float, z := 0.0) -> Vector3:
	return Vector3(x * U, (50.0 - y) * U, z * U)


# ---------- Детали ----------

## Деталь кубка: kind — "metal" / "enamel" / "velvet" / "gem" (гранёный) / "gem_s" (гладкий) /
## "rainbow" / "glass" / "glow"
func part(p: Node3D, mesh: Mesh, kind: String, col: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m: Mesh
	var mt: Material
	if _ghost:
		m = painted(mesh, _ghost_col)
		mt = ghost_mat()
	else:
		match kind:
			"metal":
				m = painted(mesh, Color(col, 1.0))
				mt = metal_mat()
			"enamel":
				m = painted(mesh, Color(col, 0.55))
				mt = metal_mat()
			"velvet":
				m = painted(mesh, Color(col, 0.15))
				mt = metal_mat()
			"gem":
				m = faceted(mesh, Color(col, 1.0))
				mt = gem_mat()
			"gem_s":
				m = painted(mesh, Color(col, 1.0))
				mt = gem_mat()
			"rainbow":
				m = faceted(mesh, Color(col, 0.3))
				mt = gem_mat()
			"glass":
				m = painted(mesh, col)
				mt = glass_mat()
			"glow_soft":
				m = mesh
				mt = glow_mat(col, 0.9)
			_:
				m = mesh
				mt = glow_mat(col, 1.5)
	var mi := put(p, m, mt, pos, rot, scl)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Камень «бриллиант» (круглый, 8 граней), площадкой к зрителю (+Z)
static func brilliant(segs := 8) -> ArrayMesh:
	var key := ["brill", segs]
	if _tm.has(key):
		return _tm[key]
	var m := lathe([Vector2(0, -0.55), Vector2(1, 0), Vector2(0.92, 0.16), Vector2(0.58, 0.34), Vector2(0, 0.34)], segs)
	_tm[key] = m
	return m


## Кристалл: шестигранная призма с острым верхом (высота 1, радиус 1)
static func crystal_mesh() -> ArrayMesh:
	if _tm.has("cryst"):
		return _tm["cryst"]
	var m := lathe([Vector2(0, 0), Vector2(0.85, 0), Vector2(1, 0.12), Vector2(1, 0.7), Vector2(0, 1.0)], 6)
	_tm["cryst"] = m
	return m


func gem(p: Node3D, pos: Vector3, r: float, col: Color, kind := "gem", tilt := Vector3.ZERO, segs := 8) -> MeshInstance3D:
	return part(p, brilliant(segs), kind, col, pos, Vector3(PI / 2.0, 0, 0) + tilt, Vector3(r, r, r))


func crystal3(p: Node3D, base: Vector3, h: float, r: float, rot: Vector3, col: Color, kind := "gem") -> MeshInstance3D:
	return part(p, crystal_mesh(), kind, col, base, rot, Vector3(r, h, r))


## Плоская фигура с объёмом (из 2D-контура в единицах рисунка), лицом к +Z
func flat(p: Node3D, poly: PackedVector2Array, depth: float, kind: String, col: Color, pos: Vector3, rot := Vector3.ZERO, key := "") -> MeshInstance3D:
	var mesh: ArrayMesh
	var k := ["flat", key if key != "" else str(poly), depth]
	if _tm.has(k):
		mesh = _tm[k]
	else:
		var pts := PackedVector2Array()
		for q in poly:
			pts.append(Vector2(q.x * U, -q.y * U))
		mesh = extrude(pts, depth * U)
		_tm[k] = mesh
	return part(p, mesh, kind, col, pos, rot)


## Гранёная фигура с фаской (сердце): контур на «поясе», спереди и сзади — уменьшенная площадка
func beveled(p: Node3D, poly: PackedVector2Array, depth: float, inset: float, kind: String, col: Color, pos: Vector3, key: String) -> MeshInstance3D:
	var k := ["bev", key, depth, inset]
	var mesh: ArrayMesh
	if _tm.has(k):
		mesh = _tm[k]
	else:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var c2 := Vector2.ZERO
		for q in poly:
			c2 += q
		c2 /= poly.size()
		var outer := []
		var front := []
		var back := []
		for q in poly:
			outer.append(Vector3(q.x * U, -q.y * U, 0))
			var iq := c2 + (q - c2) * inset
			front.append(Vector3(iq.x * U, -iq.y * U, depth * U * 0.5))
			back.append(Vector3(iq.x * U, -iq.y * U, -depth * U * 0.5))
		var idx := Geometry2D.triangulate_polygon(poly)
		for i in range(0, idx.size(), 3):
			_ftri(st, front[idx[i]], front[idx[i + 1]], front[idx[i + 2]], Vector3(0, 0, 1))
			_ftri(st, back[idx[i]], back[idx[i + 1]], back[idx[i + 2]], Vector3(0, 0, -1))
		var cc := Vector3(c2.x * U, -c2.y * U, 0)
		for i in poly.size():
			var j := (i + 1) % poly.size()
			for side in [front, back]:
				var a: Vector3 = outer[i]
				var b: Vector3 = outer[j]
				var cq: Vector3 = side[j]
				var d: Vector3 = side[i]
				var outd: Vector3 = ((a + b) * 0.5 - cc).normalized() + Vector3(0, 0, signf(d.z)) * 0.6
				_ftri(st, a, b, cq, outd)
				_ftri(st, a, cq, d, outd)
		mesh = st.commit()
		_tm[k] = mesh
	return part(p, mesh, kind, col, pos)


static func _ftri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length() < 1e-12:
		return
	if n.dot(outward) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	# Godot: лицевая сторона — по часовой (как в kit.tri): нормаль против (b-a)x(c-a)
	n = n.normalized()
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(c)
	st.set_normal(n)
	st.add_vertex(b)


## Ручка: трубка по точкам 2D-рисунка (z — вперёд/назад)
func handle(p: Node3D, pts2: Array, r: float, col: Color, z := 0.0, kind := "metal") -> MeshInstance3D:
	var key := ["h", pts2, r, z]
	var mesh: ArrayMesh
	if _tm.has(key):
		mesh = _tm[key]
	else:
		var pts := []
		for q in pts2:
			pts.append(p3(q.x, q.y, z))
		mesh = tube(pts, r * U, r * U, 7)
		_tm[key] = mesh
	return part(p, mesh, kind, col)


static func arc2(c: Vector2, rx: float, ry: float, a0: float, a1: float, n := 10) -> Array:
	var out := []
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


# ---------- Кубки ----------

## Построить кубок n (1..10) в узле p: основание — в начале координат, «лицо» — к +Z.
## ghost — полупрозрачный силуэт цвета col (кубок ещё не получен).
func trophy(p: Node3D, n: int, ghost := false, col := Color(1, 1, 1)) -> void:
	_ghost = ghost
	_ghost_col = col
	match clampi(n, 1, 10):
		1: _t_amethyst(p)
		2: _t_emerald(p)
		3: _t_flame(p)
		4: _t_frost(p)
		5: _t_heart(p)
		6: _t_wave(p)
		7: _t_amber(p)
		8: _t_moon(p)
		9: _t_fireflies(p)
		10: _t_crown(p)
	_ghost = false


## Анимация детали кубка; в простом качестве детали неподвижны (склеиваются с остальными)
func _anim(n: Node3D, k: String, params := {}) -> void:
	if _ghost or not high_fx:
		return
	anim(n, k, params)
	moving.append(n)


func _t_amethyst(p: Node3D) -> void:
	var m := Color("#B9A0EC")
	part(p, lathe_u([Vector2(0, 50), Vector2(23, 50), Vector2(23, 46), Vector2(21, 42), Vector2(9, 37), Vector2(0, 37)], 8), "metal", m.darkened(0.08))
	part(p, lathe_u([Vector2(5, 37.5), Vector2(5, 33), Vector2(9, 29), Vector2(9, 25), Vector2(5, 21), Vector2(0, 21)], 16), "metal", m)
	part(p, lathe_u([Vector2(5, 22), Vector2(8, 18), Vector2(17, 12), Vector2(24, 2), Vector2(27, -10), Vector2(28, -16), Vector2(25.5, -16), Vector2(24, -8), Vector2(0, -6)], 22), "metal", m)
	handle(p, arc2(Vector2(-25, -3), 11, 13, -PI * 0.55, -PI * 1.45), 2.6, m)
	handle(p, arc2(Vector2(25, -3), 11, 13, -PI * 0.45, PI * 0.45), 2.6, m)
	# кристаллы растут из чаши
	crystal3(p, p3(0, -6, -2), 50 * U, 8 * U, Vector3(-0.08, 0.3, 0.02), Color("#B46CFF"))
	crystal3(p, p3(-9, -7, 3), 34 * U, 6.5 * U, Vector3(0.25, 0.2, 0.5), Color("#9A50F0"))
	crystal3(p, p3(10, -7, 1), 30 * U, 6 * U, Vector3(0.1, 0.5, -0.55), Color("#C58AFF"))
	crystal3(p, p3(2, -7, -10), 24 * U, 5 * U, Vector3(-0.55, 0.0, -0.1), Color("#D9A8FF"))
	gem(p, p3(0, 0, 25.5), 10 * U, Color("#9B4DFF"))
	gem(p, p3(0, 44, 21.5), 3 * U, Color("#D9A8FF"), "gem", Vector3(-0.4, 0, 0), 6)


func _leaf_poly() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		pts.append(Vector2(u * 16.0, sin(u * PI) * 4.5))
	for i in range(7, 0, -1):
		var u := i / 8.0
		pts.append(Vector2(u * 16.0, -sin(u * PI) * 4.5))
	return pts


func _t_emerald(p: Node3D) -> void:
	var gold := Color("#FFCF5A")
	part(p, lathe_u([Vector2(0, 50), Vector2(20, 50), Vector2(22, 47), Vector2(20, 44), Vector2(8, 38), Vector2(0, 38)], 24), "metal", gold.darkened(0.06))
	part(p, lathe_u([Vector2(4, 38.5), Vector2(4, 30), Vector2(7, 26), Vector2(4, 22), Vector2(5, 10), Vector2(0, 10)], 14), "metal", gold)
	part(p, lathe_u([Vector2(6, 11), Vector2(15, 8), Vector2(27, 2), Vector2(33, -6), Vector2(34, -10), Vector2(31.5, -9), Vector2(24, -2), Vector2(0, 2)], 24), "metal", gold)
	# зелёная эмалевая полоса с кабошонами
	part(p, lathe_u([Vector2(27.4, 2.4), Vector2(31.2, -2.0), Vector2(32.6, -5.0), Vector2(0.0, -5.0)], 32), "enamel", Color("#169E62"), Vector3(0, 0.0015, 0), Vector3.ZERO, Vector3(1.02, 1, 1.02))
	for i in 5:
		var b := (i - 2) * 0.55
		gem(p, p3(0, -1.5) + Vector3(sin(b), 0, cos(b)) * 31.8 * U, 3.0 * U, Color("#5CF0A8"), "gem", Vector3(0, b, 0), 6)
	# листья, обвивающие ножку
	var lp := _leaf_poly()
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		var lf := node(p, p3(0, 24 + (i % 2) * 6))
		lf.rotation = Vector3(0, a, 0)
		flat(lf, lp, 2.0, "enamel", Color("#3DBA6A") if i % 2 == 0 else Color("#2FA35C"), Vector3(2 * U, 0, 0), Vector3(0, 0, 0.7), "leaf")
	# изумруд над чашей: медленно поворачивается, листья вокруг
	var e := node(p, p3(0, -27))
	_anim(e, "spin", {"spd": 0.6})
	var em := lathe([Vector2(0, -0.5), Vector2(0.62, -0.32), Vector2(1.0, -0.12), Vector2(1.0, 0.12), Vector2(0.62, 0.32), Vector2(0, 0.5)], 8)
	part(e, _cache_mesh("emerald", em), "gem", Color("#1FCB7E"), Vector3.ZERO, Vector3(0, PI / 8.0, 0), Vector3(12 * U, 34 * U, 8 * U))
	for i in 2:
		flat(p, lp, 2.0, "enamel", Color("#3DBA6A"), p3(-1 + i * 2, -10, 2), Vector3(0, 0, (PI * 0.62) if i == 0 else (PI * 0.38)), "leaf")


func _cache_mesh(key: String, m: Mesh) -> Mesh:
	if _tm.has(["cm", key]):
		return _tm[["cm", key]]
	_tm[["cm", key]] = m
	return m


func _flame_poly(w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		pts.append(Vector2(cos(a) * w, sin(a) * w * 0.9))
	pts.append(Vector2(-w * 0.92, -h * 0.28))
	pts.append(Vector2(-w * 0.45, -h * 0.62))
	pts.append(Vector2(0, -h))
	pts.append(Vector2(w * 0.5, -h * 0.58))
	pts.append(Vector2(w * 0.95, -h * 0.24))
	pts.reverse()
	return pts


func _t_flame(p: Node3D) -> void:
	var cu := Color("#E8834A")
	part(p, lathe_u([Vector2(0, 50), Vector2(22, 50), Vector2(22, 46), Vector2(18, 44), Vector2(18, 41), Vector2(10, 37), Vector2(0, 37)], 24), "metal", cu.darkened(0.1))
	part(p, lathe_u([Vector2(5, 37.5), Vector2(5, 34), Vector2(8, 31), Vector2(4, 28), Vector2(5, 17), Vector2(0, 17)], 14), "metal", cu)
	part(p, lathe_u([Vector2(5, 18), Vector2(7, 12), Vector2(13, 4), Vector2(19, -8), Vector2(22, -16), Vector2(19.5, -15), Vector2(16, -6), Vector2(0, -2)], 22), "metal", cu)
	handle(p, [Vector2(-17, -10), Vector2(-27, -14), Vector2(-31, -6), Vector2(-26, 2), Vector2(-18, 6), Vector2(-13, 10)], 2.6, cu)
	handle(p, [Vector2(17, -10), Vector2(27, -14), Vector2(31, -6), Vector2(26, 2), Vector2(18, 6), Vector2(13, 10)], 2.6, cu)
	gem(p, p3(0, 0, 15), 6.5 * U, Color("#FF4A2A"), "gem", Vector3.ZERO, 6)
	# самоцвет-огонёк: три слоя пламени крест-накрест, колышется
	var f := node(p, p3(0, -14))
	_anim(f, "flame", {"p": 0.3})
	for r in [0.0, PI / 3.0, -PI / 3.0]:
		part(f, _flame_mesh("f1", 15, 40), "glow_soft", Color("#FF4A1A"), Vector3.ZERO, Vector3(0, r, 0))
	for r in [0.0, PI / 2.0]:
		part(f, _flame_mesh("f2", 10, 29), "glow_soft", Color("#FF9A2A"), Vector3(0, 0.002, 0.0), Vector3(0, r, 0))
	part(f, _flame_mesh("f3", 5.5, 17), "glow", Color("#FFE27A"), Vector3(0, 0.004, 0.006))
	if not _ghost and high_fx:
		halo(p, p3(0, -26, 2), 0.3, Color(1.0, 0.5, 0.2, 0.5))


var high_fx := true


func _flame_mesh(key: String, w: float, h: float) -> ArrayMesh:
	var k := ["fl", key]
	if _tm.has(k):
		return _tm[k]
	var poly := _flame_poly(w, h)
	var pts := PackedVector2Array()
	for q in poly:
		pts.append(Vector2(q.x * U, -q.y * U))
	var m := extrude(pts, 2.5 * U)
	_tm[k] = m
	return m


func _t_frost(p: Node3D) -> void:
	var ice := Color(0.55, 0.85, 1.0, 0.62)
	part(p, lathe_u([Vector2(0, 50), Vector2(20, 50), Vector2(22, 48), Vector2(20, 45), Vector2(5, 40), Vector2(0, 40)], 24), "glass", ice)
	part(p, lathe_u([Vector2(2.5, 40.5), Vector2(2.5, 33), Vector2(6, 30), Vector2(6, 25), Vector2(2.5, 22), Vector2(3, 13), Vector2(0, 13)], 14), "glass", ice)
	part(p, lathe_u([Vector2(3, 14), Vector2(6, 10), Vector2(15, 5), Vector2(22, -4), Vector2(25, -16), Vector2(24, -26), Vector2(22.5, -26), Vector2(23, -16), Vector2(0, 8)], 22), "glass", ice)
	# снежинка внутри — светится
	var sf := node(p, p3(0, -9, 0))
	_anim(sf, "spin", {"spd": 0.5, "axis": Vector3(0, 0, 1)})
	for i in 3:
		part(sf, box(Vector3(17 * U, 1.6 * U, 1.6 * U)), "glow", Color("#E8FCFF"), Vector3.ZERO, Vector3(0, 0, i * PI / 3.0))
	part(sf, sphere(2.2 * U, 8), "glow", Color("#FFFFFF"))
	# иней: кристаллики на кромке и у основания
	for i in 10:
		var a := TAU * i / 10.0
		crystal3(p, p3(0, -25) + Vector3(cos(a) * 23.5 * U, 0, sin(a) * 23.5 * U), (6 + 3 * hash1(i, 3)) * U, 1.6 * U, Vector3(0.5 * sin(a), 0, -0.5 * cos(a)), Color("#F2FDFF"))
	crystal3(p, p3(-14, 47, 6), 13 * U, 3 * U, Vector3(0.2, 0, 0.5), Color("#9FE8FF"))
	crystal3(p, p3(14, 47, 6), 11 * U, 3 * U, Vector3(0.2, 0, -0.55), Color("#C9F6FF"))
	crystal3(p, p3(-7, 47, 12), 8 * U, 2.5 * U, Vector3(0.5, 0, 0.15), Color("#E6FCFF"))
	crystal3(p, p3(6, 47, -13), 9 * U, 2.5 * U, Vector3(-0.4, 0, -0.2), Color("#BDF4FF"))


func _heart_poly(w: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var s := w / 32.0
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(Vector2(16.0 * pow(sin(a), 3), -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))) * s)
	return pts


func _t_heart(p: Node3D) -> void:
	var gold := Color("#FFC94A")
	part(p, lathe_u([Vector2(0, 50), Vector2(24, 50), Vector2(24, 46), Vector2(22, 42), Vector2(9, 36), Vector2(0, 36)], 24), "metal", gold.darkened(0.08))
	part(p, lathe_u([Vector2(5, 36.5), Vector2(5, 30), Vector2(9, 26), Vector2(5, 22), Vector2(6, 8), Vector2(0, 8)], 14), "metal", gold)
	# лапки держат сердце
	for sx in [-1.0, 1.0]:
		handle(p, [Vector2(0, 9), Vector2(sx * 7, 5), Vector2(sx * 11, -1), Vector2(sx * 12, -5)], 2.0, gold, 3.0)
		handle(p, [Vector2(0, 9), Vector2(sx * 7, 5), Vector2(sx * 11, -1), Vector2(sx * 12, -5)], 2.0, gold, -3.0)
	gem(p, p3(0, 30, 6.5), 3.5 * U, Color("#FF4D6D"), "gem", Vector3.ZERO, 6)
	var h := node(p, p3(0, -12))
	_anim(h, "pulse", {"amp": 0.07, "spd": 3.2})
	beveled(h, _heart_poly(50), 20, 0.55, "gem", Color("#E8264E"), Vector3.ZERO, "heart")
	if not _ghost and high_fx:
		halo(p, p3(0, -14, 2), 0.32, Color(1.0, 0.3, 0.45, 0.45))


func _t_wave(p: Node3D) -> void:
	var silver := Color("#BCCDF2")
	var blue := Color("#2F5BE0")
	part(p, lathe_u([Vector2(0, 50), Vector2(22, 50), Vector2(23, 46), Vector2(22, 42), Vector2(8, 36), Vector2(0, 36)], 24), "metal", silver.darkened(0.1))
	part(p, lathe_u([Vector2(5, 36.5), Vector2(5, 33), Vector2(8, 30), Vector2(4, 27), Vector2(6, 14), Vector2(0, 14)], 14), "metal", silver)
	part(p, lathe_u([Vector2(6, 15), Vector2(13, 11), Vector2(20, 4), Vector2(24, -6), Vector2(25, -14), Vector2(23, -14), Vector2(22, -6), Vector2(0, -2)], 22), "enamel", blue)
	part(p, torus(24 * U, 26.4 * U, 22), "metal", silver, p3(0, -14))
	part(p, torus(21 * U, 23 * U, 24), "metal", silver, p3(0, 3))
	handle(p, arc2(Vector2(-24, -4), 9, 11, -PI * 0.55, -PI * 1.45), 2.4, silver)
	handle(p, arc2(Vector2(24, -4), 9, 11, -PI * 0.45, PI * 0.45), 2.4, silver)
	gem(p, p3(0, -4, 23), 7 * U, Color("#2E5BFF"))
	# гребень волны над чашей, покачивается
	var w := node(p, p3(0, -12))
	_anim(w, "wiggle", {"axis": Vector3(0, 0, 1), "amp": 0.06, "spd": 1.4})
	var crest := PackedVector2Array([Vector2(-24, -2), Vector2(-20, -14), Vector2(-10, -26), Vector2(4, -32), Vector2(16, -28),
		Vector2(21, -19), Vector2(16, -14), Vector2(10, -20), Vector2(2, -20), Vector2(-4, -12), Vector2(2, -2)])
	crest.reverse()
	flat(w, crest, 9, "gem_s", Color("#3F7DFF"), Vector3.ZERO, Vector3.ZERO, "crest")
	for i in 6:
		var u := i / 5.0
		var fy := -30.0 + 40.0 * (u - 0.5) * (u - 0.5)
		part(w, sphere(1.0, 10), "gem_s", Color("#F4FBFF"), Vector3((-12 + u * 30) * U, -fy * U, 0), Vector3.ZERO, Vector3.ONE * (5.2 - u * 1.4) * U)


func _t_amber(p: Node3D) -> void:
	var gold := Color("#FFC94A")
	part(p, lathe_u([Vector2(0, 50), Vector2(16, 50), Vector2(17, 47), Vector2(14, 44), Vector2(0, 44)], 20), "metal", gold.darkened(0.1))
	part(p, lathe_u([Vector2(4, 44.5), Vector2(6, 40), Vector2(3, 36), Vector2(3, 20), Vector2(0, 20)], 12), "metal", gold)
	for i in 3:
		var a := TAU * i / 3.0 + PI / 2.0
		var lg := node(p)
		lg.rotation.y = a
		handle(lg, [Vector2(4, 22), Vector2(14, 32), Vector2(20, 44), Vector2(23, 49)], 1.8, gold)
	# капля янтаря: тёплая сердцевина и прозрачная оболочка, между ними — застывший жучок и искра
	var dc := p3(0, 2)
	var prof_ := []
	for i in 17:
		var a := lerpf(-PI / 2.0, PI / 2.0, i / 16.0)
		var y := sin(a)
		var r := cos(a)
		if y > 0.0:
			r *= 1.0 - 0.8 * pow(y, 1.3)
		prof_.append(Vector2(r * 21 * U, (y * 44 if y > 0.0 else y * 21) * U))
	prof_[16] = Vector2(0, 44 * U)
	var drop := _cache_mesh("drop", lathe(prof_, 28))
	part(p, drop, "gem_s", Color("#C8540A"), dc, Vector3.ZERO, Vector3(0.8, 0.86, 0.8))
	part(p, drop, "glass", Color(1.0, 0.55, 0.12, 0.45), dc)
	var bug := node(p, dc + Vector3(1.5, 3, 16.5) * U)
	bug.rotation = Vector3(0.3, 0, 0.45)
	part(bug, sphere(1.0, 12), "enamel", Color("#4A2006"), Vector3.ZERO, Vector3.ZERO, Vector3(4.0, 5.5, 2.0) * U)
	part(bug, sphere(1.0, 8), "enamel", Color("#4A2006"), Vector3(0, 6.2, 0) * U, Vector3.ZERO, Vector3(2.4, 2.4, 1.6) * U)
	for sy in [-2.0, 1.0, 4.0]:
		for sx in [-1.0, 1.0]:
			part(bug, box(Vector3(4.5 * U, 0.7 * U, 0.7 * U)), "enamel", Color("#4A2006"), Vector3(sx * 5.0, sy, 0) * U, Vector3(0, 0, sx * 0.4))
	var sp := node(p, dc + Vector3(-6, 10, 15) * U)
	_anim(sp, "pulse", {"amp": 0.35, "spd": 4.0})
	part(sp, sphere(2.4 * U, 8), "glow", Color("#FFF3B0"))
	# оправа: пояс и колпачок на кончике
	part(p, torus(20.5 * U, 23 * U, 22), "metal", gold, dc + Vector3(0, -1, 0) * U)
	part(p, _cache_mesh("amber_cap", lathe([Vector2(0, 0), Vector2(5 * U, 1 * U), Vector2(3 * U, 7 * U), Vector2(0, 9 * U)], 12)), "metal", gold, dc + Vector3(0, 37, 0) * U)
	part(p, sphere(2.6 * U, 10), "metal", gold, dc + Vector3(0, 47, 0) * U)
	gem(p, dc + Vector3(0, -1, 22.5) * U, 3 * U, Color("#FF8A2A"), "gem", Vector3.ZERO, 6)
	if not _ghost and high_fx:
		halo(p, dc + Vector3(0, 8, 4) * U, 0.3, Color(1.0, 0.65, 0.2, 0.45))


func _crescent() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 21:
		var a := lerpf(0.9, TAU - 0.9, i / 20.0)
		pts.append(Vector2(cos(a), sin(a)) * 15.0)
	var e := atan2(15.0 * sin(0.9), 15.0 * cos(0.9) - 6.0)
	var r1 := Vector2(15.0 * cos(0.9) - 6.0, 15.0 * sin(0.9)).length()
	for i in range(1, 20):
		var a := lerpf(-e, -(TAU - e), i / 20.0)
		pts.append(Vector2(6, 0) + Vector2(cos(a), sin(a)) * r1)
	pts.reverse()
	return pts


func _t_moon(p: Node3D) -> void:
	var silver := Color("#BFCBEA")
	part(p, lathe_u([Vector2(0, 50), Vector2(18, 50), Vector2(19, 47), Vector2(18, 44), Vector2(7, 38), Vector2(0, 38)], 24), "metal", silver.darkened(0.1))
	part(p, lathe_u([Vector2(3.5, 38.5), Vector2(3.5, 35), Vector2(6, 32), Vector2(3, 29), Vector2(4, 15), Vector2(0, 15)], 14), "metal", silver)
	part(p, lathe_u([Vector2(4, 16), Vector2(8, 12), Vector2(14, 4), Vector2(17, -6), Vector2(17, -14), Vector2(15.3, -14), Vector2(15.3, -6), Vector2(0, 0)], 22), "metal", silver)
	handle(p, arc2(Vector2(-17, -2), 6, 9, -PI * 0.5, -PI * 1.5), 2.0, silver)
	handle(p, arc2(Vector2(17, -2), 6, 9, -PI * 0.5, PI * 0.5), 2.0, silver)
	part(p, sphere(4.2 * U, 14), "enamel", Color("#FFFFFF"), p3(0, 0, 15.5))
	part(p, cyl(1.2 * U, 1.2 * U, 8 * U, 6), "metal", silver, p3(0, -17))
	# полумесяц покачивается, вокруг звёздочки
	var mo := node(p, p3(2, -33))
	_anim(mo, "wiggle", {"axis": Vector3(0, 0, 1), "amp": 0.12, "spd": 0.9})
	flat(mo, _crescent(), 6, "glow", Color("#FFF2B8"), Vector3.ZERO, Vector3.ZERO, "crescent")
	var stp := star_poly(4.5, 2.0)
	var spts := PackedVector2Array()
	for q in stp:
		spts.append(q)
	for i in 3:
		var sp: Vector3 = [p3(-20, -40, 2), p3(19, -44, -2), p3(22, -24, 3)][i] - p3(2, -33)
		flat(mo, spts, 2, "glow", Color("#FFF7D0"), sp, Vector3(0, 0, i * 0.4), "mstar")
	if not _ghost and high_fx:
		halo(p, p3(2, -33, 2), 0.26, Color(1.0, 0.95, 0.7, 0.4))


func _t_fireflies(p: Node3D) -> void:
	var gold := Color("#FFC94A")
	part(p, lathe_u([Vector2(0, 50), Vector2(21, 50), Vector2(22, 47), Vector2(21, 43), Vector2(9, 38), Vector2(0, 38)], 24), "metal", gold.darkened(0.08))
	part(p, lathe_u([Vector2(5, 38.5), Vector2(5, 32), Vector2(10, 28), Vector2(14, 25), Vector2(0, 25)], 20), "metal", gold)
	handle(p, arc2(Vector2(-22, -6), 8, 12, -PI * 0.55, -PI * 1.45), 2.6, gold)
	handle(p, arc2(Vector2(22, -6), 8, 12, -PI * 0.45, PI * 0.45), 2.6, gold)
	# светлячки внутри банки (летают)
	if not _ghost:
		var sw := node(p, p3(0, -2))
		_anim(sw, "spin", {"spd": 0.7})
		var sw2 := node(sw)
		_anim(sw2, "bob", {"amp": 3.0 * U, "spd": 1.7})
		for i in 6:
			var a := TAU * i / 6.0
			var rr := (5.0 + 8.0 * hash1(i, 9)) * U
			part(sw2, sphere((2.4 + 0.9 * hash1(i, 5)) * U, 8), "glow", Color("#E6FF6A"), Vector3(cos(a) * rr, (i % 3 - 1) * 9.0 * U, sin(a) * rr))
		# мягкий зелёный свет внутри банки
		part(p, sphere(11 * U, 12), "glow_soft", Color("#4F8A1E"), p3(0, -2), Vector3.ZERO, Vector3(1, 1.3, 1))
	part(p, lathe_u([Vector2(17, 25), Vector2(21, 20), Vector2(23, 10), Vector2(22, -16), Vector2(16, -22), Vector2(14, -26), Vector2(13, -26), Vector2(0, -26)], 22), "glass", Color(0.45, 0.85, 0.55, 0.16))
	part(p, lathe_u([Vector2(0, -25), Vector2(16, -26), Vector2(17, -29), Vector2(16, -32), Vector2(7, -34), Vector2(5, -38), Vector2(0, -38)], 24), "metal", gold)
	flat(p, _leaf_poly(), 2.0, "enamel", Color("#5BC27E"), p3(2, -37, 0), Vector3(0, -0.3, 0.5), "leaf")
	gem(p, p3(0, 44, 21), 3 * U, Color("#C6F04A"), "gem", Vector3(-0.4, 0, 0), 6)
	if not _ghost and high_fx:
		halo(p, p3(0, -2, 4), 0.32, Color(0.85, 1.0, 0.35, 0.45))


func _t_crown(p: Node3D) -> void:
	var gold := Color("#FFC94A")
	# бархатная подушка с кисточками
	part(p, sphere(1.0, 24), "velvet", Color("#9A2488"), p3(0, 38), Vector3.ZERO, Vector3(40, 12, 30) * U)
	for i in 4:
		var c := Vector3([-1, 1, 1, -1][i] * 34, 0, [-1, -1, 1, 1][i] * 24) * U + p3(0, 38)
		part(p, sphere(3 * U, 8), "metal", gold, c)
		part(p, cyl(1.0 * U, 3.0 * U, 8 * U, 8), "metal", gold.darkened(0.1), c + Vector3(0, -5, 0) * U)
	# корона: обруч и восемь зубцов с самоцветами; медленно поворачивается
	var cr := node(p, p3(0, 26))
	_anim(cr, "spin", {"spd": 0.22})
	part(cr, lathe_u([Vector2(24, 50), Vector2(25, 47), Vector2(25, 38), Vector2(26, 36), Vector2(23.5, 36), Vector2(23, 48)], 24), "metal", gold)
	var tooth := PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(3, -14), Vector2(0, -22), Vector2(-3, -14)])
	for i in 8:
		var b := i * TAU / 8.0
		var t := node(cr, Vector3(sin(b) * 24.6 * U, 13.5 * U, cos(b) * 24.6 * U))
		t.rotation = Vector3(-0.1, b, 0)
		flat(t, tooth, 3, "metal", gold, Vector3.ZERO, Vector3.ZERO, "tooth")
		gem(t, Vector3(0, 21.5 * U, 1.2 * U), 3.4 * U, Color("#FF8AD8"), "rainbow")
	for i in 8:
		var b := (i + 0.5) * TAU / 8.0
		gem(cr, Vector3(sin(b) * 25.8 * U, 7 * U, cos(b) * 25.8 * U), 3.4 * U, Color("#FF8AD8"), "rainbow", Vector3(0, b, 0))
	if not _ghost and high_fx:
		halo(p, p3(0, 14, 2), 0.34, Color(1.0, 0.6, 0.9, 0.4))
