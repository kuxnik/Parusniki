class_name ShipView
extends Node3D
## Низкополигональная модель корабля: корпус, мачты, паруса с «пузом», вымпел.
## Локальные оси: нос — −Z, правый борт — +X, вверх — +Y.

var sim: ShipSim
var roll = Node3D.new()
var sails_v: Array = []   # {pivot, mesh_inst, kind, verts(base PackedVector3Array), bf(PackedFloat32Array), bu, idx}
var pennant_piv = Node3D.new()
var pennant: MeshInstance3D
var pennant_base = PackedVector3Array()
var H = 1.3
var L = 10.0
var B = 3.0

static var _mats = {}


static func mat(col: Color, unshaded := false, double := false, alpha := 1.0) -> StandardMaterial3D:
	var key = "%s|%s|%s|%s" % [col.to_html(), unshaded, double, alpha]
	if _mats.has(key):
		return _mats[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = 0.85
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if double:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


func setup(s: ShipSim) -> void:
	sim = s
	var c = s.c
	L = c["L"]
	B = c["B"]
	H = maxf(1.3, L * 0.14)
	add_child(roll)
	_build_hull(c)
	_build_rig(c)
	_build_pennant(c)


func hull_half(z: float) -> float:
	# полуширина на уровне палубы; нос при z = −L/2
	var yy = -z
	if yy > L * 0.25:
		var t = (yy - L * 0.25) / (L * 0.25)
		return B / 2.0 * maxf(0.02, 1.0 - t * t)
	if yy > -L * 0.15:
		return B / 2.0
	return B / 2.0 - (B * 0.1) * ((-L * 0.15 - yy) / (L * 0.35))


func _build_hull(c: Dictionary) -> void:
	var player = sim.is_player
	var hull_col = Color("#7A4A2C") if player else Color("#5E3A2A")
	var fac: String = c.get("fac", "free")
	if fac == "membrane":
		hull_col = Color("#6B2A22")
	elif fac == "rune":
		hull_col = Color("#5A8FA0")
	var deck_y = H * 0.55
	var keel_y = -H * 0.45
	var n = 18
	var secs: Array = []
	for i in n + 1:
		var z = -L / 2.0 + L * float(i) / n
		var hw = hull_half(z)
		var sheer = 0.0
		if z < -L * 0.3:
			sheer = (-z - L * 0.3) / (L * 0.2) * H * 0.25
		var ky = keel_y * (0.4 + 0.6 * sin(PI * clampf(float(i) / n * 1.05, 0.0, 1.0)))
		secs.append([
			Vector3(-hw, deck_y + sheer, z), Vector3(-hw * 0.97, H * 0.1, z), Vector3(-hw * 0.6, ky * 0.8, z),
			Vector3(0, ky, z),
			Vector3(hw * 0.6, ky * 0.8, z), Vector3(hw * 0.97, H * 0.1, z), Vector3(hw, deck_y + sheer, z)])
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a: Array = secs[i]
		var b: Array = secs[i + 1]
		for j in a.size() - 1:
			var col = hull_col
			if j == 0 or j == 5:
				col = hull_col.lightened(0.08)
			st.set_color(col)
			_quad(st, a[j], a[j + 1], b[j + 1], b[j])
	# транец
	var last: Array = secs[n]
	st.set_color(hull_col.darkened(0.15))
	for j in range(1, last.size() - 1):
		st.add_vertex(last[0]); st.add_vertex(last[j + 1]); st.add_vertex(last[j])
	st.generate_normals()
	var hm = MeshInstance3D.new()
	hm.mesh = st.commit()
	var hmat = StandardMaterial3D.new()
	hmat.vertex_color_use_as_albedo = true
	hmat.roughness = 0.8
	hmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	hm.material_override = hmat
	roll.add_child(hm)
	# палуба
	var dt = SurfaceTool.new()
	dt.begin(Mesh.PRIMITIVE_TRIANGLES)
	dt.set_color(Color("#9B6A40"))
	for i in n:
		var a: Array = secs[i]
		var b: Array = secs[i + 1]
		var d = Vector3(0, -0.05, 0)
		_quad(dt, a[0] + d, b[0] + d, b[6] + d, a[6] + d)
	dt.generate_normals()
	var dm = MeshInstance3D.new()
	dm.mesh = dt.commit()
	dm.material_override = hmat
	roll.add_child(dm)
	# полоса фракции вдоль борта
	var wale = GameData.FACTCOL.get(fac, Color("#5FA9C4"))
	for sd in [-1, 1]:
		var bx = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.12, H * 0.12, L * 0.62)
		bx.mesh = bm
		bx.material_override = mat(wale)
		bx.position = Vector3(sd * (B / 2.0 + 0.03), H * 0.3, L * 0.02)
		roll.add_child(bx)
	# кормовая надстройка
	if L >= 20.0:
		var sc = MeshInstance3D.new()
		var sb = BoxMesh.new()
		sb.size = Vector3(B * 0.78, H * 0.7, L * 0.17)
		sc.mesh = sb
		sc.material_override = mat(hull_col)
		sc.position = Vector3(0, deck_y + H * 0.35, L * 0.37)
		roll.add_child(sc)
		var win = MeshInstance3D.new()
		var wb = BoxMesh.new()
		wb.size = Vector3(B * 0.6, H * 0.18, 0.1)
		win.mesh = wb
		win.material_override = mat(Color("#F3C77A"), true)
		win.position = Vector3(0, H * 0.95, L * 0.37 + L * 0.085 + 0.06)
		roll.add_child(win)
	# бушприт
	if L >= 12.0:
		var bs = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.12
		cm.bottom_radius = maxf(0.15, L * 0.007)
		cm.height = L * 0.3
		cm.radial_segments = 6
		bs.mesh = cm
		bs.material_override = mat(Color("#5B3A22"))
		bs.rotation.x = -(PI / 2.0 - 0.25)
		bs.position = Vector3(0, H * 0.75, -L / 2.0 - L * 0.1)
		roll.add_child(bs)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c2: Vector3, d: Vector3) -> void:
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c2)
	st.add_vertex(a); st.add_vertex(c2); st.add_vertex(d)


func _build_rig(c: Dictionary) -> void:
	var smat = mat(GameData.SAILCOL[c["set"]], false, true, 0.9 if c["set"] == "rune" else 1.0)
	var mast_mat = mat(Color("#5B3A22"))
	for sl in c["sails"]:
		var s = sqrt(float(sl["area"]))
		var mh = s * 1.5 + 2.0
		var z = -float(sl["x"]) * L
		var mast = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = maxf(0.12, L * 0.008)
		cm.bottom_radius = maxf(0.16, L * 0.011)
		cm.height = mh
		cm.radial_segments = 6
		mast.mesh = cm
		mast.material_override = mast_mat
		mast.position = Vector3(0, H * 0.55 + mh / 2.0, z)
		roll.add_child(mast)
		var piv = Node3D.new()
		piv.position = Vector3(0, H * 0.55 + 1.0, z)
		roll.add_child(piv)
		var verts = PackedVector3Array()
		var bf = PackedFloat32Array()
		var bu = PackedFloat32Array()
		var idx = PackedInt32Array()
		if sl["kind"] == "square":
			var w = s * 1.05
			var hgt = s * 0.95
			var nu = 6
			var nv = 4
			for j in nv + 1:
				for i in nu + 1:
					var xx = -w / 2.0 + w * float(i) / nu
					var yv = float(j) / nv
					verts.append(Vector3(xx, mh * 0.15 + hgt * yv, 0))
					bf.append((1.0 - pow(2.0 * xx / w, 2.0)) * (0.55 + 0.45 * sin(PI * minf(1.0, yv * 1.1))) * w)
					bu.append((xx / w + 0.5) * 3.0 + yv * 2.0)
			for j in nv:
				for i in nu:
					var a = j * (nu + 1) + i
					var b2 = a + nu + 1
					idx.append_array([a, b2, a + 1, a + 1, b2, b2 + 1])
			var yard = MeshInstance3D.new()
			var ym = BoxMesh.new()
			ym.size = Vector3(w * 1.05, 0.25, 0.25)
			yard.mesh = ym
			yard.material_override = mast_mat
			yard.position = Vector3(0, mh * 0.15 + hgt, 0)
			piv.add_child(yard)
		else:
			var hh = s * 1.45
			var ln = s * 0.95
			var nr = 6
			var nc = 5
			for j in nr + 1:
				var t = float(j) / nr
				var yv = 0.5 + t * (hh - 0.5)
				var ch = ln * (1.0 - t)
				for i in nc + 1:
					var u = float(i) / nc
					verts.append(Vector3(0, yv, ch * u))
					bf.append(sin(PI * pow(u, 0.8)) * ch * (1.0 - 0.35 * t))
					bu.append(u * 3.0 + t * 1.5)
			for j in nr:
				for i in nc:
					var a = j * (nc + 1) + i
					var b2 = a + nc + 1
					idx.append_array([a, b2, a + 1, a + 1, b2, b2 + 1])
			var boom = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.2, 0.2, ln)
			boom.mesh = bm
			boom.material_override = mast_mat
			boom.position = Vector3(0, 0.5, ln / 2.0)
			piv.add_child(boom)
		var mi = MeshInstance3D.new()
		mi.material_override = smat
		piv.add_child(mi)
		sails_v.append({"pivot": piv, "mi": mi, "kind": sl["kind"], "base": verts, "bf": bf, "bu": bu, "idx": idx, "mh": mh})


func _build_pennant(c: Dictionary) -> void:
	var sl: Dictionary = c["sails"][0]
	var mtop = H * 0.55 + sqrt(float(sl["area"])) * 1.5 + 2.0
	pennant_piv.position = Vector3(0, mtop, -float(sl["x"]) * L)
	roll.add_child(pennant_piv)
	var fs = maxf(0.8, L * 0.045)
	var ln = fs * 3.0
	for i in 11:
		var u = float(i) / 10.0
		var hgt = fs * 0.9 * (1.0 - 0.75 * u)
		pennant_base.append(Vector3(ln * u, 0, 0))
		pennant_base.append(Vector3(ln * u, -hgt, 0))
	pennant = MeshInstance3D.new()
	pennant.material_override = mat(GameData.FACTCOL.get(c.get("fac", "free"), Color.WHITE), true, true)
	pennant_piv.add_child(pennant)


## Обновление вида: положение на волне, крен, паруса и вымпел.
func update_view(tt: float, amp: float) -> void:
	var s = sim
	position = Vector3(s.x, GameData.wave_y(s.x, s.y, tt, amp) * 0.8, s.y)
	rotation.y = -s.psi
	roll.rotation.z = (PI * 0.45 if s.capsized else -s.side_sign * s.heel * GameData.DEG) + sin(tt * 1.3 + s.x * 0.01) * amp * 0.02
	roll.rotation.x = sin(tt * 1.1 + s.y * 0.01) * amp * 0.015
	var awa: float = s.info.get("awa", 90.0)
	var awa_s: float = s.info.get("awa_s", 0.0)
	var rs = 1.0 if awa_s >= 0.0 else -1.0
	var luff: bool = (s.info.get("luff", false) or awa < 22.0) and s.sail > 0.05
	var press = clampf(float(s.info.get("a_sp", 5.0)) / 11.0, 0.15, 1.0)
	for sv in sails_v:
		var piv: Node3D = sv["pivot"]
		var flutter = sin(tt * 20.0) * 0.08 if luff else 0.0
		var sq: bool = sv["kind"] == "square"
		if sq:
			piv.rotation.y = -maxf(0.0, minf(55.0, 90.0 - awa * 0.5)) * GameData.DEG * rs + flutter
		else:
			piv.rotation.y = -maxf(6.0, minf(85.0, awa * 0.5)) * GameData.DEG * rs + flutter
		piv.scale.y = maxf(0.06, s.sail)
		var mi: MeshInstance3D = sv["mi"]
		mi.visible = s.sail > 0.02
		if not mi.visible:
			continue
		var base: PackedVector3Array = sv["base"]
		var bf: PackedFloat32Array = sv["bf"]
		var bu: PackedFloat32Array = sv["bu"]
		var belly = 0.02 if luff else 0.07 + 0.2 * press
		var sgn = -1.0 if sq else -rs
		var v = PackedVector3Array()
		v.resize(base.size())
		for i in base.size():
			var rip = sin(tt * 17.0 - bu[i] * 3.2) * 0.06 if luff else sin(tt * (4.0 + press * 5.0) - bu[i] * 2.0) * 0.008 * press
			var off = bf[i] * (belly + rip)
			var p = base[i]
			if sq:
				p.z = sgn * off
			else:
				p.x = sgn * off
			v[i] = p
		var sst = SurfaceTool.new()
		sst.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ids: PackedInt32Array = sv["idx"]
		for k in ids:
			sst.add_vertex(v[k])
		sst.generate_normals()
		mi.mesh = sst.commit()
	# вымпел по вымпельному ветру
	pennant_piv.rotation.y = -PI / 2.0 - awa_s * GameData.DEG
	var fr = 6.0 + press * 10.0
	var am2 = 0.06 + 0.1 * (1.0 - press * 0.6)
	var ln = pennant_base[pennant_base.size() - 1].x
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts = PackedVector3Array()
	for i in pennant_base.size():
		var p2 = pennant_base[i]
		var u2 = p2.x / ln
		p2.z = sin(tt * fr - u2 * 7.0 + s.x * 0.1) * am2 * ln * u2
		pts.append(p2)
	for i in range(0, pts.size() - 2, 2):
		st.add_vertex(pts[i]); st.add_vertex(pts[i + 1]); st.add_vertex(pts[i + 2])
		st.add_vertex(pts[i + 2]); st.add_vertex(pts[i + 1]); st.add_vertex(pts[i + 3])
	pennant.mesh = st.commit()
