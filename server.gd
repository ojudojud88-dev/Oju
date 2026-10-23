extends Node
## Layar server khusus (headless). Hanya mencetak status ruang ke konsol.

var _t := 0.0


func _ready() -> void:
	print("[SERVER] Turbo Drift siap. Menunggu pemain...")


func _process(delta: float) -> void:
	_t += delta
	if _t >= 10.0:
		_t = 0.0
		var nama: Array = []
		for id in Net.pemain:
			var p: Dictionary = Net.pemain[id]
			nama.append("%s%s" % [p["nama"], "(siap)" if p["siap"] else ""])
		print("[SERVER] pemain=%d balapan=%s  %s" % [Net.pemain.size(), str(Net.di_balapan), ", ".join(nama)])
