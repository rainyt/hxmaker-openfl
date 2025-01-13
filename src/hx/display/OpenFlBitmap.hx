package hx.display;

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
}
