extends CharacterBody3D

#casings
@export var shell_scene : PackedScene

#spread
var spread = 10

#var
@onready var animations = $head/Camera3D/weapons/shotgun/AnimationPlayer

#camera tilt settings
@export var camera_tilt_intese = 0.03
@export var camera_speed_return = 10

#hitscan
@onready var rcont = $head/Camera3D/weapons/shotgun/rcont

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

#aim
@export var speed_aiming = 5
var aiming = false
var base_pos
var dis_aim_pos
@onready var aim_down_sides = $head/Camera3D/weapons/shotgun/Node
var slowness_aim

#shooting slowness
@export var shoot_slow = walk_speed / 2

#weapon sway
var mouse_input_vec : Vector2
@export var weapon_sway_speed = 5
@export var weapon_angle = 0.005

#weapon tilt settings
@export var weapon_tilt_intese = 0.06
@export var weapon_speed_return = 10

#weapon bob setting
@export var weapon_bob_time := 0.0
@export var weapon_bob_frequency = 2
@export var weapon_bob_move_amount = 0.00025

#headbob settings
const headbob_move_amount = 0.06
const headbob_frequency = 2.4
var headbob_time := 0.0

#ground movement settings
@export var sprint_speed := 8.5
@export var walk_speed := 7.0
@export var ground_accel := 14.0
@export var ground_decel := 10.0
@export var ground_friction := 6.0

#air movement settings
@export var air_cap := 0.85
@export var air_accel := 800.0
@export var air_move_speed := 500.0

var press_dir := Vector3.ZERO

func _get_move_speed() -> float:
	return sprint_speed if Input.is_action_pressed("sprint") else walk_speed

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_ignore_first_click()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * sensetivity)
			%Camera3D.rotate_x(-event.relative.y * sensetivity)
			%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-90), deg_to_rad(90))
			mouse_input_vec = event.relative
			
	if event.is_action_pressed("lmb") and ignore_first_click == false:
		_handle_shooting()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reload"):
		_handle_reload()
		
	if event.is_action_pressed("rmb"):
		aiming = true
	elif event.is_action_released("rmb"):
		aiming = false
	
func _ready() -> void:
	animations.play("idle")
	base_pos = $head/Camera3D/weapons/shotgun/Node.position
	dis_aim_pos = base_pos + Vector3(-0.295, 0.135, 0)
	
	for r in rcont.get_children():
		r.force_raycast_update()
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
	
func _weapon_tilt(press_x, delta) -> void:
	%weapons.rotation.z = lerp(%weapons.rotation.z, -press_x * weapon_tilt_intese, weapon_speed_return * delta)

func _ignore_first_click():
	ignore_first_click = true
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		ignore_first_click = false
		return ignore_first_click

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
	if aiming:
		slowness_aim = walk_speed - walk_speed / 1.5
		aim_down_sides.position.x = lerp(aim_down_sides.position.x, dis_aim_pos.x, delta * speed_aiming)
		aim_down_sides.position.y = lerp(aim_down_sides.position.y, dis_aim_pos.y, delta * speed_aiming)
		aim_down_sides.position = Vector3(aim_down_sides.position.x, aim_down_sides.position.y, dis_aim_pos.z)
	else:
		slowness_aim = 0
		aim_down_sides.position.x = lerp(aim_down_sides.position.x, base_pos.x, delta * speed_aiming)
		aim_down_sides.position.y = lerp(aim_down_sides.position.y, base_pos.y, delta * speed_aiming)
		aim_down_sides.position = Vector3(aim_down_sides.position.x, aim_down_sides.position.y, base_pos.z)

func _handle_shooting() -> void:
	var cur_anim = animations.current_animation
	
	if cur_anim == "idle":
		animations.stop()
		
		if Global.current_number_of_bullets > 0:
			for r in rcont.get_children():
				r.force_raycast_update()
				var spread_rand = Vector3(randf_range(spread, -spread), 
				randf_range(spread, -spread), r.target_position.z)
				r.target_position = spread_rand
				if r.is_colliding():
					var collider = r.get_collider()
					if collider.is_in_group("enemy"):
						collider._getting_shot()

			animations.queue("shoot")
			Global.current_number_of_bullets -= 1
			animations.queue("idle")
			
		elif Global.current_number_of_bullets < 0.5:
			animations.play("shoot2")
		
		animations.queue("idle")

func _handle_reload() -> void:
	var cur_anim = animations.current_animation

	if cur_anim == "idle":
		if Global.current_number_of_bullets < 0.5:
			animations.play("reload")
		elif Global.current_number_of_bullets < Global.number_of_bullets:
			animations.play("reloadonebullet")
			
		animations.queue("idle")
		Global.current_number_of_bullets = Global.number_of_bullets

func _cam_tilt(press_x, delta) -> void:
	var target_tilt = -press_x * camera_tilt_intese
	%head.rotation.z = lerp(%head.rotation.z, target_tilt, camera_speed_return * delta)

func _slow_shoot():
	var cur_anim = animations.current_animation
	if cur_anim == "shoot":
		walk_speed = 7.0 - shoot_slow - slowness_aim
		sprint_speed = 8.5 - shoot_slow - slowness_aim
	else:
		walk_speed = 7 - slowness_aim
		sprint_speed = 8.5 - slowness_aim
