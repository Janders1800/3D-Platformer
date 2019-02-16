extends KinematicBody

var characterMesh
var motion = Vector2()
export var moveSpeed = 8.0
export var edgeMoveSpeed = 3.0
const MOVEMENTINTERPOLATION = 15.0
const ROTATIONINTERPOLATION = 10.0

export var jumpSpeed = 10.0
export var gravity = 9.8
export var gravityMultiplier = 2.5

var motionTarget = Vector2()
var cameraBase
var cameraPivot
var orientation = Transform()
var velocity = Vector3()

const CAMERA_ROTATION_SPEED = 0.001
const CAMERA_X_ROT_MIN = -40
const CAMERA_X_ROT_MAX = 70
var camera_x_rot = 0.0
var cameraTarget = Vector2()
export var rightJoySensivilityX = 0.07
export var rightJoySensivilityY = 0.035

var camera
var jump = false
var rayDown
var rayForward
var rayMaxLeft
var rayMaxRight
var is_hanging = false
var letGoPosition = Vector3()
var letGO = false
var targetPosition = Vector3()
var goalReached = false
var moveAmount = 0.0
var animationTree

func _init():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _ready():
	characterMesh = $CharacterMesh
	orientation = characterMesh.global_transform
	orientation.origin = Vector3()
	
	cameraBase = $CameraBase
	cameraPivot = $CameraBase/CameraPivot
	camera = $CameraBase/CameraPivot/CameraOffset/Camera
	
	rayDown = $CharacterMesh/LedgeDown
	rayForward = $CharacterMesh/LedgeFoward
	rayMaxRight = $CharacterMesh/LedgeMaxRight
	rayMaxLeft = $CharacterMesh/LedgeMaxLeft
	
	animationTree = find_node("AnimationTree")


func _input(event):
	if event is InputEventMouseMotion:
		cameraBase.rotate_y(event.relative.x * -0.01)
		cameraBase.orthonormalize()
		camera_x_rot = clamp(camera_x_rot + event.relative.y * CAMERA_ROTATION_SPEED, deg2rad(CAMERA_X_ROT_MIN), deg2rad(CAMERA_X_ROT_MAX) )
		cameraPivot.rotation.x = -camera_x_rot


func _process(delta): 
	if Input.is_action_just_pressed("ui_cancel"): get_tree().quit()
	if Input.is_action_just_pressed("ui_accept"): jump = true
	if Input.is_action_just_pressed("ui_select") and is_hanging: letGO = true
	
	motionTarget = Vector2 (Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right"), Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
	cameraTarget = Vector2 (Input.get_action_strength("camera_left") - Input.get_action_strength("camera_right"), Input.get_action_strength("camera_down") - Input.get_action_strength("camera_up"))
	moveAmount = motionTarget.length()
	
	cameraBase.rotate_y(cameraTarget.x * rightJoySensivilityX)
	cameraBase.orthonormalize()
	camera_x_rot = clamp(camera_x_rot + cameraTarget.y * rightJoySensivilityY, deg2rad(CAMERA_X_ROT_MIN), deg2rad(CAMERA_X_ROT_MAX) )
	cameraPivot.rotation.x = -camera_x_rot
	
	if translation.y < -100:
		get_tree().reload_current_scene()


func _physics_process(delta):
	motion = motion.linear_interpolate(motionTarget * moveSpeed, MOVEMENTINTERPOLATION * delta)
	
	var cam_z = - camera.global_transform.basis.z
	var cam_x = camera.global_transform.basis.x
	cam_z.y = 0
	cam_z = cam_z.normalized()
	cam_x.y = 0
	cam_x = cam_x.normalized()
	
	var direction = - cam_x * motion.x -  cam_z * motion.y
	
	var b = camera.global_transform.basis
	b.z.y = 0 # Crush Y so movement doesn't go into ground
	b.z = b.z.normalized()
	var edgeDirection = b.xform(Vector3(-motionTarget.x, 0, motionTarget.y))
	
	velocity.x = direction.x
	velocity.z = direction.z
	
	if is_on_floor():
		letGoPosition = translation
		
		var speed = motion.length() / moveSpeed
		# Animation speed
		animationTree.set("parameters/Iddle-Run/blend_amount", speed)
	else:
		animationTree.set("parameters/Iddle-Run/blend_amount", 0)
	
	if not is_hanging:
		if direction.length() > 0.01:
			var target = - cam_x * motion.x -  cam_z * motion.y
			var q_from = Quat(orientation.basis)
			var q_to = Quat(Transform().looking_at(-target,Vector3.UP).basis)
			
			#Interpolate current rotation with desired one
			orientation.basis = Basis(q_from.slerp(q_to,delta * ROTATIONINTERPOLATION))
			
			orientation = orientation.orthonormalized() # orthonormalize orientation
			characterMesh.global_transform.basis = orientation.basis
		
		if rayDown.is_colliding() and rayForward.is_colliding() and velocity.y < 0 and not is_on_floor():
			var fallDiff = translation - letGoPosition
			
			if rayForward.get_collision_normal().y <= 0 and rayDown.get_collision_normal().y > 0.5 and fallDiff.length() > 0.3:
				is_hanging = true
				goalReached = false
				
				targetPosition = rayForward.get_collision_point() + rayForward.get_collision_normal() * 0.5
				targetPosition.y = rayDown.get_collision_point().y - 1.7
				
				characterMesh.look_at(translation + rayForward.get_collision_normal(), Vector3.UP)
	
	elif is_hanging:
		if not goalReached:
			translation = translation.linear_interpolate(targetPosition, 20 * delta)
			print ((translation-targetPosition).length())
			if (translation - targetPosition).length() < 0.02: goalReached = true
			
		if letGO:	# Let go
			letGO = false
			is_hanging = false
			letGoPosition = translation
		
		velocity = Vector3()
		
		if rayDown.is_colliding() and rayDown.get_collision_normal().y >= 0.99:
			
			var calculateRight = rayForward.get_collision_normal().cross(Vector3.UP)
			
			var edgeVelocity = Vector3()
			
			if edgeDirection.dot(calculateRight) > 0.25 and rayMaxLeft.is_colliding():
				edgeVelocity += calculateRight
			elif edgeDirection.dot(calculateRight) < -0.25 and rayMaxRight.is_colliding():
				edgeVelocity -= calculateRight
			
			velocity += edgeVelocity * edgeMoveSpeed * moveAmount
	
	if ((is_on_floor() and jump) or (jump and is_hanging)):
		velocity.y = jumpSpeed
		is_hanging = false
		velocity = move_and_slide(velocity, Vector3.UP)
	else:
		velocity = move_and_slide_with_snap(velocity, Vector3.DOWN, Vector3.UP)
		if not is_hanging: velocity.y += -gravity * gravityMultiplier * delta
	
	jump = false
	