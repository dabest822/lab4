extends MeshInstance3D

@export var rotation_speed: float = 90.0  # Rotation speed in degrees per second

func _process(delta: float) -> void:
	# Rotate the star around its Y-axis
	rotate_y(deg_to_rad(rotation_speed * delta))
