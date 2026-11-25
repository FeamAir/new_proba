extends RefCounted
## Шейдеры 3D-домов (Cascado 0.12). Все — простые, для GL Compatibility (телефоны с OpenGL ES 3).
## Анимации, которые можно посчитать на видеокарте (пузырьки, светлячки, водоросли, каустика,
## звёзды проектора, фейерверк), считаются в шейдере — процессор телефона не тратится.
## Шейдер создаётся один раз и переиспользуется (get_shader).

static var _cache := {}


static func get_shader(name: String) -> Shader:
	if _cache.has(name):
		return _cache[name]
	var s := Shader.new()
	s.code = CODE[name]
	_cache[name] = s
	return s


static func material(name: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = get_shader(name)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


const CODE := {
	# Небо за окном (плоскость): звёзды мерцают, холмы; aurora > 0 — северное сияние (поздняя ступень)
	"window_sky": """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform float aurora = 0.0;
uniform vec3 top_col = vec3(0.043, 0.031, 0.15);
uniform vec3 bot_col = vec3(0.19, 0.13, 0.38);
uniform vec3 hill_col = vec3(0.10, 0.075, 0.24);
uniform float hill_y = 0.80;
uniform float cave = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	vec3 c = mix(top_col, bot_col, uv.y);
	vec2 g = uv * vec2(26.0, 20.0);
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	if (h > 0.72) {
		vec2 o = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
		float d = length(f - o * 0.6);
		float tw = 0.55 + 0.45 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
		float sz = 0.05 + 0.08 * hash(id + 1.7);
		c += vec3(1.0, 0.96, 0.82) * smoothstep(sz, 0.0, d) * tw * 1.6;
	}
	if (aurora > 0.0) {
		for (int j = 0; j < 3; j++) {
			float fj = float(j);
			float y = 0.3 + fj * 0.08 + 0.05 * sin(uv.x * 7.0 + TIME * 0.4 + fj * 1.7);
			float band = smoothstep(0.0, 0.05, uv.y - y) * smoothstep(0.16, 0.02, uv.y - y);
			vec3 ac = mix(vec3(0.25, 1.0, 0.7), vec3(0.45, 0.6, 1.0), fj * 0.5);
			c += ac * band * 0.9 * aurora * (0.7 + 0.3 * sin(uv.x * 13.0 + TIME + fj));
		}
	}
	float hill = hill_y + 0.04 * sin(uv.x * 9.0) + 0.02 * sin(uv.x * 23.0 + 1.0);
	if (uv.y > hill) {
		c = hill_col;
		// огоньки кристальной пещеры в холме
		if (cave > 0.0) {
			float d = length((uv - vec2(0.68, hill + 0.07)) * vec2(1.0, 1.6));
			c += vec3(0.5, 0.8, 1.0) * smoothstep(0.08, 0.0, d) * (0.8 + 0.2 * sin(TIME * 1.5)) * cave;
			c += vec3(0.7, 0.4, 1.0) * smoothstep(0.03, 0.0, length(uv - vec2(0.64, hill + 0.06))) * cave;
			c += vec3(0.3, 1.0, 0.7) * smoothstep(0.025, 0.0, length(uv - vec2(0.72, hill + 0.075))) * cave;
		}
	}
	ALBEDO = c;
}
""",
	# Небо-купол вокруг сада (сфера изнутри): градиент, звёзды, радуга (rainbow > 0)
	"sky_dome": """
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, depth_draw_never;
uniform float rainbow = 0.0;
varying vec3 dir;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { dir = normalize(VERTEX); }
void fragment() {
	vec3 d = normalize(dir);
	float y = d.y;
	vec3 c = mix(vec3(0.16, 0.11, 0.34), vec3(0.035, 0.025, 0.12), smoothstep(-0.05, 0.6, y));
	c = mix(c, vec3(0.30, 0.18, 0.42), smoothstep(0.25, 0.0, y) * 0.6);
	vec2 sp = vec2(atan(d.z, d.x) * 30.0, y * 40.0);
	vec2 id = floor(sp);
	vec2 f = fract(sp) - 0.5;
	float h = hash(id);
	if (h > 0.8 && y > 0.05) {
		vec2 o = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
		float dd = length(f - o * 0.6);
		float tw = 0.5 + 0.5 * sin(TIME * (1.0 + h * 3.0) + h * 50.0);
		c += vec3(1.0, 0.95, 0.8) * smoothstep(0.05 + 0.1 * hash(id + 1.3), 0.0, dd) * tw * 1.4;
	}
	if (rainbow > 0.0) {
		// радуга: дуга вокруг точки на горизонте (направление -x, -z)
		vec3 ax = normalize(vec3(-0.35, -0.12, -1.0));
		float a = acos(clamp(dot(d, ax), -1.0, 1.0));
		float r = (a - 0.62) / 0.12;
		if (r > 0.0 && r < 1.0 && y > -0.02) {
			vec3 rb = clamp(abs(mod(r * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
			float e = smoothstep(0.0, 0.15, r) * smoothstep(1.0, 0.85, r) * smoothstep(-0.02, 0.15, y);
			c = mix(c, rb, e * 0.45 * rainbow);
		}
	}
	ALBEDO = c;
}
""",
	# Колышется (водоросли, трава, цветы, листья): UV.y — доля высоты (0 у корня, 1 на кончике)
	"sway": """
shader_type spatial;
render_mode cull_disabled;
uniform float amp = 0.08;
uniform float speed = 1.3;
uniform float emit = 0.0;
uniform float rough = 0.9;
void vertex() {
	float w = pow(clamp(UV.y, 0.0, 1.0), 1.5);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = wp.x * 1.7 + wp.z * 1.3;
	VERTEX.x += sin(TIME * speed + ph) * amp * w;
	VERTEX.z += cos(TIME * speed * 0.8 + ph * 1.3) * amp * 0.6 * w;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = rough;
	SPECULAR = 0.2;
	EMISSION = COLOR.rgb * emit;
}
""",
	# Песок дна грота: цвет вершин + бегущие блики каустики
	"caustic": """
shader_type spatial;
uniform float strength = 0.55;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float cell(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float md = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(fract(sin(dot(i + g, vec2(127.1, 311.7))) * 43758.5453), fract(sin(dot(i + g, vec2(269.5, 183.3))) * 43758.5453));
			o = 0.5 + 0.45 * sin(TIME * 0.7 + 6.2831 * o);
			md = min(md, length(g + o - f));
		}
	}
	return md;
}
void fragment() {
	vec2 p = wp.xz * 1.6;
	float c = pow(smoothstep(0.0, 0.9, cell(p)), 3.0) + 0.6 * pow(smoothstep(0.1, 0.95, cell(p * 1.3 + 5.0)), 4.0);
	float fade = smoothstep(4.2, 1.0, length(wp.xz));
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	EMISSION = vec3(0.55, 0.95, 1.0) * c * strength * fade;
}
""",
	# Лучи света сверху (конусы): прозрачные, складываются со светом сцены
	"rays": """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform vec4 col : source_color = vec4(0.6, 1.0, 1.0, 0.16);
void fragment() {
	float v = UV.y;
	float edge = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.6);
	float flick = 0.75 + 0.25 * sin(TIME * 0.9 + UV.x * 12.0);
	float a = col.a * (1.0 - v) * smoothstep(0.0, 0.12, v) * edge * flick;
	ALBEDO = col.rgb * a;
}
""",
	# Поднимающиеся пузырьки: квадраты-«картонки» к камере, движение считает шейдер
	"bubbles": """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform float height = 4.0;
uniform float radius = 2.6;
uniform vec3 center = vec3(0.0);
uniform float size = 0.07;
varying float fade;
float h(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
void vertex() {
	float id = float(INSTANCE_ID);
	float spd = 0.25 + 0.35 * h(id + 1.0);
	float t = fract(TIME * spd / height + h(id + 2.0));
	float a = 6.2831 * h(id + 3.0);
	float r = radius * sqrt(h(id + 4.0));
	vec3 p = center + vec3(cos(a) * r + 0.12 * sin(TIME * 1.7 + id), t * height, sin(a) * r + 0.12 * cos(TIME * 1.3 + id));
	float s = size * (0.5 + h(id + 5.0));
	fade = smoothstep(0.0, 0.08, t) * smoothstep(1.0, 0.85, t);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 w = p + (right * VERTEX.x + up * VERTEX.y) * s * 2.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	float ring = smoothstep(1.0, 0.85, d) * smoothstep(0.55, 0.85, d);
	float hl = smoothstep(0.3, 0.0, length(q - vec2(-0.35, -0.35)));
	ALBEDO = vec3(0.85, 1.0, 1.0);
	ALPHA = clamp(ring * 0.75 + hl * 0.9 + smoothstep(1.0, 0.0, d) * 0.08, 0.0, 1.0) * fade;
}
""",
	# Светлячки: летают и мигают; положение считает шейдер (INSTANCE_ID), центр облака — uniform
	"flies": """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 center = vec3(0.0, 2.4, 0.0);
uniform vec3 spread = vec3(1.8, 1.0, 1.8);
uniform vec4 col : source_color = vec4(1.0, 0.92, 0.45, 1.0);
uniform float size = 0.045;
varying float blink;
float h(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
void vertex() {
	float id = float(INSTANCE_ID);
	float a = 6.2831 * h(id + 1.0) + TIME * (0.08 + 0.12 * h(id + 2.0)) * (mod(id, 2.0) < 1.0 ? 1.0 : -1.0);
	float r = 0.35 + 0.65 * h(id + 3.0);
	vec3 p = center + vec3(cos(a) * r * spread.x, (h(id + 4.0) - 0.5) * 2.0 * spread.y + 0.2 * sin(TIME * (0.6 + h(id + 5.0)) + id), sin(a) * r * spread.z);
	blink = 0.35 + 0.65 * (0.5 + 0.5 * sin(TIME * (2.0 + h(id + 6.0) * 2.0) + id * 1.9));
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 w = p + (right * VERTEX.x + up * VERTEX.y) * size * 2.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float core = smoothstep(0.35, 0.0, d);
	float halo = smoothstep(1.0, 0.0, d) * 0.35;
	ALBEDO = col.rgb * (core * 2.0 + halo) * blink;
}
""",
	# Стены/крыша чердака: цвет вершин + пятна звёзд от проектора (stars > 0)
	"attic": """
shader_type spatial;
uniform float stars = 0.0;
uniform vec3 proj = vec3(0.0, 0.6, 0.0);
uniform float rough = 0.9;
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = rough;
	SPECULAR = 0.15;
	if (stars > 0.0) {
		vec3 d = normalize(wp - proj);
		// звёзды — только на стенах и потолке, повёрнутых к проектору (иначе тянутся полосками)
		float facing = smoothstep(0.25, 0.6, dot(normalize(wn), -d)) * step(0.4, wp.y);
		float a = TIME * 0.04;
		d = vec3(d.x * cos(a) - d.z * sin(a), d.y, d.x * sin(a) + d.z * cos(a));
		vec3 g = d * 7.0;
		vec3 id = floor(g);
		vec3 f = fract(g) - 0.5;
		float h = fract(sin(dot(id, vec3(127.1, 311.7, 74.7))) * 43758.5453);
		vec3 o = vec3(fract(h * 13.7), fract(h * 71.3), fract(h * 37.9)) - 0.5;
		float dd = length(f - o * 0.5);
		float sz = 0.1 + 0.1 * fract(h * 5.3);
		float tw = 0.7 + 0.3 * sin(TIME * 2.0 + h * 30.0);
		vec3 sc = mix(vec3(1.0, 0.92, 0.6), vec3(0.6, 0.8, 1.0), fract(h * 3.1));
		float s = step(0.4, h) * smoothstep(sz, sz * 0.3, dd) * tw;
		EMISSION = sc * s * stars * facing * 2.2 + vec3(0.25, 0.18, 0.45) * stars * 0.1;
	}
}
""",
	# Метка места украшения («+» в кружке) и кольцо примерки: всегда к камере, видны сквозь вещи
	"marker": """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform vec4 col : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float mode = 0.0;
uniform float pulse = 0.0;
uniform float px = 0.06;
void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	float dist = length((VIEW_MATRIX * vec4(c, 1.0)).xyz);
	float s = px * clamp(dist, 0.6, 6.0);
	vec3 w = c + (right * VERTEX.x + up * VERTEX.y) * s * 2.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	float a;
	vec3 c = col.rgb;
	if (mode < 0.5) {
		float disc = smoothstep(0.62, 0.56, d);
		float rim = smoothstep(0.66, 0.6, d) - smoothstep(0.58, 0.52, d);
		float glow = smoothstep(1.0, 0.55, d) * 0.35;
		float plus = max(step(abs(q.x), 0.07) * step(abs(q.y), 0.32), step(abs(q.y), 0.07) * step(abs(q.x), 0.32));
		a = max(disc * 0.38, glow) + rim * 0.6;
		c = mix(vec3(0.16, 0.1, 0.3), col.rgb, 0.35) * (1.0 - plus) + vec3(1.0) * plus;
		a = max(a, plus);
		a *= col.a;
	} else {
		float r = 0.78 + 0.12 * pulse;
		float ring = smoothstep(0.1, 0.0, abs(d - r));
		float glow = smoothstep(0.3, 0.0, abs(d - r)) * 0.4;
		a = (ring + glow) * col.a;
	}
	ALBEDO = c;
	ALPHA = clamp(a, 0.0, 1.0);
}
""",
	# Поверхность воды над гротом (светлая, колышется)
	"water_top": """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
void fragment() {
	vec2 p = UV * 10.0;
	float w = sin(p.x * 1.3 + TIME * 0.9) * sin(p.y * 1.1 - TIME * 0.7) + 0.5 * sin((p.x + p.y) * 2.1 + TIME * 1.3);
	vec3 c = mix(vec3(0.35, 0.85, 0.9), vec3(0.85, 1.0, 1.0), smoothstep(-0.6, 1.2, w));
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = c * (1.4 - 0.6 * d);
}
""",
	# Фейерверк над садом: искры летят из точек вспышек, гаснут; всё в шейдере
	"fireworks": """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float sparks = 28.0;
uniform float size = 0.07;
varying vec3 tint;
varying float life;
float h(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
void vertex() {
	float id = float(INSTANCE_ID);
	float burst = floor(id / sparks);
	float k = mod(id, sparks);
	float period = 3.4;
	float t0 = h(burst + 0.3) * period;
	float cyc = floor((TIME + t0) / period);
	float t = mod(TIME + t0, period);
	float seed = burst * 17.0 + cyc * 3.1;
	vec3 c = vec3(-6.0 + 12.0 * h(seed + 1.0), 6.5 + 2.5 * h(seed + 2.0), -9.0 - 3.0 * h(seed + 3.0));
	float a = 6.2831 * k / sparks;
	float b = acos(1.0 - 2.0 * h(k + 7.0));
	vec3 d = vec3(sin(b) * cos(a), cos(b), sin(b) * sin(a));
	float ex = max(t - 0.15, 0.0);
	vec3 p = c + d * (1.0 - exp(-ex * 2.2)) * 2.0 - vec3(0.0, ex * ex * 0.25, 0.0);
	life = smoothstep(0.1, 0.2, t) * smoothstep(1.9, 0.9, t);
	tint = clamp(abs(mod(h(seed + 4.0) * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0) * 0.7 + 0.3;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 w = p + (right * VERTEX.x + up * VERTEX.y) * size * 2.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	ALBEDO = tint * smoothstep(1.0, 0.0, d) * 1.8 * life;
}
""",
	# Рыбка в картине/аквариуме — плоская (используется для «живой» картины)
	"picture_fish": """
shader_type spatial;
render_mode unshaded;
float fish(vec2 p) {
	float body = length(p * vec2(1.0, 1.7)) - 0.16;
	vec2 tq = p - vec2(-0.2, 0.0);
	float tail = max(abs(tq.y) - (-tq.x) * 0.9, max(tq.x, -tq.x - 0.12));
	return min(body, tail);
}
void fragment() {
	vec2 uv = UV;
	vec3 c = mix(vec3(0.62, 0.88, 1.0), vec3(0.25, 0.5, 0.82), uv.y);
	float x = 0.5 + 0.18 * sin(TIME * 1.2);
	float dir = cos(TIME * 1.2) > 0.0 ? -1.0 : 1.0;
	vec2 p = (uv - vec2(x, 0.48)) * vec2(dir, 1.0);
	float f = fish(p);
	c = mix(c, vec3(1.0, 0.55, 0.24), smoothstep(0.01, -0.01, f));
	c = mix(c, vec3(0.12, 0.07, 0.2), smoothstep(0.03, 0.02, length(p - vec2(0.08, 0.03))));
	float weed = smoothstep(0.03, 0.0, abs(uv.x - 0.2 - 0.03 * sin(uv.y * 9.0 + TIME))) * step(0.55, uv.y);
	c = mix(c, vec3(0.25, 0.7, 0.42), weed);
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 bp = vec2(x + 0.12 * -dir + fi * 0.02, 0.4 - fract(TIME * 0.3 + fi * 0.3) * 0.4);
		c += vec3(0.6) * smoothstep(0.02, 0.012, abs(length(uv - bp) - 0.02));
	}
	ALBEDO = c;
}
""",
}
