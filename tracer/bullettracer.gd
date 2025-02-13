extends Node3D
var speed = 50
var velocity: Vector3 = Vector3.ZERO

func _process(delta: float) -> void:
	global_translate(velocity * delta)
