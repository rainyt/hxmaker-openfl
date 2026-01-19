package hx.filters;

import hx.shader.StrokeShader;
import hx.geom.Matrix;
import hx.core.OpenFlBitmapData;
import hx.display.DisplayObject;
import hx.display.Image;

/**
 * 描边滤镜
 */
@:access(hx.display.DisplayObject)
class StrokeFilter extends DisplayObjectFilter {
	private static var shader:StrokeShader;

	public var image:Image = new Image();

	private var ready = new Image();

	public function new(strokeSize:Int = 3, strokeColor:UInt = 0x0, fontColor:UInt = 0xffffff, bold:Int = 0) {
		this.strokeSize = strokeSize;
		this.strokeColor = strokeColor;
		this.fontColor = fontColor;
		this.bold = bold;
		super();
	}

	override function init() {
		super.init();
		if (shader == null)
			shader = new StrokeShader(1, 0, 0, 0);
	}

	/**
	 * 文本加粗
	 */
	public var bold:Int = 1;

	/**
	 * 描边宽度
	 */
	public var strokeSize:Int = 3;

	/**
	 * 描边颜色
	 */
	public var strokeColor:UInt = 0x0;

	/**
	 * 字体颜色
	 */
	public var fontColor:UInt = 0xffffff;

	private var __textureWidth:Float = 0;
	private var __textureHeight:Float = 0;
	private var __offsetX:Float = 0;
	private var __offsetY:Float = 0;

	override function update(display:DisplayObject, dt:Float) {
		super.update(display, dt);
		if (!__dirty) {
			return;
		}
		__dirty = false;
		// var width = display.width;
		// var height = display.height;
		// var rect = display.__getLocalBounds(display.__getRect());
		var rect = display.getBounds(null);
		if (rect.width <= 0 || rect.height <= 0) {
			return;
		}
		__offsetX = rect.x;
		__offsetY = rect.y;
		image.data = OpenFlBitmapData.fromSize(Std.int(rect.width + strokeSize * 4), Std.int(rect.height + strokeSize * 4), true, 0x0);
		ready.data = OpenFlBitmapData.fromSize(Std.int(rect.width + strokeSize * 4), Std.int(rect.height + strokeSize * 4), true, 0x0);
		var m = new Matrix();
		m.translate(strokeSize - rect.x, strokeSize - rect.y);
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
		shader.updateSize(image.data.width, image.data.height);
		shader.updateParam(strokeSize, strokeColor);
		shader.updateIntensity(6);
		ready.shader = shader;
		image.data.draw(ready);

		shader.updateParam(bold, fontColor);
		ready.shader = shader;
		// ready.shader = null;
		image.data.draw(ready);
		this.render = image;

		this.updateTransform(display);
	}

	override function updateTransform(display:DisplayObject) {
		if (render != null) {
			this.render.__worldAlpha = display.__worldAlpha;
			this.render.__worldTransform.copyFrom(display.__worldTransform);
			this.render.__worldTransform.translate(-strokeSize + __offsetX, -strokeSize + __offsetY);
		}
	}
}
