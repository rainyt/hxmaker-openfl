package hx.render3d.openfl;

import haxe.ds.ObjectMap;
import hx.display.Scene3D;
import hx.display3d.MeshObject;
import hx.display3d.Node3D;
import hx.geom.Matrix3D;
import hx.render3d.GeometryMobility3D;
import hx.render3d.MobilityTracker3D;
import hx.render3d.Math3D;

private typedef MainRange3D = { var mesh:MeshObject; var start:Int; var count:Int; }
private typedef MainEntry3D = {
	var buffer:MainGeometryBuffer3D;
	var batch:MeshBatch3D;
	var snapshot:Array<Dynamic>;
	var topology:Array<Dynamic>;
	var fixedSnapshot:Array<Dynamic>;
	var ranges:Array<MainRange3D>;
	var used:Bool;
}
private typedef MainGroup3D = { var owner:Node3D; var meshes:Array<MeshObject>; var slots:Int; var mirrored:Bool; var vertexPbr:Bool; }
typedef CachedMainDraw3D = {
	var buffer:MainGeometryBuffer3D;
	var batch:MeshBatch3D;
	var owner:Node3D;
	var ranges:Array<{start:Int,count:Int}>;
}

/** 固定环境按空间区域缓存，动态与 AUTO 模型保留局部几何，镜头变化不改变成员布局。 */
class MainGeometryCache3D {
	private var gl:lime.graphics.WebGLRenderContext;
	private var entries:Map<String,MainEntry3D> = [];
	private var materialKeys:ObjectMap<hx.material.Material3D,{version:Int,atlas:Bool,keys:Map<Int,String>,used:Bool}> = new ObjectMap();
	private function materialKey(mesh:MeshObject,mirrored:Bool,vertexPbr:Bool):String {
		var material=mesh.material,cached=materialKeys.get(material),atlas=material.texture!=null&&material.texture.rect!=null;
		if(cached==null||cached.version!=material.version||cached.atlas!=atlas){
			cached={version:material.version,atlas:atlas,keys:[],used:true};materialKeys.set(material,cached);
		}
		cached.used=true;
		var flags=(mirrored?1:0)|(mesh.receiveShadow?2:0)|(vertexPbr?4:0),key=cached.keys.get(flags);
		if(key==null){key=MeshBatch3D.materialKey(material,mirrored,mesh.receiveShadow,vertexPbr);cached.keys.set(flags,key);}
		return key;
	}
	public function new(gl:lime.graphics.WebGLRenderContext) { this.gl=gl; }
	public function beginFrame():Void { for(entry in entries)entry.used=false;for(cached in materialKeys)cached.used=false; }
	public function endFrame(scene:Scene3D):Void {
		for(key in [for(key in entries.keys())key])if(!entries.get(key).used){entries.get(key).buffer.dispose();entries.remove(key);}
		for(material in [for(material in materialKeys.keys())material])if(!materialKeys.get(material).used)materialKeys.remove(material);
		scene.stats.geometryCacheBytes=0;for(entry in entries)scene.stats.geometryCacheBytes+=entry.buffer.bytes;
	}
	private static function same(a:Array<Dynamic>,b:Array<Dynamic>):Bool {
		if(a==null||a.length!=b.length)return false;
		for(i in 0...a.length)if(a[i]!=b[i])return false;return true;
	}
	private static function relative(mesh:MeshObject,owner:Node3D):Matrix3D {
		if(owner==null)return mesh.getWorldMatrix();
		var m=new Matrix3D(),node:Node3D=mesh;
		while(node!=owner){m=Math3D.multiply(node.getLocalMatrix(),m);node=node.parent;}return m;
	}
	private static function identity(m:Matrix3D):Bool {
		for(i in 0...16)if(m.rawData[i]!=(i%5==0?1:0))return false;return true;
	}
	public function prepare(scene:Scene3D,meshes:Array<MeshObject>,visible:ObjectMap<MeshObject,Bool>,guard:RenderStateGuard3D,
		context:openfl.display3D.Context3D,white:openfl.display.BitmapData,slotsFor:MeshObject->Int):Array<CachedMainDraw3D> {
		var groups:Map<String,MainGroup3D>=[],transforms:ObjectMap<MeshObject,Matrix3D>=new ObjectMap();
		for(mesh in meshes){
			// AUTO 保留自己的局部组，切换有效状态不搬迁环境缓冲。
			var owner=mesh.geometryMobility==GeometryMobility3D.STATIC?null:MobilityTracker3D.owner(mesh);
			var m=relative(mesh,owner),mirrored=m.determinant<0,slots=slotsFor(mesh),prefix:String;
			transforms.set(mesh,m);
			if(owner==null){var center=mesh.getWorldBounds().center();prefix="静态:"+Math.floor(center.x/16)+":"+Math.floor(center.y/16)+":"+Math.floor(center.z/16);}
			else prefix="局部:"+owner.instanceId;
			var skin=mesh.skinBinding!=null&&mesh.skinBinding.gpuEnabled?mesh.skinBinding:null;
			var base=prefix+(skin==null?":cpu":":gpu:"+skin.skinId)+":"+slots+":"+materialKey(mesh,mirrored,MeshBatch3D.supportsVertexPbr(mesh.material)),part=0,key=base+":0";
			while(true){
				var group=groups.get(key);
				if(group==null){groups.set(key,{owner:owner,meshes:[mesh],slots:slots,mirrored:mirrored,vertexPbr:MeshBatch3D.supportsVertexPbr(mesh.material)});break;}
				var vertices=Std.int(mesh.geometry.positions.length/3),indices=mesh.geometry.indices.length,sources:Array<openfl.display.BitmapData>=[];
				for(member in group.meshes){vertices+=Std.int(member.geometry.positions.length/3);indices+=member.geometry.indices.length;var source=TextureBridge3D.source(member.material.texture,white);if(sources.indexOf(source)<0)sources.push(source);}
				var source=TextureBridge3D.source(mesh.material.texture,white);
				if(vertices<=MeshBatch3D.MAX_VERTICES&&indices<=196605&&(sources.indexOf(source)>=0||sources.length<slots)){group.meshes.push(mesh);break;}
				key=base+":"+(++part);
			}
		}
		// 一个模型可见时准备全部材质组，避免各部件陆续入镜时反复首次上传。
		var visibleOwners:ObjectMap<Node3D,Bool>=new ObjectMap();
		for(mesh in meshes)if(mesh.geometryMobility!=GeometryMobility3D.STATIC&&visible.exists(mesh))visibleOwners.set(MobilityTracker3D.owner(mesh),true);
		var draws:Array<CachedMainDraw3D>=[];
		var keys=[for(key in groups.keys())key];keys.sort(Reflect.compare);
		for(key in keys){
			var group=groups.get(key),entry=entries.get(key),active=group.owner!=null&&visibleOwners.exists(group.owner);
			for(mesh in group.meshes)if(visible.exists(mesh)){active=true;break;}
			if(entry!=null)entry.used=true;
			if(!active)continue;
			var snapshot:Array<Dynamic>=[],fixedSnapshot:Array<Dynamic>=[],sources:Array<openfl.display.BitmapData>=[],regions:ObjectMap<MeshObject,Array<Float>>=new ObjectMap(),pbrValues:ObjectMap<MeshObject,Array<Float>>=new ObjectMap();
			for(mesh in group.meshes){
				var material=mesh.material,source=TextureBridge3D.source(material.texture,white);
				guard.activateTexture(0);TextureBridge3D.resolve(source,context);
				if(sources.indexOf(source)<0)sources.push(source);
				var size=TextureBridge3D.uvSize(source),rect=material.texture==null?null:material.texture.rect;
				var region=rect==null?[0.,0.,source.width/size[0],source.height/size[1]]:[rect.x/size[0],rect.y/size[1],rect.width/size[0],rect.height/size[1]];
				regions.set(mesh,region);
				if(group.vertexPbr){var values=MeshBatch3D.pbrVertexParameters(material);pbrValues.set(mesh,values);for(value in values)fixedSnapshot.push(value);}
				snapshot.push(mesh);snapshot.push(mesh.geometry);snapshot.push(mesh.skinBinding!=null&&mesh.skinBinding.gpuEnabled?mesh.geometry.dataVersion:mesh.geometry.version);
				fixedSnapshot.push(mesh);fixedSnapshot.push(mesh.geometry);fixedSnapshot.push(mesh.geometry.dataVersion);
				fixedSnapshot.push(material.color);fixedSnapshot.push(material.opacity);fixedSnapshot.push(source);
				for(value in region)fixedSnapshot.push(value);
				for(value in transforms.get(mesh).rawData)snapshot.push(value);
			}
			if(entry==null){entry={buffer:new MainGeometryBuffer3D(gl),batch:null,snapshot:null,topology:null,fixedSnapshot:null,ranges:[],used:true};entries.set(key,entry);}
			var fixedChanged=!same(entry.fixedSnapshot,fixedSnapshot);
			if(fixedChanged||!same(entry.snapshot,snapshot)){
				entry.snapshot=null;
				var batch=fixedChanged?new MeshBatch3D(group.meshes[0].material,group.mirrored,group.slots,group.meshes[0].receiveShadow,group.vertexPbr):entry.batch;batch.textures=sources;batch.skinBinding=group.meshes[0].skinBinding!=null&&group.meshes[0].skinBinding.gpuEnabled?group.meshes[0].skinBinding:null;
				var split=group.owner!=null,hotStride=(batch.lit?6:3)+(batch.normalMapped?4:0),coldStride=7+(batch.mapped?2:0)+(batch.vertexPbr?4:0);
				var floats=0,fixedFloats=0,elements=0,topology:Array<Dynamic>=[];
				for(mesh in group.meshes){var n=Std.int(mesh.geometry.positions.length/3);floats+=n*(split?hotStride:batch.floatsPerVertex);if(split)fixedFloats+=n*coldStride;elements+=mesh.geometry.indices.length;topology.push(mesh);topology.push(mesh.geometry);topology.push(mesh.geometry.positions.length);topology.push(mesh.geometry.indices.length);}
				var indicesChanged=!same(entry.topology,topology),buffer=entry.buffer;
				buffer.reserve(floats,elements,fixedFloats);entry.ranges=[];
				// 直接与持久索引数组比较，动画帧不再复制一份完整索引快照。
				if(!indicesChanged&&fixedChanged){
					var element=0,vertexBase=0;
					for(mesh in group.meshes){
						for(index in mesh.geometry.indices)if(buffer.indices[element++]!=vertexBase+index){indicesChanged=true;break;}
						if(indicesChanged)break;
						vertexBase+=Std.int(mesh.geometry.positions.length/3);
					}
				}
				var skinData=batch.skinBinding==null?null:new lime.utils.Float32Array(Std.int(floats/hotStride)*8),skinOffset=0;
				var offset=0,fixedOffset=0,indexOffset=0,base=0;
				for(mesh in group.meshes){
					var g=mesh.geometry,material=mesh.material,m=transforms.get(mesh),unit=identity(m),skin=batch.skinBinding==null?null:mesh.skinBinding,positions=skin==null?g.positions:skin.source.positions;
					var normals=batch.lit?(skin==null?g.getNormals():skin.source.normals):null,tangents=batch.normalMapped?g.getTangents():null;
					if(group.owner==null){positions=mesh.getWorldVertices();if(batch.lit)normals=mesh.getWorldNormals();if(batch.normalMapped)tangents=mesh.getWorldTangents();}
					else if(!unit){
						positions=[];m.transformVectors(g.positions,positions);
						if(batch.lit){normals=[];var source=g.getNormals();for(v in 0...Std.int(g.positions.length/3))Math3D.transformNormal(m.rawData,source[v*3],source[v*3+1],source[v*3+2],normals,v*3);}
						if(batch.normalMapped){tangents=[];var source=g.getTangents();for(v in 0...Std.int(g.positions.length/3))Math3D.transformTangent(m.rawData,source[v*4],source[v*4+1],source[v*4+2],source[v*4+3],normals[v*3],normals[v*3+1],normals[v*3+2],tangents,v*4);}
					}
					var region=regions.get(mesh),textureId=sources.indexOf(TextureBridge3D.source(material.texture,white)),data=buffer.vertices,vertices=Std.int(g.positions.length/3);
					var parameters=pbrValues.get(mesh);
					var r=((material.color>>16)&255)/255.,green=((material.color>>8)&255)/255.,b=(material.color&255)/255.;
					for(v in 0...vertices){
						if(skinData!=null){for(i in 0...4)skinData[skinOffset++]=skin.source.joints[v*4+i];for(i in 0...4)skinData[skinOffset++]=skin.source.weights[v*4+i];}
						data[offset++]=positions[v*3];data[offset++]=positions[v*3+1];data[offset++]=positions[v*3+2];
						if(split){
							if(batch.lit){data[offset++]=normals[v*3];data[offset++]=normals[v*3+1];data[offset++]=normals[v*3+2];}
							if(batch.normalMapped)for(i in 0...4)data[offset++]=tangents[v*4+i];
						}
						if(!split||fixedChanged){
							var target=split?buffer.attributes:data,at=split?fixedOffset:offset;
							target[at++]=region[0]+g.uvs[v*2]*region[2];target[at++]=region[1]+g.uvs[v*2+1]*region[3];target[at++]=textureId;
							target[at++]=r*(g.colors.length==0?1:g.colors[v*4]);target[at++]=green*(g.colors.length==0?1:g.colors[v*4+1]);target[at++]=b*(g.colors.length==0?1:g.colors[v*4+2]);target[at++]=material.opacity*(g.colors.length==0?1:g.colors[v*4+3]);
							if(!split&&batch.lit){target[at++]=normals[v*3];target[at++]=normals[v*3+1];target[at++]=normals[v*3+2];}
							if(batch.mapped){target[at++]=g.uvs[v*2];target[at++]=g.uvs[v*2+1];}
							if(!split&&batch.normalMapped)for(i in 0...4)target[at++]=tangents[v*4+i];
							if(batch.vertexPbr)for(i in 0...4)target[at++]=parameters[i];
							if(split)fixedOffset=at;else offset=at;
						}
					}

					entry.ranges.push({mesh:mesh,start:indexOffset,count:g.indices.length});
					if(indicesChanged)for(i in 0...g.indices.length)buffer.indices[indexOffset+i]=base+g.indices[i];
					indexOffset+=g.indices.length;base+=vertices;
				}
				var uploaded=buffer.uploadVertices(split),indexBytes=indicesChanged?buffer.uploadIndices():0;uploaded+=indexBytes;if(split&&fixedChanged)uploaded+=buffer.uploadAttributes();if(skinData!=null)uploaded+=buffer.uploadSkin(skinData);
				scene.stats.geometryIndexUploadedBytes+=indexBytes;scene.stats.uploadedBytes+=uploaded;
				var settled=true;for(mesh in group.meshes)if(mesh.effectiveGeometryMobility!=GeometryMobility3D.STATIC)settled=false;
				if(settled)scene.stats.geometryStaticUploadedBytes+=uploaded;else scene.stats.geometryDynamicUploadedBytes+=uploaded;
				entry.batch=batch;entry.topology=topology;entry.snapshot=snapshot;entry.fixedSnapshot=fixedSnapshot;scene.stats.geometryRebuilds++;
			}else scene.stats.geometryCacheHits++;
			var ranges:Array<{start:Int,count:Int}>=[];
			for(range in entry.ranges)if(visible.exists(range.mesh)){
				var previous=ranges.length==0?null:ranges[ranges.length-1];
				if(previous!=null&&previous.start+previous.count==range.start)previous.count+=range.count;
				else ranges.push({start:range.start,count:range.count});
			}
			draws.push({buffer:entry.buffer,batch:entry.batch,owner:group.owner,ranges:ranges});
		}
		return draws;
	}
	public function dispose(lost:Bool=false):Void { for(entry in entries)entry.buffer.dispose(lost);entries=[];materialKeys=new ObjectMap(); }
}
