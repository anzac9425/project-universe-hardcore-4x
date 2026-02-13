# game_manager.gd
# 게임 전체를 총괄하는 싱글톤 (Autoload).
# 씬 전환, 시뮬레이션 속도, 하위 매니저 직접 소유 및 업데이트 담당.
# 접근: GameManager.xxx

extends Node

# ── 씬 경로 상수 ──────────────────────────────────────────
const SCENE_MAIN_MENU := "res://scenes/menus/main_menu.tscn"
const SCENE_LOADING   := "res://scenes/main/loading.tscn"
const SCENE_INGAME    := "res://scenes/ingame/ingame.tscn"
const SCENE_SETTINGS  := "res://scenes/menus/settings.tscn"

# ── 게임 상태 ─────────────────────────────────────────────
enum GameState {
	NONE,
	MAIN_MENU,
	LOADING,
	INGAME,
	SETTINGS,
}

var current_state: GameState = GameState.NONE

# ── 시뮬레이션 속도 ───────────────────────────────────────
# Engine.time_scale 대신 자체 관리 - UI 애니메이션은 영향받지 않음
var sim_speed: float = 1.0
var _pre_pause_speed: float = 1.0

# ── 일시정지 요청 카운터 ──────────────────────────────────
# 여러 시스템이 동시에 pause 요청 가능 - 모두 해제되어야 resume
var _pause_requests: int = 0

# ── 시그널 ────────────────────────────────────────────────
signal scene_changed(new_state: GameState)
signal sim_speed_changed(speed: float)
signal pause_changed(is_paused: bool)

# ── 하위 매니저 (RefCounted - 씬트리와 무관하게 생존) ─────
var world_manager:      WorldManager      = null
var simulation_manager: SimulationManager = null
var combat_manager:     CombatManager     = null
var research_manager:   ResearchManager   = null
var economy_manager:    EconomyManager    = null
var faction_manager:    FactionManager    = null

var _managers_initialized: bool = false

# ── 페이드 노드 (@onready는 선언부에 위치해야 함) ──────────
@onready var _fade_layer: CanvasLayer = $FadeLayer
@onready var _fade_rect:  ColorRect   = $FadeLayer/FadeRect

# ── 초기화 ────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# _fade_rect가 @onready로 초기화된 후에 씬 전환 호출
	await go_to_main_menu()

# ── 매 프레임 - 매니저 업데이트 ──────────────────────────
func _process(delta: float) -> void:
	if not _managers_initialized:
		return
	var sim_delta := delta * sim_speed
	# WorldManager는 실시간 delta (줌 보간은 sim_speed 무관)
	world_manager.update(delta)
	# 나머지는 sim_delta (일시정지 시 0)
	if sim_delta > 0.0:
		simulation_manager.update(sim_delta)
		combat_manager.update(sim_delta)

# ── 매니저 초기화 (InGame 씬 진입 시 호출) ────────────────
func initialize_managers() -> void:
	world_manager      = WorldManager.new()
	simulation_manager = SimulationManager.new()
	combat_manager     = CombatManager.new()
	research_manager   = ResearchManager.new()
	economy_manager    = EconomyManager.new()
	faction_manager    = FactionManager.new()

	MaterialData.register_defaults()

	world_manager.initialize()
	simulation_manager.initialize()
	combat_manager.initialize()
	research_manager.initialize()
	economy_manager.initialize()
	faction_manager.initialize()

	_managers_initialized = true

func shutdown_managers() -> void:
	_managers_initialized = false
	world_manager      = null
	simulation_manager = null
	combat_manager     = null
	research_manager   = null
	economy_manager    = null
	faction_manager    = null

# ── 씬 전환 ───────────────────────────────────────────────
# await 가능한 코루틴 - 호출부에서 await 필요
func go_to_main_menu() -> void:
	await _change_scene(SCENE_MAIN_MENU, GameState.MAIN_MENU)

func go_to_ingame(_save_path: String = "") -> void:
	await _change_scene(SCENE_LOADING, GameState.LOADING)

func on_loading_complete() -> void:
	await _change_scene(SCENE_INGAME, GameState.INGAME)

func go_to_settings() -> void:
	await _change_scene(SCENE_SETTINGS, GameState.SETTINGS)

func _change_scene(path: String, state: GameState) -> void:
	current_state = state
	await _fade_out()
	get_tree().change_scene_to_file(path)
	scene_changed.emit(state)
	_fade_in()

# ── 페이드 ────────────────────────────────────────────────
func _fade_in() -> void:
	if _fade_rect == null:
		return
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color", Color(0, 0, 0, 0), 0.3)

func _fade_out() -> void:
	if _fade_rect == null:
		return
	_fade_rect.color = Color(0, 0, 0, 0)
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color", Color(0, 0, 0, 1), 0.25)
	await tween.finished

# ── 일시정지 ──────────────────────────────────────────────
func request_pause() -> void:
	_pause_requests += 1
	if _pause_requests == 1:
		_pre_pause_speed = sim_speed if sim_speed > 0.0 else 1.0
		_set_sim_speed(0.0)
		pause_changed.emit(true)

func release_pause() -> void:
	_pause_requests = maxi(0, _pause_requests - 1)
	if _pause_requests == 0:
		_set_sim_speed(_pre_pause_speed)
		pause_changed.emit(false)

func is_paused() -> bool:
	return _pause_requests > 0

func force_resume() -> void:
	_pause_requests = 0
	_set_sim_speed(_pre_pause_speed)
	pause_changed.emit(false)

# ── 속도 설정 ─────────────────────────────────────────────
func _set_sim_speed(value: float) -> void:
	sim_speed = value
	sim_speed_changed.emit(value)

func set_speed(value: float) -> void:
	if is_paused():
		return
	_set_sim_speed(value)

func set_speed_normal() -> void:    set_speed(1.0)
func set_speed_fast() -> void:      set_speed(5.0)
func set_speed_very_fast() -> void: set_speed(20.0)
func set_speed_slow() -> void:      set_speed(0.25)

# ── 인게임 여부 ───────────────────────────────────────────
func is_ingame() -> bool:
	return current_state == GameState.INGAME
