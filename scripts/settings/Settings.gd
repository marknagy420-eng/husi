extends Control

signal close_requested
signal home_requested

var sound_enabled := true
var vibration_enabled := true
var current_language := "hu"

@onready var sound_button: Button = %SoundToggleButton
@onready var vibration_button: Button = %VibrationToggleButton
@onready var sound_label: Label = %SoundText
@onready var vibration_label: Label = %VibrationText
@onready var message_label: Label = %MessageLabel

func _ready() -> void:
	%HungarianButton.pressed.connect(_on_language_pressed.bind("hu", "Magyar"))
	%EnglishButton.pressed.connect(_on_language_pressed.bind("en", "English"))
	%UkrainianButton.pressed.connect(_on_language_pressed.bind("uk", "Українська"))
	%GermanButton.pressed.connect(_on_language_pressed.bind("de", "Deutsch"))
	%ChineseButton.pressed.connect(_on_language_pressed.bind("zh", "中文"))
	sound_button.pressed.connect(_on_sound_toggle_pressed)
	vibration_button.pressed.connect(_on_vibration_toggle_pressed)
	%ScoreboardButton.pressed.connect(_on_scoreboard_pressed)
	%TrayExitButton.pressed.connect(_on_tray_exit_pressed)
	%HomeExitButton.pressed.connect(_on_home_exit_pressed)
	%CloseButton.pressed.connect(_on_close_pressed)
	%CloseButton2.pressed.connect(_on_close_pressed)
	_update_toggles()

func open() -> void:
	visible = true
	message_label.text = ""

func _on_language_pressed(language_code: String, language_name: String) -> void:
	current_language = language_code
	message_label.text = "Nyelv: %s" % language_name

func _on_sound_toggle_pressed() -> void:
	sound_enabled = not sound_enabled
	_update_toggles()

func _on_vibration_toggle_pressed() -> void:
	vibration_enabled = not vibration_enabled
	_update_toggles()
	if vibration_enabled:
		Input.vibrate_handheld(60)

func _on_scoreboard_pressed() -> void:
	message_label.text = "Scoreboard hamarosan."

func _on_tray_exit_pressed() -> void:
	message_label.text = "A tálcára küldés Godot exportban még nincs bekötve."

func _on_home_exit_pressed() -> void:
	home_requested.emit()

func _on_close_pressed() -> void:
	close_requested.emit()

func _update_toggles() -> void:
	sound_label.text = "Hang: %s" % ("Be" if sound_enabled else "Ki")
	vibration_label.text = "Vibrálás: %s" % ("Be" if vibration_enabled else "Ki")
	sound_button.text = ""
	vibration_button.text = ""
