package hx.shader;

import VectorMath.vec4;

/**
 * 描边着色器
 */
@:build(hx.macro.InstanceMacro.build())
class StrokeShader extends MultiTextureShader {
	public function new() {
		super(new GLSLSource(StrokeShaderGLSL.vertexSource, StrokeShaderGLSL.fragmentSource));
	}
}

class StrokeShaderGLSL extends GLSL {
	override public function fragment():Void {
		super.fragment();
		this.color = vec4(1, 1, 1, 1);
		this.gl_FragColor = this.color;
	}

	override public function vertex():Void {
		super.vertex();
	}
}
