#version 450

uniform sampler2D tex;
uniform sampler2D texdilate;
uniform float dilate_radius;

in vec2 tex_coord;
out vec4 frag_color;

#ifdef ESSL
const vec2 offsets[8] = vec2[](
	vec2(-1.0,  0.0), vec2( 1.0,  0.0), vec2( 0.0,  1.0), vec2( 0.0, -1.0),
	vec2(-1.0,  1.0), vec2( 1.0,  1.0), vec2( 1.0, -1.0), vec2(-1.0, -1.0)
);
#else
const vec2 offsets[8] = {
	vec2(-1.0,  0.0), vec2( 1.0,  0.0), vec2( 0.0,  1.0), vec2( 0.0, -1.0),
	vec2(-1.0,  1.0), vec2( 1.0,  1.0), vec2( 1.0, -1.0), vec2(-1.0, -1.0)
};
#endif

void main() {
	// Based on https://shaderbits.com/blog/uv-dilation by Ryan Brucks
	vec2 size = vec2(textureSize(tex, 0).xy);
	vec2 texel_size = vec2(1.0, 1.0) / size;
	float min_dist = 10000000.0;
	ivec2 coord = ivec2(tex_coord * size);
	float mask = texelFetch(texdilate, coord, 0).r;
	if (mask > 0.0) discard;

	frag_color = texelFetch(tex, coord, 0);
	int i = 0;
	while (i < int(dilate_radius)) {
		i++;
		int j = 0;
		while (j < 8) {
			vec2 cur_uv = tex_coord + offsets[j] * texel_size * vec2(i, i);
			coord = ivec2(cur_uv * size);
			float offset_mask = texelFetch(texdilate, coord, 0).r;
			vec4 offset_col = texelFetch(tex, coord, 0);

			if (offset_mask != 0.0) {
				float cur_dist = length(tex_coord - cur_uv);
				if (cur_dist < min_dist) {
					vec2 project_uv = cur_uv + offsets[j] * texel_size * vec2(i, i) * vec2(0.25, 0.25);
					vec4 direction = textureLod(tex, project_uv, 0.0);
					min_dist = cur_dist;
					if (direction.x != 0.0 || direction.y != 0.0 || direction.z != 0.0) {
						vec4 delta = offset_col - direction;
						frag_color = offset_col + delta * vec4(4.0, 4.0, 4.0, 4.0);
					}
					else {
						frag_color = offset_col;
					}
				}
			}
			j++;
		}
	}
}
