package hx.shader;

import VectorMath;
import glsl.GLSL.texture2D;

/**
 * 差值混合
 */
class DifferenceShader extends MultiTextureShader {
	public function new() {
		super(new GLSLSource(DifferenceShaderGLSL.vertexSource, DifferenceShaderGLSL.fragmentSource));
	}
}

class DifferenceShaderGLSL extends GLSL {
	override function fragment() {
		super.fragment();
		var diffColor:Vec4 = texture2D(uSampler1, gl_openfl_TextureCoordv);
		gl_FragColor = vec4(abs(color.r - diffColor.r), abs(color.g - diffColor.g), abs(color.b - diffColor.b), color.a);
	}

	override function vertex() {
		super.vertex();
	}
}
