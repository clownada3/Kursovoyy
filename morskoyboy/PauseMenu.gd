# res://PauseMenu.gd
extends CanvasLayer

func _ready():
	hide()  # Скрываем меню при старте

	# Подключаем кнопки: обратите внимание на путь
	$ColorRect/VBoxContainer/ResumeButton.connect("pressed", Callable(self, "_on_resume_button_pressed"))
	$ColorRect/VBoxContainer/MainMenuButton.connect("pressed", Callable(self, "_on_main_menu_button_pressed"))
	$ColorRect/VBoxContainer/QuitButton.connect("pressed", Callable(self, "_on_quit_button_pressed"))

func _on_resume_button_pressed() -> void:
	hide()
	get_tree().paused = false

func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
