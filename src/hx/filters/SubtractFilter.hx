package hx.filters;

import hx.shader.SubtractShader;
import hx.core.OpenFlBitmapData;
import hx.core.Hxmaker;
import hx.display.Image;
import hx.display.DisplayObject;

/**
 * 相减滤镜
 */
class SubtractFilter extends StageBitmapRenderFilter {
	private var __subtractImage:Image = new Image();

	override function init() {
		super.init();
		__subtractImage.data = OpenFlBitmapData.fromSize(Std.int(Hxmaker.engine.stageWidth), Std.int(Hxmaker.engine.stageHeight), true, 0x0);
		this.render.shader = new SubtractShader();
	}

	override function update(display:DisplayObject, dt:Float) {
		super.update(display, dt);
		// 渲染舞台的画面位图
		this.bitmapData.clear();
		Hxmaker.engine.renderer.renderToBitmapData(bitmapData);
		__subtractImage.data.clear();
		__subtractImage.data.draw(display);
		cast(this.render.shader, SubtractShader).uSampler1.input = __subtractImage.data.data.getTexture();
	}
}
