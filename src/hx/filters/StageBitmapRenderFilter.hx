package hx.filters;

import hx.core.Hxmaker;
import hx.core.OpenFlBitmapData;
import hx.display.BitmapData;
import hx.display.Image;

/**
 * 使用位图渲染的渲染滤镜，可以将渲染对象渲染为位图进行显示；该滤镜的位图渲染尺寸会保持与舞台尺寸一致，不会因为渲染对象的尺寸而改变。
 */
class StageBitmapRenderFilter extends RenderFilter {
	/**
	 * 位图渲染数据
	 */
	public var bitmapData:BitmapData;

	public var keep:Bool = false;

	public function new(keep:Bool = false) {
		this.keep = keep;
		super();
	}

	override function init() {
		super.init();
		isStageRenderFilter = true;
		if (keep)
			bitmapData = OpenFlBitmapData.fromSize(Std.int(Hxmaker.engine.stageWidth), Std.int(Hxmaker.engine.stageHeight), true, 0x0);
		else
			bitmapData = new StageBitmapData();
		var image = new Image();
		image.data = bitmapData;
		this.render = image;
	}

	/** 独占缓存被另一个持久快照读取时，先换目标再重绘，旧画面继续读取旧根。 */
	private function prepareWritableBitmap():Void {
		if (!keep || bitmapData == null || !(bitmapData.data is hx.display.IBitmapDataLifetime)
			|| cast(bitmapData.data, hx.display.IBitmapDataLifetime).getRenderReferences() == 0) return;
		var replacement:BitmapData = OpenFlBitmapData.fromSize(Math.ceil(Hxmaker.engine.stageWidth), Math.ceil(Hxmaker.engine.stageHeight), true, 0);
		bitmapData.dispose(); bitmapData = replacement; cast(render, Image).data = replacement;
	}

	override function dispose():Void {
		super.dispose();
		if (bitmapData != null) bitmapData.dispose();
		bitmapData = null;
	}

	override function updateStageSize() {
		super.updateStageSize();
		if (keep && bitmapData != null) {
			var replacement:BitmapData = OpenFlBitmapData.fromSize(Math.ceil(Hxmaker.engine.stageWidth), Math.ceil(Hxmaker.engine.stageHeight), true, 0);
			bitmapData.dispose(); bitmapData = replacement;
			cast(render, Image).data = replacement;
		}
	}
}
