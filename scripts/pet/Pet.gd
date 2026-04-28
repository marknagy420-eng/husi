extends Node2D

const SKIN_TEXTURES := {
	"default": "res://karakter.png",
	"cool": "res://coolskin.png",
	"legend": "res://legendary.png"
}

const MOOD_TEXTURES := {
	"hungry": "res://ehes.png",
	"tired": "res://faradt.png",
	"sad": "res://Szomoru2.png"
}

@onready var sprite: Sprite2D = $Sprite2D
@onready var item_sprite: Sprite2D = $ItemSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var eat_timer: Timer = $EatTimer

var current_skin := "default"
var current_stats := {
	"hunger": 70,
	"happiness": 70
}
var temporary_texture_path := ""

func _ready() -> void:
	eat_timer.timeout.connect(_on_eat_timer_timeout)
	set_skin(current_skin)

func set_skin(skin_id: String) -> void:
	current_skin = skin_id if SKIN_TEXTURES.has(skin_id) else "default"
	_refresh_texture()
	animation_player.play("idle")

func set_stats(stats: Dictionary) -> void:
	current_stats = stats.duplicate(true)
	_refresh_texture()

func show_temporary_item(texture_path: String) -> void:
	temporary_texture_path = texture_path
	_refresh_texture()
	play_eating()

func play_eating() -> void:
	animation_player.play("eating")
	eat_timer.start()

func _refresh_texture() -> void:
	var texture_path := _get_pet_texture_path()
	sprite.texture = load(texture_path)
	item_sprite.visible = false

func _get_pet_texture_path() -> String:
	return get_pet_texture_path()

func get_pet_texture_path() -> String:
	if temporary_texture_path != "":
		return temporary_texture_path
	if int(current_stats.get("happiness", 100)) < 45:
		return MOOD_TEXTURES["sad"]
	if int(current_stats.get("hunger", 100)) <= 35:
		return MOOD_TEXTURES["hungry"]
	return SKIN_TEXTURES[current_skin]

func get_selected_skin_texture_path() -> String:
	return SKIN_TEXTURES[current_skin]

func _on_eat_timer_timeout() -> void:
	temporary_texture_path = ""
	_refresh_texture()
	animation_player.play("idle")
