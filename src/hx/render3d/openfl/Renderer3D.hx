package hx.render3d.openfl;

import haxe.Json;
import hx.display.Scene3D;
import hx.display.Node3D;
import hx.display.MeshObject;
import hx.material.Material3D;
import hx.material.AlphaMode3D;
import hx.material.CullMode3D;
import hx.geom.Matrix3D;
import hx.render3d.Math3D;
import hx.utils.ContextStats;
import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GL;
import lime.graphics.opengl.GLBuffer;
import lime.utils.Float32Array;
import lime.utils.UInt16Array;
import openfl.display.OpenGLRenderer;
import openfl.events.RenderEvent;

private typedef ProgramInfo3D = { var program:GLProgram; var slots:Int; }
private typedef DrawItem3D = { var mesh:MeshObject; var depth:Float; var order:Int; var key:String; var mirrored:Bool; }

/** 专用三维渲染器，保留二维路径的多纹理设计，但独立提交真实三维顶点。 */
@:access(openfl.display.OpenGLRenderer)
@:access(openfl.display.DisplayObjectRenderer)
@:access(openfl.display.DisplayObject)
class Renderer3D {
	private var gl:WebGLRenderContext;
	private var vertexBuffer:GLBuffer;
	private var indexBuffer:GLBuffer;
	private var composite:GLProgram;
	private var target:Scene3DRenderTarget;
	private var white:openfl.display.BitmapData;
	private var programs:Map<String, ProgramInfo3D> = [];
	private var supportedSlots:Int = 1;
	private var lastVersion:Int = -1;
	private var lastSettings:String;
	public function new() {}

	public function render(scene:Scene3D, display:Scene3DDisplay, event:RenderEvent):Void {
		if (scene.isDisposed || scene.width <= 0 || scene.height <= 0) return;
		var renderer:OpenGLRenderer = cast event.renderer;
		if (renderer.gl == null || renderer.gl.isContextLost()) return;
		// 同一个 WebGL 对象在上下文恢复后仍可能保留身份，用缓冲有效性辅助识别。
		if (gl != renderer.gl || (vertexBuffer != null && !renderer.gl.isBuffer(vertexBuffer))) abandonContext();
		gl = renderer.gl;
		var count:Int = gl.getParameter(gl.MAX_TEXTURE_IMAGE_UNITS);
		count = Std.int(Math.min(16, Math.min(count, gl.getParameter(gl.MAX_COMBINED_TEXTURE_IMAGE_UNITS))));
		if (count < 1 || gl.getParameter(gl.MAX_VERTEX_ATTRIBS) < 4) throw "当前设备不支持基础三维顶点或纹理输入";
		var guard = new RenderStateGuard3D(renderer, count);
		try {
			if (vertexBuffer == null) initialize(count);
			if (!Math3D.finite(scene.renderScale) || scene.renderScale <= 0 || !Math3D.finite(scene.backgroundAlpha)
				|| scene.backgroundAlpha < 0 || scene.backgroundAlpha > 1) throw "三维分辨率或背景透明度无效";
			var ratio:Float = renderer.__pixelRatio;
			if (!Math3D.finite(ratio) || ratio <= 0) ratio = 1;
			var maxSize = Math.min(gl.getParameter(gl.MAX_TEXTURE_SIZE), gl.getParameter(gl.MAX_RENDERBUFFER_SIZE));
			var w = scene.width * ratio * scene.renderScale, h = scene.height * ratio * scene.renderScale;
			var viewport:Dynamic = gl.getParameter(gl.MAX_VIEWPORT_DIMS);
			var reduction = Math.min(1, Math.min(Math.min(maxSize, viewport[0]) / w, Math.min(maxSize, viewport[1]) / h));
			var width = Std.int(Math.max(1, Math.floor(w * reduction))), height = Std.int(Math.max(1, Math.floor(h * reduction)));
			if (target == null || target.width != width || target.height != height) {
				if (target != null) target.dispose();
				target = null; target = new Scene3DRenderTarget(gl, width, height); lastVersion = -1;
			}
			var settings = [scene.multiTextureEnabled ? 1 : 0, scene.backgroundColor, scene.backgroundAlpha,
				scene.camera == null ? 0 : scene.camera.fieldOfView, scene.camera == null ? 0 : scene.camera.near, scene.camera == null ? 0 : scene.camera.far].join(":");
			if (lastVersion != scene.contentVersion || settings != lastSettings) {
				scene.stats.reset(); scene.stats.targetBytes = width * height * 6;
				gl.bindFramebuffer(gl.FRAMEBUFFER, target.framebuffer); gl.viewport(0, 0, width, height);
				gl.disable(gl.SCISSOR_TEST); gl.disable(gl.STENCIL_TEST); gl.disable(gl.POLYGON_OFFSET_FILL); gl.disable(gl.SAMPLE_ALPHA_TO_COVERAGE);
				gl.colorMask(true, true, true, true); gl.depthMask(true); gl.depthRange(0, 1);
				var alpha = scene.backgroundAlpha;
				gl.clearColor(((scene.backgroundColor >> 16) & 255)/255.*alpha, ((scene.backgroundColor >> 8) & 255)/255.*alpha, (scene.backgroundColor & 255)/255.*alpha, alpha);
				gl.clearDepth(1); gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
				if (scene.camera != null) drawScene(scene, renderer, guard);
				lastVersion = scene.contentVersion; lastSettings = settings;
			}
			guard.restoreTarget(); drawComposite(scene, display, event, renderer);
		} catch (error:Dynamic) { guard.restore(); throw error; }
		guard.restore();
	}

	private function initialize(count:Int):Void {
		supportedSlots = count;
		composite = MultiTextureShader3D.compile(gl,
			"attribute vec3 aPosition;attribute vec2 aUV;uniform mat4 uMatrix;varying mediump vec2 vUV;void main(){gl_Position=uMatrix*vec4(aPosition,1.0);vUV=aUV;}",
			"precision mediump float;varying mediump vec2 vUV;uniform sampler2D uSampler0;uniform vec4 uColorMultiplier;uniform vec4 uColorOffset;uniform float uAlpha;"
			+ "void main(){vec4 color=texture2D(uSampler0,vUV);if(color.a>0.0){color.rgb/=color.a;}else{color.rgb=vec3(0.0);}"
			+ "color=clamp(color*uColorMultiplier+uColorOffset,0.0,1.0);color.a*=uAlpha;gl_FragColor=vec4(color.rgb*color.a,color.a);}");
		vertexBuffer = gl.createBuffer(); indexBuffer = gl.createBuffer();
		white = new openfl.display.BitmapData(1, 1, true, 0xffffffff);
	}

	private function getProgram(material:Material3D, multi:Bool):ProgramInfo3D {
		var key = Json.stringify([material.fragmentDeclarations, material.fragmentCode, multi ? Std.string(supportedSlots) : "1"]);
		var info = programs.get(key);
		if (info != null) return info;
		var slots = multi ? supportedSlots : 1;
		while (true) {
			try {
				info = {program:MultiTextureShader3D.create(gl, slots, material.fragmentDeclarations, material.fragmentCode), slots:slots};
				programs.set(key, info); return info;
			} catch (error:Dynamic) {
				if (slots <= 1) throw error;
				trace("三维多纹理 Shader 回退，当前槽位数：" + slots + "，原因：" + Std.string(error));
				slots = Std.int(Math.max(1, Math.floor(slots / 2)));
			}
		}
	}

	private function drawScene(scene:Scene3D, renderer:OpenGLRenderer, guard:RenderStateGuard3D):Void {
		var view = scene.camera.getViewMatrix(), projection = scene.camera.getViewProjection(scene.width / scene.height);
		var items:Array<DrawItem3D> = [], order = 0;
		function visit(node:Node3D):Void {
			if (!node.visible || node.isDisposed) return;
			if (Std.isOfType(node, MeshObject)) {
				var mesh:MeshObject = cast node;
				if (mesh.geometry != null && mesh.material != null && mesh.geometry.indices.length > 0) {
					var world = mesh.getWorldMatrix(), bounds = mesh.getWorldBounds();
					if (Math.abs(world.determinant) >= 1e-12) {
						if (mesh.frustumCulling && !bounds.inFrustum(projection)) scene.stats.culledMeshes++;
						else {
							var mirrored = world.determinant < 0;
							items.push({mesh:mesh, depth:-view.transformVector(bounds.center()).z, order:order++, mirrored:mirrored, key:MeshBatch3D.materialKey(mesh.material, mirrored)});
							scene.stats.visibleMeshes++;
						}
					}
				}
			}
			for (child in node.children) visit(child);
		}
		visit(scene.root);
		items.sort(function(a, b) {
			var aBlend = a.mesh.material.alphaMode == AlphaMode3D.BLEND, bBlend = b.mesh.material.alphaMode == AlphaMode3D.BLEND;
			if (aBlend != bBlend) return aBlend ? 1 : -1;
			if (aBlend) { if (a.depth != b.depth) return a.depth > b.depth ? -1 : 1; }
			else { var compare = Reflect.compare(a.key, b.key); if (compare != 0) return compare; if (a.depth != b.depth) return a.depth < b.depth ? -1 : 1; }
			return a.order - b.order;
		});
		var batch:MeshBatch3D = null;
		for (item in items) {
			var mesh = item.mesh, material = mesh.material, info = getProgram(material, scene.multiTextureEnabled);
			var source = TextureBridge3D.source(material.texture, white);
			// 先上传纹理并确定实际尺寸，后续才计算图集 UV。
			gl.activeTexture(gl.TEXTURE0); TextureBridge3D.resolve(source, renderer.__context3D);
			if (batch != null && batch.key != item.key) { submit(batch, projection, scene, renderer, guard); scene.stats.split("material"); batch = null; }
			if (batch == null) batch = new MeshBatch3D(material, item.mirrored, info.slots);
			var world = mesh.getWorldVertices(), remap:Map<Int, Int> = [];
			var indices = mesh.geometry.indices;
			for (triangle in 0...Std.int(indices.length / 3)) {
				var textureId = batch.textures.indexOf(source);
				var fullTexture = textureId < 0 && batch.textures.length >= batch.slots;
				var fullVertices = Std.int(batch.vertices.length / 10) + 3 > MeshBatch3D.MAX_VERTICES;
				// 同样限制索引内存，避免只有三个顶点的超多重复三角形无限扩大批次。
				var fullIndices = batch.indices.length + 3 > 196605;
				if (fullTexture || fullVertices || fullIndices) {
					submit(batch, projection, scene, renderer, guard); scene.stats.split(fullTexture ? "textures" : "capacity");
					batch = new MeshBatch3D(material, item.mirrored, info.slots); remap.clear(); textureId = -1;
				}
				if (textureId < 0) { textureId = batch.textures.length; batch.textures.push(source); }
				for (corner in 0...3) {
					var index = indices[triangle * 3 + corner], mapped = remap.get(index);
					if (mapped == null) { mapped = batch.vertex(mesh, index, textureId, world, source); remap.set(index, mapped); }
					batch.indices.push(mapped);
				}
			}
		}
		if (batch != null) submit(batch, projection, scene, renderer, guard);
	}

	private function submit(batch:MeshBatch3D, projection:Matrix3D, scene:Scene3D, renderer:OpenGLRenderer, guard:RenderStateGuard3D):Void {
		if (batch.indices.length == 0) return;
		var key = Json.stringify([batch.declarations, batch.fragmentCode, scene.multiTextureEnabled ? Std.string(supportedSlots) : "1"]);
		var info = programs.get(key);
		gl.useProgram(info.program); gl.uniformMatrix4fv(gl.getUniformLocation(info.program, "uViewProjection"), false, floatData(projection.rawData));
		gl.uniform1f(gl.getUniformLocation(info.program, "uAlphaMode"), batch.alphaMode);
		gl.uniform1f(gl.getUniformLocation(info.program, "uAlphaCutoff"), batch.alphaCutoff);
		// 每次提交重置所有活动自定义 uniform，缺省值不能继承上一份材质。
		var uniformCount:Int = gl.getProgramParameter(info.program, gl.ACTIVE_UNIFORMS);
		for (index in 0...uniformCount) {
			var active = gl.getActiveUniform(info.program, index), name = active.name;
			if (StringTools.startsWith(name, "uSampler") || name == "uViewProjection" || name == "uAlphaMode" || name == "uAlphaCutoff") continue;
			if (active.size != 1) throw "自定义三维 uniform 首版不支持数组";
			var length = switch (active.type) {
				case GL.FLOAT: 1;
				case GL.FLOAT_VEC2: 2;
				case GL.FLOAT_VEC3: 3;
				case GL.FLOAT_VEC4: 4;
				case GL.FLOAT_MAT4: 16;
				default: throw "自定义三维 uniform 首版只支持浮点标量、向量与四阶矩阵";
			};
			var values = batch.uniforms.get(name);
			if (values == null) values = [for (_ in 0...length) 0.];
			if (values.length != length) throw "自定义 uniform 数值长度与 Shader 声明不一致：" + name;
			var location = gl.getUniformLocation(info.program, name);
			switch (values.length) {
				case 1: gl.uniform1f(location, values[0]);
				case 2: gl.uniform2f(location, values[0], values[1]);
				case 3: gl.uniform3f(location, values[0], values[1], values[2]);
				case 4: gl.uniform4f(location, values[0], values[1], values[2], values[3]);
				case 16: gl.uniformMatrix4fv(location, false, floatData(values));
			}
		}
		for (slot in 0...batch.textures.length) {
			gl.activeTexture(gl.TEXTURE0 + slot);
			var texture = TextureBridge3D.resolve(batch.textures[slot], renderer.__context3D);
			gl.bindTexture(gl.TEXTURE_2D, texture); guard.rememberTexture(texture);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, batch.smoothing ? gl.LINEAR : gl.NEAREST);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, batch.smoothing ? gl.LINEAR : gl.NEAREST);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
			gl.uniform1i(gl.getUniformLocation(info.program, "uSampler" + slot), slot);
		}
		if (batch.depthTest) gl.enable(gl.DEPTH_TEST); else gl.disable(gl.DEPTH_TEST);
		gl.depthFunc(gl.LEQUAL); gl.depthMask(batch.depthWrite);
		if (batch.cullMode == CullMode3D.NONE) gl.disable(gl.CULL_FACE);
		else { gl.enable(gl.CULL_FACE); gl.cullFace(batch.cullMode == CullMode3D.BACK ? gl.BACK : gl.FRONT); }
		gl.frontFace(batch.mirrored ? gl.CW : gl.CCW);
		if (batch.alphaMode == AlphaMode3D.BLEND) { gl.enable(gl.BLEND); gl.blendEquation(gl.FUNC_ADD); gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA); }
		else gl.disable(gl.BLEND);
		gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer); gl.bufferData(gl.ARRAY_BUFFER, floatData(batch.vertices), gl.STREAM_DRAW);
		gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer); gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indexData(batch.indices), gl.STREAM_DRAW);
		for (i in 0...4) gl.enableVertexAttribArray(i);
		gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 40, 0); gl.vertexAttribPointer(1, 2, gl.FLOAT, false, 40, 12);
		gl.vertexAttribPointer(2, 1, gl.FLOAT, false, 40, 20); gl.vertexAttribPointer(3, 4, gl.FLOAT, false, 40, 24);
		gl.drawElements(gl.TRIANGLES, batch.indices.length, gl.UNSIGNED_SHORT, 0);
		scene.stats.drawCalls++; scene.stats.triangles += Std.int(batch.indices.length / 3);
		scene.stats.uploadedBytes += batch.vertices.length * 4 + batch.indices.length * 2;
		scene.stats.textureSlots = Std.int(Math.max(scene.stats.textureSlots, batch.textures.length));
		ContextStats.statsDrawCall(); ContextStats.statsVertexCount(batch.indices.length);
	}

	private function drawComposite(scene:Scene3D, display:Scene3DDisplay, event:RenderEvent, renderer:OpenGLRenderer):Void {
		gl.disable(gl.DEPTH_TEST); gl.depthMask(false); gl.disable(gl.CULL_FACE); gl.enable(gl.BLEND);
		gl.blendEquation(gl.FUNC_ADD); gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA); gl.useProgram(composite);
		gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, target.texture);
		gl.uniform1i(gl.getUniformLocation(composite, "uSampler0"), 0);
		var matrix = renderer.getMatrix(event.objectMatrix), values = new Float32Array(16);
		for (i in 0...16) values[i] = matrix[i];
		gl.uniformMatrix4fv(gl.getUniformLocation(composite, "uMatrix"), false, values);
		var color = renderer.__getColorTransform(event.objectColorTransform);
		gl.uniform4f(gl.getUniformLocation(composite, "uColorMultiplier"), color.redMultiplier, color.greenMultiplier, color.blueMultiplier, color.alphaMultiplier);
		gl.uniform4f(gl.getUniformLocation(composite, "uColorOffset"), color.redOffset/255, color.greenOffset/255, color.blueOffset/255, color.alphaOffset/255);
		gl.uniform1f(gl.getUniformLocation(composite, "uAlpha"), renderer.__getAlpha(display.__worldAlpha));
		var w = scene.width, h = scene.height;
		var vertices:Array<Float> = [0,0,0,0,1, w,0,0,1,1, w,h,0,1,0, 0,0,0,0,1, w,h,0,1,0, 0,h,0,0,0];
		gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer); gl.bufferData(gl.ARRAY_BUFFER, floatData(vertices), gl.STREAM_DRAW);
		gl.enableVertexAttribArray(0); gl.enableVertexAttribArray(1); gl.disableVertexAttribArray(2); gl.disableVertexAttribArray(3);
		gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 20, 0); gl.vertexAttribPointer(1, 2, gl.FLOAT, false, 20, 12);
		gl.drawArrays(gl.TRIANGLES, 0, 6); scene.stats.compositeDrawCalls = 1;
		ContextStats.statsDrawCall(); ContextStats.statsVertexCount(6);
	}

	private static function floatData(values:Array<Float>):Float32Array {
		var result = new Float32Array(values.length);
		for (i in 0...values.length) result[i] = values[i];
		return result;
	}
	private static function indexData(values:Array<Int>):UInt16Array {
		var result = new UInt16Array(values.length);
		for (i in 0...values.length) result[i] = values[i];
		return result;
	}

	/** 上下文已失效时仅丢弃句柄，不能在新上下文删除旧句柄。 */
	public function abandonContext():Void {
		gl = null; vertexBuffer = null; indexBuffer = null; composite = null; target = null; programs.clear(); lastVersion = -1;
		if (white != null) white.dispose(); white = null;
	}
	public function dispose():Void {
		if (gl != null && !gl.isContextLost()) {
			if (target != null) target.dispose();
			if (vertexBuffer != null) gl.deleteBuffer(vertexBuffer);
			if (indexBuffer != null) gl.deleteBuffer(indexBuffer);
			if (composite != null) gl.deleteProgram(composite);
			for (info in programs) gl.deleteProgram(info.program);
		}
		abandonContext();
	}
}
