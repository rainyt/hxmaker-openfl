package hx.render3d.openfl;

import haxe.Json;
import hx.display.Scene3D;
import hx.display3d.Node3D;
import hx.light.PointLight3D;
import hx.light.SpotLight3D;
import hx.display3d.MeshObject;
import hx.material.Material3D;
import hx.material.AlphaMode3D;
import hx.material.BlendMode3D;
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
	private var bloomComposite:Program3DInfo;
	private var capabilitiesReady:Bool = false;
	private var maxTargetWidth:Int = 1;
	private var maxTargetHeight:Int = 1;
	#if (js && html5)
	private var contextCanvas:js.html.CanvasElement;
	#end
	private var target:Scene3DRenderTarget;
	private var softDepth:Scene3DRenderTarget;
	private var frameSoft:Bool = false;
	private var softFailure:String = "";
	private var fragmentDepthPrecision:Bool = true;
	private var bloomPass:BloomPass3D;
	private var bloomReady:Bool = false;
	private var bloomFailure:String = "";
	private var white:openfl.display.BitmapData;
	private var programs:Map<String, Program3DInfo> = [];
	private var supportedSlots:Int = 1;
	private var frameSlots:Int = 1;
	private var frameNormals:Bool = false;
	private var frameAttributes:Int = 4;
	private var frameLights:Array<hx.light.Light3D> = [];
	private var frameShadow:Bool = false;
	private var frameIbl:Bool = false;
	private var environmentSlot:Int = 0;
	private var frameEnvironment:hx.light.Environment3D;
	private var sceneShadowFilter:Int = 0;
	private var maxAttributes:Int = 4;
	private var depthTextures:Bool = false;
	private var sizedDepth:Bool = false;
	private var shadowPass:ShadowPass3D;
	private var vertexArrays:VertexArrayBridge3D;
	private var lastVersion:Int = -1;
	private var lastSettings:String;
	public function new() {}

	public function render(scene:Scene3D, display:Scene3DDisplay, event:RenderEvent):Void {
		if (scene.isDisposed || scene.width <= 0 || scene.height <= 0) return;
		var renderer:OpenGLRenderer = cast event.renderer;
		if (renderer.gl == null || renderer.gl.isContextLost()) return;
		var timed = scene.profilingEnabled, started = timed ? profileClock() : 0.;
		var shadowTime = 0., mainTime = 0., compositeTime = 0., postTime = 0., mark = 0.;
		var redrawn = false;
		// 恢复事件会使设备代次失效，正常帧不再同步探测缓冲句柄。
		if (gl != renderer.gl) abandonContext();
		gl = renderer.gl;
		if (!capabilitiesReady) readCapabilities();
		if (!Math3D.finite(scene.renderScale) || scene.renderScale <= 0 || !Math3D.finite(scene.backgroundAlpha)
			|| scene.backgroundAlpha < 0 || scene.backgroundAlpha > 1) throw "三维分辨率或背景透明度无效";
		var ratio:Float = renderer.__pixelRatio;
		if (!Math3D.finite(ratio) || ratio <= 0) ratio = 1;
		var w = scene.width * ratio * scene.renderScale, h = scene.height * ratio * scene.renderScale;
		var reduction = Math.min(1, Math.min(maxTargetWidth / w, maxTargetHeight / h));
		var width = Std.int(Math.max(1, Math.floor(w * reduction))), height = Std.int(Math.max(1, Math.floor(h * reduction)));
		var targetChanged = target == null || target.width != width || target.height != height;
		var settingValues:Array<Dynamic> = [scene.multiTextureEnabled ? 1 : 0, scene.backgroundColor, scene.backgroundAlpha,
			scene.camera == null ? 0 : scene.camera.fieldOfView, scene.camera == null ? 0 : scene.camera.near, scene.camera == null ? 0 : scene.camera.far, scene.lightingKey(), scene.bloom.settingsKey()];
		var settings = settingValues.join(":");
		var needsRedraw = targetChanged || lastVersion != scene.contentVersion || settings != lastSettings;
		// 缓存合成不遍历网格，也不触及主通道和阴影的 GL 状态。
		var meshes:Array<MeshObject> = [];
		if (needsRedraw) {
			meshes = collectMeshes(scene.root);
			frameNormals = false; frameAttributes = 4;
			for (mesh in meshes) if (mesh.material.lightingEnabled) {
				frameNormals = true; frameAttributes = Std.int(Math.max(frameAttributes, mesh.material.pbrEnabled && mesh.material.pbrMapMask != 0 ? 7 : 5));
			}
			if (frameAttributes > maxAttributes) throw "当前设备不支持所需的 PBR UV 或切线顶点属性";
		}
		var guard = new RenderStateGuard3D(renderer, frameAttributes, !needsRedraw, vertexArrays, timed);
		try {
			// 首次目标创建、阴影目标创建、纹理上传和采样恢复都会使用槽位 0。
			guard.activateTexture(0);
			if (vertexBuffer == null) initialize();
			if (targetChanged) {
				if (target != null) target.dispose();
				target = null; target = new Scene3DRenderTarget(gl, width, height); lastVersion = -1;
			}
			scene.stats.targetWidth = width; scene.stats.targetHeight = height;
			if (needsRedraw) {
				redrawn = true; scene.stats.reset(); frameLights = scene.getActiveLights(); scene.stats.targetBytes = width * height * 6;
				if (timed) mark = profileClock();
				frameShadow = scene.camera != null && shadowPass.render(scene, meshes, supportedSlots, guard, renderer.__context3D, white);
				if (timed) { shadowTime = profileClock() - mark; mark = profileClock(); }
				sceneShadowFilter = frameShadow ? cast scene.light.shadowFilter : 0;
				frameSlots = supportedSlots - (frameShadow ? 1 : 0);
				prepareEnvironment(scene, meshes);
				prepareSoftDepth(scene, meshes, renderer, guard, width, height);
				gl.bindFramebuffer(gl.FRAMEBUFFER, target.framebuffer); gl.viewport(0, 0, width, height);
				gl.disable(gl.SCISSOR_TEST); gl.disable(gl.STENCIL_TEST); gl.disable(gl.POLYGON_OFFSET_FILL); gl.disable(gl.SAMPLE_ALPHA_TO_COVERAGE);
				gl.colorMask(true, true, true, true); gl.depthMask(true); gl.depthRange(0, 1);
				var alpha = scene.backgroundAlpha;
				gl.clearColor(((scene.backgroundColor >> 16) & 255)/255.*alpha, ((scene.backgroundColor >> 8) & 255)/255.*alpha, (scene.backgroundColor & 255)/255.*alpha, alpha);
				gl.clearDepth(1); gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
				if (scene.camera != null) drawScene(scene, meshes, renderer, guard);
				if (timed) { mainTime = profileClock() - mark; mark = profileClock(); }
				prepareBloom(scene, guard, width, height);
				if (timed) postTime = profileClock() - mark;
				lastVersion = scene.contentVersion; lastSettings = settings;
			}
			if (timed) mark = profileClock();
			guard.restoreTarget(); drawComposite(scene, display, event, renderer, guard);
			if (timed) compositeTime = profileClock() - mark;
		} catch (error:Dynamic) { guard.restore(); throw error; }
		guard.restore();
		var stats = scene.stats; stats.renderId++; if (redrawn) stats.redrawId++;
		stats.redrawThisFrame = redrawn; stats.profileReady = timed;
		stats.renderCpuMs = timed ? profileClock() - started : 0;
		stats.shadowCpuMs = shadowTime; stats.mainCpuMs = mainTime;
		stats.compositeCpuMs = compositeTime; stats.postProcessCpuMs = postTime;
		stats.stateFlushCpuMs = guard.flushCpuMs; stats.stateSnapshotCpuMs = guard.snapshotCpuMs;
		stats.stateRestoreCpuMs = guard.restoreCpuMs; stats.samplerRestoreCpuMs = guard.samplerRestoreCpuMs;
		stats.stateCpuMs = guard.flushCpuMs+guard.snapshotCpuMs+guard.restoreCpuMs+guard.samplerRestoreCpuMs;
		stats.stateQueryCount = guard.queryCount; stats.stateTextureSlots = guard.textureSlotCount;
		stats.stateCompositeOnly = guard.compositeOnly; stats.stateVao = guard.isolatedVertexArray;
	}

	/** 仅在场景显式开启性能统计时调用，不在普通路径读取时钟。 */
	private static function profileClock():Float {
		#if (js && html5)
		return js.Browser.window.performance.now();
		#else
		return haxe.Timer.stamp() * 1000;
		#end
	}

	private function readCapabilities():Void {
		var count:Int = gl.getParameter(gl.MAX_TEXTURE_IMAGE_UNITS);
		supportedSlots = Std.int(Math.min(16, Math.min(count, gl.getParameter(gl.MAX_COMBINED_TEXTURE_IMAGE_UNITS))));
		maxAttributes = gl.getParameter(gl.MAX_VERTEX_ATTRIBS);
		if (supportedSlots < 1 || maxAttributes < 4) throw "当前设备不支持基础三维顶点或纹理输入";
		var size = Math.min(gl.getParameter(gl.MAX_TEXTURE_SIZE), gl.getParameter(gl.MAX_RENDERBUFFER_SIZE));
		var viewport:Dynamic = gl.getParameter(gl.MAX_VIEWPORT_DIMS);
		maxTargetWidth = Std.int(Math.min(size, viewport[0])); maxTargetHeight = Std.int(Math.min(size, viewport[1]));
		var version = Std.string(gl.getParameter(gl.VERSION));
		var depthPrecision = (version.indexOf("WebGL") < 0 && version.indexOf("OpenGL ES") < 0) ? null : gl.getShaderPrecisionFormat(gl.FRAGMENT_SHADER, gl.HIGH_FLOAT);
		fragmentDepthPrecision = depthPrecision == null ? version.indexOf("WebGL") < 0 && version.indexOf("OpenGL ES") < 0 : depthPrecision.precision > 0;
		sizedDepth = version.indexOf("WebGL 2") >= 0 || version.indexOf("OpenGL ES 3") >= 0;
		if (version.indexOf("WebGL") >= 0) depthTextures = sizedDepth || gl.getExtension("WEBGL_depth_texture") != null;
		else if (version.indexOf("OpenGL ES 2") >= 0) depthTextures = gl.getExtension("GL_OES_depth_texture") != null || gl.getExtension("OES_depth_texture") != null;
		else depthTextures = true;
		vertexArrays = new VertexArrayBridge3D(gl, sizedDepth);
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

	/** IBL 预留一个公共纹理槽；不增加绘制通道，也不拆分相同参数的 PBR 网格。 */
	private function prepareEnvironment(scene:Scene3D, meshes:Array<MeshObject>):Void {
		frameIbl = false; frameEnvironment = scene.environment;
		if (frameEnvironment == null || !frameEnvironment.enabled || frameEnvironment.intensity == 0) return;
		var needed = false, auxiliary = 0;
		for (mesh in meshes) {
			if (mesh.material.lightingEnabled && mesh.material.pbrEnabled) needed = true;
			auxiliary = Std.int(Math.max(auxiliary, mesh.material.textureUniformNames().length));
		}
		if (!needed) { scene.stats.environmentStatus = "无 PBR 材质"; return; }
		if (frameSlots - auxiliary < 2) { scene.stats.environmentStatus = "回退：纹理槽位不足"; return; }
		var source = TextureBridge3D.source(frameEnvironment.atlas, white);
		if (source.width > maxTargetWidth || source.height > maxTargetHeight) {
			scene.stats.environmentStatus = "回退：环境图集超过设备尺寸限制"; return;
		}
		if (!fragmentDepthPrecision && frameEnvironment.radianceRange > 60000) {
			scene.stats.environmentStatus = "回退：环境辐射范围超过片元精度"; return;
		}
		frameSlots--; environmentSlot = frameSlots; frameIbl = true;
		scene.stats.environmentStatus = "启用";
	}

	/** 借用 Assets 的图集纹理；上下文恢复时沿用 OpenFL 的重新上传与采样状态恢复协议。 */
	private function applyEnvironment(info:Program3DInfo, scene:Scene3D, renderer:OpenGLRenderer, guard:RenderStateGuard3D):Void {
		guard.activateTexture(environmentSlot);
		var source = TextureBridge3D.source(frameEnvironment.atlas, white);
		var texture = TextureBridge3D.resolve(source, renderer.__context3D);
		var size = TextureBridge3D.uvSize(source);
		scene.stats.environmentTextureBytes = Std.int(size[0] * size[1] * 4);
		gl.bindTexture(gl.TEXTURE_2D, TextureBridge3D.handle(texture)); guard.rememberTexture(texture);
		TextureBridge3D.applySampler(texture, true);
		gl.uniform1i(info.location("uIblAtlas"), environmentSlot);
		gl.uniform2f(info.location("uIblAtlasSize"), size[0], size[1]);
		gl.uniform4f(info.location("uIblLayout"), frameEnvironment.layerWidth, frameEnvironment.layerHeight,
			frameEnvironment.levels, frameEnvironment.radianceRange);
		var angle = (frameEnvironment.rotation % 360) * Math.PI / 180;
		gl.uniform3f(info.location("uIblTransform"), Math.cos(angle), Math.sin(angle), frameEnvironment.intensity);
	}

	/** 单独预绘制不透明和裁剪物体，主目标不会同时挂接被采样的深度纹理。 */
	private function prepareSoftDepth(scene:Scene3D, meshes:Array<MeshObject>, renderer:OpenGLRenderer, guard:RenderStateGuard3D, width:Int, height:Int):Void {
		frameSoft = false;
		var needed = false, auxiliary = 0;
		for (mesh in meshes) {
			if (mesh.material.alphaMode == AlphaMode3D.BLEND && mesh.material.softParticleDistance > 0) needed = true;
			auxiliary = Std.int(Math.max(auxiliary, mesh.material.textureUniformNames().length));
		}
		if (!needed || scene.camera == null) {
			if (softDepth != null) softDepth.dispose(); softDepth = null; softFailure = ""; return;
		}
		var reason = !depthTextures ? "设备不支持深度纹理" : (!fragmentDepthPrecision ? "片元高精度不足" : (frameSlots - 1 - auxiliary < 1 ? "纹理槽位不足" : softFailure));
		if (reason != "") {
			if (softDepth != null) softDepth.dispose(); softDepth = null;
			scene.stats.softParticleStatus = "回退：" + reason; return;
		}
		if (softDepth == null || softDepth.width != width || softDepth.height != height) {
			if (softDepth != null) softDepth.dispose(); softDepth = null;
			try { guard.activateTexture(0); softDepth = new Scene3DRenderTarget(gl,width,height,true,sizedDepth); }
			catch (error:Dynamic) { softFailure = Std.string(error); scene.stats.softParticleStatus = "回退：" + softFailure; return; }
		}
		frameSlots--;
		gl.bindFramebuffer(gl.FRAMEBUFFER,softDepth.framebuffer); gl.viewport(0,0,width,height);
		gl.disable(gl.SCISSOR_TEST); gl.disable(gl.STENCIL_TEST); gl.disable(gl.POLYGON_OFFSET_FILL); gl.disable(gl.SAMPLE_ALPHA_TO_COVERAGE);
		gl.colorMask(true,true,true,true); gl.depthMask(true); gl.depthRange(0,1); gl.clearDepth(1); gl.clearColor(0,0,0,0);
		gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
		var opaque = [for (mesh in meshes) if (mesh.material.alphaMode != AlphaMode3D.BLEND && mesh.material.depthWrite) mesh];
		drawScene(scene,opaque,renderer,guard);
		var stats = scene.stats;
		stats.softDepthDrawCalls = stats.drawCalls; stats.softDepthTriangles = stats.triangles; stats.softDepthUploadedBytes = stats.uploadedBytes;
		stats.softDepthTargetBytes = width * height * 6; stats.softParticleStatus = "启用";
		stats.drawCalls = stats.triangles = stats.uploadedBytes = stats.visibleMeshes = stats.culledMeshes = stats.textureSlots = 0; stats.splitReasons.clear();
		frameSoft = true;
	}

	private function prepareBloom(scene:Scene3D, guard:RenderStateGuard3D, width:Int, height:Int):Void {
		bloomReady = false;
		if (!scene.bloom.enabled) {
			if (bloomPass != null) bloomPass.dispose(); bloomPass = null; bloomFailure = ""; return;
		}
		if (supportedSlots < 2 || bloomFailure != "") {
			scene.stats.bloomStatus = "回退：" + (supportedSlots < 2 ? "纹理槽位不足" : bloomFailure); return;
		}
		try {
			guard.activateTexture(0);
			if (bloomComposite == null) bloomComposite = createComposite(true);
			if (bloomPass == null) bloomPass = new BloomPass3D(gl);
			bloomPass.render(target.texture,width,height,scene.bloom,guard,frameNormals);
			bloomReady = true; scene.stats.bloomDrawCalls = 3; scene.stats.bloomTargetBytes = bloomPass.targetBytes; scene.stats.bloomStatus = "启用";
		} catch (error:Dynamic) {
			if (bloomPass != null) bloomPass.dispose(); bloomPass = null;
			bloomFailure = Std.string(error); scene.stats.bloomStatus = "回退：" + bloomFailure;
		}
	}

	private function createComposite(withBloom:Bool):Program3DInfo {
		return new Program3DInfo(gl, MultiTextureShader3D.compile(gl,
			"attribute vec3 aPosition;attribute vec2 aUV;uniform mat4 uMatrix;varying mediump vec2 vUV;void main(){gl_Position=uMatrix*vec4(aPosition,1.0);vUV=aUV;}",
			"precision mediump float;varying mediump vec2 vUV;uniform sampler2D uSampler0;uniform vec4 uColorMultiplier;uniform vec4 uColorOffset;uniform float uAlpha;"
			+ (withBloom ? "uniform sampler2D uBloom;uniform float uBloomIntensity;" : "")
			// 将超过覆盖率的 RGB 单独保留，包括 alpha 为零的加法光效。
			+ "void main(){vec4 color=texture2D(uSampler0,vUV);vec3 emission=max(color.rgb-vec3(color.a),vec3(0.0));"
			+ "color.rgb=min(color.rgb,vec3(color.a));if(color.a>0.0){color.rgb/=color.a;}else{color.rgb=vec3(0.0);}"
			+ "color=clamp(color*uColorMultiplier+uColorOffset,0.0,1.0);color.a*=uAlpha;"
			+ (withBloom ? "emission+=texture2D(uBloom,vUV).rgb*uBloomIntensity;" : "")
			+ "emission*=max(uColorMultiplier.rgb,vec3(0.0))*max(uColorMultiplier.a,0.0)*uAlpha;"
			+ "gl_FragColor=vec4(color.rgb*color.a+emission,color.a);}"), 1, false);
	}

	private function initialize():Void {
		composite = createComposite(false);
		vertexBuffer = gl.createBuffer(); indexBuffer = gl.createBuffer();
		white = new openfl.display.BitmapData(1, 1, true, 0xffffffff);
		shadowPass = new ShadowPass3D(gl, depthTextures, sizedDepth, Std.int(Math.min(maxTargetWidth, maxTargetHeight)));
	}

	private function programKey(declarations:String, code:String, multi:Bool, lit:Bool, uvCode:String, textureNames:Array<String>, soft:Bool, pbr:Bool):String {
		return Json.stringify([pbr && frameIbl ? 1 : 0, pbr ? 1 : 0, soft ? 1 : 0, uvCode, textureNames.join(","), declarations, code, Std.string(frameSlots), Std.string(multi ? frameSlots : 1), Std.string(lit), Std.string(lit && frameShadow), Std.string(frameShadow ? sceneShadowFilter : 0)]);
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
		var key = programKey(material.fragmentDeclarations, material.fragmentCode, multi, material.lightingEnabled, material.fragmentUVCode, material.textureUniformNames(), frameSoft && material.alphaMode == AlphaMode3D.BLEND && material.softParticleDistance > 0, material.lightingEnabled && material.pbrEnabled);
		var info = programs.get(key);
		if (info != null) return info;
		var textureNames = material.textureUniformNames();
		var slots = Std.int(Math.min(multi ? frameSlots : 1, frameSlots - textureNames.length));
		if (slots < 1) throw "当前三维材质的辅助纹理超出设备可用槽位";
		var program:GLProgram = null, lightSlots = material.lightingEnabled ? Scene3D.MAX_LIGHTS : 0;
		while (program == null) {
			try { program = MultiTextureShader3D.create(gl, slots, material.fragmentDeclarations, material.fragmentCode, material.lightingEnabled, frameShadow, material.fragmentUVCode, textureNames, frameSoft && material.alphaMode == AlphaMode3D.BLEND && material.softParticleDistance > 0, sceneShadowFilter == 1, lightSlots, material.pbrEnabled, frameIbl); }
			catch (error:Dynamic) {
				if (slots <= 1) {
					if (lightSlots <= 1) throw error;
					lightSlots--;
					trace("三维光照 Shader 回退，当前灯光上限：" + lightSlots + "，原因：" + Std.string(error));
					continue;
				}
				trace("三维多纹理 Shader 回退，当前槽位数：" + slots + "，原因：" + Std.string(error));
				slots = Std.int(Math.max(1, Math.floor(slots / 2)));
			}
		}
		info = new Program3DInfo(gl, program, slots, true, textureNames, lightSlots); programs.set(key, info); return info;
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
			if (aBlend) {
				var priority = Reflect.compare(a.mesh.renderOrder, b.mesh.renderOrder);
				if (priority != 0) return priority;
				if (a.depth != b.depth) return a.depth > b.depth ? -1 : 1; }
			else { var compare = Reflect.compare(a.key, b.key); if (compare != 0) return compare; if (a.depth != b.depth) return a.depth < b.depth ? -1 : 1; }
			return a.order - b.order;
		});
		var batch:MeshBatch3D = null;
		for (item in items) {
			var mesh = item.mesh, material = mesh.material, info = getProgram(material, scene.multiTextureEnabled);
			var source = TextureBridge3D.source(material.texture, white);
			// 先上传纹理并确定实际尺寸，后续才计算图集 UV。
			guard.activateTexture(0); TextureBridge3D.resolve(source, renderer.__context3D);
			TextureBridge3D.validateWrap(material, source);
			if (batch != null && batch.key != item.key) { submit(batch, projection, scene, renderer, guard); scene.stats.split("material"); batch = null; }
			if (batch == null) batch = new MeshBatch3D(material, item.mirrored, info.slots, mesh.receiveShadow);
			var world = mesh.getWorldVertices(), normals = material.lightingEnabled ? mesh.getWorldNormals() : null;
			var tangents = batch.normalMapped ? mesh.getWorldTangents() : null;
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
					if (mapped == null) { mapped = batch.vertex(mesh, index, textureId, world, source, normals, tangents); remap.set(index, mapped); }
					batch.indices.push(mapped);
				}
			}
		}
		if (batch != null) submit(batch, projection, scene, renderer, guard);
	}

	private function submit(batch:MeshBatch3D, projection:Matrix3D, scene:Scene3D, renderer:OpenGLRenderer, guard:RenderStateGuard3D):Void {
		if (batch.indices.length == 0) return;
		var key = programKey(batch.declarations, batch.fragmentCode, scene.multiTextureEnabled, batch.lit, batch.uvCode, batch.textureNames, frameSoft && batch.alphaMode == AlphaMode3D.BLEND && batch.softParticleDistance > 0, batch.pbr);
		var info = programs.get(key);
		gl.useProgram(info.program); gl.uniformMatrix4fv(info.location("uViewProjection"), false, floatData(projection.rawData));
		gl.uniform1f(info.location("uAlphaMode"), batch.alphaMode);
		gl.uniform1f(info.location("uAlphaCutoff"), batch.alphaCutoff);
		if (!batch.lit) gl.uniform1f(info.location("uLinearBaseColor"), batch.colorMultiplyLinear ? 1 : 0);
		if (batch.lit) applyLighting(info, scene, batch.receiveShadow, guard);
		if (batch.pbr && frameIbl) applyEnvironment(info, scene, renderer, guard);
		if (batch.uvCode != "") {
			var source = TextureBridge3D.source(batch.baseTexture, white);
			guard.activateTexture(0); TextureBridge3D.resolve(source, renderer.__context3D);
			var region = textureRegion(batch.baseTexture, source);
			gl.uniform4f(info.location("uBaseUVRect"), region[0], region[1], region[2], region[3]);
			gl.uniform4f(info.location("uBaseUVClamp"), region[4], region[5], region[6], region[7]);
		}
		// 辅助纹理占用主贴图槽位之后的位置，阴影槽位仍保留在设备末尾。
		for (i in 0...batch.textureNames.length) {
			var name = batch.textureNames[i], bitmap = batch.textureUniforms.get(name), slot = info.slots + i;
			var source = TextureBridge3D.source(bitmap, white);
			guard.activateTexture(slot);
			var texture = TextureBridge3D.resolve(source, renderer.__context3D);
			gl.bindTexture(gl.TEXTURE_2D, TextureBridge3D.handle(texture)); guard.rememberTexture(texture);
			// 辅助贴图只使用 CLAMP，重复由 Shader 在区域内部完成。
			if (frameIbl && batch.pbr && source == TextureBridge3D.source(frameEnvironment.atlas, white))
				throw "IBL 数据图集不能同时作为 PBR 辅助纹理";
			if (batch.textures.indexOf(source) >= 0 && (batch.wrapU != 33071 || batch.wrapV != 33071))
				throw "同一底层纹理同时作为主贴图和辅助贴图时，主贴图必须使用 CLAMP";
			var sampling = batch.pbr && StringTools.startsWith(name, "uPbr") ? batch.uniforms.get(name + "Sampler") : null;
			var smoothing = sampling == null ? batch.smoothing : sampling[0] > 0.5;
			var minSmoothing = sampling == null ? batch.minSmoothing : sampling[1] > 0.5;
			// 同一底层图片共享 GL 采样状态；不同过滤方式不能在一次绘制中并存。
			if (batch.textures.indexOf(source) >= 0 && (smoothing != batch.smoothing || minSmoothing != batch.minSmoothing))
				throw "同一图片作为基础色和 PBR 数据贴图时必须使用相同过滤设置";
			for (other in batch.textureNames) {
				if (other == name || TextureBridge3D.source(batch.textureUniforms.get(other), white) != source) continue;
				var previous = batch.pbr && StringTools.startsWith(other, "uPbr") ? batch.uniforms.get(other + "Sampler") : null;
				if (smoothing != (previous == null ? batch.smoothing : previous[0] > 0.5)
					|| minSmoothing != (previous == null ? batch.minSmoothing : previous[1] > 0.5))
					throw "同一图片绑定到多个材质贴图时必须使用相同过滤设置";
			}
			TextureBridge3D.applySampler(texture, smoothing, 33071, 33071, minSmoothing);
			gl.uniform1i(info.location(name), slot);
			var region = textureRegion(bitmap, source);
			batch.uniforms.set(name + "Rect", region.slice(0, 4));
			batch.uniforms.set(name + "Clamp", region.slice(4, 8));
		}
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
			if (frameIbl && batch.pbr && batch.textures[slot] == TextureBridge3D.source(frameEnvironment.atlas, white))
				throw "IBL 数据图集不能同时作为 PBR 基础色纹理";
			guard.activateTexture(slot);
			var texture = TextureBridge3D.resolve(batch.textures[slot], renderer.__context3D);
			gl.bindTexture(gl.TEXTURE_2D, TextureBridge3D.handle(texture)); guard.rememberTexture(texture);
			TextureBridge3D.applySampler(texture, batch.smoothing, batch.wrapU, batch.wrapV, batch.minSmoothing);
			gl.uniform1i(info.location("uSampler" + slot), slot);
		}
		if (frameSoft && batch.alphaMode == AlphaMode3D.BLEND && batch.softParticleDistance > 0) {
			guard.activateTexture(frameSlots); gl.bindTexture(gl.TEXTURE_2D, softDepth.depthTexture);
			gl.uniform1i(info.location("uSceneDepth"), frameSlots);
			gl.uniform4f(info.location("uSoftParams"), scene.camera.near, scene.camera.far, target.width, target.height);
			gl.uniform1f(info.location("uSoftDistance"), batch.softParticleDistance);
		}
		if (batch.depthTest) gl.enable(gl.DEPTH_TEST); else gl.disable(gl.DEPTH_TEST);
		gl.depthFunc(gl.LEQUAL); gl.depthMask(batch.depthWrite);
		if (batch.cullMode == CullMode3D.NONE) gl.disable(gl.CULL_FACE);
		else { gl.enable(gl.CULL_FACE); gl.cullFace(batch.cullMode == CullMode3D.BACK ? gl.BACK : gl.FRONT); }
		gl.frontFace(batch.mirrored ? gl.CW : gl.CCW);
		if (batch.alphaMode == AlphaMode3D.BLEND) {
			gl.enable(gl.BLEND); gl.blendEquation(gl.FUNC_ADD);
			// 加法只累加预乘 RGB，保留目标 alpha，使透明离屏目标正确叠加到二维背景。
			if (batch.blendMode == BlendMode3D.ADD) gl.blendFuncSeparate(gl.ONE, gl.ONE, gl.ZERO, gl.ONE);
			else gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
		}
		else gl.disable(gl.BLEND);
		guard.bindVertexArray("main");
		gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer); gl.bufferData(gl.ARRAY_BUFFER, floatData(batch.vertices), gl.STREAM_DRAW);
		gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer); gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indexData(batch.indices), gl.STREAM_DRAW);
		for (i in 0...4) gl.enableVertexAttribArray(i);
		var stride = batch.floatsPerVertex*4;
		gl.vertexAttribPointer(0, 3, gl.FLOAT, false, stride, 0); gl.vertexAttribPointer(1, 2, gl.FLOAT, false, stride, 12);
		gl.vertexAttribPointer(2, 1, gl.FLOAT, false, stride, 20); gl.vertexAttribPointer(3, 4, gl.FLOAT, false, stride, 24);
		if (batch.lit) { gl.enableVertexAttribArray(4); gl.vertexAttribPointer(4, 3, gl.FLOAT, false, stride, 40); }
		else if (frameNormals || guard.isolatedVertexArray && maxAttributes > 4) gl.disableVertexAttribArray(4);
		if (batch.mapped) { gl.enableVertexAttribArray(6); gl.vertexAttribPointer(6, 2, gl.FLOAT, false, stride, 52); }
		else if (frameAttributes >= 7 || guard.isolatedVertexArray && maxAttributes >= 7) gl.disableVertexAttribArray(6);
		if (batch.normalMapped) { gl.enableVertexAttribArray(5); gl.vertexAttribPointer(5, 4, gl.FLOAT, false, stride, 60); }
		else if (frameAttributes >= 7 || guard.isolatedVertexArray && maxAttributes >= 7) gl.disableVertexAttribArray(5);
		gl.drawElements(gl.TRIANGLES, batch.indices.length, gl.UNSIGNED_SHORT, 0);
		scene.stats.drawCalls++; scene.stats.triangles += Std.int(batch.indices.length / 3);
		scene.stats.uploadedBytes += batch.vertices.length * 4 + batch.indices.length * 2;
		scene.stats.textureSlots = Std.int(Math.max(scene.stats.textureSlots, batch.textures.length + batch.textureNames.length + (frameIbl && batch.pbr ? 1 : 0) + (frameSoft && batch.alphaMode == AlphaMode3D.BLEND && batch.softParticleDistance > 0 ? 1 : 0)));
		ContextStats.statsDrawCall(); ContextStats.statsVertexCount(batch.indices.length);
	}

	/** 返回区域起点、大小和半像素内缩边界，兼容图集与底层填充。 */
	private function textureRegion(bitmap:hx.display.BitmapData, source:openfl.display.BitmapData):Array<Float> {
		var size = TextureBridge3D.uvSize(source), x = 0., y = 0., width = source.width * 1., height = source.height * 1.;
		if (bitmap != null && bitmap.rect != null) {
			x = bitmap.rect.x; y = bitmap.rect.y; width = bitmap.rect.width; height = bitmap.rect.height;
		}
		for (value in [x, y, width, height, size[0], size[1]])
			if (!Math3D.finite(value)) throw "三维特效贴图区域必须有限";
		if (size[0] <= 0 || size[1] <= 0 || width <= 0 || height <= 0 || x < 0 || y < 0 || x + width > source.width || y + height > source.height)
			throw "三维特效贴图区域无效";
		var insetX = Math.min(0.5, width * 0.5), insetY = Math.min(0.5, height * 0.5);
		return [x / size[0], y / size[1], width / size[0], height / size[1],
			(x + insetX) / size[0], (y + insetY) / size[1], (x + width - insetX) / size[0], (y + height - insetY) / size[1]];
	}

	/** 颜色均在线性空间累加；阴影只衰减主方向光，不压暗其他灯光。 */
	private function applyLighting(info:Program3DInfo, scene:Scene3D, receive:Bool, guard:RenderStateGuard3D):Void {
		var ambient = linearColor(scene.ambientColor, scene.ambientIntensity), light = scene.light;
		gl.uniform3f(info.location("uAmbientColor"), ambient[0],ambient[1],ambient[2]);
		var camera = scene.camera.getWorldPosition();
		gl.uniform3f(info.location("uCameraPosition"), camera.x, camera.y, camera.z);
		var lights = frameLights;
		scene.stats.activeLights = Std.int(Math.max(scene.stats.activeLights, Math.min(lights.length, info.lightSlots)));
		scene.stats.skippedLights = Std.int(Math.max(scene.stats.skippedLights, Math.max(0, lights.length - info.lightSlots)));
		var direction = light == null || light.isDisposed || light.scene != scene ? new hx.geom.Vector3D(0, -1, 0) : light.getWorldDirection();
		gl.uniform3f(info.location("uLightDirection"), direction.x, direction.y, direction.z);
		for (i in 0...info.lightSlots) {
			if (i >= lights.length) {
				gl.uniform4f(info.location("uSceneLightColor" + i), 0, 0, 0, 0);
				gl.uniform4f(info.location("uSceneLightPosition" + i), 0, 0, 0, 0);
				gl.uniform3f(info.location("uSceneLightDirection" + i), 0, -1, 0);
				gl.uniform3f(info.location("uSceneLightParams" + i), 1, 1, 0);
				continue;
			}
			var current = lights[i], color = linearColor(current.color, current.intensity);
			var m = current.getWorldMatrix().rawData, d = current.getWorldDirection();
			var point:PointLight3D = Std.isOfType(current, PointLight3D) ? cast current : null;
			var spot:SpotLight3D = Std.isOfType(current, SpotLight3D) ? cast current : null;
			gl.uniform4f(info.location("uSceneLightColor" + i), color[0], color[1], color[2], frameShadow && current == light ? 1 : 0);
			gl.uniform4f(info.location("uSceneLightPosition" + i), m[12], m[13], m[14], spot != null ? 2 : point != null ? 1 : 0);
			gl.uniform3f(info.location("uSceneLightDirection" + i), d.x, d.y, d.z);
			gl.uniform3f(info.location("uSceneLightParams" + i), point == null ? 1 : point.range,
				spot == null ? 1 : Math.cos(spot.innerAngle * Math.PI / 180),
				spot == null ? 0 : Math.cos(spot.outerAngle * Math.PI / 180));
		}
		if (frameShadow) {
			var slot = supportedSlots - 1;
			guard.activateTexture(slot); gl.bindTexture(gl.TEXTURE_2D, shadowPass.texture);
			gl.uniform1i(info.location("uShadowMap"), slot);
			if (sceneShadowFilter == 1) gl.uniform2f(info.location("uShadowTexelSize"), 1.0 / scene.stats.shadowMapSize, 1.0 / scene.stats.shadowMapSize);
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

	private function drawComposite(scene:Scene3D, display:Scene3DDisplay, event:RenderEvent, renderer:OpenGLRenderer, guard:RenderStateGuard3D):Void {
		var info = bloomReady ? bloomComposite : composite;
		gl.disable(gl.DEPTH_TEST); gl.depthMask(false); gl.disable(gl.CULL_FACE); gl.enable(gl.BLEND);
		gl.blendEquation(gl.FUNC_ADD); gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA); gl.useProgram(info.program);
		guard.activateTexture(0); gl.bindTexture(gl.TEXTURE_2D, target.texture);
		gl.uniform1i(info.location("uSampler0"), 0);
		if (bloomReady) {
			guard.activateTexture(1); gl.bindTexture(gl.TEXTURE_2D, bloomPass.texture);
			gl.uniform1i(info.location("uBloom"), 1);
			gl.uniform1f(info.location("uBloomIntensity"), scene.bloom.intensity);
		}
		var matrix = renderer.getMatrix(event.objectMatrix), values = new Float32Array(16);
		for (i in 0...16) values[i] = matrix[i];
		gl.uniformMatrix4fv(info.location("uMatrix"), false, values);
		var color = renderer.__getColorTransform(event.objectColorTransform);
		gl.uniform4f(info.location("uColorMultiplier"), color.redMultiplier, color.greenMultiplier, color.blueMultiplier, color.alphaMultiplier);
		gl.uniform4f(info.location("uColorOffset"), color.redOffset/255, color.greenOffset/255, color.blueOffset/255, color.alphaOffset/255);
		gl.uniform1f(info.location("uAlpha"), renderer.__getAlpha(display.__worldAlpha));
		var w = scene.width, h = scene.height;
		var vertices:Array<Float> = [0,0,0,0,1, w,0,0,1,1, w,h,0,1,0, 0,0,0,0,1, w,h,0,1,0, 0,h,0,0,0];
		guard.bindVertexArray("composite");
		gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer); gl.bufferData(gl.ARRAY_BUFFER, floatData(vertices), gl.STREAM_DRAW);
		gl.enableVertexAttribArray(0); gl.enableVertexAttribArray(1); gl.disableVertexAttribArray(2); gl.disableVertexAttribArray(3);
		if (frameNormals) gl.disableVertexAttribArray(4);
		if (frameAttributes >= 7) { gl.disableVertexAttribArray(5); gl.disableVertexAttribArray(6); }
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
		if (vertexArrays != null) vertexArrays.abandon(); vertexArrays = null;
		frameLights = [];
		if (shadowPass != null) shadowPass.abandonContext(); shadowPass = null;
		frameShadow = false; frameSlots = 1; frameSoft = false; frameIbl = false; frameEnvironment = null;
		softDepth = null; softFailure = ""; bloomPass = null; bloomReady = false; bloomFailure = "";
		capabilitiesReady = false; gl = null; vertexBuffer = null; indexBuffer = null; composite = null; bloomComposite = null; target = null; programs.clear(); lastVersion = -1;
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
			if (vertexArrays != null) vertexArrays.dispose();
			if (shadowPass != null) shadowPass.dispose();
			if (target != null) target.dispose();
			if (softDepth != null) softDepth.dispose();
			if (bloomPass != null) bloomPass.dispose();
			if (vertexBuffer != null) gl.deleteBuffer(vertexBuffer);
			if (indexBuffer != null) gl.deleteBuffer(indexBuffer);
			if (composite != null) gl.deleteProgram(composite.program);
			if (bloomComposite != null) gl.deleteProgram(bloomComposite.program);
			for (info in programs) gl.deleteProgram(info.program);
		}
		abandonContext();
	}
}
