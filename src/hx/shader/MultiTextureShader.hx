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
// TODO: Currently this feature needs macro for optimization
class MultiTextureShader extends GraphicsShader {
	/**
	 * 多纹理支持的纹理单元数量
	 */
	public static var supportedMultiTextureUnits:Int = 1;

	@:noCompletion private static var __pool:ObjectPool<MultiTextureShader>;

	public static var vertexSource:String = "attribute float openfl_Alpha_multi;
		attribute vec4 openfl_ColorMultiplier_muti;
		attribute vec4 openfl_ColorOffset_muti;
		attribute vec4 openfl_Position;
		attribute vec2 openfl_TextureCoord;
		attribute float openfl_TextureId;
		attribute float openfl_HasColorTransform_muti;
		attribute float openfl_blendMode_add;

		varying float openfl_Alphav;
		varying vec4 openfl_ColorMultiplierv;
		varying vec4 openfl_ColorOffsetv;
		varying vec2 openfl_TextureCoordv;
		varying float openfl_TextureIdv;
		varying float openfl_HasColorTransform_mutiv;
		varying float openfl_blendMode_addv;
		
		uniform mat4 openfl_Matrix;
		uniform vec2 openfl_TextureSize;
		uniform float time;

		void main(void) {

			openfl_Alphav = openfl_Alpha_multi;
            openfl_TextureCoordv = openfl_TextureCoord;
            openfl_TextureIdv = openfl_TextureId;
			openfl_HasColorTransform_mutiv = openfl_HasColorTransform_muti;
			openfl_blendMode_addv = openfl_blendMode_add;

			if (openfl_HasColorTransform_muti > 0.5) {

				openfl_ColorMultiplierv = openfl_ColorMultiplier_muti;
				openfl_ColorOffsetv = openfl_ColorOffset_muti / 255.0;

			}

            gl_Position = openfl_Matrix * openfl_Position;

		}";
	#if emscripten
	public static var fragmentSource:String = "#pragma header

		void main(void) {

			#pragma body

			gl_FragColor = gl_FragColor.bgra;

		}";
	#else
	public static var fragmentSource:String = "varying float openfl_Alphav;
		varying vec4 openfl_ColorMultiplierv;
		varying vec4 openfl_ColorOffsetv;
		varying vec2 openfl_TextureCoordv;
		varying float openfl_HasColorTransform_mutiv;
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
			//vec4 color = texture2D (openfl_Texture, openfl_TextureCoordv);
			float vTextureId = openfl_TextureIdv;
			color = texture2D(SAMPLER_INJECT, openfl_TextureCoordv);

			if (color.a == 0.0) {

				gl_FragColor = vec4 (0.0, 0.0, 0.0, 0.0);

			} else if (openfl_HasColorTransform_mutiv > 0.5) {

				color = vec4 (color.rgb / color.a, color.a);

				mat4 colorMultiplier = mat4 (0);
				colorMultiplier[0][0] = openfl_ColorMultiplierv.x;
				colorMultiplier[1][1] = openfl_ColorMultiplierv.y;
				colorMultiplier[2][2] = openfl_ColorMultiplierv.z;
				colorMultiplier[3][3] = 1.0; // openfl_ColorMultiplierv.w;

				color = clamp (openfl_ColorOffsetv + (color * colorMultiplier), 0.0, 1.0);

				::CUSTOM_FRAGMENT_SHADER::

				if (color.a > 0.0) {

					gl_FragColor = vec4 (color.rgb * color.a * openfl_Alphav, color.a * openfl_Alphav);

				} else {

					gl_FragColor = vec4 (0.0, 0.0, 0.0, 0.0);

				}

			} else {

				::CUSTOM_FRAGMENT_SHADER::

				gl_FragColor = color * openfl_Alphav;

			}

			if(openfl_blendMode_addv > 0.5){
				gl_FragColor.a = 0.;
			}

		}";
	#end

	@:glVertexHeader("attribute float openfl_Alpha_multi;
		attribute vec4 openfl_ColorMultiplier_muti;
		attribute vec4 openfl_ColorOffset_muti;
		attribute bool openfl_HasColorTransform_muti;
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
	public function new(customVertexSource:String = null, customFragmentSource:String = null) {
		var maxCombinedTextureImageUnits:Int = GL.getParameter(GL.MAX_COMBINED_TEXTURE_IMAGE_UNITS);
		var maxTextureImageUnits:Int = GL.getParameter(GL.MAX_TEXTURE_IMAGE_UNITS);
		supportedMultiTextureUnits = Math.floor(Math.min(maxCombinedTextureImageUnits, maxTextureImageUnits));
		supportedMultiTextureUnits = Std.int(Math.min(16, supportedMultiTextureUnits));
		__glVertexSource = vertexSource;

		__glFragmentSource = fragmentSource;
		var uSamplerVariableBuffer:String = "";
		for (i in 0...supportedMultiTextureUnits) {
			uSamplerVariableBuffer += 'uniform sampler2D uSampler${i};\n';
		}
		__glFragmentSource = __glFragmentSource.replace("uniform sampler2D SAMPLER_INJECT;", uSamplerVariableBuffer);

		var uSamplerBodyBuffer:String = "";
		for (i in 0...supportedMultiTextureUnits) {
			if (i == 0) {
				uSamplerBodyBuffer += 'if (vTextureId < ${i}.5) {
                    color = texture2D(uSampler${i}, openfl_TextureCoordv);
                }';
			} else if (i == supportedMultiTextureUnits - 1) {
				uSamplerBodyBuffer += 'else {
                    color = texture2D(uSampler${i}, openfl_TextureCoordv);
                }';
			} else {
				uSamplerBodyBuffer += 'else if (vTextureId < ${i}.5) {
                    color = texture2D(uSampler${i}, openfl_TextureCoordv);
                }';
			}
		}
		__glFragmentSource = __glFragmentSource.replace("color = texture2D(SAMPLER_INJECT, openfl_TextureCoordv);", uSamplerBodyBuffer);
		__glFragmentSource = __glFragmentSource.replace("color = texture2D(SAMPLER_INJECT, uv);", uSamplerBodyBuffer.replace("openfl_TextureCoordv", "uv"));
		__glFragmentSource = __glFragmentSource.replace("::CUSTOM_FRAGMENT_SHADER::", customFragmentSource != null ? customFragmentSource : "");
		trace("shader:", __glFragmentSource);

		super(null);
		this.__initGL();
		this.time.value = [0];
	}

	public function update(time:Float):Void {
		this.time.value[0] += time;
	}
}
