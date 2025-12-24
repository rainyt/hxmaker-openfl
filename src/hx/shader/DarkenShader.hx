package hx.shader;

import VectorMath;
import glsl.GLSL.texture2D;

/**
	变暗混合着色器 
	选择显示对象的组成颜色中较深的颜色
	背景的颜色（值较小的颜色）。这
	设置通常用于叠加类型。
	例如，如果显示对象具有RGB值为的像素
	0xFFCC33，背景像素的RGB值为0xDDF800
	显示像素的RGB值为0xDDCC00（因为0xFF>
	0xDD、0xCC＜0xF8和0x33＞0x00＝33）。
	- 变暗滤镜在Hxmaker中得到支持
 */
@:build(hx.macro.InstanceMacro.build())
class DarkenShader extends MultiTextureShader {
	public function new() {
		super(new GLSLSource(DarkenShaderGLSL.vertexSource, DarkenShaderGLSL.fragmentSource));
	}
}

class DarkenShaderGLSL extends GLSL {
	override function fragment() {
		super.fragment();
		var color2:Vec4 = texture2D(uSampler1, gl_openfl_TextureCoordv);
		if (color2.a > 0)
			gl_FragColor = vec4(min(color.r, color2.r), min(color.g, color2.g), min(color.b, color2.b), color.a);
	}

	override function vertex() {
		super.vertex();
	}
}
