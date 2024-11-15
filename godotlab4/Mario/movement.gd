extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_strength: float = 10.0
@export var gravity: float = 20.0

# Camera settings
@export var camera_distance: float = 10.0
@export var camera_height: float = 6.0
@export var camera_lerp_speed: float = 2.0
@export var camera_rotation_speed: float = 0.1

@onready var camera = get_parent().get_node("Camera3D")
@onready var animation_player = $mario/AnimationPlayer
var camera_rotation: float = 0.0

func _ready() -> void:
	if camera:
		camera_rotation = PI
	
	# Hide extra parts
	if has_node("mario/Armature/Skeleton3D/mario_cap_wings"):
		get_node("mario/Armature/Skeleton3D/mario_cap_wings").visible = false
	if has_node("mario/Armature/Skeleton3D/mario_cap_on"):
		get_node("mario/Armature/Skeleton3D/mario_cap_on").visible = false

	setup_animations()

func setup_animations() -> void:
	var library = AnimationLibrary.new()
	
	# Create idle animation
	var idle = Animation.new()
	idle.length = 2.0
	idle.loop_mode = Animation.LOOP_LINEAR
	
	# Add tracks for idle breathing motion
	add_bone_track(idle, "spine_rotation", [
		[0.0, Vector3(0, 0, 0)],
		[1.0, Vector3(0.05, 0, 0)],
		[2.0, Vector3(0, 0, 0)]
	])
	add_bone_track(idle, "chest", [
		[0.0, Vector3(0, 0, 0)],
		[1.0, Vector3(0.05, 0, 0)],
		[2.0, Vector3(0, 0, 0)]
	])
	library.add_animation("idle", idle)
	
	# Create walk animation
	var walk = Animation.new()
	walk.length = 1.0
	walk.loop_mode = Animation.LOOP_LINEAR
	
	# Leg movement
	add_bone_track(walk, "left_thigh", [
		[0.0, Vector3(0.4, 0, 0)],
		[0.5, Vector3(-0.4, 0, 0)],
		[1.0, Vector3(0.4, 0, 0)]
	])
	add_bone_track(walk, "right_thigh", [
		[0.0, Vector3(-0.4, 0, 0)],
		[0.5, Vector3(0.4, 0, 0)],
		[1.0, Vector3(-0.4, 0, 0)]
	])
	add_bone_track(walk, "left_leg", [
		[0.0, Vector3(-0.2, 0, 0)],
		[0.5, Vector3(0.2, 0, 0)],
		[1.0, Vector3(-0.2, 0, 0)]
	])
	add_bone_track(walk, "right_leg", [
		[0.0, Vector3(0.2, 0, 0)],
		[0.5, Vector3(-0.2, 0, 0)],
		[1.0, Vector3(0.2, 0, 0)]
	])
	
	# Arm movement
	add_bone_track(walk, "left_upperarm", [
		[0.0, Vector3(-0.3, 0, 0)],
		[0.5, Vector3(0.3, 0, 0)],
		[1.0, Vector3(-0.3, 0, 0)]
	])
	add_bone_track(walk, "right_upperarm", [
		[0.0, Vector3(0.3, 0, 0)],
		[0.5, Vector3(-0.3, 0, 0)],
		[1.0, Vector3(0.3, 0, 0)]
	])
	library.add_animation("walk", walk)
	
	# Create jump animation
	var jump = Animation.new()
	jump.length = 0.5
	jump.loop_mode = Animation.LOOP_NONE
	
	# Jump pose
	add_bone_track(jump, "left_thigh", [[0.0, Vector3(0.6, 0, 0)]])
	add_bone_track(jump, "right_thigh", [[0.0, Vector3(0.6, 0, 0)]])
	add_bone_track(jump, "left_leg", [[0.0, Vector3(-0.8, 0, 0)]])
	add_bone_track(jump, "right_leg", [[0.0, Vector3(-0.8, 0, 0)]])
	add_bone_track(jump, "left_upperarm", [[0.0, Vector3(-0.5, 0, 0.3)]])
	add_bone_track(jump, "right_upperarm", [[0.0, Vector3(-0.5, 0, -0.3)]])
	library.add_animation("jump", jump)
	
	# Add library to animation player
	animation_player.add_animation_library("", library)

func add_bone_track(anim: Animation, bone_name: String, keys: Array) -> void:
	var track_idx = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track_idx, "Armature/Skeleton3D:" + bone_name)
	for key in keys:
		anim.rotation_track_insert_key(track_idx, key[0], Quaternion.from_euler(key[1]))

func _physics_process(delta: float) -> void:
	handle_movement(delta)
	handle_camera(delta)
	update_animation()

func handle_movement(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Get camera-relative input direction
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Convert input to camera-relative direction
	var cam_basis = camera.get_global_transform().basis
	var movement_dir = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	movement_dir.y = 0  # Ensure movement is horizontal
	
	# Handle movement
	if movement_dir:
		velocity.x = movement_dir.x * speed
		velocity.z = movement_dir.z * speed
		# Rotate mario to face movement direction
		if movement_dir.length() > 0:
			var look_transform = Transform3D().looking_at(movement_dir, Vector3.UP)
			global_transform.basis = global_transform.basis.slerp(look_transform.basis, delta * 10.0)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	# Handle jumping
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_strength
	
	move_and_slide()

func handle_camera(delta: float) -> void:
	if !camera:
		return
		
	# Camera rotation with Q and E keys
	if Input.is_action_pressed("ui_page_up"):  # Q key
		camera_rotation -= camera_rotation_speed
	if Input.is_action_pressed("ui_page_down"): # E key
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
	
	# Make camera look at a point slightly above Mario
	var look_target = global_position + Vector3(0, 1.5, 0)  # Look at head level
	var camera_transform = camera.global_transform
	camera_transform = camera_transform.looking_at(look_target, Vector3.UP)
	camera.global_transform = camera.global_transform.interpolate_with(camera_transform, camera_lerp_speed * delta)

func update_animation() -> void:
	if animation_player:
		if not is_on_floor():
			if animation_player.current_animation != "jump":
				animation_player.play("jump")
		else:
			if velocity.length() > 0.1:
				if animation_player.current_animation != "walk":
					animation_player.play("walk")
			else:
				if animation_player.current_animation != "idle":
					animation_player.play("idle")
