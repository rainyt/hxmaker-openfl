package hx.render2d.openfl;

import openfl.display.BitmapData;
import openfl.display3D.Context3D;
import openfl.display3D.textures.TextureBase;

/** 二维输入的严格分类；发布隔离只在批次边界捕获本类型错误。 */
@:access(openfl.display.BitmapData)
@:access(openfl.display3D.Context3D)
@:access(openfl.display3D.textures.TextureBase)
class TextureBridge2D {
	/** 纯逻辑预检，不改变 GL 状态。旧快照可以读取待释放资源。 */
	public static function validate(bitmap:BitmapData, inputName:String):TextureLifetime.TextureRecord {
		if (bitmap == null) throw new TextureInputError(NotReady, 0, inputName, "缺少必需的二维纹理输入");
		var state:TextureLifetime.TextureRecord = TextureLifetime.record(bitmap);
		if (state.disposed || !bitmap.__isValid) throw new TextureInputError(Disposed, state.resourceId, inputName, "二维输入已被释放");
		if (bitmap.width <= 0 || bitmap.height <= 0) throw new TextureInputError(InvalidSize, state.resourceId, inputName, "二维输入尺寸无效");
		if (RenderPass.contains(bitmap)) throw new TextureInputError(Feedback, state.resourceId, inputName, "不能采样当前正在写入的离屏目标");
		return state;
	}

	/** 上传及恢复发生在状态保护之内，失败不污染后续批次。 */
	public static function resolve(bitmap:BitmapData, context:Context3D, inputName:String):TextureBase {
		var state:TextureLifetime.TextureRecord = validate(bitmap, inputName);
		if (context == null || context.gl.isContextLost()) throw new TextureInputError(DeviceLost, state.resourceId, inputName, "渲染设备暂不可用");
		TextureRecovery.prepare(bitmap, context, inputName, state);
		var texture:TextureBase;
		try { texture = bitmap.getTexture(context); }
		catch (error:TextureInputError) { throw error; }
		catch (error:Dynamic) { throw new TextureInputError(UploadFailed, state.resourceId, inputName, "二维输入纹理上传失败：" + Std.string(error)); }
		if (texture == null || texture.__textureID == null) throw new TextureInputError(UploadFailed, state.resourceId, inputName, "二维输入没有可用 GPU 句柄");
		if (texture.__alphaTexture != null) throw new TextureInputError(Unsupported, state.resourceId, inputName, "二维直接路径不支持分离 Alpha 压缩纹理");
		return texture;
	}
}
