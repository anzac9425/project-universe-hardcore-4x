extends RefCounted
class_name PlanetMaterialManager


static var _cache := {}


static func get_material(planet_type:int, lod:int) -> Material:
	var key = str(planet_type) + "_" + str(lod)

	if _cache.has(key):
		return _cache[key]

	var material := ShaderMaterial.new()
	material.shader = _build_shader(lod)
	_cache[key] = material

	return material


static func _build_shader(lod:int) -> Shader:
	var shader := Shader.new()

	if lod <= 1:
		shader.code = '''
shader_type canvas_item;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv);
	float mask = smoothstep(0.5, 0.47, d);
	vec3 tint = COLOR.rgb;
	float shade = 1.0 - d * 0.65;
	COLOR = vec4(tint * shade, mask);
}
'''
	elif lod == 2:
		shader.code = '''
shader_type canvas_item;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv);
	float mask = step(d, 0.5);
	COLOR = vec4(COLOR.rgb, mask);
}
'''
	else:
		shader.code = '''
shader_type canvas_item;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv);
	float mask = step(d, 0.35);
	COLOR = vec4(COLOR.rgb, mask);
}
'''

	return shader
