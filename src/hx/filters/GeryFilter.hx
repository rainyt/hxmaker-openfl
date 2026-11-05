package hx.filters;

import hx.core.OpenFlBitmapData;
import hx.display.BitmapData;
import hx.display.DisplayObject;
import hx.display.Image;
import hx.display.IBitmapDataLifetime;
import hx.shader.GeryShader;

/** 灰度缓存按尺寸复用，替换时交由快照持有协议延后销毁旧结果。 */
class GeryFilter extends DisplayObjectFilter {
	private var cached:BitmapData;
	/** 只有脏更新才绘制，临时 Shader 和失败分配均配对恢复。 */
	override public function update(display:DisplayObject, dt:Float):Void {
		super.update(display, dt);
		if (!__dirty) return;
		var bounds:hx.geom.Rectangle = display.getBounds(display);
		if (!Math.isFinite(bounds.width) || !Math.isFinite(bounds.height) || bounds.width < 0 || bounds.height < 0)
			hx.render2d.openfl.RenderTargetBudget.validate(bounds.width, bounds.height);
		if (bounds.width == 0 || bounds.height == 0) {
			if (cached != null) cached.dispose();
			cached = null; render = null; __dirty = false; return;
		}
		var reuse:Bool = cached != null && cached.width == Math.ceil(bounds.width) && cached.height == Math.ceil(bounds.height)
			&& cached.data is IBitmapDataLifetime && cast(cached.data, IBitmapDataLifetime).isAvailable()
			&& cast(cached.data, IBitmapDataLifetime).getRenderReferences() == 0;
		var next:BitmapData = reuse ? cached : createCacheBitmapData(bounds.width, bounds.height);
		var previousShader:hx.display.Shader = display.shader;
		try {
			next.clear(); display.shader = GeryShader.getInstance();
			drawToBitmapData(next, display);
		} catch (error:Dynamic) {
			display.shader = previousShader;
			if (!reuse) next.dispose();
			throw error;
		}
		display.shader = previousShader;
		if (!reuse && cached != null) cached.dispose();
		cached = next;
		if (render == null) render = new Image(next); else cast(render, Image).data = next;
		__dirty = false; updateTransform(display);
	}
	/** 缓存由滤镜独占；允许再次使用时显式调用 init。 */
	override public function dispose():Void {
		if (cached != null) cached.dispose();
		cached = null; super.dispose();
	}
}
