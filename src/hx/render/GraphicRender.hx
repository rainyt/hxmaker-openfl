package hx.render;

import hx.displays.Graphic;
import hx.core.Render;

/**
 * 图形渲染逻辑
 */
@:access(hx.displays.Graphic)
class GraphicRender {
	/**
	 * 渲染图形
	 * @param graphic 
	 * @param renderer 
	 */
	public static function render(graphic:Graphic, renderer:Render) {
		var dataBuffer = renderer.imageBufferData[renderer.drawImageBuffDataIndex];
		if (!dataBuffer.drawGraphic(graphic, renderer)) {
			renderer.renderImageBuffData(dataBuffer);
			// 直到图像渲染结束
			if (graphic.__graphicDrawData.index < graphic.__graphicDrawData.draws.length) {
				render(graphic, renderer);
			}
		}
	}
}
