package hx.shader;

import glsl.Sampler2D;

@:autoBuild(glsl.macro.GLSLCompileMacro.build("glsl"))
class GLSL {
	@:varying public var openfl_Alphav:Float;
	@:varying public var openfl_ColorMultiplierv:Vec4;
	@:varying public var openfl_ColorOffsetv:Vec4;
	@:varying public var openfl_TextureCoordv:Vec2;
	@:varying public var openfl_TextureIdv:Float;
	@:varying public var openfl_HasColorTransform_mutiv:Float;
	@:varying public var openfl_blendMode_addv:Float;
	@:attribute public var openfl_Alpha_multi:Float;
	@:attribute public var openfl_ColorMultiplier_muti:Vec4;
	@:attribute public var openfl_ColorOffset_muti:Vec4;
	@:attribute public var openfl_HasColorTransform_muti:Float;
	@:attribute public var openfl_Position:Vec4;
	@:attribute public var openfl_TextureCoord:Vec2;
	@:attribute public var openfl_TextureId:Float;
	@:attribute public var openfl_blendMode_add:Float;
	@:uniform public var openfl_Matrix:Mat4;
	@:uniform public var openfl_TextureSize:Vec2;
	@:uniform public var time:Float;
	@:uniform public var uSampler0:Sampler2D;
	@:uniform public var uSampler1:Sampler2D;
	@:uniform public var uSampler2:Sampler2D;
	@:uniform public var uSampler3:Sampler2D;
	@:uniform public var uSampler4:Sampler2D;
	@:uniform public var uSampler5:Sampler2D;
	@:uniform public var uSampler6:Sampler2D;
	@:uniform public var uSampler7:Sampler2D;
	@:uniform public var uSampler8:Sampler2D;
	@:uniform public var uSampler9:Sampler2D;
	@:uniform public var uSampler10:Sampler2D;
	@:uniform public var uSampler11:Sampler2D;
	@:uniform public var uSampler12:Sampler2D;
	@:uniform public var uSampler13:Sampler2D;
	@:uniform public var uSampler14:Sampler2D;
	@:uniform public var uSampler15:Sampler2D;
	@:uniform public var uSampler16:Sampler2D;

	/**
	 * 纹理UV
	 */
	public var gl_openfl_TextureCoord:Vec2;

	/** 
	 * 纹理UV
	 */
	public var gl_openfl_TextureCoordv:Vec2;

	/**
	 * 颜色偏移
	 */
	public var gl_openfl_ColorOffsetv:Vec4;

	/**
	 * 颜色相乘
	 */
	public var gl_openfl_ColorMultiplierv:Vec4;

	/**
	 * 是否存在颜色转换
	 */
	public var gl_openfl_HasColorTransform:Bool;

	/**
	 * 纹理尺寸
	 */
	public var gl_openfl_TextureSize:Vec2;

	/**
	 * 当前纹理透明度
	 */
	public var gl_openfl_Alphav:Float;

	/**
	 * 
	 */
	public var gl_openfl_Matrix:Mat4;

	/**
	 * 顶点参数
	 */
	public var gl_openfl_Position:Vec4;

	/**
	 * 最终值输出
	 */
	public var gl_FragColor:Vec4;

	/**
	 * gl_FragCoord，舞台的像素比，单位为px
	 */
	public var gl_FragCoord:Vec4;

	/**
	 * 最终顶点坐标输出
	 */
	public var gl_Position:Vec4;

	/**
	 * 当前着色器获得到的颜色
	 */
	public var color:Vec4;

	public function fragment():Void {}

	public function vertex():Void {}

	public function readColor(uv:Vec2):Vec4 {
		return null;
	}

	public function float(value:Int):Float {
		return value;
	}

	public function int(value:Float):Int {
		return Std.int(value);
	}
}
