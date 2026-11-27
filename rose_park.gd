extends Node2D

const BASE_SIZE := Vector2(3840.0, 2160.0)
const SAD_BGM_NODE_NAME := "SadPostVomitBgmPlayer"
const SAD_BGM_PATH := "res://assets/sounds/Gymopedia1.mp3"
const CRYING_MAX_SECONDS := 120.0
const ENDING_HAND_SECONDS := 20.0
const ENDING_BLACKOUT_SECONDS := 20.0

const FREDOKA_FONT = preload("res://fonts/Fredoka-Regular.ttf")
const ROCK_SALT_FONT = preload("res://fonts/RockSalt-Regular.ttf")
const NOTIFICATION_STREAM = preload("res://assets/sounds/Soft_pencil_tap_on_n_#1-1794378651940.mp3")

# Colores UI
const TEXT_COLOR := Color("#fff9f0")
const PANEL_COLOR := Color(0.14, 0.15, 0.18, 0.86)
const MIND_PANEL_COLOR := Color(0.08, 0.08, 0.10, 0.92)
const SPEAKER_BG_COLOR := Color(0.18, 0.19, 0.22, 0.94)
const MIND_COLOR := Color("#ff595e")
const JAMMY_COLOR := Color("#f5d08a")
const XCARLET_COLOR := Color("#5bc0eb")
const MOM_COLOR := Color("#e07a5f")
const PSYCH_COLOR := Color("#81b29a")
const GOLD_ACCENT := Color("#f5d08a")

# Posiciones estándar 4K
const DIALOGUE_PANEL_SIZE := Vector2(1420.0, 270.0)
const MIND_PANEL_SIZE := Vector2(1340.0, 290.0)
const BOTTOM_BOX_POS := Vector2(1210.0, 1795.0)
const PARALLEL_MIND_POS := Vector2(72.0, 56.0)
const SPEAKER_PANEL_SIZE := Vector2(360.0, 64.0)

# Paleta Mensajería
const DESKTOP_BG_COLOR := Color("#0b141a")
const WINDOW_BG_COLOR := Color("#111b21")
const HEADER_BG_COLOR := Color("#202c33")
const BORDER_COLOR := Color("#2a3942")
const ACTIVE_CHAT_COLOR := Color("#2a3942")
const INCOMING_BUBBLE_COLOR := Color("#202c33")
const OUTGOING_BUBBLE_COLOR := Color("#005c4b")
const TEXT_PRIMARY := Color("#e9edef")
const TEXT_SECONDARY := Color("#8696a0")
const ONLINE_GREEN := Color("#00a884")

var ui_root: Control
var bg_rect: TextureRect
var sky_lights_overlay: TextureRect
var stars_fx_layer: Control
var hands_rect: TextureRect
var dark_vignette: ColorRect
var ending_black_rect: ColorRect

# UI Novela Visual
var vn_layer: Control
var dialogue_panel: Panel
var dialogue_label: Label
var speaker_panel: Panel
var speaker_label: Label
var mind_panel: Panel
var mind_label: Label

# UI Mensajería
var chat_layer: Control
var chat_vbox: VBoxContainer
var chat_status_label: Label
var sidebar_preview_label: Label
var sidebar_time_label: Label
var chat_input_label: Label

# UI Noticia / Colapso
var news_layer: Control
var comment1_highlight: ColorRect
var comment2_highlight: ColorRect
var comment1_label: Label
var comment2_label: Label
var panic_overlay: Control

# Párpados animación abrir/cerrar ojos
var eyelid_layer: CanvasLayer
var top_eyelid: ColorRect
var bottom_eyelid: ColorRect

# Indicador de menú arriba a la derecha en su propia capa superior
var menu_hint_layer: CanvasLayer
var menu_hint_root: Control
var menu_hint_panel: PanelContainer
var menu_hint_label: Label

# Modal de confirmación al pulsar ESC
var leave_confirm_layer: CanvasLayer
var leave_confirm_overlay: ColorRect
var leave_confirm_panel: PanelContainer
var leave_yes_btn: Button
var leave_no_btn: Button
var leave_dialog_open := false

# Indicador inferior
var continue_panel: PanelContainer
var continue_label: Label

# Audio
var sad_bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var loop_sfx_player: AudioStreamPlayer
var crying_player: AudioStreamPlayer

# Texturas
var tex_park: Texture2D
var tex_kiss: Texture2D
var tex_house1: Texture2D
var tex_house2: Texture2D
var tex_scene9: Texture2D
var tex_pills: Texture2D
var tex_hospital: Texture2D
var tex_sky_no_lights: Texture2D
var tex_sky_with_lights: Texture2D
var tex_hands: Texture2D

# Sonidos
var sfx_kisses: AudioStream
var sfx_breathing: AudioStream
var sfx_hospital: AudioStream
var sfx_crying: AudioStream

# Control de secuencia y paginación
var timeline: Array[Dictionary] = []
var current_index := 0
var main_pages: Array[String] = []
var mind_pages: Array[String] = []
var page_index := 0

var is_busy := false
var is_typing := false
var typing_token := 0
var waiting_for_input := false
var stars_blinking := false
var star_time := 0.0
var procedural_stars: Array[Dictionary] = []
var shake_intensity := 0.0

# Control exacto del cierre final (0 = inactivo, 1 = mano + estrellas 20s, 2 = pantalla negra + fade audio 20s)
var ending_phase := 0
var ending_phase_elapsed := 0.0
var start_bgm_db := 0.0
var start_crying_db := 0.0
var start_loop_db := 0.0

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "RosePark"
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	rng.randomize()
	_load_assets()
	_build_audio()
	_ensure_sad_bgm_playing(1.0)
	_build_ui()
	_build_leave_confirm_ui()
	_build_full_timeline()
	_update_viewport_scale()

	if not get_viewport().size_changed.is_connected(_update_viewport_scale):
		get_viewport().size_changed.connect(_update_viewport_scale)

	_run_step(0)


func _update_viewport_scale() -> void:
	var vp_size := get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var scale_vec := Vector2(vp_size.x / BASE_SIZE.x, vp_size.y / BASE_SIZE.y)
	if is_instance_valid(ui_root):
		ui_root.scale = scale_vec
	if is_instance_valid(menu_hint_root):
		menu_hint_root.scale = scale_vec


func _process(delta: float) -> void:
	_enforce_crying_time_limit()

	if leave_dialog_open:
		return

	if ending_phase == 1:
		_tick_ending_hand_phase(delta)
	elif ending_phase == 2:
		_tick_ending_blackout_phase(delta)
		return

	if is_instance_valid(sad_bgm_player) and sad_bgm_player.stream != null and not sad_bgm_player.playing:
		sad_bgm_player.play()

	if stars_blinking:
		star_time += delta
		if is_instance_valid(sky_lights_overlay) and sky_lights_overlay.visible:
			sky_lights_overlay.modulate.a = 0.55 + 0.45 * sin(star_time * 4.5)

		for entry in procedural_stars:
			var star: ColorRect = entry["node"]
			if is_instance_valid(star):
				var speed: float = entry["speed"]
				var phase: float = entry["phase"]
				star.modulate.a = 0.15 + 0.85 * (0.5 + 0.5 * sin(star_time * speed + phase))

	if shake_intensity > 0.0:
		ui_root.position = Vector2(
			rng.randf_range(-shake_intensity, shake_intensity),
			rng.randf_range(-shake_intensity, shake_intensity)
		)
	else:
		ui_root.position = Vector2.ZERO


func _tick_ending_hand_phase(delta: float) -> void:
	ending_phase_elapsed += delta
	if is_instance_valid(hands_rect):
		hands_rect.visible = true
		var rise_t := clampf(ending_phase_elapsed / 1.8, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - rise_t, 3.0)
		hands_rect.position.y = lerpf(BASE_SIZE.y, 165.0, eased)

	if ending_phase_elapsed >= ENDING_HAND_SECONDS:
		_enter_ending_blackout_phase()


func _enter_ending_blackout_phase() -> void:
	ending_phase = 2
	ending_phase_elapsed = 0.0

	if is_instance_valid(hands_rect):
		hands_rect.visible = false
	if is_instance_valid(stars_fx_layer):
		stars_fx_layer.visible = false
	if is_instance_valid(sky_lights_overlay):
		sky_lights_overlay.visible = false
	stars_blinking = false

	if is_instance_valid(ending_black_rect):
		ending_black_rect.visible = true
		ending_black_rect.color = Color.BLACK

	start_bgm_db = sad_bgm_player.volume_db if is_instance_valid(sad_bgm_player) else 0.0
	start_crying_db = crying_player.volume_db if is_instance_valid(crying_player) else 0.0
	start_loop_db = loop_sfx_player.volume_db if is_instance_valid(loop_sfx_player) else 0.0


func _tick_ending_blackout_phase(delta: float) -> void:
	ending_phase_elapsed += delta
	var t := clampf(ending_phase_elapsed / ENDING_BLACKOUT_SECONDS, 0.0, 1.0)
	var curved_t := t * t

	if is_instance_valid(sad_bgm_player) and sad_bgm_player.playing:
		sad_bgm_player.volume_db = lerpf(start_bgm_db, -80.0, curved_t)
	if is_instance_valid(crying_player) and crying_player.playing:
		crying_player.volume_db = lerpf(start_crying_db, -80.0, curved_t)
	if is_instance_valid(loop_sfx_player) and loop_sfx_player.playing:
		loop_sfx_player.volume_db = lerpf(start_loop_db, -80.0, curved_t)

	if ending_phase_elapsed >= ENDING_BLACKOUT_SECONDS:
		ending_phase = 0
		if is_instance_valid(sad_bgm_player):
			sad_bgm_player.stop()
		if is_instance_valid(crying_player):
			crying_player.stop()
		if is_instance_valid(loop_sfx_player):
			loop_sfx_player.stop()
		_return_to_main_menu()


func _enforce_crying_time_limit() -> void:
	if not is_instance_valid(crying_player) or crying_player.stream == null:
		return
	if crying_player.playing and crying_player.get_playback_position() >= CRYING_MAX_SECONDS:
		crying_player.play(0.0)


func _normalize_name(raw: String) -> String:
	return raw.get_basename().to_lower().replace(" ", "").replace("_", "").replace("-", "").replace("'", "")


func _find_file(candidates: Array[String], normalized_keywords: Array[String] = []) -> String:
	for p in candidates:
		if ResourceLoader.exists(p):
			return p
	if not normalized_keywords.is_empty():
		return _search_recursive("res://", normalized_keywords)
	return ""


func _search_recursive(dir_path: String, normalized_keywords: Array[String]) -> String:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var f := dir.get_next()
	var subdirs: Array[String] = []
	while f != "":
		if not f.begins_with("."):
			var full := dir_path.path_join(f)
			if dir.current_is_dir():
				subdirs.append(full)
			elif not f.ends_with(".import"):
				var norm := _normalize_name(f)
				for kw in normalized_keywords:
					if kw in norm:
						dir.list_dir_end()
						return full
		f = dir.get_next()
	dir.list_dir_end()
	for s in subdirs:
		var found := _search_recursive(s, normalized_keywords)
		if not found.is_empty():
			return found
	return ""


func _load_tex(names: Array[String], fallback_kws: Array[String]) -> Texture2D:
	var paths: Array[String] = []
	for n in names:
		paths.append("res://scenes/" + n)
		paths.append("res://assets/backgrounds/" + n)
		paths.append("res://assets/" + n)
		paths.append("res://" + n)
	var found := _find_file(paths, fallback_kws)
	if found.is_empty():
		push_warning("No se encontró textura para: " + str(names))
		return null
	return load(found)


func _load_snd(names: Array[String], fallback_kws: Array[String]) -> AudioStream:
	var paths: Array[String] = []
	for n in names:
		paths.append("res://assets/sounds/" + n)
		paths.append("res://sounds/" + n)
		paths.append("res://" + n)
	var found := _find_file(paths, fallback_kws)
	if found.is_empty():
		push_warning("No se encontró audio para: " + str(names))
		return null
	return load(found)


func _load_assets() -> void:
	tex_park = _load_tex([
		"Park'sBackground.png",
		"park'sBackground.png",
		"ParksBackground.png",
		"parksBackground.png",
		"ParkBackground.png",
		"parkBackground.png"
	], ["park"])
	tex_kiss = _load_tex(["Kiss.png", "kiss.png", "kissScene.png", "KissScene.png"], ["kiss"])
	tex_house1 = _load_tex(["House1.png", "house1.png", "House1.jpg", "house1.jpg"], ["house1"])
	tex_house2 = _load_tex(["House2.jpg", "house2.jpg", "House2.png", "house2.png"], ["house2"])
	if tex_house2 != null:
		print("House2 cargado: ", tex_house2.resource_path)
	else:
		print("AVISO: House2 no se encontró, se usará House1 como respaldo.")
	tex_scene9 = _load_tex(["scene9.png", "Scene9.png"], ["scene9"])
	tex_pills = _load_tex(["pills.png", "Pills.png"], ["pills"])
	tex_hospital = _load_tex(["Hospital.png", "hospital.png"], ["hospital"])
	tex_sky_no_lights = _load_tex([
		"skyWhiteoutLigjts.exr", "skyWhiteoutLigjts.png",
		"skyWhitout Lights.png", "skyWithout Lights.png",
		"skyWhitoutLights.png", "skyWithoutLights.png"
	], ["skywhiteout", "skywhitout", "skywithout"])
	tex_sky_with_lights = _load_tex([
		"skyWithLights.png", "skyWith Lights.png", "skywithlights.png"
	], ["skywithlights"])
	tex_hands = _load_tex(["hands.png", "Hands.png"], ["hands"])

	sfx_kisses = _load_snd(["kisses.mp3", "kiss.mp3", "Kisses.mp3"], ["kiss"])
	sfx_breathing = _load_snd(["breathing1.mp3", "breathing.mp3"], ["breathing"])
	sfx_hospital = _load_snd(["Hospital.mp3", "hospital.mp3"], ["hospital"])
	sfx_crying = _load_snd(["crying.mp3", "cry.mp3", "Crying.mp3"], ["crying"])


func _build_audio() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = &"Master"
	add_child(sfx_player)

	loop_sfx_player = AudioStreamPlayer.new()
	loop_sfx_player.bus = &"Master"
	add_child(loop_sfx_player)

	crying_player = AudioStreamPlayer.new()
	crying_player.bus = &"Master"
	add_child(crying_player)


func _ensure_sad_bgm_playing(volume_linear: float = 1.0) -> void:
	if ending_phase == 2:
		return
	var root := get_tree().root
	var existing := root.get_node_or_null(SAD_BGM_NODE_NAME)
	if existing is AudioStreamPlayer:
		sad_bgm_player = existing
	else:
		sad_bgm_player = AudioStreamPlayer.new()
		sad_bgm_player.name = SAD_BGM_NODE_NAME
		sad_bgm_player.bus = &"Master"
		sad_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child.call_deferred(sad_bgm_player)

	if sad_bgm_player.stream == null and ResourceLoader.exists(SAD_BGM_PATH):
		sad_bgm_player.stream = load(SAD_BGM_PATH)
	if sad_bgm_player.stream is AudioStreamMP3:
		sad_bgm_player.stream.loop = true
	sad_bgm_player.volume_db = linear_to_db(clampf(volume_linear, 0.01, 1.0))

	if sad_bgm_player.is_inside_tree():
		if sad_bgm_player.stream != null and not sad_bgm_player.playing:
			sad_bgm_player.play()
	else:
		sad_bgm_player.tree_entered.connect(func() -> void:
			if ending_phase != 2 and is_instance_valid(sad_bgm_player) and sad_bgm_player.stream != null and not sad_bgm_player.playing:
				sad_bgm_player.play()
		, CONNECT_ONE_SHOT)


func _build_ui() -> void:
	ui_root = Control.new()
	ui_root.size = BASE_SIZE
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	var black_base := ColorRect.new()
	black_base.size = BASE_SIZE
	black_base.color = Color("#05070d")
	ui_root.add_child(black_base)

	bg_rect = TextureRect.new()
	bg_rect.size = BASE_SIZE
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ui_root.add_child(bg_rect)

	sky_lights_overlay = TextureRect.new()
	sky_lights_overlay.size = BASE_SIZE
	sky_lights_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky_lights_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky_lights_overlay.visible = false
	sky_lights_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sky_lights_overlay.material = add_mat
	if tex_sky_with_lights != null:
		sky_lights_overlay.texture = tex_sky_with_lights
	ui_root.add_child(sky_lights_overlay)

	stars_fx_layer = Control.new()
	stars_fx_layer.size = BASE_SIZE
	stars_fx_layer.visible = false
	stars_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(stars_fx_layer)

	for i in range(60):
		var star := ColorRect.new()
		var sz := rng.randf_range(4.0, 11.0)
		star.size = Vector2(sz, sz)
		star.position = Vector2(rng.randf_range(100.0, BASE_SIZE.x - 100.0), rng.randf_range(60.0, 1300.0))
		star.color = Color(1.0, 0.97, 0.85, 1.0)
		stars_fx_layer.add_child(star)
		procedural_stars.append({
			"node": star,
			"speed": rng.randf_range(2.8, 7.5),
			"phase": rng.randf_range(0.0, TAU)
		})

	hands_rect = TextureRect.new()
	hands_rect.size = BASE_SIZE
	hands_rect.position = Vector2(0.0, BASE_SIZE.y)
	hands_rect.pivot_offset = Vector2(BASE_SIZE.x * 0.5, BASE_SIZE.y)
	hands_rect.scale = Vector2(1.14, 1.14)
	hands_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hands_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hands_rect.visible = false
	hands_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex_hands != null:
		hands_rect.texture = tex_hands
	ui_root.add_child(hands_rect)

	dark_vignette = ColorRect.new()
	dark_vignette.size = BASE_SIZE
	dark_vignette.color = Color(0, 0, 0, 0)
	dark_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(dark_vignette)

	ending_black_rect = ColorRect.new()
	ending_black_rect.size = BASE_SIZE
	ending_black_rect.color = Color.BLACK
	ending_black_rect.z_index = 70
	ending_black_rect.visible = false
	ending_black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(ending_black_rect)

	# --- CAPA SUPERIOR DEDICADA PARA EL INDICADOR DE MENÚ ARRIBA A LA DERECHA ---
	menu_hint_layer = CanvasLayer.new()
	menu_hint_layer.layer = 100
	add_child(menu_hint_layer)

	menu_hint_root = Control.new()
	menu_hint_root.size = BASE_SIZE
	menu_hint_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_hint_layer.add_child(menu_hint_root)

	menu_hint_panel = PanelContainer.new()
	menu_hint_panel.position = Vector2(3310.0, 56.0)
	menu_hint_panel.size = Vector2(458.0, 66.0)
	menu_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_hint_panel.add_theme_stylebox_override("panel", _make_menu_pill_style())
	menu_hint_root.add_child(menu_hint_panel)

	menu_hint_label = Label.new()
	menu_hint_label.text = "ESC  →  Start Menu"
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

	# --- CAPA NOVELA VISUAL ---
	vn_layer = Control.new()
	vn_layer.size = BASE_SIZE
	vn_layer.visible = false
	vn_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(vn_layer)

	dialogue_panel = Panel.new()
	dialogue_panel.position = BOTTOM_BOX_POS
	dialogue_panel.size = DIALOGUE_PANEL_SIZE
	dialogue_panel.add_theme_stylebox_override("panel", _make_box(PANEL_COLOR, JAMMY_COLOR, 18, 3))
	vn_layer.add_child(dialogue_panel)

	speaker_panel = Panel.new()
	speaker_panel.position = Vector2(BOTTOM_BOX_POS.x + 36.0, BOTTOM_BOX_POS.y - SPEAKER_PANEL_SIZE.y + 2.0)
	speaker_panel.size = SPEAKER_PANEL_SIZE
	speaker_panel.add_theme_stylebox_override("panel", _make_tab(SPEAKER_BG_COLOR, JAMMY_COLOR))
	vn_layer.add_child(speaker_panel)

	speaker_label = Label.new()
	speaker_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.add_theme_font_size_override("font_size", 34)
	speaker_label.add_theme_font_override("font", FREDOKA_FONT)
	speaker_panel.add_child(speaker_label)

	dialogue_label = Label.new()
	dialogue_label.position = Vector2(48.0, 22.0)
	dialogue_label.size = Vector2(DIALOGUE_PANEL_SIZE.x - 96.0, DIALOGUE_PANEL_SIZE.y - 44.0)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.clip_text = true
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.add_theme_font_size_override("font_size", 38)
	dialogue_label.add_theme_font_override("font", FREDOKA_FONT)
	dialogue_label.add_theme_color_override("font_color", TEXT_COLOR)
	dialogue_panel.add_child(dialogue_label)

	mind_panel = Panel.new()
	mind_panel.position = PARALLEL_MIND_POS
	mind_panel.size = MIND_PANEL_SIZE
	mind_panel.visible = false
	mind_panel.add_theme_stylebox_override("panel", _make_box(MIND_PANEL_COLOR, MIND_COLOR, 18, 3))
	vn_layer.add_child(mind_panel)

	mind_label = Label.new()
	mind_label.position = Vector2(48.0, 22.0)
	mind_label.size = Vector2(MIND_PANEL_SIZE.x - 96.0, MIND_PANEL_SIZE.y - 44.0)
	mind_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mind_label.clip_text = true
	mind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mind_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mind_label.add_theme_font_size_override("font_size", 34)
	mind_label.add_theme_font_override("font", ROCK_SALT_FONT)
	mind_label.add_theme_color_override("font_color", MIND_COLOR)
	mind_panel.add_child(mind_label)

	# --- CAPA MENSAJERÍA ---
	_build_chat_layer()

	# --- CAPA NOTICIA / COLAPSO ---
	_build_news_layer()

	# --- PÁRPADOS PARA ABRIR / CERRAR OJOS ---
	eyelid_layer = CanvasLayer.new()
	eyelid_layer.layer = 80
	eyelid_layer.visible = false
	add_child(eyelid_layer)

	top_eyelid = ColorRect.new()
	top_eyelid.position = Vector2.ZERO
	top_eyelid.size = Vector2(BASE_SIZE.x, BASE_SIZE.y * 0.5)
	top_eyelid.color = Color.BLACK
	eyelid_layer.add_child(top_eyelid)

	bottom_eyelid = ColorRect.new()
	bottom_eyelid.position = Vector2(0.0, BASE_SIZE.y * 0.5)
	bottom_eyelid.size = Vector2(BASE_SIZE.x, BASE_SIZE.y * 0.5)
	bottom_eyelid.color = Color.BLACK
	eyelid_layer.add_child(bottom_eyelid)

	# --- INDICADOR INFERIOR HOMOGENEIZADO ---
	continue_panel = PanelContainer.new()
	continue_panel.anchor_left = 0.5
	continue_panel.anchor_right = 0.5
	continue_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	continue_panel.position = Vector2(0.0, 2080.0)
	continue_panel.z_index = 50
	continue_panel.visible = false
	continue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	continue_panel.add_theme_stylebox_override("panel", _make_hint_pill_style())
	ui_root.add_child(continue_panel)

	continue_label = Label.new()
	continue_label.text = "ENTER / SPACE"
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	continue_label.add_theme_font_size_override("font_size", 32)
	continue_label.add_theme_font_override("font", FREDOKA_FONT)
	continue_label.add_theme_color_override("font_color", TEXT_COLOR)
	continue_label.add_theme_constant_override("outline_size", 5)
	continue_label.add_theme_color_override("font_outline_color", Color("#08080a"))
	continue_panel.add_child(continue_label)


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
	q_lbl.add_theme_color_override("font_color", TEXT_COLOR)
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
	leave_yes_btn.add_theme_color_override("font_color", TEXT_COLOR)
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
	leave_no_btn.add_theme_color_override("font_color", TEXT_COLOR)
	leave_no_btn.pressed.connect(_close_leave_confirm)
	btn_row.add_child(leave_no_btn)


func _open_leave_confirm() -> void:
	if leave_dialog_open:
		return
	leave_dialog_open = true
	if is_instance_valid(sfx_player):
		sfx_player.stop()
	if is_instance_valid(leave_confirm_layer):
		leave_confirm_layer.visible = true


func _close_leave_confirm() -> void:
	leave_dialog_open = false
	if is_instance_valid(leave_confirm_layer):
		leave_confirm_layer.visible = false


func _go_to_start_menu() -> void:
	leave_dialog_open = false
	ending_phase = 0
	ending_phase_elapsed = 0.0
	get_tree().paused = false
	if is_instance_valid(leave_confirm_layer):
		leave_confirm_layer.visible = false
	if is_instance_valid(crying_player):
		crying_player.stop()
	if is_instance_valid(loop_sfx_player):
		loop_sfx_player.stop()
	if is_instance_valid(sad_bgm_player):
		sad_bgm_player.stop()

	for menu_path in ["res://main_menu.tscn", "res://main.tscn", "res://Main.tscn", "res://scenes/main_menu.tscn"]:
		if ResourceLoader.exists(menu_path):
			get_tree().call_deferred("change_scene_to_file", menu_path)
			return


func _build_chat_layer() -> void:
	chat_layer = Control.new()
	chat_layer.size = BASE_SIZE
	chat_layer.visible = false
	ui_root.add_child(chat_layer)

	var desktop := ColorRect.new()
	desktop.size = BASE_SIZE
	desktop.color = DESKTOP_BG_COLOR
	chat_layer.add_child(desktop)

	var margin := Vector2(260.0, 140.0)
	var win_size := BASE_SIZE - margin * 2.0

	var win := Panel.new()
	win.position = margin
	win.size = win_size
	win.add_theme_stylebox_override("panel", _make_box(WINDOW_BG_COLOR, BORDER_COLOR, 20, 3))
	chat_layer.add_child(win)

	var top_bar := Panel.new()
	top_bar.size = Vector2(win_size.x, 68.0)
	top_bar.add_theme_stylebox_override("panel", _make_box(Color("#182229"), Color.TRANSPARENT, 20, 0))
	win.add_child(top_bar)

	var dots := [Color("#ff5f56"), Color("#ffbd2e"), Color("#27c93f")]
	for i in range(3):
		var d := Panel.new()
		d.position = Vector2(36.0 + i * 38.0, 23.0)
		d.size = Vector2(22.0, 22.0)
		d.add_theme_stylebox_override("panel", _make_box(dots[i], Color.TRANSPARENT, 99, 0))
		top_bar.add_child(d)

	var side_w := 920.0
	var body_y := 68.0
	var body_h := win_size.y - 68.0

	var sidebar := Panel.new()
	sidebar.position = Vector2(0.0, body_y)
	sidebar.size = Vector2(side_w, body_h)
	sidebar.add_theme_stylebox_override("panel", _make_box(WINDOW_BG_COLOR, BORDER_COLOR, 0, 2))
	win.add_child(sidebar)

	var contact_card := Panel.new()
	contact_card.position = Vector2(20.0, 40.0)
	contact_card.size = Vector2(side_w - 40.0, 146.0)
	contact_card.add_theme_stylebox_override("panel", _make_box(ACTIVE_CHAT_COLOR, Color.TRANSPARENT, 16, 0))
	sidebar.add_child(contact_card)

	var cname := Label.new()
	cname.position = Vector2(40.0, 24.0)
	cname.text = "Xcarlet"
	cname.add_theme_font_size_override("font_size", 38)
	cname.add_theme_font_override("font", FREDOKA_FONT)
	cname.add_theme_color_override("font_color", TEXT_PRIMARY)
	contact_card.add_child(cname)

	sidebar_time_label = Label.new()
	sidebar_time_label.position = Vector2(side_w - 220.0, 28.0)
	sidebar_time_label.size = Vector2(150.0, 40.0)
	sidebar_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sidebar_time_label.add_theme_font_size_override("font_size", 26)
	sidebar_time_label.add_theme_font_override("font", FREDOKA_FONT)
	sidebar_time_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	contact_card.add_child(sidebar_time_label)

	sidebar_preview_label = Label.new()
	sidebar_preview_label.position = Vector2(40.0, 78.0)
	sidebar_preview_label.size = Vector2(side_w - 100.0, 46.0)
	sidebar_preview_label.clip_text = true
	sidebar_preview_label.add_theme_font_size_override("font_size", 28)
	sidebar_preview_label.add_theme_font_override("font", FREDOKA_FONT)
	sidebar_preview_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	contact_card.add_child(sidebar_preview_label)

	var chat_area := Panel.new()
	chat_area.position = Vector2(side_w, body_y)
	chat_area.size = Vector2(win_size.x - side_w, body_h)
	chat_area.add_theme_stylebox_override("panel", _make_box(DESKTOP_BG_COLOR, Color.TRANSPARENT, 0, 0))
	win.add_child(chat_area)

	var header := Panel.new()
	header.size = Vector2(chat_area.size.x, 116.0)
	header.add_theme_stylebox_override("panel", _make_box(HEADER_BG_COLOR, Color.TRANSPARENT, 0, 0))
	chat_area.add_child(header)

	var hname := Label.new()
	hname.position = Vector2(48.0, 18.0)
	hname.text = "Xcarlet"
	hname.add_theme_font_size_override("font_size", 38)
	hname.add_theme_font_override("font", FREDOKA_FONT)
	hname.add_theme_color_override("font_color", TEXT_PRIMARY)
	header.add_child(hname)

	chat_status_label = Label.new()
	chat_status_label.position = Vector2(48.0, 66.0)
	chat_status_label.text = "online"
	chat_status_label.add_theme_font_size_override("font_size", 28)
	chat_status_label.add_theme_font_override("font", FREDOKA_FONT)
	chat_status_label.add_theme_color_override("font_color", ONLINE_GREEN)
	header.add_child(chat_status_label)

	chat_vbox = VBoxContainer.new()
	chat_vbox.position = Vector2(88.0, 180.0)
	chat_vbox.size = Vector2(chat_area.size.x - 176.0, body_h - 340.0)
	chat_vbox.add_theme_constant_override("separation", 34)
	chat_area.add_child(chat_vbox)

	var composer := Panel.new()
	composer.position = Vector2(0.0, body_h - 120.0)
	composer.size = Vector2(chat_area.size.x, 120.0)
	composer.add_theme_stylebox_override("panel", _make_box(HEADER_BG_COLOR, Color.TRANSPARENT, 0, 0))
	chat_area.add_child(composer)

	chat_input_label = Label.new()
	chat_input_label.position = Vector2(56.0, 20.0)
	chat_input_label.size = Vector2(chat_area.size.x - 180.0, 80.0)
	chat_input_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chat_input_label.text = "Type a message"
	chat_input_label.add_theme_font_size_override("font_size", 32)
	chat_input_label.add_theme_font_override("font", FREDOKA_FONT)
	chat_input_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	composer.add_child(chat_input_label)


func _build_news_layer() -> void:
	news_layer = Control.new()
	news_layer.size = BASE_SIZE
	news_layer.visible = false
	ui_root.add_child(news_layer)

	var bg := ColorRect.new()
	bg.size = BASE_SIZE
	bg.color = Color("#0c0d10")
	news_layer.add_child(bg)

	var card := Panel.new()
	card.position = Vector2(720.0, 220.0)
	card.size = Vector2(2400.0, 1680.0)
	card.add_theme_stylebox_override("panel", _make_box(Color("#16181d"), Color("#2c303a"), 24, 3))
	news_layer.add_child(card)

	var outlet := Label.new()
	outlet.position = Vector2(90.0, 60.0)
	outlet.text = "DAILY CHRONICLE  •  BREAKING NEWS"
	outlet.add_theme_font_size_override("font_size", 32)
	outlet.add_theme_font_override("font", FREDOKA_FONT)
	outlet.add_theme_color_override("font_color", Color("#ef4444"))
	card.add_child(outlet)

	var headline := Label.new()
	headline.position = Vector2(90.0, 140.0)
	headline.size = Vector2(2220.0, 260.0)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.text = "Son was killed by his mother just because he came out of the closet."
	headline.add_theme_font_size_override("font_size", 68)
	headline.add_theme_font_override("font", FREDOKA_FONT)
	headline.add_theme_color_override("font_color", Color("#f8fafc"))
	card.add_child(headline)

	var sep := ColorRect.new()
	sep.position = Vector2(90.0, 440.0)
	sep.size = Vector2(2220.0, 3.0)
	sep.color = Color("#2c303a")
	card.add_child(sep)

	var comm_header := Label.new()
	comm_header.position = Vector2(90.0, 480.0)
	comm_header.text = "TOP COMMENTS (2)"
	comm_header.add_theme_font_size_override("font_size", 32)
	comm_header.add_theme_font_override("font", FREDOKA_FONT)
	comm_header.add_theme_color_override("font_color", Color("#94a3b8"))
	card.add_child(comm_header)

	var c1_box := Panel.new()
	c1_box.position = Vector2(90.0, 570.0)
	c1_box.size = Vector2(2220.0, 220.0)
	c1_box.add_theme_stylebox_override("panel", _make_box(Color("#1e2128"), Color("#333844"), 16, 2))
	card.add_child(c1_box)

	comment1_highlight = ColorRect.new()
	comment1_highlight.position = Vector2(36.0, 96.0)
	comment1_highlight.size = Vector2(0.0, 68.0)
	comment1_highlight.color = Color(0.95, 0.12, 0.16, 0.55)
	c1_box.add_child(comment1_highlight)

	var u1 := Label.new()
	u1.position = Vector2(40.0, 26.0)
	u1.text = "@User_94812  •  12m ago"
	u1.add_theme_font_size_override("font_size", 28)
	u1.add_theme_font_override("font", FREDOKA_FONT)
	u1.add_theme_color_override("font_color", Color("#94a3b8"))
	c1_box.add_child(u1)

	comment1_label = Label.new()
	comment1_label.position = Vector2(40.0, 96.0)
	comment1_label.text = "And where's the bad part?"
	comment1_label.add_theme_font_size_override("font_size", 48)
	comment1_label.add_theme_font_override("font", FREDOKA_FONT)
	comment1_label.add_theme_color_override("font_color", Color("#f1f5f9"))
	c1_box.add_child(comment1_label)

	var c2_box := Panel.new()
	c2_box.position = Vector2(90.0, 840.0)
	c2_box.size = Vector2(2220.0, 220.0)
	c2_box.add_theme_stylebox_override("panel", _make_box(Color("#1e2128"), Color("#333844"), 16, 2))
	card.add_child(c2_box)

	comment2_highlight = ColorRect.new()
	comment2_highlight.position = Vector2(36.0, 96.0)
	comment2_highlight.size = Vector2(0.0, 68.0)
	comment2_highlight.color = Color(0.95, 0.12, 0.16, 0.55)
	c2_box.add_child(comment2_highlight)

	var u2 := Label.new()
	u2.position = Vector2(40.0, 26.0)
	u2.text = "@TradValues_77  •  8m ago"
	u2.add_theme_font_size_override("font_size", 28)
	u2.add_theme_font_override("font", FREDOKA_FONT)
	u2.add_theme_color_override("font_color", Color("#94a3b8"))
	c2_box.add_child(u2)

	comment2_label = Label.new()
	comment2_label.position = Vector2(40.0, 96.0)
	comment2_label.text = "Gift a beer to that hero on my behalf."
	comment2_label.add_theme_font_size_override("font_size", 48)
	comment2_label.add_theme_font_override("font", FREDOKA_FONT)
	comment2_label.add_theme_color_override("font_color", Color("#f1f5f9"))
	c2_box.add_child(comment2_label)

	panic_overlay = Control.new()
	panic_overlay.size = BASE_SIZE
	panic_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(panic_overlay)


func _build_full_timeline() -> void:
	var house_after_gf: Texture2D = tex_house2 if tex_house2 != null else tex_house1

	timeline = [
		# --- CHAT 1 ---
		{"type": "chat", "clear": true, "incoming": true, "text": "Do you have time to come with me to the International Rose Test Garden?", "time": "10:14 AM"},
		{"type": "chat", "clear": false, "incoming": false, "text": "yeah, see you there", "time": "10:15 AM"},

		# --- PARQUE DE ROSAS + ESCENA DEL BESO (Kiss.png + kisses.mp3) ---
		{"type": "vn", "bg": tex_park, "speaker": "Xcarlet", "color": XCARLET_COLOR, "main": "Hi."},
		{"type": "vn", "bg": tex_park, "speaker": "Jammy", "color": JAMMY_COLOR, "main": "And how are you?"},
		{
			"type": "vn",
			"bg": tex_park,
			"speaker": "Jammy",
			"color": JAMMY_COLOR,
			"main": "To be honest, I'm sad and I don't have the energy to do anything."
		},
		{
			"type": "vn",
			"bg": tex_park,
			"speaker": "Xcarlet",
			"color": XCARLET_COLOR,
			"main": "I don't know why that's happening to you, but I hope this kiss can help you."
		},
		{
			"type": "vn",
			"bg": tex_kiss if tex_kiss != null else tex_park,
			"speaker": "",
			"color": XCARLET_COLOR,
			"main": "",
			"mind": "*You'll be bland and strange after that kiss that was supposed to boost your confidence.*",
			"sfx": sfx_kisses
		},

		# --- CHAT 2 ---
		{"type": "chat", "clear": true, "incoming": false, "text": "My mom will come tomorrow, would you like to meet her?", "time": "8:42 PM"},
		{"type": "chat", "clear": false, "incoming": true, "text": "Yes, I do.", "time": "8:43 PM"},

		# --- CASA (House1 -> House2 justo después de "No, she's my new girlfriend.") ---
		{"type": "vn", "bg": tex_house1, "speaker": "Jammy's Mom", "color": MOM_COLOR, "main": "Hi, nice to meet you. Is she a new friend?"},
		{"type": "vn", "bg": tex_house1, "speaker": "Jammy", "color": JAMMY_COLOR, "main": "No, she's my new girlfriend."},
		{"type": "vn", "bg": house_after_gf, "speaker": "Jammy's Mom", "color": MOM_COLOR, "main": "Is this another one of your obsessions?"},
		{"type": "vn", "bg": house_after_gf, "speaker": "Jammy", "color": JAMMY_COLOR, "main": "No, I love her."},
		{"type": "vn", "bg": house_after_gf, "speaker": "Jammy's Mom", "color": MOM_COLOR, "main": "We give you everything and then you do this? You're an ungrateful clown, a son of the devil—you're just going against nature."},
		{"type": "vn", "bg": house_after_gf, "speaker": "Jammy's Mom", "color": MOM_COLOR, "main": "Do you want me to call your dad and tell him what you do with his money? You can fix it, if you're willing."},

		# El TOC baja al cuadro principal de Jammy (solo dice "Jammy" en rojo) con breathing1.mp3
		{
			"type": "vn",
			"bg": house_after_gf,
			"speaker": "Jammy",
			"color": MIND_COLOR,
			"is_ocd_takeover": true,
			"main": "*Despite hating it, you'll show the opposite—smiles, pretending everything is fine...*",
			"loop_sfx": sfx_breathing
		},

		# --- CRISIS NOTICIA + SCENE 9 + PILLS ---
		{"type": "panic_crisis"},

		# --- PANTALLA NEGRA 20s + HOSPITAL ---
		{"type": "hospital_blackout"},
		{
			"type": "vn",
			"bg": tex_hospital,
			"speaker": "Jammy",
			"color": JAMMY_COLOR,
			"open_eyes": true,
			"main": "*Am I alive? Being alive after attempting suicide is worse—you feel embarrassed around the people who know about it, forced to return to your painful life.*"
		},
		{
			"type": "vn",
			"bg": tex_hospital,
			"speaker": "Jammy",
			"color": JAMMY_COLOR,
			"main": "I can't move my neck."
		},
		{
			"type": "vn",
			"bg": tex_hospital,
			"speaker": "Psychiatrist",
			"color": PSYCH_COLOR,
			"blink_eyes": true,
			"main": "Yes, it's OCD."
		},

		# --- CIERRA Y ABRE LOS OJOS DE NUEVO -> CONVERSACIÓN CON LA MAMÁ EN EL HOSPITAL ---
		{
			"type": "vn",
			"bg": tex_hospital,
			"speaker": "Jammy's Mom",
			"color": MOM_COLOR,
			"blink_eyes": true,
			"main": "Were you trying to get my attention?"
		},
		{
			"type": "vn",
			"bg": tex_hospital,
			"speaker": "Jammy's Mom",
			"color": MOM_COLOR,
			"main": "Well then, you got it, asshole."
		},
		{
			"type": "vn",
			"bg": tex_hospital,
			"speaker": "Jammy's Mom",
			"color": MOM_COLOR,
			"main": "Why did you do that?"
		},
		{
			"type": "vn",
			"bg": tex_hospital,
			"speaker": "Jammy",
			"color": JAMMY_COLOR,
			"main": "Because of what you told me."
		},
		{
			"type": "vn",
			"bg": tex_hospital,
			"speaker": "Jammy's Mom",
			"color": MOM_COLOR,
			"main": "Don't blame me for your decisions, besides, I only told the truth."
		},
		{
			"type": "vn",
			"bg": tex_hospital,
			"speaker": "Jammy",
			"color": JAMMY_COLOR,
			"main": "But are you going to accept me?"
		},
		{
			"type": "vn",
			"bg": tex_hospital,
			"speaker": "Jammy's Mom",
			"color": MOM_COLOR,
			"main": "How am I going to accept something that isn't true? Focus on important things instead. Do you think that if that were true, you would try to take your own life? That's only for stupid people. Don't you think about the damage you do to your family by saying that bullshit? Selfish."
		},
		{
			"type": "vn",
			"bg": tex_hospital,
			"speaker": "Jammy",
			"color": JAMMY_COLOR,
			"main": "If you weren't going to accept your kids unconditionally, you shouldn't have had them."
		},
		{
			"type": "vn",
			"bg": tex_hospital,
			"speaker": "Jammy's Mom",
			"color": MOM_COLOR,
			"main": "Well, the bad thing is they can't be returned anymore."
		},

		# --- CIELO ESTRELLADO (SOLO TITILAN LAS ESTRELLAS; AÚN NO SALEN LAS MANOS) ---
		{
			"type": "vn",
			"bg": tex_sky_no_lights,
			"stars_blink": true,
			"stop_loop_sfx": true,
			"speaker": "Jammy",
			"color": JAMMY_COLOR,
			"crying_sfx": true,
			"main": "I did it and I still want to do it 'cause I have OCD. All my moments are stained by horrible thoughts, and sometimes I don't even know if they're true. I tried to be positive, for example when I realized you hadn't abandoned me because of OCD, but OCD found a way to ruin even this seemingly good situation—I couldn't even enjoy our first kiss, and then my mom just kicked me out. I'm dead inside. I wish I'd never been born."
		},
		{
			"type": "vn",
			"bg": tex_sky_no_lights,
			"stars_blink": true,
			"sad_bgm_vol": 0.5,
			"speaker": "Xcarlet",
			"color": XCARLET_COLOR,
			"sfx": NOTIFICATION_STREAM,
			"main": "Please—give yourself another opportunity. Let me be the star that ignites you when your light isn't enough."
		}
	]

	# --- 10 "I BEG YOU!" SEPARADOS CON SU PROPIO AUDIO CADA UNO ---
	for i in range(10):
		timeline.append({
			"type": "vn",
			"bg": tex_sky_no_lights,
			"stars_blink": true,
			"speaker": "Xcarlet",
			"color": XCARLET_COLOR,
			"sfx": NOTIFICATION_STREAM,
			"main": "I beg you!"
		})

	# --- AL FINAL: MANO + ESTRELLAS 20s -> PANTALLA NEGRA CON FADE-OUT DE MÚSICA Y LLANTO 20s -> MENÚ ---
	timeline.append({
		"type": "ending_hands"
	})


func _return_to_main_menu() -> void:
	ending_phase = 0
	ending_phase_elapsed = 0.0
	get_tree().paused = false
	if is_instance_valid(crying_player):
		crying_player.stop()
	if is_instance_valid(loop_sfx_player):
		loop_sfx_player.stop()
	if is_instance_valid(sad_bgm_player):
		sad_bgm_player.stop()

	for menu_path in ["res://main_menu.tscn", "res://main.tscn", "res://Main.tscn", "res://scenes/main_menu.tscn"]:
		if ResourceLoader.exists(menu_path):
			get_tree().call_deferred("change_scene_to_file", menu_path)
			return


func _run_step(idx: int) -> void:
	if idx >= timeline.size():
		return
	current_index = idx

	var step := timeline[idx]
	var step_type: String = step.get("type", "vn")

	if step.get("stop_loop_sfx", false) and is_instance_valid(loop_sfx_player):
		loop_sfx_player.stop()

	if step.has("sad_bgm_vol"):
		_ensure_sad_bgm_playing(float(step["sad_bgm_vol"]))

	stars_blinking = step.get("stars_blink", false)
	stars_fx_layer.visible = stars_blinking
	if stars_blinking:
		sky_lights_overlay.visible = tex_sky_with_lights != null
	else:
		sky_lights_overlay.visible = false
		bg_rect.modulate = Color.WHITE

	if step_type != "ending_hands":
		hands_rect.visible = false
		hands_rect.position = Vector2(0.0, BASE_SIZE.y)

	match step_type:
		"chat":
			await _handle_chat_step(step)
		"vn":
			await _handle_vn_step(step)
		"panic_crisis":
			await _handle_panic_crisis()
		"hospital_blackout":
			await _handle_hospital_blackout()
		"ending_hands":
			_start_ending_sequence()


func _handle_chat_step(step: Dictionary) -> void:
	is_busy = true
	continue_panel.visible = false
	menu_hint_panel.visible = true
	vn_layer.visible = false
	news_layer.visible = false
	chat_layer.visible = true

	if step.get("clear", false):
		for child in chat_vbox.get_children():
			child.queue_free()

	var is_incoming: bool = step.get("incoming", true)
	var text_str: String = step.get("text", "")
	var time_str: String = step.get("time", "")

	if is_incoming:
		chat_status_label.text = "typing..."
		sidebar_preview_label.text = "typing..."
		await get_tree().create_timer(0.8).timeout
		chat_status_label.text = "online"
		sidebar_preview_label.text = text_str
		sidebar_time_label.text = time_str
	else:
		chat_input_label.add_theme_color_override("font_color", TEXT_PRIMARY)
		chat_input_label.text = ""
		for i in range(text_str.length()):
			chat_input_label.text += text_str[i]
			await get_tree().create_timer(0.028).timeout
		await get_tree().create_timer(0.2).timeout
		chat_input_label.text = "Type a message"
		chat_input_label.add_theme_color_override("font_color", TEXT_SECONDARY)
		sidebar_preview_label.text = "✓✓ " + text_str
		sidebar_time_label.text = time_str

	_add_chat_bubble(is_incoming, text_str, time_str)
	sfx_player.stop()
	sfx_player.stream = NOTIFICATION_STREAM
	sfx_player.play()

	is_busy = false
	waiting_for_input = true
	continue_label.text = "ENTER / SPACE"
	continue_panel.visible = true


func _add_chat_bubble(is_incoming: bool, text_str: String, time_str: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN if is_incoming else BoxContainer.ALIGNMENT_END
	chat_vbox.add_child(row)

	var bubble := PanelContainer.new()
	var col := INCOMING_BUBBLE_COLOR if is_incoming else OUTGOING_BUBBLE_COLOR
	bubble.add_theme_stylebox_override("panel", _make_box(col, Color.TRANSPARENT, 20, 0))
	row.add_child(bubble)

	var vb := VBoxContainer.new()
	bubble.add_child(vb)

	var lbl := Label.new()
	lbl.text = text_str
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(960.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_font_override("font", FREDOKA_FONT)
	lbl.add_theme_color_override("font_color", TEXT_PRIMARY)
	vb.add_child(lbl)

	var meta := Label.new()
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.text = time_str if is_incoming else (time_str + "  ✓✓")
	meta.add_theme_font_size_override("font_size", 24)
	meta.add_theme_font_override("font", FREDOKA_FONT)
	meta.add_theme_color_override("font_color", TEXT_SECONDARY)
	vb.add_child(meta)


func _fits_in_label(candidate: String, target_label: Label, max_height: float) -> bool:
	target_label.text = candidate
	var lines := target_label.get_line_count()
	var line_h := float(target_label.get_line_height())
	var line_spacing := float(target_label.get_theme_constant("line_spacing"))
	var total_h := float(lines) * line_h + float(maxi(0, lines - 1)) * line_spacing
	return total_h <= max_height


func _split_text_for_box(raw_text: String, is_mind: bool) -> Array[String]:
	if raw_text.is_empty():
		return []
	var has_start := is_mind or raw_text.begins_with("*")
	var has_end := is_mind or raw_text.ends_with("*")
	var inner := raw_text.trim_prefix("*").trim_suffix("*")

	var target_label := mind_label if is_mind else dialogue_label
	var max_height := target_label.size.y - 24.0

	var full_marked := ("*" if has_start else "") + inner + ("*" if has_end else "")
	if _fits_in_label(full_marked, target_label, max_height):
		return [full_marked]

	var pages: Array[String] = []
	var chunk := ""
	for word in inner.split(" "):
		var candidate := word if chunk.is_empty() else chunk + " " + word
		var marked := ("*" if has_start else "") + candidate + ("*" if has_end else "")
		if not chunk.is_empty() and not _fits_in_label(marked, target_label, max_height):
			pages.append(("*" if has_start else "") + chunk)
			has_start = false
			chunk = word
		else:
			chunk = candidate

	if not chunk.is_empty():
		pages.append(("*" if has_start else "") + chunk + ("*" if has_end else ""))
	return pages


func _handle_vn_step(step: Dictionary) -> void:
	chat_layer.visible = false
	news_layer.visible = false
	vn_layer.visible = true
	menu_hint_panel.visible = true
	continue_panel.visible = false

	var tex: Texture2D = step.get("bg", null)
	if tex != null:
		bg_rect.texture = tex
	elif step.get("stars_blink", false):
		bg_rect.texture = tex_sky_no_lights

	if step.get("open_eyes", false):
		await _animate_open_eyes()
	elif step.get("blink_eyes", false):
		await _animate_blink_eyes()

	if step.has("sfx") and step["sfx"] != null:
		sfx_player.stop()
		sfx_player.stream = step["sfx"]
		sfx_player.play()

	if step.has("loop_sfx") and step["loop_sfx"] != null:
		var st: AudioStream = step["loop_sfx"]
		if st is AudioStreamMP3:
			st.loop = true
		loop_sfx_player.stream = st
		loop_sfx_player.volume_db = 0.0
		loop_sfx_player.play()

	if step.get("crying_sfx", false) and sfx_crying != null:
		if sfx_crying is AudioStreamMP3:
			sfx_crying.loop = true
		crying_player.stream = sfx_crying
		crying_player.volume_db = linear_to_db(1.0)
		crying_player.play(0.0)

	var sp_name: String = step.get("speaker", "")
	var sp_col: Color = step.get("color", JAMMY_COLOR)
	var is_ocd: bool = step.get("is_ocd_takeover", false)

	speaker_label.text = sp_name
	speaker_label.add_theme_color_override("font_color", sp_col)
	dialogue_panel.add_theme_stylebox_override("panel", _make_box(MIND_PANEL_COLOR if is_ocd else PANEL_COLOR, sp_col, 18, 3))
	speaker_panel.add_theme_stylebox_override("panel", _make_tab(MIND_PANEL_COLOR if is_ocd else SPEAKER_BG_COLOR, sp_col))
	dialogue_label.add_theme_font_override("font", ROCK_SALT_FONT if is_ocd else FREDOKA_FONT)
	dialogue_label.add_theme_color_override("font_color", MIND_COLOR if is_ocd else TEXT_COLOR)

	var main_txt: String = step.get("main", "")
	var mind_txt: String = step.get("mind", "")

	main_pages = _split_text_for_box(main_txt, false)
	mind_pages = _split_text_for_box(mind_txt, true)
	page_index = 0
	_show_current_vn_page()


func _show_current_vn_page() -> void:
	var total_pages := maxi(main_pages.size(), mind_pages.size())
	if total_pages == 0:
		dialogue_panel.visible = false
		speaker_panel.visible = false
		mind_panel.visible = false
		is_typing = false
		waiting_for_input = true
		continue_label.text = "ENTER / SPACE"
		continue_panel.visible = true
		return

	if page_index >= total_pages:
		if current_index >= timeline.size() - 1:
			_return_to_main_menu()
		else:
			_run_step(current_index + 1)
		return

	continue_panel.visible = false
	var has_main := page_index < main_pages.size()
	var has_mind := page_index < mind_pages.size()

	dialogue_panel.visible = has_main
	speaker_panel.visible = has_main and not speaker_label.text.is_empty()
	mind_panel.visible = has_mind

	var main_target := main_pages[page_index] if has_main else ""
	var mind_target := mind_pages[page_index] if has_mind else ""

	dialogue_label.text = ""
	mind_label.text = ""
	is_typing = true
	waiting_for_input = false
	typing_token += 1
	_type_words(typing_token, main_target, mind_target)


func _type_words(token: int, main_txt: String, mind_txt: String) -> void:
	var mw := main_txt.split(" ") if not main_txt.is_empty() else PackedStringArray()
	var rw := mind_txt.split(" ") if not mind_txt.is_empty() else PackedStringArray()
	var total := maxi(mw.size(), rw.size())

	for i in range(total):
		if token != typing_token:
			return
		if i < mw.size():
			dialogue_label.text += ("" if i == 0 else " ") + mw[i]
		if i < rw.size():
			mind_label.text += ("" if i == 0 else " ") + rw[i]
		await get_tree().create_timer(0.042).timeout

	if token == typing_token:
		is_typing = false
		waiting_for_input = true
		continue_label.text = "ENTER / SPACE"
		continue_panel.visible = true


func _handle_panic_crisis() -> void:
	is_busy = true
	vn_layer.visible = false
	chat_layer.visible = false
	continue_panel.visible = false
	news_layer.visible = true

	await get_tree().create_timer(4.5).timeout
	var tw1 := create_tween()
	tw1.tween_property(comment1_highlight, "size:x", 640.0, 0.75)
	await tw1.finished
	await get_tree().create_timer(3.2).timeout

	shake_intensity = 6.0
	dark_vignette.color = Color(0.2, 0.0, 0.0, 0.22)
	var tw2 := create_tween()
	tw2.tween_property(comment2_highlight, "size:x", 920.0, 0.75)
	await tw2.finished
	await get_tree().create_timer(3.8).timeout

	shake_intensity = 18.0
	var panic_quotes := [
		"*SON OF THE DEVIL*",
		"*UNGRATEFUL CLOWN*",
		"*GOING AGAINST NATURE*",
		"*NOBODY LOVES YOU*",
		"*SMILE AND PRETEND*",
		"*WHERE'S THE BAD PART?*",
		"*IT'S ALL IN YOUR HEAD*",
		"*YOU HAVE NO FRIENDS*"
	]

	for i in range(18):
		var lbl := Label.new()
		lbl.text = panic_quotes[i % panic_quotes.size()]
		lbl.add_theme_font_override("font", ROCK_SALT_FONT)
		lbl.add_theme_font_size_override("font_size", rng.randi_range(44, 86))
		lbl.add_theme_color_override("font_color", Color("#ff1e27"))
		lbl.position = Vector2(rng.randf_range(100.0, 2600.0), rng.randf_range(100.0, 1800.0))
		lbl.rotation_degrees = rng.randf_range(-18.0, 18.0)
		panic_overlay.add_child(lbl)

		dark_vignette.color = Color(0.0, 0.0, 0.0, 0.65 if i % 2 == 0 else 0.15)
		await get_tree().create_timer(0.38).timeout

	news_layer.visible = false
	if tex_scene9 != null:
		bg_rect.texture = tex_scene9

	for i in range(16):
		var lbl := Label.new()
		lbl.text = "*YOU HAVE NO REAL FRIENDS — YOU'RE ALONE*" if i % 2 == 0 else panic_quotes[i % panic_quotes.size()]
		lbl.add_theme_font_override("font", ROCK_SALT_FONT)
		lbl.add_theme_font_size_override("font_size", rng.randi_range(48, 92))
		lbl.add_theme_color_override("font_color", Color("#ff2a2a"))
		lbl.position = Vector2(rng.randf_range(80.0, 2400.0), rng.randf_range(80.0, 1800.0))
		panic_overlay.add_child(lbl)
		dark_vignette.color = Color(0.0, 0.0, 0.0, 0.72 if i % 2 == 1 else 0.18)
		await get_tree().create_timer(0.32).timeout

	for child in panic_overlay.get_children():
		child.queue_free()
	shake_intensity = 0.0
	dark_vignette.color = Color(0, 0, 0, 0)
	if tex_pills != null:
		bg_rect.texture = tex_pills
	await get_tree().create_timer(4.5).timeout

	is_busy = false
	_run_step(current_index + 1)


func _handle_hospital_blackout() -> void:
	is_busy = true
	vn_layer.visible = false
	chat_layer.visible = false
	news_layer.visible = false
	continue_panel.visible = false
	bg_rect.visible = false

	if is_instance_valid(loop_sfx_player):
		loop_sfx_player.stop()

	await get_tree().create_timer(20.0).timeout

	if sfx_hospital != null:
		if sfx_hospital is AudioStreamMP3:
			sfx_hospital.loop = true
		loop_sfx_player.stream = sfx_hospital
		loop_sfx_player.volume_db = 0.0
		loop_sfx_player.play()

	if tex_hospital != null:
		bg_rect.texture = tex_hospital
	bg_rect.visible = true

	top_eyelid.position.y = 0.0
	bottom_eyelid.position.y = BASE_SIZE.y * 0.5
	eyelid_layer.visible = true

	is_busy = false
	_run_step(current_index + 1)


func _animate_open_eyes() -> void:
	eyelid_layer.visible = true
	top_eyelid.position.y = 0.0
	bottom_eyelid.position.y = BASE_SIZE.y * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(top_eyelid, "position:y", -BASE_SIZE.y * 0.55, 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bottom_eyelid, "position:y", BASE_SIZE.y * 1.05, 1.3).set_trans(Tween.TRANS_SINE)
	await tw.finished
	eyelid_layer.visible = false


func _animate_blink_eyes() -> void:
	eyelid_layer.visible = true
	top_eyelid.position.y = -BASE_SIZE.y * 0.55
	bottom_eyelid.position.y = BASE_SIZE.y * 1.05
	var tw_close := create_tween()
	tw_close.set_parallel(true)
	tw_close.tween_property(top_eyelid, "position:y", 0.0, 0.35)
	tw_close.tween_property(bottom_eyelid, "position:y", BASE_SIZE.y * 0.5, 0.35)
	await tw_close.finished
	await get_tree().create_timer(0.25).timeout
	var tw_open := create_tween()
	tw_open.set_parallel(true)
	tw_open.tween_property(top_eyelid, "position:y", -BASE_SIZE.y * 0.55, 0.45)
	tw_open.tween_property(bottom_eyelid, "position:y", BASE_SIZE.y * 1.05, 0.45)
	await tw_open.finished
	eyelid_layer.visible = false


func _start_ending_sequence() -> void:
	is_busy = true
	waiting_for_input = false
	vn_layer.visible = false
	continue_panel.visible = false
	menu_hint_panel.visible = false

	stars_blinking = true
	stars_fx_layer.visible = true
	sky_lights_overlay.visible = tex_sky_with_lights != null
	bg_rect.modulate = Color.WHITE
	if tex_sky_no_lights != null:
		bg_rect.texture = tex_sky_no_lights

	if is_instance_valid(ending_black_rect):
		ending_black_rect.visible = false

	if tex_hands != null:
		hands_rect.texture = tex_hands
	hands_rect.position = Vector2(0.0, BASE_SIZE.y)
	hands_rect.modulate = Color.WHITE
	hands_rect.visible = true

	ending_phase = 1
	ending_phase_elapsed = 0.0


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

	if is_busy or leave_dialog_open or ending_phase != 0:
		return

	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			pressed = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	elif event.is_action_pressed("ui_accept"):
		pressed = true

	if not pressed:
		return

	get_viewport().set_input_as_handled()

	if is_typing:
		typing_token += 1
		if page_index < main_pages.size():
			dialogue_label.text = main_pages[page_index]
		if page_index < mind_pages.size():
			mind_label.text = mind_pages[page_index]
		is_typing = false
		waiting_for_input = true
		continue_label.text = "ENTER / SPACE"
		continue_panel.visible = true
		return

	if waiting_for_input:
		waiting_for_input = false
		var step_type: String = timeline[current_index].get("type", "vn")
		if step_type == "vn" and maxi(main_pages.size(), mind_pages.size()) > 0:
			page_index += 1
			_show_current_vn_page()
		elif current_index >= timeline.size() - 1:
			_return_to_main_menu()
		else:
			_run_step(current_index + 1)


func _make_box(bg_col: Color, border_col: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.set_border_width_all(border_w)
		s.border_color = border_col
	return s


func _make_tab(bg_col: Color, accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.border_width_left = 3
	s.border_width_top = 3
	s.border_width_right = 3
	s.border_color = accent
	return s
