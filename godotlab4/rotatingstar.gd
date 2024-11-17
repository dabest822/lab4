extends MeshInstance3D

@export var rotation_speed: float = 90.0  # Rotation speed in degrees per second

# Reference to the area node we'll create
@onready var collision_area = $Area3D

func _ready() -> void:
	# Connect the area's body entered signal
	if collision_area:
		collision_area.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Rotate the star around its Y-axis
	rotate_y(deg_to_rad(rotation_speed * delta))

func _on_body_entered(body: Node3D) -> void:
	# Check if the colliding body is Mario (the player)
	if body.name == "AltMario":  # Use your player node's name here
		# Make the star disappear
		queue_free()
