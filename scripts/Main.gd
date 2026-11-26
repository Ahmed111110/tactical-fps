extends Node3D

var player_body: CharacterBody3D
var camera: Camera3D
var rpg_viewmodel: Node3D
var vehicle_body: CharacterBody3D
var vehicle_hp: int = 100
var vehicle_dir: float = 1.0

var weapon_mode: int = 0 # 0 = RPG, 1 = Shuwaz, 2 = Mortar
var weapon_names := ["RPG", "شواظ (SHUWAZ)", "هاون (MORTAR)"]
var ammo_rpg: int = 3
var ammo_shuwaz: int = 3
var ammo_mortar: int = 3
var cooldown: float = 0.0

var move_forward: float = 0.0
var move_right: float = 0.0
var status_label: Label
var weapon_btn: Button
var ammo_label: Label

func _ready() -> void:
	_setup_environment()
	_build_arena()
	_build_player()
	_build_vehicle()
	_build_mobile_ui()
	_update_hud()

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.52, 0.60)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.82)
	env.ambient_light_energy = 0.8

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	sun.light_energy = 1.3
	add_child(sun)

func _create_box(size: Vector3, pos: Vector3, color: Color, with_body: bool = true, static_body: bool = true) -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat

	if not with_body:
		mesh_instance.position = pos
		return mesh_instance

	var body: PhysicsBody3D
	if static_body:
		body = StaticBody3D.new()
	else:
		body = CharacterBody3D.new()
	body.position = pos
	body.add_child(mesh_instance)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body

func _build_arena() -> void:
	# Ground
	var ground := _create_box(Vector3(120.0, 1.0, 140.0), Vector3(0.0, -0.5, 0.0), Color(0.58, 0.52, 0.40), true, true)
	add_child(ground)

	# Road path for vehicles
	var road := _create_box(Vector3(10.0, 0.05, 130.0), Vector3(4.0, 0.02, 0.0), Color(0.26, 0.26, 0.28), false, true)
	add_child(road)

	# Cover walls / rubble
	var covers := [
		Vector3(-4.0, 1.0, 18.0),
		Vector3(0.0, 1.0, 12.0),
		Vector3(-6.0, 1.2, 4.0),
		Vector3(9.5, 1.1, -6.0)
	]
	for p in covers:
		var wall := _create_box(Vector3(3.2, 2.0, 1.1), p, Color(0.45, 0.43, 0.40), true, true)
		add_child(wall)

func _build_player() -> void:
	player_body = CharacterBody3D.new()
	player_body.position = Vector3(-2.0, 1.8, 24.0)
	add_child(player_body)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.7
	col.shape = cap
	player_body.add_child(col)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 0.7, 0.0)
	camera.fov = 75.0
	player_body.add_child(camera)

	# Simple RPG tube model in first-person view
	rpg_viewmodel = Node3D.new()
	rpg_viewmodel.position = Vector3(0.32, -0.28, -0.55)
	rpg_viewmodel.rotation_degrees = Vector3(4.0, -6.0, 0.0)
	camera.add_child(rpg_viewmodel)

	var tube := _create_box(Vector3(0.11, 0.11, 1.15), Vector3(0.0, 0.0, 0.0), Color(0.22, 0.28, 0.20), false, true)
	rpg_viewmodel.add_child(tube)

	var warhead := _create_box(Vector3(0.14, 0.14, 0.28), Vector3(0.0, 0.0, -0.68), Color(0.35, 0.24, 0.16), false, true)
	rpg_viewmodel.add_child(warhead)

func _build_vehicle() -> void:
	vehicle_body = _create_box(Vector3(3.2, 2.0, 5.4), Vector3(4.0, 1.0, -10.0), Color(0.30, 0.35, 0.24), true, false) as CharacterBody3D
	vehicle_body.set_meta("is_vehicle", true)
	add_child(vehicle_body)

	var turret := _create_box(Vector3(2.0, 0.9, 2.2), Vector3(0.0, 1.35, 0.2), Color(0.25, 0.30, 0.20), false, true)
	vehicle_body.add_child(turret)

	var barrel := _create_box(Vector3(0.22, 0.22, 2.6), Vector3(0.0, 1.35, -1.6), Color(0.16, 0.18, 0.16), false, true)
	vehicle_body.add_child(barrel)

func _build_mobile_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	# Crosshair center
	var crosshair := Label.new()
	crosshair.text = "[ + ]"
	crosshair.add_theme_font_size_override("font_size", 26)
	crosshair.position = Vector2(335, 540)
	canvas.add_child(crosshair)

	# Top HUD status
	status_label = Label.new()
	status_label.position = Vector2(24, 40)
	status_label.add_theme_font_size_override("font_size", 24)
	canvas.add_child(status_label)

	ammo_label = Label.new()
	ammo_label.position = Vector2(24, 82)
	ammo_label.add_theme_font_size_override("font_size", 22)
	canvas.add_child(ammo_label)

	# Bottom-left movement buttons (Portrait friendly)
	var btn_fwd := _make_btn("تقدم", Vector2(40, 960), Vector2(130, 85))
	btn_fwd.button_down.connect(func(): move_forward = 1.0)
	btn_fwd.button_up.connect(func(): move_forward = 0.0)
	canvas.add_child(btn_fwd)

	var btn_back := _make_btn("تراجع", Vector2(40, 1060), Vector2(130, 85))
	btn_back.button_down.connect(func(): move_forward = -1.0)
	btn_back.button_up.connect(func(): move_forward = 0.0)
	canvas.add_child(btn_back)

	var btn_left := _make_btn("يسار", Vector2(180, 1010), Vector2(115, 85))
	btn_left.button_down.connect(func(): move_right = -1.0)
	btn_left.button_up.connect(func(): move_right = 0.0)
	canvas.add_child(btn_left)

	var btn_right := _make_btn("يمين", Vector2(305, 1010), Vector2(115, 85))
	btn_right.button_down.connect(func(): move_right = 1.0)
	btn_right.button_up.connect(func(): move_right = 0.0)
	canvas.add_child(btn_right)

	# Bottom-right action buttons
	weapon_btn = _make_btn("سلاح: RPG", Vector2(450, 860), Vector2(230, 80))
	weapon_btn.pressed.connect(_cycle_weapon)
	canvas.add_child(weapon_btn)

	var btn_reload := _make_btn("إعادة تلقيم", Vector2(450, 955), Vector2(230, 75))
	btn_reload.pressed.connect(_reload_current)
	canvas.add_child(btn_reload)

	var btn_fire := _make_btn("إطلاق / تفعيل", Vector2(450, 1045), Vector2(230, 115))
	btn_fire.pressed.connect(_fire_current)
	canvas.add_child(btn_fire)

func _make_btn(text_val: String, pos: Vector2, size_val: Vector2) -> Button:
	var b := Button.new()
	b.text = text_val
	b.position = pos
	b.size = size_val
	b.add_theme_font_size_override("font_size", 22)
	return b

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		# Look around when dragging upper/middle screen
		if event.position.y < 840.0:
			player_body.rotate_y(-event.relative.x * 0.004)
			camera.rotate_x(-event.relative.y * 0.0035)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-65.0), deg_to_rad(65.0))

func _physics_process(delta: float) -> void:
	if cooldown > 0.0:
		cooldown -= delta

	# Player movement
	var forward_vec := -player_body.global_transform.basis.z
	forward_vec.y = 0.0
	forward_vec = forward_vec.normalized()

	var right_vec := player_body.global_transform.basis.x
	right_vec.y = 0.0
	right_vec = right_vec.normalized()

	var wish_dir := (forward_vec * move_forward + right_vec * move_right)
	if wish_dir.length() > 1.0:
		wish_dir = wish_dir.normalized()

	player_body.velocity.x = wish_dir.x * 6.5
	player_body.velocity.z = wish_dir.z * 6.5
	if not player_body.is_on_floor():
		player_body.velocity.y -= 9.8 * delta
	player_body.move_and_slide()

	# Vehicle patrol movement along road
	if vehicle_body != null and vehicle_hp > 0:
		vehicle_body.velocity.x = 0.0
		vehicle_body.velocity.z = vehicle_dir * 4.2
		vehicle_body.move_and_slide()
		if vehicle_body.position.z > 14.0:
			vehicle_dir = -1.0
		elif vehicle_body.position.z < -26.0:
			vehicle_dir = 1.0

	_update_hud()

func _cycle_weapon() -> void:
	weapon_mode = (weapon_mode + 1) % 3
	rpg_viewmodel.visible = (weapon_mode == 0)
	_update_hud()

func _reload_current() -> void:
	if weapon_mode == 0:
		ammo_rpg = 3
	elif weapon_mode == 1:
		ammo_shuwaz = 3
	else:
		ammo_mortar = 3
	_update_hud()

func _fire_current() -> void:
	if cooldown > 0.0:
		return

	if weapon_mode == 0 and ammo_rpg > 0:
		ammo_rpg -= 1
		cooldown = 1.0
		_spawn_rpg_rocket()
	elif weapon_mode == 1 and ammo_shuwaz > 0:
		ammo_shuwaz -= 1
		cooldown = 0.7
		_place_shuwaz_charge()
	elif weapon_mode == 2 and ammo_mortar > 0:
		ammo_mortar -= 1
		cooldown = 1.2
		_fire_mortar_shell()

	_update_hud()

func _spawn_rpg_rocket() -> void:
	var origin := camera.global_position + (-camera.global_transform.basis.z * 1.2)
	var dir := (-camera.global_transform.basis.z).normalized()
	_raycast_or_projectile_hit(origin, dir * 55.0, 50, "RPG")

func _place_shuwaz_charge() -> void:
	var pos := player_body.global_position + (-player_body.global_transform.basis.z * 3.0)
	pos.y = 0.4
	var charge := _create_box(Vector3(0.4, 0.4, 0.4), pos, Color(0.85, 0.25, 0.15), false, true)
	add_child(charge)
	_check_blast_at(pos, 7.5, 65, "شواظ")

func _fire_mortar_shell() -> void:
	var target := camera.global_position + (-camera.global_transform.basis.z * 26.0)
	target.y = 0.2
	_check_blast_at(target, 9.0, 55, "هاون")

func _raycast_or_projectile_hit(start_pos: Vector3, vel: Vector3, dmg: int, label: String) -> void:
	var space := get_world_3d().direct_space_state
	var end_pos := start_pos + vel.normalized() * 80.0
	var query := PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	var res := space.intersect_ray(query)
	if not res.is_empty():
		var hit_pos: Vector3 = res["position"]
		_spawn_explosion(hit_pos, label)
		_check_blast_at(hit_pos, 6.0, dmg, label)
	else:
		_spawn_explosion(end_pos, label)

func _check_blast_at(center: Vector3, radius: float, dmg: int, source_name: String) -> void:
	_spawn_explosion(center, source_name)
	if vehicle_body != null and vehicle_hp > 0:
		var dist := vehicle_body.global_position.distance_to(center)
		if dist <= radius + 2.5:
			vehicle_hp = max(0, vehicle_hp - dmg)
			if vehicle_hp == 0:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.12, 0.12, 0.12)
				for child in vehicle_body.get_children():
					if child is MeshInstance3D:
						child.material_override = mat

func _spawn_explosion(pos: Vector3, tag: String) -> void:
	var blast := _create_box(Vector3(2.2, 2.2, 2.2), pos, Color(1.0, 0.45, 0.08), false, true)
	add_child(blast)
	status_label.text = "إصابة / تفجير (" + tag + ")"
	var timer := get_tree().create_timer(0.35)
	timer.timeout.connect(func():
		if is_instance_valid(blast):
			blast.queue_free()
	)

func _update_hud() -> void:
	var v_state := "آلية سليمة (%d%%)" % vehicle_hp if vehicle_hp > 0 else "آلية مُعطّلة/مُدمّرة"
	status_label.text = v_state
	weapon_btn.text = "سلاح: " + weapon_names[weapon_mode]
	var cur_ammo := ammo_rpg if weapon_mode == 0 else (ammo_shuwaz if weapon_mode == 1 else ammo_mortar)
	ammo_label.text = "الذخيرة: %d | اسحب للأعلى للنظر" % cur_ammo
