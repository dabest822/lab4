extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_strength: float = 10.0
@export var gravity: float = 20.0

# Camera settings
@export var camera_distance: float = 5.0
@export var camera_height: float = 6.0
@export var camera_lerp_speed: float = 2.0
@export var camera_rotation_speed: float = 0.1

# Animation settings
@export var leg_swing_speed: float = 10.0
@export var leg_swing_amount: float = 0.5
@export var arm_swing_amount: float = 0.3

@onready var camera = get_parent().get_node("Camera3D")
@onready var skeleton = $mario/Armature/Skeleton3D
var camera_rotation: float = 0.0
var run_cycle: float = 0.0

func _ready() -> void:
	if camera:
		camera_rotation = PI
	
	# Hide wings if they exist
	if has_node("mario/Armature/Skeleton3D/right_wing"):
		get_node("mario/Armature/Skeleton3D/right_wing").visible = false
	if has_node("mario/Armature/Skeleton3D/left_wing"):
		get_node("mario/Armature/Skeleton3D/left_wing").visible = false

func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Get camera basis (rotation)
	var cam_basis = camera.get_global_transform().basis
	
	# Get raw input
	var forward = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	var right = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	
	# Create movement direction relative to camera
	var movement_dir = Vector3.ZERO
	movement_dir += -cam_basis.z * forward
	movement_dir += cam_basis.x * right
	movement_dir.y = 0
	movement_dir = movement_dir.normalized()
	
	# Set velocity based on movement direction
	if movement_dir:
		velocity.x = movement_dir.x * speed
		velocity.z = movement_dir.z * speed
		
		# Rotate Mario to face movement direction
		var target_rot = atan2(movement_dir.x, movement_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 10.0)
		
		# Update run cycle for animations
		run_cycle += delta * leg_swing_speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	# Handle jumping
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_strength
	
	move_and_slide()
	handle_camera(delta)
	update_animations(delta)

func handle_camera(delta: float) -> void:
	if !camera:
		return
		
	# Camera rotation with Q and E keys
	if Input.is_action_pressed("ui_page_up"):
		camera_rotation -= camera_rotation_speed
	if Input.is_action_pressed("ui_page_down"):
		camera_rotation += camera_rotation_speed
	
	# Calculate camera position
	var target_pos = global_position + Vector3(0, camera_height, 0)
	var camera_offset = Vector3(
		sin(camera_rotation) * camera_distance,
		0,
		cos(camera_rotation) * camera_distance
	)
	
	# Update camera position and rotation
	camera.global_position = camera.global_position.lerp(target_pos + camera_offset, camera_lerp_speed * delta)
	
	# Make camera look at Mario
	var look_target = global_position + Vector3(0, 1.5, 0)
	var camera_transform = camera.global_transform
	camera_transform = camera_transform.looking_at(look_target, Vector3.UP)
	camera.global_transform = camera.global_transform.interpolate_with(camera_transform, camera_lerp_speed * delta)

func update_animations(delta: float) -> void:
	if !skeleton:
		return
		
	if not is_on_floor():
		# Jump animation
		animate_jump()
	elif velocity.length() > 0.1:
		# Walk/Run animation
		animate_run()
	else:
		# Idle animation
		animate_idle(delta)

func animate_run() -> void:
	var leg_swing = sin(run_cycle) * leg_swing_amount
	var arm_swing = -sin(run_cycle) * arm_swing_amount
	
	# Legs
	set_bone_pose("left_thigh", Vector3(leg_swing, 0, 0))
	set_bone_pose("right_thigh", Vector3(-leg_swing, 0, 0))
	set_bone_pose("left_leg", Vector3(-leg_swing * 0.5, 0, 0))
	set_bone_pose("right_leg", Vector3(leg_swing * 0.5, 0, 0))
	
	# Arms
	set_bone_pose("left_upperarm", Vector3(arm_swing, 0, 0))
	set_bone_pose("right_upperarm", Vector3(-arm_swing, 0, 0))
	set_bone_pose("left_forearm", Vector3(arm_swing * 0.5, 0, 0))
	set_bone_pose("right_forearm", Vector3(-arm_swing * 0.5, 0, 0))

func animate_jump() -> void:
	# Tuck legs for jump
	set_bone_pose("left_thigh", Vector3(0.4, 0, 0))
	set_bone_pose("right_thigh", Vector3(0.4, 0, 0))
	set_bone_pose("left_leg", Vector3(-0.8, 0, 0))
	set_bone_pose("right_leg", Vector3(-0.8, 0, 0))
	
	# Raise arms
	set_bone_pose("left_upperarm", Vector3(-0.5, 0, 0.3))
	set_bone_pose("right_upperarm", Vector3(-0.5, 0, -0.3))

func animate_idle(_delta: float) -> void:
	var breath = sin(Time.get_ticks_msec() * 0.002) * 0.03
	set_bone_pose("spine_rotation", Vector3(breath, 0, 0))
	set_bone_pose("chest", Vector3(breath, 0, 0))

func set_bone_pose(bone_name: String, rotation: Vector3) -> void:
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx != -1:
		skeleton.set_bone_pose_rotation(bone_idx, Quaternion.from_euler(rotation))
