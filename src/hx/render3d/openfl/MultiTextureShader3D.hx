package hx.render3d.openfl;

import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLShader;
import hx.material.Material3D;

/** 根据实际槽位数生成采样声明与分支，不依赖固定八纹理程序。 */
class MultiTextureShader3D {
	public static function create(gl:WebGLRenderContext, slots:Int, declarations:String = "", fragmentCode:String = ""):GLProgram {
		var precision = "mediump";
		var format = isDesktop(gl) ? null : gl.getShaderPrecisionFormat(gl.FRAGMENT_SHADER, gl.HIGH_FLOAT);
		if (format != null && format.precision > 0) precision = "highp";
		var vertex = "attribute vec3 aPosition; attribute vec2 aUV; attribute float aTextureId; attribute vec4 aColor;\n"
			+ "uniform mat4 uViewProjection; varying mediump vec2 vUV; varying mediump float vTextureId; varying mediump vec4 vColor;\n"
			+ "void main(){gl_Position=uViewProjection*vec4(aPosition,1.0);vUV=aUV;vTextureId=aTextureId;vColor=aColor;}";
		var fragment = "precision " + precision + " float;\nvarying mediump vec2 vUV; varying mediump float vTextureId; varying mediump vec4 vColor;\n"
			+ "uniform float uAlphaMode; uniform float uAlphaCutoff;\n";
		for (i in 0...slots) fragment += "uniform sampler2D uSampler" + i + ";\n";
		fragment += declarations + "\nvoid main(){vec4 color;\n";
		for (i in 0...slots) {
			fragment += (i == 0 ? "if" : "else if") + "(vTextureId<" + (i + 0.5) + "){color=texture2D(uSampler" + i + ",vUV);}\n";
		}
		fragment += "else{color=vec4(1.0,0.0,1.0,1.0);}\n"
			+ "float sourceAlpha=color.a; if(sourceAlpha>0.0){color.rgb/=sourceAlpha;}else{color.rgb=vec3(0.0);}\n"
			+ "color*=vColor;\n" + fragmentCode + "\n"
			+ "if(uAlphaMode<0.5){color.a=1.0;}else if(uAlphaMode<1.5){if(color.a<uAlphaCutoff)discard;color.a=1.0;}\n"
			+ "gl_FragColor=vec4(color.rgb*color.a,color.a);}";
		return compile(gl, vertex, fragment);
	}
	/** 所有程序固定使用属性位置 0 到 3，便于完整恢复宿主属性状态。 */
	public static function compile(gl:WebGLRenderContext, vertex:String, fragment:String):GLProgram {
		// 桌面兼容 GLSL 不接受 ES 精度声明，集中在程序适配层移除。
		if (isDesktop(gl)) {
			var precisionStatement = ~/precision\s+(lowp|mediump|highp)\s+float\s*;/g;
			var precisionQualifier = ~/\b(lowp|mediump|highp)\b/g;
			vertex = precisionQualifier.replace(precisionStatement.replace(vertex, ""), "");
			fragment = precisionQualifier.replace(precisionStatement.replace(fragment, ""), "");
		}
		var shaders:Array<GLShader> = [], program:GLProgram = null;
		try {
			for (entry in [{type:gl.VERTEX_SHADER, source:vertex}, {type:gl.FRAGMENT_SHADER, source:fragment}]) {
				var shader = gl.createShader(entry.type); shaders.push(shader); gl.shaderSource(shader, entry.source); gl.compileShader(shader);
				var compiled:Dynamic = gl.getShaderParameter(shader, gl.COMPILE_STATUS);
				if (compiled == false || compiled == 0) throw "三维 Shader 编译失败：" + gl.getShaderInfoLog(shader);
			}
			program = gl.createProgram(); for (shader in shaders) gl.attachShader(program, shader);
			gl.bindAttribLocation(program, 0, "aPosition"); gl.bindAttribLocation(program, 1, "aUV");
			gl.bindAttribLocation(program, 2, "aTextureId"); gl.bindAttribLocation(program, 3, "aColor"); gl.linkProgram(program);
			var linked:Dynamic = gl.getProgramParameter(program, gl.LINK_STATUS);
			if (linked == false || linked == 0) throw "三维 Shader 链接失败：" + gl.getProgramInfoLog(program);
		} catch (error:Dynamic) {
			for (shader in shaders) gl.deleteShader(shader);
			if (program != null) gl.deleteProgram(program);
			throw error;
		}
		for (shader in shaders) { gl.detachShader(program, shader); gl.deleteShader(shader); }
		return program;
	}
	private static function isDesktop(gl:WebGLRenderContext):Bool {
		var version = Std.string(gl.getParameter(gl.VERSION));
		return version.indexOf("WebGL") < 0 && version.indexOf("OpenGL ES") < 0;
	}
}
