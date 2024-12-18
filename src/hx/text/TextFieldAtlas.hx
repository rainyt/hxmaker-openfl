package hx.text;

import openfl.Vector;
import openfl.display.BitmapData;
import openfl.display.Tileset;
import openfl.geom.Rectangle;

/**
 * 文本纹理
 */
class TextFieldAtlas {
	public var bitmapData:BitmapData;

	public var chars:Map<String, FntFrame> = [];
	public var emojs:Map<String, FntFrame> = [];

	public function new(bitmapData:BitmapData) {
		this.bitmapData = bitmapData;
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
		// frame.x = 0;
		// frame.y = 0;
		// frame.width = rect.width;
		// frame.height = rect.height;
		frame.rect = rect;
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
