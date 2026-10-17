package hx.render3d.openfl;

import hx.display.Scene3D;
import hx.display3d.MeshObject;
import hx.light.DirectionalLight3D;
import hx.geom.Matrix3D;
import hx.geom.Bounds3D;
import hx.geom.Vector3D;
import hx.material.AlphaMode3D;
import hx.material.CullMode3D;
import hx.render3d.Math3D;
import hx.utils.ContextStats;
import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLUniformLocation;
import lime.graphics.opengl.GLBuffer;
import lime.utils.Float32Array;
import lime.utils.UInt16Array;

/** 绘制不透明及标准 MASK 投射物；从场景全体可见网格筛选，不沿用主相机剔除结果。 */
class ShadowPass3D {
	public var matrix(default, null):Matrix3D = new Matrix3D();
	public var texture(get, never):GLTexture;
	private function get_texture():GLTexture { return target == null ? null : target.texture; }
	private var gl:WebGLRenderContext;
	private var available:Bool;
	private var sizedDepth:Bool;
	private var maximum:Int;
	private var failedSize:Int = -1;
	private var target:ShadowMap3D;
	private var program:GLProgram;
	private var location:GLUniformLocation;
	private var maskProgram:GLProgram;
	private var maskMatrix:GLUniformLocation;
	private var maskSampler:GLUniformLocation;
	private var maskCutoff:GLUniformLocation;
	private var maskOpacity:GLUniformLocation;
	private var lastSnapshot:Array<Dynamic>;
	private var lastLight:DirectionalLight3D;
	private var lastRequest:Int = -1;
	private var lastSize:Int = 0;
	private var vertices:GLBuffer;
	private var indices:GLBuffer;
	public function new(gl:WebGLRenderContext, available:Bool, sizedDepth:Bool, maximum:Int) {
		this.gl = gl; this.available = available; this.sizedDepth = sizedDepth; this.maximum = maximum;
	}
	public function render(scene:Scene3D, meshes:Array<MeshObject>, textureUnits:Int, guard:RenderStateGuard3D, context:openfl.display3D.Context3D, white:openfl.display.BitmapData):Bool {
		var light = scene.light;
		if (light == null || !light.isWorldVisible() || !light.shadowEnabled || light.intensity <= 0) {
			releaseTarget(); scene.stats.shadowStatus = "关闭"; return false;
		}
		if (!available || textureUnits < 2) {
			scene.stats.shadowStatus = !available ? "不支持深度纹理" : "纹理单元不足"; return false;
		}
		var casters:Array<MeshObject> = [], receivers:Array<MeshObject> = [];
		for (mesh in meshes) {
			if (mesh.castShadow && (mesh.material.alphaMode == AlphaMode3D.OPAQUE || mesh.material.alphaMode == AlphaMode3D.MASK) && mesh.material.fragmentCode == "" && mesh.material.fragmentUVCode == "") casters.push(mesh);
			if (mesh.receiveShadow && mesh.material.lightingEnabled) receivers.push(mesh);
		}
		if (casters.length == 0 || receivers.length == 0) {
			releaseTarget(); scene.stats.shadowStatus = casters.length == 0 ? "无可用投射物" : "无接收阴影材质"; return false;
		}
		var size = Std.int(Math.min(maximum, light.shadowMapSize));
		if (target != null && target.size != size) releaseTarget();
		if (target == null) {
			if (failedSize == size) { scene.stats.shadowStatus = "阴影目标创建失败"; return false; }
			try { target = new ShadowMap3D(gl, size, sizedDepth); }
			catch (error:Dynamic) {
				failedSize = size; scene.stats.shadowStatus = "阴影目标创建失败"; trace("三维阴影已降级为仅光照：" + Std.string(error)); return false;
			}
		}
		// 独立于观察相机和整场景版本；比较实际参与阴影的资源与世界矩阵。
		var snapshot:Array<Dynamic> = [light, size, light.shadowPadding, light.shadowUpdateVersion];
		var direction = light.getWorldDirection();
		for (value in [direction.x, direction.y, direction.z]) snapshot.push(value);
		if (light.shadowBounds != null) {
			for (value in [light.shadowBounds.min.x, light.shadowBounds.min.y, light.shadowBounds.min.z,
				light.shadowBounds.max.x, light.shadowBounds.max.y, light.shadowBounds.max.z]) snapshot.push(value);
		}
		for (group in [casters, receivers]) {
			snapshot.push(group.length);
			for (mesh in group) {
				snapshot.push(mesh); snapshot.push(mesh.geometry); snapshot.push(mesh.geometry.version);
				snapshot.push(mesh.material); snapshot.push(mesh.material.version);
				for (value in mesh.getWorldMatrix().rawData) snapshot.push(value);
			}
		}
		var unchanged = lastSnapshot != null && snapshot.length == lastSnapshot.length;
		if (unchanged) for (i in 0...snapshot.length) if (snapshot[i] != lastSnapshot[i]) { unchanged = false; break; }
		if (lastSnapshot != null && lastLight == light && lastSize == size && lastRequest == light.shadowUpdateVersion
			&& (!light.shadowAutoUpdate || unchanged)) {
			scene.stats.shadowMapSize = size; scene.stats.shadowMapBytes = size*size*6;
			scene.stats.shadowStatus = "开启（复用缓存）"; scene.stats.shadowCacheHit = true;
			return true;
		}
		if (program == null) {
			program = MultiTextureShader3D.compile(gl,
				"attribute vec3 aPosition;uniform mat4 uLightViewProjection;void main(){gl_Position=uLightViewProjection*vec4(aPosition,1.0);}",
				"precision mediump float;void main(){gl_FragColor=vec4(1.0);}");
			location = gl.getUniformLocation(program, "uLightViewProjection"); vertices = gl.createBuffer(); indices = gl.createBuffer();
		}
		if (maskProgram == null && Lambda.exists(casters, function(mesh) return mesh.material.alphaMode == AlphaMode3D.MASK)) {
			maskProgram = MultiTextureShader3D.compile(gl,
				"attribute vec3 aPosition;attribute vec2 aUV;attribute float aTextureId;uniform mat4 uLightViewProjection;varying mediump float vAlpha;varying mediump vec2 vUV;void main(){vAlpha=aTextureId;vUV=aUV;gl_Position=uLightViewProjection*vec4(aPosition,1.0);}",
				"precision mediump float;varying mediump float vAlpha;varying mediump vec2 vUV;uniform sampler2D uMask;uniform float uCutoff;uniform float uOpacity;void main(){if(texture2D(uMask,vUV).a*uOpacity*vAlpha<uCutoff)discard;gl_FragColor=vec4(1.0);}");
			maskMatrix = gl.getUniformLocation(maskProgram, "uLightViewProjection");
			maskSampler = gl.getUniformLocation(maskProgram, "uMask");
			maskCutoff = gl.getUniformLocation(maskProgram, "uCutoff"); maskOpacity = gl.getUniformLocation(maskProgram, "uOpacity");
		}
		// 绘制中途失败时禁止下一帧复用部分写入的阴影。
		lastSnapshot = null;
		matrix = lightMatrix(light, casters, receivers, size);
		scene.stats.shadowMapSize = size; scene.stats.shadowMapBytes = size*size*6; scene.stats.shadowStatus = "开启";
		gl.bindFramebuffer(gl.FRAMEBUFFER, target.framebuffer); gl.viewport(0, 0, size, size);
		gl.disable(gl.SCISSOR_TEST); gl.disable(gl.STENCIL_TEST); gl.disable(gl.BLEND);
		gl.disable(gl.POLYGON_OFFSET_FILL); gl.disable(gl.SAMPLE_ALPHA_TO_COVERAGE);
		gl.colorMask(false, false, false, false); gl.enable(gl.DEPTH_TEST); gl.depthMask(true); gl.depthFunc(gl.LEQUAL); gl.depthRange(0, 1);
		gl.clearDepth(1); gl.clear(gl.DEPTH_BUFFER_BIT); gl.useProgram(program); gl.uniformMatrix4fv(location, false, floats(matrix.rawData));
		guard.bindVertexArray("shadow");
		for (i in 1...4) gl.disableVertexAttribArray(i);
		var positions:Array<Float> = [], elements:Array<Int> = [], key:String = null;
		var masked = false, stride = 3;
		function flush():Void {
			if (elements.length == 0) return;
			gl.bindBuffer(gl.ARRAY_BUFFER, vertices); gl.bufferData(gl.ARRAY_BUFFER, floats(positions), gl.STREAM_DRAW);
			var indexData = new UInt16Array(elements.length); for (i in 0...elements.length) indexData[i] = elements[i];
			gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indices); gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indexData, gl.STREAM_DRAW);
			gl.enableVertexAttribArray(0); gl.vertexAttribPointer(0, 3, gl.FLOAT, false, stride*4, 0);
			if (masked) {
				gl.enableVertexAttribArray(1); gl.vertexAttribPointer(1, 2, gl.FLOAT, false, 24, 12);
				gl.enableVertexAttribArray(2); gl.vertexAttribPointer(2, 1, gl.FLOAT, false, 24, 20);
			} else { gl.disableVertexAttribArray(1); gl.disableVertexAttribArray(2); }
			gl.drawElements(gl.TRIANGLES, elements.length, gl.UNSIGNED_SHORT, 0);
			scene.stats.shadowDrawCalls++; scene.stats.shadowTriangles += Std.int(elements.length / 3);
			scene.stats.shadowUploadedBytes += positions.length*4 + elements.length*2;
			ContextStats.statsDrawCall(); ContextStats.statsVertexCount(elements.length);
			positions = []; elements = [];
		}
		var materialIds = new haxe.ds.ObjectMap<hx.material.Material3D, Int>(), nextMaterialId = 0;
		for (mesh in casters) if (!materialIds.exists(mesh.material)) materialIds.set(mesh.material, nextMaterialId++);
		function stateKey(mesh:MeshObject):String { return (mesh.material.alphaMode == AlphaMode3D.MASK ? "遮罩:" + materialIds.get(mesh.material) : "不透明") + ":" + Std.string(mesh.material.cullMode) + ":" + (mesh.getWorldMatrix().determinant < 0 ? "负" : "正"); }
		casters.sort(function(a, b) { return Reflect.compare(stateKey(a), stateKey(b)); });
		for (mesh in casters) {
			if (!mesh.getWorldBounds().inFrustum(matrix)) continue;
			var nextKey = stateKey(mesh);
			if (nextKey != key) {
				flush(); key = nextKey;
				masked = mesh.material.alphaMode == AlphaMode3D.MASK; stride = masked ? 6 : 3;
				gl.useProgram(masked ? maskProgram : program);
				gl.uniformMatrix4fv(masked ? maskMatrix : location, false, floats(matrix.rawData));
				if (masked) {
					var material = mesh.material, source = TextureBridge3D.source(material.texture, white);
					TextureBridge3D.validateWrap(material, source); guard.activateTexture(0);
					var texture = TextureBridge3D.resolve(source, context);
					gl.bindTexture(gl.TEXTURE_2D, TextureBridge3D.handle(texture)); guard.rememberTexture(texture);
					TextureBridge3D.applySampler(texture, material.smoothing, material.textureWrapU, material.textureWrapV, material.textureMinSmoothing);
					gl.uniform1i(maskSampler, 0); gl.uniform1f(maskCutoff, material.alphaCutoff); gl.uniform1f(maskOpacity, material.opacity);
				}
				if (mesh.material.cullMode == CullMode3D.NONE) gl.disable(gl.CULL_FACE);
				else { gl.enable(gl.CULL_FACE); gl.cullFace(mesh.material.cullMode == CullMode3D.BACK ? gl.BACK : gl.FRONT); }
				gl.frontFace(mesh.getWorldMatrix().determinant < 0 ? gl.CW : gl.CCW);
			}
			var source = mesh.getWorldVertices(), sourceIndices = mesh.geometry.indices, remap:Map<Int, Int> = [];
			var region = [0., 0., 1., 1.];
			if (masked) {
				var bitmap = mesh.material.texture, image = TextureBridge3D.source(bitmap, white), size = TextureBridge3D.uvSize(image);
				region = bitmap != null && bitmap.rect != null
					? [bitmap.rect.x/size[0], bitmap.rect.y/size[1], bitmap.rect.width/size[0], bitmap.rect.height/size[1]]
					: [0., 0., image.width/size[0], image.height/size[1]];
			}
			for (triangle in 0...Std.int(sourceIndices.length / 3)) {
				if (Std.int(positions.length / stride) + 3 > MeshBatch3D.MAX_VERTICES || elements.length + 3 > 196605) { flush(); remap.clear(); }
				for (corner in 0...3) {
					var index = sourceIndices[triangle*3+corner], mapped = remap.get(index);
					if (mapped == null) {
						mapped = Std.int(positions.length / stride); remap.set(index, mapped);
						positions.push(source[index*3]); positions.push(source[index*3+1]); positions.push(source[index*3+2]);
						if (masked) { positions.push(region[0]+mesh.geometry.uvs[index*2]*region[2]); positions.push(region[1]+mesh.geometry.uvs[index*2+1]*region[3]); positions.push(mesh.geometry.colors.length == 0 ? 1.0 : mesh.geometry.colors[index*4+3]); }
					}
					elements.push(mapped);
				}
			}
		}
		flush(); lastSnapshot = snapshot; lastLight = light; lastRequest = light.shadowUpdateVersion; lastSize = size; return true;
	}
	/** 旋转到光源空间后适配投射物 XY；接收物只扩展深度，避免大地面浪费 XY 分辨率。 */
	private function lightMatrix(light:DirectionalLight3D, casters:Array<MeshObject>, receivers:Array<MeshObject>, size:Int):Matrix3D {
		var d = light.getWorldDirection(), z = new Vector3D(-d.x,-d.y,-d.z);
		var up = Math.abs(z.y) > 0.95 ? new Vector3D(0,0,1) : new Vector3D(0,1,0);
		var x = up.crossProduct(z); x.normalize(); var y = z.crossProduct(x);
		var view = new Matrix3D([x.x,y.x,z.x,0., x.y,y.y,z.y,0., x.z,y.z,z.z,0., 0.,0.,0.,1.]);
		var bounds = new Bounds3D();
		function include(box:Bounds3D):Void {
			if (!box.isEmpty()) { bounds.include(box.min.x,box.min.y,box.min.z); bounds.include(box.max.x,box.max.y,box.max.z); }
		}
		if (light.shadowBounds != null) include(light.shadowBounds.transformed(view));
		else {
			for (mesh in casters) include(mesh.getWorldBounds().transformed(view));
			for (mesh in receivers) {
				var box = mesh.getWorldBounds().transformed(view);
				if (!box.isEmpty()) { bounds.min.z = Math.min(bounds.min.z, box.min.z); bounds.max.z = Math.max(bounds.max.z, box.max.z); }
			}
		}
		var width = Math.max(0.1, bounds.max.x-bounds.min.x)*(1+light.shadowPadding*2);
		var height = Math.max(0.1, bounds.max.y-bounds.min.y)*(1+light.shadowPadding*2);
		var cx = (bounds.min.x+bounds.max.x)/2, cy = (bounds.min.y+bounds.max.y)/2;
		cx = Math.floor(cx/(width/size)+0.5)*(width/size); cy = Math.floor(cy/(height/size)+0.5)*(height/size);
		var margin = Math.max(0.1, (bounds.max.z-bounds.min.z)*light.shadowPadding);
		return Math3D.multiply(Math3D.orthographic(cx-width/2,cx+width/2,cy-height/2,cy+height/2,-bounds.max.z-margin,-bounds.min.z+margin), view);
	}
	private static function floats(values:Array<Float>):Float32Array {
		var result = new Float32Array(values.length); for (i in 0...values.length) result[i] = values[i]; return result;
	}
	private function releaseTarget():Void { lastSnapshot = null; lastLight = null; if (target != null) target.dispose(); target = null; failedSize = -1; }
	/** 上下文丢失只丢弃句柄，不在新上下文删除旧资源。 */
	public function abandonContext():Void { target = null; program = null; maskProgram = null; lastSnapshot = null; lastLight = null; location = null; vertices = null; indices = null; failedSize = -1; }
	public function dispose():Void {
		if (gl != null && !gl.isContextLost()) {
			releaseTarget(); if (program != null) gl.deleteProgram(program); if (maskProgram != null) gl.deleteProgram(maskProgram);
			if (vertices != null) gl.deleteBuffer(vertices); if (indices != null) gl.deleteBuffer(indices);
		}
		abandonContext(); gl = null;
	}
}
