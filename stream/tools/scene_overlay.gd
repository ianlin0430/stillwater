extends SceneTree
# Draws a scene's data (data/scenes/<id>.json + data/decor.json, via ReefScene) over its
# background at world size 1280x720, so the coordinates can be checked against the art.
#   godot --headless --path . --script tools/scene_overlay.gd -- [--scene=reef|shipwreck|all] [--out=<dir>]
# Default out: artifacts/scene-overlay/<id>.png. Legend (colours):
#   red line     bed               white ticks at left/right edges: band top/bottom per species
#                                  (chromis cyan, clownfish orange, seahorse yellow, gramma violet)
#   grey ellipse terrain obstacle  orange ellipse decor obstacle   magenta ellipse anemone
#   green dot    hitch             yellow square shelter mouth (line points to its side)
#   cyan square  rock spot         white dot fade spot   white cross slot anchor
#   Default styles are drawn solid; the other styles of each slot are drawn thin and dim.
const W: int = 1280
const H: int = 720
const BAND_COLORS: Dictionary = {"green_chromis":Color(0.3,1,1),"clownfish":Color(1,0.55,0.1),"seahorse":Color(1,0.95,0.2),"royal_gramma":Color(0.75,0.45,1)}
var img: Image

func _initialize() -> void:
	var o: Dictionary={"scene":"all","out":ProjectSettings.globalize_path("res://artifacts/scene-overlay")}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray=arg.lstrip("-").split("=")
		if parts.size()==2:
			o[parts[0]]=parts[1]
	DirAccess.make_dir_recursive_absolute(o.out)
	var written: Array=[]
	for id: String in (ReefScene.ids() if o.scene=="all" else [o.scene]):
		var s: ReefScene=ReefScene.open(id)
		if s==null:
			printerr("overlay: unknown scene "+id)
			quit(1)
			return
		var path: String=o.out.path_join(id+".png")
		if draw(s).save_png(path)!=OK:
			printerr("overlay: could not write "+path)
			quit(1)
			return
		written.append(path)
	print(JSON.stringify({"written":written}))
	quit()

func draw(s: ReefScene) -> Image:
	img=Image.load_from_file(ProjectSettings.globalize_path(s.background()))
	img.convert(Image.FORMAT_RGBA8)
	img.resize(W,H,Image.INTERPOLATE_NEAREST)
	for o: Dictionary in s.terrain_obstacles():
		ellipse(o,Color(0.6,0.6,0.6),2)
	for slot: Dictionary in s.slots():
		for style: String in slot.styles:
			var main: bool=style==slot.default
			effects(s.effects(slot.id,style),1.0 if main else 0.45,2 if main else 1)
		cross(slot.anchor,Color.WHITE)
	for r: Vector2 in s.rock_spots():
		square(r,4,Color(0.2,1,1))
	var bed: Array[Vector2]=s.bed()
	for i in range(1,bed.size()):
		line(bed[i-1],bed[i],Color.RED,2)
	var k: int=0
	for sp: String in BAND_COLORS:
		var b: Vector2=s.band(sp)
		for y: float in [b.x,b.y]:
			line(Vector2(k*6,y),Vector2(k*6+40,y),BAND_COLORS[sp],2)
			line(Vector2(W-40-k*6,y),Vector2(W-k*6,y),BAND_COLORS[sp],2)
		k+=1
	return img

func effects(e: Dictionary, a: float, t: int) -> void:
	for o: Dictionary in e.obstacles:
		ellipse(o,Color(1,0.5,0.1,a),t)
	if not e.anemone.is_empty():
		ellipse(e.anemone,Color(1,0.2,0.8,a),t)
	for h: Vector2 in e.hitches:
		dot(h,3 if t>1 else 2,Color(0.2,1,0.3,a))
	for sh: Dictionary in e.shelters:
		var p: Vector2=Vector2(sh.x,sh.y)
		square(p,4 if t>1 else 3,Color(1,0.95,0.2,a))
		line(p,p+Vector2(14*sh.side,0),Color(1,0.95,0.2,a),t)
	for f: Vector2 in e.fade_spots:
		dot(f,2,Color(1,1,1,a))

func put(x: int, y: int, c: Color) -> void:
	if x>=0 and y>=0 and x<W and y<H:
		img.set_pixel(x,y,img.get_pixel(x,y).blend(c))

func dot(p: Vector2, r: int, c: Color) -> void:
	for dy in range(-r,r+1):
		for dx in range(-r,r+1):
			if dx*dx+dy*dy<=r*r:
				put(int(p.x)+dx,int(p.y)+dy,c)

func square(p: Vector2, r: int, c: Color) -> void:
	for dy in range(-r,r+1):
		for dx in range(-r,r+1):
			if absi(dx)==r or absi(dy)==r:
				put(int(p.x)+dx,int(p.y)+dy,c)

func cross(p: Vector2, c: Color) -> void:
	for d in range(-6,7):
		put(int(p.x)+d,int(p.y),c)
		put(int(p.x),int(p.y)+d,c)

func line(a: Vector2, b: Vector2, c: Color, t: int) -> void:
	var n: int=maxi(1,int(a.distance_to(b)))
	for i in n+1:
		var p: Vector2=a.lerp(b,float(i)/n)
		for d in t:
			put(int(p.x),int(p.y)+d,c)

func ellipse(o: Dictionary, c: Color, t: int) -> void:
	var n: int=int(TAU*maxf(o.rx,o.ry))
	for i in n:
		var ang: float=TAU*i/n
		for d in t:
			put(int(o.cx+cos(ang)*(o.rx-d)),int(o.cy+sin(ang)*(o.ry-d)),c)
