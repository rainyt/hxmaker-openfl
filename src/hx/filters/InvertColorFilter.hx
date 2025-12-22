package hx.filters;

import hx.shader.InvertShader;
import hx.display.DisplayObject;

/**
 * 反色滤镜
 */
class InvertColorFilter extends StageBitmapRenderFilter {
	override function init() {
		super.init();
		this.render.shader = new InvertShader();
	}

	override function update(display:DisplayObject, dt:Float) {
		super.update(display, dt);
		this.bitmapData.clear();
		this.bitmapData.draw(display);
	}
}
