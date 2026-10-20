extends "res://tests/qa_capture.gd"
## Focused execution of the identical scenario also included in the full suite.
## It never substitutes a headless layout result for actual rendering evidence.


func _run_profile(tag: String, vp: Vector2i, _expect_scale: int) -> void:
	var holder: SubViewport = SubViewport.new()
	holder.size = vp
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	await _run_investment_preview(holder, tag, vp)
	holder.queue_free()
	await _frames(2)
