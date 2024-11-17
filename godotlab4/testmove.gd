extends CharacterBody3D

# Movement settings
@export var speed: float = 5.0
@export var jump_strength: float = 10.0
@export var gravity: float = 20.0

# Camera settings
@export var camera_distance: float = 3.75
@export var camera_height: float = 3.0
@export var camera_lerp_speed: float = 2.0
@export var camera_rotation_speed: float = 0.1

# Animation settings
@export var breathing_speed: float = 2.0
@export var breathing_strength: float = 0.1

# Node references
@onready var model = $Sketchfab_Scene/Sketchfab_model
@onready var skeleton = model.find_child("Skeleton3D", true)
@onready var animation_player = $Sketchfab_Scene/AnimationPlayer
@onready var camera = $"../Camera3D"
@onready var music = $"../AudioStreamPlayer"

var camera_rotation: float = 0.0
var is_animating: bool = false
var breathing_cycle: float = 0.0  # Used to manage breathing motion

func _ready() -> void:
	# Initialize camera rotation
	if camera:
		camera_rotation = PI

	# Ensure Mario starts in the correct rotation for idle
	model.rotation_degrees.x = -90.0

	# Play background music
	if music:
		music.play()

	# Debug: Print all bone names
	if skeleton:
		print("Skeleton detected. Bone names:")
		for i in range(skeleton.get_bone_count()):
			print("Bone [", i, "]: ", skeleton.get_bone_name(i))
	else:
		print("Skeleton not found!")

	# Start with idle animation
	play_idle_animation()

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle movement input
	handle_movement(delta)

	# Jump action
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_strength

	# Jump kick action (Enter key)
	if Input.is_action_just_pressed("ui_text_submit") and not is_animating:
		play_jump_kick_animation(delta)

	# Update movement
	move_and_slide()

	# Handle camera movement
	handle_camera(delta)

	# Update animations
	if not is_animating:
		update_idle_animation(delta)

func handle_movement(delta: float) -> void:
	var cam_basis = camera.get_global_transform().basis

	# Get movement direction
	var forward = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	var right = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var movement_dir = -cam_basis.z * forward + cam_basis.x * right
	movement_dir.y = 0
	movement_dir = movement_dir.normalized()

	if movement_dir != Vector3.ZERO:
		velocity.x = movement_dir.x * speed
		velocity.z = movement_dir.z * speed

		# Rotate the model to face the movement direction
		var target_rotation = atan2(movement_dir.x, movement_dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_rotation, delta * 10.0)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

func handle_camera(delta: float) -> void:
	# Rotate camera with Page Up and Page Down
	if Input.is_action_pressed("ui_page_up"):
		camera_rotation -= camera_rotation_speed
	if Input.is_action_pressed("ui_page_down"):
		camera_rotation += camera_rotation_speed

	# Calculate camera position
	var target_position = global_position + Vector3(0, camera_height, 0)
	var camera_offset = Vector3(
		sin(camera_rotation) * camera_distance,
		0,
		cos(camera_rotation) * camera_distance
	)

	# Smooth camera position and rotation
	camera.global_position = camera.global_position.lerp(target_position + camera_offset, camera_lerp_speed * delta)
	camera.look_at(global_position + Vector3(0, 1.5, 0), Vector3.UP)

func play_idle_animation() -> void:
	# Ensure idle rotation is always 0 on the x-axis
	model.rotation_degrees.x = -90.0

	# Reset breathing cycle for animation
	if is_animating:
		return
	breathing_cycle = 0.0

func update_idle_animation(delta: float) -> void:
	if !skeleton:
		return

	# Update breathing cycle
	breathing_cycle += delta * breathing_speed
	var breathing_offset = sin(breathing_cycle) * breathing_strength

	# Apply consistent transforms with breathing animation applied to specific bones
	var idle_pose = {
		"_rootJoint": Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)),
		"Spine1_00": Transform3D(Basis.IDENTITY, Vector3(0, 0.306 + breathing_offset * 0.1, 0.142)),
		"Spine2_01": Transform3D(Basis.IDENTITY, Vector3(0, 0.601 + breathing_offset * 0.08, 0)),
		"Spine3_02": Transform3D(Basis.IDENTITY, Vector3(0, 0.379 + breathing_offset * 0.05, 0)),
		"UpperArm.L_04": Transform3D(Basis(Quaternion(0, 0, 0.892, -0.451)), Vector3(0.472, 0.533, 0)),
		"UpperArm.R_07": Transform3D(Basis(Quaternion(0, 0, 0.892, 0.45)), Vector3(-0.473, 0.533, 0)),
		"LowerArm.L_05": Transform3D(Basis(Quaternion(0, 0, -0.128, 0.991)), Vector3(0, 0.54, 0)),
		"LowerArm.R_08": Transform3D(Basis(Quaternion(0, 0, 0.127, 0.991)), Vector3(0, 0.54, 0)),
		"Head_03": Transform3D(Basis.IDENTITY, Vector3(0, 0.419 + breathing_offset * 0.1, 0)),
		"Head_end_016": Transform3D(Basis.IDENTITY, Vector3(0, 0.419, 0)),
		"Arm.L_06": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0)),
		"Arm.R_09": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0)),
		"Arm.L_end_017": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0)),
		"Arm.R_end_018": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0))
	}

	# Apply the transformations
	for bone_name in idle_pose.keys():
		var bone_idx = skeleton.find_bone(bone_name)
		if bone_idx != -1:
			skeleton.set_bone_pose(bone_idx, idle_pose[bone_name])

func play_jump_kick_animation(delta: float) -> void:
	if animation_player and not is_animating:
		# Reset rotation for idle position (-90 degrees on x-axis)
		model.rotation_degrees.x = 180.0

		# Start animation
		is_animating = true
		animation_player.play("Armature|AirKick")

		# Wait for animation to finish
		await animation_player.animation_finished

		# Reset animation state and return to idle
		is_animating = false
		breathing_cycle += delta * breathing_speed
		var breathing_offset = sin(breathing_cycle) * breathing_strength
		var idle_pose = {
			"_rootJoint": Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)),
			"Spine1_00": Transform3D(Basis.IDENTITY, Vector3(0, 0.306 + breathing_offset * 0.1, 0.142)),
			"Spine2_01": Transform3D(Basis.IDENTITY, Vector3(0, 0.601 + breathing_offset * 0.08, 0)),
			"Spine3_02": Transform3D(Basis.IDENTITY, Vector3(0, 0.379 + breathing_offset * 0.05, 0)),
			"UpperArm.L_04": Transform3D(Basis(Quaternion(0, 0, 0.892, -0.451)), Vector3(0.472, 0.533, 0)),
			"UpperArm.R_07": Transform3D(Basis(Quaternion(0, 0, 0.892, 0.45)), Vector3(-0.473, 0.533, 0)),
			"LowerArm.L_05": Transform3D(Basis(Quaternion(0, 0, -0.128, 0.991)), Vector3(0, 0.54, 0)),
			"LowerArm.R_08": Transform3D(Basis(Quaternion(0, 0, 0.127, 0.991)), Vector3(0, 0.54, 0)),
			"Head_03": Transform3D(Basis.IDENTITY, Vector3(0, 0.419 + breathing_offset * 0.1, 0)),
			"Head_end_016": Transform3D(Basis.IDENTITY, Vector3(0, 0.419, 0)),
			"Arm.L_06": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0)),
			"Arm.R_09": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0)),
			"Arm.L_end_017": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0)),
			"Arm.R_end_018": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0))
		}
		for bone_name in idle_pose.keys():
			var bone_idx = skeleton.find_bone(bone_name)
			if bone_idx != -1:
				skeleton.set_bone_pose(bone_idx, idle_pose[bone_name])

		play_idle_animation()
