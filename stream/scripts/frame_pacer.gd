class_name FramePacer
extends RefCounted
# Event delivery stays responsive while hidden, but rendering is completely disabled.
static func mode(can_draw: bool, minimized: bool, focused: bool) -> int:
	return 0 if not can_draw or minimized else 60 if focused else 30
static func apply(fps: int) -> void:
	Engine.max_fps=10 if fps==0 else fps
	RenderingServer.render_loop_enabled=fps>0

# Eligibility comes from observed native state and actual post-draw callbacks.
# These flags do not replace CPU/RSS/thermal measurements in the package harness.
static func acceptance(data: Dictionary) -> Dictionary:
	var visible: float=float(data.get("visible_seconds",0))
	var focused: float=float(data.get("focused_seconds",0))
	var hidden: float=float(data.get("hidden_seconds",0))
	var frames: Dictionary=data.get("mode_drawn_frames",{})
	return {
		"foreground_30_minute_eligible":visible>=1800 and focused>=1800 and hidden<.5 and int(data.get("drawn_frames",0))>=100800,
		"background_30_minute_eligible":visible-focused>=1800 and int(frames.get("30",0))>=50400,
		"hidden_30_minute_eligible":hidden>=1800 and frames.has("0") and int(frames["0"])==0}
