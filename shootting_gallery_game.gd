extends Node2D

const BASE_SIZE := Vector2(3840.0, 2160.0)
const SOUNDS_DIR := "res://assets/sounds/"
const FAIR_AMBIENCE_NODE_NAME := "FairAmbiencePlayer"
const SHOOTING_BGM_NODE_NAME := "ShootingBoothBgmPlayer"
const SHOOTING_BGM_PATH := "res://assets/sounds/backgroundShooting.mp3"
const GUN_EXPLOSION_PATH := "res://assets/sounds/gun'sExplosion.mp3"
const MONKEY_SCREAM_PATH := "res://assets/sounds/monkeyScream.mp3"
const HUNTER_SCREAM_PATH := "res://assets/sounds/scream.mp3"

# Volúmenes durante el nivel (fair'sAudio sigue sonando de fondo y al salir vuelve al 100%)
const FAIR_AMBIENCE_IN_LEVEL_LINEAR := 0.45
const SHOOTING_BGM_IN_LEVEL_LINEAR := 0.45

# Bucle de fair'sAudio: minuto 6:30 (390 s) al minuto 14:00 (840 s)
const FAIR_AUDIO_LOOP_START := 390.0
const FAIR_AUDIO_LOOP_END := 840.0

# --- PALETA INTEGRADA AL ARTE ILUSTRADO DEL JUEGO ---
const TEXT_COLOR := Color("#fff9f0")
const PANEL_COLOR := Color(0.16, 0.17, 0.19, 0.88)
const SPEAKER_BG_COLOR := Color(0.14, 0.15, 0.17, 0.94)
const JAMMY_COLOR := Color("#f5d08a")
const XCARLET_COLOR := Color("#5bc0eb")
const LOUIS_COLOR := Color("#ff6b6f")

# Tarjeta de instrucciones tipo pergamino con trazo de tinta
const CARD_BG_COLOR := Color("#fbf5e8")
const CARD_INK_COLOR := Color("#261d17")
const CARD_MUTED_COLOR := Color("#5e5146")
const KEYCAP_BG_COLOR := Color("#fffdf9")
const KEYCAP_ACCENT_BG := Color("#f5d08a")
const DIVIDER_COLOR := Color(0.15, 0.11, 0.09, 0.18)
const HUNTER_BADGE_COLOR := Color("#227a42")
const MONKEY_BADGE_COLOR := Color("#b82929")

# Configuración de las 3 rondas alternadas
const TOTAL_ROUNDS := 3
const TURN_DURATION := 30.0 # 30 segundos por turno
const SHOT_COOLDOWN := 0.36
const MONKEY_JAM_COOLDOWN := 0.65
const KEYBOARD_AIM_SPEED := 1850.0
const GUN_HEIGHT := 2380.0

# Marco interior exacto del fondo verde (delimitado por los bordes amarillos izquierdo, derecho e inferior)
const GALLERY_WINDOW_RECT := Rect2(122.0, 225.0, 3638.0, 885.0)
const COUNTER_LINE_Y_LEFT := 1076.0
const COUNTER_LINE_Y_RIGHT := 1095.0

const FREDOKA_FONT = preload("res://fonts/Fredoka-Regular.ttf")
const NORMAL_DIALOGUE_STREAM = preload("res://assets/sounds/Soft_pencil_tap_on_n_#1-1794378651940.mp3")

@export_file("*.tscn") var fair_scene_path: String = "res://FairScenes.tscn"
@export var sight_fine_offset: Vector2 = Vector2.ZERO

enum GameState {
	INTRO_DIALOGUE,
	INSTRUCTION_SCREEN,
	TURN_BANNER,
	PLAYING,
	GAME_OVER
}

var state: GameState = GameState.INTRO_DIALOGUE

var tex_bg: Texture2D
var tex_hunter: Texture2D
var tex_monkey: Texture2D
var tex_machine_gun: Texture2D

var font_regular: FontVariation
var font_bold: FontVariation

var ui_root: Control
var background: TextureRect
var gallery_window: Control
var targets_layer: Control
var counter_foreground: TextureRect
var arm_sprite: TextureRect
var effects_layer: Control

# Marcadores y HUD superior
var jammy_score_panel: Panel
var jammy_score_label: Label
var xcarlet_score_panel: Panel
var xcarlet_score_label: Label
var round_panel: Panel
var round_label: Label
var timer_label: Label

# Cuadro de diálogo de Louis y barra minimalista inferior persistente
var dialogue_panel: Panel
var dialogue_label: Label
var speaker_panel: Panel
var speaker_label: Label
var continue_panel: PanelContainer
var continue_label: Label

var instruction_box_panel: PanelContainer

var center_banner_panel: Panel
var center_banner_title: Label
var center_banner_sub: Label

var muzzle_flash: ColorRect

var fair_ambience_player: AudioStreamPlayer
var shooting_bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var gun_sfx_player: AudioStreamPlayer
var hit_sfx_player: AudioStreamPlayer

var stream_gun_explosion: AudioStream
var stream_monkey_scream: AudioStream
var stream_hunter_scream: AudioStream
var gun_sfx_token := 0

# Variables de partida y apuntado con la mirilla de la escopeta
var jammy_score := 0
var xcarlet_score := 0
var current_round := 1
var is_jammy_turn := true
var turn_time_left := TURN_DURATION
var banner_timer := 0.0
var shot_timer := 0.0
var state_input_lock := 0.15
var shake_amount := 0.0
var arm_recoil_offset := 0.0
var wave_clock := 0.0

var aim_pos := Vector2(1920.0, 680.0)
var gun_sight_uv := Vector2(0.5, 0.012)

# Variables de IA para el turno de Xcarlet
var ai_target_ref: Dictionary = {}
var ai_aim_offset := Vector2.ZERO
var ai_think_timer := 0.0
var ai_fire_delay := 0.0

# Lista de objetivos activos en el riel inferior
var targets: Array[Dictionary] = []

var intro_full_text := "The game is basically earning points by shooting the hunters. Watch out for the monkeys! Luck!!"
var intro_typing := false
var intro_token := 0
var ending_triggered := false


func _ready() -> void:
	name = "shootingGalleryGame"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fonts()
	_load_assets()
	_detect_gun_sight_uv()
	_build_audio()
	_build_ui()
	_spawn_gallery_targets()
	_start_intro_dialogue()


func _build_fonts() -> void:
	font_regular = FontVariation.new()
	font_regular.base_font = FREDOKA_FONT
	font_regular.spacing_glyph = 1

	font_bold = FontVariation.new()
	font_bold.base_font = FREDOKA_FONT
	font_bold.variation_embolden = 0.28
	font_bold.spacing_glyph = 2


func _get_round_difficulty() -> Dictionary:
	match current_round:
		1:
			return {
				"start_speed_mult": 1.5,
				"end_speed_mult": 3.9,
				"hunter_chance": 0.42,
				"feint_min": 2.4,
				"feint_max": 4.6,
				"respawn_delay": 0.82,
				"ai_accuracy": 0.86,
				"ai_speed": 2900.0
			}
		2:
			return {
				"start_speed_mult": 2.05,
				"end_speed_mult": 4.95,
				"hunter_chance": 0.34,
				"feint_min": 1.6,
				"feint_max": 3.2,
				"respawn_delay": 0.62,
				"ai_accuracy": 0.92,
				"ai_speed": 3500.0
			}
		_:
			return {
				"start_speed_mult": 2.65,
				"end_speed_mult": 6.15,
				"hunter_chance": 0.25,
				"feint_min": 1.0,
				"feint_max": 2.2,
				"respawn_delay": 0.45,
				"ai_accuracy": 0.96,
				"ai_speed": 4100.0
			}


func _crop_transparent_padding(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return tex

	var w := img.get_width()
	var h := img.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1

	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.2:
				if x < min_x:
					min_x = x
				if x > max_x:
					max_x = x
				if y < min_y:
					min_y = y
				if y > max_y:
					max_y = y

	if max_x < min_x or max_y < min_y:
		return tex

	var rect := Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	var cropped := img.get_region(rect)
	return ImageTexture.create_from_image(cropped)


func _detect_gun_sight_uv() -> void:
	if tex_machine_gun == null:
		gun_sight_uv = Vector2(0.5, 0.012)
		return

	var img := tex_machine_gun.get_image()
	if img == null or img.is_empty():
		gun_sight_uv = Vector2(0.5, 0.012)
		return

	var w := img.get_width()
	var h := img.get_height()
	var scan_rows := maxi(1, int(round(float(h) * 0.025)))
	var sum_x := 0.0
	var count := 0

	for y in range(scan_rows):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.25:
				sum_x += float(x)
				count += 1

	var u := 0.5
	if count > 0:
		u = (sum_x / float(count)) / float(maxi(1, w - 1))

	gun_sight_uv = Vector2(clampf(u, 0.1, 0.9), 0.012)


func _load_texture_safe(full_path: String) -> Texture2D:
	if ResourceLoader.exists(full_path):
		var res := load(full_path)
		if res is Texture2D:
			return res

	var abs_path := ProjectSettings.globalize_path(full_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)

	return null


func _find_texture_recursive(dir_path: String, target_keys: Array[String], partial_match: bool = false) -> Texture2D:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return null

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var subdirs: Array[String] = []

	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			subdirs.append(full_path)
		elif not file_name.ends_with(".import"):
			var ext := file_name.get_extension().to_lower()
			if ext in ["png", "jpg", "jpeg", "webp"]:
				var base := file_name.get_basename().strip_edges().to_lower()
				var matched := false
				if partial_match:
					for k in target_keys:
						if k in base:
							matched = true
							break
				else:
					matched = base in target_keys

				if matched:
					var tex := _load_texture_safe(full_path)
					if tex != null:
						dir.list_dir_end()
						return tex
		file_name = dir.get_next()

	dir.list_dir_end()

	for sub in subdirs:
		var found := _find_texture_recursive(sub, target_keys, partial_match)
		if found != null:
			return found

	return null


func _load_first_existing(names: Array[String], allow_partial: bool = false) -> Texture2D:
	var folders := [
		"res://assets/",
		"res://scenes/",
		"res://",
		"res://assets/backgrounds/",
		"res://assets/sprites/",
		"res://assets/characters/"
	]
	var exts := [".png", ".jpg", ".jpeg", ".webp"]
	for base_name in names:
		for folder in folders:
			for ext in exts:
				var path: String = folder + base_name + ext
				var tex := _load_texture_safe(path)
				if tex != null:
					return tex

	var lower_keys: Array[String] = []
	for n in names:
		lower_keys.append(n.to_lower())

	var exact := _find_texture_recursive("res://", lower_keys, false)
	if exact != null:
		return exact

	if allow_partial:
		return _find_texture_recursive("res://", lower_keys, true)

	return null


func _load_assets() -> void:
	tex_bg = _load_first_existing(["shoottingGalleryGame", "shottingGalleryGame", "shootingGalleryGame"])
	tex_hunter = _crop_transparent_padding(_load_first_existing(["Hunter", "hunter"], true))
	tex_monkey = _crop_transparent_padding(_load_first_existing(["monkey", "Monkey", "mono"], true))
	tex_machine_gun = _crop_transparent_padding(_load_first_existing(["machineGun", "MachineGun", "machinegun"], true))


func _load_audio_safe(primary_path: String) -> AudioStream:
	var candidates := [
		primary_path,
		primary_path.replace("/sounds/", "/Sounds/")
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			var res := load(p)
			if res is AudioStream:
				return res
	return null


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

	return null


func _enable_stream_loop(stream: AudioStream) -> void:
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true


func _get_or_create_root_player(node_name: String) -> AudioStreamPlayer:
	var root := get_tree().root
	var existing := root.get_node_or_null(node_name)
	if existing is AudioStreamPlayer:
		existing.bus = &"Master"
		existing.process_mode = Node.PROCESS_MODE_ALWAYS
		return existing

	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = &"Master"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child.call_deferred(player)
	return player


func _setup_persistent_fair_audio() -> void:
	# 1. Audio general de la feria (fair'sAudio): continúa exactamente donde iba, nunca se reinicia
	fair_ambience_player = _get_or_create_root_player(FAIR_AMBIENCE_NODE_NAME)
	fair_ambience_player.volume_db = linear_to_db(FAIR_AMBIENCE_IN_LEVEL_LINEAR)

	if fair_ambience_player.stream != null:
		_enable_stream_loop(fair_ambience_player.stream)
		if not fair_ambience_player.playing:
			fair_ambience_player.play(FAIR_AUDIO_LOOP_START)
	else:
		var fair_stream := _load_fair_audio_stream()
		if fair_stream != null:
			_enable_stream_loop(fair_stream)
			fair_ambience_player.stream = fair_stream
			if fair_ambience_player.is_inside_tree():
				fair_ambience_player.play(FAIR_AUDIO_LOOP_START)
			else:
				fair_ambience_player.tree_entered.connect(func() -> void:
					if is_instance_valid(fair_ambience_player) and fair_ambience_player.stream != null and not fair_ambience_player.playing:
						fair_ambience_player.play(FAIR_AUDIO_LOOP_START)
				, CONNECT_ONE_SHOT)

	# 2. Música de la galería de tiro (backgroundShooting.mp3): continúa desde fairScenes sin reiniciarse
	shooting_bgm_player = _get_or_create_root_player(SHOOTING_BGM_NODE_NAME)
	shooting_bgm_player.volume_db = linear_to_db(SHOOTING_BGM_IN_LEVEL_LINEAR)

	if shooting_bgm_player.stream != null:
		_enable_stream_loop(shooting_bgm_player.stream)
		if not shooting_bgm_player.playing:
			shooting_bgm_player.play()
	else:
		var shoot_stream := _load_audio_safe(SHOOTING_BGM_PATH)
		if shoot_stream != null:
			_enable_stream_loop(shoot_stream)
			shooting_bgm_player.stream = shoot_stream
			if shooting_bgm_player.is_inside_tree():
				shooting_bgm_player.play()
			else:
				shooting_bgm_player.tree_entered.connect(func() -> void:
					if is_instance_valid(shooting_bgm_player) and shooting_bgm_player.stream != null and not shooting_bgm_player.playing:
						shooting_bgm_player.play()
				, CONNECT_ONE_SHOT)


func _build_audio() -> void:
	_setup_persistent_fair_audio()

	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = &"Master"
	add_child(sfx_player)

	gun_sfx_player = AudioStreamPlayer.new()
	gun_sfx_player.bus = &"Master"
	add_child(gun_sfx_player)

	hit_sfx_player = AudioStreamPlayer.new()
	hit_sfx_player.bus = &"Master"
	add_child(hit_sfx_player)

	stream_gun_explosion = _load_audio_safe(GUN_EXPLOSION_PATH)
	stream_monkey_scream = _load_audio_safe(MONKEY_SCREAM_PATH)
	stream_hunter_scream = _load_audio_safe(HUNTER_SCREAM_PATH)


func _play_gun_explosion() -> void:
	if gun_sfx_player == null or stream_gun_explosion == null:
		return

	gun_sfx_token += 1
	var token := gun_sfx_token

	gun_sfx_player.stop()
	gun_sfx_player.stream = stream_gun_explosion
	gun_sfx_player.play(0.0)
	_stop_gun_explosion_after_half_second(token)


func _stop_gun_explosion_after_half_second(token: int) -> void:
	await get_tree().create_timer(0.5).timeout
	if token == gun_sfx_token and is_instance_valid(gun_sfx_player):
		gun_sfx_player.stop()


func _build_counter_foreground() -> void:
	if tex_bg == null:
		return
	var src := tex_bg.get_image()
	if src == null or src.is_empty():
		return

	var iw := src.get_width()
	var ih := src.get_height()
	var strip_top_4k := 1070.0
	var strip_bottom_4k := 1210.0

	var px_left := clampi(int(round((GALLERY_WINDOW_RECT.position.x / BASE_SIZE.x) * float(iw))), 0, iw - 1)
	var px_right := clampi(int(round((GALLERY_WINDOW_RECT.end.x / BASE_SIZE.x) * float(iw))), px_left + 1, iw)
	var py_top := clampi(int(round((strip_top_4k / BASE_SIZE.y) * float(ih))), 0, ih - 1)
	var py_bottom := clampi(int(round((strip_bottom_4k / BASE_SIZE.y) * float(ih))), py_top + 1, ih)

	var strip_w := px_right - px_left
	var strip_h := py_bottom - py_top
	var out_img := Image.create(strip_w, strip_h, false, Image.FORMAT_RGBA8)

	for sy in range(strip_h):
		var py := py_top + sy
		var y_4k := (float(py) / float(ih)) * BASE_SIZE.y
		for sx in range(strip_w):
			var px := px_left + sx
			var t_x := clampf(float(sx) / float(maxi(1, strip_w - 1)), 0.0, 1.0)
			var line_y_4k := lerpf(COUNTER_LINE_Y_LEFT, COUNTER_LINE_Y_RIGHT, t_x)
			if y_4k < line_y_4k:
				out_img.set_pixel(sx, sy, Color(0.0, 0.0, 0.0, 0.0))
			else:
				out_img.set_pixel(sx, sy, src.get_pixel(px, py))

	counter_foreground = TextureRect.new()
	counter_foreground.position = Vector2(GALLERY_WINDOW_RECT.position.x, strip_top_4k)
	counter_foreground.size = Vector2(GALLERY_WINDOW_RECT.size.x, strip_bottom_4k - strip_top_4k)
	counter_foreground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	counter_foreground.stretch_mode = TextureRect.STRETCH_SCALE
	counter_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter_foreground.texture = ImageTexture.create_from_image(out_img)
	ui_root.add_child(counter_foreground)


func _make_keycap(text_val: String, font_size: int = 32, bg_col: Color = KEYCAP_BG_COLOR) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var st := StyleBoxFlat.new()
	st.bg_color = bg_col
	st.set_corner_radius_all(12)
	st.border_width_left = 3
	st.border_width_top = 3
	st.border_width_right = 3
	st.border_width_bottom = 7
	st.border_color = CARD_INK_COLOR
	st.content_margin_left = 18.0
	st.content_margin_right = 18.0
	st.content_margin_top = 6.0
	st.content_margin_bottom = 8.0
	cap.add_theme_stylebox_override("panel", st)

	var lbl := Label.new()
	lbl.text = text_val
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", font_bold)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", CARD_INK_COLOR)
	cap.add_child(lbl)

	return cap


func _make_score_pill(text_val: String, fill_col: Color, font_size: int = 34) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var st := StyleBoxFlat.new()
	st.bg_color = fill_col
	st.set_corner_radius_all(12)
	st.border_width_left = 3
	st.border_width_top = 3
	st.border_width_right = 3
	st.border_width_bottom = 5
	st.border_color = CARD_INK_COLOR
	st.content_margin_left = 16.0
	st.content_margin_right = 16.0
	st.content_margin_top = 4.0
	st.content_margin_bottom = 6.0
	pill.add_theme_stylebox_override("panel", st)

	var lbl := Label.new()
	lbl.text = text_val
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", font_bold)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", TEXT_COLOR)
	pill.add_child(lbl)

	return pill


func _make_ui_label(text_val: String, font_res: Font, font_size: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text_val
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", font_res)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	return lbl


func _update_arm_transform() -> void:
	if arm_sprite == null or not arm_sprite.visible:
		return

	var sight_local := Vector2(
		arm_sprite.size.x * gun_sight_uv.x,
		arm_sprite.size.y * gun_sight_uv.y
	)
	arm_sprite.pivot_offset = sight_local
	arm_sprite.scale = Vector2.ONE

	var target_tip: Vector2 = aim_pos + sight_fine_offset + Vector2(0.0, arm_recoil_offset)
	arm_sprite.position = target_tip - sight_local
	arm_sprite.rotation = clampf((aim_pos.x - BASE_SIZE.x * 0.5) / 5600.0, -0.14, 0.14)


func _build_ui() -> void:
	ui_root = Control.new()
	ui_root.position = Vector2.ZERO
	ui_root.size = BASE_SIZE
	ui_root.clip_contents = true
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	background = TextureRect.new()
	background.position = Vector2.ZERO
	background.size = BASE_SIZE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.texture = tex_bg
	ui_root.add_child(background)

	# Ventana recortada dentro del marco verde
	gallery_window = Control.new()
	gallery_window.position = GALLERY_WINDOW_RECT.position
	gallery_window.size = GALLERY_WINDOW_RECT.size
	gallery_window.clip_contents = true
	gallery_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(gallery_window)

	targets_layer = Control.new()
	targets_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	targets_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gallery_window.add_child(targets_layer)

	# Borde superior del mostrador amarillo delante de los palos para que nunca se monten encima
	_build_counter_foreground()

	# Brazos con escopeta: proporción original intacta y base oculta debajo del borde inferior
	var gun_size := _calc_proportional_size(tex_machine_gun, GUN_HEIGHT)
	arm_sprite = TextureRect.new()
	arm_sprite.size = gun_size
	arm_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arm_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arm_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arm_sprite.z_index = 22
	arm_sprite.visible = false
	if tex_machine_gun != null:
		arm_sprite.texture = tex_machine_gun
	ui_root.add_child(arm_sprite)

	effects_layer = Control.new()
	effects_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effects_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.z_index = 24
	ui_root.add_child(effects_layer)

	# --- MARCADOR DE JAMMY (ESQUINA SUPERIOR IZQUIERDA) ---
	jammy_score_panel = Panel.new()
	jammy_score_panel.position = Vector2(72.0, 44.0)
	jammy_score_panel.size = Vector2(620.0, 145.0)
	jammy_score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jammy_score_panel.add_theme_stylebox_override("panel", _make_box_style(PANEL_COLOR, JAMMY_COLOR))
	ui_root.add_child(jammy_score_panel)

	jammy_score_label = Label.new()
	jammy_score_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	jammy_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jammy_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	jammy_score_label.add_theme_font_size_override("font_size", 52)
	jammy_score_label.add_theme_font_override("font", font_bold)
	jammy_score_label.add_theme_color_override("font_color", JAMMY_COLOR)
	jammy_score_panel.add_child(jammy_score_label)

	# --- MARCADOR DE XCARLET (ESQUINA SUPERIOR DERECHA) ---
	xcarlet_score_panel = Panel.new()
	xcarlet_score_panel.position = Vector2(BASE_SIZE.x - 692.0, 44.0)
	xcarlet_score_panel.size = Vector2(620.0, 145.0)
	xcarlet_score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xcarlet_score_panel.add_theme_stylebox_override("panel", _make_box_style(PANEL_COLOR, XCARLET_COLOR))
	ui_root.add_child(xcarlet_score_panel)

	xcarlet_score_label = Label.new()
	xcarlet_score_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xcarlet_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xcarlet_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xcarlet_score_label.add_theme_font_size_override("font_size", 52)
	xcarlet_score_label.add_theme_font_override("font", font_bold)
	xcarlet_score_label.add_theme_color_override("font_color", XCARLET_COLOR)
	xcarlet_score_panel.add_child(xcarlet_score_label)

	# --- INDICADOR DE RONDA Y TIEMPO (ARRIBA AL CENTRO) ---
	round_panel = Panel.new()
	round_panel.position = Vector2((BASE_SIZE.x - 1040.0) * 0.5, 44.0)
	round_panel.size = Vector2(1040.0, 160.0)
	round_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_panel.add_theme_stylebox_override("panel", _make_box_style(PANEL_COLOR, LOUIS_COLOR))
	ui_root.add_child(round_panel)

	round_label = Label.new()
	round_label.position = Vector2(20.0, 12.0)
	round_label.size = Vector2(1000.0, 68.0)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 46)
	round_label.add_theme_font_override("font", font_bold)
	round_label.add_theme_color_override("font_color", TEXT_COLOR)
	round_panel.add_child(round_label)

	timer_label = Label.new()
	timer_label.position = Vector2(20.0, 80.0)
	timer_label.size = Vector2(1000.0, 66.0)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 44)
	timer_label.add_theme_font_override("font", font_regular)
	timer_label.add_theme_color_override("font_color", LOUIS_COLOR)
	round_panel.add_child(timer_label)

	# --- CUADRO DE DIÁLOGO DE LOUIS LIBERTÉ (ABAJO AL CENTRO) ---
	var dial_pos := Vector2(1280.0, 1825.0)
	var dial_size := Vector2(1280.0, 250.0)
	var louis_border := Color(LOUIS_COLOR.r, LOUIS_COLOR.g, LOUIS_COLOR.b, 0.78)

	dialogue_panel = Panel.new()
	dialogue_panel.position = dial_pos
	dialogue_panel.size = dial_size
	dialogue_panel.z_index = 26
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.add_theme_stylebox_override("panel", _make_box_style(PANEL_COLOR, louis_border, 3))
	ui_root.add_child(dialogue_panel)

	speaker_panel = Panel.new()
	speaker_panel.position = Vector2(dial_pos.x + 36.0, dial_pos.y - 60.0)
	speaker_panel.size = Vector2(320.0, 62.0)
	speaker_panel.z_index = 27
	speaker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, LOUIS_COLOR))
	ui_root.add_child(speaker_panel)

	speaker_label = Label.new()
	speaker_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.text = "Louis Liberté"
	speaker_label.add_theme_font_size_override("font_size", 36)
	speaker_label.add_theme_font_override("font", font_bold)
	speaker_label.add_theme_color_override("font_color", LOUIS_COLOR)
	speaker_label.add_theme_color_override("font_shadow_color", Color("#000000e6"))
	speaker_label.add_theme_constant_override("shadow_offset_x", 2)
	speaker_label.add_theme_constant_override("shadow_offset_y", 2)
	speaker_panel.add_child(speaker_label)

	dialogue_label = Label.new()
	dialogue_label.position = Vector2(52.0, 24.0)
	dialogue_label.size = Vector2(dial_size.x - 104.0, dial_size.y - 48.0)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.add_theme_font_size_override("font_size", 44)
	dialogue_label.add_theme_font_override("font", font_regular)
	dialogue_label.add_theme_color_override("font_color", TEXT_COLOR)
	dialogue_label.add_theme_color_override("font_shadow_color", Color("#000000f0"))
	dialogue_label.add_theme_constant_override("shadow_offset_x", 3)
	dialogue_label.add_theme_constant_override("shadow_offset_y", 3)
	dialogue_panel.add_child(dialogue_label)

	# --- BARRA MINIMALISTA INFERIOR DE CONTROLES (PERSISTENTE DURANTE EL JUEGO) ---
	continue_panel = PanelContainer.new()
	continue_panel.anchor_left = 0.5
	continue_panel.anchor_right = 0.5
	continue_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	continue_panel.position = Vector2(0.0, 2080.0)
	continue_panel.z_index = 28
	continue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	continue_panel.add_theme_stylebox_override("panel", _make_hint_pill_style())
	ui_root.add_child(continue_panel)

	continue_label = Label.new()
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	continue_label.add_theme_font_size_override("font_size", 32)
	continue_label.add_theme_font_override("font", font_bold)
	continue_label.add_theme_color_override("font_color", TEXT_COLOR)
	continue_label.add_theme_constant_override("outline_size", 5)
	continue_label.add_theme_color_override("font_outline_color", Color("#08080a"))
	continue_label.text = "ENTER TO CONTINUE"
	continue_panel.add_child(continue_label)

	# --- TARJETA DE INSTRUCCIONES CON TECLAS TÁCTILES E INSIGNIAS ---
	instruction_box_panel = PanelContainer.new()
	instruction_box_panel.position = Vector2((BASE_SIZE.x - 1780.0) * 0.5, (BASE_SIZE.y - 360.0) * 0.5)
	instruction_box_panel.size = Vector2(1780.0, 360.0)
	instruction_box_panel.z_index = 26
	instruction_box_panel.visible = false
	instruction_box_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction_box_panel.add_theme_stylebox_override("panel", _make_parchment_card_style(24, 5, 18))
	ui_root.add_child(instruction_box_panel)

	var card_vbox := VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 24)
	instruction_box_panel.add_child(card_vbox)

	# Fila 1: Controles con keycaps
	var controls_row := HBoxContainer.new()
	controls_row.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_row.add_theme_constant_override("separation", 16)
	card_vbox.add_child(controls_row)

	controls_row.add_child(_make_ui_label("AIM", font_bold, 38, CARD_MUTED_COLOR))
	controls_row.add_child(_make_keycap("MOUSE", 32))
	controls_row.add_child(_make_ui_label("/", font_regular, 34, CARD_MUTED_COLOR))
	controls_row.add_child(_make_keycap("WASD", 32))

	var v_sep := ColorRect.new()
	v_sep.custom_minimum_size = Vector2(3.0, 48.0)
	v_sep.color = DIVIDER_COLOR
	var sep_spacer_l := Control.new()
	sep_spacer_l.custom_minimum_size = Vector2(18.0, 0.0)
	var sep_spacer_r := Control.new()
	sep_spacer_r.custom_minimum_size = Vector2(18.0, 0.0)
	controls_row.add_child(sep_spacer_l)
	controls_row.add_child(v_sep)
	controls_row.add_child(sep_spacer_r)

	controls_row.add_child(_make_ui_label("SHOOT", font_bold, 38, CARD_MUTED_COLOR))
	controls_row.add_child(_make_keycap("CLICK", 32))
	controls_row.add_child(_make_ui_label("/", font_regular, 34, CARD_MUTED_COLOR))
	controls_row.add_child(_make_keycap("ENTER", 32))
	controls_row.add_child(_make_ui_label("/", font_regular, 34, CARD_MUTED_COLOR))
	controls_row.add_child(_make_keycap("SPACE", 32))

	# Separador horizontal
	var h_sep := ColorRect.new()
	h_sep.custom_minimum_size = Vector2(1500.0, 3.0)
	h_sep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	h_sep.color = DIVIDER_COLOR
	card_vbox.add_child(h_sep)

	# Fila 2: Reglas de puntuación con insignias
	var rules_row := HBoxContainer.new()
	rules_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rules_row.add_theme_constant_override("separation", 16)
	card_vbox.add_child(rules_row)

	rules_row.add_child(_make_ui_label("Hit", font_regular, 42, CARD_INK_COLOR))
	rules_row.add_child(_make_ui_label("HUNTERS", font_bold, 42, HUNTER_BADGE_COLOR))
	rules_row.add_child(_make_score_pill("+1", HUNTER_BADGE_COLOR, 34))

	var dot_lbl := _make_ui_label("   •   ", font_bold, 38, CARD_MUTED_COLOR)
	rules_row.add_child(dot_lbl)

	rules_row.add_child(_make_ui_label("Avoid", font_regular, 42, CARD_INK_COLOR))
	rules_row.add_child(_make_ui_label("MONKEYS", font_bold, 42, MONKEY_BADGE_COLOR))
	rules_row.add_child(_make_score_pill("-2", MONKEY_BADGE_COLOR, 34))

	# Fila 3: Confirmación con tecla ENTER destacada
	var start_row := HBoxContainer.new()
	start_row.alignment = BoxContainer.ALIGNMENT_CENTER
	start_row.add_theme_constant_override("separation", 14)
	card_vbox.add_child(start_row)

	start_row.add_child(_make_ui_label("Press", font_regular, 38, CARD_MUTED_COLOR))
	start_row.add_child(_make_keycap("ENTER", 30, KEYCAP_ACCENT_BG))
	start_row.add_child(_make_ui_label("to begin", font_regular, 38, CARD_MUTED_COLOR))

	# --- CARTEL CENTRAL DE CAMBIO DE TURNO / RESULTADO FINAL ---
	center_banner_panel = Panel.new()
	center_banner_panel.position = Vector2((BASE_SIZE.x - 1660.0) * 0.5, (BASE_SIZE.y - 360.0) * 0.5)
	center_banner_panel.size = Vector2(1660.0, 360.0)
	center_banner_panel.z_index = 26
	center_banner_panel.visible = false
	center_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_banner_panel.add_theme_stylebox_override("panel", _make_box_style(PANEL_COLOR, LOUIS_COLOR))
	ui_root.add_child(center_banner_panel)

	center_banner_title = Label.new()
	center_banner_title.position = Vector2(40.0, 0.0)
	center_banner_title.size = Vector2(1580.0, 360.0)
	center_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_banner_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_banner_title.add_theme_font_size_override("font_size", 70)
	center_banner_title.add_theme_font_override("font", font_bold)
	center_banner_title.add_theme_color_override("font_color", TEXT_COLOR)
	center_banner_panel.add_child(center_banner_title)

	center_banner_sub = Label.new()
	center_banner_sub.position = Vector2(40.0, 190.0)
	center_banner_sub.size = Vector2(1580.0, 120.0)
	center_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_banner_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_banner_sub.visible = false
	center_banner_sub.add_theme_font_size_override("font_size", 46)
	center_banner_sub.add_theme_font_override("font", font_regular)
	center_banner_sub.add_theme_color_override("font_color", LOUIS_COLOR)
	center_banner_panel.add_child(center_banner_sub)

	# --- DESTELLO DE DISPARO ---
	muzzle_flash = ColorRect.new()
	muzzle_flash.size = BASE_SIZE
	muzzle_flash.color = Color(1.0, 0.95, 0.75, 0.0)
	muzzle_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	muzzle_flash.z_index = 30
	ui_root.add_child(muzzle_flash)

	_update_hud()


func _calc_proportional_size(tex: Texture2D, target_height: float) -> Vector2:
	if tex == null or tex.get_height() <= 0:
		return Vector2(440.0, target_height)
	var ratio := float(tex.get_width()) / float(tex.get_height())
	return Vector2(target_height * ratio, target_height)


func _get_rail_y_at_local_x(local_x: float) -> float:
	var t_x := clampf(local_x / GALLERY_WINDOW_RECT.size.x, 0.0, 1.0)
	return lerpf(COUNTER_LINE_Y_LEFT, COUNTER_LINE_Y_RIGHT, t_x) - GALLERY_WINDOW_RECT.position.y


func _configure_target_role(t: Dictionary, is_hunter: bool) -> void:
	t["is_hunter"] = is_hunter
	var tex := tex_hunter if is_hunter else tex_monkey
	if tex == null:
		tex = tex_hunter if tex_hunter != null else tex_monkey

	# La punta de ambos palos entra 22 px detrás de la línea amarilla para no flotar ni montarse encima
	var target_height := 670.0 if is_hunter else 640.0
	var bottom_sink := 22.0
	var item_size := _calc_proportional_size(tex, target_height)

	var sprite: TextureRect = t["root"]
	sprite.texture = tex
	sprite.size = item_size
	sprite.pivot_offset = Vector2(item_size.x * 0.5, item_size.y)
	t["target_height"] = target_height
	t["bottom_sink"] = bottom_sink


func _get_target_base_y(t: Dictionary) -> float:
	var sprite: Control = t["root"]
	var center_x := sprite.position.x + sprite.size.x * 0.5
	var rail_y := _get_rail_y_at_local_x(center_x)
	return rail_y - float(t["target_height"]) + float(t["bottom_sink"])


func _spawn_gallery_targets() -> void:
	var count := 7
	var speed := 760.0
	var dir := 1.0
	var slot_width := (GALLERY_WINDOW_RECT.size.x + 680.0) / float(count)
	var diff := _get_round_difficulty()

	for i in range(count):
		var sprite := TextureRect.new()
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_SCALE
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		targets_layer.add_child(sprite)

		var t := {
			"root": sprite,
			"is_hunter": true,
			"speed": speed,
			"dir": dir,
			"target_height": 670.0,
			"bottom_sink": 22.0,
			"is_down": false,
			"respawn_timer": 0.0,
			"bob_phase": float(i) * 1.15,
			"feint_timer": randf_range(float(diff["feint_min"]), float(diff["feint_max"]))
		}

		var is_hunter := (i == 0) or (randf() < float(diff["hunter_chance"]))
		_configure_target_role(t, is_hunter)
		sprite.position.x = -460.0 + float(i) * slot_width
		sprite.position.y = _get_target_base_y(t)
		targets.append(t)


func _start_intro_dialogue() -> void:
	state = GameState.INTRO_DIALOGUE
	state_input_lock = 0.15
	dialogue_panel.visible = true
	speaker_panel.visible = true
	continue_label.text = "ENTER TO CONTINUE"
	continue_panel.visible = true
	instruction_box_panel.visible = false
	center_banner_panel.visible = false
	arm_sprite.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	dialogue_label.text = ""
	intro_typing = true
	intro_token += 1
	_type_intro_words(intro_token)


func _type_intro_words(token: int) -> void:
	var words := intro_full_text.split(" ")
	for i in range(words.size()):
		if token != intro_token:
			return
		dialogue_label.text += ("" if i == 0 else " ") + words[i]
		if i % 2 == 0:
			sfx_player.stop()
			sfx_player.stream = NORMAL_DIALOGUE_STREAM
			sfx_player.play()
		await get_tree().create_timer(0.045).timeout
	if token == intro_token:
		intro_typing = false


func _show_instruction_screen() -> void:
	state = GameState.INSTRUCTION_SCREEN
	state_input_lock = 0.15
	dialogue_panel.visible = false
	speaker_panel.visible = false
	continue_label.text = "ENTER TO BEGIN"
	continue_panel.visible = true
	instruction_box_panel.visible = true


func _begin_turn_banner() -> void:
	state = GameState.TURN_BANNER
	state_input_lock = 0.15
	instruction_box_panel.visible = false
	dialogue_panel.visible = false
	speaker_panel.visible = false
	continue_label.text = "AIM: MOUSE / WASD   •   SHOOT: CLICK / ENTER / SPACE"
	continue_panel.visible = true
	arm_sprite.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var diff := _get_round_difficulty()
	var player_name := "JAMMY'S TURN" if is_jammy_turn else "XCARLET'S TURN"
	var accent := JAMMY_COLOR if is_jammy_turn else XCARLET_COLOR

	center_banner_panel.add_theme_stylebox_override("panel", _make_box_style(PANEL_COLOR, accent))
	center_banner_title.position = Vector2(40.0, 0.0)
	center_banner_title.size = Vector2(1580.0, 360.0)
	center_banner_title.text = "ROUND %d / %d — %s" % [current_round, TOTAL_ROUNDS, player_name]
	center_banner_title.add_theme_color_override("font_color", accent)
	center_banner_sub.visible = false
	center_banner_panel.visible = true

	# Levanta todos los objetivos al iniciar cada turno según la dificultad de la ronda
	var h_chance: float = float(diff["hunter_chance"])
	for i in range(targets.size()):
		var t := targets[i]
		t["is_down"] = false
		t["respawn_timer"] = 0.0
		t["feint_timer"] = randf_range(float(diff["feint_min"]), float(diff["feint_max"]))
		var start_hunter := (i == 0) or (randf() < h_chance)
		_configure_target_role(t, start_hunter)
		var sprite: Control = t["root"]
		sprite.position.y = _get_target_base_y(t)
		sprite.scale = Vector2.ONE

	banner_timer = 1.6
	_update_hud()


func _start_active_turn() -> void:
	state = GameState.PLAYING
	state_input_lock = 0.12
	center_banner_panel.visible = false
	continue_label.text = "AIM: MOUSE / WASD   •   SHOOT: CLICK / ENTER / SPACE"
	continue_panel.visible = true
	turn_time_left = TURN_DURATION
	shot_timer = 0.0
	ai_target_ref = {}
	ai_think_timer = 0.2
	ai_fire_delay = 0.25

	if is_jammy_turn:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		aim_pos = get_global_mouse_position().clamp(Vector2.ZERO, BASE_SIZE)
		if tex_machine_gun != null:
			arm_sprite.texture = tex_machine_gun
			arm_sprite.modulate = Color.WHITE
			arm_sprite.visible = true
			_update_arm_transform()
	else:
		arm_sprite.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		aim_pos = GALLERY_WINDOW_RECT.get_center()
		_pick_new_ai_target()


func _process(delta: float) -> void:
	if state_input_lock > 0.0:
		state_input_lock = maxf(0.0, state_input_lock - delta)

	# Mantiene el bucle de fair'sAudio (6:30 a 14:00) continuo sin reiniciarlo
	if is_instance_valid(fair_ambience_player) and fair_ambience_player.stream != null:
		if not fair_ambience_player.playing:
			fair_ambience_player.play(FAIR_AUDIO_LOOP_START)
		else:
			var fpos := fair_ambience_player.get_playback_position()
			if fpos >= FAIR_AUDIO_LOOP_END or fpos < FAIR_AUDIO_LOOP_START - 0.15:
				fair_ambience_player.seek(FAIR_AUDIO_LOOP_START)

	if is_instance_valid(shooting_bgm_player) and shooting_bgm_player.stream != null and not shooting_bgm_player.playing and not ending_triggered:
		shooting_bgm_player.play()

	if shake_amount > 0.0:
		shake_amount = maxf(0.0, shake_amount - delta * 45.0)
		ui_root.position = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
	else:
		ui_root.position = Vector2.ZERO

	if muzzle_flash.color.a > 0.0:
		muzzle_flash.color.a = maxf(0.0, muzzle_flash.color.a - delta * 3.5)

	if arm_recoil_offset > 0.0:
		arm_recoil_offset = maxf(0.0, arm_recoil_offset - delta * 480.0)

	if state == GameState.TURN_BANNER:
		banner_timer -= delta
		if banner_timer <= 0.0:
			_start_active_turn()
		return

	if state != GameState.PLAYING:
		return

	wave_clock += delta

	var diff := _get_round_difficulty()
	var elapsed_ratio := clampf(1.0 - (turn_time_left / TURN_DURATION), 0.0, 1.0)
	var speed_multiplier := lerpf(float(diff["start_speed_mult"]), float(diff["end_speed_mult"]), elapsed_ratio)

	_update_targets(delta, speed_multiplier, diff)

	if is_jammy_turn:
		var aim_dir := Vector2.ZERO
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			aim_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			aim_dir.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			aim_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			aim_dir.y += 1.0

		if aim_dir != Vector2.ZERO:
			aim_pos += aim_dir.normalized() * KEYBOARD_AIM_SPEED * delta
			aim_pos = aim_pos.clamp(Vector2.ZERO, BASE_SIZE)
	else:
		_update_xcarlet_ai(delta, speed_multiplier, diff)

	_update_arm_transform()

	if shot_timer > 0.0:
		shot_timer -= delta

	turn_time_left -= delta
	if turn_time_left <= 0.0:
		turn_time_left = 0.0
		_finish_current_turn()

	_update_hud()


func _pick_new_ai_target() -> void:
	var diff := _get_round_difficulty()
	var hunters: Array[Dictionary] = []
	var monkeys: Array[Dictionary] = []

	for t in targets:
		if not t["is_down"]:
			var sprite: Control = t["root"]
			var center_x := GALLERY_WINDOW_RECT.position.x + sprite.position.x + sprite.size.x * 0.5
			if center_x > GALLERY_WINDOW_RECT.position.x + 220.0 and center_x < GALLERY_WINDOW_RECT.end.x - 220.0:
				if t["is_hunter"]:
					hunters.append(t)
				else:
					monkeys.append(t)

	var shoot_hunter := randf() < float(diff["ai_accuracy"])
	if shoot_hunter and not hunters.is_empty():
		ai_target_ref = hunters[randi() % hunters.size()]
	elif not monkeys.is_empty():
		ai_target_ref = monkeys[randi() % monkeys.size()]
	elif not hunters.is_empty():
		ai_target_ref = hunters[randi() % hunters.size()]
	else:
		ai_target_ref = {}

	ai_aim_offset = Vector2(randf_range(-34.0, 34.0), randf_range(-34.0, 34.0))
	ai_fire_delay = randf_range(0.10, 0.26)


func _update_xcarlet_ai(delta: float, speed_multiplier: float, diff: Dictionary) -> void:
	ai_think_timer -= delta * speed_multiplier
	if ai_target_ref.is_empty() or ai_target_ref.get("is_down", true) or ai_think_timer <= 0.0:
		_pick_new_ai_target()
		ai_think_timer = randf_range(0.45, 0.95)

	if ai_target_ref.is_empty():
		return

	var sprite: Control = ai_target_ref["root"]
	var target_center := GALLERY_WINDOW_RECT.position + sprite.position + Vector2(sprite.size.x * 0.5, sprite.size.y * 0.35) + ai_aim_offset
	var ai_move_speed := float(diff["ai_speed"]) * lerpf(1.0, 1.55, clampf((speed_multiplier - 1.0) / 3.0, 0.0, 1.0))

	aim_pos = aim_pos.move_toward(target_center, ai_move_speed * delta)

	if aim_pos.distance_to(target_center) < 38.0:
		ai_fire_delay -= delta * speed_multiplier
		if ai_fire_delay <= 0.0 and shot_timer <= 0.0:
			_fire_shotgun()
			ai_target_ref = {}
			ai_think_timer = randf_range(0.15, 0.40)


func _update_targets(delta: float, speed_multiplier: float, diff: Dictionary) -> void:
	var h_chance := float(diff["hunter_chance"])
	var feint_min := float(diff["feint_min"])
	var feint_max := float(diff["feint_max"])

	for t in targets:
		var sprite: Control = t["root"]
		var speed: float = float(t["speed"]) * speed_multiplier
		var dir: float = t["dir"]
		var min_x := -sprite.size.x
		var max_x := GALLERY_WINDOW_RECT.size.x + 120.0

		sprite.position.x += speed * dir * delta
		if dir > 0.0 and sprite.position.x > max_x:
			sprite.position.x = min_x
			_configure_target_role(t, randf() < h_chance)
		elif dir < 0.0 and sprite.position.x < min_x:
			sprite.position.x = max_x
			_configure_target_role(t, randf() < h_chance)

		if t["is_down"]:
			t["respawn_timer"] -= delta * lerpf(1.0, 1.85, clampf((speed_multiplier - 1.0) / 3.0, 0.0, 1.0))
			if t["respawn_timer"] <= 0.0:
				t["is_down"] = false
				_configure_target_role(t, randf() < h_chance)
				var tw := create_tween()
				tw.set_parallel(true)
				tw.tween_property(sprite, "position:y", _get_target_base_y(t), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(sprite, "scale", Vector2.ONE, 0.11)
		else:
			var bob := (sin(wave_clock * (6.3 + float(current_round) * 1.2) + float(t["bob_phase"])) + 1.0) * 6.0
			sprite.position.y = _get_target_base_y(t) + bob

			t["feint_timer"] -= delta * speed_multiplier
			if t["feint_timer"] <= 0.0:
				t["feint_timer"] = randf_range(feint_min, feint_max)
				var center_x := sprite.position.x + sprite.size.x * 0.5
				if center_x > 250.0 and center_x < GALLERY_WINDOW_RECT.size.x - 250.0:
					t["is_down"] = true
					t["respawn_timer"] = maxf(0.28, float(diff["respawn_delay"]) * 0.65)
					var hide_tw := create_tween()
					hide_tw.tween_property(sprite, "position:y", GALLERY_WINDOW_RECT.size.y + 40.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _is_enter_pressed(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER] or event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			return true
	if event.is_action_pressed("ui_accept"):
		if event is InputEventKey and event.keycode == KEY_SPACE:
			return false
		return true
	return false


func _input(event: InputEvent) -> void:
	if ending_triggered:
		return

	if event is InputEventMouseMotion and state == GameState.PLAYING and is_jammy_turn:
		aim_pos = event.position.clamp(Vector2.ZERO, BASE_SIZE)

	if state_input_lock > 0.0:
		return

	var enter_pressed := _is_enter_pressed(event)

	match state:
		GameState.INTRO_DIALOGUE:
			if enter_pressed:
				get_viewport().set_input_as_handled()
				if intro_typing:
					intro_token += 1
					dialogue_label.text = intro_full_text
					intro_typing = false
					state_input_lock = 0.12
				else:
					_show_instruction_screen()

		GameState.INSTRUCTION_SCREEN:
			if enter_pressed:
				get_viewport().set_input_as_handled()
				_begin_turn_banner()

		GameState.PLAYING:
			var shoot_pressed: bool = false
			if event is InputEventMouseButton:
				shoot_pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
			elif event is InputEventKey and event.pressed and not event.echo:
				shoot_pressed = event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]

			if shoot_pressed and is_jammy_turn and shot_timer <= 0.0:
				get_viewport().set_input_as_handled()
				_fire_shotgun()

		GameState.GAME_OVER:
			if enter_pressed:
				get_viewport().set_input_as_handled()
				_go_to_next_scene()


func _fire_shotgun() -> void:
	shot_timer = SHOT_COOLDOWN
	shake_amount = 16.0
	if is_jammy_turn:
		arm_recoil_offset = 110.0
	muzzle_flash.color.a = 0.26

	_play_gun_explosion()

	if not GALLERY_WINDOW_RECT.has_point(aim_pos):
		return

	_spawn_shot_spark(aim_pos, JAMMY_COLOR if is_jammy_turn else XCARLET_COLOR)

	for i in range(targets.size() - 1, -1, -1):
		var t := targets[i]
		if t["is_down"]:
			continue

		var sprite: Control = t["root"]
		var body_rect := Rect2(
			GALLERY_WINDOW_RECT.position + sprite.position + Vector2(sprite.size.x * 0.12, sprite.size.y * 0.04),
			Vector2(sprite.size.x * 0.76, sprite.size.y * 0.72)
		).intersection(GALLERY_WINDOW_RECT)

		if body_rect.has_point(aim_pos):
			_hit_target(t, aim_pos)
			break


func _spawn_shot_spark(pos: Vector2, col: Color) -> void:
	var spark := Panel.new()
	spark.position = pos - Vector2(24.0, 24.0)
	spark.size = Vector2(48.0, 48.0)
	spark.pivot_offset = Vector2(24.0, 24.0)
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var st := StyleBoxFlat.new()
	st.bg_color = Color(1.0, 0.98, 0.88, 0.9)
	st.set_corner_radius_all(24)
	st.border_width_left = 4
	st.border_width_top = 4
	st.border_width_right = 4
	st.border_width_bottom = 4
	st.border_color = col
	spark.add_theme_stylebox_override("panel", st)
	effects_layer.add_child(spark)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(spark, "scale", Vector2(1.8, 1.8), 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(spark, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(spark.queue_free)


func _hit_target(t: Dictionary, hit_pos: Vector2) -> void:
	var diff := _get_round_difficulty()
	t["is_down"] = true
	t["respawn_timer"] = float(diff["respawn_delay"])

	var sprite: Control = t["root"]
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale", Vector2(1.0, 0.25), 0.10)
	tw.tween_property(sprite, "position:y", GALLERY_WINDOW_RECT.size.y + 40.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if t["is_hunter"]:
		if hit_sfx_player != null and stream_hunter_scream != null:
			hit_sfx_player.stop()
			hit_sfx_player.stream = stream_hunter_scream
			hit_sfx_player.play()
		if is_jammy_turn:
			jammy_score += 1
		else:
			xcarlet_score += 1
		_spawn_floating_text("+1!", hit_pos, JAMMY_COLOR if is_jammy_turn else XCARLET_COLOR)
	else:
		if hit_sfx_player != null and stream_monkey_scream != null:
			hit_sfx_player.stop()
			hit_sfx_player.stream = stream_monkey_scream
			hit_sfx_player.play()
		shot_timer = MONKEY_JAM_COOLDOWN
		if is_jammy_turn:
			jammy_score = maxi(0, jammy_score - 2)
		else:
			xcarlet_score = maxi(0, xcarlet_score - 2)
		_spawn_floating_text("MONKEY! -2", hit_pos, LOUIS_COLOR)

	_update_hud()


func _spawn_floating_text(msg: String, pos: Vector2, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.position = pos - Vector2(200.0, 60.0)
	lbl.size = Vector2(400.0, 90.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 62)
	lbl.add_theme_font_override("font", font_bold)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", Color("#08080a"))
	effects_layer.add_child(lbl)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 130.0, 0.75)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.75)
	tw.chain().tween_callback(lbl.queue_free)


func _finish_current_turn() -> void:
	if is_jammy_turn:
		is_jammy_turn = false
		_begin_turn_banner()
	else:
		if current_round < TOTAL_ROUNDS:
			current_round += 1
			is_jammy_turn = true
			_begin_turn_banner()
		else:
			_show_final_results()


func _show_final_results() -> void:
	state = GameState.GAME_OVER
	state_input_lock = 0.25
	instruction_box_panel.visible = false
	arm_sprite.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var result_title := ""
	var winner_color := LOUIS_COLOR
	if jammy_score > xcarlet_score:
		result_title = "JAMMY WINS! (%d vs %d)" % [jammy_score, xcarlet_score]
		winner_color = JAMMY_COLOR
	elif xcarlet_score > jammy_score:
		result_title = "XCARLET WINS! (%d vs %d)" % [xcarlet_score, jammy_score]
		winner_color = XCARLET_COLOR
	else:
		result_title = "IT'S A TIE! (%d vs %d)" % [jammy_score, xcarlet_score]

	center_banner_panel.add_theme_stylebox_override("panel", _make_box_style(PANEL_COLOR, winner_color))
	center_banner_title.position = Vector2(40.0, 44.0)
	center_banner_title.size = Vector2(1580.0, 140.0)
	center_banner_title.text = result_title
	center_banner_title.add_theme_color_override("font_color", winner_color)
	center_banner_sub.text = "Press [ENTER] to continue."
	center_banner_sub.visible = true
	center_banner_panel.visible = true

	continue_label.text = "ENTER TO CONTINUE"
	continue_panel.visible = true
	_update_hud()


func _update_hud() -> void:
	jammy_score_label.text = "JAMMY: %d" % jammy_score
	xcarlet_score_label.text = "XCARLET: %d" % xcarlet_score

	var who := "JAMMY" if is_jammy_turn else "XCARLET"
	round_label.text = "ROUND %d / %d  •  %s" % [current_round, TOTAL_ROUNDS, who]
	timer_label.text = "TIME: %.1fs" % turn_time_left


func _make_hint_pill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.11, 0.88)
	style.set_corner_radius_all(14)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.98, 0.94, 0.38)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _make_parchment_card_style(corner_radius: int, border_w: int, shadow_sz: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG_COLOR
	style.set_corner_radius_all(corner_radius)
	style.border_width_left = border_w
	style.border_width_top = border_w
	style.border_width_right = border_w
	style.border_width_bottom = border_w + 3
	style.border_color = CARD_INK_COLOR
	style.shadow_color = Color(0.08, 0.06, 0.04, 0.48)
	style.shadow_size = shadow_sz
	style.shadow_offset = Vector2(0.0, 10.0)
	return style


func _make_box_style(bg_color: Color, border_color: Color, border_width: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
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


func _find_fair_scene_recursive(dir_path: String) -> String:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var subdirs: Array[String] = []

	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			subdirs.append(full_path)
		elif file_name.get_extension().to_lower() == "tscn":
			var lower := file_name.get_basename().to_lower()
			if "fair" in lower:
				dir.list_dir_end()
				return full_path
		file_name = dir.get_next()

	dir.list_dir_end()

	for sub in subdirs:
		var found := _find_fair_scene_recursive(sub)
		if not found.is_empty():
			return found
	return ""


func _resolve_fair_scene_path() -> String:
	if not fair_scene_path.is_empty() and ResourceLoader.exists(fair_scene_path):
		return fair_scene_path

	var candidates := [
		"res://FairScenes.tscn",
		"res://scenes/FairScenes.tscn",
		"res://fairScenes.tscn",
		"res://scenes/fairScenes.tscn"
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			return p

	return _find_fair_scene_recursive("res://")


func _go_to_next_scene() -> void:
	if ending_triggered:
		return
	ending_triggered = true

	if gun_sfx_player != null:
		gun_sfx_player.stop()
	if hit_sfx_player != null:
		hit_sfx_player.stop()

	# Detenemos solo la música de la caseta de tiro; fair'sAudio sigue continuo al 100 % en el resto de la feria
	if is_instance_valid(shooting_bgm_player):
		shooting_bgm_player.stop()
	if is_instance_valid(fair_ambience_player):
		fair_ambience_player.volume_db = 0.0

	# Guarda el resultado para que FairScenes muestre dropTower1.png con el diálogo correspondiente
	var jammy_lost := jammy_score < xcarlet_score
	get_tree().set_meta("fair_shooting_result", "jammy_lost" if jammy_lost else "jammy_won")

	var target_path := _resolve_fair_scene_path()

	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null and save_manager.has_method("guardar_progreso") and ResourceLoader.exists(target_path):
		save_manager.guardar_progreso(target_path, "FairScenes_DropTower")

	# Transición directa a FairScenes (dropTower1.png) sin cerrar los ojos
	if ResourceLoader.exists(target_path):
		var err := get_tree().change_scene_to_file(target_path)
		if err != OK:
			push_error("Error al cambiar a " + target_path + ": " + str(err))
			ending_triggered = false
