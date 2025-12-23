package hx.filters;

import hx.shader.StrokeShader;
import hx.geom.Matrix;
import hx.display.Box;
import hx.core.OpenFlBitmapData;
import hx.display.DisplayObject;
import hx.display.Image;

/**
 * 描边滤镜
 */
@:access(hx.display.DisplayObject)
class StrokeFilter extends RenderFilter {
	public var image:Image = new Image();

	private var ready = new Image();

	public function new(strokeSize:Int = 1) {
		this.strokeSize = strokeSize;
		super();
	}

	/**
	 * 描边宽度
	 */
	private var strokeSize:Int = 1;

	private var __textureWidth:Float = 0;
	private var __textureHeight:Float = 0;

	override function update(display:DisplayObject, dt:Float) {
		super.update(display, dt);
		if (!__dirty) {
			return;
		}
		__dirty = false;
		var width = display.width;
		var height = display.height;
		if (width <= 0 || height <= 0) {
			return;
		}
		image.data = OpenFlBitmapData.fromSize(Std.int(width + strokeSize * 4), Std.int(height + strokeSize * 4), true, 0x0);
		ready.data = OpenFlBitmapData.fromSize(Std.int(width + strokeSize * 4), Std.int(height + strokeSize * 4), true, 0x0);
		var m = new Matrix();
		m.translate(strokeSize, strokeSize);
		var clone = display.__worldTransform.clone();
		display.__worldTransform.identity();
		var oldAlpha = display.__worldAlpha;
		display.__worldAlpha = 1.0;
		ready.data.draw(display, m, null, false);
		display.__worldTransform.copyFrom(clone);
		display.__worldAlpha = oldAlpha;

		image.data.clear();

		// 先渲染黑色描边
		ready.x = ready.y = 0;
		var sShader = new StrokeShader(strokeSize, 0x0);
		sShader.updateSize(image.data.width, image.data.height);
		ready.shader = sShader;
		image.data.draw(ready);

		sShader.updateParam(1, 0xffffff);
		image.data.draw(ready);
		this.render = image;

		this.updateTransform(display);
	}

	override function updateTransform(display:DisplayObject) {
		if (render != null) {
			this.render.__worldAlpha = display.__worldAlpha;
			this.render.__worldTransform.copyFrom(display.__worldTransform);
			this.render.__worldTransform.translate(-strokeSize, -strokeSize);
		}
	}
}
