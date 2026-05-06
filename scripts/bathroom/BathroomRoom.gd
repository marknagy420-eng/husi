extends Control

signal cleaning_finished(happiness_gain: int)

const Localization = preload("res://scripts/core/Localization.gd")
const PetScene = preload("res://scenes/pet/Pet.tscn")

const SOAP_TEXTURE := preload("res://Bathroom/szappan.png")
const SHOWER_TEXTURE := preload("res://Bathroom/tusi.png")
const TOWEL_TEXTURE := preload("res://Bathroom/torcsi.png")
const SPEECH_BUBBLE_TEXTURE := preload("res://speechbubble/messeage.png")
const SPEECH_BUBBLE_REGION := Rect2(44.0, 350.0, 938.0, 760.0)
const CLEAN_MESSAGE_KEYS := [
	"bathroom.clean.message.1",
	"bathroom.clean.message.2",
	"bathroom.clean.message.3",
	"bathroom.clean.message.4",
	"bathroom.clean.message.5"
]
const TOOL_TEXTURES := {
	"soap": SOAP_TEXTURE,
	"shower": SHOWER_TEXTURE,
	"towel": TOWEL_TEXTURE
}
const SOAP_RATE := 62.0
const SHOWER_RATE := 72.0
const TOWEL_RATE := 88.0
const FINISH_HAPPINESS_GAIN := 10

var current_language := "hu"
var current_cleanliness := 100.0
var cleaning_start_cleanliness := 100.0
var current_stats: Dictionary = {}
var current_skin := "default"
var soap_progress := 0.0
var rinse_progress := 0.0
var towel_progress := 0.0
var session_finished := false
var start_message_shown := false
var already_clean_notice_shown := false
var active_tool_id := ""
var drag_pointer_position := Vector2.ZERO
var bubble_message_key := ""
var last_finish_message_index := -1
var bubble_tween: Tween
var bubble_base_position := Vector2.ZERO

var pet: Node2D
var info_label: Label
var tool_slots: Dictionary = {}
var drag_preview: TextureRect
var speech_bubble: Control
var speech_bubble_label: Label
var speech_bubble_timer: Timer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_build_ui()
	_refresh_ui()

func configure(language_code: String, skin_id: String, stats: Dictionary, cleanliness: float) -> void:
	current_language = language_code
	current_skin = skin_id
	current_stats = stats.duplicate(true)
	if not active_tool_id:
		_reset_session(cleanliness)
	else:
		current_cleanliness = clampf(cleanliness, 0.0, 100.0)
	pet.set_skin(current_skin)
	pet.set_stats(current_stats)
	pet.set_cleanliness(current_cleanliness)
	_refresh_pet_effects()
	_refresh_ui()

func set_localization(language_code: String) -> void:
	current_language = language_code
	if bubble_message_key != "":
		speech_bubble_label.text = Localization.text(current_language, bubble_message_key)
	_refresh_ui()

func open_room() -> void:
	visible = true
	_refresh_ui()

func close_room() -> void:
	visible = false
	active_tool_id = ""
	drag_preview.visible = false

func _process(delta: float) -> void:
	if active_tool_id == "":
		return
	_update_drag_preview(drag_pointer_position)
	if not pet.contains_global_point(drag_pointer_position):
		return
	_advance_cleaning(active_tool_id, delta)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var tool_id := _tool_at_point(event.position)
			if tool_id != "":
				_start_drag(tool_id, event.position)
				accept_event()
		else:
			if active_tool_id != "":
				_finish_drag()
				accept_event()
	elif event is InputEventScreenDrag:
		if active_tool_id != "":
			drag_pointer_position = event.position
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var tool_id := _tool_at_point(event.position)
			if tool_id != "":
				_start_drag(tool_id, event.position)
				accept_event()
		else:
			if active_tool_id != "":
				_finish_drag()
				accept_event()
	elif event is InputEventMouseMotion and active_tool_id != "":
		drag_pointer_position = event.position
		accept_event()

func _build_ui() -> void:
	var pet_host := Control.new()
	pet_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pet_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pet_host)

	pet = PetScene.instantiate()
	pet.position = Vector2(360, 760)
	pet.scale = Vector2(1.22, 1.22)
	pet_host.add_child(pet)

	speech_bubble = Control.new()
	speech_bubble.visible = false
	speech_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(speech_bubble)

	var bubble_texture := TextureRect.new()
	bubble_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var atlas := AtlasTexture.new()
	atlas.atlas = SPEECH_BUBBLE_TEXTURE
	atlas.region = SPEECH_BUBBLE_REGION
	bubble_texture.texture = atlas
	bubble_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bubble_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	speech_bubble.add_child(bubble_texture)

	var text_margin := MarginContainer.new()
	text_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_margin.offset_left = 36.0
	text_margin.offset_top = 42.0
	text_margin.offset_right = -56.0
	text_margin.offset_bottom = -62.0
	speech_bubble.add_child(text_margin)

	speech_bubble_label = Label.new()
	speech_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech_bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speech_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_bubble_label.add_theme_font_size_override("font_size", 17)
	speech_bubble_label.add_theme_color_override("font_color", Color(0.45, 0.24, 0.11))
	speech_bubble_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.3))
	speech_bubble_label.add_theme_constant_override("shadow_offset_x", 2)
	speech_bubble_label.add_theme_constant_override("shadow_offset_y", 2)
	text_margin.add_child(speech_bubble_label)

	speech_bubble_timer = Timer.new()
	speech_bubble_timer.one_shot = true
	speech_bubble_timer.timeout.connect(_on_speech_bubble_timeout)
	add_child(speech_bubble_timer)

	info_label = Label.new()
	info_label.anchor_left = 0.5
	info_label.anchor_top = 0.26
	info_label.anchor_right = 0.5
	info_label.anchor_bottom = 0.26
	info_label.offset_left = -220.0
	info_label.offset_top = -18.0
	info_label.offset_right = 220.0
	info_label.offset_bottom = 18.0
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.add_theme_color_override("font_color", Color(0.35, 0.18, 0.08))
	info_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25))
	info_label.add_theme_constant_override("shadow_offset_x", 2)
	info_label.add_theme_constant_override("shadow_offset_y", 2)
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info_label)

	var tool_row := HBoxContainer.new()
	tool_row.anchor_left = 0.5
	tool_row.anchor_top = 1.0
	tool_row.anchor_right = 0.5
	tool_row.anchor_bottom = 1.0
	tool_row.offset_left = -165.0
	tool_row.offset_top = -250.0
	tool_row.offset_right = 165.0
	tool_row.offset_bottom = -120.0
	tool_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tool_row.add_theme_constant_override("separation", 18)
	tool_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tool_row)

	for tool_id in ["soap", "shower", "towel"]:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(94, 94)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_stylebox_override("panel", _style_box(
			Color(1.0, 1.0, 1.0, 0.0),
			Color(1.0, 1.0, 1.0, 0.0),
			22,
			0,
			Color(0.0, 0.0, 0.0, 0.0),
			0,
			Vector2.ZERO
		))
		tool_slots[tool_id] = slot
		tool_row.add_child(slot)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(74, 74)
		icon.texture = TOOL_TEXTURES[tool_id]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)

	drag_preview = TextureRect.new()
	drag_preview.visible = false
	drag_preview.custom_minimum_size = Vector2(88, 88)
	drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drag_preview)

	_layout_bubble()

func _reset_session(cleanliness: float) -> void:
	current_cleanliness = clampf(cleanliness, 0.0, 100.0)
	cleaning_start_cleanliness = current_cleanliness
	soap_progress = 0.0
	rinse_progress = 0.0
	towel_progress = 0.0
	session_finished = false
	start_message_shown = false
	already_clean_notice_shown = false
	pet.clear_bath_overlays()
	pet.set_cleanliness(current_cleanliness)

func _refresh_ui() -> void:
	if not is_node_ready():
		return
	if session_finished:
		info_label.text = Localization.text(current_language, "bathroom.clean.finished")
	elif current_cleanliness >= 99.0 and soap_progress <= 0.0 and rinse_progress <= 0.0 and towel_progress <= 0.0:
		info_label.text = Localization.text(current_language, "bathroom.clean.alreadyClean")
	else:
		info_label.text = Localization.text(current_language, "bathroom.clean.start")

func _refresh_pet_effects() -> void:
	pet.set_cleanliness(current_cleanliness)
	pet.set_foam_amount(clampf((soap_progress / 100.0) * (1.0 - rinse_progress / 100.0), 0.0, 0.9))
	pet.set_wet_amount(clampf((rinse_progress / 100.0) * (1.0 - towel_progress / 100.0), 0.0, 0.88))

func _start_drag(tool_id: String, pointer_position: Vector2) -> void:
	if tool_id == "":
		return
	active_tool_id = tool_id
	drag_pointer_position = pointer_position
	drag_preview.texture = TOOL_TEXTURES[tool_id]
	drag_preview.visible = true
	_update_drag_preview(pointer_position)

func _finish_drag() -> void:
	active_tool_id = ""
	drag_preview.visible = false

func _tool_at_point(point: Vector2) -> String:
	for tool_id in tool_slots.keys():
		var slot: Control = tool_slots[tool_id]
		if slot.get_global_rect().has_point(point):
			return str(tool_id)
	return ""

func _update_drag_preview(pointer_position: Vector2) -> void:
	drag_preview.position = pointer_position - drag_preview.custom_minimum_size * 0.5

func _advance_cleaning(tool_id: String, delta: float) -> void:
	if session_finished:
		return
	if current_cleanliness >= 99.0 and soap_progress <= 0.0 and rinse_progress <= 0.0 and towel_progress <= 0.0:
		if not already_clean_notice_shown:
			already_clean_notice_shown = true
			_show_bubble("bathroom.clean.alreadyClean")
		return
	if not start_message_shown:
		start_message_shown = true
		info_label.text = Localization.text(current_language, "bathroom.clean.start")

	match tool_id:
		"soap":
			if rinse_progress > 0.0 or towel_progress > 0.0:
				return
			soap_progress = min(100.0, soap_progress + delta * SOAP_RATE)
		"shower":
			if soap_progress < 15.0:
				return
			rinse_progress = min(100.0, rinse_progress + delta * SHOWER_RATE)
			var rinse_ratio := rinse_progress / 100.0
			current_cleanliness = lerpf(cleaning_start_cleanliness, 100.0, rinse_ratio)
		"towel":
			if rinse_progress < 95.0:
				return
			towel_progress = min(100.0, towel_progress + delta * TOWEL_RATE)
			if towel_progress >= 100.0:
				_finish_cleaning()
				return
	_refresh_pet_effects()

func _finish_cleaning() -> void:
	session_finished = true
	current_cleanliness = 100.0
	soap_progress = 100.0
	rinse_progress = 100.0
	towel_progress = 100.0
	pet.set_cleanliness(100.0)
	pet.clear_bath_overlays()
	pet.play_clean_sparkle()
	info_label.text = Localization.text(current_language, "bathroom.clean.finished")
	_show_bubble(_random_finish_message_key())
	cleaning_finished.emit(FINISH_HAPPINESS_GAIN)

func _random_finish_message_key() -> String:
	var message_index := randi_range(0, CLEAN_MESSAGE_KEYS.size() - 1)
	if CLEAN_MESSAGE_KEYS.size() > 1 and message_index == last_finish_message_index:
		message_index = (message_index + 1 + randi_range(0, CLEAN_MESSAGE_KEYS.size() - 2)) % CLEAN_MESSAGE_KEYS.size()
	last_finish_message_index = message_index
	return CLEAN_MESSAGE_KEYS[message_index]

func _show_bubble(message_key: String) -> void:
	bubble_message_key = message_key
	speech_bubble_label.text = Localization.text(current_language, message_key)
	if bubble_tween != null:
		bubble_tween.kill()
	speech_bubble_timer.stop()
	_layout_bubble()
	speech_bubble.visible = true
	speech_bubble.scale = Vector2(0.82, 0.82)
	speech_bubble.modulate = Color(1, 1, 1, 0.0)
	speech_bubble.position = bubble_base_position + Vector2(0, 14)

	bubble_tween = create_tween()
	bubble_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bubble_tween.parallel().tween_property(speech_bubble, "modulate:a", 1.0, 0.16)
	bubble_tween.parallel().tween_property(speech_bubble, "scale", Vector2(1.04, 1.04), 0.18)
	bubble_tween.parallel().tween_property(speech_bubble, "position", bubble_base_position, 0.18)
	bubble_tween.tween_property(speech_bubble, "scale", Vector2.ONE, 0.1)
	speech_bubble_timer.start(2.6)

func _on_speech_bubble_timeout() -> void:
	if bubble_tween != null:
		bubble_tween.kill()
	bubble_tween = create_tween()
	bubble_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	bubble_tween.parallel().tween_property(speech_bubble, "modulate:a", 0.0, 0.3)
	bubble_tween.parallel().tween_property(speech_bubble, "position", bubble_base_position + Vector2(0, -8), 0.3)
	bubble_tween.finished.connect(_on_speech_bubble_hidden)

func _on_speech_bubble_hidden() -> void:
	speech_bubble.visible = false
	speech_bubble.position = bubble_base_position

func _layout_bubble() -> void:
	if speech_bubble == null:
		return
	var bubble_width: float = clampf(size.x * 0.42, 250.0, 320.0)
	var bubble_height: float = bubble_width * float(SPEECH_BUBBLE_REGION.size.y / SPEECH_BUBBLE_REGION.size.x)
	speech_bubble.size = Vector2(bubble_width, bubble_height)
	bubble_base_position = Vector2(size.x * 0.5, size.y * 0.2)
	speech_bubble.position = bubble_base_position
	speech_bubble.pivot_offset = speech_bubble.size * 0.5

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_bubble()

func _style_box(bg_color: Color, border_color: Color, radius: int, border_width: int = 3, shadow_color: Color = Color(0, 0, 0, 0.18), shadow_size: int = 5, shadow_offset: Vector2 = Vector2(0, 3)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size
	style.shadow_offset = shadow_offset
	return style
