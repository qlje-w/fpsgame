extends Node3D

@export var shell = preload("res://shell/shell_scene.tscn")
@onready var character_body_3d = $CharacterBody3D
@onready var shell_spawner = $CharacterBody3D/head/Camera3D/weapons/shotgun/spawner_Shell

@onready var tracer = preload("res://tracer/bullettracer.tscn")
@onready var rcont = $CharacterBody3D/head/Camera3D/weapons/shotgun/rcont
@onready var tracer_spawner = $CharacterBody3D/head/Camera3D/weapons/shotgun/tracerspawn

func _ejection_shell() -> void:
	var cur_anim = $CharacterBody3D/head/Camera3D/weapons/shotgun/AnimationPlayer.current_animation
	var speed_of_shell_local = shell_spawner.global_transform.basis * Vector3(0, 0, 5)
	var random_speed = randf_range(1, 1.3)
	
	if cur_anim == "reload" or cur_anim == "reloadonebullet":
		var shell_casing = shell.instantiate()
		shell_casing.global_transform = shell_spawner.global_transform
		add_child(shell_casing)
		shell_casing.linear_velocity = $CharacterBody3D.velocity + speed_of_shell_local * random_speed
