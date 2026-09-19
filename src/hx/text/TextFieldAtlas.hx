package hx.text;

import openfl.display.BitmapData;
import openfl.geom.Rectangle;

/**
 * 文本纹理图集。
 *
 * 图集由若干页组成，每页是一张独立的纹理（见`TextFieldAtlasPage`）。
 * 字形按字符去重，`chars`/`emojs`是**跨页的全局索引**，
 * 因此查表仍然是 O(1)，`Text.drawText`里的查表逻辑不需要感知页的存在。
 */
class TextFieldAtlas {
	/**
	 * 跨页的全局字形索引
	 */
	public var chars:Map<String, FntFrame> = [];
	public var emojs:Map<String, FntFrame> = [];

	/**
	 * 所有页，页 0 始终存在
	 */
	public var pages:Array<TextFieldAtlasPage> = [];

	/**
	 * 当前正在写入的页（最后一张）
	 */
	public var current(get, never):TextFieldAtlasPage;

	private function get_current():TextFieldAtlasPage {
		return pages[pages.length - 1];
	}

	/**
	 * 已分配的页数
	 */
	public var pageCount(get, never):Int;

	private function get_pageCount():Int {
		return pages.length;
	}

	public function new(bitmapData:BitmapData) {
		addPage(bitmapData);
	}

	/**
	 * 用一张已有的纹理登记为新的一页。
	 * 页的打包器容量取自纹理自身的尺寸，保证两者永远一致
	 * @param bitmapData 纹理
	 * @return TextFieldAtlasPage
	 */
	public function addPage(bitmapData:BitmapData):TextFieldAtlasPage {
		var page = new TextFieldAtlasPage(bitmapData, pages.length);
		pages.push(page);
		return page;
	}

	/**
	 * 按首页的尺寸新建一页纹理。
	 *
	 * 采用与首页相同的创建流程：先丢弃 GPU 纹理、只保留 CPU 像素，
	 * 等它第一次被采样时再由 OpenFL 惰性上传，避免逐字写入的过程中反复触发纹理同步。
	 * @return TextFieldAtlasPage
	 */
	public function createPage():TextFieldAtlasPage {
		var first = pages[0];
		var bitmapData = new BitmapData(first.bitmapData.width, first.bitmapData.height, true, 0x0);
		bitmapData.disposeImage();
		return addPage(bitmapData);
	}

	public function getCharFntFrame(char:String):FntFrame {
		return chars.get(char);
	}

	/**
	 * 追加一个字形到指定页
	 * @param page 字形所属的页
	 * @param char 字符
	 * @param rect 在页纹理中的矩形
	 * @param xadvance 前进宽度
	 */
	public function pushChar(page:TextFieldAtlasPage, char:String, rect:Rectangle, xadvance:Int):Void {
		var frame = new FntFrame(this);
		frame.data = page.view.sub(rect.x, rect.y, rect.width, rect.height);
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
	 * 重置整张图集：释放所有页（包括页 0）后按原尺寸重新分配一页。
	 *
	 * 这里不复用页 0 的纹理对象，是因为"清空已有纹理"只能依赖`BitmapData.fillRect`，
	 * 而它在没有 CPU 缓冲、又尚未建立 GL 帧缓冲的位图上会静默失效
	 * （见 OpenFL 的`__fillRect`：既非可读、又没有帧缓冲时直接返回），
	 * 结果是打包器被清空、旧字形却还在纹理里——正是串字的成因。
	 * 新建的位图天然全透明，不依赖渲染后端类型。
	 *
	 * 重置后所有已登记的字形都已失效，所以索引整体清空。
	 * 这是唯一会重置已有页的操作，必须由客户端在安全时机显式触发。
	 */
	public function reset():Void {
		var width = pages[0].bitmapData.width;
		var height = pages[0].bitmapData.height;
		dispose();
		var bitmapData = new BitmapData(width, height, true, 0x0);
		bitmapData.disposeImage();
		addPage(bitmapData);
	}

	/**
	 * 释放所有页占用的显存
	 */
	public function dispose():Void {
		for (index in 0...pages.length) {
			pages[index].dispose();
		}
		pages.resize(0);
		chars = [];
		emojs = [];
	}

	/**
	 * @deprecated 请改用`reset()`，旧实现只清索引、会留下已写满的页
	 */
	@:deprecated("请改用 reset()")
	public function clear():Void {
		reset();
	}

	/**
	 * 通过emoj获得一个纹理
	 * @param emoj
	 * @return FntFrame
	 */
	public function getCharFntFrameByEmoj(emoj:String):FntFrame {
		return emojs.get(emoj);
	}

	public var fontSize:Float = 0;

	public var maxHeight:Float = 0;

	/**
	 * @deprecated 图集已支持多页，请改用`pages`
	 */
	@:deprecated("图集已支持多页，请改用 pages")
	public var bitmapData(get, never):hx.display.BitmapData;

	private function get_bitmapData():hx.display.BitmapData {
		return pages[0].view;
	}
}
