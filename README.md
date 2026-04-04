# Project Workflow

## Current Version
- `dev-0.022`

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
  - star population 점검
  - 고 n_star에서 은하 약간 외곽쯤에 항성 밀도차로 인한 원이 보임 (n_star에 따라 밀도 역전, 저 n_star에선 밖 밀도 < 안 밀도, 자연스러움) (수정필요? 불필요?)
  - bulge, disk, stellar halo 이상 (특정 은하(특히 고질량)에서 f_bulge < f_disk일 때 f_bulge가 압도적으로 큰 문제 발생) (수정필요? 불필요?)
  - 0.1MW 이하의 왜소은하에서 bulge r_eff_kpc가 극단적으로 작은 경우 존재
  - bulge, disk, stellar halo의 영역 자르기 삭제?

  - 디버깅
  - 최적화
