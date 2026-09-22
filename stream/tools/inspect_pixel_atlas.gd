extends SceneTree
func _initialize() -> void:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	var path: String=args[0] if args.size()>0 else "res://assets/pixel/fish-atlas.png"
	var im:=Image.load_from_file(path)
	print("Size: ",im.get_size()," corner alpha: ",im.get_pixel(0,0).a)
	var columns: int=2 if "fish-atlas" in path and not "crayfish" in path else 3
	for row in 2:
		for col in columns:
			var lo:=Vector2i(im.get_width(),im.get_height())
			var hi:=Vector2i.ZERO
			for y in range(row*im.get_height()/2,(row+1)*im.get_height()/2):
				for x in range(col*im.get_width()/columns,(col+1)*im.get_width()/columns):
					if im.get_pixel(x,y).a>0.5:
						lo=lo.min(Vector2i(x,y))
						hi=hi.max(Vector2i(x,y))
			print("Cell ",col,",",row,": ",Rect2i(lo,hi-lo+Vector2i.ONE))
	quit()
