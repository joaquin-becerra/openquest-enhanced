extends Node2D
## Animated characters on the title screen: Zif talks on the phone and Zob
## uses the detector. They take the frames from the characters' scenes (so
## hd_graphics.gd swaps them for the HD ones as in the rest of the game).

const ZIF_SCENE := "res://characters/commander_zif/commander_zif.tscn"
const ZOB_SCENE := "res://characters/ensign_zob/ensign_zob.tscn"
## Feet position (the same as in the original title image).
const ZIF_POS := Vector2(888, 208)
const ZOB_POS := Vector2(1028, 208)

var _zif: AnimatedSprite2D
var _zob: AnimatedSprite2D


func _ready() -> void:
	_zif = _make_sprite(ZIF_SCENE, ZIF_POS, &"stand_with_phone_down")
	_zob = _make_sprite(ZOB_SCENE, ZOB_POS, &"idle_down")
	_zif_loop()
	_zob_loop()
	set_process_input(false)
	await get_tree().process_frame
	set_process_input(true)


## The loading indicator must show as soon as the player clicks: Escoria handles
## the click in the same frame and starts loading before anything is drawn.
## So the click is held, the indicator is drawn and only then is it
## handed back to Escoria. It listens one frame after _ready, so it doesn't
## catch the menu click that led here. With the pause menu open the tree
## is paused and this node doesn't get the click.
enum { LISTENING, WAITING, PASSING }
var _state := LISTENING


func _input(event: InputEvent) -> void:
	if _state == PASSING or not event is InputEventMouseButton:
		return
	if _state == WAITING:
		get_viewport().set_input_as_handled()  # the real click's release
		return
	if not (event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	get_viewport().set_input_as_handled()
	_state = WAITING
	LoadingSpinner.start()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_state = PASSING
	Input.parse_input_event(event)
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)


## Copies the character's AnimatedSprite2D (frames, offset) without adding the
## character to the scene (we don't want a second ESCItem with the same id).
func _make_sprite(scene_path: String, pos: Vector2, anim: StringName) -> AnimatedSprite2D:
	var actor: Node = load(scene_path).instantiate()
	var src: AnimatedSprite2D = actor.get_node("sprite")
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = src.sprite_frames
	sprite.centered = src.centered
	sprite.offset = src.offset
	sprite.position = pos
	actor.free()
	add_child(sprite)
	sprite.play(anim)
	return sprite


## Child Timer (not the tree's): if the screen is left and the node is freed,
## the coroutines wait forever instead of waking up without a node.
func _wait(min_s: float, max_s: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(randf_range(min_s, max_s))
	await timer.timeout
	timer.queue_free()


## Zif: short phrases on the phone with pauses between them.
func _zif_loop() -> void:
	while true:
		_zif.play(&"talk_to_phone_start_down")
		await _wait(1.2, 3.0)
		_zif.play(&"stand_with_phone_down")
		await _wait(0.6, 1.8)


## Zob: sweeps the detector a couple of times and rests.
func _zob_loop() -> void:
	await _wait(0.5, 1.5)
	while true:
		for i in randi_range(1, 3):
			_zob.play(&"scan_down")
			await _zob.animation_finished
			await _wait(0.2, 0.6)
		_zob.play(&"idle_down")
		await _wait(1.5, 3.5)
