extends Node3D
signal garden_tapped(screen_position: Vector2, camera: Camera3D)
@onready var camera: Camera3D = $Camera3D
var _touches: Dictionary = {}
var _start := Vector2.ZERO
var _dragged := false
var _mouse_down := false
var _pinching := false
const MIN_ZOOM := 10.0
const MAX_ZOOM := 22.0

func _ready() -> void:
	camera.position = Vector3(12, 15, 12)
	camera.look_at(Vector3.ZERO)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = touch.position
			if _touches.size() == 1:
				_start = touch.position
				_dragged = false
				_pinching = false
			else:
				_pinching = true
		elif _touches.has(touch.index):
			_touches.erase(touch.index)
			if _touches.is_empty() and not _dragged and not _pinching:
				garden_tapped.emit(touch.position, camera)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _touches.has(drag.index):
			return
		if _touches.size() == 2:
			var before: Array = _touches.values()
			var old_distance: float = (before[0] as Vector2).distance_to(before[1])
			_touches[drag.index] = drag.position
			var after: Array = _touches.values()
			var new_distance: float = (after[0] as Vector2).distance_to(after[1])
			if new_distance > 2:
				camera.size = clampf(camera.size * old_distance / new_distance, MIN_ZOOM, MAX_ZOOM)
		else:
			_touches[drag.index] = drag.position
			if drag.position.distance_to(_start) > 12:
				_dragged = true
			if _dragged:
				_pan(drag.relative)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_mouse_down = button.pressed
			if button.pressed:
				_start = button.position
				_dragged = false
			elif not _dragged:
				garden_tapped.emit(button.position, camera)
		elif button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			camera.size = clampf(camera.size + (-1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1), MIN_ZOOM, MAX_ZOOM)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _mouse_down:
			if motion.position.distance_to(_start) > 8:
				_dragged = true
			if _dragged:
				_pan(motion.relative)

func _pan(relative: Vector2) -> void:
	var right := camera.global_transform.basis.x
	var forward := Vector3(-right.z, 0, right.x)
	position -= (right * relative.x + forward * relative.y) * camera.size / get_viewport().get_visible_rect().size.y
	position.x = clampf(position.x, -2.5, 2.5)
	position.z = clampf(position.z, -2.5, 2.5)

func reset_view() -> void:
	position = Vector3.ZERO
	camera.size = 20.0
