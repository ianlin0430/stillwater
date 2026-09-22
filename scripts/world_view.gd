class_name WorldView
extends Control

signal animal_selected(id: int)
signal lake_selected(point: Vector2)
const BACKGROUND: Texture2D = preload("res://assets/wetland.png")
var snapshot: Dictionary = {}
var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO
var selected: int = -1
var follow: bool = false
var overlay: int = 0
var animation: float = 0.0
var paused: bool = false
var dragging: bool = false
var moved: bool = false
var press: Vector2
var positions: Dictionary = {}
var cutaway: bool = false
var lake_point: Vector2 = Ecosystem.CENTER
var visible_ids: Array[int] = []

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func scale_factor() -> float:
	return maxf(size.x / Ecosystem.WIDTH, size.y / Ecosystem.HEIGHT) * zoom

func origin() -> Vector2:
	return (size - Vector2(Ecosystem.WIDTH, Ecosystem.HEIGHT) * scale_factor()) * 0.5 + pan

func to_world(p: Vector2) -> Vector2:
	return (p - origin()) / scale_factor()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed and not cutaway:
				var before: Vector2 = to_world(event.position)
				zoom = clampf(zoom * (1.13 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.13), 1.0, 4.5)
				pan += event.position - (origin() + before * scale_factor())
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				moved = false
				press = event.position
			else:
				dragging = false
				if not moved:
					_pick(event.position)
	elif event is InputEventMouseMotion and dragging and not cutaway:
		if event.position.distance_to(press) > 4:
			moved = true
			follow = false
			pan += event.relative

func _pick(screen: Vector2) -> void:
	var best: float = 22.0
	var id: int = -1
	for a: Dictionary in snapshot.get("animals", []):
		if not a.alive or (cutaway and not visible_ids.has(int(a.id))):
			continue
		var p: Vector2 = underwater_position(a) if cutaway else origin() + positions.get(a.id, Vector2(a.x, a.y)) * scale_factor()
		var d: float = p.distance_to(screen)
		if d < best:
			best = d
			id = a.id
	if id >= 0:
		selected = id
		animal_selected.emit(id)
	elif not cutaway:
		var p: Vector2 = to_world(screen)
		if Ecosystem.radius(p) < sqrt(snapshot.get("level", 1.0)):
			lake_selected.emit(p)

func _process(delta: float) -> void:
	if not paused:
		animation += minf(delta, 0.1)
	var living_ids: Dictionary = {}
	for a: Dictionary in snapshot.get("animals", []):
		living_ids[a.id] = true
		var target := Vector2(a.x, a.y)
		if not positions.has(a.id):
			positions[a.id] = target
		elif not paused:
			positions[a.id] = positions[a.id].move_toward(target, minf(delta, 0.1) * 18.0)
		if follow and selected == a.id and not cutaway:
			pan = (Vector2(Ecosystem.WIDTH, Ecosystem.HEIGHT) * 0.5 - positions[a.id]) * scale_factor()
	for id: int in positions.keys():
		if not living_ids.has(id):
			positions.erase(id)
	queue_redraw()

func underwater_position(a: Dictionary) -> Vector2:
	return Vector2(20 + clampf((a.x - (lake_point.x - 230)) / 460.0, 0, 1) * (size.x - 40), 50 + a.depth * (size.y - 100))

func _draw() -> void:
	if snapshot.is_empty():
		return
	if cutaway:
		_draw_underwater()
		return
	var factor: float = scale_factor()
	draw_set_transform(origin(), 0, Vector2.ONE * factor)
	var season: int = int(fmod(snapshot.tick * Ecosystem.DT, 365.0) / 91.25)
	var tint: Color = [Color.WHITE, Color(1.04, 1, 0.85), Color(1.1, 0.88, 0.64), Color(0.78, 0.85, 0.88)][season]
	draw_texture_rect(BACKGROUND, Rect2(0, 0, Ecosystem.WIDTH, Ecosystem.HEIGHT), false, tint)
	for c: Dictionary in snapshot.cells:
		var p := Vector2(c.x, c.y)
		if c.r < 1 and not c.water:
			draw_circle(p, 43, Color(0.49, 0.40, 0.22, 0.56))
		if overlay > 0:
			var value: float = c.plant / 30.0 if overlay == 1 else (c.oxygen / 12.0 if c.water else c.moisture)
			var color: Color = Color("d08351").lerp(Color("8ecda7"), clampf(value, 0, 1))
			color.a = 0.43
			draw_rect(Rect2(p - Vector2.ONE * 31, Vector2.ONE * 62), color)
		elif c.water and c.r < 0.8:
			var drift: float = sin(animation * 0.6 + c.x) * 5
			draw_arc(p + Vector2(drift, 0), 17 + sin(animation + c.y) * 2, 0.1, 0.85, 10, Color(0.7, 0.87, 0.79, 0.09), 1.2, true)
		# Living producer patches respond to available biomass.
		if c.r > 0.8 and c.r < 1.22:
			var vigor: float = clampf(c.plant / 20.0, 0.05, 1.0)
			for blade in 4:
				var base: Vector2 = p + Vector2(blade * 7 - 10, sin(c.x + blade) * 13)
				var tip: Vector2 = base + Vector2(sin(animation + c.y + blade) * 3, -18 * vigor - 3)
				draw_line(base, tip, Color(0.48, 0.58, 0.28, 0.65), 1.4, true)
	for a: Dictionary in snapshot.animals:
		if not a.alive:
			continue
		var p: Vector2 = positions.get(a.id, Vector2(a.x, a.y))
		var size_mult: float = 0.7 if a.age < float(Ecosystem.SPECIES[a.species].mature) else 1.0
		draw_set_transform(origin() + p * factor, a.heading, Vector2.ONE * factor * size_mult)
		_animal_shape(a, 1.0)
		if a.id == selected:
			draw_arc(Vector2.ZERO, 18, 0, TAU, 36, Color("eff1c6"), 1.4, true)
	draw_set_transform(Vector2.ZERO)
	if overlay > 0:
		draw_rect(Rect2(18, size.y - 42, 330, 27), Color(0.04, 0.12, 0.10, 0.88))
		draw_string(ThemeDB.fallback_font, Vector2(28, size.y - 23), "FOOD BIOMASS  ·  low → high" if overlay == 1 else "HABITAT  ·  oxygen / soil moisture", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e0e6ce"))

func _animal_shape(a: Dictionary, opacity: float) -> void:
	var col: Color = Color(Ecosystem.SPECIES[a.species].color)
	col.a = opacity
	var phase: float = animation * 5 + a.id
	var juvenile: bool = a.age < float(Ecosystem.SPECIES[a.species].mature)
	match a.species:
		"fish":
			draw_colored_polygon(PackedVector2Array([Vector2(-9, 0), Vector2(-17, -5 + sin(phase) * 2), Vector2(-16, 5 + sin(phase) * 2)]), col.darkened(0.2))
			draw_colored_polygon(PackedVector2Array([Vector2(-11, 0), Vector2(-5, -4), Vector2(6, -4), Vector2(12, 0), Vector2(6, 4), Vector2(-5, 4)]), col)
			draw_line(Vector2(-7, 0), Vector2(7, 0), Color(0.25, 0.45, 0.39, opacity), 1.1, true)
			draw_circle(Vector2(8, -1), 1.1, Color("132e2a"))
		"frog":
			if juvenile:
				draw_line(Vector2(-2, 0), Vector2(-12, sin(phase) * 3), col.darkened(0.3), 2, true)
				draw_circle(Vector2.ZERO, 3.5, col.darkened(0.2))
			else:
				draw_line(Vector2(-2, -3), Vector2(-8, -7 - sin(phase)), col, 3, true)
				draw_line(Vector2(-2, 3), Vector2(-8, 7 + sin(phase)), col, 3, true)
				draw_circle(Vector2.ZERO, 5.5, col)
				draw_circle(Vector2(4, -3), 2.2, col.lightened(0.2))
				draw_circle(Vector2(4, 3), 2.2, col.lightened(0.2))
				draw_circle(Vector2(5, -3), 0.9, Color("1b2820"))
				draw_circle(Vector2(5, 3), 0.9, Color("1b2820"))
		"rodent":
			draw_polyline(PackedVector2Array([Vector2(-4, 0), Vector2(-11, 2), Vector2(-16, sin(phase) * 3)]), col.lightened(0.1), 1.5, true)
			draw_circle(Vector2(-2, 0), 5.5, col.darkened(0.15))
			draw_circle(Vector2(3, 0), 4, col)
			draw_circle(Vector2(2, -3), 2.2, col.lightened(0.2))
			draw_circle(Vector2(2, 3), 2.2, col.lightened(0.2))
			draw_circle(Vector2(6, -1), 0.9, Color("272922"))
		"heron":
			draw_line(Vector2(-4, -4), Vector2(-15, -6 + sin(phase) * 2), Color("b6a077"), 1.3, true)
			draw_line(Vector2(-4, 4), Vector2(-15, 6 - sin(phase) * 2), Color("b6a077"), 1.3, true)
			draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(-4, -8), Vector2(6, -5), Vector2(8, 0), Vector2(6, 5), Vector2(-4, 8)]), col)
			draw_line(Vector2(-7, 0), Vector2(5, 0), col.darkened(0.25), 2, true)
			draw_polyline(PackedVector2Array([Vector2(6, 0), Vector2(10, -3), Vector2(8, -7), Vector2(15, -8)]), col.lightened(0.12), 4, true)
			draw_colored_polygon(PackedVector2Array([Vector2(15, -10), Vector2(25, -8), Vector2(15, -6)]), Color("c9aa6e"))
			draw_circle(Vector2(16, -9), 1, Color("17251e"))
		"insect":
			if juvenile:
				draw_polyline(PackedVector2Array([Vector2(-4, 0), Vector2(-1, sin(phase)), Vector2(3, 0)]), col.darkened(0.2), 1.7, true)
			else:
				var flap: float = 2.5 + absf(sin(phase * 3)) * 2.0
				draw_line(Vector2.ZERO, Vector2(-2, -flap), Color(0.9, 0.93, 0.78, 0.8), 2, true)
				draw_line(Vector2.ZERO, Vector2(-2, flap), Color(0.9, 0.93, 0.78, 0.8), 2, true)
				draw_line(Vector2(-3, 0), Vector2(4, 0), col, 1.5, true)

func _draw_underwater() -> void:
	visible_ids.clear()
	for band in 20:
		var t: float = band / 20.0
		draw_rect(Rect2(0, size.y * t, size.x, size.y / 20.0 + 1), Color("42776d").lerp(Color("142d2e"), t))
	for ray in 6:
		var x: float = ray * 70 + sin(animation * 0.25) * 12
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 9, 0), Vector2(x - 55, size.y), Vector2(x - 80, size.y)]), Color(0.75, 0.89, 0.72, 0.045))
	var c: Dictionary = snapshot.cells[clampi(int(lake_point.y / 64), 0, 15) * 24 + clampi(int(lake_point.x / 64), 0, 23)]
	for n in 17:
		var x: float = n * size.x / 16
		var h: float = (18 + fmod(n * 29, 50)) * clampf(c.plant / 12.0, 0.1, 1.5)
		draw_polyline(PackedVector2Array([Vector2(x, size.y), Vector2(x + sin(animation + n) * 5, size.y - h * 0.6), Vector2(x + sin(animation + n + 1) * 8, size.y - h)]), Color("638663"), 2.0, true)
	for a: Dictionary in snapshot.animals:
		if not a.alive or absf(a.x - lake_point.x) > 230 or absf(a.y - lake_point.y) > 180:
			continue
		if not (a.species == "fish" or (a.species in ["insect", "frog"] and a.age < float(Ecosystem.SPECIES[a.species].mature))):
			continue
		visible_ids.append(int(a.id))
		var p: Vector2 = underwater_position(a)
		var facing: float = 0 if cos(a.heading) >= 0 else PI
		draw_set_transform(p, facing, Vector2.ONE * (1.0 if a.species == "insect" else 1.6))
		_animal_shape(a, 0.92)
		if selected == a.id:
			draw_arc(Vector2.ZERO, 18, 0, TAU, 24, Color("e1e5b7"), 1, true)
	draw_set_transform(Vector2.ZERO)
	draw_string(ThemeDB.fallback_font, Vector2(15, 25), "BENEATH THE SURFACE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d5e4cd"))
	draw_string(ThemeDB.fallback_font, Vector2(15, size.y - 12), "%d animals  ·  oxygen %.1f mg/L" % [visible_ids.size(), c.oxygen], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c1d1be"))
