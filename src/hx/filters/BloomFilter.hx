package hx.filters;

import hx.display.Image;
import hx.display.DisplayObject;
import hx.core.Hxmaker;
import hx.core.OpenFlBitmapData;
import hx.display.BitmapData;

/**
 * 泛光滤镜
 */
class BloomFilter extends StageBitmapRenderFilter {
	private var __thresholdImage:Image;

	private var __bloomImage:Image;

	override function init() {
		super.init();
		// 高光图
		__thresholdImage = new Image();
		__thresholdImage.data = OpenFlBitmapData.fromSize(Std.int(Hxmaker.engine.stageWidth), Std.int(Hxmaker.engine.stageHeight), true, 0x0);
		__thresholdImage.shader = new hx.shader.ColorThresholdShader(0.8);

		// 泛光图
		__bloomImage = new Image();
		__bloomImage.data = OpenFlBitmapData.fromSize(Std.int(Hxmaker.engine.stageWidth), Std.int(Hxmaker.engine.stageHeight), true, 0x0);
		__bloomImage.shader = new hx.shader.KawaseBloomShader(24);
	}

	override function update(display:DisplayObject, dt:Float) {
		super.update(display, dt);
		// 先提取泛光区域的颜色
		__thresholdImage.data.clear();
		__thresholdImage.data.draw(display);
		// 渲染原始图
		this.bitmapData.clear();
		this.bitmapData.draw(display);
		// 将泛光区域叠加上去
		// __thresholdImage.x = 100;
		// __thresholdImage.y = 100;
		__bloomImage.data.clear();
		__bloomImage.data.draw(__thresholdImage);
		this.bitmapData.draw(__bloomImage);
	}
}
