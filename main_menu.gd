extends Control

const BASE_SIZE := Vector2(3840.0, 2160.0)
const FREDOKA_FONT = preload("res://fonts/Fredoka-Regular.ttf")
const ROCK_SALT_FONT = preload("res://fonts/RockSalt-Regular.ttf")

@export_file("*.tscn") var first_game_scene: String = "res://visual_novel.tscn"

const INTRUSIVE_POOL: Array[String] = [
	"*You are an ungrateful clown.*",
	"*Everyone is pretending to tolerate you.*",
	"*You don't even know if your feelings are real or just OCD.*",
	"*You'll never enjoy a normal life.*",
	"*Smile so nobody notices how broken you are.*",
	"*You're going against nature.*",
	"*I wish I had never been born.*",
	"*You're a burden to everyone around you.*",
	"*Even your happiest moments are stained.*",
	"*Nobody will ever truly stay with you.*"
]

var whispers_layer: Control
var eyes_canvas: Control
var eye_openness: float = 1.0
var eye_twitch: Vector2 = Vector2.ZERO
var slots_panel: Panel
var slots_scroll: ScrollContainer
var slots_vbox: VBoxContainer
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "MainMenu"
	rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	first_game_scene = _resolve_first_game_scene()
	_build_ui()

	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr != null:
		if save_mgr.has_signal("slot_deleted") and not save_mgr.slot_deleted.is_connected(_on_save_changed):
			save_mgr.slot_deleted.connect(_on_save_changed)
		if save_mgr.has_signal("save_completed") and not save_mgr.save_completed.is_connected(_on_save_changed):
			save_mgr.save_completed.connect(_on_save_changed)

	_spawn_intrusive_whispers_loop()
	_blink_eyes_loop()


func _on_save_changed(_slot: int = -1) -> void:
	_refresh_slots_ui()


func _resolve_first_game_scene() -> String:
	var current_menu_path := scene_file_path
	if not first_game_scene.is_empty() and first_game_scene != current_menu_path and ResourceLoader.exists(first_game_scene):
		return first_game_scene

	var by_script := _find_scene_with_script("res://", "visual_novel.gd", current_menu_path)
	if by_script.is_empty():
		by_script = _find_scene_with_script("res://", "novela_visual.gd", current_menu_path)
	if not by_script.is_empty():
		return by_script

	var candidates := [
		"res://visual_novel.tscn",
		"res://scenes/visual_novel.tscn",
		"res://Visual_Novel.tscn",
		"res://scenes/VisualNovel.tscn",
		"res://novela_visual.tscn",
		"res://scenes/novela_visual.tscn"
	]
	for path in candidates:
		if path != current_menu_path and ResourceLoader.exists(path):
			return path

	var vn_script_path := _find_file_recursive("res://", "visual_novel.gd")
	if not vn_script_path.is_empty() and ResourceLoader.exists(vn_script_path):
		var target_tscn := "res://visual_novel.tscn"
		if target_tscn == current_menu_path:
			target_tscn = "res://visual_novel_chapter1.tscn"

		var root := Control.new()
		root.name = "VisualNovel"
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.set_script(load(vn_script_path))

		var packed := PackedScene.new()
		if packed.pack(root) == OK and ResourceSaver.save(packed, target_tscn) == OK:
			root.free()
			return target_tscn
		root.free()

	return ""


func _find_file_recursive(dir_path: String, target_file: String) -> String:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var subdirs: Array[String] = []

	while file_name != "":
		if not file_name.begins_with("."):
			var full := dir_path.path_join(file_name)
			if dir.current_is_dir():
				subdirs.append(full)
			elif file_name.to_lower() == target_file.to_lower():
				dir.list_dir_end()
				return full
		file_name = dir.get_next()

	dir.list_dir_end()
	for sub in subdirs:
		var res := _find_file_recursive(sub, target_file)
		if not res.is_empty():
			return res
	return ""


func _find_scene_with_script(dir_path: String, target_script_name: String, exclude_scene: String) -> String:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var subdirs: Array[String] = []

	while file_name != "":
		if not file_name.begins_with("."):
			var full := dir_path.path_join(file_name)
			if dir.current_is_dir():
				subdirs.append(full)
			elif file_name.get_extension().to_lower() == "tscn" and full != exclude_scene:
				var txt := FileAccess.get_file_as_string(full)
				if target_script_name.to_lower() in txt.to_lower():
					dir.list_dir_end()
					return full
		file_name = dir.get_next()

	dir.list_dir_end()
	for sub in subdirs:
		var res := _find_scene_with_script(sub, target_script_name, exclude_scene)
		if not res.is_empty():
			return res
	return ""


func _process(delta: float) -> void:
	if rng.randf() < 0.08:
		eye_twitch = Vector2(rng.randf_range(-5.5, 5.5), rng.randf_range(-3.0, 3.0))
	else:
		eye_twitch = eye_twitch.lerp(Vector2.ZERO, 14.0 * delta)

	if is_instance_valid(eyes_canvas):
		eyes_canvas.queue_redraw()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.size = BASE_SIZE
	bg.color = Color("#050507")
	add_child(bg)

	whispers_layer = Control.new()
	whispers_layer.size = BASE_SIZE
	whispers_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(whispers_layer)

	eyes_canvas = Control.new()
	eyes_canvas.position = Vector2(BASE_SIZE.x * 0.5 - 520.0, 210.0)
	eyes_canvas.size = Vector2(1040.0, 300.0)
	eyes_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eyes_canvas.draw.connect(_on_eyes_canvas_draw)
	add_child(eyes_canvas)

	var title_lbl := Label.new()
	title_lbl.position = Vector2(0.0, 560.0)
	title_lbl.size = Vector2(BASE_SIZE.x, 210.0)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.text = "YELLOW IS SADDER THAN DARK"
	title_lbl.add_theme_font_size_override("font_size", 88)
	title_lbl.add_theme_font_override("font", ROCK_SALT_FONT)
	title_lbl.add_theme_color_override("font_color", Color("#f5d08a"))
	title_lbl.add_theme_constant_override("outline_size", 10)
	title_lbl.add_theme_color_override("font_outline_color", Color("#000000"))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.85, 0.12, 0.16, 0.45))
	title_lbl.add_theme_constant_override("shadow_offset_x", 5)
	title_lbl.add_theme_constant_override("shadow_offset_y", 7)
	add_child(title_lbl)

	var menu_vbox := VBoxContainer.new()
	menu_vbox.position = Vector2(BASE_SIZE.x * 0.5 - 340.0, 880.0)
	menu_vbox.size = Vector2(680.0, 420.0)
	menu_vbox.add_theme_constant_override("separation", 32)
	add_child(menu_vbox)

	var btn_new := _make_menu_button("New Game")
	btn_new.pressed.connect(_on_new_game_pressed)
	menu_vbox.add_child(btn_new)

	var btn_load := _make_menu_button("Select Save")
	btn_load.pressed.connect(_on_toggle_slots_pressed)
	menu_vbox.add_child(btn_load)

	var btn_quit := _make_menu_button("Quit")
	btn_quit.pressed.connect(func() -> void: get_tree().quit())
	menu_vbox.add_child(btn_quit)

	var info_lbl := Label.new()
	info_lbl.position = Vector2(120.0, 2020.0)
	info_lbl.size = Vector2(BASE_SIZE.x - 240.0, 90.0)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_lbl.text = "Manual save on exit  •  Press [ESC] during gameplay to save or return to Main Menu"
	info_lbl.add_theme_font_size_override("font_size", 42)
	info_lbl.add_theme_font_override("font", FREDOKA_FONT)
	info_lbl.add_theme_color_override("font_color", Color("#e5e0d8"))
	info_lbl.add_theme_constant_override("outline_size", 5)
	info_lbl.add_theme_color_override("font_outline_color", Color("#000000"))
	add_child(info_lbl)

	slots_panel = Panel.new()
	slots_panel.position = Vector2(BASE_SIZE.x * 0.5 - 640.0, 1290.0)
	slots_panel.size = Vector2(1280.0, 700.0)
	slots_panel.visible = false
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.08, 0.10, 0.96)
	st.set_corner_radius_all(20)
	st.set_border_width_all(3)
	st.border_color = Color("#ff4d4d")
	slots_panel.add_theme_stylebox_override("panel", st)
	add_child(slots_panel)

	slots_scroll = ScrollContainer.new()
	slots_scroll.position = Vector2(44.0, 36.0)
	slots_scroll.size = Vector2(1192.0, 628.0)
	slots_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	slots_panel.add_child(slots_scroll)

	slots_vbox = VBoxContainer.new()
	slots_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_vbox.add_theme_constant_override("separation", 20)
	slots_scroll.add_child(slots_vbox)

	_refresh_slots_ui()


func _get_max_slots_count(save_mgr: Node) -> int:
	if save_mgr == null:
		return 6
	if save_mgr.has_method("get_max_slots"):
		return maxi(1, int(save_mgr.call("get_max_slots")))
	if "MAX_SLOTS" in save_mgr:
		return maxi(1, int(save_mgr.get("MAX_SLOTS")))
	return 6


func _delete_slot_and_refresh(save_mgr: Node, slot_idx: int) -> void:
	if save_mgr == null:
		return
	if save_mgr.has_method("borrar_slot"):
		save_mgr.call("borrar_slot", slot_idx)
	elif save_mgr.has_method("borrar_partida"):
		save_mgr.call("borrar_partida", slot_idx)
	elif save_mgr.has_method("eliminar_slot"):
		save_mgr.call("eliminar_slot", slot_idx)
	_refresh_slots_ui()


func _refresh_slots_ui() -> void:
	if not is_instance_valid(slots_vbox):
		return
	for child in slots_vbox.get_children():
		child.queue_free()

	var save_mgr := get_node_or_null("/root/SaveManager")
	var max_slots := _get_max_slots_count(save_mgr)

	for slot_idx in range(1, max_slots + 1):
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 18)
		slots_vbox.add_child(row)

		var info: Dictionary = {}
		if save_mgr != null and save_mgr.has_method("obtener_info_slot"):
			info = save_mgr.obtener_info_slot(slot_idx)

		var is_empty: bool = info.is_empty() or bool(info.get("vacio", info.get("empty", true)))

		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(0.0, 116.0)
		slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_btn.add_theme_font_size_override("font_size", 30)
		slot_btn.add_theme_font_override("font", FREDOKA_FONT)
		slot_btn.add_theme_color_override("font_color", Color("#fff9f0"))

		var slot_sb := StyleBoxFlat.new()
		slot_sb.bg_color = Color(0.14, 0.14, 0.18, 0.95)
		slot_sb.set_corner_radius_all(14)
		slot_sb.set_border_width_all(2)
		slot_sb.border_color = Color(1.0, 1.0, 1.0, 0.28) if is_empty else Color("#f5d08a")
		slot_btn.add_theme_stylebox_override("normal", slot_sb)

		if is_empty:
			slot_btn.text = "Slot %d  —  [Empty] (Start New Game)" % slot_idx
		else:
			var stage_str: String = str(info.get("stage_name", "Chapter %d" % int(info.get("chapter", 1))))
			var ts_str: String = str(info.get("timestamp", info.get("fecha", info.get("updated_at", ""))))
			slot_btn.text = "Slot %d  —  %s  (%s)" % [slot_idx, stage_str, ts_str]

		var captured_slot := slot_idx
		var captured_empty := is_empty
		slot_btn.pressed.connect(func() -> void:
			var target := _resolve_first_game_scene()
			if save_mgr == null:
				if not target.is_empty() and ResourceLoader.exists(target):
					get_tree().change_scene_to_file(target)
				return

			if captured_empty:
				if save_mgr.has_method("iniciar_nueva_partida"):
					save_mgr.iniciar_nueva_partida(target, captured_slot)
				elif not target.is_empty() and ResourceLoader.exists(target):
					get_tree().change_scene_to_file(target)
			else:
				if save_mgr.has_method("cargar_partida"):
					save_mgr.cargar_partida(captured_slot, target)
				else:
					var data: Dictionary = save_mgr.cargar_slot(captured_slot)
					var scene_path := str(data.get("scene_path", data.get("current_scene", target)))
					if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
						get_tree().change_scene_to_file(scene_path)
		)
		row.add_child(slot_btn)

		var del_btn := Button.new()
		del_btn.custom_minimum_size = Vector2(210.0, 116.0)
		del_btn.text = "Delete"
		del_btn.disabled = is_empty
		del_btn.add_theme_font_size_override("font_size", 30)
		del_btn.add_theme_font_override("font", FREDOKA_FONT)
		del_btn.add_theme_color_override("font_color", Color("#fff9f0") if not is_empty else Color(1.0, 1.0, 1.0, 0.35))

		var del_sb := StyleBoxFlat.new()
		del_sb.bg_color = Color(0.28, 0.10, 0.13, 0.95) if not is_empty else Color(0.11, 0.11, 0.13, 0.55)
		del_sb.set_corner_radius_all(14)
		del_sb.set_border_width_all(2)
		del_sb.border_color = Color("#ff4d4d") if not is_empty else Color(1.0, 1.0, 1.0, 0.15)
		del_btn.add_theme_stylebox_override("normal", del_sb)

		del_btn.pressed.connect(func() -> void:
			_delete_slot_and_refresh(save_mgr, captured_slot)
		)
		row.add_child(del_btn)


func _on_eyes_canvas_draw() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var center := BASE_SIZE * 0.5
	var look_offset := (mouse_pos - center).clamp(Vector2(-1100.0, -700.0), Vector2(1100.0, 700.0)) * 0.028 + eye_twitch

	var canvas_center := eyes_canvas.size * 0.5
	_draw_scary_eye(Vector2(canvas_center.x - 255.0, canvas_center.y), -1.0, eye_openness, look_offset)
	_draw_scary_eye(Vector2(canvas_center.x + 255.0, canvas_center.y), 1.0, eye_openness, look_offset)


func _draw_scary_eye(pos: Vector2, side: float, openness: float, look_offset: Vector2) -> void:
	var w: float = 165.0
	var h_top: float = 56.0 * openness
	var h_bot: float = 48.0 * openness
	var slant: float = 32.0 * side

	var eye_poly := PackedVector2Array([
		pos + Vector2(-w, slant * 0.45),
		pos + Vector2(-w * 0.35, -h_top + slant * 0.2),
		pos + Vector2(w * 0.35, -h_top - slant * 0.2),
		pos + Vector2(w, -slant * 0.75),
		pos + Vector2(w * 0.4, h_bot - slant * 0.2),
		pos + Vector2(-w * 0.4, h_bot + slant * 0.2),
		pos + Vector2(-w, slant * 0.45)
	])

	eyes_canvas.draw_colored_polygon(eye_poly, Color("#1f0204"))

	if openness > 0.18:
		var pupil_center: Vector2 = pos + look_offset * Vector2(1.0, 0.45 * openness)
		var rx: float = 14.0
		var ry: float = 36.0 * openness
		var pupil_pts := PackedVector2Array()
		for i in range(24):
			var a: float = (float(i) / 24.0) * TAU
			pupil_pts.append(pupil_center + Vector2(cos(a) * rx, sin(a) * ry))
		eyes_canvas.draw_colored_polygon(pupil_pts, Color("#ff1e26"))
		eyes_canvas.draw_circle(pupil_center + Vector2(-4.0, -9.0 * openness), 3.4, Color(1.0, 0.88, 0.88, 0.9))

	eyes_canvas.draw_polyline(eye_poly, Color("#ff2a2a"), 5.5, true)


func _make_menu_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(680.0, 110.0)
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", 42)
	btn.add_theme_font_override("font", FREDOKA_FONT)
	btn.add_theme_color_override("font_color", Color("#fff9f0"))
	btn.add_theme_color_override("font_hover_color", Color("#f5d08a"))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.12, 0.15, 0.90)
	normal.set_corner_radius_all(18)
	normal.set_border_width_all(3)
	normal.border_color = Color("#f5d08a")
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.10, 0.12, 0.95)
	hover.set_corner_radius_all(18)
	hover.set_border_width_all(4)
	hover.border_color = Color("#ff2a2a")
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	return btn


func _spawn_intrusive_whispers_loop() -> void:
	while is_inside_tree():
		var lbl := Label.new()
		lbl.text = INTRUSIVE_POOL[rng.randi_range(0, INTRUSIVE_POOL.size() - 1)]
		lbl.add_theme_font_override("font", ROCK_SALT_FONT)
		lbl.add_theme_font_size_override("font_size", rng.randi_range(28, 46))
		lbl.add_theme_color_override("font_color", Color(1.0, 0.22, 0.25, 0.0))
		lbl.position = Vector2(rng.randf_range(120.0, 2600.0), rng.randf_range(100.0, 1850.0))
		lbl.rotation_degrees = rng.randf_range(-10.0, 10.0)
		whispers_layer.add_child(lbl)

		var tw := create_tween()
		tw.tween_property(lbl, "modulate:a", rng.randf_range(0.35, 0.75), 0.8)
		tw.tween_interval(rng.randf_range(1.2, 2.5))
		tw.tween_property(lbl, "modulate:a", 0.0, 1.0)
		tw.finished.connect(lbl.queue_free)

		await get_tree().create_timer(rng.randf_range(0.65, 1.35)).timeout


func _blink_eyes_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(rng.randf_range(2.6, 5.2)).timeout
		if not is_inside_tree():
			return
		var tw := create_tween()
		tw.tween_property(self, "eye_openness", 0.05, 0.07)
		await tw.finished
		var tw_open := create_tween()
		tw_open.tween_property(self, "eye_openness", 1.0, 0.11)


func _on_new_game_pressed() -> void:
	var target := _resolve_first_game_scene()
	if target.is_empty() or not ResourceLoader.exists(target):
		push_error("No se encontró visual_novel.gd en el proyecto.")
		return

	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr != null and save_mgr.has_method("iniciar_nueva_partida"):
		save_mgr.iniciar_nueva_partida(target, -1)
	elif is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file(target)


func _on_toggle_slots_pressed() -> void:
	slots_panel.visible = not slots_panel.visible
	if slots_panel.visible:
		_refresh_slots_ui()
