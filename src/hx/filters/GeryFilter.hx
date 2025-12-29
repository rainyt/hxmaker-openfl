package hx.filters;

import hx.geom.Matrix;
import hx.shader.GeryShader;
import hx.core.OpenFlBitmapData;
import hx.display.Image;
import hx.display.DisplayObject;

/**
 * 灰度滤镜
 */
class GeryFilter extends DisplayObjectFilter {
	override function update(display:DisplayObject, dt:Float) {
		super.update(display, dt);
		if (__dirty) {
			var rect = display.getBounds();
			var image = new Image(OpenFlBitmapData.fromSize(Std.int(rect.width), Std.int(rect.height), true, 0x0));
			var cache = this.createCacheBitmapData(rect.width, rect.height);
			var oldShader = display.shader;
			display.shader = GeryShader.getInstance();
			this.drawToBitmapData(cache, display);
			display.shader = oldShader;
			image.data.clear();
			image.data.draw(new Image(cache));
			this.render = image;
			__dirty = false;
			this.updateTransform(display);
		}
	}
}
