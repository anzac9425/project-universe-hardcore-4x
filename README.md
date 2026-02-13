# Project Workflow

## Current Version
- `0.0.003-dev`

## Version History (Canonical Location)
- Record per-version changes in this README `Version History` table.
- Every commit must update both:
  1) `Current Version`
  2) the latest row in `Version History`

| Version | Date | Summary |
|---|---|---|
| 0.0.003-dev | 2026-02-13 | Fixed cross-script type-resolution issues (`Blueprint`/`BlueprintStats`) by reducing fragile direct type coupling and adding preload-based construction where needed. |
| 0.0.002-dev | 2026-02-13 | Unified all script paths under `skripts/` and updated scene/script links. |
| 0.0.001-dev | 2026-02-13 | Introduced Blueprint core structure, fixed scene flow/type inference issues, and removed tempf artifacts. |

## Script Location Rule (Important)
- All scripts must live under `skripts/`.
- Resource scripts: `skripts/resources/`
- System scripts: `skripts/systems/`
- Node-attached scripts: `skripts/<SceneName>/`
  - Example: BlueprintEditor scene script must be in `skripts/BlueprintEditor/`

## Daily Git Commands
```bash
cd /storage/emulated/0/Documents/alpha
git pull --rebase
git add . && git commit -m "work"
git push
```
