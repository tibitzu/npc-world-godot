shader_type spatial;
// The ground of the whole wrapping map, drawn on one plane that follows the camera.
// Every point is folded back onto the map, so the world repeats seamlessly in all directions.
// Smooth mode blends the tile colours; hex mode (V) draws each tile as a hexagon with a gap round it.

render_mode diffuse_lambert, specular_disabled;

uniform sampler2D tiles : source_color, filter_linear_mipmap, repeat_enable;
uniform bool show_hex = false;
uniform vec3 gap_colour : source_color = vec3(0.231, 0.184, 0.165);   // the dark earth between tiles

const float S = 0.42;
const float SQ3 = 1.7320508075688772;
const float COLS = 1000.0;
const float ROWS = 1000.0;
const float DX = S * SQ3;
const float DZ = S * 1.5;
const float OFF_X = (COLS - 0.5) * DX / 2.0;
const float OFF_Z = (ROWS - 1.0) * DZ / 2.0;
const float WRAP = COLS * DX;
const float WRAP_Z = ROWS * DZ;

// holes in the ground (x0, z0, x1, z1): the goblins' stairwell always, and the ground over their
// whole lair while you're playing someone down there
uniform vec4 hole = vec4(0.0);
uniform vec4 cutaway = vec4(0.0);
uniform bool cut_on = false;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

bool in_rect(vec2 p, vec4 r) {
	vec2 c = (r.xy + r.zw) * 0.5;
	vec2 h = (r.zw - r.xy) * 0.5;
	vec2 d = p - c;
	d -= vec2(WRAP, WRAP_Z) * round(d / vec2(WRAP, WRAP_Z));
	return abs(d.x) < h.x && abs(d.y) < h.y;
}

int wrap_i(int v, int n) {
	return ((v % n) + n) % n;
}

void fragment() {
	// no folding needed: the texture repeats every WRAP m and tile indices wrap below,
	// and working unfolded keeps the seam free of any line
	float x = world_pos.x;
	float z = world_pos.z;
	if (in_rect(world_pos.xz, hole) || (cut_on && in_rect(world_pos.xz, cutaway))) {
		discard;
	}
	vec3 col;
	if (!show_hex) {
		vec2 uv = vec2(((x + OFF_X) / DX + 0.25) / COLS, ((z + OFF_Z) / DZ + 0.5) / ROWS);
		col = texture(tiles, uv).rgb;
	} else {
		// nearest tile centre: the same 3 x 3 search as Hex.tile_at
		int r0 = int(round((z + OFF_Z) / DZ));
		float best = 1e9;
		vec2 rel = vec2(0.0);
		ivec2 cell = ivec2(0);
		for (int dr = -1; dr <= 1; dr++) {
			int r = r0 + dr;
			float odd = float(wrap_i(r, 2));
			int c0 = int(round((x + OFF_X) / DX - odd * 0.5));
			for (int dc = -1; dc <= 1; dc++) {
				int c = c0 + dc;
				vec2 p = vec2(x - (DX * (float(c) + odd * 0.5) - OFF_X), z - (DZ * float(r) - OFF_Z));
				float d = dot(p, p);
				if (d < best) {
					best = d;
					rel = p;
					cell = ivec2(wrap_i(c, int(COLS)), wrap_i(r, int(ROWS)));
				}
			}
		}
		vec2 a = abs(rel);
		float d = max(a.x, a.x * 0.5 + a.y * SQ3 * 0.5);     // hexagon distance, pointy-top
		float inner = 0.94 * S * SQ3 * 0.5;
		float fw = fwidth(d);
		col = texelFetch(tiles, cell, 0).rgb;
		col *= mix(1.0, 0.86, smoothstep(inner * 0.78, inner, d));   // a slight bevel at the tile edge
		col = mix(col, gap_colour, smoothstep(inner - fw, inner + fw, d));
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
}
