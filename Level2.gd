extends Node2D

# --- AJUSTES RÁPIDOS EN EL INSPECTOR DE LEVEL2 ---
@export var background_texture: Texture2D
@export var piso_y: float = 1820.0            # Altura de la banqueta donde pisan los personajes
@export var escala_gato: float = 1.0          # Ajusta si quieres al gato más grande o pequeño
@export var escala_persona: float = 1.0       # Ajusta el tamaño de la persona y la bolsa
@export var total_rondas: int = 4             # Cuántas combinaciones de 4 vocales hay hasta llegar a la persona
@export var tiempo_por_ronda: float = 5.0     # Límite de 5 segundos por combinación
@export var distancia_choque: float = 150.0   # Distancia a la que el gato impacta a la persona

# --- ESTILO HOMOGENIZADO CON VISUAL_NOVEL.GD ---
const TEXT_COLOR := Color("#fff9f0")
const PANEL_COLOR := Color(0.22, 0.23, 0.25, 0.50)
const SPEAKER_BG_COLOR := Color(0.18, 0.19, 0.21, 0.68)
const KITTY_COLOR := Color("#ffb7c5")
const INSTRUCTION_BG_COLOR := Color(0.95, 0.94, 0.91, 0.78)
const INSTRUCTION_BORDER_COLOR := Color(0.1, 0.1, 0.1, 0.25)
const INSTRUCTION_TEXT_COLOR := Color("#161616")

const DIALOGUE_PANEL_SIZE := Vector2(1240.0, 230.0)
const DIALOGUE_PANEL_POS := Vector2(1300.0, 960.0)
const SPEAKER_PANEL_SIZE := Vector2(300.0, 62.0)

const FREDOKA_FONT = preload("res://fonts/Fredoka-Regular.ttf")
const NORMAL_DIALOGUE_STREAM = preload("res://assets/sounds/Soft_pencil_tap_on_n_#1-1794378651940.mp3")

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
var typewriter_player: AudioStreamPlayer

# --- ESTADO DEL MINIJUEGO ---
enum Estado { DIALOGO_KITTY, INSTRUCCION, JUGANDO, ANIMANDO_PASO, FINAL_VOLANDO }
var estado_actual: Estado = Estado.DIALOGO_KITTY

const VOCALES: Array[String] = ["A", "E", "I", "O", "U"]
var teclas_objetivo: Array[String] = []
var teclas_completadas: Array[bool] = [false, false, false, false]

var start_x: float = 450.0
var kitty_base_y: float = 0.0
var ronda_actual: int = 0
var tiempo_restante: float = 5.0

var vel_persona: Vector2 = Vector2.ZERO
var vel_bolsa: Vector2 = Vector2.ZERO

# --- VARIABLES DE DIÁLOGO ---
const KITTY_TEXT := "Hmmm... Today's a good day to steal things by meow-crashing into people!"
var is_typing: bool = false
var typing_token: int = 0

# --- INTERFAZ (UI) ---
var ui_layer: CanvasLayer
var dialogue_panel: Panel
var dialogue_label: Label
var speaker_panel: Panel
var speaker_label: Label

var panel_instruccion_top: Panel
var label_instruccion_top: Label
var barra_tiempo: ProgressBar
var cajas_teclas: Array[PanelContainer] = []
var labels_teclas: Array[Label] = []


func _ready() -> void:
	crear_escenario_y_personajes()
	construir_ui()
	mostrar_dialogo_kitty()


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
	
	# Fondo escalado al alto 4K (2160 px) sin espacios negros
	background = Sprite2D.new()
	background.centered = false
	background.position = Vector2.ZERO
	add_child(background)
	
	var ancho_mundo: float = 10105.0
	if background_texture != null:
		background.texture = background_texture
		var tex_size: Vector2 = background_texture.get_size()
		var escala_4k: float = 2160.0 / tex_size.y
		background.scale = Vector2(escala_4k, escala_4k)
		ancho_mundo = tex_size.x * escala_4k
	
	# Gato (Kitty) con su textura recortada directamente
	kitty = Sprite2D.new()
	kitty.texture = TEX_KITTY
	kitty.scale = Vector2(escala_gato, escala_gato)
	var alto_kitty: float = TEX_KITTY.get_height() * escala_gato
	kitty_base_y = piso_y - (alto_kitty * 0.5)
	kitty.position = Vector2(start_x, kitty_base_y)
	add_child(kitty)
	
	# Persona con bolsa
	person_with_bag = Sprite2D.new()
	person_with_bag.texture = _limpiar_borde_textura(TEX_PERSON_BAG, 4)
	person_with_bag.scale = Vector2(escala_persona, escala_persona)
	var alto_persona: float = TEX_PERSON_BAG.get_height() * escala_persona
	var persona_y: float = piso_y - (alto_persona * 0.5)
	var persona_x: float = ancho_mundo - 850.0
	person_with_bag.position = Vector2(persona_x, persona_y)
	add_child(person_with_bag)
	
	# Sprites separados para el choque final
	person_flying = Sprite2D.new()
	person_flying.texture = _limpiar_borde_textura(TEX_PERSON_FLY, 4)
	person_flying.scale = Vector2(escala_persona, escala_persona)
	person_flying.visible = false
	add_child(person_flying)
	
	bag_flying = Sprite2D.new()
	bag_flying.texture = _limpiar_borde_textura(TEX_BAG, 4)
	bag_flying.scale = Vector2(escala_persona, escala_persona)
	bag_flying.visible = false
	add_child(bag_flying)
	
	# Cámara 2D limitada al ancho exacto del escenario
	camera = Camera2D.new()
	camera.enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_bottom = 2160
	camera.limit_right = int(ancho_mundo)
	camera.position = Vector2(start_x + 1200.0, 1080.0)
	add_child(camera)
	
	# Reproductor del sonido de diálogo
	typewriter_player = AudioStreamPlayer.new()
	add_child(typewriter_player)


func construir_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# --- 1. CAJA DE DIÁLOGO E INSTRUCCIÓN INICIAL (ESTILO VISUAL NOVEL) ---
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
	
	# --- 2. INSTRUCCIÓN SUPERIOR DURANTE EL MINIJUEGO (HOMOGENIZADA) ---
	panel_instruccion_top = Panel.new()
	panel_instruccion_top.position = Vector2(1170.0, 55.0)
	panel_instruccion_top.size = Vector2(1500.0, 105.0)
	panel_instruccion_top.add_theme_stylebox_override("panel", _make_dialogue_style(INSTRUCTION_BG_COLOR, INSTRUCTION_BORDER_COLOR))
	panel_instruccion_top.visible = false
	ui_layer.add_child(panel_instruccion_top)
	
	label_instruccion_top = Label.new()
	label_instruccion_top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label_instruccion_top.text = "Help the kitty out by pressing the keys indicated."
	label_instruccion_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_instruccion_top.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_instruccion_top.add_theme_font_override("font", FREDOKA_FONT)
	label_instruccion_top.add_theme_font_size_override("font_size", 46)
	label_instruccion_top.add_theme_color_override("font_color", INSTRUCTION_TEXT_COLOR)
	panel_instruccion_top.add_child(label_instruccion_top)
	
	# --- 3. BARRA DEL TEMPORIZADOR (5 SEGUNDOS) ---
	barra_tiempo = ProgressBar.new()
	barra_tiempo.min_value = 0.0
	barra_tiempo.max_value = tiempo_por_ronda
	barra_tiempo.value = tiempo_por_ronda
	barra_tiempo.show_percentage = false
	barra_tiempo.position = Vector2(1420.0, 185.0)
	barra_tiempo.size = Vector2(1000.0, 32.0)
	barra_tiempo.visible = false
	ui_layer.add_child(barra_tiempo)
	
	# --- 4. CONTENEDOR DE LAS 4 VOCALES ALEATORIAS (HOMOGENIZADO) ---
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 40)
	hbox.position = Vector2(1420.0, 245.0)
	hbox.size = Vector2(1000.0, 150.0)
	ui_layer.add_child(hbox)
	
	for i in range(4):
		var caja := PanelContainer.new()
		caja.custom_minimum_size = Vector2(145, 145)
		caja.pivot_offset = Vector2(72.5, 72.5)
		caja.visible = false
		caja.add_theme_stylebox_override("panel", _make_dialogue_style(Color(0.95, 0.94, 0.91, 0.88), INSTRUCTION_BORDER_COLOR))
		
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", FREDOKA_FONT)
		lbl.add_theme_font_size_override("font_size", 74)
		lbl.add_theme_color_override("font_color", INSTRUCTION_TEXT_COLOR)
		caja.add_child(lbl)
		
		hbox.add_child(caja)
		cajas_teclas.append(caja)
		labels_teclas.append(lbl)


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


func mostrar_dialogo_kitty() -> void:
	estado_actual = Estado.DIALOGO_KITTY
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
	_type_kitty_words(typing_token)


func _type_kitty_words(token: int) -> void:
	var words := KITTY_TEXT.split(" ")
	for i in range(words.size()):
		if token != typing_token:
			return
		dialogue_label.text += ("" if i == 0 else " ") + words[i]
		if i % 2 == 0:
			typewriter_player.stop()
			typewriter_player.stream = NORMAL_DIALOGUE_STREAM
			typewriter_player.play()
		await get_tree().create_timer(0.045).timeout
	if token == typing_token:
		typewriter_player.stop()
		is_typing = false


func mostrar_instruccion_inicial() -> void:
	estado_actual = Estado.INSTRUCCION
	speaker_panel.visible = false
	
	dialogue_panel.visible = true
	dialogue_panel.position = Vector2(1170.0, 920.0)
	dialogue_panel.size = Vector2(1500.0, 260.0)
	dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(INSTRUCTION_BG_COLOR, INSTRUCTION_BORDER_COLOR))
	
	dialogue_label.position = Vector2(44, 24)
	dialogue_label.size = Vector2(1412.0, 212.0)
	dialogue_label.add_theme_font_size_override("font_size", 48)
	dialogue_label.add_theme_color_override("font_color", INSTRUCTION_TEXT_COLOR)
	dialogue_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	dialogue_label.add_theme_constant_override("shadow_offset_x", 0)
	dialogue_label.add_theme_constant_override("shadow_offset_y", 0)
	dialogue_label.text = "Help the kitty out by pressing the keys indicated.\n[ENTER] or [SPACE] to begin."


func iniciar_gameplay() -> void:
	dialogue_panel.visible = false
	panel_instruccion_top.visible = true
	barra_tiempo.visible = true
	for caja in cajas_teclas:
		caja.visible = true
	generar_nueva_combinacion()


func generar_nueva_combinacion() -> void:
	estado_actual = Estado.JUGANDO
	tiempo_restante = tiempo_por_ronda
	barra_tiempo.value = tiempo_por_ronda
	teclas_objetivo.clear()
	teclas_completadas = [false, false, false, false]
	
	for i in range(4):
		var vocal_random: String = VOCALES.pick_random()
		teclas_objetivo.append(vocal_random)
		labels_teclas[i].text = vocal_random
		cajas_teclas[i].scale = Vector2.ONE
		actualizar_color_tecla(i, false)


func actualizar_color_tecla(indice: int, presionada: bool) -> void:
	if presionada:
		cajas_teclas[indice].add_theme_stylebox_override(
			"panel",
			_make_dialogue_style(Color(0.20, 0.76, 0.36, 0.94), Color(0.10, 0.45, 0.18, 0.85))
		)
		labels_teclas[indice].add_theme_color_override("font_color", TEXT_COLOR)
		var pop := create_tween()
		pop.tween_property(cajas_teclas[indice], "scale", Vector2(1.15, 1.15), 0.08)
		pop.tween_property(cajas_teclas[indice], "scale", Vector2.ONE, 0.08)
	else:
		cajas_teclas[indice].add_theme_stylebox_override(
			"panel",
			_make_dialogue_style(Color(0.95, 0.94, 0.91, 0.88), INSTRUCTION_BORDER_COLOR)
		)
		labels_teclas[indice].add_theme_color_override("font_color", INSTRUCTION_TEXT_COLOR)


func _unhandled_input(event: InputEvent) -> void:
	var advance_pressed := false
	if event is InputEventKey:
		advance_pressed = event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)
	elif event is InputEventMouseButton:
		advance_pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	
	if estado_actual == Estado.DIALOGO_KITTY:
		if advance_pressed:
			if is_typing:
				typing_token += 1
				typewriter_player.stop()
				dialogue_label.text = KITTY_TEXT
				is_typing = false
			else:
				mostrar_instruccion_inicial()
		return
	
	if estado_actual == Estado.INSTRUCCION:
		if advance_pressed:
			iniciar_gameplay()
		return
	
	if estado_actual == Estado.JUGANDO and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_A and event.keycode <= KEY_Z:
			var letra: String = OS.get_keycode_string(event.keycode).to_upper()
			verificar_tecla_presionada(letra)


func verificar_tecla_presionada(letra: String) -> void:
	for i in range(4):
		if not teclas_completadas[i] and teclas_objetivo[i] == letra:
			teclas_completadas[i] = true
			actualizar_color_tecla(i, true)
			if teclas_completadas.all(func(ok): return ok):
				avanzar_un_paso()
			return
	
	if letra in teclas_objetivo:
		return
	
	fallar_y_regresar_al_inicio()


func avanzar_un_paso() -> void:
	estado_actual = Estado.ANIMANDO_PASO
	ronda_actual += 1
	
	var meta_x: float = person_with_bag.position.x - distancia_choque
	var distancia_un_paso: float = (meta_x - start_x) / float(total_rondas)
	var destino_x: float = start_x + distancia_un_paso * ronda_actual
	
	var tween := create_tween()
	tween.tween_property(kitty, "position:x", destino_x, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(kitty, "position:y", kitty_base_y - 55.0, 0.14).set_ease(Tween.EASE_OUT)
	tween.tween_property(kitty, "position:y", kitty_base_y, 0.14).set_ease(Tween.EASE_IN)
	
	await tween.finished
	
	if ronda_actual >= total_rondas:
		ejecutar_choque_final()
	else:
		generar_nueva_combinacion()


func fallar_y_regresar_al_inicio() -> void:
	estado_actual = Estado.ANIMANDO_PASO
	ronda_actual = 0
	
	for i in range(4):
		cajas_teclas[i].add_theme_stylebox_override(
			"panel",
			_make_dialogue_style(Color(0.84, 0.20, 0.20, 0.94), Color(0.45, 0.08, 0.08, 0.85))
		)
		labels_teclas[i].add_theme_color_override("font_color", TEXT_COLOR)
	
	var tween := create_tween()
	tween.tween_property(kitty, "position:x", start_x, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	generar_nueva_combinacion()


func ejecutar_choque_final() -> void:
	estado_actual = Estado.FINAL_VOLANDO
	panel_instruccion_top.visible = false
	barra_tiempo.visible = false
	for caja in cajas_teclas:
		caja.visible = false
	
	person_with_bag.visible = false
	
	person_flying.position = person_with_bag.position
	person_flying.visible = true
	
	bag_flying.position = person_with_bag.position + Vector2(-40.0, 20.0)
	bag_flying.visible = true
	
	vel_persona = Vector2(950.0, -1550.0)
	vel_bolsa = Vector2(1350.0, -2050.0)


func _process(delta: float) -> void:
	camera.position.x = lerp(camera.position.x, kitty.position.x + 850.0, 6.0 * delta)
	
	if estado_actual == Estado.JUGANDO:
		tiempo_restante -= delta
		barra_tiempo.value = max(tiempo_restante, 0.0)
		if tiempo_restante <= 0.0:
			fallar_y_regresar_al_inicio()
	
	if estado_actual == Estado.FINAL_VOLANDO:
		var gravedad: float = 2400.0
		
		vel_persona.y += gravedad * delta
		person_flying.position += vel_persona * delta
		person_flying.rotation += 5.5 * delta
		
		vel_bolsa.y += gravedad * 0.9 * delta
		bag_flying.position += vel_bolsa * delta
		bag_flying.rotation -= 8.5 * delta