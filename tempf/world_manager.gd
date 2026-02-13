# world_manager.gd
# Floating Origin 구현, 카메라 줌/이동, LOD 레벨 관리.
# RefCounted 상속 - 씬트리와 무관하게 GameManager가 소유.
# _process() 없음 - GameManager._process()에서 update() 호출.
# get_viewport() 사용 불가 - 뷰포트 크기는 register_camera() 시 Camera2D로부터 접근.

class_name WorldManager
extends RefCounted

# ── Floating Origin ────────────────────────────────────────
const ORIGIN_SHIFT_THRESHOLD := 10_000.0

# ── 카메라 상태 ───────────────────────────────────────────
var camera_position: Vector2 = Vector2.ZERO
var zoom_level: float = 1.0

const ZOOM_MIN := 0.001
const ZOOM_MAX := 100.0

# ── LOD 레벨 ──────────────────────────────────────────────
enum LODLevel {
	GALAXY,   # 은하 전체 - 행성계만 점으로 표시
	SYSTEM,   # 행성계 - 행성/위성, 함선은 아이콘
	FLEET,    # 함대 - 함선 개별 스프라이트
	SHIP,     # 근접 - 픽셀 단위 셀 렌더링
}

var current_lod: LODLevel = LODLevel.SYSTEM

const LOD_THRESHOLD_GALAXY := 0.005
const LOD_THRESHOLD_SYSTEM := 0.05
const LOD_THRESHOLD_FLEET  := 1.0

# ── 시그널 ────────────────────────────────────────────────
signal origin_shifted(offset: Vector2)
signal lod_changed(level: LODLevel)
signal camera_moved(new_pos: Vector2, new_zoom: float)

# ── 카메라 참조 (InGame 씬 Renderer에서 register_camera 호출) ──
var _camera: Camera2D = null

# ── 줌 보간 ───────────────────────────────────────────────
var _target_zoom: float = 1.0
const ZOOM_LERP_SPEED := 8.0
const ZOOM_STEP       := 0.15

# ── 드래그 상태 ───────────────────────────────────────────
var _drag_active:    bool    = false
var _drag_origin:    Vector2 = Vector2.ZERO
var _drag_cam_start: Vector2 = Vector2.ZERO

# ── 초기화 ────────────────────────────────────────────────
func initialize() -> void:
	camera_position = Vector2.ZERO
	zoom_level      = 1.0
	_target_zoom    = 1.0
	current_lod     = LODLevel.SYSTEM

func register_camera(cam: Camera2D) -> void:
	_camera      = cam
	_target_zoom = zoom_level
	_apply_camera()

# ── GameManager._process()에서 호출 ───────────────────────
func update(delta: float) -> void:
	if _camera == null:
		return
	var prev_zoom := zoom_level
	var prev_pos  := camera_position
	_update_zoom_lerp(delta)
	_check_origin_shift()
	_update_lod()
	# 실제로 변경된 경우에만 시그널 발신
	if not is_equal_approx(zoom_level, prev_zoom) or camera_position != prev_pos:
		camera_moved.emit(camera_position, zoom_level)

func _update_zoom_lerp(delta: float) -> void:
	if is_equal_approx(zoom_level, _target_zoom):
		return
	zoom_level = lerpf(zoom_level, _target_zoom, ZOOM_LERP_SPEED * delta)
	if absf(zoom_level - _target_zoom) < 0.0001:
		zoom_level = _target_zoom
	_apply_camera()

func _apply_camera() -> void:
	# 카메라 노드 상태 갱신만 담당, 시그널 발신은 update()에서 일괄 처리
	_camera.zoom     = Vector2(zoom_level, zoom_level)
	_camera.position = camera_position

func _check_origin_shift() -> void:
	if camera_position.length() < ORIGIN_SHIFT_THRESHOLD:
		return
	var offset      := camera_position
	camera_position  = Vector2.ZERO
	if GameManager.simulation_manager:
		GameManager.simulation_manager.shift_origin(-offset)
	origin_shifted.emit(offset)

func _update_lod() -> void:
	var new_lod: LODLevel
	if zoom_level < LOD_THRESHOLD_GALAXY:
		new_lod = LODLevel.GALAXY
	elif zoom_level < LOD_THRESHOLD_SYSTEM:
		new_lod = LODLevel.SYSTEM
	elif zoom_level < LOD_THRESHOLD_FLEET:
		new_lod = LODLevel.FLEET
	else:
		new_lod = LODLevel.SHIP

	if new_lod != current_lod:
		current_lod = new_lod
		lod_changed.emit(current_lod)

# ── 입력 처리 (InGame 씬 _unhandled_input에서 위임) ───────
# 카메라 줌/이동은 일시정지 중에도 허용 - 전황 파악을 위해
func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_MIDDLE:
				_drag_active    = mb.pressed
				_drag_origin    = mb.position
				_drag_cam_start = camera_position
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_target_zoom = clampf(_target_zoom * (1.0 + ZOOM_STEP), ZOOM_MIN, ZOOM_MAX)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_target_zoom = clampf(_target_zoom * (1.0 - ZOOM_STEP), ZOOM_MIN, ZOOM_MAX)

	if event is InputEventMouseMotion and _drag_active:
		var mm    := event as InputEventMouseMotion
		var delta := (mm.position - _drag_origin) / zoom_level
		camera_position = _drag_cam_start - delta
		if _camera:
			_camera.position = camera_position

# ── 좌표 변환 헬퍼 (뷰포트 크기는 Camera2D 기준) ──────────
func world_to_screen(world_pos: Vector2, viewport_size: Vector2) -> Vector2:
	return (world_pos - camera_position) * zoom_level + viewport_size * 0.5

func screen_to_world(screen_pos: Vector2, viewport_size: Vector2) -> Vector2:
	return (screen_pos - viewport_size * 0.5) / zoom_level + camera_position
