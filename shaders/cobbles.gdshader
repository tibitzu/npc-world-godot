shader_type spatial;
// Grey cobblestones laid in offset rows, with dark mortar between them and a border of larger
// kerb stones round the edge. On the town square (a flat plane) the stones come from the plane's
// position; on a road (road = true) they're laid along it from its UVs (x across 0..1, y along in
// metres), with kerb stones down both edges.

render_mode diffuse_lambert;

uniform vec3 stone_colour : source_color = vec3(0.5, 0.505, 0.52);
uniform vec3 mortar_colour : source_color = vec3(0.28, 0.28, 0.29);
uniform vec2 stone_size = vec2(0.26, 0.2);    // one cobble, metres
uniform float size = 21.0;                    // the plane's side, metres (for the kerb)
uniform float kerb = 0.3;                     // width of the kerb border, metres
uniform bool road = false;
uniform float road_width = 2.6;

varying vec2 local;                           // metres from the plane's centre

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// signed distance to a rounded box of half-size b and corner radius r
float rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void vertex() {
	local = road ? vec2((UV.x - 0.5) * road_width, UV.y) : VERTEX.xz;
}

void fragment() {
	vec2 p = local;
	float edge = road ? road_width * 0.5 - abs(p.x) : size * 0.5 - max(abs(p.x), abs(p.y));    // distance in from the outer edge
	vec2 cell_size = stone_size;
	vec2 q;
	vec2 cell;
	if (edge < kerb) {
		// kerb: long stones running along whichever side we're on
		bool along_x = !road && abs(p.y) > abs(p.x);
		vec2 k = along_x ? vec2(p.x, abs(p.y)) : vec2(p.y, abs(p.x));
		float outer = road ? road_width * 0.5 : size * 0.5;
		cell_size = vec2(0.6, kerb);
		q = vec2(k.x / cell_size.x, (outer - k.y) / cell_size.y);
		cell = floor(q) + (along_x ? vec2(17.0, sign(p.y)) : vec2(31.0, sign(p.x)));
	} else {
		q = (road ? p.yx : p) / cell_size;
		q.x += mod(floor(q.y), 2.0) * 0.5;               // every other row shifted half a stone
		cell = floor(q);
	}
	vec2 f = (fract(q) - 0.5) * cell_size;              // metres from the stone's centre
	float d = rbox(f, cell_size * 0.5 - 0.013, 0.04);   // < 0 inside the stone
	float h = hash(cell);
	float h2 = hash(cell + 7.3);
	vec3 col = stone_colour * (0.84 + 0.24 * h) + vec3(0.02, 0.015, 0.0) * (h2 - 0.5);
	if (edge < kerb) {
		col *= 0.88;
	}
	float mortar = smoothstep(-0.006, 0.006, d);
	ALBEDO = mix(col, mortar_colour, mortar);
	ROUGHNESS = mix(0.85, 1.0, mortar);
	// each stone is slightly domed: tilt the normal toward its edges
	vec2 tilt = f / (cell_size * 0.5) * 0.35 * (1.0 - mortar);
	NORMAL_MAP = normalize(vec3(tilt.x * 0.5 + 0.5, -tilt.y * 0.5 + 0.5, 1.0));
	NORMAL_MAP_DEPTH = 1.0;
}
