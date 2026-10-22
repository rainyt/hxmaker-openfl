package hx.render3d.openfl;

import hx.display3d.MeshObject;
import hx.material.Material3D;
import hx.material.AlphaMode3D;
import hx.material.BlendMode3D;
import hx.material.CullMode3D;
import haxe.Json;

/** 一个稳定的绘制批次，纹理编号和索引仅在此批次中有效。 */
@:access(hx.material.Material3D)
class MeshBatch3D {
	public static inline var MAX_VERTICES:Int = 65535;
	public var material(default,null):Material3D;
	public var vertices:Array<Float> = [];
	public var indices:Array<Int> = [];
	public var textures:Array<openfl.display.BitmapData> = [];
	public var key:String;
	public var declarations:String;
	public var fragmentCode:String;
	public var uvCode:String;
	public var textureNames:Array<String>;
	public var textureUniforms:Map<String, hx.display.BitmapData>;
	public var baseTexture:hx.display.BitmapData;
	public var uniforms:Map<String, Array<Float>>;
	public var alphaMode:AlphaMode3D;
	public var blendMode:BlendMode3D;
	public var softParticleDistance:Float;
	public var alphaCutoff:Float;
	public var cullMode:CullMode3D;
	public var depthTest:Bool;
	public var depthWrite:Bool;
	public var smoothing:Bool;
	public var colorMultiplyLinear:Bool;
	public var minSmoothing:Bool;
	public var minFilter:Int;
	public var wrapU:Int;
	public var wrapV:Int;
	public var mirrored:Bool;
	public var slots:Int;
	public var lit:Bool;
	public var pbr:Bool;
	public var vertexPbr:Bool = false;
	public var skinBinding:hx.animation3d.Skin3D.SkinBinding3D;
	public var skinPalette:lime.utils.Float32Array;
	public var mapped:Bool;
	public var normalMapped:Bool;
	public var receiveShadow:Bool;
	private var vertexMesh:MeshObject;
	private var vertexSource:openfl.display.BitmapData;
	private var uvOffsetU:Float;
	private var uvOffsetV:Float;
	private var uvScaleU:Float;
	private var uvScaleV:Float;
	public var floatsPerVertex(get, never):Int;
	private function get_floatsPerVertex():Int { return (lit ? 13 : 10) + (mapped ? 2 : 0) + (normalMapped ? 4 : 0) + (vertexPbr ? 4 : 0); }
	public function new(material:Material3D, mirrored:Bool, slots:Int, receiveShadow:Bool = true, vertexPbr:Bool = false) {
		this.material=material;
		this.vertexPbr = vertexPbr;
		uvCode = material.fragmentUVCode; textureNames = material.textureUniformNames();
		textureUniforms = material.getTextureUniforms(); baseTexture = material.texture;
		lit = material.lightingEnabled; pbr = lit && material.pbrEnabled;
		mapped = pbr && material.pbrMapMask != 0; normalMapped = mapped && (material.pbrMapMask & 2) != 0; colorMultiplyLinear = material.colorMultiplyLinear; this.receiveShadow = receiveShadow;
		key = materialKey(material, mirrored, receiveShadow, vertexPbr); declarations = material.fragmentDeclarations; fragmentCode = material.fragmentCode;
		softParticleDistance = material.softParticleDistance; blendMode = material.blendMode;
		uniforms = material.getUniforms(); alphaMode = material.alphaMode; alphaCutoff = material.alphaCutoff;
		cullMode = material.cullMode; depthTest = material.depthTest;
		depthWrite = material.depthWrite && material.alphaMode != AlphaMode3D.BLEND;
		smoothing = material.smoothing; minSmoothing = material.textureMinSmoothing == null ? smoothing : material.textureMinSmoothing;
		minFilter = hx.material.TextureMinFilter3D.resolve(material.textureMinFilter, minSmoothing);
		wrapU = material.textureWrapU; wrapV = material.textureWrapV; this.mirrored = mirrored; this.slots = slots;
	}
	/** 无辅助贴图的标准 PBR 可将线性基础色和粗糙度编码为一个额外顶点属性。 */
	public static function supportsVertexPbr(material:Material3D):Bool {
		return material.lightingEnabled && Std.isOfType(material, hx.material.PbrMaterial3D)
			&& material.alphaMode != AlphaMode3D.BLEND && material.textureUniformNames().length == 0
			&& material.fragmentDeclarations == "" && material.fragmentCode == "" && material.fragmentUVCode == "";
	}
	/** 直接读取只读参数，不复制整套 uniform；写入缓存时仍保留独立的四分量快照。 */
	public static function pbrVertexParameters(material:Material3D):Array<Float> {
		var color=material.__uniforms.get("uPbrBaseColor"),rough=material.__uniforms.get("uPbrRoughness");
		if(color==null||color.length!=3||rough==null||rough.length!=1)throw "PBR 顶点材质参数长度无效";
		return [color[0],color[1],color[2],rough[0]];
	}
	public static function materialKey(material:Material3D, mirrored:Bool, receiveShadow:Bool = true, vertexPbr:Bool = false):String {
		var uniformKey:String;
		if(vertexPbr){
			var keys=[for(key in material.__uniforms.keys())if(key!="uPbrBaseColor"&&key!="uPbrRoughness")key];keys.sort(Reflect.compare);
			uniformKey=[for(key in keys)key+":"+material.__uniforms.get(key).join(",")].join(";");
		}else uniformKey=material.uniformKey();
		return Json.stringify([vertexPbr, material.fragmentUVCode, material.textureBindingKey(), material.textureUniformNames().join(","), material.fragmentDeclarations, material.fragmentCode, uniformKey, Std.string(material.alphaMode),
			Std.string(material.softParticleDistance), Std.string(material.blendMode), Std.string(material.alphaCutoff), Std.string(material.cullMode), Std.string(material.depthTest), Std.string(material.depthWrite),
			Std.string(!material.lightingEnabled && material.colorMultiplyLinear), Std.string(material.smoothing), Std.string(material.textureMinSmoothing == null ? material.smoothing : material.textureMinSmoothing),
			Std.string(material.textureMinFilter), Std.string(material.textureMinFilter != null && material.textureMinFilter >= 9984 && material.texture != null && material.texture.rect != null),
			Std.string(material.textureWrapU), Std.string(material.textureWrapV), Std.string(mirrored), Std.string(material.lightingEnabled), Std.string(material.lightingEnabled && material.pbrEnabled), Std.string(material.lightingEnabled && receiveShadow)]);
	}
	/** 添加一个顶点，颜色与透明度编码进顶点，避免为不同模型切换 uniform。 */
	public function vertex(mesh:MeshObject, index:Int, textureId:Int, world:Array<Float>, source:openfl.display.BitmapData, normals:Array<Float> = null, tangents:Array<Float> = null):Int {
		var result = Std.int(vertices.length / floatsPerVertex), material = mesh.material, g = mesh.geometry;
		var colors = g.colors, offset = index * 4;
		var red = colors.length == 0 ? 1. : colors[offset];
		var green = colors.length == 0 ? 1. : colors[offset + 1];
		var blue = colors.length == 0 ? 1. : colors[offset + 2];
		var alpha = colors.length == 0 ? 1. : colors[offset + 3];
		// 一个网格内的图集区域保持一致，只计算一次，避免每个顶点创建临时数组。
		if (vertexMesh != mesh || vertexSource != source) {
			vertexMesh = mesh; vertexSource = source;
			var texture = material.texture, size = TextureBridge3D.uvSize(source);
			var rect = texture == null ? null : texture.rect;
			uvOffsetU = rect == null ? 0 : rect.x / size[0]; uvOffsetV = rect == null ? 0 : rect.y / size[1];
			uvScaleU = (rect == null ? source.width : rect.width) / size[0];
			uvScaleV = (rect == null ? source.height : rect.height) / size[1];
		}
		vertices.push(world[index*3]); vertices.push(world[index*3+1]); vertices.push(world[index*3+2]);
		vertices.push(uvOffsetU+g.uvs[index*2]*uvScaleU); vertices.push(uvOffsetV+g.uvs[index*2+1]*uvScaleV);
		vertices.push(textureId); vertices.push(((material.color >> 16) & 255)/255. * red);
		vertices.push(((material.color >> 8) & 255)/255. * green); vertices.push((material.color & 255)/255. * blue);
		vertices.push(material.opacity * alpha);
		if (lit) {
			vertices.push(normals[index*3]); vertices.push(normals[index*3+1]); vertices.push(normals[index*3+2]);
		}
		if (mapped) { vertices.push(g.uvs[index*2]); vertices.push(g.uvs[index*2+1]); }
		if (normalMapped) for (i in 0...4) vertices.push(tangents[index*4+i]);
		return result;
	}
}
