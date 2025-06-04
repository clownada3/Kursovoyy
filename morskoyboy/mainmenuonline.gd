# res://MainMenuOnline.gd
extends Control

func _ready() -> void:
	$VBoxContainer/HostButton.connect("pressed", Callable(self, "_on_HostButton_pressed"))
	$VBoxContainer/JoinButton.connect("pressed", Callable(self, "_on_JoinButton_pressed"))

func _on_HostButton_pressed() -> void:
	get_tree().change_scene_to_file("res://Lobby.tscn")

func _on_JoinButton_pressed() -> void:
	get_tree().change_scene_to_file("res://Lobby.tscn")
