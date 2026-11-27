extends CanvasLayer

@export var main_menu_scene: String = "res://main_menu.tscn"
@export var quit_app_instead_of_menu: bool = false

const STATE_KEYS: Array[String] = [
	"step_index",
	"phase",
	"entry_index",
	"current_index",
	"dialogue_index",
	"line_index",
	"ronda_actual",
	"step",
	"chapter",
	"score",
	"hp",
	"health"
]

var _ask_panel: Panel
var _slots_panel: Panel
var _slots_vbox: VBoxContainer
var _scene_to_save: String = ""


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide_all()
	call_deferred("_restore_current_scene_state_if_needed")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _slots_panel.visible or _ask_panel.visible:
			hide_all()
			get_tree().paused = false
		else:
			open_exit_prompt()


func open_exit_prompt(override_scene_path: String = "") -> void:
	if override_scene_path != "":
		_scene_to_save = override_scene_path
	elif get_tree().current_scene != null:
		_scene_to_save = get_tree().current_scene.scene_file_path
	else:
		_scene_to_save = ""

	get_tree().paused = true
	_slots_panel.visible = false
	_ask_panel.visible = true


func hide_all() -> void:
	_ask_panel.visible = false
	_slots_panel.visible = false


func _collect_scene_state() -> Dictionary:
	var scene := get_tree().current_scene
	if scene == null:
		return {}

	if scene.has_method("obtener_estado_guardado"):
		var custom_state = scene.call("obtener_estado_guardado")
		if custom_state is Dictionary:
			return (custom_state as Dictionary).duplicate(true)

	if scene.has_method("_obtener_estado_guardado"):
		var priv_state = scene.call("_obtener_estado_guardado")
		if priv_state is Dictionary:
			return (priv_state as Dictionary).duplicate(true)

	var captured: Dictionary = {}
	for prop_name in STATE_KEYS:
		if prop_name in scene:
			captured[prop_name] = scene.get(prop_name)
	return captured


func _restore_current_scene_state_if_needed() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	var scene := get_tree().current_scene
	if save_mgr == null or scene == null:
		return

	var progress_val = save_mgr.get("current_progress")
	if not (progress_val is Dictionary):
		return

	var progress: Dictionary = progress_val as Dictionary
	if progress.is_empty() or bool(progress.get("is_new_game", false)) or bool(progress.get("vacio", false)):
		return

	var saved_scene := str(progress.get("scene_path", progress.get("current_scene", "")))
	if saved_scene.is_empty() or scene.scene_file_path.is_empty() or saved_scene != scene.scene_file_path:
		return

	var state_val = progress.get("state", {})
	var state: Dictionary = state_val as Dictionary if state_val is Dictionary else {}
	if state.is_empty():
		for k in STATE_KEYS:
			if progress.has(k):
				state[k] = progress[k]

	if state.is_empty():
		return

	if scene.has_method("aplicar_estado_guardado"):
		scene.call("aplicar_estado_guardado", state)
		return

	if scene.has_method("_aplicar_estado_guardado"):
		scene.call("_aplicar_estado_guardado", state)
		return

	for k in state.keys():
		if str(k) in scene:
			scene.set(str(k), state[k])


func _build_ui() -> void:
	_ask_panel = Panel.new()
	_ask_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ask_panel.custom_minimum_size = Vector2(760, 360)
	_ask_panel.position = Vector2(-380, -180)

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.08, 0.11, 0.98)
	st.set_corner_radius_all(20)
	st.set_border_width_all(3)
	st.border_color = Color("#f5d08a")
	_ask_panel.add_theme_stylebox_override("panel", st)
	add_child(_ask_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 40
	vbox.offset_right = -40
	vbox.offset_top = 36
	vbox.offset_bottom = -36
	vbox.add_theme_constant_override("separation", 24)
	_ask_panel.add_child(vbox)

	var title := Label.new()
	title.text = "¿Deseas guardar la partida antes de salir?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	var btn_yes := Button.new()
	btn_yes.text = "Sí, elegir slot para guardar"
	btn_yes.custom_minimum_size = Vector2(0, 68)
	btn_yes.add_theme_font_size_override("font_size", 26)
	btn_yes.pressed.connect(_on_yes_save_pressed)
	vbox.add_child(btn_yes)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var btn_no := Button.new()
	btn_no.text = "Salir sin guardar"
	btn_no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_no.custom_minimum_size = Vector2(0, 62)
	btn_no.add_theme_font_size_override("font_size", 24)
	btn_no.pressed.connect(_exit_without_saving)
	hbox.add_child(btn_no)

	var btn_cancel := Button.new()
	btn_cancel.text = "Cancelar"
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.custom_minimum_size = Vector2(0, 62)
	btn_cancel.add_theme_font_size_override("font_size", 24)
	btn_cancel.pressed.connect(func() -> void:
		hide_all()
		get_tree().paused = false
	)
	hbox.add_child(btn_cancel)

	_slots_panel = Panel.new()
	_slots_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_slots_panel.custom_minimum_size = Vector2(880, 540)
	_slots_panel.position = Vector2(-440, -270)
	_slots_panel.add_theme_stylebox_override("panel", st.duplicate())
	add_child(_slots_panel)

	var svbox := VBoxContainer.new()
	svbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svbox.offset_left = 40
	svbox.offset_right = -40
	svbox.offset_top = 32
	svbox.offset_bottom = -32
	svbox.add_theme_constant_override("separation", 18)
	_slots_panel.add_child(svbox)

	var stitle := Label.new()
	stitle.text = "Selecciona el slot donde deseas guardar:"
	stitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stitle.add_theme_font_size_override("font_size", 30)
	svbox.add_child(stitle)

	_slots_vbox = VBoxContainer.new()
	_slots_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slots_vbox.add_theme_constant_override("separation", 14)
	svbox.add_child(_slots_vbox)

	var btn_back := Button.new()
	btn_back.text = "Volver"
	btn_back.custom_minimum_size = Vector2(0, 56)
	btn_back.add_theme_font_size_override("font_size", 24)
	btn_back.pressed.connect(func() -> void:
		_slots_panel.visible = false
		_ask_panel.visible = true
	)
	svbox.add_child(btn_back)


func _on_yes_save_pressed() -> void:
	_refresh_save_slots()
	_ask_panel.visible = false
	_slots_panel.visible = true


func _refresh_save_slots() -> void:
	for c in _slots_vbox.get_children():
		c.queue_free()

	var save_mgr := get_node_or_null("/root/SaveManager")
	var max_slots := 3
	if save_mgr != null and save_mgr.has_method("get_max_slots"):
		max_slots = int(save_mgr.call("get_max_slots"))

	for slot_idx in range(1, max_slots + 1):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 96)
		btn.add_theme_font_size_override("font_size", 24)

		var info: Dictionary = {}
		if save_mgr != null and save_mgr.has_method("obtener_info_slot"):
			info = save_mgr.obtener_info_slot(slot_idx)

		var is_empty: bool = info.is_empty() or bool(info.get("vacio", true))
		if is_empty:
			btn.text = "Slot %d — [Vacío] (Guardar aquí)" % slot_idx
		else:
			btn.text = "Slot %d — %s (%s)" % [
				slot_idx,
				str(info.get("stage_name", "Chapter %d" % int(info.get("chapter", 1)))),
				str(info.get("timestamp", ""))
			]

		var captured_slot := slot_idx
		btn.pressed.connect(func() -> void:
			if save_mgr != null and save_mgr.has_method("guardar_en_slot"):
				var scene_state := _collect_scene_state()
				var data := {
					"scene_path": _scene_to_save,
					"current_scene": _scene_to_save,
					"stage_name": _scene_to_save.get_file().get_basename() if not _scene_to_save.is_empty() else "Partida",
					"state": scene_state,
					"extra_data": scene_state.duplicate(true),
					"is_new_game": false
				}
				for k in scene_state.keys():
					data[k] = scene_state[k]
				save_mgr.guardar_en_slot(captured_slot, data)
			_exit_without_saving()
		)
		_slots_vbox.add_child(btn)


func _exit_without_saving() -> void:
	hide_all()
	get_tree().paused = false
	if quit_app_instead_of_menu:
		get_tree().quit()
	elif not main_menu_scene.is_empty() and ResourceLoader.exists(main_menu_scene):
		get_tree().change_scene_to_file(main_menu_scene)
