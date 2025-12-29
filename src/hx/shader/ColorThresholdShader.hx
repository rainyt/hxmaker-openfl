package hx.shader;

import VectorMath.vec3;
import VectorMath.dot;
import VectorMath.vec4;
import openfl.display.ShaderParameter;

/**
 * 颜色阈值着色器，会提取指定阈值范围内的颜色进行显示，其他颜色将被忽略。
 */
class ColorThresholdShader extends MultiTextureShader {
	@:glFragmentHeader("
	uniform float threshold;
	")
	public function new(threshold:Float) {
		super(new GLSLSource(ColorThresholdShaderGLSL.vertexSource, ColorThresholdShaderGLSL.fragmentSource));
		updateThreshold(threshold);
	}

	public function updateThreshold(threshold:Float):Void {
		var param:ShaderParameter<Float> = this.data.threshold;
		param.value = [threshold];
	}
}

/**
 * 颜色阈值着色器GLSL实现
 */
class ColorThresholdShaderGLSL extends GLSL {
	/**
	 * 颜色阈值下限
	 */
	@:uniform public var threshold:Float;

	override function fragment() {
		super.fragment();
		var brightness:Float = dot(gl_FragColor.rgb, vec3(0.2126, 0.7152, 0.0722));
		if (brightness <= threshold) {
			gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
		}
	}

	override public function vertex():Void {
		super.vertex();
	}
}
