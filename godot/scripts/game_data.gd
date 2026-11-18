class_name GameData
extends RefCounted
## Данные мира и аэродинамика парусов — перенос из прототипа (index.html).

const KN := 0.5144
const DEG := PI / 180.0
const GAME_SPEED := 4.5

const SETS := {
	"free":     {"name": "Вольные косые",    "b0": 30.0, "CLmax": 1.3, "CD0": 0.08, "k": 0.07,  "CDrun": 0.9, "fill": 0.5, "gust": 1.0, "limitB": 6},
	"empire":   {"name": "Имперские прямые", "b0": 50.0, "CLmax": 0.9, "CD0": 0.20, "k": 0.13,  "CDrun": 2.2, "fill": 2.0, "gust": 0.7, "limitB": 9},
	"rune":     {"name": "Рунные",           "b0": 20.0, "CLmax": 1.4, "CD0": 0.03, "k": 0.045, "CDrun": 0.8, "fill": 1.0, "gust": 1.0, "limitB": 5},
	"membrane": {"name": "Перепончатые",     "b0": 38.0, "CLmax": 1.6, "CD0": 0.12, "k": 0.07,  "CDrun": 1.2, "fill": 0.2, "gust": 1.3, "limitB": 6},
}
const SAILCOL := {"free": Color("#EFE3C8"), "empire": Color("#F6F1E4"), "rune": Color("#BFE6F2"), "membrane": Color("#B0563F")}
const FACTCOL := {"free": Color("#5FA9C4"), "empire": Color("#E0A84A"), "rune": Color("#9FD8EA"), "membrane": Color("#E06A4B"), "neutral": Color("#E9DCC0")}

static var islands: Array = []
static var ports: Array = []
static var ships: Array = []
static var _loaded = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	var f = FileAccess.open("res://world_data.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	islands = d["islands"]
	ports = d["ports"]
	ships = d["ships"]
	_loaded = true


static func ship_by_id(id: String) -> Dictionary:
	ensure_loaded()
	for s in ships:
		if s["id"] == id:
			return s
	return ships[0]


## Подъёмная сила и сопротивление паруса при вымпельном угле beta (градусы).
static func wing(set_id: String, beta: float) -> Dictionary:
	var st: Dictionary = SETS[set_id]
	var b = clampf(beta, 0.0, 180.0)
	var cl = 0.0
	var cd = 0.0
	if b < st["b0"]:
		cl = 0.0
		cd = st["CD0"]
	elif b <= 90.0:
		cl = st["CLmax"] * minf(1.0, (b - st["b0"]) / 12.0)
		cd = st["CD0"] + st["k"] * cl * cl
	else:
		var t = (b - 90.0) / 90.0
		cl = st["CLmax"] * (1.0 - t)
		cd = st["CD0"] + st["k"] * cl * cl + st["CDrun"] * t
	var r = b * DEG
	return {"d": cl * sin(r) - cd * cos(r), "s": maxf(0.0, cl * cos(r) + cd * sin(r)), "luff": b < st["b0"]}


## Прямые паруса тянут на попутных курсах, косые — на острых.
static func rig_mul(c: Dictionary, awa: float) -> float:
	var a = 0.0
	var s = 0.0
	for sl in c["sails"]:
		var f = 1.0
		if sl["kind"] == "square":
			if awa < 60.0:
				f = 0.78
			elif awa < 110.0:
				f = 0.78 + 0.37 * (awa - 60.0) / 50.0
			else:
				f = 1.15
		else:
			f = 1.0 if awa < 100.0 else 1.0 - 0.15 * (awa - 100.0) / 80.0
		a += sl["area"]
		s += sl["area"] * f
	return s / a if a > 0.0 else 1.0


static func bft_of(ms: float) -> int:
	var th = [0.3, 1.6, 3.4, 5.5, 8.0, 10.8, 13.9, 17.2, 20.8]
	var b = 0
	while b < th.size() and ms >= th[b]:
		b += 1
	return b


static func isl_r(isl: Dictionary, ang: float) -> float:
	var t = fposmod(ang / TAU, 1.0) * 24.0
	var i = int(floor(t))
	var f = t - i
	var n: Array = isl["n"]
	var a: float = n[i % 24]
	var b: float = n[(i + 1) % 24]
	return isl["r"] * (a + (b - a) * f)


## Глубина в точке (x, y) мира прототипа; -1 — суша.
static func depth_at(x: float, y: float) -> float:
	ensure_loaded()
	var d = 40.0
	for isl in islands:
		var dx: float = x - isl["x"]
		var dy: float = y - isl["y"]
		var dist = sqrt(dx * dx + dy * dy)
		if dist > isl["r"] * 1.4 + 230.0:
			continue
		var r = isl_r(isl, atan2(dy, dx))
		if dist < r:
			return -1.0
		if dist < r + 30.0:
			d = minf(d, 0.6)
		elif dist < r + 120.0:
			d = minf(d, 2.2)
		elif dist < r + 220.0:
			d = minf(d, 6.0)
	for p in ports:
		if Vector2(x - p["x"], y - p["y"]).length() < 230.0:
			return 12.0
	return d


static func wave_y(x: float, z: float, t: float, amp: float) -> float:
	return amp * (0.6 * sin(0.021 * x + t * 1.1) + 0.4 * sin(0.033 * z - t * 0.9) + 0.25 * sin(0.05 * (x + z) + t * 1.7))
