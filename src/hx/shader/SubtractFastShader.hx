package hx.shader;

import VectorMath;

@:build(hx.macro.InstanceMacro.build())
class SubtractFastShader extends MultiTextureShader {
	public function new() {
		super(new GLSLSource(SubtractFastShaderGLSL.vertexSource, SubtractFastShaderGLSL.fragmentSource));
	}
}

class SubtractFastShaderGLSL extends GLSL {
	override function fragment() {
		super.fragment();
		gl_FragColor = max(vec4(0.5) - color, vec4(0, 0, 0, 1) * (1 - step(color.a, 0))) * (color.r + color.g + color.b) / 3;
	}

	override function vertex() {
		super.vertex();
	}
}
