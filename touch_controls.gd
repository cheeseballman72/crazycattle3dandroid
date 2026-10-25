extends CanvasLayer
# On-screen controls. Drives the existing input actions (left/right/forward/back/horn/pause),
# so the original scripts need no changes. Only shown on touch devices while a car is in the scene.

var enabled := false
var in_game := false
var canvas: Control
var buttons := {}      # id -> {action, pos(0-1), r, label}
var touches := {}      # finger index -> button id
var held := {}         # action -> count of fingers holding it

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	enabled = OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()
	if not enabled:
		set_process_input(false)
		return
	buttons = {
		"left":    {"action": "left",    "pos": Vector2(0.09, 0.80), "r": 0.11, "label": "<"},
		"right":   {"action": "right",   "pos": Vector2(0.26, 0.80), "r": 0.11, "label": ">"},
		"forward": {"action": "forward", "pos": Vector2(0.90, 0.62), "r": 0.11, "label": "GO"},
		"back":    {"action": "back",    "pos": Vector2(0.90, 0.85), "r": 0.09, "label": "REV"},
		"horn":    {"action": "horn",    "pos": Vector2(0.74, 0.82), "r": 0.07, "label": "BAA"},
		"pause":   {"action": "pause",   "pos": Vector2(0.95, 0.09), "r": 0.06, "label": "II"},
	}
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_buttons)
	add_child(canvas)
	var t := Timer.new()
	t.wait_time = 0.4
	t.autostart = true
	t.timeout.connect(_check_scene)
	add_child(t)
	canvas.visible = false

func _check_scene() -> void:
	var scene := get_tree().current_scene
	var found := false
	if scene:
		found = scene.find_children("*", "VehicleBody3D", true, false).size() > 0
	if found != in_game:
		in_game = found
		if not in_game:
			_release_all()
	canvas.visible = in_game
	canvas.queue_redraw()

func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _button_at(p: Vector2) -> String:
	var sz := _viewport_size()
	var best := ""
	var best_d := INF
	for id in buttons:
		var b = buttons[id]
		if id == "pause" and get_tree().paused:
			continue
		var c: Vector2 = b["pos"] * sz
		var r: float = b["r"] * sz.y * 1.35
		var d := p.distance_to(c)
		if d <= r and d < best_d:
			best = id
			best_d = d
	return best

func _input(event: InputEvent) -> void:
	if not in_game:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var id := _button_at(event.position)
			if id != "":
				touches[event.index] = id
				_press(id)
		else:
			if touches.has(event.index):
				_release(touches[event.index])
				touches.erase(event.index)
	elif event is InputEventScreenDrag:
		if touches.has(event.index):
			var old: String = touches[event.index]
			var id := _button_at(event.position)
			if id != old and id != "pause" and old != "pause":
				_release(old)
				if id == "":
					touches.erase(event.index)
				else:
					touches[event.index] = id
					_press(id)

func _press(id: String) -> void:
	var a: String = buttons[id]["action"]
	held[a] = held.get(a, 0) + 1
	Input.action_press(a)
	if id == "pause":
		get_tree().create_timer(0.1, true, false, true).timeout.connect(func(): _release("pause"))
	canvas.queue_redraw()

func _release(id: String) -> void:
	var a: String = buttons[id]["action"]
	held[a] = max(held.get(a, 0) - 1, 0)
	if held[a] == 0:
		Input.action_release(a)
	canvas.queue_redraw()

func _release_all() -> void:
	for a in held.keys():
		Input.action_release(a)
	held.clear()
	touches.clear()

func _draw_buttons() -> void:
	var sz := _viewport_size()
	var font := ThemeDB.fallback_font
	for id in buttons:
		if id == "pause" and get_tree().paused:
			continue
		var b = buttons[id]
		var c: Vector2 = b["pos"] * sz
		var r: float = b["r"] * sz.y
		var down: bool = held.get(b["action"], 0) > 0
		canvas.draw_circle(c, r, Color(1, 1, 1, 0.38 if down else 0.18))
		canvas.draw_arc(c, r, 0, TAU, 32, Color(1, 1, 1, 0.6), 2.0)
		var fs := int(r * 0.6)
		var ts := font.get_string_size(b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		canvas.draw_string(font, c + Vector2(-ts.x / 2.0, fs * 0.35), b["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
