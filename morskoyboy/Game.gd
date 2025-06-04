# Game.gd
extends Node2D

# -------------------------------------------------------------------------
# Подключаем логику расстановки и класс бота
# -------------------------------------------------------------------------
const ShipPlacement = preload("res://ShipPlacement.gd")
const BotClass      = preload("res://Bot.gd")

# -------------------------------------------------------------------------
# Режимы игры
# -------------------------------------------------------------------------
const MODE_SINGLEPLAYER = 0
const MODE_NETWORK      = 1

# -------------------------------------------------------------------------
# Размер поля (10×10)
# -------------------------------------------------------------------------
const FIELD_SIZE: int = 10

# -------------------------------------------------------------------------
# Состояния игры
# -------------------------------------------------------------------------
enum GameState { PLACEMENT, WAITING_FOR_OPPONENT, BATTLE }
var state: int = GameState.PLACEMENT

# -------------------------------------------------------------------------
# Логические карты 10×10:
#   0 = пусто
#   1 = палуба
#   2 = подбитая палуба
#   3 = промах
# -------------------------------------------------------------------------
var player_grid: Array = []
var enemy_grid_logical: Array = []
var bot_grid: Array = []

# -------------------------------------------------------------------------
# Флаг: чей ход (true = игрок/хозяин, false = бот/противник)
# -------------------------------------------------------------------------
var player_turn: bool = true
var game_over:   bool = false

# -------------------------------------------------------------------------
# Режим игры: singleplayer или network
# -------------------------------------------------------------------------
var game_mode: int = MODE_SINGLEPLAYER

# -------------------------------------------------------------------------
# Для ручной расстановки игрока (последовательность кораблей: 4,3,3,2,2,2,1,1,1,1)
# -------------------------------------------------------------------------
var manual_ships: Array = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1]
var current_ship_index: int = 0

# -------------------------------------------------------------------------
# Данные по кораблям игрока и противника
# Каждый элемент: { "x": int, "y": int, "size": int, "dir": int, "hits": int }
# -------------------------------------------------------------------------
var player_ships_data: Array = []
var bot_ships_data:    Array = []
var enemy_ships_data:  Array = []

# -------------------------------------------------------------------------
# Сетевой флаг и peer
# -------------------------------------------------------------------------
var is_host: bool = false
var is_singleplayer: bool = false
var network_peer: ENetMultiplayerPeer = null
var got_enemy_ships: bool = false  # флаг, чтобы понять, что мы получили данные противника

# -------------------------------------------------------------------------
# onready‐ссылки на узлы (пути должны совпадать с деревом сцены Game.tscn)
# -------------------------------------------------------------------------
@onready var placement_panel: Control        = $PlacementPanel
@onready var btn_random: Button              = $PlacementPanel/HBoxContainer/RandomButton
@onready var btn_done: Button                = $PlacementPanel/HBoxContainer/DoneButton
@onready var lbl_place: Label                = $PlacementPanel/HBoxContainer/PlacementLabel

@onready var player_grid_node: GridContainer = $PlayerGrid
@onready var enemy_grid_node: GridContainer  = $EnemyGrid

@onready var wait_label: Label               = $WaitLabel
@onready var status_label: Label             = $StatusLabel

@onready var btn_menu: Button                = $MenuButton

@onready var endgame_layer: CanvasLayer      = $EndGameLayer
@onready var lbl_result: Label               = $EndGameLayer/ColorRect/VBoxContainer/ResultLabel
@onready var btn_rematch: Button             = $EndGameLayer/ColorRect/VBoxContainer/RematchButton
@onready var btn_exit_to_menu: Button        = $EndGameLayer/ColorRect/VBoxContainer/ExitToMenuButton

@onready var pause_menu: CanvasLayer         = $PauseMenu
@onready var music_player: AudioStreamPlayer2D = $MusicPlayer

var bot_instance: Node = null

func _ready() -> void:
	randomize()

	# 1) Инициализируем пустые карты 10×10
	var sp = ShipPlacement.new()
	player_grid = sp.initialize_grid()
	bot_grid     = sp.initialize_grid()
	enemy_grid_logical = sp.initialize_grid()

	# 2) Проверяем наличие сетевого peer → если нет, играем против бота
	network_peer = get_multiplayer().get_multiplayer_peer() as ENetMultiplayerPeer
	if network_peer == null:
		is_singleplayer = true
		is_host = true
		game_mode = MODE_SINGLEPLAYER
		status_label.text = "Игра против бота. Расставьте корабли."
	else:
		is_singleplayer = false
		is_host = get_multiplayer().is_server()
		game_mode = MODE_NETWORK
		if is_host:
			status_label.text = "Вы хост. Расставьте корабли."
		else:
			status_label.text = "Вы клиент. Расставьте корабли."
		# Сетевые сигналы
		get_multiplayer().peer_connected.connect(_on_peer_connected)
		get_multiplayer().peer_disconnected.connect(_on_peer_disconnected)
		get_multiplayer().connection_failed.connect(_on_connection_failed)
		get_multiplayer().server_disconnected.connect(_on_server_disconnected)

	# 3) На старте фаза PLACEMENT: показываем панель расстановки
	placement_panel.visible = true
	btn_done.disabled = true
	wait_label.visible = false
	enemy_grid_node.visible = false
	endgame_layer.visible = false
	pause_menu.hide()

	# 4) Подключаем кнопки панели расстановки
	btn_random.connect("pressed", Callable(self, "_on_RandomButton_pressed"))
	btn_done.connect("pressed", Callable(self, "_on_DoneButton_pressed"))

	# 5) Подключаем gui_input ко всем кнопкам PlayerGrid
	_connect_player_grid_buttons()

	# 6) Подключаем сигналы EnemyGrid один раз и отключаем их
	_connect_enemy_grid_buttons_once()

	# 7) Кнопка «Меню»
	btn_menu.connect("pressed", Callable(self, "_on_MenuButton_pressed"))

	# 8) Кнопки конца игры
	btn_rematch.connect("pressed", Callable(self, "_on_RematchButton_pressed"))
	btn_exit_to_menu.connect("pressed", Callable(self, "_on_ExitToMenuButton_pressed"))

	# 9) Если одиночная игра, создаём бота и добавляем в дерево
	if game_mode == MODE_SINGLEPLAYER:
		bot_instance = BotClass.new()
		add_child(bot_instance)

	# 10) Запускаем музыку (если есть)
	if music_player:
		music_player.play()

	# 11) Обновляем лейбл расстановки
	_update_placement_label()

	print("Game.gd: PHASE=PLACEMENT — Расставьте корабли вручную или нажмите «Рандом».")


# -------------------------------------------------------------------------
# 1) PHASE: РАССТАНОВКА КОРАБЛЕЙ (PLACEMENT)
# -------------------------------------------------------------------------
func _connect_player_grid_buttons() -> void:
	for y in range(FIELD_SIZE):
		for x in range(FIELD_SIZE):
			var path = "PlayerGrid/Button_%d_%d" % [y, x]
			var btn = get_node_or_null(path)
			if btn is Button:
				btn.text = ""
				btn.modulate = Color.WHITE
				btn.disabled = false
				btn.connect("gui_input", Callable(self, "_on_PlayerGrid_gui_input").bind(x, y))


func _on_PlayerGrid_gui_input(event: InputEvent, x: int, y: int) -> void:
	if state != GameState.PLACEMENT or game_over:
		return

	# Левый клик — попытка поставить текущий корабль
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if current_ship_index >= manual_ships.size():
			return  # все корабли расставлены

		var size = manual_ships[current_ship_index]
		var sp = ShipPlacement.new()
		var dir = randi() % 2   # случайная ориентация: 0 = горизонтально, 1 = вертикально
		if sp.can_place_ship(player_grid, x, y, size, dir):
			# 1) Обозначаем «1» в логической карте
			sp.place_ship(player_grid, x, y, size, dir)

			# 2) «Окрашиваем» кнопки, отображая корабль
			for i in range(size):
				var dx = x + (i if dir == 0 else 0)
				var dy = y + (i if dir == 1 else 0)
				var btn_path = "PlayerGrid/Button_%d_%d" % [dy, dx]
				var deck_btn = get_node_or_null(btn_path)
				if deck_btn is Button:
					deck_btn.modulate = Color(0, 0.5, 1)  # синий
					deck_btn.disabled = true

			# 3) Добавляем в player_ships_data
			player_ships_data.append({
				"x": x,
				"y": y,
				"size": size,
				"dir": dir,
				"hits": 0
			})

			# 4) Переходим к следующему кораблю
			current_ship_index += 1
			_update_placement_label()
			if current_ship_index >= manual_ships.size():
				btn_done.disabled = false
				lbl_place.text = "Все корабли расставлены!"
		else:
			print("Game.gd: Нельзя разместить корабль здесь.")
		return


func _on_RandomButton_pressed() -> void:
	# Сброс логики и UI PlayerGrid
	for y in range(FIELD_SIZE):
		for x in range(FIELD_SIZE):
			player_grid[y][x] = 0
			var btn_path = "PlayerGrid/Button_%d_%d" % [y, x]
			var b = get_node_or_null(btn_path)
			if b is Button:
				b.text = ""
				b.modulate = Color.WHITE
				b.disabled = false

	# Рандомная расстановка всего набора кораблей
	var sp = ShipPlacement.new()
	sp.place_all_ships_randomly(player_grid)

	# Извлекаем и сохраняем данные о всех кораблях
	player_ships_data = _extract_ships_from_grid(player_grid)

	# Окрашиваем кнопки в синий и блокируем их
	for ship_info in player_ships_data:
		var sx = ship_info["x"]
		var sy = ship_info["y"]
		var sz = ship_info["size"]
		var sd = ship_info["dir"]
		for i in range(sz):
			var dx = sx + (i if sd == 0 else 0)
			var dy = sy + (i if sd == 1 else 0)
			var btn_path = "PlayerGrid/Button_%d_%d" % [dy, dx]
			var deck_btn = get_node_or_null(btn_path)
			if deck_btn is Button:
				deck_btn.modulate = Color(0, 0.5, 1)
				deck_btn.disabled = true

	current_ship_index = manual_ships.size()
	btn_done.disabled = false
	lbl_place.text = "Все корабли расставлены!"


func _update_placement_label() -> void:
	if current_ship_index < manual_ships.size():
		var size = manual_ships[current_ship_index]
		var placed = current_ship_index
		var total  = manual_ships.size()
		lbl_place.text = "Ставим %d-палубник (%d/%d)" % [size, placed + 1, total]
	else:
		lbl_place.text = "Готово!"


func _on_DoneButton_pressed() -> void:
	# Завершили расстановку → скрываем панель, показываем EnemyGrid
	placement_panel.visible = false
	enemy_grid_node.visible = true

	if game_mode == MODE_SINGLEPLAYER:
		# Одиночная игра против бота
		state = GameState.BATTLE
		player_turn = true
		status_label.text = "Игра против бота. Ваш ход."

		# Бот рандомно расставляет свои корабли
		var sp = ShipPlacement.new()
		sp.place_all_ships_randomly(bot_grid)
		bot_ships_data = _extract_ships_from_grid(bot_grid)

		# Активируем кнопки EnemyGrid
		_enable_enemy_buttons(true)
	else:
		# Сетевой режим: отправляем данные и ждём противника
		state = GameState.WAITING_FOR_OPPONENT
		wait_label.visible = true
		status_label.text = "Вы готовы. Ждём, пока противник тоже будет готов..."

		# --- Отправляем свои данные друг другу ---
		if is_host:
			for peer_id in get_multiplayer().get_peers():
				rpc_id(peer_id, "rpc_send_ships", player_ships_data)
		else:
			rpc_id(1, "rpc_send_ships", player_ships_data)

		# --- Если уже получили расстановку противника, стартуем бой сразу ---
		_try_start_battle()


# -------------------------------------------------------------------------
# 2) PHASE: СЕТЕВАЯ ЧАСТЬ
# -------------------------------------------------------------------------
func _on_peer_connected(id: int) -> void:
	if is_host:
		status_label.text = "Клиент подключился (id=%d). Ждём «Готово»." % id
	else:
		status_label.text = "Подключены к хосту. Ждём «Готово»."


func _on_peer_disconnected(id: int) -> void:
	status_label.text = "Игрок %d отключился." % id


func _on_connection_failed() -> void:
	status_label.text = "Не удалось подключиться к серверу."


func _on_server_disconnected() -> void:
	status_label.text = "Сервер разорвал соединение."


@rpc("any_peer")
func rpc_send_ships(ships_data: Array) -> void:
	# Любой (хост или клиент) получит здесь расстановку врага
	enemy_ships_data = ships_data.duplicate()
	_fill_enemy_logical(enemy_ships_data)
	got_enemy_ships = true

	# Если локально уже нажали «Готово» → стартуем бой
	_try_start_battle()


func _try_start_battle() -> void:
	# Запускаем бой, когда оба игрока нажали «Готово» и получили данные друг друга
	if state == GameState.WAITING_FOR_OPPONENT and got_enemy_ships:
		wait_label.visible = false
		state = GameState.BATTLE

		if is_host:
			player_turn = true
			status_label.text = "Оба готовы. Игра началась! Ваш ход (хост)."
			_enable_enemy_buttons(true)
		else:
			player_turn = false
			status_label.text = "Оба готовы. Игра началась! Ждём хода хоста."
			_enable_enemy_buttons(false)


func _fill_enemy_logical(ships: Array) -> void:
	# Заполняет enemy_grid_logical на основе списка кораблей
	for ship in ships:
		var sx: int = ship["x"]
		var sy: int = ship["y"]
		var sz: int = ship["size"]
		var sd: int = ship["dir"]
		for i in range(sz):
			var dx = sx + (i if sd == 0 else 0)
			var dy = sy + (i if sd == 1 else 0)
			enemy_grid_logical[dy][dx] = 1


# -------------------------------------------------------------------------
# 3) PHASE: БОЙ (BATTLE)
# -------------------------------------------------------------------------
func _connect_enemy_grid_buttons_once() -> void:
	# Подключаем сигналы ровно один раз
	for y in range(FIELD_SIZE):
		for x in range(FIELD_SIZE):
			var path = "EnemyGrid/Button_%d_%d" % [y, x]
			var btn = get_node_or_null(path)
			if btn is Button:
				btn.text = ""
				btn.modulate = Color.WHITE
				btn.disabled = true
				btn.connect("pressed", Callable(self, "player_shoot").bind(x, y))


func _enable_enemy_buttons(enable: bool) -> void:
	for y in range(FIELD_SIZE):
		for x in range(FIELD_SIZE):
			var btn = get_node("EnemyGrid/Button_%d_%d" % [y, x]) as Button
			btn.disabled = not (enable and player_turn)


func player_shoot(x: int, y: int) -> void:
	if state != GameState.BATTLE or game_over or not player_turn:
		return

	var btn = get_node("EnemyGrid/Button_%d_%d" % [y, x]) as Button
	if not btn:
		return

	if game_mode == MODE_SINGLEPLAYER:
		# — Игра против бота —
		if bot_grid[y][x] in [2, 3]:
			return  # уже стреляли сюда

		if bot_grid[y][x] == 1:
			# Попадание
			bot_grid[y][x] = 2
			btn.text = "X"
			btn.modulate = Color.RED
			btn.disabled = true

			# Обновляем bot_ships_data
			for ship in bot_ships_data:
				var sx = ship["x"]
				var sy = ship["y"]
				var sz = ship["size"]
				var sd = ship["dir"]
				for i in range(sz):
					if sx + (i if sd == 0 else 0) == x and sy + (i if sd == 1 else 0) == y:
						ship["hits"] += 1
						if ship["hits"] == sz:
							_mark_perimeter(ship, bot_grid, enemy_grid_node)
						break

			# Проверяем победу
			if _check_win(bot_grid):
				_show_endgame("Вы выиграли!")
			# Если попали, игрок остаётся в своём ходе
			return
		else:
			# Промах
			bot_grid[y][x] = 3
			btn.text = "O"
			btn.modulate = Color.GRAY
			btn.disabled = true

			player_turn = false
			_enable_enemy_buttons(false)
			await get_tree().create_timer(1.0).timeout
			if bot_instance:
				bot_instance.bot_move()
			return
	else:
		# — Сетевая игра —
		if enemy_grid_logical[y][x] in [2, 3]:
			return  # уже стреляли сюда

		btn.disabled = true
		player_turn = false
		_enable_enemy_buttons(false)

		if is_host:
			var peers = get_multiplayer().get_peers()
			if peers.size() > 0:
				var client_id = peers[0]
				rpc_id(client_id, "rpc_player_shot", x, y)
		else:
			rpc_id(1, "rpc_player_shot", x, y)


# -------------------------------------------------------------------------
# Обработка выстрела противника (RPC)
# -------------------------------------------------------------------------
@rpc("any_peer")
func rpc_player_shot(x: int, y: int) -> void:
	var shooter_id = multiplayer.get_remote_sender_id()
	var hit: bool = false

	if player_grid[y][x] == 1:
		hit = true
		player_grid[y][x] = 2
	else:
		player_grid[y][x] = 3

	var btn_host = get_node("PlayerGrid/Button_%d_%d" % [y, x]) as Button
	if btn_host:
		if hit:
			btn_host.text = "X"
			btn_host.modulate = Color(1, 0.5, 0)
		else:
			btn_host.text = "O"
			btn_host.modulate = Color.GRAY
		btn_host.disabled = true

	# Если промах, сразу даём ход стреляющему
	if not hit:
		player_turn = true
		_enable_enemy_buttons(true)

	rpc_id(shooter_id, "rpc_receive_shot_result", x, y, hit)

	if hit:
		for ship in player_ships_data:
			var sx = ship["x"]
			var sy = ship["y"]
			var sz = ship["size"]
			var sd = ship["dir"]
			for i in range(sz):
				if sx + (i if sd == 0 else 0) == x and sy + (i if sd == 1 else 0) == y:
					ship["hits"] += 1
					if ship["hits"] == sz:
						_mark_perimeter(ship, player_grid, player_grid_node)
					break
		if _check_win(player_grid):
			if is_host:
				rpc("rpc_game_over", true)
			else:
				rpc("rpc_game_over", false)
			_show_endgame("Вы проиграли!")


# -------------------------------------------------------------------------
# Обработка результата своего выстрела (RPC)
# -------------------------------------------------------------------------
@rpc("any_peer")
func rpc_receive_shot_result(x: int, y: int, hit: bool) -> void:
	var btn = get_node("EnemyGrid/Button_%d_%d" % [y, x]) as Button
	if not btn:
		return

	if hit:
		btn.text = "X"
		btn.modulate = Color.RED
		enemy_grid_logical[y][x] = 2

		for ship in enemy_ships_data:
			var sx = ship["x"]
			var sy = ship["y"]
			var sz = ship["size"]
			var sd = ship["dir"]
			for i in range(sz):
				if sx + (i if sd == 0 else 0) == x and sy + (i if sd == 1 else 0) == y:
					ship["hits"] += 1
					if ship["hits"] == sz:
						_mark_perimeter(ship, enemy_grid_logical, enemy_grid_node)
					break

		player_turn = true
		_enable_enemy_buttons(true)
	else:
		btn.text = "O"
		btn.modulate = Color.GRAY
		enemy_grid_logical[y][x] = 3
		# Ожидаем следующего rpc_your_turn


@rpc("any_peer")
func rpc_your_turn() -> void:
	player_turn = true
	_enable_enemy_buttons(true)
	if is_host:
		status_label.text = "Ваш ход (хост)."
	else:
		status_label.text = "Ваш ход (клиент)."


@rpc("any_peer")
func rpc_game_over(client_won: bool) -> void:
	if is_host:
		if client_won:
			_show_endgame("Вы проиграли!")
		else:
			_show_endgame("Вы выиграли!")
	else:
		if client_won:
			_show_endgame("Вы выиграли!")
		else:
			_show_endgame("Вы проиграли!")


# -------------------------------------------------------------------------
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# -------------------------------------------------------------------------
func process_shot(x: int, y: int) -> bool:
	# Этот метод нужен для одиночной игры (бот вызывает его напрямую)
	var hit = false

	if player_grid[y][x] == 1:
		hit = true
		player_grid[y][x] = 2
		var btn_host = get_node("PlayerGrid/Button_%d_%d" % [y, x]) as Button
		if btn_host:
			btn_host.text = "X"
			btn_host.modulate = Color(1, 0.5, 0)
			btn_host.disabled = true

		for ship in player_ships_data:
			var sx = ship["x"]
			var sy = ship["y"]
			var sz = ship["size"]
			var sd = ship["dir"]
			for i in range(sz):
				if sx + (i if sd == 0 else 0) == x and sy + (i if sd == 1 else 0) == y:
					ship["hits"] += 1
					if ship["hits"] == sz:
						_mark_perimeter(ship, player_grid, player_grid_node)
					break

		if _check_win(player_grid):
			_show_endgame("Вы проиграли!")
	else:
		player_grid[y][x] = 3
		var btn_host = get_node("PlayerGrid/Button_%d_%d" % [y, x]) as Button
		if btn_host:
			btn_host.text = "O"
			btn_host.modulate = Color.GRAY
			btn_host.disabled = true

		# После промаха бот должен вернуть ход игроку
		player_turn = true
		_enable_enemy_buttons(true)

	return hit


func _check_win(grid: Array) -> bool:
	for row in grid:
		for cell in row:
			if cell == 1:
				return false
	return true


func _show_endgame(message: String) -> void:
	game_over = true
	lbl_result.text = message
	endgame_layer.visible = true


func _on_RematchButton_pressed() -> void:
	# Сброс состояния → фаза PLACEMENT
	game_over = false
	player_turn = true
	state = GameState.PLACEMENT
	current_ship_index = 0
	player_ships_data.clear()
	bot_ships_data.clear()
	enemy_ships_data.clear()
	got_enemy_ships = false

	var sp = ShipPlacement.new()
	player_grid = sp.initialize_grid()
	bot_grid     = sp.initialize_grid()
	enemy_grid_logical = sp.initialize_grid()

	placement_panel.visible = true
	endgame_layer.visible = false

	# Сброс UI PlayerGrid
	for y in range(FIELD_SIZE):
		for x in range(FIELD_SIZE):
			var pb = get_node_or_null("PlayerGrid/Button_%d_%d" % [y, x]) as Button
			if pb:
				pb.text = ""
				pb.modulate = Color.WHITE
				pb.disabled = false

	# Сброс UI EnemyGrid
	for y in range(FIELD_SIZE):
		for x in range(FIELD_SIZE):
			var eb = get_node_or_null("EnemyGrid/Button_%d_%d" % [y, x]) as Button
			if eb:
				eb.text = ""
				eb.modulate = Color.WHITE
				eb.disabled = true

	btn_done.disabled = true
	_update_placement_label()


func _on_ExitToMenuButton_pressed() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")


func _on_MenuButton_pressed() -> void:
	get_tree().paused = true
	pause_menu.show()


func _extract_ships_from_grid(grid: Array) -> Array:
	var ships_arr: Array = []
	var visited: Array = []
	for y in range(FIELD_SIZE):
		visited.append([])
		for x in range(FIELD_SIZE):
			visited[y].append(false)

	for y in range(FIELD_SIZE):
		for x in range(FIELD_SIZE):
			if grid[y][x] == 1 and not visited[y][x]:
				var dir = 0
				if x + 1 < FIELD_SIZE and grid[y][x + 1] == 1:
					dir = 0
				elif y + 1 < FIELD_SIZE and grid[y + 1][x] == 1:
					dir = 1
				var length = 1
				if dir == 0:
					var cx = x + 1
					while cx < FIELD_SIZE and grid[y][cx] == 1:
						length += 1
						cx += 1
				else:
					var cy = y + 1
					while cy < FIELD_SIZE and grid[cy][x] == 1:
						length += 1
						cy += 1

				for i in range(length):
					var dx = x + (i if dir == 0 else 0)
					var dy = y + (i if dir == 1 else 0)
					visited[dy][dx] = true

				ships_arr.append({ "x": x, "y": y, "size": length, "dir": dir, "hits": 0 })

	return ships_arr


func _mark_perimeter(ship: Dictionary, grid: Array, grid_node: GridContainer) -> void:
	var sx = ship["x"]
	var sy = ship["y"]
	var sz = ship["size"]
	var sd = ship["dir"]

	var min_x = sx - 1
	var max_x = sx + (sz if sd == 0 else 1)
	var min_y = sy - 1
	var max_y = sy + (sz if sd == 1 else 1)

	for yy in range(min_y, max_y + 1):
		for xx in range(min_x, max_x + 1):
			if xx < 0 or xx >= FIELD_SIZE or yy < 0 or yy >= FIELD_SIZE:
				continue
			var on_ship = false
			for i in range(sz):
				if sx + (i if sd == 0 else 0) == xx and sy + (i if sd == 1 else 0) == yy:
					on_ship = true
					break
			if on_ship:
				continue

			if grid[yy][xx] in [2, 3]:
				continue

			grid[yy][xx] = 3
			var btn = grid_node.get_node_or_null("Button_%d_%d" % [yy, xx]) as Button
			if btn:
				btn.text = "O"
				btn.modulate = Color.GRAY
				btn.disabled = true
