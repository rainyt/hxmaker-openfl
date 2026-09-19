package test;

import hx.display.TextFormat;
import hx.display.Label;
import hx.display.Scene;
import hx.events.Event;
import hx.render.TextFieldRender;
import hx.text.TextFieldContextBitmapData;

/**
 * 文本图集溢出压力用例：持续制造大量唯一字形，把文本图集逐步撑满。
 *
 * 与`MoreLabelRender`的区别是它真的会溢出——后者的文本按字符去重后只有十几个唯一字形，
 * 永远填不满一页，测不出溢出路径。
 *
 * 验证要点：
 * 1. 图集写满后旧页不会被擦除重排，**先写入的文字始终保持正确**（不串字）；
 * 2. 页数单调增长且不超过`maxPages`，触顶后只降级为缺字（按空格处理），**不出现乱码**；
 * 3. 按`C`键显式清理后，页数回到 1，文本在下一帧正确重绘。
 */
class TextAtlasOverflowRender extends Scene {
	/**
	 * 文本对象数量。
	 * 无头环境（swiftshader）每帧渲染很慢，数量压在这个量级才能采到有效样本
	 */
	private static var LABEL_COUNT:Int = 40;

	/**
	 * 每个文本每帧新增的唯一字形数量
	 */
	private static var CHARS_PER_FRAME:Int = 3;

	/**
	 * 唯一字形码点的取值范围（CJK 基本区）
	 */
	private static var CODE_POINT_MIN:Int = 0x4e00;
	private static var CODE_POINT_MAX:Int = 0x9fa5;

	/**
	 * 唯一字形码点游标
	 */
	private var __codePoint:Int = CODE_POINT_MIN;

	private var __labels:Array<Label> = [];

	private var __hud:Label;

	private var __context:TextFieldContextBitmapData;

	private var __frame:Int = 0;

	/**
	 * 上一次上报的页数，用于在页数变化时打点（无头环境只能靠日志观测）
	 */
	private var __lastPageCount:Int = -1;

	/**
	 * 上一次观测到的图集版本号，用于确认清理是否真的执行了。
	 *
	 * 页数不适合用来观测清理：清理后同一帧内就会把驻留文本重新写满，
	 * 按帧采样根本看不到页数回落。
	 */
	private var __lastVersion:Int = -1;

	override function onStageInit() {
		super.onStageInit();
		if (TextFormat.defaultFont == null) {
			// 必须在第一个文本缓存器创建之前设置：字体是在缓存器构造时固化进`TextFormat`的，
			// 此后没有更新路径
			TextFormat.defaultFont = "assets/font/SourceHanSansSC-Bold.otf";
		}
		__context = TextFieldRender.getTextFieldContextBitmapData(0);
		// 触顶只上报一次，这里显式打出来，避免被淹没在日志里
		__context.onAtlasFull = (context) -> {
			trace("文本图集已写满，当前页数：" + context.pageCount);
		};
		for (i in 0...LABEL_COUNT) {
			var label = new Label();
			this.addChild(label);
			label.textFormat = new TextFormat(null, 26, 0xffffff);
			label.x = (i % 8) * 110;
			label.y = Std.int(i / 8) * 32;
			label.data = __nextText();
			__labels.push(label);
		}
		__hud = new Label();
		this.addChild(__hud);
		__hud.textFormat = new TextFormat(null, 26, 0xff0000);
		__hud.y = stage.stageHeight - 40;
		this.addEventListener(Event.UPDATE, onFrameUpdate);
		#if (html5 || desktop)
		openfl.Lib.current.stage.addEventListener(openfl.events.KeyboardEvent.KEY_DOWN, onKeyDown);
		#end
	}

	/**
	 * 取出一段全新的文本：每个字符都是此前没用过的唯一码点，因此每次都会新增字形
	 */
	private function __nextText():String {
		var text = "";
		for (i in 0...CHARS_PER_FRAME) {
			text += String.fromCharCode(__codePoint);
			__codePoint++;
			// 跳过代理区，避免产生无法渲染的半截字符
			if (__codePoint >= 0xd800 && __codePoint <= 0xdfff)
				__codePoint = 0xe000;
			// 码点用尽后回到起点，长时间运行时循环压迫图集
			if (__codePoint > CODE_POINT_MAX)
				__codePoint = CODE_POINT_MIN;
		}
		return text;
	}

	/**
	 * 每帧轮换所有文本的内容，持续产生新的唯一字形
	 */
	private function onFrameUpdate(e:Event):Void {
		for (label in __labels) {
			label.data = __nextText();
		}
		// 版本号变化即图集被重置过（清理生效的判据）
		if (__context.version != __lastVersion) {
			__lastVersion = __context.version;
			trace("文本图集已重置，版本号：" + __context.version + "，当前页数：" + __context.pageCount);
		}
		// 页数变化时打点：无头环境看不到画面，只能靠这条日志观测分页是否发生
		if (__context.pageCount != __lastPageCount) {
			__lastPageCount = __context.pageCount;
			trace("文本图集页数：" + __context.pageCount + "/" + __context.maxPages + " 唯一字形：" + __glyphCount());
		}
		// 字形总数需要遍历整个索引，没必要每帧统计
		if (__frame % 30 == 0) {
			__hud.data = "页数：" + __context.pageCount + "/" + __context.maxPages + "　唯一字形：" + __glyphCount() + "　（按C键清理图集）";
		}
		// 心跳：无头环境看不到画面，靠它判断帧循环是否还活着（静默无法区分"卡死"与"稳定"）
		if (__frame % 120 == 0) {
			trace("心跳 帧=" + __frame + " 页数=" + __context.pageCount + " 版本=" + __context.version + " 唯一字形=" + __glyphCount());
		}
		__frame++;
	}

	private function __glyphCount():Int {
		var atlas = __context.getAtlas();
		var count = 0;
		var keys = atlas.chars.keys();
		while (keys.hasNext()) {
			keys.next();
			count++;
		}
		var emojKeys = atlas.emojs.keys();
		while (emojKeys.hasNext()) {
			emojKeys.next();
			count++;
		}
		return count;
	}

	private function onKeyDown(e:openfl.events.KeyboardEvent):Void {
		// C 键：显式清理图集，回收除首页外的所有纹理页
		if (e.keyCode == 67) {
			trace("显式清理文本图集，清理前页数：" + __context.pageCount);
			Label.clearTextFieldContextBitmapData(0);
		}
	}
}
