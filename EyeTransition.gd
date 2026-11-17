extends CanvasLayer

var overlay: ColorRect
var shader_mat: ShaderMaterial
var en_transicion: bool = false

const EYELID_SHADER := """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.01, 0.5) = 0.18;
uniform float curvature : hint_range(0.0, 1.0) = 0.26;

void fragment() {
	vec2 uv = UV;
	float dx = (uv.x - 0.5) * 2.0;
	// Curvatura natural de los párpados superior e inferior
	float arch = (1.0 - dx * dx) * curvature;
	float dist_center = abs(uv.y - 0.5) * 2.0;

	float limit = (1.0 - progress) * (1.0 + arch + softness);
	float eyelid = smoothstep(limit - softness, limit + softness, dist_center);

	// Oscurecimiento total al terminar de cerrar los ojos
	float alpha = mix(eyelid, 1.0, smoothstep(0.68, 1.0, progress));
	COLOR = vec4(0.0, 0.0, 0.0, clamp(alpha, 0.0, 1.0));
}
"""


func _ready() -> void:
	layer = 100
	
	var shader := Shader.new()
	shader.code = EYELID_SHADER
	
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader
	shader_mat.set_shader_parameter("progress", 0.0)
	
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.material = shader_mat
	overlay.visible = false
	add_child(overlay)


func _set_progress(valor: float) -> void:
	shader_mat.set_shader_parameter("progress", valor)


func ir_a_escena_cerrando_ojos(ruta_escena: String, abrir_ojos_al_llegar: bool = true) -> void:
	if en_transicion:
		return
	en_transicion = true
	overlay.visible = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_progress(0.0)
	
	# Secuencia de párpados pesados en 1ra persona
	var tween := create_tween()
	# 1. Primer cierre parcial de cansancio
	tween.tween_method(_set_progress, 0.0, 0.58, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.12)
	# 2. Intenta abrir los ojos un poco
	tween.tween_method(_set_progress, 0.58, 0.28, 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.10)
	# 3. Cierre definitivo hasta quedar completamente a oscuras
	tween.tween_method(_set_progress, 0.28, 1.0, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await tween.finished
	
	# Cambiar a Level2 mientras los ojos están cerrados
	if ruta_escena != "" and ResourceLoader.exists(ruta_escena):
		get_tree().change_scene_to_file(ruta_escena)
	
	await get_tree().process_frame
	
	# Abrir los ojos ya dentro de Level2
	if abrir_ojos_al_llegar:
		var tween_abrir := create_tween()
		tween_abrir.tween_interval(0.20)
		tween_abrir.tween_method(_set_progress, 1.0, 0.0, 0.70).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tween_abrir.finished
	else:
		_set_progress(0.0)
	
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	en_transicion = false
