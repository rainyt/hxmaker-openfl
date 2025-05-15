package hx.shader;

/**
 * 灰度滤镜
 */
class GeryShader extends MultiTextureShader {
	public function new() {
        super(null, "
        float mColor = 0.;
        mColor = color.r + color.g + color.b;
        mColor = mColor / 3.;
        color.rgb = vec3(mColor);
        ");
    }
}
