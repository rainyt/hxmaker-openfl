package hx.render3d.openfl;

import hx.display.Scene3D;
import hx.display3d.MeshObject;
import hx.display3d.Node3D;
import hx.display3d.Model3D;
import hx.render3d.Math3D;
import hx.render3d.ShadowMobility3D;
import haxe.ds.ObjectMap;
import hx.light.DirectionalLight3D;
import hx.geom.Matrix3D;
import hx.material.AlphaMode3D;
import hx.material.CullMode3D;
import hx.render3d.DirectionalShadowPlanner3D;
import hx.render3d.DirectionalShadowSettings3D;
import hx.light.ShadowFilter3D;
import hx.utils.ContextStats;
import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLUniformLocation;
import lime.utils.Float32Array;

private typedef DynamicShadowGeometry3D = {
	var snapshot:Array<Dynamic>;
	var batches:Array<ShadowGeometryBuffer3D>;
	var rebuilt:Bool;
}

/** 绘制不透明及标准 MASK 投射物；从场景全体可见网格筛选，不沿用主相机剔除结果。 */
class ShadowPass3D {
	public var matrix(default, null):Matrix3D = new Matrix3D();
	public var matrices(default, null):Array<Matrix3D> = [];
	/** 分割深度、混合起点、淡出起点和淡出终点；手动范围的终点为 0。 */
	public var cascadeParams(default, null):Array<Float> = [0., 0., 0., 0.];
	public var cameraDepth(default, null):Array<Float> = [0., 0., -1., 0.];
	public var worldTexels(default, null):Array<Float> = [0., 0.];
	public var filter(default, null):ShadowFilter3D = ShadowFilter3D.PCF4;
	public var filterRadius(default, null):Float = 1.25;
	public var depthBiases(default, null):Array<Float> = [0., 0.];
	public var slopeBiases(default, null):Array<Float> = [0., 0.];
	private var planner:DirectionalShadowPlanner3D = new DirectionalShadowPlanner3D();
	private var fitMode:String = "关闭";
	private var coverageDistance:Float = 0;
	private var updated:Array<Bool> = [];
	private var degradation:String = "";
	private var lastResourceRequest:String;
	private var failedKey:String;
	private var failedLight:DirectionalLight3D;
	public var texture(get, never):GLTexture;
	private function get_texture():GLTexture { return target == null ? null : target.texture; }
	private var gl:WebGLRenderContext;
	private var gpuAttributes:Bool = false;
	private var available:Bool;
	private var sizedDepth:Bool;
	private var maximum:Int;
	private var allocationFallback:{light:DirectionalLight3D, key:String, size:Int, count:Int} = null;
	private var target:ShadowMap3D;
	private var program:GLProgram;
	private var skinPrograms:Map<Int,{program:GLProgram,matrix:GLUniformLocation,palette:GLUniformLocation}> = [];
	private var failedSkinCounts:Map<Int,Bool> = [];
	// 原生目标的 uniform 位置是 Int，显式允许上下文丢失时清空。
	private var location:Null<GLUniformLocation>;
	private var maskProgram:GLProgram;
	private var maskMatrix:GLUniformLocation;
	private var maskSampler:GLUniformLocation;
	private var maskCutoff:GLUniformLocation;
	private var maskOpacity:GLUniformLocation;
	private var lastSnapshots:Array<Array<Dynamic>> = [];
	private var lastLight:DirectionalLight3D;
	private var lastRequest:Int = -1;
	private var geometrySnapshots:Array<Array<Dynamic>> = [];
	private var geometryBatches:Array<Array<ShadowGeometryBuffer3D>> = [];
	private var dynamicGeometry:ObjectMap<Node3D, DynamicShadowGeometry3D> = new ObjectMap();
	public function new(gl:WebGLRenderContext, available:Bool, sizedDepth:Bool, maximum:Int) {
		this.gl = gl; this.available = available; this.sizedDepth = sizedDepth; this.maximum = maximum;
	}
	public function supportsSkin(count:Int):Bool { return !failedSkinCounts.exists(count); }
	public function render(scene:Scene3D, meshes:Array<MeshObject>, textureUnits:Int, guard:RenderStateGuard3D, context:openfl.display3D.Context3D, white:openfl.display.BitmapData, mipmaps:MipmapCache3D):Bool {
		for(mesh in meshes)if(mesh.skinBinding!=null&&mesh.skinBinding.gpuEnabled)gpuAttributes=true;
		var light = scene.light;
		if (light == null || light.isDisposed || light.scene != scene || !light.isWorldVisible() || !light.shadowEnabled || light.intensity <= 0) {
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
		if (casters.length == 0 || receivers.length == 0 || maximum < 16) {
			releaseTarget(); scene.stats.shadowStatus = maximum < 16 ? "设备阴影尺寸不足" : casters.length == 0 ? "无可用投射物" : "无接收阴影材质"; return false;
		}
		for(mesh in casters)if(mesh.skinBinding!=null&&mesh.skinBinding.gpuEnabled){
			var count=mesh.skinBinding.palette.length;
			if(failedSkinCounts.exists(count)){mesh.skinBinding.gpuEnabled=false;continue;}
			if(!skinPrograms.exists(count))try{
				var skinProgram=MultiTextureShader3D.compile(gl,"attribute vec3 aPosition;uniform mat4 uLightViewProjection;"+SkinShader3D.declarations(count)+"void main(){gl_Position=uLightViewProjection*vec4((skinMatrix()*vec4(aPosition,1.0)).xyz,1.0);}","precision mediump float;void main(){gl_FragColor=vec4(1.0);}");
				skinPrograms.set(count,{program:skinProgram,matrix:gl.getUniformLocation(skinProgram,"uLightViewProjection"),palette:gl.getUniformLocation(skinProgram,"uSkin[0]")});
			}catch(error:Dynamic){failedSkinCounts.set(count,true);mesh.skinBinding.gpuEnabled=false;trace("GPU 阴影蒙皮回退 CPU："+Std.string(error));}
		}
		var settings = new DirectionalShadowSettings3D(light);
		filter = settings.filter; filterRadius = settings.radius;
		var resourceRequest = [light.shadowQuality * 1., light.shadowMapSize * 1., light.shadowCascadeCount * 1.,
			light.hasShadowOverride("shadowMapSize") ? 1. : 0., light.hasShadowOverride("shadowCascadeCount") ? 1. : 0., light.shadowBounds == null ? 0. : 1.].join(":");
		// 冻结模式先于自动规划，镜头变化不能偷偷改变已经冻结的贴图布局。
		if (!light.shadowAutoUpdate && target != null && lastSnapshots.length == target.cascades && !Lambda.exists(lastSnapshots, snapshot -> snapshot == null) && lastLight == light
			&& lastRequest == light.shadowUpdateVersion && lastResourceRequest == resourceRequest) {
			updated = [for (_ in 0...target.cascades) false]; updateBiases(settings); updateStats(scene);
			scene.stats.shadowStatus = "开启（手动冻结）"; scene.stats.shadowCacheHit = true; return true;
		}
		var plan = planner.plan(scene.camera, scene.width / scene.height, light,
			[for (mesh in casters) mesh.getWorldBounds()], [for (mesh in receivers) mesh.getWorldBounds()], haxe.Timer.stamp());
		var count = plan.count;
		if (maximum < count * 16) count = 1;
		var tileLimit = Std.int(Math.pow(2, Math.floor(Math.log(maximum / count) / Math.log(2))));
		var requestedSize = settings.tileSize(count), size = Std.int(Math.min(tileLimit, requestedSize));
		var allocationKey = [count, size, light.shadowUpdateVersion].join(":");
		degradation = size < requestedSize ? "设备尺寸上限" : "";
		if (allocationFallback != null && allocationFallback.light == light && allocationFallback.key == allocationKey) {
			count = allocationFallback.count; size = allocationFallback.size; degradation = "阴影分配回退";
		}
		if (target != null && (target.size != size || target.cascades != count)) releaseTarget();
		if (target == null) {
			if (failedLight == light && failedKey == allocationKey) { scene.stats.shadowStatus = "阴影目标创建失败"; return false; }
			var originalCount = count, originalSize = size;
			while (target == null && size >= 16) {
				try { target = new ShadowMap3D(gl, size, sizedDepth, count); }
				catch (_:Dynamic) {
					if (count == 2) {
						try { target = new ShadowMap3D(gl, size, sizedDepth, 1); count = 1; } catch (_:Dynamic) {}
					}
					if (target == null) { size = Std.int(size / 2); count = originalCount; }
				}
			}
			if (target == null) {
				failedLight = light; failedKey = allocationKey; scene.stats.shadowStatus = "阴影目标创建失败"; return false;
			}
			if (count != originalCount || size != originalSize) {
				allocationFallback = {light: light, key: allocationKey, count: count, size: size}; degradation = "阴影分配回退";
			}
		}
		var nextMatrices = plan.projections(size, count);
		var params = plan.params.copy();
		if (count == 1 && plan.count == 2) { params[0] = params[3]; params[1] = params[3]; }
		var candidates:Array<Array<MeshObject>> = [];
		var snapshots:Array<Array<Dynamic>> = [];
		updated = [];
		for (i in 0...count) {
			var projection = nextMatrices[i];
			var active = casters.filter(mesh -> mesh.getWorldBounds().inFrustum(projection));
			candidates.push(active);
			var snapshot:Array<Dynamic> = [for (value in projection.rawData) value];
			for (mesh in active) {
				snapshot.push(mesh.effectiveShadowMobility); snapshot.push(mesh); snapshot.push(mesh.geometry); snapshot.push(mesh.geometry.version);
				// 不透明材质的粗糙度、颜色等变化不影响投影；MASK 继续跟踪纹理像素失效。
				var material = mesh.material;
				snapshot.push(material.alphaMode); snapshot.push(material.cullMode);
				if (material.alphaMode == AlphaMode3D.MASK) {
					snapshot.push(material); snapshot.push(material.version);
					// 图集区域可以直接修改；它改变 MASK 轮廓，也必须使深度贴图失效。
					var bitmap=material.texture, source=TextureBridge3D.source(bitmap,white), rect=bitmap==null?null:bitmap.rect;
					snapshot.push(source);snapshot.push(source.width);snapshot.push(source.height);
					snapshot.push(rect==null?null:rect.x);snapshot.push(rect==null?null:rect.y);
					snapshot.push(rect==null?null:rect.width);snapshot.push(rect==null?null:rect.height);
				}
				for (value in mesh.getWorldMatrix().rawData) snapshot.push(value);
			}
			snapshots.push(snapshot);
			var previous = i < lastSnapshots.length ? lastSnapshots[i] : null;
			var changed = lastLight != light || lastRequest != light.shadowUpdateVersion || previous == null || previous.length != snapshot.length;
			if (!changed) for (j in 0...snapshot.length) if (snapshot[j] != previous[j]) { changed = true; break; }
			updated.push(changed);
		}
		matrices = nextMatrices; matrix = matrices[0]; cascadeParams = params; cameraDepth = plan.cameraDepth;
		fitMode = plan.mode; coverageDistance = plan.distance;
		updateBiases(settings); updateStats(scene);
		var allCached = updated.indexOf(true) < 0;
		if (allCached) {
			lastResourceRequest = resourceRequest;
			scene.stats.shadowStatus = "开启（复用缓存）"; scene.stats.shadowCacheHit = true; return true;
		}
		if (program == null) {
			program = MultiTextureShader3D.compile(gl,
				"attribute vec3 aPosition;uniform mat4 uLightViewProjection;void main(){gl_Position=uLightViewProjection*vec4(aPosition,1.0);}",
				"precision mediump float;void main(){gl_FragColor=vec4(1.0);}");
			location = gl.getUniformLocation(program, "uLightViewProjection");
		}
		if (maskProgram == null && Lambda.exists(casters, function(mesh) return mesh.material.alphaMode == AlphaMode3D.MASK)) {
			maskProgram = MultiTextureShader3D.compile(gl,
				"attribute vec3 aPosition;attribute vec2 aUV;attribute float aTextureId;uniform mat4 uLightViewProjection;varying mediump float vAlpha;varying mediump vec2 vUV;void main(){vAlpha=aTextureId;vUV=aUV;gl_Position=uLightViewProjection*vec4(aPosition,1.0);}",
				"precision mediump float;varying mediump float vAlpha;varying mediump vec2 vUV;uniform sampler2D uMask;uniform float uCutoff;uniform float uOpacity;void main(){if(texture2D(uMask,vUV).a*uOpacity*vAlpha<uCutoff)discard;gl_FragColor=vec4(1.0);}");
			maskMatrix = gl.getUniformLocation(maskProgram, "uLightViewProjection");
			maskSampler = gl.getUniformLocation(maskProgram, "uMask");
			maskCutoff = gl.getUniformLocation(maskProgram, "uCutoff"); maskOpacity = gl.getUniformLocation(maskProgram, "uOpacity");
		}
		// 动态几何每次重绘只准备一次，由所有级联共享。
		guard.bindVertexArray("shadow");
		prepareDynamic(scene, casters, candidates, guard, context, white);
		// 只清理并重绘失效级联；一个图集仍只占用一个公共纹理槽位。
		gl.bindFramebuffer(gl.FRAMEBUFFER, target.framebuffer);
		gl.disable(gl.STENCIL_TEST); gl.disable(gl.BLEND); gl.enable(gl.SCISSOR_TEST);
		gl.disable(gl.POLYGON_OFFSET_FILL); gl.disable(gl.SAMPLE_ALPHA_TO_COVERAGE);
		gl.colorMask(false, false, false, false); gl.enable(gl.DEPTH_TEST); gl.depthMask(true); gl.depthFunc(gl.LEQUAL); gl.depthRange(0, 1);
		gl.clearDepth(1);
		for (i in 0...count) if (updated[i]) {
			// 先丢弃该级缓存，异常后不可复用部分写入的深度。
			lastSnapshots[i] = null;
			gl.viewport(i * size, 0, size, size); gl.scissor(i * size, 0, size, size); gl.clear(gl.DEPTH_BUFFER_BIT);
			drawCascade(scene, i, candidates[i], matrices[i], guard, context, white, mipmaps);
			lastSnapshots[i] = snapshots[i];
		}
		gl.disable(gl.SCISSOR_TEST);
		while (geometryBatches.length > count) { for (batch in geometryBatches.pop()) batch.dispose(); geometrySnapshots.pop(); }
		updateGeometryStats(scene);
		lastLight = light; lastRequest = light.shadowUpdateVersion; lastResourceRequest = resourceRequest;
		return true;
	}

	private function updateBiases(settings:DirectionalShadowSettings3D):Void {
		worldTexels = []; depthBiases = []; slopeBiases = [];
		for (projection in matrices) {
			var m = projection.rawData;
			var x = 2.0 / Math.sqrt(m[0]*m[0]+m[4]*m[4]+m[8]*m[8]);
			var y = 2.0 / Math.sqrt(m[1]*m[1]+m[5]*m[5]+m[9]*m[9]);
			var texel = (settings.adaptive ? Math.max(x,y) : x) / target.size;
			var depth = 2.0 / Math.sqrt(m[2]*m[2]+m[6]*m[6]+m[10]*m[10]);
			worldTexels.push(texel);
			depthBiases.push(settings.depthBias(texel, depth, target.depthBits, false));
			slopeBiases.push(settings.depthBias(texel, depth, target.depthBits, true));
		}
		if (worldTexels.length == 1) { worldTexels.push(worldTexels[0]); depthBiases.push(depthBiases[0]); slopeBiases.push(slopeBiases[0]); }
	}

	private function updateStats(scene:Scene3D):Void {
		updateGeometryStats(scene);
		scene.stats.shadowStatus = "开启";
		scene.stats.shadowMapSize = target.size; scene.stats.shadowMapBytes = target.bytes;
		scene.stats.shadowCascades = target.cascades; scene.stats.shadowDepthBits = target.depthBits;
		scene.stats.shadowWorldTexels = worldTexels.slice(0, target.cascades);
		scene.stats.shadowFitMode = fitMode; scene.stats.shadowEffectiveDistance = coverageDistance;
		scene.stats.shadowEffectiveFilter = cast filter; scene.stats.shadowEffectiveFilterRadius = filterRadius;
		scene.stats.shadowCascadeUpdated = updated.copy(); scene.stats.shadowDegradation = degradation;
		scene.stats.shadowDepthBiases = depthBiases.slice(0, target.cascades);
		scene.stats.shadowSlopeBiases = slopeBiases.slice(0, target.cascades);
	}

	/** 使用局部矩阵连乘，根节点移动不会引入逆矩阵舍入误差导致几何失效。 */
	private function geometryMatrix(mesh:MeshObject, owner:Node3D):Matrix3D {
		if(owner==null)return mesh.getWorldMatrix();
		var result=new Matrix3D(), node:Node3D=mesh;
		while(node!=owner){result=Math3D.multiply(node.getLocalMatrix(),result);node=node.parent;}
		return result;
	}
	private function dynamicOwner(mesh:MeshObject):Node3D {
		var node:Node3D=mesh.parent;
		while(node!=null){if(Std.isOfType(node,Model3D))return node;node=node.parent;}
		return mesh;
	}
	private function prepareDynamic(scene:Scene3D, casters:Array<MeshObject>, candidates:Array<Array<MeshObject>>, guard:RenderStateGuard3D,
		context:openfl.display3D.Context3D, white:openfl.display.BitmapData):Void {
		var active:ObjectMap<Node3D,Bool>=new ObjectMap(), groups:ObjectMap<Node3D,Array<MeshObject>>=new ObjectMap();
		for(cascade in candidates)for(mesh in cascade)if(mesh.shadowMobility!=ShadowMobility3D.STATIC)active.set(dynamicOwner(mesh),true);
		for(owner in [for(owner in dynamicGeometry.keys())owner])if(!active.exists(owner)){
			for(batch in dynamicGeometry.get(owner).batches)batch.dispose();dynamicGeometry.remove(owner);
		}
		for(mesh in casters)if(mesh.shadowMobility!=ShadowMobility3D.STATIC){
			var owner=dynamicOwner(mesh);if(!active.exists(owner))continue;
			if(!groups.exists(owner))groups.set(owner,[]);groups.get(owner).push(mesh);
		}
		for(owner in groups.keys()){
			var cache=dynamicGeometry.get(owner);
			if(cache==null){cache={snapshot:null,batches:[],rebuilt:false};dynamicGeometry.set(owner,cache);}
			// 异常后不得把部分上传的数据误认为有效缓存。
			var previous=cache.snapshot;cache.snapshot=null;
			var result=prepareGeometry(scene,groups.get(owner),owner,previous,cache.batches,guard,context,white);
			cache.snapshot=result.snapshot;cache.rebuilt=result.changed;
			if(result.changed)scene.stats.shadowDynamicGeometryRebuilds++;
			scene.stats.shadowDynamicUploadedBytes+=result.uploaded;
		}
	}
	private function drawCascade(scene:Scene3D, cascade:Int, casters:Array<MeshObject>, matrix:Matrix3D, guard:RenderStateGuard3D,
		context:openfl.display3D.Context3D, white:openfl.display.BitmapData, mipmaps:MipmapCache3D):Void {
		guard.bindVertexArray("shadow");
		for(i in 1...4)gl.disableVertexAttribArray(i);
		var batches=cascade<geometryBatches.length?geometryBatches[cascade]:null;
		if(batches==null){batches=[];geometryBatches[cascade]=batches;}
		var previous=cascade<geometrySnapshots.length?geometrySnapshots[cascade]:null;
		geometrySnapshots[cascade]=null;
		var result=prepareGeometry(scene,casters.filter(mesh->mesh.shadowMobility==ShadowMobility3D.STATIC),null,previous,batches,guard,context,white);
		geometrySnapshots[cascade]=result.snapshot;
		if(result.changed)scene.stats.shadowStaticGeometryRebuilds++;
		scene.stats.shadowStaticUploadedBytes+=result.uploaded;
		var rebuilt=result.changed;
		drawBatches(scene,batches,matrix,false,guard,context,white,mipmaps);
		var drawn:ObjectMap<Node3D,Bool>=new ObjectMap();
		for(mesh in casters)if(mesh.shadowMobility!=ShadowMobility3D.STATIC){
			var owner=dynamicOwner(mesh);if(drawn.exists(owner))continue;drawn.set(owner,true);
			var cache=dynamicGeometry.get(owner), world=owner.getWorldMatrix();
			rebuilt=rebuilt||cache.rebuilt;
			drawBatches(scene,cache.batches,Math3D.multiply(matrix,world),world.determinant<0,guard,context,white,mipmaps);
		}
		if(rebuilt)scene.stats.shadowGeometryRebuilds++;else scene.stats.shadowGeometryCacheHits++;
	}
	/** 常见容量内网格先规划批次，再直接写持久数组；只在超大网格时回退三角形拆分。 */
	private function packGeometry(scene:Scene3D,casters:Array<MeshObject>,transforms:ObjectMap<MeshObject,Matrix3D>,
		regions:ObjectMap<MeshObject,Array<Float>>,batches:Array<ShadowGeometryBuffer3D>,stateKey:MeshObject->String,stream:Bool,force:Bool):Int {
		var groups:Array<{meshes:Array<MeshObject>,key:String,vertices:Int,elements:Int}> = [];
		for(mesh in casters){
			var vertices=Std.int(mesh.geometry.positions.length/3),elements=mesh.geometry.indices.length,key=stateKey(mesh);
			var group=groups.length==0?null:groups[groups.length-1];
			if(group==null||group.key!=key||group.vertices+vertices>MeshBatch3D.MAX_VERTICES||group.elements+elements>196605){
				group={meshes:[],key:key,vertices:0,elements:0};groups.push(group);
			}
			group.meshes.push(mesh);group.vertices+=vertices;group.elements+=elements;
		}
		var uploaded=0;
		for(i in 0...groups.length){
			var group=groups[i],first=group.meshes[0],batch=i<batches.length?batches[i]:null;
			if(batch==null){batch=new ShadowGeometryBuffer3D(gl);batches.push(batch);}
			batch.material=first.material;batch.masked=first.material.alphaMode==AlphaMode3D.MASK;
			batch.mirrored=transforms.get(first).determinant<0;batch.skinBinding=first.skinBinding!=null&&first.skinBinding.gpuEnabled?first.skinBinding:null;
			batch.stride=batch.skinBinding!=null?11:batch.masked?6:3;
			// 同一个模型的刚性关节仍可能变化；只重建受影响的批次，保留 GPU 蒙皮源几何。
			var snapshot:Array<Dynamic>=[batch.stride,batch.masked,batch.mirrored,batch.skinBinding];
			for(mesh in group.meshes){
				snapshot.push(mesh);snapshot.push(mesh.geometry);snapshot.push(mesh.material);
				snapshot.push(batch.skinBinding==null?mesh.geometry.version:mesh.geometry.dataVersion);
				for(value in transforms.get(mesh).rawData)snapshot.push(value);
				if(batch.masked)for(value in regions.get(mesh))snapshot.push(value);
			}
			var previous=batch.sourceSnapshot,changed=force||previous==null||previous.length!=snapshot.length;
			if(!changed)for(k in 0...snapshot.length)if(previous[k]!=snapshot[k]){changed=true;break;}
			if(!changed)continue;
			batch.sourceSnapshot=null;
			batch.reserve(group.vertices*batch.stride,group.elements);
			var data=batch.vertexData,offset=0,indexOffset=0,base=0;
			for(mesh in group.meshes){
				var geometry=mesh.geometry,skin=batch.skinBinding==null?null:mesh.skinBinding,source=skin==null?geometry.positions:skin.source.positions,m=transforms.get(mesh).rawData,region=regions.get(mesh);
				var unit=true;for(k in 0...16)if(m[k]!=(k%5==0?1:0)){unit=false;break;}
				for(v in 0...Std.int(source.length/3)){
					var x=source[v*3],y=source[v*3+1],z=source[v*3+2];
					data[offset++]=unit?x:x*m[0]+y*m[4]+z*m[8]+m[12];
					data[offset++]=unit?y:x*m[1]+y*m[5]+z*m[9]+m[13];
					data[offset++]=unit?z:x*m[2]+y*m[6]+z*m[10]+m[14];
					if(skin!=null){for(k in 0...4)data[offset++]=skin.source.joints[v*4+k];for(k in 0...4)data[offset++]=skin.source.weights[v*4+k];}
					if(batch.masked){data[offset++]=region[0]+geometry.uvs[v*2]*region[2];data[offset++]=region[1]+geometry.uvs[v*2+1]*region[3];data[offset++]=geometry.colors.length==0?1.:geometry.colors[v*4+3];}
				}
				for(index in geometry.indices)batch.writeIndex(indexOffset++,base+index);
				base+=Std.int(source.length/3);
			}
			uploaded+=batch.commit(stream);batch.sourceSnapshot=snapshot;scene.stats.shadowIndexUploadedBytes+=batch.indexUploadedBytes;
		}
		while(batches.length>groups.length)batches.pop().dispose();
		return uploaded;
	}
	private function prepareGeometry(scene:Scene3D, casters:Array<MeshObject>, owner:Node3D, previous:Array<Dynamic>, batches:Array<ShadowGeometryBuffer3D>,
		guard:RenderStateGuard3D, context:openfl.display3D.Context3D, white:openfl.display.BitmapData):{snapshot:Array<Dynamic>,changed:Bool,uploaded:Int} {
		var materialIds = new haxe.ds.ObjectMap<hx.material.Material3D, Int>(), nextMaterialId = 0;
		var transforms:ObjectMap<MeshObject,Matrix3D>=new ObjectMap();
		for (mesh in casters) {
			if (!materialIds.exists(mesh.material)) materialIds.set(mesh.material, nextMaterialId++);
			transforms.set(mesh,geometryMatrix(mesh,owner));
		}
		function stateKey(mesh:MeshObject):String { return (mesh.skinBinding!=null&&mesh.skinBinding.gpuEnabled?"GPU:"+mesh.skinBinding.skinId+":":"CPU:")+(mesh.material.alphaMode == AlphaMode3D.MASK ? "遮罩:" + materialIds.get(mesh.material) : "不透明") + ":" + Std.string(mesh.material.cullMode) + ":" + (transforms.get(mesh).determinant < 0 ? "负" : "正"); }
		casters.sort(function(a,b) return Reflect.compare(stateKey(a),stateKey(b)));
		// 几何快照不包含阴影投影矩阵和采样参数；移动相机仍能复用静态几何。
		var snapshot:Array<Dynamic> = [], regions = new haxe.ds.ObjectMap<MeshObject,Array<Float>>();
		for (mesh in casters) {
			var material=mesh.material;
			snapshot.push(mesh);snapshot.push(mesh.geometry);snapshot.push(mesh.skinBinding!=null&&mesh.skinBinding.gpuEnabled?mesh.geometry.dataVersion:mesh.geometry.version);
			snapshot.push(material);snapshot.push(material.alphaMode);snapshot.push(material.cullMode);
			for (value in transforms.get(mesh).rawData) snapshot.push(value);
			if (material.alphaMode == AlphaMode3D.MASK) {
				var bitmap=material.texture,image=TextureBridge3D.source(bitmap,white);
				guard.activateTexture(0);TextureBridge3D.resolve(image,context);
				var size=TextureBridge3D.uvSize(image),rect=bitmap==null?null:bitmap.rect;
				var region=rect==null?[0.,0.,image.width/size[0],image.height/size[1]]:[rect.x/size[0],rect.y/size[1],rect.width/size[0],rect.height/size[1]];
				regions.set(mesh,region);for (value in region) snapshot.push(value);
			}
		}
		var changed=previous==null||previous.length!=snapshot.length;
		if(!changed)for(i in 0...snapshot.length)if(snapshot[i]!=previous[i]){changed=true;break;}
		var uploaded=0,packed=true;
		for(mesh in casters)if(mesh.geometry.positions.length/3>MeshBatch3D.MAX_VERTICES||mesh.geometry.indices.length>196605){packed=false;break;}
		if(changed&&packed)uploaded=packGeometry(scene,casters,transforms,regions,batches,stateKey,owner!=null,previous==null);
		else if(changed) {
			var positions:Array<Float>=[],elements:Array<Int>=[],key:String=null,batchIndex=0;
			var material:hx.material.Material3D=null,mirrored=false,masked=false,stride=3;
			function flush():Void {
				if(elements.length==0)return;
				var batch=batchIndex<batches.length?batches[batchIndex]:null;
				if(batch==null){batch=new ShadowGeometryBuffer3D(gl);batches.push(batch);}
				batchIndex++;batch.material=material;batch.mirrored=mirrored;batch.masked=masked;batch.stride=stride;
				uploaded+=batch.update(positions,elements);scene.stats.shadowIndexUploadedBytes+=batch.indexUploadedBytes;
				positions=[];elements=[];
			}
			for(mesh in casters) {
				var nextKey=stateKey(mesh);
				if(key!=nextKey){flush();key=nextKey;material=mesh.material;mirrored=transforms.get(mesh).determinant<0;masked=material.alphaMode==AlphaMode3D.MASK;stride=masked?6:3;}
				var source=owner==null?mesh.getWorldVertices():mesh.geometry.positions;
				if(owner!=null && mesh!=owner){
					var transform=transforms.get(mesh),unit=true;
					for(i in 0...16)if(transform.rawData[i]!=(i%5==0?1:0)){unit=false;break;}
					if(!unit){source=[];transform.transformVectors(mesh.geometry.positions,source);}
				}
				var sourceIndices=mesh.geometry.indices,remap:Map<Int,Int>=[],region=regions.get(mesh);
				// 常见网格一次打包全部顶点，避免每个三角形建立索引映射。
				var vertexCount=Std.int(source.length/3);
				if(vertexCount<=MeshBatch3D.MAX_VERTICES && sourceIndices.length<=196605){
					if(Std.int(positions.length/stride)+vertexCount>MeshBatch3D.MAX_VERTICES || elements.length+sourceIndices.length>196605)flush();
					var base=Std.int(positions.length/stride);
					for(index in 0...vertexCount){
						positions.push(source[index*3]);positions.push(source[index*3+1]);positions.push(source[index*3+2]);
						if(masked){positions.push(region[0]+mesh.geometry.uvs[index*2]*region[2]);positions.push(region[1]+mesh.geometry.uvs[index*2+1]*region[3]);positions.push(mesh.geometry.colors.length==0?1.:mesh.geometry.colors[index*4+3]);}
					}
					for(index in sourceIndices)elements.push(base+index);
					continue;
				}
				for(triangle in 0...Std.int(sourceIndices.length/3)) {
					if(Std.int(positions.length/stride)+3>MeshBatch3D.MAX_VERTICES||elements.length+3>196605){flush();remap.clear();}
					for(corner in 0...3) {
						var index=sourceIndices[triangle*3+corner],mapped=remap.get(index);
						if(mapped==null) {
							mapped=Std.int(positions.length/stride);remap.set(index,mapped);
							positions.push(source[index*3]);positions.push(source[index*3+1]);positions.push(source[index*3+2]);
							if(masked){positions.push(region[0]+mesh.geometry.uvs[index*2]*region[2]);positions.push(region[1]+mesh.geometry.uvs[index*2+1]*region[3]);positions.push(mesh.geometry.colors.length==0?1.:mesh.geometry.colors[index*4+3]);}
						}
						elements.push(mapped);
					}
				}
			}
			flush();while(batches.length>batchIndex)batches.pop().dispose();
		}
		scene.stats.shadowUploadedBytes+=uploaded;
		return {snapshot:snapshot,changed:changed,uploaded:uploaded};
	}
	private function drawBatches(scene:Scene3D,batches:Array<ShadowGeometryBuffer3D>,matrix:Matrix3D,ownerMirrored:Bool,guard:RenderStateGuard3D,
		context:openfl.display3D.Context3D,white:openfl.display.BitmapData,mipmaps:MipmapCache3D):Void {
		for(batch in batches) {
			var material=batch.material;
			var skin=batch.skinBinding==null?null:skinPrograms.get(batch.skinBinding.palette.length);
			gl.useProgram(skin!=null?skin.program:batch.masked?maskProgram:program);
			gl.uniformMatrix4fv(skin!=null?skin.matrix:batch.masked?maskMatrix:location,false,floats(matrix.rawData));
			if(skin!=null){batch.skinPalette=SkinShader3D.palette(batch.skinBinding,batch.skinPalette);gl.uniformMatrix4fv(skin.palette,false,batch.skinPalette);scene.stats.skinPaletteUploadedBytes+=batch.skinPalette.length*4;}
			else if(gpuAttributes){gl.disableVertexAttribArray(6);gl.disableVertexAttribArray(7);}
			if(batch.masked) {
				var source=TextureBridge3D.source(material.texture,white);
				TextureBridge3D.validateWrap(material,source);guard.activateTexture(0);
				var texture=TextureBridge3D.resolve(source,context);
				gl.bindTexture(gl.TEXTURE_2D,TextureBridge3D.handle(texture));guard.rememberTexture(texture);
				var requested=hx.material.TextureMinFilter3D.resolve(material.textureMinFilter,material.textureMinSmoothing==null?material.smoothing:material.textureMinSmoothing);
				var filter=mipmaps.prepare(material.texture,source,texture,requested);
				TextureBridge3D.applySampler(texture,material.smoothing,material.textureWrapU,material.textureWrapV,material.textureMinSmoothing,filter);
				gl.uniform1i(maskSampler,0);gl.uniform1f(maskCutoff,material.alphaCutoff);gl.uniform1f(maskOpacity,material.opacity);
			}
			if(material.cullMode==CullMode3D.NONE)gl.disable(gl.CULL_FACE);
			else{gl.enable(gl.CULL_FACE);gl.cullFace(material.cullMode==CullMode3D.BACK?gl.BACK:gl.FRONT);}
			gl.frontFace((batch.mirrored!=ownerMirrored)?gl.CW:gl.CCW);batch.bind();
			gl.drawElements(gl.TRIANGLES,batch.count,gl.UNSIGNED_SHORT,0);
			scene.stats.shadowDrawCalls++;scene.stats.shadowTriangles+=Std.int(batch.count/3);
			ContextStats.statsDrawCall();ContextStats.statsVertexCount(batch.count);
		}
	}
	private function updateGeometryStats(scene:Scene3D):Void {
		scene.stats.shadowGeometryBytes=0;
		for(batches in geometryBatches)for(batch in batches)scene.stats.shadowGeometryBytes+=batch.bytes;
		for(cache in dynamicGeometry)for(batch in cache.batches)scene.stats.shadowGeometryBytes+=batch.bytes;
	}
	private function releaseGeometry(lost:Bool=false):Void {
		for(batches in geometryBatches)for(batch in batches)batch.dispose(lost);
		for(cache in dynamicGeometry)for(batch in cache.batches)batch.dispose(lost);
		dynamicGeometry=new ObjectMap();geometryBatches=[];geometrySnapshots=[];
	}

	private static function floats(values:Array<Float>):Float32Array {
		var result = new Float32Array(values.length); for (i in 0...values.length) result[i] = values[i]; return result;
	}
	private function releaseTarget():Void {
		releaseGeometry();
		matrices = []; worldTexels = [0., 0.]; lastSnapshots = []; lastLight = null; lastResourceRequest = null;
		if (target != null) target.dispose(); target = null; failedKey = null; failedLight = null;
	}
	/** 上下文丢失只丢弃句柄，不在新上下文删除旧资源。 */
	public function abandonContext():Void {
		releaseGeometry(true);
		allocationFallback = null; matrices = []; worldTexels = [0., 0.]; target = null;
		skinPrograms.clear();failedSkinCounts.clear();gpuAttributes=false;program = null; maskProgram = null; lastSnapshots = []; lastLight = null; lastResourceRequest = null;
		location = null; failedKey = null; failedLight = null; planner.reset();
	}
	public function dispose():Void {
		if (gl != null && !gl.isContextLost()) {
			releaseTarget();for(skin in skinPrograms)gl.deleteProgram(skin.program); if (program != null) gl.deleteProgram(program); if (maskProgram != null) gl.deleteProgram(maskProgram);
		}
		abandonContext(); gl = null;
	}
}
