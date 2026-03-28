package hx.core;

import lime.math.Matrix4;
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

@:access(openfl.display3D.TextureBase)
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
		if (useNativeMultiTextureShader && data != null && data.perBufferSize > 0) {
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

			var vertexCount = data.vertexCount;
			var perVertexDataSize = data.perBufferCounts;
			vertexBuffer = context.createVertexBuffer(vertexCount, perVertexDataSize);
			indexBuffer = context.createIndexBuffer(data.indicesCount);
			indexBuffer.uploadFromTypedArray(data.indicesBuffer);
			vertexBuffer.uploadFromTypedArray(data.vertexBuffer);

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
			var p = new Matrix4();
			@:privateAccess p.createOrtho(0, Lib.current.stage.stageWidth, Lib.current.stage.stageHeight, 0, -10000, 10000);
			gl.uniformMatrix4fv(openfl_Matrix, false, new Float32Array(p));
			var openfl_TextureSize = gl.getUniformLocation(shaderProgram, "openfl_TextureSize");
			gl.uniform2fv(openfl_TextureSize, new Float32Array([Lib.current.stage.stageWidth, Lib.current.stage.stageHeight]));
			var time = gl.getUniformLocation(shaderProgram, "time");
			gl.uniform1f(time, Lib.getTimer());

			for (index => bitmapData in data.bitmapDatas) {
				var texture = bitmapData.getTexture(context);
				gl.activeTexture(gl.TEXTURE0 + index);
				gl.bindTexture(gl.TEXTURE_2D, @:privateAccess texture.__getTexture());
				gl.texParameteri(@:privateAccess texture.__textureTarget, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
				gl.texParameteri(@:privateAccess texture.__textureTarget, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
				gl.texParameteri(@:privateAccess texture.__textureTarget, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
				gl.texParameteri(@:privateAccess texture.__textureTarget, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
				var sampler = gl.getUniformLocation(shaderProgram, "uSampler" + index);
				gl.uniform1i(sampler, index);
			}

			gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, @:privateAccess indexBuffer.__id);
			gl.drawElements(gl.TRIANGLES, @:privateAccess indexBuffer.__numIndices, gl.UNSIGNED_SHORT, 0);
		}
	}

	public function drawImageBufferData(data:ImageBufferData) {
		// 这里会进行updateBuffer
		this.data = data;
	}
}
