package hx.render3d.openfl;

import hx.display.BitmapData;
import openfl.display3D.Context3D;
import lime.graphics.opengl.GLTexture;

/** 复用 Assets 持有的 OpenFL 纹理，不接管源纹理生命周期。 */
@:access(openfl.display3D.textures.TextureBase)
@:access(openfl.display.BitmapData)
class TextureBridge3D {
	public static function source(bitmap:BitmapData, white:openfl.display.BitmapData):openfl.display.BitmapData {
		if (bitmap == null) return white;
		if (bitmap.data == null) throw "三维材质纹理已经释放";
		var root = bitmap.data.getTexture();
		if (!Std.isOfType(root, openfl.display.BitmapData)) throw "当前三维后端只接受 OpenFL 位图纹理";
		var result:openfl.display.BitmapData = cast root;
		if (result.width <= 0 || result.height <= 0) throw "三维材质纹理尺寸无效";
		if (bitmap.frameRect != null) throw "三维首版暂不支持带裁边还原信息的图集帧";
		return result;
	}
	public static function resolve(source:openfl.display.BitmapData, context:Context3D):GLTexture {
		var texture = source.getTexture(context);
		if (texture == null || texture.__alphaTexture != null) throw "三维首版不支持无效纹理或分离 Alpha 压缩纹理";
		return texture.__textureID;
	}
	/** BitmapData 的上传区域可能因二次幂配置而比逻辑区域大。 */
	public static function uvSize(source:openfl.display.BitmapData):Array<Float> {
		return [source.__textureWidth, source.__textureHeight];
	}
}
