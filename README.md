# Project Workflow

## Current Version
- `0.0.001-dev` (last explicit version marker: commit `6564325` message `a0.0.001`)

## Commit Rule (Important)
- Every commit must update this README version section.
- Version format: `major.minor.patch[-suffix]`
- Example:
  - feature: `0.1.0`
  - fix: `0.1.1`
  - in-progress branch work: `0.1.1-dev`

## Daily Git Commands
```bash
cd /storage/emulated/0/Documents/alpha
git pull --rebase
git add . && git commit -m "작업 내용" && git push

a0.0.003
