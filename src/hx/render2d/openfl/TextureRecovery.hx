package hx.render2d.openfl;

import openfl.display.BitmapData;
import openfl.display3D.Context3D;

/** 按设备代次废弃句柄；有像素的输入重传，离屏目标由滤镜重新绘制。 */
@:access(openfl.display.BitmapData)
class TextureRecovery {
	/** 调用前必须持有资源，逻辑已释放的位图不会进入恢复路径。 */
	public static function prepare(bitmap:BitmapData, context:Context3D, inputName:String, state:TextureLifetime.TextureRecord = null):Void {
		if (state == null) state = TextureLifetime.record(bitmap);
		if (state.generation == TextureLifetime.generation()) return;
		if (bitmap.image == null && !(bitmap is RenderBitmapData) #if hx_astcenc && !(bitmap is RecoverableASTCBitmapData) #end)
			throw new TextureInputError(MissingRecovery, state.resourceId, inputName, "GPU 资源没有像素或重绘来源，禁止以空纹理伪装恢复成功");
		bitmap.__texture = null; bitmap.__textureContext = null; bitmap.__textureVersion = -1;
		bitmap.__framebuffer = null; bitmap.__framebufferContext = null;
		bitmap.__vertexBuffer = null;
		state.generation = TextureLifetime.generation();
	}
}
