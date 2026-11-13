shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform vec4 floor_color : source_color = vec4(0.65, 0.64, 0.61, 1.0);
uniform vec4 grid_color : source_color = vec4(0.40, 0.42, 0.40, 1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 coordinate = world_position.xz;
	vec2 derivative = max(fwidth(coordinate), vec2(0.0001));
	vec2 grid = abs(fract(coordinate - 0.5) - 0.5) / derivative;
	float line = 1.0 - min(min(grid.x, grid.y), 1.0);
	float fade = 1.0 - smoothstep(6.0, 22.0, distance(CAMERA_POSITION_WORLD, world_position));
	ALBEDO = mix(floor_color.rgb, grid_color.rgb, line * fade * 0.5);
	ROUGHNESS = 1.0;
}
