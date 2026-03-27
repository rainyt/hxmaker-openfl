package hx.shader;

/**
 * 多纹理着色器
 */
@:build(hx.macro.InstanceMacro.build())
class NativeMultiTextureShader extends NativeShader {
	public function new() {
		var instance = MultiTextureShader.getInstance();
		super(instance.glVertexSource, instance.glFragmentSource);
	}
}
