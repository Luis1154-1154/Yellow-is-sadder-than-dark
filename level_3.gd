extends Node2D

const BASE_SIZE := Vector2(3840.0, 2160.0)
const JAMMY_COLOR := Color("#f5d08a")
const XCARLET_COLOR := Color("#5bc0eb")
const JAMMY_INK := Color("#2a2b30")
const XCARLET_INK := Color("#3aa8db")
const TEXT_COLOR := Color("#fff9f0")
const PANEL_COLOR := Color(0.22, 0.23, 0.25, 0.72)
const SPEAKER_BG_COLOR := Color(0.18, 0.19, 0.21, 0.85)

const PAPER_RECT := Rect2(Vector2(720.0, 170.0), Vector2(2400.0, 1680.0))

var ui_root: Control
var paper_panel: Panel
var strokes_container: Node2D
var cursor_dot: ColorRect
var pass_turn_button: Button
var controls_label: Label

var dialogue_panel: Panel
var dialogue_label: Label
var speaker_panel: Panel
var speaker_label: Label

var pencil_player: AudioStreamPlayer
var pencil_stream: AudioStream
var fredoka_font: Font
var rock_salt_font: Font

var current_line: Line2D = null
var stroke_start_point := Vector2.ZERO
var is_drawing := false
var is_xcarlet_turn := false
var stroke_step_counter := 0
var jammy_brush_width := 8.0

var all_strokes: Array[Line2D] = []
var pending_jammy_strokes: Array[Line2D] = []


func _ready() -> void:
	name = "Level3"
	_load_resources()
	_build_ui()
	_show_dialogue("Xcarlet", "Draw a landscape, a character, or a half-shape—I'll match your vibe! Press ENTER when it's my turn.", XCARLET_COLOR)


func _load_resources() -> void:
	if ResourceLoader.exists("res://fonts/Fredoka-Regular.ttf"):
		fredoka_font = load("res://fonts/Fredoka-Regular.ttf")
	if ResourceLoader.exists("res://fonts/RockSalt-Regular.ttf"):
		rock_salt_font = load("res://fonts/RockSalt-Regular.ttf")
	if ResourceLoader.exists("res://assets/sounds/Soft_pencil_tap_on_n_#1-1794378651940.mp3"):
		pencil_stream = load("res://assets/sounds/Soft_pencil_tap_on_n_#1-1794378651940.mp3")


func _build_ui() -> void:
	ui_root = Control.new()
	ui_root.position = Vector2.ZERO
	ui_root.size = BASE_SIZE
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	var desk_bg := ColorRect.new()
	desk_bg.position = Vector2.ZERO
	desk_bg.size = BASE_SIZE
	desk_bg.color = Color("#7a4b2a")
	desk_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(desk_bg)

	var paper_shadow := ColorRect.new()
	paper_shadow.position = PAPER_RECT.position + Vector2(22.0, 26.0)
	paper_shadow.size = PAPER_RECT.size
	paper_shadow.color = Color(0.0, 0.0, 0.0, 0.35)
	paper_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(paper_shadow)

	paper_panel = Panel.new()
	paper_panel.position = PAPER_RECT.position
	paper_panel.size = PAPER_RECT.size
	paper_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper_style := StyleBoxFlat.new()
	paper_style.bg_color = Color("#fbf8f1")
	paper_style.set_corner_radius_all(8)
	paper_style.set_border_width_all(4)
	paper_style.border_color = Color("#ded8ca")
	paper_panel.add_theme_stylebox_override("panel", paper_style)
	ui_root.add_child(paper_panel)

	strokes_container = Node2D.new()
	strokes_container.z_index = 5
	add_child(strokes_container)

	cursor_dot = ColorRect.new()
	cursor_dot.size = Vector2(12.0, 12.0)
	cursor_dot.color = JAMMY_INK
	cursor_dot.z_index = 8
	cursor_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(cursor_dot)

	controls_label = Label.new()
	controls_label.position = Vector2(PAPER_RECT.position.x, 75.0)
	controls_label.size = Vector2(1720.0, 70.0)
	controls_label.text = "[PEN/CLICK] Draw  |  [1/2/3] Size  |  [SHIFT] Line  |  [Z/R-CLICK] Undo  |  [C] Clear"
	controls_label.add_theme_font_size_override("font_size", 32)
	if fredoka_font:
		controls_label.add_theme_font_override("font", fredoka_font)
	controls_label.add_theme_color_override("font_color", TEXT_COLOR)
	controls_label.add_theme_color_override("font_shadow_color", Color("#000000cc"))
	controls_label.add_theme_constant_override("shadow_offset_x", 3)
	controls_label.add_theme_constant_override("shadow_offset_y", 3)
	ui_root.add_child(controls_label)

	pass_turn_button = Button.new()
	pass_turn_button.position = Vector2(PAPER_RECT.end.x - 640.0, 62.0)
	pass_turn_button.size = Vector2(640.0, 84.0)
	pass_turn_button.text = "Let Xcarlet Complete [ENTER]"
	pass_turn_button.add_theme_font_size_override("font_size", 35)
	if fredoka_font:
		pass_turn_button.add_theme_font_override("font", fredoka_font)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.16, 0.22, 0.28, 0.92)
	btn_style.border_color = XCARLET_COLOR
	btn_style.set_border_width_all(3)
	btn_style.set_corner_radius_all(14)
	pass_turn_button.add_theme_stylebox_override("normal", btn_style)
	pass_turn_button.add_theme_color_override("font_color", XCARLET_COLOR)
	pass_turn_button.pressed.connect(_on_pass_turn_pressed)
	ui_root.add_child(pass_turn_button)

	dialogue_panel = Panel.new()
	dialogue_panel.position = Vector2(1120.0, 1900.0)
	dialogue_panel.size = Vector2(1600.0, 195.0)
	dialogue_panel.z_index = 10
	dialogue_panel.add_theme_stylebox_override("panel", _make_box_style(PANEL_COLOR, XCARLET_COLOR))
	ui_root.add_child(dialogue_panel)

	speaker_panel = Panel.new()
	speaker_panel.position = Vector2(1156.0, 1842.0)
	speaker_panel.size = Vector2(300.0, 60.0)
	speaker_panel.z_index = 11
	speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, XCARLET_COLOR))
	ui_root.add_child(speaker_panel)

	speaker_label = Label.new()
	speaker_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.add_theme_font_size_override("font_size", 34)
	if fredoka_font:
		speaker_label.add_theme_font_override("font", fredoka_font)
	speaker_label.add_theme_color_override("font_color", XCARLET_COLOR)
	speaker_panel.add_child(speaker_label)

	dialogue_label = Label.new()
	dialogue_label.position = Vector2(40.0, 20.0)
	dialogue_label.size = Vector2(1520.0, 155.0)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.add_theme_font_size_override("font_size", 42)
	if fredoka_font:
		dialogue_label.add_theme_font_override("font", fredoka_font)
	dialogue_label.add_theme_color_override("font_color", TEXT_COLOR)
	dialogue_panel.add_child(dialogue_label)

	pencil_player = AudioStreamPlayer.new()
	pencil_player.volume_db = -4.0
	add_child(pencil_player)


func _process(_delta: float) -> void:
	var m_pos := get_global_mouse_position()
	cursor_dot.size = Vector2.ONE * maxf(jammy_brush_width + 4.0, 8.0)
	cursor_dot.position = m_pos - cursor_dot.size * 0.5
	cursor_dot.visible = PAPER_RECT.has_point(m_pos) and not is_xcarlet_turn


func _unhandled_input(event: InputEvent) -> void:
	if is_xcarlet_turn:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_jammy_stroke(event.position)
			else:
				_finish_jammy_stroke()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_undo_last_stroke()

	elif event is InputEventMouseMotion and is_drawing:
		_update_jammy_stroke(event.position)

	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_SPACE:
				_on_pass_turn_pressed()
			KEY_Z:
				_undo_last_stroke()
			KEY_C:
				_clear_paper()
			KEY_1:
				jammy_brush_width = 4.5
			KEY_2:
				jammy_brush_width = 8.0
			KEY_3:
				jammy_brush_width = 14.0


func _clamp_to_paper(pos: Vector2) -> Vector2:
	var margin := 34.0
	return Vector2(
		clampf(pos.x, PAPER_RECT.position.x + margin, PAPER_RECT.end.x - margin),
		clampf(pos.y, PAPER_RECT.position.y + margin, PAPER_RECT.end.y - margin)
	)


func _create_styled_line(ink_color: Color, width: float, artistic_taper: bool = false) -> Line2D:
	var line := Line2D.new()
	line.default_color = ink_color
	line.width = width
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true

	var taper := Curve.new()
	if artistic_taper:
		taper.add_point(Vector2(0.0, 0.2))
		taper.add_point(Vector2(0.18, 1.0))
		taper.add_point(Vector2(0.82, 0.95))
		taper.add_point(Vector2(1.0, 0.15))
	else:
		taper.add_point(Vector2(0.0, 0.75))
		taper.add_point(Vector2(0.5, 1.0))
		taper.add_point(Vector2(1.0, 0.75))
	line.width_curve = taper

	strokes_container.add_child(line)
	return line


func _smooth_curve(control_pts: Array[Vector2], tension: float = 0.45) -> PackedVector2Array:
	if control_pts.size() < 2:
		return PackedVector2Array(control_pts)

	var curve := Curve2D.new()
	curve.bake_interval = 14.0
	var count := control_pts.size()

	for i in range(count):
		var pt := _clamp_to_paper(control_pts[i])
		var in_handle := Vector2.ZERO
		var out_handle := Vector2.ZERO

		if i == 0:
			out_handle = (control_pts[1] - control_pts[0]) * (tension * 0.5)
		elif i == count - 1:
			in_handle = -(control_pts[count - 1] - control_pts[count - 2]) * (tension * 0.5)
		else:
			var tangent := (control_pts[i + 1] - control_pts[i - 1]) * (tension * 0.5)
			in_handle = -tangent
			out_handle = tangent

		curve.add_point(pt, in_handle, out_handle)

	var baked := curve.get_baked_points()
	var clamped_baked := PackedVector2Array()
	for p in baked:
		clamped_baked.append(_clamp_to_paper(p))
	return clamped_baked


func _start_jammy_stroke(raw_pos: Vector2) -> void:
	if not PAPER_RECT.has_point(raw_pos):
		return

	is_drawing = true
	stroke_step_counter = 0
	stroke_start_point = _clamp_to_paper(raw_pos)

	current_line = _create_styled_line(JAMMY_INK, jammy_brush_width, false)
	current_line.add_point(stroke_start_point)
	_play_pencil_tick(1.0)


func _update_jammy_stroke(raw_pos: Vector2) -> void:
	if current_line == null:
		return

	var clamped := _clamp_to_paper(raw_pos)

	if Input.is_key_pressed(KEY_SHIFT):
		if current_line.get_point_count() == 1:
			current_line.add_point(clamped)
		else:
			current_line.set_point_position(1, clamped)
		return

	var last_pt := current_line.get_point_position(current_line.get_point_count() - 1)
	if last_pt.distance_to(clamped) >= 6.0:
		current_line.add_point(clamped)
		stroke_step_counter += 1
		if stroke_step_counter % 6 == 0:
			_play_pencil_tick(randf_range(0.92, 1.08))


func _finish_jammy_stroke() -> void:
	if not is_drawing or current_line == null:
		return

	is_drawing = false
	if current_line.get_point_count() < 2:
		current_line.queue_free()
	else:
		all_strokes.append(current_line)
		pending_jammy_strokes.append(current_line)
	current_line = null


func _undo_last_stroke() -> void:
	if is_drawing or all_strokes.is_empty():
		return

	var last_line: Line2D = all_strokes.pop_back()
	pending_jammy_strokes.erase(last_line)
	last_line.queue_free()


func _clear_paper() -> void:
	if is_drawing:
		return
	for s in all_strokes:
		if is_instance_valid(s):
			s.queue_free()
	all_strokes.clear()
	pending_jammy_strokes.clear()


func _on_pass_turn_pressed() -> void:
	if is_xcarlet_turn or is_drawing:
		return

	if pending_jammy_strokes.is_empty():
		_show_dialogue("Xcarlet", "Draw something on the paper first so I can build on it!", XCARLET_COLOR)
		return

	_run_adaptive_xcarlet_turn()


# ==============================================================================
# CEREBRO ADAPTATIVO: DETECTA PAISAJES, RETRATOS, MEDIAS FIGURAS Y ESPACIOS LIBRES
# ==============================================================================
func _run_adaptive_xcarlet_turn() -> void:
	is_xcarlet_turn = true
	pass_turn_button.disabled = true
	pass_turn_button.text = "Xcarlet is sketching..."

	var valid_strokes: Array[Line2D] = []
	for s in pending_jammy_strokes:
		if is_instance_valid(s) and s.get_point_count() >= 2:
			valid_strokes.append(s)
	pending_jammy_strokes.clear()

	if valid_strokes.is_empty():
		is_xcarlet_turn = false
		pass_turn_button.disabled = false
		pass_turn_button.text = "Let Xcarlet Complete [ENTER]"
		return

	var first_pt := valid_strokes[0].get_point_position(0)
	var min_pt := first_pt
	var max_pt := first_pt
	var total_length := 0.0
	var horizontal_strokes := 0

	for s in valid_strokes:
		var pts := s.points
		var s_min := pts[0]
		var s_max := pts[0]
		for i in range(pts.size()):
			min_pt = min_pt.min(pts[i])
			max_pt = max_pt.max(pts[i])
			s_min = s_min.min(pts[i])
			s_max = s_max.max(pts[i])
			if i > 0:
				total_length += pts[i - 1].distance_to(pts[i])
		var s_size := s_max - s_min
		if s_size.x > s_size.y * 1.25 and s_size.x > 180.0:
			horizontal_strokes += 1

	var cluster_rect := Rect2(min_pt, max_pt - min_pt)
	var stroke_count := valid_strokes.size()
	var aspect := cluster_rect.size.x / maxf(cluster_rect.size.y, 1.0)

	var detail_level := 1
	if stroke_count >= 7 or total_length >= 3000.0:
		detail_level = 3
	elif stroke_count >= 3 or total_length >= 1400.0:
		detail_level = 2

	# 1. Media figura abierta en 1 trazo (medio corazón, media ala, media estrella)
	if stroke_count == 1:
		var pts := valid_strokes[0].points
		var stats := _analyze_single_stroke(pts)
		if stats["is_open"] and stats["chord_len"] > 130.0 and stats["max_bulge"] > 48.0 and aspect < 1.35:
			_show_dialogue("Xcarlet", "Ooh, a half-shape! Let me mirror the other side for you.", XCARLET_COLOR)
			await _draw_mirrored_half(pts, detail_level)
			_finish_xcarlet_turn(detail_level)
			return

	# 2. Paisaje (montañas, río, horizonte ancho o varios trazos horizontales)
	if aspect >= 1.40 or horizontal_strokes >= 2 or cluster_rect.size.x >= 950.0:
		_show_dialogue("Xcarlet", "A scenic landscape! Let me add a sun, clouds, and some life to the sky.", XCARLET_COLOR)
		await _draw_scenic_landscape(valid_strokes, cluster_rect, detail_level)

	# 3. Retrato / personaje (proporción cuadrada o vertical con varios trazos)
	elif stroke_count >= 2 and aspect > 0.52 and aspect < 1.40 and cluster_rect.size.x > 110.0:
		if detail_level >= 2:
			_show_dialogue("Xcarlet", "Nice character! I'll add flowing hair, bangs, and shoulders.", XCARLET_COLOR)
		else:
			_show_dialogue("Xcarlet", "A quick character sketch! Let me add soft hair and shoulders.", XCARLET_COLOR)
		await _draw_character_adaptive(cluster_rect, detail_level)

	# 4. Boceto libre -> detalles sutiles en los huecos libres (sin encerrar en óvalos gigantes)
	else:
		_show_dialogue("Xcarlet", "I love the movement in your lines—let me add a few delicate accents around it!", XCARLET_COLOR)
		await _draw_subtle_accents(cluster_rect, detail_level)

	_finish_xcarlet_turn(detail_level)


func _finish_xcarlet_turn(detail_level: int) -> void:
	is_xcarlet_turn = false
	pass_turn_button.disabled = false
	pass_turn_button.text = "Let Xcarlet Complete [ENTER]"
	if detail_level >= 2:
		_show_dialogue("Jammy", "*She actually read the whole scene and completed what was missing...*", JAMMY_COLOR, true)
	else:
		_show_dialogue("Jammy", "*Even on a quick sketch, her lines look so effortless.*", JAMMY_COLOR, true)


func _analyze_single_stroke(pts: PackedVector2Array) -> Dictionary:
	var p_start := pts[0]
	var p_end := pts[pts.size() - 1]
	var chord_vec := p_end - p_start
	var chord_len := chord_vec.length()
	var axis := chord_vec.normalized() if chord_len > 0.001 else Vector2.RIGHT

	var path_len := 0.0
	var max_bulge := 0.0
	for i in range(pts.size()):
		if i > 0:
			path_len += pts[i - 1].distance_to(pts[i])
		var rel := pts[i] - p_start
		var proj := axis * rel.dot(axis)
		var perp_dist := (rel - proj).length()
		if perp_dist > max_bulge:
			max_bulge = perp_dist

	var is_open := chord_len > 90.0 and (chord_len / maxf(path_len, 1.0)) > 0.24
	return {
		"chord_len": chord_len,
		"path_len": path_len,
		"max_bulge": max_bulge,
		"is_open": is_open
	}


# --- PAISAJE INTELIGENTE (SOL, RAYOS, NUBES, AVES Y DETALLES EN EL AGUA) ---
func _draw_scenic_landscape(strokes: Array[Line2D], rect: Rect2, detail: int) -> void:
	var cx := rect.get_center().x
	# Detectar qué lado del cielo tiene menos trazos altos para colocar el sol sin encimarlo
	var left_highest_y := PAPER_RECT.end.y
	var right_highest_y := PAPER_RECT.end.y
	for s in strokes:
		for p in s.points:
			if p.x < cx:
				left_highest_y = minf(left_highest_y, p.y)
			else:
				right_highest_y = minf(right_highest_y, p.y)

	var sun_on_right := right_highest_y >= left_highest_y
	var sun_x := rect.end.x - rect.size.x * 0.14 if sun_on_right else rect.position.x + rect.size.x * 0.14
	var cloud_x := rect.position.x + rect.size.x * 0.22 if sun_on_right else rect.end.x - rect.size.x * 0.22

	var sky_y := clampf(rect.position.y - 55.0, PAPER_RECT.position.y + 110.0, PAPER_RECT.position.y + 420.0)

	# 1. Sol en el cielo despejado
	var sun_center := _clamp_to_paper(Vector2(sun_x, sky_y))
	var sun_r := 52.0
	var sun_pts: Array[Vector2] = []
	for i in range(13):
		var a := (float(i) / 12.0) * TAU
		sun_pts.append(sun_center + Vector2(cos(a), sin(a)) * sun_r)
	await _animate_xcarlet_stroke(_smooth_curve(sun_pts, 0.52), 7.0)

	# Rayos del sol
	var ray_count := 7 if detail >= 2 else 5
	for i in range(ray_count):
		var a := (float(i) / float(ray_count)) * TAU + 0.2
		var dir := Vector2(cos(a), sin(a))
		var ray := PackedVector2Array([
			_clamp_to_paper(sun_center + dir * (sun_r + 16.0)),
			_clamp_to_paper(sun_center + dir * (sun_r + 44.0))
		])
		await _animate_xcarlet_stroke(ray, 5.0)

	# 2. Nube esponjosa en el lado opuesto del cielo
	var cloud_c := _clamp_to_paper(Vector2(cloud_x, sky_y + 20.0))
	var cloud := _smooth_curve([
		cloud_c + Vector2(-115, 22),
		cloud_c + Vector2(-95, -18),
		cloud_c + Vector2(-42, -32),
		cloud_c + Vector2(-8, -52),
		cloud_c + Vector2(45, -42),
		cloud_c + Vector2(92, -16),
		cloud_c + Vector2(115, 22),
		cloud_c + Vector2(0, 28),
		cloud_c + Vector2(-115, 22)
	], 0.5)
	await _animate_xcarlet_stroke(cloud, 6.5)

	# 3. Aves volando cerca de las cumbres
	var bird_base := _clamp_to_paper(Vector2(cx, sky_y + 35.0))
	await _draw_bird(bird_base, 34.0)
	if detail >= 2:
		await _draw_bird(bird_base + Vector2(85.0, -32.0), 25.0)

	# 4. Si el dibujo es elaborado, agrega reflejos en el río/suelo y un pino en la orilla
	if detail >= 2:
		var ripple_y := clampf(rect.end.y - rect.size.y * 0.14, PAPER_RECT.position.y + 200.0, PAPER_RECT.end.y - 70.0)
		var ripple := _smooth_curve([
			Vector2(cx - 140.0, ripple_y),
			Vector2(cx - 45.0, ripple_y + 12.0),
			Vector2(cx + 55.0, ripple_y + 6.0),
			Vector2(cx + 150.0, ripple_y - 8.0)
		], 0.5)
		await _animate_xcarlet_stroke(ripple, 5.0)


func _draw_bird(center: Vector2, wing_span: float) -> void:
	var left_wing := _smooth_curve([
		center + Vector2(-wing_span, -wing_span * 0.25),
		center + Vector2(-wing_span * 0.45, -wing_span * 0.45),
		center
	], 0.5)
	var right_wing := _smooth_curve([
		center,
		center + Vector2(wing_span * 0.45, -wing_span * 0.45),
		center + Vector2(wing_span, -wing_span * 0.25)
	], 0.5)
	await _animate_xcarlet_stroke(left_wing, 5.0)
	await _animate_xcarlet_stroke(right_wing, 5.0)


# --- PERSONAJE CON CURVAS ORGÁNICAS ---
func _draw_character_adaptive(rect: Rect2, detail: int) -> void:
	var cx := rect.get_center().x
	var top_y := rect.position.y
	var bot_y := rect.end.y
	var w := rect.size.x
	var h := rect.size.y

	var outer_hair := _smooth_curve([
		Vector2(rect.position.x - w * 0.24, bot_y + h * 0.22),
		Vector2(rect.position.x - w * 0.28, top_y + h * 0.35),
		Vector2(rect.position.x - w * 0.12, top_y - h * 0.26),
		Vector2(cx, top_y - h * 0.34),
		Vector2(rect.end.x + w * 0.12, top_y - h * 0.26),
		Vector2(rect.end.x + w * 0.28, top_y + h * 0.35),
		Vector2(rect.end.x + w * 0.24, bot_y + h * 0.22)
	], 0.55)
	await _animate_xcarlet_stroke(outer_hair, 8.5)

	var bangs := _smooth_curve([
		Vector2(rect.position.x - w * 0.05, top_y + h * 0.26),
		Vector2(cx - w * 0.22, top_y + h * 0.06),
		Vector2(cx - w * 0.06, top_y + h * 0.24),
		Vector2(cx + w * 0.04, top_y + h * 0.04),
		Vector2(cx + w * 0.20, top_y + h * 0.23),
		Vector2(rect.end.x + w * 0.05, top_y + h * 0.16)
	], 0.45)
	await _animate_xcarlet_stroke(bangs, 6.5)

	var left_shoulder := _smooth_curve([
		Vector2(cx - w * 0.15, bot_y + h * 0.02),
		Vector2(cx - w * 0.22, bot_y + h * 0.24),
		Vector2(cx - w * 0.55, bot_y + h * 0.38),
		Vector2(cx - w * 0.85, bot_y + h * 0.62)
	], 0.5)
	var right_shoulder := _smooth_curve([
		Vector2(cx + w * 0.15, bot_y + h * 0.02),
		Vector2(cx + w * 0.22, bot_y + h * 0.24),
		Vector2(cx + w * 0.55, bot_y + h * 0.38),
		Vector2(cx + w * 0.85, bot_y + h * 0.62)
	], 0.5)
	await _animate_xcarlet_stroke(left_shoulder, 8.0)
	await _animate_xcarlet_stroke(right_shoulder, 8.0)

	if detail >= 2:
		var inner_lock_l := _smooth_curve([
			Vector2(rect.position.x - w * 0.12, top_y + h * 0.18),
			Vector2(rect.position.x - w * 0.16, bot_y + h * 0.05),
			Vector2(rect.position.x - w * 0.06, bot_y + h * 0.32)
		], 0.5)
		var inner_lock_r := _smooth_curve([
			Vector2(rect.end.x + w * 0.12, top_y + h * 0.18),
			Vector2(rect.end.x + w * 0.16, bot_y + h * 0.05),
			Vector2(rect.end.x + w * 0.06, bot_y + h * 0.32)
		], 0.5)
		var collar := _smooth_curve([
			Vector2(cx - w * 0.24, bot_y + h * 0.22),
			Vector2(cx, bot_y + h * 0.36),
			Vector2(cx + w * 0.24, bot_y + h * 0.22)
		], 0.5)
		await _animate_xcarlet_stroke(inner_lock_l, 5.5)
		await _animate_xcarlet_stroke(inner_lock_r, 5.5)
		await _animate_xcarlet_stroke(collar, 6.0)


# --- ESPEJO SUAVE PARA MEDIAS FIGURAS ---
func _draw_mirrored_half(pts: PackedVector2Array, detail: int) -> void:
	var p_start := pts[0]
	var p_end := pts[pts.size() - 1]
	var axis := (p_end - p_start).normalized()
	var normal := Vector2(-axis.y, axis.x)

	var raw_mirror: Array[Vector2] = []
	for i in range(pts.size()):
		var p := pts[i]
		var v := p - p_start
		var proj := p_start + axis * v.dot(axis)
		var mirrored := 2.0 * proj - p
		if i > 0 and i < pts.size() - 1:
			mirrored += normal * sin(float(i) * 0.3) * 4.0
		raw_mirror.append(mirrored)

	await _animate_xcarlet_stroke(_smooth_curve(raw_mirror, 0.4), 8.5)

	if detail >= 2:
		var mid := p_start.lerp(p_end, 0.5)
		await _draw_curved_sparkle(mid + normal * 70.0, 24.0)


# --- DETALLES SUTILES SIN ÓVALOS GIGANTES ---
func _draw_subtle_accents(rect: Rect2, detail: int) -> void:
	await _draw_curved_sparkle(Vector2(rect.end.x + 48.0, rect.position.y - 20.0), 28.0)
	await _draw_curved_sparkle(Vector2(rect.position.x - 48.0, rect.end.y + 18.0), 22.0)

	if detail >= 2:
		var cx := rect.get_center().x
		var flourish := _smooth_curve([
			Vector2(cx - 110.0, rect.end.y + 38.0),
			Vector2(cx, rect.end.y + 62.0),
			Vector2(cx + 110.0, rect.end.y + 38.0)
		], 0.55)
		await _animate_xcarlet_stroke(flourish, 5.5)


func _draw_curved_sparkle(center: Vector2, radius: float) -> void:
	var star := _smooth_curve([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.22, -radius * 0.22),
		center + Vector2(radius, 0.0),
		center + Vector2(radius * 0.22, radius * 0.22),
		center + Vector2(0.0, radius),
		center + Vector2(-radius * 0.22, radius * 0.22),
		center + Vector2(-radius, 0.0),
		center + Vector2(-radius * 0.22, -radius * 0.22),
		center + Vector2(0.0, -radius)
	], 0.35)
	await _animate_xcarlet_stroke(star, 5.0)


func _animate_xcarlet_stroke(target_points: PackedVector2Array, width: float = 8.0) -> void:
	if target_points.size() < 2:
		return

	var line := _create_styled_line(XCARLET_INK, width, true)
	all_strokes.append(line)

	var step_delay := clampf(0.45 / float(target_points.size()), 0.006, 0.022)
	for i in range(target_points.size()):
		line.add_point(target_points[i])
		if i % 5 == 0:
			_play_pencil_tick(randf_range(1.12, 1.25))
		await get_tree().create_timer(step_delay).timeout


func _play_pencil_tick(pitch: float) -> void:
	if pencil_stream == null:
		return
	pencil_player.pitch_scale = pitch
	pencil_player.play()


func _show_dialogue(speaker: String, text: String, border_col: Color, is_thought: bool = false) -> void:
	speaker_label.text = speaker
	speaker_label.add_theme_color_override("font_color", border_col)
	speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, border_col))
	dialogue_panel.add_theme_stylebox_override("panel", _make_box_style(PANEL_COLOR, border_col))

	dialogue_label.text = text
	if is_thought and rock_salt_font:
		dialogue_label.add_theme_font_override("font", rock_salt_font)
		dialogue_label.add_theme_font_size_override("font_size", 32)
	elif fredoka_font:
		dialogue_label.add_theme_font_override("font", fredoka_font)
		dialogue_label.add_theme_font_size_override("font_size", 42)


func _make_box_style(bg_col: Color, border_col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.border_color = Color(border_col.r, border_col.g, border_col.b, 0.75)
	s.set_border_width_all(3)
	s.set_corner_radius_all(18)
	return s


func _make_speaker_style(bg_col: Color, border_col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.border_color = Color(border_col.r, border_col.g, border_col.b, 0.85)
	s.border_width_left = 3
	s.border_width_top = 3
	s.border_width_right = 3
	s.border_width_bottom = 0
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	return s
