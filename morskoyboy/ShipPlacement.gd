# res://ShipPlacement.gd
extends Node

var ships = [
	{ "size": 4, "count": 1 },
	{ "size": 3, "count": 2 },
	{ "size": 2, "count": 3 },
	{ "size": 1, "count": 4 }
]

func initialize_grid() -> Array:
	var grid: Array = []
	for y in range(10):
		var row: Array = []
		for x in range(10):
			row.append(0)
		grid.append(row)
	return grid

func can_place_ship(grid: Array, x: int, y: int, size: int, direction: int) -> bool:
	for i in range(size):
		var dx = x + (i if direction == 0 else 0)
		var dy = y + (i if direction == 1 else 0)
		if dx < 0 or dx >= 10 or dy < 0 or dy >= 10:
			return false
		if grid[dy][dx] != 0:
			return false
	for i in range(size):
		var dx = x + (i if direction == 0 else 0)
		var dy = y + (i if direction == 1 else 0)
		for ny in range(dy - 1, dy + 2):
			for nx in range(dx - 1, dx + 2):
				if nx >= 0 and nx < 10 and ny >= 0 and ny < 10:
					if grid[ny][nx] == 1:
						return false
	return true

func place_ship(grid: Array, x: int, y: int, size: int, direction: int) -> void:
	for i in range(size):
		var dx = x + (i if direction == 0 else 0)
		var dy = y + (i if direction == 1 else 0)
		grid[dy][dx] = 1

func place_all_ships_randomly(grid: Array) -> void:
	for ship in ships:
		var to_place = ship["count"]
		var size    = ship["size"]
		var placed  = 0
		while placed < to_place:
			var x = randi() % 10
			var y = randi() % 10
			var dir = randi() % 2
			if can_place_ship(grid, x, y, size, dir):
				place_ship(grid, x, y, size, dir)
				placed += 1
