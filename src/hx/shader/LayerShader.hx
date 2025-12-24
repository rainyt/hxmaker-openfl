package hx.shader;

/**
 * 透明度组滤镜，对应`BlendMode.LAYER`
 */
@:build(hx.macro.InstanceMacro.build())
class LayerShader extends MultiTextureShader {
	public function new() {
		super(new GLSLSource(LayerShaderGLSL.vertexSource, LayerShaderGLSL.fragmentSource));
	}
}

class LayerShaderGLSL extends GLSL {
	override function fragment() {
		super.fragment();
		// var color2:Vec4 = texture2D(uSampler1, gl_openfl_TextureCoordv);
		// if (color2.a > 0)
		// gl_FragColor = vec4(max(color.r, color2.r), max(color.g, color2.g), max(color.b, color2.b), color.a);
	}

	override function vertex() {
		super.vertex();
	}
}
