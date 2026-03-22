
# Stellar Dominion - Celestial Body Visualization Reference (Revised)

**Version**: 2.0  
**Engine**: Godot 4.6  
**Target**: 코드 기반 천체 시각화 (에셋 없이)

This document updates the original reference by **modifying implementation details only**.  
The **overall architecture remains identical**, but several changes improve performance and scalability.

Key improvements:
- CPU 노이즈 텍스처 생성 제거
- 셰이더 기반 GPU 노이즈
- 궤도 시뮬레이션 중앙화
- Node 수 감소 (MultiMesh 사용)
- Material 캐싱
- CanvasLayer 제거
- LOD 시스템 확장

---

# 1. 개요

## 1.1 목적

MapGenerator가 생성한 천체 데이터를 **코드만으로 시각화**합니다.

- 에셋 불필요 (텍스처, 모델 없음)
- 셰이더 + 프로시저럴 생성
- 시드 기반 결정론적 외형

## 1.2 렌더링 계층 (Revised)

CanvasLayer 대신 일반 Node2D 계층을 사용합니다.

```
SystemView (Node2D)
├── Stars (Node2D)
│   └── StarVisual nodes
├── PlanetRenderer (MultiMeshInstance2D)
└── MoonRenderer (MultiMeshInstance2D)
```

이 구조는 다음을 제공합니다:

- draw call 감소
- GPU instancing
- 카메라와 자연스러운 통합

---

# 2. 별(Star) 시각화

## 2.1 별 스프라이트

별은 여전히 `Sprite2D` 기반입니다.  
하지만 **CPU 텍스처 생성 대신 GPU 노이즈**를 사용합니다.

```gdscript
# scripts/visuals/star_visual.gd
extends Sprite2D
class_name StarVisual

var star_data: StarData

func initialize(data: StarData) -> void:
	star_data = data
	
	scale = Vector2.ONE * star_data.radius * 0.1
	material = _create_star_material()

func _create_star_material() -> ShaderMaterial:
	
	var shader_code = '''
shader_type canvas_item;

uniform vec3 star_color : source_color;
uniform float seed;
uniform float activity;

float hash(vec2 p){
    return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}

float noise(vec2 p){
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i + vec2(1,0));
    float c = hash(i + vec2(0,1));
    float d = hash(i + vec2(1,1));

    vec2 u = f*f*(3.0-2.0*f);

    return mix(a,b,u.x) +
           (c-a)*u.y*(1.0-u.x) +
           (d-b)*u.x*u.y;
}

void fragment(){

    vec2 uv = UV - 0.5;
    float dist = length(uv);

    float circle = smoothstep(0.5,0.48,dist);

    float surface = noise(uv * 6.0 + seed);

    float corona = exp(-dist*6.0) * 0.3;

    vec3 color = star_color + surface * activity;

    COLOR = vec4(color * (circle + corona), circle);
}
'''
	
	var shader = Shader.new()
	shader.code = shader_code

	var mat = ShaderMaterial.new()
	mat.shader = shader

	mat.set_shader_parameter("seed", star_data.seed)
	mat.set_shader_parameter("activity", star_data.temperature / 10000.0)

	return mat
```

---

# 3. 행성(Planet) 시각화

행성은 개별 Sprite 대신 **MultiMeshInstance2D**로 렌더링됩니다.

이 방식은 수십 개 행성/위성에서도 **draw call 1회**로 렌더링할 수 있습니다.

## 3.1 Planet Renderer

```gdscript
# scripts/renderers/planet_renderer.gd
extends MultiMeshInstance2D
class_name PlanetRenderer

func build(planets):

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.instance_count = planets.size()

	for i in planets.size():

		var p = planets[i]

		var transform = Transform2D()
		transform.origin = Vector2(
			p.orbit_radius * cos(p.orbit_angle),
			p.orbit_radius * sin(p.orbit_angle)
		)

		mm.set_instance_transform_2d(i, transform)

	multimesh = mm
```

---

# 4. 위성(Moon) 렌더링

위성도 동일하게 **MultiMeshInstance2D** 사용.

```
MoonRenderer (MultiMeshInstance2D)
```

장점

- 수십 개 위성도 단일 draw call
- node 수 최소화

---

# 5. 궤도 시뮬레이션 중앙화

기존 구현에서는

```
StarVisual._process()
PlanetVisual._process()
MoonVisual._process()
```

각 노드에서 궤도 업데이트를 수행했습니다.

이는 Node 수가 많아질수록 비효율적입니다.

## Revised 구조

```
SystemSimulator
	↓
SystemData
	↓
Renderer
```

### SystemSimulator

```gdscript
# scripts/simulation/system_simulator.gd

func update_system(system, delta):

	for star in system.stars:
		star.orbit_angle += delta * star.orbital_speed

	for planet in system.planets:
		planet.orbit_angle += delta * planet.orbital_speed

		for moon in planet.moons:
			moon.orbit_angle += delta * moon.orbital_speed
```

Renderer는 단순히 **위치만 읽어 표시**합니다.

장점

- 단일 업데이트 루프
- 결정론 유지
- 멀티스레드 확장 가능

---

# 6. Material 캐싱

행성마다 새로운 ShaderMaterial을 생성하면 GPU state change가 증가합니다.

따라서 **Material Cache**를 사용합니다.

```gdscript
class_name PlanetMaterialManager

static var cache = {}

static func get_material(type, lod):

	var key = str(type) + "_" + str(lod)

	if cache.has(key):
		return cache[key]

	var mat = ShaderMaterial.new()

	cache[key] = mat

	return mat
```

---

# 7. LOD 시스템 확장

기존 3단계 LOD를 **5단계로 확장**합니다.

```
LOD0 : full shader
LOD1 : simplified shader
LOD2 : flat shading
LOD3 : color dot
LOD4 : hidden
```

예시 규칙

```gdscript
if zoom > 2.0:
	lod = 0
elif zoom > 1.0:
	lod = 1
elif zoom > 0.5:
	lod = 2
elif zoom > 0.2:
	lod = 3
else:
	lod = 4
```

---

# 8. 삼중성계 물리 구조 수정

기존

```
120° spacing
```

이는 장기적으로 불안정합니다.

Revised 구조

```
Inner Binary
Outer Star
```

```
Star A
Star B   → Binary orbit

Star C   → outer orbit
```

보다 현실적인 성계 구조를 제공합니다.

---

# 9. 최종 렌더 파이프라인

```
GameSession
	↓
MapGenerator
	↓
SystemData
	↓
SystemSimulator
	↓
SystemView
	↓
StarVisual / PlanetRenderer / MoonRenderer
```

Simulation은 데이터만 업데이트하고  
Renderer는 **순수 렌더링만 수행**합니다.

---

# 10. 최종 체크리스트

- [x] GPU procedural noise
- [x] CPU texture generation 제거
- [x] orbit simulation 중앙화
- [x] MultiMesh planet rendering
- [x] MultiMesh moon rendering
- [x] material caching
- [x] improved LOD
- [x] realistic triple star structure

---

**End of Revised Reference**
