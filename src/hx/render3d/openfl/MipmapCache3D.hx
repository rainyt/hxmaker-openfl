package hx.render3d.openfl;

import haxe.ds.ObjectMap;
import hx.display.BitmapData;
import hx.material.TextureMinFilter3D;
import openfl.display3D.textures.TextureBase;

/** 记录共享纹理的 mip 链版本；GPU 资源仍随 OpenFL 位图释放，不复制基础层。 */
@:access(openfl.display.BitmapData)
@:access(openfl.display3D.textures.TextureBase)
class MipmapCache3D {
	private var entries:ObjectMap<openfl.display.BitmapData, {texture:TextureBase, version:Int}> = new ObjectMap();
	private var warnings:ObjectMap<openfl.display.BitmapData, Bool> = new ObjectMap();
	public function new() {}

	/** 仅对无图集、无填充、可追踪 CPU 版本的二次幂整图启用硬件采样。 */
	public static function supported(bitmap:BitmapData, source:openfl.display.BitmapData):Bool {
		var width = source.width, height = source.height;
		return (bitmap == null || bitmap.rect == null) && source.image != null && width > 0 && height > 0
			&& (width & (width - 1)) == 0 && (height & (height - 1)) == 0
			&& width == source.__textureWidth && height == source.__textureHeight;
	}

	/** 必须在上传基础层、保存采样快照并绑定纹理之后调用。 */
	public function prepare(bitmap:BitmapData, source:openfl.display.BitmapData, texture:TextureBase, filter:Int):Int {
		if (filter < 9984) return filter;
		if (!supported(bitmap, source)) {
			if (!warnings.exists(source)) {
				warnings.set(source, true);
				trace("三维 mipmap 已降级为基础层过滤：需要无图集、无填充且保留 CPU 图片的二次幂整图。");
			}
			return TextureMinFilter3D.base(filter);
		}
		var previous = entries.get(source);
		if (previous == null || previous.texture != texture || previous.version != source.__textureVersion) {
			var gl = @:privateAccess texture.__context.gl;
			gl.bindTexture(gl.TEXTURE_2D, texture.__textureID);
			// RectangleTexture 不会自动生成 mip 链，必须在切换缩小过滤前显式生成。
			gl.generateMipmap(gl.TEXTURE_2D);
			entries.set(source, {texture: texture, version: source.__textureVersion});
		}
		return filter;
	}

	/** 不持有已经释放或已换上下文的源位图；渲染器销毁时清空其余记录。 */
	public function prune():Void {
		for (source in entries.keys()) {
			var entry = entries.get(source);
			if (!source.__isValid || source.__texture != entry.texture) entries.remove(source);
		}
		for (source in warnings.keys()) if (!source.__isValid) warnings.remove(source);
	}
	public function clear():Void { entries.clear(); warnings.clear(); }
}
