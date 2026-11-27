extends Node

const SAVE_DIR := "user://saves/"
const MAX_SLOTS := 6

signal save_completed(slot: int)
signal load_completed(slot: int, data: Dictionary)
signal active_slot_changed(slot: int)
signal slot_deleted(slot: int)

var current_slot: int = 1
var current_progress: Dictionary = {}
var extra_data: Dictionary = {}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var meta: Dictionary = _load_meta()
	if meta.has("current_slot"):
		current_slot = clampi(int(meta["current_slot"]), 1, MAX_SLOTS)

func _slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.save" % clampi(slot, 1, MAX_SLOTS)

func _meta_path() -> String:
	return SAVE_DIR + "meta.save"

func _save_meta(data: Dictionary) -> void:
	var f := FileAccess.open(_meta_path(), FileAccess.WRITE)
	if f != null:
		f.store_var(data)
		f.close()

func _load_meta() -> Dictionary:
	if not FileAccess.file_exists(_meta_path()):
		return {}
	var f := FileAccess.open(_meta_path(), FileAccess.READ)
	if f == null:
		return {}
	var val = f.get_var()
	f.close()
	return val if val is Dictionary else {}

func set_active_slot(slot: int) -> void:
	current_slot = clampi(slot, 1, MAX_SLOTS)
	_save_meta({"current_slot": current_slot})
	active_slot_changed.emit(current_slot)

func seleccionar_slot(slot: int) -> void:
	set_active_slot(slot)

func get_max_slots() -> int:
	return MAX_SLOTS

func has_save(slot: int = -1) -> bool:
	var target := current_slot if slot < 1 else clampi(slot, 1, MAX_SLOTS)
	if not FileAccess.file_exists(_slot_path(target)):
		return false
	var info: Dictionary = obtener_info_slot(target)
	return not bool(info.get("vacio", true))

func has_any_save() -> bool:
	for i in range(1, MAX_SLOTS + 1):
		if has_save(i):
			return true
	return false

func find_first_empty_slot() -> int:
	for i in range(1, MAX_SLOTS + 1):
		if not has_save(i):
			return i
	return -1

func obtener_todos_los_slots() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for i in range(1, MAX_SLOTS + 1):
		var info: Dictionary = obtener_info_slot(i)
		info["slot"] = i
		list.append(info)
	return list

func guardar_en_slot(slot: int, data: Variant) -> bool:
	var target := clampi(slot, 1, MAX_SLOTS)
	set_active_slot(target)

	var payload: Dictionary = {}
	if data is Dictionary:
		payload = (data as Dictionary).duplicate(true)
	elif data is String:
		var s := str(data)
		if not s.is_empty():
			payload["scene_path"] = s
			payload["current_scene"] = s

	var timestamp := Time.get_datetime_string_from_system(false, true)
	payload["slot"] = target
	payload["updated_at"] = timestamp
	payload["timestamp"] = timestamp
	payload["vacio"] = false
	payload["is_new_game"] = false

	var ed: Dictionary = {}
	if payload.has("extra_data") and payload["extra_data"] is Dictionary:
		ed = (payload["extra_data"] as Dictionary).duplicate(true)
	for k in ["entry_index", "step", "step_index", "index", "page_index", "is_post_gallery", "jammy_lost", "sad_bgm", "sad_bgm_vol"]:
		if payload.has(k) and not ed.has(k):
			ed[k] = payload[k]
	payload["extra_data"] = ed

	var path := _slot_path(target)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: no se pudo abrir '%s' para escribir" % path)
		return false
	f.store_var(payload)
	f.close()

	current_progress = payload.duplicate(true)
	extra_data = ed.duplicate(true)
	save_completed.emit(target)
	return true

func guardar_progreso(scene_path: String, arg2: Variant = "", arg3: Variant = {}, arg4: Variant = -1) -> bool:
	var target := current_slot
	var stage_label := ""
	var ed: Dictionary = {}

	var candidates: Array[Variant] = [arg2, arg3, arg4]
	for c in candidates:
		if c is int and int(c) >= 1:
			target = clampi(int(c), 1, MAX_SLOTS)
		elif c is String and not str(c).is_empty() and stage_label.is_empty():
			stage_label = str(c)
		elif c is Dictionary:
			for k in (c as Dictionary).keys():
				ed[k] = (c as Dictionary)[k]

	var existing: Dictionary = cargar_slot(target)
	if existing.is_empty():
		existing = {}
	if existing.has("extra_data") and existing["extra_data"] is Dictionary:
		var prev_ed: Dictionary = (existing["extra_data"] as Dictionary).duplicate(true)
		for k in ed.keys():
			prev_ed[k] = ed[k]
		ed = prev_ed

	existing["scene_path"] = scene_path
	existing["current_scene"] = scene_path
	if not stage_label.is_empty():
		existing["stage_name"] = stage_label
	existing["extra_data"] = ed.duplicate(true)
	for k in ed.keys():
		existing[k] = ed[k]

	return guardar_en_slot(target, existing)

func cargar_slot(slot: int = -1) -> Dictionary:
	var target := current_slot if slot < 1 else clampi(slot, 1, MAX_SLOTS)
	var path := _slot_path(target)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var val = f.get_var()
	f.close()
	if not (val is Dictionary):
		return {}
	var dict_val: Dictionary = (val as Dictionary).duplicate(true)
	if bool(dict_val.get("vacio", false)):
		return {}

	set_active_slot(target)
	current_progress = dict_val
	var ed: Dictionary = {}
	if dict_val.has("extra_data") and dict_val["extra_data"] is Dictionary:
		ed = (dict_val["extra_data"] as Dictionary).duplicate(true)
	for k in ["entry_index", "step", "step_index", "index", "page_index", "is_post_gallery", "jammy_lost", "sad_bgm", "sad_bgm_vol"]:
		if dict_val.has(k) and not ed.has(k):
			ed[k] = dict_val[k]
	extra_data = ed
	get_tree().set_meta("loaded_save_extra", extra_data.duplicate(true))
	load_completed.emit(target, current_progress)
	return current_progress

func cargar_progreso(slot: int = -1) -> Dictionary:
	return cargar_slot(slot)

func obtener_info_slot(slot: int) -> Dictionary:
	var target := clampi(slot, 1, MAX_SLOTS)
	var path := _slot_path(target)
	if not FileAccess.file_exists(path):
		return {"vacio": true, "slot": target}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"vacio": true, "slot": target}
	var val = f.get_var()
	f.close()
	if not (val is Dictionary):
		return {"vacio": true, "slot": target}
	var raw: Dictionary = val as Dictionary
	if raw.is_empty() or bool(raw.get("vacio", false)):
		return {"vacio": true, "slot": target}
	var info: Dictionary = raw.duplicate(true)
	info["slot"] = target
	info["vacio"] = false
	if not info.has("timestamp"):
		info["timestamp"] = str(info.get("updated_at", ""))
	if not info.has("stage_name"):
		var s_name := str(info.get("scene_path", "")).get_file().get_basename()
		info["stage_name"] = s_name if not s_name.is_empty() else "Partida"
	return info

func borrar_slot(slot: int = -1) -> bool:
	var target := current_slot if slot < 1 else clampi(slot, 1, MAX_SLOTS)
	var path := _slot_path(target)

	if FileAccess.file_exists(path):
		var global_path := ProjectSettings.globalize_path(path)
		var err := DirAccess.remove_absolute(global_path)
		if err != OK:
			err = DirAccess.remove_absolute(path)
		if err != OK:
			push_error("SaveManager: no se pudo borrar '%s' (err=%d)" % [path, err])
			return false

	if int(current_progress.get("slot", -1)) == target:
		current_progress.clear()
		extra_data.clear()
		if get_tree().has_meta("loaded_save_extra"):
			get_tree().remove_meta("loaded_save_extra")

	slot_deleted.emit(target)
	save_completed.emit(target)
	return true

func borrar_partida(slot: int = -1) -> bool:
	return borrar_slot(slot)

func eliminar_slot(slot: int = -1) -> bool:
	return borrar_slot(slot)

func preparar_nueva_partida(first_scene_path: String, preferred_slot: int = -1) -> int:
	return iniciar_nueva_partida(first_scene_path, preferred_slot)

func iniciar_nueva_partida(first_scene_path: String, preferred_slot: int = -1) -> int:
	var target_slot: int = -1
	if preferred_slot >= 1:
		target_slot = clampi(preferred_slot, 1, MAX_SLOTS)
	else:
		target_slot = find_first_empty_slot()
		if target_slot == -1:
			target_slot = (current_slot % MAX_SLOTS) + 1

	set_active_slot(target_slot)
	extra_data = {"entry_index": 0, "step": 0, "step_index": 0, "page_index": 0}
	current_progress = {
		"slot": target_slot,
		"scene_path": first_scene_path,
		"current_scene": first_scene_path,
		"stage_name": first_scene_path.get_file().get_basename() if not first_scene_path.is_empty() else "Inicio",
		"extra_data": extra_data.duplicate(true),
		"entry_index": 0,
		"step": 0,
		"is_new_game": true,
		"vacio": false
	}
	get_tree().set_meta("loaded_save_extra", extra_data.duplicate(true))
	get_tree().paused = false
	if not first_scene_path.is_empty() and ResourceLoader.exists(first_scene_path):
		get_tree().change_scene_to_file(first_scene_path)
	return target_slot

func cargar_partida(slot: int = -1, fallback_scene_path: String = "") -> bool:
	var target := current_slot if slot < 1 else clampi(slot, 1, MAX_SLOTS)
	var data: Dictionary = cargar_slot(target)
	if data.is_empty():
		return false

	var scene_to_open := str(data.get("scene_path", data.get("current_scene", data.get("scene", ""))))
	if scene_to_open.is_empty() or not ResourceLoader.exists(scene_to_open):
		scene_to_open = fallback_scene_path
	if scene_to_open.is_empty() or not ResourceLoader.exists(scene_to_open):
		return false

	get_tree().paused = false
	get_tree().change_scene_to_file(scene_to_open)
	return true

func volver_al_inicio(main_menu_path: String = "res://main_menu.tscn") -> void:
	get_tree().paused = false
	var target_path := main_menu_path
	if not ResourceLoader.exists(target_path):
		for candidate in ["res://main.tscn", "res://Main.tscn", "res://scenes/main_menu.tscn"]:
			if ResourceLoader.exists(candidate):
				target_path = candidate
				break
	if ResourceLoader.exists(target_path):
		get_tree().change_scene_to_file(target_path)
