class_name RTSCamera
extends Camera3D
## Fixed-angle RTS camera, Warcraft style.
##
## It is driven in *game-world pixels* (focus point + zoom) so the input code
## never has to think in 3D: it asks the camera to convert screen <-> world.

const PITCH_DEG := 56.0
const BASE_DISTANCE := 38.0   # metres from the focus point at zoom 1
const MIN_ZOOM := 0.5
const MAX_ZOOM := 2.2

var focus := Vector2.ZERO:
	set(v):
		focus = v
		_apply()
var zoom := 1.0:
	set(v):
		zoom = clampf(v, MIN_ZOOM, MAX_ZOOM)
		_apply()


func _ready() -> void:
	fov = 34.0
	near = 0.5
	far = 600.0
	_apply()


func _apply() -> void:
	var pitch := deg_to_rad(PITCH_DEG)
	var dist := BASE_DISTANCE / zoom
	position = ViewSpace.to_3d(focus) + Vector3(0.0, sin(pitch), cos(pitch)) * dist
	rotation = Vector3(-pitch, 0.0, 0.0)


func clamp_focus() -> void:
	focus = focus.clamp(Vector2.ZERO, Game.MAP_SIZE)


## Where a screen position hits the ground, in world pixels.
func screen_to_world(screen_pos: Vector2) -> Vector2:
	var origin := project_ray_origin(screen_pos)
	var dir := project_ray_normal(screen_pos)
	if dir.y > -0.0001:
		dir.y = -0.0001
	var hit := origin + dir * (-origin.y / dir.y)
	return ViewSpace.to_2d(hit)


## Screen position of a world point (optionally raised `height` metres above the ground).
func world_to_screen(world_pos: Vector2, height := 0.0) -> Vector2:
	return unproject_position(ViewSpace.to_3d(world_pos, height))


func is_on_screen(world_pos: Vector2, height := 0.0) -> bool:
	if is_position_behind(ViewSpace.to_3d(world_pos, height)):
		return false
	return get_viewport().get_visible_rect().has_point(world_to_screen(world_pos, height))


## Roughly how many world pixels one screen pixel covers near the middle of the view.
func world_px_per_screen_px() -> float:
	var c := get_viewport().get_visible_rect().size * 0.5
	return screen_to_world(c).distance_to(screen_to_world(c + Vector2(10, 0))) / 10.0


## Pans so the ground point under `from` ends up under `to` (finger-follows-ground).
func pan_screen(from: Vector2, to: Vector2) -> void:
	focus += screen_to_world(from) - screen_to_world(to)
	clamp_focus()
