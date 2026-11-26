extends Node

const SAVE_PATH := "user://save_data.cfg"
const MAIN_MENU_SCENE := "res://main.tscn"

var slot_actual: int = 1
var current_scene_path: String = ""
var current_label: String = ""
var extra_data: Dictionary = {}


func _slot_section(slot: int = 1) -> String:
	return "progress" if slot <= 0 else "progress_%d" % slot


func guardar_progreso(scene_path: String, label: String = "", extra: Dictionary = {}, slot: int = -1) -> void:
	var target_slot: int = slot if slot > 0 else slot_actual
	if target_slot <= 0:
		target_slot = 1
	slot_actual = target_slot

	current_scene_path = scene_path
	current_label = label
	extra_data = extra.duplicate(true)

	var timestamp_str: String = Time.get_datetime_string_from_system(false, true)

	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var sec := _slot_section(target_slot)
	cfg.set_value(sec, "scene_path", current_scene_path)
	cfg.set_value(sec, "label", current_label)
	cfg.set_value(sec, "stage_name", current_label)
	cfg.set_value(sec, "timestamp", timestamp_str)
	cfg.set_value(sec, "extra", extra_data)

	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("SaveManager: error al guardar progreso (código %d)" % err)


func obtener_info_slot(slot: int = 1) -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return {}

	var sec := _slot_section(slot)
	if not cfg.has_section(sec):
		return {}

	var path: String = str(cfg.get_value(sec, "scene_path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return {}

	var label_val: String = str(cfg.get_value(sec, "label", cfg.get_value(sec, "stage_name", "Saved")))
	var time_val: String = str(cfg.get_value(sec, "timestamp", ""))
	var raw_extra = cfg.get_value(sec, "extra", {})

	return {
		"exists": true,
		"scene_path": path,
		"label": label_val,
		"stage_name": label_val,
		"timestamp": time_val,
		"extra": raw_extra.duplicate(true) if raw_extra is Dictionary else {}
	}


func tiene_guardado(slot: int = 1) -> bool:
	return not obtener_info_slot(slot).is_empty()


func iniciar_nueva_partida(slot: int = 1, scene_path: String = "") -> void:
	slot_actual = slot if slot > 0 else 1
	borrar_guardado(slot_actual)

	var target_scene: String = scene_path
	if target_scene.is_empty():
		target_scene = "res://visual_novel.tscn"

	var initial_extra: Dictionary = {"entry_index": 0, "step": 0}
	guardar_progreso(target_scene, "Visual Novel (1/?)", initial_extra, slot_actual)
	extra_data = initial_extra.duplicate(true)
	get_tree().set_meta("loaded_save_extra", extra_data)


func cargar_guardado(slot: int = 1) -> bool:
	var info := obtener_info_slot(slot)
	if info.is_empty():
		return false

	slot_actual = slot if slot > 0 else 1
	var path: String = str(info.get("scene_path", ""))
	current_scene_path = path
	current_label = str(info.get("stage_name", info.get("label", "")))
	var raw_extra = info.get("extra", {})
	extra_data = raw_extra.duplicate(true) if raw_extra is Dictionary else {}

	if not extra_data.is_empty():
		get_tree().set_meta("loaded_save_extra", extra_data)
	elif get_tree().has_meta("loaded_save_extra"):
		get_tree().remove_meta("loaded_save_extra")

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_warning("SaveManager: no se pudo cambiar a la escena '%s' (código %d)" % [path, err])
		return false
	return true


func cargar_slot(slot: int = 1) -> bool:
	return cargar_guardado(slot)


func volver_al_inicio() -> void:
	if get_tree().has_meta("loaded_save_extra"):
		get_tree().remove_meta("loaded_save_extra")

	if ResourceLoader.exists(MAIN_MENU_SCENE):
		get_tree().call_deferred("change_scene_to_file", MAIN_MENU_SCENE)
	elif ResourceLoader.exists("res://Main.tscn"):
		get_tree().call_deferred("change_scene_to_file", "res://Main.tscn")
	else:
		push_warning("SaveManager: no se encontró la escena del menú principal.")


func borrar_guardado(slot: int = 1) -> void:
	current_scene_path = ""
	current_label = ""
	extra_data.clear()
	if get_tree().has_meta("loaded_save_extra"):
		get_tree().remove_meta("loaded_save_extra")

	if FileAccess.file_exists(SAVE_PATH):
		var cfg := ConfigFile.new()
		if cfg.load(SAVE_PATH) == OK:
			var sec := _slot_section(slot)
			if cfg.has_section(sec):
				cfg.erase_section(sec)
				cfg.save(SAVE_PATH)
