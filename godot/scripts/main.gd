extends Node3D
## Главная сцена: мир, ветер, корабль игрока, камера, частицы, интерфейс.

var world = World.new()
var hud = Hud.new()
var cam = Camera3D.new()
var sim: ShipSim
var view: ShipView
var game_t = 0.0          # игровое время (как T в прототипе)
var wind = {"dir": 0.0, "sp": 7.0, "tdir": 0.0, "tsp": 7.0, "next": 0.0}
var wake: CPUParticles3D
var spray: CPUParticles3D
var cam_dist = 40.0
var cam_yaw = 0.0
var started = false
var rng = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	add_child(world)
	world.build()
	cam.fov = 55
	cam.far = 6000
	cam.near = 0.5
	add_child(cam)
	cam.position = Vector3(0, 60, 900)
	cam.look_at(Vector3(0, 0, 500))
	var layer = CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.main = self
	hud.ship_chosen.connect(_start)
	hud.oar_toggled.connect(_on_oar)
	hud.right_ship.connect(_on_right)
	hud.graphics_toggled.connect(_on_gfx)
	var cfg = ConfigFile.new()
	var simple = false
	if cfg.load("user://settings.cfg") == OK:
		simple = cfg.get_value("gfx", "simple", false)
	hud.simple_gfx = simple
	hud.set_gfx_label()
	world.set_simple(simple)
	_pick_wind(true)
	var args = OS.get_cmdline_user_args()
	if args.has("--autotest"):
		_autotest = true
		if args.has("--simple"):
			world.set_simple(true)
		if args.has("--night"):
			game_t = World.DAY_LEN * 0.62
		_start(args[args.find("--autotest") + 1] if args.size() > args.find("--autotest") + 1 else "bark")
		hud.menu.visible = false


func _on_gfx(simple: bool) -> void:
	world.set_simple(simple)
	var cfg = ConfigFile.new()
	cfg.set_value("gfx", "simple", simple)
	cfg.save("user://settings.cfg")


func _on_oar() -> void:
	if sim:
		sim.oar = not sim.oar


func _on_right() -> void:
	if sim:
		sim.right_ship()
		hud.sail = 0.3
		hud._layout_controls()


func _start(id: String) -> void:
	if view:
		view.queue_free()
	var port: Dictionary = GameData.ports[0]
	sim = ShipSim.new(GameData.ship_by_id(id).duplicate(true), port["x"], port["y"] + 160.0, PI, true)
	sim.sail = 0.5
	hud.sail = 0.5
	hud._layout_controls()
	sim.message.connect(hud.toast)
	view = ShipView.new()
	add_child(view)
	view.setup(sim)
	cam_dist = clampf(sim.c["L"] * 2.4, 26.0, 140.0)
	_make_particles()
	started = true
	hud.toast("На воде: %s. Ветер — синяя стрелка на розе справа." % sim.c["name"])


func _make_particles() -> void:
	for p in [wake, spray]:
		if p:
			p.queue_free()
	var gt = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	var gr = Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gr
	var foam = StandardMaterial3D.new()
	foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam.albedo_texture = gt
	foam.albedo_color = Color(0.95, 0.98, 1.0, 0.35)
	foam.cull_mode = BaseMaterial3D.CULL_DISABLED
	foam.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	foam.vertex_color_use_as_albedo = true
	var foam_b = foam.duplicate()
	foam_b.albedo_color = Color(0.95, 0.98, 1.0, 0.7)
	foam_b.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	wake = CPUParticles3D.new()
	wake.amount = 90
	wake.lifetime = 5.0
	wake.local_coords = false
	var qm = PlaneMesh.new()
	qm.size = Vector2(1.4, 1.4)
	qm.material = foam
	wake.mesh = qm
	wake.direction = Vector3(0, 0, 1)
	wake.spread = 25
	wake.gravity = Vector3.ZERO
	wake.initial_velocity_min = 0.3
	wake.initial_velocity_max = 1.2
	wake.scale_amount_min = 0.6
	wake.scale_amount_max = 2.0
	var cr = Curve.new()
	cr.add_point(Vector2(0, 0.5))
	cr.add_point(Vector2(1, 2.6))
	wake.scale_amount_curve = cr
	var ramp = Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	wake.color_ramp = ramp
	add_child(wake)
	spray = CPUParticles3D.new()
	spray.amount = 90
	spray.lifetime = 1.1
	spray.local_coords = false
	var qm2 = QuadMesh.new()
	qm2.size = Vector2(0.6, 0.6)
	qm2.material = foam_b
	spray.mesh = qm2
	spray.direction = Vector3(0, 1, 0)
	spray.spread = 55
	spray.gravity = Vector3(0, -9.8, 0)
	spray.initial_velocity_min = 2.0
	spray.initial_velocity_max = 6.0
	var ramp2 = Gradient.new()
	ramp2.set_color(0, Color(1, 1, 1, 1))
	ramp2.set_color(1, Color(1, 1, 1, 0))
	spray.color_ramp = ramp2
	add_child(spray)


func _pick_wind(first: bool) -> void:
	var r = rng.randf()
	var sp = rng.randf_range(2.0, 3.5) if r < 0.08 else (rng.randf_range(5.5, 9.0) if r < 0.75 else rng.randf_range(9.0, 12.5))
	wind["tsp"] = sp
	wind["tdir"] = rng.randf_range(0, TAU) if first else wind["dir"] + rng.randf_range(-70, 70) * GameData.DEG
	wind["next"] = game_t + rng.randf_range(700, 1400)
	if first:
		wind["dir"] = wind["tdir"]
		wind["sp"] = wind["tsp"]
	elif sim:
		var b = GameData.bft_of(sp)
		hud.toast("Ветер меняется: %d балл." % b)


func _process(delta: float) -> void:
	var dt = minf(delta, 0.05)
	var tt = Time.get_ticks_msec() / 1000.0
	var amp = 0.15 + 0.1 * GameData.bft_of(wind["sp"])
	if not started:
		world.update_env(game_t, tt, cam.position, amp, Vector3.ZERO)
		game_t += dt * 20.0
		return
	hud.keyboard(dt)
	if Input.is_action_just_pressed("ui_accept") and sim.c.get("oar") != null:
		sim.oar = not sim.oar
	sim.rudder = hud.rudder
	sim.sail = hud.sail
	# физика с подшагами (как в прототипе: время идёт ×GAME_SPEED)
	var n = 4
	for i in n:
		var h = dt * GameData.GAME_SPEED / n
		game_t += h
		var a = wrapf(wind["tdir"] - wind["dir"], -PI, PI)
		wind["dir"] += a * minf(1.0, h / 60.0)
		wind["sp"] += (wind["tsp"] - wind["sp"]) * minf(1.0, h / 45.0)
		if game_t > wind["next"]:
			_pick_wind(false)
		sim.step(h, wind["sp"], wind["dir"])
	view.update_view(tt, amp)
	_update_particles(tt, amp)
	_update_camera(dt)
	world.update_env(game_t, tt, cam.position, amp, view.position)
	hud.update_hud(dt, sim, wind["sp"], wind["dir"], World.clock_str(game_t))
	if _autotest:
		_frames += 1
		hud.sail = 1.0
		hud.rudder = 0.6 if (_frames / 300) % 2 == 0 else 0.0
		if _frames == 360 or _frames == 900:
			var img := get_viewport().get_texture().get_image()
			img.save_png("/tmp/godot_shot_%d.png" % _frames)
		if _frames % 100 == 0:
			print("t=%.0f speed=%.1f kn heel=%.0f awa=%.0f aground=%s pos=(%.0f,%.0f) wind=%.1f" % [game_t, sim.speed() / GameData.KN, sim.heel, sim.info.get("awa", 0), sim.aground, sim.x, sim.y, wind["sp"]])

var _autotest := false
var _frames := 0


func _update_particles(tt: float, amp: float) -> void:
	var spd = sim.speed()
	var fwd = Vector3(sin(sim.psi), 0, -cos(sim.psi))
	var L: float = sim.c["L"]
	var stern = view.position - fwd * L * 0.45
	stern.y = amp + 0.3
	wake.global_position = stern
	wake.emitting = spd > 0.6
	wake.emission_box_extents = Vector3(sim.c["B"] * 0.3, 0.05, 0.3)
	wake.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var bow = view.position + fwd * L * 0.46
	bow.y = amp * 0.6 + 0.5
	spray.global_position = bow
	spray.emitting = spd > 1.5
	spray.initial_velocity_max = 3.0 + spd * 0.8


func _update_camera(dt: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	if vs.y > vs.x:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = 62
	else:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = 55
	var yaw = sim.psi + cam_yaw
	var f = Vector3(sin(yaw), 0, -cos(yaw))
	var target = view.position - f * cam_dist + Vector3(0, cam_dist * 0.32 + 4.0, 0)
	cam.position = cam.position.lerp(target, minf(1.0, dt * 3.0))
	cam.look_at(view.position + f * cam_dist * 0.8 + Vector3(0, 1, 0))
