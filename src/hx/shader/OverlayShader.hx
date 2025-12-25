package hx.shader;

import glsl.GLSL.texture2D;
import VectorMath.mix;

/**
 * 叠加滤镜GLSL
 */
@:build(hx.macro.InstanceMacro.build())
class OverlayShader extends MultiTextureShader {
	public function new() {
		super(new GLSLSource(OverlayShaderGLSL.vertexSource, OverlayShaderGLSL.fragmentSource));
	}
}

class OverlayShaderGLSL extends GLSL {
	override function fragment() {
		super.fragment();
		var color2:Vec4 = texture2D(uSampler1, gl_openfl_TextureCoordv);
		if (color2.a > 0) {
			var color3:Vec4 = color;
			if (color.r > 0.5) {
				color3.r = 1. - 2.0 * (1. - color3.r) * (1. - color2.r);
			} else {
				color3.r = 2. * color3.r * color2.r;
			}
			if (color.g > 0.5) {
				color3.g = 1. - 2.0 * (1. - color3.g) * (1. - color2.g);
			} else {
				color3.g = 2. * color3.g * color2.g;
			}
			if (color.b > 0.5) {
				color3.b = 1. - 2.0 * (1. - color3.b) * (1. - color2.b);
			} else {
				color3.b = 2. * color3.b * color2.b;
			}
			gl_FragColor = mix(color, color3, color2.a);
		}
	}

	override function vertex() {
		super.vertex();
	}
}
