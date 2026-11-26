extends Node2D

signal nivel_completado

# --- AJUSTES RÁPIDOS EN EL INSPECTOR DE LEVEL2 ---
@export var background_texture: Texture2D
@export_file("*.tscn") var siguiente_escena: String = "" # Si se deja vacío, busca scene15.tscn automáticamente
@export var piso_y: float = 1820.0                        # Altura de la banqueta donde pisan los personajes
@export var escala_gato: float = 1.0                      # Tamaño de Kitty (su ancho define cada paso)
@export var escala_persona: float = 1.0                   # Tamaño de la persona y la bolsa
@export var tiempo_inicial: float = 5.0                   # Tiempo en el primer paso
@export var tiempo_minimo: float = 2.7                    # Tiempo en el último paso (dificultad suavizada)

# --- ESTILO HOMOGENIZADO CON VISUAL_NOVEL_3.GD ---
const BASE_SIZE := Vector2(3840.0, 2160.0)
const TEXT_COLOR := Color("#fff9f0")
const PANEL_COLOR := Color(0.14, 0.16, 0.20, 0.94)
const SPEAKER_BG_COLOR := Color(0.12, 0.14, 0.18, 0.96)
const ACCENT_COLOR := Color("#fff9f0")
const GOLD_ACCENT := Color("#f5d08a")
const SKY_ACCENT := Color("#8ab4f8")
const MIND_COLOR := Color("#ff666b")
const KITTY_COLOR := Color("#ffb7c5")

const INSTRUCTION_BG_COLOR := Color(0.11, 0.12, 0.16, 0.95)
const INSTRUCTION_BORDER_COLOR := Color(1.0, 0.98, 0.94, 0.45)
const INSTRUCTION_TEXT_COLOR := Color("#fff9f0")

const DIALOGUE_PANEL_SIZE := Vector2(1240.0, 230.0)
const DIALOGUE_PANEL_POS := Vector2(1300.0, 960.0)
const SPEAKER_PANEL_SIZE := Vector2(300.0, 62.0)

const FREDOKA_FONT = preload("res://fonts/Fredoka-Regular.ttf")
const MEOW_STREAM = preload("res://assets/sounds/meow.mp3")
const CATS_FIGHTING_STREAM = preload("res://assets/sounds/catsFighting.mp3")

# --- TEXTURAS DE TUS PERSONAJES ---
const TEX_KITTY = preload("res://assets/characters/kitty.png")
const TEX_PERSON_BAG = preload("res://assets/characters/personWithBag.png")
const TEX_PERSON_FLY = preload("res://assets/characters/personFromLevel2.png")
const TEX_BAG = preload("res://assets/characters/bag.png")

# --- NODOS CREADOS POR CÓDIGO ---
var background: Sprite2D
var kitty: Sprite2D
var person_with_bag: Sprite2D
var person_flying: Sprite2D
var bag_flying: Sprite2D
var camera: Camera2D
var meow_dialogue_player: AudioStreamPlayer
var meow_step_player: AudioStreamPlayer
var cats_fighting_player: AudioStreamPlayer

# --- ESTADO DEL MINIJUEGO ---
enum Estado {
	DIALOGO_KITTY,
	INSTRUCCION,
	JUGANDO,
	ANIMANDO_PASO,
	FINAL_VOLANDO,
	DIALOGO_FINAL,
	INSTRUCCION_FINAL
}
var estado_actual: Estado = Estado.DIALOGO_KITTY
var transicionando_escena: bool = false

const VOCALES: Array[String] = ["A", "E", "I", "O", "U"]
var teclas_objetivo: Array[String] = []
var teclas_completadas: Array[bool] = [false, false, false, false]
var teclas_sostenidas: Dictionary = {} # Evita presiones simultáneas o repetición mientras se mantiene pulsada

var start_x: float = 450.0
var ancho_paso: float = 358.0
var pasos_hasta_objetivo: int = 10
var meta_choque_x: float = 0.0
var kitty_base_y: float = 0.0
var ronda_actual: int = 0
var tiempo_ronda_actual: float = 5.0
var tiempo_restante: float = 5.0

# Físicas y efectos de choque
var vel_persona: Vector2 = Vector2.ZERO
var vel_bolsa: Vector2 = Vector2.ZERO
var bolsa_suelo_y: float = 0.0
var bolsa_rebotes: int = 0
var bolsa_detenida: bool = false
var shake_intensidad: float = 0.0

# --- VARIABLES DE DIÁLOGO ---
const KITTY_TEXT := "Hmmm... Today's a good day to steal things by meow-crashing into people!"
const KITTY_WIN_TEXT := "Hehehe! Heist accomplished, the bag is mine now!"
var texto_dialogo_actual: String = KITTY_TEXT
var is_typing: bool = false
var typing_token: int = 0

# --- INTERFAZ (UI) ---
var ui_layer: CanvasLayer
var flash_rect: ColorRect
var dialogue_panel: Panel
var dialogue_label: Label
var speaker_panel: Panel
var speaker_label: Label

# Recordatorio perpetuo de menú (solo ESC) + modal de confirmación
var perpetual_hint_panel: PanelContainer
var perpetual_hint_label: Label
var leave_confirm_overlay: ColorRect
var leave_confirm_panel: PanelContainer
var leave_yes_btn: Button
var leave_no_btn: Button
var leave_dialog_open: bool = false

# Indicaciones atractivas del minijuego
var panel_instruccion_top: PanelContainer
var label_instruccion_top: Label
var barra_tiempo: ProgressBar
var barra_fill_style: StyleBoxFlat
var hbox_teclas: HBoxContainer
var cajas_teclas: Array[PanelContainer] = []
var labels_teclas: Array[Label] = []
var labels_indice_tecla: Array[Label] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	crear_escenario_y_personajes()
	construir_ui()
	construir_leave_confirm_ui()
	_aplicar_guardado_cargado()
	_guardar_estado_nivel2()
	mostrar_dialogo_kitty(KITTY_TEXT, false)


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

	var saved_ronda: int = -1
	if extra_data.has("ronda_actual"):
		saved_ronda = int(extra_data["ronda_actual"])
	elif extra_data.has("step"):
		saved_ronda = int(extra_data["step"])

	if saved_ronda >= 0:
		ronda_actual = clampi(saved_ronda, 0, maxi(pasos_hasta_objetivo - 1, 0))
		kitty.position.x = start_x + (ancho_paso * float(ronda_actual))
		camera.position.x = kitty.position.x + 850.0


func _guardar_estado_nivel2() -> void:
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

	var etiqueta: String = "Level 2 (Step %d/%d)" % [ronda_actual, maxi(pasos_hasta_objetivo, 1)]
	var extra_info: Dictionary = {
		"ronda_actual": ronda_actual,
		"step": ronda_actual
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


func _limpiar_borde_textura(tex: Texture2D, margen: int = 4) -> Texture2D:
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	for x in range(w):
		for y in range(margen):
			img.set_pixel(x, y, Color(0, 0, 0, 0))
			img.set_pixel(x, h - 1 - y, Color(0, 0, 0, 0))
	for y in range(h):
		for x in range(margen):
			img.set_pixel(x, y, Color(0, 0, 0, 0))
			img.set_pixel(w - 1 - x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func crear_escenario_y_personajes() -> void:
	if background_texture == null:
		for ruta in [
			"res://scenes/completed background1.png",
			"res://scenes/completed background2.png",
			"res://sprites/completed background1.png",
			"res://assets/completed background1.png",
			"res://completed background1.png"
		]:
			if ResourceLoader.exists(ruta):
				background_texture = load(ruta)
				break

	# 1. Fondo escalado al alto 4K (2160 px) sin espacios negros
	background = Sprite2D.new()
	background.centered = false
	background.position = Vector2.ZERO
	background.z_index = 0
	add_child(background)

	var ancho_mundo: float = 10105.0
	if background_texture != null:
		background.texture = background_texture
		var tex_size: Vector2 = background_texture.get_size()
		var escala_4k: float = 2160.0 / tex_size.y
		background.scale = Vector2(escala_4k, escala_4k)
		ancho_mundo = tex_size.x * escala_4k

	# 2. Gato (Kitty): cada paso equivale exactamente a 1 vez su propio ancho
	kitty = Sprite2D.new()
	kitty.texture = TEX_KITTY
	kitty.scale = Vector2(escala_gato, escala_gato)
	kitty.z_index = 2
	ancho_paso = TEX_KITTY.get_width() * escala_gato
	var alto_kitty: float = TEX_KITTY.get_height() * escala_gato
	kitty_base_y = piso_y - (alto_kitty * 0.5)
	kitty.position = Vector2(start_x, kitty_base_y)
	add_child(kitty)

	# 3. Persona con bolsa ubicada hasta el final del escenario panorámico
	person_with_bag = Sprite2D.new()
	person_with_bag.texture = _limpiar_borde_textura(TEX_PERSON_BAG, 4)
	person_with_bag.scale = Vector2(escala_persona, escala_persona)
	person_with_bag.z_index = 1
	var alto_persona: float = TEX_PERSON_BAG.get_height() * escala_persona
	var persona_y: float = piso_y - (alto_persona * 0.5)
	var persona_x: float = ancho_mundo - 650.0
	person_with_bag.position = Vector2(persona_x, persona_y)
	add_child(person_with_bag)

	# Calcular cuántos pasos de 1 cuerpo de ancho cubren todo el recorrido hasta chocarla
	var distancia_contacto: float = ancho_paso * 0.65
	meta_choque_x = persona_x - distancia_contacto
	pasos_hasta_objetivo = maxi(1, int(round((meta_choque_x - start_x) / ancho_paso)))

	# 4. Sprites separados para el choque final
	person_flying = Sprite2D.new()
	person_flying.texture = _limpiar_borde_textura(TEX_PERSON_FLY, 4)
	person_flying.scale = Vector2(escala_persona, escala_persona)
	person_flying.z_index = 4
	person_flying.visible = false
	add_child(person_flying)

	bag_flying = Sprite2D.new()
	bag_flying.texture = _limpiar_borde_textura(TEX_BAG, 4)
	bag_flying.scale = Vector2(escala_persona, escala_persona)
	bag_flying.z_index = 3
	bag_flying.visible = false
	add_child(bag_flying)

	# 5. Cámara 2D limitada al ancho exacto del escenario
	camera = Camera2D.new()
	camera.enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_bottom = 2160
	camera.limit_right = int(ancho_mundo)
	camera.position = Vector2(start_x + 1200.0, 1080.0)
	add_child(camera)

	# 6. Reproductores de sonido
	meow_dialogue_player = AudioStreamPlayer.new()
	meow_dialogue_player.stream = MEOW_STREAM
	add_child(meow_dialogue_player)

	meow_step_player = AudioStreamPlayer.new()
	meow_step_player.stream = MEOW_STREAM
	add_child(meow_step_player)

	cats_fighting_player = AudioStreamPlayer.new()
	cats_fighting_player.stream = CATS_FIGHTING_STREAM
	add_child(cats_fighting_player)


func construir_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	# Destello de impacto
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1.0, 0.96, 0.78, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.z_index = 20
	ui_layer.add_child(flash_rect)

	# Recordatorio perpetuo de menú: mismo contraste que en visual_novel_3.gd
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
	ui_layer.add_child(perpetual_hint_panel)

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

	# --- 1. CAJA DE DIÁLOGO E INSTRUCCIÓN HOMOGENIZADA ---
	dialogue_panel = Panel.new()
	dialogue_panel.position = DIALOGUE_PANEL_POS
	dialogue_panel.size = DIALOGUE_PANEL_SIZE
	dialogue_panel.z_index = 10
	ui_layer.add_child(dialogue_panel)

	speaker_panel = Panel.new()
	speaker_panel.position = Vector2(DIALOGUE_PANEL_POS.x + 36.0, DIALOGUE_PANEL_POS.y - SPEAKER_PANEL_SIZE.y + 2.0)
	speaker_panel.size = SPEAKER_PANEL_SIZE
	speaker_panel.z_index = 11
	speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, KITTY_COLOR))
	ui_layer.add_child(speaker_panel)

	speaker_label = Label.new()
	speaker_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.text = "Kitty"
	speaker_label.add_theme_font_size_override("font_size", 36)
	speaker_label.add_theme_font_override("font", FREDOKA_FONT)
	speaker_label.add_theme_color_override("font_color", KITTY_COLOR)
	speaker_label.add_theme_color_override("font_shadow_color", Color("#000000e6"))
	speaker_label.add_theme_constant_override("shadow_offset_x", 2)
	speaker_label.add_theme_constant_override("shadow_offset_y", 2)
	speaker_panel.add_child(speaker_label)

	dialogue_label = Label.new()
	dialogue_label.position = Vector2(44, 24)
	dialogue_label.size = Vector2(DIALOGUE_PANEL_SIZE.x - 88.0, DIALOGUE_PANEL_SIZE.y - 48.0)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.add_theme_font_override("font", FREDOKA_FONT)
	dialogue_panel.add_child(dialogue_label)

	# --- 2. INSTRUCCIÓN SUPERIOR DURANTE EL MINIJUEGO ---
	panel_instruccion_top = PanelContainer.new()
	panel_instruccion_top.position = Vector2(1170.0, 42.0)
	panel_instruccion_top.custom_minimum_size = Vector2(1500.0, 118.0)
	panel_instruccion_top.add_theme_stylebox_override("panel", _make_top_banner_style())
	panel_instruccion_top.visible = false
	ui_layer.add_child(panel_instruccion_top)

	label_instruccion_top = Label.new()
	label_instruccion_top.text = "Press the indicated keys"
	label_instruccion_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_instruccion_top.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_instruccion_top.add_theme_font_override("font", FREDOKA_FONT)
	label_instruccion_top.add_theme_font_size_override("font_size", 46)
	label_instruccion_top.add_theme_color_override("font_color", INSTRUCTION_TEXT_COLOR)
	label_instruccion_top.add_theme_constant_override("outline_size", 4)
	label_instruccion_top.add_theme_color_override("font_outline_color", Color("#08080a"))
	panel_instruccion_top.add_child(label_instruccion_top)

	# --- 3. BARRA DEL TEMPORIZADOR ---
	barra_tiempo = ProgressBar.new()
	barra_tiempo.min_value = 0.0
	barra_tiempo.max_value = tiempo_inicial
	barra_tiempo.value = tiempo_inicial
	barra_tiempo.show_percentage = false
	barra_tiempo.position = Vector2(1370.0, 178.0)
	barra_tiempo.size = Vector2(1100.0, 34.0)
	barra_tiempo.visible = false

	var bg_bar := StyleBoxFlat.new()
	bg_bar.bg_color = Color(0.11, 0.12, 0.16, 0.90)
	bg_bar.set_corner_radius_all(16)
	bg_bar.border_width_left = 2
	bg_bar.border_width_top = 2
	bg_bar.border_width_right = 2
	bg_bar.border_width_bottom = 2
	bg_bar.border_color = Color(1.0, 0.98, 0.94, 0.35)
	barra_tiempo.add_theme_stylebox_override("background", bg_bar)

	barra_fill_style = StyleBoxFlat.new()
	barra_fill_style.bg_color = Color(0.24, 0.82, 0.46, 0.96)
	barra_fill_style.set_corner_radius_all(14)
	barra_tiempo.add_theme_stylebox_override("fill", barra_fill_style)
	ui_layer.add_child(barra_tiempo)

	# --- 4. CONTENEDOR ATRACTIVO DE LAS 4 VOCALES (ESTILO KEYCAP) ---
	hbox_teclas = HBoxContainer.new()
	hbox_teclas.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_teclas.add_theme_constant_override("separation", 44)
	hbox_teclas.position = Vector2(1340.0, 238.0)
	hbox_teclas.size = Vector2(1160.0, 175.0)
	hbox_teclas.visible = false
	ui_layer.add_child(hbox_teclas)

	for i in range(4):
		var caja := PanelContainer.new()
		caja.custom_minimum_size = Vector2(162, 162)
		caja.pivot_offset = Vector2(81.0, 81.0)
		caja.add_theme_stylebox_override("panel", _make_keycap_style("idle"))

		var vbox_key := VBoxContainer.new()
		vbox_key.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox_key.add_theme_constant_override("separation", 2)
		caja.add_child(vbox_key)

		var idx_lbl := Label.new()
		idx_lbl.text = str(i + 1)
		idx_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		idx_lbl.add_theme_font_override("font", FREDOKA_FONT)
		idx_lbl.add_theme_font_size_override("font_size", 24)
		idx_lbl.add_theme_color_override("font_color", GOLD_ACCENT)
		vbox_key.add_child(idx_lbl)

		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", FREDOKA_FONT)
		lbl.add_theme_font_size_override("font_size", 76)
		lbl.add_theme_color_override("font_color", TEXT_COLOR)
		lbl.add_theme_constant_override("outline_size", 5)
		lbl.add_theme_color_override("font_outline_color", Color("#08080a"))
		vbox_key.add_child(lbl)

		hbox_teclas.add_child(caja)
		cajas_teclas.append(caja)
		labels_teclas.append(lbl)
		labels_indice_tecla.append(idx_lbl)


func construir_leave_confirm_ui() -> void:
	leave_confirm_overlay = ColorRect.new()
	leave_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leave_confirm_overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	leave_confirm_overlay.z_index = 120
	leave_confirm_overlay.visible = false
	leave_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(leave_confirm_overlay)

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
	teclas_sostenidas.clear()
	leave_confirm_overlay.visible = true
	leave_confirm_overlay.move_to_front()


func _close_leave_confirm() -> void:
	leave_dialog_open = false
	teclas_sostenidas.clear()
	leave_confirm_overlay.visible = false


func _go_to_start_menu() -> void:
	_guardar_estado_nivel2()
	leave_dialog_open = false
	meow_dialogue_player.stop()
	meow_step_player.stop()
	cats_fighting_player.stop()

	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr != null and save_mgr.has_method("volver_al_inicio"):
		save_mgr.volver_al_inicio()
		return

	if ResourceLoader.exists("res://main.tscn"):
		get_tree().call_deferred("change_scene_to_file", "res://main.tscn")
	elif ResourceLoader.exists("res://Main.tscn"):
		get_tree().call_deferred("change_scene_to_file", "res://Main.tscn")


func _make_top_banner_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = INSTRUCTION_BG_COLOR
	style.set_corner_radius_all(20)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.85)
	style.content_margin_left = 36.0
	style.content_margin_right = 36.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style


func _make_keycap_style(estado_tecla: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(22)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 10
	match estado_tecla:
		"done":
			style.bg_color = Color(0.16, 0.62, 0.34, 0.96)
			style.border_color = Color(0.55, 0.95, 0.68, 0.95)
		"next":
			style.bg_color = Color(0.20, 0.24, 0.34, 0.98)
			style.border_color = Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.98)
		"error":
			style.bg_color = Color(0.72, 0.16, 0.20, 0.96)
			style.border_color = Color(1.0, 0.48, 0.52, 0.95)
		_:
			style.bg_color = Color(0.13, 0.15, 0.19, 0.92)
			style.border_color = Color(SKY_ACCENT.r, SKY_ACCENT.g, SKY_ACCENT.b, 0.45)
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
	style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.75)
	return style


func mostrar_dialogo_kitty(texto: String, es_final: bool = false) -> void:
	estado_actual = Estado.DIALOGO_FINAL if es_final else Estado.DIALOGO_KITTY
	texto_dialogo_actual = texto

	dialogue_panel.visible = true
	dialogue_panel.position = DIALOGUE_PANEL_POS
	dialogue_panel.size = DIALOGUE_PANEL_SIZE

	var kitty_border := Color(KITTY_COLOR.r, KITTY_COLOR.g, KITTY_COLOR.b, 0.65)
	dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, kitty_border))

	speaker_panel.visible = true
	speaker_panel.position = Vector2(DIALOGUE_PANEL_POS.x + 36.0, DIALOGUE_PANEL_POS.y - SPEAKER_PANEL_SIZE.y + 2.0)

	dialogue_label.position = Vector2(44, 24)
	dialogue_label.size = Vector2(DIALOGUE_PANEL_SIZE.x - 88.0, DIALOGUE_PANEL_SIZE.y - 48.0)
	dialogue_label.add_theme_font_size_override("font_size", 46)
	dialogue_label.add_theme_color_override("font_color", TEXT_COLOR)
	dialogue_label.add_theme_color_override("font_shadow_color", Color("#000000f0"))
	dialogue_label.add_theme_constant_override("shadow_offset_x", 4)
	dialogue_label.add_theme_constant_override("shadow_offset_y", 4)
	dialogue_label.text = ""

	is_typing = true
	typing_token += 1
	_type_kitty_words(typing_token, texto)


func _type_kitty_words(token: int, texto: String) -> void:
	var words := texto.split(" ")
	for i in range(words.size()):
		if token != typing_token:
			return
		dialogue_label.text += ("" if i == 0 else " ") + words[i]
		if i % 3 == 0:
			meow_dialogue_player.stop()
			meow_dialogue_player.play()
		await get_tree().create_timer(0.045).timeout
	if token == typing_token:
		is_typing = false


func _mostrar_caja_instruccion(texto_instruccion: String, nuevo_estado: Estado) -> void:
	estado_actual = nuevo_estado
	speaker_panel.visible = false

	dialogue_panel.visible = true
	dialogue_panel.position = Vector2(1140.0, 900.0)
	dialogue_panel.size = Vector2(1560.0, 280.0)
	dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(INSTRUCTION_BG_COLOR, Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.85)))

	dialogue_label.position = Vector2(44, 24)
	dialogue_label.size = Vector2(1472.0, 232.0)
	dialogue_label.add_theme_font_size_override("font_size", 46)
	dialogue_label.add_theme_color_override("font_color", INSTRUCTION_TEXT_COLOR)
	dialogue_label.add_theme_constant_override("outline_size", 4)
	dialogue_label.add_theme_color_override("font_outline_color", Color("#08080a"))
	dialogue_label.add_theme_color_override("font_shadow_color", Color("#000000f0"))
	dialogue_label.add_theme_constant_override("shadow_offset_x", 3)
	dialogue_label.add_theme_constant_override("shadow_offset_y", 3)
	dialogue_label.text = texto_instruccion


func mostrar_instruccion_inicial() -> void:
	_mostrar_caja_instruccion(
		"Press the indicated keys.\nPress [ENTER] or [SPACE] to begin.",
		Estado.INSTRUCCION
	)


func mostrar_instruccion_final() -> void:
	_mostrar_caja_instruccion(
		"Press the indicated keys.\nPress [ENTER] or [SPACE] to continue.",
		Estado.INSTRUCCION_FINAL
	)


func _buscar_archivo_en_proyecto(nombres_objetivo: Array[String], carpeta: String = "res://") -> String:
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return ""

	dir.list_dir_begin()
	var item: String = dir.get_next()
	var subcarpetas: Array[String] = []

	while item != "":
		if not item.begins_with("."):
			var ruta_completa: String = (carpeta + item) if carpeta == "res://" else (carpeta + "/" + item)
			if dir.current_is_dir():
				subcarpetas.append(ruta_completa)
			else:
				for objetivo in nombres_objetivo:
					if item.to_lower() == objetivo.to_lower():
						dir.list_dir_end()
						return ruta_completa
		item = dir.get_next()
	dir.list_dir_end()

	for sub in subcarpetas:
		var encontrado: String = _buscar_archivo_en_proyecto(nombres_objetivo, sub)
		if not encontrado.is_empty():
			return encontrado
	return ""


func _continuar_siguiente_escena() -> void:
	if transicionando_escena:
		return
	transicionando_escena = true

	var destino: String = siguiente_escena.strip_edges()
	if destino.is_empty() or not ResourceLoader.exists(destino):
		for candidata in [
			"res://scenes/scene15.tscn",
			"res://scene15.tscn",
			"res://scenes/scene_15.tscn",
			"res://scene_15.tscn"
		]:
			if ResourceLoader.exists(candidata):
				destino = candidata
				break

	if destino.is_empty() or not ResourceLoader.exists(destino):
		destino = _buscar_archivo_en_proyecto(["scene15.tscn", "scene_15.tscn"])

	if destino.is_empty() or not ResourceLoader.exists(destino):
		push_warning("No se encontró scene15.tscn en el proyecto.")
		transicionando_escena = false
		return

	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null and save_manager.has_method("guardar_progreso"):
		save_manager.guardar_progreso(destino, "Scene 15", {"entry_index": 0, "step": 0}, _obtener_slot_activo())

	nivel_completado.emit()

	var eye_trans: Node = get_node_or_null("/root/EyeTransition")
	if eye_trans == null:
		var ruta_eye: String = "res://EyeTransition.gd" if ResourceLoader.exists("res://EyeTransition.gd") else _buscar_archivo_en_proyecto(["EyeTransition.gd"])
		if not ruta_eye.is_empty() and ResourceLoader.exists(ruta_eye):
			eye_trans = load(ruta_eye).new()
			get_tree().root.add_child(eye_trans)
			await get_tree().process_frame

	if eye_trans != null and eye_trans.has_method("ir_a_escena_cerrando_ojos"):
		eye_trans.ir_a_escena_cerrando_ojos(destino)
	else:
		get_tree().change_scene_to_file(destino)


func iniciar_gameplay() -> void:
	dialogue_panel.visible = false
	panel_instruccion_top.visible = true
	barra_tiempo.visible = true
	hbox_teclas.visible = true
	teclas_sostenidas.clear()
	generar_nueva_combinacion()


func _indice_siguiente_tecla() -> int:
	for i in range(4):
		if not teclas_completadas[i]:
			return i
	return -1


func generar_nueva_combinacion() -> void:
	estado_actual = Estado.JUGANDO

	var progreso: float = clampf(float(ronda_actual) / float(maxi(pasos_hasta_objetivo - 1, 1)), 0.0, 1.0)
	tiempo_ronda_actual = lerpf(tiempo_inicial, tiempo_minimo, progreso)
	tiempo_restante = tiempo_ronda_actual
	barra_tiempo.max_value = tiempo_ronda_actual
	barra_tiempo.value = tiempo_ronda_actual

	barra_fill_style.bg_color = Color(0.24, 0.82, 0.46, 0.96).lerp(Color(0.95, 0.30, 0.25, 0.96), progreso)

	teclas_objetivo.clear()
	teclas_completadas = [false, false, false, false]

	for i in range(4):
		var vocal_random: String = VOCALES.pick_random()
		teclas_objetivo.append(vocal_random)
		labels_teclas[i].text = vocal_random
		cajas_teclas[i].scale = Vector2.ONE
		cajas_teclas[i].position.y = 0.0

	_refrescar_aspecto_teclas()


func _refrescar_aspecto_teclas() -> void:
	var siguiente_idx: int = _indice_siguiente_tecla()
	for i in range(4):
		if teclas_completadas[i]:
			cajas_teclas[i].add_theme_stylebox_override("panel", _make_keycap_style("done"))
			labels_teclas[i].add_theme_color_override("font_color", TEXT_COLOR)
			labels_indice_tecla[i].add_theme_color_override("font_color", Color("#b8ffcf"))
		elif i == siguiente_idx:
			cajas_teclas[i].add_theme_stylebox_override("panel", _make_keycap_style("next"))
			labels_teclas[i].add_theme_color_override("font_color", GOLD_ACCENT)
			labels_indice_tecla[i].add_theme_color_override("font_color", GOLD_ACCENT)
		else:
			cajas_teclas[i].add_theme_stylebox_override("panel", _make_keycap_style("idle"))
			labels_teclas[i].add_theme_color_override("font_color", TEXT_COLOR)
			labels_indice_tecla[i].add_theme_color_override("font_color", SKY_ACCENT)


func _animar_acierto_tecla(indice: int) -> void:
	_refrescar_aspecto_teclas()
	var pop := create_tween()
	pop.tween_property(cajas_teclas[indice], "scale", Vector2(1.14, 0.90), 0.06)
	pop.parallel().tween_property(cajas_teclas[indice], "position:y", 8.0, 0.06)
	pop.tween_property(cajas_teclas[indice], "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK)
	pop.parallel().tween_property(cajas_teclas[indice], "position:y", 0.0, 0.10)


func _animar_error_tecla(indice: int) -> void:
	if indice < 0 or indice >= cajas_teclas.size():
		return
	cajas_teclas[indice].add_theme_stylebox_override("panel", _make_keycap_style("error"))
	var sacudida := create_tween()
	sacudida.tween_property(cajas_teclas[indice], "position:x", cajas_teclas[indice].position.x - 12.0, 0.05)
	sacudida.tween_property(cajas_teclas[indice], "position:x", cajas_teclas[indice].position.x + 12.0, 0.05)
	sacudida.tween_property(cajas_teclas[indice], "position:x", cajas_teclas[indice].position.x, 0.05)
	sacudida.tween_callback(_refrescar_aspecto_teclas)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if event.pressed:
				get_viewport().set_input_as_handled()
				if leave_dialog_open:
					_close_leave_confirm()
				else:
					_open_leave_confirm()
			return

		if not event.pressed:
			teclas_sostenidas.erase(event.keycode)
			return

	if leave_dialog_open:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				get_viewport().set_input_as_handled()
				_go_to_start_menu()
		return

	var enter_pressed := false
	var advance_pressed := false
	if event is InputEventKey:
		var is_enter: bool = event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
		enter_pressed = event.pressed and not event.echo and is_enter
		advance_pressed = event.pressed and not event.echo and (is_enter or event.keycode == KEY_SPACE)
	elif event is InputEventMouseButton:
		advance_pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT

	if estado_actual == Estado.DIALOGO_KITTY:
		if advance_pressed:
			if is_typing:
				typing_token += 1
				meow_dialogue_player.stop()
				dialogue_label.text = texto_dialogo_actual
				is_typing = false
			else:
				mostrar_instruccion_inicial()
		return

	if estado_actual == Estado.INSTRUCCION:
		if advance_pressed:
			iniciar_gameplay()
		return

	if estado_actual == Estado.DIALOGO_FINAL:
		if advance_pressed:
			if is_typing:
				typing_token += 1
				meow_dialogue_player.stop()
				dialogue_label.text = texto_dialogo_actual
				is_typing = false
			else:
				mostrar_instruccion_final()
		return

	if estado_actual == Estado.INSTRUCCION_FINAL:
		if enter_pressed or advance_pressed:
			_continuar_siguiente_escena()
		return

	if estado_actual == Estado.JUGANDO and event is InputEventKey and event.pressed and not event.echo:
		# Impide presionar varias teclas a la vez mientras otra siga sostenida
		if not teclas_sostenidas.is_empty():
			return
		if event.keycode >= KEY_A and event.keycode <= KEY_Z:
			teclas_sostenidas[event.keycode] = true
			var letra: String = OS.get_keycode_string(event.keycode).to_upper()
			verificar_tecla_presionada(letra)


func verificar_tecla_presionada(letra: String) -> void:
	var siguiente_idx: int = _indice_siguiente_tecla()
	if siguiente_idx == -1:
		return
	if teclas_objetivo[siguiente_idx] == letra:
		teclas_completadas[siguiente_idx] = true
		_animar_acierto_tecla(siguiente_idx)
		if teclas_completadas.all(func(ok): return ok):
			avanzar_un_paso()
	else:
		_animar_error_tecla(siguiente_idx)


func avanzar_un_paso() -> void:
	estado_actual = Estado.ANIMANDO_PASO
	ronda_actual += 1
	_guardar_estado_nivel2()

	meow_step_player.stop()
	meow_step_player.play()

	var es_paso_final: bool = ronda_actual >= pasos_hasta_objetivo
	var destino_x: float = meta_choque_x if es_paso_final else (start_x + (ancho_paso * float(ronda_actual)))

	var tween := create_tween()
	if es_paso_final:
		tween.tween_property(kitty, "scale", Vector2(escala_gato * 1.22, escala_gato * 0.84), 0.10)
		tween.parallel().tween_property(kitty, "position:x", destino_x, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(kitty, "position:y", kitty_base_y - 45.0, 0.11).set_ease(Tween.EASE_OUT)
		tween.tween_property(kitty, "position:y", kitty_base_y, 0.11).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(kitty, "position:x", destino_x, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(kitty, "position:y", kitty_base_y - 50.0, 0.13).set_ease(Tween.EASE_OUT)
		tween.tween_property(kitty, "position:y", kitty_base_y, 0.13).set_ease(Tween.EASE_IN)

	await tween.finished

	if es_paso_final:
		ejecutar_choque_final()
	else:
		generar_nueva_combinacion()


func fallar_y_regresar_al_inicio() -> void:
	estado_actual = Estado.ANIMANDO_PASO
	ronda_actual = 0
	teclas_sostenidas.clear()
	_guardar_estado_nivel2()

	for i in range(4):
		cajas_teclas[i].add_theme_stylebox_override("panel", _make_keycap_style("error"))
		labels_teclas[i].add_theme_color_override("font_color", TEXT_COLOR)

	var tween := create_tween()
	tween.tween_property(kitty, "position:x", start_x, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	generar_nueva_combinacion()


func ejecutar_choque_final() -> void:
	estado_actual = Estado.FINAL_VOLANDO
	panel_instruccion_top.visible = false
	barra_tiempo.visible = false
	hbox_teclas.visible = false
	_guardar_estado_nivel2()

	cats_fighting_player.stop()
	cats_fighting_player.play(10.0)

	shake_intensidad = 34.0

	flash_rect.color = Color(1.0, 0.96, 0.78, 0.65)
	var flash_tween := create_tween()
	flash_tween.tween_property(flash_rect, "color:a", 0.0, 0.28)

	var squash := create_tween()
	squash.tween_property(kitty, "scale", Vector2(escala_gato * 0.76, escala_gato * 1.28), 0.08)
	squash.tween_property(kitty, "scale", Vector2(escala_gato, escala_gato), 0.16).set_trans(Tween.TRANS_BOUNCE)

	_mostrar_texto_flotante("MEOW-CRASH!", kitty.position + Vector2(20.0, -340.0), Color("#ffdf5d"))

	person_with_bag.visible = false
	person_flying.position = person_with_bag.position
	person_flying.visible = true
	vel_persona = Vector2(1200.0, -1750.0)

	bag_flying.position = person_with_bag.position + Vector2(-45.0, -30.0)
	bag_flying.visible = true
	bolsa_rebotes = 0
	bolsa_detenida = false

	var bag_img: Image = TEX_BAG.get_image()
	if bag_img.is_compressed():
		bag_img.decompress()
	var used_rect: Rect2i = bag_img.get_used_rect()
	if used_rect.has_area():
		var offset_bottom: float = (float(used_rect.end.y) - (float(bag_img.get_height()) * 0.5)) * escala_persona
		bolsa_suelo_y = piso_y - offset_bottom
	else:
		bolsa_suelo_y = piso_y - (TEX_BAG.get_height() * escala_persona * 0.5)

	var destino_bolsa_x: float = kitty.position.x + (ancho_paso * 0.65)

	var gravedad: float = 2400.0
	var vy_inicial: float = -1150.0
	var dy: float = bolsa_suelo_y - bag_flying.position.y
	var discriminante: float = maxf((vy_inicial * vy_inicial) + (2.0 * gravedad * dy), 1.0)
	var tiempo_vuelo: float = (-vy_inicial + sqrt(discriminante)) / gravedad
	var vx_inicial: float = (destino_bolsa_x - bag_flying.position.x) / tiempo_vuelo

	vel_bolsa = Vector2(vx_inicial, vy_inicial)


func _on_bolsa_aterriza_junto_a_kitty() -> void:
	bag_flying.position.x = kitty.position.x + (ancho_paso * 0.65)
	bag_flying.rotation = 0.0

	var salto := create_tween()
	salto.tween_property(kitty, "position:y", kitty_base_y - 65.0, 0.14).set_ease(Tween.EASE_OUT)
	salto.tween_property(kitty, "position:y", kitty_base_y, 0.14).set_ease(Tween.EASE_IN)

	_mostrar_texto_flotante("STOLEN!", bag_flying.position + Vector2(-90.0, -180.0), Color("#7cf29c"))

	await get_tree().create_timer(0.45).timeout
	mostrar_dialogo_kitty(KITTY_WIN_TEXT, true)


func _mostrar_texto_flotante(texto: String, pos: Vector2, color_texto: Color) -> void:
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_override("font", FREDOKA_FONT)
	lbl.add_theme_font_size_override("font_size", 86)
	lbl.add_theme_color_override("font_color", color_texto)
	lbl.add_theme_color_override("font_outline_color", Color("#1a1412"))
	lbl.add_theme_constant_override("outline_size", 16)
	lbl.position = pos
	lbl.scale = Vector2(0.3, 0.3)
	lbl.z_index = 15
	add_child(lbl)

	var t := create_tween()
	t.tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(lbl, "position:y", lbl.position.y - 90.0, 0.85)
	t.tween_property(lbl, "modulate:a", 0.0, 0.35)
	t.tween_callback(lbl.queue_free)


func _process(delta: float) -> void:
	camera.position.x = lerp(camera.position.x, kitty.position.x + 850.0, 6.0 * delta)

	if cats_fighting_player.playing and cats_fighting_player.get_playback_position() >= 15.0:
		cats_fighting_player.stop()

	if shake_intensidad > 0.1:
		camera.offset = Vector2(
			randf_range(-shake_intensidad, shake_intensidad),
			randf_range(-shake_intensidad, shake_intensidad)
		)
		shake_intensidad = lerpf(shake_intensidad, 0.0, 10.0 * delta)
	else:
		camera.offset = Vector2.ZERO

	if leave_dialog_open:
		return

	if estado_actual == Estado.JUGANDO:
		tiempo_restante -= delta
		barra_tiempo.value = maxf(tiempo_restante, 0.0)
		if tiempo_restante <= 0.0:
			fallar_y_regresar_al_inicio()

	if estado_actual == Estado.FINAL_VOLANDO:
		var gravedad: float = 2400.0

		vel_persona.y += gravedad * delta
		person_flying.position += vel_persona * delta
		person_flying.rotation += 5.5 * delta

		if not bolsa_detenida:
			vel_bolsa.y += gravedad * delta
			bag_flying.position += vel_bolsa * delta
			bag_flying.rotation += (7.5 if bolsa_rebotes == 0 else 2.5) * delta

			if bag_flying.position.y >= bolsa_suelo_y and vel_bolsa.y > 0.0:
				bag_flying.position.y = bolsa_suelo_y
				if bolsa_rebotes < 1:
					bolsa_rebotes += 1
					vel_bolsa.y = -340.0
					vel_bolsa.x = 0.0
				else:
					vel_bolsa = Vector2.ZERO
					bolsa_detenida = true
					_on_bolsa_aterriza_junto_a_kitty()
