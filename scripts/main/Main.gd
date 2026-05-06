extends Node

const Localization = preload("res://scripts/core/Localization.gd")
const BathroomRoomScene = preload("res://scenes/bathroom/BathroomRoom.tscn")

signal currency_changed(amount: int)
signal pet_stats_changed(stats: Dictionary)
signal inventory_changed(owned_items: Array, selected_skin: String)

const FEED_COST := 5
const FEED_HUNGER_GAIN := 18
const FEED_HAPPINESS_GAIN := 6
const MINIGAME_REWARD_PER_CLICK := 2
const DAILY_DEAL_ITEM_ID := "mealBox"
const DAILY_DEAL_DISCOUNT_PERCENT := 30
const ROOM_HOME := "home"
const ROOM_SHOP := "shop"
const ROOM_BATHROOM := "bathroom"
const ROOM_MINIGAME := "minigame"
const BATHROOM_BACKGROUND_TEXTURE := "res://Bathroom/Bath.png"
const CLEANLINESS_DECAY_INTERVAL_SECONDS := 75.0
const CLEANLINESS_DECAY_PER_STEP := 4.0
const MINIGAME_CLEANLINESS_COST := 8.0

const SPECIAL_BACKGROUND_TEXTURES := {
	"beach": "res://beach.jpg",
	"nightRoom": "res://lobbynight.png",
	"halloween": "res://halloween.jpg",
	"xmas": "res://xmas.jpg"
}

# Main owns shared game state and keeps presentation scenes focused on UI/input.
var shop_catalog := {
	"fishSnack": {
		"display_name": "Fish Snack",
		"price": 50,
		"tab": "food",
		"kind": "consumable",
		"image": "res://assets/items/fish_snack.svg",
		"effects": {"hunger": 20},
		"order": 1
	},
	"premiumMeat": {
		"display_name": "Premium Meat",
		"price": 120,
		"tab": "food",
		"kind": "consumable",
		"image": "res://steak.png",
		"effects": {"hunger": 50},
		"order": 2
	},
	"cookie": {
		"display_name": "Cookie",
		"price": 40,
		"tab": "food",
		"kind": "consumable",
		"image": "res://assets/items/cookie_paw.svg",
		"effects": {"happiness": 10},
		"order": 3
	},
	"milk": {
		"display_name": "Milk",
		"price": 60,
		"tab": "food",
		"kind": "consumable",
		"image": "res://assets/items/milk_bottle.svg",
		"effects": {"hunger": 15},
		"order": 4
	},
	"iceCream": {
		"display_name": "Ice Cream",
		"price": 80,
		"tab": "food",
		"kind": "consumable",
		"image": "res://fagyi.png",
		"effects": {"happiness": 20},
		"order": 5
	},
	"goldenTreat": {
		"display_name": "Golden Treat",
		"price": 200,
		"tab": "food",
		"kind": "consumable",
		"image": "res://assets/items/golden_treat.svg",
		"effects": {"happiness": 100},
		"order": 6
	},
	"ball": {
		"display_name": "Ball Toss",
		"price": 70,
		"tab": "toys",
		"kind": "consumable",
		"image": "res://ball.png",
		"effects": {"happiness": 15},
		"order": 1
	},
	"rope": {
		"display_name": "Rope Tug",
		"price": 90,
		"tab": "toys",
		"kind": "consumable",
		"image": "res://kotel.png",
		"effects": {"happiness": 22},
		"order": 2
	},
	"teddy": {
		"display_name": "Teddy Bear",
		"price": 120,
		"tab": "toys",
		"kind": "consumable",
		"image": "res://maci.png",
		"effects": {"happiness": 30},
		"order": 3
	},
	"rubberChicken": {
		"display_name": "Rubber Chicken",
		"price": 150,
		"tab": "toys",
		"kind": "consumable",
		"image": "res://csirke.png",
		"effects": {"happiness": 36},
		"order": 4
	},
	"boneToy": {
		"display_name": "Chew Bone",
		"price": 55,
		"tab": "toys",
		"kind": "consumable",
		"image": "res://bone.png",
		"effects": {"happiness": 12},
		"order": 5
	},
	"pawCup": {
		"display_name": "Paw Cup",
		"price": 65,
		"tab": "toys",
		"kind": "consumable",
		"image": "res://cup.png",
		"effects": {"energy": 14},
		"order": 6
	},
	"beach": {
		"display_name": "Beach House",
		"price": 170,
		"tab": "furniture",
		"kind": "background",
		"image": "res://beach.jpg",
		"order": 1
	},
	"nightRoom": {
		"display_name": "Moonlight Loft",
		"price": 150,
		"tab": "furniture",
		"kind": "background",
		"image": "res://lobbynight.png",
		"order": 2
	},
	"halloween": {
		"display_name": "Spooky Den",
		"price": 200,
		"tab": "furniture",
		"kind": "background",
		"image": "res://halloween.jpg",
		"order": 3
	},
	"xmas": {
		"display_name": "Snowy Suite",
		"price": 200,
		"tab": "furniture",
		"kind": "background",
		"image": "res://xmas.jpg",
		"order": 4
	},
	"default": {
		"display_name": "Classic Pup",
		"price": 0,
		"tab": "skins",
		"kind": "skin",
		"image": "res://karakter.png",
		"order": 1
	},
	"cool": {
		"display_name": "Cool Pup",
		"price": 950,
		"tab": "skins",
		"kind": "skin",
		"image": "res://coolskin.png",
		"order": 2
	},
	"legend": {
		"display_name": "Legend Pup",
		"price": 2200,
		"tab": "skins",
		"kind": "skin",
		"image": "res://legendary.png",
		"order": 3
	},
	"mealBox": {
		"display_name": "Meal Box",
		"price": 150,
		"tab": "special",
		"kind": "consumable",
		"image": "res://assets/items/meal_box.svg",
		"effects": {"hunger": 40},
		"order": 1
	},
	"megaCookie": {
		"display_name": "Mega Cookie",
		"price": 180,
		"tab": "special",
		"kind": "consumable",
		"image": "res://assets/items/cookie_paw.svg",
		"effects": {"happiness": 45},
		"order": 2
	},
	"energyShake": {
		"display_name": "Energy Shake",
		"price": 130,
		"tab": "special",
		"kind": "consumable",
		"image": "res://energy.png",
		"effects": {"energy": 35},
		"order": 3
	},
	"royalTreat": {
		"display_name": "Royal Treat",
		"price": 260,
		"tab": "special",
		"kind": "consumable",
		"image": "res://assets/items/golden_treat.svg",
		"effects": {"hunger": 30, "happiness": 50},
		"order": 4
	},
	"coolSpecial": {
		"display_name": "Cool Pup+",
		"price": 950,
		"tab": "special",
		"kind": "skin",
		"image": "res://coolskin.png",
		"order": 5,
		"selection_id": "cool"
	},
	"legendSpecial": {
		"display_name": "Legend Pup+",
		"price": 2200,
		"tab": "special",
		"kind": "skin",
		"image": "res://legendary.png",
		"order": 6,
		"selection_id": "legend"
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
var daily_deal_claimed_on := ""
var current_language := "hu"
var master_volume := 100.0
var effects_volume := 100.0
var best_score := 0
var cleanliness := 100.0
var last_cleanliness_timestamp := 0
var cleanliness_decay_accumulator := 0.0
var current_room := ROOM_HOME
var current_shop_tab := "food"

@onready var lobby_background: TextureRect = $LobbyBackground
@onready var pet := $Pet
@onready var hud := $HUD
@onready var shop := $Shop
@onready var minigame := $Minigame
@onready var settings := $Settings
var bathroom: Control

func _ready() -> void:
	_create_bathroom_room()
	_connect_signals()
	_load_state()
	_show_home()
	set_process(true)

func _process(delta: float) -> void:
	cleanliness_decay_accumulator += delta
	if cleanliness_decay_accumulator < CLEANLINESS_DECAY_INTERVAL_SECONDS:
		return

	var decay_steps := int(floor(cleanliness_decay_accumulator / CLEANLINESS_DECAY_INTERVAL_SECONDS))
	cleanliness_decay_accumulator -= decay_steps * CLEANLINESS_DECAY_INTERVAL_SECONDS
	if _change_cleanliness(-float(decay_steps) * CLEANLINESS_DECAY_PER_STEP):
		_emit_state()
		_save_state()

func _connect_signals() -> void:
	hud.feed_requested.connect(_on_feed_requested)
	hud.shop_requested.connect(_on_shop_requested)
	hud.skins_requested.connect(_on_skins_requested)
	hud.minigame_requested.connect(_show_minigame)
	hud.settings_requested.connect(_show_settings)
	hud.bathroom_requested.connect(_on_bathroom_requested)
	shop.buy_requested.connect(_on_buy_requested)
	shop.select_requested.connect(_on_select_requested)
	shop.daily_deal_requested.connect(_on_daily_deal_requested)
	shop.tab_changed.connect(_on_shop_tab_changed)
	minigame.coins_earned.connect(_on_minigame_coins_earned)
	minigame.run_finished.connect(_on_minigame_run_finished)
	minigame.quit_requested.connect(_show_home)
	settings.close_requested.connect(_hide_settings)
	settings.home_requested.connect(_show_home)
	settings.language_changed.connect(_on_language_changed)
	settings.audio_levels_changed.connect(_on_audio_levels_changed)
	bathroom.cleaning_finished.connect(_on_bathroom_cleaning_finished)

func _create_bathroom_room() -> void:
	bathroom = BathroomRoomScene.instantiate()
	add_child(bathroom)

func _load_state() -> void:
	var data := SaveManager.load_game()
	currency = int(data["currency"])
	pet_stats = data["pet_stats"].duplicate(true)
	owned_items = data["owned_items"].duplicate()
	owned_backgrounds = data.get("owned_backgrounds", ["default"]).duplicate()
	selected_skin = str(data["selected_skin"])
	selected_background = str(data.get("selected_background", "default"))
	daily_deal_claimed_on = str(data.get("daily_deal_claimed_on", ""))
	current_language = str(data.get("language_code", "hu"))
	master_volume = float(data.get("master_volume", 100.0))
	effects_volume = float(data.get("effects_volume", 100.0))
	best_score = int(data.get("best_score", 0))
	cleanliness = float(data.get("cleanliness", 100.0))
	last_cleanliness_timestamp = int(data.get("last_cleanliness_timestamp", _now_unix()))
	_apply_offline_cleanliness_decay()

	if not owned_items.has("default"):
		owned_items.append("default")
	if not owned_backgrounds.has("default"):
		owned_backgrounds.append("default")
	if not shop_catalog.has(selected_skin):
		selected_skin = "default"
	if selected_background != "default" and not SPECIAL_BACKGROUND_TEXTURES.has(selected_background):
		selected_background = "default"

	pet.set_skin(selected_skin)
	pet.set_stats(pet_stats)
	pet.set_cleanliness(cleanliness)
	_apply_preferences()
	_refresh_room_visuals()
	_emit_state()

func _save_state() -> void:
	SaveManager.save_game({
		"currency": currency,
		"pet_stats": pet_stats,
		"owned_items": owned_items,
		"selected_skin": selected_skin,
		"owned_backgrounds": owned_backgrounds,
		"selected_background": selected_background,
		"daily_deal_claimed_on": daily_deal_claimed_on,
		"language_code": current_language,
		"master_volume": master_volume,
		"effects_volume": effects_volume,
		"best_score": best_score,
		"cleanliness": cleanliness,
		"last_cleanliness_timestamp": _now_unix()
	})

func _emit_state() -> void:
	currency_changed.emit(currency)
	pet_stats_changed.emit(pet_stats)
	inventory_changed.emit(owned_items, selected_skin)
	hud.set_localization(current_language)
	hud.set_currency(currency)
	hud.set_pet_stats(pet_stats)
	pet.set_stats(pet_stats)
	pet.set_cleanliness(cleanliness)
	shop.set_localization(current_language)
	shop.set_shop_data(
		_get_localized_shop_catalog(),
		owned_items,
		owned_backgrounds,
		selected_skin,
		selected_background,
		currency,
		_build_daily_deal_state()
	)
	minigame.set_localization(current_language)
	minigame.set_effects_volume(effects_volume)
	bathroom.configure(current_language, selected_skin, pet_stats, cleanliness)
	settings.sync_state(_build_settings_state())
	_refresh_room_visuals()

func _on_feed_requested() -> void:
	if currency < FEED_COST:
		hud.show_status(Localization.text(current_language, "main.need_feed", {"cost": FEED_COST}))
		return

	currency -= FEED_COST
	pet_stats["hunger"] = clampi(int(pet_stats["hunger"]) + FEED_HUNGER_GAIN, 0, 100)
	pet_stats["happiness"] = clampi(int(pet_stats["happiness"]) + FEED_HAPPINESS_GAIN, 0, 100)
	pet.play_eating()
	hud.show_status(Localization.text(current_language, "main.fed_pet"))
	_emit_state()
	_save_state()

func _on_buy_requested(item_id: String) -> void:
	_purchase_item(item_id)

func _on_shop_requested() -> void:
	if current_room == ROOM_SHOP and current_shop_tab != "skins":
		_show_home()
		return
	_show_shop("food")

func _on_skins_requested() -> void:
	if current_room == ROOM_SHOP and current_shop_tab == "skins":
		_show_home()
		return
	_show_shop("skins")

func _on_bathroom_requested() -> void:
	if current_room == ROOM_BATHROOM:
		_show_home()
		return
	_show_bathroom()

func _on_shop_tab_changed(tab_id: String) -> void:
	current_shop_tab = tab_id

func _on_daily_deal_requested(item_id: String) -> void:
	if _is_daily_deal_claimed_today():
		shop.show_message(Localization.text(current_language, "main.daily_claimed_already"))
		return
	if item_id != DAILY_DEAL_ITEM_ID:
		return
	if not shop_catalog.has(item_id):
		return

	var base_price := int(shop_catalog[item_id]["price"])
	var deal_price := maxi(1, int(round(base_price * float(100 - DAILY_DEAL_DISCOUNT_PERCENT) / 100.0)))
	if not _purchase_item(item_id, deal_price, Localization.text(current_language, "main.daily_claimed")):
		return

	daily_deal_claimed_on = _today_key()
	_emit_state()
	_save_state()

func _purchase_item(item_id: String, override_price: int = -1, success_message: String = "") -> bool:
	if not shop_catalog.has(item_id):
		return false

	var item: Dictionary = shop_catalog[item_id]
	var kind := str(item.get("kind", "consumable"))
	var selection_id := str(item.get("selection_id", item_id))

	if kind == "background" and owned_backgrounds.has(selection_id):
		_on_select_requested(selection_id)
		return true
	if kind == "skin" and owned_items.has(selection_id):
		_on_select_requested(selection_id)
		return true

	var price := override_price if override_price >= 0 else int(item["price"])
	if currency < price:
		shop.show_message(Localization.text(current_language, "main.not_enough_coins"))
		return false

	currency -= price

	match kind:
		"background":
			owned_backgrounds.append(selection_id)
			selected_background = selection_id
			_refresh_room_visuals()
			shop.show_message(success_message if success_message != "" else Localization.text(current_language, "main.unlocked", {"item": _get_item_display_name(selection_id)}))
			_emit_state()
			_save_state()
		"skin":
			owned_items.append(selection_id)
			selected_skin = selection_id
			pet.set_skin(selected_skin)
			shop.show_message(success_message if success_message != "" else Localization.text(current_language, "main.unlocked", {"item": _get_item_display_name(selection_id)}))
			_emit_state()
			_save_state()
		_:
			_apply_consumable(item)
			pet.show_temporary_item(str(item["image"]))
			shop.show_message(success_message if success_message != "" else Localization.text(current_language, "main.used", {"item": _get_item_display_name(item_id)}))
			_show_shop_purchase_reaction(item)
			_emit_state()
			_save_state()

	return true

func _on_select_requested(item_id: String) -> void:
	if not shop_catalog.has(item_id):
		return

	var item: Dictionary = shop_catalog[item_id]
	var kind := str(item.get("kind", "consumable"))
	if kind == "background":
		if not owned_backgrounds.has(item_id):
			return
		selected_background = item_id
		_refresh_room_visuals()
	else:
		if not owned_items.has(item_id):
			return
		selected_skin = item_id
		pet.set_skin(selected_skin)

	shop.show_message(Localization.text(current_language, "main.selected", {"item": _get_item_display_name(item_id)}))
	_emit_state()
	_save_state()

func _on_minigame_coins_earned(amount: int) -> void:
	currency += amount
	hud.show_status(Localization.text(current_language, "main.coins_plus", {"amount": amount}))
	_emit_state()
	_save_state()

func _on_minigame_run_finished(score: int) -> void:
	best_score = max(best_score, score)
	var cleanliness_changed := _change_cleanliness(-MINIGAME_CLEANLINESS_COST)
	settings.sync_state(_build_settings_state())
	if cleanliness_changed:
		_emit_state()
	_save_state()

func _show_home() -> void:
	current_room = ROOM_HOME
	lobby_background.visible = true
	pet.visible = true
	hud.visible = true
	hud.set_compact_mode(false)
	shop.visible = false
	shop.clear_purchase_reaction()
	bathroom.close_room()
	minigame.visible = false
	settings.visible = false
	_refresh_room_visuals()
	hud.show_status("")

func _show_shop(tab_id: String = "food") -> void:
	current_room = ROOM_SHOP
	current_shop_tab = tab_id
	lobby_background.visible = false
	pet.visible = false
	hud.visible = true
	hud.set_compact_mode(true)
	shop.visible = true
	bathroom.close_room()
	minigame.visible = false
	settings.visible = false
	shop.request_tab(tab_id)
	shop.set_shop_data(
		_get_localized_shop_catalog(),
		owned_items,
		owned_backgrounds,
		selected_skin,
		selected_background,
		currency,
		_build_daily_deal_state()
	)

func _show_bathroom() -> void:
	current_room = ROOM_BATHROOM
	lobby_background.visible = true
	lobby_background.texture = load(BATHROOM_BACKGROUND_TEXTURE)
	pet.visible = false
	hud.visible = true
	hud.set_compact_mode(true)
	shop.visible = false
	shop.clear_purchase_reaction()
	bathroom.open_room()
	minigame.visible = false
	settings.visible = false
	hud.show_status("")

func _show_minigame() -> void:
	current_room = ROOM_MINIGAME
	lobby_background.visible = false
	pet.visible = false
	hud.visible = false
	shop.visible = false
	shop.clear_purchase_reaction()
	bathroom.close_room()
	settings.visible = false
	minigame.visible = true
	minigame.start_game(
		MINIGAME_REWARD_PER_CLICK,
		_get_active_room_texture_path(),
		pet.get_selected_skin_texture_path()
	)

func _show_settings() -> void:
	settings.sync_state(_build_settings_state())
	settings.open()

func _hide_settings() -> void:
	settings.visible = false

func _on_language_changed(language_code: String) -> void:
	current_language = language_code
	_apply_preferences()
	_emit_state()
	_save_state()

func _on_audio_levels_changed(master_volume_percent: float, effects_volume_percent: float) -> void:
	master_volume = master_volume_percent
	effects_volume = effects_volume_percent
	_apply_audio_settings()
	settings.sync_state(_build_settings_state())
	_save_state()

func _on_bathroom_cleaning_finished(happiness_gain: int) -> void:
	if cleanliness >= 100.0:
		return
	cleanliness = 100.0
	pet_stats["happiness"] = clampi(int(pet_stats.get("happiness", 0)) + happiness_gain, 0, 100)
	_emit_state()
	_save_state()

func _apply_consumable(item: Dictionary) -> void:
	var effects: Dictionary = item.get("effects", {})
	for stat_name in effects.keys():
		pet_stats[stat_name] = clampi(int(pet_stats.get(stat_name, 0)) + int(effects[stat_name]), 0, 100)

func _refresh_room_visuals() -> void:
	if current_room == ROOM_BATHROOM:
		lobby_background.texture = load(BATHROOM_BACKGROUND_TEXTURE)
		return
	lobby_background.texture = load(_get_active_room_texture_path())

func _get_active_room_texture_path() -> String:
	if selected_background == "default":
		var hour := int(Time.get_datetime_dict_from_system()["hour"])
		return "res://lobbynight.png" if hour >= 19 or hour < 7 else "res://lobbyday.png"
	return SPECIAL_BACKGROUND_TEXTURES.get(selected_background, "res://lobbyday.png")

func _build_daily_deal_state() -> Dictionary:
	return {
		"item_id": DAILY_DEAL_ITEM_ID,
		"discount_percent": DAILY_DEAL_DISCOUNT_PERCENT,
		"claimed": _is_daily_deal_claimed_today()
	}

func _is_daily_deal_claimed_today() -> bool:
	return daily_deal_claimed_on == _today_key()

func _today_key() -> String:
	var date: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]

func _apply_preferences() -> void:
	_apply_audio_settings()
	hud.set_localization(current_language)
	shop.set_localization(current_language)
	bathroom.set_localization(current_language)
	minigame.set_localization(current_language)
	minigame.set_effects_volume(effects_volume)
	bathroom.configure(current_language, selected_skin, pet_stats, cleanliness)
	settings.sync_state(_build_settings_state())

func _apply_audio_settings() -> void:
	AudioServer.set_bus_volume_db(0, _volume_percent_to_db(master_volume))
	minigame.set_effects_volume(effects_volume)

func _volume_percent_to_db(volume_percent: float) -> float:
	if volume_percent <= 0.0:
		return -80.0
	return linear_to_db(volume_percent / 100.0)

func _show_shop_purchase_reaction(item: Dictionary) -> void:
	if not shop.visible:
		return
	var category_id := _purchase_reaction_category(item)
	if category_id == "":
		return
	shop.show_purchase_reaction(category_id)

func _purchase_reaction_category(item: Dictionary) -> String:
	var tab_id := str(item.get("tab", ""))
	if tab_id == "food":
		return "food"
	if tab_id == "toys":
		return "toy"
	if tab_id != "special":
		return ""

	var effects: Dictionary = item.get("effects", {})
	if effects.has("hunger"):
		return "food"
	if effects.has("happiness") or effects.has("energy"):
		return "toy"
	return ""

func _get_localized_shop_catalog() -> Dictionary:
	var localized_catalog := shop_catalog.duplicate(true)
	for item_id in localized_catalog.keys():
		localized_catalog[item_id]["display_name"] = _get_item_display_name(str(item_id))
	return localized_catalog

func _get_item_display_name(item_id: String) -> String:
	if not shop_catalog.has(item_id):
		return item_id
	return Localization.item_name(current_language, item_id, str(shop_catalog[item_id].get("display_name", item_id)))

func _build_settings_state() -> Dictionary:
	return {
		"language_code": current_language,
		"master_volume": master_volume,
		"effects_volume": effects_volume,
		"scoreboard_state": {
			"best_score": best_score,
			"currency": currency,
			"level": _current_level(),
			"skins_count": maxi(1, owned_items.size()),
			"rooms_count": maxi(1, owned_backgrounds.size()),
			"pet_stats": pet_stats.duplicate(true)
		}
	}

func _current_level() -> int:
	return max(1, int(currency / 300) + 1)

func _change_cleanliness(delta_amount: float) -> bool:
	var previous_cleanliness := cleanliness
	cleanliness = clampf(cleanliness + delta_amount, 0.0, 100.0)
	if is_equal_approx(previous_cleanliness, cleanliness):
		return false
	last_cleanliness_timestamp = _now_unix()
	return true

func _apply_offline_cleanliness_decay() -> void:
	var now: int = _now_unix()
	if last_cleanliness_timestamp <= 0:
		last_cleanliness_timestamp = now
		return
	var elapsed_seconds: int = maxi(0, now - last_cleanliness_timestamp)
	var decay_steps := int(floor(float(elapsed_seconds) / CLEANLINESS_DECAY_INTERVAL_SECONDS))
	if decay_steps > 0:
		cleanliness = clampf(cleanliness - float(decay_steps) * CLEANLINESS_DECAY_PER_STEP, 0.0, 100.0)
	last_cleanliness_timestamp = now

func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())
