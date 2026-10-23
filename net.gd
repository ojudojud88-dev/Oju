extends Node
## Autoload "Net": multiplayer online (ENet / UDP, port 7777).
## - Server khusus: godot --headless --path . -- --server [--port=7777]
## - Atau salah satu pemain menjadi host (Buat Ruang) dan teman Gabung lewat alamat IP.
## Fisika dihitung di masing-masing HP; server hanya mengatur ruang tunggu, start serempak, dan meneruskan posisi.

signal daftar_berubah
signal terhubung
signal gagal
signal putus
signal balapan_dimulai
signal go_serempak
signal state_masuk(id: int, data: Dictionary)
signal info_selesai(id: int, nama: String, peringkat: int, waktu: float)
signal pesan(teks: String)

const PORT := 7777
const MAKS := 8

var aktif := false
var dedicated := false
var di_balapan := false
var pemain := {}          # id -> {nama, mobil, siap, muat, prog, selesai}
var slot := 0             # urutan start saya (0..n-1)
var jml_pemain := 1
var rank_saya := 0
var _urutan_selesai: Array = []
var _hitung_mulai := -1.0
var _akhir_t := -1.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		var port := PORT
		for a in args:
			if a.begins_with("--port="):
				port = int(a.substr(7))
		dedicated = true
		var err := host(port)
		print("[SERVER] port %d -> %s" % [port, "OK" if err == OK else "GAGAL (%d)" % err])
		get_tree().change_scene_to_file.call_deferred("res://server.tscn")


func id_saya() -> int:
	if not aktif:
		return 0
	return multiplayer.get_unique_id()


func siap_jaringan() -> bool:
	# true hanya jika benar-benar tersambung (klien yang masih menyambung belum boleh memanggil RPC)
	if not aktif or multiplayer.multiplayer_peer == null:
		return false
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func adalah_server() -> bool:
	return aktif and multiplayer.is_server()


# ---------------------------------------------------------------------
#  SAMBUNGAN
# ---------------------------------------------------------------------
func host(port: int = PORT) -> int:
	tutup()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAKS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_sambung_sinyal()
	aktif = true
	pemain.clear()
	if not dedicated:
		pemain[1] = _baru(Gm.nama_pemain, Gm.terpilih)
		_siar_daftar()
	return OK


func gabung(alamat: String, port: int = PORT) -> int:
	tutup()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(alamat, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_sambung_sinyal()
	aktif = true
	return OK


func tutup() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	aktif = false
	di_balapan = false
	pemain.clear()
	_urutan_selesai.clear()


func _sambung_sinyal() -> void:
	for pair in [
		[multiplayer.peer_connected, _on_peer_masuk],
		[multiplayer.peer_disconnected, _on_peer_keluar],
		[multiplayer.connected_to_server, _on_terhubung],
		[multiplayer.connection_failed, _on_gagal],
		[multiplayer.server_disconnected, _on_putus],
	]:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if not sig.is_connected(cb):
			sig.connect(cb)


func _on_peer_masuk(_id: int) -> void:
	pass


func _on_peer_keluar(id: int) -> void:
	if not multiplayer.is_server():
		return
	pemain.erase(id)
	_siar_daftar()
	_cek_semua_muat()
	_cek_mulai()


func _on_terhubung() -> void:
	r_daftar.rpc_id(1, Gm.nama_pemain.substr(0, 14), Gm.terpilih)
	terhubung.emit()


func _on_gagal() -> void:
	tutup()
	gagal.emit()


func _on_putus() -> void:
	tutup()
	putus.emit()


func _baru(nama: String, mobil: String) -> Dictionary:
	return {"nama": nama.substr(0, 14), "mobil": mobil, "siap": false, "muat": false, "prog": 0.0, "selesai": false}


# ---------------------------------------------------------------------
#  RUANG TUNGGU
# ---------------------------------------------------------------------
@rpc("any_peer", "reliable")
func r_daftar(nama: String, mobil: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not Gm.MOBIL.has(mobil):
		mobil = "giallo"
	pemain[id] = _baru(nama, mobil)
	_siar_daftar()


func _siar_daftar() -> void:
	r_daftar_masuk.rpc(pemain)
	daftar_berubah.emit()


@rpc("authority", "call_remote", "reliable")
func r_daftar_masuk(d: Dictionary) -> void:
	pemain = d
	daftar_berubah.emit()


func atur_siap(v: bool) -> void:
	if not siap_jaringan():
		return
	if multiplayer.is_server():
		_set_siap(1, v)
	else:
		r_siap.rpc_id(1, v)


@rpc("any_peer", "reliable")
func r_siap(v: bool) -> void:
	if multiplayer.is_server():
		_set_siap(multiplayer.get_remote_sender_id(), v)


func _set_siap(id: int, v: bool) -> void:
	if not pemain.has(id) or di_balapan or pemain[id]["siap"] == v:
		return
	pemain[id]["siap"] = v
	_siar_daftar()
	_cek_mulai()


func ganti_mobil(mobil: String) -> void:
	if not siap_jaringan():
		return
	if multiplayer.is_server():
		if pemain.has(1):
			pemain[1]["mobil"] = mobil
			_siar_daftar()
	else:
		r_mobil.rpc_id(1, mobil)


@rpc("any_peer", "reliable")
func r_mobil(mobil: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if pemain.has(id) and Gm.MOBIL.has(mobil) and not di_balapan:
		pemain[id]["mobil"] = mobil
		_siar_daftar()


func _cek_mulai() -> void:
	if not multiplayer.is_server() or di_balapan or pemain.is_empty():
		return
	for id in pemain:
		if not pemain[id]["siap"]:
			_hitung_mulai = -1.0
			return
	if _hitung_mulai < 0.0:
		_hitung_mulai = 3.0
		r_pesan.rpc("Semua siap! Balapan dimulai...")
		pesan.emit("Semua siap! Balapan dimulai...")


@rpc("authority", "call_remote", "reliable")
func r_pesan(t: String) -> void:
	pesan.emit(t)


func _process(delta: float) -> void:
	if not aktif or not multiplayer.is_server():
		return
	if _hitung_mulai >= 0.0:
		_hitung_mulai -= delta
		if _hitung_mulai < 0.0:
			_hitung_mulai = -1.0
			_mulai_balapan()
	if _akhir_t >= 0.0:
		_akhir_t -= delta
		if _akhir_t < 0.0:
			_akhir_t = -1.0
			r_pesan.rpc("Balapan berakhir. Kembali ke lobi untuk main lagi.")


func _mulai_balapan() -> void:
	di_balapan = true
	_urutan_selesai.clear()
	var ids := pemain.keys()
	ids.sort()
	for id in pemain:
		pemain[id]["muat"] = false
		pemain[id]["prog"] = 0.0
		pemain[id]["selesai"] = false
		pemain[id]["dalam"] = true
	r_mulai.rpc(ids)


@rpc("authority", "call_local", "reliable")
func r_mulai(ids: Array) -> void:
	slot = maxi(ids.find(multiplayer.get_unique_id()), 0)
	jml_pemain = ids.size()
	rank_saya = 0
	di_balapan = true
	if not multiplayer.is_server():
		for id in pemain:
			pemain[id]["selesai"] = false
	Gm.mode = "online"
	balapan_dimulai.emit()


# ---------------------------------------------------------------------
#  START SEREMPAK, POSISI, SELESAI
# ---------------------------------------------------------------------
func lapor_muat() -> void:
	if not siap_jaringan():
		return
	if multiplayer.is_server():
		_set_muat(1)
	else:
		r_muat.rpc_id(1)


@rpc("any_peer", "reliable")
func r_muat() -> void:
	if multiplayer.is_server():
		_set_muat(multiplayer.get_remote_sender_id())


func _set_muat(id: int) -> void:
	if pemain.has(id):
		pemain[id]["muat"] = true
	_cek_semua_muat()


func _cek_semua_muat() -> void:
	if not multiplayer.is_server() or not di_balapan:
		return
	var ada := false
	for id in pemain:
		if pemain[id].get("dalam", false):
			ada = true
			if not pemain[id]["muat"]:
				return
	if ada:
		r_go.rpc()


@rpc("authority", "call_local", "reliable")
func r_go() -> void:
	go_serempak.emit()


func kirim_state(data: Dictionary) -> void:
	if not siap_jaringan():
		return
	if multiplayer.is_server():
		_relay(1, data)
	else:
		r_state.rpc_id(1, data)


@rpc("any_peer", "unreliable_ordered")
func r_state(data: Dictionary) -> void:
	if multiplayer.is_server():
		_relay(multiplayer.get_remote_sender_id(), data)


func _relay(id: int, data: Dictionary) -> void:
	if pemain.has(id):
		pemain[id]["prog"] = float(data.get("prog", 0.0))
	r_state_relay.rpc(id, data)
	if id != multiplayer.get_unique_id():
		state_masuk.emit(id, data)


@rpc("authority", "call_remote", "unreliable_ordered")
func r_state_relay(id: int, data: Dictionary) -> void:
	if id != multiplayer.get_unique_id():
		state_masuk.emit(id, data)


func lapor_selesai(waktu: float) -> void:
	if not siap_jaringan():
		return
	if multiplayer.is_server():
		_selesai(1, waktu)
	else:
		r_selesai.rpc_id(1, waktu)


@rpc("any_peer", "reliable")
func r_selesai(waktu: float) -> void:
	if multiplayer.is_server():
		_selesai(multiplayer.get_remote_sender_id(), waktu)


func _selesai(id: int, waktu: float) -> void:
	if not pemain.has(id) or pemain[id]["selesai"]:
		return
	pemain[id]["selesai"] = true
	_urutan_selesai.append(id)
	var rank := _urutan_selesai.size()
	if rank == 1:
		_akhir_t = 25.0
	r_info.rpc(id, str(pemain[id]["nama"]), rank, waktu)


@rpc("authority", "call_local", "reliable")
func r_info(id: int, nama: String, rank: int, waktu: float) -> void:
	if id == multiplayer.get_unique_id():
		rank_saya = rank
	info_selesai.emit(id, nama, rank, waktu)


func kembali_lobi() -> void:
	if not siap_jaringan():
		return
	if multiplayer.is_server():
		_kembali(1)
	else:
		r_kembali.rpc_id(1)


@rpc("any_peer", "reliable")
func r_kembali() -> void:
	if multiplayer.is_server():
		_kembali(multiplayer.get_remote_sender_id())


func _kembali(id: int) -> void:
	if pemain.has(id):
		pemain[id]["dalam"] = false
		pemain[id]["siap"] = false
		pemain[id]["muat"] = false
	var masih := false
	for k in pemain:
		if pemain[k].get("dalam", false):
			masih = true
	if not masih:
		di_balapan = false
		_urutan_selesai.clear()
		_akhir_t = -1.0
	_siar_daftar()
