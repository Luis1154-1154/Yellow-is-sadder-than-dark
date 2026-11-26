extends Control

const BASE_SIZE := Vector2(3840.0, 2160.0)
const TEXT_COLOR := Color("#fff9f0")
const PANEL_COLOR := Color(0.14, 0.16, 0.20, 0.94)
const MIND_PANEL_COLOR := Color(0.11, 0.12, 0.16, 0.95)
const SPEAKER_BG_COLOR := Color(0.12, 0.14, 0.18, 0.96)
const MIND_COLOR := Color("#ff666b")
const ACCENT_COLOR := Color("#fff9f0")
const GOLD_ACCENT := Color("#f5d08a")
const SKY_ACCENT := Color("#8ab4f8")

# Colores por personaje
const JAMMY_COLOR := Color("#f5d08a")
const COUSIN_COLOR := Color("#a3aab2")
const XCARLET_COLOR := Color("#5bc0eb")
const GRANDMA_COLOR := Color("#f2a6b8")
const CLASSMATES_TAB_COLOR := Color("#46527a")
const CLASSMATES_BOX_COLOR := Color("#cfd5e0")
const CLASSMATES_TEXT_COLOR := Color("#c6cee0")

const DIALOGUE_PANEL_SIZE := Vector2(1240.0, 230.0)
const DIALOGUE_PANEL_POS := Vector2(1300.0, 960.0)
const SPEAKER_PANEL_SIZE := Vector2(300.0, 62.0)

# Ajuste del zoom hacia la laptop sobre scene4.png (3840x2160)
const LAPTOP_ZOOM_PIVOT := Vector2(1920.0, 1180.0)
const LAPTOP_ZOOM_SCALE := 4.4

const FREDOKA_FONT = preload("res://fonts/Fredoka-Regular.ttf")
const ROCK_SALT_FONT = preload("res://fonts/RockSalt-Regular.ttf")
const NORMAL_DIALOGUE_STREAM = preload("res://assets/sounds/Soft_pencil_tap_on_n_#1-1794378651940.mp3")
const BREATHING_STREAM = preload("res://assets/sounds/breathing1.mp3")
const HEARTBEAT_STREAM = preload("res://assets/sounds/Hbeating1.mp3")
const FOCUS_EFFORT_STREAM = preload("res://assets/sounds/audioJuego1.mp3")
const FOCUS_SUCCESS_STREAM = preload("res://assets/sounds/mixingGame1.mp3")

const SCENE12_TEX: Texture2D = preload("res://scenes/scene12.png")
const SCENE13_TEX: Texture2D = preload("res://scenes/scene13.png")

# Dificultad alta del minijuego
const FOCUS_EFFORT_MAX := 100.0
const FOCUS_EFFORT_RATE := 11.5
const FOCUS_EFFORT_DECAY := 220.0
const FOCUS_WINDOW_TIME := 0.42
const FOCUS_FAKEOUT_TIME := 0.11
const FOCUS_FAKEOUT_BLUR := 3.2
const FOCUS_RESOLUTION_TIME := 5.5
const FOCUS_CLIMAX_BLUR := 9.5

var background: TextureRect
var black_background: ColorRect
var dialogue_panel: Panel
var dialogue_label: Label
var speaker_panel: Panel
var speaker_label: Label
var continue_panel: PanelContainer
var continue_label: Label
var cat_prompt_panel: PanelContainer
var cat_prompt_label: RichTextLabel

# Recordatorio perpetuo minimalista + modal de salida al inicio
var perpetual_hint_panel: PanelContainer
var perpetual_hint_label: Label
var leave_confirm_overlay: ColorRect
var leave_confirm_panel: PanelContainer
var leave_yes_btn: Button
var leave_no_btn: Button
var leave_dialog_open: bool = false

var typewriter_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var mind_breath_player: AudioStreamPlayer
var mind_heartbeat_player: AudioStreamPlayer
var sonido_esfuerzo: AudioStreamPlayer
var sonido_corte: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var typewriter_stream: AudioStream
var breath_stream: AudioStream
var heartbeat_stream: AudioStream
var effort_stream: AudioStream
var cut_stream: AudioStream
var night_ambience_stream: AudioStream
var sigh_stream: AudioStream

var entries: Array[Dictionary] = []
var entry_index: int = 0
var is_typing: bool = false
var typing_token: int = 0
var displayed_words: int = 0
var current_words: PackedStringArray
var current_entry: Dictionary = {}
var waiting_for_input: bool = false
var vn_focus_mode: bool = false
var vn_focus_intro: bool = true
enum FocusState { EFFORT, WINDOW, RESOLUTION }
var focus_state: FocusState = FocusState.EFFORT
var focus_effort: float = 0.0
var focus_window_timer: float = 0.0
var focus_image: TextureRect
var focus_shader_material: ShaderMaterial
var focus_instructions: RichTextLabel
var focus_vignette: ColorRect
var focus_status: Label
var focus_hint: Label
var focus_fakeout_timer: float = 0.0
var focus_fakeout_armed: bool = true
var focus_fakeout2_armed: bool = true
var focus_fakeout3_armed: bool = true
var focus_exit_prompt: bool = false
var mixing_game_active: bool = false
var mixing_loop_start: float = 0.5

# Estado del Browser con Summary + hipervínculos (debajo de los diálogos)
var browser_root: Control
var browser_tab_label: Label
var browser_url_label: Label
var browser_search_input: LineEdit
var browser_results_container: VBoxContainer
var browser_cursor: Control
var browser_active: bool = false
var browser_zooming: bool = false
var browser_typing: bool = false
var browser_results_shown: bool = false
var browser_current_query: String = ""
var browser_typing_token: int = 0
var _last_advance_msec: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	set_process_unhandled_input(true)
	_build_audio()
	_build_ui()
	_build_browser_ui()
	_build_leave_confirm_ui()
	_build_script()
	_split_long_dialogues()
	_aplicar_guardado_cargado()
	_show_entry()

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

func _obtener_slot_activo() -> int:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr == null:
		return 0
	for prop in ["slot_actual", "current_slot", "active_slot", "selected_slot"]:
		if prop in save_mgr:
			var val = save_mgr.get(prop)
			if typeof(val) == TYPE_INT and int(val) >= 0:
				return int(val)
	return 0

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

	var etiqueta: String = "Visual Novel (%d/%d)" % [entry_index + 1, max(entries.size(), 1)]
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

func _process(delta: float) -> void:
	if mixing_game_active:
		_maintain_mixing_game_loop()
	if leave_dialog_open:
		return
	if not vn_focus_mode or vn_focus_intro:
		return
	var is_pressing: bool = Input.is_key_pressed(KEY_W) and Input.is_key_pressed(KEY_S)
	_update_focus_music(is_pressing)
	_update_focus_key_hint(is_pressing)
	if focus_fakeout_timer > 0.0:
		if not is_pressing:
			focus_effort = 0.0
		focus_fakeout_timer -= delta
		if focus_fakeout_timer <= 0.0 or not is_pressing:
			focus_image.texture = SCENE12_TEX
			focus_shader_material.set_shader_parameter("blur_amount", 0.0)
			focus_fakeout_timer = 0.0
		return
	match focus_state:
		FocusState.EFFORT:
			if is_pressing:
				focus_effort = min(focus_effort + FOCUS_EFFORT_RATE * delta, FOCUS_EFFORT_MAX)
			else:
				focus_effort = max(focus_effort - FOCUS_EFFORT_DECAY * delta, 0.0)
			_apply_focus_tension()
			if focus_effort < 50.0:
				focus_fakeout_armed = true
			elif focus_effort >= 62.0 and focus_fakeout_armed:
				focus_fakeout_armed = false
				_begin_focus_fakeout()
			if focus_effort < 72.0:
				focus_fakeout2_armed = true
			elif focus_effort >= 81.0 and focus_fakeout2_armed:
				focus_fakeout2_armed = false
				_begin_focus_fakeout()
			if focus_effort < 88.0:
				focus_fakeout3_armed = true
			elif focus_effort >= 94.0 and focus_fakeout3_armed:
				focus_fakeout3_armed = false
				_begin_focus_fakeout()
			if focus_effort >= FOCUS_EFFORT_MAX:
				_begin_focus_window()
		FocusState.WINDOW:
			var both_released: bool = not Input.is_key_pressed(KEY_W) and not Input.is_key_pressed(KEY_S)
			if both_released:
				_complete_focus()
				return
			focus_window_timer -= delta
			if focus_window_timer <= 0.0:
				_reset_focus_cycle()

func _set_continue_visible(visible_state: bool, hint_text: String = "SPACE / CLICK TO CONTINUE") -> void:
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

func show_cat_minigame_prompt(prompt_text: String = "Help the kitty out by pressing the keys indicated.\n[SPACE] to begin.") -> void:
	if cat_prompt_panel == null or cat_prompt_label == null:
		return
	var formatted: String = "[center][color=#8ab4f8]✦ CAT MINIGAME[/color]\n" + prompt_text.replace("[", "[color=#f5d08a][b][").replace("]", "][/b][/color]") + "[/center]"
	cat_prompt_label.text = formatted
	cat_prompt_panel.visible = true
	cat_prompt_label.visible = true
	cat_prompt_panel.reset_size()
	cat_prompt_panel.position = Vector2(BASE_SIZE.x * 0.5 - cat_prompt_panel.size.x * 0.5, 720.0)
	cat_prompt_panel.move_to_front()

func hide_cat_minigame_prompt() -> void:
	if cat_prompt_panel != null:
		cat_prompt_panel.visible = false
	if cat_prompt_label != null:
		cat_prompt_label.visible = false

func set_second_scene_as_jammy(target_index: int = 1) -> void:
	if target_index >= 0 and target_index < entries.size():
		entries[target_index]["speaker"] = "Jammy"
		if str(entries[target_index].get("kind", "")) == "":
			entries[target_index]["kind"] = "spoken"

func _build_ui() -> void:
	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.pivot_offset = BASE_SIZE / 2.0
	background.z_index = 1

	black_background = ColorRect.new()
	black_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black_background.color = Color.BLACK
	black_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black_background.z_index = 0
	add_child(black_background)
	add_child(background)

	dialogue_panel = Panel.new()
	dialogue_panel.position = DIALOGUE_PANEL_POS
	dialogue_panel.size = DIALOGUE_PANEL_SIZE
	dialogue_panel.z_index = 20
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, Color(1.0, 0.98, 0.94, 0.45)))
	add_child(dialogue_panel)

	speaker_panel = Panel.new()
	speaker_panel.position = Vector2(DIALOGUE_PANEL_POS.x + 36.0, DIALOGUE_PANEL_POS.y - SPEAKER_PANEL_SIZE.y + 2.0)
	speaker_panel.size = SPEAKER_PANEL_SIZE
	speaker_panel.z_index = 21
	speaker_panel.visible = false
	speaker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, JAMMY_COLOR))
	add_child(speaker_panel)

	speaker_label = Label.new()
	speaker_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.add_theme_font_size_override("font_size", 36)
	speaker_label.add_theme_font_override("font", FREDOKA_FONT)
	speaker_label.add_theme_color_override("font_color", JAMMY_COLOR)
	speaker_label.add_theme_constant_override("outline_size", 3)
	speaker_label.add_theme_color_override("font_outline_color", Color("#08080a"))
	speaker_label.add_theme_color_override("font_shadow_color", Color("#000000f0"))
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
	dialogue_label.add_theme_constant_override("outline_size", 4)
	dialogue_label.add_theme_color_override("font_outline_color", Color("#08080a"))
	dialogue_label.add_theme_color_override("font_shadow_color", Color("#000000f5"))
	dialogue_label.add_theme_constant_override("shadow_offset_x", 4)
	dialogue_label.add_theme_constant_override("shadow_offset_y", 4)
	dialogue_panel.add_child(dialogue_label)

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
	add_child(continue_panel)

	continue_label = Label.new()
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	continue_label.add_theme_font_size_override("font_size", 34)
	continue_label.add_theme_font_override("font", FREDOKA_FONT)
	continue_label.add_theme_color_override("font_color", ACCENT_COLOR)
	continue_label.add_theme_constant_override("outline_size", 5)
	continue_label.add_theme_color_override("font_outline_color", Color("#08080a"))
	continue_label.text = "SPACE / CLICK TO CONTINUE"
	continue_label.visible = false
	continue_panel.add_child(continue_label)

	# Recordatorio perpetuo minimalista: ESC lleva a inicio con confirmación previa
	perpetual_hint_panel = PanelContainer.new()
	perpetual_hint_panel.position = Vector2(BASE_SIZE.x - 560.0, 40.0)
	perpetual_hint_panel.z_index = 90
	perpetual_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var perp_sb: StyleBoxFlat = StyleBoxFlat.new()
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
	add_child(perpetual_hint_panel)

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

	cat_prompt_panel = PanelContainer.new()
	cat_prompt_panel.z_index = 35
	cat_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cat_prompt_panel.add_theme_stylebox_override("panel", _make_cat_prompt_style())
	cat_prompt_panel.visible = false
	add_child(cat_prompt_panel)

	cat_prompt_label = RichTextLabel.new()
	cat_prompt_label.bbcode_enabled = true
	cat_prompt_label.fit_content = true
	cat_prompt_label.scroll_active = false
	cat_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cat_prompt_label.custom_minimum_size = Vector2(1280.0, 0.0)
	cat_prompt_label.add_theme_font_size_override("normal_font_size", 44)
	cat_prompt_label.add_theme_font_size_override("bold_font_size", 46)
	cat_prompt_label.add_theme_font_override("normal_font", FREDOKA_FONT)
	cat_prompt_label.add_theme_font_override("bold_font", FREDOKA_FONT)
	cat_prompt_label.add_theme_color_override("default_color", TEXT_COLOR)
	cat_prompt_label.add_theme_constant_override("outline_size", 4)
	cat_prompt_label.add_theme_color_override("font_outline_color", Color("#08080a"))
	cat_prompt_label.visible = false
	cat_prompt_panel.add_child(cat_prompt_label)

	focus_image = TextureRect.new()
	focus_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	focus_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	focus_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_image.z_index = 2
	focus_image.pivot_offset = BASE_SIZE / 2.0
	focus_image.visible = false
	var focus_shader: Shader = Shader.new()
	focus_shader.code = """
shader_type canvas_item;

uniform float blur_amount = 0.0;

void fragment() {
	vec2 offset = TEXTURE_PIXEL_SIZE * blur_amount;
	vec4 color = texture(TEXTURE, UV) * 0.2;
	color += texture(TEXTURE, UV + vec2(offset.x, 0.0)) * 0.2;
	color += texture(TEXTURE, UV - vec2(offset.x, 0.0)) * 0.2;
	color += texture(TEXTURE, UV + vec2(0.0, offset.y)) * 0.2;
	color += texture(TEXTURE, UV - vec2(0.0, offset.y)) * 0.2;
	COLOR = color;
}
"""
	focus_shader_material = ShaderMaterial.new()
	focus_shader_material.shader = focus_shader
	focus_shader_material.set_shader_parameter("blur_amount", 0.0)
	focus_image.material = focus_shader_material
	add_child(focus_image)

	focus_vignette = ColorRect.new()
	focus_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_vignette.z_index = 3
	var vignette_shader: Shader = Shader.new()
	vignette_shader.code = """
shader_type canvas_item;

uniform float vignette_alpha = 0.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float edge = smoothstep(0.24, 0.72, length(centered));
	COLOR = vec4(0.0, 0.0, 0.0, edge * vignette_alpha);
}
"""
	var vignette_material: ShaderMaterial = ShaderMaterial.new()
	vignette_material.shader = vignette_shader
	vignette_material.set_shader_parameter("vignette_alpha", 0.0)
	focus_vignette.material = vignette_material
	focus_vignette.visible = false
	add_child(focus_vignette)

	focus_instructions = RichTextLabel.new()
	focus_instructions.position = Vector2(44, 24)
	focus_instructions.size = Vector2(1312.0, 252.0)
	focus_instructions.bbcode_enabled = true
	focus_instructions.fit_content = false
	focus_instructions.scroll_active = false
	focus_instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus_instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_instructions.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	focus_instructions.add_theme_font_size_override("normal_font_size", 44)
	focus_instructions.add_theme_font_size_override("bold_font_size", 46)
	focus_instructions.add_theme_font_override("normal_font", FREDOKA_FONT)
	focus_instructions.add_theme_font_override("bold_font", FREDOKA_FONT)
	focus_instructions.add_theme_color_override("default_color", TEXT_COLOR)
	focus_instructions.add_theme_constant_override("outline_size", 4)
	focus_instructions.add_theme_color_override("font_outline_color", Color("#08080a"))
	focus_instructions.visible = false
	dialogue_panel.add_child(focus_instructions)

	focus_status = Label.new()
	focus_status.position = Vector2(150, 150)
	focus_status.size = Vector2(700, 80)
	focus_status.add_theme_font_size_override("font_size", 48)
	focus_status.add_theme_color_override("font_color", TEXT_COLOR)
	focus_status.add_theme_constant_override("outline_size", 4)
	focus_status.add_theme_color_override("font_outline_color", Color("#08080a"))
	focus_status.add_theme_color_override("font_shadow_color", Color("#000000e6"))
	focus_status.add_theme_constant_override("shadow_offset_x", 4)
	focus_status.add_theme_constant_override("shadow_offset_y", 4)
	focus_status.visible = false
	add_child(focus_status)

	focus_hint = Label.new()
	focus_hint.position = Vector2(670, 1880)
	focus_hint.size = Vector2(2500, 110)
	focus_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	focus_hint.add_theme_font_override("font", FREDOKA_FONT)
	focus_hint.add_theme_font_size_override("font_size", 44)
	focus_hint.add_theme_color_override("font_color", GOLD_ACCENT)
	focus_hint.add_theme_constant_override("outline_size", 5)
	focus_hint.add_theme_color_override("font_outline_color", Color("#08080a"))
	focus_hint.add_theme_color_override("font_shadow_color", Color("#000000f5"))
	focus_hint.add_theme_constant_override("shadow_offset_x", 3)
	focus_hint.add_theme_constant_override("shadow_offset_y", 3)
	focus_hint.z_index = 40
	focus_hint.visible = false
	add_child(focus_hint)

	typewriter_player = AudioStreamPlayer.new()
	typewriter_player.pitch_scale = 1.0
	typewriter_player.volume_db = 0.0
	add_child(typewriter_player)
	ambience_player = AudioStreamPlayer.new()
	add_child(ambience_player)
	mind_breath_player = AudioStreamPlayer.new()
	add_child(mind_breath_player)
	mind_heartbeat_player = AudioStreamPlayer.new()
	mind_heartbeat_player.pitch_scale = 2.0
	add_child(mind_heartbeat_player)
	sonido_esfuerzo = AudioStreamPlayer.new()
	add_child(sonido_esfuerzo)
	sonido_corte = AudioStreamPlayer.new()
	add_child(sonido_corte)
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)

func _build_leave_confirm_ui() -> void:
	leave_confirm_overlay = ColorRect.new()
	leave_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leave_confirm_overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	leave_confirm_overlay.z_index = 120
	leave_confirm_overlay.visible = false
	leave_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(leave_confirm_overlay)

	var center_box: CenterContainer = CenterContainer.new()
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_box.mouse_filter = Control.MOUSE_FILTER_STOP
	leave_confirm_overlay.add_child(center_box)

	leave_confirm_panel = PanelContainer.new()
	leave_confirm_panel.custom_minimum_size = Vector2(1180.0, 440.0)
	leave_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var modal_sb: StyleBoxFlat = StyleBoxFlat.new()
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

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 42)
	leave_confirm_panel.add_child(vb)

	var q_lbl: Label = Label.new()
	q_lbl.text = "do you really want to leave ?"
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.add_theme_font_size_override("font_size", 54)
	q_lbl.add_theme_font_override("font", FREDOKA_FONT)
	q_lbl.add_theme_color_override("font_color", TEXT_COLOR)
	q_lbl.add_theme_constant_override("outline_size", 4)
	q_lbl.add_theme_color_override("font_outline_color", Color("#08080a"))
	vb.add_child(q_lbl)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 48)
	vb.add_child(btn_row)

	leave_yes_btn = Button.new()
	leave_yes_btn.text = "Yes  [SPACE]"
	leave_yes_btn.custom_minimum_size = Vector2(360.0, 96.0)
	leave_yes_btn.add_theme_font_size_override("font_size", 40)
	leave_yes_btn.add_theme_font_override("font", FREDOKA_FONT)
	var yes_sb: StyleBoxFlat = StyleBoxFlat.new()
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
	var no_sb: StyleBoxFlat = StyleBoxFlat.new()
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
	_stop_mixing_game_loop()
	ambience_player.stop()
	mind_breath_player.stop()
	mind_heartbeat_player.stop()
	sonido_esfuerzo.stop()
	sfx_player.stop()
	typewriter_player.stop()

	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr != null and save_mgr.has_method("volver_al_inicio"):
		save_mgr.volver_al_inicio()
		return

	if ResourceLoader.exists("res://main.tscn"):
		get_tree().call_deferred("change_scene_to_file", "res://main.tscn")
	elif ResourceLoader.exists("res://Main.tscn"):
		get_tree().call_deferred("change_scene_to_file", "res://Main.tscn")

func _build_browser_ui() -> void:
	browser_root = Control.new()
	browser_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	browser_root.modulate.a = 0.0
	browser_root.visible = false
	browser_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	browser_root.z_index = 5
	add_child(browser_root)

	var window_box: VBoxContainer = VBoxContainer.new()
	window_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_box.add_theme_constant_override("separation", 0)
	browser_root.add_child(window_box)

	# 1. Barra de pestañas
	var tab_strip: PanelContainer = PanelContainer.new()
	tab_strip.custom_minimum_size = Vector2(0.0, 84.0)
	tab_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tab_strip_sb: StyleBoxFlat = StyleBoxFlat.new()
	tab_strip_sb.bg_color = Color("#181a1f")
	tab_strip_sb.content_margin_left = 24.0
	tab_strip_sb.content_margin_right = 28.0
	tab_strip_sb.content_margin_top = 14.0
	tab_strip.add_theme_stylebox_override("panel", tab_strip_sb)
	window_box.add_child(tab_strip)

	var tab_hbox: HBoxContainer = HBoxContainer.new()
	tab_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_hbox.add_theme_constant_override("separation", 12)
	tab_strip.add_child(tab_hbox)

	var active_tab: PanelContainer = PanelContainer.new()
	active_tab.custom_minimum_size = Vector2(760.0, 70.0)
	active_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var active_tab_sb: StyleBoxFlat = StyleBoxFlat.new()
	active_tab_sb.bg_color = Color("#28292d")
	active_tab_sb.corner_radius_top_left = 18
	active_tab_sb.corner_radius_top_right = 18
	active_tab_sb.content_margin_left = 28.0
	active_tab_sb.content_margin_right = 28.0
	active_tab.add_theme_stylebox_override("panel", active_tab_sb)
	tab_hbox.add_child(active_tab)

	var active_tab_row: HBoxContainer = HBoxContainer.new()
	active_tab_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_tab_row.add_theme_constant_override("separation", 16)
	active_tab.add_child(active_tab_row)

	var tab_icon: Label = Label.new()
	tab_icon.text = "⌕"
	tab_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tab_icon.add_theme_font_size_override("font_size", 36)
	tab_icon.add_theme_color_override("font_color", Color("#8ab4f8"))
	active_tab_row.add_child(tab_icon)

	browser_tab_label = Label.new()
	browser_tab_label.text = "Search - Browser"
	browser_tab_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	browser_tab_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	browser_tab_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browser_tab_label.add_theme_font_size_override("font_size", 34)
	browser_tab_label.add_theme_font_override("font", FREDOKA_FONT)
	browser_tab_label.add_theme_color_override("font_color", Color("#e8eaed"))
	active_tab_row.add_child(browser_tab_label)

	var plus_tab: Label = Label.new()
	plus_tab.text = "  +  "
	plus_tab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus_tab.add_theme_font_size_override("font_size", 40)
	plus_tab.add_theme_color_override("font_color", Color("#9aa0a6"))
	tab_hbox.add_child(plus_tab)

	# 2. Barra de direcciones
	var url_bar: PanelContainer = PanelContainer.new()
	url_bar.custom_minimum_size = Vector2(0.0, 96.0)
	url_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var url_bar_sb: StyleBoxFlat = StyleBoxFlat.new()
	url_bar_sb.bg_color = Color("#28292d")
	url_bar_sb.border_color = Color("#3c4043")
	url_bar_sb.border_width_bottom = 2
	url_bar_sb.content_margin_left = 32.0
	url_bar_sb.content_margin_right = 32.0
	url_bar_sb.content_margin_top = 12.0
	url_bar_sb.content_margin_bottom = 12.0
	url_bar.add_theme_stylebox_override("panel", url_bar_sb)
	window_box.add_child(url_bar)

	var url_hbox: HBoxContainer = HBoxContainer.new()
	url_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	url_hbox.add_theme_constant_override("separation", 28)
	url_bar.add_child(url_hbox)

	var nav_arrows: Label = Label.new()
	nav_arrows.text = "←   →   ↻"
	nav_arrows.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav_arrows.add_theme_font_size_override("font_size", 36)
	nav_arrows.add_theme_color_override("font_color", Color("#9aa0a6"))
	url_hbox.add_child(nav_arrows)

	var address_pill: PanelContainer = PanelContainer.new()
	address_pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var addr_sb: StyleBoxFlat = StyleBoxFlat.new()
	addr_sb.bg_color = Color("#1e1f23")
	addr_sb.set_corner_radius_all(34)
	addr_sb.content_margin_left = 30.0
	addr_sb.content_margin_right = 30.0
	addr_sb.content_margin_top = 8.0
	addr_sb.content_margin_bottom = 8.0
	address_pill.add_theme_stylebox_override("panel", addr_sb)
	url_hbox.add_child(address_pill)

	browser_url_label = Label.new()
	browser_url_label.text = "https://browser.local/search?q="
	browser_url_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	browser_url_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	browser_url_label.add_theme_font_size_override("font_size", 34)
	browser_url_label.add_theme_font_override("font", FREDOKA_FONT)
	browser_url_label.add_theme_color_override("font_color", Color("#bdc1c6"))
	address_pill.add_child(browser_url_label)

	# 3. Área principal tipo dashboard de búsqueda: barra arriba, Summary arriba, hipervínculos debajo
	var page_bg: PanelContainer = PanelContainer.new()
	page_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var page_sb: StyleBoxFlat = StyleBoxFlat.new()
	page_sb.bg_color = Color("#1f2125")
	page_sb.content_margin_left = 220.0
	page_sb.content_margin_right = 220.0
	page_sb.content_margin_top = 34.0
	page_sb.content_margin_bottom = 120.0
	page_bg.add_theme_stylebox_override("panel", page_sb)
	window_box.add_child(page_bg)

	var page_vbox: VBoxContainer = VBoxContainer.new()
	page_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_vbox.add_theme_constant_override("separation", 22)
	page_bg.add_child(page_vbox)

	var top_search_row: HBoxContainer = HBoxContainer.new()
	top_search_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_search_row.add_theme_constant_override("separation", 40)
	page_vbox.add_child(top_search_row)

	var browser_logo: Label = Label.new()
	browser_logo.text = "Browser"
	browser_logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	browser_logo.add_theme_font_size_override("font_size", 58)
	browser_logo.add_theme_font_override("font", FREDOKA_FONT)
	browser_logo.add_theme_color_override("font_color", Color("#ffffff"))
	top_search_row.add_child(browser_logo)

	var search_pill: PanelContainer = PanelContainer.new()
	search_pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var search_sb: StyleBoxFlat = StyleBoxFlat.new()
	search_sb.bg_color = Color("#303134")
	search_sb.border_color = Color("#5f6368")
	search_sb.set_border_width_all(3)
	search_sb.set_corner_radius_all(48)
	search_sb.content_margin_left = 32.0
	search_sb.content_margin_right = 32.0
	search_sb.content_margin_top = 8.0
	search_sb.content_margin_bottom = 8.0
	search_pill.add_theme_stylebox_override("panel", search_sb)
	top_search_row.add_child(search_pill)

	var search_inner: HBoxContainer = HBoxContainer.new()
	search_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	search_inner.add_theme_constant_override("separation", 16)
	search_pill.add_child(search_inner)

	browser_search_input = LineEdit.new()
	browser_search_input.editable = false
	browser_search_input.focus_mode = Control.FOCUS_NONE
	browser_search_input.mouse_filter = Control.MOUSE_FILTER_IGNORE
	browser_search_input.caret_blink = true
	browser_search_input.custom_minimum_size = Vector2(0.0, 66.0)
	browser_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browser_search_input.placeholder_text = "Search or type a URL"
	browser_search_input.add_theme_font_size_override("font_size", 40)
	browser_search_input.add_theme_font_override("font", FREDOKA_FONT)
	browser_search_input.add_theme_color_override("font_color", Color("#e8eaed"))
	browser_search_input.add_theme_color_override("font_placeholder_color", Color("#9aa0a6"))
	var empty_sb: StyleBoxEmpty = StyleBoxEmpty.new()
	browser_search_input.add_theme_stylebox_override("normal", empty_sb)
	browser_search_input.add_theme_stylebox_override("focus", empty_sb)
	search_inner.add_child(browser_search_input)

	var search_icon: Label = Label.new()
	search_icon.text = "⌕"
	search_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	search_icon.add_theme_font_size_override("font_size", 44)
	search_icon.add_theme_color_override("font_color", Color("#8ab4f8"))
	search_inner.add_child(search_icon)

	var divider: ColorRect = ColorRect.new()
	divider.custom_minimum_size = Vector2(0.0, 3.0)
	divider.color = Color("#3c4043")
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_vbox.add_child(divider)

	# Contenedor del dashboard: Summary arriba + hipervínculos debajo
	browser_results_container = VBoxContainer.new()
	browser_results_container.visible = false
	browser_results_container.modulate.a = 0.0
	browser_results_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	browser_results_container.add_theme_constant_override("separation", 22)
	page_vbox.add_child(browser_results_container)

	# 1. Summary arriba
	var summary_panel: PanelContainer = PanelContainer.new()
	summary_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var summary_sb: StyleBoxFlat = StyleBoxFlat.new()
	summary_sb.bg_color = Color("#25282e")
	summary_sb.border_color = Color("#424956")
	summary_sb.set_border_width_all(3)
	summary_sb.set_corner_radius_all(24)
	summary_sb.content_margin_left = 42.0
	summary_sb.content_margin_right = 42.0
	summary_sb.content_margin_top = 24.0
	summary_sb.content_margin_bottom = 24.0
	summary_panel.add_theme_stylebox_override("panel", summary_sb)
	browser_results_container.add_child(summary_panel)

	var summary_vbox: VBoxContainer = VBoxContainer.new()
	summary_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_vbox.add_theme_constant_override("separation", 10)
	summary_panel.add_child(summary_vbox)

	var tag_lbl: Label = Label.new()
	tag_lbl.text = "✦ Summary"
	tag_lbl.add_theme_font_size_override("font_size", 36)
	tag_lbl.add_theme_font_override("font", FREDOKA_FONT)
	tag_lbl.add_theme_color_override("font_color", Color("#8ab4f8"))
	summary_vbox.add_child(tag_lbl)

	var summary_body: Label = Label.new()
	summary_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_body.add_theme_font_size_override("font_size", 38)
	summary_body.add_theme_font_override("font", FREDOKA_FONT)
	summary_body.add_theme_color_override("font_color", Color("#e8eaed"))
	summary_body.text = (
		"Distressing, unwanted thoughts paired with an urge to do something to get rid of them are linked to Obsessive-Compulsive Disorder (OCD) and its cycle. "
		+ "Some pages describe it as incurable because the cycle can feel automatic and persistent, though speaking with a mental health professional helps clarify what is happening."
	)
	summary_vbox.add_child(summary_body)

	# 2. Hipervínculos de resultados debajo del Summary (8 resultados para llenar bien la pantalla)
	var links_list: VBoxContainer = VBoxContainer.new()
	links_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	links_list.add_theme_constant_override("separation", 18)
	browser_results_container.add_child(links_list)

	var link_items: Array[Dictionary] = [
		{
			"url": "https://health-guide.local/articles/intrusive-thoughts-and-urges",
			"title": "Unwanted Thoughts, Compulsive Urges, and Why They Feel Incurable",
			"snippet": "How automatic thoughts and urges trap people in a loop that often feels incurable."
		},
		{
			"url": "https://mental-wellness.local/resources/ocd-cycle-explained",
			"title": "The Obsessive-Compulsive Cycle: Doubt, Relief, and Return",
			"snippet": "Overview of how trying to neutralize thoughts brings brief relief while keeping doubt active."
		},
		{
			"url": "https://forum-archive.local/threads/anyone-else-feels-trapped",
			"title": "Forum: Does anyone else feel like this cycle is incurable?",
			"snippet": "Community posts discussing sudden urges, mental checking, and constant second-guessing."
		},
		{
			"url": "https://mind-notes.local/guides/why-urges-feel-automatic",
			"title": "Why Compulsive Urges Feel Automatic Before You Can React",
			"snippet": "Notes on how tension spikes right when you try to force calm or control reactions."
		},
		{
			"url": "https://campus-health.local/faq/first-day-anxiety-and-obsessions",
			"title": "FAQ: Handling Intrusive Thoughts During Big Transitions",
			"snippet": "Common questions around school stress, social pressure, and unwanted mental loops."
		},
		{
			"url": "https://thought-patterns.local/articles/mental-checking-and-guilt",
			"title": "Mental Checking, Guilt, and Trying Not to Ruin Moments",
			"snippet": "Why over-monitoring your own reactions makes ordinary days feel heavier."
		},
		{
			"url": "https://daily-coping.local/notes/when-compulsions-take-over",
			"title": "When Doing Something to Get Rid of the Thought Becomes Automatic",
			"snippet": "Looking at the urge to neutralize an idea and why it keeps coming back."
		},
		{
			"url": "https://support-directory.local/care/talking-to-a-specialist",
			"title": "When to Speak With a Mental Health Professional",
			"snippet": "Practical notes on seeking professional guidance rather than guessing alone online."
		}
	]

	for item in link_items:
		var link_block: VBoxContainer = VBoxContainer.new()
		link_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		link_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		link_block.add_theme_constant_override("separation", 3)
		links_list.add_child(link_block)

		var site_lbl: Label = Label.new()
		site_lbl.text = str(item["url"])
		site_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		site_lbl.add_theme_font_size_override("font_size", 30)
		site_lbl.add_theme_font_override("font", FREDOKA_FONT)
		site_lbl.add_theme_color_override("font_color", Color("#9aa0a6"))
		link_block.add_child(site_lbl)

		var title_lbl: Label = Label.new()
		title_lbl.text = str(item["title"])
		title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title_lbl.add_theme_font_size_override("font_size", 44)
		title_lbl.add_theme_font_override("font", FREDOKA_FONT)
		title_lbl.add_theme_color_override("font_color", Color("#8ab4f8"))
		link_block.add_child(title_lbl)

		var snippet_lbl: Label = Label.new()
		snippet_lbl.text = str(item["snippet"])
		snippet_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		snippet_lbl.add_theme_font_size_override("font_size", 36)
		snippet_lbl.add_theme_font_override("font", FREDOKA_FONT)
		snippet_lbl.add_theme_color_override("font_color", Color("#bdc1c6"))
		link_block.add_child(snippet_lbl)

	# Cursor de Jammy interactuando
	browser_cursor = Control.new()
	browser_cursor.z_index = 12
	browser_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	browser_cursor.visible = false
	browser_cursor.draw.connect(_draw_jammy_cursor)
	browser_root.add_child(browser_cursor)

func _sync_browser_url(query_str: String) -> void:
	if browser_url_label != null:
		var encoded: String = query_str.strip_edges().replace(" ", "+")
		browser_url_label.text = "https://browser.local/search?q=" + encoded
	if browser_tab_label != null:
		var clean_q: String = query_str.strip_edges()
		browser_tab_label.text = ("Search - Browser" if clean_q.is_empty() else clean_q + " - Browser")

func _draw_jammy_cursor() -> void:
	if browser_cursor == null:
		return
	var poly: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(0.0, 44.0),
		Vector2(12.0, 33.0),
		Vector2(21.0, 52.0),
		Vector2(29.0, 48.0),
		Vector2(20.0, 29.0),
		Vector2(35.0, 29.0)
	])
	browser_cursor.draw_colored_polygon(poly, Color("#111317"))
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		browser_cursor.draw_line(a, b, Color("#ffffff"), 3.0)

func _move_cursor_to(target_pos: Vector2, duration: float = 0.45) -> void:
	if browser_cursor == null:
		return
	browser_cursor.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(browser_cursor, "position", target_pos, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

func _pulse_cursor_click() -> void:
	if browser_cursor == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(browser_cursor, "scale", Vector2(0.84, 0.84), 0.08)
	tw.tween_property(browser_cursor, "scale", Vector2.ONE, 0.10)
	await tw.finished

func _show_browser_results_dashboard() -> void:
	if browser_results_container == null:
		return
	browser_results_shown = true
	browser_results_container.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(browser_results_container, "modulate:a", 1.0, 0.25)

func _start_browser_scene(entry: Dictionary) -> void:
	browser_active = true
	browser_zooming = true
	browser_typing = false
	browser_results_shown = false
	waiting_for_input = false
	is_typing = false
	_set_continue_visible(false)

	var query_text: String = str(entry.get("search_query", "unwanted thoughts and urge to do something to get rid of them"))
	browser_current_query = query_text
	browser_typing_token += 1
	var token: int = browser_typing_token

	speaker_panel.visible = false
	dialogue_panel.visible = false
	dialogue_label.visible = false
	focus_instructions.visible = false
	black_background.visible = false
	background.visible = true
	background.modulate = Color.WHITE
	if ResourceLoader.exists("res://scenes/scene4.png"):
		background.texture = load("res://scenes/scene4.png")
	background.pivot_offset = LAPTOP_ZOOM_PIVOT
	background.scale = Vector2.ONE
	background.position = Vector2.ZERO

	browser_root.visible = true
	browser_root.modulate.a = 0.0
	browser_search_input.text = ""
	_sync_browser_url("")
	browser_results_container.visible = false
	browser_results_container.modulate.a = 0.0
	browser_cursor.visible = true
	browser_cursor.position = Vector2(2450.0, 1450.0)

	var zoom_tween: Tween = create_tween().set_parallel(true)
	zoom_tween.tween_property(background, "scale", Vector2.ONE * LAPTOP_ZOOM_SCALE, 1.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	zoom_tween.tween_property(background, "position", (BASE_SIZE * 0.5 - LAPTOP_ZOOM_PIVOT) * (LAPTOP_ZOOM_SCALE - 1.0), 1.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await zoom_tween.finished
	if not browser_active or token != browser_typing_token:
		return

	browser_zooming = false
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(browser_root, "modulate:a", 1.0, 0.30)
	await fade_tween.finished
	if not browser_active or token != browser_typing_token:
		return

	var input_pos: Vector2 = browser_search_input.global_position + Vector2(90.0, 28.0)
	await _move_cursor_to(input_pos, 0.45)
	if not browser_active or token != browser_typing_token:
		return
	await _pulse_cursor_click()
	if not browser_active or token != browser_typing_token:
		return

	dialogue_panel.position = Vector2(1300.0, 1740.0)
	dialogue_panel.size = Vector2(1240.0, 210.0)
	dialogue_label.position = Vector2(44, 20)
	dialogue_label.size = Vector2(1152.0, 170.0)
	dialogue_panel.visible = true
	dialogue_label.visible = true
	_style_dialogue()

	var full_dlg: String = str(current_entry.text)
	dialogue_label.text = full_dlg
	dialogue_label.visible_characters = 0

	browser_typing = true
	is_typing = true
	typing_token += 1
	var dlg_token: int = typing_token

	var total_chars: int = max(query_text.length(), 1)
	var total_dlg_chars: int = max(full_dlg.length(), 1)
	var typed_chars: int = 0
	var step_delay: float = float(current_entry.get("slow", 0.085)) * 0.35

	for idx in range(full_dlg.length()):
		if not browser_active or dlg_token != typing_token:
			return
		dialogue_label.visible_characters = idx + 1
		if idx % 6 == 0:
			typewriter_player.stop()
			typewriter_player.stream = typewriter_stream
			typewriter_player.play()

		var target_chars: int = int(round(float(idx + 1) / float(total_dlg_chars) * float(total_chars)))
		while typed_chars < target_chars and typed_chars < query_text.length():
			browser_search_input.text += query_text[typed_chars]
			browser_search_input.caret_column = browser_search_input.text.length()
			_sync_browser_url(browser_search_input.text)
			var caret_x: float = min(browser_search_input.global_position.x + 36.0 + float(typed_chars) * 15.0, browser_search_input.global_position.x + browser_search_input.size.x - 40.0)
			browser_cursor.position = Vector2(caret_x, browser_search_input.global_position.y + 28.0)
			typed_chars += 1
			await get_tree().create_timer(0.035).timeout

		await get_tree().create_timer(step_delay).timeout

	if not browser_active or dlg_token != typing_token:
		return
	typewriter_player.stop()
	dialogue_label.text = full_dlg
	dialogue_label.visible_characters = -1
	browser_search_input.text = query_text
	browser_search_input.caret_column = browser_search_input.text.length()
	_sync_browser_url(query_text)
	_show_browser_results_dashboard()
	browser_typing = false
	is_typing = false
	waiting_for_input = true
	_set_continue_visible(true, "SPACE / CLICK TO CONTINUE")

func _trigger_browser_enter() -> void:
	if not browser_active:
		return
	if browser_zooming or browser_typing:
		browser_typing_token += 1
		typing_token += 1
		browser_zooming = false
		browser_typing = false
		typewriter_player.stop()
		background.pivot_offset = LAPTOP_ZOOM_PIVOT
		background.scale = Vector2.ONE * LAPTOP_ZOOM_SCALE
		background.position = (BASE_SIZE * 0.5 - LAPTOP_ZOOM_PIVOT) * (LAPTOP_ZOOM_SCALE - 1.0)
		browser_root.modulate.a = 1.0
		dialogue_panel.position = Vector2(1300.0, 1740.0)
		dialogue_panel.size = Vector2(1240.0, 210.0)
		dialogue_label.position = Vector2(44, 20)
		dialogue_label.size = Vector2(1152.0, 170.0)
		dialogue_panel.visible = true
		dialogue_label.visible = true
		_style_dialogue()
		dialogue_label.text = current_entry.text
		dialogue_label.visible_characters = -1
		browser_search_input.text = browser_current_query
		browser_search_input.caret_column = browser_search_input.text.length()
		_sync_browser_url(browser_current_query)
		browser_cursor.visible = true
		browser_cursor.position = browser_search_input.global_position + Vector2(220.0, 28.0)
		_show_browser_results_dashboard()
		is_typing = false
		waiting_for_input = true
		_set_continue_visible(true, "SPACE / CLICK TO CONTINUE")
		return

	_set_continue_visible(false)
	entry_index += 1
	_show_entry()

func _hide_browser_scene() -> void:
	browser_active = false
	browser_zooming = false
	browser_typing = false
	browser_results_shown = false
	browser_typing_token += 1
	browser_root.visible = false
	browser_root.modulate.a = 0.0
	browser_results_container.visible = false
	browser_results_container.modulate.a = 0.0
	browser_cursor.visible = false
	background.scale = Vector2.ONE
	background.position = Vector2.ZERO
	background.pivot_offset = BASE_SIZE / 2.0

func _build_script() -> void:
	entries = [
		{"image": "scene1_4k.png", "text": "To continue, press SPACE", "instant": false, "kind": "prompt"},
		{"image": "scene1_4k.png", "text": "The asterisks (* *) indicate that the dialogue belongs to the character's mind.", "instant": false, "kind": "instruction"},
		{"image": "scene1_4k.png", "text": "We still gotta build downtown, cousin. It's better if I call mom and tell her that it will take much longer.", "instant": false, "kind": "spoken", "speaker": "Cousin", "slow": 0.055},
		{"image": "scene2_4k.png", "text": "I love you so much, sweetie.", "instant": false, "kind": "spoken", "speaker": "Grandma"},
		{"image": "scene2_4k.png", "text": "Please remember me when I've passed away.", "instant": false, "kind": "spoken", "speaker": "Grandma"},
		{"black": true, "text": "*But one day, something started to paint my life with a melancholic yellow.*", "instant": false, "kind": "narration"},
		{"image": "scene3.png", "text": "*I'm so anxious. I don't wanna arrive at the party.*", "instant": false, "kind": "narration", "speaker": "Jammy", "ambience": "breath_heart"},
		{"image": "scene3.png", "text": "*You won't be able to control your eye movements.*", "instant": false, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*You won't be able to control what you say.*", "instant": false, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*Don't worry, all those thoughts are lies.*", "instant": false, "kind": "spoken", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*Nobody can notice things like my eye movements or a shift in my mood.*", "instant": false, "kind": "spoken", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*But how do people notice when your eye movements aren't okay, or when somebody is, for example... falling in love with you?.*", "instant": false, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*Shut up, mind.*", "instant": false, "kind": "spoken", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*Actions will happen faster than you can react. For example, if you see that old aunt who doesn't get along with you, you might look at her as if you were falling in love with her.*", "instant": false, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*You will speak in a tone of voice you don't like because your mind will trigger it before you can do anything about it.*", "instant": false, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*I think I'm ruined. I just wanna close my eyes and forget everything.*", "instant": false, "kind": "spoken", "speaker": "Jammy"},
		{"image": "scene4.png", "text": "*Maybe if I type what I'm feeling during these holidays, I'll find something revelatory.*", "instant": false, "kind": "narration", "speaker": "Jammy", "slow": 0.085},
		{"browser": true, "image": "scene4.png", "search_query": "unwanted thoughts and urge to do something to get rid of them", "text": "*What do I have if I get unwanted thoughts and the need to do something to get rid of them?*", "instant": false, "kind": "narration", "speaker": "Jammy", "slow": 0.11},
		{"image": "scene6.png", "text": "*It says... Obsessive-Compulsive Disorder, and the cycle is a trap. But I feel like it happens...", "instant": false, "kind": "narration", "speaker": "Jammy", "in_browser": true},
		{"image": "scene6.png", "text": "automatically. And it also says that it's... INCURABLE.*", "instant": false, "kind": "narration", "speaker": "Jammy", "in_browser": true},
		{"image": "scene6.png", "text": "*Your life can be summed up by the fact that this illness will bother you until your very last second.*", "instant": false, "kind": "mind", "speaker": "Jammy", "in_browser": true},
		{"image": "scene6.png", "text": "*My biggest dream is just...", "instant": false, "kind": "narration", "speaker": "Jammy", "in_browser": true},
		{"image": "scene6.png", "text": "TO HAVE A NORMAL LIFE. FOR EXAMPLE, TO HAVE FUN WITHOUT THIS...*", "instant": false, "kind": "narration", "speaker": "Jammy", "in_browser": true},
		{"image": "scene6.png", "text": "*DESPICABLE...*", "instant": false, "kind": "narration", "speaker": "Jammy", "in_browser": true},
		{"image": "scene6.png", "text": "*BASTARD!*", "instant": false, "kind": "narration", "speaker": "Jammy", "ambience": "cry", "in_browser": true},
		{"image": "scene6.png", "text": "*Say whatever you want, nothing will change. And you know it... you know...*", "instant": false, "kind": "mind", "speaker": "Jammy", "in_browser": true},
		{"image": "scene6.png", "text": "*You aren't brave enough to end this forever by yourself.*", "instant": false, "kind": "mind", "speaker": "Jammy", "in_browser": true},
		{"image": "scene6.png", "text": "*You know your destiny is worse than death.*", "instant": false, "kind": "mind", "speaker": "Jammy", "in_browser": true},
		{"image": "scene7and8.png", "text": "*Ugh... tomorrow is my first day of high school. It's the only school of this grade in this county.*", "instant": false, "kind": "narration", "speaker": "Jammy"},
		{"image": "scene7and8.png", "text": "*I'll see the same people I've always seen at school. What if...", "instant": false, "kind": "narration", "speaker": "Jammy", "ambience": "breath"},
		{"image": "scene7and8.png", "text": "...they don't treat me like they used to 'cause of OCD, and I take all these troubles outside?*", "instant": false, "kind": "narration", "speaker": "Jammy"},
		{"image": "scene7and8.png", "text": "*Oh, you will. And you know, you haven't been diagnosed by a professional.*", "instant": false, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene7and8.png", "text": "*So you have both problems: the mental illness and the uncertainty of not being sure if it's even OCD.*", "instant": false, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene7and8.png", "text": "*So it's more difficult to treat something when you don't even know what it is.*", "instant": false, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene7and8.png", "text": "*It's scary to do it, but it's even scarier to live 'cause I can't end this easily.*", "instant": false, "kind": "narration", "speaker": "Jammy"},
		{"image": "scene9.png", "text": "You're insane. We don't like you.", "instant": false, "kind": "spoken", "speaker": "Classmates"},
		{"image": "scene9.png", "text": "Yesterday I saw ya at the party while I was doing the team's project.", "instant": false, "kind": "spoken", "speaker": "Jammy"},
		{"image": "scene9.png", "text": "At least we have friends...", "instant": false, "kind": "spoken", "speaker": "Classmates", "ambience": "breath"},
		{"image": "scene9.png", "text": "*What if you start to behave like it never happened?*", "instant": false, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene9.png", "text": "*Like for example a cheerful mood... you won't be able to control it.*", "instant": false, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene9.png", "text": "*The more you try to control your seriousness, the more you'll do the opposite.*", "instant": false, "kind": "mind", "speaker": "Jammy"},
		{"black": true, "text": "*My grandma has passed away. I couldn't enjoy her last moments due to OCD.*", "instant": false, "kind": "narration"},
		{"black": true, "text": "*Tomorrow will be my first day at Art University.*", "instant": false, "kind": "narration", "ambience": "breath"},
		{"black": true, "text": "*I don't want to ruin it like high school. I've been feeling so guilty 'bout it and everything.*", "instant": false, "kind": "narration"},
		{"black": true, "text": "*I know that not everything is my fault, but I can't help thinking this way.*", "instant": false, "kind": "narration"},
		{"black": true, "text": "*Everything hurts.*", "instant": false, "kind": "narration"},
		{"black": true, "text": "*I wanna cry but I can't.*", "instant": false, "kind": "narration"},
		{"image": "scene10.png", "text": "*They can't notice you.*", "instant": false, "kind": "narration", "speaker": "Jammy", "ambience": "heartbeat"},
		{"image": "scene10.png", "text": "*But I can't stop being ridiculously tense, anyways.*", "instant": false, "kind": "narration", "speaker": "Jammy", "ambience": "heartbeat"},
		{"image": "scene10.png", "text": "*Oh no, no, no... somebody's approaching me.*", "instant": false, "kind": "narration", "speaker": "Jammy", "ambience": "heartbeat"},
		{"image": "scene10.png", "text": "*What if I mess it up like I messed up other relationships?*", "instant": false, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene10.png", "text": "*Where can I turn my head to accomplish both: not looking like I'm ignoring her, and not looking at her while she's coming over?*", "instant": false, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene10.png", "text": "*Your face looks like you hate her. You try to fix it, but it isn't enough.*", "instant": false, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene11.png", "text": "Hiiii!", "instant": false, "kind": "spoken", "speaker": "Xcarlet", "ambience": "heartbeat"},
		{"image": "scene12.png", "text": "*This girl's so pretty... I like her. If I look ugly, I'll feel way less pressure around her, 'cause I won't be liked by her, so my OCD won't have the chance to betray me and fuck this relationship up.*", "instant": false, "kind": "narration", "speaker": "Jammy"},
		{"focus": true, "text": "", "instant": true, "kind": "narration"},
		{"image": "scene11.png", "text": "Umm, hi.", "instant": false, "kind": "spoken", "speaker": "Jammy", "sequence": true},
		{"image": "scene11.png", "text": "You looked so concerned. Is everything okay?", "instant": false, "kind": "spoken", "speaker": "Xcarlet", "sequence": true},
		{"image": "scene11.png", "text": "*Oh no, she actually cares about me. What if I disappoint her? What if I look ungrateful? What if I act rude and she ends up throwing me away like the others.....realizing over time that I'm even worse than at first, and it's not just embarrassment...*", "instant": false, "kind": "narration", "speaker": "Jammy", "sequence": true},
		{"image": "scene11.png", "text": "Umm, yeah, LMAO!", "instant": false, "kind": "spoken", "speaker": "Jammy", "sequence": true},
		{"image": "scene11.png", "text": "*LMAO? You looked so ridiculous. Always being such a weirdo.*", "instant": false, "kind": "mind", "speaker": "Jammy", "mixing": "start", "mixing_start": 0.5, "sequence": true},
		{"image": "scene11.png", "text": "*Remember, you're not comfortable touching those cringe notes. I don't wanna give in to a compulsion.....just remember it makes you anxious, and it won't happen again.*", "instant": false, "kind": "narration", "speaker": "Jammy", "mixing": "keep", "sequence": true},
		{"image": "scene11.png", "text": "Well, I'm glad to meet you! My name's Xcarlet, what's your name?", "instant": false, "kind": "spoken", "speaker": "Xcarlet", "mixing": "stop", "sequence": true},
		{"image": "scene11.png", "text": "I'm Jammy.", "instant": false, "kind": "spoken", "speaker": "Jammy", "sequence": true},
		{"image": "scene11.png", "text": "Animation?", "instant": false, "kind": "spoken", "speaker": "Xcarlet", "sequence": true},
		{"image": "scene11.png", "text": "Yeah, I guess we'll be in the same class.", "instant": false, "kind": "spoken", "speaker": "Jammy", "sequence": true},
		{"image": "scene11.png", "text": "Then let's head to our classroom!", "instant": false, "kind": "spoken", "speaker": "Xcarlet", "sequence": true},
		{"image": "scene11.png", "text": "*To be honest, I'm doing pretty well.*", "instant": false, "kind": "narration", "speaker": "Jammy", "sequence": true},
		{"image": "scene11.png", "text": "*But what if I mess it up by reminding you that you're still you? You were just on autopilot, and from now on you won't be.....realizing you have years ahead to keep up this act, and at this very moment she could notice something and suddenly be scared of you.*", "instant": false, "kind": "mind", "speaker": "Jammy", "mixing": "start", "mixing_start": 5.0, "sequence": true},
		{"image": "scene14.png", "text": "*After that crisis before classes, I feel like I acted so bland and rude to her. I realized I was still the same old me, and that's why I got so tense. The worst part is that I wish I could kiss her, but I'm just a weirdo. Why do I gotta be full of these thoughts right when I'm in front of such a beautiful girl?*", "instant": false, "kind": "narration", "speaker": "Jammy", "mixing": "stop", "sfx": "sigh"},
		{"image": "scene14.png", "text": "*I'll just close my eyes and imagine something insane but funny.*", "instant": false, "kind": "narration", "speaker": "Jammy"}
	]

func _fits_in_dialogue_box(candidate: String, font: Font, font_size: int, max_width: float, max_height: float) -> bool:
	var measured: Vector2 = font.get_multiline_string_size(candidate, HORIZONTAL_ALIGNMENT_CENTER, max_width, font_size)
	return measured.y <= max_height

func _split_long_dialogues() -> void:
	var split_entries: Array[Dictionary] = []
	var prev_was_browser_chain: bool = false
	for idx in range(entries.size()):
		var entry: Dictionary = entries[idx]
		var text: String = str(entry.get("text", ""))
		if bool(entry.get("focus", false)) or bool(entry.get("browser", false)) or bool(entry.get("no_split", false)):
			var item_copy: Dictionary = entry.duplicate()
			if bool(entry.get("browser", false)):
				prev_was_browser_chain = true
			split_entries.append(item_copy)
			continue

		var kind: String = str(entry.get("kind", ""))
		var image_name: String = str(entry.get("image", ""))
		var is_mind: bool = kind == "mind"
		var has_start_marker: bool = is_mind or text.begins_with("*")
		var has_end_marker: bool = is_mind or text.ends_with("*")
		var inner_text: String = text.trim_prefix("*").trim_suffix("*")

		var font: Font = ROCK_SALT_FONT if is_mind else FREDOKA_FONT
		var font_size: int = 36 if is_mind else 46
		var max_width: float = 1130.0
		var max_height: float = 165.0

		if kind == "prompt":
			font_size = 58
			max_width = 1220.0
			max_height = 220.0
		elif kind == "instruction":
			font_size = 48
			max_width = 1520.0
			max_height = 260.0
		elif image_name == "scene11.png":
			max_width = 1070.0
			max_height = 155.0
		elif image_name == "scene10.png":
			max_width = 990.0
			max_height = 155.0
		elif image_name == "scene14.png":
			max_width = 1210.0
			max_height = 175.0

		var chunks: Array[String] = []
		var full_marked: String = _apply_thought_markers(inner_text, has_start_marker, has_end_marker)
		if _fits_in_dialogue_box(full_marked, font, font_size, max_width, max_height):
			chunks.append(full_marked)
		else:
			var chunk: String = ""
			var start_m: bool = has_start_marker
			for word in inner_text.split(" "):
				var candidate: String = word if chunk.is_empty() else chunk + " " + word
				var marked_candidate: String = _apply_thought_markers(candidate, start_m, has_end_marker)
				if not chunk.is_empty() and not _fits_in_dialogue_box(marked_candidate, font, font_size, max_width, max_height):
					chunks.append(_apply_thought_markers(chunk, start_m, false))
					start_m = false
					chunk = word
				else:
					chunk = candidate
			if not chunk.is_empty():
				chunks.append(_apply_thought_markers(chunk, start_m, has_end_marker))

		for c_idx in range(chunks.size()):
			var chunk_entry: Dictionary = entry.duplicate()
			chunk_entry["text"] = chunks[c_idx]
			if prev_was_browser_chain and str(chunk_entry.get("image", "")) == "scene6.png":
				chunk_entry["in_browser"] = true
			if c_idx > 0 and str(chunk_entry.get("mixing", "")) == "start":
				chunk_entry["mixing"] = "keep"
			if c_idx > 0 and chunk_entry.has("sfx"):
				chunk_entry.erase("sfx")
			split_entries.append(chunk_entry)

		if str(entry.get("image", "")) != "scene6.png":
			prev_was_browser_chain = false

	entries = split_entries

func _apply_thought_markers(text: String, add_start: bool, add_end: bool) -> String:
	var result: String = text
	if add_start:
		result = "*" + result
	if add_end:
		result += "*"
	return result

func _play_dialogue_typewriter(token: int) -> void:
	var full_text: String = str(current_entry.get("text", ""))
	dialogue_label.text = full_text
	dialogue_label.visible_characters = 0

	var total_chars: int = full_text.length()
	if total_chars <= 0:
		is_typing = false
		waiting_for_input = true
		_set_continue_visible(true, "SPACE / CLICK TO CONTINUE")
		return

	var char_delay: float = max(float(current_entry.get("slow", 0.045)) * 0.28, 0.012)
	var plays_typewriter: bool = str(current_entry.get("kind", "")) != "mind"

	for idx in range(total_chars):
		if token != typing_token:
			return
		dialogue_label.visible_characters = idx + 1
		if plays_typewriter and idx % 7 == 0:
			typewriter_player.stop()
			typewriter_player.stream = typewriter_stream
			typewriter_player.play()
		await get_tree().create_timer(char_delay).timeout

	if token == typing_token:
		if plays_typewriter:
			typewriter_player.stop()
		dialogue_label.visible_characters = -1
		is_typing = false
		waiting_for_input = true
		_set_continue_visible(true, "SPACE / CLICK TO CONTINUE")

func _show_entry() -> void:
	if entry_index >= entries.size():
		_show_ending()
		return
	current_entry = entries[entry_index]
	_guardar_estado_actual()
	hide_cat_minigame_prompt()
	if bool(current_entry.get("focus", false)):
		_hide_browser_scene()
		_start_focus()
		return
	if bool(current_entry.get("browser", false)):
		_update_ambience()
		_start_browser_scene(current_entry)
		return
	if bool(current_entry.get("in_browser", false)) and browser_active:
		_set_continue_visible(false)
		dialogue_panel.visible = true
		dialogue_label.visible = true
		focus_instructions.visible = false
		_show_browser_results_dashboard()
		_update_ambience()
		_style_dialogue()
		waiting_for_input = false
		is_typing = true
		typing_token += 1
		_play_dialogue_typewriter(typing_token)
		return

	_hide_browser_scene()
	_set_continue_visible(false)
	dialogue_panel.visible = true
	dialogue_label.visible = true
	focus_instructions.visible = false
	if bool(current_entry.get("black", false)):
		background.texture = null
		black_background.visible = true
	else:
		black_background.visible = false
		background.modulate = Color.WHITE
		var img_path: String = "res://scenes/" + str(current_entry.get("image", ""))
		if ResourceLoader.exists(img_path):
			background.texture = load(img_path)
		_apply_camera_focus()
	_update_ambience()
	_style_dialogue()
	dialogue_label.visible = true
	focus_instructions.visible = false
	waiting_for_input = false
	is_typing = true
	typing_token += 1
	_play_dialogue_typewriter(typing_token)

func _start_focus() -> void:
	vn_focus_mode = true
	vn_focus_intro = true
	focus_state = FocusState.EFFORT
	focus_effort = 0.0
	focus_window_timer = 0.0
	focus_fakeout_timer = 0.0
	focus_fakeout_armed = true
	focus_fakeout2_armed = true
	focus_fakeout3_armed = true
	focus_exit_prompt = false
	speaker_panel.visible = false
	background.texture = null
	black_background.visible = false
	focus_image.texture = SCENE12_TEX
	focus_image.visible = true
	focus_image.scale = Vector2.ONE
	focus_image.position = Vector2.ZERO
	focus_shader_material.set_shader_parameter("blur_amount", 0.0)
	focus_vignette.visible = false
	var vignette_material: ShaderMaterial = focus_vignette.material as ShaderMaterial
	vignette_material.set_shader_parameter("vignette_alpha", 0.0)
	focus_status.visible = false
	focus_hint.visible = false
	dialogue_panel.visible = true
	dialogue_panel.position = Vector2(1220.0, 1490.0)
	dialogue_panel.size = Vector2(1400.0, 300.0)
	dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(Color(0.11, 0.12, 0.16, 0.96), Color(JAMMY_COLOR.r, JAMMY_COLOR.g, JAMMY_COLOR.b, 0.90)))
	dialogue_label.visible = false
	focus_instructions.position = Vector2(44, 24)
	focus_instructions.size = Vector2(1312.0, 252.0)
	focus_instructions.text = (
		"[center][color=#8ab4f8]✦ FOCUS CHALLENGE[/color]\n"
		+ "Hold [color=#f5d08a][b][W][/b][/color] + [color=#f5d08a][b][S][/b][/color] to build tension, then [color=#ff666b][b]RELEASE[/b][/color] at the peak.\n"
		+ "Press [color=#f5d08a][b][SPACE][/b][/color] or [color=#f5d08a][b]CLICK[/b][/color] to begin.[/center]"
	)
	focus_instructions.visible = true
	_set_continue_visible(true, "SPACE / CLICK TO BEGIN")
	mind_heartbeat_player.stop()
	ambience_player.stop()

func _begin_focus_game() -> void:
	vn_focus_intro = false
	dialogue_panel.visible = false
	focus_instructions.visible = false
	focus_state = FocusState.EFFORT
	focus_effort = 0.0
	_set_continue_visible(false)
	focus_status.visible = false
	focus_hint.text = "HOLD [W] + [S] TO BUILD TENSION"
	focus_hint.add_theme_color_override("font_color", GOLD_ACCENT)
	focus_hint.visible = true
	ambience_player.stop()
	sonido_esfuerzo.stream = effort_stream
	sonido_esfuerzo.pitch_scale = 0.85
	sonido_esfuerzo.volume_db = 0.0
	sonido_esfuerzo.play()

func _update_focus_key_hint(is_pressing: bool) -> void:
	if focus_hint == null:
		return
	focus_hint.visible = true
	if focus_state == FocusState.WINDOW:
		focus_hint.text = "RELEASE [W] + [S] NOW!"
		focus_hint.add_theme_color_override("font_color", MIND_COLOR)
	elif is_pressing:
		focus_hint.text = "KEEP HOLDING [W] + [S] — RELEASE AT PEAK"
		focus_hint.add_theme_color_override("font_color", SKY_ACCENT)
	else:
		focus_hint.text = "HOLD [W] + [S] TO BUILD TENSION"
		focus_hint.add_theme_color_override("font_color", GOLD_ACCENT)

func _apply_focus_tension() -> void:
	var progress: float = focus_effort / FOCUS_EFFORT_MAX
	var zoom: float = 1.0 + progress * 0.12
	var shake: float = sin(Time.get_ticks_msec() * 0.068) * progress * 10.5
	focus_image.scale = Vector2(zoom, zoom)
	focus_image.position = Vector2(shake, cos(Time.get_ticks_msec() * 0.074) * progress * 7.0)
	sonido_esfuerzo.pitch_scale = lerp(0.85, 1.90, progress)
	sonido_esfuerzo.volume_db = lerp(0.0, 4.0, progress)

func _begin_focus_fakeout() -> void:
	focus_fakeout_timer = FOCUS_FAKEOUT_TIME
	focus_image.texture = SCENE13_TEX
	focus_shader_material.set_shader_parameter("blur_amount", FOCUS_FAKEOUT_BLUR)

func _begin_focus_window() -> void:
	focus_state = FocusState.WINDOW
	focus_window_timer = FOCUS_WINDOW_TIME
	focus_image.texture = SCENE13_TEX
	focus_image.scale = Vector2.ONE
	focus_image.position = Vector2.ZERO
	focus_shader_material.set_shader_parameter("blur_amount", FOCUS_CLIMAX_BLUR)
	focus_vignette.visible = false
	sonido_esfuerzo.stop()
	sonido_corte.stream = cut_stream
	sonido_corte.play()

func _complete_focus() -> void:
	focus_state = FocusState.RESOLUTION
	sonido_esfuerzo.stop()
	focus_status.visible = false
	focus_hint.visible = false
	mind_heartbeat_player.stop()
	ambience_player.stop()
	dialogue_panel.visible = false
	focus_instructions.visible = false
	_set_continue_visible(false)
	waiting_for_input = false
	vn_focus_mode = false
	focus_vignette.visible = true
	var resolution_tween: Tween = create_tween()
	resolution_tween.tween_method(_update_resolution_effect, 0.0, 1.0, FOCUS_RESOLUTION_TIME)
	resolution_tween.tween_callback(_finish_resolution_effect)

func _reset_focus_cycle() -> void:
	focus_image.texture = SCENE12_TEX
	focus_image.visible = true
	focus_state = FocusState.EFFORT
	focus_effort = 0.0
	focus_window_timer = 0.0
	focus_fakeout_timer = 0.0
	focus_fakeout_armed = true
	focus_fakeout2_armed = true
	focus_fakeout3_armed = true
	focus_image.scale = Vector2.ONE
	focus_image.position = Vector2.ZERO
	focus_shader_material.set_shader_parameter("blur_amount", 0.0)
	focus_vignette.visible = false
	var vignette_material: ShaderMaterial = focus_vignette.material as ShaderMaterial
	vignette_material.set_shader_parameter("vignette_alpha", 0.0)
	sonido_esfuerzo.pitch_scale = 0.85
	sonido_esfuerzo.volume_db = 0.0
	sonido_esfuerzo.play()

func _update_focus_music(is_pressing: bool) -> void:
	if not is_pressing:
		if ambience_player.playing:
			ambience_player.stop()
		return
	if ambience_player.stream != FOCUS_SUCCESS_STREAM or not ambience_player.playing:
		ambience_player.stream = FOCUS_SUCCESS_STREAM
		ambience_player.volume_db = 0.0
		ambience_player.play(5.0)
	elif ambience_player.get_playback_position() >= FOCUS_SUCCESS_STREAM.get_length():
		ambience_player.play(5.0)

func _update_resolution_effect(progress: float) -> void:
	focus_shader_material.set_shader_parameter("blur_amount", lerp(FOCUS_CLIMAX_BLUR, 0.0, progress))
	var shake_amount: float = lerp(3.0, 24.0, progress)
	focus_image.position = Vector2(
		sin(Time.get_ticks_msec() * 0.06) * shake_amount,
		cos(Time.get_ticks_msec() * 0.071) * shake_amount
	)
	focus_image.scale = Vector2.ONE * (1.0 + progress * 0.035)
	var vignette_material: ShaderMaterial = focus_vignette.material as ShaderMaterial
	vignette_material.set_shader_parameter("vignette_alpha", progress * 0.85)

func _finish_resolution_effect() -> void:
	focus_image.position = Vector2.ZERO
	focus_image.scale = Vector2.ONE
	focus_shader_material.set_shader_parameter("blur_amount", 0.0)
	var vignette_material: ShaderMaterial = focus_vignette.material as ShaderMaterial
	vignette_material.set_shader_parameter("vignette_alpha", 0.0)
	focus_vignette.visible = false
	focus_exit_prompt = true
	dialogue_panel.visible = false
	dialogue_label.visible = false
	focus_instructions.visible = false
	_set_continue_visible(true, "SPACE / CLICK TO CONTINUE")

func _leave_focus_game() -> void:
	focus_exit_prompt = false
	vn_focus_mode = false
	_set_continue_visible(false)
	_stop_mixing_game_loop()
	dialogue_panel.visible = false
	focus_instructions.visible = false
	focus_image.visible = false
	background.visible = true
	background.texture = load("res://scenes/scene11.png")
	entry_index += 1
	_show_entry()

func _start_mixing_game_loop(start_position: float) -> void:
	mixing_game_active = true
	mixing_loop_start = start_position
	ambience_player.stop()
	ambience_player.stream = FOCUS_SUCCESS_STREAM
	ambience_player.volume_db = 0.0
	ambience_player.play(mixing_loop_start)

func _stop_mixing_game_loop() -> void:
	mixing_game_active = false
	if ambience_player.stream == FOCUS_SUCCESS_STREAM:
		ambience_player.stop()

func _maintain_mixing_game_loop() -> void:
	if not ambience_player.playing:
		ambience_player.play(mixing_loop_start)
	elif ambience_player.get_playback_position() >= 19.0:
		ambience_player.play(mixing_loop_start)

func _advance() -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_advance_msec < 90:
		return
	_last_advance_msec = now_msec

	if browser_active and not bool(current_entry.get("in_browser", false)):
		_trigger_browser_enter()
		return
	if is_typing:
		typing_token += 1
		typewriter_player.stop()
		dialogue_label.text = str(current_entry.get("text", ""))
		dialogue_label.visible_characters = -1
		is_typing = false
		waiting_for_input = true
		_set_continue_visible(true, "SPACE / CLICK TO CONTINUE")
		return
	if waiting_for_input:
		_set_continue_visible(false)
		entry_index += 1
		_show_entry()

func _apply_camera_focus() -> void:
	background.scale = Vector2.ONE
	background.position = Vector2.ZERO
	background.pivot_offset = BASE_SIZE / 2.0
	var image_name: String = str(current_entry.get("image", ""))
	var text: String = str(current_entry.get("text", ""))
	if image_name == "scene7and8.png" and text.contains("It's scary to do it"):
		background.scale = Vector2(2.1, 2.1)
		background.position = Vector2(-2880, -270)

func _handle_advance_event(event: InputEvent) -> void:
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

	var advance_pressed: bool = false
	if event is InputEventKey:
		advance_pressed = event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)
	elif event is InputEventMouseButton:
		advance_pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if advance_pressed:
		if focus_exit_prompt:
			_leave_focus_game()
			return
		if vn_focus_mode:
			if vn_focus_intro:
				_begin_focus_game()
			return
		_advance()

func _input(event: InputEvent) -> void:
	_handle_advance_event(event)

func _unhandled_input(event: InputEvent) -> void:
	_handle_advance_event(event)

func _get_speaker_color(speaker_name: String) -> Color:
	match speaker_name.to_lower():
		"jammy":
			return JAMMY_COLOR
		"cousin":
			return COUSIN_COLOR
		"xcarlet":
			return XCARLET_COLOR
		"grandma":
			return GRANDMA_COLOR
		"classmates":
			return CLASSMATES_BOX_COLOR
		_:
			return TEXT_COLOR

func _style_dialogue() -> void:
	var kind: String = str(current_entry.get("kind", ""))
	var is_mind: bool = kind == "mind"
	var speaker: String = str(current_entry.get("speaker", ""))
	var image_name: String = str(current_entry.get("image", ""))
	var is_black: bool = bool(current_entry.get("black", false))

	if is_mind and speaker.is_empty() and not is_black:
		speaker = "Jammy"

	dialogue_label.add_theme_constant_override("outline_size", 4)
	dialogue_label.add_theme_color_override("font_outline_color", Color("#08080a"))
	dialogue_label.add_theme_color_override("font_shadow_color", Color("#000000f5"))
	dialogue_label.add_theme_constant_override("shadow_offset_x", 4)
	dialogue_label.add_theme_constant_override("shadow_offset_y", 4)

	var panel_pos: Vector2 = DIALOGUE_PANEL_POS
	var panel_size: Vector2 = DIALOGUE_PANEL_SIZE

	if browser_active or bool(current_entry.get("in_browser", false)):
		panel_pos = Vector2(1300.0, 1740.0)
		panel_size = Vector2(1240.0, 210.0)
	elif is_black:
		panel_pos = Vector2(1250.0, 940.0)
		panel_size = Vector2(1340.0, 250.0)
	elif image_name == "scene1_4k.png":
		panel_pos = Vector2(1620.0, 860.0)
	elif image_name == "scene2_4k.png":
		panel_pos = Vector2(2080.0, 480.0)
	elif image_name == "scene3.png":
		panel_pos = Vector2(1280.0, 920.0)
	elif image_name in ["scene4.png", "scene5.png", "scene6.png"]:
		panel_pos = Vector2(1300.0, 1180.0)
	elif image_name == "scene7and8.png":
		panel_pos = Vector2(960.0, 1040.0)
	elif image_name == "scene9.png":
		if speaker.to_lower() == "classmates":
			panel_pos = Vector2(1920.0, 1000.0)
		else:
			panel_pos = Vector2(1340.0, 1340.0)
	elif image_name == "scene10.png":
		panel_pos = Vector2(520.0, 940.0)
		panel_size = Vector2(1100.0, 220.0)
	elif image_name == "scene11.png":
		panel_size = Vector2(1180.0, 220.0)
		if speaker.to_lower() == "xcarlet":
			panel_pos = Vector2(860.0, 1040.0)
		else:
			panel_pos = Vector2(480.0, 1080.0)
	elif image_name == "scene12.png":
		panel_pos = Vector2(1320.0, 1480.0)
	elif image_name == "scene14.png":
		panel_pos = Vector2(1260.0, 480.0)
		panel_size = Vector2(1320.0, 240.0)

	if kind == "prompt":
		panel_pos = Vector2(1250.0, 920.0)
		panel_size = Vector2(1340.0, 280.0)
		dialogue_label.add_theme_font_size_override("font_size", 58)
	elif kind == "instruction":
		panel_pos = Vector2(1100.0, 860.0)
		panel_size = Vector2(1640.0, 320.0)
		dialogue_label.add_theme_font_size_override("font_size", 48)
	elif is_mind:
		dialogue_label.add_theme_font_size_override("font_size", 36)
	else:
		dialogue_label.add_theme_font_size_override("font_size", 46)

	dialogue_panel.position = panel_pos
	dialogue_panel.size = panel_size
	dialogue_label.position = Vector2(44, 24)
	dialogue_label.size = Vector2(panel_size.x - 88.0, panel_size.y - 48.0)

	if kind == "instruction" or kind == "prompt":
		speaker_panel.visible = false
		dialogue_label.add_theme_color_override("font_color", TEXT_COLOR)
		dialogue_label.add_theme_font_override("font", FREDOKA_FONT)
		dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(Color(0.14, 0.14, 0.17, 0.92), Color(JAMMY_COLOR.r, JAMMY_COLOR.g, JAMMY_COLOR.b, 0.80)))
	elif is_black:
		speaker_panel.visible = false
		dialogue_label.add_theme_color_override("font_color", MIND_COLOR if is_mind else TEXT_COLOR)
		dialogue_label.add_theme_font_override("font", ROCK_SALT_FONT if is_mind else FREDOKA_FONT)
		dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, Color(1.0, 0.98, 0.94, 0.35)))
	elif is_mind:
		dialogue_label.add_theme_color_override("font_color", MIND_COLOR)
		dialogue_label.add_theme_font_override("font", ROCK_SALT_FONT)
		var j_border: Color = Color(JAMMY_COLOR.r, JAMMY_COLOR.g, JAMMY_COLOR.b, 0.80)
		dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(MIND_PANEL_COLOR, j_border))
		speaker_panel.visible = true
		speaker_panel.position = Vector2(panel_pos.x + 36.0, panel_pos.y - SPEAKER_PANEL_SIZE.y + 2.0)
		speaker_panel.size = SPEAKER_PANEL_SIZE
		speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, JAMMY_COLOR))
		speaker_label.text = "Jammy"
		speaker_label.add_theme_color_override("font_color", JAMMY_COLOR)
	else:
		dialogue_label.add_theme_color_override("font_color", TEXT_COLOR)
		dialogue_label.add_theme_font_override("font", FREDOKA_FONT)
		if not speaker.is_empty():
			if speaker.to_lower() == "classmates":
				var box_border: Color = Color(CLASSMATES_BOX_COLOR.r, CLASSMATES_BOX_COLOR.g, CLASSMATES_BOX_COLOR.b, 0.85)
				dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, box_border))
				speaker_panel.visible = true
				speaker_panel.position = Vector2(panel_pos.x + 36.0, panel_pos.y - SPEAKER_PANEL_SIZE.y + 2.0)
				speaker_panel.size = SPEAKER_PANEL_SIZE
				speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, CLASSMATES_TAB_COLOR))
				speaker_label.text = "Classmates"
				speaker_label.add_theme_color_override("font_color", CLASSMATES_TEXT_COLOR)
			else:
				var s_color: Color = _get_speaker_color(speaker)
				var s_border: Color = Color(s_color.r, s_color.g, s_color.b, 0.80)
				dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, s_border))
				speaker_panel.visible = true
				speaker_panel.position = Vector2(panel_pos.x + 36.0, panel_pos.y - SPEAKER_PANEL_SIZE.y + 2.0)
				speaker_panel.size = SPEAKER_PANEL_SIZE
				speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, s_color))
				speaker_label.text = speaker
				speaker_label.add_theme_color_override("font_color", s_color)
		else:
			speaker_panel.visible = false
			dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, Color(1.0, 0.98, 0.94, 0.35)))

func _make_cat_prompt_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.16, 0.96)
	style.set_corner_radius_all(20)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(SKY_ACCENT.r, SKY_ACCENT.g, SKY_ACCENT.b, 0.88)
	style.content_margin_left = 54.0
	style.content_margin_right = 54.0
	style.content_margin_top = 34.0
	style.content_margin_bottom = 34.0
	return style

func _make_hint_pill_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
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

func _make_dialogue_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
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
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 0
	style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.85)
	return style

func _load_first_existing_audio(paths: Array[String]) -> AudioStream:
	for path in paths:
		if ResourceLoader.exists(path):
			return load(path)
	return null

func _build_audio() -> void:
	typewriter_stream = NORMAL_DIALOGUE_STREAM
	breath_stream = BREATHING_STREAM
	heartbeat_stream = HEARTBEAT_STREAM
	effort_stream = FOCUS_EFFORT_STREAM
	cut_stream = _make_tone(0.12, 180.0, 0.32, false)

	night_ambience_stream = _load_first_existing_audio([
		"res://assets/sounds/crickets-and-distant-owls.mp3",
		"res://crickets-and-distant-owls.mp3"
	])
	sigh_stream = _load_first_existing_audio([
		"res://assets/sounds/sighs.mp3",
		"res://assets/sounds/sighs.ogg",
		"res://assets/sounds/sighs.wav",
		"res://sighs.mp3",
		"res://sighs.ogg",
		"res://sighs.wav"
	])

	var effort_mp3: AudioStreamMP3 = effort_stream as AudioStreamMP3
	if effort_mp3:
		effort_mp3.loop = true
	var heartbeat_mp3: AudioStreamMP3 = heartbeat_stream as AudioStreamMP3
	if heartbeat_mp3:
		heartbeat_mp3.loop = true
	var success_mp3: AudioStreamMP3 = FOCUS_SUCCESS_STREAM as AudioStreamMP3
	if success_mp3:
		success_mp3.loop = false
	var night_mp3: AudioStreamMP3 = night_ambience_stream as AudioStreamMP3
	if night_mp3:
		night_mp3.loop = true
	var sigh_mp3: AudioStreamMP3 = sigh_stream as AudioStreamMP3
	if sigh_mp3:
		sigh_mp3.loop = false

func _make_tone(duration: float, frequency: float, volume: float, looping: bool) -> AudioStreamWAV:
	var rate: int = 22050
	var samples: int = int(duration * rate)
	var data: PackedByteArray = PackedByteArray()
	for i in samples:
		var sample: float = sin(TAU * frequency * float(i) / rate) * volume
		var value: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.append(value & 0xff)
		data.append((value >> 8) & 0xff)
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples
	return stream

func _update_ambience() -> void:
	var image_name: String = str(current_entry.get("image", ""))
	var is_mind: bool = str(current_entry.get("kind", "")) == "mind"
	var mixing_mode: String = str(current_entry.get("mixing", ""))
	var is_focus_sequence: bool = bool(current_entry.get("sequence", false))

	if str(current_entry.get("sfx", "")) == "sigh" and sigh_stream != null:
		sfx_player.stop()
		sfx_player.stream = sigh_stream
		sfx_player.volume_db = 0.0
		sfx_player.play()

	if is_focus_sequence:
		mind_breath_player.stop()
		mind_heartbeat_player.stop()
		if mixing_mode == "start":
			_start_mixing_game_loop(float(current_entry.get("mixing_start", 0.5)))
		elif mixing_mode == "stop":
			_stop_mixing_game_loop()
		if not mixing_game_active:
			ambience_player.stop()
		return

	if mixing_mode == "start":
		_start_mixing_game_loop(float(current_entry.get("mixing_start", 0.5)))
	elif mixing_mode == "stop":
		_stop_mixing_game_loop()
	if mixing_mode == "keep" or mixing_mode == "start":
		return
	if is_mind:
		ambience_player.stop()
		if not mind_breath_player.playing:
			mind_breath_player.stream = breath_stream
			mind_breath_player.volume_db = 0.0
			mind_breath_player.play()
		if not mind_heartbeat_player.playing:
			mind_heartbeat_player.stream = heartbeat_stream
			mind_heartbeat_player.volume_db = 0.0
			mind_heartbeat_player.play(0.0)
	elif image_name == "scene14.png":
		mind_heartbeat_player.stop()
		mind_breath_player.stop()
		if night_ambience_stream != null and (ambience_player.stream != night_ambience_stream or not ambience_player.playing):
			ambience_player.stop()
			ambience_player.stream = night_ambience_stream
			ambience_player.volume_db = 0.0
			ambience_player.play()
	elif image_name in ["scene10.png", "scene11.png"]:
		mind_heartbeat_player.stop()
		if ambience_player.stream != breath_stream or not ambience_player.playing:
			ambience_player.stop()
			ambience_player.stream = breath_stream
			ambience_player.volume_db = -3.0
			ambience_player.play()
	else:
		ambience_player.stop()
		mind_heartbeat_player.stop()
		mind_breath_player.stop()

func _show_ending() -> void:
	waiting_for_input = false
	is_typing = false
	hide_cat_minigame_prompt()
	_hide_browser_scene()
	_set_continue_visible(false)
	_stop_mixing_game_loop()
	ambience_player.stop()
	sfx_player.stop()

	var siguiente_escena := _buscar_siguiente_escena()
	if siguiente_escena.is_empty():
		push_error("No se encontró la escena 15 ni Level2.tscn. Volviendo al menú principal.")
		siguiente_escena = "res://main.tscn"

	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr != null and save_mgr.has_method("guardar_progreso") and siguiente_escena != "res://main.tscn":
		save_mgr.guardar_progreso(siguiente_escena, "Scene 15", {})

	var eye_trans: Node = get_node_or_null("/root/EyeTransition")
	if eye_trans != null and eye_trans.has_method("ir_a_escena_cerrando_ojos"):
		eye_trans.ir_a_escena_cerrando_ojos(siguiente_escena)
	else:
		get_tree().call_deferred("change_scene_to_file", siguiente_escena)

func _buscar_siguiente_escena() -> String:
	var candidatas: Array[String] = [
		"res://scenes/Level2.tscn",
		"res://Level2.tscn",
		"res://scenes/level2.tscn",
		"res://level2.tscn",
		"res://scenes/scene15.tscn",
		"res://scene15.tscn",
		"res://scenes/Scene15.tscn",
		"res://Scene15.tscn",
		"res://scenes/escena15.tscn",
		"res://escena15.tscn",
		"res://scenes/rose_park.tscn",
		"res://rose_park.tscn"
	]
	for ruta in candidatas:
		if ResourceLoader.exists(ruta):
			return ruta
	return ""
