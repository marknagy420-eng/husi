extends Control

signal coins_earned(amount: int)
signal quit_requested

const GRAVITY := 0.35
const JUMP_POWER := -12.0
const PLATFORM_WIDTH := 70.0
const PLATFORM_HEIGHT := 12.0
const BROKEN_GAP := 6.0
const PLATFORM_GAP_Y := 70.0
const MIN_PLATFORM_COUNT := 11
const LEVEL_JUMP_STEP := 10
const PLATFORM_EDGE_MARGIN := 30.0
const PLATFORM_X_STEP := 95.0
const COIN_CHANCE := 0.45
const VIRTUAL_COIN_STEP := 15
const VIRTUAL_COIN_REWARD := 15
const JET_PLATFORM_CHANCE := 0.08
const BROKEN_PLATFORM_CHANCE := 0.16
const PLAYER_SIZE := 50.0

@onready var background: TextureRect = %Background
@onready var hud_label: Label = %HudLabel
@onready var notice_label: Label = %NoticeLabel
@onready var game_over_panel: PanelContainer = %GameOverPanel
@onready var jump_sound: AudioStreamPlayer = $JumpSound
@onready var coin_sound: AudioStreamPlayer = $CoinSound
@onready var level_sound: AudioStreamPlayer = $LevelSound

var player_texture: Texture2D
var coin_texture: Texture2D = preload("res://assets/items/coin.svg")

var player := {
	"x": 200.0,
	"y": 200.0,
	"vy": 0.0
}
var platforms: Array = []
var floating_coins: Array = []
var floating_jets: Array = []
var falling_pieces: Array = []
var next_platform_id := 0
var jump_count := 0
var run_score := 0
var level := 1
var last_landed_platform_id := -1
var is_running := false
var is_paused := false
var pointer_control_active := false
var pointer_start_x := 0.0
var pointer_start_player_x := 0.0
var last_background_path := "res://ezkellneked.jpg"
var last_player_texture_path := "res://karakter.png"

func _ready() -> void:
	set_process(false)
	%BackButton.pressed.connect(_on_back_button_pressed)
	%RestartButton.pressed.connect(_on_restart_button_pressed)
	%PauseButton.pressed.connect(_on_pause_button_pressed)
	game_over_panel.visible = false
	notice_label.visible = false
	%BackButton.visible = false

func start_game(_click_reward: int, background_path: String = "res://ezkellneked.jpg", pet_texture_path: String = "res://karakter.png") -> void:
	last_background_path = background_path
	last_player_texture_path = pet_texture_path
	background.texture = load(background_path)
	player_texture = load(pet_texture_path)
	%PauseButton.text = "Pause"
	%BackButton.visible = false
	game_over_panel.visible = false
	notice_label.visible = false
	is_running = true
	is_paused = false
	var game_size := _get_game_size()
	jump_count = 0
	run_score = 0
	level = 1
	last_landed_platform_id = -1
	next_platform_id = 0
	player = {
		"x": game_size.x / 2.0 - PLAYER_SIZE / 2.0,
		"y": game_size.y - 320.0,
		"vy": 0.0
	}
	_create_platforms()
	_update_hud()
	set_process(true)
	queue_redraw()

func _process(_delta: float) -> void:
	if not is_running or is_paused:
		return

	if Input.is_action_pressed("ui_left"):
		player["x"] = float(player["x"]) - 7.0
	if Input.is_action_pressed("ui_right"):
		player["x"] = float(player["x"]) + 7.0
	_clamp_player_x()

	player["vy"] = float(player["vy"]) + GRAVITY
	player["y"] = float(player["y"]) + float(player["vy"])

	var game_size := _get_game_size()
	if float(player["y"]) < game_size.y * 0.3:
		var diff := game_size.y * 0.3 - float(player["y"])
		player["y"] = game_size.y * 0.3
		for platform in platforms:
			platform["y"] = float(platform["y"]) + diff
		for piece in falling_pieces:
			piece["y"] = float(piece["y"]) + diff

	_update_collisions()
	_update_falling_pieces()
	_update_collectables()
	_recycle_platforms()

	if float(player["y"]) > game_size.y:
		_game_over()

	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not is_running or is_paused:
		return

	if event is InputEventScreenTouch:
		pointer_control_active = event.pressed
		pointer_start_x = event.position.x
		pointer_start_player_x = float(player["x"])
		accept_event()
	elif event is InputEventScreenDrag and pointer_control_active:
		player["x"] = pointer_start_player_x + event.position.x - pointer_start_x
		_clamp_player_x()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer_control_active = event.pressed
		pointer_start_x = event.position.x
		pointer_start_player_x = float(player["x"])
		accept_event()
	elif event is InputEventMouseMotion and pointer_control_active:
		player["x"] = pointer_start_player_x + event.position.x - pointer_start_x
		_clamp_player_x()
		accept_event()

func _draw() -> void:
	for platform in platforms:
		if not bool(platform.get("falling", false)):
			_draw_platform(platform)

	for piece in falling_pieces:
		_draw_falling_piece(piece)

	for coin in floating_coins:
		if not bool(coin["collected"]):
			_draw_coin(coin)

	for jet in floating_jets:
		if not bool(jet["collected"]):
			_draw_jet(jet)

	if player_texture != null:
		draw_texture_rect(player_texture, Rect2(Vector2(float(player["x"]), float(player["y"])), Vector2(PLAYER_SIZE, PLAYER_SIZE)), false)
	else:
		draw_rect(Rect2(float(player["x"]), float(player["y"]), PLAYER_SIZE, PLAYER_SIZE), Color(1.0, 0.55, 0.1))

func _create_platforms() -> void:
	platforms.clear()
	floating_coins.clear()
	floating_jets.clear()
	falling_pieces.clear()

	var game_size := _get_game_size()
	var platform_width := _get_platform_width()
	var start_y := game_size.y - 80.0
	var previous_x := game_size.x / 2.0 - platform_width / 2.0
	var first_platform: Dictionary = _make_platform(previous_x, start_y, false)
	platforms.append(first_platform)
	_spawn_coin_for_platform(first_platform, true)

	for i in range(1, _get_platform_count()):
		previous_x = _get_reachable_platform_x(previous_x)
		var platform: Dictionary = _make_platform(previous_x, start_y - i * PLATFORM_GAP_Y, randf() < BROKEN_PLATFORM_CHANCE)
		platform["jet"] = _should_platform_have_jet(platform, i)
		platforms.append(platform)
		_spawn_coin_for_platform(platform)
		_spawn_jet_for_platform(platform, i)

	_fill_platforms_to_top()

func _make_platform(x: float, y: float, broken: bool) -> Dictionary:
	var platform := {
		"id": next_platform_id,
		"x": x,
		"y": y,
		"w": _get_platform_width(),
		"broken": broken,
		"jet": false,
		"falling": false
	}
	next_platform_id += 1
	return platform

func _update_collisions() -> void:
	for platform in platforms:
		if bool(platform.get("falling", false)):
			continue

		var player_bottom := float(player["y"]) + PLAYER_SIZE
		var hit_x := float(player["x"]) + PLAYER_SIZE > float(platform["x"]) and float(player["x"]) < float(platform["x"]) + float(platform["w"])
		var hit_y := player_bottom >= float(platform["y"]) and player_bottom <= float(platform["y"]) + 15.0

		if float(player["vy"]) > 0.0 and hit_x and hit_y:
			if bool(platform["broken"]):
				_trigger_broken_platform_fall(platform)
				continue

			player["y"] = float(platform["y"]) - PLAYER_SIZE
			player["vy"] = JUMP_POWER
			_score_landing(int(platform["id"]))

func _score_landing(platform_id: int) -> void:
	if last_landed_platform_id == platform_id:
		return

	last_landed_platform_id = platform_id
	jump_count += 1
	_add_run_coins(1)

	if jump_count % VIRTUAL_COIN_STEP == 0:
		_add_run_coins(VIRTUAL_COIN_REWARD)
		_show_notice("+%d virtual coins" % VIRTUAL_COIN_REWARD)

	var previous_level := level
	level = int(floor(float(jump_count) / float(LEVEL_JUMP_STEP))) + 1
	if level > previous_level:
		level_sound.play()
		_show_notice("LEVEL %d!" % level)

	jump_sound.play()
	_update_hud()

func _update_collectables() -> void:
	for coin in floating_coins:
		if bool(coin["collected"]):
			continue
		var platform: Dictionary = _find_platform(int(coin["platform_id"]))
		if platform.is_empty() or bool(platform.get("falling", false)):
			continue
		coin["x"] = float(platform["x"]) + float(platform["w"]) / 2.0
		coin["y"] = float(platform["y"]) - 20.0
		coin["bob"] = float(coin["bob"]) + 0.08
		var draw_y := float(coin["y"]) + sin(float(coin["bob"])) * 4.0
		var hit_x := float(player["x"]) + PLAYER_SIZE > float(coin["x"]) - 12.0 and float(player["x"]) < float(coin["x"]) + 12.0
		var hit_y := float(player["y"]) + PLAYER_SIZE > draw_y - 24.0 and float(player["y"]) < draw_y + 8.0
		if hit_x and hit_y:
			coin["collected"] = true
			_add_run_coins(int(coin["reward"]))
			coin_sound.play()
			_update_hud()

	for jet in floating_jets:
		if bool(jet["collected"]):
			continue
		var platform: Dictionary = _find_platform(int(jet["platform_id"]))
		if platform.is_empty() or bool(platform.get("falling", false)):
			continue
		jet["x"] = float(platform["x"]) + float(platform["w"]) / 2.0
		jet["y"] = float(platform["y"]) - 24.0
		jet["bob"] = float(jet["bob"]) + 0.12
		var draw_y := float(jet["y"]) + sin(float(jet["bob"])) * 4.0
		var hit_x := float(player["x"]) + PLAYER_SIZE > float(jet["x"]) - 14.0 and float(player["x"]) < float(jet["x"]) + 14.0
		var hit_y := float(player["y"]) + PLAYER_SIZE > draw_y - 26.0 and float(player["y"]) < draw_y + 10.0
		if hit_x and hit_y:
			jet["collected"] = true
			player["vy"] = min(float(player["vy"]), JUMP_POWER * 2.05)
			jump_sound.play()
			_show_notice("JET BOOST!")

func _add_run_coins(amount: int) -> void:
	run_score += amount
	coins_earned.emit(amount)

func _recycle_platforms() -> void:
	var game_size := _get_game_size()
	for platform in platforms:
		if float(platform["y"]) <= game_size.y + 20.0:
			continue

		var current_top_y := _get_top_platform_y()
		var top_platform: Dictionary = _get_top_platform()
		var old_id := int(platform["id"])
		platform["id"] = next_platform_id
		next_platform_id += 1
		platform["y"] = current_top_y - PLATFORM_GAP_Y
		platform["x"] = _get_reachable_platform_x(float(top_platform["x"]))
		platform["w"] = _get_platform_width()
		platform["broken"] = randf() < BROKEN_PLATFORM_CHANCE
		platform["jet"] = _should_platform_have_jet(platform, next_platform_id)
		platform["falling"] = false

		floating_coins = floating_coins.filter(func(coin: Dictionary) -> bool: return int(coin["platform_id"]) != old_id)
		floating_jets = floating_jets.filter(func(jet: Dictionary) -> bool: return int(jet["platform_id"]) != old_id)
		_spawn_coin_for_platform(platform)
		_spawn_jet_for_platform(platform, next_platform_id)

	_fill_platforms_to_top()

func _fill_platforms_to_top() -> void:
	while _get_top_platform_y() > -PLATFORM_GAP_Y:
		var top_platform: Dictionary = _get_top_platform()
		var platform: Dictionary = _make_platform(
			_get_reachable_platform_x(float(top_platform["x"])),
			float(top_platform["y"]) - PLATFORM_GAP_Y,
			randf() < BROKEN_PLATFORM_CHANCE
		)
		platform["jet"] = _should_platform_have_jet(platform, next_platform_id)
		platforms.append(platform)
		_spawn_coin_for_platform(platform)
		_spawn_jet_for_platform(platform, next_platform_id)

func _trigger_broken_platform_fall(platform: Dictionary) -> void:
	if bool(platform.get("falling", false)):
		return

	platform["falling"] = true
	var piece_width := (float(platform["w"]) - BROKEN_GAP) / 2.0
	falling_pieces.append({
		"x": float(platform["x"]),
		"y": float(platform["y"]),
		"w": piece_width,
		"h": PLATFORM_HEIGHT,
		"vy": 1.4,
		"drift": -0.55,
		"rotation": 0.0,
		"spin": -0.035
	})
	falling_pieces.append({
		"x": float(platform["x"]) + piece_width + BROKEN_GAP,
		"y": float(platform["y"]),
		"w": piece_width,
		"h": PLATFORM_HEIGHT,
		"vy": 1.4,
		"drift": 0.55,
		"rotation": 0.0,
		"spin": 0.035
	})

func _update_falling_pieces() -> void:
	var game_size := _get_game_size()
	for piece in falling_pieces:
		piece["vy"] = float(piece["vy"]) + 0.28
		piece["y"] = float(piece["y"]) + float(piece["vy"])
		piece["x"] = float(piece["x"]) + float(piece["drift"])
		piece["rotation"] = float(piece["rotation"]) + float(piece["spin"])
	falling_pieces = falling_pieces.filter(func(piece: Dictionary) -> bool: return float(piece["y"]) < game_size.y + 60.0)

func _spawn_coin_for_platform(platform: Dictionary, force: bool = false) -> void:
	if bool(platform["broken"]) or bool(platform["jet"]):
		return
	if not force and randf() > COIN_CHANCE:
		return
	var is_gold := randf() < 0.32
	floating_coins.append({
		"platform_id": int(platform["id"]),
		"x": float(platform["x"]) + float(platform["w"]) / 2.0,
		"y": float(platform["y"]) - 18.0,
		"reward": 20 if is_gold else 10,
		"gold": is_gold,
		"collected": false,
		"bob": randf() * TAU
	})

func _spawn_jet_for_platform(platform: Dictionary, index: int = 0) -> void:
	if bool(platform["broken"]) or not bool(platform["jet"]):
		return
	if index % 8 != 0 and randf() > JET_PLATFORM_CHANCE:
		platform["jet"] = false
		return
	floating_jets.append({
		"platform_id": int(platform["id"]),
		"x": float(platform["x"]) + float(platform["w"]) / 2.0,
		"y": float(platform["y"]) - 22.0,
		"collected": false,
		"bob": randf() * TAU
	})

func _should_platform_have_jet(platform: Dictionary, index: int = 0) -> bool:
	if bool(platform["broken"]):
		return false
	if index > 0 and index % 12 == 0:
		return true
	return randf() < JET_PLATFORM_CHANCE

func _get_reachable_platform_x(previous_x: float) -> float:
	var game_size := _get_game_size()
	var platform_width := _get_platform_width()
	var min_x := PLATFORM_EDGE_MARGIN
	var max_x := game_size.x - platform_width - PLATFORM_EDGE_MARGIN
	var horizontal_step := _get_platform_x_step()
	var directional_x := previous_x + (horizontal_step if randf() > 0.5 else -horizontal_step)
	if directional_x < min_x:
		return min(previous_x + horizontal_step, max_x)
	if directional_x > max_x:
		return max(previous_x - horizontal_step, min_x)
	return directional_x

func _get_platform_x_step() -> float:
	return clampf(_get_game_size().x * 0.28, PLATFORM_X_STEP, 170.0)

func _get_platform_width() -> float:
	return clampf(_get_game_size().x * 0.21, PLATFORM_WIDTH, 118.0)

func _get_platform_count() -> int:
	return max(MIN_PLATFORM_COUNT, int(ceil(_get_game_size().y / PLATFORM_GAP_Y)) + 4)

func _find_platform(platform_id: int) -> Dictionary:
	for platform in platforms:
		if int(platform["id"]) == platform_id:
			return platform
	return {}

func _get_top_platform_y() -> float:
	var top_y := _get_game_size().y
	for platform in platforms:
		top_y = min(top_y, float(platform["y"]))
	return top_y

func _get_top_platform() -> Dictionary:
	var top_platform: Dictionary = platforms[0]
	for platform in platforms:
		if float(platform["y"]) < float(top_platform["y"]):
			top_platform = platform
	return top_platform

func _draw_platform(platform: Dictionary) -> void:
	var x := float(platform["x"])
	var y := float(platform["y"])
	var w := float(platform["w"])
	if bool(platform["broken"]):
		var piece_width := (w - BROKEN_GAP) / 2.0
		_draw_platform_piece(Rect2(x, y, piece_width, PLATFORM_HEIGHT), true)
		_draw_platform_piece(Rect2(x + piece_width + BROKEN_GAP, y, piece_width, PLATFORM_HEIGHT), true)
	else:
		_draw_platform_piece(Rect2(x, y, w, PLATFORM_HEIGHT), false)

func _draw_platform_piece(rect: Rect2, broken: bool) -> void:
	draw_rect(rect, Color.html("#5f4f45") if broken else Color.html("#8b5a2b"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), Color.html("#159447") if not broken else Color.html("#3b312b"))
	draw_rect(rect, Color.html("#2c2622"), false, 2.0)

func _draw_falling_piece(piece: Dictionary) -> void:
	var center := Vector2(float(piece["x"]) + float(piece["w"]) / 2.0, float(piece["y"]) + float(piece["h"]) / 2.0)
	draw_set_transform(center, float(piece["rotation"]), Vector2.ONE)
	_draw_platform_piece(Rect2(Vector2(-float(piece["w"]) / 2.0, -float(piece["h"]) / 2.0), Vector2(float(piece["w"]), float(piece["h"]))), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_coin(coin: Dictionary) -> void:
	var draw_y := float(coin["y"]) + sin(float(coin["bob"])) * 4.0
	var rect := Rect2(Vector2(float(coin["x"]) - 11.0, draw_y - 22.0), Vector2(22.0, 22.0))
	if coin_texture != null:
		draw_texture_rect(coin_texture, rect, false, Color.html("#ffd84d") if bool(coin["gold"]) else Color.html("#ff5a5a"))
	else:
		draw_circle(rect.get_center(), 10.0, Color.html("#ffd84d") if bool(coin["gold"]) else Color.html("#ff5a5a"))

func _draw_jet(jet: Dictionary) -> void:
	var draw_y := float(jet["y"]) + sin(float(jet["bob"])) * 4.0
	var center := Vector2(float(jet["x"]), draw_y - 8.0)
	draw_rect(Rect2(center + Vector2(-6, -18), Vector2(12, 32)), Color.html("#f9d423"))
	draw_rect(Rect2(center + Vector2(-9, -13), Vector2(18, 22)), Color.html("#2c2622"), false, 2.0)
	draw_polygon([center + Vector2(-7, 14), center + Vector2(0, 25), center + Vector2(7, 14)], [Color.html("#ff5a1f")])

func _clamp_player_x() -> void:
	player["x"] = clampf(float(player["x"]), 0.0, max(0.0, _get_game_size().x - PLAYER_SIZE))

func _get_game_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	return get_viewport_rect().size

func _update_hud() -> void:
	hud_label.text = "Level %d - Score: %d" % [level, run_score]

func _show_notice(message: String) -> void:
	notice_label.text = message
	notice_label.visible = true
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_callback(func() -> void: notice_label.visible = false)

func _game_over() -> void:
	is_running = false
	set_process(false)
	game_over_panel.visible = true
	%BackButton.visible = true
	notice_label.visible = false

func _on_restart_button_pressed() -> void:
	start_game(1, last_background_path, last_player_texture_path)

func _on_pause_button_pressed() -> void:
	if not is_running:
		return
	is_paused = not is_paused
	%PauseButton.text = "Resume" if is_paused else "Pause"
	%BackButton.visible = is_paused
	notice_label.text = "PAUSE"
	notice_label.visible = is_paused

func _on_back_button_pressed() -> void:
	is_running = false
	set_process(false)
	quit_requested.emit()
