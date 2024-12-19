package hx.render;

import hx.displays.DisplayObject;
import hx.gemo.Matrix;
import hx.core.Render;
import hx.displays.Image;

/**
 * 图片渲染器支持
 */
class ImageRender {
	/**
	 * 渲染图片
	 * @param image 
	 * @param render
	 */
	public static function render(image:Image, render:Render):Void {
		// 当前渲染的图片缓存数据
		var dataBuffer = render.imageBufferData[render.drawImageBuffDataIndex];
		if (!dataBuffer.draw(image, render)) {
			render.renderImageBuffData(dataBuffer);
			ImageRender.render(image, render);
		}
	}
}
