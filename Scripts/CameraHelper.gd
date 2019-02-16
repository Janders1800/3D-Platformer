extends Spatial


const INTERPOLATION = 0.1
const MINDISTANCE = 1.6

var originalCamZoom = null
var originalCamVect = null
var ray
var camera


func _ready():
	ray = get_node("CameraPivot/RayCast")
	camera = get_node("CameraPivot/CameraOffset")
	originalCamVect = camera.translation.normalized()
	originalCamZoom = camera.translation.length()
	get_node("CameraPivot/RayCast").add_exception(get_node(".."))


func _process(delta):
	var dist = camera.translation.length()
	var distTarget = originalCamZoom
	
	if ray.is_colliding():
		distTarget = (ray.get_collision_point() - to_global(translation)).length() - MINDISTANCE
	
	dist += (distTarget - dist) * INTERPOLATION
	camera.translation = originalCamVect.normalized() * dist