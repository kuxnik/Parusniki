class_name World
extends Node3D
## Острова, порты, океан, небо со сменой суток, туман.

const DAY_LEN := 3240.0   # игровых единиц на сутки (как в прототипе)

var ocean: MeshInstance3D
var ocean_mat: ShaderMaterial
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var lamp: OmniLight3D
var port_lights: Array = []


func build() -> void:
	GameData.ensure_loaded()
	_build_env()
	_build_ocean()
	for isl in GameData.islands:
		add_child(_island_mesh(isl))
	for p in GameData.ports:
		add_child(_port_mesh(p))
	_build_palms()


func _build_env() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#4F93C8")
	sky_mat.sky_horizon_color = Color("#C6DDE8")
	sky_mat.ground_horizon_color = Color("#C6DDE8")
	sky_mat.ground_bottom_color = Color("#1C5874")
	sky_mat.sun_angle_max = 8.0
	var sky = Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("#C6DDE8")
	env.fog_density = 0.00032
	env.fog_sky_affect = 0.0
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.1
	sun.light_color = Color("#FFF1D6")
	sun.shadow_enabled = false
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color("#8FA6D6")
	moon.light_energy = 0.0
	add_child(moon)
	lamp = OmniLight3D.new()
	lamp.light_color = Color("#FFC070")
	lamp.omni_range = 60.0
	lamp.light_energy = 0.0
	add_child(lamp)


func _build_ocean() -> void:
	ocean = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(4400, 4400)
	pm.subdivide_width = 110
	pm.subdivide_depth = 110
	ocean.mesh = pm
	ocean_mat = ShaderMaterial.new()
	ocean_mat.shader = load("res://shaders/ocean.gdshader")
	var arr: Array = []
	for isl in GameData.islands:
		arr.append(Vector4(isl["x"], isl["y"], isl["r"] * 0.95, 0.0))
	while arr.size() < 32:
		arr.append(Vector4(1e6, 1e6, 0, 0))
	ocean_mat.set_shader_parameter("islands", arr)
	ocean_mat.set_shader_parameter("island_count", GameData.islands.size())
	ocean.material_override = ocean_mat
	ocean.extra_cull_margin = 50.0
	add_child(ocean)


func _island_mesh(isl: Dictionary) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg = 32
	var r0: float = isl["r"]
	var peak: float = 10.0 + r0 * 0.12
	var rings = [[1.06, -2.0, Color("#3E8FA6")], [1.0, 0.8, Color("#D9C08A")], [0.86, 2.6, Color("#C9B27C")], [0.78, 4.5, Color("#5E8F4A")], [0.45, peak * 0.7, Color("#4E7A43")]]
	var pts: Array = []
	for ring in rings:
		var row: Array = []
		for i in seg:
			var a = TAU * float(i) / seg
			var rr = GameData.isl_r(isl, a) * float(ring[0])
			var jitter = 0.0 if ring[1] < 1.0 else sin(a * 5.0 + isl["seed"]) * 1.2
			row.append(Vector3(isl["x"] + cos(a) * rr, float(ring[1]) + jitter, isl["y"] + sin(a) * rr))
		pts.append(row)
	for k in rings.size() - 1:
		for i in seg:
			var j = (i + 1) % seg
			st.set_color(rings[k + 1][2])
			var a0: Vector3 = pts[k][i]
			var a1: Vector3 = pts[k][j]
			var b0: Vector3 = pts[k + 1][i]
			var b1: Vector3 = pts[k + 1][j]
			st.add_vertex(a0); st.add_vertex(b0); st.add_vertex(a1)
			st.add_vertex(a1); st.add_vertex(b0); st.add_vertex(b1)
	var top = Vector3(isl["x"], peak, isl["y"])
	var last: Array = pts[rings.size() - 1]
	st.set_color(Color("#46703C"))
	for i in seg:
		st.add_vertex(last[i]); st.add_vertex(top); st.add_vertex(last[(i + 1) % seg])
	st.generate_normals()
	var mi = MeshInstance3D.new()
	mi.mesh = st.commit()
	var m = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	mi.material_override = m
	return mi


func _port_mesh(p: Dictionary) -> Node3D:
	var n = Node3D.new()
	var px: float = p["x"]
	var py: float = p["y"]
	var col: Color = GameData.FACTCOL.get(p["fac"], Color.WHITE)
	var wood = ShipView.mat(Color("#6E4A2E"))
	var pier = MeshInstance3D.new()
	var pb = BoxMesh.new()
	pb.size = Vector3(10, 1.2, 110)
	pier.mesh = pb
	pier.material_override = wood
	pier.position = Vector3(px, 1.0, py - 70)
	n.add_child(pier)
	for i in 6:
		var hs = MeshInstance3D.new()
		var hb = BoxMesh.new()
		hb.size = Vector3(14, 9, 12)
		hs.mesh = hb
		hs.material_override = ShipView.mat(Color("#E9DCC0").darkened(0.1 * (i % 3)))
		var a = -0.6 + i * 0.24
		hs.position = Vector3(px + sin(a) * 120.0, 7.0, py - 150.0 - cos(a) * 30.0 - (i % 2) * 22.0)
		n.add_child(hs)
		var rf = MeshInstance3D.new()
		var pr = PrismMesh.new()
		pr.size = Vector3(16, 6, 13)
		rf.mesh = pr
		rf.material_override = ShipView.mat(Color("#B24A35"))
		rf.position = hs.position + Vector3(0, 7.5, 0)
		n.add_child(rf)
		var lt = OmniLight3D.new()
		lt.light_color = Color("#FFC870")
		lt.omni_range = 40.0
		lt.light_energy = 0.0
		lt.position = hs.position + Vector3(0, 2, 8)
		n.add_child(lt)
		port_lights.append(lt)
	var pole = MeshInstance3D.new()
	var pc = CylinderMesh.new()
	pc.top_radius = 0.3
	pc.bottom_radius = 0.4
	pc.height = 24
	pole.mesh = pc
	pole.material_override = wood
	pole.position = Vector3(px + 6, 12, py - 120)
	n.add_child(pole)
	var flag = MeshInstance3D.new()
	var fq = QuadMesh.new()
	fq.size = Vector2(9, 6)
	flag.mesh = fq
	flag.material_override = ShipView.mat(col, true, true)
	flag.position = Vector3(px + 10.5, 21, py - 120)
	n.add_child(flag)
	var lbl = Label3D.new()
	lbl.text = p["name"]
	lbl.font_size = 64
	lbl.outline_size = 18
	lbl.modulate = col
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = false
	lbl.pixel_size = 0.14
	lbl.position = Vector3(px, 45, py - 60)
	n.add_child(lbl)
	return n


func _build_palms() -> void:
	var trunks = []
	for isl in GameData.islands:
		var n = 6 + int(isl["r"] / 40.0)
		for k in n:
			var a = TAU * float(k) / n + sin(isl["seed"] * 3.0 + k) * 0.3
			if isl.get("port") != null and sin(a) > 0.35:
				continue
			var rr = GameData.isl_r(isl, a) * (0.7 + 0.12 * absf(sin(k * 1.7 + isl["seed"])))
			trunks.append(Vector3(isl["x"] + cos(a) * rr, 3.0, isl["y"] + sin(a) * rr))
	var trunk_mm = MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	var cm = CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = 0.6
	cm.height = 11
	cm.radial_segments = 5
	trunk_mm.mesh = cm
	trunk_mm.instance_count = trunks.size()
	var leaf_mm = MultiMesh.new()
	leaf_mm.transform_format = MultiMesh.TRANSFORM_3D
	var lm = PrismMesh.new()
	lm.size = Vector3(2.2, 0.5, 7.5)
	leaf_mm.mesh = lm
	leaf_mm.instance_count = trunks.size() * 5
	for i in trunks.size():
		var p: Vector3 = trunks[i]
		var lean = 0.15 + (i % 4) * 0.05
		var basis = Basis(Vector3.UP, i * 1.3) * Basis(Vector3.RIGHT, lean)
		trunk_mm.set_instance_transform(i, Transform3D(basis, p + basis * Vector3(0, 5.5, 0)))
		var top = p + basis * Vector3(0, 11, 0)
		for l in 5:
			var lb = Basis(Vector3.UP, TAU * l / 5.0 + i) * Basis(Vector3.RIGHT, 0.45)
			leaf_mm.set_instance_transform(i * 5 + l, Transform3D(lb, top + lb * Vector3(0, 0, -3.5)))
	var tmi = MultiMeshInstance3D.new()
	tmi.multimesh = trunk_mm
	tmi.material_override = ShipView.mat(Color("#8A6A44"))
	add_child(tmi)
	var lmi = MultiMeshInstance3D.new()
	lmi.multimesh = leaf_mm
	lmi.material_override = ShipView.mat(Color("#3F7F3A"))
	add_child(lmi)


## Небо, солнце, туман по времени суток. t — игровое время.
func update_env(t: float, tt: float, cam_pos: Vector3, amp: float, player_pos: Vector3) -> void:
	var tod = fposmod(t / DAY_LEN + 0.3, 1.0)
	var el = sin(TAU * (tod - 0.25))
	var day = clampf(el * 3.0 + 0.35, 0.0, 1.0)
	var dusk = clampf(1.0 - absf(el) * 4.0, 0.0, 1.0)
	var top = Color("#0E1F45").lerp(Color("#4F93C8"), day).lerp(Color("#3D5A8C"), dusk * 0.6)
	var hor = Color("#2E4570").lerp(Color("#C6DDE8"), day).lerp(Color("#F2A36B"), dusk * 0.75)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	env.fog_light_color = hor
	env.fog_density = lerpf(0.0006, 0.00022, day)
	env.ambient_light_energy = 0.5 + 0.35 * day
	var az = TAU * tod + 0.7
	sun.rotation = Vector3(-asin(clampf(el, -1.0, 1.0)), az, 0)
	sun.light_energy = maxf(0.0, 1.1 * day)
	sun.light_color = Color("#FFF1D6").lerp(Color("#FF9A5A"), dusk)
	moon.rotation = Vector3(-0.9, az + PI, 0)
	moon.light_energy = 0.5 * (1.0 - day)
	lamp.light_energy = 1.6 * clampf(1.0 - day * 1.5, 0.0, 1.0)
	lamp.position = player_pos + Vector3(0, 8, 0)
	for l in port_lights:
		l.light_energy = 1.2 * clampf(1.0 - day * 1.6, 0.0, 1.0)
	ocean.position = Vector3(snappedf(cam_pos.x, 40.0), 0, snappedf(cam_pos.z, 40.0))
	ocean_mat.set_shader_parameter("amp", amp)
	ocean_mat.set_shader_parameter("wtime", tt)
	ocean_mat.set_shader_parameter("night", 1.0 - day)


static func clock_str(t: float) -> String:
	var m = int(fposmod(t / DAY_LEN + 0.3, 1.0) * 1440.0)
	return "%d:%02d" % [m / 60, m % 60]
