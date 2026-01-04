package hx.filters;

import hx.display.DisplayObject;
import hx.shader.SubtractFastShader;

/**
 * 减去滤镜，对应`BlendMode.SUBTRACT_FAST`
 */
class SubtractFastFilter extends BlendModeFilter {
	override function init() {
		super.init();
		this.render.shader = SubtractFastShader.getInstance();
	}

	override function update(display:DisplayObject, dt:Float) {
		//
		this.bitmapData.clear();
		this.bitmapData.draw(display);
	}
}
