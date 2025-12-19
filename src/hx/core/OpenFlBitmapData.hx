package hx.core;

import hx.geom.Matrix;
import hx.display.DisplayObject;
import openfl.display.BitmapData;
import hx.display.IBitmapData;

/**
 * OpenFL纹理
 */
class OpenFlBitmapData implements IBitmapData {
	/**
	 * 通过`openfl.display.BitmapData`创建`hx.display.BitmapData`
	 * @param bitmapData 
	 * @return hx.display.BitmapData
	 */
	public static function fromBitmapData(bitmapData:BitmapData):hx.display.BitmapData {
		return hx.display.BitmapData.formData(new OpenFlBitmapData(bitmapData));
	}

	/**
	 * 创建一个指定大小的`hx.display.BitmapData`
	 * @param width 宽度
	 * @param height 高度
	 * @param transparent 是否透明
	 * @param fillColor 填充颜色
	 * @return hx.display.BitmapData
	 */
	public static function fromSize(width:Int, height:Int, transparent:Bool = false, fillColor:Int = 0xffffff):hx.display.BitmapData {
		return fromBitmapData(new BitmapData(width, height, transparent, fillColor));
	}

	private static var __bitmapDataRender:Render;

	public static function getBitmapDataRender():Render {
		if (__bitmapDataRender == null) {
			__bitmapDataRender = new Render();
		}
		return __bitmapDataRender;
	}

	private var __root:BitmapData;

	public function new(root:BitmapData) {
		this.__root = root;
	}

	public function getTexture():Dynamic {
		return __root;
	}

	public function getWidth():Int {
		return __root != null ? __root.width : 0;
	}

	public function getHeight():Int {
		return __root != null ? __root.height : 0;
	}

	public function draw(source:DisplayObject, matrix:Matrix):Void {
		getBitmapDataRender().clear();
		if (__root.readable) {
			__root.disposeImage();
		}
		if (source.stage != null) {
			@:privateAccess source.stage.__updateTransform(null);
		} else {
			@:privateAccess source.__updateTransform(null);
		}
		getBitmapDataRender().renderDisplayObject(source);
		__root.draw(getBitmapDataRender().stage, new openfl.geom.Matrix(matrix.a, matrix.b, matrix.c, matrix.d, matrix.tx, matrix.ty));
	}

	/**
	 * 清除当前位图数据
	 */
	public function clear():Void {
		__root.fillRect(__root.rect, 0);
	}
}
