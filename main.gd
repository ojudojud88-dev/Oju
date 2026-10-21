extends Node3D
## TURBO DRIFT: game balap 3D realistis (Godot 4.x, renderer Mobile).
## Dunia, HUD, dan kontrol sentuh dibuat lewat kode.

const CarScript := preload("res://car.gd")
const HOLD := ["kiri", "kanan", "gas", "rem", "nitro", "naik", "turun"]
const TAU_R := 6.28318530718
const R_TRACK := 70.0

# Kualitas gambar: 1.0 = normal, 1.4 = lebih tajam (supersampling). Turunkan kalau HP terasa berat.
const RENDER_SCALE := 1.0

# Tanah: rumput detail + bunga, kerikil, aspal retak/bertambal + bekas ban, marka, kerb, garis start
const SHADER_TANAH := """
shader_type spatial;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}
void fragment() {
	vec2 p = wp.xz;
	float r = length(p);
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float fade = clamp(dist / 60.0, 0.0, 1.0);
	float g1 = fbm(p * 0.12);
	float g2 = vnoise(p * 2.5);
	float g3 = vnoise(p * 9.0);

	// rumput
	vec3 grass = mix(vec3(0.10, 0.24, 0.05), vec3(0.30, 0.45, 0.10), g1);
	grass = mix(grass, vec3(0.45, 0.40, 0.18), smoothstep(0.58, 0.82, fbm(p * 0.04 + 7.0)) * 0.55);
	grass *= mix(0.7 + 0.25 * g2 + 0.2 * g3, 1.0, fade);
	vec2 fc = floor(p * 2.0);
	float fl = step(0.985, hash(fc)) * (1.0 - fade);
	grass = mix(grass, mix(vec3(1.0, 0.9, 0.2), vec3(0.95), step(0.5, hash(fc + 3.0))), fl * 0.8);

	// kerikil di pinggir jalan
	float jitter = (g1 - 0.5) * 3.0;
	float gz_out = smoothstep(85.8, 86.6, r) * (1.0 - smoothstep(89.0, 92.0, r + jitter));
	float gz_in = smoothstep(46.0, 50.0, r + jitter) * (1.0 - smoothstep(53.8, 54.2, r));
	float gz = clamp(gz_out + gz_in, 0.0, 1.0);
	vec3 gravel = mix(vec3(0.38, 0.34, 0.30), vec3(0.62, 0.57, 0.50), vnoise(p * 16.0) * 0.6 + vnoise(p * 60.0) * 0.4);
	vec3 ground = mix(grass, gravel, gz);

	// aspal: butiran, retakan, tambalan, bekas ban
	float grain = vnoise(p * 14.0) * 0.5 + vnoise(p * 55.0) * 0.5;
	float patch = fbm(p * 0.35);
	vec3 asp = vec3(0.09) + vec3(0.035) * patch + vec3(0.05) * mix(grain, 0.5, fade);
	float cr = fbm(p * 1.3);
	float crack = (1.0 - smoothstep(0.0, 0.022, abs(cr - 0.52))) * (1.0 - fade);
	asp *= 1.0 - 0.6 * crack;
	asp *= mix(1.0, 0.72, smoothstep(0.62, 0.66, fbm(p * 0.09 + 3.3)));
	float track = clamp((1.0 - smoothstep(0.0, 2.4, abs(r - 63.0))) + (1.0 - smoothstep(0.0, 2.4, abs(r - 77.0))), 0.0, 1.0);
	asp *= 1.0 - 0.3 * track * (0.6 + 0.4 * g2);
	float road = step(55.0, r) * (1.0 - step(85.0, r));

	// marka putih (agak aus), kerb merah-putih, garis start
	float a = atan(p.y, p.x);
	float wear = 0.8 + 0.2 * grain;
	float edge = (1.0 - smoothstep(0.18, 0.23, abs(r - 55.8))) + (1.0 - smoothstep(0.18, 0.23, abs(r - 84.2)));
	float dash = step(0.5, fract(a * 20.0 / 3.14159265));
	float mid = (1.0 - smoothstep(0.1, 0.16, abs(r - 70.0))) * dash;
	float kerb = step(54.2, r) * (1.0 - step(55.0, r)) + step(85.0, r) * (1.0 - step(85.8, r));
	float kc = step(0.5, fract(a * 80.0 / 3.14159265));
	vec3 kerbcol = mix(vec3(0.75, 0.05, 0.05), vec3(0.9), kc);
	float on_line = step(-1.2, p.y) * (1.0 - step(1.2, p.y)) * step(0.0, p.x);
	float chk = mod(floor(p.x) + floor(p.y), 2.0);

	vec3 col = mix(ground, asp, road);
	col = mix(col, vec3(0.85) * wear, clamp(edge + mid, 0.0, 1.0) * road);
	col = mix(col, kerbcol, clamp(kerb, 0.0, 1.0));
	col = mix(col, mix(vec3(0.05), vec3(0.95), chk), on_line * road);

	// bump halus (butiran aspal / tanah)
	float bs = 1.0 - fade;
	float h0 = vnoise(p * 30.0);
	float hx = vnoise((p + vec2(0.03, 0.0)) * 30.0) - h0;
	float hz = vnoise((p + vec2(0.0, 0.03)) * 30.0) - h0;
	vec3 nw = normalize(vec3(-hx * 0.35 * bs, 1.0, -hz * 0.35 * bs));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	ALBEDO = col;
	ROUGHNESS = mix(mix(0.95, 0.85, gz), mix(0.88, 0.66, track), road);
	METALLIC = 0.0;
	SPECULAR = 0.3;
}
"""

# Gedung: rangka beton + jendela kaca memantulkan langit
const SHADER_GEDUNG := """
shader_type spatial;
uniform vec4 beton : source_color = vec4(0.55, 0.55, 0.57, 1.0);
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = abs(wn.x) > 0.5 ? wp.zy : wp.xy;
	vec2 cell = uv / vec2(2.6, 3.6);
	vec2 f = fract(cell);
	float win = step(0.08, f.x) * step(f.x, 0.92) * step(0.1, f.y) * step(f.y, 0.88);
	win *= 1.0 - step(0.5, abs(wn.y));
	float rnd = hash(floor(cell));
	vec3 glass = mix(vec3(0.05, 0.09, 0.15), vec3(0.14, 0.2, 0.28), rnd);
	ALBEDO = mix(beton.rgb, glass, win);
	METALLIC = win * 0.85;
	ROUGHNESS = mix(0.8, 0.08, win);
	SPECULAR = 0.6;
}
"""

const SHADER_RAMPA := """
shader_type spatial;
render_mode cull_disabled;
varying vec3 lp;
varying vec3 ln;
void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	float ax = abs(lp.x);
	float top = step(0.5, ln.y);
	// aspal halus dengan butiran
	float g = hash(floor(lp.xz * 40.0));
	vec3 col = vec3(0.30) + vec3(0.04) * g;
	// tepi: garis kuning-hitam diagonal (peringatan)
	float edge = step(4.15, ax);
	float haz = step(0.5, fract((lp.z - ax) * 0.55));
	col = mix(col, mix(vec3(0.03), vec3(0.95, 0.75, 0.02), haz), edge);
	// garis putih tepi dalam
	col = mix(col, vec3(0.9), (1.0 - smoothstep(0.0, 0.05, abs(ax - 3.9))) * 0.9);
	// panah chevron putih di tengah, menunjuk ke arah lompatan
	float v = fract((lp.z * 0.5 - ax * 0.42) * 0.5);
	float chev = step(0.0, v) * (1.0 - step(0.22, v)) * (1.0 - step(2.6, ax)) * (1.0 - step(13.0, lp.z + 14.0));
	col = mix(col, vec3(0.92), chev);
	// sisi samping & bagian bawah: beton abu
	col = mix(vec3(0.42, 0.42, 0.44), col, top);
	ALBEDO = col;
	ROUGHNESS = mix(0.9, 0.7, top);
	SPECULAR = 0.3;
}
"""

const SHADER_RUMPUT := """
shader_type spatial;
render_mode cull_disabled;
void vertex() {
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sw = sin(TIME * 1.6 + wpos.x * 0.35 + wpos.z * 0.25) * 0.12 * COLOR.a;
	VERTEX.x += sw;
	VERTEX.z += sw * 0.6;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
"""

const SHADER_AWAN := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, fog_disabled;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}
void fragment() {
	vec2 p = wp.xz * 0.0035 + vec2(TIME * 0.004, TIME * 0.0015);
	float c = fbm(p);
	float cov = smoothstep(0.52, 0.78, c);
	float edge = 1.0 - smoothstep(380.0, 780.0, length(wp.xz - CAMERA_POSITION_WORLD.xz));
	vec3 lit = mix(vec3(1.0, 0.78, 0.62), vec3(1.0, 0.96, 0.92), smoothstep(0.55, 0.9, c));
	ALBEDO = lit * 1.1;
	ALPHA = cov * edge * 0.85;
}
"""

const SHADER_BLOB := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
uniform float strength = 0.55;
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - smoothstep(0.35, 1.0, d)) * strength;
}
"""

const SHADER_TRIBUN := """
shader_type spatial;
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = abs(wn.y) > 0.5 ? wp.zx : wp.zy;
	vec2 cell = floor(uv * 1.6);
	vec2 f = fract(uv * 1.6) - 0.5;
	float r = hash(cell);
	vec3 shirt = vec3(0.15, 0.7, 0.35);
	if (r < 0.2) { shirt = vec3(0.9, 0.15, 0.15); }
	else if (r < 0.4) { shirt = vec3(0.95, 0.8, 0.1); }
	else if (r < 0.6) { shirt = vec3(0.15, 0.4, 0.9); }
	else if (r < 0.8) { shirt = vec3(0.95); }
	float head = 1.0 - smoothstep(0.12, 0.16, length(f - vec2(0.0, 0.18)));
	float body = 1.0 - smoothstep(0.26, 0.32, length((f - vec2(0.0, -0.12)) * vec2(1.0, 1.5)));
	vec3 skin = mix(vec3(0.95, 0.75, 0.6), vec3(0.45, 0.3, 0.22), hash(cell + 9.0));
	vec3 col = vec3(0.35, 0.36, 0.4);
	col = mix(col, shirt, body);
	col = mix(col, skin, head);
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
"""

const SHADER_PIT := """
shader_type spatial;
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 col = vec3(0.82, 0.83, 0.86);
	if (wn.x > 0.5) {
		float k = fract((wp.z + 20.0) / 6.0);
		float door = step(0.1, k) * step(k, 0.9) * step(wp.y, 3.2);
		float ribs = step(0.5, fract(wp.y * 5.0));
		vec3 dcol = mix(vec3(0.16, 0.17, 0.2), vec3(0.22, 0.23, 0.27), ribs);
		col = mix(col, dcol, door);
		col = mix(col, vec3(0.85, 0.1, 0.1), step(3.5, wp.y) * step(wp.y, 3.8));
	}
	ALBEDO = col;
	ROUGHNESS = 0.7;
	METALLIC = 0.1;
}
"""

const SHADER_BENDERA := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear;
uniform float geser = 0.0;
void vertex() {
	float k = (UV.x);
	VERTEX.z += sin(TIME * 4.0 + UV.x * 6.0 + geser) * 0.35 * k;
	VERTEX.y += sin(TIME * 3.0 + UV.x * 5.0 + geser) * 0.08 * k;
}
void fragment() {
	vec4 c = texture(tex, vec2(UV.x * 0.25 + geser * 0.25, UV.y));
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.9;
}
"""

const SHADER_GARIS := """
shader_type canvas_item;
uniform float intensity = 0.0;
void fragment() {
	vec2 uv = UV - 0.5;
	float r = length(uv);
	float a = atan(uv.y, uv.x);
	float n = fract(sin(floor(a * 70.0) * 91.7 + floor(TIME * 24.0) * 13.1) * 4375.5);
	float streak = smoothstep(0.6, 1.0, n) * smoothstep(0.28, 0.75, r);
	COLOR = vec4(0.92, 0.96, 1.0, streak * intensity * 0.6);
}
"""

var car
var cam: Camera3D
var blob: MeshInstance3D
var garis_kecepatan: ColorRect
var fov_kick := 0.0
var gl_int := 0.0
var cam_dir := Vector3(0, 0, -1)
var root_ui: Control
var lbl_speed: Label
var lbl_gigi: Label
var bar_rpm: ProgressBar
var sb_rpm_fill: StyleBoxFlat
var bar_nitro: ProgressBar
var layar_muat: ColorRect
var lbl_petunjuk: Label
var tombol := {}
var sentuhan := {}
var aktif := {}
var terbalik_t := 0.0

# ---- balapan ----
var kondisi := "muat"       # muat, tunggu, hitung, jalan
var hitung_t := 0.0
var t_balap := 0.0
var lawan: Array = []       # AI: {car, nama, prog, prev, vmax, lane, look, selesai, waktu, macet, label}
var hantu := {}             # online: id -> {car, nama, prog, p, q, kmh, t, label}
var prog := 0.0
var th_prev := 0.0
var selesai_saya := false
var waktu_saya := 0.0
var hadiah_diberikan := false
var lbl_lap: Label
var lbl_pos: Label
var lbl_hitung: Label
var panel_hasil: PanelContainer
var lbl_hasil: Label
var lbl_hadiah: Label
var lbl_koin: Label
var hasil_online: Array = []   # [{nama, rank, waktu}]
var kirim_t := 0.0
var pesan_t := 0.0


func _ready() -> void:
	randomize()
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_2X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = RENDER_SCALE
	_buat_lingkungan()
	_buat_awan()
	_buat_tanah()
	_buat_rumput()
	_buat_kota()
	_buat_pembatas()
	_buat_pohon()
	_buat_gerbang()
	_buat_baliho()
	_buat_tribun()
	_buat_pit()
	_buat_bendera()
	_buat_logo_lapangan()
	_buat_rampa_semua()
	_buat_kerucut()
	_buat_mobil()
	_buat_blob()
	_buat_kamera()
	_buat_hud()
	_buat_balapan_ui()
	_siapkan_lawan()


# =====================================================================
#  LINGKUNGAN: sore keemasan, bayangan lembut, refleksi langit
# =====================================================================
func _buat_lingkungan() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.18, 0.36, 0.72)
	sky_mat.sky_horizon_color = Color(0.93, 0.74, 0.58)
	sky_mat.sky_curve = 0.2
	sky_mat.ground_horizon_color = Color(0.72, 0.64, 0.55)
	sky_mat.ground_bottom_color = Color(0.22, 0.22, 0.2)
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 30.0
	sky_mat.sun_curve = 0.15
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.74, 0.68)
	env.fog_density = 0.0009
	env.fog_sky_affect = 0.3
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, 30, 0)
	sun.light_color = Color(1.0, 0.85, 0.68)
	sun.light_energy = 1.9
	sun.light_angular_distance = 0.6
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.shadow_blur = 1.0
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

	# probe refleksi: bodi mobil memantulkan langit & gedung (diambil sekali saat start)
	var rp := ReflectionProbe.new()
	rp.position = Vector3(0, 8, 0)
	rp.size = Vector3(500, 80, 500)
	rp.update_mode = ReflectionProbe.UPDATE_ONCE
	rp.box_projection = false
	rp.intensity = 0.5
	add_child(rp)


func _statis_box(ukuran: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	sb.rotation_degrees = rot_deg
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = ukuran
	cs.shape = bs
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = ukuran
	mi.mesh = bm
	mi.material_override = mat
	sb.add_child(mi)
	add_child(sb)
	return sb


# =====================================================================
#  TANAH, JALAN, KOTA, POHON
# =====================================================================
func _buat_tanah() -> void:
	var sh := Shader.new()
	sh.code = SHADER_TANAH
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1600, 1600)
	mi.mesh = pm
	mi.material_override = mat
	add_child(mi)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1600, 2, 1600)
	cs.shape = bs
	cs.position = Vector3(0, -1, 0)
	sb.add_child(cs)
	add_child(sb)


func _buat_awan() -> void:
	var sh := Shader.new()
	sh.code = SHADER_AWAN
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2400, 2400)
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(0, 320, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _buat_rumput() -> void:
	# Rumpun rumput 3D (bergoyang tertiup angin): 5 helai per rumpun, pangkal gelap -> ujung terang
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var ang := i * 2.399
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x)
		var off := dir * randf_range(0.0, 0.18)
		var h := randf_range(0.55, 1.0)
		var w := 0.07
		var tip := off + dir * randf_range(0.05, 0.2) + Vector3(0, h, 0)
		st.set_normal(Vector3.UP)
		st.set_color(Color(0.10, 0.20, 0.05, 0.0))
		st.add_vertex(off - side * w)
		st.set_normal(Vector3.UP)
		st.set_color(Color(0.10, 0.20, 0.05, 0.0))
		st.add_vertex(off + side * w)
		st.set_normal(Vector3.UP)
		st.set_color(Color(0.48, 0.64, 0.22, 1.0))
		st.add_vertex(tip)
	var mesh := st.commit()

	var pusat_rampa := []
	var n := 16000
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	mm.custom_aabb = AABB(Vector3(-300, -1, -300), Vector3(600, 4, 600))
	for i in n:
		var pos := Vector2.ZERO
		var ok := false
		while not ok:
			var t := randf()
			var rr := 0.0
			if t < 0.4:
				rr = sqrt(randf()) * 52.0
			elif t < 0.55:
				rr = randf_range(47.0, 53.5)
			else:
				rr = sqrt(lerpf(89.5 * 89.5, 170.0 * 170.0, randf()))
			var ang := randf() * TAU
			pos = Vector2(cos(ang), sin(ang)) * rr
			ok = true
			for c in pusat_rampa:
				if pos.distance_to(c) < 10.0:
					ok = false
		var sk := randf_range(0.7, 1.5)
		var bas := Basis(Vector3.UP, randf() * TAU) * Basis.from_scale(Vector3(sk, sk * randf_range(0.8, 1.3), sk))
		mm.set_instance_transform(i, Transform3D(bas, Vector3(pos.x, 0.0, pos.y)))
		var v := randf_range(0.65, 1.0)
		mm.set_instance_color(i, Color(v, v, v, 1.0))
	var sh := Shader.new()
	sh.code = SHADER_RUMPUT
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 120.0
	add_child(mi)


func _buat_blob() -> void:
	# bayangan lembut di bawah mobil supaya mobil terlihat menapak di aspal
	var sh := Shader.new()
	sh.code = SHADER_BLOB
	var mat := ShaderMaterial.new()
	mat.shader = sh
	blob = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3.4, 5.8)
	blob.mesh = pm
	blob.material_override = mat
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)


func _buat_kota() -> void:
	# Gedung latar (visual saja): 3 warna beton, tiap warna 1 MultiMesh
	var tint := [Color(0.58, 0.58, 0.6), Color(0.66, 0.6, 0.52), Color(0.48, 0.53, 0.6)]
	var sh := Shader.new()
	sh.code = SHADER_GEDUNG
	for ci in 3:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("beton", tint[ci])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		mm.mesh = bm
		var n := 40
		mm.instance_count = n
		mm.custom_aabb = AABB(Vector3(-600, 0, -600), Vector3(1200, 250, 1200))
		for i in n:
			var x := 0.0
			var z := 0.0
			while maxf(absf(x), absf(z)) < 200.0:
				x = randf_range(-420.0, 420.0)
				z = randf_range(-420.0, 420.0)
			var w := randf_range(14.0, 34.0)
			var d := randf_range(14.0, 34.0)
			var h := randf_range(40.0, 170.0)
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(w, h, d)), Vector3(x, h * 0.5, z)))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		add_child(mi)


func _buat_pembatas() -> void:
	# Pembatas beton merah-putih mengelilingi sirkuit (dengan tabrakan)
	var n := 96
	var r := 87.6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 1.0, 6.0)
	mm.mesh = bm
	mm.instance_count = n
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 1.0, 6.0)
	var body := StaticBody3D.new()
	for i in n:
		var a := i * TAU / n
		var bas := Basis(Vector3.UP, -a)
		var pos := Vector3(cos(a) * r, 0.5, sin(a) * r)
		mm.set_instance_transform(i, Transform3D(bas, pos))
		mm.set_instance_color(i, Color(0.85, 0.85, 0.85) if ((i >> 1) % 2 == 0) else Color(0.72, 0.07, 0.07))
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = Transform3D(bas, pos)
		body.add_child(cs)
	add_child(body)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	add_child(mi)


func _buat_pohon() -> void:
	# Pohon pinus di luar pembatas (2 MultiMesh: daun berwarna acak + batang)
	var n := 220
	var mm_daun := MultiMesh.new()
	mm_daun.transform_format = MultiMesh.TRANSFORM_3D
	mm_daun.use_colors = true
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 1.7
	cm.height = 5.0
	cm.radial_segments = 8
	cm.rings = 1
	mm_daun.mesh = cm
	mm_daun.instance_count = n
	var mm_batang := MultiMesh.new()
	mm_batang.transform_format = MultiMesh.TRANSFORM_3D
	var tm := CylinderMesh.new()
	tm.top_radius = 0.18
	tm.bottom_radius = 0.26
	tm.height = 1.6
	tm.radial_segments = 6
	tm.rings = 1
	mm_batang.mesh = tm
	mm_batang.instance_count = n
	for i in n:
		var x := 0.0
		var z := 0.0
		var ok := false
		while not ok:
			x = randf_range(-185.0, 185.0)
			z = randf_range(-185.0, 185.0)
			ok = Vector2(x, z).length() > 96.0
		var sk := randf_range(0.8, 1.6)
		mm_daun.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(sk, sk, sk)), Vector3(x, 1.4 * sk + 2.5 * sk, z)))
		mm_daun.set_instance_color(i, Color(randf_range(0.07, 0.15), randf_range(0.24, 0.38), randf_range(0.06, 0.12)))
		mm_batang.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(sk, sk, sk)), Vector3(x, 0.8 * sk, z)))
	var mat_daun := StandardMaterial3D.new()
	mat_daun.vertex_color_use_as_albedo = true
	mat_daun.roughness = 0.9
	var mat_batang := StandardMaterial3D.new()
	mat_batang.albedo_color = Color(0.25, 0.16, 0.09)
	mat_batang.roughness = 0.95
	var mi1 := MultiMeshInstance3D.new()
	mi1.multimesh = mm_daun
	mi1.material_override = mat_daun
	add_child(mi1)
	var mi2 := MultiMeshInstance3D.new()
	mi2.multimesh = mm_batang
	mi2.material_override = mat_batang
	add_child(mi2)


func _buat_gerbang() -> void:
	# Gerbang start/finish dari baja di atas garis start
	var baja := StandardMaterial3D.new()
	baja.albedo_color = Color(0.75, 0.77, 0.8)
	baja.metallic = 0.8
	baja.roughness = 0.35
	var gelap := StandardMaterial3D.new()
	gelap.albedo_color = Color(0.05, 0.05, 0.06)
	gelap.roughness = 0.6
	_statis_box(Vector3(0.9, 10.0, 0.9), Vector3(54.0, 5.0, 0.0), baja)
	_statis_box(Vector3(0.9, 10.0, 0.9), Vector3(86.0, 5.0, 0.0), baja)
	var balok := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(34.0, 1.8, 1.2)
	balok.mesh = bm
	balok.material_override = gelap
	balok.position = Vector3(70.0, 9.4, 0.0)
	add_child(balok)
	var lb := Label3D.new()
	lb.text = "START / FINISH"
	lb.font_size = 96
	lb.pixel_size = 0.02
	lb.modulate = Color(1, 1, 1)
	lb.outline_size = 6
	lb.position = Vector3(70.0, 9.4, 0.65)
	add_child(lb)


# =====================================================================
#  DEKORASI: baliho bergambar, tribun, garasi pit, bendera, logo lapangan
# =====================================================================
func _tekstur(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _mat_gambar(tex: Texture2D, terang: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission_energy_multiplier = terang
	m.roughness = 0.6
	return m


func _papan(parent: Node3D, tex: Texture2D, lebar: float, tinggi: float, y: float, kolisi: bool) -> void:
	var rangka_mat := StandardMaterial3D.new()
	rangka_mat.albedo_color = Color(0.1, 0.1, 0.12)
	rangka_mat.metallic = 0.5
	rangka_mat.roughness = 0.5
	# tiang
	for sx in [-1.0, 1.0]:
		var tiang := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, y, 0.5)
		tiang.mesh = bm
		tiang.material_override = rangka_mat
		tiang.position = Vector3(sx * (lebar * 0.5 - 1.0), y * 0.5 - 0.5, -0.35)
		parent.add_child(tiang)
	# rangka + gambar
	var rangka := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(lebar + 0.8, tinggi + 0.8, 0.4)
	rangka.mesh = rm
	rangka.material_override = rangka_mat
	rangka.position = Vector3(0, y, 0)
	parent.add_child(rangka)
	var gambar := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(lebar, tinggi)
	gambar.mesh = qm
	gambar.material_override = _mat_gambar(tex)
	gambar.position = Vector3(0, y, 0.22)
	gambar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(gambar)
	if kolisi:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(lebar, y + tinggi * 0.5, 1.0)
		cs.shape = bs
		cs.position = Vector3(0, (y + tinggi * 0.5) * 0.5, 0)
		sb.add_child(cs)
		parent.add_child(sb)


func _buat_baliho() -> void:
	var daftar := ["res://tex/bb_turbo.png", "res://tex/bb_nitro.png", "res://tex/bb_gp.png", "res://tex/bb_v12.png"]
	var tex: Array = []
	for pth in daftar:
		tex.append(_tekstur(pth))
	if tex[0] == null:
		return
	# baliho besar di luar sirkuit, menghadap ke tengah
	var sudut_luar := [0.75, 1.4, 2.05, 2.7, 3.35, 4.0, 4.65, 5.3, 5.85]
	for i in sudut_luar.size():
		var a: float = sudut_luar[i]
		var arah_ke_pusat := Vector3(-cos(a), 0, -sin(a))
		var n := Node3D.new()
		n.position = Vector3(cos(a), 0, sin(a)) * 100.0
		n.basis = Basis.looking_at(-arah_ke_pusat, Vector3.UP)
		add_child(n)
		_papan(n, tex[i % 4], 20.0, 10.0, 9.0, false)
	# baliho di lapangan tengah, menghadap ke jalan (berkolisi)
	var sudut_dalam := [0.9, 2.45, 3.95, 5.4]
	for i in sudut_dalam.size():
		var a2: float = sudut_dalam[i]
		var keluar := Vector3(cos(a2), 0, sin(a2))
		var n2 := Node3D.new()
		n2.position = keluar * 34.0
		n2.basis = Basis.looking_at(-keluar, Vector3.UP)
		add_child(n2)
		_papan(n2, tex[(i + 1) % 4], 14.0, 7.0, 6.0, true)


func _buat_tribun() -> void:
	# Tribun penonton di sisi luar lintasan lurus start (sumbu +X), lengkap dengan atap
	var sh := Shader.new()
	sh.code = SHADER_TRIBUN
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var panjang := 46.0
	for t in 6:
		var h := 1.3 * (t + 1)
		var bm := BoxMesh.new()
		bm.size = Vector3(3.0, h, panjang)
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(93.0 + 3.0 * t + 1.5, h * 0.5, 0.0)
		add_child(mi)
	var atap_mat := StandardMaterial3D.new()
	atap_mat.albedo_color = Color(0.85, 0.85, 0.88)
	atap_mat.metallic = 0.4
	atap_mat.roughness = 0.5
	var atap := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(20.0, 0.35, panjang + 2.0)
	atap.mesh = am
	atap.material_override = atap_mat
	atap.position = Vector3(102.0, 11.5, 0.0)
	atap.rotation_degrees = Vector3(0, 0, -4)
	add_child(atap)
	for z in [-panjang * 0.5, 0.0, panjang * 0.5]:
		var tiang := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.5, 11.0, 0.5)
		tiang.mesh = tm
		tiang.material_override = atap_mat
		tiang.position = Vector3(92.0, 5.5, z)
		add_child(tiang)
	# pagar depan tribun
	_statis_box(Vector3(0.4, 1.2, panjang), Vector3(91.2, 0.6, 0.0), atap_mat)


func _buat_pit() -> void:
	# Garasi pit di lapangan tengah, menghadap lintasan start
	var sh := Shader.new()
	sh.code = SHADER_PIT
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var b := _statis_box(Vector3(6.0, 4.2, 40.0), Vector3(42.0, 2.1, 0.0), mat)
	var atap_mat := StandardMaterial3D.new()
	atap_mat.albedo_color = Color(0.2, 0.2, 0.24)
	atap_mat.metallic = 0.4
	var teras := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(8.5, 0.3, 41.0)
	teras.mesh = tm
	teras.material_override = atap_mat
	teras.position = Vector3(43.5, 4.35, 0.0)
	add_child(teras)
	var tex := _tekstur("res://tex/pit.png")
	if tex != null:
		var papan := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(16.0, 4.0)
		papan.mesh = qm
		papan.material_override = _mat_gambar(tex, 0.9)
		papan.position = Vector3(46.4, 6.2, 0.0)
		papan.basis = Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP)
		papan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(papan)


func _buat_bendera() -> void:
	var tex := _tekstur("res://tex/pennant.png")
	var tiang_mat := StandardMaterial3D.new()
	tiang_mat.albedo_color = Color(0.85, 0.85, 0.88)
	tiang_mat.metallic = 0.7
	tiang_mat.roughness = 0.35
	var sh := Shader.new()
	sh.code = SHADER_BENDERA
	var n := 22
	for i in n:
		var a := (float(i) + 0.5) * TAU / float(n)
		if absf(wrapf(a, -PI, PI)) < 0.45:
			continue    # area tribun
		var pos := Vector3(cos(a), 0, sin(a)) * 90.4
		var tiang := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.1
		cm.height = 9.0
		cm.radial_segments = 8
		tiang.mesh = cm
		tiang.material_override = tiang_mat
		tiang.position = pos + Vector3(0, 4.5, 0)
		add_child(tiang)
		if tex != null:
			var mat := ShaderMaterial.new()
			mat.shader = sh
			mat.set_shader_parameter("tex", tex)
			mat.set_shader_parameter("geser", float(i % 4))
			var bendera := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(2.6, 1.6)
			qm.subdivide_width = 8
			bendera.mesh = qm
			bendera.material_override = mat
			bendera.position = pos + Vector3(0, 8.0, 0)
			bendera.basis = Basis(Vector3.UP, -a + PI * 0.5)
			bendera.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bendera.translate_object_local(Vector3(1.4, 0, 0))
			add_child(bendera)


func _buat_logo_lapangan() -> void:
	var tex := _tekstur("res://tex/logo_lapangan.png")
	if tex == null:
		return
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(66, 66)
	mi.mesh = pm
	mi.material_override = m
	mi.position = Vector3(0, 0.04, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# =====================================================================
#  RAMPA & KERUCUT
# =====================================================================
func _buat_rampa_semua() -> void:
	# 3 lompatan meja (table-top) di atas jalan sirkuit, sejajar arah balap
	var sh := Shader.new()
	sh.code = SHADER_RAMPA
	var mat := ShaderMaterial.new()
	mat.shader = sh
	for sudut in [100.0, 205.0, 300.0]:
		_lompatan(sudut, mat)


func _lompatan(sudut_deg: float, mat: Material) -> void:
	# Profil (z, y): tanjakan melengkung halus -> meja datar -> turunan landai.
	var lebar := 10.0
	var hw := lebar * 0.5
	var l_naik := 12.0
	var l_meja := 6.0
	var l_turun := 14.0
	var tinggi := 1.9
	var total := l_naik + l_meja + l_turun
	var prof: Array = []
	var nn := 16
	for i in nn + 1:
		var u := float(i) / float(nn)
		prof.append(Vector2(-total * 0.5 + u * l_naik, tinggi * u * u * (1.2 - 0.2 * u)))
	prof.append(Vector2(-total * 0.5 + l_naik + l_meja, tinggi))
	for i in 1 + nn:
		var u := float(i) / float(nn)
		prof.append(Vector2(-total * 0.5 + l_naik + l_meja + u * l_turun, tinggi * (1.0 - u * u * (3.0 - 2.0 * u))))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tutup_bawah := -0.25
	for i in prof.size() - 1:
		var p0: Vector2 = prof[i]
		var p1: Vector2 = prof[i + 1]
		var n_atas := Vector3(0.0, p1.x - p0.x, -(p1.y - p0.y)).normalized()
		var a := Vector3(-hw, p0.y, p0.x)
		var b := Vector3(hw, p0.y, p0.x)
		var c := Vector3(-hw, p1.y, p1.x)
		var d := Vector3(hw, p1.y, p1.x)
		# permukaan atas
		for v in [a, b, c, b, d, c]:
			st.set_normal(n_atas)
			st.add_vertex(v)
		# dinding samping kiri & kanan sampai di bawah tanah
		var al := Vector3(-hw, tutup_bawah, p0.x)
		var cl := Vector3(-hw, tutup_bawah, p1.x)
		var br := Vector3(hw, tutup_bawah, p0.x)
		var dr := Vector3(hw, tutup_bawah, p1.x)
		for v in [al, a, c, al, c, cl]:
			st.set_normal(Vector3(-1, 0, 0))
			st.add_vertex(v)
		for v in [br, d, b, br, dr, d]:
			st.set_normal(Vector3(1, 0, 0))
			st.add_vertex(v)
	# dinding belakang meja (tidak ada celah) dan alas
	var mesh := st.commit()

	var a_rad := deg_to_rad(sudut_deg)
	var sb := StaticBody3D.new()
	sb.position = Vector3(cos(a_rad) * 70.0, 0.0, sin(a_rad) * 70.0)
	sb.rotation = Vector3(0.0, PI - a_rad, 0.0)
	var cs := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape() as ConcavePolygonShape3D
	shape.backface_collision = true
	cs.shape = shape
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	sb.add_child(mi)
	add_child(sb)


func _buat_kerucut() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.33, 0.04)
	mat.roughness = 0.6
	for i in 36:
		var ang := randf_range(0.25, TAU - 0.25)
		var r := randf_range(58.0, 82.0)
		var di_lompatan := false
		for sd in [100.0, 205.0, 300.0]:
			var rc := Vector2(cos(deg_to_rad(sd)), sin(deg_to_rad(sd))) * 70.0
			if (Vector2(cos(ang), sin(ang)) * r).distance_to(rc) < 16.0:
				di_lompatan = true
		if di_lompatan:
			continue
		var rb := RigidBody3D.new()
		rb.mass = 2.0
		rb.position = Vector3(cos(ang) * r, 0.45, sin(ang) * r)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.28
		cyl.height = 0.8
		cs.shape = cyl
		rb.add_child(cs)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.3
		cm.height = 0.8
		cm.radial_segments = 12
		mi.mesh = cm
		mi.material_override = mat
		rb.add_child(mi)
		add_child(rb)


# =====================================================================
#  MOBIL & KAMERA
# =====================================================================
func _slot_xf(idx: int) -> Array:
	# grid start di belakang garis (z > 0), menghadap searah putaran (-Z di garis start)
	var baris := idx / 2
	var sisi := idx % 2
	var th := 0.055 * float(baris + 1) * (1.0 if idx > 0 else 0.0) + (0.0 if idx > 0 else 0.0)
	if idx == 0:
		th = 0.04
	var r := 62.0 + 16.0 * float(sisi)
	var pos := Vector3(cos(th) * r, 0.8, sin(th) * r)
	var dir := Vector3(sin(th), 0.0, -cos(th))
	return [pos, dir, th]


func _buat_mobil() -> void:
	car = CarScript.new()
	car.profil = Gm.profil(Gm.terpilih)
	var idx := 0
	if Gm.mode == "online" and Net.aktif:
		idx = Net.slot
	var sl := _slot_xf(idx)
	car.position = sl[0]
	car.spawn_pos = sl[0]
	car.spawn_dir = sl[1]
	prog = -float(sl[2])
	th_prev = atan2(sl[0].z, sl[0].x)
	add_child(car)
	car.siap.connect(_on_siap)
	car.nitro_mulai.connect(_on_nitro)


func _buat_kamera() -> void:
	cam = Camera3D.new()
	cam.fov = 58.0
	cam.near = 0.1
	cam.far = 1200.0
	add_child(cam)
	cam.make_current()
	cam.global_position = car.global_position + Vector3(0, 3, 7)


func _update_kamera(delta: float) -> void:
	var f: Vector3 = car.get_forward()
	f.y = 0.0
	if f.length() < 0.01:
		f = cam_dir
	f = f.normalized()
	cam_dir = cam_dir.lerp(f, 1.0 - exp(-3.5 * delta)).normalized()
	var sr := clampf(car.kmh / 300.0, 0.0, 1.0)
	var pos: Vector3 = car.global_position
	var terb := 1.0 if car.terbang_on else 0.0
	var want := pos - cam_dir * (4.7 + sr * 1.6 + terb * 2.2) + Vector3(0, 1.4 + sr * 0.3 + terb * 1.4, 0)
	cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-9.0 * delta))
	cam.look_at(pos + cam_dir * 3.0 + Vector3(0, 0.75, 0), Vector3.UP)
	var boost: bool = car.boost_aktif
	var fov_t := 58.0 + sr * 20.0 + (14.0 if boost else 0.0)
	fov_kick = lerpf(fov_kick, 0.0, 1.0 - exp(-5.0 * delta))
	cam.fov = lerpf(cam.fov, fov_t + fov_kick, 1.0 - exp(-4.0 * delta))
	if boost:
		cam.h_offset = randf_range(-0.04, 0.04)
		cam.v_offset = randf_range(-0.04, 0.04)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


# =====================================================================
#  HUD & KONTROL SENTUH (multi-touch)
# =====================================================================
func _buat_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	root_ui = Control.new()
	root_ui.anchor_right = 1.0
	root_ui.anchor_bottom = 1.0
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root_ui)

	var gs := Shader.new()
	gs.code = SHADER_GARIS
	var gm := ShaderMaterial.new()
	gm.shader = gs
	garis_kecepatan = ColorRect.new()
	garis_kecepatan.anchor_right = 1.0
	garis_kecepatan.anchor_bottom = 1.0
	garis_kecepatan.material = gm
	garis_kecepatan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(garis_kecepatan)

	var putih := Color(1, 1, 1)
	_tombol("kiri", "<", 0.0, 1.0, 40, -210, 170, 170, putih, 64)
	_tombol("kanan", ">", 0.0, 1.0, 230, -210, 170, 170, putih, 64)
	_tombol("rem", "REM", 1.0, 1.0, -400, -190, 170, 150, Color(1.0, 0.5, 0.45), 38)
	_tombol("gas", "GAS", 1.0, 1.0, -210, -250, 170, 210, Color(0.6, 0.95, 0.65), 44)
	_tombol("nitro", "NITRO", 1.0, 1.0, -400, -350, 170, 140, Color(0.6, 0.82, 1.0), 32)
	_tombol("ulang", "ULANG", 0.0, 0.0, 20, 20, 130, 60, putih, 24)
	_tombol("terbang", "TERBANG", 0.0, 0.0, 20, 175, 190, 70, Color(0.55, 0.8, 1.0), 26)
	_tombol("naik", "NAIK", 0.0, 1.0, 40, -400, 170, 170, Color(0.55, 0.8, 1.0), 40)
	_tombol("turun", "TURUN", 0.0, 1.0, 230, -400, 170, 170, Color(1.0, 0.75, 0.5), 36)
	for n in ["terbang", "naik", "turun"]:
		tombol[n]["node"].visible = false

	lbl_speed = Label.new()
	lbl_speed.anchor_left = 1.0
	lbl_speed.anchor_right = 1.0
	lbl_speed.offset_left = -300
	lbl_speed.offset_right = -30
	lbl_speed.offset_top = 10
	lbl_speed.offset_bottom = 110
	lbl_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_speed.add_theme_font_size_override("font_size", 80)
	lbl_speed.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	lbl_speed.add_theme_constant_override("outline_size", 8)
	lbl_speed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(lbl_speed)

	var unit := Label.new()
	unit.text = "KM/J"
	unit.anchor_left = 1.0
	unit.anchor_right = 1.0
	unit.offset_left = -300
	unit.offset_right = -30
	unit.offset_top = 105
	unit.offset_bottom = 140
	unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	unit.add_theme_font_size_override("font_size", 24)
	unit.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	unit.add_theme_constant_override("outline_size", 6)
	unit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(unit)

	bar_rpm = ProgressBar.new()
	bar_rpm.anchor_left = 1.0
	bar_rpm.anchor_right = 1.0
	bar_rpm.offset_left = -300
	bar_rpm.offset_right = -30
	bar_rpm.offset_top = 148
	bar_rpm.offset_bottom = 162
	bar_rpm.max_value = 100.0
	bar_rpm.show_percentage = false
	bar_rpm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb_rpm_bg := StyleBoxFlat.new()
	sb_rpm_bg.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	sb_rpm_bg.set_corner_radius_all(7)
	sb_rpm_fill = StyleBoxFlat.new()
	sb_rpm_fill.bg_color = Color(0.95, 0.95, 0.95)
	sb_rpm_fill.set_corner_radius_all(7)
	bar_rpm.add_theme_stylebox_override("background", sb_rpm_bg)
	bar_rpm.add_theme_stylebox_override("fill", sb_rpm_fill)
	root_ui.add_child(bar_rpm)

	lbl_gigi = Label.new()
	lbl_gigi.anchor_left = 1.0
	lbl_gigi.anchor_right = 1.0
	lbl_gigi.offset_left = -300
	lbl_gigi.offset_right = -30
	lbl_gigi.offset_top = 166
	lbl_gigi.offset_bottom = 210
	lbl_gigi.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_gigi.add_theme_font_size_override("font_size", 32)
	lbl_gigi.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	lbl_gigi.add_theme_constant_override("outline_size", 6)
	lbl_gigi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(lbl_gigi)

	bar_nitro = ProgressBar.new()
	bar_nitro.anchor_left = 0.5
	bar_nitro.anchor_right = 0.5
	bar_nitro.offset_left = -160
	bar_nitro.offset_right = 160
	bar_nitro.offset_top = 24
	bar_nitro.offset_bottom = 42
	bar_nitro.max_value = 100.0
	bar_nitro.show_percentage = false
	bar_nitro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	sb_bg.set_corner_radius_all(9)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.45, 0.75, 1.0)
	sb_fill.set_corner_radius_all(9)
	bar_nitro.add_theme_stylebox_override("background", sb_bg)
	bar_nitro.add_theme_stylebox_override("fill", sb_fill)
	root_ui.add_child(bar_nitro)

	lbl_petunjuk = Label.new()
	lbl_petunjuk.text = "Tahan REM sambil belok = DRIFT   |   NITRO = boost   |   Keyboard: WASD/Panah, Spasi, Shift, R"
	lbl_petunjuk.anchor_left = 0.5
	lbl_petunjuk.anchor_right = 0.5
	lbl_petunjuk.anchor_top = 1.0
	lbl_petunjuk.anchor_bottom = 1.0
	lbl_petunjuk.offset_left = -500
	lbl_petunjuk.offset_right = 500
	lbl_petunjuk.offset_top = -50
	lbl_petunjuk.offset_bottom = -15
	lbl_petunjuk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_petunjuk.add_theme_font_size_override("font_size", 20)
	lbl_petunjuk.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	lbl_petunjuk.add_theme_constant_override("outline_size", 5)
	lbl_petunjuk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(lbl_petunjuk)

	# layar loading (mobil dikalibrasi sebentar saat start)
	layar_muat = ColorRect.new()
	layar_muat.color = Color(0.06, 0.07, 0.09)
	layar_muat.anchor_right = 1.0
	layar_muat.anchor_bottom = 1.0
	layar_muat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gbr := _tekstur("res://tex/loading.png")
	if gbr != null:
		var tr := TextureRect.new()
		tr.texture = gbr
		tr.anchor_right = 1.0
		tr.anchor_bottom = 1.0
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layar_muat.add_child(tr)
	var jdl := Label.new()
	jdl.text = "%s\n%s\nmenyiapkan mobil..." % [car.profil.get("nama", ""), car.profil.get("info", "")]
	jdl.anchor_right = 1.0
	jdl.anchor_bottom = 1.0
	jdl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jdl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	jdl.offset_bottom = -30
	jdl.add_theme_font_size_override("font_size", 30)
	jdl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	jdl.add_theme_constant_override("outline_size", 8)
	jdl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layar_muat.add_child(jdl)
	root_ui.add_child(layar_muat)


func _tombol(nama: String, teks: String, ax: float, ay: float, ox: float, oy: float, w: float, h: float, warna: Color, fs: int) -> void:
	var p := Panel.new()
	p.anchor_left = ax
	p.anchor_right = ax
	p.anchor_top = ay
	p.anchor_bottom = ay
	p.offset_left = ox
	p.offset_top = oy
	p.offset_right = ox + w
	p.offset_bottom = oy + h
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(warna.r, warna.g, warna.b, 0.18)
	sb.border_color = Color(warna.r, warna.g, warna.b, 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(28)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = teks
	l.anchor_right = 1.0
	l.anchor_bottom = 1.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", warna)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	root_ui.add_child(p)
	tombol[nama] = {"node": p, "sb": sb, "warna": warna}


func _tombol_di(pos: Vector2) -> String:
	for n in tombol:
		var r: Rect2 = tombol[n]["node"].get_global_rect().grow(8.0)
		if r.has_point(pos):
			return n
	return ""


func _aksi(n: String) -> void:
	if n == "ulang":
		car.tegakkan()
	elif n == "terbang":
		car.toggle_terbang()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.physical_keycode == KEY_R:
				_aksi("ulang")
			elif event.physical_keycode == KEY_F:
				_aksi("terbang")
	elif event is InputEventScreenTouch:
		if event.pressed:
			var n := _tombol_di(event.position)
			if n in HOLD:
				sentuhan[event.index] = n
			elif n != "":
				_aksi(n)
		else:
			sentuhan.erase(event.index)
	elif event is InputEventScreenDrag:
		var n2 := _tombol_di(event.position)
		if n2 in HOLD:
			sentuhan[event.index] = n2
		else:
			sentuhan.erase(event.index)


func _on_nitro() -> void:
	fov_kick = 12.0


func _on_siap() -> void:
	if Gm.mode == "online" and Net.aktif:
		kondisi = "tunggu"
		lbl_hitung.text = "Menunggu pemain lain..."
		lbl_hitung.visible = true
		lbl_hitung.add_theme_font_size_override("font_size", 56)
		Net.lapor_muat()
	else:
		kondisi = "hitung"
		hitung_t = 3.6
	cam_dir = car.get_forward()
	cam_dir.y = 0.0
	cam_dir = cam_dir.normalized()
	cam.global_position = car.global_position - cam_dir * 5.0 + Vector3(0, 1.8, 0)
	var tw := create_tween()
	tw.tween_property(layar_muat, "modulate:a", 0.0, 0.8)
	tw.tween_callback(layar_muat.queue_free)
	var tw2 := create_tween()
	tw2.tween_interval(9.0)
	tw2.tween_property(lbl_petunjuk, "modulate:a", 0.0, 1.5)


# =====================================================================
#  BALAPAN: lawan AI, putaran, posisi, hasil
# =====================================================================
func _lbl(teks: String, fs: int, ax: float, ay: float, ox: float, oy: float, w: float, h: float, rata: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = teks
	l.anchor_left = ax
	l.anchor_right = ax
	l.anchor_top = ay
	l.anchor_bottom = ay
	l.offset_left = ox
	l.offset_top = oy
	l.offset_right = ox + w
	l.offset_bottom = oy + h
	l.horizontal_alignment = rata
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(l)
	return l


func _buat_balapan_ui() -> void:
	lbl_lap = _lbl("PUTARAN 1/%d" % Gm.PUTARAN, 34, 0.0, 0.0, 20, 255, 360, 44)
	lbl_pos = _lbl("POSISI 1/1", 44, 0.0, 0.0, 20, 295, 360, 56)
	lbl_hitung = _lbl("", 150, 0.5, 0.5, -400, -190, 800, 240, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_hitung.visible = false

	panel_hasil = PanelContainer.new()
	panel_hasil.anchor_left = 0.5
	panel_hasil.anchor_right = 0.5
	panel_hasil.anchor_top = 0.5
	panel_hasil.anchor_bottom = 0.5
	panel_hasil.offset_left = -330
	panel_hasil.offset_right = 330
	panel_hasil.offset_top = -270
	panel_hasil.offset_bottom = 270
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.92)
	sb.border_color = Color(1.0, 0.75, 0.2)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(26)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	panel_hasil.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel_hasil.add_child(vb)
	var jd := Label.new()
	jd.text = "BALAPAN SELESAI"
	jd.add_theme_font_size_override("font_size", 46)
	jd.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	jd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(jd)
	lbl_hasil = Label.new()
	lbl_hasil.add_theme_font_size_override("font_size", 28)
	lbl_hasil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(lbl_hasil)
	lbl_hadiah = Label.new()
	lbl_hadiah.add_theme_font_size_override("font_size", 34)
	lbl_hadiah.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	lbl_hadiah.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lbl_hadiah)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	var b1 := Button.new()
	b1.text = "LOBI"
	b1.custom_minimum_size = Vector2(240, 80)
	b1.add_theme_font_size_override("font_size", 34)
	b1.pressed.connect(_ke_lobi)
	hb.add_child(b1)
	if Gm.mode != "online":
		var b2 := Button.new()
		b2.text = "ULANGI"
		b2.custom_minimum_size = Vector2(240, 80)
		b2.add_theme_font_size_override("font_size", 34)
		b2.pressed.connect(func(): get_tree().reload_current_scene())
		hb.add_child(b2)
	panel_hasil.visible = false
	root_ui.add_child(panel_hasil)

	lbl_koin = _lbl("", 30, 0.5, 0.0, -300, 52, 600, 40, HORIZONTAL_ALIGNMENT_CENTER)

	if Gm.mode == "online" and Net.aktif:
		Net.state_masuk.connect(_on_state)
		Net.go_serempak.connect(_on_go)
		Net.info_selesai.connect(_on_info_selesai)
		Net.daftar_berubah.connect(_on_daftar)
		Net.putus.connect(_ke_lobi)
		Net.pesan.connect(func(t): lbl_koin.text = t)


func _ke_lobi() -> void:
	if Net.aktif:
		Net.kembali_lobi()
	get_tree().change_scene_to_file("res://lobi.tscn")


func _label3d(teks: String) -> Label3D:
	var lb := Label3D.new()
	lb.text = teks
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.pixel_size = 0.008
	lb.font_size = 48
	lb.outline_size = 12
	lb.position = Vector3(0, 2.0, 0)
	return lb


func _siapkan_lawan() -> void:
	if Gm.mode == "online":
		_siapkan_hantu()
		return
	var nama_ai := ["Rizky", "Dewi", "Bima", "Sari", "Joko"]
	var lane := [78.0, 58.0, 80.0, 60.0, 78.0]
	var pilihan := ["rosso", "nero", "giallo", "rosso", "nero"]
	for i in clampi(Gm.jumlah_lawan, 1, 5):
		var c = CarScript.new()
		c.profil = Gm.profil(pilihan[i]).duplicate()
		c.suara = false
		var sl := _slot_xf(i + 1)
		c.position = sl[0]
		c.spawn_pos = sl[0]
		c.spawn_dir = sl[1]
		add_child(c)
		var lb := _label3d(nama_ai[i])
		c.add_child(lb)
		lawan.append({
			"car": c, "nama": nama_ai[i], "prog": -float(sl[2]), "prev": atan2(sl[0].z, sl[0].x),
			"vmax": randf_range(0.92, 1.0) * sqrt(17.0 * lane[i]), "lane": lane[i], "look": randf_range(0.11, 0.15),
			"selesai": false, "waktu": 0.0, "macet": 0.0, "lbl": lb,
		})


func _selisih_sudut(th: float, prev: float) -> float:
	var d := -(th - prev)
	return fposmod(d + PI, TAU_R) - PI


func _ke_lintasan(c) -> void:
	var p: Vector3 = c.global_position
	var th := atan2(p.z, p.x)
	var pos := Vector3(cos(th) * R_TRACK, 1.0, sin(th) * R_TRACK)
	var dir := Vector3(sin(th), 0.0, -cos(th))
	c.reset_car(Transform3D(c._basis_menghadap(dir), pos))
	if c == car:
		cam_dir = dir


func _ai_step(a: Dictionary, delta: float) -> void:
	var c = a["car"]
	if c._fase < 2:
		return
	var p: Vector3 = c.global_position
	var th := atan2(p.z, p.x)
	var th_t: float = th - float(a["look"])
	var r_t: float = a["lane"]
	var tgt := Vector3(cos(th_t) * r_t, 0.0, sin(th_t) * r_t)
	var f: Vector3 = c.get_forward()
	f.y = 0.0
	f = f.normalized()
	var to := tgt - Vector3(p.x, 0.0, p.z)
	var kiri_v := Vector3.UP.cross(f)
	var ang := atan2(to.dot(kiri_v), maxf(to.dot(f), 0.1))
	c.stir_in = clampf(ang * 1.8, -1.0, 1.0)
	var vm: float = a["vmax"]
	# karet gelang: tertinggal jauh dikebut, terlalu jauh di depan diperlambat
	var selisih: float = float(a["prog"]) - prog
	if selisih > 0.5:
		vm *= 0.88
	elif selisih < -0.4:
		vm *= 1.08
	var v: float = c.kmh / 3.6
	var jalan := kondisi == "jalan"
	c.gas = 1.0 if (jalan and v < vm) else 0.0
	c.rem_in = 1.0 if (jalan and v > vm * 1.15) else 0.0
	c.parkir = not jalan
	c.nitro_on = false
	# anti macet / terbalik
	if jalan and c.kmh < 6.0:
		a["macet"] += delta
	else:
		a["macet"] = 0.0
	if c.terbalik() and c.kmh < 8.0:
		a["macet"] += delta * 2.0
	if a["macet"] > 3.0 or c.global_position.y < -10.0 or c.global_position.length() > 200.0:
		a["macet"] = 0.0
		_ke_lintasan(c)


func _update_balapan(delta: float) -> void:
	# hitung mundur
	if kondisi == "hitung":
		hitung_t -= delta
		lbl_hitung.visible = true
		if hitung_t > 3.0:
			lbl_hitung.text = ""
		elif hitung_t > 0.0:
			lbl_hitung.text = str(int(ceil(hitung_t)))
		else:
			kondisi = "jalan"
			t_balap = 0.0
			lbl_hitung.text = "GO!"
			var tw := create_tween()
			tw.tween_interval(0.8)
			tw.tween_callback(func(): lbl_hitung.visible = false)
	elif kondisi == "jalan":
		t_balap += delta

	# kemajuan putaran pemain
	if kondisi == "jalan" and not selesai_saya:
		var th := atan2(car.global_position.z, car.global_position.x)
		prog += _selisih_sudut(th, th_prev)
		th_prev = th
		if prog >= TAU_R * float(Gm.PUTARAN):
			_selesai_pemain()
	elif kondisi != "jalan":
		th_prev = atan2(car.global_position.z, car.global_position.x)

	for a in lawan:
		var c = a["car"]
		_ai_step(a, delta)
		if kondisi == "jalan":
			var th2 := atan2(c.global_position.z, c.global_position.x)
			a["prog"] += _selisih_sudut(th2, a["prev"])
			a["prev"] = th2
			if not a["selesai"] and a["prog"] >= TAU_R * float(Gm.PUTARAN):
				a["selesai"] = true
				a["waktu"] = t_balap
		else:
			a["prev"] = atan2(c.global_position.z, c.global_position.x)

	# online: kirim posisi ~15x/detik
	if Gm.mode == "online" and Net.aktif and kondisi == "jalan":
		kirim_t -= delta
		if kirim_t <= 0.0:
			kirim_t = 0.066
			Net.kirim_state({"p": car.global_position, "q": Quaternion(car.global_transform.basis.orthonormalized()), "k": car.kmh, "t": car.terbang_on, "prog": prog})

	# HUD putaran & posisi
	var lap := clampi(int(floor(maxf(prog, 0.0) / TAU_R)) + 1, 1, Gm.PUTARAN)
	lbl_lap.text = "PUTARAN %d/%d" % [lap, Gm.PUTARAN]
	var total := 1 + lawan.size() + hantu.size()
	lbl_pos.text = "POSISI %d/%d" % [_peringkat_sekarang(), total]
	if kondisi == "jalan":
		lbl_koin.text = _fmt_waktu(t_balap)

	if panel_hasil.visible and Gm.mode != "online":
		_isi_hasil_solo()


var _rank_akhir := 1


func _peringkat_sekarang() -> int:
	if selesai_saya:
		return _rank_akhir
	var r := 1
	for a in lawan:
		if a["selesai"] or a["prog"] > prog:
			r += 1
	for id in hantu:
		if hantu[id]["prog"] > prog:
			r += 1
	return r


func _selesai_pemain() -> void:
	selesai_saya = true
	waktu_saya = t_balap
	if Gm.mode == "online" and Net.aktif:
		Net.lapor_selesai(waktu_saya)
		panel_hasil.visible = true
		_isi_hasil_online()
		return
	var r := 1
	for a in lawan:
		if a["selesai"]:
			r += 1
	_rank_akhir = r
	var h := Gm.hadiah(r)
	Gm.tambah_koin(h)
	hadiah_diberikan = true
	lbl_hadiah.text = "Peringkat %d   +%d koin   (total %d)" % [r, h, Gm.koin]
	panel_hasil.visible = true
	_isi_hasil_solo()


func _fmt_waktu(w: float) -> String:
	return "%d:%05.2f" % [int(w) / 60, fmod(w, 60.0)]


func _isi_hasil_solo() -> void:
	var baris: Array = []
	baris.append({"nama": "Kamu", "selesai": true, "waktu": waktu_saya, "prog": prog + 999.0})
	for a in lawan:
		baris.append({"nama": a["nama"], "selesai": a["selesai"], "waktu": a["waktu"], "prog": a["prog"]})
	baris.sort_custom(func(x, y):
		if x["selesai"] != y["selesai"]:
			return x["selesai"]
		if x["selesai"]:
			return x["waktu"] < y["waktu"]
		return x["prog"] > y["prog"])
	var t := ""
	for i in baris.size():
		var b: Dictionary = baris[i]
		t += "%d.  %s    %s\n" % [i + 1, b["nama"], _fmt_waktu(b["waktu"]) if b["selesai"] else "masih balapan"]
	lbl_hasil.text = t


func _isi_hasil_online() -> void:
	var t := ""
	for b in hasil_online:
		t += "%d.  %s    %s\n" % [b["rank"], b["nama"], _fmt_waktu(b["waktu"])]
	lbl_hasil.text = t


# ---------------- online: pemain lain ----------------
func _siapkan_hantu() -> void:
	var ids: Array = Net.pemain.keys()
	ids.sort()
	var me := Net.id_saya()
	for i in ids.size():
		var id: int = ids[i]
		if id == me:
			continue
		var info: Dictionary = Net.pemain[id]
		var c = CarScript.new()
		c.profil = Gm.profil(str(info["mobil"])).duplicate()
		c.hantu = true
		c.suara = false
		var sl := _slot_xf(i)
		c.position = sl[0]
		add_child(c)
		c.add_child(_label3d(str(info["nama"])))
		hantu[id] = {"car": c, "nama": info["nama"], "prog": 0.0, "p": c.position, "q": Quaternion(c.transform.basis.orthonormalized()), "kmh": 0.0, "t": false}


func _on_state(id: int, d: Dictionary) -> void:
	if not hantu.has(id):
		return
	var h: Dictionary = hantu[id]
	h["p"] = d.get("p", h["p"])
	h["q"] = d.get("q", h["q"])
	h["kmh"] = float(d.get("k", 0.0))
	h["t"] = bool(d.get("t", false))
	h["prog"] = float(d.get("prog", 0.0))


func _update_hantu(delta: float) -> void:
	for id in hantu:
		var h: Dictionary = hantu[id]
		var c = h["car"]
		var kini := Quaternion(c.global_transform.basis.orthonormalized())
		var q: Quaternion = kini.slerp(h["q"], 1.0 - exp(-14.0 * delta))
		var pos: Vector3 = c.global_position.lerp(h["p"], 1.0 - exp(-14.0 * delta))
		c.atur_hantu(Transform3D(Basis(q), pos), h["kmh"], h["t"])


func _on_go() -> void:
	if kondisi == "tunggu":
		kondisi = "hitung"
		hitung_t = 3.6
		lbl_hitung.text = ""


func _on_info_selesai(id: int, nama: String, rank: int, waktu: float) -> void:
	hasil_online.append({"nama": nama, "rank": rank, "waktu": waktu})
	if id == Net.id_saya() and not hadiah_diberikan:
		hadiah_diberikan = true
		_rank_akhir = rank
		var h := Gm.hadiah(rank)
		Gm.tambah_koin(h)
		lbl_hadiah.text = "Peringkat %d   +%d koin   (total %d)" % [rank, h, Gm.koin]
	if panel_hasil.visible:
		_isi_hasil_online()


func _on_daftar() -> void:
	for id in hantu.keys():
		if not Net.pemain.has(id):
			(hantu[id]["car"] as Node).queue_free()
			hantu.erase(id)


# =====================================================================
#  LOOP
# =====================================================================
func _physics_process(delta: float) -> void:
	aktif = {"kiri": false, "kanan": false, "gas": false, "rem": false, "nitro": false, "naik": false, "turun": false}
	for idx in sentuhan:
		aktif[sentuhan[idx]] = true

	var kiri: bool = aktif["kiri"] or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var kanan: bool = aktif["kanan"] or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var gas: bool = aktif["gas"] or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var rem: bool = aktif["rem"] or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_SPACE)
	var nitro: bool = aktif["nitro"] or Input.is_physical_key_pressed(KEY_SHIFT)

	var naik: bool = aktif["naik"] or Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_PAGEUP)
	var turun: bool = aktif["turun"] or Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_PAGEDOWN)

	if kondisi == "jalan" and not selesai_saya:
		car.stir_in = (1.0 if kiri else 0.0) - (1.0 if kanan else 0.0)
		car.gas = 1.0 if gas else 0.0
		car.rem_in = 1.0 if rem else 0.0
		car.nitro_on = nitro
		car.parkir = false
		car.naik_in = (1.0 if naik else 0.0) - (1.0 if turun else 0.0)
	else:
		# sebelum GO atau setelah finis: mobil ditahan / melambat
		car.stir_in = 0.0
		car.gas = 0.0
		car.rem_in = 0.0
		car.parkir = true
		car.nitro_on = false
		car.naik_in = -0.4 if (selesai_saya and car.terbang_on) else 0.0

	_update_balapan(delta)

	# jatuh / keluar arena / terbalik terlalu lama -> kembali ke lintasan
	if car.terbang_on:
		if car.global_position.length() > 480.0:
			car.toggle_terbang()
			_ke_lintasan(car)
	elif car.global_position.y < -20.0 or car.global_position.length() > 300.0:
		_ke_lintasan(car)
	if car.terbalik() and car.kmh < 8.0:
		terbalik_t += delta
		if terbalik_t > 2.0:
			car.tegakkan()
			terbalik_t = 0.0
	else:
		terbalik_t = 0.0

	var fb: Vector3 = car.get_forward()
	fb.y = 0.0
	if fb.length() > 0.1:
		blob.global_transform = Transform3D(Basis.looking_at(fb.normalized(), Vector3.UP), Vector3(car.global_position.x, 0.03, car.global_position.z))
	var tinggi := clampf(1.0 - (car.global_position.y - 0.8) / 3.0, 0.0, 1.0)
	(blob.material_override as ShaderMaterial).set_shader_parameter("strength", 0.55 * tinggi)

	_update_kamera(delta)


func _process(_delta: float) -> void:
	lbl_speed.text = str(int(car.kmh))
	bar_nitro.value = car.nitro_isi * 100.0
	bar_rpm.value = car.rpm / 8500.0 * 100.0
	sb_rpm_fill.bg_color = Color(1.0, 0.25, 0.2) if car.rpm > 7800.0 else Color(0.95, 0.95, 0.95)
	if car.terbang_on:
		lbl_gigi.text = "TERBANG  %d m" % int(car.global_position.y)
	elif car.ev:
		lbl_gigi.text = "LISTRIK  %d kW" % int(car.rpm / 8000.0 * 760.0)
	else:
		lbl_gigi.text = "GIGI %d   %d RPM" % [car.gigi, int(car.rpm)]
	tombol["terbang"]["node"].visible = car.terbang_mampu and not selesai_saya
	for n in ["naik", "turun"]:
		tombol[n]["node"].visible = car.terbang_on
	tombol["terbang"]["node"].get_child(0).text = "MENDARAT" if car.terbang_on else "TERBANG"
	_update_hantu(_delta)
	var target_gl := 1.0 if car.boost_aktif else clampf((car.kmh - 180.0) / 150.0, 0.0, 0.3)
	gl_int = lerpf(gl_int, target_gl, 1.0 - exp(-6.0 * _delta))
	(garis_kecepatan.material as ShaderMaterial).set_shader_parameter("intensity", gl_int)
	for n in tombol:
		var t: Dictionary = tombol[n]
		var sb: StyleBoxFlat = t["sb"]
		var c: Color = t["warna"]
		var tekan: bool = aktif.get(n, false)
		sb.bg_color = Color(c.r, c.g, c.b, 0.5 if tekan else 0.18)
