extends Control

signal feed_requested
signal shop_requested
signal minigame_requested
signal settings_requested

@onready var currency_label: Label = %CurrencyLabel
@onready var level_label: Label = %LevelLabel
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var happiness_bar: ProgressBar = %HappinessBar
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var hunger_value_label: Label = %HungerValueLabel
@onready var happiness_value_label: Label = %HappinessValueLabel
@onready var energy_value_label: Label = %EnergyValueLabel
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	%PlusButton.pressed.connect(_on_plus_button_pressed)
	%SettingsButton.pressed.connect(_on_settings_button_pressed)
	%ShopButton.pressed.connect(_on_shop_button_pressed)
	%MinigameButton.pressed.connect(_on_minigame_button_pressed)
	%SkinsButton.pressed.connect(_on_shop_button_pressed)
	%BathroomButton.pressed.connect(_on_bathroom_button_pressed)

func set_currency(amount: int) -> void:
	currency_label.text = str(amount)
	level_label.text = "Level %d" % max(1, int(amount / 300) + 1)

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

func _on_plus_button_pressed() -> void:
	minigame_requested.emit()

func _on_shop_button_pressed() -> void:
	shop_requested.emit()

func _on_minigame_button_pressed() -> void:
	minigame_requested.emit()

func _on_settings_button_pressed() -> void:
	settings_requested.emit()

func _on_bathroom_button_pressed() -> void:
	show_status("Bathroom coming soon.")
