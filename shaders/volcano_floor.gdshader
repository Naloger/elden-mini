shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.22;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	v += 0.55 * noise(p);
	v += 0.30 * noise(p * 2.3);
	v += 0.15 * noise(p * 5.1);
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv_main = world_pos.xz * uv_scale;
	vec2 uv_macro = world_pos.xz * (uv_scale * 0.27) + vec2(0.37, 0.61);

	vec3 tex_a = texture(albedo_tex, uv_main).rgb;
	vec3 tex_macro = texture(albedo_tex, uv_macro).rgb;
	vec3 rock = mix(tex_a, tex_macro, 0.35);

	vec3 n1 = texture(normal_tex, uv_main).rgb;
	vec3 n2 = texture(normal_tex, uv_macro).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.3));
	NORMAL_MAP_DEPTH = 1.45;

	// Darken & char toward Volcano Manor basalt/ash palette
	float ash_mask = fbm(world_pos.xz * 0.18);
	vec3 basalt_tint = mix(vec3(0.36, 0.28, 0.24), vec3(0.55, 0.44, 0.38), ash_mask);
	vec3 stone = rock * basalt_tint;

	// Fine glowing magma fissures in rock crevices
	float vein = abs(fbm(world_pos.xz * 0.45) - 0.5);
	float crack = smoothstep(0.003, 0.011, vein);
	float pulse = 0.78 + 0.22 * sin(TIME * 2.1 + world_pos.x * 0.3 + world_pos.z * 0.25);
	vec3 ember = vec3(1.0, 0.24, 0.03) * pulse;

	ALBEDO = mix(ember * 0.5, stone, crack);
	ROUGHNESS = mix(0.35, 0.90 - rock.r * 0.12, crack);
	METALLIC = 0.05;
	EMISSION = ember * (1.0 - crack) * 0.45;
}
