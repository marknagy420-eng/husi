extends Control

const Localization = preload("res://scripts/core/Localization.gd")

signal close_requested
signal home_requested
signal language_changed(language_code: String)
signal audio_levels_changed(master_volume: float, effects_volume: float)

var current_language := "hu"
var master_volume := 100.0
var effects_volume := 100.0
var scoreboard_state: Dictionary = {}
var is_syncing_sliders := false
var language_selected_style: StyleBox
var language_normal_style: StyleBox
var language_buttons: Dictionary = {}
var scoreboard_popup: AcceptDialog
var scoreboard_label: RichTextLabel

@onready var title_label: Label = $Panel/Content/TopArea/Title
@onready var name_label: Label = $Panel/Content/TopArea/NameRibbon/NameRow/NameLabel
@onready var language_title: Label = $Panel/Content/LanguageSection/LanguageBox/LanguageHeader/LanguageTitle
@onready var audio_title: Label = $Panel/Content/AudioSection/AudioBox/AudioHeader/AudioTitle
@onready var exit_title: Label = $Panel/Content/ExitSection/ExitBox/ExitHeader/ExitTitle
@onready var sound_label: Label = %SoundText
@onready var effects_label: Label = %VibrationText
@onready var sound_slider: HSlider = $Panel/Content/AudioSection/AudioBox/SoundRow/SoundLevel
@onready var effects_slider: HSlider = $Panel/Content/AudioSection/AudioBox/VibrationRow/VibrationLevel
@onready var sound_button: Button = %SoundToggleButton
@onready var vibration_button: Button = %VibrationToggleButton
@onready var message_label: Label = %MessageLabel
@onready var scoreboard_button: Button = %ScoreboardButton
@onready var tray_exit_button: Button = %TrayExitButton
@onready var home_exit_button: Button = %HomeExitButton
@onready var close_button_secondary: Button = %CloseButton2

func _ready() -> void:
	language_buttons = {
		"hu": %HungarianButton,
		"de": %GermanButton,
		"en": %EnglishButton,
		"zh": %ChineseButton,
		"uk": %UkrainianButton
	}
	language_selected_style = %HungarianButton.get_theme_stylebox("normal")
	language_normal_style = %GermanButton.get_theme_stylebox("normal")

	%HungarianButton.pressed.connect(_on_language_pressed.bind("hu"))
	%GermanButton.pressed.connect(_on_language_pressed.bind("de"))
	%EnglishButton.pressed.connect(_on_language_pressed.bind("en"))
	%ChineseButton.pressed.connect(_on_language_pressed.bind("zh"))
	%UkrainianButton.pressed.connect(_on_language_pressed.bind("uk"))
	sound_slider.value_changed.connect(_on_sound_slider_changed)
	effects_slider.value_changed.connect(_on_effects_slider_changed)
	scoreboard_button.pressed.connect(_on_scoreboard_pressed)
	tray_exit_button.pressed.connect(_on_tray_exit_pressed)
	home_exit_button.pressed.connect(_on_home_exit_pressed)
	%CloseButton.pressed.connect(_on_close_pressed)
	close_button_secondary.pressed.connect(_on_close_pressed)

	sound_button.visible = false
	vibration_button.visible = false
	_style_slider(sound_slider)
	_style_slider(effects_slider)
	_build_scoreboard_popup()
	_refresh_ui()

func open() -> void:
	visible = true
	message_label.text = ""
	_refresh_ui()

func sync_state(state: Dictionary) -> void:
	current_language = str(state.get("language_code", current_language))
	master_volume = clampf(float(state.get("master_volume", master_volume)), 0.0, 100.0)
	effects_volume = clampf(float(state.get("effects_volume", effects_volume)), 0.0, 100.0)
	scoreboard_state = state.get("scoreboard_state", scoreboard_state).duplicate(true)
	_refresh_ui()

func _on_language_pressed(language_code: String) -> void:
	current_language = language_code
	_refresh_ui()
	message_label.text = Localization.text(current_language, "settings.language_set", {"language": _language_native_name(language_code)})
	language_changed.emit(current_language)

func _on_sound_slider_changed(value: float) -> void:
	if is_syncing_sliders:
		return
	master_volume = value
	audio_levels_changed.emit(master_volume, effects_volume)

func _on_effects_slider_changed(value: float) -> void:
	if is_syncing_sliders:
		return
	effects_volume = value
	audio_levels_changed.emit(master_volume, effects_volume)

func _on_scoreboard_pressed() -> void:
	var stats: Dictionary = scoreboard_state.get("pet_stats", {})
	scoreboard_label.text = Localization.text(current_language, "settings.scoreboard_body", {
		"best_score": int(scoreboard_state.get("best_score", 0)),
		"coins": int(scoreboard_state.get("currency", 0)),
		"level": int(scoreboard_state.get("level", 1)),
		"skins": int(scoreboard_state.get("skins_count", 1)),
		"rooms": int(scoreboard_state.get("rooms_count", 1)),
		"hunger": int(stats.get("hunger", 0)),
		"happiness": int(stats.get("happiness", 0)),
		"energy": int(stats.get("energy", 0))
	})
	scoreboard_popup.title = Localization.text(current_language, "settings.scoreboard_title")
	scoreboard_popup.ok_button_text = Localization.text(current_language, "settings.ok")
	scoreboard_popup.popup_centered(Vector2i(380, 280))

func _on_tray_exit_pressed() -> void:
	message_label.text = Localization.text(current_language, "settings.tray_unavailable")

func _on_home_exit_pressed() -> void:
	home_requested.emit()

func _on_close_pressed() -> void:
	close_requested.emit()

func _refresh_ui() -> void:
	if not is_node_ready():
		return
	is_syncing_sliders = true
	sound_slider.value = master_volume
	effects_slider.value = effects_volume
	is_syncing_sliders = false

	title_label.text = Localization.text(current_language, "settings.title")
	language_title.text = Localization.text(current_language, "settings.language")
	audio_title.text = Localization.text(current_language, "settings.audio")
	exit_title.text = Localization.text(current_language, "settings.exit")
	sound_label.text = Localization.text(current_language, "settings.master")
	effects_label.text = Localization.text(current_language, "settings.effects")
	scoreboard_button.text = Localization.text(current_language, "settings.scoreboard")
	tray_exit_button.text = Localization.text(current_language, "settings.tray_exit")
	home_exit_button.text = Localization.text(current_language, "settings.home_exit")
	close_button_secondary.text = Localization.text(current_language, "settings.close")
	name_label.text = "Husi"
	_update_language_buttons()

func _update_language_buttons() -> void:
	for language_code in language_buttons.keys():
		var button: Button = language_buttons[language_code]
		var selected: bool = language_code == current_language
		var style: StyleBox = language_selected_style if selected else language_normal_style
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", language_selected_style)

func _language_native_name(language_code: String) -> String:
	match language_code:
		"hu":
			return "Magyar"
		"de":
			return "Deutsch"
		"en":
			return "English"
		"zh":
			return "Chinese"
		"uk":
			return "Ukrainian"
		_:
			return language_code

func _build_scoreboard_popup() -> void:
	scoreboard_popup = AcceptDialog.new()
	scoreboard_popup.title = Localization.text(current_language, "settings.scoreboard_title")
	scoreboard_popup.ok_button_text = Localization.text(current_language, "settings.ok")
	add_child(scoreboard_popup)

	scoreboard_label = RichTextLabel.new()
	scoreboard_label.fit_content = true
	scoreboard_label.scroll_active = false
	scoreboard_label.bbcode_enabled = false
	scoreboard_label.custom_minimum_size = Vector2(320, 180)
	scoreboard_popup.add_child(scoreboard_label)

func _style_slider(slider: HSlider) -> void:
	slider.add_theme_constant_override("grabber_offset", 2)
	slider.add_theme_stylebox_override("grabber_area", _style_box(
		Color(0.55, 0.78, 0.18, 0.34),
		Color(0.3, 0.45, 0.08, 0.4),
		8,
		1,
		Color(0, 0, 0, 0.0),
		0,
		Vector2.ZERO
	))
	slider.add_theme_stylebox_override("grabber_area_highlight", _style_box(
		Color(0.55, 0.78, 0.18, 0.48),
		Color(0.3, 0.45, 0.08, 0.5),
		8,
		1,
		Color(0, 0, 0, 0.0),
		0,
		Vector2.ZERO
	))
	slider.add_theme_stylebox_override("slider", _style_box(
		Color(0.55, 0.78, 0.18, 1.0),
		Color(0.3, 0.45, 0.08, 1.0),
		10,
		2,
		Color(0, 0, 0, 0.18),
		3,
		Vector2(0, 1)
	))

func _style_box(bg_color: Color, border_color: Color, radius: int, border_width: int = 2, shadow_color: Color = Color(0, 0, 0, 0.18), shadow_size: int = 0, shadow_offset: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
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
