package hx.shader;

import openfl.display.ShaderParameter;
import VectorMath.vec2;
import VectorMath.vec4;

/**
 * Kawase 模糊 shader
 */
class KawaseBloomShader extends MultiTextureShader {
	@:glFragmentHeader("
	uniform int iterations;
	")
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
		var color2:Vec4 = color;
		var uv:Vec2 = 0.5 / this.openfl_TextureSize;
		var times:Float = 1.;
		for (i in 1...32) {
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
		color2 /= times * 0.5;
		this.gl_FragColor = color2;
	}

	override public function vertex():Void {
		super.vertex();
	}
}
