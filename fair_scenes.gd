extends Node2D

const BASE_SIZE := Vector2(3840.0, 2160.0)
const SOUNDS_DIR := "res://assets/sounds/"
const TEXT_COLOR := Color("#fff9f0")
const PANEL_COLOR := Color(0.22, 0.23, 0.25, 0.68)
const MIND_PANEL_COLOR := Color(0.10, 0.10, 0.12, 0.88)
const SPEAKER_BG_COLOR := Color(0.18, 0.19, 0.21, 0.82)
const MIND_COLOR := Color("#ff666b")
const ACCENT_COLOR := Color("#fff9f0")

# Colores de personajes
const JAMMY_COLOR := Color("#f5d08a")
const XCARLET_COLOR := Color("#5bc0eb")

# Tamaño estándar y posiciones homogenizadas (3840x2160)
const DIALOGUE_PANEL_SIZE := Vector2(1280.0, 250.0)
const MIND_PANEL_SIZE := Vector2(1340.0, 290.0)
const JAMMY_BOTTOM_POS := Vector2(1280.0, 1825.0)
const PARALLEL_MIND_POS := Vector2(72.0, 56.0)
const SPEAKER_PANEL_SIZE := Vector2(320.0, 62.0)

# Bucle de fair'sAudio: minuto 6:30 (390 s) al minuto 14:00 (840 s)
const FAIR_AUDIO_LOOP_START := 390.0
const FAIR_AUDIO_LOOP_END := 840.0

const FREDOKA_FONT = preload("res://fonts/Fredoka-Regular.ttf")
const ROCK_SALT_FONT = preload("res://fonts/RockSalt-Regular.ttf")
const NORMAL_DIALOGUE_STREAM = preload("res://assets/sounds/Soft_pencil_tap_on_n_#1-1794378651940.mp3")

@export_file("*.tscn") var next_scene_path: String = "res://scenes/scene17.tscn"

var ui_root: Control
var background: TextureRect
var black_background: ColorRect

# Cuadro principal (abajo al centro)
var dialogue_panel: Panel
var dialogue_label: Label
var speaker_panel: Panel
var speaker_label: Label

# Cuadro rojo paralelo en la esquina superior izquierda
var parallel_mind_panel: Panel
var parallel_mind_label: Label

var continue_label: Label

var typewriter_player: AudioStreamPlayer
var fair_ambience_player: AudioStreamPlayer
var typewriter_stream: AudioStream
var fair_audio_stream: AudioStream

var tex_fair_overview: Texture2D
var tex_scene2_fair: Texture2D

var story_steps: Array[Dictionary] = []
var step_index := 0
var main_pages: Array[String] = []
var mind_pages: Array[String] = []
var page_index := 0

var is_typing := false
var typing_token := 0
var waiting_for_input := false
var ending_triggered := false


func _ready() -> void:
	name = "fairScenes"
	_register_arrival_progress()
	_load_backgrounds()
	_build_audio()
	_build_ui()
	_build_script()
	_start_fair_ambience_loop()
	_load_step(0)


func _process(_delta: float) -> void:
	if ending_triggered or fair_ambience_player == null or fair_audio_stream == null:
		return

	if not fair_ambience_player.playing:
		fair_ambience_player.play(FAIR_AUDIO_LOOP_START)
		return

	var pos := fair_ambience_player.get_playback_position()
	if pos >= FAIR_AUDIO_LOOP_END or pos < FAIR_AUDIO_LOOP_START - 0.15:
		fair_ambience_player.seek(FAIR_AUDIO_LOOP_START)


func _register_arrival_progress() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null:
		var current_path := scene_file_path
		if current_path.is_empty():
			current_path = "res://scenes/fairScenes.tscn" if ResourceLoader.exists("res://scenes/fairScenes.tscn") else "res://fairScenes.tscn"
		if ResourceLoader.exists(current_path):
			save_manager.guardar_progreso(current_path, "fairScenes")


func _load_scene_texture(file_name: String) -> Texture2D:
	var candidates := ["res://scenes/" + file_name, "res://" + file_name]
	for path in candidates:
		if ResourceLoader.exists(path):
			return load(path)
	push_warning("No se encontró la imagen: " + file_name)
	return null


func _load_backgrounds() -> void:
	tex_fair_overview = _load_scene_texture("fairOverview.png")
	tex_scene2_fair = _load_scene_texture("scene2Fair.png")


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
	black_background.visible = false
	black_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(black_background)

	background = TextureRect.new()
	background.position = Vector2.ZERO
	background.size = BASE_SIZE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.pivot_offset = BASE_SIZE / 2.0
	background.texture = tex_fair_overview
	ui_root.add_child(background)

	# --- CUADRO DE DIÁLOGO PRINCIPAL (ABAJO AL CENTRO) ---
	var jammy_border := Color(JAMMY_COLOR.r, JAMMY_COLOR.g, JAMMY_COLOR.b, 0.70)

	dialogue_panel = Panel.new()
	dialogue_panel.position = JAMMY_BOTTOM_POS
	dialogue_panel.size = DIALOGUE_PANEL_SIZE
	dialogue_panel.z_index = 10
	dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, jammy_border))
	ui_root.add_child(dialogue_panel)

	speaker_panel = Panel.new()
	speaker_panel.position = Vector2(JAMMY_BOTTOM_POS.x + 36.0, JAMMY_BOTTOM_POS.y - SPEAKER_PANEL_SIZE.y + 2.0)
	speaker_panel.size = SPEAKER_PANEL_SIZE
	speaker_panel.z_index = 11
	speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, JAMMY_COLOR))
	ui_root.add_child(speaker_panel)

	speaker_label = Label.new()
	speaker_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.text = "Jammy"
	speaker_label.add_theme_font_size_override("font_size", 36)
	speaker_label.add_theme_font_override("font", FREDOKA_FONT)
	speaker_label.add_theme_color_override("font_color", JAMMY_COLOR)
	speaker_label.add_theme_color_override("font_shadow_color", Color("#000000e6"))
	speaker_label.add_theme_constant_override("shadow_offset_x", 2)
	speaker_label.add_theme_constant_override("shadow_offset_y", 2)
	speaker_panel.add_child(speaker_label)

	dialogue_label = Label.new()
	dialogue_label.position = Vector2(52.0, 24.0)
	dialogue_label.size = Vector2(DIALOGUE_PANEL_SIZE.x - 104.0, DIALOGUE_PANEL_SIZE.y - 48.0)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.clip_text = true
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.add_theme_font_size_override("font_size", 42)
	dialogue_label.add_theme_font_override("font", FREDOKA_FONT)
	dialogue_label.add_theme_color_override("font_color", TEXT_COLOR)
	dialogue_label.add_theme_color_override("font_shadow_color", Color("#000000f0"))
	dialogue_label.add_theme_constant_override("shadow_offset_x", 4)
	dialogue_label.add_theme_constant_override("shadow_offset_y", 4)
	dialogue_panel.add_child(dialogue_label)

	# --- CUADRO ROJO PARALELO (ESQUINA SUPERIOR IZQUIERDA - ALTA LEGIBILIDAD) ---
	var mind_border := Color(MIND_COLOR.r, MIND_COLOR.g, MIND_COLOR.b, 0.85)

	parallel_mind_panel = Panel.new()
	parallel_mind_panel.position = PARALLEL_MIND_POS
	parallel_mind_panel.size = MIND_PANEL_SIZE
	parallel_mind_panel.z_index = 10
	parallel_mind_panel.add_theme_stylebox_override("panel", _make_dialogue_style(MIND_PANEL_COLOR, mind_border))
	ui_root.add_child(parallel_mind_panel)

	parallel_mind_label = Label.new()
	parallel_mind_label.position = Vector2(56.0, 24.0)
	parallel_mind_label.size = Vector2(MIND_PANEL_SIZE.x - 112.0, MIND_PANEL_SIZE.y - 48.0)
	parallel_mind_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parallel_mind_label.clip_text = true
	parallel_mind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parallel_mind_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parallel_mind_label.add_theme_font_size_override("font_size", 36)
	parallel_mind_label.add_theme_constant_override("line_spacing", 6)
	parallel_mind_label.add_theme_font_override("font", ROCK_SALT_FONT)
	parallel_mind_label.add_theme_color_override("font_color", MIND_COLOR)
	parallel_mind_label.add_theme_constant_override("outline_size", 6)
	parallel_mind_label.add_theme_color_override("font_outline_color", Color("#08080a"))
	parallel_mind_label.add_theme_color_override("font_shadow_color", Color("#000000f5"))
	parallel_mind_label.add_theme_constant_override("shadow_offset_x", 4)
	parallel_mind_label.add_theme_constant_override("shadow_offset_y", 4)
	parallel_mind_panel.add_child(parallel_mind_label)

	continue_label = Label.new()
	continue_label.position = Vector2(0.0, 2085.0)
	continue_label.size = Vector2(3840.0, 60.0)
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.z_index = 12
	continue_label.add_theme_font_size_override("font_size", 36)
	continue_label.add_theme_font_override("font", FREDOKA_FONT)
	continue_label.add_theme_color_override("font_color", ACCENT_COLOR)
	continue_label.text = "ENTER / SPACE"
	continue_label.visible = false
	ui_root.add_child(continue_label)

	typewriter_player = AudioStreamPlayer.new()
	typewriter_player.pitch_scale = 1.0
	typewriter_player.volume_db = 0.0
	add_child(typewriter_player)

	fair_ambience_player = AudioStreamPlayer.new()
	fair_ambience_player.bus = &"Master"
	fair_ambience_player.volume_db = 0.0
	add_child(fair_ambience_player)


func _build_script() -> void:
	var jammy_white_thought := "*Wow, look at these lights, this vibe, these smells—an experience that you can enjoy just once each year here in Oregon. Well, it's the first time for me at this fair, but it's almost the same as in my hometown, Dallas—big, big Texas. I don't, don't miss you. Fairs have been a double-edged knife for me, cuz if I don't enjoy this like always, I gotta wait until the next year, expecting just to have fun here like others, and so these stunning and colorful lights turn into lasers that aim at my heart until the last view of the fair from the car while I'm coming back home. But this time is different: the same girl that hasn't abandoned me because of OCD is coming with me—for the first time in my life, the one who was capable of letting a numb, real sunshine warm my heart is with me, and I can even taste this euphoria in my mouth, and it's mouth-watering.*"

	var jammy_red_parallel := "*I gotta recognize that it's impossible for me just to enjoy a fair. If I accept that it'll be the same until my last day, at least I won't waste energy trying to change it. The nightmare starts again—remember, remember: if you see pretty people, don't stalk them, that's nasty, and falling in love with someone doesn't make sense, cuz you can just enjoy watching yourself in the mirror, and falling in love with someone because of beauty is just a loop of jealousy, so remember it. Hahaha, are you stupid, you hanging out with a real friend? You will never fill the company of a normal friend without mental issues. You have OCD, you have OCD, hahaha, idiot.*"

	var jammy_clothes_parallel := "*You're talking about private topics that people usually don't dare bring up—this is just the beginning. Soon you won't be able to control the words you say to her, you'll end up impulsively saying things you don't even want to say, and that'll leave you anxious and irritable. It's better to keep control of this.*"

	story_steps = [
		{
			"bg": tex_fair_overview,
			"speaker": "Jammy",
			"color": JAMMY_COLOR,
			"main": jammy_white_thought,
			"mind": jammy_red_parallel
		},
		{
			"bg": tex_scene2_fair,
			"speaker": "Xcarlet",
			"color": XCARLET_COLOR,
			"main": "Hey, so...",
			"mind": ""
		},
		{
			"bg": tex_scene2_fair,
			"speaker": "Jammy",
			"color": JAMMY_COLOR,
			"main": "Wait, it's not a problem for me, I'm just wondering... are these clothes the same ones you were wearing at 8 PM?",
			"mind": jammy_clothes_parallel
		},
		{
			"bg": tex_scene2_fair,
			"speaker": "Xcarlet",
			"color": XCARLET_COLOR,
			"main": "Haha, right on target! You know, it's just the same as wine—the more aged, the better.",
			"mind": ""
		},
		{
			"bg": tex_scene2_fair,
			"speaker": "Jammy",
			"color": JAMMY_COLOR,
			"main": "Hey, I'm hungry, stop talking 'bout delights.",
			"mind": ""
		},
		{
			"bg": tex_scene2_fair,
			"speaker": "Xcarlet",
			"color": XCARLET_COLOR,
			"main": "Well, the promise that everybody makes before coming to the fair is not to waste time looking at booths with useless things, but I'm sure that this is part of the experience, so let's fucking go! Those pirate things are waiting for us, and the places that we really wanna visit will come to us themselves. I'm meow sureeeeee, soo here we go!",
			"mind": ""
		}
	]

	dialogue_label.text = ""
	parallel_mind_label.text = ""


func _apply_speaker_style(speaker_name: String, accent_color: Color) -> void:
	speaker_label.text = speaker_name
	speaker_label.add_theme_color_override("font_color", accent_color)
	var border_col := Color(accent_color.r, accent_color.g, accent_color.b, 0.75)
	dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, border_col))
	speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, accent_color))


func _load_step(idx: int) -> void:
	if idx >= story_steps.size():
		_show_ending()
		return

	step_index = idx
	var step := story_steps[step_index]

	var step_bg: Texture2D = step.get("bg", null)
	if step_bg != null:
		background.texture = step_bg

	_apply_speaker_style(step.get("speaker", "Jammy"), step.get("color", JAMMY_COLOR))

	var raw_main: String = step.get("main", "")
	var raw_mind: String = step.get("mind", "")

	main_pages.clear()
	if not raw_main.is_empty():
		main_pages = _split_text_for_box(raw_main, false)

	mind_pages.clear()
	if not raw_mind.is_empty():
		mind_pages = _split_text_for_box(raw_mind, true)

	page_index = 0
	_show_current_pages()


func _fits_in_label(candidate: String, target_label: Label, max_height: float) -> bool:
	target_label.text = candidate
	var lines := target_label.get_line_count()
	var line_h := float(target_label.get_line_height())
	var line_spacing := float(target_label.get_theme_constant("line_spacing"))
	var total_h := float(lines) * line_h + float(maxi(0, lines - 1)) * line_spacing
	return total_h <= max_height


func _apply_thought_markers(text: String, add_start: bool, add_end: bool) -> String:
	var result := text
	if add_start:
		result = "*" + result
	if add_end:
		result += "*"
	return result


func _split_text_for_box(raw_text: String, is_mind: bool) -> Array[String]:
	var has_start_marker: bool = is_mind or raw_text.begins_with("*")
	var has_end_marker: bool = is_mind or raw_text.ends_with("*")
	var inner_text: String = raw_text.trim_prefix("*").trim_suffix("*")

	var target_label: Label = parallel_mind_label if is_mind else dialogue_label
	var max_height: float = target_label.size.y - 20.0

	var full_marked: String = _apply_thought_markers(inner_text, has_start_marker, has_end_marker)
	if _fits_in_label(full_marked, target_label, max_height):
		return [full_marked]

	var pages: Array[String] = []
	var chunk := ""
	for word in inner_text.split(" "):
		var candidate: String = word if chunk.is_empty() else chunk + " " + word
		var marked_candidate: String = _apply_thought_markers(candidate, has_start_marker, has_end_marker)
		if not chunk.is_empty() and not _fits_in_label(marked_candidate, target_label, max_height):
			pages.append(_apply_thought_markers(chunk, has_start_marker, false))
			has_start_marker = false
			chunk = word
		else:
			chunk = candidate

	if not chunk.is_empty():
		pages.append(_apply_thought_markers(chunk, has_start_marker, has_end_marker))

	return pages


func _show_current_pages() -> void:
	var total_pages := maxi(main_pages.size(), mind_pages.size())
	if page_index >= total_pages:
		_load_step(step_index + 1)
		return

	continue_label.visible = false
	black_background.visible = false
	background.modulate = Color.WHITE

	var has_main := page_index < main_pages.size()
	var has_mind := page_index < mind_pages.size()

	dialogue_panel.visible = has_main
	speaker_panel.visible = has_main
	parallel_mind_panel.visible = has_mind

	var main_target := main_pages[page_index] if has_main else ""
	var mind_target := mind_pages[page_index] if has_mind else ""

	dialogue_label.text = ""
	parallel_mind_label.text = ""

	waiting_for_input = false
	is_typing = true
	typing_token += 1
	_type_parallel_words(typing_token, main_target, mind_target)


func _type_parallel_words(token: int, main_target: String, mind_target: String) -> void:
	var delay := 0.045
	var main_words := main_target.split(" ") if not main_target.is_empty() else PackedStringArray()
	var mind_words := mind_target.split(" ") if not mind_target.is_empty() else PackedStringArray()
	var max_words := maxi(main_words.size(), mind_words.size())
	var sound_step := 2 if main_words.size() >= 3 else 1

	var idx := 0
	while idx < max_words and token == typing_token:
		if idx < main_words.size():
			dialogue_label.text += ("" if idx == 0 else " ") + main_words[idx]
			if idx % sound_step == 0:
				typewriter_player.stop()
				typewriter_player.stream = typewriter_stream
				typewriter_player.play()

		if idx < mind_words.size():
			parallel_mind_label.text += ("" if idx == 0 else " ") + mind_words[idx]

		idx += 1
		await get_tree().create_timer(delay).timeout

	if token == typing_token:
		typewriter_player.stop()
		is_typing = false
		waiting_for_input = true
		continue_label.visible = true


func _advance() -> void:
	if ending_triggered:
		return

	if is_typing:
		typing_token += 1
		typewriter_player.stop()
		if page_index < main_pages.size():
			dialogue_label.text = main_pages[page_index]
		if page_index < mind_pages.size():
			parallel_mind_label.text = mind_pages[page_index]
		is_typing = false
		waiting_for_input = true
		continue_label.visible = true
		return

	if waiting_for_input:
		page_index += 1
		_show_current_pages()


func _unhandled_input(event: InputEvent) -> void:
	var advance_pressed := false
	if event is InputEventKey:
		advance_pressed = event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)
	elif event is InputEventMouseButton:
		advance_pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT

	if advance_pressed:
		_advance()


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


func _normalize_sound_key(raw: String) -> String:
	var s := raw.get_basename().to_lower()
	return s.replace("'", "").replace("’", "").replace(" ", "").replace("_", "").replace("-", "")


func _load_fair_audio_stream() -> AudioStream:
	var candidates := ["fair'sAudio", "fairsAudio", "fairAudio"]
	var exts := [".mp3", ".ogg", ".wav"]
	for base_name in candidates:
		for ext in exts:
			var path: String = SOUNDS_DIR + base_name + ext
			if ResourceLoader.exists(path):
				return load(path)

	var dir := DirAccess.open(SOUNDS_DIR)
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and not file_name.ends_with(".import"):
				if _normalize_sound_key(file_name) == "fairsaudio":
					var full_path: String = SOUNDS_DIR + file_name
					if ResourceLoader.exists(full_path):
						dir.list_dir_end()
						return load(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()

	push_warning("No se encontró fair'sAudio en " + SOUNDS_DIR)
	return null


func _build_audio() -> void:
	typewriter_stream = NORMAL_DIALOGUE_STREAM
	fair_audio_stream = _load_fair_audio_stream()


func _start_fair_ambience_loop() -> void:
	if fair_ambience_player != null and fair_audio_stream != null:
		fair_ambience_player.stream = fair_audio_stream
		fair_ambience_player.volume_db = 0.0
		fair_ambience_player.play(FAIR_AUDIO_LOOP_START)


func _show_ending() -> void:
	if ending_triggered:
		return
	ending_triggered = true

	waiting_for_input = false
	is_typing = false
	typewriter_player.stop()
	if fair_ambience_player != null:
		fair_ambience_player.stop()

	var eye_trans := get_node_or_null("/root/EyeTransition")
	if eye_trans == null and ResourceLoader.exists("res://EyeTransition.gd"):
		eye_trans = load("res://EyeTransition.gd").new()
		get_tree().root.add_child(eye_trans)

	if eye_trans != null and ResourceLoader.exists(next_scene_path):
		eye_trans.ir_a_escena_cerrando_ojos(next_scene_path)
		return

	if not ResourceLoader.exists(next_scene_path):
		push_error("No existe la siguiente escena: " + next_scene_path)
		ending_triggered = false
		return

	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null:
		save_manager.guardar_progreso(next_scene_path, "fairScenes")

	var packed := ResourceLoader.load(next_scene_path) as PackedScene
	if packed == null:
		push_error("No se pudo cargar " + next_scene_path)
		ending_triggered = false
		return

	var err := get_tree().change_scene_to_packed(packed)
	if err != OK:
		push_error("Error al cambiar a " + next_scene_path + ": " + str(err))
		ending_triggered = false
