# res://Settings.gd
extends Control

@onready var volume_slider: HSlider = $VBoxContainer/VolumeSlider

func _ready() -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	volume_slider.connect("value_changed", Callable(self, "_on_VolumeSlider_value_changed"))
	$VBoxContainer/BackButton.connect("pressed", Callable(self, "_on_BackButton_pressed"))

	if has_node("MusicPlayer"):
		$MusicPlayer.play()

func _on_VolumeSlider_value_changed(val: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val))

func _on_BackButton_pressed() -> void:
	get_tree().change_scene_to_file("res://mainmenu.tscn")
