package hx.render2d.openfl;

import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLUniformLocation;
import lime.utils.Float32Array;
import openfl.display.OpenGLRenderer;
import openfl.events.RenderEvent;
import hx.render3d.openfl.RenderStateGuard3D;
import hx.render3d.openfl.TextureBridge3D;
import hx.render3d.openfl.VertexArrayBridge3D;

private typedef BatchProgram = {
	var program:GLProgram;
	var matrix:GLUniformLocation;
	var alpha:GLUniformLocation;
	var samplers:Array<GLUniformLocation>;
}

/** 二维直接提交：只改变几何、程序和采样，不改变父级目标或裁剪。 */
@:access(openfl.display.OpenGLRenderer)
@:access(openfl.display.DisplayObjectRenderer)
@:access(openfl.display.DisplayObject)
@:access(openfl.display.Shader)
@:access(openfl.display3D.Program3D)
@:access(openfl.display3D.Context3D)
@:access(openfl.display3D.textures.TextureBase)
@:access(openfl.display3D._internal.Context3DState)
class DirectBatchRenderer {
	private var gl:WebGLRenderContext;
	private var programs:Map<Int, BatchProgram> = [];
	private var vertexArrays:VertexArrayBridge3D;
	private var matrixData:Float32Array = new Float32Array(16);
	private var maxAttributes:Int = 8;
	private var uintIndices:Bool = false;
	private var nativeAlpha:Array<Float> = [1];
	public function new() {}

	private function compile(slots:Int):BatchProgram {
		var vertex = "precision highp float; attribute vec2 aPosition; attribute vec2 aUV; attribute vec3 aProperties; uniform mat4 uMatrix; varying vec2 vUV; varying vec3 vProperties; void main(){vUV=aUV;vProperties=aProperties;gl_Position=uMatrix*vec4(aPosition,0.0,1.0);}";
		var fragment = "precision highp float; varying vec2 vUV; varying vec3 vProperties; uniform float uAlpha;";
		for (i in 0...slots) fragment += 'uniform sampler2D uSampler$i;';
		fragment += "void main(){vec4 color=vec4(0.0);";
		for (i in 0...slots) fragment += (i == 0 ? "if" : "else if") + '(vProperties.x<${i + 0.5}){color=texture2D(uSampler$i,vUV);}';
		fragment += "gl_FragColor=color*vProperties.y*uAlpha;gl_FragColor.a*=1.0-step(0.5,vProperties.z);}";
		var vs = gl.createShader(gl.VERTEX_SHADER), fs = gl.createShader(gl.FRAGMENT_SHADER);
		var program = gl.createProgram();
		try {
			gl.shaderSource(vs, vertex); gl.compileShader(vs);
			if (!gl.getShaderParameter(vs, gl.COMPILE_STATUS)) throw gl.getShaderInfoLog(vs);
			gl.shaderSource(fs, fragment); gl.compileShader(fs);
			if (!gl.getShaderParameter(fs, gl.COMPILE_STATUS)) throw gl.getShaderInfoLog(fs);
			gl.attachShader(program, vs); gl.attachShader(program, fs);
			gl.bindAttribLocation(program, 0, "aPosition"); gl.bindAttribLocation(program, 1, "aUV"); gl.bindAttribLocation(program, 2, "aProperties");
			gl.linkProgram(program);
			if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw gl.getProgramInfoLog(program);
		} catch (error:Dynamic) {
			gl.deleteShader(vs); gl.deleteShader(fs); gl.deleteProgram(program); throw error;
		}
		gl.deleteShader(vs); gl.deleteShader(fs);
		return {program:program, matrix:gl.getUniformLocation(program, "uMatrix"), alpha:gl.getUniformLocation(program, "uAlpha"),
			samplers:[for (i in 0...slots) gl.getUniformLocation(program, 'uSampler$i')]};
	}

	public function render(batch:DirectBatchDisplay, event:RenderEvent):Void {
		if (batch.indexCount == 0) return;
		var renderer:OpenGLRenderer = cast event.renderer;
		if (renderer.gl == null || renderer.gl.isContextLost()) return;
		if (gl != renderer.gl) {
			abandon(); gl = renderer.gl;
			var raw:Dynamic = gl;
			vertexArrays = new VertexArrayBridge3D(gl, Reflect.isFunction(Reflect.field(raw, "createVertexArray")));
			maxAttributes = gl.getParameter(gl.MAX_VERTEX_ATTRIBS);
			uintIndices = vertexArrays.webgl2 || gl.getExtension("OES_element_index_uint") != null;
		}
		if (batch.wide && !uintIndices) throw "单个网格超过 65535 个顶点，需要 32 位索引扩展";
		var native = batch.shaderBuffer != null && batch.shaderBuffer.shader != null;
		var guard = new RenderStateGuard3D(renderer, native ? maxAttributes : 3, true, vertexArrays);
		var cachedArray = renderer.__context3D.__contextState.__currentGLArrayBuffer;
		try {
			guard.activateTexture(0);
			var info = native ? null : programs.get(batch.textures.length);
			if (!native && info == null) { info = compile(batch.textures.length); programs.set(batch.textures.length, info); }
			guard.bindVertexArray("batch2d");
			if (batch.vertexBuffer == null) batch.vertexBuffer = gl.createBuffer();
			if (batch.indexBuffer == null) batch.indexBuffer = gl.createBuffer();
			gl.bindBuffer(gl.ARRAY_BUFFER, batch.vertexBuffer);
			if (batch.uploadedRevision != batch.revision) {
				if (batch.gpuVertexCapacity < batch.vertices.length) {
					gl.bufferData(gl.ARRAY_BUFFER, batch.vertices.length * 4, gl.DYNAMIC_DRAW);
					batch.gpuVertexCapacity = batch.vertices.length;
				}
				gl.bufferSubData(gl.ARRAY_BUFFER, 0, batch.vertices.subarray(0, batch.vertexCount * 7));
				gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, batch.indexBuffer);
				if (batch.fixedIndices) {
					if (batch.gpuIndexCapacity < batch.indexCount) {
						var quads = 64;
						while (quads * 6 < batch.indexCount) quads *= 2;
						quads = Std.int(Math.min(quads, DirectBatchDisplay.MAX_QUADS));
						var fixedData = batch.prepareFixedIndices(quads);
						gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, fixedData, gl.STATIC_DRAW);
						// 有效容量取自已完整生成的固定索引，不能使用旧通用网格的数组容量。
						batch.gpuIndexCapacity = fixedData.length;
						batch.gpuIndexStride = 2;
					}
				} else {
					var indexData:Dynamic = batch.wide ? cast batch.wideIndices : cast batch.indices;
					var stride = batch.wide ? 4 : 2;
					if (batch.gpuIndexCapacity < indexData.length || batch.gpuIndexStride != stride) {
						gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indexData.length * stride, gl.DYNAMIC_DRAW);
						batch.gpuIndexCapacity = indexData.length; batch.gpuIndexStride = stride;
					}
					gl.bufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, indexData.subarray(0, batch.indexCount));
				}
				batch.uploadedRevision = batch.revision;
			} else gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, batch.indexBuffer);
			if (native) {
				drawNative(batch, renderer, guard);
			} else {
			gl.useProgram(info.program);
			for (slot in 0...batch.textures.length) {
				guard.activateTexture(slot);
				var texture = TextureBridge3D.resolve(batch.textures[slot], renderer.__context3D);
				guard.rememberTexture(texture);
				gl.bindTexture(gl.TEXTURE_2D, TextureBridge3D.handle(texture));
				TextureBridge3D.applySampler(texture, batch.smoothing);
				gl.uniform1i(info.samplers[slot], slot);
			}
			var matrix = renderer.__getMatrix(batch.__renderTransform, AUTO);
			for (i in 0...16) matrixData[i] = matrix[i];
			gl.uniformMatrix4fv(info.matrix, false, matrixData);
			gl.uniform1f(info.alpha, batch.__worldAlpha * renderer.__worldAlpha);
			for (i in 0...3) gl.enableVertexAttribArray(i);
			gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 28, 0);
			gl.vertexAttribPointer(1, 2, gl.FLOAT, false, 28, 8);
			gl.vertexAttribPointer(2, 3, gl.FLOAT, false, 28, 16);
			gl.enable(gl.BLEND); gl.disable(gl.DEPTH_TEST); gl.disable(gl.CULL_FACE); gl.depthMask(false);
			// 沿用回调入口已经提交的混合状态，保留 SCREEN 及父级合成语义。
			gl.drawElements(gl.TRIANGLES, batch.indexCount, batch.wide ? gl.UNSIGNED_INT : gl.UNSIGNED_SHORT, 0);
			}
		} catch (error:Dynamic) { guard.restore(); renderer.__context3D.__contextState.__currentGLArrayBuffer = cachedArray; throw error; }
		guard.restore();
		renderer.__context3D.__contextState.__currentGLArrayBuffer = cachedArray;
	}

	/** 复用 OpenFL 的 Shader 反射和参数绑定，绕过 Graphics 命令与几何重组。 */
	private function drawNative(batch:DirectBatchDisplay, renderer:OpenGLRenderer, guard:RenderStateGuard3D):Void {
		var buffer = batch.shaderBuffer, shader = buffer.shader;
		shader.__setContext(renderer.__context3D);
		gl.useProgram(shader.program.__glProgram);
		for (slot in 0...buffer.inputCount) {
			if (buffer.inputs[slot] == null) continue;
			guard.activateTexture(slot);
			var texture = TextureBridge3D.resolve(buffer.inputs[slot], renderer.__context3D);
			guard.rememberTexture(texture);
			gl.bindTexture(gl.TEXTURE_2D, TextureBridge3D.handle(texture));
			texture.__setSamplerState(new openfl.display._internal.SamplerState(buffer.inputWrap[slot], buffer.inputFilter[slot], buffer.inputMipFilter[slot]));
		}
		shader.__enable();
		buffer.clearOverride();
		buffer.addFloatOverride("openfl_Matrix", renderer.__getMatrix(batch.__renderTransform, AUTO));
		nativeAlpha[0] = renderer.__worldAlpha;
		buffer.addFloatOverride("openfl_Alpha", nativeAlpha);
		buffer.addBoolOverride("openfl_HasColorTransform", [false]);
		// 直接绑定纹理，不向 Context3D 的延迟状态队列写入临时采样状态。
		var inputCount = buffer.inputCount;
		buffer.inputCount = 0;
		renderer.__context3D.__contextState.__currentGLArrayBuffer = null;
		try { shader.__updateGLFromBuffer(buffer, 0); }
		catch (error:Dynamic) { buffer.inputCount = inputCount; throw error; }
		buffer.inputCount = inputCount;
		gl.bindBuffer(gl.ARRAY_BUFFER, batch.vertexBuffer);
		if (shader.__position != null) {
			gl.enableVertexAttribArray(shader.__position.index);
			gl.vertexAttribPointer(shader.__position.index, 2, gl.FLOAT, false, 28, 0);
		}
		if (shader.__textureCoord != null) {
			gl.enableVertexAttribArray(shader.__textureCoord.index);
			gl.vertexAttribPointer(shader.__textureCoord.index, 2, gl.FLOAT, false, 28, 8);
		}
		gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, batch.indexBuffer);
		gl.disable(gl.DEPTH_TEST); gl.disable(gl.CULL_FACE); gl.depthMask(false);
		gl.drawElements(gl.TRIANGLES, batch.indexCount, batch.wide ? gl.UNSIGNED_INT : gl.UNSIGNED_SHORT, 0);
	}

	public function release(batch:DirectBatchDisplay):Void {
		if (gl != null && !gl.isContextLost()) {
			if (batch.vertexBuffer != null) gl.deleteBuffer(batch.vertexBuffer);
			if (batch.indexBuffer != null) gl.deleteBuffer(batch.indexBuffer);
			if (batch.shaderBuffer != null && batch.shaderBuffer.paramDataBuffer != null) gl.deleteBuffer(batch.shaderBuffer.paramDataBuffer);
		}
		batch.abandon();
	}
	public function abandon():Void { programs.clear(); if (vertexArrays != null) vertexArrays.abandon(); vertexArrays = null; gl = null; }
	public function dispose():Void {
		if (gl != null && !gl.isContextLost()) {
			for (info in programs) gl.deleteProgram(info.program);
			if (vertexArrays != null) vertexArrays.dispose();
		}
		abandon();
	}
}
