# blueprint_editor.gd
# Blueprint 에디터의 핵심 로직.
# UI는 별도로 붙이고, 이 클래스는 데이터 조작과 렌더링 미리보기만 담당.
# Node를 상속하지 않아도 되지만, EditorPlugin 등에서 Node로 쓸 경우를 위해 Node2D 상속.

class_name BlueprintEditor
extends Node2D

# ── 현재 편집 중인 Blueprint ──────────────────────────────
var current_blueprint: Blueprint = null

# ── 에디터 상태 ───────────────────────────────────────────
var selected_material: int  = CellDefs.MATERIAL_STEEL
var selected_module_type: int = 0   # 0 = 없음
var brush_size: int         = 1     # 브러시 크기 (셀 단위)
var is_erase_mode: bool     = false

# ── 미리보기 텍스처 (RenderingServer 직접 사용) ───────────
var preview_texture_rid: RID = RID()
var preview_image: Image    = null
var texture_dirty: bool     = false

# 셀 하나의 화면 픽셀 크기
const CELL_SCREEN_PX := 8

const MODULE_OVERLAY_COLOR   := Color(1.0, 0.85, 0.0, 0.4)
const CRITICAL_OVERLAY_COLOR := Color(1.0, 0.2,  0.2, 0.4)

# ── 초기화 ────────────────────────────────────────────────
func new_blueprint(w: int, h: int) -> void:
	current_blueprint = Blueprint.new()
	current_blueprint.init_empty(w, h)
	_init_preview_texture()

func load_blueprint(bp: Blueprint) -> void:
	current_blueprint = bp
	_init_preview_texture()

# ── 셀 페인팅 ─────────────────────────────────────────────
func paint_cell(x: int, y: int) -> void:
	if current_blueprint == null:
		return
	_paint_region(x, y, brush_size)
	texture_dirty = true

func erase_cell(x: int, y: int) -> void:
	if current_blueprint == null:
		return
	for dy in range(brush_size):
		for dx in range(brush_size):
			var cx := x + dx - brush_size / 2
			var cy := y + dy - brush_size / 2
			if current_blueprint.in_bounds(cx, cy):
				current_blueprint.clear_cell(cx, cy)
	texture_dirty = true

func _paint_region(cx: int, cy: int, size: int) -> void:
	for dy in range(size):
		for dx in range(size):
			var px := cx + dx - size / 2
			var py := cy + dy - size / 2
			if not current_blueprint.in_bounds(px, py):
				continue
			var flags := CellDefs.FLAG_OCCUPIED
			# 외장 셀 자동 판정은 bake 시 수행
			current_blueprint.set_cell(px, py, selected_material, 0, 255, flags)

# ── 화면 좌표 → 셀 좌표 변환 ────────────────────────────
func screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var local := (screen_pos - global_position) / CELL_SCREEN_PX
	return Vector2i(int(local.x), int(local.y))

# ── 미리보기 텍스처 ───────────────────────────────────────
func _init_preview_texture() -> void:
	if current_blueprint == null:
		return
	var pw := current_blueprint.width
	var ph := current_blueprint.height
	preview_image = Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	_rebuild_preview_image()
	if preview_texture_rid.is_valid():
		RenderingServer.free_rid(preview_texture_rid)
	preview_texture_rid = RenderingServer.texture_2d_create(preview_image)

func _rebuild_preview_image() -> void:
	if preview_image == null or current_blueprint == null:
		return
	for y in range(current_blueprint.height):
		for x in range(current_blueprint.width):
			var color: Color
			if not current_blueprint.is_occupied(x, y):
				color = MaterialData.get_color(CellDefs.MATERIAL_EMPTY)
			else:
				var mat   := current_blueprint.get_material(x, y)
				var flags := CellDefs.get_flags(current_blueprint.cell_data, x, y, current_blueprint.width)
				color = MaterialData.get_color(mat)
				if current_blueprint.get_module_id(x, y) > 0:
					color = color.blend(MODULE_OVERLAY_COLOR)
				if flags & CellDefs.FLAG_CRITICAL:
					color = color.blend(CRITICAL_OVERLAY_COLOR)
			preview_image.set_pixel(x, y, color)
	texture_dirty = false

# ── 외장 셀 자동 플래그 계산 (bake 전 호출) ──────────────
func auto_flag_exterior() -> void:
	if current_blueprint == null:
		return
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for y in range(current_blueprint.height):
		for x in range(current_blueprint.width):
			if not current_blueprint.is_occupied(x, y):
				continue
			var is_ext := false
			for d in dirs:
				var nx := x + d.x
				var ny := y + d.y
				if not current_blueprint.in_bounds(nx, ny) or not current_blueprint.is_occupied(nx, ny):
					is_ext = true
					break
			var idx   := CellDefs.cell_index(x, y, current_blueprint.width) + CellDefs.BYTE_FLAGS
			var flags := current_blueprint.cell_data[idx]
			if is_ext:
				flags |= CellDefs.FLAG_EXTERIOR
			else:
				flags &= ~CellDefs.FLAG_EXTERIOR
			current_blueprint.cell_data[idx] = flags

# ── 설계 확정 ─────────────────────────────────────────────
func bake() -> BlueprintStats:
	if current_blueprint == null:
		return null
	auto_flag_exterior()
	var stats := current_blueprint.bake_stats()
	_rebuild_preview_image()
	if preview_texture_rid.is_valid():
		RenderingServer.texture_2d_update(preview_texture_rid, preview_image, 0)
	return stats

# ── _process: dirty 시 텍스처 갱신 ───────────────────────
func _process(_delta: float) -> void:
	if texture_dirty:
		_rebuild_preview_image()
		if preview_texture_rid.is_valid():
			RenderingServer.texture_2d_update(preview_texture_rid, preview_image, 0)

# ── 정리 ──────────────────────────────────────────────────
func _exit_tree() -> void:
	if preview_texture_rid.is_valid():
		RenderingServer.free_rid(preview_texture_rid)
