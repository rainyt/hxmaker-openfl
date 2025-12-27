package hx.filters;

import motion.easing.Linear;
import motion.Actuate;
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
	public var blurX(default, set):Float = 10;

	/**
	 * 垂直模糊值
	 */
	public var blurY(default, set):Float = 10;

	/**
	 * 是否强制刷新
	 */
	public var forceDirty:Bool = false;

	private function set_blurX(value:Float):Float {
		this.invalidate();
		return blurX = value;
	}

	private function set_blurY(value:Float):Float {
		this.invalidate();
		return blurY = value;
	}

	public function new(blurX:Float = 10, blurY:Float = 10) {
		this.blurX = blurX;
		this.blurY = blurY;
		super();
	}

	override function init() {
		super.init();
		blurImage.data = OpenFlBitmapData.fromSize(Std.int(Hxmaker.engine.stageWidth), Std.int(Hxmaker.engine.stageHeight), true, 0x0);
		blurImage.shader = BlurShader.getInstance();
	}

	override function update(display:DisplayObject, dt:Float) {
		super.update(display, dt);
		if (!__dirty && !forceDirty)
			return;
		__dirty = false;
		this.blurImage.data.clear();
		this.blurImage.data.draw(display);
		this.bitmapData.clear();
		this.bitmapData.draw(display);
		var quad = new Quad(50, 50, 0xff0000);
		quad.y = 300;
		var stepX = blurX / Std.int(blurX);
		var stepY = blurY / Std.int(blurY);
		for (i in 0...Std.int(blurX)) {
			cast(blurImage.shader, BlurShader).updateBlur(i * stepX, 0);
			this.blurImage.data.draw(this.render);
			this.bitmapData.draw(blurImage);
		}
		for (i in 0...Std.int(blurY)) {
			cast(blurImage.shader, BlurShader).updateBlur(0, i * stepY);
			this.blurImage.data.draw(this.render);
			this.bitmapData.draw(blurImage);
		}
		trace("渲染", this.blurImage.data.width, this.blurImage.data.height);
	}

	/**
	 * 模糊值动画
	 */
	public function tweenTo(blurX:Int, blurY:Int, duration:Float):BlurFilter {
		Actuate.tween(this, duration, {blurX: blurX, blurY: blurY}).ease(Linear.easeNone);
		return this;
	}

	override function updateStageSize() {
		super.updateStageSize();
		blurImage.data = OpenFlBitmapData.fromSize(Std.int(Hxmaker.engine.stageWidth), Std.int(Hxmaker.engine.stageHeight), true, 0x0);
	}
}
