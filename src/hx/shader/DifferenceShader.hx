package hx.shader;

import VectorMath;
import glsl.GLSL.texture2D;

/**
 * 差值混合
 */
@:build(hx.macro.InstanceMacro.build())
class DifferenceShader extends MultiTextureShader {
	public function new() {
		super(new GLSLSource(DifferenceShaderGLSL.vertexSource, DifferenceShaderGLSL.fragmentSource));
	}
}

class DifferenceShaderGLSL extends GLSL {
	override function fragment() {
		super.fragment();
		var diffColor:Vec4 = texture2D(uSampler1, gl_openfl_TextureCoordv);
		gl_FragColor = vec4(abs(diffColor.r - color.r), abs(diffColor.g - color.g), abs(diffColor.b - color.b), color.a);
	}

	override function vertex() {
		super.vertex();
	}
}
