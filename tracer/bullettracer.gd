extends Node3D
var speed = 50
var velocity: Vector3 = Vector3.ZERO

@export var hole = preload("res://assets/textures/png-clipart-bullet-transparency-and-translucency-bullet-holes-miscellaneous-rock.png")

func _process(delta: float) -> void:
	global_translate(velocity * delta)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy"):
		body._getting_shot()
