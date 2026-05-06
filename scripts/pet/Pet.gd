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

const DIRT_TEXTURE_SOURCE := preload("res://Bathroom/kosz.png")
const FOAM_TEXTURE_SOURCE := preload("res://Bathroom/hab.png")
const WATER_TEXTURE_SOURCE := preload("res://Bathroom/viz.png")
const DIRT_TEXTURE_REGION := Rect2(129.0, 344.0, 799.0, 819.0)
const FOAM_TEXTURE_REGION := Rect2(89.0, 180.0, 841.0, 760.0)
const WATER_TEXTURE_REGION := Rect2(84.0, 96.0, 845.0, 809.0)
const BODY_ANCHORS := [
	Vector2(-0.18, -0.16),
	Vector2(-0.08, -0.2),
	Vector2(0.06, -0.2),
	Vector2(0.18, -0.15),
	Vector2(-0.24, -0.06),
	Vector2(-0.12, -0.04),
	Vector2(0.0, -0.03),
	Vector2(0.12, -0.04),
	Vector2(0.24, -0.06),
	Vector2(-0.2, 0.05),
	Vector2(-0.08, 0.06),
	Vector2(0.06, 0.06),
	Vector2(0.18, 0.05)
]
const BODY_JITTER := Vector2(0.035, 0.03)

@onready var sprite: Sprite2D = $Sprite2D
@onready var overlay_container: Node2D = $Sprite2D/OverlayContainer
@onready var item_sprite: Sprite2D = $ItemSprite
@onready var sparkle_root: Node2D = $SparkleRoot
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var eat_timer: Timer = $EatTimer

var current_skin := "default"
var current_stats := {
	"hunger": 70,
	"happiness": 70
}
var temporary_texture_path := ""
var cleanliness := 100.0
var foam_amount := 0.0
var wet_amount := 0.0
var sparkle_tween: Tween
var dirt_instances: Array[Sprite2D] = []
var foam_instances: Array[Sprite2D] = []
var wet_instances: Array[Sprite2D] = []
var overlay_rng := RandomNumberGenerator.new()
var dirt_overlay_texture: Texture2D
var foam_overlay_texture: Texture2D
var water_overlay_texture: Texture2D

func _ready() -> void:
	overlay_rng.randomize()
	dirt_overlay_texture = _build_overlay_texture(DIRT_TEXTURE_SOURCE, DIRT_TEXTURE_REGION)
	foam_overlay_texture = _build_overlay_texture(FOAM_TEXTURE_SOURCE, FOAM_TEXTURE_REGION)
	water_overlay_texture = _build_overlay_texture(WATER_TEXTURE_SOURCE, WATER_TEXTURE_REGION)
	eat_timer.timeout.connect(_on_eat_timer_timeout)
	set_skin(current_skin)
	_update_overlays()

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

func set_cleanliness(value: float) -> void:
	cleanliness = clampf(value, 0.0, 100.0)
	_update_overlays()

func set_foam_amount(value: float) -> void:
	foam_amount = clampf(value, 0.0, 1.0)
	_update_overlays()

func set_wet_amount(value: float) -> void:
	wet_amount = clampf(value, 0.0, 1.0)
	_update_overlays()

func clear_bath_overlays() -> void:
	foam_amount = 0.0
	wet_amount = 0.0
	_update_overlays()

func play_clean_sparkle() -> void:
	if sparkle_tween != null:
		sparkle_tween.kill()
	sparkle_tween = create_tween()
	for child in sparkle_root.get_children():
		var sparkle := child as Sprite2D
		if sparkle == null:
			continue
		sparkle.visible = true
		sparkle.scale = Vector2(0.05, 0.05)
		sparkle.modulate = Color(1, 1, 1, 0.0)
		var base_position := sparkle.position
		sparkle_tween.parallel().tween_property(sparkle, "scale", sparkle.scale * 4.0, 0.18)
		sparkle_tween.parallel().tween_property(sparkle, "modulate:a", 1.0, 0.14)
		sparkle_tween.parallel().tween_property(sparkle, "position", base_position + Vector2(0, -10), 0.2)
		sparkle_tween.parallel().tween_property(sparkle, "modulate:a", 0.0, 0.42).set_delay(0.18)
	sparkle_tween.finished.connect(_on_sparkle_finished)

func contains_global_point(global_point: Vector2) -> bool:
	return get_global_interaction_rect().has_point(global_point)

func get_global_interaction_rect() -> Rect2:
	var texture := sprite.texture
	if texture == null:
		return Rect2(global_position - Vector2(90, 90), Vector2(180, 180))
	var size := texture.get_size() * sprite.scale
	var top_left := sprite.global_position - size * 0.5
	return Rect2(top_left, size)

func play_eating() -> void:
	animation_player.play("eating")
	eat_timer.start()

func _refresh_texture() -> void:
	var texture_path := _get_pet_texture_path()
	sprite.texture = load(texture_path)
	item_sprite.visible = false
	_update_overlays()

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

func _update_overlays() -> void:
	var dirt_ratio := clampf((88.0 - cleanliness) / 88.0, 0.0, 1.0)
	var dirt_count := 0
	if dirt_ratio > 0.0:
		dirt_count = int(round(lerpf(5.0, 15.0, dirt_ratio)))
	_sync_overlay_instances(
		dirt_instances,
		dirt_count,
		dirt_overlay_texture,
		clampf(dirt_ratio * 0.9, 0.0, 0.9),
		Vector2(0.014, 0.014),
		Vector2(0.026, 0.026)
	)

	var foam_count := 0
	if foam_amount > 0.02:
		foam_count = int(round(lerpf(10.0, 18.0, foam_amount)))
	_sync_overlay_instances(
		foam_instances,
		foam_count,
		foam_overlay_texture,
		clampf(foam_amount * 0.92, 0.0, 0.92),
		Vector2(0.014, 0.014),
		Vector2(0.024, 0.024)
	)

	var wet_count := 0
	if wet_amount > 0.02:
		wet_count = int(round(lerpf(8.0, 14.0, wet_amount)))
	_sync_overlay_instances(
		wet_instances,
		wet_count,
		water_overlay_texture,
		clampf(wet_amount * 0.8, 0.0, 0.8),
		Vector2(0.012, 0.012),
		Vector2(0.02, 0.02)
	)

func _on_sparkle_finished() -> void:
	for child in sparkle_root.get_children():
		var sparkle := child as Sprite2D
		if sparkle != null:
			sparkle.visible = false

func _sync_overlay_instances(instances: Array[Sprite2D], target_count: int, texture: Texture2D, target_alpha: float, min_scale: Vector2, max_scale: Vector2) -> void:
	while instances.size() < target_count:
		instances.append(_create_overlay_instance(texture, min_scale, max_scale))

	while instances.size() > target_count:
		var removed: Sprite2D = instances.pop_back()
		_fade_and_remove_overlay(removed)

	for overlay in instances:
		if overlay == null:
			continue
		overlay.texture = texture
		overlay.visible = true
		overlay.z_index = 4
		var color: Color = overlay.modulate
		color.a = target_alpha
		overlay.modulate = color

func _create_overlay_instance(texture: Texture2D, min_scale: Vector2, max_scale: Vector2) -> Sprite2D:
	var overlay: Sprite2D = Sprite2D.new()
	overlay.texture = texture
	overlay.centered = true
	overlay.position = _random_body_position()
	overlay.rotation = deg_to_rad(overlay_rng.randf_range(-18.0, 18.0))
	var scale_x := overlay_rng.randf_range(min_scale.x, max_scale.x)
	var scale_y := overlay_rng.randf_range(min_scale.y, max_scale.y)
	overlay.scale = Vector2(scale_x, scale_y)
	overlay.modulate = Color(1, 1, 1, 0)
	overlay_container.add_child(overlay)
	return overlay

func _fade_and_remove_overlay(overlay: Sprite2D) -> void:
	if overlay == null:
		return
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 0.18)
	tween.finished.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
	)

func _build_overlay_texture(source: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	return atlas

func _random_body_position() -> Vector2:
	var texture := sprite.texture
	if texture == null:
		return Vector2.ZERO
	var texture_size := texture.get_size()
	var anchor: Vector2 = BODY_ANCHORS[overlay_rng.randi_range(0, BODY_ANCHORS.size() - 1)]
	var x := anchor.x + overlay_rng.randf_range(-BODY_JITTER.x, BODY_JITTER.x)
	var y := anchor.y + overlay_rng.randf_range(-BODY_JITTER.y, BODY_JITTER.y)
	y = min(y, 0.1)
	return Vector2(
		x * texture_size.x,
		y * texture_size.y
	)
