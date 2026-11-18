class_name ShipSim
extends RefCounted
## Физика корабля: парус как крыло, корпус, киль, крен. Перенос physics() из прототипа.
## Координаты как в прототипе: x — восток, y — юг; курс psi = 0 на север.

var c: Dictionary
var is_player = false
var x = 0.0
var y = 0.0
var psi = 0.0
var vx = 0.0
var vy = 0.0
var om = 0.0
var heel = 0.0
var fill = 1.0
var over = false
var stam = 100.0
var aground = false
var capsized = false
var flood = false
var side_sign = 1.0
var hull = 1.0
var sails = 1.0
var crew = 1.0
var water = 0.0
var leak = 0.0
var load = 0.0
var trail: Array = []
var trail_t = 0.0
var info: Dictionary = {}
# управление
var rudder = 0.0
var sail = 0.5
var oar = false
var sprint = false
var cb_down = true

signal message(text: String, warn: bool)


func _init(cfg: Dictionary, px: float, py: float, heading: float, player := false) -> void:
	c = cfg
	x = px
	y = py
	psi = heading
	is_player = player


func total_area() -> float:
	var a = 0.0
	for s in c["sails"]:
		a += s["area"]
	return a


func speed() -> float:
	return Vector2(vx, vy).length()


func step(dt: float, wind_sp: float, wind_dir: float, gust := 1.0) -> void:
	var st: Dictionary = GameData.SETS[c["set"]]
	var gf = 1.0 + (gust - 1.0) * st["gust"]
	var wsp = wind_sp * gf
	var wx = -sin(wind_dir) * wsp
	var wy = cos(wind_dir) * wsp
	var fx = sin(psi)
	var fy = -cos(psi)
	var rx = cos(psi)
	var ry = sin(psi)
	var ax = wx - vx
	var ay = wy - vy
	var a_sp = sqrt(ax * ax + ay * ay)
	var awa_s = atan2(-(ax * rx + ay * ry), -(ax * fx + ay * fy)) / GameData.DEG
	var awa = absf(awa_s)
	var q = 0.613 * a_sp * a_sp
	var w = GameData.wing(c["set"], awa)
	var area = total_area()
	var setv = 0.0 if capsized else sail
	var cos_h = cos(heel * GameData.DEG)
	var tau: float = 0.3 if w["luff"] else st["fill"] / maxf(0.35, crew)
	fill += ((0.0 if w["luff"] else 1.0) - fill) * minf(1.0, dt / tau)
	var bft = GameData.bft_of(wind_sp) + (1 if gust > 1.15 else 0)
	var is_over: bool = bft > st["limitB"] and setv > 0.5
	if is_over and not over:
		_msg("Руны перегружены и гаснут! Уберите паруса до 50%." if c["set"] == "rune" else "Ветер сильнее предела парусов — уберите часть!", true)
	over = is_over
	var eff = fill * ((0.25 if c["set"] == "rune" else 0.7) if is_over else 1.0) * (0.2 + 0.8 * sails)
	var drive: float = q * w["d"] * area * setv * cos_h * eff * GameData.rig_mul(c, awa)
	var side: float = q * w["s"] * area * setv * cos_h * eff
	var u = vx * fx + vy * fy
	var lat = vx * rx + vy * ry

	var oar_f = 0.0
	var oc = c.get("oar")
	if oc != null and oar and not capsized and not aground:
		var crew_k = maxf(0.2, crew)
		if oc["sprint"] > 0 and sprint and stam > 1.0:
			oar_f = oc["sprint"] * crew_k
			stam -= 12.0 * dt
		else:
			oar_f = oc["cruise"] * crew_k
			if oc["sprint"] > 0:
				stam -= 0.6 * dt
		if stam <= 0.0:
			stam = 0.0
			if oc["sprint"] > 0:
				oar = false
				_msg("Гребцы выдохлись — нужен отдых.", true)
	elif oc != null and oc["sprint"] > 0:
		stam = minf(100.0, stam + 5.0 * dt)

	var mass: float = c["m"] * (1.0 + 0.35 * water + 0.5 * load)
	var vh: float = 2.43 * sqrt(c["L"]) * GameData.KN * c.get("hullMul", 1.0)
	var wave = 0.0 if c.get("planing", false) else maxf(0.0, absf(u) / vh - 0.8)
	var rf: float = c["k"] * u * absf(u) * (1.0 + 14.0 * wave * wave) * (1.8 if flood else 1.0) * (1.0 + 1.5 * water)
	var k_lat: float
	if c.get("cb", false):
		k_lat = c["kLatDown"] if cb_down else c["kLatUp"]
	else:
		k_lat = c["kLat"]
	var side_dir = -1.0 if awa_s >= 0.0 else 1.0
	var rl: float = k_lat * lat * (absf(u) + 0.6) + c["k"] * 25.0 * lat * absf(lat)
	var f_x = drive + oar_f - rf
	var f_y = side_dir * side - rl
	vx += (fx * f_x + rx * f_y) / mass * dt
	vy += (fy * f_x + ry * f_y) / mass * dt

	var u2 = vx * fx + vy * fy
	var eff_r = maxf(0.15, minf(1.0, absf(u2) / (0.35 * vh)))
	var target: float = rudder * c["maxTurn"] * eff_r * (1.0 if u2 >= 0.0 else -1.0)
	if oc != null and oar and absf(rudder) > 0.05:
		target += rudder * oc["pivot"] * (1.0 - eff_r)
	om += (target * GameData.DEG - om) * minf(1.0, dt * 3.0)
	psi += om * dt

	var r: float = side * c["hCE"] / (mass * 9.81 * c["GM"] * (1.0 - 0.45 * water) * (1.0 + 0.15 * load))
	var heel_t = 90.0 if r >= 1.0 else asin(minf(1.0, r)) / GameData.DEG
	heel += (heel_t - heel) * minf(1.0, dt * 1.5)
	if not capsized and heel > c["capsize"]:
		capsized = true
		vx *= 0.2
		vy *= 0.2
		_msg("Перевернулись! Слишком много парусов для такого ветра.", true)
	var was_flood = flood
	flood = heel > c["flood"]
	if flood:
		water = minf(1.0, water + 0.004 * dt)
	if flood and not was_flood:
		_msg("Крен %d°: черпаем воду нижними портами!" % int(heel), true)
	side_sign = side_dir
	water = clampf(water + (leak - 0.004 * crew) * dt, 0.0, 1.0)

	var nx = x + vx * dt
	var ny = y + vy * dt
	var base_draft: float
	if c.get("cb", false):
		base_draft = c["draftDown"] if cb_down else c["draftUp"]
	else:
		base_draft = c["draft"]
	var draft = base_draft + water * 0.8
	var dep = GameData.depth_at(nx + fx * c["L"] * 0.4, ny + fy * c["L"] * 0.4)
	if dep < 0.0 or dep < draft:
		if not aground:
			_msg("Берег! Отворачивайте." if dep < 0.0 else "Сели на мель: глубина %.1f м, осадка %.1f м." % [dep, draft], true)
		aground = true
		vx = 0.0
		vy = 0.0
	else:
		aground = false
		x = nx
		y = ny

	trail_t += dt
	if trail_t > 0.25:
		trail_t = 0.0
		trail.append(Vector2(x - fx * c["L"] * 0.5, y - fy * c["L"] * 0.5))
		if trail.size() > 120:
			trail.pop_front()

	info = {"wsp": wsp, "true_sp": wind_sp, "dir": wind_dir, "gust": gust, "luff": w["luff"], "awa": awa, "awa_s": awa_s, "a_sp": a_sp, "u": u2, "draft": draft}


func _msg(t: String, warn: bool) -> void:
	if is_player:
		message.emit(t, warn)


## Поворот через ветер после переворота: «на киль».
func right_ship() -> void:
	capsized = false
	heel = 0.0
	water = minf(water, 0.3)
	sail = 0.3
