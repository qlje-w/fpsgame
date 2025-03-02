extends CharacterBody3D

#casings
@export var shell_scene : PackedScene

#spread
var spread = 5

#tracer
@export var tracer = preload("res://tracer/bullettracer.tscn")
@onready var tracer_spawner = $head/Camera3D/weapons/shotgun/tracerspawn
@onready var rcont = $head/Camera3D/weapons/shotgun/rcont

#var
@onready var animations = $head/Camera3D/weapons/shotgun/AnimationPlayer

#camera tilt settings
@export var camera_tilt_intese = 0.03
@export var camera_speed_return = 10

#subcam
@onready var camera = get_node("%Camera3D")
@onready var camerasub = get_node("%subcam")

var pos : Vector3

#movement
@export var jump_velocity = 4.5
@export var sensetivity : float = 0.006
@export var auto_bhop = false

#weapon
@onready var head: Node3D = %head

#click
var ignore_first_click = true

#shoot slowness
var shoot_slow
var initial_walk_speed
var initial_sprint_speed

#aim
@export var speed_aiming = 5
var aiming = false
var base_pos
var dis_aim_pos
@onready var aim_down_sides = $head/Camera3D/weapons/shotgun/Node
var slowness_aim

#weapon sway
var mouse_input_vec : Vector2
@export var weapon_sway_speed = 5
@export var weapon_angle = 0.005

#weapon tilt settings
@export var weapon_tilt_intese = 0.06
@export var weapon_speed_return = 10

#weapon bob setting
@export var weapon_bob_time := 0.0
@export var weapon_bob_frequency = 1.5
@export var weapon_bob_move_amount = 0.0002

#headbob settings
const headbob_move_amount = 0.06
const headbob_frequency = 2.4
var headbob_time := 0.0

#ground movement settings
@export var sprint_speed := 7.5
@export var walk_speed := 6.0
@export var ground_accel := 14.0
@export var ground_decel := 10.0
@export var ground_friction := 5.0

#air movement settings
@export var air_cap := 0.85
@export var air_accel := 800.0
@export var air_move_speed := 500.0

#qte
var wait_for_input = false
var possible_keys = ["q", "e"]
var action_key

var press_dir := Vector3.ZERO

#anim conditions
@onready var anim_tree : AnimationTree = $head/Camera3D/weapons/shotgun/AnimationTree
var is_shooting = false
var is_reloading = false

func _get_move_speed() -> float:
	return sprint_speed if Input.is_action_pressed("sprint") else walk_speed

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * sensetivity)
			%Camera3D.rotate_x(-event.relative.y * sensetivity)
			%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-90), deg_to_rad(90))
			mouse_input_vec = event.relative
	_ignore_first_click()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reload") and not is_reloading and not is_shooting:
		_handle_reload()

	if event.is_action_pressed("rmb"):
		aiming = true
	elif event.is_action_released("rmb"):
		aiming = false

	if event.is_action_pressed("lmb") and ignore_first_click == false and not is_reloading:
		_handle_shooting()
	
	_continue_reload(event)

func _ready() -> void:
	base_pos = $head/Camera3D/weapons/shotgun/Node.position
	dis_aim_pos = base_pos + Vector3(-0.295, 0.135, 0)
	
	initial_walk_speed = walk_speed
	initial_sprint_speed = sprint_speed
	
	for r in rcont.get_children():
		r.target_position = Vector3(
			randf_range(spread, -spread), 
			randf_range(spread, -spread), 
			r.target_position.z
		)
	
func _physics_process(delta: float) -> void:
	# Gets the input direction
	var input_dir = Input.get_vector("left", "right", "up", "down").normalized()
	press_dir = %head.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	
	# Handles the physics
	if is_on_floor():
		if Input.is_action_just_pressed("space") or (auto_bhop == true and Input.is_action_pressed("space")):
			self.velocity.y = jump_velocity
		_handle_ground_physics(delta)
	else:
		_handle_air_physics(delta)
	
	move_and_slide()

	_cam_tilt(input_dir.x, delta)
	
	_weapon_tilt(input_dir.x, delta)
	
	_weapon_sway(delta)
		
	_take_aim(delta)
	
	_slow_shoot()
	
func _handle_air_physics(delta: float) -> void:
	self.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	
	var cur_speed_in_press_dir = self.velocity.dot(press_dir)
	var capped_speed = min((air_move_speed * press_dir).length(), air_cap)
	var add_speed_till_cap = capped_speed - cur_speed_in_press_dir
	if add_speed_till_cap > 0:
		var accel_speed = air_accel * air_move_speed * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * press_dir

func _handle_ground_physics(delta: float) -> void:
	var cur_speed_in_press_dir = self.velocity.dot(press_dir)
	var add_speed_till_cap = _get_move_speed() - cur_speed_in_press_dir
	if add_speed_till_cap > 0:
		var accel_speed = ground_accel * _get_move_speed() * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * press_dir
		
	# friction
	var control = max(self.velocity.length(), ground_decel)
	var drop = control * ground_friction * delta
	var new_speed = max(self.velocity.length() - drop, 0.0)
	if self.velocity.length() > 0:
		new_speed /= self.velocity.length()
	self.velocity *= new_speed
	
	_headbob_effect(delta)
	
	_weapon_bob(delta)

func _headbob_effect(delta) -> void:
	headbob_time += delta * self.velocity.length()
	%Camera3D.transform.origin = Vector3(
		cos(headbob_time * headbob_frequency * 0.5) * headbob_move_amount,
		sin(headbob_time * headbob_frequency) * headbob_move_amount,
		0
	)

func _process(_delta: float):
	camerasub.set_global_transform(camera.get_global_transform())
	print(is_reloading)
	
func _weapon_tilt(press_x, delta) -> void:
	%weapons.rotation.z = lerp(%weapons.rotation.z, -press_x * weapon_tilt_intese, weapon_speed_return * delta)

func _ignore_first_click():
	ignore_first_click = true
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		ignore_first_click = false

func _weapon_sway(delta) -> void:
	if aiming:
		weapon_angle = 0.002
		weapon_sway_speed = 7
	else:
		weapon_angle = 0.005
		weapon_sway_speed = 5
		
	mouse_input_vec = lerp(mouse_input_vec, Vector2.ZERO, 10 * delta)
	
	var target_x = -mouse_input_vec.x * weapon_angle
	var target_y = mouse_input_vec.y * weapon_angle
	
	%weapons.position.x = lerp(%weapons.position.x, target_x, delta * weapon_sway_speed)
	%weapons.position.y = lerp(%weapons.position.y, target_y, delta * weapon_sway_speed)

func _weapon_bob(delta) -> void:
	if aiming:
		weapon_bob_move_amount = 0.00005
	else:
		weapon_bob_move_amount = 0.00025
		
	weapon_bob_time += delta * self.velocity.length()
	%weapons.position.x += cos(weapon_bob_time * weapon_bob_frequency * 0.5) * self.velocity.length() * weapon_bob_move_amount
	%weapons.position.y += sin(weapon_bob_time * weapon_bob_frequency) * self.velocity.length() * weapon_bob_move_amount

func _take_aim(delta):
	var target_pos = base_pos if is_reloading or not aiming else dis_aim_pos
	
	if is_reloading:
		slowness_aim = 0.0
	else:
		if aiming:
			slowness_aim = walk_speed - walk_speed / 1.5
		else:
			slowness_aim = 0.0

	aim_down_sides.position.x = lerp(aim_down_sides.position.x, target_pos.x, delta * speed_aiming)
	aim_down_sides.position.y = lerp(aim_down_sides.position.y, target_pos.y, delta * speed_aiming)
	aim_down_sides.position.z = target_pos.z

func _handle_shooting() -> void:
	if Global.current_number_of_bullets > 0:
		is_shooting = true
		anim_tree["parameters/StateMachine/conditions/is_shoot"] = true
		_appear_tracer()
		
		Global.current_number_of_bullets -= 1
		
	elif Global.current_number_of_bullets < 0.5:
		is_shooting = true
		anim_tree["parameters/StateMachine/conditions/is_shootbl"] = true

func _handle_reload() -> void:
	if Global.current_number_of_bullets < 0.5:
		is_reloading = true
		anim_tree["parameters/StateMachine/conditions/is_reloading"] = true
	
	elif Global.current_number_of_bullets < Global.number_of_bullets:
		is_reloading = true
		anim_tree["parameters/StateMachine/conditions/is_reloadone"] = true

	Global.current_number_of_bullets = Global.number_of_bullets

func _cam_tilt(press_x, delta) -> void:
	#I NEED TO FIX THIS MF 
	var target_tilt = -press_x * camera_tilt_intese
	target_tilt = clamp(target_tilt, -90, 90)
	%head.rotation.z = lerp(%head.rotation.z, target_tilt, camera_speed_return * delta)

func _slow_shoot():
	shoot_slow = walk_speed / 6
	if is_shooting:
		walk_speed = initial_walk_speed - shoot_slow - slowness_aim
		sprint_speed = initial_sprint_speed - shoot_slow - slowness_aim
	else:
		walk_speed = initial_walk_speed - slowness_aim
		sprint_speed = initial_sprint_speed - slowness_aim

func _appear_tracer():
	for r in rcont.get_children():
		r.force_raycast_update()
		var spread_rand = Vector3(randf_range(spread, -spread), 
		randf_range(spread, -spread), r.target_position.z)
		r.target_position = spread_rand
		var bullet_tracer = tracer.instantiate()
		bullet_tracer.global_transform = tracer_spawner.global_transform
		bullet_tracer.look_at_from_position(tracer_spawner.global_transform.origin, 
		r.get_collision_point(), Vector3.UP)
		var direction = (r.get_collision_point() - tracer_spawner.global_transform.origin).normalized()
		bullet_tracer.velocity = direction * bullet_tracer.speed
		add_sibling(bullet_tracer)

func _stop_reload():
	anim_tree.set("parameters/TimeScale/scale", 0.0)
	action_key = possible_keys[randi() % possible_keys.size()]
	wait_for_input = true
	$CanvasLayer/Label.text = action_key
	
func _continue_reload(event):
	if wait_for_input:
		if event.is_action_pressed(action_key):
			anim_tree.set("parameters/TimeScale/scale", 1.0)
			wait_for_input = false
			$CanvasLayer/Label.text = ""

func _on_animation_tree_animation_finished(_anim_name: StringName) -> void:
	anim_tree["parameters/StateMachine/conditions/is_shoot"] = false
	anim_tree["parameters/StateMachine/conditions/is_shootbl"] = false
	anim_tree["parameters/StateMachine/conditions/is_reloadone"] = false
	anim_tree["parameters/StateMachine/conditions/is_reloading"] = false
	

	is_reloading = false
	
	is_shooting = false
