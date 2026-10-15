shader_type spatial;
// A dirt track: packed earth, mottled, with two darker wheel ruts, a strip of grass up the middle,
// a scatter of pebbles and ragged edges where the moss grows in. Laid along the road strip from its
// UVs (x across 0..1, y along in metres), like the cobbled roads.

render_mode diffuse_lambert, specular_disabled, skip_vertex_transform;

uniform vec3 earth_colour : source_color = vec3(0.47, 0.37, 0.26);
uniform vec3 rut_colour : source_color = vec3(0.34, 0.26, 0.18);
uniform vec3 grass_colour : source_color = vec3(0.42, 0.56, 0.26);
uniform vec3 pebble_colour : source_color = vec3(0.6, 0.57, 0.52);
uniform float road_width = 2.4;
uniform float rut_gap = 1.3;           // metres between the wheel ruts
uniform float bed_length = 6.5;        // metres at the start laid as a levelled sand bed (under new cobbles)
uniform vec3 sand_colour : source_color = vec3(0.7, 0.6, 0.44);

uniform float depth_bias = 0.0004;          // fraction of the distance to pull toward the camera (see vertex())

varying vec2 local;                    // metres: x across from the middle, y along

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.5 + noise(p * 2.03 + 7.1) * 0.3 + noise(p * 4.1 + 3.3) * 0.2;
}

void vertex() {
	local = vec2((UV.x - 0.5) * road_width, UV.y);
	// Pull the surface toward the camera by a tiny fraction of its distance. Seen from the eye this
	// moves nothing on screen, but its depth now clearly wins over whatever lies just below it (the
	// ground, a road running under the square), so the layers don't flicker when seen from far off.
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (PROJECTION_MATRIX[3][3] == 0.0) {                 // perspective (not an orthographic shadow pass)
		view.xyz *= 1.0 - depth_bias;
	}
	VERTEX = view.xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	TANGENT = normalize((MODELVIEW_MATRIX * vec4(TANGENT, 0.0)).xyz);
	BINORMAL = normalize((MODELVIEW_MATRIX * vec4(BINORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = local;
	float half_w = road_width * 0.5;
	// ragged edges: the moss creeps in by up to 0.45 m
	float ragged = fbm(vec2(p.y * 1.3, sign(p.x) * 5.0)) * 0.45 + fbm(vec2(p.y * 6.0, sign(p.x) * 9.0)) * 0.12;
	// at the start, the levelled sand bed the new cobbles are laid on: straight edged, the full width
	float bed = 1.0 - smoothstep(bed_length - 1.0, bed_length + 2.5, p.y);
	ragged *= 1.0 - bed;
	float edge = half_w - abs(p.x) - ragged - bed * 0.05;
	if (edge < 0.0) {
		discard;
	}
	float m = fbm(p * vec2(2.5, 1.2));
	vec3 col = earth_colour * (0.85 + 0.3 * m);
	// the wheel ruts, wobbling a little
	float wob = (noise(vec2(p.y * 0.35, 1.7)) - 0.5) * 0.12;
	float rut = 0.0;
	for (int s = -1; s <= 1; s += 2) {
		float d = abs(p.x - wob - float(s) * rut_gap * 0.5);
		rut = max(rut, 1.0 - smoothstep(0.08, 0.2, d));
	}
	col = mix(col, rut_colour * (0.85 + 0.3 * m), rut * 0.85);
	// grass up the middle between the ruts, patchy
	float mid = 1.0 - smoothstep(0.1, 0.3, abs(p.x - wob));
	float patch = smoothstep(0.45, 0.7, fbm(p * vec2(4.0, 1.5) + 11.0));
	col = mix(col, grass_colour * (0.8 + 0.4 * m), mid * patch * 0.9);
	// and a fringe of grass along the ragged edges
	col = mix(col, grass_colour * (0.75 + 0.4 * m), (1.0 - smoothstep(0.0, 0.22, edge)) * 0.8);
	// pebbles
	vec2 cell = floor(p / 0.17);
	vec2 f = fract(p / 0.17) - 0.5;
	float h = hash(cell);
	if (h > 0.9 && rut < 0.5) {
		vec2 c = vec2(hash(cell + 3.1), hash(cell + 5.7)) * 0.4 - 0.2;
		float r = 0.12 + 0.12 * hash(cell + 9.2);
		float pb = 1.0 - smoothstep(r - 0.04, r, length(f - c));
		col = mix(col, pebble_colour * (0.8 + 0.4 * hash(cell + 1.3)), pb);
	}
	// the sand bed: raked smooth, the rake's lines running along it, scuffed where it gives way to the track
	if (bed > 0.0) {
		float rake = 0.95 + 0.05 * sin(p.x * 70.0 + noise(p * 3.0) * 4.0);
		vec3 sand = sand_colour * (0.88 + 0.2 * fbm(p * 3.0)) * rake;
		float scuff = smoothstep(0.3, 0.75, fbm(p * vec2(1.5, 2.5) + 4.0));
		col = mix(col, sand, bed * (1.0 - 0.45 * scuff * smoothstep(bed_length - 3.0, bed_length, p.y)));
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
