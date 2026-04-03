# Project Workflow

## Current Version
- `dev-0.020`

## Git Commands
```bash
cd %path%
git pull --rebase
git add .
git commit -m ""
git push
```

## TODO/BUG
  - 은하 타입 추론(로지스틱 회귀)
  - 항성이 bulge 최솟값에서 원모양으로 수렴
  - z: 적색편이가 특정 계산에 적용되지 않음
  - 금속도가 너무 높음
  - stable_inner_radius가 최솟값으로 고정되는 일이 많음
  - 나선팔 = 0인 은하에서 공백 영역 발생
  - disk radius > bulge radius
  - bulge, disk 계산 전면 수정
  - bulge, disk, star_halo 경계면이 인위적인 원모양
  - SMBH 시각화
  - 디버깅
  - 최적화
