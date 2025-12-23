package hx.filters;

import hx.shader.BlurShader;
import hx.core.Hxmaker;
import hx.core.OpenFlBitmapData;
import hx.display.Image;
import hx.display.DisplayObject;
import hx.display.Quad;

/**
 * 模糊滤镜
 */
class BlurFilter extends StageBitmapRenderFilter {
	/**
	 * 模糊图像
	 */
	public var blurImage:Image = new Image();

	/**
	 * 水平模糊值
	 */
	public var blurX(default, set):Int = 10;

	/**
	 * 垂直模糊值
	 */
	public var blurY(default, set):Int = 10;

	private function set_blurX(value:Int):Int {
		this.invalidate();
		return blurX = value;
	}

	private function set_blurY(value:Int):Int {
		this.invalidate();
		return blurY = value;
	}

	public function new(blurX:Int = 10, blurY:Int = 10) {
		this.blurX = blurX;
		this.blurY = blurY;
		super();
	}

	override function init() {
		super.init();
		blurImage.data = OpenFlBitmapData.fromSize(Std.int(Hxmaker.engine.stageWidth), Std.int(Hxmaker.engine.stageHeight), true, 0x0);
		blurImage.shader = new BlurShader(blurX, blurY);
	}

	override function update(display:DisplayObject, dt:Float) {
		super.update(display, dt);
		if (!__dirty)
			return;
		__dirty = false;
		this.blurImage.data.clear();
		this.blurImage.data.draw(display);
		this.bitmapData.clear();
		this.bitmapData.draw(display);
		var quad = new Quad(50, 50, 0xff0000);
		quad.y = 300;
		for (i in 0...blurX) {
			cast(blurImage.shader, BlurShader).updateBlur(i, 0);
			this.blurImage.data.draw(this.render);
			this.bitmapData.draw(blurImage);
		}
		for (i in 0...blurY) {
			cast(blurImage.shader, BlurShader).updateBlur(0, i);
			this.blurImage.data.draw(this.render);
			this.bitmapData.draw(blurImage);
		}
	}
}
