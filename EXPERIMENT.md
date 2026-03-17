# Stellar Dominion - Technical Architecture

**Version**: NOT FIXED, REQUIRE CHANGE
**Engine**: Godot 4.6 (GDScript)  
**Target**: PC, 수천 척 규모 함대전, 셀 기반 파괴 시스템

**용어**: 
- **셀(Cell)** = Blueprint 설계의 1픽셀. 모든 내구도·파괴는 셀 단위로 처리
- **함선(Ship)** = 셀 격자로 구성된 구조체
- **모듈(Module)** = 셀 위에 배치되는 기능 요소 (엔진, 무기, 원자로 등)

---

## 1. Core Design Philosophy

### 1.1 통합 시뮬레이션 (맵과 전투 비분리)

**핵심 원칙**: 은하 맵, 성계, 전투를 단일 연속 공간에서 처리한다.

```
전통적 4X 게임:
  전략 맵 (턴제) ←→ 전투 화면 (실시간) 분리

Stellar Dominion:
  단일 연속 공간 + LOD로 디테일 조절
  줌인 = 더 많은 셀 시뮬레이션
  줌아웃 = 집계된 함대 파워만
```

**장점**:
- 전투 중 원거리에서 접근하는 증원 함대가 자연스럽게 보임
- 성계 간 이동 중 요격 가능
- 모든 물리 법칙이 일관성 유지

**도전과제**:
- 성능 관리 복잡도 증가
- LOD 전환 경계 처리 필요

---

### 1.2 Data-Oriented Design

**금지 사항**:
- 함선 하나당 Node2D 생성
- Dictionary에 엔티티 저장
- 깊은 오브젝트 트리

**권장 구조**:
```gdscript
# ❌ 나쁜 예
var ships: Dictionary = {}
ships[id] = {
	"pos": Vector2(),
	"hp": 100,
	"cells": []
}

# ✅ 좋은 예
class ShipData extends RefCounted:
	var id: int
	var position: Vector2
	var hp: float
	var cells: PackedByteArray
	var modules: PackedInt32Array

var ships: Array[ShipData] = []
var ship_lookup: Dictionary = {} # int -> ShipData (조회용만)
```

---

### 1.3 결정론적 시뮬레이션

**고정 틱 30Hz**:
```gdscript
const SIM_TICK_RATE = 30
const FIXED_DELTA = 1.0 / SIM_TICK_RATE

var accumulator: float = 0.0

func _physics_process(delta: float) -> void:
	accumulator += delta
	while accumulator >= FIXED_DELTA:
		_simulation_tick()
		accumulator -= FIXED_DELTA
```

**결정론 보장 규칙**:
- 부동소수점 연산 순서 고정
- RNG는 tick + context ID로 시드 고정
- 배열 순회는 정렬된 ID 순서만 사용
- Dictionary 순회 금지 (순서 불확정)

---

## 2. System Architecture

### 2.1 Ingame 씬 구조

**전체 노드 트리**:
```
Ingame (Node)
├── Managers (Node)
│   ├── GameManager (autoload reference)
│   ├── SimulationManager (script)
│   ├── RenderManager (script)
│   ├── OriginManager (script)
│   ├── SpatialManager (script)
│   ├── StreamingManager (script)
│   ├── PoolManager (script)
│   └── EventBus (script)
│
├── World (Node2D)
│   ├── Camera (Camera2D)
│   ├── RenderRoot (Node2D)  # Floating Origin 이동 대상
│   │   ├── BackgroundLayer (ParallaxBackground)
│   │   ├── SystemsLayer (Node2D)
│   │   │   └── [동적 생성: 성계 스프라이트/마커]
│   │   ├── ShipsLayer (Node2D)
│   │   │   └── [풀에서 할당: ShipView 인스턴스들]
│   │   ├── ProjectilesLayer (Node2D)
│   │   │   └── [풀에서 할당: Projectile 스프라이트들]
│   │   └── VFXLayer (Node2D)
│   │       └── [풀에서 할당: GPUParticles2D 등]
│   │
│   └── DebugOverlay (CanvasLayer)
│       └── DebugLabel (Label)
│
├── UI (CanvasLayer)
│   ├── TopBar (Control)
│   │   ├── ResourceDisplay (HBoxContainer)
│   │   └── TimeControls (HBoxContainer)
│   ├── SelectionPanel (PanelContainer)
│   ├── TacticsPanel (PanelContainer)
│   ├── BlueprintEditor (Control)
│   └── SystemInfo (PanelContainer)
│
└── Pools (Node)
	├── ShipViewPool (Node)
	├── ProjectileViewPool (Node)
	└── VFXPool (Node)
	
	
	
Ingame (Node)
│
├── Core
│   ├── SimulationDriver (Node)
│   ├── RenderDriver (Node)
│   ├── StreamingDriver (Node)
│   └── OriginDriver (Node)
│
├── World (Node2D)
│   ├── CameraRig (Node2D)
│   │   └── Camera2D
│   │
│   └── RenderRoot (Node2D)
│       │
│       ├── BackgroundLayer
│       │   └── ParallaxBackground
│       │
│       ├── GalaxyLayer
│       │   └── SystemMarkers
│       │
│       ├── CombatLayer
│       │   ├── ShipViews
│       │   ├── ProjectileViews
│       │   └── VFX
│       │
│       └── OverlayLayer
│           └── SelectionIndicators
│
├── Pools
│   ├── ShipViewPool
│   ├── ProjectileViewPool
│   └── VFXPool
│
├── Debug
│   ├── DebugOverlay (CanvasLayer)
│   └── PerformancePanel
│
└── UI (CanvasLayer)
	├── TopBar
	├── SelectionPanel
	├── TacticsPanel
	├── BlueprintEditor
	└── SystemInfo
```

---

### 2.2 씬 구조 세부 설명

**Managers 노드**:
- 실제 로직은 모두 `RefCounted` 기반 GDScript 클래스
- Managers 노드는 단순히 스크립트를 attach하는 컨테이너
- `_ready()`에서 각 매니저 인스턴스 생성 및 초기화

```gdscript
# Managers 노드에 attach된 스크립트
extends Node

var simulation_manager: SimulationManager
var render_manager: RenderManager
var origin_manager: OriginManager
# ...

func _ready() -> void:
	simulation_manager = SimulationManager.new()
	render_manager = RenderManager.new()
	origin_manager = OriginManager.new()
	
	# 상호 참조 설정
	render_manager.simulation = simulation_manager
	origin_manager.camera = %Camera
	origin_manager.render_root = %RenderRoot
```

---

**World/RenderRoot 구조**:
- `RenderRoot`는 Floating Origin 이동의 타겟
- 모든 시각 요소는 RenderRoot 하위에 배치
- 레이어별로 분리하여 z-index 관리 용이

```gdscript
# OriginManager에서 호출
func _shift_origin(delta: Vector2) -> void:
	origin_offset += delta
	render_root.global_position -= delta
	camera.global_position -= delta
```

---

**Pools 노드**:
- 비활성 뷰 오브젝트를 보관
- 씬 시작 시 사전 생성 (prewarm)
- 풀 노드는 `visible = false`, `process_mode = DISABLED`

```gdscript
# ShipViewPool 예시
extends Node

var pool: Array[ShipView] = []
var ship_view_scene := preload("res://scenes/ship_view.tscn")

func prewarm(count: int) -> void:
	for i in range(count):
		var view = ship_view_scene.instantiate()
		view.visible = false
		view.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(view)
		pool.append(view)

func acquire() -> ShipView:
	if pool.is_empty():
		return _create_new()
	return pool.pop_back()

func release(view: ShipView) -> void:
	view.visible = false
	view.process_mode = Node.PROCESS_MODE_DISABLED
	pool.append(view)
```

---

### 2.3 매니저 구조 요약

```
GameManager (autoload singleton)
├── SimulationManager      # 게임 상태, 고정 틱 루프
├── RenderManager          # 시각화 레이어 관리
├── OriginManager          # Floating Origin 처리
├── SpatialManager         # 공간 분할 (Spatial Hash)
├── StreamingManager       # 청크 로드/언로드
├── PoolManager            # 오브젝트 풀링
└── EventBus               # 시스템 간 통신
```

**핵심**: 모든 매니저는 `RefCounted` 기반. Node 트리에 의존하지 않음.

---

### 2.4 SimulationManager

**책임**:
- 단일 진실 원천(Single Source of Truth)
- 고정 틱 루프
- 모든 게임 상태 소유

**데이터 구조**:
```gdscript
class_name SimulationManager extends RefCounted

var tick_count: int = 0
var galaxy_data: GalaxyData
var active_systems: Dictionary # system_id -> SystemData
var active_combats: Dictionary # combat_id -> CombatState

# 활성 엔티티 (현재 시뮬레이션 중인 것만)
var ships: Array[ShipData] = []
var projectiles: Array[ProjectileData] = []

# 공간 인덱스
var spatial_hash: SpatialHash

func _simulation_tick() -> void:
	tick_count += 1
	_update_physics()
	_update_projectiles()
	_process_damage_events()
	_update_ai()
	_check_lod_boundaries()
```

---

### 2.3 LOD 시스템 (단일 축)

**전투 내부 LOD만 사용** (맵 레벨 LOD 제거):

```gdscript
enum ShipLOD {
	FULL_CELL,      # 모든 셀 개별 시뮬레이션
	MODULE,         # 모듈 단위 집계
	SHIP_HP,        # 함선 전체 HP만
	DORMANT         # 비활성 (먼 함대)
}

func determine_ship_lod(ship: ShipData, camera_distance: float) -> ShipLOD:
	if camera_distance < 5000:
		return ShipLOD.FULL_CELL
	elif camera_distance < 20000:
		return ShipLOD.MODULE
	elif camera_distance < 100000:
		return ShipLOD.SHIP_HP
	else:
		return ShipLOD.DORMANT
```

**줌 레벨과 LOD의 관계**:
- 줌인 → 카메라 근처 함선은 FULL_CELL로 자동 전환
- 줌아웃 → 원거리 함선은 SHIP_HP로 저하
- 전투와 맵의 경계 없음. 단일 연속 공간

---

## 3. Cell-Based Ship Data

### 3.1 셀 압축 전략

**기본 원칙**: 전투 중/비전투 이중 구조

```gdscript
class ShipData extends RefCounted:
	var id: int
	var width: int
	var height: int
	
	# 압축 모드 (비전투, 원거리)
	var cells_compressed: PackedByteArray  # 32bit/cell
	
	# 언팩 모드 (전투 중, 근거리)
	var cells_expanded: Array[CellData] = []
	var is_expanded: bool = false
	
	# CRITICAL 셀 캐시
	var critical_cells: PackedInt32Array  # CRITICAL 모듈 셀 인덱스
	
	# Dirty Flag 시스템
	var dirty_cells: PackedInt32Array        # 이번 틱 변경된 셀
	var damaged_cells_cache: PackedInt32Array  # 현재 손상된 모든 셀
```

**압축 포맷 (32bit per cell)**:
```
bits 0-7:   hp_ratio (0-255)
bits 8-11:  material_id (16종)
bits 12-15: module_id (16종)
bits 16-19: flags (파괴됨, CRITICAL 등)
bits 20-31: reserved
```

**언팩 구조**:
```gdscript
class CellData:
	var hp: float
	var max_hp: float
	var material_id: int
	var module_id: int
	var is_critical: bool
	var is_destroyed: bool
```

---

### 3.2 CRITICAL 셀 시스템

**핵심 오해 방지**: 
- ❌ "CRITICAL 셀만 검사하고 일반 셀은 무시한다"
- ✅ "**모든 셀이 처리**되지만, 검사 방식과 우선순위가 다르다"

---

**목적**: 
- 매 틱 3600개 셀 전부 순회 방지
- 중요 시스템(원자로, AI 코어 등) 즉시 감지
- 피격된 셀만 선택적으로 처리

---

**3가지 셀 분류와 처리 방식**:

```
1. CRITICAL 셀 (10~50개):
   처리: 매 틱 능동 검사
   이유: 멜트다운, 유폭 같은 시간 기반 이벤트 즉시 감지
   예: 원자로, AI 코어, 탄약고, 주 엔진

2. 피격된 일반 셀 (0~수백 개):
   처리: Dirty Flag 방식 (피격 시점에만 검사)
   이유: 변화가 있을 때만 처리
   예: 손상된 장갑, 파괴된 구조 프레임

3. 건강한 일반 셀 (수천 개):
   처리: 안 함 (변화 없음)
   이유: CPU 낭비 방지
   예: 멀쩡한 장갑, 외장 패널
```

---

**처리 우선순위 전략**:

```gdscript
func _update_ship_systems(ship: ShipData) -> void:
	# 1. CRITICAL 셀 — 매 틱 검사 (30Hz)
	for cell_idx in ship.critical_cells:
		var cell = ship.cells_expanded[cell_idx]
		if cell.is_destroyed:
			_handle_critical_failure(ship, cell_idx)
		elif cell.hp < cell.max_hp * 0.3:
			_check_critical_degradation(ship, cell_idx)
	
	# 2. 피격된 일반 셀 — Dirty Flag (피격 시점만)
	for cell_idx in ship.dirty_cells_this_tick:
		var cell = ship.cells_expanded[cell_idx]
		_update_cell_state(ship, cell_idx)
		
		# 인접 셀 피해 전파
		if cell.is_destroyed:
			_propagate_damage(ship, cell_idx)
	
	# 3. 건강한 일반 셀 — 검사 안 함
	# (CPU 절약)
```

---

**Dirty Flag 시스템 상세**:

```gdscript
class ShipData:
	var cells_expanded: Array[CellData]
	var critical_cells: PackedInt32Array      # CRITICAL 셀 인덱스
	var dirty_cells_this_tick: PackedInt32Array  # 이번 틱 피격 셀
	var damaged_cells_cache: Dictionary       # cell_idx -> ticks_since_damage

# 피격 시 Dirty Flag 설정
func _apply_damage_to_cell(ship: ShipData, cell_idx: int, damage: float) -> void:
	var cell = ship.cells_expanded[cell_idx]
	cell.hp = max(0, cell.hp - damage)
	
	# Dirty 마크
	if cell_idx not in ship.dirty_cells_this_tick:
		ship.dirty_cells_this_tick.append(cell_idx)
	
	# 지속 추적 (화재, 열 전파 등)
	ship.damaged_cells_cache[cell_idx] = 0

# 매 틱 종료 시 정리
func _cleanup_dirty_flags(ship: ShipData) -> void:
	ship.dirty_cells_this_tick.clear()
	
	# 10틱 동안 변화 없으면 캐시에서 제거
	for cell_idx in ship.damaged_cells_cache.keys():
		ship.damaged_cells_cache[cell_idx] += 1
		if ship.damaged_cells_cache[cell_idx] > 10:
			ship.damaged_cells_cache.erase(cell_idx)
```

---

**실제 처리량 비교 (60×60 함선)**:

```
총 셀: 3600개

기존 방식 (전체 순회):
  매 틱 검사: 3600개 × 30Hz = 108,000 검사/초

CRITICAL + Dirty Flag 방식:
  CRITICAL: 30개 × 30Hz = 900 검사/초
  피격 셀: 평균 10개/틱 × 30Hz = 300 검사/초
  총: 1,200 검사/초

절감: 108,000 → 1,200 = 99% 감소
```

---

**핵심 정리**:

✅ **모든 셀이 정상 처리됨**:
- 피격 = 즉시 Dirty Flag 설정 → 다음 틱 처리
- 인접 셀 피해 전파 작동
- 파괴 효과, 모듈 성능 저하 적용

✅ **CRITICAL 셀의 특별함**:
- 피격 여부 무관하게 매 틱 검사
- 시간 기반 이벤트 즉시 감지 (멜트다운 카운트다운 등)

✅ **성능 최적화**:
- 건강한 셀은 검사 안 함
- 99% CPU 절감

---

**CRITICAL 셀 태깅**:

```gdscript
func tag_critical_cells(ship: ShipData) -> void:
	ship.critical_cells.clear()
	for i in range(ship.cells_expanded.size()):
		var cell = ship.cells_expanded[i]
		if _is_critical_module(cell.module_id):
			ship.critical_cells.append(i)

func _is_critical_module(module_id: int) -> bool:
	match module_id:
		ModuleType.REACTOR, \
		ModuleType.AI_CORE, \
		ModuleType.AMMO_STORAGE, \
		ModuleType.MAIN_ENGINE, \
		ModuleType.POWER_CORE:
			return true
		_:
			return false
```

---

**틱별 처리 분산**:

```gdscript
func _simulation_tick() -> void:
	for ship in ships:
		if not ship.is_expanded:
			continue
		
		# 매 틱: CRITICAL 셀 + Dirty 셀
		_check_critical_cells(ship)
		_process_dirty_cells(ship)
		
		# 10틱마다: 손상된 일반 셀 (성능 저하 재계산)
		if tick_count % 10 == 0:
			_update_damaged_cells(ship)
		
		# 30틱마다: 전체 셀 정합성 검사 (디버그/안전성)
		if tick_count % 30 == 0:
			_validate_all_cells(ship)
	
	# Dirty 플래그 초기화
	for ship in ships:
		ship.dirty_cells.clear()
```

---

**결론**:
- **CRITICAL 셀**: 매 틱 검사 (원자로 멜트다운, AI 코어 파괴 등 즉각 처리)
- **손상된 셀**: Dirty Flag로 변화 추적, 주기적 업데이트
- **정상 셀**: 매우 낮은 빈도로 검사 (거의 변화 없음)
- **모든 셀**: 피격 시 즉시 HP 감소. 단지 후속 처리 빈도가 다름

---

### 3.3 압축/언팩 전환 (재정의)

**핵심 변경**: 메모리가 충분하므로 압축은 성능 최적화 수단

**명확한 언팩 기준**:
```gdscript
const EXPAND_DISTANCE = 10000.0      # 카메라 10km 이내
const COMPRESS_DISTANCE = 15000.0    # 카메라 15km 밖 (히스테리시스)
const DAMAGE_MEMORY = 10.0           # 피격 후 10초간 유지

func _update_expansion_state(ship: ShipData) -> void:
	var should_expand = (
		ship.position.distance_to(camera.position) < EXPAND_DISTANCE or
		ship.is_firing or
		(tick_count - ship.last_damage_tick) < DAMAGE_MEMORY * 30 or
		ship.id in player_selected_ships or
		ship.is_flagship
	)
	
	if should_expand and not ship.is_expanded:
		_expand_ship(ship)
	elif not should_expand and ship.is_expanded:
		# 압축 조건: 카메라 멀고 + 전투 안 함 + 선택 안됨
		if ship.position.distance_to(camera.position) > COMPRESS_DISTANCE:
			_compress_ship(ship)
```

**압축의 실제 이점**:
1. **캐시 효율**: 압축 데이터 순회가 더 빠름
2. **업데이트 단순화**: 비전투 함선은 위치만 갱신
3. **LOD 자연 통합**: 압축=저디테일 시뮬레이션

**개발 전략**:
```
Phase 1-2: 압축 구현 없이 전부 언팩으로 개발
  → 단순하고 디버깅 쉬움
  → 메모리 2.5GB 사용 (충분)

Phase 3: 성능 병목 발견 시 선택적 압축 도입
  → 프로파일링 후 실측 이득 확인
  → 이득 없으면 압축 제거 고려
```

---

## 4. Spatial Hash (공간 분할)

### 4.1 구조

**목적**: O(n²) 충돌 검사 → O(n)

```gdscript
class SpatialHash extends RefCounted:
	const CELL_SIZE = 2000.0  # 셀 크기 (game units)
	
	var grid: Dictionary = {}  # Vector2i -> Array[int] (ship_ids)
	
	func insert(ship_id: int, pos: Vector2) -> void:
		var cell = _to_cell(pos)
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(ship_id)
	
	func query_radius(pos: Vector2, radius: float) -> Array[int]:
		var results: Array[int] = []
		var center_cell = _to_cell(pos)
		var cell_radius = ceili(radius / CELL_SIZE)
		
		for dy in range(-cell_radius, cell_radius + 1):
			for dx in range(-cell_radius, cell_radius + 1):
				var cell = center_cell + Vector2i(dx, dy)
				if grid.has(cell):
					results.append_array(grid[cell])
		
		return results
	
	func _to_cell(pos: Vector2) -> Vector2i:
		return Vector2i(
			floori(pos.x / CELL_SIZE),
			floori(pos.y / CELL_SIZE)
		)
```

**사용 예시**:
```gdscript
# 탄체 충돌 검사
func _check_projectile_hits(proj: ProjectileData) -> void:
	var nearby_ships = spatial_hash.query_radius(proj.position, 100.0)
	for ship_id in nearby_ships:
		if _intersects(proj, ships_dict[ship_id]):
			_apply_damage(ship_id, proj)
```

---

### 4.2 업데이트 전략

**문제**: 함선이 이동하면 셀이 바뀜 → 재삽입 필요

**해결**:
```gdscript
# 매 틱 전체 재구축 (간단하고 안정적)
func rebuild_spatial_hash() -> void:
	spatial_hash.clear()
	for ship in ships:
		if ship.alive:
			spatial_hash.insert(ship.id, ship.position)
```

**최적화 (선택)**:
- Dirty Flag: 이동한 함선만 재삽입
- 하지만 전체 재구축도 충분히 빠름 (~0.2ms for 2000 ships)

---

## 5. Damage Pipeline

### 5.1 Event Queue 기반

**문제**: 탄체 충돌 즉시 셀 파괴하면 순회 중 배열 변경 위험

**해결**: 이벤트 큐에 누적 후 일괄 처리

```gdscript
class DamageEvent:
	var ship_id: int
	var cell_index: int
	var damage: float
	var damage_type: int  # 관통, 폭발, 에너지 등

var damage_queue: Array[DamageEvent] = []

func _process_projectile_hit(proj: ProjectileData, ship: ShipData) -> void:
	var cell_idx = _ray_to_cell(proj.position, ship)
	if cell_idx >= 0:
		damage_queue.append(DamageEvent.new(
			ship.id, cell_idx, proj.damage, proj.damage_type
		))
```

**일괄 처리 + Dirty Flag**:
```gdscript
func _process_damage_events() -> void:
	for event in damage_queue:
		var ship = ships_dict[event.ship_id]
		if not ship.is_expanded:
			_expand_ship(ship)  # 피격 시 강제 언팩
		
		var cell = ship.cells_expanded[event.cell_index]
		var old_hp = cell.hp
		
		# 피해 적용
		_apply_damage_to_cell(cell, event.damage, event.damage_type)
		
		# Dirty Flag 설정
		if cell.hp != old_hp:
			if event.cell_index not in ship.dirty_cells:
				ship.dirty_cells.append(event.cell_index)
			
			# 손상 캐시 업데이트
			if cell.hp < cell.max_hp and event.cell_index not in ship.damaged_cells_cache:
				ship.damaged_cells_cache.append(event.cell_index)
			
			# 파괴 시 캐시에서 제거
			if cell.hp == 0:
				ship.damaged_cells_cache.erase(event.cell_index)
	
	damage_queue.clear()
```

**핵심**: 
- 모든 셀 피해는 즉시 반영
- Dirty Flag로 변경된 셀만 추적
- 후속 처리(성능 저하, 연쇄 효과)는 Dirty 셀에만 적용

---

### 5.2 도탄/관통 로직

**재질별 물성치**:
```gdscript
class MaterialData extends Resource:
	@export var density: float
	@export var hardness: float
	@export var reflection_angle: float  # 도탄 각도

var materials: Dictionary = {}  # material_id -> MaterialData

func _calculate_penetration(
	damage: float,
	cell: CellData,
	impact_angle: float
) -> bool:
	var mat = materials[cell.material_id]
	
	# 입사각 도탄 체크
	if impact_angle > mat.reflection_angle:
		return false  # 도탄
	
	# 관통력 계산
	var armor_value = cell.hp * mat.density * mat.hardness
	return damage > armor_value
```

---

### 5.3 연쇄 파괴 (유폭, 멜트다운)

**원자로 멜트다운 예시**:
```gdscript
class ReactorMeltdown:
	var ship_id: int
	var cell_index: int
	var countdown_ticks: int
	var suppression_attempts: Array[int] = []

var active_meltdowns: Array[ReactorMeltdown] = []

func _check_reactor_damage(ship: ShipData, reactor_cell_idx: int) -> void:
	var cell = ship.cells_expanded[reactor_cell_idx]
	var hp_ratio = cell.hp / cell.max_hp
	
	if hp_ratio < 0.25:
		# 멜트다운 시작
		active_meltdowns.append(ReactorMeltdown.new(
			ship.id, reactor_cell_idx, 90  # 3초 (30Hz)
		))

func _update_meltdowns() -> void:
	for meltdown in active_meltdowns:
		meltdown.countdown_ticks -= 1
		
		if _is_suppressed(meltdown):
			# 억제 성공 → 소규모 폭발
			_trigger_small_explosion(meltdown)
			active_meltdowns.erase(meltdown)
		elif meltdown.countdown_ticks <= 0:
			# 억제 실패 → 대규모 폭발
			_trigger_large_explosion(meltdown)
			active_meltdowns.erase(meltdown)
```

---

## 6. GPU Compute Shader

### 6.1 적용 대상

**CPU → GPU 이전 후보**:
1. 셀 피해 전파 (인접 셀 열/충격 확산)
2. 폭발 반경 계산
3. 에너지 무기 반사 각도
4. 압력 시뮬레이션 (선택)

**기준**:
- 병렬화 가능한 작업
- 데이터 종속성 낮음
- 계산량 > 데이터 전송 비용

---

### 6.2 구현 예시 (피해 전파)

**Compute Shader (GLSL)**:
```glsl
#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16) in;

layout(set = 0, binding = 0, std430) buffer CellBuffer {
	float cells[];  // hp, max_hp, material_id, ...
};

layout(push_constant, std430) uniform Params {
	int width;
	int height;
	float damage_falloff;
} params;

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	if (pos.x >= params.width || pos.y >= params.height) return;
	
	int idx = pos.y * params.width + pos.x;
	float hp = cells[idx * 4 + 0];
	
	if (hp <= 0.0) {
		// 파괴된 셀 → 인접 셀에 피해 전파
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				if (dx == 0 && dy == 0) continue;
				ivec2 neighbor = pos + ivec2(dx, dy);
				if (neighbor.x < 0 || neighbor.x >= params.width) continue;
				if (neighbor.y < 0 || neighbor.y >= params.height) continue;
				
				int n_idx = neighbor.y * params.width + neighbor.x;
				atomicAdd(cells[n_idx * 4 + 0], -params.damage_falloff);
			}
		}
	}
}
```

**GDScript 호출**:
```gdscript
var rd := RenderingServer.create_local_rendering_device()
var shader_file := load("res://shaders/cell_damage.glsl")
var shader := rd.shader_create_from_spirv(shader_file.get_spirv())

func _apply_gpu_damage_propagation(ship: ShipData) -> void:
	# 1. CPU → GPU 버퍼 전송
	var cell_buffer = _create_cell_buffer(ship)
	
	# 2. Compute Shader 실행
	var pipeline = rd.compute_pipeline_create(shader)
	var dispatch_x = ceili(float(ship.width) / 16.0)
	var dispatch_y = ceili(float(ship.height) / 16.0)
	rd.compute_list_dispatch(pipeline, dispatch_x, dispatch_y, 1)
	
	# 3. GPU → CPU 결과 읽기
	_read_back_cell_buffer(ship, cell_buffer)
```

**주의**: 
- 버퍼 전송 비용 > 계산 이득이면 오히려 느려짐
- 프로토타입 후 실측 필요

---

## 7. Floating Origin

### 7.1 목적

**문제**: 부동소수점 정밀도
- 은하 스케일: 수십만 ~ 수백만 단위
- float32 정밀도: ~10^-6 at 10^6
- 멀리 떨어진 좌표에서 떨림 발생

**해결**: 카메라 중심으로 월드 재조정

---

### 7.2 구현

```gdscript
class OriginManager extends RefCounted:
	const SHIFT_THRESHOLD = 50000.0
	
	var origin_offset: Vector2 = Vector2.ZERO
	var camera: Camera2D
	var render_root: Node2D
	
	func update(delta: float) -> void:
		var cam_pos = camera.global_position
		if cam_pos.length() > SHIFT_THRESHOLD:
			_shift_origin(cam_pos)
	
	func _shift_origin(delta: Vector2) -> void:
		# 1. 오프셋 누적
		origin_offset += delta
		
		# 2. 렌더 루트 이동
		render_root.global_position -= delta
		camera.global_position -= delta
		
		# 3. 시뮬레이션 좌표는 그대로
		# (정규 좌표 = 렌더 좌표 + origin_offset)
```

**좌표 변환**:
```gdscript
# 시뮬레이션 → 렌더
func sim_to_render(sim_pos: Vector2) -> Vector2:
	return sim_pos - origin_offset

# 렌더 → 시뮬레이션
func render_to_sim(render_pos: Vector2) -> Vector2:
	return render_pos + origin_offset
```

---

## 8. Streaming & Chunking

### 8.1 은하 청크 분할

**목적**: 1000개 성계를 한번에 로드하면 메모리/성능 낭비

**구조**:
```gdscript
class StreamingManager extends RefCounted:
	const CHUNK_SIZE = 10000.0  # 청크 크기 (game units)
	const LOAD_RADIUS = 2       # 로드 반경 (청크 단위)
	
	var galaxy_chunks: Dictionary = {}  # Vector2i -> ChunkData
	var loaded_chunks: Dictionary = {}  # Vector2i -> bool
	
	class ChunkData:
		var systems: Array[SystemData] = []
		var is_loaded: bool = false
```

**로드/언로드**:
```gdscript
func update_streaming(camera_pos: Vector2) -> void:
	var cam_chunk = _to_chunk(camera_pos)
	
	# 로드할 청크 결정
	var desired_chunks: Dictionary = {}
	for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var chunk_pos = cam_chunk + Vector2i(dx, dy)
			desired_chunks[chunk_pos] = true
			
			if not loaded_chunks.has(chunk_pos):
				_load_chunk(chunk_pos)
	
	# 언로드할 청크
	for chunk_pos in loaded_chunks.keys():
		if not desired_chunks.has(chunk_pos):
			_unload_chunk(chunk_pos)

func _to_chunk(pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(pos.x / CHUNK_SIZE),
		floori(pos.y / CHUNK_SIZE)
	)
```

---

### 8.2 전투 활성/비활성 전략

**핵심 원칙**: 카메라에서 먼 전투는 결과만 계산

```gdscript
enum CombatDetail {
	FULL,      # 셀 단위 시뮬레이션 (카메라 근처)
	SUMMARY,   # 집계 전투력 계산 (중거리)
	DORMANT    # 결과만 예측 (원거리)
}

func _determine_combat_detail(combat: CombatState, cam_pos: Vector2) -> CombatDetail:
	var distance = combat.center.distance_to(cam_pos)
	
	if distance < 5000:
		return CombatDetail.FULL
	elif distance < 50000:
		return CombatDetail.SUMMARY
	else:
		return CombatDetail.DORMANT
```

**FULL (전체 시뮬레이션)**:
```gdscript
func _activate_combat_full(combat: CombatState) -> void:
	# 1. 함선 데이터 언팩
	for ship_id in combat.ship_ids:
		var ship = ships_dict[ship_id]
		if not ship.is_expanded:
			_expand_ship(ship)
	
	# 2. 렌더 뷰 생성
	pool_manager.spawn_combat_views(combat.ship_ids)
	
	# 3. Spatial Hash에 등록
	for ship_id in combat.ship_ids:
		spatial_hash.insert(ship_id, ships_dict[ship_id].position)
	
	combat.detail = CombatDetail.FULL
```

**SUMMARY (집계 계산)**:
```gdscript
func _update_combat_summary(combat: CombatState) -> void:
	# 전투력 집계
	var side_a_power = 0.0
	var side_b_power = 0.0
	
	for ship_id in combat.side_a:
		var ship = ships_dict[ship_id]
		side_a_power += ship.total_hp * ship.firepower
	
	for ship_id in combat.side_b:
		var ship = ships_dict[ship_id]
		side_b_power += ship.total_hp * ship.firepower
	
	# 단순 확률 계산
	var power_ratio = side_a_power / (side_a_power + side_b_power)
	var damage_rate = 0.01  # 초당 1% HP 손실 (예시)
	
	# 양측에 피해 분배
	_apply_summary_damage(combat.side_a, damage_rate * (1.0 - power_ratio))
	_apply_summary_damage(combat.side_b, damage_rate * power_ratio)
```

**DORMANT (결과만)**:
```gdscript
func _resolve_dormant_combat(combat: CombatState) -> void:
	# 전투력 비율로 즉시 결과 예측
	var winner = _predict_winner(combat)
	var losses = _predict_losses(combat)
	
	# 함선 상태만 업데이트 (시뮬레이션 생략)
	_apply_predicted_result(combat, winner, losses)
	
	combat.is_resolved = true
```

---

### 8.3 스트리밍 성능 최적화

**비동기 로딩**:
```gdscript
func _load_chunk_async(chunk_pos: Vector2i) -> void:
	# 1. 청크 데이터 비동기 읽기
	var chunk_data = await _read_chunk_from_disk(chunk_pos)
	
	# 2. 메인 스레드에서 등록
	galaxy_chunks[chunk_pos] = chunk_data
	loaded_chunks[chunk_pos] = true
	
	# 3. 렌더 마커 생성
	_create_system_markers(chunk_data.systems)
```

**사전 로딩 (Prefetch)**:
```gdscript
func _prefetch_chunks(camera_pos: Vector2, camera_velocity: Vector2) -> void:
	# 카메라 이동 방향 예측
	var predicted_pos = camera_pos + camera_velocity * 5.0  # 5초 후
	var target_chunk = _to_chunk(predicted_pos)
	
	# 이동 방향 청크 우선 로드
	if not loaded_chunks.has(target_chunk):
		_load_chunk_async(target_chunk)
```

**메모리 압박 시 강제 언로드**:
```gdscript
func _check_memory_pressure() -> void:
	var current_usage = OS.get_static_memory_usage()
	var threshold = 3.0 * 1024 * 1024 * 1024  # 3GB
	
	if current_usage > threshold:
		# 가장 먼 청크부터 언로드
		var chunks_by_distance = _sort_chunks_by_distance(camera.position)
		for chunk_pos in chunks_by_distance:
			if current_usage < threshold * 0.9:
				break
			_unload_chunk(chunk_pos)
			current_usage = OS.get_static_memory_usage()
```

---

### 8.4 전투 전환 시나리오

**시나리오 1: 줌인 (DORMANT → FULL)**:
```
1. 전투 감지 (카메라 5km 진입)
2. 함선 데이터 언팩 시작 (비동기)
3. 렌더 뷰 풀에서 할당
4. Spatial Hash 등록
5. 전체 시뮬레이션 시작
→ 소요 시간: ~100ms (사전 워밍 시 ~20ms)
```

**시나리오 2: 줌아웃 (FULL → SUMMARY)**:
```
1. 카메라 5km 이탈
2. 렌더 뷰 풀로 반환
3. Spatial Hash에서 제거
4. 함선 데이터 압축 (선택)
5. 집계 모드 전환
→ 소요 시간: ~50ms
```

---

### 8.5 스트리밍 디버그 도구

```gdscript
func _draw_streaming_debug() -> void:
	var debug_label = %DebugLabel
	var cam_chunk = _to_chunk(camera.position)
	
	var text = "Streaming Info:\n"
	text += "Camera Chunk: %s\n" % cam_chunk
	text += "Loaded Chunks: %d\n" % loaded_chunks.size()
	text += "Active Combats: %d\n" % active_combats.size()
	text += "  - FULL: %d\n" % _count_combats_by_detail(CombatDetail.FULL)
	text += "  - SUMMARY: %d\n" % _count_combats_by_detail(CombatDetail.SUMMARY)
	text += "  - DORMANT: %d\n" % _count_combats_by_detail(CombatDetail.DORMANT)
	
	debug_label.text = text
```

---

## 9. Object Pooling

### 9.1 풀 구조

```gdscript
class PoolManager extends RefCounted:
	var ship_view_pool: Array[Node2D] = []
	var projectile_view_pool: Array[Sprite2D] = []
	var vfx_pool: Array[GPUParticles2D] = []
	
	var active_views: Dictionary = {}  # entity_id -> Node
	
	func spawn_ship_view(ship_id: int) -> Node2D:
		var view: Node2D
		if ship_view_pool.is_empty():
			view = _create_ship_view()
		else:
			view = ship_view_pool.pop_back()
		
		view.visible = true
		active_views[ship_id] = view
		return view
	
	func despawn_ship_view(ship_id: int) -> void:
		var view = active_views.get(ship_id)
		if view:
			view.visible = false
			ship_view_pool.append(view)
			active_views.erase(ship_id)
```

---

### 9.2 사전 워밍

```gdscript
func prewarm_pools(expected_ships: int, expected_projectiles: int) -> void:
	for i in range(expected_ships):
		ship_view_pool.append(_create_ship_view())
	
	for i in range(expected_projectiles):
		projectile_view_pool.append(_create_projectile_view())
```

**호출 시점**: 
- 게임 시작 시
- 대규모 전투 진입 전

---

## 10. Render Pipeline

### 10.1 시뮬레이션 → 렌더 분리

**원칙**: 렌더는 시뮬레이션 읽기 전용

```gdscript
# SimulationManager
signal snapshot_updated(snapshot: RenderSnapshot)

class RenderSnapshot:
	var ships: Array[ShipRenderData]
	var projectiles: Array[ProjectileRenderData]
	var vfx_events: Array[VFXEvent]

func _emit_render_snapshot() -> void:
	var snapshot = RenderSnapshot.new()
	for ship in ships:
		if ship.visible_to_camera:
			snapshot.ships.append(_make_ship_render_data(ship))
	
	snapshot_updated.emit(snapshot)
```

**렌더러**:
```gdscript
# RenderManager
func _on_snapshot_updated(snapshot: RenderSnapshot) -> void:
	_update_ship_views(snapshot.ships)
	_update_projectile_views(snapshot.projectiles)
	_spawn_vfx(snapshot.vfx_events)
```

---

### 10.2 보간 (Interpolation)

**문제**: 30Hz 시뮬레이션 + 60Hz 렌더 = 뚝뚝 끊김

**해결**: 이전/현재 상태 사이 보간

```gdscript
class ShipView extends Node2D:
	var prev_pos: Vector2
	var curr_pos: Vector2
	var prev_rot: float
	var curr_rot: float
	
	func _process(delta: float) -> void:
		var alpha = simulation_manager.get_interpolation_alpha()
		position = prev_pos.lerp(curr_pos, alpha)
		rotation = lerp_angle(prev_rot, curr_rot, alpha)

# SimulationManager
func get_interpolation_alpha() -> float:
	return accumulator / FIXED_DELTA
```

---

## 11. AI 위임 시스템 통합

### 11.1 처리 예산 스케줄러

```gdscript
class AICore:
	var ship_id: int
	var processing_points: float
	var delegations: Dictionary = {}  # task_type -> bool
	
	const TASK_COSTS = {
		"target_selection": 8.0,
		"evasion": 10.0,
		"ecm": 30.0,
		"path_planning": 10.0,
	}
	
	func allocate_budget() -> void:
		var total_cost = 0.0
		var enabled_tasks = []
		
		for task in delegations:
			if delegations[task]:
				total_cost += TASK_COSTS[task]
				enabled_tasks.append(task)
		
		if total_cost > processing_points:
			# 예산 초과 → 우선순위 낮은 작업 비활성
			_disable_low_priority_tasks(enabled_tasks)
```

---

### 11.2 전자전 효과 전파

**ECM/ECCM 시스템**: GDD의 전자전 설계 반영

```gdscript
func _apply_ecm_effects() -> void:
	for ship in ships:
		if not ship.ai_core or not ship.ai_core.delegations.get("ecm", false):
			continue
		
		var ecm_grade = ship.ecm_research_level  # Mk.I, Mk.II, Mk.III
		var ecm_output = ship.ai_core.processing_points * ECM_EFFICIENCY[ecm_grade]
		var affected = spatial_hash.query_radius(ship.position, ECM_RADIUS)
		
		for target_id in affected:
			var target = ships_dict[target_id]
			if target.faction_id == ship.faction_id:
				continue
			
			var eccm_grade = target.eccm_research_level
			var eccm_resist = target.ai_core.processing_points * ECCM_EFFICIENCY[eccm_grade]
			var jamming_strength = max(0, ecm_output - eccm_resist)
			
			if jamming_strength > 0:
				# 교란 효과 적용
				target.sensor_range *= (1.0 - jamming_strength * 0.01)
				target.accuracy_penalty += jamming_strength * 0.005
				
				# 네트워크 분리 (ECCM Mk.II 이상은 자동 격리)
				if eccm_grade < 2:  # Mk.II 미만
					target.ai_network_disconnected = true
```

**주요 포인트**:
- ECM/ECCM 등급은 연구로 해금 (GDD 5.11절)
- 성능 = 처리 포인트 × 등급 효율 계수
- 교란 강도 = ECM 출력 - ECCM 저항
- AI 네트워크 통신 차단은 ECCM 등급에 따라 방어 가능

---

## 12. Performance Targets

### 12.1 목표 스케일

```
함선:         2000척
셀:          10M (평균 5000/ship)
발사체:      20000개
피해 이벤트:  50000/tick

틱 예산:     33ms (30Hz)
```

---

### 12.2 프로파일링 포인트

```gdscript
var perf_timers: Dictionary = {}

func _simulation_tick() -> void:
	perf_timers["physics"] = Time.get_ticks_usec()
	_update_physics()
	
	perf_timers["projectiles"] = Time.get_ticks_usec()
	_update_projectiles()
	
	perf_timers["damage"] = Time.get_ticks_usec()
	_process_damage_events()
	
	perf_timers["ai"] = Time.get_ticks_usec()
	_update_ai()
	
	_print_perf_summary()

func _print_perf_summary() -> void:
	var total_us = Time.get_ticks_usec() - perf_timers["physics"]
	print("Tick %d: %.2f ms total" % [tick_count, total_us / 1000.0])
	print("  Physics: %.2f ms" % [(perf_timers["projectiles"] - perf_timers["physics"]) / 1000.0])
	print("  Projectiles: %.2f ms" % [(perf_timers["damage"] - perf_timers["projectiles"]) / 1000.0])
	# ...
```

---

## 13. Memory Budget

### 13.1 현실적인 메모리 예산

**타겟 시스템**: 
- 최소: 8GB RAM (게임 할당 4GB)
- 권장: 16GB RAM (게임 할당 8GB)
- 이상: 32GB RAM (게임 할당 16GB)

**메모리 분배 전략**:
```
총 8GB 할당 기준:
  시뮬레이션 데이터: 2GB
  렌더 리소스:      3GB (텍스처, 메쉬, 셰이더)
  오디오:           500MB
  UI/기타:          500MB
  시스템 여유:      2GB
```

---

### 13.2 함선 데이터 메모리 계산

**압축 모드 (비전투, 원거리)**:
```
60×60 셀 함선:
  cells_compressed: 3600 × 4 bytes = 14.4 KB
  메타데이터: ~1 KB (position, velocity, id 등)
  총: ~15 KB/ship

2000척 전부 압축:
  = 2000 × 15 KB = 30 MB
```

**언팩 모드 (전투 중, 근거리)**:
```
60×60 셀 함선:
  cells_expanded: 3600 × 32 bytes = 115.2 KB
  메타데이터: ~1 KB
  총: ~116 KB/ship

2000척 전부 언팩:
  = 2000 × 116 KB = 232 MB
```

**현실적인 혼합 시나리오**:
```
시나리오 1: 대규모 전투 (보수적)
  전투 중 (언팩): 200척 × 116 KB = 23.2 MB
  대기/이동 (압축): 1800척 × 15 KB = 27 MB
  총: 50.2 MB

시나리오 2: 초대규모 전투 (공격적)
  전투 중 (언팩): 1000척 × 116 KB = 116 MB
  대기/이동 (압축): 1000척 × 15 KB = 15 MB
  총: 131 MB

시나리오 3: 전면전 (최대)
  전투 중 (언팩): 2000척 × 116 KB = 232 MB
  총: 232 MB (압축 함선 없음)
```

**결론**: 
- **232 MB는 2GB 시뮬레이션 예산의 11.6%에 불과**
- **전부 언팩해도 충분한 여유**
- 하지만 압축/언팩 구조는 성능 최적화용으로 유지

---

### 13.3 언팩 기준 재정의

**기존 문제점**: "전투 중"이라는 모호한 기준

**새로운 언팩 기준 (명확)**:

```gdscript
enum UnpackTrigger {
	DISTANCE,      # 카메라 거리 기준
	COMBAT,        # 교전 상태
	DAMAGE,        # 피격 경험
	PLAYER_CONTROL # 플레이어 직접 제어
}

func should_expand_ship(ship: ShipData) -> bool:
	# 1. 카메라 거리 (가장 명확)
	var cam_distance = ship.position.distance_to(camera.position)
	if cam_distance < EXPAND_DISTANCE_THRESHOLD:  # 예: 10,000
		return true
	
	# 2. 교전 중 (공격 또는 피격)
	if ship.is_firing or ship.time_since_last_damage < 10.0:
		return true
	
	# 3. 플레이어가 선택한 함선
	if ship.id in player_selected_ships:
		return true
	
	# 4. 중요 함선 (항상 언팩)
	if ship.is_flagship or ship.is_player_ship:
		return true
	
	return false
```

**임계값 예시**:
```
EXPAND_DISTANCE_THRESHOLD = 10,000  # 카메라 근처만
COMPRESS_DISTANCE_THRESHOLD = 15,000  # 히스테리시스
DAMAGE_MEMORY_DURATION = 10.0  # 피격 후 10초간 언팩 유지
```

---

### 13.4 압축의 실제 목적 재정의

**메모리 절약 ✗** → 이미 충분함

**실제 목적 ○**:
1. **캐시 효율**: 압축 데이터가 캐시 라인에 더 많이 적재
2. **순회 속도**: 비전투 함선은 간소화된 업데이트만 필요
3. **LOD 통합**: 압축=저디테일, 언팩=고디테일

```gdscript
# 압축 상태 = 단순 업데이트
func _update_compressed_ship(ship: ShipData) -> void:
	ship.position += ship.velocity * delta
	# HP는 집계값만. 개별 셀 무시

# 언팩 상태 = 전체 시뮬레이션
func _update_expanded_ship(ship: ShipData) -> void:
	ship.position += ship.velocity * delta
	_check_critical_cells(ship)
	_update_module_states(ship)
	_process_damage_propagation(ship)
```

---

### 13.5 메모리 최적화 우선순위 재정렬

**높은 우선순위** (실제 문제):
1. 렌더 리소스 (텍스처, 메쉬) — 가장 큰 메모리 소비
2. 발사체 오브젝트 풀 크기
3. VFX 파티클 시스템
4. 사운드 버퍼

**낮은 우선순위** (이미 충분):
1. 함선 셀 데이터 압축
2. AI 처리 데이터 구조
3. 경로 탐색 캐시

**권장 접근**:
```
개발 초기: 전부 언팩 상태로 개발
  → 단순하고 디버깅 쉬움
  → 메모리 문제 없음

성능 병목 발견 시: 선택적 압축 도입
  → 프로파일링 결과 기반
  → 실측 이득 확인 후 적용
```

---

### 13.6 실전 메모리 예산 (재계산)

```
2000척 시나리오 (전부 언팩):
  함선 셀 데이터:     232 MB
  함선 메타데이터:    10 MB (ShipData 구조체)
  발사체 (20K):       1.3 MB
  Spatial Hash:       5 MB
  Event Queue:        10 MB
  AI 처리 데이터:     20 MB
  경로 캐시:          20 MB
  기타 시뮬레이션:    50 MB
  ─────────────────────────
  총 시뮬레이션:      ~350 MB

렌더 리소스:
  함선 텍스처/메쉬:   500 MB (LOD 여러 단계)
  발사체 스프라이트:  50 MB
  VFX 텍스처:         200 MB
  UI 텍스처:          100 MB
  배경/행성:          300 MB
  ─────────────────────────
  총 렌더:            ~1150 MB

오디오:               500 MB
UI/기타:              500 MB
─────────────────────────────
총 게임 메모리:       ~2500 MB (2.5 GB)

여유 공간:            5.5 GB (8GB 할당 기준)
```

**결론**: 메모리는 전혀 문제 없음. 압축은 선택 사항.

---

## 14. Implementation Roadmap

### Phase 1: Core Foundation
- [ ] SimulationManager 고정 틱 루프
- [ ] ShipData 기본 구조 (언팩 모드만, 압축 제외)
- [ ] Spatial Hash 구현
- [ ] Damage Event Queue
- [ ] Dirty Flag 시스템
- [ ] CRITICAL 셀 태깅

**주의**: 압축/언팩은 Phase 3 이후. Phase 1은 단순하게.

### Phase 2: Combat Simulation
- [ ] 발사체 시스템
- [ ] 도탄/관통 로직
- [ ] CRITICAL 셀 시스템 (멜트다운, 유폭)
- [ ] AI 위임 스케줄러

### Phase 3: Optimization
- [ ] Object Pooling
- [ ] LOD 시스템
- [ ] Floating Origin
- [ ] **성능 측정 후 압축/언팩 도입 여부 결정**
- [ ] Compute Shader 프로토타입 (CPU 버전과 비교 측정)

### Phase 4: Scalability
- [ ] Streaming Manager
- [ ] 청크 로드/언로드
- [ ] 대규모 전투 테스트 (1000 vs 1000)

### Phase 5: Integration
- [ ] AI 위임 스케줄러 최적화
- [ ] 전자전 효과 전파
- [ ] 렌더 보간
- [ ] 최종 성능 튜닝

---

## 15. Critical Warnings

### ⚠️ 반드시 피해야 할 것

1. **함선당 Node2D 생성**
   - 2000개 Node = 씬 트리 폭발
   - 렌더만 Node, 시뮬레이션은 순수 데이터

2. **Dictionary 순회**
   - 순서 불확정 = 결정론 파괴
   - 조회용만 사용, 순회는 Array

3. **매 프레임 전체 셀 순회**
   - 10M 셀 × 60 FPS = 불가능
   - Dirty Flag + CRITICAL 셀 우선

4. **공간 분할 없이 충돌 검사**
   - O(n²) = 2000² = 4M 연산
   - Spatial Hash 필수

5. **압축 없이 모든 함선 언팩**
   - 2000 × 115 KB = 230 MB
   - 비전투 함선은 압축 유지

---

## 18. Advanced Topics

### 18.1 Multithreading (선택)

**기본 전략**: 단일 스레드 시뮬레이션부터 시작

```gdscript
# Phase 1-3: 단일 스레드
func _simulation_tick() -> void:
	_update_physics()
	_update_projectiles()
	_process_damage_events()
	_update_ai()
```

**멀티스레드 도입 (Phase 4 이후, 필요 시)**:
```gdscript
var physics_thread: Thread
var projectile_thread: Thread
var damage_mutex: Mutex  # 공유 데이터 보호

func _simulation_tick() -> void:
	# 병렬 실행
	physics_thread.start(_update_physics_threaded)
	projectile_thread.start(_update_projectiles_threaded)
	
	# AI는 메인 스레드에서 (간단)
	_update_ai()
	
	# 완료 대기
	physics_thread.wait_to_finish()
	projectile_thread.wait_to_finish()
	
	# 피해 처리 (단일 스레드, 순서 보장)
	_process_damage_events()
```

**주의**:
- Mutex로 공유 데이터(ships_dict, damage_queue) 보호
- 결정론 유지 위해 스레드 실행 순서 고정
- 성능 측정 후 이득 확인 (오버헤드 > 병렬 이득 가능)

---

### 18.2 순환 참조 방지

**문제**: `RefCounted` 객체 간 순환 참조 → 메모리 누수

```gdscript
# ❌ 나쁜 예: 순환 참조
class ShipData:
	var fleet: FleetData  # 강한 참조

class FleetData:
	var ships: Array[ShipData]  # 강한 참조
	# → ShipData ↔ FleetData 순환
```

**해결: weakref 사용**:
```gdscript
# ✓ 좋은 예
class ShipData:
	var fleet_weakref: WeakRef  # 약한 참조
	
	func get_fleet() -> FleetData:
		return fleet_weakref.get_ref() as FleetData

class FleetData:
	var ships: Array[ShipData]  # 강한 참조 (소유)
```

**규칙**:
- 부모 → 자식: 강한 참조 (소유 관계)
- 자식 → 부모: 약한 참조 (역참조)
- 예: Fleet(부모) → Ships(자식), Ship → Fleet은 weakref

---

### 18.3 에러 처리 및 복구

**널 체크**:
```gdscript
func _apply_damage_to_ship(ship_id: int, damage: float) -> void:
	var ship = ships_dict.get(ship_id)
	if not ship:
		push_error("Ship %d not found" % ship_id)
		return
	
	if not ship.is_expanded:
		_expand_ship(ship)
	
	# ...
```

**경계 검사**:
```gdscript
func _get_cell(ship: ShipData, cell_idx: int) -> CellData:
	if cell_idx < 0 or cell_idx >= ship.cells_expanded.size():
		push_error("Cell index %d out of bounds" % cell_idx)
		return null
	return ship.cells_expanded[cell_idx]
```

**정합성 검증 (디버그 모드)**:
```gdscript
func _validate_ship_state(ship: ShipData) -> void:
	if OS.is_debug_build():
		# CRITICAL 셀 인덱스 유효성
		for idx in ship.critical_cells:
			assert(idx < ship.cells_expanded.size(), "Invalid critical cell index")
		
		# Dirty 셀 중복 검사
		var dirty_set = {}
		for idx in ship.dirty_cells:
			assert(not dirty_set.has(idx), "Duplicate dirty cell")
			dirty_set[idx] = true
```

**복구 전략**:
```gdscript
func _safe_simulation_tick() -> void:
	try:
		_simulation_tick()
	except:
		push_error("Simulation tick failed, attempting recovery")
		_recover_simulation_state()

func _recover_simulation_state() -> void:
	# 손상된 함선 제거
	for ship in ships:
		if not ship.is_valid():
			ships.erase(ship)
	
	# 큐 초기화
	damage_queue.clear()
	
	# Spatial Hash 재구축
	spatial_hash.rebuild()
```

---

## 19. Next Steps

1. **프로토타입 우선 순위**:
   - Spatial Hash (가장 중요)
   - 압축/언팩 전환
   - Damage Event Queue

2. **성능 측정**:
   - 100척 → 500척 → 1000척 → 2000척 단계별
   - 각 단계에서 33ms 틱 예산 준수 확인

3. **Compute Shader 검증**:
   - CPU 버전 먼저 완성
   - GPU 버전 프로토타입 후 실측 비교
   - 이득 없으면 보류

---

## 20. Final Review Checklist

### 20.1 GDD 연계성 확인

**핵심 시스템 반영**:
- [x] Blueprint 1픽셀 = 1셀 구조
- [x] 셀별 HP, 소재, 모듈 관리
- [x] 도탄/관통 로직 (입사각 계산)
- [x] CRITICAL 셀 시스템 (원자로, 탄약고, AI 코어)
- [x] 원자로 멜트다운 카운트다운
- [x] 유폭 연쇄
- [x] AI 위임 시스템 (처리 포인트 소모)
- [x] 전자전 ECM/ECCM (등급별 효율)
- [x] AI 네트워킹 (풀링 효율)
- [x] Floating Origin

**성능 최적화**:
- [x] Spatial Hash (O(n²) → O(n))
- [x] Event Queue 기반 Damage Pipeline
- [x] 압축/언팩 이중 구조
- [x] CRITICAL 셀 우선 검사
- [x] Object Pooling
- [x] LOD 시스템
- [x] Compute Shader 경로

**아키텍처 원칙**:
- [x] Data-Oriented Design
- [x] 결정론적 시뮬레이션 (30Hz 고정 틱)
- [x] Node Minimalism (RefCounted 기반)
- [x] 맵/전투 통합 (단일 연속 공간)

---

### 20.2 구현 우선순위 재확인

**Phase 1 (필수, 프로토타입)**:
1. SimulationManager 고정 틱 루프
2. ShipData 압축/언팩 구조
3. Spatial Hash 구현
4. Damage Event Queue
5. CRITICAL 셀 태깅

**Phase 2 (핵심 게임플레이)**:
1. 발사체 시스템
2. 도탄/관통 계산
3. 유폭/멜트다운 이벤트
4. AI 위임 스케줄러

**Phase 3 (스케일업)**:
1. Object Pooling
2. LOD 전환
3. Floating Origin
4. 1000 vs 1000 테스트

**Phase 4 (폴리싱)**:
1. Compute Shader 프로토타입
2. Streaming Manager
3. 렌더 보간
4. 최종 튜닝

---

### 20.3 위험 요소 최종 점검

**🔴 반드시 피해야 할 것**:

1. **함선당 Node2D 생성** ← 2000개 = 씬 트리 폭발
2. **Dictionary 순회** ← 순서 불확정 = 결정론 파괴
3. **매 프레임 전체 셀 순회 (Dirty Flag 없이)** ← 10M 셀 × 60 FPS = 불가능
4. **공간 분할 없는 충돌 검사** ← O(n²) = 4M 연산
5. **압축 없이 성능 문제 발생 시 조급한 최적화** ← 측정 먼저

**핵심**: 
- Dirty Flag 시스템 = 필수
- CRITICAL 셀 우선순위 = 필수
- 압축/언팩 = 선택 사항

**🟡 주의 필요**:

1. **Compute Shader 조기 도입** ← CPU 버전 먼저 완성 후 측정
2. **과도한 LOD 단계** ← 전환 경계 복잡도 증가
3. **Floating Origin 없이 개발** ← 후반 추가 시 전면 수정
4. **압축 시스템 먼저 구현** ← Phase 3 이후 성능 측정 후 결정

**💡 권장 개발 순서**:
```
1. 전부 언팩 상태로 프로토타입 완성 (메모리 2.5GB, 충분)
2. 성능 프로파일링
3. 병목 발견 시 압축 도입 고려
4. 실측 이득 확인 후 유지/제거 결정
```

---

### 20.4 성능 측정 계획

**단계별 목표**:
```
100척:   틱 예산 10ms 이하
500척:   틱 예산 20ms 이하
1000척:  틱 예산 30ms 이하
2000척:  틱 예산 33ms 목표 (30Hz 유지)
```

**병목 예상 지점**:
1. Spatial Hash 재구축 (매 틱)
2. Damage Event 일괄 처리
3. AI 위임 작업 스케줄링
4. 렌더 뷰 업데이트 (보간)

**프로파일링 포인트**:
- `_update_physics()`
- `_update_projectiles()`
- `_process_damage_events()`
- `_update_ai()`
- `spatial_hash.rebuild()`

---

### 20.5 문서 버전 관리

**현재 버전**: 1.0  
**작성일**: 2026-03-16  
**기반**: GDD v6 (Stellar Dominion)

**변경 이력**:
- v1.0 (2026-03-16): 초안 작성
  - 맵/전투 통합 구조
  - Ingame 씬 구조 추가
  - 16개 챕터, 40개 코드 예시
  - 1121 라인

**다음 업데이트 예정**:
- Compute Shader 벤치마크 결과 반영
- 프로토타입 단계별 실측 데이터
- 병목 지점 최적화 기법

---

**End of Document**

이 아키텍처는 GDD의 설계 철학을 유지하면서도 실제 구현 가능한 구조로 정리했습니다. 맵과 전투를 분리하지 않고 단일 연속 공간에서 LOD로 처리하는 방식입니다.
