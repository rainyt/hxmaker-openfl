package hx.render;

import hx.geom.Rectangle;
import hx.utils.ColorUtils;
import hx.geom.ColorTransform;
import openfl.utils.ObjectPool;
import hx.display.Image;
import hx.text.TextFieldContextBitmapData;
import hx.providers.ITextFieldDataProvider;
import openfl.text.TextField;
import hx.core.Render;
import hx.display.Label;
import hx.text.TextFieldQueue;

/**
 * 文本渲染器，需要支持纹理渲染
 */
class TextFieldRender {
	/**
	 * 文本渲染纹理缓存
	 */
	private static var __contextBitmapDataCache:Map<Int, TextFieldContextBitmapData> = [];

	/**
	 * 获得文本渲染纹理
	 * @return TextFieldContextBitmapData
	 */
	public static function getTextFieldContextBitmapData(cacheId:Int):TextFieldContextBitmapData {
		if (!__contextBitmapDataCache.exists(cacheId)) {
			// 页尺寸取 1024：分页粒度更细、浪费更少，4 页合计 16MB，与改动前的单张 2048² 持平
			var context = new TextFieldContextBitmapData(50, 1024, 1024, 5, 5);
			context.cacheId = cacheId;
			__contextBitmapDataCache[cacheId] = context;
		}
		return __contextBitmapDataCache[cacheId];
	}

	/**
	 * 释放文本渲染纹理
	 * @param cacheId 缓存id
	 */
	public static function disposeTextFieldContextBitmapData(cacheId:Int = 0):Void {
		var context = __contextBitmapDataCache[cacheId];
		if (context == null)
			return;
		context.dispose();
		// 必须移除而不是置空：置空之后`getTextFieldContextBitmapData`会因为`exists`为真而返回 null
		__contextBitmapDataCache.remove(cacheId);
	}

	/**
	 * 渲染遍历期间被请求、需要推迟到下一次预写执行的清理
	 */
	private static var __pendingClear:Array<Int> = [];

	/**
	 * 清空指定文本缓存器的图集，由客户端在安全时机（例如切场景）调用。
	 *
	 * 分页图集写满时只会新开一页、不会再原地重排，所以通常不需要调用，
	 * 只在需要回收显存（页数接近`maxPages`）时才用得上。
	 * 若在渲染遍历中调用，会推迟到下一次预写执行，不会破坏本帧已经入队的顶点。
	 * @param cacheId 缓存id
	 */
	public static function clearTextFieldContextBitmapData(cacheId:Int = 0):Void {
		if (TextFieldQueue.isRendering()) {
			if (!__pendingClear.contains(cacheId))
				__pendingClear.push(cacheId);
			return;
		}
		var context = __contextBitmapDataCache[cacheId];
		if (context != null)
			context.reset();
	}

	/**
	 * 执行渲染期被推迟的清理，由`TextFieldQueue.prepare`在帧首的安全点调用
	 */
	public static function applyPendingClear():Void {
		if (__pendingClear.length == 0)
			return;
		var list = __pendingClear;
		__pendingClear = [];
		for (cacheId in list) {
			var context = __contextBitmapDataCache[cacheId];
			if (context != null)
				context.reset();
		}
	}

	/**
	 * 设置文本渲染纹理
	 * @param cacheId 缓存id
	 * @param context 文本渲染纹理
	 */
	public static function setTextFieldContextBitmapData(cacheId:Int = 0, context:TextFieldContextBitmapData):Void {
		context.cacheId = cacheId;
		__contextBitmapDataCache[cacheId] = context;
	}

	/**
	 * 预写文本，由`TextFieldQueue`在正式渲染之前调用。
	 * 与`render`的区别是只重建渲染数据，不提交绘制，这样图集的写入都会发生在渲染遍历之前。
	 *
	 * 图集版本失配也必须重新写入：图集被重置后，文本的渲染数据指向的是已经不存在的字形。
	 * 这一条不能省——被强制入队的离屏文本只会走这个入口，
	 * 少了它字形就永远写不进新图集，表现为永久缺字。
	 * @param label 文本对象
	 */
	public static function prepareLabel(label:Label):Void {
		if (label.data == null)
			return;
		var textField = getText(label);
		var context = getTextFieldContextBitmapData(label.textCacheId);
		if (textField.text != label.data || @:privateAccess label.__textFormatDirty || textField.isAtlasChanged(context)) {
			rebuildText(textField, label, context);
			textField.drawText(context, null, true);
			textField.markAtlasVersion(context);
		}
	}

	public inline static function render(label:Label, render:Render):Void {
		if (label.data == null)
			return;
		var textField = getText(label);
		if (label.data != null) {
			var context = getTextFieldContextBitmapData(label.textCacheId);
			if (textField.text != label.data || @:privateAccess label.__textFormatDirty || textField.isAtlasChanged(context)) {
				if (TextFieldQueue.isRendering()) {
					// 渲染遍历中不写图集：分页之后写入空闲矩形或新开一页都不会覆盖已用区域，
					// 但把写入统一收敛到`prepare`，可以让"图集只在一处被改写"成为一条无需推理的约束，
					// 也给将来可能出现的页回收留出安全边界。
					// 这里只重建渲染数据（重建只读图集），字形留给下一次`prepare`补写；
					// 版本标记刻意不更新，保证下一帧`prepareLabel`仍会重新写入。
					textField.text = label.data;
					// 强制入队：离屏、cacheAsBitmap等不在舞台树上的文本也要能补上字形
					TextFieldQueue.invalidate(label, true);
				} else {
					rebuildText(textField, label, context);
					textField.markAtlasVersion(context);
				}
				// 进行渲染，使用多个image组成
				textField.drawText(context, render, true);
			} else {
				// 没有变化，则使用已有的数据进行渲染
				textField.drawText(context, render);
			}
		}
	}

	/**
	 * 获得文本对象的渲染数据，不存在时创建
	 * @param label 文本对象
	 * @return Text
	 */
	private static function getText(label:Label):Text {
		if (label.root == null) {
			label.root = new Text(label);
		}
		return cast label.root;
	}

	/**
	 * 把文本写入图集，并标记为不再是脏数据
	 * @param textField 文本渲染数据
	 * @param label 文本对象
	 * @param context 文本图集
	 */
	private static function rebuildText(textField:Text, label:Label, context:TextFieldContextBitmapData):Void {
		textField.text = label.data;
		@:privateAccess label.__textFormatDirty = false;
		if (label.charFilterEnabled && Label.onGlobalCharFilter != null)
			context.drawText(Label.onGlobalCharFilter(textField.text));
		else
			context.drawText(textField.text);
	}
}

/**
 * 文本渲染显示对象
 */
@:access(hx.display.DisplayObject)
class Text implements ITextFieldDataProvider {
	/**
	 * 回收池
	 */
	private static var __images_pool:ObjectPool<Image> = new ObjectPool<Image>(() -> {
		return new Image();
	});

	/**
	 * 当前已渲染的文本内容
	 */
	public var images:Array<Image> = [];

	/**
	 * 每个字符的边界
	 */
	public var charBounds:Array<Rectangle> = [];

	/**
	 * 应用的显示对象
	 */
	public var label:Label;

	/**
	 * 构建当前渲染数据时所依据的图集版本。
	 *
	 * `-1`表示还没写过图集；与`context.version`不一致就说明图集被重置过，
	 * 现有的`images`指向的是已经不存在的字形，必须重建。
	 */
	private var __atlasVersion:Int = -1;

	public function new(label:Label) {
		this.label = label;
	}

	/**
	 * 图集是否在本次渲染数据构建之后被重置过
	 * @param context 文本图集
	 * @return Bool
	 */
	public function isAtlasChanged(context:TextFieldContextBitmapData):Bool {
		return __atlasVersion != context.version;
	}

	/**
	 * 记录本次字形写入所依据的图集版本。
	 * 只能在真正把字形写进图集之后调用：提前调用会让缺失的字形被永久判定为有效。
	 * @param context 文本图集
	 */
	public function markAtlasVersion(context:TextFieldContextBitmapData):Void {
		__atlasVersion = context.version;
	}

	/**
	 * 当前文本
	 */
	public var text:String = null;

	/**
	 * 文本宽度
	 */
	public var textWidth:Null<Float> = null;

	/**
	 * 文本高度
	 */
	public var textHeight:Null<Float> = null;

	public function getTextWidth():Float {
		if (this.textWidth == null) {
			this.drawText(TextFieldRender.getTextFieldContextBitmapData(label.textCacheId), null, true);
		}
		return this.textWidth;
	}

	public function getTextHeight():Float {
		if (this.textWidth == null) {
			this.drawText(TextFieldRender.getTextFieldContextBitmapData(label.textCacheId), null, true);
		}
		return this.textHeight;
	}

	public function getChatBounds(index:Int):Rectangle {
		if (index < 0 || index > images.length) {
			return null;
		}
		return charBounds[index];
	}

	public function release():Void {
		// for (image in images) {
		// __images_pool.release(image);
		// }
		// trace("__images_pool", __images_pool.activeObjects);
		images = [];
	}

	public function drawText(context:TextFieldContextBitmapData, render:Render, isReset:Bool = false):Void {
		if (isReset) {
			this.release();
			var allText = this.text;
			if (label.charFilterEnabled && Label.onGlobalCharFilter != null) {
				allText = Label.onGlobalCharFilter(allText);
			}
			var chars = allText.split("");
			var offestX = 0.;
			var offestY = 0.;
			textWidth = 0;
			textHeight = 0;
			charBounds = [];
			for (index => char in chars) {
				var fntFrame = context.getAtlas().getCharFntFrame(char);
				var textFormat = label.getCharTextFormatAt(index);
				var scale = textFormat.size / context.fontSize;
				if (fntFrame != null) {
					// var image = __images_pool.get();
					var image = new Image();
					image.data = fntFrame.data;
					image.smoothing = label.smoothing;
					images.push(image);
					// 追加到渲染区域
					var color = ColorUtils.toShaderColor(textFormat.color);
					image.colorTransform = new ColorTransform(color.r, color.g, color.b, 1);
					image.x = offestX;
					image.y = offestY;
					offestX += fntFrame.xadvance * scale;
					if (label.wordWrap && label.__width != null && offestX > label.width) {
						offestX = fntFrame.xadvance * scale;
						offestY += 60 * scale;
						image.x = 0;
						image.y = offestY;
					}
					if (offestX > textWidth)
						textWidth = offestX;
					if (offestY + fntFrame.data.rect.height * scale > textHeight) {
						textHeight = offestY + fntFrame.data.rect.height * scale;
					}
					charBounds.push(new Rectangle(offestX - fntFrame.xadvance * scale, offestY, fntFrame.data.rect.width * scale,
						fntFrame.data.rect.height * scale));
				} else if (char == "\n") {
					// 换行处理
					charBounds.push(null);
					offestX = 0;
					offestY += 60 * scale;
				} else {
					// 当空格处理
					charBounds.push(new Rectangle(offestX, offestY, 30 * scale * 0.8, 60 * scale));
					offestX += 30 * scale * 0.8;
				}
			}
			label.updateAlignTranform();
			label.__updateTransform(label.parent);
		}
		if (render != null) {
			for (index => image in images) {
				if (label.__transformDirty) {
					var textFormat = label.getCharTextFormatAt(index);
					var scale = textFormat.size / context.fontSize;
					var __worldTransform = image.__worldTransform;
					image.smoothing = label.smoothing;
					image.__worldAlpha = label.__worldAlpha * image.__alpha;
					image.setTransformDirty(true);
					// 世界矩阵
					__worldTransform.identity();
					__worldTransform.scale(scale, scale);
					__worldTransform.concat(image.__transform);
					// var scale = 0.5;
					__worldTransform.concat(label.__worldTransform);
				}
				ImageRender.render(image, render);
			}
		}
	}
}
