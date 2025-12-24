package hx.shader;

import VectorMath.step;
import VectorMath.max;
import VectorMath.vec4;
import glsl.GLSL.texture2D;

/**
 * 相减滤镜
 */
class SubtractShader extends MultiTextureShader {
	public function new() {
		super(new GLSLSource(SubtractShaderGLSL.vertexSource, SubtractShaderGLSL.fragmentSource));
	}
}

class SubtractShaderGLSL extends GLSL {
	override function fragment() {
		super.fragment();
		var subColor:Vec4 = texture2D(uSampler1, gl_openfl_TextureCoordv);
		gl_FragColor = max(color - subColor, vec4(0, 0, 0, 1) * (1 - step(color.a, 0)));
	}

	override function vertex() {
		super.vertex();
	}
}
