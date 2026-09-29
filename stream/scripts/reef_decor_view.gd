class_name ReefDecorView
extends Node2D
# Reusable visual asset. Slot coordinates and biological effects come from ReefScene.
const SHADER=preload("res://scripts/reef_decor.gdshader")
const CATALOG="res://assets/decor/catalog.json"
static var art: Dictionary={}
var style: String="anemone_green"
var definition: Dictionary={}
var clock: float=0
var phase: float=0
var extent:=Vector2.ZERO
var materials: Array[ShaderMaterial]=[]
var guides: bool=false

static func catalog() -> Dictionary:
	if art.is_empty(): art=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	return art

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var cfg: Dictionary=catalog()[style]
	var texture: Texture2D=load(cfg.texture)
	var region:=Rect2(cfg.region[0],cfg.region[1],cfg.region[2],cfg.region[3])
	extent=Vector2(cfg.size[0],cfg.size[1])
	var vertices:=PackedVector2Array()
	var uv:=PackedVector2Array()
	var quads: Array[PackedInt32Array]=[]
	const COLS=12
	const ROWS=20
	for x in COLS+1:
		for y in ROWS+1:
			var at:=Vector2(float(x)/COLS,float(y)/ROWS)
			vertices.append((at-Vector2(.5,1))*extent)
			uv.append(region.position+at*region.size)
	for x in COLS:
		for y in ROWS:
			var i: int=x*(ROWS+1)+y
			quads.append(PackedInt32Array([i,i+ROWS+1,i+ROWS+2,i+1]))
	for foreground: bool in [false,true]:
		var mesh:=Polygon2D.new()
		mesh.texture=texture
		mesh.polygon=vertices
		mesh.uv=uv
		mesh.polygons=quads
		mesh.z_index=3 if foreground else 0
		var mat:=ShaderMaterial.new()
		mat.shader=SHADER
		mat.set_shader_parameter("extent",extent)
		mat.set_shader_parameter("region",Vector4(region.position.x,region.position.y,region.size.x,region.size.y))
		mat.set_shader_parameter("foreground",foreground)
		mat.set_shader_parameter("plant",definition.get("kind","")=="hitch")
		mat.set_shader_parameter("anemone",definition.get("kind","")=="anemone")
		mat.set_shader_parameter("phase",phase)
		for index in 4:
			var h: Array=definition.get("hitches",[])
			mat.set_shader_parameter("hold"+str(index),Vector2(h[index][0],h[index][1]) if index<h.size() else Vector2(10000,10000))
		mesh.material=mat
		materials.append(mat)
		add_child(mesh)
	if guides:
		var overlay:=Node2D.new()
		overlay.z_index=8
		add_child(overlay)
		overlay.draw.connect(_draw_guides.bind(overlay))

func advance(delta: float) -> void:
	if delta<=0: return
	clock+=delta
	for mat: ShaderMaterial in materials: mat.set_shader_parameter("clock",clock)

func _draw_guides(canvas: Node2D) -> void:
	canvas.draw_line(Vector2(-6,0),Vector2(6,0),Color.WHITE,1)
	canvas.draw_line(Vector2(0,-6),Vector2(0,6),Color.WHITE,1)
	for h: Array in definition.get("hitches",[]): canvas.draw_circle(Vector2(h[0],h[1]),2,Color.GREEN)
	for h: Dictionary in definition.get("shelters",[]): canvas.draw_circle(Vector2(h.x,h.y),2,Color.YELLOW)
