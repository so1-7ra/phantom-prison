// PS1 風の壁・床用シェーダー。
// 頂点を画面の粗いグリッドに吸着させて「ガタつく」ポリゴンを再現し、
// テクスチャはぼかさず（nearest）ワールド座標で貼る（壁の長さが違っても模様が伸びない）。
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
// 1 m あたりのテクスチャの繰り返し数
uniform float texture_scale = 0.5;
// 頂点を吸着させる画面グリッドの細かさ（小さいほどガタつく）
uniform float snap_resolution = 120.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = snap_resolution * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv = n.x > n.y && n.x > n.z ? world_pos.zy : (n.y > n.z ? world_pos.xz : world_pos.xy);
	ALBEDO = albedo.rgb * texture(albedo_texture, uv * texture_scale).rgb;
	ROUGHNESS = 1.0;
}
