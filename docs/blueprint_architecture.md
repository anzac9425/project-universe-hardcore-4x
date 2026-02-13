# Blueprint Core Architecture (Phase 1)

## 목표
- 함선/거점/정거장을 동일한 1픽셀 Blueprint 데이터 구조로 표현.
- 런타임에서는 Blueprint 원본을 읽기 전용으로 참조하고, 인스턴스 상태만 분리 저장.
- `PackedByteArray` + `Resource` 중심으로 메모리 사용량을 제한.

## 디렉터리 구조
- `skripts/resources/cell_defs.gd`
  - 셀 1개(4바이트) 레이아웃과 플래그 비트, 읽기/쓰기 헬퍼.
- `skripts/resources/material_data.gd`
  - 소재 Resource 정의 + 런타임 ID 레지스트리.
- `skripts/resources/blueprint.gd`
  - 설계 원본 Resource (`cell_data`, `module_map`, 직렬화/역직렬화).
- `skripts/resources/blueprint_stats.gd`
  - bake 시점 자동 산출 스탯 캐시.
- `skripts/systems/ship_instance.gd`
  - 런타임 경량 인스턴스(`RefCounted`)와 피격/물리 처리.
- `skripts/BlueprintEditor/blueprint_editor.gd`
  - 설계 데이터 조작 + 미리보기 텍스처 갱신.
- `skripts/shaders/cell_damage.glsl`
  - GPU 기반 셀 피해 계산용 Compute Shader 초안.

## 런타임 흐름
1. `MaterialData.register_defaults()`로 기본 소재 등록.
2. 에디터/툴에서 `Blueprint`를 작성.
3. `Blueprint.bake_stats()` 호출로 캐시 생성.
4. 전투 시작 시 `ShipInstance.create()`로 인스턴스화.
5. 피격은 `ShipInstance.apply_hit()` CPU fallback 사용 (추후 Compute Shader 전환).

## 다음 단계
- `skripts/BlueprintEditor/blueprint_editor.gd`에서 데이터 로직과 렌더링 로직 분리.
- `skripts/shaders/cell_damage.glsl`를 `ShipInstance.apply_hit()` 경로에 연결.
- `module_map`을 고정 타입 Resource 기반으로 교체(런타임 Dictionary 접근 최소화).
- 거리 기반 시뮬레이션 LOD(셀 단위/모듈 단위/선체 단위) 분리.
