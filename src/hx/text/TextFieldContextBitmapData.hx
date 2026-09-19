package hx.text;

import hx.text.MaxRectsBinPack.FreeRectangleChoiceHeuristic;
import lime.text.Font;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.display.Sprite;
// import zygame.utils.load.Atlas;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.display.BitmapData;

/**
 * 文本渲染缓存纹理，一般在渲染位图为TextField
 */
class TextFieldContextBitmapData {
	/**
	 * 图集版本号的全局单调序列。
	 *
	 * 必须是静态的：缓存器被释放后重建时，如果版本号从 0 重新开始，
	 * 会与文本对象上记录的旧版本号撞号，导致失效判定漏检。
	 */
	private static var __versionSeq:Int = 0;

	private var __renderTestBitmapData:BitmapData;

	/**
	 * 缓存版本号，每次重置图集都会前进。
	 *
	 * 文本对象会记下自己构建渲染数据时所依据的版本号，
	 * 两者不一致就说明它的渲染数据指向的是被重置掉的旧图集，必须重建。
	 */
	public var version:Int = 0;

	/**
	 * 当前缓存器对应的`textCacheId`，由`TextFieldRender`赋值，用于定位驻留在该图集上的文本
	 */
	public var cacheId:Int = 0;

	/**
	 * 允许分配的最大页数。
	 *
	 * 达到上限后新的字形会被丢弃，并通过`onAtlasFull`通知一次，
	 * 缺字在`Text.drawText`里会退化成空格（布局不崩、不会出现乱码）。
	 * 每多一页就多一张`textureWidth × textureHeight`的纹理
	 * （1024×1024 RGBA 约 4MB 显存），并在本帧的渲染批次里多占用一个纹理单元。
	 */
	public var maxPages:Int = 4;

	/**
	 * 页数达到上限时回调一次，由客户端决定是调大`maxPages`，还是在安全时机清理图集
	 */
	public var onAtlasFull:TextFieldContextBitmapData->Void;

	/**
	 * 是否已经达到页数上限。
	 *
	 * 同时充当两个用途：达到上限时只上报一次，避免持续刷屏；
	 * 以及作为"图集已无空间"的短路标记，避免每帧重复做注定被丢弃的字体排版。
	 * 由`reset()`清除。
	 */
	private var __reportedFull:Bool = false;

	/**
	 * 图集
	 */
	private var __atlas:TextFieldAtlas;

	private var __textFormat:TextFormat;

	/**
	 * 文本渲染器
	 */
	private var __textField:TextField;

	private var __offestX:Int = 0;

	private var __offestY:Int = 0;

	private var __textureWidth:Int = 0;

	private var __textureHeight:Int = 0;

	private var emoj = "";
	#if !cpp
	private var req = ~/[\ud04e-\ue50e]+/;
	#end

	public var fontSize:Int = 36;

	public function new(size:Int = 36, textureWidth:Int = 2048, textureHeight:Int = 2048, offestX:Int = 1, offestY:Int = 1, maxPages:Int = 4) {
		this.fontSize = size;
		this.__textureWidth = textureWidth;
		this.__textureHeight = textureHeight;
		this.__offestX = offestX;
		this.__offestY = offestY;
		this.maxPages = maxPages;
		__renderTestBitmapData = new BitmapData(1, 1, true, 0x0);
		__renderTestBitmapData.disposeImage();
		var bitmapData = new BitmapData(textureWidth, textureHeight, true, 0x0);
		bitmapData.disposeImage();
		var fontPath = #if ios "assets/" + hx.display.TextFormat.defaultFont #else hx.display.TextFormat.defaultFont #end;
		__textFormat = new TextFormat(fontPath, size, 0xffffff);
		__textFormat.leading = Std.int(size / 2);
		__textField = new TextField();
		__atlas = new TextFieldAtlas(bitmapData);
		__atlas.fontSize = size + offestY / 2;
		version = ++__versionSeq;
	}

	/**
	 * 渲染文本
	 * @param text
	 */
	public function drawText(text:String):Void {
		if (text == null)
			return;

		#if (text_debug && stack_printf)
		var list = haxe.CallStack.callStack();
		if (list != null && list.length > 0) {
			// 开始上报调用栈
			var stackMessage = haxe.CallStack.toString(list);
			if (stackMessage.indexOf("onExitFrameEvent") == -1)
				ZLog.warring("darwText " + text + " stack:\n" + stackMessage);
		}
		#end

		// 过滤重复的文本
		var caches:Array<String> = [];
		var chars = text.split("");
		emoj = "";
		for (char in chars) {
			if (char == " " || char == "\n" || char == "\r")
				continue;
			#if !cpp
			if (req.match(char)) {
				emoj += char;
				if (emoj.length == 2) {
					if (__atlas.getCharFntFrameByEmoj(emoj) == null)
						if (!caches.contains(emoj)) {
							caches.push(emoj);
						}
					emoj = "";
				}
			} else {
			#end
				if (__atlas.getCharFntFrame(char) == null)
					if (!caches.contains(char)) {
						caches.push(char);
					}
			#if !cpp
			}
			#end
		}
		if (caches.length == 0)
			return;

		#if (cpp || html5)
		for (s in caches) {
			__cacheText(s);
		}
		#else
		text = caches.join(" ");
		__cacheText(text);
		#end
	}

	/**
	 * 为一次字形写入挑选一张可用的页。
	 *
	 * 关键约定：页放不下时只把它标记为满并另开一页，**绝不擦除或重排任何已存在的页**。
	 * 这样已经入队的顶点读到的永远是写入时的内容，文字串字的问题从机制上消失。
	 *
	 * @param width 字形宽度
	 * @param height 字形高度
	 * @return 可用的页与矩形，返回 null 表示本次字形放弃写入
	 */
	private function __insertRect(width:Int, height:Int):{page:TextFieldAtlasPage, rect:Rectangle} {
		var page = __atlas.current;
		var rect = page == null ? null : page.rects.insert(width, height, FreeRectangleChoiceHeuristic.BestShortSideFit);
		if (rect != null && rect.width > 0 && rect.height > 0)
			return {page: page, rect: rect};

		if (page != null) {
			page.full = true;
			// 兜底：当前页一个字都没写上还是放不下，说明这个字形本身就大于整页，
			// 再开一张同样尺寸的新页也是白搭，直接放弃，避免无限开页
			if (page.isEmpty) {
				trace("TextFieldContextBitmapData: 单个字形大于整页，放弃缓存");
				return null;
			}
		}
		// 达到页上限：不淘汰旧页——淘汰相当于把 ASCII 与常用字丢掉，下几帧又会被填满，
		// 既造成抖动又要重建所有引用它的文本。改为丢弃该字形并通知客户端。
		if (__atlas.pageCount >= maxPages) {
			if (!__reportedFull) {
				__reportedFull = true;
				if (onAtlasFull != null)
					onAtlasFull(this);
			}
			return null;
		}
		var next = __atlas.createPage();
		if (next == null)
			return null;
		__reportedFull = false;
		rect = next.rects.insert(width, height, FreeRectangleChoiceHeuristic.BestShortSideFit);
		if (rect == null || rect.width == 0 || rect.height == 0)
			return null;
		return {page: next, rect: rect};
	}

	/**
		 * 缓存文本
		 * @param text
		 */
	private function __cacheText(text:String):Void {
		// __textField = new TextField();
		if (text == null)
			return;
		// 已无空间可写：当前页放不下、页数又到了上限。直接跳过——
		// 否则每帧都会白做一次完整的字体排版（测量 textWidth/textHeight）再把结果丢掉。
		// 用条件而不是一次性标记，是为了让客户端中途调大`maxPages`时能立刻恢复写入
		if (__atlas.pageCount >= maxPages && __atlas.current.full)
			return;
		__textField.wordWrap = true;
		__textField.text = text;
		__textField.width = __textureWidth;
		__textField.setTextFormat(__textFormat);
		var pakWidth = Std.int(__textField.textWidth + __offestX * 3);
		var pakHeight = Std.int(__textField.textHeight + __offestY * 3);
		__textField.height = pakHeight;
		var slot = __insertRect(pakWidth, pakHeight);
		if (slot == null) {
			// 放不下又没有页可开：放弃本次写入，不再触发任何整张重排
			return;
		}
		var pakRect = slot.rect;
		var page = slot.page;

		var m = new Matrix();
		m.translate(pakRect.x, pakRect.y);
		__textField.invalidate();
		#if (ks || IOS_HIGH_PREFORMANCE_V2)
		// 微信高性能+模式下，需要重建TextField，否则会有字体重叠的问题
		// __textField = new TextField();
		if (untyped __textField.__graphics.__context != null)
			untyped __textField.__graphics.__context.clearRect(0, 0, __textField.__graphics.__canvas.width, __textField.__graphics.__canvas.height);
		#end
		__renderTestBitmapData.draw(__textField);
		page.bitmapData.draw(__textField, m, null, null, null, true);
		#if !cpp
		emoj = "";
		#end
		for (i in 0...__textField.text.length) {
			var char = __textField.text.charAt(i);
			if (char == " ")
				continue;

			#if !cpp
			if (req.match(char)) {
				emoj += char;
				if (emoj.length == 2) {
					char = emoj;
					emoj = "";
				} else {
					continue;
				}
			}
			#end

			var rect = __textField.getCharBoundaries(i);
			if (rect == null)
				continue;
			rect.x += pakRect.x;
			rect.y += pakRect.y;
			rect.x -= __offestX;
			rect.width += __offestX * 2;
			rect.y -= __offestY;
			rect.height += __offestY * 2;
			this.__atlas.pushChar(page, char, rect, Std.int(rect.width - __offestX * 2));

			// 测试
			#if text_debug
			var spr = new Sprite();
			spr.graphics.beginFill(0xff0000, 0.5);
			spr.graphics.drawRect(rect.x, rect.y, rect.width, rect.height);
			spr.graphics.endFill();
			page.bitmapData.draw(spr);
			#end
		}
	}

	/**
	 * 重置整张图集（所有页）。
	 *
	 * 这是**唯一**会重置已有页的操作。分页图集写满时只会新开一页、绝不原地重排，
	 * 所以通常不需要调用，只在需要回收显存（页数接近`maxPages`）时由客户端显式触发。
	 *
	 * 重置后所有已构建的渲染数据都失效：驻留文本会被重新标记为待写，
	 * 离屏、cacheAsBitmap 等不在舞台树上的文本由版本号兜底。
	 *
	 * 注意：不要在渲染遍历中直接调用，请改用`TextFieldRender.clearTextFieldContextBitmapData`，
	 * 它会自动把渲染期的调用推迟到下一次预写。
	 */
	public function reset():Void {
		version = ++__versionSeq;
		__reportedFull = false;
		__textField = new TextField();
		__atlas.reset();
		// 重建名单来自文本队列，这样离屏渲染、cacheAsBitmap 等不在舞台树上的文本也不会漏掉
		var labels = TextFieldQueue.getResident(this.cacheId);
		for (index in 0...labels.length) {
			labels[index].setTextFormatDirty();
		}
	}

	/**
	 * 释放图集占用的所有纹理
	 */
	public function dispose():Void {
		__atlas.dispose();
	}

	/**
	 * @deprecated 请改用`reset()`
	 */
	@:deprecated("请改用 reset()")
	public function redraw():Void {
		reset();
	}

	/**
	 * @deprecated 请改用`reset()`，旧实现只清索引、会留下已写满的页
	 */
	@:deprecated("请改用 reset()")
	public function clear():Void {
		reset();
	}

	/**
	 * 获得纹理
	 * @return Atlas
	 */
	public function getAtlas():TextFieldAtlas {
		return __atlas;
	}

	/**
	 * 已分配的页数，用于调试与显存统计
	 */
	public var pageCount(get, never):Int;

	private function get_pageCount():Int {
		return __atlas.pageCount;
	}

	/**
	 * @deprecated 图集已支持多页，请改用`getAtlas()`
	 */
	@:deprecated("图集已支持多页，请改用 getAtlas()")
	public var bitmapData(get, never):BitmapData;

	private function get_bitmapData():BitmapData {
		return __atlas.pages[0].bitmapData;
	}

	/**
	 * @deprecated 图集已支持多页，请改用`getAtlas()`，打包器在`TextFieldAtlasPage`上
	 */
	@:deprecated("图集已支持多页，打包器在 TextFieldAtlasPage 上")
	public var rects(get, never):MaxRectsBinPack;

	private function get_rects():MaxRectsBinPack {
		return __atlas.pages[0].rects;
	}
}
