은하 생성 절차

━━━ PHASE 1: 전역 파라미터 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1.  입력 파라미터 정의 #
	  - global_seed, time

2.  결정론적 서브시드 파생 #
	  - galaxy_seed = hash(global_seed, GALAXY)

3.  은하 나이 / 형성 적색편이 샘플링 #
	  - z_form ~ 로그정규 (mu=0.8, sigma=0.5)
	  - age_gyr = lookback_time(z_form)
	  - 이후 SFR, 진화 단계, 금속도 모두 이 값에 조건부

_4.  은하 타입 샘플링 (허블 시퀀스) X
	  - E / S0 / Sa-Sd / Irr 확률 분포
	  - galaxy_type → 이후 나선팔 단계(16) 진입 여부 결정

5.  총 질량 샘플링 (로그정규) #
	  - M_gal = exp(mu + sigma * Z)


━━━ PHASE 2: 질량 분해 & 형태 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

6.  바리온 분율 / 가스 분율 샘플링 #
	  - f_baryon(seed, M_vir)
	  - f_gas(seed, M_vir, f_baryon, z_form, delta_physics)

7.  디스크 / 벌지 / 헤일로 질량 분해 #
	  - f_star_halo, f_bulge, f_disk, s_morph

8.  암흑물질 헤일로 프로파일 #
	  - NFW concentration c200, r200c, rs, rho_s
	  - halo_state_from_mvir()


━━━ PHASE 3: 기하 구조 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

9.  디스크 스케일 길이 샘플링 #
	  - van der Wel+2014 size-mass 기반 로그정규
	  - Rd = Reff / 1.678

10. 디스크 두께 샘플링 #
	  - q = z0 / Rd  (logistic-normal)
	  - 가스 분율 ↑ → 더 얇음 / 벌지 비중 ↑ → 더 두꺼움

11. 벌지 Sérsic index & 유효 반지름 샘플링 #
	  - n_sersic: logistic-normal, 질량/형태 조건부
	  - r_eff: van der Wel+2014 early-type 기반


━━━ PHASE 4: 중심 블랙홀 & AGN ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

12. SMBH 기본 물리량 #
	  - M_BH: M–M_bulge 관계 (Kormendy & Ho 2013)
	  - spin_a: coherent/chaotic accretion 혼합 분포
	  - eta_rad: Kerr ISCO → 복사 효율
	  - 강착 원반 존재 여부 (p_disk)

13. AGN 활성도 & 관측 분류 #
	  - log10_lambda: Eddington 비율 프록시
	  - L_bol, L_Edd 계산
	  - 차폐 확률 (receding torus model)
	  - agn_class: quasar / seyfert / liner / weak × Type 1/2

14. 제트 파라미터 #
	  - p_jet: Blandford-Znajek (spin² × 질량 × ADAF boost)
	  - log10_P_jet [W]
	  - jet_morphology: FRI / FRII / compact
	  - jet_lorentz, jet_half_angle_deg


━━━ PHASE 5: 항성 집단 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

15. 별 형성률 (SFR) 샘플링 #
	  - SFMS 기반 로그정규
	  - AGN 피드백(14) → quenching 보정
	  - f_gas, delta_physics 조건부

16. 금속도 분포 #
	  - 중심 금속도: mass-metallicity 관계
	  - 반경 방향 gradient: -0.05 ~ -0.10 dex/kpc
	  - 산포: 0.10 dex


━━━ PHASE 6: 나선 구조 (galaxy_type == spiral 분기) ━━━━━━━━━

17. 나선팔 개수 샘플링 #
	  - m = 2 (Sd까지) / m = 4 (grand design) 확률 분포
	  - 타원/S0 → 이 블록 전체 skip

18. 피치 각 샘플링 (로그정규) #
	  - 관측 범위: 5° ~ 35°
	  - 질량 ↑ → 피치각 ↓ 경향

19. 팔 강도 (contrast) 샘플링 #
	  - f_gas, SFR 조건부
	  - 가스 풍부 → 강한 팔

20. 팔 위상 오프셋 생성 #
	  - 각 팔마다 균등 분포 + 작은 산포


━━━ PHASE 7: 공간 분포 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

21. 반경 방향 표면밀도 프로파일 생성 #
	  - 지수 디스크: Σ(R) = Σ0 · exp(-R/Rd)
	  - 벌지: Sérsic 프로파일 추가

22. 확률 밀도장 (PDF) 구성 #
	  - 디스크 + 벌지 + 나선팔(해당 시) + Poisson 노이즈

23. 별 총 개수 결정 #
	  - N_star = M_star / <m_IMF>
	  - Kroupa IMF 적분으로 <m_IMF> 계산
	  - 렌더링 예산에 맞게 N 클램프

24. 별 위치 샘플링 (PDF 기반, 비균일) #
	  - rejection sampling 또는 역CDF

25. 회전 곡선 생성 #
	  - V²(R) = V²_DM(R) + V²_disk(R) + V²_bulge(R)
	  - NFW + 지수 디스크 + Hernquist 벌지 합산

26. Jeans / Hill 안정성 필터 #
	  - Q_Toomre > 1 조건 (불안정 영역 재샘플링)
	  - Hill 반지름 기준 최소 이웃 거리


━━━ PHASE 8: 개별 별 물리량 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

27. 개별 별 질량 배정 (IMF) #
	  - Kroupa: dN/dm ∝ m^-2.3  (m > 0.5 Msun)
	  -                 m^-1.3  (m < 0.5 Msun)

28. 항성 진화 단계 샘플링 #
	  - 나이(age_gyr) + 질량 → HR도 위치
	  - MS / SGB / RGB / HB / AGB / WD / NS / BH

29. 광도 / 유효온도 / 반지름 파생 #
	  - MIST/BaSTI isochrone 근사 다항식
	  - L(M, age), T_eff(M, age), R(M, age)


━━━ PHASE 9: 성단 & 성간물질 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

30. 성단 / 성운 생성 # but not applied
	  - 클러스터링 확률: SFR, 금속도 조건부
	  - OB 성협, 구상성단, HII 영역

31. 가스 구름 분포
	  - 난류 Kolmogorov 스펙트럼 기반 프랙탈
	  - 분자운 질량 함수: dN/dM ∝ M^-1.8


━━━ PHASE 10: 궤도 & 시간 진화 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

32. 각 별의 궤도 결정
	  - V_circ(R) from 25번 회전 곡선
	  - 경사각 i, 방위각 φ 샘플링                ← 신규
	  - 이심률 e: 속도 분산 조건부 로그정규

33. 시간 위상 계산
	  - T_orbit(R) = 2π R / V_circ(R)
	  - phase(R, t) = (t / T_orbit) mod 1.0

34. 위치 / 속도 갱신
	  - x(t) = R · cos(phase · 2π + φ0)
	  - y(t) = R · sin(phase · 2π + φ0)
	  - z(t) = z0 · sin(i · phase · 2π)

35. Time wrapping
	  - t_eff = t mod T_max  (T_max = lcm of 대표 궤도 주기)
	  - 동일 seed + time → 완전 동일 상태 보장


━━━ PHASE 11: 출력 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

36. 최종 은하 상태 출력
	  - 상태 저장 없이 seed + time 만으로 완전 재생성 가능
	  - GalaxyData 반환
