package hx.render2d.openfl;

#if hx_astcenc
import haxe.io.Bytes;
import openfl.display.BitmapData;
import openfl.display.ASTCBitmapData;
import openfl.display3D.Context3D;
import openfl.display3D.textures.TextureBase;

/** 在后端保留有预算的压缩恢复来源，不修改 ASTC、OpenFL 或 Lime。 */
@:access(openfl.display.BitmapData)
@:access(openfl.display3D.Context3D)
@:access(openfl.display3D._internal.Context3DState)
class RecoverableASTCBitmapData extends BitmapData {
	public static var maxSourceBytes:Int = 67108864;
	public static var sourceBytes(default, null):Int = 0;
	private var compressed:Bytes;
	private var originalPath:String;
	private var deviceGeneration:Int;
	private var fallbackStarted:Bool = false;
	private var fallbackReady:Bool = false;
	/** 是否已经完成有界原图回退，供诊断验收读取。 */
	public var fallbackActive(get, never):Bool;
	private function get_fallbackActive():Bool { return fallbackReady; }
	private var terminalFailure:Bool = false;
	private var terminalKind:TextureInputError.TextureFaultKind = Unsupported;

	/** 初次上传仍使用依赖的解码器，恢复来源由引擎后端接管。 */
	public static function decode(bytes:Bytes, originalPath:String = null):RecoverableASTCBitmapData {
		if (bytes == null || sourceBytes + bytes.length > maxSourceBytes)
			throw new TextureInputError(Unsupported, 0, "ASTC", "ASTC 恢复字节超过预算，请使用普通图片");
		return new RecoverableASTCBitmapData(decodeNative(bytes), bytes, originalPath);
	}
	/** 解码器会直接绑定 GL 纹理；仅在分配和恢复时保存它实际修改的状态。 */
	private static function decodeNative(bytes:Bytes):BitmapData {
		var context:Context3D = openfl.Lib.current.stage.context3D;
		var gl:lime.graphics.WebGLRenderContext = context.gl;
		var slot:Int = gl.getParameter(gl.ACTIVE_TEXTURE);
		var binding:Dynamic = gl.getParameter(gl.TEXTURE_BINDING_2D);
		var cached:Dynamic = context.__contextState.__currentGLTexture2D;
		var generation:Int = TextureLifetime.generation();
		var result:BitmapData;
		try { result = ASTCBitmapData.fromBytes(bytes); }
		catch (error:Dynamic) {
			if (!gl.isContextLost() && generation == TextureLifetime.generation()) {
				gl.activeTexture(slot); gl.bindTexture(gl.TEXTURE_2D, binding); context.__contextState.__currentGLTexture2D = cached;
			}
			throw error;
		}
		if (!gl.isContextLost() && generation == TextureLifetime.generation()) {
			gl.activeTexture(slot); gl.bindTexture(gl.TEXTURE_2D, binding); context.__contextState.__currentGLTexture2D = cached;
		}
		return result;
	}

	private function new(decoded:BitmapData, bytes:Bytes, originalPath:String) {
		super(0, 0, true, 0);
		width = decoded.width; height = decoded.height; rect = decoded.rect.clone();
		__textureWidth = width; __textureHeight = height; __isValid = true; readable = false;
		__texture = decoded.__texture; __textureContext = decoded.__textureContext;
		decoded.__texture = null; decoded.dispose();
		compressed = bytes; sourceBytes += bytes.length;
		this.originalPath = originalPath; deviceGeneration = TextureLifetime.generation();
	}
	/** 每个设备代次最多进行一次压缩重建或一次原图回退；终态不逐帧重试。 */
	override public function getTexture(context:Context3D):TextureBase {
		if (!__isValid) return null;
		if (terminalFailure) throw fault(terminalKind, "ASTC 恢复已进入终态失败");
		if (fallbackReady) return super.getTexture(context);
		if (fallbackStarted) throw fault(NotReady, "等待 ASTC 原图回退");
		if (deviceGeneration != TextureLifetime.generation()) {
			deviceGeneration = TextureLifetime.generation();
			if (!ASTCBitmapData.isSupportASTCConfig()) {
				if (originalPath == null) { terminalFailure = true; throw fault(Unsupported, "恢复后的设备不支持 ASTC 且没有原图路径"); }
				startFallback(); throw fault(NotReady, "设备能力变化，正在加载原始图片");
			}
			try {
				var decoded:BitmapData = decodeNative(compressed);
				__texture = decoded.__texture; __textureContext = decoded.__textureContext;
				decoded.__texture = null; decoded.dispose();
			} catch (error:Dynamic) {
				terminalFailure = true; terminalKind = UploadFailed; throw fault(UploadFailed, "ASTC 重建失败");
			}
		}
		return __texture;
	}
	/** 能力改变后仅请求一次稳定原图，完成时触发真实重绘。 */
	private function startFallback():Void {
		fallbackStarted = true;
		BitmapData.loadFromFile(hx.assets.Assets.getDefaultNativePath(originalPath)).onComplete(function(bitmap:BitmapData):Void {
			if (!__isValid) { bitmap.dispose(); return; }
			if (bitmap.width != width || bitmap.height != height) {
				bitmap.dispose(); terminalFailure = true; terminalKind = InvalidSize; invalidateStages(); return;
			}
			image = bitmap.image; bitmap.image = null;
			__texture = null; __textureContext = null; __textureVersion = -1;
			readable = true; fallbackReady = true;
			releaseSource();
			invalidateStages();
		}).onError(function(error:Dynamic):Void { terminalFailure = true; terminalKind = UploadFailed; invalidateStages(); });
	}
	/** 成功和终态失败均触发一次重绘，让业务收到最终状态。 */
	private function invalidateStages():Void { for (stage in hx.core.Hxmaker.engine.stages) stage.invalidate(); }
	private function fault(kind:TextureInputError.TextureFaultKind, message:String):TextureInputError {
		return new TextureInputError(kind, TextureLifetime.record(this).resourceId, "ASTC", message);
	}
	/** 字节预算随最终资源释放归还。 */
	private function releaseSource():Void {
		if (compressed != null) { sourceBytes -= compressed.length; compressed = null; }
	}
	override public function dispose():Void { releaseSource(); super.dispose(); }
}
#end
