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
import lime.graphics.opengl.GLBuffer;
import lime.utils.Float32Array;
import lime.utils.UInt16Array;
import openfl.display.OpenGLRenderer;
import openfl.events.RenderEvent;

private typedef DrawItem3D = { var mesh:MeshObject; var depth:Float; var order:Int; var key:String; var mirrored:Bool; }

/** 专用三维渲染器，保留二维路径的多纹理设计，但独立提交真实三维顶点。 */
@:access(openfl.display.OpenGLRenderer)
@:access(openfl.display.DisplayObjectRenderer)
@:access(openfl.display.DisplayObject)
class Renderer3D {
	private var gl:WebGLRenderContext;
	private var vertexBuffer:GLBuffer;
	private var indexBuffer:GLBuffer;
	private var composite:Program3DInfo;
	private var capabilitiesReady:Bool = false;
	private var maxTargetWidth:Int = 1;
	private var maxTargetHeight:Int = 1;
	#if (js && html5)
	private var contextCanvas:js.html.CanvasElement;
	#end
	private var target:Scene3DRenderTarget;
	private var white:openfl.display.BitmapData;
	private var programs:Map<String, Program3DInfo> = [];
	private var supportedSlots:Int = 1;
	private var frameSlots:Int = 1;
	private var frameNormals:Bool = false;
	private var frameShadow:Bool = false;
	private var maxAttributes:Int = 4;
	private var depthTextures:Bool = false;
	private var sizedDepth:Bool = false;
	private var shadowPass:ShadowPass3D;
	private var lastVersion:Int = -1;
	private var lastSettings:String;
	#if hxmaker_3d_profile
	private var profileWarmup:Int = 120;
	private var profileSamples:Array<Float> = [];
	private var profileMulti:Bool = true;
	#end
	public function new() {}

	public function render(scene:Scene3D, display:Scene3DDisplay, event:RenderEvent):Void {
		if (scene.isDisposed || scene.width <= 0 || scene.height <= 0) return;
		var renderer:OpenGLRenderer = cast event.renderer;
		if (renderer.gl == null || renderer.gl.isContextLost()) return;
		var timed = scene.profilingEnabled, started = timed ? profileClock() : 0.;
		var stateTime = 0., shadowTime = 0., mainTime = 0., compositeTime = 0., mark = 0.;
		var redrawn = false;
		#if hxmaker_3d_profile
		var profileStart = timed ? started : profileClock();
		#end
		// 恢复事件会使设备代次失效，正常帧不再同步探测缓冲句柄。
		if (gl != renderer.gl) abandonContext();
		gl = renderer.gl;
		if (!capabilitiesReady) readCapabilities();
		var meshes = collectMeshes(scene.root);
		frameNormals = false; for (mesh in meshes) if (mesh.material.lightingEnabled) { frameNormals = true; break; }
		if (frameNormals && maxAttributes < 5) throw "当前设备不支持光照法线属性";
		if (timed) mark = profileClock();
		var guard = new RenderStateGuard3D(renderer, supportedSlots, frameNormals ? 5 : 4);
		if (timed) stateTime = profileClock() - mark;
		try {
			if (vertexBuffer == null) initialize();
			if (!Math3D.finite(scene.renderScale) || scene.renderScale <= 0 || !Math3D.finite(scene.backgroundAlpha)
				|| scene.backgroundAlpha < 0 || scene.backgroundAlpha > 1) throw "三维分辨率或背景透明度无效";
			var ratio:Float = renderer.__pixelRatio;
			if (!Math3D.finite(ratio) || ratio <= 0) ratio = 1;
			var w = scene.width * ratio * scene.renderScale, h = scene.height * ratio * scene.renderScale;
			var reduction = Math.min(1, Math.min(maxTargetWidth / w, maxTargetHeight / h));
			var width = Std.int(Math.max(1, Math.floor(w * reduction))), height = Std.int(Math.max(1, Math.floor(h * reduction)));
			if (target == null || target.width != width || target.height != height) {
				if (target != null) target.dispose();
				target = null; target = new Scene3DRenderTarget(gl, width, height); lastVersion = -1;
			}
			scene.stats.targetWidth = width; scene.stats.targetHeight = height;
			var settingValues:Array<Dynamic> = [scene.multiTextureEnabled ? 1 : 0, scene.backgroundColor, scene.backgroundAlpha,
				scene.camera == null ? 0 : scene.camera.fieldOfView, scene.camera == null ? 0 : scene.camera.near, scene.camera == null ? 0 : scene.camera.far, scene.lightingKey()];
			var settings = settingValues.join(":");
			if (lastVersion != scene.contentVersion || settings != lastSettings) {
				redrawn = true; scene.stats.reset(); scene.stats.targetBytes = width * height * 6;
				if (timed) mark = profileClock();
				frameShadow = scene.camera != null && shadowPass.render(scene, meshes, supportedSlots);
				if (timed) { shadowTime = profileClock() - mark; mark = profileClock(); }
				frameSlots = supportedSlots - (frameShadow ? 1 : 0);
				gl.bindFramebuffer(gl.FRAMEBUFFER, target.framebuffer); gl.viewport(0, 0, width, height);
				gl.disable(gl.SCISSOR_TEST); gl.disable(gl.STENCIL_TEST); gl.disable(gl.POLYGON_OFFSET_FILL); gl.disable(gl.SAMPLE_ALPHA_TO_COVERAGE);
				gl.colorMask(true, true, true, true); gl.depthMask(true); gl.depthRange(0, 1);
				var alpha = scene.backgroundAlpha;
				gl.clearColor(((scene.backgroundColor >> 16) & 255)/255.*alpha, ((scene.backgroundColor >> 8) & 255)/255.*alpha, (scene.backgroundColor & 255)/255.*alpha, alpha);
				gl.clearDepth(1); gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
				if (scene.camera != null) drawScene(scene, meshes, renderer, guard);
				if (timed) mainTime = profileClock() - mark;
				lastVersion = scene.contentVersion; lastSettings = settings;
			}
			if (timed) mark = profileClock();
			guard.restoreTarget(); drawComposite(scene, display, event, renderer);
			if (timed) compositeTime = profileClock() - mark;
		} catch (error:Dynamic) { guard.restore(); throw error; }
		if (timed) mark = profileClock();
		guard.restore();
		if (timed) stateTime += profileClock() - mark;
		var stats = scene.stats; stats.renderId++; if (redrawn) stats.redrawId++;
		stats.redrawThisFrame = redrawn; stats.profileReady = timed;
		stats.renderCpuMs = timed ? profileClock() - started : 0;
		stats.shadowCpuMs = shadowTime; stats.mainCpuMs = mainTime;
		stats.compositeCpuMs = compositeTime; stats.stateCpuMs = stateTime;
		#if hxmaker_3d_profile
		recordProfile(profileClock() - profileStart, scene.multiTextureEnabled);
		#end
	}

	/** 按场景显式开启或诊断构建开启时才调用，不在普通路径读取时钟。 */
	private static function profileClock():Float {
		#if (js && html5)
		return js.Browser.window.performance.now();
		#else
		return haxe.Timer.stamp() * 1000;
		#end
	}
	#if hxmaker_3d_profile
	private function recordProfile(elapsed:Float, multi:Bool):Void {
		if (multi != profileMulti) { profileMulti = multi; profileWarmup = 120; profileSamples = []; }
		if (profileWarmup > 0) { profileWarmup--; return; }
		profileSamples.push(elapsed);
		if (profileSamples.length == 240) {
			profileSamples.sort(Reflect.compare);
			var sum = 0.; for (value in profileSamples) sum += value;
			trace("HXMAKER_3D_PROFILE mode=" + (multi ? "multi" : "single") + " samples=240 meanMs=" + (sum / 240)
				+ " p50Ms=" + profileSamples[119] + " p95Ms=" + profileSamples[227] + " maxMs=" + profileSamples[239]);
			profileSamples = [];
		}
	}
	#end

	private function readCapabilities():Void {
		var count:Int = gl.getParameter(gl.MAX_TEXTURE_IMAGE_UNITS);
		supportedSlots = Std.int(Math.min(16, Math.min(count, gl.getParameter(gl.MAX_COMBINED_TEXTURE_IMAGE_UNITS))));
		maxAttributes = gl.getParameter(gl.MAX_VERTEX_ATTRIBS);
		if (supportedSlots < 1 || maxAttributes < 4) throw "当前设备不支持基础三维顶点或纹理输入";
		var size = Math.min(gl.getParameter(gl.MAX_TEXTURE_SIZE), gl.getParameter(gl.MAX_RENDERBUFFER_SIZE));
		var viewport:Dynamic = gl.getParameter(gl.MAX_VIEWPORT_DIMS);
		maxTargetWidth = Std.int(Math.min(size, viewport[0])); maxTargetHeight = Std.int(Math.min(size, viewport[1]));
		var version = Std.string(gl.getParameter(gl.VERSION));
		sizedDepth = version.indexOf("WebGL 2") >= 0 || version.indexOf("OpenGL ES 3") >= 0;
		if (version.indexOf("WebGL") >= 0) depthTextures = sizedDepth || gl.getExtension("WEBGL_depth_texture") != null;
		else if (version.indexOf("OpenGL ES 2") >= 0) depthTextures = gl.getExtension("GL_OES_depth_texture") != null || gl.getExtension("OES_depth_texture") != null;
		else depthTextures = true;
		capabilitiesReady = true;
		#if (js && html5)
		var raw:js.html.webgl.RenderingContext = cast gl;
		var canvas:js.html.CanvasElement = cast raw.canvas;
		if (canvas != contextCanvas) {
			removeContextListeners(); contextCanvas = canvas;
			if (contextCanvas != null) {
				contextCanvas.addEventListener("webglcontextlost", onContextChange);
				contextCanvas.addEventListener("webglcontextrestored", onContextChange);
			}
		}
		#end
	}

	private function initialize():Void {
		composite = new Program3DInfo(gl, MultiTextureShader3D.compile(gl,
			"attribute vec3 aPosition;attribute vec2 aUV;uniform mat4 uMatrix;varying mediump vec2 vUV;void main(){gl_Position=uMatrix*vec4(aPosition,1.0);vUV=aUV;}",
			"precision mediump float;varying mediump vec2 vUV;uniform sampler2D uSampler0;uniform vec4 uColorMultiplier;uniform vec4 uColorOffset;uniform float uAlpha;"
			+ "void main(){vec4 color=texture2D(uSampler0,vUV);if(color.a>0.0){color.rgb/=color.a;}else{color.rgb=vec3(0.0);}"
			+ "color=clamp(color*uColorMultiplier+uColorOffset,0.0,1.0);color.a*=uAlpha;gl_FragColor=vec4(color.rgb*color.a,color.a);}"), 1, false);
		vertexBuffer = gl.createBuffer(); indexBuffer = gl.createBuffer();
		white = new openfl.display.BitmapData(1, 1, true, 0xffffffff);
		shadowPass = new ShadowPass3D(gl, depthTextures, sizedDepth, Std.int(Math.min(maxTargetWidth, maxTargetHeight)));
	}

	private function programKey(declarations:String, code:String, multi:Bool, lit:Bool):String {
		return Json.stringify([declarations, code, Std.string(multi ? frameSlots : 1), Std.string(lit), Std.string(lit && frameShadow)]);
	}

	private function collectMeshes(root:Node3D):Array<MeshObject> {
		var meshes:Array<MeshObject> = [];
		function visit(node:Node3D):Void {
			if (!node.visible || node.isDisposed) return;
			if (Std.isOfType(node, MeshObject)) {
				var mesh:MeshObject = cast node;
				if (mesh.geometry != null && mesh.material != null && mesh.geometry.indices.length > 0 && Math.abs(mesh.getWorldMatrix().determinant) >= 1e-12) meshes.push(mesh);
			}
			for (child in node.children) visit(child);
		}
		visit(root); return meshes;
	}

	private function getProgram(material:Material3D, multi:Bool):Program3DInfo {
		var key = programKey(material.fragmentDeclarations, material.fragmentCode, multi, material.lightingEnabled);
		var info = programs.get(key);
		if (info != null) return info;
		var slots = multi ? frameSlots : 1;
		var program:GLProgram = null;
		while (program == null) {
			try { program = MultiTextureShader3D.create(gl, slots, material.fragmentDeclarations, material.fragmentCode, material.lightingEnabled, frameShadow); }
			catch (error:Dynamic) {
				if (slots <= 1) throw error;
				trace("三维多纹理 Shader 回退，当前槽位数：" + slots + "，原因：" + Std.string(error));
				slots = Std.int(Math.max(1, Math.floor(slots / 2)));
			}
		}
		info = new Program3DInfo(gl, program, slots); programs.set(key, info); return info;
	}

	private function drawScene(scene:Scene3D, meshes:Array<MeshObject>, renderer:OpenGLRenderer, guard:RenderStateGuard3D):Void {
		var view = scene.camera.getViewMatrix(), projection = scene.camera.getViewProjection(scene.width / scene.height);
		var items:Array<DrawItem3D> = [], order = 0;
		for (mesh in meshes) {
			var world = mesh.getWorldMatrix(), bounds = mesh.getWorldBounds();
			if (mesh.frustumCulling && !bounds.inFrustum(projection)) scene.stats.culledMeshes++;
			else {
				var mirrored = world.determinant < 0;
				items.push({mesh:mesh, depth:-view.transformVector(bounds.center()).z, order:order++, mirrored:mirrored,
					key:MeshBatch3D.materialKey(mesh.material, mirrored, mesh.receiveShadow)});
				scene.stats.visibleMeshes++;
			}
		}
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
			TextureBridge3D.validateWrap(material, source);
			if (batch != null && batch.key != item.key) { submit(batch, projection, scene, renderer, guard); scene.stats.split("material"); batch = null; }
			if (batch == null) batch = new MeshBatch3D(material, item.mirrored, info.slots, mesh.receiveShadow);
			var world = mesh.getWorldVertices(), normals = material.lightingEnabled ? mesh.getWorldNormals() : null;
			var remap:Map<Int, Int> = [];
			var indices = mesh.geometry.indices;
			for (triangle in 0...Std.int(indices.length / 3)) {
				var textureId = batch.textures.indexOf(source);
				var fullTexture = textureId < 0 && batch.textures.length >= batch.slots;
				var fullVertices = Std.int(batch.vertices.length / batch.floatsPerVertex) + 3 > MeshBatch3D.MAX_VERTICES;
				// 同样限制索引内存，避免只有三个顶点的超多重复三角形无限扩大批次。
				var fullIndices = batch.indices.length + 3 > 196605;
				if (fullTexture || fullVertices || fullIndices) {
					submit(batch, projection, scene, renderer, guard); scene.stats.split(fullTexture ? "textures" : "capacity");
					batch = new MeshBatch3D(material, item.mirrored, info.slots, mesh.receiveShadow); remap.clear(); textureId = -1;
				}
				if (textureId < 0) { textureId = batch.textures.length; batch.textures.push(source); }
				for (corner in 0...3) {
					var index = indices[triangle * 3 + corner], mapped = remap.get(index);
					if (mapped == null) { mapped = batch.vertex(mesh, index, textureId, world, source, normals); remap.set(index, mapped); }
					batch.indices.push(mapped);
				}
			}
		}
		if (batch != null) submit(batch, projection, scene, renderer, guard);
	}

	private function submit(batch:MeshBatch3D, projection:Matrix3D, scene:Scene3D, renderer:OpenGLRenderer, guard:RenderStateGuard3D):Void {
		if (batch.indices.length == 0) return;
		var key = programKey(batch.declarations, batch.fragmentCode, scene.multiTextureEnabled, batch.lit);
		var info = programs.get(key);
		gl.useProgram(info.program); gl.uniformMatrix4fv(info.location("uViewProjection"), false, floatData(projection.rawData));
		gl.uniform1f(info.location("uAlphaMode"), batch.alphaMode);
		gl.uniform1f(info.location("uAlphaCutoff"), batch.alphaCutoff);
		if (!batch.lit) gl.uniform1f(info.location("uLinearBaseColor"), batch.colorMultiplyLinear ? 1 : 0);
		if (batch.lit) applyLighting(info, scene, batch.receiveShadow);
		// 描述与位置在链接后缓存，缺省值仍逐批重置，防止材质参数串用。
		for (uniform in info.customUniforms) {
			var values = batch.uniforms.get(uniform.name);
			if (values == null) values = uniform.zero;
			if (values.length != uniform.length) throw "自定义 uniform 数值长度与 Shader 声明不一致：" + uniform.name;
			var location = uniform.location;
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
			gl.bindTexture(gl.TEXTURE_2D, TextureBridge3D.handle(texture)); guard.rememberTexture(texture);
			TextureBridge3D.applySampler(texture, batch.smoothing, batch.wrapU, batch.wrapV, batch.minSmoothing);
			gl.uniform1i(info.location("uSampler" + slot), slot);
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
		var stride = batch.floatsPerVertex*4;
		gl.vertexAttribPointer(0, 3, gl.FLOAT, false, stride, 0); gl.vertexAttribPointer(1, 2, gl.FLOAT, false, stride, 12);
		gl.vertexAttribPointer(2, 1, gl.FLOAT, false, stride, 20); gl.vertexAttribPointer(3, 4, gl.FLOAT, false, stride, 24);
		if (batch.lit) { gl.enableVertexAttribArray(4); gl.vertexAttribPointer(4, 3, gl.FLOAT, false, stride, 40); }
		else if (frameNormals) gl.disableVertexAttribArray(4);
		gl.drawElements(gl.TRIANGLES, batch.indices.length, gl.UNSIGNED_SHORT, 0);
		scene.stats.drawCalls++; scene.stats.triangles += Std.int(batch.indices.length / 3);
		scene.stats.uploadedBytes += batch.vertices.length * 4 + batch.indices.length * 2;
		scene.stats.textureSlots = Std.int(Math.max(scene.stats.textureSlots, batch.textures.length));
		ContextStats.statsDrawCall(); ContextStats.statsVertexCount(batch.indices.length);
	}

	/** 颜色均在线性空间累加；阴影只衰减方向光，不压暗环境光。 */
	private function applyLighting(info:Program3DInfo, scene:Scene3D, receive:Bool):Void {
		var ambient = linearColor(scene.ambientColor, scene.ambientIntensity), light = scene.light;
		gl.uniform3f(info.location("uAmbientColor"), ambient[0],ambient[1],ambient[2]);
		if (light != null && light.isWorldVisible()) {
			var color = linearColor(light.color, light.intensity), direction = light.getWorldDirection();
			gl.uniform3f(info.location("uLightColor"), color[0],color[1],color[2]);
			gl.uniform3f(info.location("uLightDirection"), direction.x,direction.y,direction.z);
		} else {
			gl.uniform3f(info.location("uLightColor"), 0,0,0); gl.uniform3f(info.location("uLightDirection"), 0,-1,0);
		}
		if (frameShadow) {
			var slot = supportedSlots - 1;
			gl.activeTexture(gl.TEXTURE0 + slot); gl.bindTexture(gl.TEXTURE_2D, shadowPass.texture);
			gl.uniform1i(info.location("uShadowMap"), slot);
			gl.uniformMatrix4fv(info.location("uLightViewProjection"), false, floatData(shadowPass.matrix.rawData));
			gl.uniform1f(info.location("uReceiveShadow"), receive ? 1 : 0);
			gl.uniform1f(info.location("uShadowBias"), light.shadowBias); gl.uniform1f(info.location("uShadowSlopeBias"), light.shadowSlopeBias);
		}
	}
	private static function linearColor(color:Int, intensity:Float):Array<Float> {
		var result:Array<Float> = [];
		for (shift in [16,8,0]) {
			var value = ((color >> shift) & 255)/255.;
			result.push((value <= 0.04045 ? value/12.92 : Math.pow((value+0.055)/1.055,2.4))*intensity);
		}
		return result;
	}

	private function drawComposite(scene:Scene3D, display:Scene3DDisplay, event:RenderEvent, renderer:OpenGLRenderer):Void {
		gl.disable(gl.DEPTH_TEST); gl.depthMask(false); gl.disable(gl.CULL_FACE); gl.enable(gl.BLEND);
		gl.blendEquation(gl.FUNC_ADD); gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA); gl.useProgram(composite.program);
		gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, target.texture);
		gl.uniform1i(composite.location("uSampler0"), 0);
		var matrix = renderer.getMatrix(event.objectMatrix), values = new Float32Array(16);
		for (i in 0...16) values[i] = matrix[i];
		gl.uniformMatrix4fv(composite.location("uMatrix"), false, values);
		var color = renderer.__getColorTransform(event.objectColorTransform);
		gl.uniform4f(composite.location("uColorMultiplier"), color.redMultiplier, color.greenMultiplier, color.blueMultiplier, color.alphaMultiplier);
		gl.uniform4f(composite.location("uColorOffset"), color.redOffset/255, color.greenOffset/255, color.blueOffset/255, color.alphaOffset/255);
		gl.uniform1f(composite.location("uAlpha"), renderer.__getAlpha(display.__worldAlpha));
		var w = scene.width, h = scene.height;
		var vertices:Array<Float> = [0,0,0,0,1, w,0,0,1,1, w,h,0,1,0, 0,0,0,0,1, w,h,0,1,0, 0,h,0,0,0];
		gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer); gl.bufferData(gl.ARRAY_BUFFER, floatData(vertices), gl.STREAM_DRAW);
		gl.enableVertexAttribArray(0); gl.enableVertexAttribArray(1); gl.disableVertexAttribArray(2); gl.disableVertexAttribArray(3);
		if (frameNormals) gl.disableVertexAttribArray(4);
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
		if (shadowPass != null) shadowPass.abandonContext(); shadowPass = null;
		frameShadow = false; frameSlots = 1;
		capabilitiesReady = false; gl = null; vertexBuffer = null; indexBuffer = null; composite = null; target = null; programs.clear(); lastVersion = -1;
		if (white != null) white.dispose(); white = null;
	}
	#if (js && html5)
	private function onContextChange(event:js.html.Event):Void { abandonContext(); }
	private function removeContextListeners():Void {
		if (contextCanvas == null) return;
		contextCanvas.removeEventListener("webglcontextlost", onContextChange);
		contextCanvas.removeEventListener("webglcontextrestored", onContextChange);
		contextCanvas = null;
	}
	#end
	public function dispose():Void {
		#if (js && html5)
		removeContextListeners();
		#end
		if (gl != null && !gl.isContextLost()) {
			if (shadowPass != null) shadowPass.dispose();
			if (target != null) target.dispose();
			if (vertexBuffer != null) gl.deleteBuffer(vertexBuffer);
			if (indexBuffer != null) gl.deleteBuffer(indexBuffer);
			if (composite != null) gl.deleteProgram(composite.program);
			for (info in programs) gl.deleteProgram(info.program);
		}
		abandonContext();
	}
}
