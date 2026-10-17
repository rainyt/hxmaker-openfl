package hx.render3d.openfl;

import hx.display3d.MeshObject;
import hx.material.Material3D;
import hx.material.AlphaMode3D;
import hx.material.BlendMode3D;
import hx.material.CullMode3D;
import haxe.Json;

/** 一个稳定的绘制批次，纹理编号和索引仅在此批次中有效。 */
class MeshBatch3D {
	public static inline var MAX_VERTICES:Int = 65535;
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
	public var alphaCutoff:Float;
	public var cullMode:CullMode3D;
	public var depthTest:Bool;
	public var depthWrite:Bool;
	public var smoothing:Bool;
	public var colorMultiplyLinear:Bool;
	public var minSmoothing:Bool;
	public var wrapU:Int;
	public var wrapV:Int;
	public var mirrored:Bool;
	public var slots:Int;
	public var lit:Bool;
	public var receiveShadow:Bool;
	public var floatsPerVertex(get, never):Int;
	private function get_floatsPerVertex():Int { return lit ? 13 : 10; }
	public function new(material:Material3D, mirrored:Bool, slots:Int, receiveShadow:Bool = true) {
		uvCode = material.fragmentUVCode; textureNames = material.textureUniformNames();
		textureUniforms = material.getTextureUniforms(); baseTexture = material.texture;
		lit = material.lightingEnabled; colorMultiplyLinear = material.colorMultiplyLinear; this.receiveShadow = receiveShadow;
		key = materialKey(material, mirrored, receiveShadow); declarations = material.fragmentDeclarations; fragmentCode = material.fragmentCode;
		blendMode = material.blendMode;
		uniforms = material.getUniforms(); alphaMode = material.alphaMode; alphaCutoff = material.alphaCutoff;
		cullMode = material.cullMode; depthTest = material.depthTest;
		depthWrite = material.depthWrite && material.alphaMode != AlphaMode3D.BLEND;
		smoothing = material.smoothing; minSmoothing = material.textureMinSmoothing == null ? smoothing : material.textureMinSmoothing;
		wrapU = material.textureWrapU; wrapV = material.textureWrapV; this.mirrored = mirrored; this.slots = slots;
	}
	public static function materialKey(material:Material3D, mirrored:Bool, receiveShadow:Bool = true):String {
		return Json.stringify([material.fragmentUVCode, material.textureBindingKey(), material.textureUniformNames().join(","), material.fragmentDeclarations, material.fragmentCode, material.uniformKey(), Std.string(material.alphaMode),
			Std.string(material.blendMode), Std.string(material.alphaCutoff), Std.string(material.cullMode), Std.string(material.depthTest), Std.string(material.depthWrite),
			Std.string(!material.lightingEnabled && material.colorMultiplyLinear), Std.string(material.smoothing), Std.string(material.textureMinSmoothing == null ? material.smoothing : material.textureMinSmoothing),
			Std.string(material.textureWrapU), Std.string(material.textureWrapV), Std.string(mirrored), Std.string(material.lightingEnabled), Std.string(material.lightingEnabled && receiveShadow)]);
	}
	/** 添加一个顶点，颜色与透明度编码进顶点，避免为不同模型切换 uniform。 */
	public function vertex(mesh:MeshObject, index:Int, textureId:Int, world:Array<Float>, source:openfl.display.BitmapData, normals:Array<Float> = null):Int {
		var result = Std.int(vertices.length / floatsPerVertex), material = mesh.material, g = mesh.geometry;
		var colors = g.colors, offset = index * 4;
		var red = colors.length == 0 ? 1. : colors[offset];
		var green = colors.length == 0 ? 1. : colors[offset + 1];
		var blue = colors.length == 0 ? 1. : colors[offset + 2];
		var alpha = colors.length == 0 ? 1. : colors[offset + 3];
		var texture = material.texture, size = TextureBridge3D.uvSize(source);
		var x = 0., y = 0., width = source.width * 1., height = source.height * 1.;
		if (texture != null && texture.rect != null) { x = texture.rect.x; y = texture.rect.y; width = texture.rect.width; height = texture.rect.height; }
		for (v in [world[index*3], world[index*3+1], world[index*3+2], (x+g.uvs[index*2]*width)/size[0], (y+g.uvs[index*2+1]*height)/size[1],
			textureId * 1., ((material.color >> 16) & 255)/255. * red, ((material.color >> 8) & 255)/255. * green, (material.color & 255)/255. * blue, material.opacity * alpha]) vertices.push(v);
		if (lit) {
			vertices.push(normals[index*3]); vertices.push(normals[index*3+1]); vertices.push(normals[index*3+2]);
		}
		return result;
	}
}
