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
 * 永远填不满一张图集，测不出溢出路径。
 *
 * 验证要点：
 * 1. 图集写满后只会追加新的纹理，**先写入的文字始终保持正确**（不串字）；
 * 2. 已缓存的字形不会被重复写进新图集（`唯一字形`不该随着页数暴涨）；
 * 3. 按`C`键释放图集后，驻留文本会在下一帧重新写入新图集（版本/页数回落，文本不消失）。
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
	 * 上一次上报的图集数量，用于在图集追加时打点（无头环境只能靠日志观测）
	 */
	private var __lastAtlasCount:Int = -1;

	override function onStageInit() {
		super.onStageInit();
		if (TextFormat.defaultFont == null) {
			// 必须在第一个文本缓存器创建之前设置：字体是在缓存器构造时固化进`TextFormat`的，
			// 此后没有更新路径
			TextFormat.defaultFont = "assets/font/SourceHanSansSC-Bold.otf";
		}
		__context = TextFieldRender.getTextFieldContextBitmapData();
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
		// 每帧重新取一次：图集释放之后缓存器会被重建，这里才能观测到新的那一份
		__context = TextFieldRender.getTextFieldContextBitmapData();
		for (label in __labels) {
			label.data = __nextText();
		}
		// 图集数量变化时打点：无头环境看不到画面，只能靠这条日志观测是否发生了追加
		if (__context.atlasCount != __lastAtlasCount) {
			__lastAtlasCount = __context.atlasCount;
			trace("文本图集数量：" + __context.atlasCount + " 唯一字形：" + __context.glyphCount);
		}
		// 字形总数需要遍历整个索引，没必要每帧统计
		if (__frame % 30 == 0) {
			__hud.data = "图集：" + __context.atlasCount + " 张　唯一字形：" + __context.glyphCount + "　（按C键释放图集）";
		}
		// 心跳：无头环境看不到画面，靠它判断帧循环是否还活着（静默无法区分"卡死"与"稳定"）
		if (__frame % 120 == 0) {
			trace("心跳 帧=" + __frame + " 图集=" + __context.atlasCount + " 唯一字形=" + __context.glyphCount);
		}
		__frame++;
	}

	private function onKeyDown(e:openfl.events.KeyboardEvent):Void {
		// C 键：释放整个文本图集，验证释放后驻留文本能否重新写入新图集
		if (e.keyCode == 67) {
			trace("释放文本图集，释放前图集数量：" + __context.atlasCount);
			Label.disposeTextFieldContextBitmapData();
		}
	}
}
