extends SceneTree

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame


func mouse(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(500, 500)
	Input.parse_input_event(event)


func run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await frames(3)
	var boat = world.get_node("Boat")
	var hook = boat.get_node("Hook")
	var hud = world.get_node("HUD")
	var spot = world.get_node("FishingSpot")
	spot.set_process(false)
	var fish = spot.get_child(1)
	for child in spot.get_children():
		if child.has_method("hook_to"):
			child.set_physics_process(false)
			child.position = Vector2(2000, 500)

	var boat_start: Vector2 = boat.position
	boat.position.x = -100.0
	await frames(4)
	check(world.boat_in_dock_area, "Harbor detects boat entry")
	boat.position = boat_start
	await frames(4)
	check(not world.boat_in_dock_area, "Harbor clears proximity on exit")
	Input.action_press("move_right")
	await frames(4)
	Input.action_release("move_right")
	check(boat.position.x > boat_start.x and boat.position.y == boat_start.y, "A/D horizontal movement")
	boat.position = boat_start
	mouse(MOUSE_BUTTON_RIGHT, true)
	await frames(2)
	mouse(MOUSE_BUTTON_RIGHT, false)
	check(hook.deployed and hook.position.y > hook.start_position.y, "Right click deploys and automatically sinks")
	check(not boat.can_move, "Boat locked while line is deployed")
	check(is_equal_approx(hook.position.x, hook.start_position.x), "Line stays vertical")
	mouse(MOUSE_BUTTON_LEFT, true)
	await frames(15)
	mouse(MOUSE_BUTTON_LEFT, false)
	check(not hook.deployed and boat.can_move, "Mouse reels empty hook and unlocks boat")

	hook.deploy()
	hook.position.y = hook.start_position.y + hook.max_depth - 1.0
	await frames(4)
	check(is_equal_approx(hook.position.y, hook.start_position.y + hook.max_depth), "Maximum depth is clamped")
	hook.update_camera(1.0)
	check(hook.position.y - boat.get_node("Camera2D").position.y < 280.0, "Camera keeps deepest hook above control hints")
	hook.position.y = hook.start_position.y + 220.0
	fish.global_position = hook.global_position
	await frames(4)
	check(hook.hooked_fish == fish and fish.is_hooked, "Real Area2D overlap hooks fish")
	check(hud.fight_active, "Hooking starts existing fight")
	var depth: float = hook.position.y
	mouse(MOUSE_BUTTON_LEFT, true)
	await frames(4)
	check(is_equal_approx(hook.position.y, depth), "Fish must be subdued before lifting")
	hud.set_process(false)
	hud.fish_marker.position.x = hud.catch_zone.position.x
	hud.update_fight_progress(4.0)
	check(hud.is_fight_won(), "Reeling with fish inside catch zone wins fight")
	await frames(100)
	mouse(MOUSE_BUTTON_LEFT, false)
	check(hud.get_total_fish() == 1, "Landed fish enters inventory exactly once")
	check(not hook.deployed and hook.hooked_fish == null and boat.can_move, "Landing resets fishing state")
	hud.set_process(true)

	for i in range(7):
		hud.add_fish("Sardalya")
	hook.deploy()
	check(not hook.deployed and not hud.can_add_fish(), "Full inventory prevents another drop")
	world._on_sell_button_pressed()
	check(hud.get_total_fish() == 0 and world.money == 80, "Selling preserves species prices and clears inventory")
	world.docked = true
	hook.deploy()
	check(not hook.deployed, "Cannot fish while docked")
	world._on_leave_button_pressed()
	check(boat.can_move, "Leaving harbor restores movement")

	# Spawns must record their actual world position as the patrol centre.
	spot.spawn_one_fish()
	var spawned = spot.get_child(spot.get_child_count() - 1)
	check(is_equal_approx(spawned.start_x, spawned.global_position.x), "Respawn patrol centre matches spawn position")
	world.queue_free()
	await frames(2)
	print("Fishing loop failures: ", failures)
	quit(1 if failures else 0)
