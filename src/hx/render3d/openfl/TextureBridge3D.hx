package hx.render3d.openfl;

import hx.display.BitmapData;
import openfl.display3D.Context3D;
import lime.graphics.opengl.GLTexture;
import openfl.display3D.textures.TextureBase;
import openfl.display._internal.SamplerState;

/** 复用 Assets 持有的 OpenFL 纹理，不接管源纹理生命周期。 */
@:access(openfl.display3D.textures.TextureBase)
@:access(openfl.display.BitmapData)
@:access(openfl.display3D.Context3D)
class TextureBridge3D {
	private static var nearestSampler:SamplerState = new SamplerState(CLAMP, NEAREST, MIPNONE);
	private static var linearSampler:SamplerState = new SamplerState(CLAMP, LINEAR, MIPNONE);
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
	public static function resolve(source:openfl.display.BitmapData, context:Context3D):TextureBase {
		var texture = source.getTexture(context);
		if (texture == null || texture.__alphaTexture != null) throw "三维首版不支持无效纹理或分离 Alpha 压缩纹理";
		return texture;
	}
	public static function handle(texture:TextureBase):GLTexture { return texture.__textureID; }
	/** 使用 OpenFL 的采样状态缓存，临时切换与恢复都经过同一个协议。 */
	public static function applySampler(texture:TextureBase, smoothing:Bool):Void {
		texture.__setSamplerState(smoothing ? linearSampler : nearestSampler);
	}
	public static function samplerSnapshot(texture:TextureBase):SamplerState {
		return texture.__samplerState == null ? null : texture.__samplerState.clone();
	}
	public static function restoreSampler(texture:TextureBase, previous:SamplerState):Void {
		var gl = texture.__context.gl;
		// 原始 GL 合成可能已改变绑定，不能依赖 OpenFL 的绑定缓存。
		gl.bindTexture(gl.TEXTURE_2D, texture.__textureID);
		if (previous != null) {
			texture.__setSamplerState(previous);
		} else {
			// 尚未设置过采样状态的 OpenFL 纹理仍使用 GL 初始值。
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_LINEAR);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
			texture.__samplerState = null;
		}
	}
	/** 完整查询兼容路径恢复时同步回原有缓存，避免实际状态与缓存分离。 */
	public static function restoreSamplerCache(texture:TextureBase, previous:SamplerState):Void {
		texture.__samplerState = previous;
	}
	/** BitmapData 的上传区域可能因二次幂配置而比逻辑区域大。 */
	public static function uvSize(source:openfl.display.BitmapData):Array<Float> {
		return [source.__textureWidth, source.__textureHeight];
	}
}
