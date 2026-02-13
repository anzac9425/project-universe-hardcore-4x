// cell_damage.glsl
// 셀 단위 피해 계산 Compute Shader (스캐폴드)
// NOTE: 현재는 데이터 형식을 보수적으로 맞춘 안전한 초안이며,
// 실제 게임 적용 전에 ShipInstance CPU fallback 로직과 1:1로 동기화 필요.

#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

struct HitEvent {
    uint  instance_id;
    uint  cell_offset;
    int   damage;
    int   penetration;
    float angle_deg;
    uint  direction; // (dx + 2, dy + 2)
    uint  _pad0;
    uint  _pad1;
};

layout(set = 0, binding = 0, std430) restrict readonly buffer HitEventBuffer {
    uint       event_count;
    HitEvent   events[];
} hit_events;

// 8-bit 타입 확장 의존을 피하기 위해 uint 배열로 저장.
// 실제 값 범위는 0~255로 clamp 하여 사용.
layout(set = 0, binding = 1, std430) restrict buffer HpDataBuffer {
    uint data[];
} hp_data;

layout(set = 0, binding = 2, std430) restrict readonly buffer HpOffsetBuffer {
    uint offsets[];
} hp_offsets;

layout(set = 0, binding = 3, std430) restrict readonly buffer BlueprintBuffer {
    uint data[];
} bp_data;

layout(set = 0, binding = 4, std430) restrict readonly buffer BpOffsetBuffer {
    uint offsets[];
} bp_offsets;

layout(set = 0, binding = 5, std430) restrict buffer DestroyedBuffer {
    uint  count;
    uvec2 cells[];
} destroyed;

int material_resistance(uint mat_id) {
    switch (mat_id) {
        case 1u: return 10;
        case 2u: return 18;
        case 3u: return 25;
        case 4u: return 40;
        case 5u: return 60;
        default: return 5;
    }
}

void main() {
    uint gid = gl_GlobalInvocationID.x;
    if (gid >= hit_events.event_count) return;

    HitEvent ev = hit_events.events[gid];
    if (abs(ev.angle_deg) > 70.0) return;

    uint hp_base = hp_offsets.offsets[ev.instance_id];
    uint bp_base = bp_offsets.offsets[ev.instance_id];

    int remaining = int(ev.damage);
    uint cell_off = ev.cell_offset;

    for (int i = 0; i < int(ev.penetration) && remaining > 0; ++i) {
        uint bp_cell_base = bp_base + cell_off * 4u;
        uint mat_id = bp_data.data[bp_cell_base];
        uint flags  = bp_data.data[bp_cell_base + 3u];

        if ((flags & 0x01u) == 0u) {
            cell_off += 1u;
            continue;
        }

        int resist = material_resistance(mat_id);
        int actual_dmg = max(1, remaining - resist);

        uint hp_idx = hp_base + cell_off;
        int cur_hp  = int(hp_data.data[hp_idx] & 0xFFu);
        int new_hp  = max(0, cur_hp - actual_dmg);
        hp_data.data[hp_idx] = uint(clamp(new_hp, 0, 255));

        if (new_hp == 0) {
            uint slot = atomicAdd(destroyed.count, 1u);
            destroyed.cells[slot] = uvec2(ev.instance_id, cell_off);
        }

        remaining -= resist;
        cell_off += 1u;
    }
}
