extends MeshInstance3D

@export var rotation_speed: float = 90.0  # Rotation speed in degrees per second
@export var camera_fly_duration: float = 4.25  # How long the camera flies away
@export var fade_duration: float = 4.25  # How long the fade effect takes

@onready var collision_area = $Area3D
@onready var star_sound = $"../starget"
@onready var bgm = $"../AudioStreamPlayer"
@onready var camera = $"../Camera3D"  # Reference to your camera

# Create a ColorRect for the fade effect
var fade_overlay: ColorRect

func _ready() -> void:
	if collision_area:
		collision_area.body_entered.connect(_on_body_entered)
	setup_fade_overlay()

func setup_fade_overlay() -> void:
	# Create the overlay that will hold our shader
	fade_overlay = ColorRect.new()
	fade_overlay.custom_minimum_size = Vector2(2000, 2000)  # Make it big enough to cover screen
	fade_overlay.visible = false
	
	# Create and set up the shader
	var shader_material = ShaderMaterial.new()
	shader_material.shader = preload("res://fade_shader.gdshader")  # We'll create this file
	fade_overlay.material = shader_material
	
	# Add to the UI layer
	var canvas_layer = CanvasLayer.new()
	canvas_layer.add_child(fade_overlay)
	add_child(canvas_layer)

func _process(delta: float) -> void:
	rotate_y(deg_to_rad(rotation_speed * delta))

func _on_body_entered(body: Node3D) -> void:
	if body.name == "AltMario":
		# Make star invisible and disable collisions
		visible = false
		collision_area.set_deferred("monitoring", false)
		collision_area.set_deferred("monitorable", false)
		
		# Stop background music and play star sound
		if bgm:
			bgm.stop()
		if star_sound:
			star_sound.play()
		
		# Start the camera fly-away and fade effect
		start_ending_sequence()

func start_ending_sequence() -> void:
	# Store initial camera position and rotation
	var initial_camera_pos = camera.global_position
	var initial_camera_rot = camera.global_rotation
	var _initial_distance = camera.position.length()
	
	# Make fade overlay visible
	fade_overlay.visible = true
	var shader_mat = fade_overlay.material as ShaderMaterial
	
	# Animate over time
	var elapsed_time = 0.0
	while elapsed_time < camera_fly_duration:
		elapsed_time += get_process_delta_time()
		var progress = elapsed_time / camera_fly_duration
		
		# Move camera away and up
		var distance_mult = 1.0 + (progress * 2.0)  # Fly 5x further away
		var height_offset = progress * 5.0  # Fly upward
		camera.position = initial_camera_pos * distance_mult + Vector3(0, height_offset, 0)
		
		# Tilt camera down slightly
		camera.rotation.x = initial_camera_rot.x - (progress * 0.3)
		
		# Update shader progress (0 to 1)
		if shader_mat:
			shader_mat.set_shader_parameter("progress", progress)
		
		await get_tree().process_frame
	
	# Wait for star sound to finish if it hasn't already
	await star_sound.finished
	get_tree().quit()
