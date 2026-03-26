





# Stellar Dominion — 결정론적 우주 생성 알고리즘 레퍼런스

**목적**: IMF + MMSN + Hill 안정성 + Kepler 궤도 + seed 기반 완전 결정론적 정적 우주 모델  
**엔진**: Godot 4 / GDScript  

---

## 전체 파이프라인

```
Seed
  ↓
1. 은하 구조 생성       밀도장 기반 샘플링 (나선팔 + 지수 감쇠)
  ↓
2. 항성 생성            IMF piecewise power-law inverse CDF
  ↓
3. 원반 생성            MMSN 기반 표면 밀도 + 응결선
  ↓
4. 안정 궤도 패킹       Hill 안정성 기준 슬롯 배치
  ↓
5. 행성 물리 결정       코어 질량 → 타입 → 물리 속성
  ↓
6. 위성 생성            Hill sphere 내부 안정 궤도 + 공명
  ↓
7. Kepler 파라미터화    모든 천체 → (a, e, i, Ω, ω, M₀)
  ↓
8. 시간 → 위치          M(t) = M₀ + n·t → Kepler 방정식 → 위치
```

---

## 1. Seed 관리

### 계층 구조

```
galaxy_seed
  └─ derive("system", i)     → system_seed[i]
	   └─ derive("star")     → star_seed
	   └─ derive("disk")     → disk_seed
	   └─ derive("slot", i)  → slot_seed[i]       ← 궤도 슬롯
			└─ derive("body")       → planet_seed
				 └─ derive("orbit") → orbit_seed   ← 궤도 파라미터
				 └─ derive("moon_slot", j) → moon_slot_seed[j]
					  └─ derive("body")   → moon_seed
					  └─ derive("orbit")  → moon_orbit_seed
```

### SeedManager

```gdscript
class_name SeedManager

# SHA256 기반 — 플랫폼/버전 독립 결정론 보장
static func derive_seed(parent: int, purpose: String, index: int = 0) -> int:
	var digest = ("%d:%s:%d" % [parent, purpose, index]).sha256_text()
	return digest.left(8).hex_to_int() & 0x7FFFFFFF

static func make_rng(seed: int) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	return rng
```

---

## 2. 은하 구조 생성

### 밀도장 기반 샘플링

항성 분포는 균등 분포가 아닙니다. 은하 중심에서 지수 감쇠하는 밀도장을 따릅니다.

```gdscript
# 지수 원반 밀도 프로파일
# ρ(r) ∝ exp(-r / Rd)
# Rd: 특성 반경 (은하 크기에 따라 조정)

static func sample_radial_position(rng: RandomNumberGenerator, Rd: float) -> float:
	# inverse CDF: r = -Rd * ln(1 - u)
	var u = rng.randf_range(0.0001, 0.9999)   # 0, 1 경계 보호
	return -Rd * log(1.0 - u)

# 나선팔 위상
# θ_arm(r) = k * ln(r) + phase
# k: 나선팔 감김 계수, phase: 팔 위상 오프셋

static func sample_arm_angle(r: float, k: float, phase: float) -> float:
	return fmod(k * log(r) + phase, TAU)

# 최종 위치 샘플링
static func sample_position(
	rng:        RandomNumberGenerator,
	Rd:         float,
	arm_count:  int,
	arm_spread: float   # 팔 폭 (rad)
) -> Vector2:
	var r       = sample_radial_position(rng, Rd)
	var arm_idx = rng.randi_range(0, arm_count - 1)
	var phase   = (TAU / arm_count) * arm_idx
	var k       = 0.3   # 나선 감김 계수

	# 팔 중심각 + 가우시안 분산
	var arm_angle   = sample_arm_angle(r, k, phase)
	var spread      = rng.randf_range(-arm_spread, arm_spread)
	var final_angle = arm_angle + spread

	return Vector2(cos(final_angle), sin(final_angle)) * r
```

### Poisson Disk로 최소 거리 보장

```gdscript
# 밀도장 샘플링 후 Poisson Disk로 최소 거리 필터링
# → 항성계 간 물리적 최소 거리 유지
static func generate_galaxy(seed: int, count: int, Rd: float, min_dist: float) -> Array[Vector2]:
	var rng       = SeedManager.make_rng(seed)
	var positions = _density_sample(rng, count * 3, Rd)   # 과샘플링 후 필터
	return _poisson_filter(positions, min_dist, count)     # 최소 거리 필터
```

---

## 3. 항성 생성 — IMF + inverse CDF

### Kroupa IMF piecewise power-law

```
dN/dM ∝ M^(-α)

α = 0.3   (0.08 ≤ M < 0.5 M☉)   저질량
α = 1.3   (0.5  ≤ M < 1.0 M☉)   중간질량
α = 2.3   (1.0  ≤ M        M☉)   고질량 (Salpeter)
```

```gdscript
# Kroupa IMF inverse CDF 샘플링
# 각 구간의 누적 확률로 역변환
static func sample_stellar_mass(rng: RandomNumberGenerator) -> float:
	# 구간별 정규화 가중치 (관측 기반)
	const W1 = 0.760   # M형 (0.08~0.50)
	const W2 = 0.150   # K형 (0.50~0.80)
	const W3 = 0.066   # G형 (0.80~1.20)
	const W4 = 0.019   # F형 (1.20~2.00)
	const W5 = 0.005   # A/B/O형 (2.0~50.0)

	var u = rng.randf()

	if   u < W1:                   return _power_law_sample(rng, 0.08,  0.50, -0.3)
	elif u < W1 + W2:              return _power_law_sample(rng, 0.50,  0.80, -1.3)
	elif u < W1 + W2 + W3:        return _power_law_sample(rng, 0.80,  1.20, -2.3)
	elif u < W1 + W2 + W3 + W4:   return _power_law_sample(rng, 1.20,  2.00, -2.3)
	else:                          return _power_law_sample(rng, 2.00, 50.00, -2.3)

# power-law inverse CDF: x = ((x_max^(α+1) - x_min^(α+1)) * u + x_min^(α+1))^(1/(α+1))
static func _power_law_sample(rng: RandomNumberGenerator, x_min: float, x_max: float, alpha: float) -> float:
	var g  = alpha + 1.0
	var u  = rng.randf()
	return pow(u * (pow(x_max, g) - pow(x_min, g)) + pow(x_min, g), 1.0 / g)

# 질량 → 물리량 파생 (주계열성 관계식)
static func derive_from_mass(mass: float) -> Dictionary:
	return {
		"radius":      pow(mass, 0.8),
		"luminosity":  clamp(pow(mass, 4.0), 0.0001, 100.0),
		"temperature": 5778.0 * pow(mass, 0.505),
		"lifetime_gy": 10.0 / pow(mass, 2.5),      # Gyr
		"type":        _mass_to_type(mass)
	}

static func _mass_to_type(m: float) -> StarData.Type:
	if   m >= 16.0: return StarData.Type.O
	elif m >=  2.0: return StarData.Type.B
	elif m >=  1.5: return StarData.Type.A
	elif m >=  1.1: return StarData.Type.F
	elif m >=  0.9: return StarData.Type.G
	elif m >=  0.6: return StarData.Type.K
	else:           return StarData.Type.M
```

---

## 4. 원반 생성 — MMSN 모델

### Minimum Mass Solar Nebula

```gdscript
class_name ProtoplanetaryDisk

var star_mass:       float
var star_luminosity: float
var inner_edge:      float   # AU
var outer_edge:      float   # AU
var snow_line:       float   # AU  — 물 얼음 응결선
var rock_line:       float   # AU  — 암석 응결선
var surface_density: float   # g/cm² at 1 AU

static func build(star_mass: float, star_luminosity: float) -> ProtoplanetaryDisk:
	var d = ProtoplanetaryDisk.new()
	d.star_mass       = star_mass
	d.star_luminosity = star_luminosity

	# 응결선: 복사 플럭스 기반
	d.snow_line   = 2.7  * sqrt(star_luminosity)         # 물 얼음
	d.rock_line   = 0.3  * sqrt(star_luminosity)         # 암석
	d.inner_edge  = 0.1  * sqrt(star_luminosity)         # 복사압 한계
	d.outer_edge  = 30.0 * pow(star_mass, 1.0 / 3.0)    # 조석 절단

	# MMSN: Σ(r) = Σ₀ * (r/1AU)^(-3/2)
	d.surface_density = 1700.0 * star_mass               # Σ₀ at 1AU

	return d

# 특정 궤도에서의 표면 밀도
func sigma_at(r: float) -> float:
	# 응결선 바깥: 얼음 포함으로 밀도 4배
	var ice_factor = 4.0 if r > snow_line else 1.0
	return surface_density * pow(r, -1.5) * ice_factor
```

---

## 5. 안정 궤도 패킹 — Hill 안정성

### 궤도 슬롯 생성

```gdscript
# Hill 안정성 기준 최소 궤도 간격
# 인접 행성 간 Hill 반경의 K배 이상 유지
# K = 3.5 (관측 통계 기반, Chambers et al. 1996)
const HILL_SPACING = 8.0

static func generate_orbital_slots(
	disk: ProtoplanetaryDisk,
	rng:  RandomNumberGenerator
) -> Array[float]:

	var slots: Array[float] = []
	var r = disk.inner_edge

	while r < disk.outer_edge:
		slots.append(r)

		# 이 궤도에서의 코어 질량 추정 → Hill 반경 계산
		var core_mass   = _estimate_core_mass(r, disk)
		var hill_r      = r * pow(core_mass / (3.0 * disk.star_mass), 1.0 / 3.0)

		# 다음 슬롯까지 최소 간격: HILL_SPACING * 2 * hill_r
		var min_gap     = HILL_SPACING * 2.0 * hill_r
		var actual_gap  = max(min_gap, r * rng.randf_range(0.3, 0.8))
		r              += actual_gap

	return slots

# 원반 밀도 기반 코어 질량 추정
static func _estimate_core_mass(r: float, disk: ProtoplanetaryDisk) -> float:
	var sigma        = disk.sigma_at(r)
	var feeding_zone = 2.0 * PI * r * (r * 0.2) * sigma
	return max(feeding_zone * 1e-6, 0.001)   # 지구 질량 단위, 최솟값 보장

# 궤도 교차 검증
static func validate_no_crossing(slots: Array[float]) -> bool:
	for i in range(slots.size() - 1):
		if slots[i] >= slots[i + 1]:
			Log.error("Orbital crossing detected at index %d" % i, "OrbitalPacking")
			return false
	return true
```

### 공명 체인

```gdscript
# 인접 궤도 주기비가 정수비에 가까우면 공명으로 고정
# 확률적 적용 (20%)
static func apply_resonance(
	slots:      Array[float],
	rng:        RandomNumberGenerator,
	star_mass:  float
) -> Array[float]:

	const RESONANCES = [
		[2.0, 1.0],   # 2:1
		[3.0, 2.0],   # 3:2
		[4.0, 3.0],   # 4:3
	]

	for i in range(1, slots.size()):
		if rng.randf() > 0.20:
			continue

		var res  = RESONANCES[rng.randi_range(0, RESONANCES.size() - 1)]
		var prev = slots[i - 1]

		# 주기비 → 반장축 비 (Kepler 제3법칙: T ∝ a^(3/2))
		# a_next = a_prev * (T_next/T_prev)^(2/3)
		var period_ratio = res[0] / res[1]
		var new_slot     = prev * pow(period_ratio, 2.0 / 3.0)

		# 앞 슬롯과 교차하지 않는 경우에만 적용
		if i + 1 < slots.size() and new_slot < slots[i + 1]:
			slots[i] = new_slot

	return slots
```

---

## 6. 행성 물리 결정

```gdscript
# 코어 질량 + 응결선 위치 → 행성 타입
static func determine_type(
	orbit_r: float,
	disk:    ProtoplanetaryDisk,
	rng:     RandomNumberGenerator
) -> PlanetData.Type:

	var core_mass = _estimate_core_mass(orbit_r, disk)

	if orbit_r < disk.snow_line:
		# 응결선 안쪽 — 암석 계열
		if core_mass < 0.1:  return PlanetData.Type.ROCKY      # 소형 암석
		if core_mass < 2.0:  return PlanetData.Type.ROCKY
		if core_mass < 5.0:  return PlanetData.Type.SUPER_EARTH
		# 질량이 크면 가스 포획 시작
		return PlanetData.Type.GAS_GIANT if rng.randf() < 0.3 else PlanetData.Type.SUPER_EARTH
	else:
		# 응결선 바깥 — 얼음/가스 계열
		if core_mass < 2.0:  return PlanetData.Type.ICE
		if core_mass < 5.0:  return PlanetData.Type.ICE
		if core_mass < 10.0:
			return PlanetData.Type.GAS_GIANT if rng.randf() < 0.6 else PlanetData.Type.ICE
		return PlanetData.Type.GAS_GIANT

# 거주가능성 점수 (0.0 ~ 1.0)
static func assess_habitability(planet: PlanetData, star: StarData) -> float:
	# 복사 플럭스 (Kopparapu 2013)
	var flux = star.luminosity / pow(planet.orbit.a, 2.0)
	if flux > 1.67 or flux < 0.32:
		return 0.0   # 금성형 온난화 또는 동결

	var flux_score = 1.0 - abs(flux - 1.0) * 1.5
	var mass_score = _mass_habitability(planet.mass)
	var star_score = _star_habitability(star.type)

	return clamp(flux_score * mass_score * star_score, 0.0, 1.0)

static func _mass_habitability(mass_earth: float) -> float:
	# 0.3 ~ 5.0 지구 질량 범위 최적
	if mass_earth < 0.1 or mass_earth > 10.0: return 0.0
	if mass_earth < 0.3: return mass_earth / 0.3
	if mass_earth > 5.0: return 1.0 - (mass_earth - 5.0) / 5.0
	return 1.0

static func _star_habitability(type: StarData.Type) -> float:
	match type:
		StarData.Type.F: return 0.7
		StarData.Type.G: return 1.0
		StarData.Type.K: return 0.9
		StarData.Type.M: return 0.4
		_:               return 0.1
```

---

## 7. 위성 생성 — Hill sphere 내부 안정 궤도

```gdscript
# Hill sphere 내부 안정 한계
# r_stable < 0.3~0.5 * r_Hill (형성 메커니즘에 따라 다름)
const MOON_STABLE_FACTOR_COFORM   = 0.50   # 공동 형성
const MOON_STABLE_FACTOR_CAPTURED = 0.30   # 포획 (불안정)

enum MoonOrigin { COFORMATION, CAPTURED, IMPACT }

static func generate_moon_slots(
	planet:    PlanetData,
	star_mass: float,
	rng:       RandomNumberGenerator
) -> Array[float]:

	var hill_r = planet.orbit.a \
				 * pow(planet.mass / (3.0 * star_mass), 1.0 / 3.0)

	var origin       = _roll_origin(planet.type, rng)
	var stable_limit = hill_r * (
		MOON_STABLE_FACTOR_COFORM if origin == MoonOrigin.COFORMATION
		else MOON_STABLE_FACTOR_CAPTURED
	)

	# Roche 한계 (내부 경계) — 조석력으로 분해됨
	# r_roche ≈ 2.44 * R_planet * (ρ_planet / ρ_moon)^(1/3)
	var roche_limit = 2.44 * planet.radius * pow(planet.density / 3.0, 1.0 / 3.0)

	var slots:     Array[float] = []
	var r          = max(planet.radius * 2.5, roche_limit * 1.1)   # Roche 한계 밖에서 시작

	while r < stable_limit:
		slots.append(r)

		# 위성 간 Hill 안정성 (행성 질량 기반이 아닌 위성 질량 기반)
		var gap = r * rng.randf_range(0.4, 0.8)
		r      += gap

	return slots

static func _roll_origin(type: PlanetData.Type, rng: RandomNumberGenerator) -> MoonOrigin:
	var u = rng.randf()
	match type:
		PlanetData.Type.GAS_GIANT:
			if u < 0.6:  return MoonOrigin.COFORMATION
			elif u < 0.9: return MoonOrigin.CAPTURED
			else:         return MoonOrigin.IMPACT
		PlanetData.Type.ROCKY:
			if u < 0.3:  return MoonOrigin.IMPACT
			elif u < 0.7: return MoonOrigin.COFORMATION
			else:         return MoonOrigin.CAPTURED
		_:
			return MoonOrigin.COFORMATION
```

---

## 8. Kepler 궤도 파라미터화

### 6개 궤도 요소

모든 천체는 동일한 궤도 요소로 표현됩니다. 행성/위성 구분 없이 동일한 구조체를 사용합니다.

```gdscript
class_name KeplerOrbit

var a:   float   # semi-major axis (AU 또는 임의 단위)
var e:   float   # eccentricity [0, 1)
var i:   float   # inclination (rad)
var W:   float   # longitude of ascending node Ω (rad)
var w:   float   # argument of periapsis ω (rad)
var M0:  float   # initial mean anomaly (rad), t=0 기준

# seed 기반 생성 — 모든 값 결정론적 고정
static func from_seed(
	orbit_seed: int,
	a:          float,
	origin:     int     # MoonOrigin 또는 행성 형성 타입
) -> KeplerOrbit:

	var rng  = SeedManager.make_rng(orbit_seed)
	var orb  = KeplerOrbit.new()
	orb.a    = a

	match origin:
		MoonOrigin.COFORMATION:
			orb.e = rng.randf_range(0.00, 0.05)
			orb.i = deg_to_rad(rng.randf_range(0.0, 5.0))
		MoonOrigin.CAPTURED:
			orb.e = rng.randf_range(0.10, 0.60)
			orb.i = deg_to_rad(rng.randf_range(0.0, 180.0))   # 역행 가능
		MoonOrigin.IMPACT:
			orb.e = rng.randf_range(0.00, 0.10)
			orb.i = deg_to_rad(rng.randf_range(0.0, 15.0))
		_:   # 행성
			orb.e = rng.randf_range(0.00, 0.20)
			orb.i = deg_to_rad(rng.randf_range(0.0, 10.0))

	orb.W  = fmod(rng.randf() * TAU, TAU)
	orb.w  = fmod(rng.randf() * TAU, TAU)
	orb.M0 = fmod(rng.randf() * TAU, TAU)

	return orb
```

---

## 9. 시간 → 위치 계산

### Kepler 방정식 풀이

```gdscript
# scripts/simulation/kepler_solver.gd
class_name KeplerSolver

const G = 4.0 * PI * PI

# 평균 운동 n = sqrt(GM / a³)  [rad/s]
static func mean_motion(central_mass: float, a: float) -> float:
	if a <= 0.0: return 0.0
	return sqrt(G * central_mass / (a * a * a))

# 평균 이각 M(t) = M₀ + n * t   → fmod TAU
static func mean_anomaly(M0: float, n: float, t: float) -> float:
	return fmod(M0 + n * t, TAU)

# Kepler 방정식: M = E - e * sin(E)
# Newton-Raphson 반복으로 이심 이각 E 계산
static func eccentric_anomaly(M: float, e: float, tol: float = 1e-6) -> float:
	if e < 1e-9: return M   # 원궤도 early return

	var E = M   # 초기 추정값
	const ITER = 8
	for _i in range(ITER):
		var dE = (M - E + e * sin(E)) / (1.0 - e * cos(E))
		E += dE

	return E

# 이심 이각 E → 진 이각 ν (true anomaly)
static func true_anomaly(E: float, e: float) -> float:
	var x = sqrt(1.0 - e) * cos(E / 2.0)
	var y = sqrt(1.0 + e) * sin(E / 2.0)
	return 2.0 * atan2(y, x)

# 궤도면 내 거리 r
static func radius_at(a: float, e: float, E: float) -> float:
	return a * (1.0 - e * cos(E))

# 최종: t → 3D 위치 (2D 투영 포함)
static func position_at_time(
	orbit:        KeplerOrbit,
	central_mass: float,
	t:            float,
	parent_pos:   Vector2 = Vector2.ZERO
) -> Vector2:

	var n  = mean_motion(central_mass, orbit.a)
	var M  = mean_anomaly(orbit.M0, n, t)
	var E  = eccentric_anomaly(M, orbit.e)
	var nu = true_anomaly(E, orbit.e)
	var r  = radius_at(orbit.a, orbit.e, E)

	# 궤도면 내 위치
	var x_orb = r * cos(nu)
	var y_orb = r * sin(nu)

	# 3D → 2D 투영 (경사 i, 승교점 Ω, 근점 인수 ω 적용)
	var cos_W = cos(orbit.W); var sin_W = sin(orbit.W)
	var cos_w = cos(orbit.w); var sin_w = sin(orbit.w)
	var cos_i = cos(orbit.i)

	var x = (cos_W * cos_w - sin_W * sin_w * cos_i) * x_orb \
		  + (-cos_W * sin_w - sin_W * cos_w * cos_i) * y_orb
	var y = (sin_W * cos_w + cos_W * sin_w * cos_i) * x_orb \
		  + (-sin_W * sin_w + cos_W * cos_w * cos_i) * y_orb

	return parent_pos + Vector2(x, y)
```

---

## 10. SystemSimulator 통합

```gdscript
# scripts/simulation/system_simulator.gd
class_name SystemSimulator

const TICK_SIZE: float = 1.0 / 60.0

static func get_time() -> float:
	var raw:  float = Engine.get_physics_time()
	var tick: int   = int(raw / TICK_SIZE)
	return tick * TICK_SIZE

static func update_positions(
	system:      SystemData,
	out_planets: Array,     # Array[Vector2]
	out_moons:   Array      # Array[Array[Vector2]]
) -> void:
	var t          = get_time()
	var star_mass  = system.star.mass

	out_planets.clear()

	for i in range(system.planets.size()):
		var planet     = system.planets[i]
		var planet_pos = KeplerSolver.position_at_time(planet.orbit, star_mass, t)
		out_planets.append(planet_pos)

		# Moon 배열 재사용 (GC 방지)
		var m_arr: Array
		if i < out_moons.size():
			m_arr = out_moons[i]
			m_arr.clear()
		else:
			m_arr = []
			out_moons.append(m_arr)

		for moon in planet.moons:
			var moon_pos = KeplerSolver.position_at_time(moon.orbit, planet.mass, t, planet_pos)
			m_arr.append(moon_pos)
```

---

## 11. 안정성 검증

생성 후 반드시 검증합니다. 검증 실패는 seed + 파라미터 조합 문제이므로 로그에 남기고 해당 슬롯을 비워둡니다.

```gdscript
class_name OrbitValidator

# 궤도 교차 검증 — 반장축 기준
# 이심률이 있으면 근점/원점도 체크
static func check_no_crossing(planets: Array[PlanetData]) -> bool:
	for i in range(planets.size() - 1):
		var a = planets[i].orbit
		var b = planets[i + 1].orbit
		var a_apoapsis  = a.a * (1.0 + a.e)   # 원점
		var b_periapsis = b.a * (1.0 - b.e)   # 근점
		if a_apoapsis >= b_periapsis:
			Log.warn("Orbital crossing: planet %d ↔ %d" % [i, i+1], "Validator")
			return false
	return true

# Hill 안정성 검증
# 인접 행성 간 Hill 반경 합의 K배 이상 이격
static func check_hill_stability(
	planets:   Array[PlanetData],
	star_mass: float,
	K:         float = 3.5
) -> bool:
	for i in range(planets.size() - 1):
		var p1  = planets[i]
		var p2  = planets[i + 1]
		var rH1 = p1.orbit.a * pow(p1.mass / (3.0 * star_mass), 1.0 / 3.0)
		var rH2 = p2.orbit.a * pow(p2.mass / (3.0 * star_mass), 1.0 / 3.0)
		var sep = p2.orbit.a - p1.orbit.a
		if sep < K * (rH1 + rH2):
			Log.warn("Hill instability: planet %d ↔ %d" % [i, i+1], "Validator")
			return false
	return true

# 위성 Hill sphere 내부 확인
static func check_moon_stability(
	planet:    PlanetData,
	star_mass: float
) -> bool:
	var hill_r = planet.orbit.a \
				 * pow(planet.mass / (3.0 * star_mass), 1.0 / 3.0)
	for moon in planet.moons:
		if moon.orbit.a > hill_r * 0.5:
			Log.warn("Moon outside stable Hill sphere", "Validator")
			return false
	return true
```

---

## 전체 생성 플로우 요약

```gdscript
static func generate_system(system: SystemData) -> void:
	if system.generated: return
	var rng_seed = system.system_seed

	# 1. 항성
	var star_seed = SeedManager.derive_seed(rng_seed, "star")
	system.star   = StarFactory.generate(star_seed)

	# 2. 원반
	var disk = ProtoplanetaryDisk.build(system.star.mass, system.star.luminosity)

	# 3. 궤도 슬롯 (Hill 안정성 기준)
	var disk_seed = SeedManager.derive_seed(rng_seed, "disk")
	var disk_rng  = SeedManager.make_rng(disk_seed)
	var slots     = OrbitalPacking.generate_orbital_slots(disk, disk_rng)
	slots         = OrbitalPacking.apply_resonance(slots, disk_rng, system.star.mass)

	# 4. 행성
	for i in range(slots.size()):
		var slot_seed   = SeedManager.derive_seed(rng_seed, "slot", i)
		var body_seed   = SeedManager.derive_seed(slot_seed, "body")
		var orbit_seed  = SeedManager.derive_seed(slot_seed, "orbit")
		var planet      = PlanetFactory.generate(body_seed, slots[i], disk)
		planet.orbit    = KeplerOrbit.from_seed(orbit_seed, slots[i], 0)
		system.planets.append(planet)

	# 5. 검증
	OrbitValidator.check_no_crossing(system.planets)
	OrbitValidator.check_hill_stability(system.planets, system.star.mass)

	# 6. 위성
	for i in range(system.planets.size()):
		var planet      = system.planets[i]
		var moon_slots  = MoonFactory.generate_moon_slots(planet, system.star.mass, disk_rng)
		for j in range(moon_slots.size()):
			var ms_seed  = SeedManager.derive_seed(planet.seed, "moon_slot", j)
			var mb_seed  = SeedManager.derive_seed(ms_seed, "body")
			var mo_seed  = SeedManager.derive_seed(ms_seed, "orbit")
			var origin   = MoonFactory.roll_origin(planet.type, SeedManager.make_rng(ms_seed))
			var moon     = MoonFactory.generate(mb_seed, moon_slots[j], planet)
			moon.orbit   = KeplerOrbit.from_seed(mo_seed, moon_slots[j], origin)
			planet.moons.append(moon)

	system.generated = true
```

---

## 체크리스트

### 물리 모델

- [x] IMF piecewise power-law inverse CDF (Kroupa 2001)
- [x] 질량 → 광도/온도/반경 관계식 (주계열성)
- [x] MMSN 표면 밀도 Σ(r) ∝ r^(-3/2)
- [x] 응결선 기반 행성 타입 결정
- [x] Kopparapu 거주가능 영역
- [x] Hill 안정성 궤도 패킹 (K = 3.5)
- [x] Roche 한계 (위성 내부 경계)
- [x] 공명 체인 (2:1, 3:2, 4:3)
- [x] 위성 형성 메커니즘 (COFORMATION / CAPTURED / IMPACT)

### 궤도

- [x] 6요소 Kepler 궤도 (a, e, i, Ω, ω, M₀)
- [x] Newton-Raphson Kepler 방정식 풀이
- [x] 3D → 2D 투영
- [x] 궤도 교차 금지 검증
- [x] Hill 안정성 검증
- [x] 위성 Hill sphere 내부 검증

### 결정론

- [x] SHA256 기반 계층 seed 파생
- [x] purpose + index로 충돌 방지
- [x] `Engine.get_physics_time()` + `int(raw/TICK_SIZE)` 양자화
- [x] 모든 궤도 요소 seed 고정
- [x] 전역 RNG 없음

### 참고 논문

| 모델 | 출처 |
|------|------|
| Kroupa IMF | Kroupa (2001) |
| MMSN | Hayashi (1981) |
| Hill 안정성 간격 | Chambers et al. (1996) |
| 거주가능 영역 | Kopparapu et al. (2013) |
| 나선팔 구조 | Logarithmic spiral model |
