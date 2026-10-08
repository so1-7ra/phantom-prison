// 低解像度で描いた 3D 画面を拡大するときにかける仕上げ。
// 色数を減らしてディザ（網目状のざらつき）を足し、画面の端を暗くする。
shader_type canvas_item;

// 1 色あたりの階調数（PS1 は 32 階調）
uniform float color_depth = 32.0;
uniform float dither_strength = 1.0;
// 低解像度の 1 ピクセルが画面上で何ピクセルになるか
uniform float pixel_size = 3.0;
uniform float vignette = 0.55;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	ivec2 cell = ivec2(floor(FRAGCOORD.xy / pixel_size)) % 4;
	float threshold = BAYER[cell.y * 4 + cell.x] / 16.0 - 0.5;
	col.rgb = floor(col.rgb * color_depth + threshold * dither_strength + 0.5) / color_depth;
	col.rgb *= 1.0 - smoothstep(0.35, 0.85, length(UV - 0.5)) * vignette;
	COLOR = col;
}
