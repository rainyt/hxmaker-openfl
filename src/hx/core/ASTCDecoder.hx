package hx.core;

#if hx_astcenc
import haxe.io.Bytes;
import hx.display.BitmapData;
import hx.assets.astc.IASTCDecoder;
import openfl.display.ASTCBitmapData;

/**
 * OpenFL 后端的 ASTC 能力实现，核心在首次加载图片时绑定这个实例。
 */
class ASTCDecoder implements IASTCDecoder {
	public function new() {}

	/** 当前设备与渲染上下文是否支持 ASTC 纹理上传。 */
	public function isSupported():Bool {
		try {
			return ASTCBitmapData.isSupportASTCConfig();
		} catch (error:Dynamic) {
			return false;
		}
	}

	/** 把校验过的 ASTC 字节直接上传为 GPU 压缩纹理。 */
	public function fromBytes(bytes:Bytes):BitmapData {
		return BitmapData.formData(new OpenFlBitmapData(ASTCBitmapData.fromBytes(bytes)));
	}

	/** 使用 Lime 的平台 zlib 实现，避免在 JS 上重复纯 Haxe 解压。 */
	public function inflate(bytes:Bytes):Bytes {
		var source:lime.utils.Bytes = bytes;
		return source.decompress(lime.utils.CompressionAlgorithm.ZLIB);
	}
}
#end
