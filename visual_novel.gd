extends Control

const BASE_SIZE := Vector2(3840.0, 2160.0)
const TEXT_COLOR := Color("#fff9f0")
const PANEL_COLOR := Color("#18212a99")
const MIND_COLOR := Color("#ff5a5f")
const ACCENT_COLOR := Color("#fff9f0")
const DIALOGUE_PANEL_SIZE := Vector2(1600.0, 280.0)
const DIALOGUE_TEXT_SIZE := Vector2(1480.0, 230.0)
const FREDOKA_FONT = preload("res://fonts/Fredoka-Regular.ttf")
const ROCK_SALT_FONT = preload("res://fonts/RockSalt-Regular.ttf")

var background: TextureRect
var black_background: ColorRect
var dialogue_panel: Panel
var dialogue_label: Label
var continue_label: Label
var typewriter_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var click_stream: AudioStreamWAV
var breath_stream: AudioStreamWAV
var heartbeat_stream: AudioStreamWAV

var entries: Array[Dictionary] = []
var entry_index := 0
var is_typing := false
var typing_token := 0
var displayed_words := 0
var current_words: PackedStringArray
var current_entry: Dictionary
var waiting_for_input := false

func _ready() -> void:
	_build_audio()
	_build_ui()
	_build_script()
	_split_long_dialogues()
	_show_entry()

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
	dialogue_panel.position = Vector2(820, 1580)
	dialogue_panel.size = DIALOGUE_PANEL_SIZE
	dialogue_panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_COLOR))
	add_child(dialogue_panel)

	dialogue_label = Label.new()
	dialogue_label.position = Vector2(60, 25)
	dialogue_label.size = DIALOGUE_TEXT_SIZE
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.clip_text = false
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.add_theme_font_size_override("font_size", 62)
	dialogue_label.add_theme_font_override("font", FREDOKA_FONT)
	dialogue_label.add_theme_color_override("font_color", TEXT_COLOR)
	dialogue_label.add_theme_color_override("font_shadow_color", Color("#000000cc"))
	dialogue_label.add_theme_constant_override("shadow_offset_x", 5)
	dialogue_label.add_theme_constant_override("shadow_offset_y", 5)
	dialogue_panel.add_child(dialogue_label)

	continue_label = Label.new()
	continue_label.position = Vector2(0, 2020)
	continue_label.size = Vector2(3840, 70)
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.add_theme_font_size_override("font_size", 42)
	continue_label.add_theme_color_override("font_color", ACCENT_COLOR)
	continue_label.text = "ENTER / SPACE"
	continue_label.visible = false
	add_child(continue_label)

	typewriter_player = AudioStreamPlayer.new()
	add_child(typewriter_player)
	ambience_player = AudioStreamPlayer.new()
	add_child(ambience_player)

func _build_script() -> void:
	entries = [
		{"image": "scene1_4k.png", "text": "To continue, press SPACE", "instant": true, "kind": "prompt"},
		{"image": "scene1_4k.png", "text": "The asterisks (* *) indicate that the dialogue belongs to the character's mind.", "instant": false, "kind": "instruction"},
		{"image": "scene1_4k.png", "text": "We still gotta build downtown, cousin. It's better if I call mom and tell her that it will take much longer.", "instant": false, "kind": "spoken", "slow": 0.055},
		{"image": "scene2_4k.png", "text": "I love you so much, sweetie.", "instant": false, "kind": "spoken"},
		{"image": "scene2_4k.png", "text": "Please remember me when I've passed away.", "instant": false, "kind": "spoken"},
		{"black": true, "text": "*But one day, something started to paint my life with a melancholic yellow.*", "instant": false, "kind": "narration"},
		{"image": "scene3.png", "text": "*I'm so anxious. I don't wanna arrive at the party.*", "instant": false, "kind": "narration", "ambience": "breath_heart"},
		{"image": "scene3.png", "text": "*You won't be able to control your eye movements.*", "instant": true, "kind": "mind"},
		{"image": "scene3.png", "text": "*You won't be able to control what you say.*", "instant": true, "kind": "mind"},
		{"image": "scene3.png", "text": "*Don't worry, all those thoughts are lies.*", "instant": false, "kind": "spoken"},
		{"image": "scene3.png", "text": "*Nobody can notice things like my eye movements or a shift in my mood.*", "instant": false, "kind": "spoken"},
		{"image": "scene3.png", "text": "*But how do people notice when your eye movements aren't okay, or when somebody is, for example... falling in love with you?.*", "instant": true, "kind": "mind"},
		{"image": "scene3.png", "text": "*Shut up, mind.*", "instant": false, "kind": "spoken"},
		{"image": "scene3.png", "text": "*Actions will happen faster than you can react. For example, if you see that old aunt who doesn't get along with you, you might look at her as if you were falling in love with her.*", "instant": true, "kind": "mind"},
		{"image": "scene3.png", "text": "*You will speak in a tone of voice you don't like because your mind will trigger it before you can do anything about it.*", "instant": true, "kind": "mind"},
		{"image": "scene3.png", "text": "*I think I'm ruined. I just wanna close my eyes and forget everything.*", "instant": false, "kind": "spoken"},
		{"image": "scene4.png", "text": "*Maybe if I type what I'm feeling during these holidays, I'll find something revelatory.*", "instant": false, "kind": "narration", "slow": 0.085},
		{"image": "scene5.png", "text": "*What do I have if I get unwanted thoughts and the need to do something to get rid of them?*", "instant": false, "kind": "narration", "slow": 0.13},
		{"image": "scene6.png", "text": "*It says... Obsessive-Compulsive Disorder, and the cycle is a trap. But I feel like it happens...", "instant": false, "kind": "narration"},
		{"image": "scene6.png", "text": "automatically. And it also says that it's... INCURABLE.*", "instant": false, "kind": "narration"},
		{"image": "scene6.png", "text": "*Your life can be summed up by the fact that this illness will bother you until your very last second.*", "instant": true, "kind": "mind"},
		{"image": "scene6.png", "text": "*My biggest dream is just...", "instant": false, "kind": "narration"},
		{"image": "scene6.png", "text": "TO HAVE A NORMAL LIFE. FOR EXAMPLE, TO HAVE FUN WITHOUT THIS...*", "instant": false, "kind": "narration"},
		{"image": "scene6.png", "text": "*DESPICABLE...*", "instant": false, "kind": "narration"},
		{"image": "scene6.png", "text": "*BASTARD!*", "instant": false, "kind": "narration", "ambience": "cry"},
		{"image": "scene6.png", "text": "*Say whatever you want, nothing will change. And you know it... you know...*", "instant": true, "kind": "mind"},
		{"image": "scene6.png", "text": "*You aren't brave enough to end this forever by yourself.*", "instant": true, "kind": "mind"},
		{"image": "scene6.png", "text": "*You know your destiny is worse than death.*", "instant": true, "kind": "mind"},
		{"image": "scene7and8.png", "text": "*Ugh... tomorrow is my first day of high school. It's the only school of this grade in this county.*", "instant": false, "kind": "narration"},
		{"image": "scene7and8.png", "text": "*I'll see the same people I've always seen at school. What if...", "instant": false, "kind": "narration", "ambience": "breath"},
		{"image": "scene7and8.png", "text": "...they don't treat me like they used to 'cause of OCD, and I take all these troubles outside?*", "instant": false, "kind": "narration"},
		{"image": "scene7and8.png", "text": "*Oh, you will. And you know, you haven't been diagnosed by a professional.*", "instant": true, "kind": "mind"},
		{"image": "scene7and8.png", "text": "*So you have both problems: the mental illness and the uncertainty of not being sure if it's even OCD.*", "instant": true, "kind": "mind"},
		{"image": "scene7and8.png", "text": "*So it's more difficult to treat something when you don't even know what it is.*", "instant": true, "kind": "mind"},
		{"image": "scene7and8.png", "text": "*It's scary to do it, but it's even scarier to live 'cause I can't end this easily.*", "instant": false, "kind": "narration"},
		{"image": "scene9.png", "text": "You're insane. We don't like you.", "instant": false, "kind": "spoken"},
		{"image": "scene9.png", "text": "Yesterday I saw ya at the party while I was doing the team's project.", "instant": false, "kind": "spoken"},
		{"image": "scene9.png", "text": "At least we have friends...", "instant": false, "kind": "spoken", "ambience": "breath"},
		{"image": "scene9.png", "text": "*What if you start to behave like it never happened?*", "instant": true, "kind": "mind"},
		{"image": "scene9.png", "text": "*Like for example a cheerful mood... you won't be able to control it.*", "instant": true, "kind": "mind"},
		{"image": "scene9.png", "text": "*The more you try to control your seriousness, the more you'll do the opposite.*", "instant": true, "kind": "mind"},
		{"black": true, "text": "*My grandma has passed away. I couldn't enjoy her last moments due to OCD.*", "instant": false, "kind": "narration"},
		{"black": true, "text": "*Tomorrow will be my first day at Art University.*", "instant": false, "kind": "narration", "ambience": "breath"},
		{"black": true, "text": "*I don't want to ruin it like high school. I've been feeling so guilty 'bout it and everything.*", "instant": false, "kind": "narration"},
		{"black": true, "text": "*I know that not everything is my fault, but I can't help thinking this way.*", "instant": false, "kind": "narration"},
		{"black": true, "text": "*Everything hurts.*", "instant": false, "kind": "narration"},
		{"black": true, "text": "*I wanna cry but I can't.*", "instant": false, "kind": "narration"},
		{"image": "scene10.png", "text": "*They can't notice you.*", "instant": false, "kind": "narration"},
		{"image": "scene10.png", "text": "*But I can't stop being ridiculously tense, anyways.*", "instant": false, "kind": "narration", "ambience": "heartbeat"},
		{"image": "scene10.png", "text": "*Oh no, no, no... somebody's approaching me.*", "instant": false, "kind": "narration"},
		{"image": "scene10.png", "text": "*What if I mess it up like I messed up other relationships?*", "instant": true, "kind": "mind"},
		{"image": "scene10.png", "text": "*Where can I turn my head to accomplish both: not looking like I'm ignoring her, and not looking at her while she's coming over?*", "instant": true, "kind": "mind"},
		{"image": "scene10.png", "text": "*Your face looks like you hate her. You try to fix it, but it isn't enough.*", "instant": true, "kind": "mind"},
		{"image": "scene11.png", "text": "Hiiii!", "instant": false, "kind": "spoken"}
	]

func _split_long_dialogues() -> void:
	var split_entries: Array[Dictionary] = []
	for entry in entries:
		var text: String = str(entry.get("text", ""))
		var is_mind: bool = str(entry.get("kind", "")) == "mind"
		var has_mind_markers: bool = is_mind or text.begins_with("*") or text.ends_with("*")
		var has_start_marker: bool = is_mind or text.begins_with("*")
		var has_end_marker: bool = is_mind or text.ends_with("*")
		var inner_text: String = text.trim_prefix("*").trim_suffix("*")
		var character_limit: int = 58 if is_mind else 78
		if str(entry.get("image", "")) == "scene10.png":
			character_limit = 38 if is_mind else 48
		if str(entry.get("kind", "")) == "instruction":
			character_limit = 180
		if has_mind_markers:
			text = "*" + inner_text + "*"
		if text.length() <= character_limit:
			var normalized_entry: Dictionary = entry.duplicate()
			normalized_entry["text"] = _apply_thought_markers(inner_text, has_start_marker, has_end_marker)
			split_entries.append(normalized_entry)
			continue

		var chunk := ""
		for word in inner_text.split(" "):
			var candidate: String = word if chunk.is_empty() else chunk + " " + word
			if not chunk.is_empty() and candidate.length() > character_limit:
				var chunk_entry: Dictionary = entry.duplicate()
				chunk_entry["text"] = _apply_thought_markers(chunk, has_start_marker, false)
				split_entries.append(chunk_entry)
				has_start_marker = false
				chunk = word
			else:
				chunk = candidate
		if not chunk.is_empty():
			var final_entry: Dictionary = entry.duplicate()
			final_entry["text"] = _apply_thought_markers(chunk, has_start_marker, has_end_marker)
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
	continue_label.visible = false
	if current_entry.get("black", false):
		background.texture = null
		black_background.visible = true
	else:
		black_background.visible = false
		background.modulate = Color.WHITE
		background.texture = load("res://scenes/" + current_entry.image)
		_apply_camera_focus()
	_update_ambience()
	_style_dialogue()
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

func _type_words(token: int) -> void:
	var delay := float(current_entry.get("slow", 0.045))
	while displayed_words < current_words.size() and token == typing_token:
		var word := current_words[displayed_words]
		dialogue_label.text += ("" if displayed_words == 0 else " ") + word
		displayed_words += 1
		typewriter_player.stream = click_stream
		typewriter_player.play()
		await get_tree().create_timer(delay).timeout
	if token == typing_token:
		is_typing = false
		waiting_for_input = true

func _advance() -> void:
	if is_typing:
		typing_token += 1
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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_advance()

func _style_dialogue() -> void:
	var is_mind: bool = current_entry.get("kind", "") == "mind"
	if is_mind:
		dialogue_label.add_theme_color_override("font_color", MIND_COLOR)
		dialogue_label.add_theme_font_size_override("font_size", 58)
		dialogue_label.add_theme_font_override("font", ROCK_SALT_FONT)
		dialogue_panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_COLOR))
	else:
		dialogue_label.add_theme_color_override("font_color", TEXT_COLOR)
		dialogue_label.add_theme_font_size_override("font_size", 62)
		dialogue_label.add_theme_font_override("font", FREDOKA_FONT)
		dialogue_panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_COLOR))
	var image_name: String = str(current_entry.get("image", ""))
	var text: String = str(current_entry.get("text", ""))
	dialogue_panel.position = Vector2(820, 1580)
	dialogue_panel.size = DIALOGUE_PANEL_SIZE
	dialogue_label.size = DIALOGUE_TEXT_SIZE
	if str(current_entry.get("kind", "")) == "prompt":
		dialogue_panel.position = Vector2(1120, 900)
		dialogue_panel.size = Vector2(1600, 360)
		dialogue_label.size = Vector2(1480, 310)
		dialogue_label.add_theme_font_size_override("font_size", 72)
	elif str(current_entry.get("kind", "")) == "instruction":
		dialogue_panel.position = Vector2(920, 820)
		dialogue_panel.size = Vector2(2000, 420)
		dialogue_label.size = Vector2(1880, 370)
		dialogue_label.add_theme_font_size_override("font_size", 58)
	if current_entry.get("black", false):
		dialogue_panel.position = Vector2(1120, 940)
	if image_name == "scene1_4k.png":
		dialogue_panel.position = Vector2(1330, 850)
	elif image_name == "scene2_4k.png":
		dialogue_panel.position = Vector2(1870, 450)
	elif image_name == "scene3.png":
		dialogue_panel.position = Vector2(1120, 1180)
	elif image_name in ["scene4.png", "scene5.png", "scene6.png"]:
		dialogue_panel.position = Vector2(1120, 1150)
	elif image_name == "scene7and8.png":
		dialogue_panel.position = Vector2(1120, 1250)
	elif image_name == "scene9.png":
		dialogue_panel.position = Vector2(1800, 960)
		if text.begins_with("Yesterday I saw ya"):
			dialogue_panel.position = Vector2(1800, 960)
		elif str(current_entry.get("kind", "")) == "mind":
			dialogue_panel.position = Vector2(1050, 1350)
	elif image_name == "scene10.png":
		dialogue_panel.position = Vector2(520, 1020)
		dialogue_panel.size = Vector2(1200, 260)
		dialogue_label.size = Vector2(1080, 210)
	elif image_name == "scene11.png":
		dialogue_panel.position = Vector2(1050, 900)
		dialogue_panel.size = Vector2(900, 240)
		dialogue_label.size = Vector2(780, 190)
	if str(current_entry.get("kind", "")) == "prompt":
		dialogue_panel.position = Vector2(1120, 900)
	elif str(current_entry.get("kind", "")) == "instruction":
		dialogue_panel.position = Vector2(920, 820)

func _make_panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style

func _build_audio() -> void:
	click_stream = _make_tone(0.035, 1500.0, 0.18, false)
	breath_stream = _make_tone(1.6, 160.0, 0.12, true)
	heartbeat_stream = _make_heartbeat()

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

func _make_heartbeat() -> AudioStreamWAV:
	var stream := _make_tone(1.4, 72.0, 0.22, true)
	return stream

func _update_ambience() -> void:
	var ambience: String = str(current_entry.get("ambience", ""))
	if ambience in ["breath", "breath_heart", "cry"]:
		ambience_player.stream = breath_stream
		ambience_player.volume_db = -12.0
		ambience_player.play()
	elif ambience == "heartbeat":
		ambience_player.stream = heartbeat_stream
		ambience_player.volume_db = -9.0
		ambience_player.play()
	else:
		ambience_player.stop()

func _show_ending() -> void:
	background.texture = null
	dialogue_panel.visible = false
	continue_label.text = "THE END"
