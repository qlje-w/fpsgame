extends Node3D

var target_pos = Vector3(0, 0, 0)
var speed = 75

func _process(delta: float) -> void:
	var diff = target_pos - self.global_position
	var add = diff.normalized() * speed * delta
	add = add.limit_length(diff.length())
