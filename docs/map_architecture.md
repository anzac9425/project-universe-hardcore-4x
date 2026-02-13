# Map Architecture (Phase 1)

## Goal
- Prioritize map implementation before deeper Blueprint expansion.
- Keep map memory layout cache-friendly with `PackedByteArray`.
- Stream chunks in/out for large star-system scale.

## Scripts
- `skripts/map/map_chunk_data.gd`
  - Chunk cell container (`128x128`, 4 bytes per cell).
  - Raw `PackedByteArray` serialization/deserialization.
- `skripts/map/map_world.gd`
  - Chunk generation, cache (`loaded_chunks`), and distance-based unload.
- `skripts/Ingame/ingame.gd`
  - Ingame bootstrap for map world and 3x3 neighborhood streaming.

## Next Steps
- Replace deterministic hash terrain with real noise pipeline.
- Connect camera/world position to dynamic chunk center.
- Add floating-origin recentering and LOD simulation tiers.
