class_name MapWorld
extends RefCounted

const MapChunkScript = preload("res://skripts/map/map_chunk_data.gd")
const CHUNK_SIZE := 128

var world_seed: int = 1337
var loaded_chunks: Dictionary = {}

func setup(seed: int) -> void:
	world_seed = seed
	loaded_chunks.clear()

func ensure_chunk(coord: Vector2i):
	if loaded_chunks.has(coord):
		return loaded_chunks[coord]
	var chunk = _generate_chunk(coord)
	loaded_chunks[coord] = chunk
	return chunk

func unload_far_chunks(center_coord: Vector2i, keep_radius: int) -> void:
	var to_remove: Array = []
	for key in loaded_chunks.keys():
		var c: Vector2i = key
		if abs(c.x - center_coord.x) > keep_radius or abs(c.y - center_coord.y) > keep_radius:
			to_remove.append(c)
	for c in to_remove:
		loaded_chunks.erase(c)

func _generate_chunk(coord: Vector2i):
	var chunk = MapChunkScript.new()
	chunk.init_empty(coord)

	var base: int = int((coord.x * 73856093) ^ (coord.y * 19349663) ^ world_seed)
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var n: int = (base + x * 31 + y * 17) & 255
			var terrain: int = 1 if n > 25 else 2
			var resource: int = 1 if n > 220 else 0
			var threat: int = 1 if n < 10 else 0
			chunk.set_cell(x, y, terrain, resource, threat, 0)
	return chunk
