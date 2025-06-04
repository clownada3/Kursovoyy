# Bot.gd
extends Node

const FIELD_SIZE: int = 10
var bot_targets: Array = []

func _ready() -> void:
	randomize()
	_initialize_bot_targets()

func _initialize_bot_targets() -> void:
	bot_targets.clear()
	for y in range(FIELD_SIZE):
		for x in range(FIELD_SIZE):
			bot_targets.append(Vector2(x, y))

func bot_move() -> void:
	var game_scene = get_tree().get_current_scene() as Node
	if game_scene == null or not game_scene.has_method("process_shot"):
		push_error("Bot.gd: Не найден метод process_shot в Game!")
		return

	# Фильтруем уже посещённые клетки (2 = подбитая, 3 = промах)
	var new_targets: Array = []
	for coord in bot_targets:
		var x = int(coord.x)
		var y = int(coord.y)
		var grid_val = game_scene.player_grid[y][x]
		if grid_val == 0 or grid_val == 1:
			new_targets.append(coord)
	bot_targets = new_targets.duplicate()

	if bot_targets.size() == 0:
		return

	var rnd_idx = randi() % bot_targets.size()
	var target = bot_targets[rnd_idx]
	var tx = int(target.x)
	var ty = int(target.y)
	bot_targets.remove_at(rnd_idx)

	print("Bot.gd: Ход бота в клетку [%d, %d]" % [tx, ty])

	# Вызываем process_shot и получаем, попал ли бот
	var was_hit: bool = game_scene.process_shot(tx, ty)
	if was_hit:
		# Если попал, ждём 0.5 секунды и стреляет снова
		await get_tree().create_timer(0.5).timeout
		bot_move()
	# Если промах – process_shot внутри Game вернёт игроку ход, и бот остановится
