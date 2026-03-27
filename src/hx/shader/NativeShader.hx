package hx.shader;

import lime.graphics.opengl.GLProgram;
import openfl.Lib;
import lime.graphics.WebGLRenderContext;
import openfl.display.OpenGLRenderer;

/**
 * 原生着色器支持
 */
class NativeShader {
	private var __renderer:OpenGLRenderer;

	private var __shaderProgram:GLProgram;

	private var __vertexSource:String;

	public var __fragmentSource:String;

	public function new(vertexSource:String = null, fragmentSource:String = null) {
		__vertexSource = vertexSource;
		__fragmentSource = fragmentSource;
	}

	/**
	 * 初始化GLSL着色器
	 */
	private function __initGLSLShader(renderer:OpenGLRenderer):Void {
		if (__shaderProgram != null)
			return;
		var __gl = renderer.gl;
		// 编译顶点着色器
		var vertexShader = __gl.createShader(__gl.VERTEX_SHADER);
		__gl.shaderSource(vertexShader, __vertexSource);
		__gl.compileShader(vertexShader);
		if (__gl.getShaderParameter(vertexShader, __gl.COMPILE_STATUS) == 0) {
			var message = "Error compiling vertex shader";
			message += "\n" + __gl.getShaderInfoLog(vertexShader);
			message += "\n" + __vertexSource;
			throw message;
		}
		// 编译片段着色器
		var fragmentShader = __gl.createShader(__gl.FRAGMENT_SHADER);
		__gl.shaderSource(fragmentShader, __fragmentSource);
		__gl.compileShader(fragmentShader);
		if (__gl.getShaderParameter(fragmentShader, __gl.COMPILE_STATUS) == 0) {
			var message = "Error compiling fragment shader";
			message += "\n" + __gl.getShaderInfoLog(fragmentShader);
			message += "\n" + __fragmentSource;
			throw message;
		}
		// 链接程序
		__shaderProgram = __gl.createProgram();
		__gl.attachShader(__shaderProgram, vertexShader);
		__gl.attachShader(__shaderProgram, fragmentShader);
		__gl.linkProgram(__shaderProgram);
		if (__gl.getProgramParameter(__shaderProgram, __gl.LINK_STATUS) == 0) {
			var message = "Error linking program";
			message += "\n" + __gl.getProgramInfoLog(__shaderProgram);
			message += "\n" + __vertexSource + "\n" + __fragmentSource;
			throw message;
		}
		trace("compile shader success");
	}
}
