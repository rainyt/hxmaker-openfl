package hx.text;

import hx.core.OpenFlBitmapData;
import openfl.Vector;
import openfl.display.BitmapData;
import openfl.display.Tileset;
import openfl.geom.Rectangle;

/**
 * 文本纹理
 */
class TextFieldAtlas {
	/**
	 * 底层纹理，文本图像直接绘制到这张位图上
	 */
	public var texture:BitmapData;

	/**
	 * 纹理数据
	 */
	public var bitmapData:hx.display.BitmapData;

	/**
	 * 打包器
	 */
	 public var rects:MaxRectsBinPack;

	public var chars:Map<String, FntFrame> = [];
	public var emojs:Map<String, FntFrame> = [];

	public function new(width:Int, height:Int) {
		var bitmapData = new BitmapData(width, height, true, 0x0);
		rects = new MaxRectsBinPack(width, height, false);
		bitmapData.disposeImage();
		this.texture = bitmapData;
		this.bitmapData = hx.display.BitmapData.formData(new OpenFlBitmapData(bitmapData));
	}

	public var fontSize:Float = 0;

	public var maxHeight:Float = 0;

	public function clear():Void {
		chars = [];
		emojs = [];
	}

	public function getCharFntFrame(char:String):FntFrame {
		return chars.get(char);
	}

	public function pushChar(char:String, rect:Rectangle, xadvance:Int):Void {
		var frame = new FntFrame(this);
		frame.data = bitmapData.sub(rect.x, rect.y, rect.width, rect.height);
		frame.xadvance = xadvance;
		frame.char = char;
		if (rect.height > maxHeight)
			maxHeight = rect.height;
		if (char.length == 2) {
			// emoj表情
			emojs.set(char, frame);
		} else {
			chars.set(char, frame);
		}
	}

	/**
	 * 通过emoj获得一个纹理
	 * @param emoj
	 * @return FntFrame
	 */
	public function getCharFntFrameByEmoj(emoj:String):FntFrame {
		return emojs.get(emoj);
	}
}
