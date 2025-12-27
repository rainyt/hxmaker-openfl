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

	override function init() {
		super.init();
		isStageRenderFilter = true;
		bitmapData = OpenFlBitmapData.fromSize(Std.int(Hxmaker.engine.stageWidth), Std.int(Hxmaker.engine.stageHeight), true, 0x0);
		var image = new Image();
		image.data = bitmapData;
		this.render = image;
	}

	override function dispose():Void {
		super.dispose();
		bitmapData.dispose();
	}

	override function updateStageSize() {
		super.updateStageSize();
		bitmapData.data = OpenFlBitmapData.fromSize(Std.int(Hxmaker.engine.stageWidth), Std.int(Hxmaker.engine.stageHeight), true, 0x0).data;
	}
}
