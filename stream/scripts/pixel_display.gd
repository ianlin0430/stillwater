class_name PixelDisplay
extends Control
# The UI keeps its native resolution; only the aquarium is enlarged in whole pixels.
const RESOLUTION := Vector2i(640,360)
const WORLD_SIZE := Vector2(1280,720)
var texture: Texture2D

static func fitted_rect(available: Vector2) -> Rect2:
	var multiple: float=maxf(1,floorf(minf(available.x/RESOLUTION.x,available.y/RESOLUTION.y)))
	var drawn_size: Vector2=Vector2(RESOLUTION)*multiple
	return Rect2(((available-drawn_size)/2).floor(),drawn_size)

func world_point(local_point: Vector2) -> Vector2:
	var rect:=fitted_rect(size)
	return (local_point-rect.position)/rect.size*WORLD_SIZE

func _ready() -> void:
	custom_minimum_size=Vector2(RESOLUTION)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)

func _draw() -> void:
	if texture!=null: draw_texture_rect(texture,fitted_rect(size),false)
