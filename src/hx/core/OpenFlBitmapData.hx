package hx.core;

import openfl.geom.Rectangle;
import hx.display.BlendMode;
import hx.geom.Matrix;
import hx.display.DisplayObject;
import openfl.display.BitmapData;
import hx.display.IBitmapData;
import hx.render2d.openfl.RenderBitmapData;

/**
 * OpenFL纹理
 */
class OpenFlBitmapData implements IBitmapData implements hx.display.IBitmapDataLifetime {
	private var disposed:Bool = false;
	/**
	 * 通过`openfl.display.BitmapData`创建`hx.display.BitmapData`
	 * @param bitmapData 
	 * @return hx.display.BitmapData
	 */
	public static function fromBitmapData(bitmapData:BitmapData):hx.display.BitmapData {
		return hx.display.BitmapData.formData(new OpenFlBitmapData(bitmapData));
	}

	/**
	 * 创建一个指定大小的`hx.display.BitmapData`
	 * @param width 宽度
	 * @param height 高度
	 * @param transparent 是否透明
	 * @param fillColor 填充颜色
	 * @return hx.display.BitmapData
	 */
	public static function fromSize(width:Int, height:Int, transparent:Bool = false, fillColor:Int = 0xffffff):hx.display.BitmapData {
		hx.render2d.openfl.RenderTargetBudget.validate(width, height);
		return fromBitmapData(new RenderBitmapData(width, height, transparent, fillColor));
	}

	private static var __bitmapDataRender:Render;
	private static var renderPool:Array<Render> = [];
	private static var renderDepth:Int = 0;

	public static function getBitmapDataRender():Render {
		if (__bitmapDataRender == null) {
			__bitmapDataRender = new Render();
		}
		return __bitmapDataRender;
	}

	private var __root:BitmapData;

	public function new(root:BitmapData) {
		this.__root = root;
		if (root != null) hx.render2d.openfl.TextureLifetime.record(root).owners++;
	}

	public function getTexture():Dynamic {
		return disposed ? null : __root;
	}

	public function getWidth():Int {
		return !disposed && __root != null ? __root.width : 0;
	}

	public function getHeight():Int {
		return !disposed && __root != null ? __root.height : 0;
	}

	public function draw(source:DisplayObject, matrix:Matrix, ?blendMode:BlendMode, updateTransform:Bool = true):Void {
		if (!isAvailable() || source == null) return;
		if (renderDepth >= 16) throw new hx.render2d.openfl.TextureInputError(Unsupported, 0, "离屏输出", "截图嵌套深度超过预算");
		var render:Render = renderPool.length == 0 ? new Render() : renderPool.pop();
		renderDepth++;
		try {
			render.clear();
			render.enableRenderFilterDisplayObject = source;
			if (__root.readable) __root.disposeImage();
			if (updateTransform) {
				if (source.stage != null && @:privateAccess source.stage.__transformDirty)
					@:privateAccess source.stage.__updateTransform(null);
				else if (@:privateAccess source.__transformDirty) @:privateAccess source.__updateTransform(null);
			}
			render.renderDisplayObject(source);
			render.endFill();
			__root.draw(render.stage, new openfl.geom.Matrix(matrix.a, matrix.b, matrix.c, matrix.d, matrix.tx, matrix.ty), null,
				blendMode == null ? null : cast blendMode);
		} catch (error:Dynamic) {
			try { releaseRender(render); } catch (cleanupError:Dynamic) {}
			throw error;
		}
		releaseRender(render);
	}

	/** 立即消费完成后拆离快照并归还上下文，空闲缓存最多保留四个。 */
	private static function releaseRender(render:Render):Void {
		render.enableRenderFilterDisplayObject = null;
		renderDepth--;
		render.clear();
		if (renderPool.length < 4) renderPool.push(render); else render.dispose();
	}

	/**
	 * 清除当前位图数据
	 */
	public function clear(?rect:hx.geom.Rectangle):Void {
		if (!isAvailable()) return;
		if (__root.readable) {
			__root.disposeImage();
		}
		__root.fillRect(rect != null ? new Rectangle(rect.x, rect.y, rect.width, rect.height) : __root.rect, 0);
	}

	/** 公开包装器已释放后禁止新消费者取得纹理。 */
	public function isAvailable():Bool {
		return !disposed && __root != null && __root.width > 0 && __root.height > 0
			&& !hx.render2d.openfl.TextureLifetime.record(__root).pending;
	}
	/** 提供缓存安全回收所需的实际快照持有数。 */
	public function getRenderReferences():Int {
		return __root == null ? 0 : hx.render2d.openfl.TextureLifetime.record(__root).references;
	}

	/**
	 * 释放位图数据
	 */
	public function dispose():Void {
		if (disposed) return;
		disposed = true;
		if (__root != null) {
			var state:hx.render2d.openfl.TextureLifetime.TextureRecord = hx.render2d.openfl.TextureLifetime.record(__root);
			state.owners--;
			if (state.owners == 0) hx.render2d.openfl.TextureLifetime.requestDispose(__root, "OpenFlBitmapData.dispose");
		}
		__root = null;
	}
}
