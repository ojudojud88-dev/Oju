extends VehicleBody3D
## Lamborghini Aventador LP 700-4 (V12 6.5L, 740 hp, 7 percepatan, AWD).
## Bodi melengkung hasil loft mesh + detail shader, bukan kotak.
## Konvensi model: depan = -Z, kanan = +X. Arah gerak fisika dideteksi otomatis saat start.

signal siap
signal nitro_mulai

# ---------- SETELAN (boleh diubah) ----------
const MASSA := 500.0
const GAYA_MESIN := 1300.0        # Newton per roda (0-100 km/j sekitar 3 detik)
const PENGALI_NITRO := 1.5
const KECEPATAN_MAKS := 83.0      # m/s (sekitar 300 km/j)
const GAYA_REM := 15.0
const STIR_MAKS := 0.55
const STIR_MIN := 0.07
const GRIP_DEPAN := 4.0
const GRIP_BELAKANG := 3.4
const GRIP_DRIFT := 1.3
const SKID_MAKS := 500
const EXH_Z := 2.52               # posisi ujung knalpot (sumbu Z lokal)

# Mesin V12 6.5L: 6 pembakaran per putaran, redline 8500 rpm, 7 percepatan
const REDLINE := 8500.0
const IDLE := 900.0
const GIGI_KMH := [68.0, 108.0, 150.0, 195.0, 238.0, 278.0, 315.0]   # km/j maks tiap gigi di redline
const MIX_RATE := 22050

# ---------- MODEL 3D ASLI (opsional) ----------
# Taruh file model di res://models/mobil.glb -> otomatis dipakai menggantikan bodi buatan kode.
const MODEL_PATH := "res://models/mobil.glb"
const MODEL_PANJANG := 4.5        # panjang mobil di game (meter)
const MODEL_YAW := 0.0            # derajat. Ubah ke 180 kalau mobil terlihat jalan mundur
const MODEL_Y_OFFSET := 0.0       # naik/turunkan model (meter)

const PALET := [
	{"body": Color(0.98, 0.72, 0.00), "stripe": Color(0.02, 0.02, 0.025)},   # kuning Giallo + strip hitam
]

# Profil bodi Aventador (panjang 4,8 m, lebar 2,02 m, tinggi 1,13 m, wheelbase 2,7 m).
# Tiap stasiun: [z, y_bawah, lebar_sisi, y_bahu, lebar_atas1, y_atas1, lebar_atap, y_atap, punggung_kap].
# Penampang berupa poligon bersudut (garis lipatan tegas khas Lamborghini), memanjang halus ke belakang.
const STASIUN := [
	[-2.40, 0.30, 0.84, 0.44, 0.58, 0.50, 0.58, 0.50, 0.008, 0.00],
	[-2.18, 0.28, 0.97, 0.50, 0.70, 0.56, 0.70, 0.56, 0.015, 0.03],
	[-1.80, 0.28, 1.01, 0.60, 0.76, 0.66, 0.76, 0.66, 0.022, 0.09],
	[-1.45, 0.28, 1.02, 0.68, 0.78, 0.76, 0.78, 0.76, 0.025, 0.15],
	[-0.95, 0.28, 1.01, 0.76, 0.72, 0.88, 0.72, 0.88, 0.025, 0.08],
	[-0.55, 0.28, 1.01, 0.82, 0.64, 1.04, 0.64, 1.04, 0.018, 0.02],
	[-0.15, 0.28, 1.01, 0.86, 0.58, 1.17, 0.58, 1.17, 0.012, 0.00],
	[0.35, 0.28, 1.02, 0.90, 0.54, 1.19, 0.54, 1.19, 0.012, 0.00],
	[0.95, 0.28, 1.05, 0.95, 0.58, 1.08, 0.58, 1.08, 0.012, 0.04],
	[1.40, 0.28, 1.06, 0.96, 0.66, 0.98, 0.66, 0.98, 0.010, 0.08],
	[1.95, 0.28, 1.04, 0.94, 0.72, 0.93, 0.72, 0.93, 0.010, 0.07],
	[2.30, 0.28, 0.93, 0.84, 0.66, 0.84, 0.66, 0.84, 0.000, 0.02],
	[2.40, 0.30, 0.84, 0.74, 0.56, 0.74, 0.56, 0.74, 0.000, 0.00],
]

# Profil bodi roadster listrik: lebih rendah, mulus, kaca atap lebar, tanpa punuk mesin.
const STASIUN_RD := [
	[-2.40, 0.30, 0.82, 0.42, 0.52, 0.46, 0.52, 0.46, 0.008, 0.00],
	[-2.18, 0.28, 0.95, 0.48, 0.68, 0.52, 0.68, 0.52, 0.012, 0.02],
	[-1.80, 0.28, 1.00, 0.58, 0.76, 0.64, 0.76, 0.64, 0.020, 0.08],
	[-1.45, 0.28, 1.01, 0.66, 0.78, 0.72, 0.78, 0.72, 0.022, 0.12],
	[-0.95, 0.28, 1.01, 0.74, 0.72, 0.86, 0.72, 0.86, 0.020, 0.07],
	[-0.55, 0.28, 1.01, 0.80, 0.66, 1.00, 0.66, 1.00, 0.015, 0.02],
	[-0.15, 0.28, 1.01, 0.84, 0.62, 1.10, 0.62, 1.10, 0.012, 0.00],
	[0.35, 0.28, 1.02, 0.88, 0.60, 1.12, 0.60, 1.12, 0.012, 0.00],
	[0.95, 0.28, 1.04, 0.92, 0.64, 1.04, 0.64, 1.04, 0.012, 0.05],
	[1.40, 0.28, 1.05, 0.94, 0.70, 0.94, 0.70, 0.94, 0.010, 0.09],
	[1.95, 0.28, 1.03, 0.92, 0.72, 0.90, 0.72, 0.90, 0.010, 0.08],
	[2.30, 0.28, 0.96, 0.84, 0.66, 0.84, 0.66, 0.84, 0.000, 0.03],
	[2.40, 0.30, 0.84, 0.74, 0.56, 0.74, 0.56, 0.74, 0.000, 0.00],
]


const SHADER_BODI := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 paint : source_color = vec4(0.98, 0.72, 0.0, 1.0);
uniform vec4 stripe : source_color = vec4(0.02, 0.02, 0.025, 1.0);
uniform float rem_glow = 1.6;
uniform float ev = 0.0;
uniform vec4 paint2 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float iri = 0.0;
varying vec3 lp;
varying vec3 ln;
void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}
float hexd(vec2 p, float r) {
	vec2 q = abs(p);
	return max(q.x - 0.866 * r, 0.5 * q.x + 0.866 * q.y - 0.866 * r);
}
float line(float d, float w) { float w2 = max(w, fwidth(d) * 1.2); return 1.0 - smoothstep(w2, w2 * 2.0, d); }
void fragment() {
	float ax = abs(lp.x);
	// lubang lengkung roda
	float dz = abs(abs(lp.z) - 1.35);
	if (length(vec2(dz, lp.y - 0.50)) < 0.47 && lp.y < 0.74 && ax > 0.6 && (abs(ln.x) > 0.55 || lp.y < 0.34)) { discard; }
	// bak mesin heksagonal terbuka (V12 terlihat)
	float hx = hexd(vec2(lp.x, lp.z - 1.58), 0.5);
	if (ev < 0.5 && hx < 0.0 && lp.y > 0.85) { discard; }

	// kaca depan, kaca samping (bentuk trapesium, tiang tetap dicat), kaca belakang kecil
	float wind = step(-0.85, lp.z) * (1.0 - step(-0.10 + ev * 1.0, lp.z)) * step(0.96, lp.y) * step(0.35, ln.y) * (1.0 - step(0.62, ax));
	float zmin = -0.40 + (lp.y - 1.0) * 1.4;
	float zmax = 0.92 - (lp.y - 1.0) * 1.2;
	float sidew = step(zmin, lp.z) * step(lp.z, zmax) * step(1.0, lp.y) * (1.0 - step(1.25, lp.y)) * step(0.2, abs(ln.x)) * step(0.7, ax);
	float rearw = step(0.88, lp.z) * (1.0 - step(1.08, lp.z)) * step(0.98, lp.y) * (1.0 - step(0.5, ax)) * step(0.3, ln.y);
	float glass = clamp(wind + sidew + rearw, 0.0, 1.0);

	// intake samping besar bersirip, bumper depan, rok, panel belakang, ventilasi kap, bingkai mesin
	float intake = step(0.5, lp.z) * (1.0 - step(1.12, lp.z)) * step(0.5, lp.y) * (1.0 - step(0.62 + (lp.z - 0.5) * 0.55, lp.y)) * step(0.94, ax) * step(0.5, abs(ln.x));
	float gfw = fwidth(lp.y * 22.0);
	float grille = mix(smoothstep(0.35, 0.65, abs(fract(lp.y * 22.0) - 0.5) * 2.0), 0.5, smoothstep(0.25, 0.5, gfw));
	float frontg = (1.0 - step(-2.0, lp.z)) * (1.0 - step(0.42, lp.y)) * (1.0 - step(0.9, ax));
	float sill = 1.0 - step(0.33, lp.y);
	float rear_panel = step(2.2, lp.z) * (1.0 - step(0.5, lp.y));
	float vent = 0.0 * step(0.25, ax) * (1.0 - step(0.45, ax)) * step(-1.35, lp.z) * (1.0 - step(-0.95, lp.z)) * step(0.7, lp.y) * step(0.5, ln.y);
	float ring = (1.0 - step(0.06, hx)) * step(0.0, hx) * step(0.85, lp.y);

	// pintu gunting: garis halus, bukan kotak hitam
	float door_zone = step(0.9, ax) * step(0.4, lp.y) * (1.0 - step(1.0, lp.y)) * step(0.8, abs(ln.x)) * step(-0.55, lp.z) * (1.0 - step(0.5, lp.z));
	float dd = min(abs(lp.z + 0.40 - (lp.y - 0.4) * 0.35), abs(lp.z - 0.46));
	float doorline = clamp(line(dd, 0.004) + line(abs(lp.y - 0.42), 0.004), 0.0, 1.0) * door_zone;
	float handle = step(0.3, lp.z) * (1.0 - step(0.42, lp.z)) * step(0.72, lp.y) * (1.0 - step(0.76, lp.y)) * step(0.95, ax);

	// lampu depan LED berbentuk Y di ujung fender
	vec2 pf = vec2(ax, lp.z);
	float dY = min(seg(pf, vec2(0.52, -2.16), vec2(0.70, -2.02)), min(seg(pf, vec2(0.70, -2.02), vec2(0.90, -1.86)), seg(pf, vec2(0.70, -2.02), vec2(0.90, -2.12))));
	float zf = step(0.45, lp.y) * (1.0 - step(-1.7, lp.z)) * step(-2.35, lp.z);
	float lampY = (1.0 - smoothstep(0.014, 0.024, dY)) * zf;
	float house = (1.0 - smoothstep(0.05, 0.08, dY)) * zf;
	// lampu belakang LED berbentuk Y
	vec2 pr = vec2(ax, lp.y);
	float dT = min(seg(pr, vec2(0.62, 0.66), vec2(0.42, 0.80)), min(seg(pr, vec2(0.62, 0.66), vec2(0.84, 0.80)), seg(pr, vec2(0.62, 0.66), vec2(0.62, 0.54))));
	float tz = step(2.15, lp.z);
	float tail = (1.0 - smoothstep(0.012, 0.022, dT)) * tz;
	float tailhouse = (1.0 - smoothstep(0.035, 0.055, dT)) * tz;

	intake *= 1.0 - ev;
	float ring_k = 1.0 - ev;
	ring *= ring_k;
	float dark = clamp(intake + frontg + sill + rear_panel + vent + ring + house + tailhouse, 0.0, 1.0);

	vec3 col = paint.rgb;
	// strip balap ganda di kap, atap, dan kap mesin
	float top = step(0.8, lp.y) * (1.0 - glass) * (1.0 - dark) * step(0.3, ln.y);
	float racing = (1.0 - smoothstep(0.0, 0.012, abs(ax - 0.16) - 0.065)) * top;
	col = mix(col, stripe.rgb, racing);
	// bayangan lembut di bagian bawah bodi
	col *= mix(0.5, 1.0, smoothstep(0.28, 0.7, lp.y));
	// bentuk lengkung terbaca jelas: atas lebih terang, sisi lebih dalam
	col *= 0.70 + 0.42 * smoothstep(-0.3, 0.95, ln.y);
	col = mix(col, vec3(0.006, 0.009, 0.016), glass);
	// garis panel rapi: tepi kap, tutup mesin, belt line jendela, lis lengkung roda
	float lw = 0.0035;
	float hood_l = (line(abs(ax - 0.62), lw) * step(-2.05, lp.z) * (1.0 - step(-0.95, lp.z)) + line(abs(lp.z + 0.95), lw) * (1.0 - step(0.62, ax))) * step(0.6, lp.y) * step(0.5, ln.y);
	float deck_l = (line(abs(ax - 0.55), lw) * step(0.9, lp.z) * (1.0 - step(2.25, lp.z)) + line(abs(lp.z - 2.25), lw) * (1.0 - step(0.55, ax))) * step(0.85, lp.y) * step(0.5, ln.y);
	float belt = line(abs(lp.y - 1.0), 0.006) * step(zmin, lp.z) * step(lp.z, zmax) * step(0.2, abs(ln.x)) * step(0.8, ax);
	float arch_d = abs(length(vec2(dz, lp.y - 0.50)) - 0.50);
	float arch_l = line(arch_d, 0.006) * step(0.6, ax) * step(lp.y, 0.9) * step(0.55, abs(ln.x));
	float seam = clamp(hood_l + deck_l + arch_l, 0.0, 1.0) * (1.0 - dark) * (1.0 - glass);
	col = mix(col, col * 0.35, seam);
	col = mix(col, vec3(0.02), belt * (1.0 - dark));
	// jaring sarang lebah di intake bumper depan dan panel belakang
	vec2 hq = vec2(lp.x * 26.0 + floor(lp.y * 22.0) * 0.5, lp.y * 22.0);
	float hole = length(fract(hq) - 0.5);
	float mfw = fwidth(lp.y * 22.0);
	float mesh = mix(smoothstep(0.30, 0.40, hole), 0.55, smoothstep(0.2, 0.45, mfw));
	float meshz = clamp(frontg + rear_panel, 0.0, 1.0);
	vec3 meshcol = mix(vec3(0.004), vec3(0.20, 0.20, 0.22), mesh);
	col = mix(col, vec3(0.012), dark * (1.0 - intake) * (1.0 - meshz));
	col = mix(col, meshcol, meshz * (1.0 - sill));
	col = mix(col, paint.rgb * 0.10, intake);
	col = mix(col, paint.rgb * 0.45, intake * grille);
	col = mix(col, col * 0.5, doorline);
	col = mix(col, vec3(0.02), handle);

	// kilau metalik lembut (frekuensi rendah, tanpa butiran kasar) + semburat pearl di tepi
	float fl = 0.5 + 0.5 * sin(lp.x * 5.0 + lp.z * 3.0) * sin(lp.y * 4.0 - lp.z * 2.0);
	col *= 1.0 + (fl - 0.5) * 0.10 * (1.0 - dark) * (1.0 - glass);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	col = mix(col, col * vec3(1.12, 1.0, 0.78) + vec3(0.04, 0.02, 0.0), fres * 0.5 * (1.0 - dark) * (1.0 - glass));
	// cat kameleon: warna bergeser ke paint2 mengikuti sudut pandang & lengkung bodi
	float sudut_k = clamp(fres * 1.6 + 0.35 * (0.5 + 0.5 * sin(lp.z * 1.6 + lp.y * 2.0)), 0.0, 1.0);
	col = mix(col, paint2.rgb * (0.75 + 0.5 * smoothstep(-0.3, 0.95, ln.y)), sudut_k * iri * (1.0 - dark) * (1.0 - glass));
	ALBEDO = col;
	METALLIC = mix(0.25, 0.85, glass);
	ROUGHNESS = mix(mix(0.3, 0.05, glass), 0.55, dark);
	SPECULAR = 0.6;
	CLEARCOAT = 0.9 * (1.0 - dark);
	CLEARCOAT_ROUGHNESS = 0.03;
	RIM = 0.2;
	RIM_TINT = 0.5;
	EMISSION = vec3(0.9, 0.95, 1.0) * lampY * 6.0 + vec3(1.0, 0.03, 0.03) * tail * rem_glow;
}
"""

const SHADER_API := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float power = 0.0;
uniform float core = 0.0;
uniform float len = 1.6;
varying float u;
void vertex() { u = clamp(VERTEX.y / len + 0.5, 0.0, 1.0); }
void fragment() {
	float fl = 0.85 + 0.15 * sin(TIME * 70.0 + u * 25.0);
	float diamond = pow(max(0.0, sin(u * 18.0 + sin(TIME * 40.0) * 0.6)), 6.0);
	vec3 hot = mix(vec3(0.55, 0.8, 1.0), vec3(1.0, 0.97, 0.85), core);
	vec3 col = mix(hot, vec3(1.0, 0.35, 0.05), smoothstep(0.05, 0.7, u) * (1.0 - core));
	col += vec3(0.4, 0.7, 1.0) * diamond * 0.9 * (1.0 - u);
	float edge = smoothstep(0.0, 0.6, abs(dot(normalize(NORMAL), normalize(VIEW))));
	float a = pow(1.0 - u, 1.4) * fl * power * edge;
	ALBEDO = col * 3.0;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

# ---------- INPUT (diisi oleh main.gd) ----------
var gas := 0.0
var rem_in := 0.0
var stir_in := 0.0          # +1 = kiri, -1 = kanan
var nitro_on := false

# ---------- STATUS (dibaca oleh main.gd) ----------
var nitro_isi := 1.0
var kmh := 0.0
var boost_aktif := false
var fz := -1.0
var spawn_pos := Vector3(70, 0.8, 0)
var spawn_dir := Vector3(0, 0, -1)

# ---------- PROFIL MOBIL (diisi sebelum add_child) ----------
var profil: Dictionary = {}
var hantu := false            # true = tanpa fisika (pajangan toko / pemain online lain)
var suara := true
var ev := false
var terbang_mampu := false
var terbang_on := false
var naik_in := 0.0            # -1 turun ... +1 naik (saat terbang)
var parkir := false           # true = tahan di tempat (sebelum GO / setelah finis)
var _st: Array = STASIUN
var _daya := 1.0
var _vm := 1.0
var _thruster: Array[MeshInstance3D] = []
var _thr_light: OmniLight3D
var _thr_p := 0.0

var _visual: Node3D
var _body_proc: Node3D
var _hub_list: Array[Node3D] = []
var _sayap: Node3D
var rpm := 900.0
var gigi := 1
var _shift_t := 0.0
var _gas_s := 0.0
var _ph := 0.0
const TAB_N := 1024
var _tab_lo := PackedFloat32Array()
var _tab_hi := PackedFloat32Array()
var _lp := 0.0
var _lp2 := 0.0
var _pop_amp := 0.0
var _ph_whine := 0.0
var _audio: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _yaw0 := 0.0
var _mat_bodi: ShaderMaterial
var _mat_body: StandardMaterial3D
var _mat_kaca: StandardMaterial3D
var _mat_karbon: StandardMaterial3D
var _mat_ban: StandardMaterial3D
var _mat_velg: StandardMaterial3D
var _mat_kaliper: StandardMaterial3D
var _mat_neon: StandardMaterial3D
var _mat_mesin: StandardMaterial3D
var _mat_kepala: StandardMaterial3D
var _mat_pipa: StandardMaterial3D
var _mat_kacahex: StandardMaterial3D
var _mat_liner: ShaderMaterial
var _mat_cakram: StandardMaterial3D
var _mat_tutup: StandardMaterial3D
var _lampu_rem: OmniLight3D
var _nos_light: OmniLight3D
var _wheels: Array[VehicleWheel3D] = []
var _asap: Array[CPUParticles3D] = []
var _percikan: Array[CPUParticles3D] = []
var _api_kerucut: Array = []
var _skid_mm: MultiMeshInstance3D
var _skid_i := 0
var _skid_timer := 0.0
var _fase := 0
var _t := 0.0
var _t_anim := 0.0
var _pods: Array = []
var _fwd_prev := 0.0
var _acc_s := 0.0
var _roll := 0.0
var _pitch := 0.0
var _grip := GRIP_BELAKANG
var _palet_i := 0
var _rem_glow := 1.6
var _nos_p := 0.0
var _flash := 0.0
var _boost_prev := false
var _pop := 0.0
var _land := 0.0
var _udara_t := 0.0
var _gas_prev := 0.0


func _ready() -> void:
	_terapkan_profil()
	mass = MASSA
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.3, 0)
	linear_damp = 0.05
	angular_damp = 0.6
	can_sleep = false
	_siapkan_material()
	if not hantu:
		_buat_collision()
	_buat_body()
	_buat_roda()
	_buat_lampu()
	_buat_efek()
	_buat_nos()
	if suara and not hantu:
		_buat_audio()
	_pasang_model()
	_set_palet(0)
	_buat_thruster()
	_terapkan_arah()
	if hantu:
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		collision_layer = 0
		collision_mask = 0
		_fase = 2
		fz = -1.0
		_terapkan_arah()
		siap.emit.call_deferred()


func _terapkan_profil() -> void:
	_daya = float(profil.get("daya", 1.0))
	_vm = float(profil.get("vmaks", 1.0))
	ev = bool(profil.get("ev", false))
	terbang_mampu = bool(profil.get("terbang", false))
	if str(profil.get("bodi", "lambo")) == "roadster":
		_st = STASIUN_RD
	else:
		_st = STASIUN


# =====================================================================
#  MATERIAL
# =====================================================================
func _siapkan_material() -> void:
	var sh := Shader.new()
	sh.code = SHADER_BODI
	_mat_bodi = ShaderMaterial.new()
	_mat_bodi.shader = sh

	_mat_body = StandardMaterial3D.new()
	_mat_body.metallic = 0.85
	_mat_body.roughness = 0.22

	_mat_kaca = StandardMaterial3D.new()
	_mat_kaca.albedo_color = Color(0.02, 0.03, 0.07)
	_mat_kaca.metallic = 0.9
	_mat_kaca.roughness = 0.05

	_mat_karbon = StandardMaterial3D.new()
	_mat_karbon.albedo_color = Color(0.03, 0.03, 0.04)
	_mat_karbon.metallic = 0.6
	_mat_karbon.roughness = 0.3
	_mat_karbon.albedo_texture = load("res://tex/carbon.png")
	_mat_karbon.uv1_triplanar = true
	_mat_karbon.uv1_scale = Vector3(2.5, 2.5, 2.5)
	_mat_karbon.clearcoat_enabled = true
	_mat_karbon.clearcoat = 0.8
	_mat_karbon.clearcoat_roughness = 0.08

	_mat_ban = StandardMaterial3D.new()
	_mat_ban.albedo_color = Color(0.025, 0.025, 0.03)
	_mat_ban.roughness = 0.9
	_mat_ban.albedo_texture = load("res://tex/karet.png")
	_mat_ban.uv1_triplanar = true
	_mat_ban.uv1_scale = Vector3(3, 3, 3)

	_mat_velg = StandardMaterial3D.new()
	_mat_velg.albedo_color = Color(0.92, 0.93, 0.97)
	_mat_velg.metallic = 0.6
	_mat_velg.roughness = 0.3
	if profil.has("velg_warna"):
		_mat_velg.albedo_color = profil["velg_warna"]
	_mat_kaliper = StandardMaterial3D.new()
	_mat_kaliper.albedo_color = Color(0.85, 0.02, 0.02)
	_mat_kaliper.roughness = 0.4

	var shl := Shader.new()
	shl.code = "shader_type spatial;\nrender_mode cull_front;\nvoid vertex() { VERTEX.x = min(VERTEX.x, 0.1); }\nvoid fragment() {\n\tALBEDO = vec3(0.04);\n\tROUGHNESS = 0.9;\n}\n"
	_mat_liner = ShaderMaterial.new()
	_mat_liner.shader = shl

	_mat_cakram = StandardMaterial3D.new()
	_mat_cakram.albedo_color = Color(0.42, 0.43, 0.47)
	_mat_cakram.metallic = 0.9
	_mat_cakram.roughness = 0.45

	_mat_tutup = StandardMaterial3D.new()
	_mat_tutup.albedo_color = Color(0.9, 0.68, 0.1)
	_mat_tutup.metallic = 1.0
	_mat_tutup.roughness = 0.3

	_mat_neon = StandardMaterial3D.new()    # dipakai sebagai krom (bibir velg)
	_mat_neon.albedo_color = Color(0.85, 0.86, 0.9)
	_mat_neon.metallic = 1.0
	_mat_neon.roughness = 0.12

	_mat_mesin = StandardMaterial3D.new()
	_mat_mesin.albedo_color = Color(0.08, 0.08, 0.09)
	_mat_mesin.metallic = 0.8
	_mat_mesin.roughness = 0.4

	_mat_kepala = StandardMaterial3D.new()
	_mat_kepala.albedo_color = Color(0.75, 0.12, 0.04)
	_mat_kepala.metallic = 0.6
	_mat_kepala.roughness = 0.35

	_mat_pipa = StandardMaterial3D.new()
	_mat_pipa.albedo_color = Color(0.32, 0.32, 0.35)
	_mat_pipa.metallic = 0.6
	_mat_pipa.roughness = 0.4

	_mat_kacahex = StandardMaterial3D.new()
	_mat_kacahex.albedo_color = Color(0.03, 0.04, 0.06, 0.22)
	_mat_kacahex.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_kacahex.metallic = 0.5
	_mat_kacahex.roughness = 0.05


# =====================================================================
#  BODI MELENGKUNG (loft dari penampang superellipse)
# =====================================================================
func _stasiun(kol: int, s: float) -> float:
	var n := _st.size()
	var i := clampi(int(floor(s)), 0, n - 2)
	var t := s - float(i)
	var p0: float = _st[maxi(i - 1, 0)][kol]
	var p1: float = _st[i][kol]
	var p2: float = _st[i + 1][kol]
	var p3: float = _st[mini(i + 2, n - 1)][kol]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


func _rata2(row: Array) -> Vector3:
	var s := Vector3.ZERO
	for v in row:
		s += v
	return s / float(row.size())


func _bangun_bodi() -> ArrayMesh:
	var n := _st.size()
	var cincin := 200
	var p_exp := 2.0 / float(profil.get("sudut", 2.6))
	var grid: Array = []
	for r in cincin:
		var t := float(r) / float(cincin - 1) * float(n - 1)
		var z := _stasiun(0, t)
		var yb := _stasiun(1, t)
		var wl := _stasiun(2, t)
		var ysh := _stasiun(3, t)
		var wu := _stasiun(6, t)
		var yt := _stasiun(7, t)
		var rid := _stasiun(8, t)
		var bul := _stasiun(9, t)
		# sisi kanan: sill -> badan bawah -> bahu -> lengkung membulat (fender/kap/atap)
		var kanan: Array = [Vector2(wl - 0.14, yb), Vector2(wl - 0.03, yb + 0.07), Vector2(wl, yb + 0.17), Vector2(wl, ysh + bul)]
		for i in range(1, 11):
			var th := float(i) / 10.0 * PI * 0.5
			var ce := pow(cos(th), p_exp)
			var se := pow(sin(th), p_exp)
			kanan.append(Vector2(wu + (wl - wu) * ce, ysh + (yt - ysh) * se + bul * ce * ce))
		var row: Array = []
		row.append(Vector3(0.0, yb, z))
		for pt in kanan:
			var pv: Vector2 = pt
			row.append(Vector3(pv.x, pv.y, z))
		row.append(Vector3(0.0, yt + rid, z))
		for i in range(kanan.size() - 1, -1, -1):
			var pk: Vector2 = kanan[i]
			row.append(Vector3(-pk.x, pk.y, z))
		grid.append(row)
	var jml: int = grid[0].size()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in cincin - 1:
		for k in jml:
			var k2 := (k + 1) % jml
			var a: Vector3 = grid[r][k]
			var b: Vector3 = grid[r][k2]
			var c: Vector3 = grid[r + 1][k]
			var d: Vector3 = grid[r + 1][k2]
			# alas datar & chamfer bawah punya grup sendiri (tepi tegas); sisanya halus membulat
			var grup := 0
			if k == 0 or k == jml - 1:
				grup = 1
			elif k == 1 or k == 2 or k == jml - 3 or k == jml - 2:
				grup = 2
			st.set_smooth_group(grup)
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(d)
	# tutup ujung depan & belakang (rata)
	var fc := _rata2(grid[0])
	var rc := _rata2(grid[cincin - 1])
	st.set_smooth_group(-1)
	for k in jml:
		var k2 := (k + 1) % jml
		st.add_vertex(fc)
		st.add_vertex(grid[0][k2])
		st.add_vertex(grid[0][k])
		st.add_vertex(rc)
		st.add_vertex(grid[cincin - 1][k])
		st.add_vertex(grid[cincin - 1][k2])
	st.generate_normals()
	return st.commit()


func _box(parent: Node3D, ukuran: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = ukuran
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _silinder(parent: Node3D, r: float, h: float, pos: Vector3, rot_deg: Vector3, mat: Material, seg: int = 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _buat_collision() -> void:
	var c1 := CollisionShape3D.new()
	var b1 := BoxShape3D.new()
	b1.size = Vector3(1.95, 0.5, 4.7)
	c1.shape = b1
	c1.position = Vector3(0, 0.58, 0)
	add_child(c1)
	var c2 := CollisionShape3D.new()
	var b2 := BoxShape3D.new()
	b2.size = Vector3(1.2, 0.4, 1.7)
	c2.shape = b2
	c2.position = Vector3(0, 1.1, 0.15)
	add_child(c2)


func _buat_body() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_body_proc = Node3D.new()
	_visual.add_child(_body_proc)
	var v := _body_proc

	var bodi := MeshInstance3D.new()
	bodi.mesh = _bangun_bodi()
	bodi.material_override = _mat_bodi
	v.add_child(bodi)

	# bagian dalam sumur roda (gelap)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_silinder(v, 0.46, 0.5, Vector3(sx * 0.78, 0.5, sz * 1.35), Vector3(0, 0, 90), _mat_liner, 28)

	# splitter depan besar & difuser belakang bersirip
	_box(v, Vector3(1.5, 0.03, 0.2), Vector3(0, 0.27, -2.44), _mat_karbon)
	_box(v, Vector3(1.5, 0.04, 0.7), Vector3(0, 0.3, 2.42), _mat_karbon, Vector3(-12, 0, 0))
	for i in 5:
		_box(v, Vector3(0.02, 0.14, 0.55), Vector3((i - 2) * 0.25, 0.3, 2.42), _mat_karbon)

	# spoiler aktif: naik sesuai kecepatan, terangkat tegak saat mengerem
	_sayap = Node3D.new()
	_sayap.position = Vector3(0, 1.0, 2.12)
	v.add_child(_sayap)
	if profil.get("sayap_gt", false):
		# sayap GT besar: bidang utama + sirip samping + dua tiang
		_box(_sayap, Vector3(2.0, 0.045, 0.62), Vector3(0, 0.34, 0.1), _mat_karbon)
		_box(_sayap, Vector3(1.9, 0.03, 0.26), Vector3(0, 0.40, 0.42), _mat_karbon, Vector3(-14, 0, 0))
		for sx in [-1.0, 1.0]:
			_box(_sayap, Vector3(0.035, 0.30, 0.78), Vector3(sx * 1.0, 0.34, 0.14), _mat_karbon)
			_box(_sayap, Vector3(0.06, 0.40, 0.12), Vector3(sx * 0.42, 0.14, 0.05), _mat_karbon)
	else:
		_box(_sayap, Vector3(1.55, 0.03, 0.42), Vector3.ZERO, _mat_karbon)
	if profil.has("underglow"):
		var ug := OmniLight3D.new()
		ug.light_color = profil["underglow"]
		ug.light_energy = 2.2
		ug.omni_range = 4.2
		ug.position = Vector3(0, 0.12, 0)
		ug.shadow_enabled = false
		_visual.add_child(ug)

	for sx in [-1.0, 1.0]:
		# spion
		var sp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sp.mesh = sm
		sp.material_override = _mat_body
		sp.position = Vector3(sx * 1.0, 1.0, -0.42)
		sp.scale = Vector3(0.3, 0.12, 0.18)
		v.add_child(sp)
		# dua knalpot heksagonal di tengah belakang
		if not ev:
			_silinder(v, 0.1, 0.3, Vector3(sx * 0.22, 0.48, 2.45), Vector3(90, 0, 0), _mat_pipa, 6)
	if not ev:
		_buat_mesin(v)
	else:
		_sayap.visible = false


func _buat_mesin(v: Node3D) -> void:
	# Mesin V12 terlihat dari bak mesin heksagonal di belakang kabin
	var cz := 1.58
	_box(v, Vector3(0.46, 0.18, 1.0), Vector3(0, 0.74, cz), _mat_mesin)
	for sx in [-1.0, 1.0]:
		_box(v, Vector3(0.2, 0.12, 0.98), Vector3(sx * 0.17, 0.86, cz), _mat_kepala, Vector3(0, 0, -sx * 25.0))
		for i in 6:
			_silinder(v, 0.035, 0.16, Vector3(sx * 0.1, 0.98, cz - 0.4 + i * 0.16), Vector3.ZERO, _mat_pipa, 10)
	_box(v, Vector3(0.2, 0.05, 0.9), Vector3(0, 0.98, cz), _mat_karbon)
	var kaca := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 0.5
	cm.height = 0.008
	cm.radial_segments = 6
	cm.rings = 1
	kaca.mesh = cm
	kaca.material_override = _mat_kacahex
	kaca.position = Vector3(0, 1.08, cz)
	kaca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(kaca)


func _buat_roda() -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_buat_satu_roda(Vector3(sx * (0.93 if sz > 0.0 else 0.90), 0.5, sz * 1.35))


func _buat_satu_roda(pos: Vector3) -> void:
	var w := VehicleWheel3D.new()
	w.position = pos
	w.wheel_radius = 0.40
	w.wheel_rest_length = 0.15
	w.suspension_travel = 0.25
	w.suspension_stiffness = 70.0
	w.suspension_max_force = 9000.0
	w.damping_compression = 0.5
	w.damping_relaxation = 0.6
	w.wheel_friction_slip = GRIP_DEPAN
	w.wheel_roll_influence = 0.05
	w.use_as_traction = true
	w.use_as_steering = pos.z < 0.0
	add_child(w)
	# model roda: silinder diputar 90 derajat supaya sumbunya sejajar sumbu X
	var hub := Node3D.new()
	_hub_list.append(hub)
	hub.rotation_degrees = Vector3(0, 0, 90)
	w.add_child(hub)
	var wt := 0.34 if pos.z > 0.0 else 0.28
	var hw := wt * 0.5 + 0.008
	_silinder(hub, 0.40, wt, Vector3.ZERO, Vector3.ZERO, _mat_ban, 48)          # ban
	_silinder(hub, 0.245, 0.2, Vector3.ZERO, Vector3.ZERO, _mat_cakram, 40)       # cakram rem
	# velg 10 jari perak di kedua sisi, melebar di dekat tepi
	for i in 10:
		var piv := Node3D.new()
		piv.rotation_degrees = Vector3(0, i * 36.0, 0)
		hub.add_child(piv)
		for sy in [-hw, hw]:
			_box(piv, Vector3(0.24, 0.03, 0.04), Vector3(0.155, sy, 0), _mat_velg)
	# bibir velg krom
	for sy in [-(hw + 0.002), hw + 0.002]:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.27
		tm.outer_radius = 0.31
		tm.rings = 40
		tm.ring_segments = 8
		var ring := MeshInstance3D.new()
		ring.mesh = tm
		ring.material_override = _mat_neon
		ring.position = Vector3(0, sy, 0)
		hub.add_child(ring)
	_silinder(hub, 0.055, 0.3, Vector3.ZERO, Vector3.ZERO, _mat_tutup, 12)       # tutup tengah emas
	if profil.has("velg_glow"):
		var gc: Color = profil["velg_glow"]
		var gm := StandardMaterial3D.new()
		gm.albedo_color = gc
		gm.emission_enabled = true
		gm.emission = gc
		gm.emission_energy_multiplier = 1.5
		for sy in [-(hw + 0.006), hw + 0.006]:
			var gt := TorusMesh.new()
			gt.inner_radius = 0.37
			gt.outer_radius = 0.40
			gt.rings = 48
			gt.ring_segments = 6
			var gr := MeshInstance3D.new()
			gr.mesh = gt
			gr.material_override = gm
			gr.position = Vector3(0, sy, 0)
			gr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hub.add_child(gr)
	_box(hub, Vector3(0.14, 0.012, 0.2), Vector3(0.17, signf(pos.x) * (hw - 0.002), 0.0), _mat_kaliper)
	_wheels.append(w)


func _buat_lampu() -> void:
	for sx in [-1.0, 1.0]:
		var s := SpotLight3D.new()
		s.position = Vector3(sx * 0.62, 0.5, -2.3)
		s.rotation_degrees = Vector3(-3, 0, 0)
		s.spot_range = 45.0
		s.spot_angle = 30.0
		s.light_energy = 4.0
		s.light_color = Color(1.0, 0.95, 0.85)
		_visual.add_child(s)
	_lampu_rem = OmniLight3D.new()
	_lampu_rem.position = Vector3(0, 0.6, 2.8)
	_lampu_rem.omni_range = 5.0
	_lampu_rem.light_energy = 0.4
	_lampu_rem.light_color = Color(1.0, 0.05, 0.05)
	_visual.add_child(_lampu_rem)


# =====================================================================
#  EFEK: asap drift, skid mark
# =====================================================================
func _partikel(jumlah: int, umur: float, ukuran: float, ramp: Gradient, tambah: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = jumlah
	p.lifetime = umur
	p.emitting = false
	p.local_coords = false
	var sm := SphereMesh.new()
	sm.radius = ukuran
	sm.height = ukuran * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	if tambah:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.material = m
	p.mesh = sm
	p.color_ramp = ramp
	return p


func _buat_efek() -> void:
	var g_asap := Gradient.new()
	g_asap.offsets = PackedFloat32Array([0.0, 1.0])
	g_asap.colors = PackedColorArray([Color(0.85, 0.85, 0.9, 0.55), Color(0.6, 0.6, 0.65, 0.0)])
	var c_asap := Curve.new()
	c_asap.add_point(Vector2(0.0, 0.5))
	c_asap.add_point(Vector2(1.0, 2.2))
	for sx in [-1.0, 1.0]:
		var p := _partikel(36, 0.9, 0.18, g_asap, false)
		p.position = Vector3(sx * 0.95, 0.15, 1.35)
		p.direction = Vector3(0, 1, 0.5)
		p.spread = 25.0
		p.initial_velocity_min = 1.0
		p.initial_velocity_max = 2.5
		p.gravity = Vector3(0, 0.8, 0)
		p.scale_amount_curve = c_asap
		_visual.add_child(p)
		_asap.append(p)

	# percikan api NOS
	var g_pc := Gradient.new()
	g_pc.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g_pc.colors = PackedColorArray([Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.45, 0.08, 0.9), Color(1.0, 0.2, 0.0, 0.0)])
	var c_pc := Curve.new()
	c_pc.add_point(Vector2(0.0, 1.0))
	c_pc.add_point(Vector2(1.0, 0.2))
	for sx in [-1.0, 1.0]:
		var f := _partikel(50, 0.55, 0.035, g_pc, true)
		f.position = Vector3(sx * 0.22, 0.48, EXH_Z + 0.2)
		f.direction = Vector3(0, 0.05, 1)
		f.spread = 14.0
		f.initial_velocity_min = 6.0
		f.initial_velocity_max = 13.0
		f.gravity = Vector3(0, -3.0, 0)
		f.scale_amount_curve = c_pc
		_visual.add_child(f)
		_percikan.append(f)

	# skid mark: satu MultiMesh (1 draw call)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.3, 0.8)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.0, 0.0, 0.0, 0.5)
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.material = sm
	mm.mesh = pm
	mm.instance_count = SKID_MAKS
	mm.custom_aabb = AABB(Vector3(-400, -5, -400), Vector3(800, 10, 800))
	var sembunyi := Transform3D(Basis.from_scale(Vector3(0.001, 0.001, 0.001)), Vector3(0, -50, 0))
	for i in SKID_MAKS:
		mm.set_instance_transform(i, sembunyi)
	_skid_mm = MultiMeshInstance3D.new()
	_skid_mm.multimesh = mm
	_skid_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_skid_mm)
	_skid_mm.top_level = true
	_skid_mm.global_transform = Transform3D.IDENTITY


# =====================================================================
#  NOS: api kerucut berlapis (inti + luar) dengan diamond shock
# =====================================================================
func _buat_nos() -> void:
	var sh := Shader.new()
	sh.code = SHADER_API
	for sx in [-1.0, 1.0]:
		for lapis in 2:
			var mat := ShaderMaterial.new()
			mat.shader = sh
			var inti := 1.0 if lapis == 1 else 0.0
			var panjang := 1.5 if lapis == 1 else 2.4
			var radius := 0.07 if lapis == 1 else 0.17
			mat.set_shader_parameter("core", inti)
			mat.set_shader_parameter("len", panjang)
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = radius
			cm.height = panjang
			cm.radial_segments = 16
			cm.rings = 1
			cm.cap_top = false
			cm.cap_bottom = false
			var mi := MeshInstance3D.new()
			mi.mesh = cm
			mi.material_override = mat
			mi.rotation_degrees = Vector3(90, 0, 0)
			mi.position = Vector3(sx * 0.22, 0.48, EXH_Z + panjang * 0.5)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			_visual.add_child(mi)
			_api_kerucut.append({"mi": mi, "mat": mat, "len": panjang, "z0": EXH_Z})
	_nos_light = OmniLight3D.new()
	_nos_light.position = Vector3(0, 0.6, 3.7)
	_nos_light.omni_range = 9.0
	_nos_light.light_color = Color(1.0, 0.5, 0.15)
	_nos_light.light_energy = 0.0
	_visual.add_child(_nos_light)


func _update_nos(delta: float, boost: bool) -> void:
	_nos_p = move_toward(_nos_p, 1.0 if boost else 0.0, delta * (7.0 if boost else 5.0))
	_flash = maxf(_flash - delta * 3.0, 0.0)
	_pop = maxf(_pop - delta * 5.0, 0.0)
	var np := maxf(_nos_p, _pop * 0.4)
	var vis := np > 0.01
	var fl := 0.92 + 0.08 * sin(_t_anim * 55.0)
	var l := (0.3 + 0.7 * np) * (1.0 + _flash * 0.6) * fl
	var w := (0.5 + 0.5 * np) * (1.0 + _flash * 0.5)
	for d in _api_kerucut:
		var mi: MeshInstance3D = d["mi"]
		mi.visible = vis
		mi.scale = Vector3(w, l, w)
		mi.position.z = float(d["z0"]) + float(d["len"]) * l * 0.5
		d["mat"].set_shader_parameter("power", np * (1.0 + _flash))
	_nos_light.light_energy = np * (3.0 + _flash * 6.0)
	for pc in _percikan:
		pc.emitting = boost


func _skid(delta: float) -> void:
	_skid_timer -= delta
	if _skid_timer > 0.0:
		return
	_skid_timer = 0.04
	var d := linear_velocity
	d.y = 0.0
	if d.length() < 1.0:
		return
	var bas := Basis.looking_at(d.normalized(), Vector3.UP)
	for w in _wheels:
		if w.position.z * fz < 0.0 and w.is_in_contact():
			var p := w.global_position
			_skid_mm.multimesh.set_instance_transform(_skid_i, Transform3D(bas, Vector3(p.x, p.y - 0.36, p.z)))
			_skid_i = (_skid_i + 1) % SKID_MAKS


# =====================================================================
#  MODEL 3D ASLI (.glb) - otomatis diskalakan, dipusatkan, dan ditaruh di tanah
# =====================================================================
func _kumpul_aabb(n: Node, xf: Transform3D, hasil: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var a: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		hasil.append(a)
	for c in n.get_children():
		_kumpul_aabb(c, t, hasil)


func _pasang_model() -> void:
	if not ResourceLoader.exists(MODEL_PATH):
		return
	var res = load(MODEL_PATH)
	if not (res is PackedScene):
		return
	var model := (res as PackedScene).instantiate() as Node3D
	if model == null:
		return
	var hasil: Array = []
	_kumpul_aabb(model, Transform3D.IDENTITY, hasil)
	if hasil.is_empty():
		model.queue_free()
		return
	var total: AABB = hasil[0]
	for a in hasil:
		total = total.merge(a)
	var panjang := maxf(total.size.x, total.size.z)
	var skala := MODEL_PANJANG / maxf(panjang, 0.001)
	var yaw := (90.0 if total.size.x > total.size.z else 0.0) + MODEL_YAW
	var bas := Basis(Vector3.UP, deg_to_rad(yaw)) * Basis.from_scale(Vector3.ONE * skala)
	var c := total.position + total.size * 0.5
	var titik_bawah := Vector3(c.x, total.position.y, c.z)
	model.transform = Transform3D(bas, -(bas * titik_bawah) + Vector3(0, -0.03 + MODEL_Y_OFFSET, 0))
	_visual.add_child(model)
	# sembunyikan bodi & velg buatan kode, pakai model asli
	_body_proc.visible = false
	for h in _hub_list:
		h.visible = false


# =====================================================================
#  WARNA
# =====================================================================



func _set_palet(i: int) -> void:
	_palet_i = i
	var p: Dictionary = PALET[i]
	var cb: Color = profil.get("body", p["body"])
	var cs: Color = profil.get("stripe", p["stripe"])
	_mat_bodi.set_shader_parameter("paint", cb)
	_mat_bodi.set_shader_parameter("stripe", cs)
	_mat_bodi.set_shader_parameter("ev", 1.0 if ev else 0.0)
	_mat_bodi.set_shader_parameter("paint2", profil.get("paint2", cb))
	_mat_bodi.set_shader_parameter("iri", float(profil.get("iri", 0.0)))
	_mat_body.albedo_color = cb


# =====================================================================
#  ARAH, RESET, KALIBRASI
# =====================================================================
func get_forward() -> Vector3:
	return global_transform.basis.z * fz


func terbalik() -> bool:
	return global_transform.basis.y.y < 0.3


func _basis_menghadap(f: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(f.x * fz, f.z * fz))


func reset_car(xf: Transform3D) -> void:
	var rid := get_rid()
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)


func ke_garis_start() -> void:
	reset_car(Transform3D(_basis_menghadap(spawn_dir), spawn_pos))


func tegakkan() -> void:
	var f := get_forward()
	f.y = 0.0
	if f.length() < 0.1:
		f = Vector3(0, 0, -1)
	reset_car(Transform3D(_basis_menghadap(f.normalized()), global_position + Vector3(0, 1.2, 0)))


func _terapkan_arah() -> void:
	_yaw0 = 0.0 if fz < 0.0 else PI
	for i in _wheels.size():
		var w := _wheels[i]
		var depan := (w.position.z * fz) > 0.0
		w.use_as_steering = depan
		if i < _hub_list.size():
			_hub_list[i].scale = Vector3(1.06, 1.0 if depan else 1.35, 1.06)


func _kalibrasi(delta: float, lv: Vector3) -> void:
	_t += delta
	if _fase == 0 and _t > 1.0:
		_fase = 1
		_t = 0.0
		engine_force = 900.0
	elif _fase == 1 and _t > 0.7:
		fz = 1.0 if lv.z > 0.3 else -1.0
		engine_force = 0.0
		brake = 0.0
		_terapkan_arah()
		ke_garis_start()
		_fase = 2
		siap.emit()


# =====================================================================
#  LOOP FISIKA + ANIMASI
# =====================================================================
func _update_rpm(delta: float, v_kmh: float) -> void:
	# kotak gigi 7 percepatan: naik gigi mendekati redline, turun saat putaran rendah
	var gmax: float = GIGI_KMH[gigi - 1]
	var rpm_kecepatan := v_kmh / gmax * REDLINE
	if _shift_t > 0.0:
		_shift_t -= delta
	elif rpm_kecepatan > REDLINE * 0.96 and gigi < 7:
		gigi += 1
		_shift_t = 0.15
		_pop = 1.0
		gmax = GIGI_KMH[gigi - 1]
		rpm_kecepatan = v_kmh / gmax * REDLINE
	elif rpm_kecepatan < 4200.0 and gigi > 1:
		gigi -= 1
		gmax = GIGI_KMH[gigi - 1]
		rpm_kecepatan = v_kmh / gmax * REDLINE
	var target := maxf(IDLE, rpm_kecepatan)
	if _gas_s > 0.05 and rpm_kecepatan < 5000.0:
		target = maxf(target, IDLE + _gas_s * 4200.0)
	var laju := 9000.0 if target > rpm else 6000.0
	rpm = minf(move_toward(rpm, target, delta * laju), REDLINE)


func _buat_audio() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.1
	_audio = AudioStreamPlayer.new()
	_audio.stream = gen
	_audio.volume_db = -4.0
	add_child(_audio)
	_audio.play()
	_pb = _audio.get_stream_playback() as AudioStreamGeneratorPlayback


func _bangun_tabel() -> void:
	# satu siklus gelombang V12 dihitung sekali; saat bermain cukup dibaca (murah untuk HP)
	_tab_lo.resize(TAB_N)
	_tab_hi.resize(TAB_N)
	var h_lo := {1: 0.55, 2: 0.30, 3: 0.35, 6: 0.50, 9: 0.18, 12: 0.12}
	var h_hi := {1: 0.20, 2: 0.18, 3: 0.30, 6: 0.60, 9: 0.40, 12: 0.45, 18: 0.30, 24: 0.16}
	for i in TAB_N:
		var a := float(i) / TAB_N * TAU
		var lo := 0.0
		var hi := 0.0
		for k in h_lo:
			lo += h_lo[k] * sin(k * a + k * 0.7)
		for k in h_hi:
			hi += h_hi[k] * sin(k * a + k * 0.7)
		_tab_lo[i] = tanh(lo * 1.1)
		_tab_hi[i] = tanh(hi * 1.9)


func _baca_tabel(t: PackedFloat32Array, ph: float) -> float:
	var x := ph * TAB_N
	var i := int(x)
	var fr := x - i
	return lerpf(t[i % TAB_N], t[(i + 1) % TAB_N], fr)


func _isi_audio() -> void:
	# suara V12: tabel gelombang (berat -> garing sesuai beban) + filter yang membuka seiring rpm
	# + desis intake, batas rpm bergetar, letupan knalpot saat gas dilepas, siulan nitro
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	if n < 1:
		return
	if ev:
		_isi_audio_ev(n)
		return
	if _tab_lo.is_empty():
		_bangun_tabel()
	var buf := PackedVector2Array()
	buf.resize(n)
	var beban := clampf(_gas_s, 0.0, 1.0)
	var rr := clampf((rpm - IDLE) / (REDLINE - IDLE), 0.0, 1.0)
	var f := rpm / 60.0 / float(MIX_RATE)
	var vol := 0.34 + 0.22 * beban + 0.10 * _nos_p
	if _shift_t > 0.0:
		vol *= 0.35               # tenaga terputus sesaat saat pindah gigi
	var batas := 1.0 if rpm < REDLINE - 200.0 else 0.0
	var alfa := clampf((500.0 + rr * 3800.0 + beban * 2200.0) * TAU / float(MIX_RATE), 0.03, 0.9)
	var desis := 0.015 + 0.05 * beban * rr
	var pop := _pop
	var ph := _ph
	for i in n:
		ph += f * (1.0 + (randf() - 0.5) * 0.004)      # getaran halus agar tidak terdengar mesin sintetis
		if ph >= 1.0:
			ph -= 1.0
		var s := lerpf(_baca_tabel(_tab_lo, ph), _baca_tabel(_tab_hi, ph), beban * 0.8 + rr * 0.2)
		var nz := randf() * 2.0 - 1.0
		s += nz * desis
		if pop > 0.05 and randf() < 0.012:
			_pop_amp = 1.0                               # letupan acak
		_pop_amp *= 0.9985
		s += nz * _pop_amp * pop * 0.8
		_lp += (s - _lp) * alfa
		_lp2 += (_lp - _lp2) * alfa
		var out := _lp2
		if batas < 0.5:
			out *= 0.6 + 0.4 * sin(_t_anim * 110.0 + float(i) * 0.002)   # limiter berkedip
		if _nos_p > 0.05:
			_ph_whine += (2600.0 + 900.0 * _nos_p) / float(MIX_RATE)
			if _ph_whine >= 1.0:
				_ph_whine -= 1.0
			out += sin(_ph_whine * TAU) * 0.05 * _nos_p
		out = tanh(out * 1.3) * vol
		buf[i] = Vector2(out, out)
	_ph = ph
	_pb.push_buffer(buf)


func _process(_delta: float) -> void:
	_isi_audio()


func _physics_process(delta: float) -> void:
	if hantu:
		_anim_hantu(delta)
		return
	var lv := global_transform.basis.inverse() * linear_velocity
	kmh = linear_velocity.length() * 3.6
	if _fase < 2:
		_kalibrasi(delta, lv)
		return

	var fwd := lv.z * fz
	var speed := linear_velocity.length()
	var sr := clampf(speed / (KECEPATAN_MAKS * _vm), 0.0, 1.0)
	_gas_s = lerpf(_gas_s, gas, 1.0 - exp(-8.0 * delta))
	var di_tanah := false
	for w in _wheels:
		if w.is_in_contact():
			di_tanah = true

	# --- setir (makin kecil saat ngebut) ---
	var maks := lerpf(STIR_MAKS, STIR_MIN, clampf(speed / 70.0, 0.0, 1.0))
	var laju := 3.2 if absf(stir_in) > 0.01 else 6.0
	steering = move_toward(steering, stir_in * maks, delta * laju)

	# --- nitro ---
	var boost := nitro_on and nitro_isi > 0.02
	boost_aktif = boost
	if boost and not _boost_prev:
		_flash = 1.0
		nitro_mulai.emit()
	_boost_prev = boost
	if boost:
		nitro_isi = maxf(nitro_isi - delta * 0.3, 0.0)
	else:
		nitro_isi = minf(nitro_isi + delta * 0.07, 1.0)

	# --- mesin & rem ---
	var gaya := 0.0
	var rem_val := 0.0
	var mengerem := false
	var drift := rem_in > 0.05 and fwd > 12.0 and absf(stir_in) > 0.15
	if boost or gas > 0.05:
		var pengali := PENGALI_NITRO if boost else 1.0
		var rasio := clampf(fwd / (KECEPATAN_MAKS * _vm * (1.2 if boost else 1.0)), 0.0, 1.0)
		var batas := 1.0 - rasio * rasio
		gaya = GAYA_MESIN * _daya * pengali * batas * (1.0 if boost else gas)
	if rem_in > 0.05:
		if drift:
			rem_val = GAYA_REM * 0.15
			mengerem = true
		elif fwd > 1.5:
			rem_val = GAYA_REM * rem_in
			gaya = 0.0
			mengerem = true
		elif not (boost or gas > 0.05):
			gaya = -GAYA_MESIN * _daya * 0.55 * (1.0 if fwd > -14.0 else 0.0)
	elif gas < 0.05 and not boost and fwd > 0.5:
		rem_val = 0.5
	if ev:
		gigi = 1
		rpm = lerpf(rpm, minf(IDLE + absf(fwd) * 3.6 * 22.0 + _gas_s * 600.0, 8000.0), 1.0 - exp(-6.0 * delta))
	else:
		_update_rpm(delta, absf(fwd) * 3.6)
	if _shift_t > 0.0:
		gaya *= 0.3
	if parkir and not terbang_on:
		gaya = 0.0
		rem_val = GAYA_REM
		mengerem = false
	if terbang_on:
		_fisika_terbang(delta, boost)
		gaya = 0.0
		rem_val = 0.0
		mengerem = false
		drift = false
	engine_force = gaya
	brake = rem_val

	# --- grip roda belakang (drift) ---
	var grip_t := GRIP_DRIFT if drift else GRIP_BELAKANG
	_grip = lerpf(_grip, grip_t, 1.0 - exp(-10.0 * delta))
	for w in _wheels:
		w.wheel_friction_slip = _grip if (w.position.z * fz < 0.0) else GRIP_DEPAN

	if not terbang_on:
		apply_central_force(-global_transform.basis.y * speed * speed * 0.45)

	# --- animasi bodi: roll saat menikung, pitch saat gas/rem, squat saat nitro ---
	var acc := (fwd - _fwd_prev) / maxf(delta, 0.0001)
	_fwd_prev = fwd
	_acc_s = lerpf(_acc_s, acc, 1.0 - exp(-6.0 * delta))
	var lat_acc := angular_velocity.y * fwd
	var roll_t := clampf(-lat_acc * 0.012, -0.13, 0.13)
	var pitch_t := clampf(_acc_s * 0.006, -0.07, 0.07) + _nos_p * 0.025
	if terbang_on:
		roll_t = clampf(-stir_in * 0.32, -0.35, 0.35)
		pitch_t = clampf(-linear_velocity.y * 0.012, -0.3, 0.3) - gas * 0.05
	_update_thruster(delta)
	var k := 1.0 - exp(-8.0 * delta)
	_roll = lerpf(_roll, roll_t, k)
	_pitch = lerpf(_pitch, pitch_t, k)
	_t_anim += delta
	_visual.rotation = Vector3(_pitch, _yaw0, _roll)
	var getar := 0.4 + gas * 0.6 + _nos_p * 1.2
	if not di_tanah:
		_udara_t += delta
	else:
		if _udara_t > 0.35:
			_land = clampf(_udara_t * 0.8, 0.3, 1.0)
		_udara_t = 0.0
	_land = maxf(_land - delta * 2.2, 0.0)
	var pantul := sin((1.0 - _land) * 14.0) * _land * 0.05
	_visual.position.y = sin(_t_anim * 75.0) * 0.004 * getar * (1.0 - sr * 0.7) - sr * 0.025 - _land * 0.07 + pantul
	_visual.rotation.x += _land * 0.03 * sin(_t_anim * 18.0)
	if _gas_prev > 0.6 and gas < 0.2 and kmh > 110.0:
		_pop = 0.9
	_gas_prev = gas
	var panas := 1.0 if (mengerem and kmh > 80.0) else 0.0
	_mat_cakram.emission_enabled = true
	_mat_cakram.emission = Color(1.0, 0.25, 0.03)
	_mat_cakram.emission_energy_multiplier = lerpf(_mat_cakram.emission_energy_multiplier, panas * 2.2, 1.0 - exp(-5.0 * delta))

	# --- spoiler aktif ---
	var naik := clampf((kmh - 100.0) / 60.0, 0.0, 1.0)
	_sayap.position.y = 1.0 + 0.14 * naik
	var sudut := 0.55 if (mengerem and kmh > 60.0) else -0.12 * naik
	_sayap.rotation.x = lerpf(_sayap.rotation.x, sudut, 1.0 - exp(-10.0 * delta))

	# --- lampu ---
	_rem_glow = lerpf(_rem_glow, 9.0 if mengerem else 1.6, 1.0 - exp(-20.0 * delta))
	_mat_bodi.set_shader_parameter("rem_glow", _rem_glow)
	_lampu_rem.light_energy = 3.0 if mengerem else 0.4

	# --- efek ---
	var slip := absf(lv.x)
	var drifting := di_tanah and slip > 3.0 and speed > 6.0
	var burnout := di_tanah and gas > 0.9 and speed < 9.0
	for sm in _asap:
		sm.emitting = drifting or burnout
	_update_nos(delta, boost)
	if drifting:
		_skid(delta)


# =====================================================================
#  MOBIL LISTRIK: SUARA, TERBANG, THRUSTER
# =====================================================================
func _isi_audio_ev(n: int) -> void:
	# dengung motor listrik: nada naik sesuai kecepatan + desis angin
	var buf := PackedVector2Array()
	buf.resize(n)
	var nada := 180.0 + kmh * 7.0 + _gas_s * 120.0 + _thr_p * 140.0
	var f := nada / float(MIX_RATE)
	var vol := 0.10 + 0.12 * _gas_s + 0.10 * _thr_p + 0.08 * _nos_p
	for i in n:
		_ph += f
		if _ph > 1.0:
			_ph -= 1.0
		var a := _ph * TAU
		var smp := 0.6 * sin(a) + 0.25 * sin(2.0 * a + 0.5) + 0.12 * sin(3.0 * a)
		smp += (randf() * 2.0 - 1.0) * (0.03 + 0.10 * _thr_p)
		buf[i] = Vector2(smp * vol, smp * vol)
	_pb.push_buffer(buf)


func _buat_thruster() -> void:
	if not terbang_mampu:
		return
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, blend_add, cull_disabled, depth_draw_never;\nuniform float power = 0.0;\nvoid fragment() {\n\tfloat r = length(UV - vec2(0.5)) * 2.0;\n\tfloat core = smoothstep(1.0, 0.0, r);\n\tfloat ring = smoothstep(0.55, 0.75, r) * smoothstep(1.0, 0.8, r);\n\tvec3 c = mix(vec3(0.2, 0.55, 1.0), vec3(0.9, 0.97, 1.0), core * core);\n\tALBEDO = c * (core * 1.6 + ring * 1.2) * (0.7 + 0.3 * sin(TIME * 60.0));\n\tALPHA = clamp((core + ring) * power, 0.0, 1.0);\n}\n"
	m.shader = sh
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(0.9, 0.9)
			mi.mesh = pm
			mi.material_override = m.duplicate()
			mi.position = Vector3(sx * 0.82, 0.22, sz * 1.35)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			_visual.add_child(mi)
			_thruster.append(mi)
	# pod thruster logam di dalam sumur roda (tampil saat terbang)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.78, 0.8, 0.86)
	pmat.metallic = 0.85
	pmat.roughness = 0.25
	var emat := StandardMaterial3D.new()
	emat.albedo_color = Color(0.4, 0.7, 1.0)
	emat.emission_enabled = true
	emat.emission = Color(0.35, 0.65, 1.0)
	emat.emission_energy_multiplier = 2.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pod := Node3D.new()
			pod.position = Vector3(sx * 0.86, 0.36, sz * 1.35)
			pod.rotation_degrees = Vector3(0, 0, 90)
			pod.visible = false
			_visual.add_child(pod)
			_pods.append(pod)
			var cy := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.30
			cm.bottom_radius = 0.24
			cm.height = 0.30
			cm.radial_segments = 32
			cy.mesh = cm
			cy.material_override = pmat
			pod.add_child(cy)
			var rg := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.17
			tm.outer_radius = 0.21
			tm.rings = 32
			tm.ring_segments = 6
			rg.mesh = tm
			rg.material_override = emat
			rg.position = Vector3(0, -sx * 0.155, 0)
			pod.add_child(rg)
	_thr_light = OmniLight3D.new()
	_thr_light.position = Vector3(0, 0.1, 0)
	_thr_light.omni_range = 7.0
	_thr_light.light_color = Color(0.35, 0.65, 1.0)
	_thr_light.light_energy = 0.0
	_visual.add_child(_thr_light)


func _update_thruster(delta: float) -> void:
	_thr_p = move_toward(_thr_p, 1.0 if terbang_on else 0.0, delta * 3.0)
	for mi in _thruster:
		mi.visible = _thr_p > 0.02
		(mi.material_override as ShaderMaterial).set_shader_parameter("power", _thr_p)
	if _thr_light:
		_thr_light.light_energy = _thr_p * 3.5
	for h in _hub_list:
		h.visible = _thr_p < 0.5 and _body_proc.visible
	for pd in _pods:
		pd.visible = _thr_p >= 0.5 and _body_proc.visible


func toggle_terbang() -> void:
	if not terbang_mampu or _fase < 2:
		return
	if terbang_on:
		_mendarat()
	else:
		_lepas_landas()


func _lepas_landas() -> void:
	var f := get_forward()
	f.y = 0.0
	if f.length() < 0.1:
		return
	f = f.normalized()
	var v := linear_velocity
	reset_car(Transform3D(_basis_menghadap(f), global_position + Vector3(0, 0.25, 0)))
	linear_velocity = v
	gravity_scale = 0.0
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	terbang_on = true


func _mendarat() -> void:
	terbang_on = false
	gravity_scale = 1.0
	axis_lock_angular_x = false
	axis_lock_angular_z = false
	naik_in = 0.0


func _fisika_terbang(delta: float, boost: bool) -> void:
	var f := get_forward()
	f.y = 0.0
	if f.length() < 0.05:
		return
	f = f.normalized()
	var kanan := f.cross(Vector3.UP)
	var v := linear_velocity
	var vf := v.dot(f)
	var vr := v.dot(kanan)
	var vmax := 95.0 * _vm * (1.35 if boost else 1.0)
	var acc := 30.0 * gas * (1.5 if boost else 1.0) * clampf(1.0 - vf / vmax, 0.0, 1.0)
	if rem_in > 0.05:
		acc -= 38.0 * minf(1.0, absf(vf) / 6.0) * signf(vf)
	apply_central_force(f * acc * mass)
	apply_central_force(-kanan * vr * mass * 2.5)
	apply_central_force(-f * vf * mass * 0.10)
	var tinggi := global_position.y
	var vy_t := naik_in * 16.0
	if tinggi > 160.0 and vy_t > 0.0:
		vy_t = 0.0
	apply_central_force(Vector3(0.0, (vy_t - v.y) * mass * 3.0, 0.0))
	var yaw_t := stir_in * (1.4 - clampf(vf / vmax, 0.0, 1.0) * 0.7)
	angular_velocity.y = lerpf(angular_velocity.y, yaw_t, 1.0 - exp(-6.0 * delta))
	angular_velocity.x = 0.0
	angular_velocity.z = 0.0
	# mendarat otomatis saat turun sampai dekat tanah
	if tinggi < 1.15 and naik_in <= 0.0 and v.y <= 0.5 and gas < 0.05:
		_mendarat()


func _anim_hantu(delta: float) -> void:
	_t_anim += delta
	var sr := clampf(kmh / 300.0, 0.0, 1.0)
	_update_thruster(delta)
	_visual.position.y = sin(_t_anim * 75.0) * 0.003 * sr
	if _sayap and _sayap.visible:
		_sayap.position.y = 1.0 + 0.14 * clampf((kmh - 100.0) / 60.0, 0.0, 1.0)
	for w in _wheels:
		if _thr_p < 0.5:
			w.rotate_x(-kmh / 3.6 / 0.4 * delta * fz)


func atur_hantu(xf: Transform3D, kec_kmh: float, terbang: bool) -> void:
	global_transform = xf
	kmh = kec_kmh
	terbang_on = terbang
