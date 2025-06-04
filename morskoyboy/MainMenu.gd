# res://MainMenu.gd
extends Control

func _ready() -> void:
	$VBoxContainer/PlayBotButton.connect("pressed", Callable(self, "_on_PlayBotButton_pressed"))
	$VBoxContainer/PlayOnlineButton.connect("pressed", Callable(self, "_on_PlayOnlineButton_pressed"))
	$VBoxContainer/SettingsButton.connect("pressed", Callable(self, "_on_SettingsButton_pressed"))
	$VBoxContainer/ExitButton.connect("pressed", Callable(self, "_on_ExitButton_pressed"))

	if has_node("MusicPlayer"):
		$MusicPlayer.play()

func _on_PlayBotButton_pressed() -> void:
	# В этом случае мы просто идём в Game.tscn, и там играем против бота (если у вас есть алгоритм бота)
	get_tree().change_scene_to_file("res://Game.tscn")

func _on_PlayOnlineButton_pressed() -> void:
	# Переходим в Lobby
	get_tree().change_scene_to_file("res://Lobby.tscn")

func _on_SettingsButton_pressed() -> void:
	get_tree().change_scene_to_file("res://Settings.tscn")

func _on_ExitButton_pressed() -> void:
	get_tree().quit()
