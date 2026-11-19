shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

// Волны те же, что в прототипе (waveY), плюс отмели у островов.
uniform float amp = 0.5;
uniform float wtime = 0.0;
uniform vec4 islands[32];     // x, z, радиус, 0
uniform int island_count = 0;
uniform vec3 deep_col : source_color = vec3(0.04, 0.22, 0.34);
uniform vec3 mid_col : source_color = vec3(0.08, 0.33, 0.46);
uniform vec3 shallow_col : source_color = vec3(0.30, 0.72, 0.74);
uniform vec3 foam_col : source_color = vec3(0.92, 0.97, 1.0);
uniform float night = 0.0;
uniform vec3 haze_col : source_color = vec3(0.78, 0.87, 0.91);

varying highp vec3 wpos;
varying float crest;

float wave(highp vec2 p, highp float t) {
	return amp * (0.6 * sin(0.021 * p.x + t * 1.1) + 0.4 * sin(0.033 * p.y - t * 0.9) + 0.25 * sin(0.05 * (p.x + p.y) + t * 1.7));
}

void vertex() {
	highp vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = wave(w.xz, wtime);
	VERTEX.y += h;
	float e = 2.0;
	float hx = wave(w.xz + vec2(e, 0.0), wtime);
	float hz = wave(w.xz + vec2(0.0, e), wtime);
	NORMAL = normalize(vec3(h - hx, e, h - hz));
	wpos = w;
	crest = clamp(h / max(amp, 0.01) - 0.55, 0.0, 1.0);
}

void fragment() {
	float shallow = 0.0;
	float foam = 0.0;
	for (int i = 0; i < 32; i++) {
		if (i >= island_count) break;
		vec4 isl = islands[i];
		float d = length(wpos.xz - isl.xy) - isl.z;
		shallow = max(shallow, 1.0 - smoothstep(0.0, 230.0, d));
		foam = max(foam, 1.0 - smoothstep(0.0, 22.0, abs(d - 4.0)));
	}
	vec3 col = mix(deep_col, mid_col, 0.35);
	col = mix(col, shallow_col, shallow * shallow);
	col += crest * 0.18;
	col = mix(col, foam_col, foam * 0.55);
	col *= mix(1.0, 0.62, night);
	highp float dist = length(wpos.xz - CAMERA_POSITION_WORLD.xz);
	col = mix(col, haze_col, smoothstep(700.0, 2200.0, dist) * 0.75);
	ALBEDO = col;
	ROUGHNESS = 0.55;
	METALLIC = 0.0;
	SPECULAR = 0.12;
}
