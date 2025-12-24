package hx.filters;

import hx.display.Image;
import hx.display.DisplayObjectContainer;
import hx.display.DisplayObject;

/**
 * 透明度组滤镜，对应`BlendMode.LAYER`
 */
@:access(hx.display.DisplayObject)
class LayerFilter extends BlendModeFilter {
	private var __image:Image;

	override function init() {
		super.init();
		this.__image = cast this.render;
		this.render.shader = hx.shader.LayerShader.getInstance();
	}

	override function update(display:DisplayObject, dt:Float) {
		super.update(display, dt);
		if (display is DisplayObjectContainer) {
			this.render = this.__image;
			this.bitmapData.clear();
			var oldAlpha = display.alpha;
			display.alpha = 1;
			display.__updateTransform(null);
			this.bitmapData.draw(display, null, null, false);
			display.alpha = oldAlpha;
			this.render.__worldAlpha = display.__worldAlpha;
			this.render.alpha = display.alpha;
		} else {
			this.render = display;
		}
	}
}
