# Project Workflow

## Current Version
- `dev-0.024`

## Git Commands
```bash
cd %path%
git pull --rebase
git add .
git commit -m ""
git push
```

## TODO/BUG
- 은하 타입 추론
- cluster_physics 매우 많은 수정사항
  - 난류 밀도 음수 문제 해결
  - 미사용 인자 정리 또는 실제 모델에 반영
  - hii_radius_pc를 결과에 포함할지 결정
  - cap 값이 물리 의도를 망치지 않는지 재검토
  - Dictionary 대신 타입 있는 구조체로 점진 이행
  - GC/GMC/OB 분포에 z 또는 디스크 두께 반영

  - 디버깅
  - 최적화
