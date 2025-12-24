package hx.shader;

import VectorMath.vec4;
import glsl.GLSL.texture2D;

/**
 * 乘法混合滤镜
 */
@:build(hx.macro.InstanceMacro.build())
class MultiplyShader extends MultiTextureShader {
	public function new() {
		super(new GLSLSource(MultiplyShaderGLSL.vertexSource, MultiplyShaderGLSL.fragmentSource));
	}
}

class MultiplyShaderGLSL extends GLSL {
	override function fragment() {
		super.fragment();
		var mulColor:Vec4 = texture2D(uSampler1, gl_openfl_TextureCoordv);
		if (mulColor.a > 0)
			gl_FragColor = vec4(mulColor.r * color.r, mulColor.g * color.g, mulColor.b * color.b, color.a);
	}

	override function vertex() {
		super.vertex();
	}
}
