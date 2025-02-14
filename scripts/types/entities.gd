extends Node

var entities: Array = []

func add_entity(entity) -> void:
	entities.append(entity)

func remove_entity(entity) -> void:
	entities.erase(entity)
