package hx.render3d.openfl;

import hx.display.MeshObject;
import hx.material.Material3D;
import hx.material.AlphaMode3D;
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
	public var uniforms:Map<String, Array<Float>>;
	public var alphaMode:AlphaMode3D;
	public var alphaCutoff:Float;
	public var cullMode:CullMode3D;
	public var depthTest:Bool;
	public var depthWrite:Bool;
	public var smoothing:Bool;
	public var mirrored:Bool;
	public var slots:Int;
	public function new(material:Material3D, mirrored:Bool, slots:Int) {
		key = materialKey(material, mirrored); declarations = material.fragmentDeclarations; fragmentCode = material.fragmentCode;
		uniforms = material.getUniforms(); alphaMode = material.alphaMode; alphaCutoff = material.alphaCutoff;
		cullMode = material.cullMode; depthTest = material.depthTest;
		depthWrite = material.depthWrite && material.alphaMode != AlphaMode3D.BLEND;
		smoothing = material.smoothing; this.mirrored = mirrored; this.slots = slots;
	}
	public static function materialKey(material:Material3D, mirrored:Bool):String {
		return Json.stringify([material.fragmentDeclarations, material.fragmentCode, material.uniformKey(), Std.string(material.alphaMode),
			Std.string(material.alphaCutoff), Std.string(material.cullMode), Std.string(material.depthTest), Std.string(material.depthWrite),
			Std.string(material.smoothing), Std.string(mirrored)]);
	}
	/** 添加一个顶点，颜色与透明度编码进顶点，避免为不同模型切换 uniform。 */
	public function vertex(mesh:MeshObject, index:Int, textureId:Int, world:Array<Float>, source:openfl.display.BitmapData):Int {
		var result = Std.int(vertices.length / 10), material = mesh.material, g = mesh.geometry;
		var texture = material.texture, size = TextureBridge3D.uvSize(source);
		var x = 0., y = 0., width = source.width * 1., height = source.height * 1.;
		if (texture != null && texture.rect != null) { x = texture.rect.x; y = texture.rect.y; width = texture.rect.width; height = texture.rect.height; }
		for (v in [world[index*3], world[index*3+1], world[index*3+2], (x+g.uvs[index*2]*width)/size[0], (y+g.uvs[index*2+1]*height)/size[1],
			textureId * 1., ((material.color >> 16) & 255)/255., ((material.color >> 8) & 255)/255., (material.color & 255)/255., material.opacity]) vertices.push(v);
		return result;
	}
}
