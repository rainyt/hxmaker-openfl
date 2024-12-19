package hx.render;

import hx.utils.ColorUtils;
import hx.gemo.ColorTransform;
import openfl.utils.ObjectPool;
import hx.displays.Image;
import hx.text.TextFieldContextBitmapData;
import hx.providers.ITextFieldDataProvider;
import openfl.text.TextField;
import hx.core.Render;
import hx.displays.Label;

/**
 * 文本渲染器，需要支持纹理渲染
 */
class TextFieldRender {
	private static var __contextBitmapData:TextFieldContextBitmapData;

	/**
	 * 获得文本渲染纹理
	 * @return TextFieldContextBitmapData
	 */
	public static function getTextFieldContextBitmapData():TextFieldContextBitmapData {
		if (__contextBitmapData == null)
			__contextBitmapData = new TextFieldContextBitmapData(50);
		return __contextBitmapData;
	}

	public static function render(label:Label, render:Render):Void {
		if (label.data == null)
			return;
		if (label.root == null) {
			label.root = new Text(label);
		}
		var textField:Text = cast label.root;
		if (label.data != null) {
			var context = getTextFieldContextBitmapData();
			if (textField.text != label.data) {
				textField.text = label.data;
				context.drawText(textField.text); // 进行渲染，使用多个image组成
				textField.drawText(__contextBitmapData, render, true);
			} else {
				// 没有变化，则使用已有的数据进行渲染
				textField.drawText(__contextBitmapData, render);
			}
		}
	}
}

/**
 * 文本渲染显示对象
 */
@:access(hx.displays.DisplayObject)
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
	public var textWidth:Float = 0;

	/**
	 * 文本高度
	 */
	public var textHeight:Float = 0;

	public function getTextWidth():Float {
		return this.textWidth;
	}

	public function getTextHeight():Float {
		return this.textHeight;
	}

	public function reset():Void {
		for (image in images) {
			__images_pool.release(image);
		}
		images = [];
	}

	public function drawText(context:TextFieldContextBitmapData, render:Render, isReset:Bool = false):Void {
		var scale = label.textFormat.size / 60;
		if (isReset) {
			this.reset();
			var chars = this.text.split("");
			var offestX = 0.;
			var offestY = 0.;
			textWidth = 0;
			textHeight = 0;
			for (char in chars) {
				var fntFrame = context.getAtlas().getCharFntFrame(char);
				if (fntFrame != null) {
					var image = new Image(fntFrame.data);
					images.push(image);
					// 追加到渲染区域
					var color = ColorUtils.toShaderColor(label.textFormat.color);
					image.colorTransform = new ColorTransform(color.r, color.g, color.b, 1);
					image.x = offestX;
					image.y = offestY;
					offestX += fntFrame.xadvance * scale;
					if (offestX > textWidth)
						textWidth = offestX;
					if (offestY + fntFrame.data.rect.height > textHeight) {
						textHeight = offestY + fntFrame.data.rect.height;
					}
				} else {
					// 当空格处理
					offestX += 30 * scale;
				}
			}
			label.updateAlignTranform();
			label.__updateTransform(label.parent);
		}
		for (image in images) {
			var __worldTransform = image.__worldTransform;
			image.__worldAlpha = label.__worldAlpha * image.__alpha;
			// 世界矩阵
			__worldTransform.identity();
			__worldTransform.scale(scale, scale);
			__worldTransform.concat(image.__transform);
			// var scale = 0.5;
			__worldTransform.concat(label.__worldTransform);
			ImageRender.render(image, render);
		}
	}
}
