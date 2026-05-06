extends Control

const Localization = preload("res://scripts/core/Localization.gd")

signal buy_requested(item_id: String)
signal select_requested(item_id: String)
signal daily_deal_requested(item_id: String)
signal tab_changed(tab_id: String)

const STORE_BACKGROUND_TEXTURE := preload("res://Store/storebackground.png")
const COIN_TEXTURE := preload("res://assets/ui_icons/coin_paw.png")
const STAR_TEXTURE := preload("res://assets/ui_icons/star.png")
const SKINS_TEXTURE := preload("res://assets/ui_icons/tshirt_skins.png")
const FOOD_TEXTURE := preload("res://steak.png")
const TOYS_TEXTURE := preload("res://ball.png")
const ROOMS_TEXTURE := preload("res://assets/ui_icons/cozy_chair.svg")
const DEAL_TEXTURE := preload("res://assets/ui_icons/gift_box.svg")
const SPEECH_BUBBLE_TEXTURE := preload("res://speechbubble/messeage.png")
const SPEECH_BUBBLE_REGION := Rect2(44.0, 350.0, 938.0, 760.0)
const PURCHASE_MESSAGE_KEYS := {
	"food": [
		"shop.food.message.1",
		"shop.food.message.2",
		"shop.food.message.3",
		"shop.food.message.4",
		"shop.food.message.5"
	],
	"toy": [
		"shop.toy.message.1",
		"shop.toy.message.2",
		"shop.toy.message.3",
		"shop.toy.message.4",
		"shop.toy.message.5"
	]
}

const TAB_CONFIG := [
	{"id": "food", "label": "Food", "icon": FOOD_TEXTURE},
	{"id": "toys", "label": "Toys", "icon": TOYS_TEXTURE},
	{"id": "furniture", "label": "Rooms", "icon": ROOMS_TEXTURE},
	{"id": "skins", "label": "Skins", "icon": SKINS_TEXTURE},
	{"id": "special", "label": "Special", "icon": STAR_TEXTURE}
]

const BOARD_MARGIN_LEFT := 0.03
const BOARD_MARGIN_TOP := 0.30
const BOARD_MARGIN_RIGHT := 0.97
const BOARD_MARGIN_BOTTOM := 0.93

var shop_catalog: Dictionary = {}
var owned_items_state: Array = []
var owned_backgrounds_state: Array = []
var selected_skin_state := "default"
var selected_background_state := "default"
var current_currency := 0
var current_tab := "food"
var daily_deal_state: Dictionary = {}
var countdown_accumulator := 0.0
var current_language := "hu"

var tab_buttons: Dictionary = {}
var board_area: Control
var grid: GridContainer
var message_label: Label
var content_scroll: ScrollContainer
var daily_deal_ribbon_label: Label
var daily_deal_name_label: Label
var daily_deal_timer_label: Label
var daily_deal_old_price_label: RichTextLabel
var daily_deal_button: Button
var daily_deal_discount_label: Label
var daily_deal_caption_label: Label
var purchase_bubble: Control
var purchase_bubble_label: Label
var purchase_bubble_timer: Timer
var purchase_bubble_tween: Tween
var purchase_bubble_base_position := Vector2.ZERO
var active_purchase_message_key := ""
var last_purchase_message_indices := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)
	_build_ui()
	_refresh_all()

func _process(delta: float) -> void:
	countdown_accumulator += delta
	if countdown_accumulator >= 1.0:
		countdown_accumulator = 0.0
		_refresh_daily_deal()

func set_shop_data(catalog: Dictionary, owned_items: Array, owned_backgrounds: Array, selected_skin: String, selected_background: String, currency: int, daily_deal: Dictionary = {}) -> void:
	shop_catalog = catalog.duplicate(true)
	owned_items_state = owned_items.duplicate()
	owned_backgrounds_state = owned_backgrounds.duplicate()
	selected_skin_state = selected_skin
	selected_background_state = selected_background
	current_currency = currency
	daily_deal_state = daily_deal.duplicate(true)
	_refresh_all()

func request_tab(tab_id: String) -> void:
	if not _has_tab(tab_id):
		return
	current_tab = tab_id
	tab_changed.emit(current_tab)
	_refresh_all()

func set_localization(language_code: String) -> void:
	current_language = language_code
	if purchase_bubble_label != null and active_purchase_message_key != "":
		purchase_bubble_label.text = Localization.text(current_language, active_purchase_message_key)
	_refresh_all()

func show_message(message: String) -> void:
	if message_label != null:
		message_label.text = message

func show_purchase_reaction(category_id: String) -> void:
	var message_key := _random_purchase_message_key(category_id)
	if message_key == "":
		return

	active_purchase_message_key = message_key
	if purchase_bubble_label != null:
		purchase_bubble_label.text = Localization.text(current_language, message_key)

	_layout_purchase_bubble()
	if purchase_bubble_tween != null:
		purchase_bubble_tween.kill()
	if purchase_bubble_timer != null:
		purchase_bubble_timer.stop()

	purchase_bubble.visible = true
	purchase_bubble.modulate = Color(1, 1, 1, 0)
	purchase_bubble.scale = Vector2(0.82, 0.82)
	purchase_bubble.position = purchase_bubble_base_position + Vector2(0, 14)

	purchase_bubble_tween = create_tween()
	purchase_bubble_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	purchase_bubble_tween.parallel().tween_property(purchase_bubble, "modulate:a", 1.0, 0.14)
	purchase_bubble_tween.parallel().tween_property(purchase_bubble, "scale", Vector2(1.05, 1.05), 0.16)
	purchase_bubble_tween.parallel().tween_property(purchase_bubble, "position", purchase_bubble_base_position, 0.18)
	purchase_bubble_tween.tween_property(purchase_bubble, "scale", Vector2.ONE, 0.12)
	purchase_bubble_timer.start(randf_range(2.0, 3.0))

func clear_purchase_reaction() -> void:
	active_purchase_message_key = ""
	if purchase_bubble_timer != null:
		purchase_bubble_timer.stop()
	if purchase_bubble_tween != null:
		purchase_bubble_tween.kill()
	if purchase_bubble != null:
		purchase_bubble.visible = false

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture = STORE_BACKGROUND_TEXTURE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	board_area = Control.new()
	board_area.anchor_left = BOARD_MARGIN_LEFT
	board_area.anchor_top = BOARD_MARGIN_TOP
	board_area.anchor_right = BOARD_MARGIN_RIGHT
	board_area.anchor_bottom = BOARD_MARGIN_BOTTOM
	board_area.offset_left = 0.0
	board_area.offset_top = 0.0
	board_area.offset_right = 0.0
	board_area.offset_bottom = 0.0
	board_area.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(board_area)

	_build_purchase_bubble()

	var board_margin := MarginContainer.new()
	board_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_margin.offset_left = 14.0
	board_margin.offset_top = 12.0
	board_margin.offset_right = -14.0
	board_margin.offset_bottom = -12.0
	board_area.add_child(board_margin)

	var shell := VBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 10)
	board_margin.add_child(shell)

	var tabs := _build_tabs()
	shell.add_child(tabs)

	message_label = _make_label("", 15, Color(0.47, 0.25, 0.12), Color(1, 1, 1, 0.22))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shell.add_child(message_label)

	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.add_child(content_scroll)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 12)
	content_scroll.add_child(stack)

	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	stack.add_child(grid)

	stack.add_child(_build_daily_deal())
	_style_scrollbar(content_scroll.get_v_scroll_bar())

	_on_resized()

func _build_purchase_bubble() -> void:
	purchase_bubble = Control.new()
	purchase_bubble.visible = false
	purchase_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(purchase_bubble)

	var bubble_texture := TextureRect.new()
	bubble_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var atlas := AtlasTexture.new()
	atlas.atlas = SPEECH_BUBBLE_TEXTURE
	atlas.region = SPEECH_BUBBLE_REGION
	bubble_texture.texture = atlas
	bubble_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bubble_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	bubble_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purchase_bubble.add_child(bubble_texture)

	var text_margin := MarginContainer.new()
	text_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_margin.offset_left = 34.0
	text_margin.offset_top = 42.0
	text_margin.offset_right = -56.0
	text_margin.offset_bottom = -58.0
	text_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purchase_bubble.add_child(text_margin)

	purchase_bubble_label = _make_label("", 17, Color(0.45, 0.24, 0.11), Color(1, 1, 1, 0.36))
	purchase_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	purchase_bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	purchase_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_margin.add_child(purchase_bubble_label)

	purchase_bubble_timer = Timer.new()
	purchase_bubble_timer.one_shot = true
	purchase_bubble_timer.timeout.connect(_on_purchase_bubble_timeout)
	add_child(purchase_bubble_timer)

func _build_tabs() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 58)
	row.add_theme_constant_override("separation", 8)

	for tab_data in TAB_CONFIG:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = Localization.text(current_language, "shop.tab.%s" % str(tab_data["id"]))
		button.icon = tab_data["icon"]
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 26)
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", Color(1, 0.97, 0.9))
		button.pressed.connect(_on_tab_pressed.bind(str(tab_data["id"])))
		tab_buttons[str(tab_data["id"])] = button
		row.add_child(button)

	return row

func _build_daily_deal() -> Control:
	var deal_card := PanelContainer.new()
	deal_card.custom_minimum_size = Vector2(0, 148)
	_set_panel_style(deal_card, _style_box(
		Color(0.98, 0.78, 0.72, 0.98),
		Color(0.88, 0.5, 0.33, 1.0),
		22,
		3,
		Color(0.51, 0.28, 0.12, 0.1),
		6,
		Vector2(0, 3),
		{"left": 16, "top": 14, "right": 16, "bottom": 14}
	))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	deal_card.add_child(row)

	var gift := TextureRect.new()
	gift.custom_minimum_size = Vector2(58, 58)
	gift.texture = DEAL_TEXTURE
	gift.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gift.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(gift)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)

	var ribbon := PanelContainer.new()
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_set_panel_style(ribbon, _style_box(Color(0.92, 0.29, 0.28, 1.0), Color(0.73, 0.13, 0.13, 1.0), 12, 2, Color(0, 0, 0, 0.1), 3, Vector2(0, 2), {"left": 10, "top": 4, "right": 10, "bottom": 4}))
	info.add_child(ribbon)

	daily_deal_ribbon_label = _make_label(Localization.text(current_language, "shop.daily_deal"), 15, Color(1, 1, 1), Color(0, 0, 0, 0))
	ribbon.add_child(daily_deal_ribbon_label)

	daily_deal_name_label = _make_label("Meal Box", 22, Color(0.36, 0.18, 0.09), Color(1, 1, 1, 0.3))
	info.add_child(daily_deal_name_label)

	daily_deal_caption_label = _make_label("", 15, Color(0.44, 0.21, 0.12), Color(0, 0, 0, 0))
	info.add_child(daily_deal_caption_label)

	daily_deal_timer_label = _make_label("", 13, Color(0.63, 0.23, 0.18), Color(0, 0, 0, 0))
	info.add_child(daily_deal_timer_label)

	var price_stack := VBoxContainer.new()
	price_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	price_stack.add_theme_constant_override("separation", 8)
	row.add_child(price_stack)

	daily_deal_old_price_label = RichTextLabel.new()
	daily_deal_old_price_label.custom_minimum_size = Vector2(84, 24)
	daily_deal_old_price_label.bbcode_enabled = true
	daily_deal_old_price_label.fit_content = true
	daily_deal_old_price_label.scroll_active = false
	daily_deal_old_price_label.add_theme_font_size_override("normal_font_size", 15)
	daily_deal_old_price_label.add_theme_color_override("default_color", Color(0.58, 0.22, 0.18))
	price_stack.add_child(daily_deal_old_price_label)

	daily_deal_button = Button.new()
	daily_deal_button.custom_minimum_size = Vector2(104, 40)
	daily_deal_button.icon = COIN_TEXTURE
	daily_deal_button.expand_icon = true
	daily_deal_button.add_theme_constant_override("icon_max_width", 22)
	daily_deal_button.add_theme_font_size_override("font_size", 18)
	daily_deal_button.add_theme_color_override("font_color", Color(1, 1, 1))
	_set_button_style(daily_deal_button, _style_box(Color(0.44, 0.79, 0.13, 1.0), Color(0.24, 0.42, 0.07, 1.0), 16, 3, Color(0, 0, 0, 0.12), 4, Vector2(0, 3)))
	daily_deal_button.pressed.connect(_on_daily_deal_pressed)
	price_stack.add_child(daily_deal_button)

	var discount_badge := PanelContainer.new()
	discount_badge.custom_minimum_size = Vector2(68, 68)
	_set_panel_style(discount_badge, _style_box(Color(0.99, 0.77, 0.22, 1.0), Color(0.91, 0.56, 0.07, 1.0), 34, 4, Color(0.56, 0.29, 0.05, 0.12), 5, Vector2(0, 3)))
	row.add_child(discount_badge)

	daily_deal_discount_label = _make_label("-30%", 19, Color(0.63, 0.27, 0.04), Color(0, 0, 0, 0))
	daily_deal_discount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	daily_deal_discount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	discount_badge.add_child(daily_deal_discount_label)

	return deal_card

func _refresh_all() -> void:
	if grid == null:
		return
	_update_tab_buttons()
	_rebuild_item_cards()
	_refresh_daily_deal()

func _update_tab_buttons() -> void:
	for tab_data in TAB_CONFIG:
		var tab_id := str(tab_data["id"])
		var button: Button = tab_buttons.get(tab_id)
		if button == null:
			continue
		var is_active := tab_id == current_tab
		button.text = Localization.text(current_language, "shop.tab.%s" % tab_id)
		button.add_theme_color_override("font_color", Color(0.37, 0.22, 0.12) if is_active else Color(1, 0.97, 0.9))
		_set_button_style(button, _style_box(
			Color(0.98, 0.9, 0.7, 0.98) if is_active else Color(0.72, 0.45, 0.23, 0.92),
			Color(0.84, 0.61, 0.32, 1.0) if is_active else Color(0.47, 0.25, 0.12, 1.0),
			18,
			3,
			Color(0, 0, 0, 0.12),
			4,
			Vector2(0, 2)
		))

func _rebuild_item_cards() -> void:
	for child in grid.get_children():
		child.queue_free()

	var entries: Array = []
	for item_id in shop_catalog.keys():
		var item: Dictionary = shop_catalog[item_id]
		if str(item.get("tab", "")) == current_tab:
			entries.append({"id": str(item_id), "item": item})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["item"].get("order", 999)) < int(b["item"].get("order", 999))
	)

	for entry in entries:
		grid.add_child(_create_item_card(str(entry["id"]), entry["item"]))

func _create_item_card(item_id: String, item: Dictionary) -> Control:
	var kind := str(item.get("kind", "consumable"))
	var selection_id := str(item.get("selection_id", item_id))
	var is_owned := owned_backgrounds_state.has(selection_id) if kind == "background" else owned_items_state.has(selection_id)
	var is_selected := selected_background_state == selection_id if kind == "background" else selected_skin_state == selection_id

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 246)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_panel_style(card, _style_box(
		Color(1.0, 0.97, 0.91, 0.98),
		Color(0.9, 0.75, 0.53, 1.0),
		20,
		2,
		Color(0.53, 0.31, 0.13, 0.08),
		5,
		Vector2(0, 3),
		{"left": 10, "top": 10, "right": 10, "bottom": 10}
	))

	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var title := _make_label(str(item.get("display_name", item_id)), 15, Color(0.35, 0.18, 0.08), Color(1, 1, 1, 0.28))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)

	var icon_center := CenterContainer.new()
	icon_center.custom_minimum_size = Vector2(0, 112)
	box.add_child(icon_center)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(88, 88)
	icon.texture = load(str(item.get("image", "")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if kind == "background":
		icon.custom_minimum_size = Vector2(132, 84)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon_center.add_child(icon)

	var bonus := _make_label(_item_bonus_text(item), 12, _item_bonus_color(item), Color(0, 0, 0, 0))
	bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(bonus)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 6)
	box.add_child(bottom_row)

	if is_owned and kind in ["skin", "background"]:
		var owned_row := HBoxContainer.new()
		owned_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		owned_row.alignment = BoxContainer.ALIGNMENT_CENTER
		owned_row.add_theme_constant_override("separation", 4)
		owned_row.add_child(_make_texture_rect(COIN_TEXTURE, Vector2(16, 16), Color(0.46, 0.83, 0.23, 1.0)))
		var owned_label := _make_label(Localization.text(current_language, "shop.owned" if not is_selected else "shop.selected"), 13, Color(0.29, 0.56, 0.16), Color(0, 0, 0, 0))
		owned_row.add_child(owned_label)
		bottom_row.add_child(owned_row)
	else:
		var price_row := HBoxContainer.new()
		price_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		price_row.alignment = BoxContainer.ALIGNMENT_CENTER
		price_row.add_theme_constant_override("separation", 4)
		price_row.add_child(_make_texture_rect(COIN_TEXTURE, Vector2(18, 18)))
		var price_label := _make_label(str(int(item.get("price", 0))), 15, Color(0.42, 0.21, 0.1), Color(0, 0, 0, 0))
		price_row.add_child(price_label)
		bottom_row.add_child(price_row)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(78, 34)
	action_button.text = _action_text(kind, is_owned, is_selected)
	action_button.add_theme_font_size_override("font_size", 14)
	action_button.add_theme_color_override("font_color", Color(1, 1, 1))
	_set_button_style(action_button, _style_box(
		Color(0.44, 0.79, 0.13, 1.0) if not is_selected else Color(0.66, 0.5, 0.26, 1.0),
		Color(0.24, 0.42, 0.07, 1.0) if not is_selected else Color(0.45, 0.3, 0.14, 1.0),
		14,
		3,
		Color(0, 0, 0, 0.12),
		4,
		Vector2(0, 2)
	))
	if is_selected and kind in ["skin", "background"]:
		action_button.disabled = true
	action_button.pressed.connect(_on_item_pressed.bind(item_id))
	bottom_row.add_child(action_button)

	return card

func _refresh_daily_deal() -> void:
	if daily_deal_name_label == null:
		return
	daily_deal_ribbon_label.text = Localization.text(current_language, "shop.daily_deal")

	var item_id := str(daily_deal_state.get("item_id", ""))
	if item_id == "" or not shop_catalog.has(item_id):
		daily_deal_name_label.text = Localization.text(current_language, "shop.daily_deal")
		daily_deal_button.text = Localization.text(current_language, "shop.soon")
		daily_deal_button.disabled = true
		daily_deal_old_price_label.text = ""
		daily_deal_timer_label.text = Localization.text(current_language, "shop.check_back_later")
		return

	var item: Dictionary = shop_catalog[item_id]
	var base_price := int(item.get("price", 0))
	var discount_percent := int(daily_deal_state.get("discount_percent", 30))
	var discounted_price := maxi(1, int(round(base_price * float(100 - discount_percent) / 100.0)))
	var claimed := bool(daily_deal_state.get("claimed", false))

	daily_deal_name_label.text = str(item.get("display_name", "Daily Deal"))
	daily_deal_caption_label.text = Localization.text(current_language, "shop.today_only", {"bonus": _item_bonus_text(item)})
	daily_deal_old_price_label.text = "[center][s]%d[/s][/center]" % base_price
	daily_deal_button.text = Localization.text(current_language, "shop.claimed") if claimed else str(discounted_price)
	daily_deal_button.disabled = claimed
	daily_deal_discount_label.text = "-%d%%" % discount_percent
	daily_deal_timer_label.text = Localization.text(current_language, "shop.refresh_in", {"time": _countdown_text()})

func _on_tab_pressed(tab_id: String) -> void:
	current_tab = tab_id
	message_label.text = ""
	tab_changed.emit(current_tab)
	_refresh_all()

func _on_item_pressed(item_id: String) -> void:
	if not shop_catalog.has(item_id):
		return
	var item: Dictionary = shop_catalog[item_id]
	var kind := str(item.get("kind", "consumable"))
	var selection_id := str(item.get("selection_id", item_id))
	var is_owned := owned_backgrounds_state.has(selection_id) if kind == "background" else owned_items_state.has(selection_id)
	if is_owned and kind in ["skin", "background"]:
		select_requested.emit(selection_id)
	else:
		buy_requested.emit(item_id)

func _on_daily_deal_pressed() -> void:
	var item_id := str(daily_deal_state.get("item_id", ""))
	if item_id != "":
		daily_deal_requested.emit(item_id)

func _on_resized() -> void:
	if board_area == null or grid == null:
		return
	var available_width := board_area.size.x
	grid.columns = 2 if available_width < 520.0 else 3
	_layout_purchase_bubble()

func _style_scrollbar(scrollbar: VScrollBar) -> void:
	if scrollbar == null:
		return
	scrollbar.custom_minimum_size.x = 16.0
	scrollbar.mouse_filter = Control.MOUSE_FILTER_STOP
	scrollbar.add_theme_constant_override("grabber_min_size", 60)
	scrollbar.add_theme_stylebox_override("scroll", _style_box(
		Color(0.83, 0.61, 0.38, 0.35),
		Color(0.61, 0.37, 0.18, 0.35),
		10,
		1,
		Color(0, 0, 0, 0.0),
		0,
		Vector2.ZERO
	))
	scrollbar.add_theme_stylebox_override("scroll_focus", _style_box(
		Color(0.83, 0.61, 0.38, 0.35),
		Color(0.61, 0.37, 0.18, 0.35),
		10,
		1,
		Color(0, 0, 0, 0.0),
		0,
		Vector2.ZERO
	))
	scrollbar.add_theme_stylebox_override("grabber", _style_box(
		Color(0.69, 0.42, 0.2, 0.96),
		Color(0.45, 0.25, 0.12, 1.0),
		10,
		2,
		Color(0, 0, 0, 0.16),
		4,
		Vector2(0, 2)
	))
	scrollbar.add_theme_stylebox_override("grabber_highlight", _style_box(
		Color(0.78, 0.5, 0.24, 0.98),
		Color(0.5, 0.28, 0.14, 1.0),
		10,
		2,
		Color(0, 0, 0, 0.16),
		4,
		Vector2(0, 2)
	))
	scrollbar.add_theme_stylebox_override("grabber_pressed", _style_box(
		Color(0.58, 0.34, 0.17, 0.98),
		Color(0.38, 0.21, 0.1, 1.0),
		10,
		2,
		Color(0, 0, 0, 0.16),
		4,
		Vector2(0, 2)
	))

func _item_bonus_text(item: Dictionary) -> String:
	var kind := str(item.get("kind", "consumable"))
	if kind == "skin":
		return Localization.text(current_language, "shop.bonus.style_unlock")
	if kind == "background":
		return Localization.text(current_language, "shop.bonus.room_theme")

	var parts: Array[String] = []
	var effects: Dictionary = item.get("effects", {})
	for stat_name in effects.keys():
		parts.append("%+d %s" % [int(effects[stat_name]), _stat_display_name(str(stat_name))])
	return " / ".join(parts) if not parts.is_empty() else Localization.text(current_language, "shop.bonus.cute_surprise")

func _item_bonus_color(item: Dictionary) -> Color:
	var kind := str(item.get("kind", "consumable"))
	if kind == "skin":
		return Color(0.65, 0.37, 0.82)
	if kind == "background":
		return Color(0.2, 0.52, 0.79)

	var effects: Dictionary = item.get("effects", {})
	if effects.has("happiness"):
		return Color(0.85, 0.18, 0.45)
	if effects.has("energy"):
		return Color(0.91, 0.64, 0.11)
	return Color(0.21, 0.61, 0.19)

func _action_text(kind: String, is_owned: bool, is_selected: bool) -> String:
	if kind in ["skin", "background"]:
		if is_selected:
			return Localization.text(current_language, "shop.selected")
		if is_owned:
			return Localization.text(current_language, "shop.select")
	return Localization.text(current_language, "shop.buy")

func _stat_display_name(stat_name: String) -> String:
	match stat_name:
		"hunger":
			return Localization.text(current_language, "shop.stat.hunger")
		"happiness":
			return Localization.text(current_language, "shop.stat.happiness")
		"energy":
			return Localization.text(current_language, "shop.stat.energy")
		_:
			return stat_name.capitalize()

func _countdown_text() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var total_seconds := (24 * 60 * 60) - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))
	if total_seconds <= 0:
		total_seconds = 1
	var hours := int(total_seconds / 3600)
	var minutes := int((total_seconds % 3600) / 60)
	var seconds := int(total_seconds % 60)
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

func _has_tab(tab_id: String) -> bool:
	for tab_data in TAB_CONFIG:
		if str(tab_data["id"]) == tab_id:
			return true
	return false

func _make_texture_rect(texture: Texture2D, min_size: Vector2, modulate_color: Color = Color(1, 1, 1, 1)) -> TextureRect:
	var node := TextureRect.new()
	node.custom_minimum_size = min_size
	node.texture = texture
	node.modulate = modulate_color
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _make_label(text_value: String, font_size: int, font_color: Color, shadow_color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", shadow_color)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _style_box(bg_color: Color, border_color: Color, radius: int, border_width: int = 3, shadow_color: Color = Color(0, 0, 0, 0.18), shadow_size: int = 5, shadow_offset: Vector2 = Vector2(0, 3), margins: Dictionary = {}) -> StyleBoxFlat:
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
	style.content_margin_left = float(margins.get("left", 0.0))
	style.content_margin_top = float(margins.get("top", 0.0))
	style.content_margin_right = float(margins.get("right", 0.0))
	style.content_margin_bottom = float(margins.get("bottom", 0.0))
	return style

func _set_panel_style(control: Control, style: StyleBoxFlat) -> void:
	control.add_theme_stylebox_override("panel", style)

func _set_button_style(button: Button, style: StyleBoxFlat) -> void:
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("disabled", style)

func _layout_purchase_bubble() -> void:
	if purchase_bubble == null:
		return
	var bubble_width: float = clampf(size.x * 0.4, 240.0, 320.0)
	var bubble_height: float = bubble_width * float(SPEECH_BUBBLE_REGION.size.y / SPEECH_BUBBLE_REGION.size.x)
	purchase_bubble.size = Vector2(bubble_width, bubble_height)
	purchase_bubble_base_position = Vector2(size.x * 0.54, size.y * 0.085)
	purchase_bubble.position = purchase_bubble_base_position
	purchase_bubble.pivot_offset = purchase_bubble.size * 0.5

func _random_purchase_message_key(category_id: String) -> String:
	var message_keys: Array = PURCHASE_MESSAGE_KEYS.get(category_id, [])
	if message_keys.is_empty():
		return ""

	var previous_index := int(last_purchase_message_indices.get(category_id, -1))
	var message_index := randi_range(0, message_keys.size() - 1)
	if message_keys.size() > 1 and message_index == previous_index:
		message_index = (message_index + 1 + randi_range(0, message_keys.size() - 2)) % message_keys.size()
	last_purchase_message_indices[category_id] = message_index
	return str(message_keys[message_index])

func _on_purchase_bubble_timeout() -> void:
	if purchase_bubble == null:
		return
	if purchase_bubble_tween != null:
		purchase_bubble_tween.kill()
	purchase_bubble_tween = create_tween()
	purchase_bubble_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	purchase_bubble_tween.parallel().tween_property(purchase_bubble, "modulate:a", 0.0, 0.28)
	purchase_bubble_tween.parallel().tween_property(purchase_bubble, "position", purchase_bubble_base_position + Vector2(0, -8), 0.28)
	purchase_bubble_tween.finished.connect(_on_purchase_bubble_faded)

func _on_purchase_bubble_faded() -> void:
	if purchase_bubble == null:
		return
	purchase_bubble.visible = false
	purchase_bubble.position = purchase_bubble_base_position
