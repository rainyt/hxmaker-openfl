package hx.text;

import hx.display.Label;
import hx.text.MaxRectsBinPack.FreeRectangleChoiceHeuristic;
import lime.text.Font;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.display.BitmapData;

/**
 * 文本渲染缓存纹理，一般在渲染位图为TextField
 */
class TextFieldContextBitmapData {
	/**
	 * 纹理
	 */
	public var bitmapData:BitmapData;

	/**
	 * 是否清理纹理时，直接重构整个纹理
	 */
	public var cleanBitmapData:Bool = false;

	/**
	 * 缓存版本号
	 */
	public var version:Int = 0;

	/**
	 * 图集，使用列表储存，如果满了图集后，则自动追加
	 */
	private var __atlasList:Array<TextFieldAtlas> = [];

	/**
	 * 图集字形管理
	 */
	private var __charsMap:Map<String, Int> = [];

	private var __textFormat:TextFormat;

	/**
	 * 文本渲染器
	 */
	private var __textField:TextField;

	private var __offestX:Int = 0;

	private var __offestY:Int = 0;

	private var __redrawing:Bool = false;

	private var __textureWidth:Int = 0;

	private var __textureHeight:Int = 0;

	private var emoj = "";
	#if !cpp
	private var req = ~/[\ud04e-\ue50e]+/;
	#end

	public var fontSize:Int = 36;

	public function new(size:Int = 36, textureWidth:Int = 2048, textureHeight:Int = 2048, offestX:Int = 1, offestY:Int = 1) {
		this.fontSize = size;
		this.__textureWidth = textureWidth;
		this.__textureHeight = textureHeight;
		this.__offestX = offestX;
		this.__offestY = offestY;
		var fontPath = #if ios "assets/" + hx.display.TextFormat.defaultFont #else hx.display.TextFormat.defaultFont #end;
		__textFormat = new TextFormat(fontPath, size, 0xffffff);
		__textFormat.leading = Std.int(size / 2);
		__textField = new TextField();
		createNewAtlas();
	}

	/**
	 * 创建新的精灵图集
	 */
	private function createNewAtlas() {
		var atlas = new TextFieldAtlas(__textureWidth, __textureHeight);
		atlas.fontSize = fontSize + __offestY / 2;
		__atlasList.push(atlas);
	}

	/**
	 * 渲染文本
	 * @param text 
	 */
	public function drawText(text:String):Void {
		if (text == null)
			return;

		var __atlas = __atlasList[__atlasList.length - 1];

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
		 * 缓存文本
		 * @param text 
		 */
	private function __cacheText(text:String):Void {
		// __textField = new TextField();
		if (text == null)
			return;
		var id = __atlasList.length - 1;
		var __atlas = __atlasList[id];
		__textField.wordWrap = true;
		__textField.text = text;
		__textField.width = 2048;
		__textField.setTextFormat(__textFormat);
		var pakWidth = Std.int(__textField.textWidth + __offestX * 3);
		var pakHeight = Std.int(__textField.textHeight + __offestY * 3);
		__textField.height = pakHeight;
		var pakRect = __atlas.rects.insert(pakWidth, pakHeight, FreeRectangleChoiceHeuristic.BestShortSideFit);
		if (pakRect == null || pakRect.width == 0 || pakRect.height == 0) {
			// 当缓冲区满了，则创建下一张
			createNewAtlas();
			__cacheText(text);
			return;
		}

		var m = new Matrix();
		m.translate(pakRect.x, pakRect.y);
		__textField.invalidate();
		#if (ks || IOS_HIGH_PREFORMANCE_V2)
		// 微信高性能+模式下，需要重建TextField，否则会有字体重叠的问题
		// __textField = new TextField();
		if (untyped __textField.__graphics.__context != null)
			untyped __textField.__graphics.__context.clearRect(0, 0, __textField.__graphics.__canvas.width, __textField.__graphics.__canvas.height);
		#end
		bitmapData.draw(__textField, m, null, null, null, true);
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
			__atlas.pushChar(char, rect, Std.int(rect.width - __offestX * 2));
			__charsMap[char] = id;

			// 测试
			#if text_debug
			var spr = new Sprite();
			spr.graphics.beginFill(0xff0000, 0.5);
			spr.graphics.drawRect(rect.x, rect.y, rect.width, rect.height);
			spr.graphics.endFill();
			bitmapData.draw(spr);
			#end
		}
	}

	/**
	 * 清理纹理数据
	 */
	public function dispose():Void {
		for (atlas in __atlasList) {
			atlas.bitmapData.dispose();
		}
		__atlasList = [];
	}

	/**
		 * 清空文字纹理渲染
		 */
	// public function clear():Void {
	// 	version++;
	// 	if (cleanBitmapData) {
	// 		bitmapData = new BitmapData(bitmapData.width, bitmapData.height, true, 0x0);
	// 		bitmapData.disposeImage();
	// 	}
	// 	__textField = new TextField();
	// 	bitmapData.fillRect(bitmapData.rect, 0x0);
	// 	__atlas.clear();
	// 	rects = new MaxRectsBinPack(__textureWidth, __textureHeight, false);
	// }
	/**
		 * 对当前显示对象进行重绘
		 */
	// public function redraw():Void {
	// 	this.clear();
	// 	// 重建名单来自文本队列，这样离屏渲染、cacheAsBitmap 等不在舞台树上的文本也不会漏掉
	// 	var labels = TextFieldQFueue.getResident(this.cacheId);
	// 	for (index in 0...labels.length) {
	// 		var label:Label = labels[index];
	// 		label.setTextFormatDirty();
	// 		drawText(label.data);
	// 	}
	// }

	/**
	 * 获得纹理
	 * @return Atlas
	 */
	public function getAtlas(char:String):TextFieldAtlas {
		if (__charsMap.exists(char)) {
			return __atlasList[__charsMap.get(char)];
		}
		return null;
	}
}
