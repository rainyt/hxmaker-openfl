package hx.shader;

/**
 * 反色着色器
 */
class InvertShader extends MultiTextureShader {
	public function new() {
		super(null, "
        color.rgb = vec3(1.) - color.rgb;
        ");
	}
}
