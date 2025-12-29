package hx.shader;

import glsl.GLSL.texture2D;
import openfl.display.ShaderParameter;

/**
 * 透明度组滤镜，对应`BlendMode.LAYER`
 */
@:build(hx.macro.InstanceMacro.build())
class LayerShader extends MultiTextureShader {
	@:glFragmentHeader("
	uniform bool applyAlphav;
	uniform bool applyErasev;
	")
	public function new() {
		super(new GLSLSource(LayerShaderGLSL.vertexSource, LayerShaderGLSL.fragmentSource));
	}

	public function applyAlpha(value:Bool) {
		var alpha:ShaderParameter<Bool> = this.data.applyAlphav;
		alpha.value = [value];
	}

	/**
	 * 是否应用擦除
	 */
	public function applyErase(value:Bool) {
		var erase:ShaderParameter<Bool> = this.data.applyErasev;
		erase.value = [value];
	}
}

class LayerShaderGLSL extends GLSL {
	/**
	 * 是否应用透明度
	 */
	@:uniform var applyAlphav:Bool;

	/**
	 * 是否应用擦除
	 */
	@:uniform var applyErasev:Bool;

	override function fragment() {
		super.fragment();
		if (applyErasev) {
			var color3:Vec4 = texture2D(uSampler2, gl_openfl_TextureCoordv);
			color = color * (1 - color3.a);
			gl_FragColor = color;
		}
		if (applyAlphav) {
			var color2:Vec4 = texture2D(uSampler1, gl_openfl_TextureCoordv);
			if (color2.a > 0)
				gl_FragColor = color * color2.a;
		} else {
			gl_FragColor = color * this.gl_openfl_Alphav;
		}
	}

	override function vertex() {
		super.vertex();
	}
}
