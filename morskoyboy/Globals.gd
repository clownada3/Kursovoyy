extends Node

# Флаг: true = мы хостим (сервер), false = мы клиент
var is_host: bool = true

# IP и порт сервера (для клиента будет заполнено из Lobby)
var server_ip: String = ""
var server_port: int = 7777
