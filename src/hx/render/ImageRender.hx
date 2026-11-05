package hx.render;

import hx.display.DisplayObject;
import hx.geom.Matrix;
import hx.core.Render;
import hx.display.Image;

/**
 * 图片渲染器支持
 */
class ImageRender {
	/**
	 * 渲染图片s
	 * @param image 
	 * @param render
	 */
	public static function render(image:Image, render:Render):Void {
		if (image.data == null || image.data.data == null)
			return;
		// 当前渲染的图片缓存数据
		var dataBuffer = render.imageBufferData[render.drawImageBuffDataIndex];
		if (!dataBuffer.draw(image, render)) {
			var shader:openfl.display.Shader = render.currentShader;
			render.renderImageBuffData(dataBuffer);
			render.currentShader = shader;
			ImageRender.render(image, render);
		}
	}
}
