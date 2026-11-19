class_name Hud
extends Control
## Интерфейс: скорость, роза ветров, руль и паруса (мультитач), кнопки, сообщения.

signal ship_chosen(id: String)
signal oar_toggled
signal right_ship
signal graphics_toggled(simple: bool)
var gfx_btn = Button.new()
var simple_gfx := false

var main  # ссылка на Main
var spd_lbl = Label.new()
var info_lbl = Label.new()
var toast_lbl = Label.new()
var rose = Control.new()
var rudder_area = Panel.new()
var rudder_knob = Panel.new()
var sail_area = Panel.new()
var sail_fill = ColorRect.new()
var sail_lbl = Label.new()
var oar_btn = Button.new()
var right_btn = Button.new()
var menu = PanelContainer.new()
var top_panel = PanelContainer.new()
var touches = {}   # index -> "rudder" / "sail"
var rudder = 0.0
var sail = 0.5
var toast_t = 0.0
var wind_dir = 0.0
var ship_psi = 0.0
var bft = 3


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.add_theme_stylebox_override("panel", _box(Color(0.07, 0.15, 0.23, 0.78)))
	add_child(top_panel)
	var vb = VBoxContainer.new()
	top_panel.add_child(vb)
	spd_lbl.add_theme_font_size_override("font_size", 30)
	vb.add_child(spd_lbl)
	info_lbl.add_theme_font_size_override("font_size", 15)
	info_lbl.modulate = Color("#A9B8C6")
	vb.add_child(info_lbl)

	rose.custom_minimum_size = Vector2(110, 110)
	rose.size = Vector2(110, 110)
	rose.position = Vector2(-122, 12)
	rose.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rose.draw.connect(_draw_rose)
	add_child(rose)

	rudder_area.position = Vector2(16, -112)
	rudder_area.size = Vector2(300, 96)
	rudder_area.add_theme_stylebox_override("panel", _box(Color(0.07, 0.15, 0.23, 0.35)))
	rudder_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rudder_area)
	rudder_knob.size = Vector2(70, 70)
	rudder_knob.add_theme_stylebox_override("panel", _box(Color("#5B3A22"), 35, Color("#E0A84A"), 4))
	rudder_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rudder_area.add_child(rudder_knob)

	sail_area.position = Vector2(-86, -236)
	sail_area.size = Vector2(70, 220)
	sail_area.add_theme_stylebox_override("panel", _box(Color(0.07, 0.15, 0.23, 0.45)))
	sail_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sail_area)
	sail_fill.color = Color("#E9DCC0")
	sail_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sail_area.add_child(sail_fill)
	sail_lbl.position = Vector2(0, 6)
	sail_lbl.size = Vector2(70, 24)
	sail_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sail_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	sail_lbl.add_theme_constant_override("outline_size", 6)
	sail_area.add_child(sail_lbl)

	oar_btn.text = "Вёсла"
	oar_btn.position = Vector2(-220, -80)
	oar_btn.size = Vector2(120, 56)
	oar_btn.toggle_mode = true
	oar_btn.pressed.connect(oar_toggled.emit)
	add_child(oar_btn)
	right_btn.text = "На киль"
	right_btn.position = Vector2(-80, -150)
	right_btn.size = Vector2(160, 60)
	right_btn.visible = false
	right_btn.pressed.connect(right_ship.emit)
	add_child(right_btn)

	toast_lbl.position = Vector2(-300, 16)
	toast_lbl.size = Vector2(600, 40)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_lbl.add_theme_font_size_override("font_size", 18)
	toast_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast_lbl.add_theme_constant_override("outline_size", 8)
	add_child(toast_lbl)
	_build_menu()
	_layout_controls()


func _box(col: Color, radius := 14, border := Color(1, 1, 1, 0.12), bw := 1) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _build_menu() -> void:
	menu.add_theme_stylebox_override("panel", _box(Color(0.05, 0.11, 0.17, 0.95)))
	add_child(menu)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	menu.add_child(vb)
	var t = Label.new()
	t.text = "Парусники — выберите корабль"
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color("#E0A84A"))
	vb.add_child(t)
	GameData.ensure_loaded()
	for s in GameData.ships:
		var b = Button.new()
		b.text = "%s  ·  %d м" % [s["name"], int(s["L"])]
		b.custom_minimum_size = Vector2(460, 54)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_choose.bind(String(s["id"])))
		vb.add_child(b)
	gfx_btn.custom_minimum_size = Vector2(460, 46)
	gfx_btn.add_theme_font_size_override("font_size", 17)
	gfx_btn.pressed.connect(_toggle_gfx)
	vb.add_child(gfx_btn)
	var gpu = Label.new()
	gpu.text = "Видеочип: %s · %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()]
	gpu.add_theme_font_size_override("font_size", 13)
	gpu.modulate = Color("#7F8C99")
	vb.add_child(gpu)
	var h = Label.new()
	h.text = "Руль — тяните ручку влево-вправо. Паруса — ползунок справа.\nКлавиатура: ← → руль, W/S паруса, R вёсла."
	h.add_theme_font_size_override("font_size", 15)
	h.modulate = Color("#A9B8C6")
	vb.add_child(h)
	menu.reset_size()


func _process(_dt: float) -> void:
	_place()


func _place() -> void:
	var vp := get_viewport_rect().size
	# безопасная зона (вырез камеры, скругления), в координатах интерфейса
	var safe := DisplayServer.get_display_safe_area()
	var scr := DisplayServer.screen_get_size()
	var k := vp.x / maxf(1.0, float(scr.x))
	var top := maxf(0.0, safe.position.y * k)
	var left := maxf(0.0, safe.position.x * k)
	var right := maxf(0.0, (scr.x - safe.end.x) * k)
	var bottom := maxf(0.0, (scr.y - safe.end.y) * k)
	top_panel.position = Vector2(12 + left, 12 + top)
	rose.position = Vector2(vp.x - 122 - right, 12 + top)
	rudder_area.position = Vector2(16 + left, vp.y - 112 - bottom)
	sail_area.position = Vector2(vp.x - 86 - right, vp.y - 236 - bottom)
	oar_btn.position = Vector2(vp.x - 220 - right, vp.y - 80 - bottom)
	right_btn.position = Vector2(vp.x / 2.0 - 80, vp.y - 170)
	toast_lbl.position = Vector2(vp.x / 2.0 - 300, 16)
	menu.position = (vp - menu.size) / 2.0


func set_gfx_label() -> void:
	gfx_btn.text = "Графика: простая (для магнитол)" if simple_gfx else "Графика: полная"


func _toggle_gfx() -> void:
	simple_gfx = not simple_gfx
	set_gfx_label()
	graphics_toggled.emit(simple_gfx)


func _choose(id: String) -> void:
	menu.visible = false
	ship_chosen.emit(id)


func _layout_controls() -> void:
	var w = rudder_area.size.x
	rudder_knob.position = Vector2(w / 2.0 - 35 + rudder * (w / 2.0 - 40), 13)
	var hgt = sail_area.size.y - 12
	sail_fill.position = Vector2(6, 6 + hgt * (1.0 - sail))
	sail_fill.size = Vector2(sail_area.size.x - 12, hgt * sail)
	sail_lbl.text = "%d%%" % int(round(sail * 100))


func _input(event: InputEvent) -> void:
	if menu.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if rudder_area.get_global_rect().grow(30).has_point(event.position):
				touches[event.index] = "rudder"
				_apply(event.index, event.position)
			elif sail_area.get_global_rect().grow(30).has_point(event.position):
				touches[event.index] = "sail"
				_apply(event.index, event.position)
		else:
			if touches.get(event.index) == "rudder":
				rudder = 0.0
				_layout_controls()
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		if touches.has(event.index):
			_apply(event.index, event.position)


func _apply(idx: int, pos: Vector2) -> void:
	if touches[idx] == "rudder":
		var r = rudder_area.get_global_rect()
		rudder = clampf((pos.x - r.get_center().x) / (r.size.x / 2.0 - 30.0), -1.0, 1.0)
	else:
		var r2 = sail_area.get_global_rect()
		sail = clampf(1.0 - (pos.y - r2.position.y - 10.0) / (r2.size.y - 20.0), 0.0, 1.0)
	_layout_controls()


func keyboard(dt: float) -> void:
	var kr = 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		kr -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		kr += 1.0
	if kr != 0.0:
		rudder = kr
		_layout_controls()
	elif not touches.values().has("rudder") and absf(rudder) > 0.0 and (Input.is_key_pressed(KEY_LEFT) == false and Input.is_key_pressed(KEY_RIGHT) == false) and _kb_rudder:
		rudder = 0.0
		_layout_controls()
	_kb_rudder = kr != 0.0
	if Input.is_key_pressed(KEY_W):
		sail = minf(1.0, sail + dt * 0.6)
		_layout_controls()
	if Input.is_key_pressed(KEY_S):
		sail = maxf(0.0, sail - dt * 0.6)
		_layout_controls()

var _kb_rudder = false


func toast(t: String, warn := false) -> void:
	toast_lbl.text = t
	toast_lbl.add_theme_color_override("font_color", Color("#F6B07E") if warn else Color("#F3EBDD"))
	toast_t = 3.5


func update_hud(dt: float, sim: ShipSim, wsp: float, wdir: float, clock: String) -> void:
	var kn = sim.speed() / GameData.KN
	spd_lbl.text = "%.1f уз" % kn
	bft = GameData.bft_of(wsp)
	info_lbl.text = "крен %d°  ·  %d балл.  ·  %s  ·  %d fps" % [int(sim.heel), bft, clock, Engine.get_frames_per_second()]
	wind_dir = wdir
	ship_psi = sim.psi
	rose.queue_redraw()
	oar_btn.visible = sim.c.get("oar") != null
	oar_btn.button_pressed = sim.oar
	right_btn.visible = sim.capsized
	if toast_t > 0.0:
		toast_t -= dt
		toast_lbl.modulate.a = clampf(toast_t, 0.0, 1.0)


func _draw_rose() -> void:
	var c = Vector2(55, 55)
	rose.draw_circle(c, 52, Color(0.06, 0.13, 0.2, 0.75))
	rose.draw_arc(c, 52, 0, TAU, 40, Color(1, 1, 1, 0.15), 2)
	var f = ThemeDB.fallback_font
	rose.draw_string(f, c + Vector2(-5, -36), "С", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#A9B8C6"))
	# стрелка ветра: дует из wind_dir
	var d = Vector2(-sin(wind_dir), cos(wind_dir))
	rose.draw_line(c - d * 34, c + d * 26, Color("#5FA9C4"), 5)
	var tip = c + d * 34
	var n = Vector2(-d.y, d.x)
	rose.draw_colored_polygon(PackedVector2Array([tip, tip - d * 14 + n * 8, tip - d * 14 - n * 8]), Color("#5FA9C4"))
	# корабль
	var fwd = Vector2(sin(ship_psi), -cos(ship_psi))
	var side = Vector2(-fwd.y, fwd.x)
	rose.draw_colored_polygon(PackedVector2Array([c + fwd * 16, c - fwd * 10 + side * 7, c - fwd * 5, c - fwd * 10 - side * 7]), Color("#E0A84A"))
	rose.draw_string(f, c + Vector2(-26, 70), "%d балл." % bft, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
