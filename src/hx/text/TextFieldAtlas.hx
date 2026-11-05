package hx.text;

import hx.core.OpenFlBitmapData;
import hx.render2d.openfl.RenderBitmapData;
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

	public function new(width:Int, height:Int, cpuPixels:Bool = false) {
		var bitmapData:BitmapData = new RenderBitmapData(width, height, true, 0x0);
		rects = new MaxRectsBinPack(width, height, false);
		// 恢复后的浏览器图集保留 CPU 像素，draw 使用 Canvas，设备重建时可直接上传。
		if (!cpuPixels) bitmapData.disposeImage();
		this.texture = bitmapData;
		this.bitmapData = hx.display.BitmapData.formData(new OpenFlBitmapData(bitmapData));
	}

	public var fontSize:Float = 0;

	public var maxHeight:Float = 0;

	public function clear():Void {
		for (frame in chars) frame.data.dispose();
		for (frame in emojs) frame.data.dispose();
		chars = [];
		emojs = [];
	}

	public function getCharFntFrame(char:String):FntFrame {
		return chars.get(char);
	}

	/** 清除切片后才退出根位图所有权，避免字形视图阻止最终回收。 */
	public function dispose():Void { clear(); bitmapData.dispose(); }

	public function pushChar(char:String, rect:Rectangle, xadvance:Int):Void {
		var previous:FntFrame = char.length == 2 ? emojs.get(char) : chars.get(char);
		if (previous != null) previous.data.dispose();
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
