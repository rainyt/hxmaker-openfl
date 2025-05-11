package hx.render;

import hx.display.Graphics;
import hx.core.Render;

/**
 * 图形渲染逻辑
 */
@:access(hx.display.Graphics)
class GraphicRender {
	/**
	 * 渲染图形
	 * @param graphic 
	 * @param renderer 
	 */
	public static function render(graphic:Graphics, renderer:Render) {
		if (graphic.__graphicsDirty) {
			graphic.updateGraphics();
		}
		var dataBuffer = renderer.imageBufferData[renderer.drawImageBuffDataIndex];
		if (!dataBuffer.drawGraphic(graphic, renderer)) {
			renderer.renderImageBuffData(dataBuffer);
			// 直到图像渲染结束
			if (graphic.__graphicsDrawData.index < graphic.__graphicsDrawData.draws.length) {
				render(graphic, renderer);
			}
		}
	}
}
