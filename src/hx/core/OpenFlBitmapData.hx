package hx.core;

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
}
