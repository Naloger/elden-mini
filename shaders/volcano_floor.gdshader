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
	vec2 p = world_pos.xz * 0.65;
	float n = fbm(p);
	float detail = fbm(p * 4.5);
	float vein = abs(fbm(p * 1.4) - 0.5);
	float crack = smoothstep(0.004, 0.014, vein);

	vec3 ash = vec3(0.06, 0.05, 0.045);
	vec3 basalt = vec3(0.14, 0.115, 0.105);
	vec3 ember = vec3(0.85, 0.20, 0.03);

	vec3 stone = mix(ash, basalt, n * 0.7 + detail * 0.3);
	ALBEDO = mix(ember * 0.45, stone, crack);
	ROUGHNESS = 0.94;
	METALLIC = 0.04;
	EMISSION = ember * (1.0 - crack) * 0.25;
}
