extends KinematicBody

export (NodePath) var characterMesh
var motion = Vector2()
export var moveSpeed = 10.0
const MOVEMENTINTERPOLATION = 15.0
const ROTATIONINTERPOLATION = 10.0

export var jumpSpeed = 12.0
export var gravity = 9.8
export var gravityMultiplier = 2.5

var motionTarget = Vector2()
var cameraBase
var cameraPivot
var orientation = Transform()

var characterInitialScale
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
var is_hanging = false
var letGoPosition = Vector3()


func _init():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _ready():
	characterMesh = get_node(characterMesh)
	orientation = characterMesh.global_transform
	orientation.origin = Vector3()


	characterInitialScale = characterMesh.scale
	cameraBase = $CameraBase
	cameraPivot = $CameraBase/CameraPivot
	camera = $CameraBase/CameraPivot/CameraOffset/Camera

	rayDown = $Dummy/LedgeDown
	rayForward = $Dummy/LedgeFoward


func _input(event):
	if event is InputEventMouseMotion:
		cameraBase.rotate_y(event.relative.x * -0.01)
		cameraBase.orthonormalize()
		camera_x_rot = clamp(camera_x_rot + event.relative.y * CAMERA_ROTATION_SPEED, deg2rad(CAMERA_X_ROT_MIN), deg2rad(CAMERA_X_ROT_MAX) )
		cameraPivot.rotation.x = -camera_x_rot


func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"): get_tree().quit()
	if Input.is_action_just_pressed("ui_select"): jump = true
	motionTarget = Vector2 (Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right"), Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
	cameraTarget = Vector2 (Input.get_action_strength("camera_left") - Input.get_action_strength("camera_right"), Input.get_action_strength("camera_down") - Input.get_action_strength("camera_up"))
	cameraBase.rotate_y(cameraTarget.x * rightJoySensivilityX)
	cameraBase.orthonormalize()
	camera_x_rot = clamp(camera_x_rot + cameraTarget.y * rightJoySensivilityY, deg2rad(CAMERA_X_ROT_MIN), deg2rad(CAMERA_X_ROT_MAX) )
	cameraPivot.rotation.x = -camera_x_rot


func _physics_process(delta):
	motion = motion.linear_interpolate(motionTarget * moveSpeed, MOVEMENTINTERPOLATION * delta)

	var cam_z = - camera.global_transform.basis.z
	var cam_x = camera.global_transform.basis.x
	cam_z.y = 0
	cam_z = cam_z.normalized()
	cam_x.y = 0
	cam_x = cam_x.normalized()

	var direction = - cam_x * motion.x -  cam_z * motion.y
	velocity.x = direction.x
	velocity.z = direction.z

	if not is_hanging:
		if rayDown.is_colliding() and rayForward.is_colliding() and velocity.y < 0 and not is_on_floor():
			var fallDiff = translation - letGoPosition
			if rayForward.get_collision_normal().y <= 0 and rayDown.get_collision_normal().y > 0.5 and fallDiff.length() > 1:
				is_hanging = true

				translation = rayForward.get_collision_point() + rayForward.get_collision_normal() * 0.5
				translation.y = rayDown.get_collision_point().y - 1.75
				print(translation)
				var target = -rayForward.get_collision_normal()
				var q_from = Quat(orientation.basis)
				var q_to = Quat(Transform().looking_at(-target,Vector3.UP).basis)

				#Interpolate current rotation with desired one
				orientation.basis = Basis(q_from.slerp(q_to,delta * ROTATIONINTERPOLATION))
				#characterMesh.look_at(translation + rayForward.get_collision_normal(), Vector3.UP)
				print(translation)
	elif is_hanging:
		if Input.is_action_just_pressed("ui_accept"):	# Let go
			is_hanging = false
			letGoPosition = translation

		velocity.x = 0
		velocity.y = 0
		velocity.z = 0

		if rayDown.is_colliding() and rayDown.get_collision_normal().y >= 0.99:

			var calculateRight = rayForward.get_collision_normal().cross(Vector3.UP)

			var edgeVelocity = Vector3()

			if direction.dot(calculateRight) > 0.25:
				edgeVelocity += calculateRight
			elif direction.dot(calculateRight) < -0.25:
				edgeVelocity -= calculateRight

			velocity += edgeVelocity * moveSpeed / 4
	var prevPos = translation
	if ((is_on_floor() and jump) or (jump and is_hanging)):
		velocity.y = jumpSpeed
		is_hanging = false
		velocity = move_and_slide(velocity, Vector3.UP)
		print ("jumping")
	else:
		velocity = move_and_slide_with_snap(velocity, Vector3.DOWN, Vector3.UP)
		if not is_hanging: velocity.y += -gravity * gravityMultiplier * delta

	jump = false


	if is_hanging:
		rayForward.force_raycast_update()
		rayDown.force_raycast_update()
		if not rayForward.is_colliding():
			translation = prevPos

	if direction.length() > 0.001 and not is_hanging:
		var target = - cam_x * motion.x -  cam_z * motion.y
		var q_from = Quat(orientation.basis)
		var q_to = Quat(Transform().looking_at(-target,Vector3.UP).basis)

		#Interpolate current rotation with desired one
		orientation.basis = Basis(q_from.slerp(q_to,delta * ROTATIONINTERPOLATION))

	orientation = orientation.orthonormalized() # orthonormalize orientation
	characterMesh.global_transform.basis = orientation.basis
	characterMesh.scale = characterInitialScale

