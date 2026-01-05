package hx.filters;

import hx.shader.MultiTextureShader;
import hx.shader.SubtractShader;
import hx.core.OpenFlBitmapData;
import hx.core.Hxmaker;
import hx.display.Image;
import hx.display.DisplayObject;

/**
 * 混合模式滤镜
 */
class BlendModeFilter extends StageBitmapRenderFilter {
	public var displayImage:Image = new Image();

	override function init() {
		super.init();
		displayImage.data = new StageBitmapData();
	}

	override function update(display:DisplayObject, dt:Float) {
		super.update(display, dt);
		// 渲染舞台的画面位图
		this.bitmapData.clear();
		Hxmaker.engine.renderer.renderToBitmapData(bitmapData);
		displayImage.data.clear();
		displayImage.data.draw(display);
		cast(this.render.shader, MultiTextureShader).uSampler1.input = displayImage.data.data.getTexture();
	}
}
