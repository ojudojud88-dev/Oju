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
	"volt": Color(0.20, 0.78, 1.0),
}
var _tema := Color(1.0, 0.72, 0.10)
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
	pm.sky_top_color = Color(0.35, 0.42, 0.55)
	pm.sky_horizon_color = Color(0.9, 0.88, 0.85)
	pm.ground_horizon_color = Color(0.45, 0.43, 0.42)
	pm.ground_bottom_color = Color(0.04, 0.04, 0.06)
	pm.sun_angle_max = 25.0
	sky.sky_material = pm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.2
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.92, 0.82)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.0
	_vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 0.9
	rim.light_color = Color(0.6, 0.75, 1.0)
	_vp.add_child(rim)
	_rim_l = rim

	# lantai panggung bundar
	var lantai := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 4.2
	cm.bottom_radius = 4.2
	cm.height = 0.12
	cm.radial_segments = 64
	lantai.mesh = cm
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.07, 0.07, 0.09)
	lm.metallic = 0.7
	lm.roughness = 0.28
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
	_mat_cincin = cmat
	cincin.scale = Vector3(1, 0.3, 1)
	_vp.add_child(cincin)
	# dinding studio melengkung (sisi dalam silinder)
	var dinding := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 15.0
	wm.bottom_radius = 15.0
	wm.height = 12.0
	wm.radial_segments = 64
	wm.cap_top = false
	wm.cap_bottom = false
	dinding.mesh = wm
	var dmat := ShaderMaterial.new()
	var dsh := Shader.new()
	dsh.code = """shader_type spatial;
render_mode unshaded, cull_front;
uniform vec3 tema = vec3(1.0, 0.7, 0.1);
varying vec3 wp;
void vertex() { wp = VERTEX; }
void fragment() {
	float g = clamp((wp.y + 6.0) / 12.0, 0.0, 1.0);
	float sudut = atan(wp.x, wp.z);
	float pita = 0.5 + 0.5 * sin(sudut * 3.0 + TIME * 0.35);
	float pita2 = 0.5 + 0.5 * sin(sudut * 5.0 - TIME * 0.22 + 1.7);
	vec3 gelap = vec3(0.012, 0.015, 0.03);
	vec3 bawah = tema * (0.55 + 0.25 * pita);
	vec3 tengah = mix(tema, vec3(0.35, 0.2, 0.7), 0.5) * (0.18 + 0.12 * pita2);
	vec3 c = mix(bawah, tengah, smoothstep(0.38, 0.62, g));
	c = mix(c, gelap, smoothstep(0.55, 1.0, g));
	c = mix(gelap, c, smoothstep(0.30, 0.45, g));
	ALBEDO = c;
}
""";
	dmat.shader = dsh
	_mat_dinding = dmat
	dinding.material_override = dmat
	dinding.position = Vector3(0, 5.5, 0)
	_vp.add_child(dinding)
	# lantai luas mengilap
	var lt := MeshInstance3D.new()
	var lc := CylinderMesh.new()
	lc.top_radius = 15.0
	lc.bottom_radius = 15.0
	lc.height = 0.1
	lc.radial_segments = 64
	lt.mesh = lc
	var ltm := StandardMaterial3D.new()
	ltm.albedo_color = Color(0.04, 0.045, 0.06)
	ltm.metallic = 0.5
	ltm.roughness = 0.4
	lt.material_override = ltm
	lt.position = Vector3(0, -0.12, 0)
	_vp.add_child(lt)
	# strip lampu di dinding (tiga cincin cahaya)
	for k in 3:
		var rg := MeshInstance3D.new()
		var rt := TorusMesh.new()
		rt.inner_radius = 14.8
		rt.outer_radius = 14.95
		rt.rings = 64
		rt.ring_segments = 6
		rg.mesh = rt
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.7, 0.85, 1.0)
		rm.emission_enabled = true
		rm.emission = Color(0.55, 0.75, 1.0)
		rm.emission_energy_multiplier = 0.7
		rg.material_override = rm
		_mat_strip.append(rm)
		rg.position = Vector3(0, 1.2 + k * 2.6, 0)
		_vp.add_child(rg)
	# lampu sorot ke mobil
	var sp := SpotLight3D.new()
	sp.position = Vector3(0, 7.0, 2.0)
	sp.rotation_degrees = Vector3(-90, 0, 0)
	sp.spot_range = 12.0
	sp.spot_angle = 38.0
	sp.light_energy = 2.2
	sp.light_color = Color(1.0, 0.95, 0.88)
	_vp.add_child(sp)
	_spot = sp

	# tiang cahaya melingkar
	var psh := Shader.new()
	psh.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec3 tema = vec3(1.0, 0.7, 0.1);
uniform float fase = 0.0;
void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float sisi = pow(1.0 - x, 2.0);
	float naik = pow(1.0 - UV.y, 1.5);
	float kedip = 0.65 + 0.35 * sin(TIME * 1.3 + fase);
	ALBEDO = tema * 1.4;
	ALPHA = sisi * naik * 0.55 * kedip;
}
""";
	for k in 12:
		var ang := float(k) / 12.0 * TAU
		var pl := MeshInstance3D.new()
		var pq := QuadMesh.new()
		pq.size = Vector2(0.9, 9.0)
		pl.mesh = pq
		var pmt := ShaderMaterial.new()
		pmt.shader = psh
		pmt.set_shader_parameter("fase", float(k) * 1.7)
		pl.material_override = pmt
		pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pl.position = Vector3(sin(ang) * 7.5, 4.5, cos(ang) * 7.5)
		pl.rotation.y = ang + PI
		_vp.add_child(pl)
		_mat_pilar.append(pmt)
	# percikan cahaya melayang naik
	var pt := CPUParticles3D.new()
	pt.amount = 90
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
	pt.scale_amount_max = 1.6
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
	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.position = Vector3(5.4, 1.5, 8.6)
	_vp.add_child(cam)
	cam.look_at_from_position(Vector3(5.4, 1.5, 8.6), Vector3(0, 0.7, 0), Vector3.UP)
	cam.current = true


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


func _buat_ui() -> void:
	# judul + koin
	var judul := _label("TURBO DRIFT", 54, Color(1.0, 0.82, 0.3))
	judul.position = Vector2(34, 14)
	add_child(judul)
	_lbl_koin = _label("", 40, Color(1.0, 0.9, 0.4))
	_lbl_koin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lbl_koin.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_koin.offset_left = -440
	_lbl_koin.offset_right = -34
	_lbl_koin.offset_top = 20
	_lbl_koin.offset_bottom = 70
	add_child(_lbl_koin)

	# daftar mobil (kiri)
	var kiri := _panel(Color(0.4, 0.7, 1.0))
	kiri.position = Vector2(30, 100)
	kiri.custom_minimum_size = Vector2(320, 0)
	add_child(kiri)
	var vk := VBoxContainer.new()
	vk.add_theme_constant_override("separation", 10)
	kiri.add_child(vk)
	vk.add_child(_label("TOKO & GARASI", 28, Color(0.7, 0.88, 1.0)))
	for id in Gm.URUTAN:
		var b := _tombol("", Color(0.45, 0.72, 1.0), 20, 300, 78)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_pilih_pajang.bind(id))
		vk.add_child(b)
		_daftar_btn[id] = b
		_pasang_ikon(b, id)

	# detail (kanan)
	var kanan := _panel(Color(1.0, 0.75, 0.3))
	kanan.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	kanan.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	kanan.offset_left = -350
	kanan.offset_right = -30
	kanan.offset_top = 80
	add_child(kanan)
	var vd := VBoxContainer.new()
	vd.add_theme_constant_override("separation", 5)
	kanan.add_child(vd)
	_lbl_nama = _label("", 28, Color(1.0, 0.9, 0.5))
	_lbl_nama.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_nama.custom_minimum_size = Vector2(300, 0)
	vd.add_child(_lbl_nama)
	_lbl_warna = _label("", 22, Color(0.8, 0.85, 0.9))
	vd.add_child(_lbl_warna)
	_lbl_info = _label("", 22, Color(0.85, 0.9, 1.0))
	_lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_info.custom_minimum_size = Vector2(300, 0)
	vd.add_child(_lbl_info)
	vd.add_child(_label("TENAGA", 20))
	_bar_daya = _bar()
	vd.add_child(_bar_daya)
	vd.add_child(_label("KECEPATAN MAKS", 20))
	_bar_vmaks = _bar()
	vd.add_child(_bar_vmaks)
	_lbl_fitur = _label("", 24, Color(0.55, 0.85, 1.0))
	vd.add_child(_lbl_fitur)
	_btn_aksi = _tombol("", Color(0.5, 1.0, 0.6), 28, 300, 60)
	_btn_aksi.pressed.connect(_aksi)
	vd.add_child(_btn_aksi)
	_lbl_pesan = _label("", 22, Color(1.0, 0.7, 0.5))
	_lbl_pesan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_pesan.custom_minimum_size = Vector2(300, 0)
	vd.add_child(_lbl_pesan)

	# tombol utama (bawah tengah)
	var bawah := HBoxContainer.new()
	bawah.add_theme_constant_override("separation", 22)
	bawah.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bawah.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bawah.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bawah.offset_bottom = -26
	add_child(bawah)
	var b_solo := _tombol("BALAPAN", Color(0.5, 1.0, 0.6), 40, 320, 84)
	b_solo.pressed.connect(_mulai_solo)
	bawah.add_child(b_solo)
	_btn_lawan = _tombol("", Color(0.8, 0.8, 0.9), 24, 180, 84)
	_btn_lawan.pressed.connect(_ganti_lawan)
	bawah.add_child(_btn_lawan)
	var b_on := _tombol("ONLINE", Color(0.5, 0.75, 1.0), 40, 320, 84)
	b_on.pressed.connect(_buka_online)
	bawah.add_child(b_on)
	_perbarui_lawan()

	_buat_panel_online()


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
	_lbl_koin.text = "KOIN  %s" % _rp(Gm.koin)
	for id in Gm.URUTAN:
		var p: Dictionary = Gm.profil(id)
		var b: Button = _daftar_btn[id]
		var status := "DIMILIKI" if Gm.punya(id) else "%s koin" % _rp(int(p["harga"]))
		if Gm.terpilih == id:
			status = "DIPAKAI"
		b.text = "%s\n%s" % [p["nama"], status]
		b.add_theme_font_size_override("font_size", 21)
	var p2: Dictionary = Gm.profil(_id_pajang)
	_lbl_nama.text = p2["nama"]
	_lbl_warna.text = "Warna: %s" % p2["warna"]
	_lbl_info.text = p2["info"]
	_bar_daya.value = float(p2["daya"]) / 1.3 * 100.0
	_bar_vmaks.value = float(p2["vmaks"]) / 1.1 * 100.0
	_lbl_fitur.text = "BISA TERBANG" if p2["terbang"] else ("Mobil listrik" if p2["ev"] else "Mesin V12")
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
	if _mat_dinding:
		_mat_dinding.set_shader_parameter("tema", Vector3(_tema.r, _tema.g, _tema.b))
	for pm in _mat_pilar:
		pm.set_shader_parameter("tema", Vector3(_tema.r, _tema.g, _tema.b))
	var denyut := 1.3 + 0.7 * sin(_t * 2.2)
	if _mat_cincin:
		_mat_cincin.albedo_color = _tema
		_mat_cincin.emission = _tema
		_mat_cincin.emission_energy_multiplier = denyut
	for rm in _mat_strip:
		rm.emission = _tema.lerp(Color(1, 1, 1), 0.35)
		rm.albedo_color = _tema
	if _mat_partikel:
		_mat_partikel.albedo_color = _tema.lerp(Color(1, 1, 1), 0.4)
	if _spot:
		_spot.light_color = Color(1, 1, 1).lerp(_tema, 0.25)
	if _rim_l:
		_rim_l.light_color = _tema.lerp(Color(1, 1, 1), 0.3)


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
