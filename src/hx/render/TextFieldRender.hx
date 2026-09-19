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
	private static var __contextBitmapData:TextFieldContextBitmapData;

	/**
	 * 获得文本渲染纹理
	 * @return TextFieldContextBitmapData
	 */
	public static function getTextFieldContextBitmapData():TextFieldContextBitmapData {
		if (__contextBitmapData == null) {
			var context = new TextFieldContextBitmapData(50, 2048, 2048, 5, 5);
			__contextBitmapData = context;
		}
		return __contextBitmapData;
	}

	/**
	 * 释放文本渲染纹理
	 * @param cacheId 缓存id
	 */
	public static function disposeTextFieldContextBitmapData(cacheId:Int = 0):Void {
		__contextBitmapData.dispose();
		__contextBitmapData = null;
	}

	/**
	 * 预写文本，由`TextFieldQueue`在正式渲染之前调用。
	 * 与`render`的区别是只重建渲染数据，不提交绘制，这样图集的写入（包括写满后的整张重排）
	 * 都会发生在渲染遍历之前，不会污染本帧已经入队的顶点。
	 * @param label 文本对象
	 */
	public static function prepareLabel(label:Label):Void {
		if (label.data == null)
			return;
		var textField = getText(label);
		if (textField.text != label.data || @:privateAccess label.__textFormatDirty) {
			var context = getTextFieldContextBitmapData();
			rebuildText(textField, label, context);
			textField.drawText(context, null, true);
		}
	}

	public inline static function render(label:Label, render:Render):Void {
		if (label.data == null)
			return;
		var textField = getText(label);
		if (label.data != null) {
			var context = getTextFieldContextBitmapData();
			if (textField.text != label.data || @:privateAccess label.__textFormatDirty) {
				if (TextFieldQueue.isRendering()) {
					// 渲染遍历中禁止写图集：写入可能撑满图集并触发整张重排，
					// 从而让本帧已经入队的顶点读到错误的内容。
					// 这里只重建渲染数据，字形留给下一次`prepare`补写；
					// 脏标记刻意不清除，保证`prepareLabel`下一帧仍会处理它。
					textField.text = label.data;
					TextFieldQueue.invalidate(label);
				} else {
					rebuildText(textField, label, context);
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

	public function new(label:Label) {
		this.label = label;
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
			this.drawText(TextFieldRender.getTextFieldContextBitmapData(), null, true);
		}
		return this.textWidth;
	}

	public function getTextHeight():Float {
		if (this.textWidth == null) {
			this.drawText(TextFieldRender.getTextFieldContextBitmapData(), null, true);
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
				var fntFrame = context.getAtlas(char).getCharFntFrame(char);
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
