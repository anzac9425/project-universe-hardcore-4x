// cell_damage.glsl
// 셀 단위 피해 계산 Compute Shader
// 수천 척이 동시 교전할 때 CPU 대신 GPU에서 처리

#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// ── 피격 이벤트 구조체 ────────────────────────────────────
struct HitEvent {
    uint  instance_id;   // 피격 인스턴스 ID
    uint  cell_offset;   // hp_data 내 셀 오프셋
    int   damage;        // 피해량
    int   penetration;   // 관통 셀 수
    float angle_deg;     // 입사각
    uint  direction;     // 관통 방향 인코딩 (dx + 2, dy + 2 각 4비트)
    uint  _pad0;
    uint  _pad1;
};

// ── 바인딩 ────────────────────────────────────────────────
// 피격 이벤트 배열 (CPU → GPU)
layout(set = 0, binding = 0, std430) restrict readonly buffer HitEventBuffer {
    uint       event_count;
    HitEvent   events[];
} hit_events;

// 인스턴스별 hp_data 플랫 배열
// 각 인스턴스의 오프셋은 instance_hp_offsets로 조회
layout(set = 0, binding = 1, std430) restrict buffer HpDataBuffer {
    uint8_t data[];
} hp_data;

// 인스턴스 HP 오프셋 테이블 (instance_id → hp_data 시작 오프셋)
layout(set = 0, binding = 2, std430) restrict readonly buffer HpOffsetBuffer {
    uint offsets[];
} hp_offsets;

// Blueprint 셀 데이터 (소재/플래그 참조용, Read-Only)
layout(set = 0, binding = 3, std430) restrict readonly buffer BlueprintBuffer {
    uint8_t data[];
} bp_data;

// Blueprint 오프셋 테이블
layout(set = 0, binding = 4, std430) restrict readonly buffer BpOffsetBuffer {
    uint offsets[];
} bp_offsets;

// 결과 출력: 파괴된 셀 이벤트 (GPU → CPU)
layout(set = 0, binding = 5, std430) restrict buffer DestroyedBuffer {
    uint  count;
    uvec2 cells[]; // (instance_id, cell_offset)
} destroyed;

// ── 소재 저항값 ──────────────────────────────────────────
int material_resistance(uint mat_id) {
    switch (mat_id) {
        case 1u: return 10;  // STEEL
        case 2u: return 18;  // TITANIUM
        case 3u: return 25;  // COMPOSITE
        case 4u: return 40;  // NANOMESH
        case 5u: return 60;  // ANTIMATTER
        default: return 5;
    }
}

// ── 메인 ─────────────────────────────────────────────────
void main() {
    uint gid = gl_GlobalInvocationID.x;
    if (gid >= hit_events.event_count) return;

    HitEvent ev = hit_events.events[gid];

    // 도탄 판정
    if (abs(ev.angle_deg) > 70.0) return;

    uint hp_base  = hp_offsets.offsets[ev.instance_id];
    uint bp_base  = bp_offsets.offsets[ev.instance_id];

    // 관통 방향 디코딩
    int  dx       = int((ev.direction >> 4u) & 0xFu) - 2;
    int  dy       = int(ev.direction & 0xFu) - 2;

    int  remaining = int(ev.damage);
    uint cell_off  = ev.cell_offset;

    for (int i = 0; i < int(ev.penetration) && remaining > 0; ++i) {
        // Blueprint 셀 데이터에서 소재 ID 읽기 (byte 0)
        uint bp_cell_base = bp_base + cell_off * 4u;
        uint mat_id       = uint(bp_data.data[bp_cell_base]);     // BYTE_MATERIAL
        uint flags        = uint(bp_data.data[bp_cell_base + 3u]); // BYTE_FLAGS

        // 빈 셀이면 관통 계속
        if ((flags & 0x01u) == 0u) {
            // 방향 이동 (단순화: 1D 오프셋 적용)
            cell_off += 1u;
            continue;
        }

        int resist     = material_resistance(mat_id);
        int actual_dmg = max(1, remaining - resist);

        uint hp_idx    = hp_base + cell_off;
        int  cur_hp    = int(hp_data.data[hp_idx]);
        int  new_hp    = max(0, cur_hp - actual_dmg);

        hp_data.data[hp_idx] = uint8_t(new_hp);

        if (new_hp == 0) {
            // 파괴 이벤트 기록 (atomic으로 안전하게)
            uint slot = atomicAdd(destroyed.count, 1u);
            if (slot < destroyed.cells.length()) {
                destroyed.cells[slot] = uvec2(ev.instance_id, cell_off);
            }
        }

        remaining -= resist;
        cell_off  += 1u;
    }
}
