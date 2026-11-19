shader_type spatial;
render_mode unshaded;

uniform float speed = 0.18;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV * 14.0;
	float t = TIME * speed;
	float n1 = noise(uv + vec2(t, t * 0.7));
	float n2 = noise(uv * 2.1 - vec2(t * 0.8, -t * 0.5));
	float magma = clamp(n1 * 0.65 + n2 * 0.45, 0.0, 1.0);

	vec3 crust = vec3(0.12, 0.03, 0.01);
	vec3 red_hot = vec3(0.95, 0.18, 0.02);
	vec3 bright = vec3(1.0, 0.68, 0.12);

	vec3 col = mix(crust, red_hot, smoothstep(0.35, 0.72, magma));
	col = mix(col, bright, smoothstep(0.72, 0.96, magma));
	ALBEDO = col * 1.4;
}
