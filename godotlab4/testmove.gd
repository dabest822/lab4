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
@export var breathing_strength: float = 0.2
@export var jump_animation_speed: float = 2.0
@export var walk_speed: float = 5.0  # Controls animation speed

# Node references
@onready var model = $Sketchfab_Scene/Sketchfab_model
@onready var skeleton = model.find_child("Skeleton3D", true)
@onready var animation_player = $Sketchfab_Scene/AnimationPlayer
@onready var camera = $"../Camera3D"
@onready var music = $"../AudioStreamPlayer"

var camera_rotation: float = 0.0
var is_animating: bool = false
var breathing_cycle: float = 0.0
var current_animation: String = "idle"
var jump_progress: float = 0.0
var walk_cycle: float = 0.0

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
	# Track previous floor state to detect landing
	var was_on_floor = is_on_floor()
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle movement input
	handle_movement(delta)

	# Jump action
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_strength
		play_jump_animation()

	# Update movement
	move_and_slide()
	
	# Detect landing
	if !was_on_floor and is_on_floor():
		play_idle_animation()

	# Handle camera movement
	handle_camera(delta)

	# Update current animation
	if current_animation == "jump":
		update_jump_animation(delta)
	elif current_animation == "walking":
		update_walk_animation(delta)
	elif current_animation == "idle":
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

		# Start walking animation when moving
		if current_animation != "jump" and current_animation != "walking":
			play_walk_animation()

		# Rotate the model to face the movement direction
		var target_rotation = atan2(movement_dir.x, movement_dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_rotation, delta * 10.0)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		
		# Return to idle when not moving
		if current_animation == "walking":
			play_idle_animation()

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
	current_animation = "idle"
	model.rotation_degrees.x = -90.0
	breathing_cycle = 0.0
	is_animating = false
	
	if !skeleton:
		return
		
	# Create base orientation matrices for legs
	var upper_leg_l_basis = Basis()
	upper_leg_l_basis.x = Vector3(-1, 0, 0)
	upper_leg_l_basis.y = Vector3(0, -1, 0)
	upper_leg_l_basis.z = Vector3(0, 0, 1)
	
	var lower_leg_l_basis = Basis()
	lower_leg_l_basis.x = Vector3(1, 0, 0)
	lower_leg_l_basis.y = Vector3(0, 1, -0.006)
	lower_leg_l_basis.z = Vector3(0, 0.005, 1)
	
	var upper_leg_r_basis = Basis()
	upper_leg_r_basis.x = Vector3(-1, 0, 0)
	upper_leg_r_basis.y = Vector3(0, -1, 0)
	upper_leg_r_basis.z = Vector3(0, 0, 1)
	
	var lower_leg_r_basis = Basis()
	lower_leg_r_basis.x = Vector3(1, 0, 0)
	lower_leg_r_basis.y = Vector3(0, 1, -0.006)
	lower_leg_r_basis.z = Vector3(0, 0.005, 1)
	
	# Set all bones to idle pose
	var idle_pose = {
		"_rootJoint": Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)),
		"Spine1_00": Transform3D(Basis.IDENTITY, Vector3(0, 0.306, 0.142)),
		"Spine2_01": Transform3D(Basis.IDENTITY, Vector3(0, 0.601, 0)),
		"Spine3_02": Transform3D(Basis.IDENTITY, Vector3(0, 0.379, 0)),
		"UpperArm.L_04": Transform3D(Basis(Quaternion(0, 0, 0.892, -0.451)), Vector3(0.472, 0.533, 0)),
		"UpperArm.R_07": Transform3D(Basis(Quaternion(0, 0, 0.892, 0.45)), Vector3(-0.473, 0.533, 0)),
		"LowerArm.L_05": Transform3D(Basis(Quaternion(0, 0, -0.128, 0.991)), Vector3(0, 0.54, 0)),
		"LowerArm.R_08": Transform3D(Basis(Quaternion(0, 0, 0.127, 0.991)), Vector3(0, 0.54, 0)),
		"Head_03": Transform3D(Basis.IDENTITY, Vector3(0, 0.419, 0)),
		"Head_end_016": Transform3D(Basis.IDENTITY, Vector3(0, 0.419, 0)),
		"Arm.L_06": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0)),
		"Arm.R_09": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0)),
		"Arm.L_end_017": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0)),
		"Arm.R_end_018": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0)),
		
		# Left leg idle pose
		"UpperLeg.L_010": Transform3D(
			upper_leg_l_basis,
			Vector3(0.408, -0.003, 0)
		),
		"LowerLeg.L_011": Transform3D(
			lower_leg_l_basis,
			Vector3(0, 0.614, -0.011)
		),
		
		# Right leg idle pose
		"UpperLeg.R_013": Transform3D(
			upper_leg_r_basis,
			Vector3(-0.409, -0.003, 0)
		),
		"LowerLeg.R_014": Transform3D(
			lower_leg_r_basis,
			Vector3(0, 0.614, -0.011)
		)
	}
	
	# Apply the transformations
	for bone_name in idle_pose.keys():
		var bone_idx = skeleton.find_bone(bone_name)
		if bone_idx != -1:
			skeleton.set_bone_pose(bone_idx, idle_pose[bone_name])

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
		"Arm.R_end_018": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0)),
		"UpperLeg.L_010": Transform3D(Basis(Quaternion(0, 0, 1, 0)), Vector3(0.408, -0.003, 0)),
		"LowerLeg.L_011": Transform3D(Basis(Quaternion(0, 0, 0, 1)), Vector3(0, 0.614, -0.011)),
		}
	# Apply the transformations
	for bone_name in idle_pose.keys():
		var bone_idx = skeleton.find_bone(bone_name)
		if bone_idx != -1:
			skeleton.set_bone_pose(bone_idx, idle_pose[bone_name])

func play_jump_animation() -> void:
	current_animation = "jump"
	model.rotation_degrees.x = -90.0
	jump_progress = 0.0
	is_animating = true

func update_jump_animation(delta: float) -> void:
	if !skeleton:
		return

	# Update the jump progress
	jump_progress += delta * jump_animation_speed
	var jump_phase = clamp(jump_progress, 0.0, 1.0)

	var jump_pose = {
		"_rootJoint": Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)),
		
		# Left arm raised and out to avoid head clipping
		"UpperArm.L_04": Transform3D(Basis(Quaternion(0, 0, 0.3, -0.6)), Vector3(0.472, 0.533, -0.3)),
		"LowerArm.L_05": Transform3D(Basis(Quaternion(0, -0.2 * jump_phase, 0.1 * jump_phase, 1)), Vector3(0, 0.54, 0)),
		"Arm.L_06": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0)),

		# Right arm relaxed at side
		"UpperArm.R_07": Transform3D(Basis(Quaternion(0, 0, 0.3, 0.6)), Vector3(-0.473, 0.533, 0)),
		"LowerArm.R_08": Transform3D(Basis(Quaternion(0, 0, -0.1 * jump_phase, 1)), Vector3(0, 0.54, 0)),
		"Arm.R_09": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0)),

		# Keep spine straight
		"Spine1_00": Transform3D(Basis.IDENTITY, Vector3(0, 0.306, 0.142)),
		"Spine2_01": Transform3D(Basis.IDENTITY, Vector3(0, 0.601, 0)),
		"Spine3_02": Transform3D(Basis.IDENTITY, Vector3(0, 0.379, 0)),

		"UpperLeg.L_010": Transform3D(Basis(Quaternion(0, 0.6 * jump_phase, 1 * jump_phase, 0)), Vector3(0.1, 0.8, 0)),
		"LowerLeg.L_011": Transform3D(Basis(Quaternion(0.1 * jump_phase, 0, 0, 0.9)), Vector3(0, 0.6, 0)),

		# Head stays upright
		"Head_03": Transform3D(Basis.IDENTITY, Vector3(0, 0.419, 0)),
		"Head_end_016": Transform3D(Basis.IDENTITY, Vector3(0, 0.419, 0)),
	}

	# Apply the transformations
	for bone_name in jump_pose.keys():
		var bone_idx = skeleton.find_bone(bone_name)
		if bone_idx != -1:
			skeleton.set_bone_pose(bone_idx, jump_pose[bone_name])

func play_walk_animation() -> void:
	current_animation = "walking"
	model.rotation_degrees.x = -90.0
	walk_cycle = 0.0
	is_animating = true
	
func update_walk_animation(delta: float) -> void:
	if !skeleton:
		return
		
	# Update walk cycle
	walk_cycle += delta * walk_speed
	var walk_phase = sin(walk_cycle)  # Creates a -1 to 1 cycle
	
	# Create basis using the Rest Transform values for legs
	# Left Leg
	var upper_leg_l_basis = Basis()
	upper_leg_l_basis.x = Vector3(-1, 0, 0)
	upper_leg_l_basis.y = Vector3(0, -1, 0)
	upper_leg_l_basis.z = Vector3(0, 0, 1)
	
	var lower_leg_l_basis = Basis()
	lower_leg_l_basis.x = Vector3(1, 0, 0)
	lower_leg_l_basis.y = Vector3(0, 1, -0.006)
	lower_leg_l_basis.z = Vector3(0, 0.005, 1)

	# Right Leg
	var upper_leg_r_basis = Basis()
	upper_leg_r_basis.x = Vector3(-1, 0, 0)
	upper_leg_r_basis.y = Vector3(0, -1, 0)
	upper_leg_r_basis.z = Vector3(0, 0, 1)
	
	var lower_leg_r_basis = Basis()
	lower_leg_r_basis.x = Vector3(1, 0, 0)
	lower_leg_r_basis.y = Vector3(0, 1, -0.006)
	lower_leg_r_basis.z = Vector3(0, 0.005, 1)
	
	var walk_pose = {
		"_rootJoint": Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)),

		# Left leg with walking motion
		"UpperLeg.L_010": Transform3D(
			upper_leg_l_basis * Basis(Quaternion(Vector3(1, 0, 0), 0.3 * walk_phase)),
			Vector3(0.408, -0.003, 0)
		),
		"LowerLeg.L_011": Transform3D(
			lower_leg_l_basis * Basis(Quaternion(Vector3(1, 0, 0), 0.15 * walk_phase)),
			Vector3(0, 0.614, -0.011)
		),

		# Right leg with opposite phase walking motion
		"UpperLeg.R_013": Transform3D(
			upper_leg_r_basis * Basis(Quaternion(Vector3(1, 0, 0), 0.3 * -walk_phase)),
			Vector3(-0.409, -0.003, 0)
		),
		"LowerLeg.R_014": Transform3D(
			lower_leg_r_basis * Basis(Quaternion(Vector3(1, 0, 0), 0.15 * -walk_phase)),
			Vector3(0, 0.614, -0.011)
		),

		# Arms swinging in opposition to legs (right arm with left leg)
		"UpperArm.L_04": Transform3D(
			Basis(Quaternion(0, 0, 0.892, -0.451) * Quaternion(Vector3(1, 0, 0), 0.2 * -walk_phase)), # Opposite to right leg
			Vector3(0.472, 0.533, 0)
		),
		"UpperArm.R_07": Transform3D(
			Basis(Quaternion(0, 0, 0.892, 0.45) * Quaternion(Vector3(1, 0, 0), 0.2 * walk_phase)), # Opposite to left leg
			Vector3(-0.473, 0.533, 0)
		),
		"LowerArm.L_05": Transform3D(
			Basis(Quaternion(0, 0, -0.128, 0.991) * Quaternion(Vector3(1, 0, 0), 0.1 * -walk_phase)),
			Vector3(0, 0.54, 0)
		),
		"LowerArm.R_08": Transform3D(
			Basis(Quaternion(0, 0, 0.127, 0.991) * Quaternion(Vector3(1, 0, 0), 0.1 * walk_phase)),
			Vector3(0, 0.54, 0)
		),

		# Keep rest of body in neutral pose
		"Spine1_00": Transform3D(Basis.IDENTITY, Vector3(0, 0.306, 0.142)),
		"Spine2_01": Transform3D(Basis.IDENTITY, Vector3(0, 0.601, 0)),
		"Spine3_02": Transform3D(Basis.IDENTITY, Vector3(0, 0.379, 0)),
		"Head_03": Transform3D(Basis.IDENTITY, Vector3(0, 0.419, 0)),
		"Head_end_016": Transform3D(Basis.IDENTITY, Vector3(0, 0.419, 0)),
		"Arm.L_06": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0)),
		"Arm.R_09": Transform3D(Basis.IDENTITY, Vector3(0, 0.474, 0))
	}
	
	# Apply the transformations
	for bone_name in walk_pose.keys():
		var bone_idx = skeleton.find_bone(bone_name)
		if bone_idx != -1:
			skeleton.set_bone_pose(bone_idx, walk_pose[bone_name])
