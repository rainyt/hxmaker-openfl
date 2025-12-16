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
		updateMixColor(scolor, ecolor);
	}

	public function updateParam(size:Float, color:UInt):Void {
		var param:ShaderParameter<Float> = this.data.storksize;
		param.value = [size > 0 ? size + 1 : size];
		var scolor = ColorUtils.toShaderColor(color);
		var param:ShaderParameter<Float> = this.data.storkcolor;
		param.value = [scolor.r, scolor.g, scolor.b, 1];
		var param:ShaderParameter<Bool> = this.data.availableColor;
		param.value = [false];
	}

	public function updateMixColor(start:Float, end:Float):Void {
		var scolor = ColorUtils.toShaderColor(start);
		var ecolor = ColorUtils.toShaderColor(end);
		var param:ShaderParameter<Float> = this.data.startcolor;
		param.value = [scolor.r, scolor.g, scolor.b, 1];
		var param:ShaderParameter<Float> = this.data.endcolor;
		param.value = [ecolor.r, ecolor.g, ecolor.b, 1];
		var param:ShaderParameter<Bool> = this.data.availableColor;
		param.value = [start != end];
	}
}

class StrokeShaderGLSL extends GLSL {
	/**
	 * 描边的大小
	 */
	@:uniform public var storksize:Float;

	/**
	 * 描边的颜色
	 */
	@:uniform public var storkcolor:Vec4;

	/**
	 * 字体开始的颜色（顶部）
	 */
	@:uniform public var startcolor:Vec4;

	/**
	 * 字体结束的颜色（底部）
	 */
	@:uniform public var endcolor:Vec4;

	/**
	 * 是否启动颜色
	 */
	@:uniform public var availableColor:Bool;

	/**
	 * 检测当前这个点的偏移位置是否包含透明度
	 * @param v2 
	 * @param offestX 
	 * @param offestY 
	 * @return Bool
	 */
	@:fragmentglsl public function getAlpha(v2:Vec2, offestX:Float, offestY:Float):Float {
		return readColor(v2 + vec2(offestX, offestY)).a;
	}

	/**
	 * 每个点都做一次圆检测
	 * @param v2 
	 * @return Bool
	 */
	@:fragmentglsl public function circleCheck(v2:Vec2, len:Float):Float {
		var setpX:Float = 1. / (2048. * 2.) * len;
		var setpY:Float = 1. / (2048. * 2.) * len;
		var checkTimes = 36.;
		var setp:Float = 6.28 / checkTimes;
		var allAlpha:Float = 0.;
		for (i in 0...36) {
			var r:Float = setp * float(i);
			var alpha:Float = getAlpha(v2, setpX * sin(r), setpY * cos(r));
			allAlpha += alpha;
		}
		return clamp(allAlpha / (checkTimes * 0.5) * 4., 0., 1.);
	}

	@:precision("highp float")
	override function fragment() {
		super.fragment();
		// 渐变色支持
		if (availableColor) {
			color = mix(startcolor, endcolor, gl_openfl_TextureCoordv.y) * color.a;
		}
		for (i in 0...12) {
			if (float(i) > (storksize * 2.))
				break;
			var alpha:Float = circleCheck(gl_openfl_TextureCoordv, float(i));
			if (alpha > 0.) {
				gl_FragColor = storkcolor * alpha;
				if (color.a > 0.) {
					gl_FragColor = vec4(color.rgb, 1);
				}
			}
		}
		gl_FragColor *= gl_openfl_Alphav;
	}

	@:precision("highp float")
	override public function vertex():Void {
		super.vertex();
	}
}
