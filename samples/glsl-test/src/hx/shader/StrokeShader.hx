package hx.shader;

import VectorMath.vec4;

class StrokeShader extends GLSL {
	override public function fragment():Void {
		super.fragment();
		this.color = vec4(1, 1, 1, 1);
		this.gl_FragColor = this.color;
	}

	override public function vertex():Void {
		super.vertex();
	}
}
