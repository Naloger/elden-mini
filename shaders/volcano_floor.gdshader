shader_type spatial;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * 0.45;
	float n = noise(p) * 0.6 + noise(p * 2.4) * 0.4;
	float vein = abs(noise(p * 1.3) - 0.5);
	float crack = smoothstep(0.015, 0.045, vein);

	vec3 ash = vec3(0.07, 0.055, 0.05);
	vec3 basalt = vec3(0.14, 0.11, 0.10);
	vec3 ember = vec3(0.95, 0.25, 0.03);

	vec3 stone = mix(ash, basalt, n);
	ALBEDO = mix(ember * 0.5, stone, crack);
	ROUGHNESS = 0.92;
	METALLIC = 0.04;
	EMISSION = ember * (1.0 - crack) * 0.35;
}
