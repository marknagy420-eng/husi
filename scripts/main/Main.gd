extends Node

signal currency_changed(amount: int)
signal pet_stats_changed(stats: Dictionary)
signal inventory_changed(owned_items: Array, selected_skin: String)

const FEED_COST := 5
const FEED_HUNGER_GAIN := 18
const FEED_HAPPINESS_GAIN := 6
const MINIGAME_REWARD_PER_CLICK := 2

const BACKGROUND_TEXTURES := {
	"default": "res://ezkellneked.jpg",
	"halloween": "res://halloween.jpg",
	"xmas": "res://xmas.jpg"
}

# Main owns shared game state and lets child scenes stay focused on presentation/input.
var shop_catalog := {
	"default": {
		"display_name": "Alap skin",
		"price": 0,
		"category": "skin",
		"image": "res://karakter.png"
	},
	"dogFood": {
		"display_name": "Kutyatap",
		"price": 150,
		"category": "food",
		"image": "res://tal.png",
		"effects": {"hunger": 20}
	},
	"meat": {
		"display_name": "Hus",
		"price": 220,
		"category": "food",
		"image": "res://steak.png",
		"effects": {"hunger": 30}
	},
	"bone": {
		"display_name": "Csont",
		"price": 60,
		"category": "food",
		"image": "res://bone.png",
		"effects": {"hunger": 10}
	},
	"cookie": {
		"display_name": "Suti",
		"price": 300,
		"category": "food",
		"image": "res://cake.png",
		"effects": {"hunger": 40}
	},
	"iceCream": {
		"display_name": "Fagyi",
		"price": 110,
		"category": "food",
		"image": "res://fagyi.png",
		"effects": {"hunger": 25, "happiness": 30}
	},
	"ball": {
		"display_name": "Labda",
		"price": 100,
		"category": "games",
		"image": "res://ball.png",
		"effects": {"happiness": 30}
	},
	"rope": {
		"display_name": "Kotel",
		"price": 130,
		"category": "games",
		"image": "res://kotel.png",
		"effects": {"happiness": 45}
	},
	"teddy": {
		"display_name": "Pluss maci",
		"price": 285,
		"category": "games",
		"image": "res://maci.png",
		"effects": {"happiness": 60}
	},
	"rubberChicken": {
		"display_name": "Gumi csirke",
		"price": 310,
		"category": "games",
		"image": "res://csirke.png",
		"effects": {"happiness": 75}
	},
	"cool": {
		"display_name": "Cool skin",
		"price": 1500,
		"category": "skin",
		"image": "res://coolskin.png"
	},
	"legend": {
		"display_name": "Legendary skin",
		"price": 50000,
		"category": "skin",
		"image": "res://legendary.png"
	},
	"halloween": {
		"display_name": "Halloween hatter",
		"price": 200,
		"category": "background",
		"image": "res://halloween.jpg"
	},
	"xmas": {
		"display_name": "Karacsonyi hatter",
		"price": 200,
		"category": "background",
		"image": "res://xmas.jpg"
	}
}

var currency := 0
var pet_stats := {
	"hunger": 70,
	"happiness": 70,
	"energy": 72
}
var owned_items: Array = ["default"]
var owned_backgrounds: Array = ["default"]
var selected_skin := "default"
var selected_background := "default"

@onready var lobby_background := $LobbyBackground
@onready var pet := $Pet
@onready var hud := $HUD
@onready var shop := $Shop
@onready var minigame := $Minigame
@onready var settings := $Settings

func _ready() -> void:
	_connect_signals()
	_load_state()
	_show_home()

func _connect_signals() -> void:
	hud.feed_requested.connect(_on_feed_requested)
	hud.shop_requested.connect(_show_shop)
	hud.minigame_requested.connect(_show_minigame)
	hud.settings_requested.connect(_show_settings)
	shop.buy_requested.connect(_on_buy_requested)
	shop.select_requested.connect(_on_select_requested)
	shop.back_requested.connect(_show_home)
	minigame.coins_earned.connect(_on_minigame_coins_earned)
	minigame.quit_requested.connect(_show_home)
	settings.close_requested.connect(_hide_settings)
	settings.home_requested.connect(_show_home)

func _load_state() -> void:
	var data := SaveManager.load_game()
	currency = int(data["currency"])
	pet_stats = data["pet_stats"].duplicate(true)
	owned_items = data["owned_items"].duplicate()
	owned_backgrounds = data.get("owned_backgrounds", ["default"]).duplicate()
	selected_skin = str(data["selected_skin"])
	selected_background = str(data.get("selected_background", "default"))
	pet.set_skin(selected_skin)
	pet.set_stats(pet_stats)
	_set_lobby_background()
	_emit_state()

func _save_state() -> void:
	SaveManager.save_game({
		"currency": currency,
		"pet_stats": pet_stats,
		"owned_items": owned_items,
		"selected_skin": selected_skin,
		"owned_backgrounds": owned_backgrounds,
		"selected_background": selected_background
	})

func _emit_state() -> void:
	currency_changed.emit(currency)
	pet_stats_changed.emit(pet_stats)
	inventory_changed.emit(owned_items, selected_skin)
	hud.set_currency(currency)
	hud.set_pet_stats(pet_stats)
	pet.set_stats(pet_stats)
	shop.set_shop_data(shop_catalog, owned_items, owned_backgrounds, selected_skin, selected_background, currency)

func _on_feed_requested() -> void:
	if currency < FEED_COST:
		hud.show_status("Need %d coins to feed." % FEED_COST)
		return

	currency -= FEED_COST
	pet_stats["hunger"] = clampi(int(pet_stats["hunger"]) + FEED_HUNGER_GAIN, 0, 100)
	pet_stats["happiness"] = clampi(int(pet_stats["happiness"]) + FEED_HAPPINESS_GAIN, 0, 100)
	pet.play_eating()
	hud.show_status("Fed pet.")
	_emit_state()
	_save_state()

func _on_buy_requested(item_id: String) -> void:
	if not shop_catalog.has(item_id):
		return

	var item: Dictionary = shop_catalog[item_id]
	var category := str(item["category"])

	if category == "background" and owned_backgrounds.has(item_id):
		_on_select_requested(item_id)
		return
	if category == "skin" and owned_items.has(item_id):
		_on_select_requested(item_id)
		return

	var price := int(item["price"])
	if currency < price:
		shop.show_message("Not enough coins.")
		return

	currency -= price

	if category == "background":
		owned_backgrounds.append(item_id)
		_on_select_requested(item_id)
	elif category == "skin":
		owned_items.append(item_id)
		_on_select_requested(item_id)
	else:
		_apply_consumable(item)
		pet.show_temporary_item(str(item["image"]))
		hud.show_status("Used %s." % item["display_name"])
		_emit_state()
		_save_state()

func _on_select_requested(item_id: String) -> void:
	if not shop_catalog.has(item_id):
		return

	var category := str(shop_catalog[item_id]["category"])
	if category == "background":
		if not owned_backgrounds.has(item_id):
			return
		selected_background = item_id
		_set_lobby_background()
	else:
		if not owned_items.has(item_id):
			return
		selected_skin = item_id
		pet.set_skin(selected_skin)
	_emit_state()
	_save_state()

func _on_minigame_coins_earned(amount: int) -> void:
	currency += amount
	hud.show_status("+%d coins" % amount)
	_emit_state()
	_save_state()

func _show_home() -> void:
	lobby_background.visible = true
	pet.visible = true
	hud.visible = true
	shop.visible = false
	minigame.visible = false
	settings.visible = false
	hud.show_status("")

func _show_shop() -> void:
	lobby_background.visible = false
	pet.visible = false
	hud.visible = false
	shop.visible = true
	minigame.visible = false
	settings.visible = false
	shop.set_shop_data(shop_catalog, owned_items, owned_backgrounds, selected_skin, selected_background, currency)

func _show_minigame() -> void:
	lobby_background.visible = false
	pet.visible = false
	hud.visible = false
	shop.visible = false
	minigame.visible = true
	settings.visible = false
	minigame.start_game(
		MINIGAME_REWARD_PER_CLICK,
		BACKGROUND_TEXTURES.get(selected_background, BACKGROUND_TEXTURES["default"]),
		pet.get_selected_skin_texture_path()
	)

func _show_settings() -> void:
	settings.open()

func _hide_settings() -> void:
	settings.visible = false

func _apply_consumable(item: Dictionary) -> void:
	var effects: Dictionary = item.get("effects", {})
	for stat_name in effects.keys():
		pet_stats[stat_name] = clampi(int(pet_stats.get(stat_name, 0)) + int(effects[stat_name]), 0, 100)

func _set_lobby_background() -> void:
	var hour := int(Time.get_datetime_dict_from_system()["hour"])
	var lobby_path := "res://lobbynight.png" if hour >= 19 or hour < 7 else "res://lobbyday.png"
	lobby_background.texture = load(lobby_path)
