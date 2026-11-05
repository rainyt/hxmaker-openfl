package hx.filters;

import hx.geom.Matrix;
import hx.display.DisplayObject;
import hx.display.BitmapData;
import hx.core.OpenFlBitmapData;

/**
 * 显示对象滤镜基类
 */
@:access(hx.display.DisplayObject)
class DisplayObjectFilter extends RenderFilter {
	/**
	 * 滤镜渲染时的X轴偏移量
	 */
	public var translateX:Float = 0;

	/**
	 * 滤镜渲染时的Y轴偏移量
	 */
	public var translateY:Float = 0;
	private var cacheOriginX:Float = 0;
	private var cacheOriginY:Float = 0;

	public function createCacheBitmapData(width:Float, height:Float):BitmapData {
		return OpenFlBitmapData.fromSize(Math.ceil(width), Math.ceil(height), true, 0x0);
	}

	override function updateTransform(display:DisplayObject) {
		if (render != null) {
			this.render.__worldAlpha = display.__worldAlpha;
			this.render.__worldTransform.copyFrom(display.__worldTransform);
			// 缓存原点属于源对象的局部坐标，先转换到世界偏移，再应用滤镜显式偏移。
			this.render.__worldTransform.tx += display.__worldTransform.a * cacheOriginX + display.__worldTransform.c * cacheOriginY;
			this.render.__worldTransform.ty += display.__worldTransform.b * cacheOriginX + display.__worldTransform.d * cacheOriginY;
			this.render.__worldTransform.translate(translateX, translateY);
		}
	}

	/**
	 * 将显示对象绘制到指定的BitmapData中，该方法会忽略所有变换矩阵和透明度
	 */
	public function drawToBitmapData(bitmapData:BitmapData, display:DisplayObject, matrix:Matrix = null) {
		var rect:hx.geom.Rectangle = display.getBounds(display);
		cacheOriginX = rect.x; cacheOriginY = rect.y;
		var m:Matrix = display.__worldTransform.clone();
		m.invert();
		var oldAlpha = display.__worldAlpha;
		display.__worldAlpha = 1.0;
		m.translate(-rect.x, -rect.y);
		if (matrix != null) {
			m.concat(matrix);
		}
		try { bitmapData.draw(display, m, null, false); }
		catch (error:Dynamic) { display.__worldAlpha = oldAlpha; throw error; }
		display.__worldAlpha = oldAlpha;
	}
}
