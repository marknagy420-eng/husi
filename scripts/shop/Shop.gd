extends Control

signal buy_requested(item_id: String)
signal select_requested(item_id: String)
signal back_requested

@onready var currency_label: Label = %CurrencyLabel
@onready var item_list: VBoxContainer = %ItemList
@onready var message_label: Label = %MessageLabel

# Shop rebuilds from catalog/state, so it can support more item types later.
func _ready() -> void:
	%BackButton.pressed.connect(_on_back_button_pressed)

func set_shop_data(catalog: Dictionary, owned_items: Array, owned_backgrounds: Array, selected_skin: String, selected_background: String, currency: int) -> void:
	currency_label.text = "Coins: %d" % currency
	_clear_items()

	for item_id in catalog.keys():
		var item: Dictionary = catalog[item_id]
		var current_item_id := str(item_id)
		var category := str(item["category"])
		var is_owned := owned_backgrounds.has(current_item_id) if category == "background" else owned_items.has(current_item_id)
		var is_selected := selected_background == current_item_id if category == "background" else selected_skin == current_item_id

		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 76)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var preview := TextureRect.new()
		preview.custom_minimum_size = Vector2(72, 72)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture = load(str(item["image"]))
		row.add_child(preview)

		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 64)
		button.text = _button_text(item, is_owned, is_selected)
		button.pressed.connect(_on_item_button_pressed.bind(current_item_id, is_owned, category))
		row.add_child(button)
		item_list.add_child(row)

func show_message(message: String) -> void:
	message_label.text = message

func _button_text(item: Dictionary, is_owned: bool, is_selected: bool) -> String:
	if is_selected:
		return "%s - Selected" % item["display_name"]
	if is_owned:
		return "%s - Select" % item["display_name"]
	return "%s - %d coins" % [item["display_name"], int(item["price"])]

func _on_item_button_pressed(item_id: String, is_owned: bool, category: String) -> void:
	if is_owned and category in ["skin", "background"]:
		select_requested.emit(item_id)
	else:
		buy_requested.emit(item_id)

func _on_back_button_pressed() -> void:
	back_requested.emit()

func _clear_items() -> void:
	for child in item_list.get_children():
		child.queue_free()
	message_label.text = ""
