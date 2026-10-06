class_name FramePacer
extends RefCounted
# Event delivery stays responsive while hidden, but rendering is completely disabled.
static func mode(can_draw: bool, minimized: bool, focused: bool) -> int:
	return 0 if not can_draw or minimized else 60 if focused else 30
static func apply(fps: int) -> void:
	Engine.max_fps=10 if fps==0 else fps
	RenderingServer.render_loop_enabled=fps>0
