extends "res://tests/qa_capture.gd"
## Exact same two-size scenario as the full capture suite; layout mode is
## explicit and never presented as actual rendered screenshots.


func _run_profile(tag: String, vp: Vector2i, _scale: int) -> void:
	var holder: SubViewport = SubViewport.new()
	holder.size = vp
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	await _run_market_foraging(holder, tag, vp)
	holder.queue_free()
	await _frames(2)
