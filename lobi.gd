extends Control
## Lobi: pajangan mobil 3D, toko/garasi, tombol Balapan (vs AI) dan Online.

const CarScript := preload("res://car.gd")

var _vp: SubViewport
var _putar: Node3D
var _mobil_pajang
var _id_pajang := ""
var _t := 0.0

var _lbl_koin: Label
var _lbl_nama: Label
var _lbl_info: Label
var _lbl_warna: Label
var _bar_daya: ProgressBar
var _bar_vmaks: ProgressBar
var _lbl_fitur: Label
var _btn_aksi: Button
var _lbl_pesan: Label
var _daftar_btn := {}
var _btn_lawan: Button

# tema warna & efek
const TEMA := {
	"giallo": Color(1.0, 0.72, 0.10),
	"rosso": Color(1.0, 0.15, 0.22),
	"nero": Color(0.62, 0.32, 1.0),
	"viola": Color(0.70, 0.30, 1.0),
	"verde": Color(0.30, 0.95, 0.60),
	"volt": Color(0.20, 0.78, 1.0),
}
var _tema := Color(1.0, 0.72, 0.10)
var _env: Environment
var _kota: Node3D
var _latar_garasi: MeshInstance3D
var _mat_latar: ShaderMaterial
var _cam: Camera3D
var _cam_pos := Vector3.ZERO
var _cam_lihat := Vector3.ZERO
var _cam_tpos := Vector3.ZERO
var _cam_tlihat := Vector3.ZERO
var _lbl_pemain: Label
var _lbl_pakai: Label
var _lbl_skor: Label
var _radar: Control
var _lbl_axis: Array = []
var _ui_lobi: Control
var _ui_garasi: Control
var _mode_garasi := false
var _kartu_pemain: Control
const CAM_LOBI := [Vector3(6.6, 1.5, 10.4), Vector3(-2.0, 0.8, 0.0)]
const CAM_GARASI := [Vector3(5.2, 1.3, 8.6), Vector3(-1.9, 0.7, 0.0)]
var _tema_t := Color(1.0, 0.72, 0.10)
var _mat_dinding: ShaderMaterial
var _mat_cincin: StandardMaterial3D
var _mat_strip: Array = []
var _mat_pilar: Array = []
var _mat_partikel: StandardMaterial3D
var _spot: SpotLight3D
var _rim_l: DirectionalLight3D

# online
var _panel_online: PanelContainer
var _in_nama: LineEdit
var _in_alamat: LineEdit
var _vb_koneksi: VBoxContainer
var _vb_ruang: VBoxContainer
var _lbl_ruang: Label
var _lbl_status: Label
var _btn_siap: Button
var _lbl_ip: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_buat_panggung()
	_buat_ui()
	_pajang(Gm.terpilih)
	_segarkan()
	if Net.aktif:
		_buka_online()
		_tampil_ruang(true)
	Net.terhubung.connect(func(): _tampil_ruang(true))
	Net.gagal.connect(func(): _status("Gagal terhubung ke server."); _tampil_ruang(false))
	Net.putus.connect(func(): _status("Koneksi terputus."); _tampil_ruang(false))
	Net.daftar_berubah.connect(_segarkan_ruang)
	Net.pesan.connect(func(t): _status(t))
	Net.balapan_dimulai.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))


# =====================================================================
#  PANGGUNG 3D (showroom)
# =====================================================================
const SHADER_GEDUNG := """
shader_type spatial;
uniform vec3 tint = vec3(0.6, 0.3, 1.0);
varying vec3 wp;
varying vec3 wn;
void vertex() { wp = VERTEX; wn = NORMAL; }
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float u = abs(wn.x) > 0.5 ? wp.z : wp.x;
	vec2 g = vec2(u * 0.9, wp.y * 0.55);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float on = step(0.62, h(cell));
	float win = step(0.18, f.x) * step(f.x, 0.82) * step(0.22, f.y) * step(f.y, 0.78);
	vec3 hangat = vec3(1.0, 0.82, 0.5);
	vec3 dingin = mix(vec3(0.3, 0.85, 1.0), vec3(1.0, 0.3, 0.8), h(cell + 7.0));
	vec3 wc = mix(hangat, dingin, step(0.55, h(cell + 3.0)));
	float sisi = 1.0 - step(0.5, abs(wn.y));
	ALBEDO = vec3(0.02, 0.018, 0.04) + tint * 0.02;
	ROUGHNESS = 0.6;
	EMISSION = wc * on * win * sisi * 0.95;
}
"""

const SHADER_LATAR_GARASI := """
shader_type spatial;
render_mode unshaded;
uniform vec3 tema = vec3(1.0, 0.5, 0.05);
void fragment() {
	float x = (UV.x - 0.5) * 200.0;
	float y = 18.0 + (0.5 - UV.y) * 80.0;
	float u = y - 0.72 * x;
	vec3 gelap = mix(vec3(0.13, 0.12, 0.13), vec3(0.04, 0.04, 0.05), clamp(y / 26.0, 0.0, 1.0));
	float pita1 = smoothstep(-3.5, -3.3, u) * (1.0 - smoothstep(5.5, 5.7, u));
	float pita2 = smoothstep(8.0, 8.15, u) * (1.0 - smoothstep(9.6, 9.75, u));
	float pita3 = smoothstep(-8.0, -7.85, u) * (1.0 - smoothstep(-6.4, -6.25, u));
	float pita4 = smoothstep(14.0, 14.2, u) * (1.0 - smoothstep(19.0, 19.2, u));
	vec3 oranye = mix(tema * 0.30, tema * 0.9, clamp((u + 3.5) / 9.0, 0.0, 1.0));
	vec3 c = gelap;
	c = mix(c, oranye, pita1 * 0.9);
	c = mix(c, tema * 1.15, pita2);
	c = mix(c, tema * 0.7, pita3 * 0.8);
	c = mix(c, tema * 0.28, pita4);
	ALBEDO = c;
}
"""

func _buat_panggung() -> void:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.scaling_3d_scale = 1.0
	_vp.handle_input_locally = false
	svc.add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pm := ProceduralSkyMaterial.new()
	pm.sky_top_color = Color(0.03, 0.02, 0.14)
	pm.sky_horizon_color = Color(0.62, 0.20, 0.62)
	pm.ground_horizon_color = Color(0.30, 0.12, 0.38)
	pm.ground_bottom_color = Color(0.02, 0.01, 0.05)
	pm.sky_curve = 0.18
	sky.sky_material = pm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.32, 0.12, 0.45)
	env.fog_density = 0.010
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	_env = env

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -30, 0)
	sun.light_energy = 1.5
	sun.light_color = Color(0.8, 0.82, 1.0)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.0
	_vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, 150, 0)
	rim.light_energy = 1.3
	rim.light_color = Color(1.0, 0.4, 0.9)
	_vp.add_child(rim)
	_rim_l = rim
	var sp := SpotLight3D.new()
	sp.position = Vector3(0, 7.0, 2.0)
	sp.rotation_degrees = Vector3(-90, 0, 0)
	sp.spot_range = 12.0
	sp.spot_angle = 38.0
	sp.light_energy = 3.0
	sp.light_color = Color(1.0, 0.95, 0.9)
	_vp.add_child(sp)
	_spot = sp

	# aspal basah luas
	var tanah := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 90.0
	tc.bottom_radius = 90.0
	tc.height = 0.1
	tc.radial_segments = 48
	tanah.mesh = tc
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.03, 0.03, 0.05)
	tmat.metallic = 0.6
	tmat.roughness = 0.22
	tanah.material_override = tmat
	tanah.position = Vector3(0, -0.12, 0)
	_vp.add_child(tanah)

	# panggung bundar + cincin tema
	var lantai := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 4.2
	cm.bottom_radius = 4.2
	cm.height = 0.12
	cm.radial_segments = 64
	lantai.mesh = cm
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.05, 0.05, 0.07)
	lm.metallic = 0.7
	lm.roughness = 0.25
	lantai.material_override = lm
	lantai.position = Vector3(0, -0.06, 0)
	_vp.add_child(lantai)
	var cincin := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 4.1
	tm.outer_radius = 4.25
	tm.rings = 64
	tm.ring_segments = 8
	cincin.mesh = tm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(1.0, 0.8, 0.3)
	cmat.emission_enabled = true
	cmat.emission = Color(1.0, 0.7, 0.2)
	cmat.emission_energy_multiplier = 1.6
	cincin.material_override = cmat
	cincin.scale = Vector3(1, 0.3, 1)
	_vp.add_child(cincin)
	_mat_cincin = cmat

	# ---- kota malam ----
	_kota = Node3D.new()
	_vp.add_child(_kota)
	var gsh := Shader.new()
	gsh.code = SHADER_GEDUNG
	var gmat := ShaderMaterial.new()
	gmat.shader = gsh
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var neon_cols := [Color(1.0, 0.25, 0.8), Color(0.2, 0.85, 1.0), Color(1.0, 0.8, 0.2), Color(0.6, 0.35, 1.0)]
	for k in 54:
		var ang := float(k) / 54.0 * TAU + rng.randf_range(-0.04, 0.04)
		var rad := rng.randf_range(24.0, 46.0)
		var w := rng.randf_range(5.0, 10.0)
		var d := rng.randf_range(5.0, 10.0)
		var h := rng.randf_range(10.0, 44.0)
		var gd := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, d)
		gd.mesh = bm
		gd.material_override = gmat
		gd.position = Vector3(sin(ang) * rad, h * 0.5 - 0.1, cos(ang) * rad)
		gd.rotation.y = ang
		gd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_kota.add_child(gd)
		if k % 4 == 0:
			var nb := MeshInstance3D.new()
			var nq := QuadMesh.new()
			nq.size = Vector2(rng.randf_range(1.2, 2.4), rng.randf_range(5.0, 11.0))
			nb.mesh = nq
			var nm := StandardMaterial3D.new()
			var nc: Color = neon_cols[(k / 4) % neon_cols.size()]
			nm.albedo_color = nc
			nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			nm.emission_enabled = true
			nm.emission = nc
			nm.emission_energy_multiplier = 2.2
			nm.cull_mode = BaseMaterial3D.CULL_DISABLED
			nb.material_override = nm
			nb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			nb.position = Vector3(sin(ang) * (rad - d * 0.5 - 0.1), h * 0.55, cos(ang) * (rad - d * 0.5 - 0.1))
			nb.rotation.y = ang + PI
			_kota.add_child(nb)
	# tiang lampu jalan
	var lamp_m := StandardMaterial3D.new()
	lamp_m.albedo_color = Color(1.0, 0.85, 0.6)
	lamp_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_m.emission_enabled = true
	lamp_m.emission = Color(1.0, 0.8, 0.5)
	lamp_m.emission_energy_multiplier = 3.0
	var tiang_m := StandardMaterial3D.new()
	tiang_m.albedo_color = Color(0.08, 0.08, 0.1)
	tiang_m.metallic = 0.7
	tiang_m.roughness = 0.4
	for k in 8:
		var ang := float(k) / 8.0 * TAU + 0.2
		var pos := Vector3(sin(ang) * 14.0, 0, cos(ang) * 14.0)
		var tg := MeshInstance3D.new()
		var tcm := CylinderMesh.new()
		tcm.top_radius = 0.07
		tcm.bottom_radius = 0.1
		tcm.height = 6.0
		tg.mesh = tcm
		tg.material_override = tiang_m
		tg.position = pos + Vector3(0, 3.0, 0)
		_kota.add_child(tg)
		var kp := MeshInstance3D.new()
		var ksm := SphereMesh.new()
		ksm.radius = 0.28
		ksm.height = 0.56
		kp.mesh = ksm
		kp.material_override = lamp_m
		kp.position = pos + Vector3(0, 6.1, 0)
		kp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_kota.add_child(kp)

	# ---- latar garasi (pita diagonal oranye) ----
	_latar_garasi = MeshInstance3D.new()
	var lq := QuadMesh.new()
	lq.size = Vector2(200, 80)
	_latar_garasi.mesh = lq
	var lsh := Shader.new()
	lsh.code = SHADER_LATAR_GARASI
	_mat_latar = ShaderMaterial.new()
	_mat_latar.shader = lsh
	_latar_garasi.material_override = _mat_latar
	_latar_garasi.position = Vector3(0, 18, -14)
	_latar_garasi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_latar_garasi.visible = false
	_vp.add_child(_latar_garasi)

	# percikan cahaya
	var pt := CPUParticles3D.new()
	pt.amount = 70
	pt.lifetime = 6.0
	pt.preprocess = 6.0
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	pt.emission_ring_axis = Vector3.UP
	pt.emission_ring_radius = 5.5
	pt.emission_ring_inner_radius = 1.5
	pt.emission_ring_height = 0.2
	pt.direction = Vector3.UP
	pt.spread = 12.0
	pt.gravity = Vector3(0, 0.05, 0)
	pt.initial_velocity_min = 0.35
	pt.initial_velocity_max = 0.9
	pt.scale_amount_min = 0.5
	pt.scale_amount_max = 1.5
	pt.position = Vector3(0, 0.1, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	sm.radial_segments = 6
	sm.rings = 3
	_mat_partikel = StandardMaterial3D.new()
	_mat_partikel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_partikel.albedo_color = Color(1.0, 0.8, 0.3)
	sm.material = _mat_partikel
	pt.mesh = sm
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	pt.color_ramp = ramp
	_vp.add_child(pt)

	_putar = Node3D.new()
	_vp.add_child(_putar)
	_cam = Camera3D.new()
	_cam.fov = 36.0
	_vp.add_child(_cam)
	_cam_pos = CAM_LOBI[0]
	_cam_lihat = CAM_LOBI[1]
	_cam_tpos = CAM_LOBI[0]
	_cam_tlihat = CAM_LOBI[1]
	_cam.look_at_from_position(_cam_pos, _cam_lihat, Vector3.UP)
	_cam.current = true


func _pajang(id: String) -> void:
	if _mobil_pajang != null:
		_mobil_pajang.queue_free()
	_id_pajang = id
	_tema_t = TEMA.get(id, Color(1.0, 0.72, 0.1))
	var c = CarScript.new()
	c.profil = Gm.profil(id).duplicate()
	c.hantu = true
	c.suara = false
	_putar.add_child(c)
	_mobil_pajang = c


# =====================================================================
#  UI
# =====================================================================
func _gaya(warna: Color, radius: int = 22, alfa: float = 0.55) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(warna.r * 0.35, warna.g * 0.35, warna.b * 0.35, alfa)
	sb.border_color = warna
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _tombol(teks: String, warna: Color, fs: int, lebar: float, tinggi: float) -> Button:
	var b := Button.new()
	b.text = teks
	b.custom_minimum_size = Vector2(lebar, tinggi)
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	var n := _gaya(warna)
	var h := _gaya(warna, 22, 0.8)
	var d := _gaya(warna.darkened(0.5), 22, 0.35)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _label(teks: String, fs: int, warna: Color = Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = teks
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", warna)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _panel(warna: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _gaya(warna, 26, 0.72)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", sb)
	return p


func _kartu(warna: Color, alfa: float = 0.78) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.06, alfa)
	sb.border_color = warna
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _tombol_datar(teks: String, warna: Color, fs: int, ukuran: Vector2) -> Button:
	var b := Button.new()
	b.text = teks
	b.custom_minimum_size = ukuran
	b.add_theme_font_size_override("font_size", fs)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	var n := _kartu(warna, 0.8)
	n.set_corner_radius_all(8)
	var h := _kartu(warna, 0.95)
	h.bg_color = Color(warna.r * 0.45, warna.g * 0.45, warna.b * 0.45, 0.95)
	var d := _kartu(warna.darkened(0.5), 0.5)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _buat_ui() -> void:
	# ---------------- elemen selalu tampil: kartu pemain + koin ----------------
	var pemain := PanelContainer.new()
	_kartu_pemain = pemain
	pemain.add_theme_stylebox_override("panel", _kartu(Color(0.7, 0.6, 1.0)))
	pemain.position = Vector2(24, 18)
	add_child(pemain)
	var hp := HBoxContainer.new()
	hp.add_theme_constant_override("separation", 12)
	pemain.add_child(hp)
	var avatar := Control.new()
	avatar.custom_minimum_size = Vector2(56, 56)
	avatar.draw.connect(func():
		avatar.draw_circle(Vector2(28, 28), 27, Color(0.35, 0.25, 0.75))
		avatar.draw_arc(Vector2(28, 28), 27, 0, TAU, 40, Color(1, 1, 1, 0.8), 2.0, true)
		avatar.draw_circle(Vector2(28, 21), 9, Color(0.95, 0.85, 0.8))
		avatar.draw_circle(Vector2(28, 50), 18, Color(0.95, 0.95, 1.0)))
	hp.add_child(avatar)
	var vp2 := VBoxContainer.new()
	hp.add_child(vp2)
	_lbl_pemain = _label(Gm.nama_pemain, 26, Color(1, 1, 1))
	vp2.add_child(_lbl_pemain)
	_lbl_pakai = _label("", 18, Color(0.75, 0.85, 1.0))
	vp2.add_child(_lbl_pakai)

	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _kartu(Color(1.0, 0.8, 0.3), 0.85))
	chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chip.offset_left = -250
	chip.offset_right = -24
	chip.offset_top = 22
	add_child(chip)
	var hk := HBoxContainer.new()
	hk.add_theme_constant_override("separation", 10)
	chip.add_child(hk)
	var koin_ic := Control.new()
	koin_ic.custom_minimum_size = Vector2(34, 34)
	koin_ic.draw.connect(func():
		koin_ic.draw_circle(Vector2(17, 17), 15, Color(1.0, 0.75, 0.15))
		koin_ic.draw_arc(Vector2(17, 17), 15, 0, TAU, 32, Color(1, 0.95, 0.6), 2.0, true)
		koin_ic.draw_arc(Vector2(17, 17), 8, 0, TAU, 24, Color(0.8, 0.5, 0.05), 2.5, true))
	hk.add_child(koin_ic)
	_lbl_koin = _label("", 30, Color(1.0, 0.93, 0.5))
	hk.add_child(_lbl_koin)

	_buat_ui_lobi()
	_buat_ui_garasi()
	_buat_panel_online()


func _buat_ui_lobi() -> void:
	_ui_lobi = Control.new()
	_ui_lobi.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_lobi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_lobi)

	# judul miring kiri
	var jd := _label("TURBO DRIFT", 50, Color(1.0, 0.85, 0.35))
	jd.position = Vector2(24, 100)
	jd.rotation = -0.03
	_ui_lobi.add_child(jd)

	# kartu promo (kiri)
	var kol := VBoxContainer.new()
	kol.add_theme_constant_override("separation", 10)
	kol.position = Vector2(24, 170)
	_ui_lobi.add_child(kol)
	for item in [["viola", "MOBIL BARU", Color(1.0, 0.85, 0.2)], ["volt", "BISA TERBANG", Color(0.3, 0.85, 1.0)], ["verde", "KROM KAMELEON", Color(0.5, 1.0, 0.6)]]:
		var id: String = item[0]
		var kb := _tombol_datar("", item[2], 20, Vector2(330, 92))
		kb.pressed.connect(_buka_garasi.bind(id))
		kol.add_child(kb)
		var tag := _label(item[1], 17, item[2])
		tag.position = Vector2(12, 4)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kb.add_child(tag)
		var nm := _label(Gm.profil(id)["nama"], 20, Color(1, 1, 1))
		nm.position = Vector2(12, 30)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kb.add_child(nm)
		var harga := _label("%s koin" % _rp(int(Gm.profil(id)["harga"])), 17, Color(1.0, 0.9, 0.5))
		harga.position = Vector2(12, 60)
		harga.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kb.add_child(harga)
		_pasang_ikon(kb, id)

	# bilah navigasi bawah
	var nav := PanelContainer.new()
	var nsb := _kartu(Color(0.5, 0.5, 0.7), 0.85)
	nsb.set_corner_radius_all(0)
	nsb.border_width_left = 0
	nsb.border_width_right = 0
	nsb.border_width_bottom = 0
	nav.add_theme_stylebox_override("panel", nsb)
	nav.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	nav.grow_vertical = Control.GROW_DIRECTION_BEGIN
	nav.offset_left = 0
	nav.offset_bottom = 0
	nav.custom_minimum_size = Vector2(690, 82)
	_ui_lobi.add_child(nav)
	var hn := HBoxContainer.new()
	hn.add_theme_constant_override("separation", 22)
	nav.add_child(hn)
	var b_mobil := _tombol_datar("MOBIL", Color(0.6, 0.7, 1.0), 26, Vector2(190, 62))
	b_mobil.pressed.connect(_buka_garasi.bind(""))
	hn.add_child(b_mobil)
	var b_on := _tombol_datar("ONLINE", Color(0.4, 0.8, 1.0), 26, Vector2(190, 62))
	b_on.pressed.connect(_buka_online)
	hn.add_child(b_on)
	_btn_lawan = _tombol_datar("", Color(0.8, 0.8, 0.9), 22, Vector2(200, 62))
	_btn_lawan.pressed.connect(_ganti_lawan)
	hn.add_child(_btn_lawan)
	_perbarui_lawan()

	# tombol BALAP bulat merah
	var balap := Button.new()
	balap.text = "BALAP"
	balap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	balap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	balap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	balap.offset_left = -230
	balap.offset_right = -34
	balap.offset_top = -214
	balap.offset_bottom = -18
	balap.add_theme_font_size_override("font_size", 38)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		balap.add_theme_color_override(k, Color(1, 1, 1))
	balap.add_theme_color_override("font_outline_color", Color(0.4, 0, 0, 0.9))
	balap.add_theme_constant_override("outline_size", 6)
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color(0.88, 0.05, 0.1)
	bn.border_color = Color(1.0, 0.7, 0.7)
	bn.set_border_width_all(5)
	bn.set_corner_radius_all(120)
	bn.shadow_color = Color(1.0, 0.1, 0.2, 0.55)
	bn.shadow_size = 22
	var bh := bn.duplicate()
	bh.bg_color = Color(1.0, 0.2, 0.25)
	balap.add_theme_stylebox_override("normal", bn)
	balap.add_theme_stylebox_override("hover", bh)
	balap.add_theme_stylebox_override("pressed", bh)
	balap.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	balap.pressed.connect(_mulai_solo)
	_ui_lobi.add_child(balap)
	var ket := _label("vs AI  •  %d putaran" % Gm.PUTARAN, 18, Color(1, 1, 1, 0.85))
	ket.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ket.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ket.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ket.offset_left = -270
	ket.offset_right = -34
	ket.offset_top = -246
	ket.offset_bottom = -216
	ket.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui_lobi.add_child(ket)


func _buat_ui_garasi() -> void:
	_ui_garasi = Control.new()
	_ui_garasi.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_garasi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_garasi.visible = false
	add_child(_ui_garasi)

	# bilah judul merah miring + tombol kembali
	var judul := Control.new()
	judul.position = Vector2(0, 0)
	judul.custom_minimum_size = Vector2(600, 70)
	judul.size = Vector2(600, 70)
	judul.mouse_filter = Control.MOUSE_FILTER_IGNORE
	judul.draw.connect(func():
		judul.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(520, 0), Vector2(480, 70), Vector2(0, 70)]), Color(0.04, 0.04, 0.06, 0.92))
		judul.draw_polyline(PackedVector2Array([Vector2(0, 70), Vector2(480, 70), Vector2(520, 0)]), Color(0.95, 0.1, 0.15), 3.0, true))
	_ui_garasi.add_child(judul)
	var kembali := _tombol_datar("<  LOBI", Color(0.95, 0.2, 0.25), 24, Vector2(150, 54))
	kembali.position = Vector2(10, 8)
	kembali.pressed.connect(_tutup_garasi)
	_ui_garasi.add_child(kembali)
	var jt := _label("Ganti Mobil", 34, Color(1, 1, 1))
	jt.position = Vector2(180, 12)
	_ui_garasi.add_child(jt)

	# kartu info (kiri atas)
	_lbl_nama = _label("", 34, Color(1, 1, 1))
	_lbl_nama.position = Vector2(30, 92)
	_lbl_nama.custom_minimum_size = Vector2(520, 0)
	_ui_garasi.add_child(_lbl_nama)
	_lbl_skor = _label("", 22, Color(1, 1, 1))
	_lbl_skor.position = Vector2(30, 140)
	_ui_garasi.add_child(_lbl_skor)
	_lbl_warna = _label("", 20, Color(0.8, 0.85, 0.95))
	_lbl_warna.position = Vector2(230, 142)
	_ui_garasi.add_child(_lbl_warna)

	# tab INFO MOBIL (merah)
	var tab := Control.new()
	tab.position = Vector2(0, 190)
	tab.size = Vector2(230, 70)
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.draw.connect(func():
		tab.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(230, 0), Vector2(230, 70), Vector2(0, 70)]), Color(0.9, 0.1, 0.15, 0.95)))
	_ui_garasi.add_child(tab)
	var tl := _label("INFO MOBIL", 26, Color(1, 1, 1))
	tl.position = Vector2(26, 206)
	_ui_garasi.add_child(tl)

	# radar statistik
	_radar = Control.new()
	_radar.position = Vector2(60, 282)
	_radar.size = Vector2(380, 300)
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar.draw.connect(_gambar_radar)
	_ui_garasi.add_child(_radar)
	_lbl_axis = []
	for k in 4:
		var l := _label("", 20, Color(1, 1, 1))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_radar.add_child(l)
		_lbl_axis.append(l)

	# info & fitur
	_lbl_info = _label("", 20, Color(0.85, 0.9, 1.0))
	_lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_info.custom_minimum_size = Vector2(380, 0)
	_lbl_info.position = Vector2(30, 600)
	_ui_garasi.add_child(_lbl_info)
	_lbl_fitur = _label("", 22, Color(0.55, 0.85, 1.0))
	_lbl_fitur.position = Vector2(30, 676)
	_ui_garasi.add_child(_lbl_fitur)

	# panah ganti mobil
	var kiri := _tombol_datar("<", Color(0.9, 0.9, 1.0), 40, Vector2(76, 76))
	kiri.position = Vector2(470, 560)
	kiri.pressed.connect(_geser.bind(-1))
	_ui_garasi.add_child(kiri)
	var kanan := _tombol_datar(">", Color(0.9, 0.9, 1.0), 40, Vector2(76, 76))
	kanan.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	kanan.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	kanan.offset_left = -430
	kanan.offset_right = -354
	kanan.offset_top = 560
	kanan.offset_bottom = 636
	kanan.pressed.connect(_geser.bind(1))
	_ui_garasi.add_child(kanan)

	# aksi beli/pakai
	_btn_aksi = _tombol_datar("", Color(0.5, 1.0, 0.6), 30, Vector2(300, 78))
	_btn_aksi.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_btn_aksi.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_btn_aksi.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_btn_aksi.offset_left = -330
	_btn_aksi.offset_right = -30
	_btn_aksi.offset_top = -100
	_btn_aksi.offset_bottom = -22
	_btn_aksi.pressed.connect(_aksi)
	_ui_garasi.add_child(_btn_aksi)
	_lbl_pesan = _label("", 22, Color(1.0, 0.75, 0.5))
	_lbl_pesan.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_lbl_pesan.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_lbl_pesan.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_lbl_pesan.offset_left = -560
	_lbl_pesan.offset_right = -30
	_lbl_pesan.offset_top = -144
	_lbl_pesan.offset_bottom = -106
	_lbl_pesan.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui_garasi.add_child(_lbl_pesan)


func _nilai_statistik(id: String) -> Array:
	var p: Dictionary = Gm.profil(id)
	var daya: float = p["daya"]
	var vm: float = p["vmaks"]
	var akselerasi := clampf((daya - 0.8) / 0.65, 0.1, 1.0)
	var kecepatan := clampf((vm - 0.85) / 0.30, 0.1, 1.0)
	var kemudi := 0.86 if p["ev"] else 0.72
	var drift := clampf(0.5 + (daya - 1.0) * 0.9, 0.2, 1.0)
	# urutan: atas, kanan, bawah, kiri
	return [kecepatan, kemudi, drift, akselerasi]


func _nilai_huruf(v: float) -> String:
	if v >= 0.92:
		return "S"
	if v >= 0.82:
		return "A+"
	if v >= 0.72:
		return "A"
	if v >= 0.62:
		return "B+"
	if v >= 0.5:
		return "B"
	return "C"


func _gambar_radar() -> void:
	var c := Vector2(190, 150)
	var rr := 100.0
	var nilai := _nilai_statistik(_id_pajang)
	var arah := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	_radar.draw_circle(c, rr + 8, Color(0.05, 0.08, 0.15, 0.85))
	for s in [0.33, 0.66, 1.0]:
		_radar.draw_arc(c, rr * s, 0, TAU, 48, Color(0.5, 0.65, 1.0, 0.35), 1.5, true)
	for k in 4:
		_radar.draw_line(c, c + arah[k] * (rr + 6), Color(0.6, 0.7, 1.0, 0.5), 1.5)
	# irisan berwarna (biru / hijau bergantian)
	for k in 4:
		var a0: Vector2 = arah[k] * rr * nilai[k]
		var a1: Vector2 = arah[(k + 1) % 4] * rr * nilai[(k + 1) % 4]
		var warna := Color(0.2, 0.45, 0.95, 0.75) if k % 2 == 0 else Color(0.25, 0.7, 0.4, 0.75)
		_radar.draw_colored_polygon(PackedVector2Array([c, c + a0, c + a1]), warna)
	var tepi := PackedVector2Array()
	for k in 4:
		tepi.append(c + arah[k] * rr * nilai[k])
	tepi.append(tepi[0])
	_radar.draw_polyline(tepi, Color(1, 1, 1, 0.85), 2.0, true)
	_radar.draw_circle(c, 4, Color(1, 1, 1))
	var nama := ["KECEPATAN MAKS", "KEMUDI", "DRIFT SUDUT", "AKSELERASI"]
	var pos := [Vector2(c.x - 70, 4), Vector2(c.x + rr + 14, c.y - 24), Vector2(c.x - 46, c.y + rr + 14), Vector2(0, c.y - 24)]
	for k in 4:
		if _lbl_axis.size() > k:
			_lbl_axis[k].text = "%s\n%s" % [_nilai_huruf(nilai[k]), nama[k]]
			_lbl_axis[k].add_theme_font_size_override("font_size", 16)
			_lbl_axis[k].position = pos[k]


func _geser(arah: int) -> void:
	var i := Gm.URUTAN.find(_id_pajang)
	i = (i + arah + Gm.URUTAN.size()) % Gm.URUTAN.size()
	_pilih_pajang(Gm.URUTAN[i])


func _buka_garasi(id: String = "") -> void:
	if id != "":
		_pilih_pajang(id)
	_atur_mode(true)


func _tutup_garasi() -> void:
	if _id_pajang != Gm.terpilih:
		_pajang(Gm.terpilih)
	_lbl_pesan.text = ""
	_atur_mode(false)
	_segarkan()


func _atur_mode(garasi: bool) -> void:
	_mode_garasi = garasi
	_ui_lobi.visible = not garasi
	_kartu_pemain.visible = not garasi
	_ui_garasi.visible = garasi
	_kota.visible = not garasi
	_latar_garasi.visible = garasi
	var t: Array = CAM_GARASI if garasi else CAM_LOBI
	_cam_tpos = t[0]
	_cam_tlihat = t[1]
	if _env:
		_env.fog_enabled = not garasi
	_segarkan()


func _bar() -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = 100.0
	b.show_percentage = false
	b.custom_minimum_size = Vector2(360, 18)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(9)
	var fl := StyleBoxFlat.new()
	fl.bg_color = Color(1.0, 0.75, 0.25)
	fl.set_corner_radius_all(9)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fl)
	return b


func _rp(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return out


# =====================================================================
#  TOKO / GARASI
# =====================================================================
func _pasang_ikon(b: Button, id: String) -> void:
	var ic := Control.new()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ic.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ic.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ic.offset_left = -112
	ic.offset_right = -8
	ic.offset_top = -40
	ic.offset_bottom = -4
	b.add_child(ic)
	ic.draw.connect(func(): _gambar_ikon(ic, id))


func _gambar_ikon(ic: Control, id: String) -> void:
	var p: Dictionary = Gm.profil(id)
	var w := ic.size.x
	var h := ic.size.y
	var warna: Color = p["body"]
	var tema: Color = TEMA.get(id, Color(1, 1, 1))
	var terbang: bool = p["terbang"]
	var dy := -4.0 if terbang else 0.0
	var pts := PackedVector2Array()
	var rd: Array = [Vector2(0.02, 0.78), Vector2(0.04, 0.58), Vector2(0.22, 0.50), Vector2(0.38, 0.20), Vector2(0.62, 0.14), Vector2(0.80, 0.45), Vector2(0.97, 0.56), Vector2(0.98, 0.78)]
	if p["bodi"] == "roadster":
		rd = [Vector2(0.02, 0.76), Vector2(0.05, 0.56), Vector2(0.30, 0.44), Vector2(0.48, 0.20), Vector2(0.68, 0.18), Vector2(0.84, 0.44), Vector2(0.98, 0.54), Vector2(0.98, 0.76)]
	for v in rd:
		pts.append(Vector2(v.x * w, v.y * h * 0.9 + dy))
	if terbang:
		for k in 3:
			ic.draw_line(Vector2(w * (0.25 + k * 0.25), h * 0.95), Vector2(w * (0.25 + k * 0.25), h * 1.0), Color(tema.r, tema.g, tema.b, 0.9), 2.0)
	ic.draw_colored_polygon(pts, warna)
	var kaca := PackedVector2Array([Vector2(0.40 * w, 0.30 * h + dy), Vector2(0.50 * w, 0.20 * h + dy), Vector2(0.62 * w, 0.20 * h + dy), Vector2(0.74 * w, 0.44 * h + dy)])
	ic.draw_colored_polygon(kaca, Color(0.1, 0.14, 0.2, 0.9))
	var tepi := pts.duplicate()
	tepi.append(pts[0])
	ic.draw_polyline(tepi, Color(1, 1, 1, 0.55), 1.2, true)
	if p["stripe"] != warna:
		ic.draw_line(Vector2(0.30 * w, 0.52 * h + dy), Vector2(0.92 * w, 0.60 * h + dy), p["stripe"], 2.0)
	for wx in [0.24, 0.78]:
		var c := Vector2(wx * w, 0.80 * h + dy * 0.3)
		ic.draw_circle(c, h * 0.17, Color(0.05, 0.05, 0.06))
		ic.draw_circle(c, h * 0.09, Color(0.85, 0.88, 0.95) if not terbang else tema)


func _segarkan() -> void:
	_lbl_koin.text = _rp(Gm.koin)
	_lbl_pemain.text = Gm.nama_pemain
	_lbl_pakai.text = Gm.profil(Gm.terpilih)["nama"]
	var p2: Dictionary = Gm.profil(_id_pajang)
	_lbl_nama.text = p2["nama"]
	var nilai := _nilai_statistik(_id_pajang)
	var skor := int((nilai[0] + nilai[1] + nilai[2] + nilai[3]) * 250.0)
	_lbl_skor.text = "SKOR  %d" % skor
	_lbl_warna.text = p2["warna"]
	_lbl_info.text = p2["info"]
	_lbl_fitur.text = "BISA TERBANG" if p2["terbang"] else ("Mobil listrik" if p2["ev"] else "Mesin V12")
	if _radar:
		_radar.queue_redraw()
	if Gm.punya(_id_pajang):
		if Gm.terpilih == _id_pajang:
			_btn_aksi.text = "DIPAKAI"
			_btn_aksi.disabled = true
		else:
			_btn_aksi.text = "PAKAI"
			_btn_aksi.disabled = false
	else:
		_btn_aksi.text = "BELI  %s" % _rp(int(p2["harga"]))
		_btn_aksi.disabled = false


func _pilih_pajang(id: String) -> void:
	if id != _id_pajang:
		_pajang(id)
	_lbl_pesan.text = ""
	_segarkan()


func _aksi() -> void:
	var id := _id_pajang
	if Gm.punya(id):
		if Net.aktif and Net.di_balapan:
			_lbl_pesan.text = "Tidak bisa ganti mobil saat balapan."
			return
		Gm.pilih(id)
		Net.ganti_mobil(id)
		_lbl_pesan.text = "Mobil dipilih."
	else:
		if Gm.beli(id):
			Net.ganti_mobil(id)
			_lbl_pesan.text = "Berhasil dibeli! Selamat."
		else:
			_lbl_pesan.text = "Koin belum cukup. Menangkan balapan untuk dapat koin."
	_segarkan()


func _perbarui_lawan() -> void:
	_btn_lawan.text = "LAWAN AI\n%d" % Gm.jumlah_lawan


func _ganti_lawan() -> void:
	Gm.jumlah_lawan = Gm.jumlah_lawan % 5 + 1
	_perbarui_lawan()


func _mulai_solo() -> void:
	if Net.aktif:
		Net.tutup()
	Gm.mode = "solo"
	Gm.simpan()
	get_tree().change_scene_to_file("res://main.tscn")


# =====================================================================
#  ONLINE
# =====================================================================
func _buat_panel_online() -> void:
	_panel_online = _panel(Color(0.5, 0.75, 1.0))
	_panel_online.set_anchors_preset(Control.PRESET_CENTER)
	_panel_online.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel_online.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel_online.custom_minimum_size = Vector2(700, 0)
	_panel_online.visible = false
	add_child(_panel_online)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_panel_online.add_child(vb)
	vb.add_child(_label("MAIN ONLINE", 40, Color(0.7, 0.88, 1.0)))

	# --- sebelum terhubung ---
	_vb_koneksi = VBoxContainer.new()
	_vb_koneksi.add_theme_constant_override("separation", 12)
	vb.add_child(_vb_koneksi)
	_vb_koneksi.add_child(_label("Nama pemain", 22))
	_in_nama = LineEdit.new()
	_in_nama.text = Gm.nama_pemain
	_in_nama.max_length = 14
	_in_nama.add_theme_font_size_override("font_size", 30)
	_in_nama.custom_minimum_size = Vector2(0, 62)
	_vb_koneksi.add_child(_in_nama)
	_vb_koneksi.add_child(_label("Alamat server (IP atau domain)", 22))
	_in_alamat = LineEdit.new()
	_in_alamat.text = Gm.alamat_server
	_in_alamat.add_theme_font_size_override("font_size", 30)
	_in_alamat.custom_minimum_size = Vector2(0, 62)
	_vb_koneksi.add_child(_in_alamat)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	_vb_koneksi.add_child(hb)
	var b_gabung := _tombol("GABUNG", Color(0.5, 1.0, 0.6), 32, 200, 80)
	b_gabung.pressed.connect(_gabung)
	hb.add_child(b_gabung)
	var b_host := _tombol("BUAT RUANG", Color(1.0, 0.8, 0.4), 28, 230, 80)
	b_host.pressed.connect(_buat_ruang)
	hb.add_child(b_host)
	var b_tutup := _tombol("TUTUP", Color(1.0, 0.55, 0.5), 28, 160, 80)
	b_tutup.pressed.connect(func(): _panel_online.visible = false)
	hb.add_child(b_tutup)
	var tip := _label("Server khusus: jalankan  godot --headless -- --server  di PC/VPS (port UDP 7777).\nAtau BUAT RUANG di HP ini lalu teman GABUNG ke IP-mu (satu Wi-Fi).", 18, Color(0.75, 0.8, 0.9))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(640, 0)
	_vb_koneksi.add_child(tip)

	# --- ruang tunggu ---
	_vb_ruang = VBoxContainer.new()
	_vb_ruang.add_theme_constant_override("separation", 12)
	_vb_ruang.visible = false
	vb.add_child(_vb_ruang)
	_lbl_ip = _label("", 22, Color(0.75, 0.9, 1.0))
	_vb_ruang.add_child(_lbl_ip)
	_lbl_ruang = _label("", 28)
	_lbl_ruang.custom_minimum_size = Vector2(0, 200)
	_vb_ruang.add_child(_lbl_ruang)
	var hb2 := HBoxContainer.new()
	hb2.add_theme_constant_override("separation", 14)
	_vb_ruang.add_child(hb2)
	_btn_siap = _tombol("SIAP", Color(0.5, 1.0, 0.6), 36, 260, 90)
	_btn_siap.pressed.connect(_toggle_siap)
	hb2.add_child(_btn_siap)
	var b_keluar := _tombol("KELUAR", Color(1.0, 0.55, 0.5), 30, 220, 90)
	b_keluar.pressed.connect(func():
		Net.tutup()
		_tampil_ruang(false))
	hb2.add_child(b_keluar)
	var b_kecil := _tombol("TUTUP", Color(0.8, 0.8, 0.9), 26, 150, 90)
	b_kecil.pressed.connect(func(): _panel_online.visible = false)
	hb2.add_child(b_kecil)

	_lbl_status = _label("", 22, Color(1.0, 0.8, 0.5))
	_lbl_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_status.custom_minimum_size = Vector2(640, 0)
	vb.add_child(_lbl_status)


func _buka_online() -> void:
	_panel_online.visible = true


func _status(t: String) -> void:
	if _lbl_status:
		_lbl_status.text = t


func _simpan_input() -> void:
	var n := _in_nama.text.strip_edges()
	Gm.nama_pemain = n if n != "" else "Pembalap"
	Gm.alamat_server = _in_alamat.text.strip_edges()
	Gm.simpan()


func _gabung() -> void:
	_simpan_input()
	var alamat := Gm.alamat_server
	var port := Net.PORT
	if ":" in alamat:
		var bag := alamat.split(":")
		alamat = bag[0]
		port = int(bag[1])
	_status("Menghubungkan ke %s ..." % alamat)
	var e := Net.gabung(alamat, port)
	if e != OK:
		_status("Alamat tidak valid.")


func _buat_ruang() -> void:
	_simpan_input()
	var e := Net.host(Net.PORT)
	if e != OK:
		_status("Gagal membuat ruang (port %d dipakai?)." % Net.PORT)
		return
	_tampil_ruang(true)
	_status("Ruang dibuat. Beri tahu temanmu alamat IP di atas, lalu tekan SIAP.")


func _tampil_ruang(ya: bool) -> void:
	_vb_koneksi.visible = not ya
	_vb_ruang.visible = ya
	if ya:
		var ips: Array = []
		for a in IP.get_local_addresses():
			if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
				ips.append(a)
		_lbl_ip.text = ("IP ruang ini: %s   (port %d)" % [", ".join(ips.slice(0, 2)), Net.PORT]) if Net.adalah_server() and not Net.dedicated else "Terhubung ke server."
		_segarkan_ruang()


func _segarkan_ruang() -> void:
	if _lbl_ruang == null or not Net.aktif:
		return
	var t := ""
	var saya := Net.id_saya()
	for id in Net.pemain:
		var p: Dictionary = Net.pemain[id]
		t += "%s %s  —  %s  —  %s\n" % ["▶" if id == saya else "•", p["nama"], Gm.profil(str(p["mobil"]))["nama"], "SIAP" if p["siap"] else "menunggu"]
	_lbl_ruang.text = t
	var sendiri: bool = Net.pemain.has(saya) and Net.pemain[saya]["siap"]
	_btn_siap.text = "BATAL SIAP" if sendiri else "SIAP"


func _toggle_siap() -> void:
	var saya := Net.id_saya()
	if not Net.pemain.has(saya):
		return
	Net.atur_siap(not Net.pemain[saya]["siap"])


func _terapkan_tema(delta: float) -> void:
	_tema = _tema.lerp(_tema_t, 1.0 - exp(-4.0 * delta))
	var denyut := 1.3 + 0.7 * sin(_t * 2.2)
	if _mat_cincin:
		_mat_cincin.albedo_color = _tema
		_mat_cincin.emission = _tema
		_mat_cincin.emission_energy_multiplier = denyut
	if _mat_partikel:
		_mat_partikel.albedo_color = _tema.lerp(Color(1, 1, 1), 0.4)
	if _mat_latar:
		_mat_latar.set_shader_parameter("tema", Vector3(_tema.r, _tema.g, _tema.b))
	if _rim_l:
		_rim_l.light_color = Color(1.0, 0.4, 0.9).lerp(_tema, 0.5)
	if _cam:
		_cam_pos = _cam_pos.lerp(_cam_tpos, 1.0 - exp(-3.5 * delta))
		_cam_lihat = _cam_lihat.lerp(_cam_tlihat, 1.0 - exp(-3.5 * delta))
		_cam.look_at_from_position(_cam_pos, _cam_lihat, Vector3.UP)


func _process(delta: float) -> void:
	_t += delta
	_terapkan_tema(delta)
	if _putar:
		_putar.rotation.y += delta * 0.45
	if _mobil_pajang != null and is_instance_valid(_mobil_pajang):
		var terbang: bool = _mobil_pajang.terbang_mampu
		var naik := 0.0
		if terbang:
			naik = 0.65 + sin(_t * 1.6) * 0.07
		# hantu: set transform lokal terhadap panggung putar
		_mobil_pajang.position = Vector3(0, 0.08 + naik, 0)
		_mobil_pajang.terbang_on = terbang
		_mobil_pajang.kmh = 0.0
