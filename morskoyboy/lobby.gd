# res://Lobby.gd
extends Control

@onready var info_label: Label    = $VBoxContainer/InfoLabel
@onready var ip_field: LineEdit   = $VBoxContainer/IPField
@onready var port_field: LineEdit = $VBoxContainer/PortField
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var back_button: Button  = $VBoxContainer/BackButton
@onready var status_label: Label  = $VBoxContainer/StatusLabel

func _ready() -> void:
	# 1) Подсказочный текст и порт по умолчанию
	info_label.text = "Если поле IP пустое — мы запустим сервер.\nЕсли указать IP, подключаемся как клиент."
	port_field.text = "7777"

	# 2) Подключаем сигналы
	start_button.connect("pressed", Callable(self, "_on_StartButton_pressed"))
	back_button.connect("pressed", Callable(self, "_on_BackButton_pressed"))

	# 3) Сетевые сигналы
	var mp = get_tree().get_multiplayer()
	mp.peer_connected.connect(_on_peer_connected)
	mp.connection_failed.connect(_on_connection_failed)
	mp.server_disconnected.connect(_on_server_disconnected)
	mp.peer_disconnected.connect(_on_peer_disconnected)

	# 4) Пока не нажали «Start», все поля активны:
	ip_field.editable = true
	port_field.editable = true
	start_button.disabled = false
	back_button.disabled = false

func _on_StartButton_pressed() -> void:
	var port: int = int(port_field.text)
	var typed_ip: String = ip_field.text.strip_edges()

	if typed_ip == "":
		# ====== Старт сервера ======
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(port, 2)
		if err != OK:
			status_label.text = "Не удалось запустить сервер на порту %d." % port
			return
		get_tree().get_multiplayer().multiplayer_peer = peer
		status_label.text = "Сервер запущен на порту %d.\nЖдём подключения клиента..." % port

		# Блокируем всё:
		ip_field.editable = false
		port_field.editable = false
		start_button.disabled = true
		back_button.disabled = true

	else:
		# ====== Старт клиента ======
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_client(typed_ip, port)
		if err != OK:
			status_label.text = "Не удалось подключиться к %s:%d." % [typed_ip, port]
			return
		get_tree().get_multiplayer().multiplayer_peer = peer
		status_label.text = "Подключаемся к %s:%d..." % [typed_ip, port]

		# Блокируем всё:
		ip_field.editable = false
		port_field.editable = false
		start_button.disabled = true
		back_button.disabled = true

func _on_BackButton_pressed() -> void:
	# Возвращаемся в MainMenu
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _on_peer_connected(id: int) -> void:
	# Когда peer действительно подключился (у хоста: клиент, у клиента: он сам).
	status_label.text = "Соединение установлено (peer id=%d). Переход в игру..." % id
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://Game.tscn")

func _on_connection_failed() -> void:
	status_label.text = "Ошибка подключения."
	ip_field.editable = true
	port_field.editable = true
	start_button.disabled = false
	back_button.disabled = false

func _on_server_disconnected() -> void:
	status_label.text = "Сервер разорвал соединение."
	ip_field.editable = true
	port_field.editable = true
	start_button.disabled = false
	back_button.disabled = false

func _on_peer_disconnected(id: int) -> void:
	status_label.text = "Игрок %d отключился." % id
