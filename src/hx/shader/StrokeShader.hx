package hx.shader;

import hx.utils.ColorUtils;
import openfl.display.ShaderParameter;
import VectorMath.vec4;
import VectorMath;
import glsl.GLSL;

/**
 * 描边着色器
 */
class StrokeShader extends MultiTextureShader {
	public function new(size:Float = 1.5, color:UInt = 0x0, scolor:UInt = 0, ecolor:UInt = 0) {
		super(new GLSLSource(StrokeShaderGLSL.vertexSource, StrokeShaderGLSL.fragmentSource));
		// 初始化渐变色
		updateParam(size, color);
		updateIntensity(2);
	}

	public function updateIntensity(intensity:Float):Void {
		var param:ShaderParameter<Float> = this.data.intensity;
		param.value = [intensity];
	}

	public function updateSize(width:Float, height:Float):Void {
		var param:ShaderParameter<Float> = this.data.textureSize;
		param.value = [width, height];
	}

	public function updateParam(size:Float, color:UInt):Void {
		var param:ShaderParameter<Float> = this.data.storksize;
		param.value = [size];
		var scolor = ColorUtils.toShaderColor(color);
		var param:ShaderParameter<Float> = this.data.storkcolor;
		param.value = [scolor.r, scolor.g, scolor.b, 1];
	}
}

class StrokeShaderGLSL extends GLSL {
	/**
	 * 描边的大小
	 */
	@:uniform public var storksize:Float;

	/**
	 * 纹理的大小
	 */
	@:uniform public var textureSize:Vec2;

	/**
	 * 描边的颜色
	 */
	@:uniform public var storkcolor:Vec4;

	/**
	 * 强度
	 */
	@:uniform public var intensity:Float;

	@:precision("highp float")
	override function fragment() {
		super.fragment();
		var color3:Vec4 = vec4(0.);
		var checkTimes:Float = 0.;

		for (i in 0...12) {
			if (float(i) > (storksize))
				break;
			var setpX:Float = 1. / (textureSize.x) * float(i);
			var setpY:Float = 1. / (textureSize.y) * float(i);
			// for (i in 0...36) {
			// 	var r:Float = setp * float(i);
			// 	var color4:Vec4 = readColor(gl_openfl_TextureCoordv + vec2(setpX * sin(r), setpY * cos(r)));
			// 	if (color4.r + color4.g + color4.b > 0.0) {
			// 		color3 += color4;
			// 	} else {
			// 		color3 += vec4(1.0, 0.0, 0.0, 0.);
			// 	}
			// }
			color3 += readColor(gl_openfl_TextureCoordv + vec2(setpX, setpY) * vec2(1.0, 0.0));
			color3 += readColor(gl_openfl_TextureCoordv + vec2(setpX, setpY) * vec2(0.0, 1.0));
			color3 += readColor(gl_openfl_TextureCoordv + vec2(setpX, setpY) * vec2(-1.0, 0.0));
			color3 += readColor(gl_openfl_TextureCoordv + vec2(setpX, setpY) * vec2(0.0, -1.0));
			color3 += readColor(gl_openfl_TextureCoordv + vec2(setpX, setpY) * vec2(1.0, 1.0));
			color3 += readColor(gl_openfl_TextureCoordv + vec2(setpX, setpY) * vec2(-1.0, -1.0));
			color3 += readColor(gl_openfl_TextureCoordv + vec2(setpX, setpY) * vec2(-1.0, 1.0));
			color3 += readColor(gl_openfl_TextureCoordv + vec2(setpX, setpY) * vec2(1.0, -1.0));
			checkTimes += 8.;
		}

		gl_FragColor = min(1., (color3.a / checkTimes * intensity)) * storkcolor;
		gl_FragColor *= gl_openfl_Alphav;
	}

	@:precision("highp float")
	override public function vertex():Void {
		super.vertex();
	}
}
