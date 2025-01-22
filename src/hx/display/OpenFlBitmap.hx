package hx.display;

import hx.gemo.Rectangle;
import openfl.display.Bitmap;

/**
 * OpenFL的Bitmap自定义渲染类
 */
class OpenFlBitmap extends CustomDisplayObject {
	/**
	 * 位图对象
	 */
	public var bitmap:Bitmap;

	public function new(bitmapData:BitmapData) {
		bitmap = new Bitmap(bitmapData.data?.getTexture());
		super(bitmap);
	}

	override function get_width():Float {
		if (__width != null) {
			return __width;
		}
		return super.get_width();
	}

	override function get_height():Float {
		if (__height != null) {
			return __height;
		}
		return getBounds().height;
	}

	override function __getRect():Rectangle {
		if (root == null) {
			__rect.width = __rect.height = 0;
		} else {
			__rect.width = bitmap.bitmapData != null ? bitmap.bitmapData.width : 0;
			__rect.height = bitmap.bitmapData != null ? bitmap.bitmapData.height : 0;
		}
		return __rect;
	}
}
