extends Node2D

const SYSTEM_DOT_RADIUS := 1.0
const GALAXY_CENTER_COLOR := Color("ffd166")
const SYSTEM_COLOR := Color("74c0fc")

const STAR_BASE_SIZE := 2.2
const STAR_MAX_SIZE := 11.5
const STAR_MAP_SCALE := 16.0
const SMBH_BASE_RADIUS := 10.0
const SMBH_MAX_RADIUS := 58.0
const SMBH_RING_MIN := 12.0
const SMBH_RING_MAX := 130.0
const SMBH_JET_MAX_LENGTH := 460.0

var _star_field: MultiMeshInstance2D


func _ready() -> void:
	_build_star_field()
	queue_redraw()


func _draw() -> void:
	if GameSession.galaxy == null:
		Log.error(20, "Galaxy data is null")
		return

	draw_circle(Vector2.ZERO, SYSTEM_DOT_RADIUS * 1.4, GALAXY_CENTER_COLOR)
	_draw_smbh_overlay()

	for system in GameSession.galaxy.systems:
		draw_circle(system.location, SYSTEM_DOT_RADIUS, SYSTEM_COLOR)


func _draw_smbh_overlay() -> void:
	var galaxy := GameSession.galaxy
	if galaxy == null or galaxy.accretion_disk == null:
		return

	var ad := galaxy.accretion_disk
	var p_exist := clamp(ad.p_bh_exist, 0.0, 1.0)
	if not ad.has_bh and p_exist <= 0.01:
		return

	var has_bh_factor := 1.0 if ad.has_bh else 0.40
	var bh_mass := max(ad.m_bh_kg / C.SOLAR_MASS, 0.0)
	var log_m := ad.log10_m_bh_msun if is_finite(ad.log10_m_bh_msun) else 0.0
	var mass_norm := clamp((log_m - 5.0) / 5.0, 0.0, 1.0)
	if mass_norm <= 0.0 and bh_mass > 0.0:
		mass_norm = clamp(log(1.0 + bh_mass) / log(1.0 + 1.0e10), 0.0, 1.0)

	var core_radius := lerp(SMBH_BASE_RADIUS, SMBH_MAX_RADIUS, mass_norm)
	core_radius *= has_bh_factor * (0.75 + 0.25 * p_exist)

	var spin_norm := clamp((ad.spin_a + 1.0) * 0.5, 0.0, 1.0)
	var eta_norm := clamp((ad.eta_rad - 0.03) / 0.39, 0.0, 1.0)
	var p_mass_norm := clamp(ad.p_bh_mass, 0.0, 1.0)
	var coherent_norm := clamp(ad.p_coherent, 0.0, 1.0)
	var fuel_norm := clamp(ad.p_fuel, 0.0, 1.0)
	var disk_prob_norm := clamp(ad.p_disk, 0.0, 1.0)
	var lambda_norm := clamp((ad.log10_lambda_proxy + 6.0) / 7.0, 0.0, 1.0) if is_finite(ad.log10_lambda_proxy) else 0.0
	var lum_norm := clamp((ad.log10_l_bol_lsun + 2.0) / 16.0, 0.0, 1.0) if is_finite(ad.log10_l_bol_lsun) else 0.0
	var edd_norm := clamp((ad.log10_l_edd_lsun + 3.0) / 16.0, 0.0, 1.0) if is_finite(ad.log10_l_edd_lsun) else 0.0
	var obscured_norm := clamp(ad.p_obscured, 0.0, 1.0)
	var jet_prob_norm := clamp(ad.p_jet, 0.0, 1.0)
	var jet_power_norm := clamp((ad.log10_p_jet_w - 30.0) / 18.0, 0.0, 1.0) if is_finite(ad.log10_p_jet_w) else 0.0
	var jet_lorentz_norm := clamp((ad.jet_lorentz - 1.0) / 29.0, 0.0, 1.0)
	var jet_half_angle_norm := clamp(ad.jet_half_angle_deg / 45.0, 0.0, 1.0)

	var agn_hash := float(abs(ad.agn_class.hash()) % 1000) / 1000.0
	var jet_morph_hash := float(abs(ad.jet_morphology.hash()) % 1000) / 1000.0

	var bh_color := Color(0.05, 0.07, 0.10, 0.95)
	var halo_color := Color(
		0.45 + 0.45 * lambda_norm,
		0.30 + 0.55 * (0.5 * eta_norm + 0.5 * coherent_norm),
		0.22 + 0.65 * (0.5 * spin_norm + 0.5 * agn_hash),
		0.18 + 0.60 * lum_norm
	)
	draw_circle(Vector2.ZERO, core_radius * (1.45 + 0.55 * lum_norm), halo_color)
	draw_circle(Vector2.ZERO, core_radius, bh_color)

	if ad.has_disk or disk_prob_norm > 0.05:
		var ring_radius := lerp(SMBH_RING_MIN, SMBH_RING_MAX, clamp(ad.r_out_rg / 100000.0, 0.0, 1.0))
		ring_radius *= (0.55 + 0.45 * (mass_norm * 0.5 + p_mass_norm * 0.5))
		var ring_width := 2.0 + 7.0 * (0.6 * fuel_norm + 0.4 * disk_prob_norm)
		var ring_alpha := 0.15 + 0.75 * (0.4 * lambda_norm + 0.6 * lum_norm)
		var ring_color := Color(
			0.72 + 0.25 * eta_norm,
			0.36 + 0.52 * coherent_norm,
			0.20 + 0.55 * spin_norm,
			ring_alpha
		)
		draw_arc(Vector2.ZERO, ring_radius, -PI, PI, 96, ring_color, ring_width, true)
		draw_arc(Vector2.ZERO, ring_radius + ring_width * 0.75, -PI, PI, 96, ring_color * Color(1.0, 1.0, 1.0, 0.5), 1.25, true)

	if ad.has_jet or jet_prob_norm > 0.05:
		var jet_length := lerp(40.0, SMBH_JET_MAX_LENGTH, 0.35 * jet_power_norm + 0.35 * jet_lorentz_norm + 0.30 * jet_prob_norm)
		var tilt := lerp(-0.65, 0.65, jet_morph_hash)
		var jet_dir := Vector2(cos(tilt), sin(tilt)).normalized()
		var jet_open := deg_to_rad(max(ad.jet_half_angle_deg, 0.4))
		var jet_width := 1.2 + 8.0 * (0.55 * jet_half_angle_norm + 0.45 * jet_prob_norm)
		var jet_color := Color(
			0.35 + 0.45 * jet_prob_norm,
			0.62 + 0.35 * (1.0 - obscured_norm),
			0.88 + 0.12 * jet_morph_hash,
			0.20 + 0.70 * jet_power_norm
		)

		var forward := jet_dir * jet_length
		var backward := -forward
		draw_line(Vector2.ZERO, forward, jet_color, jet_width, true)
		draw_line(Vector2.ZERO, backward, jet_color, jet_width, true)

		var wing_len := jet_length * 0.18
		var wing_dir_a := jet_dir.rotated(jet_open * 0.5)
		var wing_dir_b := jet_dir.rotated(-jet_open * 0.5)
		draw_line(forward * 0.82, forward * 0.82 + wing_dir_a * wing_len, jet_color * Color(1.0, 1.0, 1.0, 0.65), max(1.0, jet_width * 0.35), true)
		draw_line(forward * 0.82, forward * 0.82 + wing_dir_b * wing_len, jet_color * Color(1.0, 1.0, 1.0, 0.65), max(1.0, jet_width * 0.35), true)
		draw_line(backward * 0.82, backward * 0.82 - wing_dir_a * wing_len, jet_color * Color(1.0, 1.0, 1.0, 0.65), max(1.0, jet_width * 0.35), true)
		draw_line(backward * 0.82, backward * 0.82 - wing_dir_b * wing_len, jet_color * Color(1.0, 1.0, 1.0, 0.65), max(1.0, jet_width * 0.35), true)

	if ad.is_obscured:
		var obscuration_r := core_radius * (1.7 + 1.0 * obscured_norm)
		var obscuration_color := Color(0.07, 0.05, 0.04, 0.25 + 0.60 * obscured_norm)
		draw_circle(Vector2.ZERO, obscuration_r, obscuration_color)


func _build_star_field() -> void:
	if GameSession.galaxy == null or GameSession.galaxy.galaxy_field == null:
		return

	if is_instance_valid(_star_field):
		_star_field.queue_free()

	var field := GameSession.galaxy.galaxy_field
	var population := field.star_population
	if population.is_empty() or not population.has("masses_msun"):
		return

	var positions: PackedVector2Array = field.positions_kpc
	var masses: PackedFloat32Array = population.get("masses_msun", PackedFloat32Array())
	var phases: PackedInt32Array = population.get("phases", PackedInt32Array())
	var logls: PackedFloat32Array = population.get("log10_l_lsun", PackedFloat32Array())
	var logts: PackedFloat32Array = population.get("log10_t_eff_k", PackedFloat32Array())
	var radii: PackedFloat32Array = population.get("r_rsun", PackedFloat32Array())
	var remnants: PackedFloat32Array = population.get("m_remnant_msun", PackedFloat32Array())

	var n_star := positions.size()
	n_star = mini(n_star, masses.size())
	n_star = mini(n_star, phases.size())
	n_star = mini(n_star, logls.size())
	n_star = mini(n_star, logts.size())
	n_star = mini(n_star, radii.size())
	n_star = mini(n_star, remnants.size())

	if n_star <= 0:
		return

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = QuadMesh.new()
	multimesh.mesh.size = Vector2.ONE
	multimesh.instance_count = n_star


	for i in range(n_star):
		var pos: Vector2 = positions[i] * STAR_MAP_SCALE
		var mass: float = max(masses[i], 0.0)
		var phase: int = phases[i]
		var log_l: float = logls[i]
		var log_t: float = logts[i]
		var r_rsun: float = max(radii[i], 0.0)
		var remnant_m: float = max(remnants[i], 0.0)

		var luminosity_norm := _normalize_log_l(log_l)
		var radius_norm := _normalize_radius(r_rsun)
		var mass_norm := _normalize_mass(mass)
		var remnant_norm := _normalize_remnant(remnant_m)
		var phase_norm := float(phase) / 7.0

		var scale_ := STAR_BASE_SIZE + STAR_MAX_SIZE * (0.55 * radius_norm + 0.45 * luminosity_norm)
		var xform := Transform2D(0.0, pos)
		xform.x = Vector2(scale_, 0.0)
		xform.y = Vector2(0.0, scale_)
		multimesh.set_instance_transform_2d(i, xform)

		var temp_color := _temperature_to_color(log_t)
		var phase_tint := _phase_tint(phase)
		var visual_color := temp_color.lerp(phase_tint, 0.40)
		visual_color.a = 0.22 + 0.78 * luminosity_norm
		multimesh.set_instance_color(i, visual_color)

		multimesh.set_instance_custom_data(i, Color(mass_norm, remnant_norm, phase_norm, luminosity_norm))

	_star_field = MultiMeshInstance2D.new()
	_star_field.multimesh = multimesh
	_star_field.texture = _build_star_texture()
	_star_field.material = _build_star_shader_material()
	add_child(_star_field)


func _build_star_texture() -> Texture2D:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(image)


func _build_star_shader_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

varying vec4 instance_custom_data;

void vertex() {
	instance_custom_data = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float r = length(p);
	float mask = smoothstep(1.0, 0.66, r);
	if (mask <= 0.001) {
		discard;
	}

	float mass_norm = instance_custom_data.r;
	float remnant_norm = instance_custom_data.g;
	float phase_norm = instance_custom_data.b;
	float lum_norm = instance_custom_data.a;

	float core = smoothstep(0.75, 0.0, r);
	float glow = smoothstep(1.0, 0.15, r);
	vec3 remnant_tint = vec3(0.85, 0.55, 1.0);
	vec3 phase_tint = mix(vec3(0.85, 0.92, 1.0), vec3(1.0, 0.78, 0.55), phase_norm);
	vec3 color = COLOR.rgb;
	color = mix(color, phase_tint, 0.25);
	color = mix(color, remnant_tint, remnant_norm * 0.45);
	color *= (0.55 + 0.65 * mass_norm) * (0.70 + 0.50 * lum_norm);
	color += core * (0.15 + 0.55 * lum_norm);

	float alpha = COLOR.a * glow * mask;
	COLOR = vec4(color, alpha);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _temperature_to_color(log10_t_eff_k: float, sat: float = 0.55, value_mul: float = 1.0) -> Color:
	if not is_finite(log10_t_eff_k):
		return Color(0.35, 0.32, 0.42)

	var t: float = clamp(pow(10.0, log10_t_eff_k), 800.0, 40000.0)

	var r8: float
	var g8: float
	var b8: float

	var temp: float = t / 100.0

	if temp <= 66.0:
		r8 = 255.0
		g8 = clamp(99.4708025861 * log(temp) - 161.1195681661, 0.0, 255.0)

		if temp <= 19.0:
			b8 = 0.0
		else:
			b8 = clamp(138.5177312231 * log(temp - 10.0) - 305.0447927307, 0.0, 255.0)
	else:
		r8 = clamp(329.698727446 * pow(temp - 60.0, -0.1332047592), 0.0, 255.0)
		g8 = clamp(288.1221695283 * pow(temp - 60.0, -0.0755148492), 0.0, 255.0)
		b8 = 255.0

	var base := Color(r8 / 255.0, g8 / 255.0, b8 / 255.0)

	# ✅ HSV 값 가져오기 (Godot 방식)
	var h := base.h
	var v := base.v

	# 채도 고정 + 밝기 보정
	var s: float = clamp(sat, 0.0, 1.0)
	v = clamp(v * value_mul, 0.0, 1.0)

	return Color.from_hsv(h, s, v)


func _phase_tint(phase: int) -> Color:
	match phase:
		StarPhysics.StellarPhase.MS:
			return Color(0.95, 0.97, 1.0)
		StarPhysics.StellarPhase.SGB:
			return Color(1.0, 0.92, 0.78)
		StarPhysics.StellarPhase.RGB:
			return Color(1.0, 0.72, 0.40)
		StarPhysics.StellarPhase.HB:
			return Color(1.0, 0.88, 0.60)
		StarPhysics.StellarPhase.AGB:
			return Color(1.0, 0.62, 0.36)
		StarPhysics.StellarPhase.WD:
			return Color(0.72, 0.86, 1.0)
		StarPhysics.StellarPhase.NS:
			return Color(0.70, 0.78, 1.0)
		StarPhysics.StellarPhase.BH:
			return Color(0.52, 0.42, 0.62)
		_:
			return Color(1.0, 1.0, 1.0)


func _normalize_log_l(log_l: float) -> float:
	if not is_finite(log_l):
		return 0.0
	return clamp((log_l + 5.0) / 10.5, 0.0, 1.0)


func _normalize_radius(r_rsun: float) -> float:
	if not is_finite(r_rsun) or r_rsun <= 0.0:
		return 0.0
	return clamp(log(1.0 + r_rsun) / log(1.0 + 1200.0), 0.0, 1.0)


func _normalize_mass(mass: float) -> float:
	if not is_finite(mass) or mass <= 0.0:
		return 0.0
	return clamp(log(1.0 + mass) / log(1.0 + 150.0), 0.0, 1.0)


func _normalize_remnant(remnant_m: float) -> float:
	if not is_finite(remnant_m) or remnant_m <= 0.0:
		return 0.0
	return clamp(remnant_m / 60.0, 0.0, 1.0)
