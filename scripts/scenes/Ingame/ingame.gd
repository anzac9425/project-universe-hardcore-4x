extends Node2D

const SYSTEM_DOT_RADIUS := 6.0
const GALAXY_CENTER_COLOR := Color("ffd166")
const SYSTEM_COLOR := Color("74c0fc")

const STAR_BASE_SIZE := 2.2
const STAR_MAX_SIZE := 11.5
const STAR_MAP_SCALE := 16.0

var _star_field: MultiMeshInstance2D


func _ready() -> void:
	_build_star_field()
	queue_redraw()


func _draw() -> void:
	if GameSession.galaxy == null:
		Log.error(20, "Galaxy data is null")
		return

	draw_circle(Vector2.ZERO, SYSTEM_DOT_RADIUS * 1.4, GALAXY_CENTER_COLOR)

	for system in GameSession.galaxy.systems:
		draw_circle(system.location, SYSTEM_DOT_RADIUS, SYSTEM_COLOR)


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

		var scale := STAR_BASE_SIZE + STAR_MAX_SIZE * (0.55 * radius_norm + 0.45 * luminosity_norm)
		var xform := Transform2D(0.0, pos)
		xform.x = Vector2(scale, 0.0)
		xform.y = Vector2(0.0, scale)
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

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float r = length(p);
	float mask = smoothstep(1.0, 0.66, r);
	if (mask <= 0.001) {
		discard;
	}

	float mass_norm = INSTANCE_CUSTOM.r;
	float remnant_norm = INSTANCE_CUSTOM.g;
	float phase_norm = INSTANCE_CUSTOM.b;
	float lum_norm = INSTANCE_CUSTOM.a;

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


func _temperature_to_color(log10_t_eff_k: float) -> Color:
	if not is_finite(log10_t_eff_k):
		return Color(0.35, 0.32, 0.42)

	var t := clamp(pow(10.0, log10_t_eff_k), 800.0, 40000.0)
	var x := clamp((t - 800.0) / (40000.0 - 800.0), 0.0, 1.0)
	var r := clamp(1.0 - 0.45 * x, 0.40, 1.0)
	var g := clamp(0.35 + 0.55 * sqrt(x), 0.25, 1.0)
	var b := clamp(0.12 + 0.92 * x, 0.12, 1.0)
	return Color(r, g, b)


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
