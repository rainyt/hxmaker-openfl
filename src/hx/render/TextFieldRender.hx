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
	 * 设置文本渲染纹理。
	 *
	 * 当前只有一个全局缓存器，`cacheId`仅用于兼容旧调用，不做区分。
	 * @param cacheId 缓存id
	 * @param context 文本缓存器
	 */
	public static function setTextFieldContextBitmapData(cacheId:Int = 0, context:TextFieldContextBitmapData):Void {
		if (context == null)
			return;
		__contextBitmapData = context;
		// 旧图集上的字形已经失效，让所有驻留文本重新写入
		TextFieldQueue.invalidateAll();
	}

	/**
	 * 释放文本渲染纹理，缓存器会在下一次取用时重建
	 * @param cacheId 缓存id
	 */
	public static function disposeTextFieldContextBitmapData(cacheId:Int = 0):Void {
		if (__contextBitmapData == null)
			return;
		__contextBitmapData.dispose();
		// 必须置为`null`而不是保留：`getTextFieldContextBitmapData`靠它判断是否需要重建
		__contextBitmapData = null;
		// 纹理已经释放，让它上面驻留的文本重新写入新图集
		TextFieldQueue.invalidateAll();
	}

	/**
	 * 预写文本，由`TextFieldQueue`在正式渲染之前调用。
	 * 与`render`的区别是只重建渲染数据，不提交绘制，这样字形写入只会发生在渲染遍历之前，
	 * 不会污染本帧已经入队的顶点。
	 *
	 * 队列传来的都是本帧真正发生变动的文本，所以这里不做"内容是否变化"的比对：
	 * 图集被替换之后文本内容没变、字形却已经失效，同样需要重写。
	 * @param label 文本对象
	 */
	public static function prepareLabel(label:Label):Void {
		if (label.data == null)
			return;
		var textField = getText(label);
		// 构建布局时会走回`Label.getTextWidth/Height`做对齐，而它们的脏标记会再次走到这里，
		// 用标记挡住重入
		if (@:privateAccess textField.__building)
			return;
		@:privateAccess textField.__building = true;
		var context = getTextFieldContextBitmapData();
		rebuildText(textField, label, context);
		textField.drawText(context, null, true);
		@:privateAccess textField.__building = false;
	}

	public inline static function render(label:Label, render:Render):Void {
		if (label.data == null)
			return;
		var textField = getText(label);
		var context = getTextFieldContextBitmapData();
		if (!@:privateAccess textField.__building && (!textField.prepared || TextFieldQueue.isPending(label))) {
			if (TextFieldQueue.isRendering()) {
				// 渲染遍历中禁止写图集：本帧只构建布局，缺字形的地方退化成空格，
				// 字形留给下一帧的`prepare`补写
				@:privateAccess textField.__building = true;
				textField.text = label.data;
				textField.drawText(context, null, true);
				@:privateAccess textField.__building = false;
			} else {
				// 不在渲染遍历中（离屏测量、把文本树绘制到位图的场景），就地写入图集
				prepareLabel(label);
			}
		}
		// 渲染遍历只提交绘制，不写图集；字形一律由`prepare`在遍历之前写好
		textField.drawText(context, render);
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
		textField.prepared = true;
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
	 * 字形是否已经写入图集。为`false`时只能先构建布局，绘制会缺失字形
	 */
	public var prepared:Bool = false;

	/**
	 * 是否正在构建渲染数据，用于阻止构建过程中的重入
	 */
	@:privateAccess private var __building:Bool = false;

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
			// 兜底：正常情况下布局已经在`prepare`阶段构建好了
			TextFieldRender.render(this.label, null);
		}
		return this.textWidth;
	}

	public function getTextHeight():Float {
		if (this.textWidth == null) {
			TextFieldRender.render(this.label, null);
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
				var atlas = context.getAtlas(char);
				// 图集里没有这个字符：可能是它本身就无法渲染（拿不到字形边界），按空格处理
				var fntFrame = atlas == null ? null : atlas.getCharFntFrame(char);
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
