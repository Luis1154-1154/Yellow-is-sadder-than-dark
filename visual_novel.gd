extends Control

const BASE_SIZE := Vector2(3840.0, 2160.0)
const TEXT_COLOR := Color("#fff9f0")
const PANEL_COLOR := Color(0.22, 0.23, 0.25, 0.50)
const MIND_PANEL_COLOR := Color(0.18, 0.18, 0.20, 0.56)
const SPEAKER_BG_COLOR := Color(0.18, 0.19, 0.21, 0.68)
const MIND_COLOR := Color("#ff5a5f")
const ACCENT_COLOR := Color("#fff9f0")

# Colores por personaje
const JAMMY_COLOR := Color("#f5d08a")
const COUSIN_COLOR := Color("#a3aab2")
const XCARLET_COLOR := Color("#5bc0eb")
const GRANDMA_COLOR := Color("#f2a6b8")
const CLASSMATES_TAB_COLOR := Color("#46527a")
const CLASSMATES_BOX_COLOR := Color("#cfd5e0")
const CLASSMATES_TEXT_COLOR := Color("#c6cee0")

const DIALOGUE_PANEL_SIZE := Vector2(1240.0, 230.0)
const DIALOGUE_PANEL_POS := Vector2(1300.0, 960.0)
const SPEAKER_PANEL_SIZE := Vector2(300.0, 62.0)

const FREDOKA_FONT = preload("res://fonts/Fredoka-Regular.ttf")
const ROCK_SALT_FONT = preload("res://fonts/RockSalt-Regular.ttf")
const NORMAL_DIALOGUE_STREAM = preload("res://assets/sounds/Soft_pencil_tap_on_n_#1-1794378651940.mp3")
const BREATHING_STREAM = preload("res://assets/sounds/breathing1.mp3")
const HEARTBEAT_STREAM = preload("res://assets/sounds/Hbeating1.mp3")
const FOCUS_EFFORT_STREAM = preload("res://assets/sounds/audioJuego1.mp3")
const FOCUS_SUCCESS_STREAM = preload("res://assets/sounds/mixingGame1.mp3")

# Dificultad alta del minijuego con ventana de 0.5 segundos
const FOCUS_EFFORT_MIN_TARGET := 110.0
const FOCUS_EFFORT_MAX_TARGET := 155.0
const FOCUS_EFFORT_RATE := 14.5
const FOCUS_WINDOW_TIME := 0.5
const FOCUS_RESOLUTION_TIME := 5.5
const FOCUS_CLIMAX_BLUR := 8.5

var background: TextureRect
var black_background: ColorRect
var dialogue_panel: Panel
var dialogue_label: Label
var speaker_panel: Panel
var speaker_label: Label
var continue_label: Label
var typewriter_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var mind_breath_player: AudioStreamPlayer
var mind_heartbeat_player: AudioStreamPlayer
var sonido_esfuerzo: AudioStreamPlayer
var sonido_corte: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var typewriter_stream: AudioStream
var breath_stream: AudioStream
var heartbeat_stream: AudioStream
var effort_stream: AudioStream
var cut_stream: AudioStream
var night_ambience_stream: AudioStream
var sigh_stream: AudioStream

var entries: Array[Dictionary] = []
var entry_index := 0
var is_typing := false
var typing_token := 0
var displayed_words := 0
var current_words: PackedStringArray
var current_entry: Dictionary
var waiting_for_input := false
var vn_focus_mode := false
var vn_focus_intro := true
enum FocusState { EFFORT, WINDOW, RESOLUTION }
var focus_state := FocusState.EFFORT
var focus_effort := 0.0
var focus_target_effort := 125.0
var focus_window_timer := 0.0
var focus_phase_wobble := 0.0
var focus_image: TextureRect
var focus_shader_material: ShaderMaterial
var focus_instructions: RichTextLabel
var focus_vignette: ColorRect
var focus_status: Label
var focus_hint: Label
var focus_fakeout_timer := 0.0
var focus_fakeout_points: Array[float] = []
var focus_fakeout_index := 0
var focus_exit_prompt := false
var tex_focus_base: Texture2D
var tex_focus_ugly: Texture2D
var mixing_game_active := false
var mixing_loop_start := 0.5

func _ready() -> void:
	randomize()
	_build_audio()
	_build_ui()
	_build_script()
	_split_long_dialogues()
	_show_entry()

func _process(delta: float) -> void:
	if mixing_game_active:
		_maintain_mixing_game_loop()
	if not vn_focus_mode or vn_focus_intro:
		return
	var is_pressing := Input.is_key_pressed(KEY_W) and Input.is_key_pressed(KEY_S)
	_update_focus_music(is_pressing)
	focus_phase_wobble += delta

	if focus_fakeout_timer > 0.0:
		_apply_focus_tension(true)
		if not is_pressing:
			_abort_focus_attempt()
			return
		focus_fakeout_timer -= delta
		if focus_fakeout_timer <= 0.0:
			focus_image.texture = tex_focus_base
			focus_fakeout_timer = 0.0
		return

	match focus_state:
		FocusState.EFFORT:
			if is_pressing:
				var resistance := 0.62 + 0.52 * (0.5 + 0.5 * sin(focus_phase_wobble * 4.3)) + randf_range(-0.18, 0.22)
				focus_effort = min(focus_effort + FOCUS_EFFORT_RATE * maxf(resistance, 0.35) * delta, focus_target_effort)
			else:
				if focus_effort > 0.0:
					_abort_focus_attempt()
					return
			_apply_focus_tension(false)
			if focus_fakeout_index < focus_fakeout_points.size() and focus_effort >= focus_fakeout_points[focus_fakeout_index]:
				focus_fakeout_index += 1
				_begin_focus_fakeout()
			elif focus_effort >= focus_target_effort:
				_begin_focus_window()
		FocusState.WINDOW:
			if not is_pressing:
				_complete_focus()
				return
			_apply_focus_tension(true)
			focus_window_timer -= delta
			if focus_window_timer <= 0.0:
				_reset_focus_cycle()

func _abort_focus_attempt() -> void:
	focus_effort = 0.0
	focus_fakeout_timer = 0.0
	focus_image.texture = tex_focus_base
	focus_image.scale = Vector2.ONE
	focus_image.position = Vector2.ZERO
	focus_shader_material.set_shader_parameter("blur_amount", 0.0)
	sonido_esfuerzo.pitch_scale = 0.85
	sonido_esfuerzo.volume_db = 0.0
	_roll_focus_cycle_params()

func _roll_focus_cycle_params() -> void:
	focus_target_effort = randf_range(FOCUS_EFFORT_MIN_TARGET, FOCUS_EFFORT_MAX_TARGET)
	focus_fakeout_points.clear()
	focus_fakeout_index = 0
	var fakeout_count := randi_range(3, 4)
	var cursor := randf_range(0.73, 0.78)
	for i in fakeout_count:
		if cursor >= 0.965:
			break
		focus_fakeout_points.append(focus_target_effort * cursor)
		cursor += randf_range(0.048, 0.072)

func _build_ui() -> void:
	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.pivot_offset = BASE_SIZE / 2.0

	black_background = ColorRect.new()
	black_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black_background.color = Color.BLACK
	black_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black_background)
	add_child(background)
	move_child(black_background, 0)

	dialogue_panel = Panel.new()
	dialogue_panel.position = DIALOGUE_PANEL_POS
	dialogue_panel.size = DIALOGUE_PANEL_SIZE
	dialogue_panel.z_index = 10
	dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, Color(1.0, 1.0, 1.0, 0.22)))
	add_child(dialogue_panel)

	speaker_panel = Panel.new()
	speaker_panel.position = Vector2(DIALOGUE_PANEL_POS.x + 36.0, DIALOGUE_PANEL_POS.y - SPEAKER_PANEL_SIZE.y + 2.0)
	speaker_panel.size = SPEAKER_PANEL_SIZE
	speaker_panel.z_index = 11
	speaker_panel.visible = false
	speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, JAMMY_COLOR))
	add_child(speaker_panel)

	speaker_label = Label.new()
	speaker_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.add_theme_font_size_override("font_size", 36)
	speaker_label.add_theme_font_override("font", FREDOKA_FONT)
	speaker_label.add_theme_color_override("font_color", JAMMY_COLOR)
	speaker_label.add_theme_color_override("font_shadow_color", Color("#000000e6"))
	speaker_label.add_theme_constant_override("shadow_offset_x", 2)
	speaker_label.add_theme_constant_override("shadow_offset_y", 2)
	speaker_panel.add_child(speaker_label)

	dialogue_label = Label.new()
	dialogue_label.position = Vector2(44, 24)
	dialogue_label.size = Vector2(DIALOGUE_PANEL_SIZE.x - 88.0, DIALOGUE_PANEL_SIZE.y - 48.0)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.clip_text = false
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.add_theme_font_size_override("font_size", 46)
	dialogue_label.add_theme_font_override("font", FREDOKA_FONT)
	dialogue_label.add_theme_color_override("font_color", TEXT_COLOR)
	dialogue_label.add_theme_color_override("font_shadow_color", Color("#000000e6"))
	dialogue_label.add_theme_constant_override("shadow_offset_x", 4)
	dialogue_label.add_theme_constant_override("shadow_offset_y", 4)
	dialogue_panel.add_child(dialogue_label)

	continue_label = Label.new()
	continue_label.position = Vector2(0, 2065)
	continue_label.size = Vector2(3840, 70)
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.z_index = 12
	continue_label.add_theme_font_size_override("font_size", 40)
	continue_label.add_theme_color_override("font_color", ACCENT_COLOR)
	continue_label.text = "ENTER / SPACE"
	continue_label.visible = false
	add_child(continue_label)

	focus_image = TextureRect.new()
	focus_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	focus_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	focus_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_image.z_index = 1
	focus_image.pivot_offset = BASE_SIZE / 2.0
	focus_image.visible = false
	var focus_shader := Shader.new()
	focus_shader.code = """
shader_type canvas_item;

uniform float blur_amount = 0.0;

void fragment() {
	vec2 offset = TEXTURE_PIXEL_SIZE * blur_amount;
	vec4 color = texture(TEXTURE, UV) * 0.2;
	color += texture(TEXTURE, UV + vec2(offset.x, 0.0)) * 0.2;
	color += texture(TEXTURE, UV - vec2(offset.x, 0.0)) * 0.2;
	color += texture(TEXTURE, UV + vec2(0.0, offset.y)) * 0.2;
	color += texture(TEXTURE, UV - vec2(0.0, offset.y)) * 0.2;
	COLOR = color;
}
"""
	focus_shader_material = ShaderMaterial.new()
	focus_shader_material.shader = focus_shader
	focus_shader_material.set_shader_parameter("blur_amount", 0.0)
	focus_image.material = focus_shader_material
	add_child(focus_image)

	focus_vignette = ColorRect.new()
	focus_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_vignette.z_index = 2
	var vignette_shader := Shader.new()
	vignette_shader.code = """
shader_type canvas_item;

uniform float vignette_alpha = 0.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float edge = smoothstep(0.24, 0.72, length(centered));
	COLOR = vec4(0.0, 0.0, 0.0, edge * vignette_alpha);
}
"""
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = vignette_shader
	vignette_material.set_shader_parameter("vignette_alpha", 0.0)
	focus_vignette.material = vignette_material
	focus_vignette.visible = false
	add_child(focus_vignette)

	focus_instructions = RichTextLabel.new()
	focus_instructions.position = Vector2(44, 24)
	focus_instructions.size = Vector2(DIALOGUE_PANEL_SIZE.x - 88.0, DIALOGUE_PANEL_SIZE.y - 48.0)
	focus_instructions.bbcode_enabled = true
	focus_instructions.fit_content = false
	focus_instructions.scroll_active = false
	focus_instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus_instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_instructions.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	focus_instructions.add_theme_font_size_override("normal_font_size", 46)
	focus_instructions.add_theme_font_override("normal_font", FREDOKA_FONT)
	focus_instructions.add_theme_color_override("default_color", Color("#161616"))
	focus_instructions.visible = false
	dialogue_panel.add_child(focus_instructions)

	focus_status = Label.new()
	focus_status.position = Vector2(150, 150)
	focus_status.size = Vector2(700, 80)
	focus_status.add_theme_font_size_override("font_size", 48)
	focus_status.add_theme_color_override("font_color", TEXT_COLOR)
	focus_status.add_theme_color_override("font_shadow_color", Color("#000000cc"))
	focus_status.add_theme_constant_override("shadow_offset_x", 4)
	focus_status.add_theme_constant_override("shadow_offset_y", 4)
	focus_status.visible = false
	add_child(focus_status)

	focus_hint = Label.new()
	focus_hint.position = Vector2(650, 1910)
	focus_hint.size = Vector2(2540, 100)
	focus_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_hint.add_theme_font_size_override("font_size", 42)
	focus_hint.add_theme_color_override("font_color", TEXT_COLOR)
	focus_hint.add_theme_color_override("font_shadow_color", Color("#000000cc"))
	focus_hint.add_theme_constant_override("shadow_offset_x", 4)
	focus_hint.add_theme_constant_override("shadow_offset_y", 4)
	focus_hint.visible = false
	add_child(focus_hint)

	typewriter_player = AudioStreamPlayer.new()
	typewriter_player.pitch_scale = 1.0
	typewriter_player.volume_db = 0.0
	add_child(typewriter_player)
	ambience_player = AudioStreamPlayer.new()
	add_child(ambience_player)
	mind_breath_player = AudioStreamPlayer.new()
	add_child(mind_breath_player)
	mind_heartbeat_player = AudioStreamPlayer.new()
	mind_heartbeat_player.pitch_scale = 2.0
	add_child(mind_heartbeat_player)
	sonido_esfuerzo = AudioStreamPlayer.new()
	add_child(sonido_esfuerzo)
	sonido_corte = AudioStreamPlayer.new()
	add_child(sonido_corte)
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)

func _build_script() -> void:
	entries = [
		{"image": "scene1_4k.png", "text": "To continue, press SPACE", "instant": true, "kind": "prompt"},
		{"image": "scene1_4k.png", "text": "The asterisks (* *) indicate that the dialogue belongs to the character's mind.", "instant": false, "kind": "instruction"},
		{"image": "scene1_4k.png", "text": "We still gotta build downtown, cousin. It's better if I call mom and tell her that it will take much longer.", "instant": false, "kind": "spoken", "speaker": "Cousin", "slow": 0.055},
		{"image": "scene2_4k.png", "text": "I love you so much, sweetie.", "instant": false, "kind": "spoken", "speaker": "Grandma"},
		{"image": "scene2_4k.png", "text": "Please remember me when I've passed away.", "instant": false, "kind": "spoken", "speaker": "Grandma"},
		{"black": true, "text": "*But one day, something started to paint my life with a melancholic yellow.*", "instant": false, "kind": "narration"},
		{"image": "scene3.png", "text": "*I'm so anxious. I don't wanna arrive at the party.*", "instant": false, "kind": "narration", "speaker": "Jammy", "ambience": "breath_heart"},
		{"image": "scene3.png", "text": "*You won't be able to control your eye movements.*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*You won't be able to control what you say.*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*Don't worry, all those thoughts are lies.*", "instant": false, "kind": "spoken", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*Nobody can notice things like my eye movements or a shift in my mood.*", "instant": false, "kind": "spoken", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*But how do people notice when your eye movements aren't okay, or when somebody is, for example... falling in love with you?.*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*Shut up, mind.*", "instant": false, "kind": "spoken", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*Actions will happen faster than you can react. For example, if you see that old aunt who doesn't get along with you, you might look at her as if you were falling in love with her.*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*You will speak in a tone of voice you don't like because your mind will trigger it before you can do anything about it.*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene3.png", "text": "*I think I'm ruined. I just wanna close my eyes and forget everything.*", "instant": false, "kind": "spoken", "speaker": "Jammy"},
		{"image": "scene4.png", "text": "*Maybe if I type what I'm feeling during these holidays, I'll find something revelatory.*", "instant": false, "kind": "narration", "speaker": "Jammy", "slow": 0.085},
		{"image": "scene5.png", "text": "*What do I have if I get unwanted thoughts and the need to do something to get rid of them?*", "instant": false, "kind": "narration", "speaker": "Jammy", "slow": 0.13},
		{"image": "scene6.png", "text": "*It says... Obsessive-Compulsive Disorder, and the cycle is a trap. But I feel like it happens...", "instant": false, "kind": "narration", "speaker": "Jammy"},
		{"image": "scene6.png", "text": "automatically. And it also says that it's... INCURABLE.*", "instant": false, "kind": "narration", "speaker": "Jammy"},
		{"image": "scene6.png", "text": "*Your life can be summed up by the fact that this illness will bother you until your very last second.*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene6.png", "text": "*My biggest dream is just...", "instant": false, "kind": "narration", "speaker": "Jammy"},
		{"image": "scene6.png", "text": "TO HAVE A NORMAL LIFE. FOR EXAMPLE, TO HAVE FUN WITHOUT THIS...*", "instant": false, "kind": "narration", "speaker": "Jammy"},
		{"image": "scene6.png", "text": "*DESPICABLE...*", "instant": false, "kind": "narration", "speaker": "Jammy"},
		{"image": "scene6.png", "text": "*BASTARD!*", "instant": false, "kind": "narration", "speaker": "Jammy", "ambience": "cry"},
		{"image": "scene6.png", "text": "*Say whatever you want, nothing will change. And you know it... you know...*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene6.png", "text": "*You aren't brave enough to end this forever by yourself.*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene6.png", "text": "*You know your destiny is worse than death.*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene7and8.png", "text": "*Ugh... tomorrow is my first day of high school. It's the only school of this grade in this county.*", "instant": false, "kind": "narration", "speaker": "Jammy"},
		{"image": "scene7and8.png", "text": "*I'll see the same people I've always seen at school. What if...", "instant": false, "kind": "narration", "speaker": "Jammy", "ambience": "breath"},
		{"image": "scene7and8.png", "text": "...they don't treat me like they used to 'cause of OCD, and I take all these troubles outside?*", "instant": false, "kind": "narration", "speaker": "Jammy"},
		{"image": "scene7and8.png", "text": "*Oh, you will. And you know, you haven't been diagnosed by a professional.*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene7and8.png", "text": "*So you have both problems: the mental illness and the uncertainty of not being sure if it's even OCD.*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene7and8.png", "text": "*So it's more difficult to treat something when you don't even know what it is.*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene7and8.png", "text": "*It's scary to do it, but it's even scarier to live 'cause I can't end this easily.*", "instant": false, "kind": "narration", "speaker": "Jammy"},
		{"image": "scene9.png", "text": "You're insane. We don't like you.", "instant": false, "kind": "spoken", "speaker": "Classmates"},
		{"image": "scene9.png", "text": "Yesterday I saw ya at the party while I was doing the team's project.", "instant": false, "kind": "spoken", "speaker": "Classmates"},
		{"image": "scene9.png", "text": "At least we have friends...", "instant": false, "kind": "spoken", "speaker": "Classmates", "ambience": "breath"},
		{"image": "scene9.png", "text": "*What if you start to behave like it never happened?*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene9.png", "text": "*Like for example a cheerful mood... you won't be able to control it.*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene9.png", "text": "*The more you try to control your seriousness, the more you'll do the opposite.*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"black": true, "text": "*My grandma has passed away. I couldn't enjoy her last moments due to OCD.*", "instant": false, "kind": "narration"},
		{"black": true, "text": "*Tomorrow will be my first day at Art University.*", "instant": false, "kind": "narration", "ambience": "breath"},
		{"black": true, "text": "*I don't want to ruin it like high school. I've been feeling so guilty 'bout it and everything.*", "instant": false, "kind": "narration"},
		{"black": true, "text": "*I know that not everything is my fault, but I can't help thinking this way.*", "instant": false, "kind": "narration"},
		{"black": true, "text": "*Everything hurts.*", "instant": false, "kind": "narration"},
		{"black": true, "text": "*I wanna cry but I can't.*", "instant": false, "kind": "narration"},
		{"image": "scene10.png", "text": "*They can't notice you.*", "instant": false, "kind": "narration", "speaker": "Jammy", "ambience": "heartbeat"},
		{"image": "scene10.png", "text": "*But I can't stop being ridiculously tense, anyways.*", "instant": false, "kind": "narration", "speaker": "Jammy", "ambience": "heartbeat"},
		{"image": "scene10.png", "text": "*Oh no, no, no... somebody's approaching me.*", "instant": false, "kind": "narration", "speaker": "Jammy", "ambience": "heartbeat"},
		{"image": "scene10.png", "text": "*What if I mess it up like I messed up other relationships?*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene10.png", "text": "*Where can I turn my head to accomplish both: not looking like I'm ignoring her, and not looking at her while she's coming over?*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene10.png", "text": "*Your face looks like you hate her. You try to fix it, but it isn't enough.*", "instant": true, "kind": "mind", "speaker": "Jammy"},
		{"image": "scene11.png", "text": "Hiiii!", "instant": false, "kind": "spoken", "speaker": "Xcarlet", "ambience": "heartbeat"},
		{"image": "scene12.png", "text": "*This girl's so pretty... I like her. If I look ugly, I'll feel way less pressure around her, 'cause I won't be liked by her, so my OCD won't have the chance to betray me and fuck this relationship up.*", "instant": false, "kind": "narration", "speaker": "Jammy"},
		{"focus": true, "text": "", "instant": true, "kind": "narration"},
		{"image": "scene11.png", "text": "Umm, hi.", "instant": false, "kind": "spoken", "speaker": "Jammy", "sequence": true},
		{"image": "scene11.png", "text": "You looked so concerned. Is everything okay?", "instant": false, "kind": "spoken", "speaker": "Xcarlet", "sequence": true},
		{"image": "scene11.png", "text": "*Oh no, she actually cares about me. What if I disappoint her? What if I look ungrateful? What if I act rude and she ends up throwing me away like the others.....realizing over time that I'm even worse than at first, and it's not just embarrassment...*", "instant": false, "kind": "narration", "speaker": "Jammy", "sequence": true},
		{"image": "scene11.png", "text": "Umm, yeah, LMAO!", "instant": false, "kind": "spoken", "speaker": "Jammy", "sequence": true},
		{"image": "scene11.png", "text": "*LMAO? You looked so ridiculous. Always being such a weirdo.*", "instant": true, "kind": "mind", "speaker": "Jammy", "mixing": "start", "mixing_start": 0.5, "sequence": true},
		{"image": "scene11.png", "text": "*Remember, you're not comfortable touching those cringe notes. I don't wanna give in to a compulsion.....just remember it makes you anxious, and it won't happen again.*", "instant": true, "kind": "narration", "speaker": "Jammy", "mixing": "keep", "sequence": true},
		{"image": "scene11.png", "text": "Well, I'm glad to meet you! My name's Xcarlet, what's your name?", "instant": false, "kind": "spoken", "speaker": "Xcarlet", "mixing": "stop", "sequence": true},
		{"image": "scene11.png", "text": "I'm Jammy.", "instant": false, "kind": "spoken", "speaker": "Jammy", "sequence": true},
		{"image": "scene11.png", "text": "Animation?", "instant": false, "kind": "spoken", "speaker": "Xcarlet", "sequence": true},
		{"image": "scene11.png", "text": "Yeah, I guess we'll be in the same class.", "instant": false, "kind": "spoken", "speaker": "Jammy", "sequence": true},
		{"image": "scene11.png", "text": "Then let's head to our classroom!", "instant": false, "kind": "spoken", "speaker": "Xcarlet", "sequence": true},
		{"image": "scene11.png", "text": "*To be honest, I'm doing pretty well.*", "instant": false, "kind": "narration", "speaker": "Jammy", "sequence": true},
		{"image": "scene11.png", "text": "*But what if I mess it up by reminding you that you're still you? You were just on autopilot, and from now on you won't be.....realizing you have years ahead to keep up this act, and at this very moment she could notice something and suddenly be scared of you.*", "instant": true, "kind": "mind", "speaker": "Jammy", "mixing": "start", "mixing_start": 5.0, "sequence": true},
		{"image": "scene14.png", "text": "*After that crisis before classes, I feel like I acted so bland and rude to her. I realized I was still the same old me, and that's why I got so tense. The worst part is that I wish I could kiss her, but I'm just a weirdo. Why do I gotta be full of these thoughts right when I'm in front of such a beautiful girl?*", "instant": false, "kind": "narration", "speaker": "Jammy", "mixing": "stop", "sfx": "sigh"},
		{"image": "scene14.png", "text": "*I'll just close my eyes and imagine something insane but funny.*", "instant": false, "kind": "narration", "speaker": "Jammy"}
	]

func _fits_in_dialogue_box(candidate: String, font: Font, font_size: int, max_width: float, max_height: float) -> bool:
	var measured := font.get_multiline_string_size(candidate, HORIZONTAL_ALIGNMENT_CENTER, max_width, font_size)
	return measured.y <= max_height

func _split_long_dialogues() -> void:
	var split_entries: Array[Dictionary] = []
	for entry in entries:
		var text: String = str(entry.get("text", ""))
		if entry.get("focus", false) or entry.get("no_split", false):
			split_entries.append(entry.duplicate())
			continue
		var kind: String = str(entry.get("kind", ""))
		var image_name: String = str(entry.get("image", ""))
		var is_mind: bool = kind == "mind"
		var has_start_marker: bool = is_mind or text.begins_with("*")
		var has_end_marker: bool = is_mind or text.ends_with("*")
		var inner_text: String = text.trim_prefix("*").trim_suffix("*")

		var font: Font = ROCK_SALT_FONT if is_mind else FREDOKA_FONT
		var font_size: int = 36 if is_mind else 46
		var max_width: float = 1130.0
		var max_height: float = 165.0

		if kind == "prompt":
			font_size = 58
			max_width = 1220.0
			max_height = 220.0
		elif kind == "instruction":
			font_size = 48
			max_width = 1520.0
			max_height = 260.0
		elif image_name == "scene11.png":
			max_width = 1070.0
			max_height = 155.0
		elif image_name == "scene10.png":
			max_width = 990.0
			max_height = 155.0
		elif image_name == "scene14.png":
			max_width = 1210.0
			max_height = 175.0

		var full_marked: String = _apply_thought_markers(inner_text, has_start_marker, has_end_marker)
		if _fits_in_dialogue_box(full_marked, font, font_size, max_width, max_height):
			var normalized_entry: Dictionary = entry.duplicate()
			normalized_entry["text"] = full_marked
			split_entries.append(normalized_entry)
			continue

		var chunk := ""
		var is_first_chunk := true
		for word in inner_text.split(" "):
			var candidate: String = word if chunk.is_empty() else chunk + " " + word
			var marked_candidate: String = _apply_thought_markers(candidate, has_start_marker, has_end_marker)
			if not chunk.is_empty() and not _fits_in_dialogue_box(marked_candidate, font, font_size, max_width, max_height):
				var chunk_entry: Dictionary = entry.duplicate()
				chunk_entry["text"] = _apply_thought_markers(chunk, has_start_marker, false)
				if not is_first_chunk and str(chunk_entry.get("mixing", "")) == "start":
					chunk_entry["mixing"] = "keep"
				if not is_first_chunk and chunk_entry.has("sfx"):
					chunk_entry.erase("sfx")
				split_entries.append(chunk_entry)
				has_start_marker = false
				is_first_chunk = false
				chunk = word
			else:
				chunk = candidate
		if not chunk.is_empty():
			var final_entry: Dictionary = entry.duplicate()
			final_entry["text"] = _apply_thought_markers(chunk, has_start_marker, has_end_marker)
			if not is_first_chunk and str(final_entry.get("mixing", "")) == "start":
				final_entry["mixing"] = "keep"
			if not is_first_chunk and final_entry.has("sfx"):
				final_entry.erase("sfx")
			split_entries.append(final_entry)
	entries = split_entries

func _apply_thought_markers(text: String, add_start: bool, add_end: bool) -> String:
	var result := text
	if add_start:
		result = "*" + result
	if add_end:
		result += "*"
	return result

func _show_entry() -> void:
	if entry_index >= entries.size():
		_show_ending()
		return
	current_entry = entries[entry_index]
	if current_entry.get("focus", false):
		_start_focus()
		return
	continue_label.visible = false
	dialogue_panel.visible = true
	dialogue_label.visible = true
	focus_instructions.visible = false
	if current_entry.get("black", false):
		background.texture = null
		black_background.visible = true
	else:
		black_background.visible = false
		background.modulate = Color.WHITE
		var img_path := "res://scenes/" + str(current_entry.image)
		if ResourceLoader.exists(img_path):
			background.texture = load(img_path)
		_apply_camera_focus()
	_update_ambience()
	_style_dialogue()
	dialogue_label.visible = true
	focus_instructions.visible = false
	dialogue_label.text = ""
	waiting_for_input = false
	is_typing = true
	typing_token += 1
	var token := typing_token
	current_words = String(current_entry.text).split(" ")
	displayed_words = 0
	if current_entry.get("instant", false):
		dialogue_label.text = current_entry.text
		is_typing = false
		waiting_for_input = true
	else:
		_type_words(token)

func _start_focus() -> void:
	vn_focus_mode = true
	vn_focus_intro = true
	focus_state = FocusState.EFFORT
	focus_effort = 0.0
	focus_window_timer = 0.0
	focus_fakeout_timer = 0.0
	focus_phase_wobble = 0.0
	tex_focus_base = load("res://scenes/scene12.png")
	tex_focus_ugly = load("res://scenes/scene13.png")
	_roll_focus_cycle_params()
	focus_exit_prompt = false
	speaker_panel.visible = false
	background.texture = null
	black_background.visible = false
	focus_image.texture = tex_focus_base
	focus_image.visible = true
	focus_image.scale = Vector2.ONE
	focus_image.position = Vector2.ZERO
	focus_shader_material.set_shader_parameter("blur_amount", 0.0)
	focus_vignette.visible = false
	var vignette_material := focus_vignette.material as ShaderMaterial
	vignette_material.set_shader_parameter("vignette_alpha", 0.0)
	focus_status.visible = false
	focus_hint.visible = false
	dialogue_panel.visible = true
	dialogue_panel.position = Vector2(1270.0, 1520.0)
	dialogue_panel.size = Vector2(1300.0, 240.0)
	dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(Color(0.95, 0.94, 0.91, 0.78), Color(0.1, 0.1, 0.1, 0.25)))
	dialogue_label.visible = false
	focus_instructions.position = Vector2(44, 24)
	focus_instructions.size = Vector2(1212.0, 192.0)
	focus_instructions.text = "[center]Hold [lb]W[rb] and [lb]S[rb] until you turn myself ugly.[/center]\n[center]Release when it's done.[/center]\n[center][lb]ENTER[rb] to begin.[/center]"
	focus_instructions.visible = true
	continue_label.visible = false
	mind_heartbeat_player.stop()
	ambience_player.stop()

func _begin_focus_game() -> void:
	vn_focus_intro = false
	dialogue_panel.visible = false
	focus_instructions.visible = false
	focus_state = FocusState.EFFORT
	focus_effort = 0.0
	focus_phase_wobble = 0.0
	_roll_focus_cycle_params()
	continue_label.visible = false
	focus_status.visible = false
	focus_hint.visible = false
	ambience_player.stop()
	sonido_esfuerzo.stream = effort_stream
	sonido_esfuerzo.pitch_scale = 0.85
	sonido_esfuerzo.volume_db = 0.0
	sonido_esfuerzo.play()

func _apply_focus_tension(is_climax_or_fakeout: bool) -> void:
	var raw_progress := clampf(focus_effort / focus_target_effort, 0.0, 1.0)
	# Satura la tensión percibida al 68% para que el zoom/shake/tono no revelen el 100% real
	var perceived := clampf(raw_progress / 0.68, 0.0, 1.0)
	var wobble := 0.0
	if raw_progress > 0.68:
		wobble = sin(focus_phase_wobble * 9.5) * 0.5 + cos(focus_phase_wobble * 15.3) * 0.5

	var zoom := 1.0 + perceived * 0.115 + wobble * 0.014
	var shake_amp := perceived * 8.2 + absf(wobble) * 3.5
	var shake := sin(Time.get_ticks_msec() * 0.062) * shake_amp
	focus_image.scale = Vector2(zoom, zoom)
	focus_image.position = Vector2(shake, cos(Time.get_ticks_msec() * 0.071) * shake_amp * 0.65)

	if not is_climax_or_fakeout:
		var erratic_blur := 0.0
		if raw_progress > 0.65:
			erratic_blur = clampf(2.4 + wobble * 3.2, 0.0, 6.2)
		focus_shader_material.set_shader_parameter("blur_amount", erratic_blur)
		sonido_esfuerzo.pitch_scale = clampf(lerp(0.85, 1.78, perceived) + wobble * 0.14, 0.85, 1.95)
		sonido_esfuerzo.volume_db = lerp(0.0, 3.8, perceived)

func _begin_focus_fakeout() -> void:
	focus_fakeout_timer = randf_range(0.22, 0.35)
	focus_image.texture = tex_focus_ugly
	focus_shader_material.set_shader_parameter("blur_amount", FOCUS_CLIMAX_BLUR)
	sonido_esfuerzo.volume_db = -8.0

func _begin_focus_window() -> void:
	focus_state = FocusState.WINDOW
	focus_window_timer = FOCUS_WINDOW_TIME
	focus_image.texture = tex_focus_ugly
	focus_shader_material.set_shader_parameter("blur_amount", FOCUS_CLIMAX_BLUR)
	focus_vignette.visible = false
	sonido_esfuerzo.volume_db = -8.0

func _complete_focus() -> void:
	focus_state = FocusState.RESOLUTION
	sonido_esfuerzo.stop()
	sonido_corte.stream = cut_stream
	sonido_corte.play()
	focus_status.visible = false
	focus_hint.visible = false
	mind_heartbeat_player.stop()
	ambience_player.stop()
	dialogue_panel.visible = false
	focus_instructions.visible = false
	continue_label.visible = false
	waiting_for_input = false
	vn_focus_mode = false
	focus_vignette.visible = true
	var resolution_tween := create_tween()
	resolution_tween.tween_method(_update_resolution_effect, 0.0, 1.0, FOCUS_RESOLUTION_TIME)
	resolution_tween.tween_callback(_finish_resolution_effect)

func _reset_focus_cycle() -> void:
	focus_image.texture = tex_focus_base
	focus_image.visible = true
	focus_state = FocusState.EFFORT
	focus_effort = 0.0
	focus_window_timer = 0.0
	focus_fakeout_timer = 0.0
	_roll_focus_cycle_params()
	focus_image.scale = Vector2.ONE
	focus_image.position = Vector2.ZERO
	focus_shader_material.set_shader_parameter("blur_amount", 0.0)
	focus_vignette.visible = false
	var vignette_material := focus_vignette.material as ShaderMaterial
	vignette_material.set_shader_parameter("vignette_alpha", 0.0)
	sonido_esfuerzo.pitch_scale = 0.85
	sonido_esfuerzo.volume_db = 0.0
	if not sonido_esfuerzo.playing:
		sonido_esfuerzo.play()

func _update_focus_music(is_pressing: bool) -> void:
	if not is_pressing:
		if ambience_player.playing:
			ambience_player.stop()
		return
	if ambience_player.stream != FOCUS_SUCCESS_STREAM or not ambience_player.playing:
		ambience_player.stream = FOCUS_SUCCESS_STREAM
		ambience_player.volume_db = 0.0
		ambience_player.play(5.0)
	elif ambience_player.get_playback_position() >= FOCUS_SUCCESS_STREAM.get_length():
		ambience_player.play(5.0)

func _update_resolution_effect(progress: float) -> void:
	focus_shader_material.set_shader_parameter("blur_amount", lerp(FOCUS_CLIMAX_BLUR, 0.0, progress))
	var shake_amount: float = lerp(3.0, 24.0, progress)
	focus_image.position = Vector2(
		sin(Time.get_ticks_msec() * 0.06) * shake_amount,
		cos(Time.get_ticks_msec() * 0.071) * shake_amount
	)
	focus_image.scale = Vector2.ONE * (1.0 + progress * 0.035)
	var vignette_material := focus_vignette.material as ShaderMaterial
	vignette_material.set_shader_parameter("vignette_alpha", progress * 0.85)

func _finish_resolution_effect() -> void:
	focus_image.position = Vector2.ZERO
	focus_image.scale = Vector2.ONE
	focus_shader_material.set_shader_parameter("blur_amount", 0.0)
	var vignette_material := focus_vignette.material as ShaderMaterial
	vignette_material.set_shader_parameter("vignette_alpha", 0.0)
	focus_vignette.visible = false
	focus_exit_prompt = true
	dialogue_panel.visible = true
	dialogue_panel.position = Vector2(1420.0, 1520.0)
	dialogue_panel.size = Vector2(1000.0, 200.0)
	dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(Color(0.95, 0.94, 0.91, 0.78), Color(0.1, 0.1, 0.1, 0.25)))
	dialogue_label.visible = false
	focus_instructions.position = Vector2(44, 24)
	focus_instructions.size = Vector2(912.0, 152.0)
	focus_instructions.text = "[center]Press [lb]ENTER[rb][/center]"
	focus_instructions.visible = true

func _leave_focus_game() -> void:
	focus_exit_prompt = false
	vn_focus_mode = false
	_stop_mixing_game_loop()
	dialogue_panel.visible = false
	focus_instructions.visible = false
	focus_image.visible = false
	background.visible = true
	background.texture = load("res://scenes/scene11.png")
	entry_index += 1
	_show_entry()

func _start_mixing_game_loop(start_position: float) -> void:
	mixing_game_active = true
	mixing_loop_start = start_position
	ambience_player.stop()
	ambience_player.stream = FOCUS_SUCCESS_STREAM
	ambience_player.volume_db = 0.0
	ambience_player.play(mixing_loop_start)

func _stop_mixing_game_loop() -> void:
	mixing_game_active = false
	if ambience_player.stream == FOCUS_SUCCESS_STREAM:
		ambience_player.stop()

func _maintain_mixing_game_loop() -> void:
	if not ambience_player.playing:
		ambience_player.play(mixing_loop_start)
	elif ambience_player.get_playback_position() >= 19.0:
		ambience_player.play(mixing_loop_start)

func _type_words(token: int) -> void:
	var delay := float(current_entry.get("slow", 0.045))
	var plays_typewriter := str(current_entry.get("kind", "")) != "mind"
	var sound_step := 2 if current_words.size() >= 3 else 1
	while displayed_words < current_words.size() and token == typing_token:
		var word := current_words[displayed_words]
		dialogue_label.text += ("" if displayed_words == 0 else " ") + word
		if plays_typewriter and displayed_words % sound_step == 0:
			typewriter_player.stop()
			typewriter_player.stream = typewriter_stream
			typewriter_player.play()
		displayed_words += 1
		await get_tree().create_timer(delay).timeout
	if token == typing_token:
		if plays_typewriter:
			typewriter_player.stop()
		is_typing = false
		waiting_for_input = true

func _advance() -> void:
	if is_typing:
		typing_token += 1
		typewriter_player.stop()
		dialogue_label.text = current_entry.text
		is_typing = false
		waiting_for_input = true
		return
	if waiting_for_input:
		entry_index += 1
		_show_entry()

func _apply_camera_focus() -> void:
	background.scale = Vector2.ONE
	background.position = Vector2.ZERO
	var image_name: String = str(current_entry.get("image", ""))
	var text: String = str(current_entry.get("text", ""))
	if image_name == "scene7and8.png" and text.contains("It's scary to do it"):
		background.scale = Vector2(2.1, 2.1)
		background.position = Vector2(-2880, -270)

func _unhandled_input(event: InputEvent) -> void:
	var advance_pressed := false
	if event is InputEventKey:
		advance_pressed = event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)
	elif event is InputEventMouseButton:
		advance_pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if advance_pressed:
		if focus_exit_prompt:
			_leave_focus_game()
			return
		if vn_focus_mode:
			if vn_focus_intro:
				_begin_focus_game()
			return
		_advance()

func _get_speaker_color(speaker_name: String) -> Color:
	match speaker_name.to_lower():
		"jammy":
			return JAMMY_COLOR
		"cousin":
			return COUSIN_COLOR
		"xcarlet":
			return XCARLET_COLOR
		"grandma":
			return GRANDMA_COLOR
		"classmates":
			return CLASSMATES_BOX_COLOR
		_:
			return TEXT_COLOR

func _style_dialogue() -> void:
	var kind: String = str(current_entry.get("kind", ""))
	var is_mind: bool = kind == "mind"
	var speaker: String = str(current_entry.get("speaker", ""))
	var image_name: String = str(current_entry.get("image", ""))
	var is_black: bool = current_entry.get("black", false)

	if is_mind and speaker.is_empty() and not is_black:
		speaker = "Jammy"

	dialogue_label.add_theme_color_override("font_shadow_color", Color("#000000f0"))
	dialogue_label.add_theme_constant_override("shadow_offset_x", 4)
	dialogue_label.add_theme_constant_override("shadow_offset_y", 4)

	var panel_pos := DIALOGUE_PANEL_POS
	var panel_size := DIALOGUE_PANEL_SIZE

	if is_black:
		panel_pos = Vector2(1250.0, 940.0)
		panel_size = Vector2(1340.0, 250.0)
	elif image_name == "scene1_4k.png":
		panel_pos = Vector2(1620.0, 860.0)
	elif image_name == "scene2_4k.png":
		panel_pos = Vector2(2080.0, 480.0)
	elif image_name == "scene3.png":
		panel_pos = Vector2(1280.0, 920.0)
	elif image_name in ["scene4.png", "scene5.png", "scene6.png"]:
		panel_pos = Vector2(1300.0, 1180.0)
	elif image_name == "scene7and8.png":
		panel_pos = Vector2(960.0, 1040.0)
	elif image_name == "scene9.png":
		if speaker.to_lower() == "classmates":
			panel_pos = Vector2(1920.0, 1000.0)
		else:
			panel_pos = Vector2(1340.0, 1340.0)
	elif image_name == "scene10.png":
		panel_pos = Vector2(520.0, 940.0)
		panel_size = Vector2(1100.0, 220.0)
	elif image_name == "scene11.png":
		panel_size = Vector2(1180.0, 220.0)
		if speaker.to_lower() == "xcarlet":
			panel_pos = Vector2(860.0, 1040.0)
		else:
			panel_pos = Vector2(480.0, 1080.0)
	elif image_name == "scene12.png":
		panel_pos = Vector2(1320.0, 1480.0)
	elif image_name == "scene14.png":
		panel_pos = Vector2(1260.0, 480.0)
		panel_size = Vector2(1320.0, 240.0)

	if kind == "prompt":
		panel_pos = Vector2(1250.0, 920.0)
		panel_size = Vector2(1340.0, 280.0)
		dialogue_label.add_theme_font_size_override("font_size", 58)
	elif kind == "instruction":
		panel_pos = Vector2(1100.0, 860.0)
		panel_size = Vector2(1640.0, 320.0)
		dialogue_label.add_theme_font_size_override("font_size", 48)
	elif is_mind:
		dialogue_label.add_theme_font_size_override("font_size", 36)
	else:
		dialogue_label.add_theme_font_size_override("font_size", 46)

	dialogue_panel.position = panel_pos
	dialogue_panel.size = panel_size
	dialogue_label.position = Vector2(44, 24)
	dialogue_label.size = Vector2(panel_size.x - 88.0, panel_size.y - 48.0)

	if kind == "instruction" or kind == "prompt":
		speaker_panel.visible = false
		dialogue_label.add_theme_color_override("font_color", Color("#161616"))
		dialogue_label.add_theme_font_override("font", FREDOKA_FONT)
		dialogue_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		dialogue_label.add_theme_constant_override("shadow_offset_x", 0)
		dialogue_label.add_theme_constant_override("shadow_offset_y", 0)
		dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(Color(0.95, 0.94, 0.91, 0.78), Color(0.1, 0.1, 0.1, 0.25)))
	elif is_black:
		speaker_panel.visible = false
		dialogue_label.add_theme_color_override("font_color", MIND_COLOR if is_mind else TEXT_COLOR)
		dialogue_label.add_theme_font_override("font", ROCK_SALT_FONT if is_mind else FREDOKA_FONT)
		dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, Color(1.0, 1.0, 1.0, 0.25)))
	elif is_mind:
		dialogue_label.add_theme_color_override("font_color", MIND_COLOR)
		dialogue_label.add_theme_font_override("font", ROCK_SALT_FONT)
		var j_border := Color(JAMMY_COLOR.r, JAMMY_COLOR.g, JAMMY_COLOR.b, 0.65)
		dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(MIND_PANEL_COLOR, j_border))
		speaker_panel.visible = true
		speaker_panel.position = Vector2(panel_pos.x + 36.0, panel_pos.y - SPEAKER_PANEL_SIZE.y + 2.0)
		speaker_panel.size = SPEAKER_PANEL_SIZE
		speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, JAMMY_COLOR))
		speaker_label.text = "Jammy"
		speaker_label.add_theme_color_override("font_color", JAMMY_COLOR)
	else:
		dialogue_label.add_theme_color_override("font_color", TEXT_COLOR)
		dialogue_label.add_theme_font_override("font", FREDOKA_FONT)
		if not speaker.is_empty():
			if speaker.to_lower() == "classmates":
				var box_border := Color(CLASSMATES_BOX_COLOR.r, CLASSMATES_BOX_COLOR.g, CLASSMATES_BOX_COLOR.b, 0.75)
				dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, box_border))
				speaker_panel.visible = true
				speaker_panel.position = Vector2(panel_pos.x + 36.0, panel_pos.y - SPEAKER_PANEL_SIZE.y + 2.0)
				speaker_panel.size = SPEAKER_PANEL_SIZE
				speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, CLASSMATES_TAB_COLOR))
				speaker_label.text = "Classmates"
				speaker_label.add_theme_color_override("font_color", CLASSMATES_TEXT_COLOR)
			else:
				var s_color := _get_speaker_color(speaker)
				var s_border := Color(s_color.r, s_color.g, s_color.b, 0.65)
				dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, s_border))
				speaker_panel.visible = true
				speaker_panel.position = Vector2(panel_pos.x + 36.0, panel_pos.y - SPEAKER_PANEL_SIZE.y + 2.0)
				speaker_panel.size = SPEAKER_PANEL_SIZE
				speaker_panel.add_theme_stylebox_override("panel", _make_speaker_style(SPEAKER_BG_COLOR, s_color))
				speaker_label.text = speaker
				speaker_label.add_theme_color_override("font_color", s_color)
		else:
			speaker_panel.visible = false
			dialogue_panel.add_theme_stylebox_override("panel", _make_dialogue_style(PANEL_COLOR, Color(1.0, 1.0, 1.0, 0.25)))

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

func _load_first_existing_audio(paths: Array[String]) -> AudioStream:
	for path in paths:
		if ResourceLoader.exists(path):
			return load(path)
	return null

func _build_audio() -> void:
	typewriter_stream = NORMAL_DIALOGUE_STREAM
	breath_stream = BREATHING_STREAM
	heartbeat_stream = HEARTBEAT_STREAM
	effort_stream = FOCUS_EFFORT_STREAM
	cut_stream = _make_tone(0.12, 180.0, 0.32, false)

	night_ambience_stream = _load_first_existing_audio([
		"res://assets/sounds/crickets-and-distant-owls.mp3",
		"res://crickets-and-distant-owls.mp3"
	])
	sigh_stream = _load_first_existing_audio([
		"res://assets/sounds/sighs.mp3",
		"res://assets/sounds/sighs.ogg",
		"res://assets/sounds/sighs.wav",
		"res://sighs.mp3",
		"res://sighs.ogg",
		"res://sighs.wav"
	])

	var effort_mp3 := effort_stream as AudioStreamMP3
	if effort_mp3:
		effort_mp3.loop = true
	var heartbeat_mp3 := heartbeat_stream as AudioStreamMP3
	if heartbeat_mp3:
		heartbeat_mp3.loop = true
	var success_mp3 := FOCUS_SUCCESS_STREAM as AudioStreamMP3
	if success_mp3:
		success_mp3.loop = false
	var night_mp3 := night_ambience_stream as AudioStreamMP3
	if night_mp3:
		night_mp3.loop = true
	var sigh_mp3 := sigh_stream as AudioStreamMP3
	if sigh_mp3:
		sigh_mp3.loop = false

func _make_tone(duration: float, frequency: float, volume: float, looping: bool) -> AudioStreamWAV:
	var rate := 22050
	var samples := int(duration * rate)
	var data := PackedByteArray()
	for i in samples:
		var sample := sin(TAU * frequency * float(i) / rate) * volume
		var value := int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.append(value & 0xff)
		data.append((value >> 8) & 0xff)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples
	return stream

func _update_ambience() -> void:
	var image_name: String = str(current_entry.get("image", ""))
	var is_mind: bool = current_entry.get("kind", "") == "mind"
	var mixing_mode := str(current_entry.get("mixing", ""))
	var is_focus_sequence: bool = current_entry.get("sequence", false)

	if str(current_entry.get("sfx", "")) == "sigh" and sigh_stream != null:
		sfx_player.stop()
		sfx_player.stream = sigh_stream
		sfx_player.volume_db = 0.0
		sfx_player.play()

	if is_focus_sequence:
		mind_breath_player.stop()
		mind_heartbeat_player.stop()
		if mixing_mode == "start":
			_start_mixing_game_loop(float(current_entry.get("mixing_start", 0.5)))
		elif mixing_mode == "stop":
			_stop_mixing_game_loop()
		if not mixing_game_active:
			ambience_player.stop()
		return

	if mixing_mode == "start":
		_start_mixing_game_loop(float(current_entry.get("mixing_start", 0.5)))
	elif mixing_mode == "stop":
		_stop_mixing_game_loop()
	if mixing_mode == "keep" or mixing_mode == "start":
		return
	if is_mind:
		ambience_player.stop()
		if not mind_breath_player.playing:
			mind_breath_player.stream = breath_stream
			mind_breath_player.volume_db = 0.0
			mind_breath_player.play()
		if not mind_heartbeat_player.playing:
			mind_heartbeat_player.stream = heartbeat_stream
			mind_heartbeat_player.volume_db = 0.0
			mind_heartbeat_player.play(0.0)
	elif image_name == "scene14.png":
		mind_heartbeat_player.stop()
		mind_breath_player.stop()
		if night_ambience_stream != null and (ambience_player.stream != night_ambience_stream or not ambience_player.playing):
			ambience_player.stop()
			ambience_player.stream = night_ambience_stream
			ambience_player.volume_db = 0.0
			ambience_player.play()
	elif image_name in ["scene10.png", "scene11.png"]:
		mind_heartbeat_player.stop()
		if ambience_player.stream != breath_stream or not ambience_player.playing:
			ambience_player.stop()
			ambience_player.stream = breath_stream
			ambience_player.volume_db = -3.0
			ambience_player.play()
	else:
		ambience_player.stop()
		mind_heartbeat_player.stop()
		mind_breath_player.stop()

func _show_ending() -> void:
	waiting_for_input = false
	is_typing = false
	_stop_mixing_game_loop()
	ambience_player.stop()
	sfx_player.stop()
	
	var ruta_nivel2 := "res://scenes/Level2.tscn"
	if not ResourceLoader.exists(ruta_nivel2) and ResourceLoader.exists("res://Level2.tscn"):
		ruta_nivel2 = "res://Level2.tscn"
	
	var eye_trans := get_node_or_null("/root/EyeTransition")
	if eye_trans == null and ResourceLoader.exists("res://EyeTransition.gd"):
		eye_trans = load("res://EyeTransition.gd").new()
		get_tree().root.add_child(eye_trans)
	
	if eye_trans != null:
		eye_trans.ir_a_escena_cerrando_ojos(ruta_nivel2)
	else:
		get_tree().change_scene_to_file(ruta_nivel2)
