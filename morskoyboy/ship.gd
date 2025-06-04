# res://Ship.gd
extends Node2D

@export var length: int = 1       # длина корабля (1..4)
var orientation: int = 0          # 0 = горизонтально, 1 = вертикально

func _ready() -> void:
	var texture_path = "res://sprites/ship_%d.png" % length
	if ResourceLoader.exists(texture_path):
		$Sprite2D.texture = load(texture_path)
		if orientation == 1:
			$Sprite2D.rotation_degrees = 90
	else:
		push_error("Ship.gd: Не удалось загрузить спрайт: %s" % texture_path)
