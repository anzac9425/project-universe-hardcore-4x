class_name MapChunkData
extends Resource

const CELLS_PER_CHUNK := 128
const BYTES_PER_CELL := 4

const BYTE_TERRAIN := 0
const BYTE_RESOURCE := 1
const BYTE_THREAT := 2
const BYTE_FLAGS := 3

@export var chunk_coord: Vector2i = Vector2i.ZERO
@export var cell_data: PackedByteArray = PackedByteArray()

func init_empty(coord: Vector2i) -> void:
	chunk_coord = coord
	cell_data.resize(CELLS_PER_CHUNK * CELLS_PER_CHUNK * BYTES_PER_CELL)
	cell_data.fill(0)

func _idx(x: int, y: int) -> int:
	return (y * CELLS_PER_CHUNK + x) * BYTES_PER_CELL

func set_cell(x: int, y: int, terrain: int, resource: int, threat: int, flags: int) -> void:
	var i: int = _idx(x, y)
	cell_data[i + BYTE_TERRAIN] = terrain
	cell_data[i + BYTE_RESOURCE] = resource
	cell_data[i + BYTE_THREAT] = threat
	cell_data[i + BYTE_FLAGS] = flags

func get_terrain(x: int, y: int) -> int:
	return cell_data[_idx(x, y) + BYTE_TERRAIN]

func serialize() -> Dictionary:
	return {
		"coord": chunk_coord,
		"cell_data": cell_data,
	}

static func deserialize(data: Dictionary):
	var c := MapChunkData.new()
	c.chunk_coord = data.get("coord", Vector2i.ZERO)
	var raw_data = data.get("cell_data", PackedByteArray())
	if raw_data is PackedByteArray:
		c.cell_data = raw_data
	else:
		c.cell_data = PackedByteArray()
	return c
