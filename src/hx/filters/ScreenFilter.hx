package hx.filters;

import hx.display.DisplayObject;
import hx.core.Hxmaker;
import hx.core.OpenFlBitmapData;
import hx.display.Image;

/**
 * 漂白滤镜，这是提供给图层容器的滤镜，如果非容器，则直接使用`SCREEN`渲染即可
 */
class ScreenFilter extends StageBitmapRenderFilter {
	public var displayImage:Image;

	override function init() {
		super.init();
		displayImage = new Image(OpenFlBitmapData.fromSize(Std.int(Hxmaker.engine.stageWidth), Std.int(Hxmaker.engine.stageHeight), true, 0x0));
		this.render = displayImage;
		this.render.blendMode = SCREEN;
	}

	override function update(display:DisplayObject, dt:Float) {
		super.update(display, dt);
		displayImage.data.clear();
		displayImage.data.draw(display);
	}
}
