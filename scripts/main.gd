extends Control

const STEP_SECONDS: float = 7200.0 / 1460.0
const CREAM: Color = Color("e5e7d7")
const MUTED: Color = Color("97ad9f")
var sim: Ecosystem
var view: WorldView
var underwater: WorldView
var chart: PopulationChart
var info: RichTextLabel
var events_label: RichTextLabel
var date_label: Label
var climate_label: Label
var count_label: Label
var status_label: Label
var pause_button: Button
var branch_button: Button
var follow_button: Button
var species_option: OptionButton
var rain_slider: HSlider
var experiment: VBoxContainer
var help_panel: AcceptDialog
var file_dialog: FileDialog
var speed: int = 1
var paused: bool = false
var accumulator: float = 0.0
var autosave_clock: float = 0.0
var refresh_clock: float = 0.0
var selected: int = -1
var save_path: String = "user://stillwater.world"
var last_snapshot: Dictionary = {}
var sound: AudioStreamPlayer
var screenshot_mode: bool = false
var fps_samples: Array = []
var qa_clock: float = 0.0
var qa_observations: Dictionary = {}
var qa_view_failures: Array[String] = []
var qa_capture_pending: bool = false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	DisplayServer.window_set_min_size(Vector2i(1100, 740))
	screenshot_mode = "--qa" in OS.get_cmdline_user_args()
	sim = Ecosystem.new()
	var loaded: Dictionary = {} if screenshot_mode else SaveStore.load_world(save_path)
	if not loaded.is_empty():
		sim.restore(loaded.state)
	var original_path: String = save_path
	if not screenshot_mode and loaded.is_empty():
		save_path = SaveStore.fresh_path_if_unreadable(save_path)
	_setup_theme()
	_build_ui()
	_ambient_sound()
	_refresh()
	if loaded.get("backup", false):
		status_label.text = "Recovered the verified backup; primary save was unreadable."
	if save_path != original_path:
		status_label.text = "Original save could not be read and was preserved. New world saves to " + save_path.get_file()
	if screenshot_mode:
		status_label.text = "QA session · isolated from your saved world"

func _setup_theme() -> void:
	var theme_new := Theme.new()
	theme_new.default_font_size = 14
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "sans-serif"])
	theme_new.default_font = font
	theme_new.set_color("font_color", "Label", CREAM)
	theme_new.set_color("default_color", "RichTextLabel", MUTED)
	for type in ["Button", "OptionButton"]:
		for variant in ["normal", "hover", "pressed", "focus", "disabled"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color("294c41") if variant in ["hover", "pressed"] else Color("19382f")
			box.border_color = Color("55755c") if variant == "focus" else Color("345448")
			box.set_border_width_all(1)
			box.set_corner_radius_all(5)
			box.content_margin_left = 13
			box.content_margin_right = 13
			box.content_margin_top = 8
			box.content_margin_bottom = 8
			theme_new.set_stylebox(variant, type, box)
			theme_new.set_color("font_color", type, CREAM)
			theme_new.set_color("font_hover_color", type, Color.WHITE)
	theme = theme_new

func label(text: String, size_px: int = 14, color: Color = CREAM) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size_px)
	item.add_theme_color_override("font_color", color)
	return item

func button(text: String, callback: Callable, tooltip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tooltip
	b.pressed.connect(callback)
	return b

func _build_ui() -> void:
	var base := VBoxContainer.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.add_theme_constant_override("separation", 0)
	add_child(base)
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 26)
	header_margin.add_theme_constant_override("margin_right", 24)
	header_margin.add_theme_constant_override("margin_top", 18)
	header_margin.add_theme_constant_override("margin_bottom", 17)
	base.add_child(header_margin)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	header_margin.add_child(header)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	var title := label("Stillwater", 34)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "serif"])
	title.add_theme_font_override("font", serif)
	identity.add_child(title)
	identity.add_child(label("A  L I V I N G  W E T L A N D", 10, MUTED))
	var datebox := VBoxContainer.new()
	datebox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(datebox)
	date_label = label("")
	datebox.add_child(date_label)
	climate_label = label("", 12, MUTED)
	datebox.add_child(climate_label)
	for item in [["Save", _save], ["Open", _open_dialog], ["Branch experiment", _branch], ["?", _help]]:
		var b: Button = button(item[0], item[1])
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(b)
		if item[0] == "Branch experiment":
			branch_button = b
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	base.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	body.add_child(left)
	view = WorldView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(650, 380)
	view.animal_selected.connect(_select)
	view.lake_selected.connect(_lake)
	left.add_child(view)
	var controls_margin := MarginContainer.new()
	controls_margin.add_theme_constant_override("margin_left", 20)
	controls_margin.add_theme_constant_override("margin_right", 20)
	controls_margin.add_theme_constant_override("margin_top", 14)
	controls_margin.add_theme_constant_override("margin_bottom", 14)
	left.add_child(controls_margin)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	controls_margin.add_child(controls)
	pause_button = button("Ⅱ  Pause", _toggle_pause, "Space · pause / resume")
	controls.add_child(pause_button)
	for rate in [1, 5, 20]:
		var b := button("%d×" % rate, func() -> void: speed = rate; _refresh())
		controls.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)
	var overlay_option := OptionButton.new()
	for text in ["Natural view", "Food availability", "Habitat conditions"]:
		overlay_option.add_item(text)
	overlay_option.item_selected.connect(func(index: int) -> void: view.overlay = index)
	controls.add_child(overlay_option)
	controls.add_child(button("Reset view", func() -> void: view.pan = Vector2.ZERO; view.zoom = 1; view.follow = false))
	controls.add_child(button("Sound", func() -> void: sound.stream_paused = not sound.stream_paused))
	var side_margin := MarginContainer.new()
	side_margin.custom_minimum_size.x = 310
	side_margin.add_theme_constant_override("margin_left", 20)
	side_margin.add_theme_constant_override("margin_right", 20)
	side_margin.add_theme_constant_override("margin_top", 16)
	body.add_child(side_margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_margin.add_child(scroll)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 270
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	scroll.add_child(side)
	side.add_child(label("FIELD NOTES", 11, MUTED))
	side.add_child(label("Life at the water’s edge", 19))
	count_label = label("", 13, MUTED)
	side.add_child(count_label)
	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.custom_minimum_size.y = 140
	info.scroll_active = false
	side.add_child(info)
	follow_button = button("Follow selected animal", func() -> void: view.follow = not view.follow; _refresh())
	side.add_child(follow_button)
	underwater = WorldView.new()
	underwater.cutaway = true
	underwater.custom_minimum_size = Vector2(270, 205)
	underwater.animal_selected.connect(_select)
	side.add_child(underwater)
	side.add_child(label("Click the lake to move this cutaway", 11, MUTED))
	side.add_child(label("POPULATION THROUGH TIME", 11, MUTED))
	chart = PopulationChart.new()
	chart.custom_minimum_size.y = 76
	side.add_child(chart)
	side.add_child(label("RECENT OBSERVATIONS", 11, MUTED))
	events_label = RichTextLabel.new()
	events_label.bbcode_enabled = true
	events_label.fit_content = true
	events_label.custom_minimum_size.y = 100
	events_label.scroll_active = false
	events_label.add_theme_font_size_override("normal_font_size", 12)
	side.add_child(events_label)
	experiment = VBoxContainer.new()
	experiment.add_theme_constant_override("separation", 8)
	side.add_child(experiment)
	experiment.add_child(label("EXPERIMENT CONTROLS", 11, Color("d8bf84")))
	experiment.add_child(label("Rainfall multiplier (0–3×)", 12, MUTED))
	rain_slider = HSlider.new()
	rain_slider.min_value = 0
	rain_slider.max_value = 3
	rain_slider.step = 0.1
	rain_slider.value = sim.state.rain_scale
	rain_slider.drag_ended.connect(func(_changed: bool) -> void: _command({"kind": "rain", "value": rain_slider.value}))
	experiment.add_child(rain_slider)
	experiment.add_child(button("Add 100 nutrient units", func() -> void: _command({"kind": "nutrients", "value": 100})))
	species_option = OptionButton.new()
	for species: String in Ecosystem.SPECIES:
		species_option.add_item(Ecosystem.SPECIES[species].label)
	experiment.add_child(species_option)
	var population_controls := HBoxContainer.new()
	experiment.add_child(population_controls)
	population_controls.add_child(button("Add 10", func() -> void: _population(10)))
	population_controls.add_child(button("Remove 10", func() -> void: _population(-10)))
	var footer := MarginContainer.new()
	footer.add_theme_constant_override("margin_left", 24)
	footer.add_theme_constant_override("margin_bottom", 10)
	base.add_child(footer)
	status_label = label("Drag to explore · scroll to zoom · click an animal to inspect · Space to pause", 12, MUTED)
	footer.add_child(status_label)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.world ; Stillwater world"])
	file_dialog.current_dir = OS.get_user_data_dir()
	file_dialog.file_selected.connect(_load)
	add_child(file_dialog)
	help_panel = AcceptDialog.new()
	help_panel.title = "About this living world"
	help_panel.dialog_text = "Observe a connected lake, wetland and woodland.\n\nDrag to pan; scroll to zoom; click an animal to inspect.\nClick water to inspect that location below the surface.\nSpace pauses. 1× advances one ecological year in two hours.\n5× and 20× execute the same ecological steps faster.\n\nBranches preserve your original world and unlock experiments.\nSaves resume where you left off. Nothing runs while closed.\n\nColours in the population chart match animal colours.\nLake midges → minnows / frogs → herons. Voles graze plants.\nDetritus and nutrients support producer regrowth.\n\nThis is an illustrative model, not a scientific prediction.\nAnimal motion and ecological time use different scales.\nSpecies parameters and simplifications: docs/ecology.md.\n\nAutosaves: " + OS.get_user_data_dir()
	add_child(help_panel)

func _refresh() -> void:
	last_snapshot = sim.snapshot()
	view.snapshot = last_snapshot
	underwater.snapshot = last_snapshot
	view.paused = paused
	underwater.paused = paused
	view.selected = selected
	underwater.selected = selected
	var day: int = int(sim.state.tick * Ecosystem.DT)
	var seasons: Array = ["Spring", "Summer", "Autumn", "Winter"]
	date_label.text = "%s · day %d  /  year %d     %d×" % [seasons[int(fmod(sim.state.tick * Ecosystem.DT, 365.0) / 91.25)], day % 365 + 1, int(day / 365) + 1, speed]
	climate_label.text = "%.0f°C  ·  rain %.1f  ·  lake %.0f%%" % [sim.state.temperature, sim.state.rain, sim.state.level * 100]
	var counts: Dictionary = sim.counts()
	count_label.text = "%d fish  ·  %d frogs  ·  %d voles\n%d midges  ·  %d herons" % [counts.fish, counts.frog, counts.rodent, counts.insect, counts.heron]
	info.text = "[color=#e5e7d7]A world with its own rhythm.[/color]\n\nFollow a life, watch the seasons, or look beneath the surface. Every animal is part of the same food web.\n\nSelect an animal to read its story."
	for a: Dictionary in last_snapshot.animals:
		if a.id == selected:
			var cfg: Dictionary = Ecosystem.SPECIES[a.species]
			info.text = "[color=#e5e7d7][b]%s · #%d[/b][/color]\n%s · %.0f days old\nReserve %.0f%% · %s\n" % [cfg.label, a.id, "Juvenile" if a.age < float(cfg.mature) else "Adult", a.age, a.energy / float(cfg.reserve) * 100, a.activity]
			for e: Dictionary in a.recent.slice(-3):
				info.text += "\nDay %d · %s" % [int(e.tick * Ecosystem.DT) + 1, e.detail]
			break
	follow_button.disabled = selected < 0
	follow_button.text = "Stop following" if view.follow else "Follow selected animal"
	events_label.text = ""
	for e: Dictionary in last_snapshot.events.slice(-4):
		events_label.text += "[color=#d2d9be]Day %d[/color]  %s\n" % [int(e.tick * Ecosystem.DT) + 1, e.detail]
	chart.history = last_snapshot.history
	chart.queue_redraw()
	experiment.visible = sim.state.parent != ""
	branch_button.text = "Branch again" if experiment.visible else "Branch experiment"
	pause_button.text = "▶  Resume" if paused else "Ⅱ  Pause"

func _process(delta: float) -> void:
	# A long gap is a sleep/suspension, not a backlog of ecological work.
	if delta > 1.0:
		return
	if not paused:
		accumulator += delta * speed
		var started: int = Time.get_ticks_usec()
		while accumulator >= STEP_SECONDS and Time.get_ticks_usec() - started < 6000:
			sim.step()
			accumulator -= STEP_SECONDS
	refresh_clock += delta
	autosave_clock += delta
	if refresh_clock > 0.3:
		_refresh()
		refresh_clock = 0
	if autosave_clock > 60:
		if not screenshot_mode:
			_save()
		autosave_clock = 0
	if screenshot_mode:
		_qa(delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_pause()
		if event.keycode == KEY_S and event.meta_pressed:
			_save()
		if event.keycode == KEY_ESCAPE:
			view.follow = false
			selected = -1
			_refresh()

func _select(id: int) -> void:
	selected = id
	_refresh()

func _lake(point: Vector2) -> void:
	underwater.lake_point = point
	_refresh()

func _toggle_pause() -> void:
	paused = not paused
	_refresh()

func _save() -> void:
	if screenshot_mode:
		return
	var err: Error = SaveStore.save_world(save_path, sim)
	status_label.text = "Saved · " + sim.state.world_id if err == OK else "Save failed: " + error_string(err)

func _open_dialog() -> void:
	file_dialog.popup_centered_ratio(0.7)

func _load(path: String) -> void:
	var loaded: Dictionary = SaveStore.load_world(path)
	if loaded.is_empty() or not sim.restore(loaded.state):
		status_label.text = "Could not load this world; your current world is unchanged."
		return
	save_path = path
	accumulator = 0
	selected = -1
	view.positions.clear()
	underwater.positions.clear()
	view.follow = false
	rain_slider.set_value_no_signal(sim.state.rain_scale)
	_refresh()
	status_label.text = "Loaded verified backup" if loaded.backup else "Resumed · " + sim.state.world_id

func _branch() -> void:
	if screenshot_mode:
		return
	var err: Error = SaveStore.save_world(save_path, sim)
	if err != OK:
		status_label.text = "Could not preserve parent; branch cancelled."
		return
	var child := Ecosystem.new()
	child.restore(sim.export_state())
	var name: String = "experiment-%d" % Time.get_unix_time_from_system()
	child.branch(name)
	var path: String = "user://" + name + ".world"
	err = SaveStore.save_world(path, child)
	if err != OK:
		status_label.text = "Could not save branch; original world remains active."
		return
	sim = child
	save_path = path
	paused = true
	_refresh()
	status_label.text = "Experiment paused · original preserved · change conditions, then Resume"

func _command(command: Dictionary) -> void:
	if sim.intervene(command):
		status_label.text = "Recorded experiment · " + JSON.stringify(command)
		_refresh()
		_save()

func _population(amount: int) -> void:
	_command({"kind": "population", "species": Ecosystem.SPECIES.keys()[species_option.selected], "value": amount})

func _help() -> void:
	help_panel.popup_centered(Vector2i(600, 550))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not screenshot_mode:
			var err: Error = SaveStore.save_world(save_path, sim)
			if err != OK:
				status_label.text = "Exit cancelled: save failed. " + error_string(err)
				return
		get_tree().quit()

func _ambient_sound() -> void:
	# Synthesized quiet wind/water, generated with an independent RNG.
	var audio_rng := RandomNumberGenerator.new()
	audio_rng.seed = 42
	var bytes := PackedByteArray()
	var length: int = 22050 * 8
	bytes.resize(length * 2)
	var low: float = 0
	for i in length:
		low = low * 0.97 + audio_rng.randf_range(-1, 1) * 0.03
		var envelope: float = sin(PI * float(i) / length)
		var sample: int = int((low * 0.24 + sin(i * 0.003) * 0.004) * envelope * 32767)
		bytes.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = length
	sound = AudioStreamPlayer.new()
	sound.stream = stream
	sound.volume_db = -19
	add_child(sound)
	sound.play()

func _qa(delta: float) -> void:
	qa_clock += delta
	if qa_clock > 3 and qa_clock < 13:
		fps_samples.append(1.0 / maxf(delta, 0.00001))
	if qa_clock > 14 and qa_clock < 15:
		qa_clock = 15
		_capture("overview")
		_select(151)
		view.zoom = 1.7
		view.follow = true
		_lake(Ecosystem.CENTER)
	if qa_clock > 18 and qa_clock < 19:
		qa_clock = 19
		_capture("inspection")
		var total: float = 0
		for fps: float in fps_samples:
			total += fps
		var f := FileAccess.open("user://qa-performance.json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"mean_fps": total / maxf(1, fps_samples.size()), "frames": fps_samples.size(), "animals": sim.counts(), "renderer": RenderingServer.get_video_adapter_name()}, "  "))
	if qa_clock > 22:
		if "--qa-ecology" in OS.get_cmdline_user_args():
			_qa_ecology()
		else:
			get_tree().quit()

func _qa_ecology() -> void:
	if qa_capture_pending:
		return
	qa_capture_pending = true
	paused = true
	sim.step()
	var capture_name: String = ""
	var season: int = int(fmod(sim.state.tick * Ecosystem.DT, 365.0) / 91.25)
	var season_key: String = ["spring", "summer", "autumn", "winter"][season]
	if not qa_observations.has(season_key):
		qa_observations[season_key] = {"tick": sim.state.tick}
		view.follow = false
		view.zoom = 1
		view.pan = Vector2.ZERO
		capture_name = season_key
	for a: Dictionary in sim.state.animals:
		if a.alive and a.activity in ["Feeding", "Pursuing prey", "Hiding / fleeing", "Breeding"] and not qa_observations.has(a.activity) and capture_name.is_empty():
			qa_observations[a.activity] = {"id": a.id, "tick": sim.state.tick}
			selected = a.id
			view.follow = true
			view.zoom = 2.4
			view.pan = (Vector2(Ecosystem.WIDTH, Ecosystem.HEIGHT) * 0.5 - Vector2(a.x, a.y)) * view.scale_factor()
			capture_name = a.activity.to_lower().replace(" / ", "-").replace(" ", "-")
			break
	_refresh()
	if not capture_name.is_empty():
		view.positions.clear()
		underwater.positions.clear()
		view.queue_redraw()
		underwater.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		_capture(capture_name)
		# The cutaway is a filtered projection of the exact landscape snapshot.
		var expected: Array[int] = []
		for a: Dictionary in last_snapshot.animals:
			if a.alive and sim.aquatic(a) and absf(a.x - underwater.lake_point.x) <= 230 and absf(a.y - underwater.lake_point.y) <= 180:
				expected.append(int(a.id))
		if expected != underwater.visible_ids:
			qa_view_failures.append("Cutaway mismatch at tick %d" % sim.state.tick)
	qa_capture_pending = false
	if sim.state.tick >= 1100:
		var f := FileAccess.open("user://qa-ecology.json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"observations": qa_observations, "view_failures": qa_view_failures}, "  "))
		get_tree().quit(0 if qa_view_failures.is_empty() and qa_observations.size() == 8 else 1)

func _capture(name: String) -> void:
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png("user://qa-" + name + ".png")
