extends Sprite2D
class_name StarVisual


static var _shared_texture: Texture2D

var star_data: StarData


func initialize(data: StarData) -> void:
	star_data = data

	if _shared_texture == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_shared_texture = ImageTexture.create_from_image(image)

	texture = _shared_texture
	centered = true
	scale = Vector2.ONE * max(8.0, star_data.radius * 18.0)
	material = _create_star_material()


func set_world_position(position_in_system:Vector2) -> void:
	position = position_in_system


func _create_star_material() -> ShaderMaterial:
	var shader_code := '''
shader_type canvas_item;

uniform vec3 star_color : source_color;
uniform float seed;
uniform float activity;

float hash(vec2 p){
    return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}

float noise(vec2 p){
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i + vec2(1.0,0.0));
    float c = hash(i + vec2(0.0,1.0));
    float d = hash(i + vec2(1.0,1.0));

    vec2 u = f*f*(3.0-2.0*f);

    return mix(a,b,u.x) +
           (c-a)*u.y*(1.0-u.x) +
           (d-b)*u.x*u.y;
}

void fragment(){
    vec2 uv = UV - 0.5;
    float dist = length(uv);

    float circle = smoothstep(0.5,0.48,dist);
    float surface = noise(uv * 6.0 + seed);
    float corona = exp(-dist*6.0) * 0.3;

    vec3 color = star_color + surface * activity;
    COLOR = vec4(color * (circle + corona), circle);
}
'''

	var shader := Shader.new()
	shader.code = shader_code

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("star_color", _star_type_color(star_data.type))
	mat.set_shader_parameter("seed", float(star_data.seed % 100000) * 0.001)
	mat.set_shader_parameter("activity", clamp(star_data.temperature / 10000.0, 0.2, 3.0))

	return mat


func _star_type_color(star_type:StarData.StarType) -> Color:
	match star_type:
		StarData.StarType.O:
			return Color("#8abfff")
		StarData.StarType.B:
			return Color("#a2c7ff")
		StarData.StarType.A:
			return Color("#cad8ff")
		StarData.StarType.F:
			return Color("#f8f7ff")
		StarData.StarType.G:
			return Color("#fff4ea")
		StarData.StarType.K:
			return Color("#ffd2a1")
		StarData.StarType.M:
			return Color("#ffb381")
		_:
			return Color.WHITE
