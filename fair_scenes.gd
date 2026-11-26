extends Node2D

const BASE_SIZE := Vector2(3840.0, 2160.0)
const SOUNDS_DIR := "res://assets/sounds/"
const FAIR_AMBIENCE_NODE_NAME := "FairAmbiencePlayer"
const SHOOTING_BGM_NODE_NAME := "ShootingBoothBgmPlayer"
const SAD_BGM_NODE_NAME := "SadPostVomitBgmPlayer"
const SHOOTING_BGM_PATH := "res://assets/sounds/backgroundShooting.mp3"
const SAD_BGM_PATH := "res://assets/sounds/Gymopedia1.mp3"
const VOMIT_SFX_PATH := "res://assets/sounds/vomit.mp3"
const SHOOTING_BGM_VOLUME_LINEAR := 0.5 # 50 % de volumen
const VOMIT_REPEAT_COUNT := 3
const VOMIT_FALLBACK_SECONDS := 5.0

const TEXT_COLOR := Color("#fff9f0")
const PANEL_COLOR := Color(0.22, 0.23, 0.25, 0.68)
const OVERHEAD_PANEL_COLOR := Color(0.11, 0.11, 0.14, 0.92)
const MIND_PANEL_COLOR := Color(0.10, 0.10, 0.12, 0.88)
const SPEAKER_BG_COLOR := Color(0.18, 0.19, 0.21, 0.82)
const OVERHEAD_SPEAKER_BG := Color(0.14, 0.14, 0.18, 0.95)
const MIND_COLOR := Color("#ff666b")
const ACCENT_COLOR := Color("#fff9f0")
const GOLD_ACCENT := Color("#f5d08a")

# Colores de personajes
const JAMMY_COLOR := Color("#f5d08a")
const XCARLET_COLOR := Color("#5bc0eb")
const LOUIS_COLOR := Color("#ff6b6f")

# Tamaño estándar y posiciones homogenizadas (3840x2160)
const DIALOGUE_PANEL_SIZE := Vector2(1280.0, 250.0)
const MIND_PANEL_SIZE := Vector2(1340.0, 290.0)
const JAMMY_BOTTOM_POS := Vector2(1280.0, 1825.0)
const JAMMY_LEFT_POS := Vector2(140.0, 1780.0)
const PARALLEL_MIND_POS := Vector2(72.0, 56.0)
const OVERHEAD_POS := Vector2(860.0, 650.0)
const SPEAKER_PANEL_SIZE := Vector2(320.0, 62.0)

# Bucle de fair'sAudio: minuto 6:30 (390 s) al minuto 14:00 (840 s)
const FAIR_AUDIO_LOOP_START := 390.0
const FAIR_AUDIO_LOOP_END := 840.0

const FREDOKA_FONT = preload("res://fonts/Fredoka-Regular.ttf")
const ROCK_SALT_FONT = preload("res://fonts/RockSalt-Regular.ttf")
const NORMAL_DIALOGUE_STREAM = preload("res://assets/sounds/Soft_pencil_tap_on_n_#1-1794378651940.mp3")

@export_file("*.tscn") var shooting_game_scene_path: String = "res://shootting_Gallery_Game.tscn"
@export_file("*.tscn") var post_fair_scene_path: String = "res://rosePark.tscn"

var ui_root: Control
var background: TextureRect
var black_background: ColorRect
var black_overlay_layer: CanvasLayer
var black_overlay_rect: ColorRect

# Cuadro principal (abajo al centro, arriba de Louis Liberté o a la izquierda)
var dialogue_panel: Panel
var dialogue_label: Label
var speaker_panel: Panel
var speaker_label: Label

# Cuadro rojo paralelo (siempre en la esquina superior izquierda)
var parallel_mind_panel: Panel
var parallel_mind_label: Label

# Cuadro paralelo encima de Louis Liberté (mismo tamaño y formato homogenizado)
var overhead_panel: Panel
var overhead_label: Label
var overhead_speaker_panel: Panel
var overhead_speaker_label: Label

# Indicador de menú arriba a la derecha con alto contraste
var menu_hint_panel: PanelContainer
var menu_hint_label: Label

# Modal de confirmación al pulsar ESC
var leave_confirm_layer: CanvasLayer
var leave_confirm_overlay: ColorRect
var leave_confirm_panel: PanelContainer
var leave_yes_btn: Button
var leave_no_btn: Button
var leave_dialog_open := false

# Indicador minimalista de teclas abajo al centro con fondo oscuro legible
var continue_panel: PanelContainer
var continue_label: Label

var typewriter_player: AudioStreamPlayer
var fair_ambience_player: AudioStreamPlayer
var shooting_bgm_player: AudioStreamPlayer
var sad_bgm_player: AudioStreamPlayer
var vomit_player: AudioStreamPlayer

var typewriter_stream: AudioStream
var fair_audio_stream: AudioStream
var shooting_bgm_stream: AudioStream
var sad_bgm_stream: AudioStream
var vomit_stream: AudioStream
var shooting_bgm_active := false
var sad_bgm_active := false

var tex_fair_overview: Texture2D
var tex_scene2_fair: Texture2D
var tex_shooting_gallery1: Texture2D
var tex_shooting_gallery2: Texture2D
var tex_shooting_gallery3: Texture2D
var tex_drop_tower1: Texture2D
var tex_drop_tower2: Texture2D
var tex_drop_tower_xcarlet: Texture2D

var story_steps: Array[Dictionary] = []
var step_index := 0
var main_pages: Array[String] = []
var mind_pages: Array[String] = []
var overhead_pages: Array[String] = []
var page_index := 0

var is_typing := false
var typing_token := 0
var waiting_for_input := false
var ending_triggered := false
var is_post_gallery_phase := false
var jammy_lost_post_gallery := false
var in_vomit_black_screen := false


func _ready() -> void:
	name = "FairScenes"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_backgrounds()
	_build_audio()
	_build_ui()
	_build_leave_confirm_ui()

	var inicio_paso := 0
	var extra_data := _consume_loaded_extra_data()

	if get_tree().has_meta("fair_shooting_result"):
		var result := str(get_tree().get_meta("fair_shooting_result")).strip_edges().to_lower()
		get_tree().remove_meta("fair_shooting_result")
		is_post_gallery_phase = true
		jammy_lost_post_gallery = result in ["jammy_lost", "jammy", "jammy_lose", "p1_lost"]
		_stop_shooting_bgm()
		_stop_sad_bgm()
		_build_post_gallery_script(jammy_lost_post_gallery)
		_guardar_progreso_fair(0, 0)
	else:
		is_post_gallery_phase = bool(extra_data.get("is_post_gallery", false))
		jammy_lost_post_gallery = bool(extra_data.get("jammy_lost", false))

		if is_post_gallery_phase:
			_stop_shooting_bgm()
			_stop_sad_bgm()
			_build_post_gallery_script(jammy_lost_post_gallery)
			inicio_paso = _resolver_paso_guardado(extra_data)
			if bool(extra_data.get("sad_bgm", false)) or _paso_es_post_vomito(inicio_paso):
				_start_sad_bgm_loop()
			_guardar_progreso_fair(inicio_paso, 0)
		else:
			_stop_sad_bgm()
			_build_script()
			inicio_paso = _resolver_paso_guardado(extra_data)
			_guardar_progreso_fair(inicio_paso, 0)

	_start_fair_ambience_loop()
	_load_step(inicio_paso)


func _process(_delta: float) -> void:
	if in_vomit_black_screen:
		return

	if sad_bgm_active:
		if is_instance_valid(sad_bgm_player) and sad_bgm_player.stream != null and not sad_bgm_player.playing:
			sad_bgm_player.play()
		return

	if is_instance_valid(fair_ambience_player) and fair_ambience_player.stream != null:
		if not fair_ambience_player.playing:
			fair_ambience_player.play(FAIR_AUDIO_LOOP_START)
		else:
			var pos := fair_ambience_player.get_playback_position()
			if pos >= FAIR_AUDIO_LOOP_END or pos < FAIR_AUDIO_LOOP_START - 0.15:
				fair_ambience_player.seek(FAIR_AUDIO_LOOP_START)

	if shooting_bgm_active and is_instance_valid(shooting_bgm_player) and shooting_bgm_player.stream != null:
		if not shooting_bgm_player.playing:
			shooting_bgm_player.play()


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


func _consume_loaded_extra_data() -> Dictionary:
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

	return extra_data


func _resolver_paso_guardado(extra_data: Dictionary) -> int:
	if extra_data.is_empty() or story_steps.is_empty():
		return 0

	var raw_step = extra_data.get("step_index", extra_data.get("step", extra_data.get("index", 0)))
	var parsed_step := 0
	if typeof(raw_step) == TYPE_INT or typeof(raw_step) == TYPE_FLOAT:
		parsed_step = int(raw_step)
	elif typeof(raw_step) == TYPE_STRING and str(raw_step).strip_edges().is_valid_int():
		parsed_step = int(str(raw_step).strip_edges())

	parsed_step = clampi(parsed_step, 0, story_steps.size() - 1)
	if str(story_steps[parsed_step].get("type", "")) == "vomit_black_screen":
		parsed_step = clampi(parsed_step + 1, 0, story_steps.size() - 1)

	return parsed_step


func _paso_es_post_vomito(idx: int) -> bool:
	if not is_post_gallery_phase:
		return false
	for i in range(mini(idx, story_steps.size())):
		if str(story_steps[i].get("type", "")) == "vomit_black_screen":
			return true
	return false


func _resolver_ruta_escena_actual() -> String:
	if not scene_file_path.is_empty() and ResourceLoader.exists(scene_file_path):
		return scene_file_path

	var current_scene := get_tree().current_scene
	if current_scene != null and not current_scene.scene_file_path.is_empty() and ResourceLoader.exists(current_scene.scene_file_path):
		return current_scene.scene_file_path

	for candidata in [
		"res://FairScenes.tscn",
		"res://scenes/FairScenes.tscn",
		"res://fairScenes.tscn",
		"res://scenes/fairScenes.tscn"
	]:
		if ResourceLoader.exists(candidata):
			return candidata

	return ""


func _guardar_progreso_fair(paso: int = step_index, pagina: int = page_index) -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null or not save_manager.has_method("guardar_progreso"):
		return

	var current_path := _resolver_ruta_escena_actual()
	if current_path.is_empty():
		return

	var etiqueta := "FairScenes"
	if is_post_gallery_phase:
		etiqueta = "FairScenes - Drop Tower (%d/%d)" % [paso + 1, maxi(story_steps.size(), 1)]
	else:
		etiqueta = "FairScenes (%d/%d)" % [paso + 1, maxi(story_steps.size(), 1)]

	var extra_info: Dictionary = {
		"step_index": paso,
		"step": paso,
		"page_index": pagina,
		"is_post_gallery": is_post_gallery_phase,
		"jammy_lost": jammy_lost_post_gallery,
		"sad_bgm": sad_bgm_active
	}

	var slot_id := _obtener_slot_activo()
	var accepts_slot := false
	for m in save_manager.get_method_list():
		if str(m.get("name", "")) == "guardar_progreso":
			var args: Array = m.get("args", [])
			if args.size() >= 4:
				accepts_slot = true
			break

	if accepts_slot:
		save_manager.call("guardar_progreso", current_path, etiqueta, extra_info, slot_id)
	else:
		save_manager.call("guardar_progreso", current_path, etiqueta, extra_info)


func _load_scene_texture(file_name: String) -> Texture2D:
	var candidates := [
		"res://scenes/" + file_name,
		"res://" + file_name,
		"res://assets/backgrounds/" + file_name,
		"res://assets/" + file_name
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			return load(path)
	push_warning("No se encontró la imagen: " + file_name)
	return null


func _load_first_existing(names: Array[String]) -> Texture2D:
	var folders := ["res://scenes/", "res://", "res://assets/backgrounds/", "res://assets/"]
	var exts := [".png", ".jpg", ".jpeg", ".webp"]
	for base_name in names:
		for folder in folders:
			for ext in exts:
				var path: String = folder + base_name + ext
				if ResourceLoader.exists(path):
					return load(path)
	push_warning("No se encontró ninguna variante de: " + str(names))
	return null


func _load_backgrounds() -> void:
	tex_fair_overview = _load_scene_texture("fairOverview.png")
	tex_scene2_fair = _load_scene_texture("scene2Fair.png")
	tex_shooting_gallery1 = _load_first_existing([
		"shottingGallery", "shoottingGallery", "shootingGallery",
		"shottingGallery1", "shoottingGallery1", "shootingGallery1",
		"shotting1", "shootting1", "shooting1"
	])
	tex_shooting_gallery2 = _load_first_existing([
		"shoottingGallery2", "shottingGallery2", "shootingGallery2",
		"shotting2", "shootting2", "shooting2"
	])
	tex_shooting_gallery3 = _load_first_existing([
		"shoottingGallery3", "shottingGallery3", "shootingGallery3",
		"shotting3", "shootting3", "shooting3"
	])
	tex_drop_tower1 = _load_first_existing([
		"dropTower1", "droptower1", "dropTower", "droptower"
	])
	tex_drop_tower2 = _load_first_existing([
		"dropTower2", "droptower2"
	])
	tex_drop_tower_xcarlet = _load_first_existing([
		"dropTowerXcarlet", "dropTowerxcarlet", "droptowerXcarlet", "droptowerxcarlet",
		"dropTowerXScarlet", "dropTower_Xcarlet", "dropTower_xcarlet"
	])


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

	# Capa negra superior garantizada por encima de cualquier cámara o nodo de la escena
	black_overlay_layer = CanvasLayer.new()
	black_overlay_layer.layer = 100
	black_overlay_layer.visible = false
	add_child(black_overlay_layer)

	black_overlay_rect = ColorRect.new()
	black_overlay_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black_overlay_rect.color = Color.BLACK
	black_overlay_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	black_overlay_layer.add_child(black_overlay_rect)

	background = TextureRect.new()
	background.position = Vector2.ZERO
	background.size = BASE_SIZE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.pivot_offset = BASE_SIZE / 2.0
	background.texture = tex_fair_overview
	ui_root.add_child(background)

	# --- INDICADOR DE MENÚ ARRIBA A LA DERECHA CON ALTO CONTRASTE ---
	menu_hint_panel = PanelContainer.new()
	menu_hint_panel.anchor_left = 1.0
	menu_hint_panel.anchor_right = 1.0
	menu_hint_panel.anchor_top = 0.0
	menu_hint_panel.anchor_bottom = 0.0
	menu_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu_hint_panel.grow_vertical = Control.GROW_DIRECTION_END
	menu_hint_panel.offset_top = 56.0
	menu_hint_panel.offset_right = -72.0
	menu_hint_panel.z_index = 20
	menu_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_hint_panel.add_theme_stylebox_override("panel", _make_menu_pill_style())
	ui_root.add_child(menu_hint_panel)

	menu_hint_label = Label.new()
	menu_hint_label.text = "ESC   →   Start Menu"
	menu_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	menu_hint_label.add_theme_font_size_override("font_size", 32)
	menu_hint_label.add_theme_font_override("font", FREDOKA_FONT)
	menu_hint_label.add_theme_color_override("font_color", GOLD_ACCENT)
	menu_hint_label.add_theme_constant_override("outline_size", 5)
	menu_hint_label.add_theme_color_override("font_outline_color", Color("#050507"))
	menu_hint_label.add_theme_color_override("font_shadow_color", Color("#000000f5"))
	menu_hint_label.add_theme_constant_override("shadow_offset_x", 3)
	menu_hint_label.add_theme_constant_override("shadow_offset_y", 3)
	menu_hint_panel.add_child(menu_hint_label)

	# --- CUADRO DE DIÁLOGO PRINCIPAL ---
	var jammy_border := Color(JAMMY_COLOR.r, JAMMY_COLOR.g, JAMMY_COLOR.b, 0.70)

	dialogue_panel = Panel.new()
	dialogue_panel.position = JAMMY_BOTTOM_POS
	dialogue_panel.size = DIALOGUE_PANEL_SIZE
	dialogue_panel.z_index = 10
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, jammy_border))
	ui_root.add_child(dialogue_panel)

	speaker_panel = Panel.new()
	speaker_panel.position = Vector2(JAMMY_BOTTOM_POS.x + 36.0, JAMMY_BOTTOM_POS.y - SPEAKER_PANEL_SIZE.y + 2.0)
	speaker_panel.size = SPEAKER_PANEL_SIZE
	speaker_panel.z_index = 11
	speaker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	# --- CUADRO ROJO PARALELO (SIEMPRE EN ESQUINA SUPERIOR IZQUIERDA) ---
	var mind_border := Color(MIND_COLOR.r, MIND_COLOR.g, MIND_COLOR.b, 0.85)

	parallel_mind_panel = Panel.new()
	parallel_mind_panel.position = PARALLEL_MIND_POS
	parallel_mind_panel.size = MIND_PANEL_SIZE
	parallel_mind_panel.z_index = 10
	parallel_mind_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	# --- CUADRO PARALELO ENCIMA DE LOUIS LIBERTÉ ---
	var louis_border := Color(LOUIS_COLOR.r, LOUIS_COLOR.g, LOUIS_COLOR.b, 0.95)

	overhead_panel = Panel.new()
	overhead_panel.position = OVERHEAD_POS
	overhead_panel.size = DIALOGUE_PANEL_SIZE
	overhead_panel.z_index = 10
	overhead_panel.visible = false
	overhead_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overhead_panel.add_theme_stylebox_override("panel", _make_dialogue_style(OVERHEAD_PANEL_COLOR, louis_border))
	ui_root.add_child(overhead_panel)

	overhead_speaker_panel = Panel.new()
	overhead_speaker_panel.position = Vector2(OVERHEAD_POS.x + 36.0, OVERHEAD_POS.y - SPEAKER_PANEL_SIZE.y + 2.0)
	overhead_speaker_panel.size = SPEAKER_PANEL_SIZE
	overhead_speaker_panel.z_index = 11
	overhead_speaker_panel.visible = false
	overhead_speaker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overhead_speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(OVERHEAD_SPEAKER_BG, LOUIS_COLOR))
	ui_root.add_child(overhead_speaker_panel)

	overhead_speaker_label = Label.new()
	overhead_speaker_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overhead_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overhead_speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overhead_speaker_label.text = "Louis Liberté"
	overhead_speaker_label.add_theme_font_size_override("font_size", 36)
	overhead_speaker_label.add_theme_font_override("font", FREDOKA_FONT)
	overhead_speaker_label.add_theme_color_override("font_color", LOUIS_COLOR)
	overhead_speaker_label.add_theme_constant_override("outline_size", 3)
	overhead_speaker_label.add_theme_color_override("font_outline_color", Color("#08080a"))
	overhead_speaker_label.add_theme_color_override("font_shadow_color", Color("#000000f0"))
	overhead_speaker_label.add_theme_constant_override("shadow_offset_x", 2)
	overhead_speaker_label.add_theme_constant_override("shadow_offset_y", 2)
	overhead_speaker_panel.add_child(overhead_speaker_label)

	overhead_label = Label.new()
	overhead_label.position = Vector2(52.0, 24.0)
	overhead_label.size = Vector2(DIALOGUE_PANEL_SIZE.x - 104.0, DIALOGUE_PANEL_SIZE.y - 48.0)
	overhead_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overhead_label.clip_text = true
	overhead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overhead_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overhead_label.add_theme_font_size_override("font_size", 42)
	overhead_label.add_theme_font_override("font", FREDOKA_FONT)
	overhead_label.add_theme_color_override("font_color", Color("#ffffff"))
	overhead_label.add_theme_constant_override("outline_size", 4)
	overhead_label.add_theme_color_override("font_outline_color", Color("#08080a"))
	overhead_label.add_theme_color_override("font_shadow_color", Color("#000000f5"))
	overhead_label.add_theme_constant_override("shadow_offset_x", 4)
	overhead_label.add_theme_constant_override("shadow_offset_y", 4)
	overhead_panel.add_child(overhead_label)

	# --- INDICADOR MINIMALISTA INFERIOR CON CONTRASTE LEGIBLE ---
	continue_panel = PanelContainer.new()
	continue_panel.anchor_left = 0.5
	continue_panel.anchor_right = 0.5
	continue_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	continue_panel.position = Vector2(0.0, 2080.0)
	continue_panel.z_index = 12
	continue_panel.visible = false
	continue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	continue_panel.add_theme_stylebox_override("panel", _make_hint_pill_style())
	ui_root.add_child(continue_panel)

	continue_label = Label.new()
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	continue_label.add_theme_font_size_override("font_size", 32)
	continue_label.add_theme_font_override("font", FREDOKA_FONT)
	continue_label.add_theme_color_override("font_color", ACCENT_COLOR)
	continue_label.add_theme_constant_override("outline_size", 5)
	continue_label.add_theme_color_override("font_outline_color", Color("#08080a"))
	continue_label.text = "ENTER / SPACE"
	continue_panel.add_child(continue_label)

	typewriter_player = AudioStreamPlayer.new()
	typewriter_player.pitch_scale = 1.0
	typewriter_player.volume_db = 0.0
	add_child(typewriter_player)

	vomit_player = AudioStreamPlayer.new()
	vomit_player.bus = &"Master"
	vomit_player.volume_db = 0.0
	add_child(vomit_player)


func _make_menu_pill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.96)
	style.set_corner_radius_all(14)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.85)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
	style.shadow_size = 8
	return style


func _build_leave_confirm_ui() -> void:
	leave_confirm_layer = CanvasLayer.new()
	leave_confirm_layer.layer = 120
	leave_confirm_layer.visible = false
	add_child(leave_confirm_layer)

	leave_confirm_overlay = ColorRect.new()
	leave_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leave_confirm_overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	leave_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	leave_confirm_layer.add_child(leave_confirm_overlay)

	var center_box := CenterContainer.new()
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_box.mouse_filter = Control.MOUSE_FILTER_STOP
	leave_confirm_overlay.add_child(center_box)

	leave_confirm_panel = PanelContainer.new()
	leave_confirm_panel.custom_minimum_size = Vector2(1180.0, 440.0)
	leave_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var modal_sb := StyleBoxFlat.new()
	modal_sb.bg_color = Color(0.09, 0.10, 0.14, 0.98)
	modal_sb.set_corner_radius_all(24)
	modal_sb.border_width_left = 4
	modal_sb.border_width_top = 4
	modal_sb.border_width_right = 4
	modal_sb.border_width_bottom = 4
	modal_sb.border_color = Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.90)
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
	q_lbl.add_theme_color_override("font_color", ACCENT_COLOR)
	q_lbl.add_theme_constant_override("outline_size", 4)
	q_lbl.add_theme_color_override("font_outline_color", Color("#050507"))
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
	yes_sb.bg_color = Color(0.24, 0.12, 0.15, 0.96)
	yes_sb.set_corner_radius_all(16)
	yes_sb.border_width_left = 3
	yes_sb.border_width_top = 3
	yes_sb.border_width_right = 3
	yes_sb.border_width_bottom = 3
	yes_sb.border_color = MIND_COLOR
	leave_yes_btn.add_theme_stylebox_override("normal", yes_sb)
	leave_yes_btn.add_theme_stylebox_override("hover", yes_sb)
	leave_yes_btn.add_theme_color_override("font_color", ACCENT_COLOR)
	leave_yes_btn.pressed.connect(_go_to_start_menu)
	btn_row.add_child(leave_yes_btn)

	leave_no_btn = Button.new()
	leave_no_btn.text = "No  [ESC]"
	leave_no_btn.custom_minimum_size = Vector2(360.0, 96.0)
	leave_no_btn.add_theme_font_size_override("font_size", 40)
	leave_no_btn.add_theme_font_override("font", FREDOKA_FONT)
	var no_sb := StyleBoxFlat.new()
	no_sb.bg_color = Color(0.15, 0.17, 0.22, 0.96)
	no_sb.set_corner_radius_all(16)
	no_sb.border_width_left = 3
	no_sb.border_width_top = 3
	no_sb.border_width_right = 3
	no_sb.border_width_bottom = 3
	no_sb.border_color = Color(1.0, 1.0, 1.0, 0.45)
	leave_no_btn.add_theme_stylebox_override("normal", no_sb)
	leave_no_btn.add_theme_stylebox_override("hover", no_sb)
	leave_no_btn.add_theme_color_override("font_color", ACCENT_COLOR)
	leave_no_btn.pressed.connect(_close_leave_confirm)
	btn_row.add_child(leave_no_btn)


func _open_leave_confirm() -> void:
	if leave_dialog_open:
		return
	leave_dialog_open = true
	if is_instance_valid(typewriter_player):
		typewriter_player.stop()
	if is_instance_valid(leave_confirm_layer):
		leave_confirm_layer.visible = true


func _close_leave_confirm() -> void:
	leave_dialog_open = false
	if is_instance_valid(leave_confirm_layer):
		leave_confirm_layer.visible = false


func _go_to_start_menu() -> void:
	_guardar_progreso_fair(step_index, page_index)
	leave_dialog_open = false
	if is_instance_valid(leave_confirm_layer):
		leave_confirm_layer.visible = false

	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr != null and save_mgr.has_method("volver_al_inicio"):
		save_mgr.volver_al_inicio()
		return

	if ResourceLoader.exists("res://main.tscn"):
		get_tree().call_deferred("change_scene_to_file", "res://main.tscn")
	elif ResourceLoader.exists("res://Main.tscn"):
		get_tree().call_deferred("change_scene_to_file", "res://Main.tscn")


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
		},

		# --- GALERÍA DE TIRO 1: shottingGallery.png / shooting1.png ---
		{
			"bg": tex_shooting_gallery1,
			"speaker": "Jammy",
			"color": JAMMY_COLOR,
			"main": "*Oh, look at that girl with purple hair. She's so pretty, she seems to be feeling so good, I'd not like to change it.*",
			"mind": "*OCD is making my expressions in some time that she can interpret as a person angry with her. Pls purple girl, don't fall in another OCD's trap, don't break my heart again, my heart can't resist another blame.*"
		},

		# --- GALERÍA DE TIRO 2: shoottingGallery2.png ---
		{
			"bg": tex_shooting_gallery2,
			"speaker": "",
			"color": Color.WHITE,
			"main": "",
			"mind": "*Fuck, I'm so sorry, I'm sure that it ain't my fault.*"
		},
		{
			"bg": tex_shooting_gallery2,
			"speaker": "Jammy",
			"color": JAMMY_COLOR,
			"main": "Oh look at that, one of the fair booths that I wanted to visit. I was thinking... If you win one of those teddies, I'll... ummm... kiss you!",
			"overhead_speaker": "Louis Liberté",
			"overhead_color": LOUIS_COLOR,
			"overhead": [
				"*Everyone, everyone! Don't miss this opportunity and get a Monkey Teddy by saving the monkeys in the Gabon's rainforest!*",
				"*Monkeys, monkeys! Try your luck and take an original Monkey to your house!*"
			],
			"mind": "*The feared moment has arrived, while you're having your first attempt to have your first kiss, OCD will fuck it by filling your mind with heavy thoughts, like now, you're not paying attention to her, are you? You're just in the middle of this storm, and now you're doomed to live forever worried 'bout if you make Xcarlet hate you.*"
		},
		{
			"bg": tex_shooting_gallery2,
			"speaker": "Xcarlet",
			"color": XCARLET_COLOR,
			"main": "Ahhm, what?",
			"mind": ""
		},
		{
			"bg": tex_shooting_gallery2,
			"speaker": "Jammy",
			"color": JAMMY_COLOR,
			"main": "I meant, who gets less points at that shooting gallery will have to climb on the drop tower.",
			"mind": ""
		},
		{
			"bg": tex_shooting_gallery2,
			"speaker": "Xcarlet",
			"color": XCARLET_COLOR,
			"main": "Deal!! Anyways, I don't know where's the punishment, just people with numb minds let themselves throw up there, and obviously I've never... had that experience, yeah... ahem... and it's even less probable that I've thrown up on a mayor's head, yeahhh, so... improbable.",
			"mind": ""
		},
		{
			"bg": tex_shooting_gallery2,
			"speaker": "Jammy",
			"color": JAMMY_COLOR,
			"main": "Ahhh yeahh, I meant, thanks for your explanation...",
			"mind": ""
		},
		{
			"bg": tex_shooting_gallery2,
			"speaker": "Xcarlet",
			"color": XCARLET_COLOR,
			"main": "But, seems to be that this is an individual game, but... hold on... I got an idea...",
			"mind": ""
		},

		# --- GALERÍA DE TIRO 3: shoottingGallery3.png (Louis Liberté habla arriba de su cabeza) ---
		{
			"bg": tex_shooting_gallery3,
			"speaker": "Xcarlet",
			"color": XCARLET_COLOR,
			"main": "Hi, ahem... Gabon boy.",
			"mind": ""
		},
		{
			"bg": tex_shooting_gallery3,
			"speaker": "Louis Liberté",
			"color": LOUIS_COLOR,
			"box_pos": OVERHEAD_POS,
			"main": "Louis Liberté, the glorious man with the written destiny of preserving the memory of my father in the Gabon's Jungle and...",
			"mind": ""
		},
		{
			"bg": tex_shooting_gallery3,
			"speaker": "Xcarlet",
			"color": XCARLET_COLOR,
			"main": "Sir, sir, that's very interesting, but well... I meant I've already understood, Louis.",
			"mind": ""
		},
		{
			"bg": tex_shooting_gallery3,
			"speaker": "Louis Liberté",
			"color": LOUIS_COLOR,
			"box_pos": OVERHEAD_POS,
			"main": "And sooo, those currents that lead you to my lands have a name?",
			"mind": ""
		},
		{
			"bg": tex_shooting_gallery3,
			"speaker": "Xcarlet",
			"color": XCARLET_COLOR,
			"main": "...What?",
			"mind": ""
		},
		{
			"bg": tex_shooting_gallery3,
			"speaker": "Louis Liberté",
			"color": LOUIS_COLOR,
			"box_pos": OVERHEAD_POS,
			"main": "I meant, what do you want?",
			"mind": ""
		},
		{
			"bg": tex_shooting_gallery3,
			"speaker": "Xcarlet",
			"color": XCARLET_COLOR,
			"main": "It seems to be that this is a single-player game.",
			"mind": ""
		},
		{
			"bg": tex_shooting_gallery3,
			"speaker": "Louis Liberté",
			"color": LOUIS_COLOR,
			"box_pos": OVERHEAD_POS,
			"main": "And that's correct!!",
			"mind": ""
		},
		{
			"bg": tex_shooting_gallery3,
			"speaker": "Xcarlet",
			"color": XCARLET_COLOR,
			"main": "So I wanted to ask you if you won't give us the teddy, but you let us turn it into a multiplayer game.",
			"mind": ""
		},
		{
			"bg": tex_shooting_gallery3,
			"speaker": "Louis Liberté",
			"color": LOUIS_COLOR,
			"box_pos": OVERHEAD_POS,
			"main": "How do you dare!! During 60 years, my family has been fostering the individual will of preserving the Gabon's wildlife, so that—",
			"mind": ""
		},
		{
			"bg": tex_shooting_gallery3,
			"speaker": "Xcarlet",
			"color": XCARLET_COLOR,
			"main": "Sir, sir, stop! What 'bout paying double bill?",
			"mind": ""
		},
		{
			"bg": tex_shooting_gallery3,
			"speaker": "Louis Liberté",
			"color": LOUIS_COLOR,
			"box_pos": OVERHEAD_POS,
			"main": "Ohhhh, yes! No, no, no, wait, wait, I wanted to say, just 'cause you smell like my favorite French cheese!",
			"mind": ""
		}
	]

	dialogue_label.text = ""
	parallel_mind_label.text = ""
	overhead_label.text = ""


# --- TODAS LAS ESCENAS POSTERIORES A LA GALERÍA DE TIRO VAN AQUÍ EN ESTE MISMO SCRIPT ---
func _build_post_gallery_script(jammy_lost: bool) -> void:
	if jammy_lost:
		var bg_jammy_lost: Texture2D = tex_drop_tower2 if tex_drop_tower2 != null else tex_drop_tower1
		story_steps = [
			{
				"bg": tex_drop_tower1,
				"speaker": "Jammy",
				"color": JAMMY_COLOR,
				"box_pos": JAMMY_LEFT_POS,
				"main": "*I'm already sick of saying bad jokes, but I can't even try to be myself, 'cause I don't even know who I am, I'm just a bunch of intrusive thoughts. Sometimes I even doubt if it's me talking or an intrusive thought. Apparently I can be how I wanted, but my mental illness makes me feel anxious anyway. I wish I had never been born. I'm tired.*",
				"mind": ""
			},
			{
				"bg": tex_drop_tower1,
				"speaker": "Jammy",
				"color": JAMMY_COLOR,
				"box_pos": JAMMY_LEFT_POS,
				"main": "*The drop tower looks dangerous, but I'm not scared. I'd be better off dead.*",
				"mind": ""
			},
			{
				"type": "vomit_black_screen"
			},
			{
				"bg": bg_jammy_lost,
				"speaker": "Jammy",
				"color": JAMMY_COLOR,
				"box_pos": JAMMY_LEFT_POS,
				"main": "*I was throwing up, so that I smell pretty bad, but I don't care 'bout it, anything in my life can't be worse. It's just another event where my energy can barely let me breathe.*",
				"mind": ""
			}
		]
	else:
		var bg_xcarlet_lost: Texture2D = tex_drop_tower_xcarlet if tex_drop_tower_xcarlet != null else tex_drop_tower1
		story_steps = [
			{
				"bg": tex_drop_tower1,
				"speaker": "Xcarlet",
				"color": XCARLET_COLOR,
				"main": "Sis, I lied to you, I really threw up on Seattle's mayor's head...",
				"mind": ""
			},
			{
				"type": "vomit_black_screen"
			},
			{
				"bg": bg_xcarlet_lost,
				"speaker": "Xcarlet",
				"color": XCARLET_COLOR,
				"box_pos": JAMMY_LEFT_POS,
				"main": "Are you served?",
				"mind": ""
			}
		]

	dialogue_label.text = ""
	parallel_mind_label.text = ""
	overhead_label.text = ""


func _set_main_dialogue_position(pos: Vector2) -> void:
	dialogue_panel.position = pos
	speaker_panel.position = Vector2(pos.x + 36.0, pos.y - SPEAKER_PANEL_SIZE.y + 2.0)


func _apply_speaker_style(speaker_name: String, accent_color: Color) -> void:
	speaker_label.text = speaker_name
	speaker_label.add_theme_color_override("font_color", accent_color)
	var border_col := Color(accent_color.r, accent_color.g, accent_color.b, 0.90)
	var bg_col := OVERHEAD_PANEL_COLOR if speaker_name == "Louis Liberté" else PANEL_COLOR
	var tab_bg := OVERHEAD_SPEAKER_BG if speaker_name == "Louis Liberté" else SPEAKER_BG_COLOR
	dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(bg_col, border_col))
	speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(tab_bg, accent_color))


func _apply_overhead_style(speaker_name: String, accent_color: Color) -> void:
	overhead_speaker_label.text = speaker_name
	overhead_speaker_label.add_theme_color_override("font_color", accent_color)
	var border_col := Color(accent_color.r, accent_color.g, accent_color.b, 0.95)
	overhead_panel.add_theme_stylebox_override("panel", _make_dialogue_style(OVERHEAD_PANEL_COLOR, border_col))
	overhead_speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(OVERHEAD_SPEAKER_BG, accent_color))


func _enable_stream_loop(stream: AudioStream) -> void:
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true


func _disable_stream_loop(stream: AudioStream) -> void:
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = false
	elif stream is AudioStreamOggVorbis:
		stream.loop = false


func _start_shooting_bgm_if_needed() -> void:
	if shooting_bgm_active:
		return
	shooting_bgm_active = true
	if is_instance_valid(shooting_bgm_player) and shooting_bgm_stream != null:
		_enable_stream_loop(shooting_bgm_stream)
		if shooting_bgm_player.stream != shooting_bgm_stream:
			shooting_bgm_player.stream = shooting_bgm_stream
		shooting_bgm_player.volume_db = linear_to_db(SHOOTING_BGM_VOLUME_LINEAR)
		if not shooting_bgm_player.playing:
			shooting_bgm_player.play()


func _stop_shooting_bgm() -> void:
	shooting_bgm_active = false
	if is_instance_valid(shooting_bgm_player) and shooting_bgm_player.playing:
		shooting_bgm_player.stop()


func _start_sad_bgm_loop() -> void:
	sad_bgm_active = true
	if sad_bgm_stream == null:
		sad_bgm_stream = _load_sad_bgm_stream()
	if is_instance_valid(sad_bgm_player) and sad_bgm_stream != null:
		_enable_stream_loop(sad_bgm_stream)
		sad_bgm_player.volume_db = 0.0
		if sad_bgm_player.stream != sad_bgm_stream:
			sad_bgm_player.stream = sad_bgm_stream
		if not sad_bgm_player.playing:
			sad_bgm_player.play()


func _stop_sad_bgm() -> void:
	sad_bgm_active = false
	if is_instance_valid(sad_bgm_player) and sad_bgm_player.playing:
		sad_bgm_player.stop()


func _load_step(idx: int) -> void:
	if idx >= story_steps.size():
		_show_ending()
		return

	step_index = idx
	page_index = 0
	var step := story_steps[step_index]

	if str(step.get("type", "")) == "vomit_black_screen":
		_play_black_screen_vomit_sequence(step_index + 1)
		return

	_guardar_progreso_fair(step_index, page_index)

	var step_bg: Texture2D = step.get("bg", null)
	if step_bg != null:
		background.texture = step_bg

	# Activa backgroundShooting.mp3 al 50 % a partir de shooting1 / shottingGallery (paso 6 en adelante)
	if not is_post_gallery_phase and (step_index >= 6 or (step_bg != null and step_bg == tex_shooting_gallery1)):
		_start_shooting_bgm_if_needed()

	var speaker_name: String = step.get("speaker", "Jammy")
	var default_pos: Vector2 = OVERHEAD_POS if speaker_name == "Louis Liberté" else JAMMY_BOTTOM_POS
	var target_pos: Vector2 = step.get("box_pos", default_pos)
	_set_main_dialogue_position(target_pos)

	_apply_speaker_style(speaker_name, step.get("color", JAMMY_COLOR))
	_apply_overhead_style(step.get("overhead_speaker", "Louis Liberté"), step.get("overhead_color", LOUIS_COLOR))

	var raw_main: String = step.get("main", "")
	var raw_mind: String = step.get("mind", "")
	var raw_overhead = step.get("overhead", [])

	main_pages.clear()
	if not raw_main.is_empty():
		main_pages = _split_text_for_box(raw_main, false)

	mind_pages.clear()
	if not raw_mind.is_empty():
		mind_pages = _split_text_for_box(raw_mind, true)

	overhead_pages.clear()
	if raw_overhead is Array:
		for line in raw_overhead:
			var line_str := str(line)
			if not line_str.is_empty():
				overhead_pages.append_array(_split_text_for_box(line_str, false, overhead_label))
	elif raw_overhead is String and not raw_overhead.is_empty():
		overhead_pages = _split_text_for_box(raw_overhead, false, overhead_label)

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


func _split_text_for_box(raw_text: String, is_mind: bool, custom_label: Label = null) -> Array[String]:
	var has_start_marker: bool = is_mind or raw_text.begins_with("*")
	var has_end_marker: bool = is_mind or raw_text.ends_with("*")
	var inner_text: String = raw_text.trim_prefix("*").trim_suffix("*")

	var target_label: Label = custom_label if custom_label != null else (parallel_mind_label if is_mind else dialogue_label)
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
	var total_pages := maxi(maxi(main_pages.size(), mind_pages.size()), overhead_pages.size())
	if page_index >= total_pages:
		_load_step(step_index + 1)
		return

	continue_panel.visible = false
	menu_hint_panel.visible = true
	black_background.visible = false
	black_overlay_layer.visible = false
	background.visible = true
	background.modulate = Color.WHITE

	var has_main := page_index < main_pages.size()
	var has_mind := page_index < mind_pages.size()
	var has_overhead := page_index < overhead_pages.size()

	dialogue_panel.visible = has_main
	speaker_panel.visible = has_main
	parallel_mind_panel.visible = has_mind
	overhead_panel.visible = has_overhead
	overhead_speaker_panel.visible = has_overhead

	var main_target := main_pages[page_index] if has_main else ""
	var mind_target := mind_pages[page_index] if has_mind else ""
	var overhead_target := overhead_pages[page_index] if has_overhead else ""

	dialogue_label.text = ""
	parallel_mind_label.text = ""
	overhead_label.text = ""

	waiting_for_input = false
	is_typing = true
	typing_token += 1
	_type_parallel_words(typing_token, main_target, mind_target, overhead_target)


func _type_parallel_words(token: int, main_target: String, mind_target: String, overhead_target: String) -> void:
	var delay := 0.045
	var main_words := main_target.split(" ") if not main_target.is_empty() else PackedStringArray()
	var mind_words := mind_target.split(" ") if not mind_target.is_empty() else PackedStringArray()
	var overhead_words := overhead_target.split(" ") if not overhead_target.is_empty() else PackedStringArray()
	var max_words := maxi(maxi(main_words.size(), mind_words.size()), overhead_words.size())
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

		if idx < overhead_words.size():
			overhead_label.text += ("" if idx == 0 else " ") + overhead_words[idx]

		idx += 1
		await get_tree().create_timer(delay).timeout

	if token == typing_token:
		typewriter_player.stop()
		is_typing = false
		waiting_for_input = true
		continue_label.text = "ENTER / SPACE"
		continue_panel.visible = true


func _advance() -> void:
	if ending_triggered or in_vomit_black_screen or leave_dialog_open:
		return

	if is_typing:
		typing_token += 1
		typewriter_player.stop()
		if page_index < main_pages.size():
			dialogue_label.text = main_pages[page_index]
		if page_index < mind_pages.size():
			parallel_mind_label.text = mind_pages[page_index]
		if page_index < overhead_pages.size():
			overhead_label.text = overhead_pages[page_index]
		is_typing = false
		waiting_for_input = true
		continue_label.text = "ENTER / SPACE"
		continue_panel.visible = true
		return

	if waiting_for_input:
		page_index += 1
		_show_current_pages()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if leave_dialog_open:
				_close_leave_confirm()
			else:
				_open_leave_confirm()
			return
		if leave_dialog_open and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			get_viewport().set_input_as_handled()
			_go_to_start_menu()
			return

	if ending_triggered or in_vomit_black_screen or leave_dialog_open:
		return

	var advance_pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			advance_pressed = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_pressed = true
	elif event.is_action_pressed("ui_accept"):
		advance_pressed = true

	if advance_pressed:
		get_viewport().set_input_as_handled()
		_advance()


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
	style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.90)
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


func _load_shooting_bgm_stream() -> AudioStream:
	var candidates := [
		SHOOTING_BGM_PATH,
		"res://assets/sounds/backgroundShotting.mp3",
		"res://sounds/backgroundShooting.mp3"
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			return load(path)
	push_warning("No se encontró " + SHOOTING_BGM_PATH)
	return null


func _load_sad_bgm_stream() -> AudioStream:
	var candidates := [
		SAD_BGM_PATH,
		"res://assets/sounds/Gymnopedia1.mp3",
		"res://assets/sounds/Gymnopedie1.mp3",
		"res://sounds/Gymopedia1.mp3"
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is AudioStream:
				return res

	var found := _find_audio_recursive("res://", "gym")
	if found != null:
		return found

	push_warning("No se encontró Gymopedia1.mp3 en " + SOUNDS_DIR)
	return null


func _find_audio_recursive(dir_path: String, keyword: String) -> AudioStream:
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
			if ext in ["mp3", "ogg", "wav"] and keyword in file_name.get_basename().to_lower():
				if ResourceLoader.exists(full_path):
					var res := load(full_path)
					if res is AudioStream:
						dir.list_dir_end()
						return res
		file_name = dir.get_next()

	dir.list_dir_end()

	for sub in subdirs:
		var found := _find_audio_recursive(sub, keyword)
		if found != null:
			return found
	return null


func _load_vomit_stream() -> AudioStream:
	var candidates := [
		VOMIT_SFX_PATH,
		"res://assets/Sounds/vomit.mp3",
		"res://sounds/vomit.mp3",
		"res://vomit.mp3",
		"res://assets/sounds/vomit.ogg",
		"res://assets/sounds/vomit.wav"
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is AudioStream:
				return res

	var found := _find_audio_recursive("res://", "vomit")
	if found != null:
		return found

	push_warning("No se encontró vomit.mp3 en el proyecto")
	return null


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


func _build_audio() -> void:
	typewriter_stream = NORMAL_DIALOGUE_STREAM
	fair_audio_stream = _load_fair_audio_stream()
	shooting_bgm_stream = _load_shooting_bgm_stream()
	sad_bgm_stream = _load_sad_bgm_stream()
	vomit_stream = _load_vomit_stream()

	# Reproductores persistentes en /root para que no se reinicien al cambiar de escena
	fair_ambience_player = _get_or_create_root_player(FAIR_AMBIENCE_NODE_NAME)
	shooting_bgm_player = _get_or_create_root_player(SHOOTING_BGM_NODE_NAME)
	sad_bgm_player = _get_or_create_root_player(SAD_BGM_NODE_NAME)


func _start_fair_ambience_loop() -> void:
	if sad_bgm_active:
		return
	if fair_ambience_player == null or fair_audio_stream == null:
		return

	_enable_stream_loop(fair_audio_stream)
	fair_ambience_player.volume_db = 0.0

	if fair_ambience_player.stream == fair_audio_stream and fair_ambience_player.playing:
		return

	fair_ambience_player.stream = fair_audio_stream
	if fair_ambience_player.is_inside_tree():
		fair_ambience_player.play(FAIR_AUDIO_LOOP_START)
	else:
		fair_ambience_player.tree_entered.connect(func() -> void:
			if is_instance_valid(fair_ambience_player) and fair_ambience_player.stream != null and not fair_ambience_player.playing and not sad_bgm_active:
				fair_ambience_player.play(FAIR_AUDIO_LOOP_START)
		, CONNECT_ONE_SHOT)


func _find_scene_recursive(dir_path: String, any_keywords: Array[String], exclude_keywords: Array[String] = []) -> String:
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
			var excluded := false
			for ex in exclude_keywords:
				if ex in lower:
					excluded = true
					break
			if not excluded:
				for k in any_keywords:
					if k in lower:
						dir.list_dir_end()
						return full_path
		file_name = dir.get_next()

	dir.list_dir_end()

	for sub in subdirs:
		var found := _find_scene_recursive(sub, any_keywords, exclude_keywords)
		if not found.is_empty():
			return found
	return ""


func _resolve_level_scene_path() -> String:
	if not shooting_game_scene_path.is_empty() and ResourceLoader.exists(shooting_game_scene_path):
		return shooting_game_scene_path

	var candidates := [
		"res://shootting_Gallery_Game.tscn",
		"res://scenes/shootting_Gallery_Game.tscn",
		"res://shooting_Gallery_Game.tscn",
		"res://scenes/shooting_Gallery_Game.tscn",
		"res://shotting_Gallery_Game.tscn",
		"res://scenes/shotting_Gallery_Game.tscn",
		"res://shoottingGalleryGame.tscn",
		"res://scenes/shoottingGalleryGame.tscn",
		"res://shootingGalleryGame.tscn",
		"res://scenes/shootingGalleryGame.tscn"
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			return p

	return _find_scene_recursive("res://", ["gallery", "shoott", "shoot", "shott"], ["fair"])


func _resolve_rose_park_scene_path() -> String:
	if not post_fair_scene_path.is_empty() and ResourceLoader.exists(post_fair_scene_path):
		return post_fair_scene_path

	var candidates := [
		"res://rosePark.tscn",
		"res://scenes/rosePark.tscn",
		"res://rose_park.tscn",
		"res://scenes/rose_park.tscn",
		"res://RosePark.tscn",
		"res://scenes/RosePark.tscn"
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			return p

	return _find_scene_recursive("res://", ["rosepark", "rose_park"], ["fair"])


func _play_black_screen_vomit_sequence(next_step_idx: int) -> void:
	in_vomit_black_screen = true
	waiting_for_input = false
	is_typing = false
	typewriter_player.stop()
	_stop_shooting_bgm()
	_stop_sad_bgm()

	if is_instance_valid(fair_ambience_player):
		fair_ambience_player.stop()

	# Pantalla totalmente negra sin cuadros ni texto (en CanvasLayer 100 + fondo)
	background.visible = false
	black_background.visible = true
	black_overlay_layer.visible = true
	dialogue_panel.visible = false
	speaker_panel.visible = false
	parallel_mind_panel.visible = false
	overhead_panel.visible = false
	overhead_speaker_panel.visible = false
	continue_panel.visible = false
	menu_hint_panel.visible = false

	# Reproduce vomit.mp3 exactamente 3 veces en pantalla negra
	if vomit_stream == null:
		vomit_stream = _load_vomit_stream()

	if vomit_player != null and vomit_stream != null:
		_disable_stream_loop(vomit_stream)
		vomit_player.stop()
		vomit_player.stream = vomit_stream
		vomit_player.volume_db = 0.0

		for _i in range(VOMIT_REPEAT_COUNT):
			vomit_player.play(0.0)
			await vomit_player.finished
			if not is_inside_tree():
				return

		if is_instance_valid(vomit_player):
			vomit_player.stop()
	else:
		await get_tree().create_timer(VOMIT_FALLBACK_SECONDS, true).timeout

	black_background.visible = false
	black_overlay_layer.visible = false
	background.visible = true
	menu_hint_panel.visible = true
	in_vomit_black_screen = false

	# Inicia Gymopedia1.mp3 en bucle justo después de la pantalla negra de vómito
	_start_sad_bgm_loop()
	_load_step(next_step_idx)


func _show_ending() -> void:
	if ending_triggered:
		return
	ending_triggered = true

	waiting_for_input = false
	is_typing = false
	typewriter_player.stop()
	continue_panel.visible = false

	if is_post_gallery_phase:
		_stop_shooting_bgm()
		if is_instance_valid(fair_ambience_player):
			fair_ambience_player.stop()

		# Mantiene Gymopedia1.mp3 sonando sin cortes hacia rosePark.tscn
		var rose_scene := _resolve_rose_park_scene_path()
		if rose_scene.is_empty() or not ResourceLoader.exists(rose_scene):
			push_warning("No se encontró la escena rosePark.tscn")
			ending_triggered = false
			return

		var save_manager := get_node_or_null("/root/SaveManager")
		if save_manager != null and save_manager.has_method("guardar_progreso"):
			save_manager.guardar_progreso(rose_scene, "RosePark")

		var err_rose := get_tree().change_scene_to_file(rose_scene)
		if err_rose != OK:
			push_error("Error al cambiar a " + rose_scene + ": " + str(err_rose))
			ending_triggered = false
		return

	# Cambio directo sin transición de ojos; el audio de la feria y de la caseta continúa sin cortes
	var target_scene := _resolve_level_scene_path()
	if target_scene.is_empty() or not ResourceLoader.exists(target_scene):
		ending_triggered = false
		return

	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null and save_manager.has_method("guardar_progreso"):
		save_manager.guardar_progreso(target_scene, "FairScenes")

	var err := get_tree().change_scene_to_file(target_scene)
	if err != OK:
		push_error("Error al cambiar a " + target_scene + ": " + str(err))
		ending_triggered = false
