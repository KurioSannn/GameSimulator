extends SceneTree
## Ending calibration entry point (not part of the regression suite); logic in calibrate_endings_impl.gd.
##   tools/Godot.app/Contents/MacOS/Godot --headless --path game -s res://tests/calibrate_endings.gd


func _initialize() -> void:
	load("res://tests/calibrate_endings_impl.gd").new().run()
	quit()
