extends CanvasLayer

func _ready():
	hide()  # Скрываем меню при запуске

func _on_resume_button_pressed():
	hide()
	get_tree().paused = false

func _on_main_menu_button_pressed():
	get_tree().paused = false
	get_tree().change_scene("res://MainMenu.tscn")  # Замените на путь к вашей сцене главного меню

func _on_quit_button_pressed():
	get_tree().quit()
