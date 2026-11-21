extends Node2D

const BASE_SIZE: Vector2 = Vector2(3840.0, 2160.0)
const CHARS_DIR: String = "res://assets/characters/"
const PENCIL_SOUND_PATH: String = "res://assets/sounds/pencil.wav"

# Paleta y medidas homogenizadas (con alto contraste sobre el papel blanco de este nivel)
const JAMMY_COLOR: Color = Color("#f5d08a")
const XCARLET_COLOR: Color = Color("#5bc0eb")
const MIND_COLOR: Color = Color("#ff5a5f")
const NORMAL_BLACK_TEXT_COLOR: Color = Color("#161616")
const NORMAL_WHITE_PANEL_COLOR: Color = Color(0.97, 0.96, 0.94, 0.94)
const MIND_PANEL_COLOR: Color = Color(0.11, 0.11, 0.13, 0.94)
const SPEAKER_BG_COLOR: Color = Color(0.14, 0.15, 0.17, 0.94)

const DIALOGUE_PANEL_SIZE: Vector2 = Vector2(1280.0, 240.0)
const DIALOGUE_PANEL_POS: Vector2 = Vector2(1280.0, 1835.0)
const DIALOGUE_PANEL_LEFT_POS: Vector2 = Vector2(72.0, 1835.0)
const TOC_PANEL_POS: Vector2 = Vector2(72.0, 56.0)
const TOP_RIGHT_INSTRUCTION_SIZE: Vector2 = Vector2(880.0, 150.0)
const TOP_RIGHT_INSTRUCTION_POS: Vector2 = Vector2(2888.0, 56.0)
const SPEAKER_PANEL_SIZE: Vector2 = Vector2(300.0, 62.0)

# Brazo escalado para cubrir todo el lienzo incluso con zoom sin cortar la manga
const HAND_SIZE: Vector2 = Vector2(5600.0, 3150.0)
const JAMMY_TIP_UV: Vector2 = Vector2(0.812, 0.186)
const XCARLET_TIP_UV: Vector2 = Vector2(0.838, 0.126)
const OFFSCREEN_TIP_POS: Vector2 = Vector2(-950.0, BASE_SIZE.y + 650.0)
const HAND_OFFSCREEN_POS: Vector2 = Vector2(-6200.0, 4200.0)

# Máscara de alta definición para revelado limpio
const MASK_SIZE: Vector2i = Vector2i(1280, 720)

# Parámetros de dificultad
const MIN_ACCURACY: float = 80.0
const SNAP_MAX_DIST: float = 18.0
const STEP_MAX_DIST: float = 17.0
const OFF_PATH_ZERO_DIST: float = 30.0
const MIN_COVERAGE_RATIO: float = 0.95

@export_file("*.tscn") var next_scene_path: String = "res://scenes/scene17.tscn"

var ui_root: Control
var canvas_container: Control
var base_art_rect: TextureRect
var reveal_art_rect: TextureRect
var reveal_material: ShaderMaterial
var guide_canvas: Control

var jammy_hand_rect: TextureRect
var xcarlet_hand_rect: TextureRect

# Barra Kawaii de Accuracy (arriba a la derecha)
var kawaii_panel: Panel
var kawaii_title_label: Label
var kawaii_percent_label: Label
var kawaii_bar_bg: Panel
var kawaii_bar_fill: ColorRect
var kawaii_threshold_mark: ColorRect

# Cuadro rojo del TOC con tres puntos fijos centrados (mismo tamaño que el cuadro de diálogo)
var thought_dots_panel: Panel
var thought_dots_label: Label
var thought_dots_tween: Tween

# Cartel blanco de instrucciones homogenizado
var instruction_panel: Panel
var instruction_label: RichTextLabel
var is_instruction_in_top_right: bool = false

# Cuadro de diálogo homogenizado
var dialogue_panel: Panel
var dialogue_label: Label
var speaker_panel: Panel
var speaker_label: Label

var pencil_player: AudioStreamPlayer
var fredoka_font: Font
var rock_salt_font: Font
var pencil_stream: AudioStream

var cached_char_files: PackedStringArray = PackedStringArray()

# Texturas cargadas
var tex_jammy_1: Texture2D
var tex_xcarlet_2: Texture2D
var tex_jammy_2: Texture2D
var tex_xcarlet_3: Texture2D
var tex_jammy_3: Texture2D
var tex_both: Texture2D
var tex_xcarlet_1_tex: Texture2D

# Máscara dinámica de opacidad
var mask_image: Image
var mask_texture: ImageTexture
var mask_snapshot: PackedByteArray

enum Phase {
	AUTO_XCARLET_1,
	WAIT_AFTER_XCARLET_1,
	SHOW_INSTRUCTIONS,
	JAMMY_1_CHAIN,
	AUTO_XCARLET_2,
	WAIT_AFTER_XCARLET_2,
	JAMMY_2_WOUND_DROPS_PUDDLE,
	AUTO_XCARLET_3,
	WAIT_AFTER_XCARLET_3,
	JAMMY_3_KNIFE_CUTS,
	WAIT_KNIFE_XCARLET_REACTION,
	WAIT_KNIFE_JAMMY_RESPONSE,
	JAMMY_4_BOTH_SIGNATURE,
	WAIT_SUNSHINE_XCARLET_QUESTION,
	WAIT_SUNSHINE_JAMMY_RESPONSE,
	WAIT_DELAYED_DIALOGUES,
	FINISHED
}

var current_phase: Phase = Phase.AUTO_XCARLET_1
var delayed_return_phase: Phase = Phase.JAMMY_1_CHAIN
var jammy_strokes_queue: Array[Dictionary] = []
var current_stroke_idx: int = 0

# Datos precisos de las firmas en la esquina inferior derecha
var active_jammy_ink_pts: PackedVector2Array = PackedVector2Array()
var active_xcarlet_ink_pts: PackedVector2Array = PackedVector2Array()
var active_signatures_split_x: float = 3502.0

# Cola de cuadros de diálogo divididos (evita desbordamientos y conserva diálogos atrasados)
var dialogue_queue: Array[Dictionary] = []
var dialogue_queue_idx: int = 0

# Control bidireccional desde cualquier extremo/punto sobre la línea punteada
var active_guide_points: PackedVector2Array = PackedVector2Array()
var guide_covered: Array[bool] = []
var is_closed_loop: bool = false
var current_anchor_idx: int = -1
var guide_pulse_time: float = 0.0

var is_player_tracing: bool = false
var has_last_sample_pos: bool = false
var last_sample_pos: Vector2 = Vector2.ZERO
var sample_scores: Array[float] = []

# Control fluido del sonido del lápiz sin cortes ni golpeteos
var is_pencil_actively_drawing: bool = false
var pencil_idle_timer: float = 0.0

# Estado de zoom de cámara sobre el lienzo
var current_zoom: float = 1.0
var zoom_tween: Tween


func _ready() -> void:
	name = "Level3"
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_scan_characters_directory()
	_load_all_assets()
	_build_ui()
	_start_phase(Phase.AUTO_XCARLET_1)


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _scan_characters_directory() -> void:
	cached_char_files.clear()
	var dir: DirAccess = DirAccess.open(CHARS_DIR)
	if dir == null:
		push_warning("No se pudo abrir la carpeta: " + CHARS_DIR)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and not file_name.ends_with(".import"):
			cached_char_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _normalize_key(raw: String) -> String:
	var s: String = raw.get_basename().to_lower()
	s = s.replace("'", "").replace("’", "").replace(" ", "").replace("_", "").replace("-", "")
	return s


func _load_all_assets() -> void:
	if ResourceLoader.exists("res://fonts/Fredoka-Regular.ttf"):
		fredoka_font = load("res://fonts/Fredoka-Regular.ttf")
	if ResourceLoader.exists("res://fonts/RockSalt-Regular.ttf"):
		rock_salt_font = load("res://fonts/RockSalt-Regular.ttf")

	if ResourceLoader.exists(PENCIL_SOUND_PATH):
		pencil_stream = load(PENCIL_SOUND_PATH)
	elif ResourceLoader.exists("res://assets/sounds/pencil.ogg"):
		pencil_stream = load("res://assets/sounds/pencil.ogg")
	elif ResourceLoader.exists("res://assets/sounds/pencil.mp3"):
		pencil_stream = load("res://assets/sounds/pencil.mp3")

	tex_xcarlet_1_tex = _load_character_art(["xcarlet'sStroke1", "xcarletsstroke1"])
	tex_jammy_1 = _load_character_art(["Jammy'sStroke1", "jammysstroke1"])
	tex_xcarlet_2 = _load_character_art(["xcarlet'sStroke2", "xcarletsstroke2"])
	tex_jammy_2 = _load_character_art(["jammy'sStroke2", "jammysstroke2"])
	tex_xcarlet_3 = _load_character_art(["xcarlet'sStroke3", "xcarletsstroke3"])
	tex_jammy_3 = _load_character_art(["jammy'sStroke3", "jammysstroke3"])
	tex_both = _load_character_art(["both"])


func _load_character_art(candidate_names: Array) -> Texture2D:
	var exts: Array[String] = [".png", ".jpg", ".jpeg", ".webp"]
	for raw_name in candidate_names:
		var b: String = str(raw_name)
		for ext: String in exts:
			var full: String = CHARS_DIR + b + ext
			if ResourceLoader.exists(full):
				return load(full)

	for raw_name in candidate_names:
		var target_key: String = _normalize_key(str(raw_name))
		for file_name: String in cached_char_files:
			if _normalize_key(file_name) == target_key:
				var full_path: String = CHARS_DIR + file_name
				if ResourceLoader.exists(full_path):
					return load(full_path)

	push_warning("Falta archivo en " + CHARS_DIR + ": " + str(candidate_names))
	return null


func _load_hand_texture_sharp(candidate_names: Array) -> Texture2D:
	var tex: Texture2D = _load_character_art(candidate_names)
	if tex == null:
		return null

	var img: Image = tex.get_image()
	if img == null:
		return tex

	if img.detect_alpha() != Image.ALPHA_NONE:
		return tex

	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)

	var w: int = img.get_width()
	var h: int = img.get_height()
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(w * h)

	var queue: Array[Vector2i] = []
	for x: int in range(w):
		for y: int in [0, h - 1]:
			var idx: int = y * w + x
			if visited[idx] == 0:
				visited[idx] = 1
				queue.append(Vector2i(x, y))
	for y: int in range(h):
		for x: int in [0, w - 1]:
			var idx: int = y * w + x
			if visited[idx] == 0:
				visited[idx] = 1
				queue.append(Vector2i(x, y))

	var head: int = 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1

		var col: Color = img.get_pixel(p.x, p.y)
		var lum: float = maxf(col.r, maxf(col.g, col.b))
		if lum < 0.05:
			img.set_pixel(p.x, p.y, Color(0.0, 0.0, 0.0, 0.0))
			var neighbors: Array[Vector2i] = [
				Vector2i(p.x + 1, p.y),
				Vector2i(p.x - 1, p.y),
				Vector2i(p.x, p.y + 1),
				Vector2i(p.x, p.y - 1)
			]
			for n: Vector2i in neighbors:
				if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h:
					var n_idx: int = n.y * w + n.x
					if visited[n_idx] == 0:
						visited[n_idx] = 1
						queue.append(n)

	return ImageTexture.create_from_image(img)


func _build_ui() -> void:
	ui_root = Control.new()
	ui_root.position = Vector2.ZERO
	ui_root.size = BASE_SIZE
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.clip_contents = true
	add_child(ui_root)

	canvas_container = Control.new()
	canvas_container.position = Vector2.ZERO
	canvas_container.size = BASE_SIZE
	canvas_container.scale = Vector2.ONE
	canvas_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(canvas_container)

	base_art_rect = TextureRect.new()
	base_art_rect.position = Vector2.ZERO
	base_art_rect.size = BASE_SIZE
	base_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	base_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_container.add_child(base_art_rect)

	reveal_art_rect = TextureRect.new()
	reveal_art_rect.position = Vector2.ZERO
	reveal_art_rect.size = BASE_SIZE
	reveal_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reveal_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reveal_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_container.add_child(reveal_art_rect)

	mask_image = Image.create(MASK_SIZE.x, MASK_SIZE.y, false, Image.FORMAT_RGBA8)
	mask_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	mask_texture = ImageTexture.create_from_image(mask_image)

	var reveal_shader: Shader = Shader.new()
	reveal_shader.code = """
shader_type canvas_item;
uniform sampler2D mask_tex;
uniform bool preserve_paper_bg = false;
uniform float extra_reveal : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base_col = texture(TEXTURE, UV);
	float m = clamp(texture(mask_tex, UV).r + extra_reveal, 0.0, 1.0);
	if (preserve_paper_bg) {
		bool inside_heart = (UV.x >= 0.375 && UV.x <= 0.580 && UV.y >= 0.335 && UV.y <= 0.665);
		if (!inside_heart) {
			COLOR = base_col;
		} else {
			COLOR = vec4(mix(vec3(1.0, 1.0, 1.0), base_col.rgb, m), base_col.a);
		}
	} else {
		COLOR = vec4(base_col.rgb, base_col.a * m);
	}
}
"""
	reveal_material = ShaderMaterial.new()
	reveal_material.shader = reveal_shader
	reveal_material.set_shader_parameter("mask_tex", mask_texture)
	reveal_material.set_shader_parameter("preserve_paper_bg", false)
	reveal_material.set_shader_parameter("extra_reveal", 0.0)
	reveal_art_rect.material = reveal_material

	guide_canvas = Control.new()
	guide_canvas.position = Vector2.ZERO
	guide_canvas.size = BASE_SIZE
	guide_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_canvas.z_index = 4
	guide_canvas.draw.connect(_on_guide_canvas_draw)
	canvas_container.add_child(guide_canvas)

	xcarlet_hand_rect = TextureRect.new()
	xcarlet_hand_rect.size = HAND_SIZE
	xcarlet_hand_rect.position = HAND_OFFSCREEN_POS
	xcarlet_hand_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	xcarlet_hand_rect.stretch_mode = TextureRect.STRETCH_SCALE
	xcarlet_hand_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	xcarlet_hand_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xcarlet_hand_rect.z_index = 8
	xcarlet_hand_rect.visible = false
	xcarlet_hand_rect.texture = _load_hand_texture_sharp(["brazoXcarlet"])
	ui_root.add_child(xcarlet_hand_rect)

	jammy_hand_rect = TextureRect.new()
	jammy_hand_rect.size = HAND_SIZE
	jammy_hand_rect.position = HAND_OFFSCREEN_POS
	jammy_hand_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	jammy_hand_rect.stretch_mode = TextureRect.STRETCH_SCALE
	jammy_hand_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	jammy_hand_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jammy_hand_rect.z_index = 8
	jammy_hand_rect.visible = false
	jammy_hand_rect.texture = _load_hand_texture_sharp(["brazoJammy"])
	ui_root.add_child(jammy_hand_rect)

	_build_kawaii_accuracy_bar()
	_build_thought_dots_badge()
	_build_homogenized_boxes()

	pencil_player = AudioStreamPlayer.new()
	pencil_player.volume_db = 0.0
	pencil_player.finished.connect(_on_pencil_player_finished)
	add_child(pencil_player)


func _build_kawaii_accuracy_bar() -> void:
	kawaii_panel = Panel.new()
	kawaii_panel.position = Vector2(3038.0, 56.0)
	kawaii_panel.size = Vector2(730.0, 150.0)
	kawaii_panel.z_index = 14
	kawaii_panel.visible = false

	var k_style: StyleBoxFlat = StyleBoxFlat.new()
	k_style.bg_color = Color("#fff5f8")
	k_style.border_color = Color("#ff8fb1")
	k_style.set_border_width_all(5)
	k_style.set_corner_radius_all(28)
	k_style.shadow_color = Color(0.95, 0.45, 0.65, 0.35)
	k_style.shadow_size = 10
	kawaii_panel.add_theme_stylebox_override("panel", k_style)
	ui_root.add_child(kawaii_panel)

	kawaii_title_label = Label.new()
	kawaii_title_label.position = Vector2(28.0, 14.0)
	kawaii_title_label.size = Vector2(440.0, 48.0)
	kawaii_title_label.text = "♡ ACCURACY ♡"
	kawaii_title_label.add_theme_font_size_override("font_size", 34)
	if fredoka_font:
		kawaii_title_label.add_theme_font_override("font", fredoka_font)
	kawaii_title_label.add_theme_color_override("font_color", Color("#d94e78"))
	kawaii_panel.add_child(kawaii_title_label)

	kawaii_percent_label = Label.new()
	kawaii_percent_label.position = Vector2(490.0, 10.0)
	kawaii_percent_label.size = Vector2(210.0, 54.0)
	kawaii_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kawaii_percent_label.text = "100% ★"
	kawaii_percent_label.add_theme_font_size_override("font_size", 38)
	if fredoka_font:
		kawaii_percent_label.add_theme_font_override("font", fredoka_font)
	kawaii_percent_label.add_theme_color_override("font_color", Color("#d94e78"))
	kawaii_panel.add_child(kawaii_percent_label)

	kawaii_bar_bg = Panel.new()
	kawaii_bar_bg.position = Vector2(28.0, 74.0)
	kawaii_bar_bg.size = Vector2(674.0, 48.0)
	var bg_s: StyleBoxFlat = StyleBoxFlat.new()
	bg_s.bg_color = Color("#ffe3ec")
	bg_s.border_color = Color("#ffb3c6")
	bg_s.set_border_width_all(3)
	bg_s.set_corner_radius_all(22)
	kawaii_bar_bg.add_theme_stylebox_override("panel", bg_s)
	kawaii_panel.add_child(kawaii_bar_bg)

	kawaii_bar_fill = ColorRect.new()
	kawaii_bar_fill.position = Vector2(6.0, 6.0)
	kawaii_bar_fill.size = Vector2(662.0, 36.0)
	kawaii_bar_fill.color = Color("#ff85a1")
	kawaii_bar_bg.add_child(kawaii_bar_fill)

	kawaii_threshold_mark = ColorRect.new()
	kawaii_threshold_mark.position = Vector2(6.0 + 662.0 * (MIN_ACCURACY / 100.0), 0.0)
	kawaii_threshold_mark.size = Vector2(6.0, 48.0)
	kawaii_threshold_mark.color = Color("#6b1128")
	kawaii_bar_bg.add_child(kawaii_threshold_mark)


func _sync_kawaii_panel_position() -> void:
	if instruction_panel != null and instruction_panel.visible and is_instruction_in_top_right:
		kawaii_panel.position = Vector2(3038.0, TOP_RIGHT_INSTRUCTION_POS.y + TOP_RIGHT_INSTRUCTION_SIZE.y + 20.0)
	else:
		kawaii_panel.position = Vector2(3038.0, 56.0)


func _build_thought_dots_badge() -> void:
	thought_dots_panel = Panel.new()
	thought_dots_panel.position = DIALOGUE_PANEL_POS
	thought_dots_panel.size = DIALOGUE_PANEL_SIZE
	thought_dots_panel.z_index = 16
	thought_dots_panel.visible = false
	thought_dots_panel.add_theme_stylebox_override(
		"panel",
		_make_dialogue_style(MIND_PANEL_COLOR, Color(MIND_COLOR.r, MIND_COLOR.g, MIND_COLOR.b, 0.88))
	)
	ui_root.add_child(thought_dots_panel)

	thought_dots_label = Label.new()
	thought_dots_label.position = Vector2(44.0, 24.0)
	thought_dots_label.size = Vector2(DIALOGUE_PANEL_SIZE.x - 88.0, DIALOGUE_PANEL_SIZE.y - 48.0)
	thought_dots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thought_dots_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	thought_dots_label.text = "..."
	thought_dots_label.add_theme_font_size_override("font_size", 48)
	if rock_salt_font:
		thought_dots_label.add_theme_font_override("font", rock_salt_font)
	elif fredoka_font:
		thought_dots_label.add_theme_font_override("font", fredoka_font)
	thought_dots_label.add_theme_color_override("font_color", MIND_COLOR)
	thought_dots_label.add_theme_color_override("font_shadow_color", Color("#000000e6"))
	thought_dots_label.add_theme_constant_override("shadow_offset_x", 3)
	thought_dots_label.add_theme_constant_override("shadow_offset_y", 3)
	thought_dots_panel.add_child(thought_dots_label)


func _show_thought_dots_from_jammy() -> void:
	if thought_dots_tween != null and thought_dots_tween.is_valid():
		thought_dots_tween.kill()

	thought_dots_panel.size = DIALOGUE_PANEL_SIZE
	thought_dots_panel.position = DIALOGUE_PANEL_POS
	thought_dots_panel.scale = Vector2.ONE
	thought_dots_panel.modulate.a = 1.0
	thought_dots_label.text = "..."
	thought_dots_panel.visible = true

	await get_tree().create_timer(0.18).timeout

	thought_dots_tween = create_tween()
	thought_dots_tween.set_trans(Tween.TRANS_CUBIC)
	thought_dots_tween.set_ease(Tween.EASE_OUT)
	thought_dots_tween.tween_property(thought_dots_panel, "position", TOC_PANEL_POS, 0.75)
	await thought_dots_tween.finished


func _hide_thought_dots_badge() -> void:
	if not thought_dots_panel.visible:
		return
	if thought_dots_tween != null and thought_dots_tween.is_valid():
		thought_dots_tween.kill()

	thought_dots_tween = create_tween()
	thought_dots_tween.set_trans(Tween.TRANS_CUBIC)
	thought_dots_tween.set_ease(Tween.EASE_IN)
	thought_dots_tween.tween_property(thought_dots_panel, "modulate:a", 0.0, 0.30)
	await thought_dots_tween.finished
	thought_dots_panel.visible = false
	thought_dots_panel.modulate.a = 1.0


func _build_homogenized_boxes() -> void:
	instruction_panel = Panel.new()
	instruction_panel.position = Vector2(1100.0, 860.0)
	instruction_panel.size = Vector2(1640.0, 320.0)
	instruction_panel.z_index = 18
	instruction_panel.visible = false
	instruction_panel.add_theme_stylebox_override(
		"panel",
		_make_dialogue_style(NORMAL_WHITE_PANEL_COLOR, Color(0.1, 0.1, 0.1, 0.35))
	)
	ui_root.add_child(instruction_panel)

	instruction_label = RichTextLabel.new()
	instruction_label.position = Vector2(44.0, 24.0)
	instruction_label.size = Vector2(1552.0, 272.0)
	instruction_label.bbcode_enabled = true
	instruction_label.scroll_active = false
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("normal_font_size", 46)
	if fredoka_font:
		instruction_label.add_theme_font_override("normal_font", fredoka_font)
	instruction_label.add_theme_color_override("default_color", NORMAL_BLACK_TEXT_COLOR)
	instruction_panel.add_child(instruction_label)

	dialogue_panel = Panel.new()
	dialogue_panel.position = DIALOGUE_PANEL_POS
	dialogue_panel.size = DIALOGUE_PANEL_SIZE
	dialogue_panel.z_index = 10
	dialogue_panel.add_theme_stylebox_override(
		"panel",
		_make_dialogue_style(NORMAL_WHITE_PANEL_COLOR, Color(XCARLET_COLOR.r, XCARLET_COLOR.g, XCARLET_COLOR.b, 0.85))
	)
	ui_root.add_child(dialogue_panel)

	speaker_panel = Panel.new()
	speaker_panel.position = Vector2(DIALOGUE_PANEL_POS.x + 36.0, DIALOGUE_PANEL_POS.y - SPEAKER_PANEL_SIZE.y + 2.0)
	speaker_panel.size = SPEAKER_PANEL_SIZE
	speaker_panel.z_index = 11
	speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, XCARLET_COLOR))
	ui_root.add_child(speaker_panel)

	speaker_label = Label.new()
	speaker_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.add_theme_font_size_override("font_size", 36)
	if fredoka_font:
		speaker_label.add_theme_font_override("font", fredoka_font)
	speaker_label.add_theme_color_override("font_color", XCARLET_COLOR)
	speaker_label.add_theme_color_override("font_shadow_color", Color("#000000e6"))
	speaker_label.add_theme_constant_override("shadow_offset_x", 2)
	speaker_label.add_theme_constant_override("shadow_offset_y", 2)
	speaker_panel.add_child(speaker_label)

	dialogue_label = Label.new()
	dialogue_label.position = Vector2(44.0, 20.0)
	dialogue_label.size = Vector2(DIALOGUE_PANEL_SIZE.x - 88.0, DIALOGUE_PANEL_SIZE.y - 40.0)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.clip_text = true
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.add_theme_font_size_override("font_size", 46)
	if fredoka_font:
		dialogue_label.add_theme_font_override("font", fredoka_font)
	dialogue_label.add_theme_color_override("font_color", NORMAL_BLACK_TEXT_COLOR)
	dialogue_panel.add_child(dialogue_label)


func _show_white_instruction(bbcode_text: String, fixed_top_right: bool = false) -> void:
	is_instruction_in_top_right = fixed_top_right
	if fixed_top_right:
		instruction_panel.position = TOP_RIGHT_INSTRUCTION_POS
		instruction_panel.size = TOP_RIGHT_INSTRUCTION_SIZE
		instruction_label.position = Vector2(32.0, 16.0)
		instruction_label.size = Vector2(TOP_RIGHT_INSTRUCTION_SIZE.x - 64.0, TOP_RIGHT_INSTRUCTION_SIZE.y - 32.0)
		instruction_label.add_theme_font_size_override("normal_font_size", 42)
	else:
		instruction_panel.position = Vector2(1100.0, 860.0)
		instruction_panel.size = Vector2(1640.0, 320.0)
		instruction_label.position = Vector2(44.0, 24.0)
		instruction_label.size = Vector2(1552.0, 272.0)
		instruction_label.add_theme_font_size_override("normal_font_size", 48)

	instruction_label.text = bbcode_text
	instruction_panel.visible = true
	_sync_kawaii_panel_position()


func _hide_white_instruction() -> void:
	is_instruction_in_top_right = false
	instruction_panel.visible = false
	_sync_kawaii_panel_position()


func _hide_dialogue() -> void:
	dialogue_queue.clear()
	dialogue_queue_idx = 0
	if dialogue_panel != null:
		dialogue_panel.visible = false
	if speaker_panel != null:
		speaker_panel.visible = false
	_hide_white_instruction()


func _update_dialogue_prompt(is_blocking_wait: bool) -> void:
	if _has_more_dialogues():
		_show_white_instruction("[center]Press [lb]ENTER[rb] to move to the next dialogue.[/center]", true)
	elif is_blocking_wait:
		_show_white_instruction("[center]Press [lb]ENTER[rb] to continue.[/center]", true)
	else:
		_hide_white_instruction()


# ==============================================================================
# CONTROL DE ZOOM SUAVE SOBRE EL ÁREA A CONTORNEAR Y RELEASE A 1.0x
# ==============================================================================
func _set_camera_zoom(target_scale: float, focus_norm: Vector2, duration: float = 0.55) -> void:
	if zoom_tween != null and zoom_tween.is_valid():
		zoom_tween.kill()

	var clamped_scale: float = clampf(target_scale, 1.0, 3.2)
	var target_pos: Vector2 = Vector2.ZERO

	if clamped_scale > 1.001:
		var focus_px: Vector2 = Vector2(focus_norm.x * BASE_SIZE.x, focus_norm.y * BASE_SIZE.y)
		var screen_anchor: Vector2 = Vector2(BASE_SIZE.x * 0.50, BASE_SIZE.y * 0.45)
		target_pos = screen_anchor - focus_px * clamped_scale
		target_pos.x = clampf(target_pos.x, BASE_SIZE.x * (1.0 - clamped_scale), 0.0)
		target_pos.y = clampf(target_pos.y, BASE_SIZE.y * (1.0 - clamped_scale), 0.0)

	zoom_tween = create_tween()
	zoom_tween.set_parallel(true)
	zoom_tween.set_trans(Tween.TRANS_CUBIC)
	zoom_tween.set_ease(Tween.EASE_IN_OUT)
	zoom_tween.tween_property(canvas_container, "scale", Vector2(clamped_scale, clamped_scale), duration)
	zoom_tween.tween_property(canvas_container, "position", target_pos, duration)
	await zoom_tween.finished
	current_zoom = clamped_scale


func _canvas_to_screen(canvas_pt: Vector2) -> Vector2:
	return canvas_container.position + canvas_pt * canvas_container.scale.x


func _screen_to_canvas(screen_pt: Vector2) -> Vector2:
	return (screen_pt - canvas_container.position) / maxf(canvas_container.scale.x, 0.001)


# ==============================================================================
# CONTROL EXCLUSIVO DE MANOS CON ENTRADA Y SALIDA SUAVE (CERO GLITCHES)
# ==============================================================================
func _get_hand_tip_screen_pos(hand: TextureRect, tip_uv: Vector2) -> Vector2:
	return hand.position + Vector2(hand.size.x * tip_uv.x, hand.size.y * tip_uv.y)


func _set_exclusive_hand(who: String) -> void:
	if who == "xcarlet":
		jammy_hand_rect.visible = false
		jammy_hand_rect.position = HAND_OFFSCREEN_POS
		if not xcarlet_hand_rect.visible:
			_place_hand_at_raw_screen_tip(xcarlet_hand_rect, XCARLET_TIP_UV, OFFSCREEN_TIP_POS, false)
			xcarlet_hand_rect.visible = true
	elif who == "jammy":
		xcarlet_hand_rect.visible = false
		xcarlet_hand_rect.position = HAND_OFFSCREEN_POS
		if not jammy_hand_rect.visible:
			_place_hand_at_raw_screen_tip(jammy_hand_rect, JAMMY_TIP_UV, OFFSCREEN_TIP_POS, false)
			jammy_hand_rect.visible = true
	else:
		xcarlet_hand_rect.visible = false
		xcarlet_hand_rect.position = HAND_OFFSCREEN_POS
		jammy_hand_rect.visible = false
		jammy_hand_rect.position = HAND_OFFSCREEN_POS
		_stop_pencil_sound()


func _enter_hand_to_canvas_point(hand: TextureRect, tip_uv: Vector2, target_canvas_pt: Vector2, duration: float = 0.22) -> void:
	var target_screen: Vector2 = _canvas_to_screen(target_canvas_pt)
	target_screen = Vector2(
		clampf(target_screen.x, 20.0, BASE_SIZE.x - 20.0),
		clampf(target_screen.y, 20.0, BASE_SIZE.y - 20.0)
	)
	if not hand.visible:
		_place_hand_at_raw_screen_tip(hand, tip_uv, OFFSCREEN_TIP_POS, false)
		hand.visible = true

	var start_tip: Vector2 = _get_hand_tip_screen_pos(hand, tip_uv)
	if start_tip.distance_to(target_screen) < 6.0:
		_place_hand_at_screen_tip(hand, tip_uv, target_screen, false)
		return

	var steps: int = maxi(int(round(duration / 0.014)), 6)
	for i: int in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var eased: float = 1.0 - pow(1.0 - t, 3.0)
		var cur_tip: Vector2 = start_tip.lerp(target_screen, eased)
		_place_hand_at_raw_screen_tip(hand, tip_uv, cur_tip, false)
		await get_tree().create_timer(0.014).timeout


func _retract_hand_down(hand: TextureRect) -> void:
	_stop_pencil_sound()
	if not hand.visible:
		return

	var tip_uv: Vector2 = XCARLET_TIP_UV if hand == xcarlet_hand_rect else JAMMY_TIP_UV
	var start_tip: Vector2 = _get_hand_tip_screen_pos(hand, tip_uv)
	var steps: int = 16
	for i: int in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var eased: float = t * t
		var cur_tip: Vector2 = start_tip.lerp(OFFSCREEN_TIP_POS, eased)
		_place_hand_at_raw_screen_tip(hand, tip_uv, cur_tip, false)
		await get_tree().create_timer(0.014).timeout

	hand.visible = false
	hand.position = HAND_OFFSCREEN_POS


func _place_hand_at_raw_screen_tip(hand: TextureRect, tip_uv: Vector2, raw_screen_tip: Vector2, is_tracing_now: bool = false) -> void:
	var offset: Vector2 = Vector2(hand.size.x * tip_uv.x, hand.size.y * tip_uv.y)
	var new_pos: Vector2 = raw_screen_tip - offset
	var moved_dist: float = hand.position.distance_to(new_pos)
	hand.position = new_pos

	if is_tracing_now and moved_dist > 1.2:
		_trigger_pencil_sound()


func _place_hand_at_screen_tip(hand: TextureRect, tip_uv: Vector2, screen_tip_pos: Vector2, is_tracing_now: bool = false) -> void:
	var safe_tip: Vector2 = Vector2(
		clampf(screen_tip_pos.x, 20.0, BASE_SIZE.x - 20.0),
		clampf(screen_tip_pos.y, 20.0, BASE_SIZE.y - 20.0)
	)
	_place_hand_at_raw_screen_tip(hand, tip_uv, safe_tip, is_tracing_now)


func _trigger_pencil_sound() -> void:
	if pencil_stream == null:
		return
	is_pencil_actively_drawing = true
	pencil_idle_timer = 0.14
	if not pencil_player.playing:
		pencil_player.stream = pencil_stream
		pencil_player.volume_db = 0.0
		pencil_player.pitch_scale = 1.0
		pencil_player.play()


func _on_pencil_player_finished() -> void:
	if is_pencil_actively_drawing and pencil_stream != null:
		pencil_player.stream = pencil_stream
		pencil_player.pitch_scale = 1.0
		pencil_player.play()


func _stop_pencil_sound() -> void:
	is_pencil_actively_drawing = false
	pencil_idle_timer = 0.0
	if pencil_player != null and pencil_player.playing:
		pencil_player.stop()


# ==============================================================================
# GENERADORES DE FORMAS EXACTAS DEL DIBUJO (ESLABONES, GOTAS FINAS, FIRMAS)
# ==============================================================================
func _build_chain_links_strokes() -> Array[Dictionary]:
	var link_centers: Array[Vector2] = [
		Vector2(0.443, 0.568),
		Vector2(0.460, 0.563),
		Vector2(0.478, 0.557),
		Vector2(0.496, 0.552),
		Vector2(0.514, 0.546),
		Vector2(0.531, 0.541)
	]
	var strokes: Array[Dictionary] = []
	var angle_rad: float = deg_to_rad(-16.0)
	var rx: float = 0.0132
	var ry: float = 0.0070

	for idx: int in range(link_centers.size()):
		var c: Vector2 = link_centers[idx]
		var loop_pts: Array[Vector2] = []
		var segments: int = 24
		for s: int in range(segments + 1):
			var theta: float = (float(s) / float(segments)) * TAU
			var lx: float = cos(theta) * rx
			var ly: float = sin(theta) * ry
			var rot_x: float = lx * cos(angle_rad) - ly * sin(angle_rad)
			var rot_y: float = lx * sin(angle_rad) + ly * cos(angle_rad)
			loop_pts.append(Vector2(c.x + rot_x, c.y + rot_y))

		strokes.append({
			"name": "chain_link_" + str(idx + 1),
			"pts": _norm_to_screen(loop_pts),
			"reveal_radius": 15
		})
	return strokes


func _build_slender_drop_norm_pts(tip_norm: Vector2, width_n: float, height_n: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var steps: int = 32
	for i: int in range(steps + 1):
		var t: float = (float(i) / float(steps)) * TAU
		var sin_half: float = sin(t * 0.5)
		var x_offset: float = (width_n * 0.52) * sin(t) * pow(maxf(sin_half, 0.0), 0.72)
		var y_offset: float = height_n * (1.0 - cos(t)) * 0.5
		pts.append(tip_norm + Vector2(x_offset, y_offset))
	return pts


func _build_spiral_signature_norm_pts(center_norm: Vector2, max_rx: float, max_ry: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var steps: int = 56
	var turns: float = 2.15
	for i: int in range(steps + 1):
		var u: float = float(i) / float(steps)
		var theta: float = -PI * 0.35 + u * TAU * turns
		var r_scale: float = lerpf(1.0, 0.38, u)
		var px: float = center_norm.x + cos(theta) * max_rx * r_scale
		var py: float = center_norm.y + sin(theta) * max_ry * r_scale
		pts.append(Vector2(px, py))
	return pts


func _analyze_both_signatures() -> Dictionary:
	var fallback_jammy_rect: Rect2 = Rect2(3380.0, 1945.0, 108.0, 96.0)
	var fallback_xcarlet_rect: Rect2 = Rect2(3516.0, 1930.0, 162.0, 118.0)
	var result: Dictionary = {
		"xcarlet_rect": fallback_xcarlet_rect,
		"jammy_rect": fallback_jammy_rect,
		"jammy_ink_pts": PackedVector2Array(),
		"xcarlet_ink_pts": PackedVector2Array(),
		"split_x": 3502.0
	}

	if tex_both == null:
		return result

	var img_both: Image = tex_both.get_image()
	if img_both == null:
		return result
	if img_both.is_compressed():
		img_both.decompress()

	var img_prev: Image = tex_jammy_3.get_image() if tex_jammy_3 != null else null
	if img_prev != null and img_prev.is_compressed():
		img_prev.decompress()

	var bw: int = img_both.get_width()
	var bh: int = img_both.get_height()
	if bw <= 0 or bh <= 0:
		return result

	var dark_pixels: Array[Vector2] = []
	var step_u: float = 0.0010
	var step_v: float = 0.0015
	var u: float = 0.82
	while u <= 0.97:
		var v: float = 0.84
		while v <= 0.97:
			var bx: int = clampi(int(u * float(bw)), 0, bw - 1)
			var by: int = clampi(int(v * float(bh)), 0, bh - 1)
			var cb: Color = img_both.get_pixel(bx, by)
			var lum_b: float = (cb.r + cb.g + cb.b) / 3.0
			if cb.a > 0.25 and lum_b < 0.62:
				var was_already_dark: bool = false
				if img_prev != null:
					var px: int = clampi(int(u * float(img_prev.get_width())), 0, img_prev.get_width() - 1)
					var py: int = clampi(int(v * float(img_prev.get_height())), 0, img_prev.get_height() - 1)
					var cp: Color = img_prev.get_pixel(px, py)
					var lum_p: float = (cp.r + cp.g + cp.b) / 3.0
					if cp.a > 0.25 and lum_p < 0.65:
						was_already_dark = true
				if not was_already_dark:
					dark_pixels.append(Vector2(u * BASE_SIZE.x, v * BASE_SIZE.y))
			v += step_v
		u += step_u

	if dark_pixels.size() < 12:
		return result

	var min_x: float = dark_pixels[0].x
	var max_x: float = dark_pixels[0].x
	for pt: Vector2 in dark_pixels:
		min_x = minf(min_x, pt.x)
		max_x = maxf(max_x, pt.x)

	var span_x: float = max_x - min_x
	if span_x < 80.0:
		return result

	# Buscar el hueco vacío entre la firma de Jammy (izquierda) y la de Xcarlet (derecha)
	var bins: int = 40
	var counts: Array[int] = []
	counts.resize(bins)
	for b_idx: int in range(bins):
		counts[b_idx] = 0

	for pt: Vector2 in dark_pixels:
		var norm_b: float = (pt.x - min_x) / span_x
		var b_i: int = clampi(int(norm_b * float(bins - 1)), 0, bins - 1)
		counts[b_i] += 1

	var best_gap_bin: int = int(bins * 0.42)
	var best_gap_score: int = 999999
	for b_idx: int in range(int(bins * 0.25), int(bins * 0.65)):
		var neighborhood: int = counts[b_idx] * 2 + counts[maxi(b_idx - 1, 0)] + counts[mini(b_idx + 1, bins - 1)]
		if neighborhood < best_gap_score:
			best_gap_score = neighborhood
			best_gap_bin = b_idx

	var split_x: float = min_x + (float(best_gap_bin) + 0.5) / float(bins) * span_x
	result["split_x"] = split_x

	var jammy_ink: PackedVector2Array = PackedVector2Array()
	var xcarlet_ink: PackedVector2Array = PackedVector2Array()
	var j_rect: Rect2 = Rect2()
	var x_rect: Rect2 = Rect2()
	var has_j: bool = false
	var has_x: bool = false

	for pt: Vector2 in dark_pixels:
		if pt.x < split_x:
			jammy_ink.append(pt)
			if not has_j:
				j_rect = Rect2(pt, Vector2.ZERO)
				has_j = true
			else:
				j_rect = j_rect.expand(pt)
		else:
			xcarlet_ink.append(pt)
			if not has_x:
				x_rect = Rect2(pt, Vector2.ZERO)
				has_x = true
			else:
				x_rect = x_rect.expand(pt)

	if has_j and j_rect.size.x > 16.0 and j_rect.size.y > 16.0:
		result["jammy_rect"] = j_rect
		result["jammy_ink_pts"] = jammy_ink

	if has_x and x_rect.size.x > 16.0 and x_rect.size.y > 16.0:
		result["xcarlet_rect"] = x_rect
		result["xcarlet_ink_pts"] = xcarlet_ink

	return result


func _build_smooth_cat_signature_strokes(cat_rect: Rect2, min_allowed_x: float) -> Array[PackedVector2Array]:
	var r: Rect2 = cat_rect
	if r.size.x < 40.0 or r.size.y < 40.0:
		r = Rect2(3516.0, 1930.0, 162.0, 118.0)

	var cx: float = maxf(r.position.x + r.size.x * 0.56, min_allowed_x + r.size.x * 0.36)
	var cy: float = r.position.y + r.size.y * 0.60
	var rx: float = r.size.x * 0.32
	var ry: float = r.size.y * 0.32

	var strokes: Array[PackedVector2Array] = []

	# 1. Letras a la izquierda de la cabecita ("xcarlet")
	var lx: float = maxf(r.position.x + r.size.x * 0.14, min_allowed_x + 12.0)
	strokes.append(PackedVector2Array([
		Vector2(lx + 18.0, r.position.y + r.size.y * 0.22),
		Vector2(lx, r.position.y + r.size.y * 0.52),
		Vector2(lx + 14.0, r.position.y + r.size.y * 0.84)
	]))

	# 2. Contorno de la cara del gatito
	var head_pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 26
	for i: int in range(steps + 1):
		var a: float = -PI * 0.5 + (float(i) / float(steps)) * TAU
		var px: float = maxf(cx + cos(a) * rx, min_allowed_x + 10.0)
		head_pts.append(Vector2(px, cy + sin(a) * ry))
	strokes.append(head_pts)

	# 3. Oreja izquierda
	strokes.append(PackedVector2Array([
		Vector2(maxf(cx - rx * 0.72, min_allowed_x + 10.0), cy - ry * 0.62),
		Vector2(maxf(cx - rx * 0.48, min_allowed_x + 12.0), r.position.y + r.size.y * 0.08),
		Vector2(maxf(cx - rx * 0.10, min_allowed_x + 14.0), cy - ry * 0.84)
	]))

	# 4. Oreja derecha
	strokes.append(PackedVector2Array([
		Vector2(cx + rx * 0.12, cy - ry * 0.84),
		Vector2(cx + rx * 0.50, r.position.y + r.size.y * 0.08),
		Vector2(cx + rx * 0.72, cy - ry * 0.62)
	]))

	# 5. Estrellita / cruz arriba a la derecha
	var sx: float = r.position.x + r.size.x * 0.88
	var sy: float = r.position.y + r.size.y * 0.20
	var sr: float = maxf(r.size.x * 0.09, 12.0)
	strokes.append(PackedVector2Array([
		Vector2(sx - sr, sy - sr),
		Vector2(sx + sr, sy + sr)
	]))
	strokes.append(PackedVector2Array([
		Vector2(sx + sr, sy - sr),
		Vector2(sx - sr, sy + sr)
	]))

	# 6. Ojitos y boquita
	strokes.append(PackedVector2Array([
		Vector2(maxf(cx - rx * 0.44, min_allowed_x + 12.0), cy - ry * 0.08),
		Vector2(cx - rx * 0.10, cy - ry * 0.12),
		Vector2(cx + rx * 0.15, cy - ry * 0.12),
		Vector2(cx + rx * 0.44, cy - ry * 0.08)
	]))
	strokes.append(PackedVector2Array([
		Vector2(maxf(cx - rx * 0.22, min_allowed_x + 12.0), cy + ry * 0.34),
		Vector2(cx + rx * 0.22, cy + ry * 0.30)
	]))

	return strokes


# ==============================================================================
# FLUJO DE TURNOS DE XCARLET Y JAMMY
# ==============================================================================
func _start_phase(phase: Phase) -> void:
	current_phase = phase
	active_guide_points = PackedVector2Array()
	guide_covered.clear()
	current_anchor_idx = -1
	has_last_sample_pos = false
	kawaii_panel.visible = false
	_stop_pencil_sound()
	guide_canvas.queue_redraw()

	match phase:
		Phase.AUTO_XCARLET_1:
			_hide_dialogue()
			await _set_camera_zoom(1.0, Vector2(0.5, 0.5), 0.1)
			_set_exclusive_hand("xcarlet")
			base_art_rect.texture = null
			reveal_art_rect.texture = tex_xcarlet_1_tex
			reveal_material.set_shader_parameter("preserve_paper_bg", true)
			_clear_mask(0.0)

			_start_dialogue("Xcarlet", "Let's start with a cute, cute heart—kawaii, isn't it?", XCARLET_COLOR, false, false)
			await _animate_xcarlet_heart_outline()
			await _retract_hand_down(xcarlet_hand_rect)

			base_art_rect.texture = tex_xcarlet_1_tex
			_clear_mask(0.0)
			reveal_material.set_shader_parameter("preserve_paper_bg", false)

			_start_dialogue(
				"Jammy",
				"*I'm getting so tense. It happens when someone I wanna keep in my life who likes me decides to approach me, closer to being my girlfriend than my friend. I can't even explain it at all—I think it's just my destiny that has decided to make me suffer during my most special moments, like my birthday, Christmas, etc.*",
				JAMMY_COLOR,
				false,
				true
			)
			current_phase = Phase.WAIT_AFTER_XCARLET_1

		Phase.SHOW_INSTRUCTIONS:
			_set_exclusive_hand("none")
			base_art_rect.texture = tex_xcarlet_1_tex
			reveal_art_rect.texture = tex_jammy_1
			reveal_material.set_shader_parameter("preserve_paper_bg", false)
			_clear_mask(0.0)

			_show_white_instruction(
				"[center]Draw the stroke with " + str(int(MIN_ACCURACY)) + "% or more accuracy on the indicated parts by using the mouse to move the hand and the [lb]M[rb] key to draw.[/center]\n[center]Press [lb]ENTER[rb] to begin.[/center]",
				false
			)

		Phase.JAMMY_1_CHAIN:
			_hide_dialogue()
			base_art_rect.texture = tex_xcarlet_1_tex
			reveal_art_rect.texture = tex_jammy_1
			_clear_mask(0.0)

			_start_dialogue(
				"Jammy",
				"*but you know, this time I can see a numb sunshine that has managed to break through this gray fog of false sunshine. It's not something incredible, but in my life full of sadness, that's a big win.*",
				JAMMY_COLOR,
				false,
				false
			)
			await _show_thought_dots_from_jammy()

			await _set_camera_zoom(2.35, Vector2(0.488, 0.554), 0.55)
			jammy_strokes_queue = _build_chain_links_strokes()
			_begin_jammy_interactive_queue()

		Phase.AUTO_XCARLET_2:
			_hide_dialogue()
			base_art_rect.texture = tex_jammy_1
			reveal_art_rect.texture = tex_xcarlet_2
			_clear_mask(0.0)

			await _animate_xcarlet_shading()
			await _retract_hand_down(xcarlet_hand_rect)

			_update_dialogue_prompt(true)
			current_phase = Phase.WAIT_AFTER_XCARLET_2

		Phase.JAMMY_2_WOUND_DROPS_PUDDLE:
			_hide_dialogue()
			base_art_rect.texture = tex_xcarlet_2
			reveal_art_rect.texture = tex_jammy_2
			_clear_mask(0.0)

			await _set_camera_zoom(2.20, Vector2(0.502, 0.565), 0.55)

			jammy_strokes_queue = [
				{
					"name": "wound_contour",
					"pts": _norm_to_screen([
						Vector2(0.499, 0.438),
						Vector2(0.514, 0.451),
						Vector2(0.525, 0.476),
						Vector2(0.512, 0.472),
						Vector2(0.502, 0.454),
						Vector2(0.499, 0.438)
					]),
					"reveal_radius": 16
				},
				{
					"name": "drop_left_top",
					"pts": _norm_to_screen(_build_slender_drop_norm_pts(Vector2(0.493, 0.583), 0.0035, 0.021)),
					"reveal_radius": 10
				},
				{
					"name": "drop_left_bottom",
					"pts": _norm_to_screen(_build_slender_drop_norm_pts(Vector2(0.491, 0.620), 0.0036, 0.022)),
					"reveal_radius": 10
				},
				{
					"name": "drop_right_top",
					"pts": _norm_to_screen(_build_slender_drop_norm_pts(Vector2(0.520, 0.553), 0.0035, 0.021)),
					"reveal_radius": 10
				},
				{
					"name": "drop_right_bottom",
					"pts": _norm_to_screen(_build_slender_drop_norm_pts(Vector2(0.517, 0.594), 0.0036, 0.022)),
					"reveal_radius": 10
				},
				{
					"name": "puddle_contour",
					"pts": _norm_to_screen([
						Vector2(0.474, 0.661),
						Vector2(0.484, 0.654),
						Vector2(0.499, 0.654),
						Vector2(0.508, 0.661),
						Vector2(0.499, 0.668),
						Vector2(0.484, 0.668),
						Vector2(0.474, 0.661)
					]),
					"reveal_radius": 14
				}
			]
			_begin_jammy_interactive_queue()

		Phase.AUTO_XCARLET_3:
			_hide_dialogue()
			base_art_rect.texture = tex_jammy_2
			reveal_art_rect.texture = tex_xcarlet_3
			_clear_mask(0.0)

			_start_dialogue("Xcarlet", "Ohh, I see—a bleeding heart. Let's heal it.", XCARLET_COLOR, false, false)
			await _animate_xcarlet_bandaid()
			await _retract_hand_down(xcarlet_hand_rect)

			_update_dialogue_prompt(true)
			current_phase = Phase.WAIT_AFTER_XCARLET_3

		Phase.JAMMY_3_KNIFE_CUTS:
			_hide_dialogue()
			base_art_rect.texture = tex_xcarlet_3
			reveal_art_rect.texture = tex_jammy_3
			_clear_mask(0.0)

			await _set_camera_zoom(1.75, Vector2(0.340, 0.515), 0.55)

			jammy_strokes_queue = [
				{
					"name": "knife_contour",
					"pts": _norm_to_screen([
						Vector2(0.199, 0.684),
						Vector2(0.322, 0.557),
						Vector2(0.327, 0.562),
						Vector2(0.431, 0.438),
						Vector2(0.432, 0.474),
						Vector2(0.421, 0.530),
						Vector2(0.396, 0.588),
						Vector2(0.356, 0.645),
						Vector2(0.331, 0.582),
						Vector2(0.207, 0.703),
						Vector2(0.199, 0.684)
					]),
					"reveal_radius": 14
				},
				{
					"name": "cut_1",
					"pts": _norm_to_screen([
						Vector2(0.362, 0.368),
						Vector2(0.376, 0.386),
						Vector2(0.390, 0.405)
					]),
					"reveal_radius": 12
				},
				{
					"name": "cut_2",
					"pts": _norm_to_screen([
						Vector2(0.378, 0.354),
						Vector2(0.392, 0.374),
						Vector2(0.406, 0.394)
					]),
					"reveal_radius": 12
				},
				{
					"name": "cut_3",
					"pts": _norm_to_screen([
						Vector2(0.394, 0.342),
						Vector2(0.408, 0.362),
						Vector2(0.421, 0.382)
					]),
					"reveal_radius": 12
				}
			]
			_begin_jammy_interactive_queue()

		Phase.JAMMY_4_BOTH_SIGNATURE:
			_hide_dialogue()
			base_art_rect.texture = tex_jammy_3
			reveal_art_rect.texture = tex_both
			_clear_mask(0.0)

			var sig_info: Dictionary = _analyze_both_signatures()
			var xcarlet_rect: Rect2 = sig_info["xcarlet_rect"]
			var jammy_rect: Rect2 = sig_info["jammy_rect"]
			active_jammy_ink_pts = sig_info["jammy_ink_pts"]
			active_xcarlet_ink_pts = sig_info["xcarlet_ink_pts"]
			active_signatures_split_x = sig_info["split_x"]

			var j_center_px: Vector2 = jammy_rect.get_center()
			var j_center_norm: Vector2 = Vector2(j_center_px.x / BASE_SIZE.x, j_center_px.y / BASE_SIZE.y)
			var j_rx: float = clampf((jammy_rect.size.x * 0.48) / BASE_SIZE.x, 0.011, 0.018)
			var j_ry: float = clampf((jammy_rect.size.y * 0.48) / BASE_SIZE.y, 0.018, 0.028)
			var jammy_sig_pts: PackedVector2Array = _norm_to_screen(_build_spiral_signature_norm_pts(j_center_norm, j_rx, j_ry))

			var both_center_px: Vector2 = xcarlet_rect.merge(jammy_rect).get_center()
			var sig_focus_norm: Vector2 = Vector2(both_center_px.x / BASE_SIZE.x, both_center_px.y / BASE_SIZE.y)

			_start_dialogue("Xcarlet", "Well, better start practicing our signatures.", XCARLET_COLOR, false, false)
			await _set_camera_zoom(2.65, sig_focus_norm, 0.55)
			await _animate_xcarlet_cat_signature(xcarlet_rect, active_xcarlet_ink_pts, active_signatures_split_x)
			await _retract_hand_down(xcarlet_hand_rect)

			jammy_strokes_queue = [
				{
					"name": "jammy_spiral_signature",
					"pts": jammy_sig_pts,
					"reveal_radius": 9
				}
			]
			_begin_jammy_interactive_queue()

		Phase.FINISHED:
			_hide_dialogue()
			_set_exclusive_hand("none")
			_finish_scene()


# ==============================================================================
# MECÁNICA INTERACTIVA BIDIRECCIONAL CON FEEDBACK REAL EN TIEMPO REAL
# ==============================================================================
func _begin_jammy_interactive_queue() -> void:
	current_stroke_idx = 0
	_set_exclusive_hand("jammy")
	_place_hand_at_screen_tip(jammy_hand_rect, JAMMY_TIP_UV, get_global_mouse_position(), false)
	_load_current_jammy_stroke()


func _load_current_jammy_stroke() -> void:
	if current_stroke_idx >= jammy_strokes_queue.size():
		_on_all_jammy_strokes_completed()
		return

	mask_snapshot = mask_image.get_data().duplicate()

	var raw_pts: PackedVector2Array = jammy_strokes_queue[current_stroke_idx]["pts"]
	active_guide_points = _resample_polyline(raw_pts, 5.0)
	is_closed_loop = (
		active_guide_points.size() >= 4
		and active_guide_points[0].distance_to(active_guide_points[active_guide_points.size() - 1]) < 16.0
	)

	guide_covered.clear()
	guide_covered.resize(active_guide_points.size())
	for i: int in range(guide_covered.size()):
		guide_covered[i] = false

	current_anchor_idx = -1
	is_player_tracing = false
	has_last_sample_pos = false
	sample_scores.clear()
	kawaii_panel.visible = false
	_stop_pencil_sound()
	guide_canvas.queue_redraw()


func _process(delta: float) -> void:
	guide_pulse_time += delta

	if is_pencil_actively_drawing:
		pencil_idle_timer -= delta
		if pencil_idle_timer <= 0.0:
			_stop_pencil_sound()

	if not active_guide_points.is_empty():
		guide_canvas.queue_redraw()

	if jammy_hand_rect.visible and not xcarlet_hand_rect.visible and _is_interactive_jammy_phase():
		var m_screen: Vector2 = get_global_mouse_position()
		var m_pressed: bool = Input.is_key_pressed(KEY_M)
		_place_hand_at_screen_tip(jammy_hand_rect, JAMMY_TIP_UV, m_screen, m_pressed)

		var screen_tip: Vector2 = _get_hand_tip_screen_pos(jammy_hand_rect, JAMMY_TIP_UV)
		var canvas_tip: Vector2 = _screen_to_canvas(screen_tip)

		if m_pressed:
			if not is_player_tracing:
				is_player_tracing = true
				has_last_sample_pos = false
				sample_scores.clear()
				_sync_kawaii_panel_position()
				kawaii_panel.visible = true
				_update_kawaii_bar(100.0)
			_record_player_trace_at_tip(canvas_tip)
		elif is_player_tracing:
			is_player_tracing = false
			has_last_sample_pos = false
			_stop_pencil_sound()
			_evaluate_on_release()


func _is_blocking_wait_phase() -> bool:
	return current_phase in [
		Phase.WAIT_AFTER_XCARLET_1,
		Phase.SHOW_INSTRUCTIONS,
		Phase.WAIT_AFTER_XCARLET_2,
		Phase.WAIT_AFTER_XCARLET_3,
		Phase.WAIT_KNIFE_XCARLET_REACTION,
		Phase.WAIT_KNIFE_JAMMY_RESPONSE,
		Phase.WAIT_SUNSHINE_XCARLET_QUESTION,
		Phase.WAIT_SUNSHINE_JAMMY_RESPONSE,
		Phase.WAIT_DELAYED_DIALOGUES,
		Phase.FINISHED
	]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if _has_more_dialogues():
				dialogue_queue_idx += 1
				_render_dialogue_entry(dialogue_queue[dialogue_queue_idx])
				_update_dialogue_prompt(_is_blocking_wait_phase())
				return

			match current_phase:
				Phase.WAIT_DELAYED_DIALOGUES:
					_hide_white_instruction()
					_execute_post_jammy_phase(delayed_return_phase)
				Phase.WAIT_AFTER_XCARLET_1:
					_start_phase(Phase.SHOW_INSTRUCTIONS)
				Phase.SHOW_INSTRUCTIONS:
					_start_phase(Phase.JAMMY_1_CHAIN)
				Phase.WAIT_AFTER_XCARLET_2:
					_start_phase(Phase.JAMMY_2_WOUND_DROPS_PUDDLE)
				Phase.WAIT_AFTER_XCARLET_3:
					_start_phase(Phase.JAMMY_3_KNIFE_CUTS)
				Phase.WAIT_KNIFE_XCARLET_REACTION:
					_start_dialogue(
						"Jammy",
						"It's because a heart like this never stops its suffering and just wishes to die, cuz it seems to be the easier way to turn off the false sunshine, which just worsens the situation with its melancholic light—but it hasn't been able to do it.",
						JAMMY_COLOR,
						false,
						true
					)
					current_phase = Phase.WAIT_KNIFE_JAMMY_RESPONSE
				Phase.WAIT_KNIFE_JAMMY_RESPONSE:
					_start_phase(Phase.JAMMY_4_BOTH_SIGNATURE)
				Phase.WAIT_SUNSHINE_XCARLET_QUESTION:
					_start_dialogue(
						"Jammy",
						"Cuz it's false sunshine. It isn't warm and cheerful light—it's just a draining thing.",
						JAMMY_COLOR,
						false,
						true
					)
					current_phase = Phase.WAIT_SUNSHINE_JAMMY_RESPONSE
				Phase.WAIT_SUNSHINE_JAMMY_RESPONSE:
					_start_phase(Phase.FINISHED)
				Phase.FINISHED:
					_finish_scene()


func _is_interactive_jammy_phase() -> bool:
	return current_phase in [
		Phase.JAMMY_1_CHAIN,
		Phase.JAMMY_2_WOUND_DROPS_PUDDLE,
		Phase.JAMMY_3_KNIFE_CUTS,
		Phase.JAMMY_4_BOTH_SIGNATURE
	]


func _wrap_guide_index(raw_idx: int, total_pts: int) -> int:
	if is_closed_loop:
		var m: int = raw_idx % total_pts
		if m < 0:
			m += total_pts
		return m
	return clampi(raw_idx, 0, total_pts - 1)


func _mark_arc_covered(from_idx: int, to_idx: int, delta_step: int, total_pts: int) -> void:
	var steps: int = absi(delta_step)
	var dir: int = 1 if delta_step >= 0 else -1
	for s: int in range(steps + 1):
		var idx: int = _wrap_guide_index(from_idx + s * dir, total_pts)
		guide_covered[idx] = true
	if is_closed_loop:
		if guide_covered[0] or guide_covered[total_pts - 1]:
			guide_covered[0] = true
			guide_covered[total_pts - 1] = true


func _compute_covered_ratio() -> float:
	if guide_covered.is_empty():
		return 0.0
	var count: int = 0
	for c: bool in guide_covered:
		if c:
			count += 1
	return float(count) / float(guide_covered.size())


func _score_from_distance(dist_px: float) -> float:
	if dist_px <= 3.5:
		return 1.0
	elif dist_px <= 10.0:
		return lerpf(0.96, 0.80, (dist_px - 3.5) / 6.5)
	elif dist_px <= 20.0:
		return lerpf(0.80, 0.45, (dist_px - 10.0) / 10.0)
	elif dist_px <= OFF_PATH_ZERO_DIST:
		return lerpf(0.45, 0.0, (dist_px - 20.0) / (OFF_PATH_ZERO_DIST - 20.0))
	return 0.0


func _record_player_trace_at_tip(canvas_tip: Vector2) -> void:
	if active_guide_points.is_empty():
		return

	if has_last_sample_pos and last_sample_pos.distance_to(canvas_tip) < 2.5:
		return

	last_sample_pos = canvas_tip
	has_last_sample_pos = true

	var total_pts: int = active_guide_points.size()

	if current_anchor_idx == -1:
		var start_best_idx: int = -1
		var start_best_dist: float = 999999.0
		for i: int in range(total_pts):
			var d: float = canvas_tip.distance_to(active_guide_points[i])
			if d < start_best_dist:
				start_best_dist = d
				start_best_idx = i

		if start_best_idx != -1 and start_best_dist <= SNAP_MAX_DIST:
			current_anchor_idx = start_best_idx
			_mark_arc_covered(current_anchor_idx, current_anchor_idx, 0, total_pts)
			sample_scores.append(_score_from_distance(start_best_dist))
		else:
			sample_scores.append(_score_from_distance(start_best_dist))
	else:
		var best_step: int = 0
		var best_idx: int = -1
		var best_dist: float = 999999.0

		for step: int in range(-2, 3):
			if not is_closed_loop:
				var raw: int = current_anchor_idx + step
				if raw < 0 or raw >= total_pts:
					continue
			var cand_idx: int = _wrap_guide_index(current_anchor_idx + step, total_pts)
			var d: float = canvas_tip.distance_to(active_guide_points[cand_idx])
			if d < best_dist:
				best_dist = d
				best_idx = cand_idx
				best_step = step

		if best_idx != -1 and best_dist <= STEP_MAX_DIST:
			_mark_arc_covered(current_anchor_idx, best_idx, best_step, total_pts)
			current_anchor_idx = best_idx
			sample_scores.append(_score_from_distance(best_dist))
		else:
			var off_dist: float = canvas_tip.distance_to(active_guide_points[current_anchor_idx])
			sample_scores.append(_score_from_distance(off_dist))

	var current_acc: float = _compute_precision_percent()
	_update_kawaii_bar(current_acc)

	if sample_scores.size() >= 8 and current_acc < 45.0:
		is_player_tracing = false
		has_last_sample_pos = false
		_stop_pencil_sound()
		_reset_current_stroke(current_acc)
		return

	if _compute_covered_ratio() >= MIN_COVERAGE_RATIO:
		is_player_tracing = false
		has_last_sample_pos = false
		_stop_pencil_sound()
		if current_acc >= MIN_ACCURACY:
			_complete_current_stroke()
		else:
			_reset_current_stroke(current_acc)


func _compute_precision_percent() -> float:
	if sample_scores.is_empty():
		return 100.0
	var total: float = 0.0
	for s: float in sample_scores:
		total += s
	return (total / float(sample_scores.size())) * 100.0


func _evaluate_on_release() -> void:
	var current_acc: float = _compute_precision_percent()
	if _compute_covered_ratio() >= (MIN_COVERAGE_RATIO - 0.02) and current_acc >= MIN_ACCURACY:
		_complete_current_stroke()
	else:
		_reset_current_stroke(current_acc)


func _complete_current_stroke() -> void:
	kawaii_panel.visible = false
	var finished_stroke_name: String = jammy_strokes_queue[current_stroke_idx].get("name", "")
	var pts: PackedVector2Array = jammy_strokes_queue[current_stroke_idx]["pts"]
	var reveal_r: int = jammy_strokes_queue[current_stroke_idx].get("reveal_radius", 14)

	if current_phase == Phase.JAMMY_4_BOTH_SIGNATURE and finished_stroke_name == "jammy_spiral_signature":
		# Revelar de inmediato y por completo cada trazo de la firma de Jammy (sin cajas rectangulares)
		for p: Vector2 in _resample_polyline(pts, 4.0):
			_paint_mask_circle_no_update(p, 8, 1.0, -99999.0, active_signatures_split_x - 6.0)
		for ink_pt: Vector2 in active_jammy_ink_pts:
			_paint_mask_circle_no_update(ink_pt, 7, 1.0, -99999.0, active_signatures_split_x - 6.0)
		mask_texture.update(mask_image)
	else:
		for p: Vector2 in _resample_polyline(pts, 4.0):
			_paint_mask_circle_no_update(p, reveal_r, 1.0)
		mask_texture.update(mask_image)

	if current_phase == Phase.JAMMY_2_WOUND_DROPS_PUDDLE and finished_stroke_name == "wound_contour":
		_start_dialogue(
			"Jammy",
			"*A heart full of wounds that bleeds black blood, cuz its suffering has wiped any color out.*",
			JAMMY_COLOR,
			false,
			false
		)

	current_stroke_idx += 1
	_load_current_jammy_stroke()


func _reset_current_stroke(_acc_val: float) -> void:
	kawaii_panel.visible = false
	mask_image.set_data(MASK_SIZE.x, MASK_SIZE.y, false, Image.FORMAT_RGBA8, mask_snapshot)
	mask_texture.update(mask_image)
	_load_current_jammy_stroke()


func _on_all_jammy_strokes_completed() -> void:
	active_guide_points = PackedVector2Array()
	guide_covered.clear()
	current_anchor_idx = -1
	has_last_sample_pos = false
	guide_canvas.queue_redraw()
	kawaii_panel.visible = false
	_stop_pencil_sound()

	var completed_phase: Phase = current_phase

	if _has_more_dialogues():
		delayed_return_phase = completed_phase
		current_phase = Phase.WAIT_DELAYED_DIALOGUES
		dialogue_queue_idx += 1
		_render_dialogue_entry(dialogue_queue[dialogue_queue_idx])
		_update_dialogue_prompt(true)
		return

	_execute_post_jammy_phase(completed_phase)


func _execute_post_jammy_phase(completed_phase: Phase) -> void:
	match completed_phase:
		Phase.JAMMY_1_CHAIN:
			_hide_dialogue()
			await _hide_thought_dots_badge()
			await _set_camera_zoom(1.0, Vector2(0.5, 0.5), 0.55)
			await _retract_hand_down(jammy_hand_rect)
			_start_phase(Phase.AUTO_XCARLET_2)

		Phase.JAMMY_2_WOUND_DROPS_PUDDLE:
			_hide_dialogue()
			await _set_camera_zoom(1.0, Vector2(0.5, 0.5), 0.55)
			await _animate_jammy_puddle_fill()
			await _retract_hand_down(jammy_hand_rect)
			_start_phase(Phase.AUTO_XCARLET_3)

		Phase.JAMMY_3_KNIFE_CUTS:
			_hide_dialogue()
			await _set_camera_zoom(1.0, Vector2(0.5, 0.5), 0.55)
			await _animate_jammy_knife_fill()
			await _retract_hand_down(jammy_hand_rect)

			current_phase = Phase.WAIT_KNIFE_XCARLET_REACTION
			_start_dialogue("Xcarlet", "Ohh, you're mad, sis—another wound? Why?", XCARLET_COLOR, false, true)

		Phase.JAMMY_4_BOTH_SIGNATURE:
			_hide_dialogue()
			await _set_camera_zoom(1.0, Vector2(0.5, 0.5), 0.55)
			await _animate_jammy_yellow_light()
			await _retract_hand_down(jammy_hand_rect)

			current_phase = Phase.WAIT_SUNSHINE_XCARLET_QUESTION
			_start_dialogue("Xcarlet", "And why sunshine?", XCARLET_COLOR, false, true)


# ==============================================================================
# ANIMACIONES REALISTAS TRAZO A TRAZO + COMPLETADO INSTANTÁNEO SIN LAG
# ==============================================================================
func _animate_xcarlet_heart_outline() -> void:
	_set_exclusive_hand("xcarlet")
	var left_lobe: PackedVector2Array = _norm_to_screen([
		Vector2(0.476, 0.415),
		Vector2(0.448, 0.372),
		Vector2(0.418, 0.362),
		Vector2(0.396, 0.415),
		Vector2(0.408, 0.495),
		Vector2(0.438, 0.578),
		Vector2(0.475, 0.646)
	])
	await _sweep_hand_along_path(xcarlet_hand_rect, XCARLET_TIP_UV, left_lobe, 0.72, 24, 1.0)
	_stop_pencil_sound()
	await _sweep_hand_along_path(xcarlet_hand_rect, XCARLET_TIP_UV, left_lobe, 0.42, 28, 1.0)
	_stop_pencil_sound()

	var right_lobe: PackedVector2Array = _norm_to_screen([
		Vector2(0.476, 0.415),
		Vector2(0.502, 0.372),
		Vector2(0.534, 0.362),
		Vector2(0.558, 0.422),
		Vector2(0.546, 0.495),
		Vector2(0.514, 0.580),
		Vector2(0.475, 0.646)
	])
	await _sweep_hand_along_path(xcarlet_hand_rect, XCARLET_TIP_UV, right_lobe, 0.72, 24, 1.0)
	_stop_pencil_sound()
	await _sweep_hand_along_path(xcarlet_hand_rect, XCARLET_TIP_UV, right_lobe, 0.42, 28, 1.0)
	_stop_pencil_sound()
	_complete_full_mask_fast()


func _animate_xcarlet_shading() -> void:
	_set_exclusive_hand("xcarlet")
	var left_shade_outer: PackedVector2Array = _norm_to_screen([
		Vector2(0.452, 0.382),
		Vector2(0.418, 0.372),
		Vector2(0.402, 0.422),
		Vector2(0.414, 0.500),
		Vector2(0.444, 0.578),
		Vector2(0.475, 0.635)
	])
	await _sweep_hand_along_path(xcarlet_hand_rect, XCARLET_TIP_UV, left_shade_outer, 0.52, 36, 1.0)
	_stop_pencil_sound()

	var left_shade_inner: PackedVector2Array = _norm_to_screen([
		Vector2(0.468, 0.425),
		Vector2(0.440, 0.405),
		Vector2(0.425, 0.450),
		Vector2(0.438, 0.525),
		Vector2(0.475, 0.610)
	])
	await _sweep_hand_along_path(xcarlet_hand_rect, XCARLET_TIP_UV, left_shade_inner, 0.45, 38, 1.0)
	_stop_pencil_sound()

	var right_shade_outer: PackedVector2Array = _norm_to_screen([
		Vector2(0.500, 0.382),
		Vector2(0.532, 0.372),
		Vector2(0.550, 0.425),
		Vector2(0.538, 0.502),
		Vector2(0.508, 0.578),
		Vector2(0.475, 0.635)
	])
	await _sweep_hand_along_path(xcarlet_hand_rect, XCARLET_TIP_UV, right_shade_outer, 0.52, 36, 1.0)
	_stop_pencil_sound()

	var right_shade_inner: PackedVector2Array = _norm_to_screen([
		Vector2(0.484, 0.425),
		Vector2(0.512, 0.405),
		Vector2(0.526, 0.455),
		Vector2(0.512, 0.525),
		Vector2(0.475, 0.610)
	])
	await _sweep_hand_along_path(xcarlet_hand_rect, XCARLET_TIP_UV, right_shade_inner, 0.45, 38, 1.0)
	_stop_pencil_sound()

	var outer_smudge_left: PackedVector2Array = _norm_to_screen([
		Vector2(0.412, 0.352),
		Vector2(0.384, 0.415),
		Vector2(0.398, 0.505),
		Vector2(0.432, 0.592),
		Vector2(0.475, 0.658)
	])
	await _sweep_hand_along_path(xcarlet_hand_rect, XCARLET_TIP_UV, outer_smudge_left, 0.40, 38, 1.0)
	_stop_pencil_sound()

	var outer_smudge_right: PackedVector2Array = _norm_to_screen([
		Vector2(0.540, 0.352),
		Vector2(0.568, 0.422),
		Vector2(0.554, 0.505),
		Vector2(0.520, 0.592),
		Vector2(0.475, 0.658)
	])
	await _sweep_hand_along_path(xcarlet_hand_rect, XCARLET_TIP_UV, outer_smudge_right, 0.40, 38, 1.0)
	_stop_pencil_sound()
	_complete_full_mask_fast()


func _animate_xcarlet_bandaid() -> void:
	_set_exclusive_hand("xcarlet")
	var bandaid_outline: PackedVector2Array = _norm_to_screen([
		Vector2(0.492, 0.415),
		Vector2(0.531, 0.453),
		Vector2(0.512, 0.483),
		Vector2(0.477, 0.443),
		Vector2(0.492, 0.415)
	])
	await _sweep_hand_along_path(xcarlet_hand_rect, XCARLET_TIP_UV, bandaid_outline, 0.48, 16, 1.0)
	_stop_pencil_sound()

	var gauze_box: PackedVector2Array = _norm_to_screen([
		Vector2(0.496, 0.430),
		Vector2(0.519, 0.452),
		Vector2(0.508, 0.469),
		Vector2(0.486, 0.446),
		Vector2(0.496, 0.430)
	])
	await _sweep_hand_along_path(xcarlet_hand_rect, XCARLET_TIP_UV, gauze_box, 0.34, 16, 1.0)
	_stop_pencil_sound()

	var gauze_cross_1: PackedVector2Array = _norm_to_screen([
		Vector2(0.494, 0.434),
		Vector2(0.512, 0.463)
	])
	await _sweep_hand_along_path(xcarlet_hand_rect, XCARLET_TIP_UV, gauze_cross_1, 0.18, 16, 1.0)
	_stop_pencil_sound()

	var gauze_cross_2: PackedVector2Array = _norm_to_screen([
		Vector2(0.515, 0.443),
		Vector2(0.491, 0.457)
	])
	await _sweep_hand_along_path(xcarlet_hand_rect, XCARLET_TIP_UV, gauze_cross_2, 0.18, 16, 1.0)
	_stop_pencil_sound()

	var side_flaps: PackedVector2Array = _norm_to_screen([
		Vector2(0.483, 0.432),
		Vector2(0.492, 0.441),
		Vector2(0.517, 0.462),
		Vector2(0.525, 0.470)
	])
	await _sweep_hand_along_path(xcarlet_hand_rect, XCARLET_TIP_UV, side_flaps, 0.22, 18, 1.0)
	_stop_pencil_sound()
	_complete_full_mask_fast()


func _animate_jammy_puddle_fill() -> void:
	_set_exclusive_hand("jammy")
	var puddle_fill_stroke: PackedVector2Array = _norm_to_screen([
		Vector2(0.476, 0.661),
		Vector2(0.506, 0.661),
		Vector2(0.478, 0.665),
		Vector2(0.504, 0.665)
	])
	await _sweep_hand_along_path(jammy_hand_rect, JAMMY_TIP_UV, puddle_fill_stroke, 0.36, 16, 1.0)
	_stop_pencil_sound()
	_complete_full_mask_fast()


func _animate_jammy_knife_fill() -> void:
	_set_exclusive_hand("jammy")
	var handle_stroke: PackedVector2Array = _norm_to_screen([
		Vector2(0.203, 0.693),
		Vector2(0.325, 0.568),
		Vector2(0.330, 0.576),
		Vector2(0.206, 0.698)
	])
	await _sweep_hand_along_path(jammy_hand_rect, JAMMY_TIP_UV, handle_stroke, 0.40, 18, 1.0)
	_stop_pencil_sound()

	var blade_shade: PackedVector2Array = _norm_to_screen([
		Vector2(0.428, 0.455),
		Vector2(0.342, 0.575),
		Vector2(0.354, 0.625),
		Vector2(0.415, 0.525)
	])
	await _sweep_hand_along_path(jammy_hand_rect, JAMMY_TIP_UV, blade_shade, 0.44, 24, 1.0)
	_stop_pencil_sound()
	_complete_full_mask_fast()


func _animate_xcarlet_cat_signature(xcarlet_rect: Rect2, xcarlet_ink: PackedVector2Array, split_x: float) -> void:
	_set_exclusive_hand("xcarlet")
	var min_x_guard: float = split_x + 8.0
	var cat_strokes: Array[PackedVector2Array] = _build_smooth_cat_signature_strokes(xcarlet_rect, min_x_guard)
	for stroke_path: PackedVector2Array in cat_strokes:
		if stroke_path.is_empty():
			continue
		await _sweep_hand_along_path(
			xcarlet_hand_rect,
			XCARLET_TIP_UV,
			stroke_path,
			0.20,
			7,
			1.0,
			min_x_guard,
			99999.0
		)
		_stop_pencil_sound()

	# Completar únicamente los píxeles de tinta de Xcarlet sin invadir la firma de Jammy
	for ink_pt: Vector2 in xcarlet_ink:
		_paint_mask_circle_no_update(ink_pt, 7, 1.0, min_x_guard, 99999.0)
	mask_texture.update(mask_image)


func _animate_jammy_yellow_light() -> void:
	_set_exclusive_hand("jammy")

	# Trazos de resplandor y rayos largos con grosor de lápiz real (sin silueta redondeada)
	var sun_strokes: Array[Array] = [
		# Rayos superiores y diagonales largos
		[Vector2(0.476, 0.340), Vector2(0.476, 0.080)],
		[Vector2(0.425, 0.355), Vector2(0.240, 0.110)],
		[Vector2(0.528, 0.355), Vector2(0.715, 0.110)],
		# Rayos laterales amplios
		[Vector2(0.565, 0.430), Vector2(0.840, 0.285)],
		[Vector2(0.575, 0.515), Vector2(0.865, 0.525)],
		[Vector2(0.555, 0.595), Vector2(0.810, 0.775)],
		# Rayo inferior y rayos izquierdos
		[Vector2(0.476, 0.655), Vector2(0.476, 0.895)],
		[Vector2(0.398, 0.595), Vector2(0.145, 0.775)],
		[Vector2(0.378, 0.515), Vector2(0.095, 0.525)],
		[Vector2(0.388, 0.430), Vector2(0.115, 0.285)],
		# Pasadas diagonales de luz alrededor del corazón
		[Vector2(0.360, 0.320), Vector2(0.430, 0.260), Vector2(0.525, 0.265), Vector2(0.595, 0.325)],
		[Vector2(0.605, 0.380), Vector2(0.635, 0.495), Vector2(0.600, 0.625)],
		[Vector2(0.350, 0.380), Vector2(0.320, 0.495), Vector2(0.355, 0.625)]
	]

	for stroke_pts: Array in sun_strokes:
		await _sweep_hand_along_path(jammy_hand_rect, JAMMY_TIP_UV, _norm_to_screen(stroke_pts), 0.15, 24, 1.0)
		_stop_pencil_sound()

	# Fundido suave del brillo ambiental restante para evitar cortes bruscos
	await _fade_complete_mask(0.45)


func _sweep_hand_along_path(
	hand: TextureRect,
	tip_uv: Vector2,
	canvas_path: PackedVector2Array,
	duration: float,
	brush_radius_px: int,
	opacity_strength: float,
	clamp_min_x: float = -99999.0,
	clamp_max_x: float = 99999.0
) -> void:
	var sampled: PackedVector2Array = _resample_polyline(canvas_path, 11.0)
	if sampled.is_empty():
		return

	var move_dur: float = 0.22 if not hand.visible else 0.10
	await _enter_hand_to_canvas_point(hand, tip_uv, sampled[0], move_dur)

	var step_time: float = clampf(duration / float(sampled.size()), 0.008, 0.028)
	for i: int in range(sampled.size()):
		var canvas_pt: Vector2 = sampled[i]
		_place_hand_at_screen_tip(hand, tip_uv, _canvas_to_screen(canvas_pt), true)
		_paint_mask_circle(canvas_pt, brush_radius_px, opacity_strength, clamp_min_x, clamp_max_x)
		await get_tree().create_timer(step_time).timeout


# ==============================================================================
# DIBUJO DE LÍNEAS PUNTEADAS FINAS QUE CAMBIAN DE COLOR EN CUALQUIER SENTIDO
# ==============================================================================
func _on_guide_canvas_draw() -> void:
	if active_guide_points.size() < 2 or guide_covered.size() != active_guide_points.size():
		return

	var pulse: float = 0.72 + 0.28 * sin(guide_pulse_time * 5.0)
	var pending_col: Color = Color(0.95, 0.25, 0.46, pulse)
	var done_col: Color = Color(0.16, 0.78, 0.50, 0.96)

	for i: int in range(0, active_guide_points.size() - 1, 2):
		var next_i: int = mini(i + 1, active_guide_points.size() - 1)
		var p1: Vector2 = active_guide_points[i]
		var p2: Vector2 = active_guide_points[next_i]
		var is_seg_done: bool = guide_covered[i] and guide_covered[next_i]
		var col: Color = done_col if is_seg_done else pending_col
		guide_canvas.draw_line(p1, p2, col, 3.0, true)


# ==============================================================================
# UTILIDADES DE MÁSCARA, GEOMETRÍA Y BARRA DE ACCURACY GRADUAL
# ==============================================================================
func _clear_mask(alpha_val: float) -> void:
	if reveal_material != null:
		reveal_material.set_shader_parameter("extra_reveal", 0.0)
	mask_image.fill(Color(alpha_val, alpha_val, alpha_val, 1.0))
	mask_texture.update(mask_image)


func _complete_full_mask_fast() -> void:
	mask_image.fill(Color(1.0, 1.0, 1.0, 1.0))
	mask_texture.update(mask_image)
	if reveal_material != null:
		reveal_material.set_shader_parameter("extra_reveal", 0.0)


func _fade_complete_mask(duration: float = 0.45) -> void:
	if reveal_material == null:
		_complete_full_mask_fast()
		return
	var fade_tween: Tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.tween_method(
		func(val: float) -> void:
			reveal_material.set_shader_parameter("extra_reveal", val),
		0.0,
		1.0,
		duration
	)
	await fade_tween.finished
	_complete_full_mask_fast()


func _paint_mask_circle_no_update(
	canvas_pos: Vector2,
	radius_px: int,
	target_alpha: float = 1.0,
	clamp_min_x: float = -99999.0,
	clamp_max_x: float = 99999.0
) -> void:
	var uv: Vector2 = Vector2(canvas_pos.x / BASE_SIZE.x, canvas_pos.y / BASE_SIZE.y)
	var cx: int = int(uv.x * float(MASK_SIZE.x))
	var cy: int = int(uv.y * float(MASK_SIZE.y))
	var r_sq: int = radius_px * radius_px

	var min_x: int = maxi(cx - radius_px, 0)
	var max_x: int = mini(cx + radius_px, MASK_SIZE.x - 1)
	var min_y: int = maxi(cy - radius_px, 0)
	var max_y: int = mini(cy + radius_px, MASK_SIZE.y - 1)

	if clamp_min_x > -90000.0:
		var m_min: int = clampi(int(ceil((clamp_min_x / BASE_SIZE.x) * float(MASK_SIZE.x))), 0, MASK_SIZE.x - 1)
		min_x = maxi(min_x, m_min)
	if clamp_max_x < 90000.0:
		var m_max: int = clampi(int(floor((clamp_max_x / BASE_SIZE.x) * float(MASK_SIZE.x))), 0, MASK_SIZE.x - 1)
		max_x = mini(max_x, m_max)

	for y: int in range(min_y, max_y + 1):
		var dy: int = y - cy
		for x: int in range(min_x, max_x + 1):
			var dx: int = x - cx
			var d_sq: int = dx * dx + dy * dy
			if d_sq <= r_sq:
				var falloff: float = 1.0 - (float(d_sq) / float(maxi(r_sq, 1))) * 0.15
				var val: float = clampf(target_alpha * falloff, 0.0, 1.0)
				var cur: float = mask_image.get_pixel(x, y).r
				if val > cur:
					mask_image.set_pixel(x, y, Color(val, val, val, 1.0))


func _paint_mask_circle(
	canvas_pos: Vector2,
	radius_px: int,
	target_alpha: float = 1.0,
	clamp_min_x: float = -99999.0,
	clamp_max_x: float = 99999.0
) -> void:
	_paint_mask_circle_no_update(canvas_pos, radius_px, target_alpha, clamp_min_x, clamp_max_x)
	mask_texture.update(mask_image)


func _norm_to_screen(norm_pts: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for item in norm_pts:
		var np: Vector2 = item
		out.append(Vector2(np.x * BASE_SIZE.x, np.y * BASE_SIZE.y))
	return out


func _resample_polyline(pts: PackedVector2Array, spacing: float) -> PackedVector2Array:
	if pts.size() < 2:
		return pts
	var result: PackedVector2Array = PackedVector2Array()
	result.append(pts[0])
	var accum: float = 0.0
	for i: int in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var seg_len: float = a.distance_to(b)
		if seg_len < 0.001:
			continue
		var dir: Vector2 = (b - a) / seg_len
		var pos: Vector2 = a
		var remaining: float = seg_len
		while accum + remaining >= spacing:
			var step: float = spacing - accum
			pos += dir * step
			result.append(pos)
			remaining -= step
			accum = 0.0
		accum += remaining
	if result[result.size() - 1].distance_to(pts[pts.size() - 1]) > 2.0:
		result.append(pts[pts.size() - 1])
	return result


func _get_accuracy_bar_color(pct: float) -> Color:
	if pct >= 90.0:
		return Color("#ff85a1")
	elif pct >= 80.0:
		return Color("#ff5c8a")
	elif pct >= 70.0:
		return Color("#ff3366")
	elif pct >= 60.0:
		return Color("#e62e3d")
	elif pct >= 50.0:
		return Color("#cc1424")
	else:
		return Color("#99000d")


func _update_kawaii_bar(pct: float) -> void:
	var clamped: float = clampf(pct, 0.0, 100.0)
	var ratio: float = clamped / 100.0
	var bar_col: Color = _get_accuracy_bar_color(clamped)

	kawaii_bar_fill.size.x = 662.0 * ratio
	kawaii_bar_fill.color = bar_col
	kawaii_percent_label.add_theme_color_override("font_color", bar_col.darkened(0.15))

	if clamped >= MIN_ACCURACY:
		kawaii_percent_label.text = str(int(round(clamped))) + "% ★"
	else:
		kawaii_percent_label.text = str(int(round(clamped))) + "% !"


# ==============================================================================
# SISTEMA DE DIÁLOGOS CON DIVISIÓN ESTRICTA (CERO DESBORDAMIENTO) Y COLA DE ATRASADOS
# ==============================================================================
func _fits_in_dialogue_box(candidate: String, font: Font, font_size: int, max_width: float, max_height: float) -> bool:
	if font == null:
		return candidate.length() <= 85
	var measured: Vector2 = font.get_multiline_string_size(candidate, HORIZONTAL_ALIGNMENT_CENTER, max_width, font_size)
	return measured.y <= max_height


func _apply_thought_markers(text: String, add_start: bool, add_end: bool) -> String:
	var result: String = text
	if add_start:
		result = "*" + result
	if add_end:
		result += "*"
	return result


func _split_text_for_dialogue_box(raw_text: String, is_mind: bool) -> Array[String]:
	var font: Font = rock_salt_font if is_mind else fredoka_font
	var font_size: int = 36 if is_mind else 46
	var max_width: float = DIALOGUE_PANEL_SIZE.x - 130.0
	var max_height: float = 145.0 if is_mind else 156.0

	var has_start_marker: bool = is_mind or raw_text.begins_with("*")
	var has_end_marker: bool = is_mind or raw_text.ends_with("*")
	var inner_text: String = raw_text.trim_prefix("*").trim_suffix("*")

	var full_marked: String = _apply_thought_markers(inner_text, has_start_marker, has_end_marker)
	if _fits_in_dialogue_box(full_marked, font, font_size, max_width, max_height):
		return [full_marked]

	var pages: Array[String] = []
	var chunk: String = ""
	for word: String in inner_text.split(" "):
		var candidate: String = word if chunk.is_empty() else chunk + " " + word
		var marked_candidate: String = _apply_thought_markers(candidate, has_start_marker, has_end_marker)
		if not chunk.is_empty() and not _fits_in_dialogue_box(marked_candidate, font, font_size, max_width, max_height):
			pages.append(_apply_thought_markers(chunk, has_start_marker, false))
			has_start_marker = false
			chunk = word
		else:
			chunk = candidate

	if not chunk.is_empty():
		pages.append(_apply_thought_markers(chunk, has_start_marker, has_end_marker))

	return pages


func _has_more_dialogues() -> bool:
	return dialogue_queue_idx + 1 < dialogue_queue.size()


func _start_dialogue(speaker: String, text: String, border_col: Color, is_mind: bool = false, is_blocking_wait: bool = false) -> void:
	var pages: Array[String] = _split_text_for_dialogue_box(text, is_mind)
	dialogue_queue.clear()
	for page: String in pages:
		dialogue_queue.append({
			"speaker": speaker,
			"text": page,
			"border_col": border_col,
			"is_mind": is_mind
		})

	dialogue_queue_idx = 0
	_render_dialogue_entry(dialogue_queue[0])
	_update_dialogue_prompt(is_blocking_wait)


func _render_dialogue_entry(entry: Dictionary) -> void:
	var speaker: String = entry["speaker"]
	var text: String = entry["text"]
	var border_col: Color = entry["border_col"]
	var is_mind: bool = entry["is_mind"]

	var is_signature_moment: bool = (
		current_phase == Phase.JAMMY_4_BOTH_SIGNATURE
		or (current_phase == Phase.WAIT_DELAYED_DIALOGUES and delayed_return_phase == Phase.JAMMY_4_BOTH_SIGNATURE)
	)
	var panel_pos: Vector2 = DIALOGUE_PANEL_LEFT_POS if is_signature_moment else DIALOGUE_PANEL_POS

	dialogue_panel.visible = true
	dialogue_panel.position = panel_pos
	dialogue_panel.size = DIALOGUE_PANEL_SIZE
	dialogue_label.position = Vector2(44.0, 20.0)
	dialogue_label.size = Vector2(DIALOGUE_PANEL_SIZE.x - 88.0, DIALOGUE_PANEL_SIZE.y - 40.0)

	if is_mind and border_col == MIND_COLOR:
		dialogue_label.add_theme_color_override("font_color", MIND_COLOR)
		if rock_salt_font:
			dialogue_label.add_theme_font_override("font", rock_salt_font)
		dialogue_label.add_theme_font_size_override("font_size", 36)
		dialogue_label.add_theme_constant_override("outline_size", 0)
		dialogue_label.add_theme_color_override("font_shadow_color", Color("#000000e6"))
		dialogue_label.add_theme_constant_override("shadow_offset_x", 3)
		dialogue_label.add_theme_constant_override("shadow_offset_y", 3)

		var j_border: Color = Color(JAMMY_COLOR.r, JAMMY_COLOR.g, JAMMY_COLOR.b, 0.85)
		dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(MIND_PANEL_COLOR, j_border))

		speaker_panel.visible = true
		speaker_panel.position = Vector2(panel_pos.x + 36.0, panel_pos.y - SPEAKER_PANEL_SIZE.y + 2.0)
		speaker_panel.size = SPEAKER_PANEL_SIZE
		speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, JAMMY_COLOR))
		speaker_label.text = speaker
		speaker_label.add_theme_color_override("font_color", JAMMY_COLOR)
	else:
		dialogue_label.add_theme_color_override("font_color", NORMAL_BLACK_TEXT_COLOR)
		if fredoka_font:
			dialogue_label.add_theme_font_override("font", fredoka_font)
		dialogue_label.add_theme_font_size_override("font_size", 46)
		dialogue_label.add_theme_constant_override("outline_size", 0)
		dialogue_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		dialogue_label.add_theme_constant_override("shadow_offset_x", 0)
		dialogue_label.add_theme_constant_override("shadow_offset_y", 0)

		var s_border: Color = Color(border_col.r, border_col.g, border_col.b, 0.85)
		dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(NORMAL_WHITE_PANEL_COLOR, s_border))

		speaker_panel.visible = true
		speaker_panel.position = Vector2(panel_pos.x + 36.0, panel_pos.y - SPEAKER_PANEL_SIZE.y + 2.0)
		speaker_panel.size = SPEAKER_PANEL_SIZE
		speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, border_col))
		speaker_label.text = speaker
		speaker_label.add_theme_color_override("font_color", border_col)

	dialogue_label.text = text


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


func _finish_scene() -> void:
	var eye_trans: Node = get_node_or_null("/root/EyeTransition")
	if eye_trans == null and ResourceLoader.exists("res://EyeTransition.gd"):
		eye_trans = load("res://EyeTransition.gd").new()
		get_tree().root.add_child(eye_trans)

	if eye_trans != null and ResourceLoader.exists(next_scene_path):
		eye_trans.ir_a_escena_cerrando_ojos(next_scene_path)
	elif ResourceLoader.exists(next_scene_path):
		get_tree().change_scene_to_file(next_scene_path)
