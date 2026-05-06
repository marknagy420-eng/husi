extends Control

const Localization = preload("res://scripts/core/Localization.gd")

signal feed_requested
signal shop_requested
signal skins_requested
signal minigame_requested
signal settings_requested
signal bathroom_requested

@onready var currency_label: Label = %CurrencyLabel
@onready var level_label: Label = %LevelLabel
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var happiness_bar: ProgressBar = %HappinessBar
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var hunger_value_label: Label = %HungerValueLabel
@onready var happiness_value_label: Label = %HappinessValueLabel
@onready var energy_value_label: Label = %EnergyValueLabel
@onready var status_label: Label = %StatusLabel
@onready var name_panel: Control = $NamePanel
@onready var level_badge: Control = $LevelBadge
@onready var stats_panel: Control = $StatsPanel
@onready var hunger_title: Label = $StatsPanel/StatsRow/HungerGroup/HungerTitle
@onready var happiness_title: Label = $StatsPanel/StatsRow/HappinessGroup/HappinessTitle
@onready var energy_title: Label = $StatsPanel/StatsRow/EnergyGroup/EnergyTitle
@onready var shop_button: Button = %ShopButton
@onready var minigame_button: Button = %MinigameButton
@onready var skins_button: Button = %SkinsButton
@onready var bathroom_button: Button = %BathroomButton

var current_language := "hu"

func _ready() -> void:
	%PlusButton.pressed.connect(_on_plus_button_pressed)
	%SettingsButton.pressed.connect(_on_settings_button_pressed)
	%ShopButton.pressed.connect(_on_shop_button_pressed)
	%MinigameButton.pressed.connect(_on_minigame_button_pressed)
	%SkinsButton.pressed.connect(_on_skins_button_pressed)
	%BathroomButton.pressed.connect(_on_bathroom_button_pressed)

func set_currency(amount: int) -> void:
	currency_label.text = str(amount)
	level_label.text = Localization.text(current_language, "hud.level", {"level": max(1, int(amount / 300) + 1)})

func set_pet_stats(stats: Dictionary) -> void:
	var hunger := int(stats.get("hunger", 0))
	var happiness := int(stats.get("happiness", 0))
	var energy := int(stats.get("energy", 72))
	hunger_bar.value = hunger
	happiness_bar.value = happiness
	energy_bar.value = energy
	hunger_value_label.text = "%d%%" % hunger
	happiness_value_label.text = "%d%%" % happiness
	energy_value_label.text = "%d%%" % energy

func show_status(message: String) -> void:
	status_label.text = message

func set_localization(language_code: String) -> void:
	current_language = language_code
	hunger_title.text = Localization.text(current_language, "hud.hunger")
	happiness_title.text = Localization.text(current_language, "hud.happiness")
	energy_title.text = Localization.text(current_language, "hud.energy")
	shop_button.text = Localization.text(current_language, "hud.shop")
	minigame_button.text = Localization.text(current_language, "hud.play")
	skins_button.text = Localization.text(current_language, "hud.skins")
	bathroom_button.text = Localization.text(current_language, "hud.bathroom")
	set_currency(int(currency_label.text))

func set_compact_mode(enabled: bool) -> void:
	name_panel.visible = not enabled
	level_badge.visible = not enabled
	status_label.visible = not enabled
	stats_panel.visible = not enabled

func _on_plus_button_pressed() -> void:
	minigame_requested.emit()

func _on_shop_button_pressed() -> void:
	shop_requested.emit()

func _on_skins_button_pressed() -> void:
	skins_requested.emit()

func _on_minigame_button_pressed() -> void:
	minigame_requested.emit()

func _on_settings_button_pressed() -> void:
	settings_requested.emit()

func _on_bathroom_button_pressed() -> void:
	bathroom_requested.emit()
