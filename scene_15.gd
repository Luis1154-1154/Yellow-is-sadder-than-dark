extends Node2D

const BASE_SIZE := Vector2(3840.0, 2160.0)
const TEXT_COLOR := Color("#fff9f0")
const PANEL_COLOR := Color(0.22, 0.23, 0.25, 0.50)
const MIND_PANEL_COLOR := Color(0.18, 0.18, 0.20, 0.56)
const SPEAKER_BG_COLOR := Color(0.18, 0.19, 0.21, 0.68)
const MIND_COLOR := Color("#ff5a5f")
const ACCENT_COLOR := Color("#fff9f0")
const GOLD_ACCENT := Color("#f5d08a")

# Colores por personaje
const JAMMY_COLOR := Color("#f5d08a")
const LEON_COLOR := Color("#e5df88")
const XCARLET_COLOR := Color("#5bc0eb")

# Tamaño estándar y posiciones (3840x2160)
const DIALOGUE_PANEL_SIZE := Vector2(1240.0, 230.0)
const LEON_PANEL_POS := Vector2(1060.0, 230.0)         # Arriba de la cabeza de Leon (scene15)
const JAMMY_CENTER_POS := Vector2(1300.0, 960.0)       # Centro de pantalla (scene15)
const XCARLET_PANEL_POS := Vector2(2150.0, 220.0)      # Arriba de la cabeza de Xcarlet (scene16)
const JAMMY_LEFT_CENTER_POS := Vector2(520.0, 960.0)   # Centro-izquierda para no tapar a Xcarlet (scene16)
const SPEAKER_PANEL_SIZE := Vector2(320.0, 62.0)

const FREDOKA_FONT = preload("res://fonts/Fredoka-Regular.ttf")
const ROCK_SALT_FONT = preload("res://fonts/RockSalt-Regular.ttf")
const NORMAL_DIALOGUE_STREAM = preload("res://assets/sounds/Soft_pencil_tap_on_n_#1-1794378651940.mp3")
const BREATHING_STREAM = preload("res://assets/sounds/breathing1.mp3")
const HEARTBEAT_STREAM = preload("res://assets/sounds/Hbeating1.mp3")

@export_file("*.tscn") var next_scene_path: String = "res://Level3.tscn"

var ui_root: Control
var background: TextureRect
var black_background: ColorRect
var eye_open_overlay: ColorRect
var dialogue_panel: Panel
var dialogue_label: Label
var speaker_panel: Panel
var speaker_label: Label
var continue_panel: PanelContainer
var continue_label: Label

# Recordatorio perpetuo de menú + modal de confirmación
var perpetual_hint_panel: PanelContainer
var perpetual_hint_label: Label
var leave_confirm_overlay: ColorRect
var leave_confirm_panel: PanelContainer
var leave_yes_btn: Button
var leave_no_btn: Button
var leave_dialog_open: bool = false

var typewriter_player: AudioStreamPlayer
var mind_breath_player: AudioStreamPlayer
var mind_heartbeat_player: AudioStreamPlayer
var typewriter_stream: AudioStream
var breath_stream: AudioStream
var heartbeat_stream: AudioStream

var entries: Array[Dictionary] = []
var entry_index := 0
var is_typing := false
var typing_token := 0
var displayed_words := 0
var current_words: PackedStringArray
var current_entry: Dictionary
var waiting_for_input := false
var ending_triggered := false


func _ready() -> void:
	name = "scene15"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_audio()
	_build_ui()
	_build_leave_confirm_ui()
	_build_script()
	_split_long_dialogues()
	_aplicar_guardado_cargado()
	_play_eye_open_fade()
	_show_entry()


func _obtener_slot_activo() -> int:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr == null:
		return 1
	for prop in ["slot_actual", "current_slot", "active_slot", "selected_slot"]:
		if prop in save_mgr:
			var val = save_mgr.get(prop)
			if typeof(val) == TYPE_INT and int(val) > 0:
				return int(val)
	return 1


func _aplicar_guardado_cargado() -> void:
	var extra_data: Dictionary = {}
	if get_tree().has_meta("loaded_save_extra"):
		var raw_meta = get_tree().get_meta("loaded_save_extra")
		if raw_meta is Dictionary:
			extra_data = raw_meta
		get_tree().remove_meta("loaded_save_extra")

	if extra_data.is_empty():
		var save_mgr := get_node_or_null("/root/SaveManager")
		if save_mgr != null and "extra_data" in save_mgr and save_mgr.extra_data is Dictionary:
			extra_data = save_mgr.extra_data

	var saved_idx: int = -1
	if extra_data.has("entry_index"):
		saved_idx = int(extra_data["entry_index"])
	elif extra_data.has("step"):
		saved_idx = int(extra_data["step"])

	if saved_idx >= 0 and entries.size() > 0:
		entry_index = clampi(saved_idx, 0, entries.size() - 1)


func _guardar_estado_actual() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr == null or not save_mgr.has_method("guardar_progreso"):
		return

	var scene_file: String = scene_file_path
	if scene_file.is_empty():
		var current_scene := get_tree().current_scene
		if current_scene != null:
			scene_file = current_scene.scene_file_path
	if scene_file.is_empty():
		return

	var etiqueta: String = "Scene 15 (%d/%d)" % [entry_index + 1, max(entries.size(), 1)]
	var extra_info: Dictionary = {
		"entry_index": entry_index,
		"step": entry_index
	}
	var slot_id: int = _obtener_slot_activo()

	var accepts_slot: bool = false
	for m in save_mgr.get_method_list():
		if str(m.get("name", "")) == "guardar_progreso":
			var args: Array = m.get("args", [])
			if args.size() >= 4:
				accepts_slot = true
			break

	if accepts_slot:
		save_mgr.call("guardar_progreso", scene_file, etiqueta, extra_info, slot_id)
	else:
		save_mgr.call("guardar_progreso", scene_file, etiqueta, extra_info)


func _set_continue_visible(visible_state: bool, hint_text: String = "ENTER TO CONTINUE") -> void:
	if continue_panel == null or continue_label == null:
		return
	continue_label.text = hint_text
	continue_panel.visible = visible_state
	continue_label.visible = visible_state
	if visible_state:
		continue_panel.anchor_left = 0.5
		continue_panel.anchor_right = 0.5
		continue_panel.anchor_top = 1.0
		continue_panel.anchor_bottom = 1.0
		continue_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		continue_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		continue_panel.reset_size()
		await get_tree().process_frame
		if not is_instance_valid(continue_panel) or not continue_panel.visible:
			return
		var panel_w: float = continue_panel.size.x
		var panel_h: float = continue_panel.size.y
		continue_panel.offset_left = -panel_w * 0.5
		continue_panel.offset_right = panel_w * 0.5
		continue_panel.offset_top = -panel_h - 45.0
		continue_panel.offset_bottom = -45.0
		continue_panel.move_to_front()


func _build_ui() -> void:
	ui_root = Control.new()
	ui_root.position = Vector2.ZERO
	ui_root.size = BASE_SIZE
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	black_background = ColorRect.new()
	black_background.position = Vector2.ZERO
	black_background.size = BASE_SIZE
	black_background.color = Color.BLACK
	black_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(black_background)

	background = TextureRect.new()
	background.position = Vector2.ZERO
	background.size = BASE_SIZE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.pivot_offset = BASE_SIZE / 2.0
	ui_root.add_child(background)

	# Recordatorio perpetuo minimalista: ESC → Start Menu
	perpetual_hint_panel = PanelContainer.new()
	perpetual_hint_panel.position = Vector2(BASE_SIZE.x - 560.0, 40.0)
	perpetual_hint_panel.z_index = 90
	perpetual_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var perp_sb := StyleBoxFlat.new()
	perp_sb.bg_color = Color(0.08, 0.08, 0.11, 0.92)
	perp_sb.set_corner_radius_all(14)
	perp_sb.border_width_left = 2
	perp_sb.border_width_top = 2
	perp_sb.border_width_right = 2
	perp_sb.border_width_bottom = 2
	perp_sb.border_color = Color(1.0, 0.98, 0.94, 0.45)
	perp_sb.content_margin_left = 24.0
	perp_sb.content_margin_right = 24.0
	perp_sb.content_margin_top = 10.0
	perp_sb.content_margin_bottom = 10.0
	perpetual_hint_panel.add_theme_stylebox_override("panel", perp_sb)
	ui_root.add_child(perpetual_hint_panel)

	perpetual_hint_label = Label.new()
	perpetual_hint_label.text = "ESC  →  Start Menu"
	perpetual_hint_label.add_theme_font_size_override("font_size", 28)
	perpetual_hint_label.add_theme_font_override("font", FREDOKA_FONT)
	perpetual_hint_label.add_theme_color_override("font_color", ACCENT_COLOR)
	perpetual_hint_label.add_theme_constant_override("outline_size", 4)
	perpetual_hint_label.add_theme_color_override("font_outline_color", Color("#08080a"))
	perpetual_hint_label.add_theme_color_override("font_shadow_color", Color("#000000f5"))
	perpetual_hint_label.add_theme_constant_override("shadow_offset_x", 2)
	perpetual_hint_label.add_theme_constant_override("shadow_offset_y", 2)
	perpetual_hint_panel.add_child(perpetual_hint_label)

	dialogue_panel = Panel.new()
	dialogue_panel.position = LEON_PANEL_POS
	dialogue_panel.size = DIALOGUE_PANEL_SIZE
	dialogue_panel.z_index = 10
	dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, Color(1.0, 1.0, 1.0, 0.22)))
	ui_root.add_child(dialogue_panel)

	speaker_panel = Panel.new()
	speaker_panel.position = Vector2(LEON_PANEL_POS.x + 36.0, LEON_PANEL_POS.y - SPEAKER_PANEL_SIZE.y + 2.0)
	speaker_panel.size = SPEAKER_PANEL_SIZE
	speaker_panel.z_index = 11
	speaker_panel.visible = false
	speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, LEON_COLOR))
	ui_root.add_child(speaker_panel)

	speaker_label = Label.new()
	speaker_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.add_theme_font_size_override("font_size", 36)
	speaker_label.add_theme_font_override("font", FREDOKA_FONT)
	speaker_label.add_theme_color_override("font_color", LEON_COLOR)
	speaker_label.add_theme_color_override("font_shadow_color", Color("#000000e6"))
	speaker_label.add_theme_constant_override("shadow_offset_x", 2)
	speaker_label.add_theme_constant_override("shadow_offset_y", 2)
	speaker_panel.add_child(speaker_label)

	dialogue_label = Label.new()
	dialogue_label.position = Vector2(44, 24)
	dialogue_label.size = Vector2(DIALOGUE_PANEL_SIZE.x - 88.0, DIALOGUE_PANEL_SIZE.y - 48.0)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.clip_text = false
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.add_theme_font_size_override("font_size", 46)
	dialogue_label.add_theme_font_override("font", FREDOKA_FONT)
	dialogue_label.add_theme_color_override("font_color", TEXT_COLOR)
	dialogue_label.add_theme_color_override("font_shadow_color", Color("#000000e6"))
	dialogue_label.add_theme_constant_override("shadow_offset_x", 4)
	dialogue_label.add_theme_constant_override("shadow_offset_y", 4)
	dialogue_panel.add_child(dialogue_label)

	# Recordatorio minimalista y legible al terminar el diálogo
	continue_panel = PanelContainer.new()
	continue_panel.anchor_left = 0.5
	continue_panel.anchor_right = 0.5
	continue_panel.anchor_top = 1.0
	continue_panel.anchor_bottom = 1.0
	continue_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	continue_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	continue_panel.z_index = 45
	continue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	continue_panel.add_theme_stylebox_override("panel", _make_hint_pill_style())
	continue_panel.visible = false
	ui_root.add_child(continue_panel)

	continue_label = Label.new()
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	continue_label.add_theme_font_size_override("font_size", 34)
	continue_label.add_theme_font_override("font", FREDOKA_FONT)
	continue_label.add_theme_color_override("font_color", ACCENT_COLOR)
	continue_label.add_theme_constant_override("outline_size", 5)
	continue_label.add_theme_color_override("font_outline_color", Color("#08080a"))
	continue_label.text = "ENTER TO CONTINUE"
	continue_label.visible = false
	continue_panel.add_child(continue_label)

	eye_open_overlay = ColorRect.new()
	eye_open_overlay.position = Vector2.ZERO
	eye_open_overlay.size = BASE_SIZE
	eye_open_overlay.color = Color.BLACK
	eye_open_overlay.z_index = 20
	eye_open_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(eye_open_overlay)

	typewriter_player = AudioStreamPlayer.new()
	typewriter_player.pitch_scale = 1.0
	typewriter_player.volume_db = 0.0
	add_child(typewriter_player)

	mind_breath_player = AudioStreamPlayer.new()
	add_child(mind_breath_player)

	mind_heartbeat_player = AudioStreamPlayer.new()
	mind_heartbeat_player.pitch_scale = 2.0
	add_child(mind_heartbeat_player)


func _build_leave_confirm_ui() -> void:
	leave_confirm_overlay = ColorRect.new()
	leave_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leave_confirm_overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	leave_confirm_overlay.z_index = 120
	leave_confirm_overlay.visible = false
	leave_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(leave_confirm_overlay)

	var center_box := CenterContainer.new()
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_box.mouse_filter = Control.MOUSE_FILTER_STOP
	leave_confirm_overlay.add_child(center_box)

	leave_confirm_panel = PanelContainer.new()
	leave_confirm_panel.custom_minimum_size = Vector2(1180.0, 440.0)
	leave_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var modal_sb := StyleBoxFlat.new()
	modal_sb.bg_color = Color(0.11, 0.12, 0.16, 0.98)
	modal_sb.set_corner_radius_all(24)
	modal_sb.border_width_left = 4
	modal_sb.border_width_top = 4
	modal_sb.border_width_right = 4
	modal_sb.border_width_bottom = 4
	modal_sb.border_color = Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.88)
	modal_sb.content_margin_left = 56.0
	modal_sb.content_margin_right = 56.0
	modal_sb.content_margin_top = 48.0
	modal_sb.content_margin_bottom = 48.0
	leave_confirm_panel.add_theme_stylebox_override("panel", modal_sb)
	center_box.add_child(leave_confirm_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 42)
	leave_confirm_panel.add_child(vb)

	var q_lbl := Label.new()
	q_lbl.text = "do you really want to leave ?"
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.add_theme_font_size_override("font_size", 54)
	q_lbl.add_theme_font_override("font", FREDOKA_FONT)
	q_lbl.add_theme_color_override("font_color", TEXT_COLOR)
	q_lbl.add_theme_constant_override("outline_size", 4)
	q_lbl.add_theme_color_override("font_outline_color", Color("#08080a"))
	vb.add_child(q_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 48)
	vb.add_child(btn_row)

	leave_yes_btn = Button.new()
	leave_yes_btn.text = "Yes  [SPACE]"
	leave_yes_btn.custom_minimum_size = Vector2(360.0, 96.0)
	leave_yes_btn.add_theme_font_size_override("font_size", 40)
	leave_yes_btn.add_theme_font_override("font", FREDOKA_FONT)
	var yes_sb := StyleBoxFlat.new()
	yes_sb.bg_color = Color(0.24, 0.14, 0.16, 0.96)
	yes_sb.set_corner_radius_all(16)
	yes_sb.border_width_left = 3
	yes_sb.border_width_top = 3
	yes_sb.border_width_right = 3
	yes_sb.border_width_bottom = 3
	yes_sb.border_color = MIND_COLOR
	leave_yes_btn.add_theme_stylebox_override("normal", yes_sb)
	leave_yes_btn.add_theme_stylebox_override("hover", yes_sb)
	leave_yes_btn.add_theme_color_override("font_color", TEXT_COLOR)
	leave_yes_btn.pressed.connect(_go_to_start_menu)
	btn_row.add_child(leave_yes_btn)

	leave_no_btn = Button.new()
	leave_no_btn.text = "No  [ESC]"
	leave_no_btn.custom_minimum_size = Vector2(360.0, 96.0)
	leave_no_btn.add_theme_font_size_override("font_size", 40)
	leave_no_btn.add_theme_font_override("font", FREDOKA_FONT)
	var no_sb := StyleBoxFlat.new()
	no_sb.bg_color = Color(0.16, 0.18, 0.23, 0.96)
	no_sb.set_corner_radius_all(16)
	no_sb.border_width_left = 3
	no_sb.border_width_top = 3
	no_sb.border_width_right = 3
	no_sb.border_width_bottom = 3
	no_sb.border_color = Color(1.0, 1.0, 1.0, 0.45)
	leave_no_btn.add_theme_stylebox_override("normal", no_sb)
	leave_no_btn.add_theme_stylebox_override("hover", no_sb)
	leave_no_btn.add_theme_color_override("font_color", TEXT_COLOR)
	leave_no_btn.pressed.connect(_close_leave_confirm)
	btn_row.add_child(leave_no_btn)


func _open_leave_confirm() -> void:
	if leave_dialog_open:
		return
	leave_dialog_open = true
	leave_confirm_overlay.visible = true
	leave_confirm_overlay.move_to_front()


func _close_leave_confirm() -> void:
	leave_dialog_open = false
	leave_confirm_overlay.visible = false


func _go_to_start_menu() -> void:
	_guardar_estado_actual()
	leave_dialog_open = false
	mind_heartbeat_player.stop()
	mind_breath_player.stop()
	typewriter_player.stop()

	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr != null and save_mgr.has_method("volver_al_inicio"):
		save_mgr.volver_al_inicio()
		return

	if ResourceLoader.exists("res://main.tscn"):
		get_tree().call_deferred("change_scene_to_file", "res://main.tscn")
	elif ResourceLoader.exists("res://Main.tscn"):
		get_tree().call_deferred("change_scene_to_file", "res://Main.tscn")


func _make_hint_pill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.11, 0.92)
	style.set_corner_radius_all(14)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.98, 0.94, 0.45)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _play_eye_open_fade() -> void:
	var fade_tween := create_tween()
	fade_tween.tween_property(eye_open_overlay, "modulate:a", 0.0, 1.1)
	fade_tween.finished.connect(func(): eye_open_overlay.visible = false)


func _build_script() -> void:
	entries = [
		# --- SCENE 15 ---
		{
			"image": "scene15.png",
			"text": "Welcome... welcome everybody! You made a clever decision choosing Reed College. I can assure you that Oregon is one of the most magical places in the world, especially when talking about its nature and atmosphere. It fits you perfectly, because every artist needs inspiration—our fuel.",
			"instant": false,
			"kind": "spoken",
			"speaker": "Leon James"
		},
		{
			"image": "scene15.png",
			"text": "*He's so happy, thinking that this is just another normal, youthful year with laughs and good friends. However, he doesn't know that there's a walking curse among us. Maybe he's noticed that my stare is hostile, but he will lose his mind when he feels trapped in a hellish cycle.*",
			"instant": false,
			"kind": "mind",
			"speaker": "Jammy"
		},
		{
			"image": "scene15.png",
			"text": "*It's just 8 AM and my mind has drained all my energy. I don't wanna focus on my stupid thoughts while there's a whole universe outside. I want to stop, but how? It just continues and continues. Enough, shut the fuck up, Jammy, you bore me.*",
			"instant": false,
			"kind": "narration",
			"speaker": "Jammy"
		},
		{
			"image": "scene15.png",
			"text": "Well, well, I don't want you to introduce yourselves—you know, it's so cringe. So, for your first task in this class, Sketching, I'd like to know your drawing styles. Pair up and let your souls interact!",
			"instant": false,
			"kind": "spoken",
			"speaker": "Leon James"
		},

		# --- SCENE 16 ---
		{
			"image": "scene16.png",
			"text": "Hi again, new bestie!",
			"instant": false,
			"kind": "spoken",
			"speaker": "Xcarlet"
		},
		{
			"image": "scene16.png",
			"text": "*I'd like to make friends, but when I'm in the process, my body feels so fucking bad.*",
			"instant": false,
			"kind": "narration",
			"speaker": "Jammy"
		},
		{
			"image": "scene16.png",
			"text": "*Flee from me. I can feel how you're falling apart slowly. I'm sure you were a luminous girl, but now you're learning what it means to have a boring, bland, stinky life. Even I can notice that fart smell you're emitting today after your first day with me, and recalling my past experiences, you'll get pimples on your face, your hair undone, your energy drained—another one of Jammy's victims. My stare is telling you: 'Can you feel my hostility?' You'll remember me 'til your last day.*",
			"instant": false,
			"kind": "mind",
			"speaker": "Jammy"
		},
		{
			"image": "scene16.png",
			"text": "*That's not true, that's not true!!!!! Stop, it's too late...*",
			"instant": false,
			"kind": "narration",
			"speaker": "Jammy"
		},
		{
			"image": "scene16.png",
			"text": "What's up?",
			"instant": false,
			"kind": "spoken",
			"speaker": "Xcarlet"
		},
		{
			"image": "scene16.png",
			"text": "Well, I'm... just okay. What 'bout you?",
			"instant": false,
			"kind": "spoken",
			"speaker": "Jammy"
		},
		{
			"image": "scene16.png",
			"text": "*Right?*",
			"instant": true,
			"kind": "mind",
			"speaker": "Jammy"
		},
		{
			"image": "scene16.png",
			"text": "Well, I'm a little bit anxious, and I don't know why—it's not usual for me, but I can manage it.",
			"instant": false,
			"kind": "spoken",
			"speaker": "Xcarlet"
		},
		{
			"image": "scene16.png",
			"text": "*I told you.*",
			"instant": false,
			"kind": "mind",
			"speaker": "Jammy"
		},
		{
			"image": "scene16.png",
			"text": "Well, let's let our souls flow into this drawing—no prior plans, just ourselves talking aloud.",
			"instant": false,
			"kind": "spoken",
			"speaker": "Xcarlet"
		}
	]


func _fits_in_dialogue_box(candidate: String, font: Font, font_size: int, max_width: float, max_height: float) -> bool:
	var measured := font.get_multiline_string_size(candidate, HORIZONTAL_ALIGNMENT_CENTER, max_width, font_size)
	return measured.y <= max_height


func _split_long_dialogues() -> void:
	var split_entries: Array[Dictionary] = []
	for entry in entries:
		var text: String = str(entry.get("text", ""))
		if entry.get("no_split", false):
			split_entries.append(entry.duplicate())
			continue

		var kind: String = str(entry.get("kind", ""))
		var is_mind: bool = kind == "mind"
		var has_start_marker: bool = is_mind or text.begins_with("*")
		var has_end_marker: bool = is_mind or text.ends_with("*")
		var inner_text: String = text.trim_prefix("*").trim_suffix("*")

		var font: Font = ROCK_SALT_FONT if is_mind else FREDOKA_FONT
		var font_size: int = 36 if is_mind else 46
		var max_width: float = 1130.0
		var max_height: float = 165.0

		var full_marked: String = _apply_thought_markers(inner_text, has_start_marker, has_end_marker)
		if _fits_in_dialogue_box(full_marked, font, font_size, max_width, max_height):
			var normalized_entry: Dictionary = entry.duplicate()
			normalized_entry["text"] = full_marked
			split_entries.append(normalized_entry)
			continue

		var chunk := ""
		for word in inner_text.split(" "):
			var candidate: String = word if chunk.is_empty() else chunk + " " + word
			var marked_candidate: String = _apply_thought_markers(candidate, has_start_marker, has_end_marker)
			if not chunk.is_empty() and not _fits_in_dialogue_box(marked_candidate, font, font_size, max_width, max_height):
				var chunk_entry: Dictionary = entry.duplicate()
				chunk_entry["text"] = _apply_thought_markers(chunk, has_start_marker, false)
				split_entries.append(chunk_entry)
				has_start_marker = false
				chunk = word
			else:
				chunk = candidate

		if not chunk.is_empty():
			var final_entry: Dictionary = entry.duplicate()
			final_entry["text"] = _apply_thought_markers(chunk, has_start_marker, has_end_marker)
			split_entries.append(final_entry)

	entries = split_entries


func _apply_thought_markers(text: String, add_start: bool, add_end: bool) -> String:
	var result := text
	if add_start:
		result = "*" + result
	if add_end:
		result += "*"
	return result


func _show_entry() -> void:
	if entry_index >= entries.size():
		_show_ending()
		return

	current_entry = entries[entry_index]
	_guardar_estado_actual()
	_set_continue_visible(false)
	dialogue_panel.visible = true
	dialogue_label.visible = true

	black_background.visible = false
	background.modulate = Color.WHITE
	var img_path := "res://scenes/" + str(current_entry.image)
	if ResourceLoader.exists(img_path):
		background.texture = load(img_path)

	_update_ambience()
	_style_dialogue()

	dialogue_label.text = ""
	waiting_for_input = false
	is_typing = true
	typing_token += 1
	var token := typing_token
	current_words = String(current_entry.text).split(" ")
	displayed_words = 0

	if current_entry.get("instant", false):
		dialogue_label.text = current_entry.text
		is_typing = false
		waiting_for_input = true
		_set_continue_visible(true, "ENTER TO CONTINUE")
	else:
		_type_words(token)


func _type_words(token: int) -> void:
	var delay := float(current_entry.get("slow", 0.045))
	var plays_typewriter := str(current_entry.get("kind", "")) != "mind"
	var sound_step := 2 if current_words.size() >= 3 else 1

	while displayed_words < current_words.size() and token == typing_token:
		var word := current_words[displayed_words]
		dialogue_label.text += ("" if displayed_words == 0 else " ") + word
		if plays_typewriter and displayed_words % sound_step == 0:
			typewriter_player.stop()
			typewriter_player.stream = typewriter_stream
			typewriter_player.play()
		displayed_words += 1
		await get_tree().create_timer(delay).timeout

	if token == typing_token:
		if plays_typewriter:
			typewriter_player.stop()
		is_typing = false
		waiting_for_input = true
		_set_continue_visible(true, "ENTER TO CONTINUE")


func _advance() -> void:
	if ending_triggered:
		return

	if is_typing:
		typing_token += 1
		typewriter_player.stop()
		dialogue_label.text = current_entry.text
		is_typing = false
		waiting_for_input = true
		_set_continue_visible(true, "ENTER TO CONTINUE")
		return

	if waiting_for_input:
		_set_continue_visible(false)
		entry_index += 1
		_show_entry()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if leave_dialog_open:
				_close_leave_confirm()
			else:
				_open_leave_confirm()
			return
		if leave_dialog_open and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			get_viewport().set_input_as_handled()
			_go_to_start_menu()
			return

	if leave_dialog_open:
		return

	var advance_pressed := false
	if event is InputEventKey:
		advance_pressed = event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE)
	elif event is InputEventMouseButton:
		advance_pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT

	if advance_pressed:
		_advance()


func _get_speaker_color(speaker_name: String) -> Color:
	match speaker_name.to_lower():
		"jammy":
			return JAMMY_COLOR
		"leon james":
			return LEON_COLOR
		"xcarlet":
			return XCARLET_COLOR
		_:
			return TEXT_COLOR


func _style_dialogue() -> void:
	var kind: String = str(current_entry.get("kind", ""))
	var is_mind: bool = kind == "mind"
	var speaker: String = str(current_entry.get("speaker", ""))
	var image_name: String = str(current_entry.get("image", ""))

	dialogue_label.add_theme_color_override("font_shadow_color", Color("#000000f0"))
	dialogue_label.add_theme_constant_override("shadow_offset_x", 4)
	dialogue_label.add_theme_constant_override("shadow_offset_y", 4)

	var panel_size := DIALOGUE_PANEL_SIZE
	var panel_pos := JAMMY_CENTER_POS

	if image_name == "scene16.png":
		if speaker.to_lower() == "xcarlet":
			panel_pos = XCARLET_PANEL_POS
		else:
			panel_pos = JAMMY_LEFT_CENTER_POS
	else:
		if speaker.to_lower() == "leon james":
			panel_pos = LEON_PANEL_POS
		else:
			panel_pos = JAMMY_CENTER_POS

	if is_mind:
		dialogue_label.add_theme_font_size_override("font_size", 36)
	else:
		dialogue_label.add_theme_font_size_override("font_size", 46)

	dialogue_panel.position = panel_pos
	dialogue_panel.size = panel_size
	dialogue_label.position = Vector2(44, 24)
	dialogue_label.size = Vector2(panel_size.x - 88.0, panel_size.y - 48.0)

	var s_color := _get_speaker_color(speaker)
	var s_border := Color(s_color.r, s_color.g, s_color.b, 0.65)

	if is_mind:
		dialogue_label.add_theme_color_override("font_color", MIND_COLOR)
		dialogue_label.add_theme_font_override("font", ROCK_SALT_FONT)
		dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(MIND_PANEL_COLOR, s_border))
	else:
		dialogue_label.add_theme_color_override("font_color", TEXT_COLOR)
		dialogue_label.add_theme_font_override("font", FREDOKA_FONT)
		dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, s_border))

	if not speaker.is_empty():
		speaker_panel.visible = true
		speaker_panel.position = Vector2(panel_pos.x + 36.0, panel_pos.y - SPEAKER_PANEL_SIZE.y + 2.0)
		speaker_panel.size = SPEAKER_PANEL_SIZE
		speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, s_color))
		speaker_label.text = speaker
		speaker_label.add_theme_color_override("font_color", s_color)
	else:
		speaker_panel.visible = false


func _make_dialogue_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = border_color
	return style


func _make_speaker_style(bg_color: Color, accent_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 0
	style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.75)
	return style


func _build_audio() -> void:
	typewriter_stream = NORMAL_DIALOGUE_STREAM
	breath_stream = BREATHING_STREAM
	heartbeat_stream = HEARTBEAT_STREAM

	var heartbeat_mp3 := heartbeat_stream as AudioStreamMP3
	if heartbeat_mp3:
		heartbeat_mp3.loop = true


func _update_ambience() -> void:
	var is_mind: bool = current_entry.get("kind", "") == "mind"
	if is_mind:
		if not mind_breath_player.playing:
			mind_breath_player.stream = breath_stream
			mind_breath_player.volume_db = 0.0
			mind_breath_player.play()
		if not mind_heartbeat_player.playing:
			mind_heartbeat_player.stream = heartbeat_stream
			mind_heartbeat_player.volume_db = 0.0
			mind_heartbeat_player.play(0.0)
	else:
		mind_heartbeat_player.stop()
		mind_breath_player.stop()


func _show_ending() -> void:
	if ending_triggered:
		return
	ending_triggered = true

	waiting_for_input = false
	is_typing = false
	_set_continue_visible(false)
	mind_heartbeat_player.stop()
	mind_breath_player.stop()

	var destino := next_scene_path.strip_edges()
	if destino.is_empty():
		destino = "res://Level3.tscn"
	if not ResourceLoader.exists(destino):
		push_error("No existe %s" % destino)
		ending_triggered = false
		return

	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null and save_manager.has_method("guardar_progreso"):
		save_manager.guardar_progreso(destino, "Level 3", {"step": 0}, _obtener_slot_activo())

	var packed := ResourceLoader.load(destino) as PackedScene
	if packed == null:
		push_error("No se pudo cargar %s. Revisa si hay un error rojo en el script del nivel." % destino)
		ending_triggered = false
		return

	var err := get_tree().change_scene_to_packed(packed)
	if err != OK:
		push_error("Error al cambiar a %s: %s" % [destino, str(err)])
		ending_triggered = false
