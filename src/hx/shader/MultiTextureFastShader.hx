package hx.shader;

import openfl.display.GraphicsShader;
import openfl.utils.ByteArray;
import openfl.utils.ObjectPool;
import lime.graphics.opengl.GL;

using StringTools;

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end

/**
 * 多纹理快速渲染色器，该渲染器不支持颜色变换，主要提高无颜色的渲染效率
 * 由18个步长调整后，会变更为13个步长
 */
@:build(hx.macro.InstanceMacro.build())
class MultiTextureFastShader extends GraphicsShader {
	/**
	 * 多纹理支持的纹理单元数量
	 */
	public static var supportedMultiTextureUnits(get, never):Int;

	private static var __supportedMultiTextureUnits:Int = 1;

	private static function get_supportedMultiTextureUnits():Int {
		return multiTextureEnabled ? __supportedMultiTextureUnits : 1;
	}

	/**
	 * 是否启用多纹理渲染，默认为`true`，设置为`false`后可关闭
	 */
	public static var multiTextureEnabled:Bool = true;

	@:noCompletion private static var __pool:ObjectPool<MultiTextureShader>;

	public static var vertexSource:String = "
		precision highp float;

		attribute float openfl_Alpha_multi;
		attribute vec4 openfl_Position;
		attribute vec2 openfl_TextureCoord;
		attribute float openfl_TextureId;
		attribute float openfl_blendMode_add;

		varying float openfl_Alphav;
		varying vec2 openfl_TextureCoordv;
		varying float openfl_TextureIdv;
		varying float openfl_blendMode_addv;
		
		uniform mat4 openfl_Matrix;
		uniform vec2 openfl_TextureSize;
		uniform float time;

		void main(void) {

			openfl_Alphav = openfl_Alpha_multi;
            openfl_TextureCoordv = openfl_TextureCoord;
            openfl_TextureIdv = openfl_TextureId;
			openfl_blendMode_addv = openfl_blendMode_add;

            gl_Position = openfl_Matrix * openfl_Position;

		}";
	#if emscripten
	public static var fragmentSource:String = "#pragma header

		void main(void) {

			#pragma body

			gl_FragColor = gl_FragColor.bgra;

		}";
	#else
	public static var fragmentSource:String = "
		precision highp float; 
		
		varying float openfl_Alphav;
		varying vec2 openfl_TextureCoordv;
		varying float openfl_TextureIdv;
		varying float openfl_blendMode_addv;
		uniform float time;

		uniform sampler2D SAMPLER_INJECT;

		uniform vec2 openfl_TextureSize;

		vec4 readColor(vec2 uv) {
			float vTextureId = openfl_TextureIdv;
			vec4 color;
			color = texture2D(SAMPLER_INJECT, uv);
			return color;
		}

		void main(void) {

			vec4 color;

			color = readColor(openfl_TextureCoordv);

			::CUSTOM_FRAGMENT_SHADER::

			gl_FragColor = color * openfl_Alphav;

			gl_FragColor.a *= (1. - step(0.5, openfl_blendMode_addv));

		}";
	#end

	@:glVertexHeader("attribute float openfl_Alpha_multi;
		attribute vec4 openfl_Position;
		attribute vec2 openfl_TextureCoord;
		attribute float openfl_TextureId;
		attribute float openfl_blendMode_add;
		uniform mat4 openfl_Matrix;
		uniform vec2 openfl_TextureSize;
		uniform float time;
		uniform sampler2D uSampler0;
		uniform sampler2D uSampler1;
		uniform sampler2D uSampler2;
		uniform sampler2D uSampler3;
		uniform sampler2D uSampler4;
		uniform sampler2D uSampler5;
		uniform sampler2D uSampler6;
		uniform sampler2D uSampler7;
		uniform sampler2D uSampler8;
		uniform sampler2D uSampler9;
		uniform sampler2D uSampler10;
		uniform sampler2D uSampler11;
		uniform sampler2D uSampler12;
		uniform sampler2D uSampler13;
		uniform sampler2D uSampler14;
		uniform sampler2D uSampler15;
		uniform sampler2D uSampler16;")
	public function new(customVertexSource:String = null, customFragmentSource:String = null, customVertexBodySource:String = null,
			customFragmentBodySource:String = null, glsl:GLSLSource = null) {
		var maxCombinedTextureImageUnits:Int = GL.getParameter(GL.MAX_COMBINED_TEXTURE_IMAGE_UNITS);
		var maxTextureImageUnits:Int = GL.getParameter(GL.MAX_TEXTURE_IMAGE_UNITS);
		__supportedMultiTextureUnits = Math.floor(Math.min(maxCombinedTextureImageUnits, maxTextureImageUnits));
		__supportedMultiTextureUnits = Std.int(Math.min(16, __supportedMultiTextureUnits));
		if (glsl != null) {
			__glVertexSource = glsl.vertexSource;
			__glFragmentSource = glsl.fragmentSource;
		} else {
			__glVertexSource = vertexSource;
			__glFragmentSource = fragmentSource;
		}
		var uSamplerVariableBuffer:String = "";
		for (i in 0...__supportedMultiTextureUnits) {
			uSamplerVariableBuffer += 'uniform sampler2D uSampler${i};\n';
		}
		__glFragmentSource = __glFragmentSource.replace("uniform sampler2D SAMPLER_INJECT;", uSamplerVariableBuffer);

		var uSamplerBodyBuffer:String = "";
		if (__supportedMultiTextureUnits >= 16) {
			uSamplerBodyBuffer = texture16Shader;
		} else {
			uSamplerBodyBuffer = texture8Shader;
		}
		__glFragmentSource = __glFragmentSource.replace("color = texture2D(SAMPLER_INJECT, openfl_TextureCoordv);", uSamplerBodyBuffer);
		__glFragmentSource = __glFragmentSource.replace("color = texture2D(SAMPLER_INJECT, uv);", uSamplerBodyBuffer.replace("openfl_TextureCoordv", "uv"));
		__glFragmentSource = __glFragmentSource.replace("::CUSTOM_FRAGMENT_SHADER::", customFragmentSource != null ? customFragmentSource : "");

		// trace(__glVertexSource, "\n\n\n\n", __glFragmentSource);

		super(null);
		this.__initGL();
		this.time.value = [0];
	}

	public function update(time:Float):Void {
		this.time.value[0] += time;
	}

	/**
	 * 16个纹理着色器
	 */
	private static inline var texture16Shader:String = "if (vTextureId < 7.5) {
        if (vTextureId < 3.5) {
            if (vTextureId < 1.5) {
                if (vTextureId < 0.5) color = texture2D(uSampler0, openfl_TextureCoordv);
                else color = texture2D(uSampler1, openfl_TextureCoordv);
            } else {
                if (vTextureId < 2.5) color = texture2D(uSampler2, openfl_TextureCoordv);
                else color = texture2D(uSampler3, openfl_TextureCoordv);
            }
        } else {
            if (vTextureId < 5.5) {
                if (vTextureId < 4.5) color = texture2D(uSampler4, openfl_TextureCoordv);
                else color = texture2D(uSampler5, openfl_TextureCoordv);
            } else {
                if (vTextureId < 6.5) color = texture2D(uSampler6, openfl_TextureCoordv);
                else color = texture2D(uSampler7, openfl_TextureCoordv);
            }
        }
    } else {
        if (vTextureId < 11.5) {
            if (vTextureId < 9.5) {
                if (vTextureId < 8.5) color = texture2D(uSampler8, openfl_TextureCoordv);
                else color = texture2D(uSampler9, openfl_TextureCoordv);
            } else {
                if (vTextureId < 10.5) color = texture2D(uSampler10, openfl_TextureCoordv);
                else color = texture2D(uSampler11, openfl_TextureCoordv);
            }
        } else {
            if (vTextureId < 13.5) {
                if (vTextureId < 12.5) color = texture2D(uSampler12, openfl_TextureCoordv);
                else color = texture2D(uSampler13, openfl_TextureCoordv);
            } else {
                if (vTextureId < 14.5) color = texture2D(uSampler14, openfl_TextureCoordv);
                else color = texture2D(uSampler15, openfl_TextureCoordv);
            }
        }
    }";

	/**
	 * 8个纹理着色器
	 */
	private static inline var texture8Shader:String = "if (vTextureId < 3.5) {
		if (vTextureId < 1.5) {
			if (vTextureId < 0.5) color = texture2D(uSampler0, openfl_TextureCoordv);
			else color = texture2D(uSampler1, openfl_TextureCoordv);
		} else {
			if (vTextureId < 2.5) color = texture2D(uSampler2, openfl_TextureCoordv);
			else color = texture2D(uSampler3, openfl_TextureCoordv);
		}
	} else {
		if (vTextureId < 5.5) {
			if (vTextureId < 4.5) color = texture2D(uSampler4, openfl_TextureCoordv);
			else color = texture2D(uSampler5, openfl_TextureCoordv);
		} else {
			if (vTextureId < 6.5) color = texture2D(uSampler6, openfl_TextureCoordv);
			else color = texture2D(uSampler7, openfl_TextureCoordv);
		}
	}";
}
