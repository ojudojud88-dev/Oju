extends Node
## Autoload "Gm": data pemain (koin, mobil terbeli), katalog toko, dan pengaturan mode permainan.

const SAVE_PATH := "user://turbo_drift.cfg"
const PUTARAN := 3
const KOIN_AWAL := 3000

# Katalog mobil. "profil" dikirim ke car.gd.
const MOBIL := {
	"giallo": {
		"nama": "Lamborghini Aventador LP 700-4",
		"warna": "Giallo (kuning)",
		"harga": 0,
		"daya": 1.0, "vmaks": 1.0,
		"body": Color(0.98, 0.72, 0.0), "stripe": Color(0.02, 0.02, 0.025),
		"interior": Color(0.03, 0.03, 0.035), "aksen": Color(0.95, 0.70, 0.05),
		"bodi": "lambo", "ev": false, "terbang": false,
		"info": "V12 6.5L • 740 hp • 7 percepatan • AWD",
	},
	"rosso": {
		"nama": "Aventador SV Rosso",
		"warna": "Rosso Mars (merah)",
		"harga": 2500,
		"daya": 1.15, "vmaks": 1.04,
		"body": Color(0.80, 0.02, 0.03), "stripe": Color(0.03, 0.03, 0.035),
		"interior": Color(0.07, 0.03, 0.03), "aksen": Color(0.9, 0.1, 0.1),
		"bodi": "lambo", "ev": false, "terbang": false,
		"info": "Tenaga +15% • kecepatan maks +4%",
	},
	"nero": {
		"nama": "Aventador Nero Performante",
		"warna": "Nero Noctis (hitam)",
		"harga": 6000,
		"daya": 1.3, "vmaks": 1.08,
		"body": Color(0.04, 0.04, 0.05), "stripe": Color(0.85, 0.62, 0.05),
		"interior": Color(0.03, 0.03, 0.04), "aksen": Color(0.85, 0.62, 0.05),
		"bodi": "lambo", "ev": false, "terbang": false,
		"info": "Tenaga +30% • kecepatan maks +8%",
	},
	"viola": {
		"nama": "Hyper Viola GT",
		"warna": "Ungu kameleon",
		"harga": 9000,
		"daya": 1.35, "vmaks": 1.09,
		"body": Color(0.42, 0.08, 0.78), "stripe": Color(0.03, 0.03, 0.04),
		"paint2": Color(0.95, 0.35, 0.80), "iri": 0.5, "sudut": 3.2,
		"velg_glow": Color(0.75, 0.35, 1.0), "velg_warna": Color(0.06, 0.06, 0.07),
		"sayap_gt": true, "underglow": Color(0.65, 0.3, 1.0),
		"interior": Color(0.05, 0.03, 0.08), "aksen": Color(0.75, 0.35, 1.0),
		"bodi": "lambo", "ev": false, "terbang": false,
		"info": "Hypercar sayap GT • tenaga +35% • velg menyala",
	},
	"verde": {
		"nama": "Aero Verde Chrome",
		"warna": "Hijau krom kameleon",
		"harga": 15000,
		"daya": 1.4, "vmaks": 1.1,
		"body": Color(0.06, 0.58, 0.36), "stripe": Color(0.02, 0.02, 0.03),
		"paint2": Color(0.55, 0.22, 0.95), "iri": 0.55, "sudut": 3.0,
		"velg_glow": Color(0.45, 0.25, 1.0), "velg_warna": Color(0.05, 0.05, 0.06),
		"sayap_gt": false, "underglow": Color(0.35, 0.2, 0.95),
		"interior": Color(0.03, 0.05, 0.05), "aksen": Color(0.4, 0.95, 0.7),
		"bodi": "lambo", "ev": false, "terbang": false,
		"info": "Cat krom berubah warna • tenaga +40% • velg neon ungu",
	},
	"gt_biru": {
		"nama": "Stallion GT Biru",
		"warna": "Biru metalik, garis putih",
		"harga": 7000,
		"daya": 1.30, "vmaks": 1.07,
		"body": Color(0.07, 0.30, 0.82), "stripe": Color(0.95, 0.96, 0.98),
		"sudut": 3.0, "velg_warna": Color(0.07, 0.07, 0.08),
		"interior": Color(0.03, 0.03, 0.04), "aksen": Color(0.2, 0.5, 1.0),
		"bodi": "lambo", "ev": false, "terbang": false,
		"info": "Muscle GT bergaris balap • tenaga +30% • interior kulit hitam",
	},
	"gt_putih": {
		"nama": "Heritage GT Putih",
		"warna": "Putih mutiara, garis oranye",
		"harga": 11000,
		"daya": 1.33, "vmaks": 1.09,
		"body": Color(0.80, 0.80, 0.84), "stripe": Color(1.0, 0.36, 0.03),
		"sudut": 3.0, "velg_warna": Color(0.35, 0.36, 0.40),
		"interior": Color(0.20, 0.15, 0.11), "aksen": Color(1.0, 0.45, 0.08),
		"bodi": "lambo", "ev": false, "terbang": false,
		"info": "Supercar garis oranye klasik • tenaga +33% • interior kulit cokelat",
	},
	"merah_c": {
		"nama": "Crimson Roadster",
		"warna": "Merah menyala",
		"harga": 13000,
		"daya": 1.32, "vmaks": 1.10,
		"body": Color(0.80, 0.03, 0.05), "stripe": Color(0.80, 0.03, 0.05),
		"paint2": Color(1.0, 0.25, 0.10), "iri": 0.25,
		"interior": Color(0.30, 0.25, 0.20), "aksen": Color(0.95, 0.95, 0.97),
		"bodi": "roadster", "ev": false, "terbang": false,
		"info": "Roadster mesin tengah • tenaga +32% • kabin krem terbuka",
	},
	"volt": {
		"nama": "Tesla Roadster Terbang",
		"warna": "Putih mutiara",
		"harga": 12000,
		"daya": 1.25, "vmaks": 1.1,
		"body": Color(0.93, 0.94, 0.97), "stripe": Color(0.93, 0.94, 0.97),
		"interior": Color(0.70, 0.71, 0.75), "aksen": Color(0.3, 0.7, 1.0),
		"bodi": "roadster", "ev": true, "terbang": true,
		"info": "Listrik • thruster roket • BISA TERBANG (tombol TERBANG)",
	},
}
const URUTAN := ["giallo", "rosso", "nero", "gt_biru", "viola", "gt_putih", "volt", "merah_c", "verde"]

var koin := KOIN_AWAL
var dimiliki: Array = ["giallo"]
var terpilih := "giallo"
var nama_pemain := "Pembalap"
var alamat_server := "127.0.0.1"
var mode := "solo"          # "solo" atau "online"
var jumlah_lawan := 3


func _ready() -> void:
	muat()
	if "--server" in OS.get_cmdline_user_args():
		return   # server khusus: Net yang mengatur


func profil(id: String) -> Dictionary:
	return MOBIL.get(id, MOBIL["giallo"])


func punya(id: String) -> bool:
	return dimiliki.has(id)


func beli(id: String) -> bool:
	if punya(id) or not MOBIL.has(id):
		return false
	var h: int = MOBIL[id]["harga"]
	if koin < h:
		return false
	koin -= h
	dimiliki.append(id)
	terpilih = id
	simpan()
	return true


func pilih(id: String) -> void:
	if punya(id):
		terpilih = id
		simpan()


func tambah_koin(n: int) -> void:
	koin += n
	simpan()


func hadiah(peringkat: int) -> int:
	match peringkat:
		1: return 1500
		2: return 1000
		3: return 700
	return 400


func muat() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	koin = int(cf.get_value("pemain", "koin", KOIN_AWAL))
	var d = cf.get_value("pemain", "dimiliki", ["giallo"])
	dimiliki = d if d is Array else ["giallo"]
	if not dimiliki.has("giallo"):
		dimiliki.append("giallo")
	terpilih = str(cf.get_value("pemain", "terpilih", "giallo"))
	if not dimiliki.has(terpilih):
		terpilih = "giallo"
	nama_pemain = str(cf.get_value("pemain", "nama", "Pembalap"))
	alamat_server = str(cf.get_value("pemain", "alamat", "127.0.0.1"))


func simpan() -> void:
	var cf := ConfigFile.new()
	cf.set_value("pemain", "koin", koin)
	cf.set_value("pemain", "dimiliki", dimiliki)
	cf.set_value("pemain", "terpilih", terpilih)
	cf.set_value("pemain", "nama", nama_pemain)
	cf.set_value("pemain", "alamat", alamat_server)
	cf.save(SAVE_PATH)
