package hx.core;

import hx.shader.NativeMultiTextureShader;
import lime.graphics.opengl.GLProgram;
import lime.utils.UInt16Array;
import openfl.display3D.IndexBuffer3D;
import openfl.display3D.VertexBuffer3D;
import hx.render.ImageBufferData;
import openfl.display.OpenGLRenderer;
import openfl.Lib;
import openfl.events.RenderEvent;
import openfl.display.Sprite;
import openfl.utils._internal.Float32Array;

class EngineSprite extends Sprite {
	public var isPool = true;

	/**
	 * 是否使用原生多纹理着色器
	 */
	public var useNativeMultiTextureShader = true;

	/**
	 * 图像数据
	 */
	public var data:ImageBufferData;

	public function new() {
		super();
		this.addEventListener(RenderEvent.RENDER_OPENGL, onRenderOpenGL);
	}

	private var vertexBuffer:VertexBuffer3D;

	private var indexBuffer:IndexBuffer3D;

	private function onRenderOpenGL(event:RenderEvent) {
		if (useNativeMultiTextureShader && data != null && data.vertices != null && data.vertices.length > 0 && data.indices != null && data.indices.length > 0) {
			// 渲染OpenGL
			var renderer:OpenGLRenderer = cast event.renderer;
			var context = Lib.application.window.stage.context3D;
			renderer.setShader(null);
			var gl = renderer.gl;

			@:privateAccess NativeMultiTextureShader.getInstance().__initGLSLShader(renderer);
			var shaderProgram:GLProgram = @:privateAccess NativeMultiTextureShader.getInstance().__shaderProgram;

			if (vertexBuffer != null) {
				vertexBuffer.dispose();
			}
			if (indexBuffer != null) {
				indexBuffer.dispose();
			}

			var vertexCount = Std.int(data.vertices.length / 2);
			var perVertexDataSize = data.perBufferCounts;
			vertexBuffer = context.createVertexBuffer(vertexCount, perVertexDataSize);
			indexBuffer = context.createIndexBuffer(data.indices.length);
			indexBuffer.uploadFromTypedArray(new UInt16Array(data.indices));
			vertexBuffer.uploadFromTypedArray(@:privateAccess data.__buffer);

			gl.useProgram(shaderProgram);

			var openfl_Alpha_multi = gl.getAttribLocation(shaderProgram, "openfl_Alpha_multi");
			context.setVertexBufferAt(openfl_Alpha_multi, vertexBuffer, 0, FLOAT_1);
			var openfl_ColorMultiplier_muti = gl.getAttribLocation(shaderProgram, "openfl_ColorMultiplier_muti");
			context.setVertexBufferAt(openfl_ColorMultiplier_muti, vertexBuffer, 1, FLOAT_4);
			var openfl_ColorOffset_muti = gl.getAttribLocation(shaderProgram, "openfl_ColorOffset_muti");
			context.setVertexBufferAt(openfl_ColorOffset_muti, vertexBuffer, 5, FLOAT_4);
			var openfl_Position = gl.getAttribLocation(shaderProgram, "openfl_Position");
			context.setVertexBufferAt(openfl_Position, vertexBuffer, 9, FLOAT_4);
			var openfl_TextureCoord = gl.getAttribLocation(shaderProgram, "openfl_TextureCoord");
			context.setVertexBufferAt(openfl_TextureCoord, vertexBuffer, 13, FLOAT_2);
			var openfl_TextureId = gl.getAttribLocation(shaderProgram, "openfl_TextureId");
			context.setVertexBufferAt(openfl_TextureId, vertexBuffer, 15, FLOAT_1);
			var openfl_HasColorTransform_muti = gl.getAttribLocation(shaderProgram, "openfl_HasColorTransform_muti");
			context.setVertexBufferAt(openfl_HasColorTransform_muti, vertexBuffer, 16, FLOAT_1);
			var openfl_blendMode_add = gl.getAttribLocation(shaderProgram, "openfl_blendMode_add");
			context.setVertexBufferAt(openfl_blendMode_add, vertexBuffer, 17, FLOAT_1);

			var openfl_Matrix = gl.getUniformLocation(shaderProgram, "openfl_Matrix");
			// context.setUniformMatrix4fv(openfl_Matrix, false, data.matrix);
			var matrix = new Float32Array([
				1, 0, 0, 0,
				0, 1, 0, 0,
				0, 0, 1, 0,
				0, 0, 0, 1
			]);
			gl.uniformMatrix4fv(openfl_Matrix, false, matrix);
			var openfl_TextureSize = gl.getUniformLocation(shaderProgram, "openfl_TextureSize");
			gl.uniform2fv(openfl_TextureSize, new Float32Array([1024, 1024]));
			var time = gl.getUniformLocation(shaderProgram, "time");
			gl.uniform1f(time, Lib.getTimer());

			for (index => bitmapData in data.bitmapDatas) {
				context.setTextureAt(index, bitmapData.getTexture(context));
			}

			context.drawTriangles(indexBuffer);
		}
	}

	public function drawImageBufferData(data:ImageBufferData) {
		// 这里会进行updateBuffer
		this.data = data;
		this.data.buildBuffer();
	}
}
