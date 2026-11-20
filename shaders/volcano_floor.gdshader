shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.16;

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
	// Dual-scale world-space volcanic basalt sampling (zero visible tiling seams)
	vec2 uv_detail = world_pos.xz * uv_scale;
	vec2 uv_macro = world_pos.xz * (uv_scale * 0.23) + vec2(0.41, 0.73);

	vec3 rock_d = texture(albedo_tex, uv_detail).rgb;
	vec3 rock_m = texture(albedo_tex, uv_macro).rgb;
	vec3 rock = mix(rock_d, rock_m, 0.38);

	vec3 n_d = texture(normal_tex, uv_detail).rgb;
	vec3 n_m = texture(normal_tex, uv_macro).rgb;
	NORMAL_MAP = normalize(mix(n_d, n_m, 0.35));
	NORMAL_MAP_DEPTH = 2.0;

	// Ash drifts & scorched basalt patches (authentic Rykard Audience Chamber ground)
	float ash_patch = smoothstep(0.32, 0.72, fbm(world_pos.xz * 0.09));
	vec3 dark_basalt = rock * vec3(0.72, 0.60, 0.54);
	vec3 grey_ash = rock * vec3(1.15, 1.02, 0.94);
	vec3 surface = mix(dark_basalt, grey_ash, ash_patch * 0.65);

	// Subtle outer-edge heat glow near the surrounding lava ring (radius > 34m)
	float dist = length(world_pos.xz);
	float rim_heat = smoothstep(32.0, 41.5, dist) * (1.0 - smoothstep(0.18, 0.45, rock.r));
	vec3 ember = vec3(1.0, 0.25, 0.03) * (0.85 + 0.15 * sin(TIME * 2.0 + dist * 0.4));

	ALBEDO = mix(surface, ember * 0.6, rim_heat * 0.55);
	ROUGHNESS = clamp(0.92 - rock.r * 0.25, 0.55, 0.95);
	METALLIC = 0.06;
	EMISSION = ember * rim_heat * 0.65;
}
