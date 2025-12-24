package hx.shader;

import glsl.GLSL.texture2D;
import VectorMath;

/**
 * 翻转颜色混合滤镜，对应`BlendMode.INVERT`
 */
class InvertBlendShader extends MultiTextureShader {
	public function new() {
		super(new GLSLSource(InvertBlendShaderGLSL.vertexSource, InvertBlendShaderGLSL.fragmentSource));
	}
}

class InvertBlendShaderGLSL extends GLSL {
	override function fragment() {
		super.fragment();
		var color2:Vec4 = texture2D(uSampler1, gl_openfl_TextureCoordv);
		if (color2.a > 0) {
			gl_FragColor = vec4(1.) - abs(color - color2);
		}
	}

	override function vertex() {
		super.vertex();
	}
}
