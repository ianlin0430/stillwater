class_name PopulationChart
extends Control
var history: Array = []
func _draw() -> void:
	if history.size() < 2:
		return
	var entries: Array = history.slice(maxi(0, history.size() - 150))
	var high: float = 1.0
	for e: Dictionary in entries:
		for species: String in Ecosystem.SPECIES:
			high = maxf(high, e[species])
	for n in 3:
		var y: float = 12 + (size.y - 28) * n / 2.0
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.75, 0.8, 0.65, 0.10))
	for species: String in Ecosystem.SPECIES:
		var points := PackedVector2Array()
		for i in entries.size():
			points.append(Vector2(i * size.x / (entries.size() - 1), size.y - 16 - (entries[i][species] / high) * (size.y - 30)))
		draw_polyline(points, Color(Ecosystem.SPECIES[species].color), 1.5, true)
	draw_string(ThemeDB.fallback_font, Vector2(0, 10), str(int(high)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("829887"))
