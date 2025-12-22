package hx.shader;

import openfl.display.ShaderParameter;
import VectorMath.vec2;
import VectorMath.vec4;

class KawaseBloomShader extends MultiTextureShader {
	public function new(iterations:Int) {
		super(new GLSLSource(KawaseBloomShaderGLSL.vertexSource, KawaseBloomShaderGLSL.fragmentSource));
		this.updateIterations(iterations);
	}

	public function updateIterations(iterations:Int):Void {
		var param:ShaderParameter<Float> = this.data.iterations;
		param.value = [iterations];
	}
}

class KawaseBloomShaderGLSL extends GLSL {
	@:uniform var iterations:Int; // 迭代次数

	override function fragment() {
		super.fragment();
		// Kawase Bloom implementation goes here
		// color = readColor(gl_openfl_TextureCoordv);
		var color2:Vec4 = vec4(0);
		var uv:Vec2 = 0.5 / this.openfl_TextureSize;
		// var uv:Vec2 = vec2(0.001, 0.001);
		var times:Float = 0.;
		for (i in 0...24) {
			if (i > iterations) {
				break;
			}
			// Sample neighboring pixels and accumulate bloom effect
			// This is a placeholder for the actual bloom logic
			color2 += readColor(gl_openfl_TextureCoordv + uv * vec2(i, i));
			color2 += readColor(gl_openfl_TextureCoordv + uv * vec2(-i, -i));
			color2 += readColor(gl_openfl_TextureCoordv + uv * vec2(i, -i));
			color2 += readColor(gl_openfl_TextureCoordv + uv * vec2(-i, i));
			color2 += readColor(gl_openfl_TextureCoordv + uv * vec2(i, 0));
			color2 += readColor(gl_openfl_TextureCoordv + uv * vec2(-i, 0));
			color2 += readColor(gl_openfl_TextureCoordv + uv * vec2(0, -i));
			color2 += readColor(gl_openfl_TextureCoordv + uv * vec2(0, i));

			times += 8.;
		}
		this.gl_FragColor = color2 / times * 2.;
		// this.gl_FragColor = vec4(1, uv.x, uv.y, 1);
	}

	override public function vertex():Void {
		super.vertex();
	}
}
