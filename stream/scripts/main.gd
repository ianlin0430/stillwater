extends Control

const STEP: float = 0.2
const CREAM: Color = Color("e0e5d7")
const MUTED: Color = Color("a0b3aa")
const PersistQA=preload("res://scripts/persist_qa.gd")
const Absence=preload("res://scripts/absence.gd")
var world: StreamWorld
var viewport: SubViewport
var stage: StreamStage
var display: TextureRect
var title: Label
var status: Label
var climate: Label
var inspector: PanelContainer
var notes: RichTextLabel
var pause_button: Button
var light_button: Button
var help_panel: PanelContainer
var selected: int = -1
var paused: bool = false
var suspended_view: bool = false
var focused: bool = true
var viewing_light: bool = false
var last_wall: float = 0
var last_ticks: int = 0
var started_ticks: int = 0
var shown_ticks: int = -1
var save_clock: float = 0
var ui_clock: float = 0
var save_path: String = StreamStore.DEFAULT_PATH
var qa: bool = false
var qa_clock: float = 0
var qa_duration: float = 0
var qa_capture: bool = false
var qa_frames: Array[float] = []
var away_text: String = ""
var away_until: float = 0
var absence: Dictionary = {}
var absence_elapsed: float = 0
var settings: ConfigFile = ConfigFile.new()
var failure_status: String = ""
var qa_snapshots: Dictionary = {}
var recording: bool = false
var capture_pending: bool = false
var qa_drawn_frames: int = 0
var qa_visible_seconds: float = 0
var qa_hidden_seconds: float = 0
var qa_focused_seconds: float = 0
var qa_progress_at: float = 0
var prefs_path: String = "user://preferences.cfg"
var persist_dir: String = ""
var persist_log: Dictionary = {}
# Feed / tap / lure wiring (world API, docs/BACKEND_SNAPSHOT_EVENTS.md). Pointer in world coords.
const LURE_REST: float = 1.5
var pointer: Vector2 = Vector2(-1,-1)
var pointer_rest: float = 0
var notice_text: String = ""
var notice_until: float = 0

func _ready() -> void:
	Engine.max_fps=30
	Engine.physics_ticks_per_second=10
	get_tree().auto_accept_quit=false
	DisplayServer.window_set_min_size(Vector2i(900,620))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	qa="--qa" in args
	recording="--record" in args
	qa_duration=55.0 if qa else 0.0
	for arg: String in args:
		if arg.begins_with("--duration="):
			qa_duration=float(arg.trim_prefix("--duration="))
	last_wall=Time.get_unix_time_from_system()
	last_ticks=Time.get_ticks_msec()
	started_ticks=last_ticks
	for arg: String in args:
		if arg.begins_with("--persist-qa="):
			var run_id: String=arg.trim_prefix("--persist-qa=")
			if qa or not PersistQA.valid_run_id(run_id):
				printerr("Stillwater: invalid --persist-qa run id (need [A-Za-z0-9_-]+, no --qa)")
				set_process(false)
				get_tree().quit(1)
				return
			persist_dir=PersistQA.dir_for(run_id)
			prefs_path=persist_dir+"preferences.cfg"
			DirAccess.make_dir_recursive_absolute(persist_dir)
	if qa:
		world=StreamWorld.new(240921,last_wall)
	else:
		settings.load(prefs_path)
		viewing_light=settings.get_value("view","light",false)
		var path: String = settings.get_value("world","path",StreamStore.DEFAULT_PATH) if persist_dir.is_empty() else persist_dir+"stream.world"
		if not persist_dir.is_empty():
			var pre: Dictionary=StreamStore.read(path)
			persist_log={"mode":"persist-qa","launch":PersistQA.next_launch(persist_dir),"path":ProjectSettings.globalize_path(path),"preferences":ProjectSettings.globalize_path(prefs_path),"wall":last_wall,"pre":{"digest":PersistQA.digest(pre),"summary":PersistQA.summary(pre)}}
			PersistQA.write(persist_dir+"launch-%d.json" % persist_log.launch,persist_log)
		var loaded: Dictionary = StreamStore.load_or_create(path,last_wall)
		world=loaded.world
		save_path=loaded.path
		if loaded.error!=OK:
			failure_status="Could not save: "+error_string(loaded.error)+". Your previous save is preserved."
		if loaded.preserved:
			failure_status="Unreadable world preserved. A new world uses a separate recovery file."
		elif loaded.backup:
			failure_status="Recovered the previous verified save."
		_set_away(loaded.away)
		settings.set_value("world","path",save_path)
		settings.save(prefs_path)
		if not persist_dir.is_empty():
			var post: Dictionary=world.export_state()
			persist_log.post={"digest":PersistQA.digest(post),"summary":PersistQA.summary(post),"lost":PersistQA.lost(persist_log.pre.summary,post),"away":loaded.away,"saved_path":ProjectSettings.globalize_path(save_path),"backup":loaded.backup,"preserved":loaded.preserved,"error":loaded.error}
			PersistQA.write(persist_dir+"launch-%d.json" % persist_log.launch,persist_log)
	print("Stillwater: mode=%s path=%s" % ["qa" if qa else "normal" if persist_dir.is_empty() else "persist-qa","(none)" if qa else ProjectSettings.globalize_path(save_path)])
	_setup_ui()
	if qa:
		RenderingServer.frame_post_draw.connect(_qa_frame_drawn)
	_update_biological_clock()
	_refresh()

func _setup_ui() -> void:
	var theme_new := Theme.new()
	var font := SystemFont.new()
	font.font_names=PackedStringArray(["Avenir Next","Helvetica Neue","sans-serif"])
	theme_new.default_font=font
	theme_new.default_font_size=14
	theme_new.set_color("font_color","Label",CREAM)
	for kind: String in ["Button","CheckButton"]:
		for state_name: String in ["normal","hover","pressed","focus","disabled"]:
			var box := StyleBoxFlat.new()
			box.bg_color=Color("29423e") if state_name in ["hover","pressed"] else Color("172c29")
			box.set_corner_radius_all(4)
			box.content_margin_left=12
			box.content_margin_right=12
			box.content_margin_top=7
			box.content_margin_bottom=7
			if state_name=="focus":
				box.set_border_width_all(1)
				box.border_color=Color("a3c8cc")
			theme_new.set_stylebox(state_name,kind,box)
			theme_new.set_color("font_color",kind,CREAM)
	theme=theme_new
	var base := VBoxContainer.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.add_theme_constant_override("separation",0)
	add_child(base)
	var header_margin := MarginContainer.new()
	for side: String in ["left","right"]:
		header_margin.add_theme_constant_override("margin_"+side,24)
	header_margin.add_theme_constant_override("margin_top",12)
	header_margin.add_theme_constant_override("margin_bottom",12)
	base.add_child(header_margin)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",10)
	header_margin.add_child(header)
	title=_label("Stillwater",24)
	var serif := SystemFont.new()
	serif.font_names=PackedStringArray(["Georgia","serif"])
	title.add_theme_font_override("font",serif)
	header.add_child(title)
	var subtitle: Label = _label("REEF",10,MUTED)
	subtitle.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	header.add_child(subtitle)
	var spacer := Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	climate=_label("",12,MUTED)
	header.add_child(climate)
	light_button=_button("Viewing light",_toggle_light,"L · illuminate the view without changing the animals’ clock")
	light_button.toggle_mode=true
	light_button.button_pressed=viewing_light
	header.add_child(light_button)
	pause_button=_button("Pause",_toggle_pause,"Space · pause observation")
	header.add_child(pause_button)
	header.add_child(_button("−",func() -> void: _zoom(-0.15),"Zoom out · minus"))
	header.add_child(_button("+",func() -> void: _zoom(0.15),"Zoom in · plus"))
	header.add_child(_button("?",func() -> void: help_panel.visible=not help_panel.visible,"Controls and this world"))
	viewport=SubViewport.new()
	viewport.size=Vector2i(960,540)
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.canvas_transform=Transform2D(Vector2(0.75,0),Vector2(0,0.75),Vector2.ZERO)
	stage=StreamStage.new()
	viewport.add_child(stage)
	display=TextureRect.new()
	display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	display.texture=viewport.get_texture()
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.size_flags_vertical=Control.SIZE_EXPAND_FILL
	display.gui_input.connect(_scene_input)
	base.add_child(display)
	var footer := MarginContainer.new()
	footer.add_theme_constant_override("margin_left",24)
	footer.add_theme_constant_override("margin_right",24)
	footer.add_theme_constant_override("margin_top",10)
	footer.add_theme_constant_override("margin_bottom",10)
	base.add_child(footer)
	status=_label("",12,MUTED)
	status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(status)
	inspector=_panel(Vector2(24,88),Vector2(268,245))
	var box := VBoxContainer.new()
	inspector.add_child(box)
	notes=RichTextLabel.new()
	notes.bbcode_enabled=true
	notes.fit_content=true
	notes.scroll_active=false
	notes.custom_minimum_size=Vector2(236,150)
	notes.add_theme_color_override("default_color",CREAM)
	box.add_child(notes)
	box.add_child(_button("Close",func() -> void: _select(-1),"Escape"))
	inspector.hide()
	help_panel=_panel(Vector2(24,88),Vector2(420,300))
	var help_box := VBoxContainer.new()
	help_panel.add_child(help_box)
	var help_text := Label.new()
	help_text.text="A small reef beneath the surface\n\nClick an animal to read its story.\nDrag through water or plants to feel the current.\nR makes a ripple without the mouse.\nClick Feed, or press F, for a pinch of food (a few pinches a day).\nClick Tap, or press T, to tap the glass.\nRest the pointer in the water and curious fish may come to look.\nScroll or use + / − to look closer. Tab selects the next animal.\nSpace pauses; Escape returns to the whole pool.\nL switches the viewing light.\n\nNatural food, arrivals, births and departures need no care;\nfeeding is a treat, never required.\nThe world advances while you’re away, up to three days.\nNothing runs on your Mac after you quit.\n\nReal species, a fictional shared habitat.\nQuiet mode: 30 FPS. Saves are automatic."
	help_text.add_theme_font_size_override("font_size",13)
	help_box.add_child(help_text)
	help_box.add_child(_button("Back to the reef",func() -> void: help_panel.hide()))
	help_panel.hide()

func _label(text: String, font_size: int, color: Color=CREAM) -> Label:
	var label := Label.new()
	label.text=text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	return label

func _button(text: String, action: Callable, tip: String="") -> Button:
	var button := Button.new()
	button.text=text
	button.tooltip_text=tip
	button.pressed.connect(action)
	button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	return button

func _panel(at: Vector2, minimum: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position=at
	panel.custom_minimum_size=minimum
	var style := StyleBoxFlat.new()
	style.bg_color=Color("182d29")
	style.set_corner_radius_all(6)
	style.content_margin_left=16
	style.content_margin_right=16
	style.content_margin_top=14
	style.content_margin_bottom=14
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	return panel

func _scene_input(event: InputEvent) -> void:
	# Frontend-only interactions. Mouse coordinates account for letterboxing and zoom.
	var fit: float=minf(display.size.x/1280,display.size.y/720)
	if fit<=0: return
	var offset: Vector2=(display.size-Vector2(1280,720)*fit)/2
	if event is InputEventMouse:
		var point: Vector2=(event.position-offset)/fit
		_world_pointer(event,point)
		if not Rect2(0,0,1280,720).has_point(point): return
		if event is InputEventMouseMotion:
			display.tooltip_text=stage.describe_environment(point)
			if not stage.control_at(point).is_empty(): pointer=Vector2(-1,-1)
			if not paused and stage.control_at(point).is_empty() and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
				stage.interact(point,clampf(event.relative.length()/12.0,0.2,1.0))
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index==MOUSE_BUTTON_WHEEL_UP:
				_zoom(0.10)
			elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(-0.10)
			elif event.button_index==MOUSE_BUTTON_LEFT:
				var action: String=stage.control_at(point)
				if not action.is_empty():
					if paused: return
					if action=="feed":
						var previous_food: int=world.state.get("food",[]).size()
						_feed()
						if world.state.get("food",[]).size()==previous_food:
							stage.interaction_layer.show_full()
					else:
						world.startle(stage.center.x,stage.center.y,1.0)
						stage.tap_feedback(Vector2(640,360))
					return
				var hit: int=stage.pick(point)
				_select(hit)
				if hit<0 and not paused: stage.interact(point)

# Backend interactions only (Codex: keep this call in _scene_input; draw the cues yourself).
# Tracks the pointer for the lure and F, and turns a click on the frame into a glass tap.
func _world_pointer(event: InputEventMouse, point: Vector2) -> void:
	var at: Vector2=(point-stage.position)/stage.zoom
	var inside: bool=Rect2(0,0,1280,720).has_point(point)
	if event is InputEventMouseMotion:
		pointer=at if inside and at.y>StreamWorld.FOOD.surface and at.y<StreamWorld.floor_y(at.x) else Vector2(-1,-1)
		pointer_rest=0
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not inside and not paused:
		world.startle(clampf(at.x,0,1280),clampf(at.y,0,720),1.0)

func _feed() -> void:
	if paused: return
	if not world.feed(pointer.x if pointer.x>=0 else 640.0):
		notice_text="They’re full for today — natural food keeps them going."
		notice_until=qa_clock+4
		_refresh()

func _update_lure(delta: float) -> void:
	pointer_rest+=delta
	if pointer.x>=0 and pointer_rest>=LURE_REST and not paused and not suspended_view:
		world.set_lure(pointer)
	else:
		world.clear_lure()

func _select(id: int) -> void:
	if id>=0 and not id in stage.visible_ids(): id=-1
	selected=id
	stage.selected=id
	inspector.visible=id>=0
	help_panel.hide()
	_refresh_info()

func _zoom(amount: float) -> void:
	stage.zoom=clampf(stage.zoom+amount,1,1.65)
	if selected>=0 and stage.rigs.has(selected):
		stage.center=stage.rigs[selected].position
	if stage.zoom<=1:
		stage.center=Vector2(640,360)

func _toggle_light() -> void:
	viewing_light=not viewing_light
	light_button.button_pressed=viewing_light
	if not qa:
		settings.set_value("view","light",viewing_light)
		settings.save(prefs_path)
	_refresh()

func _toggle_pause() -> void:
	paused=not paused
	pause_button.text="Resume" if paused else "Pause"
	_refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_toggle_pause()
				get_viewport().set_input_as_handled()
			KEY_L:
				_toggle_light()
				get_viewport().set_input_as_handled()
			KEY_EQUAL,KEY_PLUS:
				_zoom(0.15)
			KEY_MINUS:
				_zoom(-0.15)
			KEY_ESCAPE:
				_select(-1)
				stage.zoom=1
				stage.center=Vector2(640,360)
			KEY_R:
				if not paused: stage.interact(Vector2(640,360))
				get_viewport().set_input_as_handled()
			KEY_F:
				_feed()
				get_viewport().set_input_as_handled()
			KEY_T:
				if not paused: world.startle(pointer.x if pointer.x>=0 else 640.0,pointer.y if pointer.x>=0 else 360.0,1.0)
				get_viewport().set_input_as_handled()
			KEY_TAB:
				var ids: Array[int]=stage.visible_ids()
				if not event.shift_pressed and not ids.is_empty():
					_select(ids[(ids.find(selected)+1)%ids.size()])
					get_viewport().set_input_as_handled()

func _refresh_info() -> void:
	if selected<0:
		return
	var found: Dictionary={}
	for a: Dictionary in world.state.animals+world.state.archive:
		if a.id==selected:
			found=a
			break
	if found.is_empty():
		notes.text="This animal’s detailed record has aged out of the journal."
		return
	var cfg: Dictionary=StreamWorld.SPECIES[found.species]
	var text: String="[font_size=20]"+found.name+"[/font_size]\n[color=#a0b3aa]"+cfg.label+" · #"+str(found.id)+"[/color]\n\n"
	text+=("Young" if found.age<cfg.mature else "Adult")+" · "+str(int(found.age))+" days old\n"
	text+=found.activity if not found.has("cause") else "Left the pool" if found.cause=="departure" else "Died: "+found.cause
	if found.parent>0:
		text+="\nParent #"+str(found.parent)
	text+="\n"
	for e: Dictionary in found.recent.slice(-2):
		text+="\n[color=#a0b3aa]"+e.text+"[/color]"
	notes.text=text

func _update_biological_clock() -> void:
	var local: Dictionary=Time.get_datetime_dict_from_system()
	world.state.light_hour=local.hour+local.minute/60.0

func _refresh() -> void:
	stage.apply_snapshot(world.snapshot())
	var local: Dictionary=Time.get_datetime_dict_from_system()
	var hour: float=local.hour+local.minute/60.0
	stage.natural_light=clampf(sin((hour-6)/12*PI),0,1)
	stage.viewing_light=viewing_light
	climate.text=("Night" if hour<6 or hour>=20 else "Evening" if hour>=17 else "Morning" if hour<11 else "Daylight")+" · "+str(stage.visible_ids().size())+" fish in view"
	status.text="Click a creature · Drag water or plants to explore · Scroll to look closer" if not paused else "Paused · the reef will continue when you resume"
	if qa_clock<away_until and not away_text.is_empty():
		status.text=away_text
	if qa_clock<notice_until:
		status.text=notice_text
	if not failure_status.is_empty():
		status.text=failure_status
	_refresh_info()

func _set_away(report: Dictionary) -> void:
	var text: String=Absence.text(report)
	if text.is_empty():
		return
	away_text=text
	away_until=qa_clock+30

func _save() -> bool:
	if qa:
		return true
	var now: float=Time.get_unix_time_from_system()
	if suspended_view and not paused:
		Absence.advance(absence,world,now)
	world.state.wall_checkpoint=maxf(world.state.wall_checkpoint,now)
	var err: Error=StreamStore.save(save_path,world)
	if err!=OK:
		failure_status="Save failed: "+error_string(err)+". Previous save preserved."
		return false
	return true

func _process(delta: float) -> void:
	var ticks: int=Time.get_ticks_msec()
	var now: float=Time.get_unix_time_from_system()
	var gap: float=(ticks-last_ticks)/1000.0
	last_ticks=ticks
	qa_clock=(ticks-started_ticks)/1000.0
	var should_hide: bool=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED or not DisplayServer.window_can_draw()
	if "--hidden-test" in OS.get_cmdline_user_args():
		should_hide=qa_clock>8
	if "--hide-cycle" in OS.get_cmdline_user_args():
		should_hide=qa_clock>8 and qa_clock<18
	if should_hide!=suspended_view:
		_set_suspended_view(should_hide)
	if qa and qa_clock>5:
		var measured_gap: float=maxf(0,gap)
		if suspended_view:
			qa_hidden_seconds+=measured_gap
		else:
			qa_visible_seconds+=measured_gap
			if DisplayServer.window_is_focused():
				qa_focused_seconds+=measured_gap
		if qa_clock-qa_progress_at>=60:
			var progress:=FileAccess.open("user://qa-progress.json",FileAccess.WRITE)
			progress.store_string(JSON.stringify({"seconds":qa_clock,"visible_seconds":qa_visible_seconds,"hidden_seconds":qa_hidden_seconds,"focused_seconds":qa_focused_seconds,"drawn_frames":qa_drawn_frames}))
			qa_progress_at=qa_clock
	if suspended_view:
		if not paused and now-absence.since-absence.simulated>=60:
			Absence.advance(absence,world,now)
		if qa and qa_duration>0 and qa_clock>=qa_duration:
			_finish_qa()
		return
	if maxf(gap,now-last_wall)>2.0 and not paused:
		var report: Dictionary=world.advance_offline(maxf(0,now-last_wall))
		_set_away(report)
		_save()
		_refresh()
	elif not paused:
		world.advance_live(minf(delta,0.25))
	_update_lure(delta)
	last_wall=now
	ui_clock+=delta
	save_clock+=delta
	if world.state.motion_ticks!=shown_ticks:
		stage.apply_snapshot(world.snapshot())
		shown_ticks=world.state.motion_ticks
	if not paused:
		stage.animate(minf(delta,0.1))
	else:
		stage.animate(0)
	if ui_clock>=2:
		_update_biological_clock()
		_refresh()
		ui_clock=0
	if save_clock>=60:
		_save()
		save_clock=0
	if qa:
		_qa(delta)

func _set_suspended_view(value: bool) -> void:
	suspended_view=value
	if not persist_dir.is_empty():
		print("Stillwater: persist-qa suspended_view=%s at %.1f" % [value,Time.get_unix_time_from_system()])
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED if suspended_view else SubViewport.UPDATE_ALWAYS
	if suspended_view:
		absence=Absence.fresh(Time.get_unix_time_from_system())
		absence_elapsed=world.state.elapsed
		# Keep AppKit event/Accessibility delivery responsive while rendering is off.
		Engine.max_fps=10
		RenderingServer.render_loop_enabled=false
		_save()
	else:
		if not paused:
			# One summary for the whole absence, including every advance made while hidden.
			_set_away(Absence.advance(absence,world,Time.get_unix_time_from_system()))
		if not persist_dir.is_empty():
			PersistQA.write(persist_dir+"absence-%d.json" % PersistQA.next_index(persist_dir,"absence"),{"launch":persist_log.get("launch",0),"resumed":Time.get_unix_time_from_system(),"paused":paused,"absence":absence,"elapsed_at_hide":absence_elapsed,"elapsed_at_resume":world.state.elapsed,"away_text":away_text})
		last_wall=Time.get_unix_time_from_system()
		last_ticks=Time.get_ticks_msec()
		Engine.max_fps=30
		RenderingServer.render_loop_enabled=true
		_refresh()
		_save()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if _save():
			if not persist_dir.is_empty():
				var saved: Dictionary=world.export_state()
				PersistQA.write(persist_dir+"exit-%d.json" % persist_log.launch,{"reason":"wm_close_request","suspended_view":suspended_view,"focused":focused,"wall":Time.get_unix_time_from_system(),"digest":PersistQA.digest(saved),"summary":PersistQA.summary(saved)})
				print("Stillwater: persist-qa exit %d written" % persist_log.launch)
			get_tree().quit()
	elif what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused=false
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		focused=true

func _qa(delta: float) -> void:
	if qa_clock>5:
		qa_frames.append(delta)
	if qa_clock>6 and not qa_snapshots.has("overview"):
		qa_snapshots.overview=true
		_capture("overview")
	if qa_clock>10 and not qa_snapshots.has("select"):
		qa_snapshots.select=true
		_select(7)
		_zoom(0.65)
	if qa_clock>13 and not qa_snapshots.has("inspection"):
		qa_snapshots.inspection=true
		_capture("inspection")
	if qa_clock>17 and not qa_snapshots.has("light"):
		qa_snapshots.light=true
		_toggle_light()
		_select(-1)
		stage.zoom=1
		stage.center=Vector2(640,360)
	if qa_clock>20 and not qa_snapshots.has("lit"):
		qa_snapshots.lit=true
		_capture("lit")
	if qa_clock>25 and not qa_snapshots.has("shrimp"):
		qa_snapshots.shrimp=true
		_select(1)
		_zoom(0.65)
	if qa_clock>28 and not qa_snapshots.has("shrimp_capture"):
		qa_snapshots.shrimp_capture=true
		_capture("shrimp")
	if qa_clock>32 and not qa_snapshots.has("fish"):
		qa_snapshots.fish=true
		_select(12)
		stage.center=stage.rigs[12].position
	if qa_clock>35 and not qa_snapshots.has("fish_capture"):
		qa_snapshots.fish_capture=true
		_capture("fish")
	if qa_clock>40 and not qa_snapshots.has("reset"):
		qa_snapshots.reset=true
		_select(-1)
		stage.zoom=1
		stage.center=Vector2(640,360)
	if qa_duration>0 and qa_clock>=qa_duration:
		_finish_qa()

func _capture(name: String) -> void:
	if capture_pending:
		return
	capture_pending=true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://qa-"+name+".png")
	capture_pending=false

func _finish_qa() -> void:
	qa_frames.sort()
	var total: float=0
	for value: float in qa_frames:
		total+=value
	var data: Dictionary={"seconds":qa_clock,"frames":qa_frames.size(),"mean_frame_ms":total/maxi(1,qa_frames.size())*1000,"p95_frame_ms":qa_frames[int(qa_frames.size()*0.95)]*1000 if not qa_frames.is_empty() else 0,"animals":world.counts(),"memory_static_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576,"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"suspended_view":suspended_view,"material_residual":world.residual(),"renderer":RenderingServer.get_video_adapter_name()}
	var file := FileAccess.open("user://qa-performance-hidden.json" if suspended_view else "user://qa-performance.json",FileAccess.WRITE)
	data.drawn_frames=qa_drawn_frames
	data.visible_seconds=qa_visible_seconds
	data.hidden_seconds=qa_hidden_seconds
	data.focused_seconds=qa_focused_seconds
	data.foreground_30_minute_eligible=qa_visible_seconds>=1800 and qa_focused_seconds>=1800 and qa_hidden_seconds<0.5 and qa_drawn_frames>=50400
	file.store_string(JSON.stringify(data,"  "))
	print(JSON.stringify(data))
	get_tree().quit()

func _qa_frame_drawn() -> void:
	if qa_clock>5 and not suspended_view:
		qa_drawn_frames+=1
