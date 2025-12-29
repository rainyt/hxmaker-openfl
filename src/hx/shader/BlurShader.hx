package hx.shader;

import openfl.display.ShaderParameter;
import VectorMath.vec2;
import VectorMath.vec4;

/**
 * 模糊着色器
 */
@:build(hx.macro.InstanceMacro.build())
class BlurShader extends MultiTextureShader {
	@:glFragmentHeader("
	uniform vec2 blurRadius;
	varying vec2 vBlurCoords[7];
	")
	@:glVertexHeader("
	varying vec2 vBlurCoords[7];
	")
	public function new(blurX:Float = 10, blurY:Float = 10) {
		super(new GLSLSource(BlurShaderGLSL.vertexSource, BlurShaderGLSL.fragmentSource));
		this.updateBlur(blurX, blurY);
	}

	public function updateBlur(blurX:Float, blurY:Float):Void {
		var blurRadius:ShaderParameter<Float> = this.data.blurRadius;
		blurRadius.value = [blurX, blurY];
	}
}

class BlurShaderGLSL extends GLSL {
	@:uniform var blurRadius:Vec2;

	@:arrayLen(7) @:varying var vBlurCoords:Array<Vec2>;

	@:precision("highp float")
	override function fragment() {
		super.fragment();
		var sum:Vec4 = vec4(0.0);
		sum += readColor(vBlurCoords[0]) * 0.00443;
		sum += readColor(vBlurCoords[1]) * 0.05399;
		sum += readColor(vBlurCoords[2]) * 0.24197;
		sum += readColor(vBlurCoords[3]) * 0.39894;
		sum += readColor(vBlurCoords[4]) * 0.24197;
		sum += readColor(vBlurCoords[5]) * 0.05399;
		sum += readColor(vBlurCoords[6]) * 0.00443;
		gl_FragColor = sum;
	}

	override public function vertex():Void {
		super.vertex();
		var r:Vec2 = blurRadius / openfl_TextureSize;
		vBlurCoords[0] = openfl_TextureCoord - r;
		vBlurCoords[1] = openfl_TextureCoord - r * 0.75;
		vBlurCoords[2] = openfl_TextureCoord - r * 0.5;
		vBlurCoords[3] = openfl_TextureCoord;
		vBlurCoords[4] = openfl_TextureCoord + r * 0.5;
		vBlurCoords[5] = openfl_TextureCoord + r * 0.75;
		vBlurCoords[6] = openfl_TextureCoord + r;
	}
}
