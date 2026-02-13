# Project Workflow

## Current Version
- `0.0.003-dev`

## Version History (표기 위치)
- 버전별 변경사항은 **이 README의 `Version History` 표**에 기록한다.
- 모든 커밋은 아래 2가지를 함께 갱신한다.
  1) `Current Version`
  2) `Version History` 최신 행

| Version | Date | Summary |
|---|---|---|
| 0.0.003-dev | 2026-02-13 | wndqhrehlsms vkdlf wprj. ekfms wndqhrehlsms vkdlfdl dlTsmswl ghkrdls vlfdy
| 0.0.002-dev | 2026-02-13 | 모든 스크립트 경로를 `skripts/` 하위로 통일 (`resources/editor/systems/shaders` 이동). |
| 0.0.001-dev | 2026-02-13 | Blueprint 코어 구조 도입, 씬 전환/타입 추론 오류 수정, tempf 정리. |

## Script Location Rule (중요)
- 모든 스크립트 파일은 `skripts/` 하위에 둔다.
- 리소스 성격 스크립트: `skripts/resources/`
- 시스템 스크립트: `skripts/systems/`
- 노드 부착 스크립트: `skripts/<씬이름>/`
  - 예: BlueprintEditor 씬 스크립트는 `skripts/BlueprintEditor/`

## Daily Git Commands
```bash
cd /storage/emulated/0/Documents/alpha
git pull --rebase
git add . && git commit -m "작업 내용" && git push
```
