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

func _init():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _ready():
	orientation = $"2B-UV-Fix".global_transform
	orientation.origin = Vector3()

	characterMesh = get_node(characterMesh)
	characterInitialScale = characterMesh.scale
	cameraBase = $CameraBase
	cameraPivot = $CameraBase/CameraPivot
	camera = $CameraBase/CameraPivot/CameraOffset/Camera



func _input(event):
	if event is InputEventMouseMotion:
		cameraBase.rotate_y(event.relative.x * -0.01)
		cameraBase.orthonormalize()
		camera_x_rot = clamp(camera_x_rot + event.relative.y * CAMERA_ROTATION_SPEED, deg2rad(CAMERA_X_ROT_MIN), deg2rad(CAMERA_X_ROT_MAX) )
		cameraPivot.rotation.x = -camera_x_rot


func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"): get_tree().quit()
	if is_on_floor() and Input.is_action_just_pressed("ui_select"): jump = true
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

	velocity.y += -gravity * gravityMultiplier * delta

	var direction = - cam_x * motion.x -  cam_z * motion.y
	velocity.x = direction.x
	velocity.z = direction.z

	if is_on_floor() and jump:
		velocity.y = jumpSpeed
		jump = false
		velocity = move_and_slide(velocity, Vector3.UP)
	else:
		velocity = move_and_slide_with_snap(velocity, Vector3.DOWN, Vector3.UP)

	if direction.length() > 0.001:
		var target = - cam_x * motion.x -  cam_z * motion.y
		var q_from = Quat(orientation.basis)
		var q_to = Quat(Transform().looking_at(-target,Vector3.UP).basis)

		#Interpolate current rotation with desired one
		orientation.basis = Basis(q_from.slerp(q_to,delta * ROTATIONINTERPOLATION))

	orientation = orientation.orthonormalized() # orthonormalize orientation
	characterMesh.global_transform.basis = orientation.basis
	characterMesh.scale = characterInitialScale
