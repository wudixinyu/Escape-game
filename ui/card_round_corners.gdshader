shader_type canvas_item;

// 把卡面素材裁成圆角，这样替换素材时不用自己抠透明角。
// half_size 由 CardView 在 _ready 里按卡的像素尺寸填进去。
uniform vec2 half_size = vec2(64.0, 92.0);
uniform float radius = 10.0;

void fragment() {
	vec2 p = abs(UV * half_size * 2.0 - half_size) - (half_size - vec2(radius));
	float d = length(max(p, vec2(0.0))) - radius;
	if (d > 0.0) {
		discard;
	}
	COLOR = texture(TEXTURE, UV);
}
