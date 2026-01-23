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

	public function createCacheBitmapData(width:Float, height:Float):BitmapData {
		return OpenFlBitmapData.fromSize(Std.int(width), Std.int(height), true, 0x0);
	}

	override function updateTransform(display:DisplayObject) {
		if (render != null) {
			this.render.__worldAlpha = display.__worldAlpha;
			this.render.__worldTransform.copyFrom(display.__worldTransform);
			this.render.__worldTransform.translate(translateX, translateY);
		}
	}

	/**
	 * 将显示对象绘制到指定的BitmapData中，该方法会忽略所有变换矩阵和透明度
	 */
	public function drawToBitmapData(bitmapData:BitmapData, display:DisplayObject, matrix:Matrix = null) {
		var rect = display.getBounds();
		var m = new Matrix();
		var oldAlpha = display.__worldAlpha;
		display.__worldAlpha = 1.0;
		m.translate(-display.__worldTransform.tx, -display.__worldTransform.ty);
		if (matrix != null) {
			m.concat(matrix);
		}
		bitmapData.draw(display, m, null, false);
		display.__worldAlpha = oldAlpha;
	}
}
