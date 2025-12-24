package hx.shader;

import VectorMath;
import glsl.GLSL.texture2D;

/**
 * 变亮滤镜
 */
@:build(hx.macro.InstanceMacro.build())
class LightenShader extends MultiTextureShader {
	public function new() {
		super(new GLSLSource(LightenShaderGLSL.vertexSource, LightenShaderGLSL.fragmentSource));
	}
}

class LightenShaderGLSL extends GLSL {
	override function fragment() {
		super.fragment();
		var color2:Vec4 = texture2D(uSampler1, gl_openfl_TextureCoordv);
		if (color2.a > 0)
			gl_FragColor = vec4(max(color.r, color2.r), max(color.g, color2.g), max(color.b, color2.b), color.a);
	}

	override function vertex() {
		super.vertex();
	}
}
