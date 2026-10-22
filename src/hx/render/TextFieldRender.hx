package hx.render;

import hx.geom.Rectangle;
import hx.utils.ColorUtils;
import hx.geom.ColorTransform;
import openfl.utils.ObjectPool;
import hx.display.Image;
import hx.text.TextFieldContextBitmapData;
import hx.providers.ITextFieldDataProvider;
import hx.providers.ITextFieldLayoutProvider;
import openfl.text.TextField;
import hx.core.Render;
import hx.display.Label;
import hx.text.TextFieldQueue;

/**
 * 文本渲染器，需要支持纹理渲染
 */
class TextFieldRender {
	/** 离屏文本不一定驻留舞台，也必须能察觉字形设备代次变化。 */
	public static var contextGeneration(default, null):Int = 0;
	public static var preparedLabels(default, null):Int = 0;
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
	 */
	public static function disposeTextFieldContextBitmapData():Void {
		if (__contextBitmapData == null)
			return;
		__contextBitmapData.dispose();
		// 必须置为`null`而不是保留：`getTextFieldContextBitmapData`靠它判断是否需要重建
		__contextBitmapData = null;
		// 纹理已经释放，让它上面驻留的文本重新写入新图集
		TextFieldQueue.invalidateAll();
	}

	/** 保留外部设置的图集对象及其配置，只重建已失效的字形。 */
	public static function onContextRestored(forceRedraw:Bool = false):Void {
		contextGeneration++;
		if (__contextBitmapData != null) __contextBitmapData.onContextRestored(forceRedraw);
		for (label in TextFieldQueue.getResident()) {
			var text = getText(label);
			@:privateAccess text.__building = false;
			text.prepared = false;
		}
		TextFieldQueue.invalidateAll();
	}

	/** 只读取 CPU 诊断数据，不创建图集、不执行 GPU 查询或像素读回。 */
	public static function contextStats():Dynamic {
		var current = 0, stale = 0;
		for (label in TextFieldQueue.getResident()) {
			if (label.root != null) {
				var text = getText(label);
				if (text.prepared && text.preparedGeneration == contextGeneration) current++; else stale++;
			} else stale++;
		}
		return {generation:contextGeneration,resident:TextFieldQueue.residentCount,pending:TextFieldQueue.pendingCount,
			prepared:current,stale:stale,prepareTotal:preparedLabels,
			atlasCount:__contextBitmapData == null ? 0 : __contextBitmapData.atlasCount,
			glyphCount:__contextBitmapData == null ? 0 : __contextBitmapData.glyphCount,
			glyphWrites:__contextBitmapData == null ? 0 : __contextBitmapData.glyphWrites,
			cpuPixels:__contextBitmapData != null && __contextBitmapData.cpuAtlasEnabled};
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
		preparedLabels++;
		// 预写完成后消费掉脏标记。叶子显示对象的`__dirty`在渲染遍历中不会被清除
		// （渲染遍历只清除舞台与容器自身），不清掉的话`Label.getTextWidth/Height`
		// 每次调用都会重新走一遍完整重建。任何内容/格式变更都会重新置脏，这里清除不会漏建
		@:privateAccess label.setDirty(false);
	}

	public inline static function render(label:Label, render:Render):Void {
		if (label.data == null)
			return;
		var textField = getText(label);
		var context = getTextFieldContextBitmapData();
		if (!@:privateAccess textField.__building && (!textField.prepared || textField.preparedGeneration != contextGeneration || TextFieldQueue.isPending(label))) {
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
		textField.preparedGeneration = contextGeneration;
	}
}

/**
 * 文本渲染显示对象
 */
@:access(hx.display.DisplayObject)
class Text implements ITextFieldLayoutProvider {
	/**
	 * 字符图片回收池，所有`Text`实例共享，避免文本重建时反复分配
	 */
	private static var __images_pool:ObjectPool<Image> = new ObjectPool<Image>(() -> {
		return new Image();
	});

	/**
	 * 字符颜色变换回收池，所有`Text`实例共享。
	 * `colorTransform`的setter是拷贝语义（`setTo`进`image`自己的实例，不保留传入对象），
	 * 所以同一个实例配置完立即归还，可以反复使用
	 */
	private static var __colorTransformPool:ObjectPool<ColorTransform> = new ObjectPool<ColorTransform>(() -> {
		return new ColorTransform();
	});

	/**
	 * 当前已渲染的文本内容
	 */
	public var images:Array<Image> = [];

	/**
	 * 每个字符的边界
	 */
	public var charBounds:Array<Rectangle> = [];

	/** 插入位置独立于字形边界，包含尾部空格和文本末尾。 */
	private var __caretBounds:Array<Rectangle> = [];
	private var __textBounds:Rectangle = new Rectangle();
	private var __imageIndices:Array<Int> = [];
	public var layoutVersion(default, null):Int = 0;

	public function getTextBounds():Rectangle {
		return __textBounds;
	}

	public function getCaretBounds(index:Int):Rectangle {
		return index < 0 || index >= __caretBounds.length ? null : __caretBounds[index];
	}

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
	public var preparedGeneration:Int = -1;

	/**
	 * 是否正在构建渲染数据，用于阻止构建过程中的重入
	 */
	@:privateAccess private var __building:Bool = false;

	/**
	 * 字符世界矩阵是否与`label`当前的世界矩阵一致。
	 * 文本重建会整体换掉字符对象，即使世界矩阵分量没有变化也必须重算一次，重建后置为`false`
	 */
	private var __worldSynced:Bool = false;

	/**
	 * 上次同步时`label`的世界矩阵分量
	 */
	private var __lastWorldA:Float = 0;
	private var __lastWorldB:Float = 0;
	private var __lastWorldC:Float = 0;
	private var __lastWorldD:Float = 0;
	private var __lastWorldTX:Float = 0;
	private var __lastWorldTY:Float = 0;

	/**
	 * 上次同步时`label`的世界透明度与平滑设置
	 */
	private var __lastWorldAlpha:Float = -1;
	private var __lastSmoothing:Bool = false;

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
		if (this.textHeight == null) {
			TextFieldRender.render(this.label, null);
		}
		return this.textHeight;
	}

	public function getChatBounds(index:Int):Rectangle {
		if (index < 0 || index >= charBounds.length) {
			return null;
		}
		return charBounds[index];
	}

	public function release():Void {
		for (image in images) {
			image.data = null;
			__images_pool.release(image);
		}
		// 复用数组本身，减少重建时的分配
		images.resize(0);
		charBounds.resize(0);
		__caretBounds.resize(0);
		__imageIndices.resize(0);
	}

	public function drawText(context:TextFieldContextBitmapData, render:Render, isReset:Bool = false):Void {
		if (isReset) {
			this.release();
			var allText = this.text;
			if (label.charFilterEnabled && Label.onGlobalCharFilter != null) {
				allText = Label.onGlobalCharFilter(allText);
			}
			var chars = allText.split("");
			var offsetX = 0.;
			var offsetY = 0.;
			var lineAdvance = 0.;
			var caretHeight:Float = label.fontSize + 2;
			__textBounds.setTo(0, 0, 0, 0);
			textWidth = 0;
			textHeight = 0;
			for (index => char in chars) {
				var textFormat = label.getCharTextFormatAt(index);
				var scale = textFormat.size / context.fontSize;
				var atlas = context.getAtlas(char);
				var frame = atlas == null ? null : atlas.getCharFntFrame(char);
				var isNewline = char == "\n" || char == "\r";
				var advance = frame == null ? 30 * scale * 0.8 : frame.xadvance * scale;
				caretHeight = Math.max(textFormat.size + 2, frame == null ? 0 : frame.data.rect.height * scale);
				// 空白字符与普通字形遵循同一换行逻辑；过宽的首字符保留在当前行并交给视口裁剪。
				if (!isNewline && label.wordWrap && label.__width != null && offsetX > 0 && offsetX + advance > label.width) {
					offsetX = 0;
					offsetY += lineAdvance;
					lineAdvance = 0;
				}
				lineAdvance = Math.max(lineAdvance, 60 * scale);
				__caretBounds.push(new Rectangle(offsetX, offsetY, 1, caretHeight));
				if (isNewline) {
					charBounds.push(null);
					textWidth = Math.max(textWidth, offsetX);
					offsetX = 0;
					// CRLF 只换行一次，同时保留两个字符索引。
					if (char != "\n" || index == 0 || chars[index - 1] != "\r")
						offsetY += lineAdvance;
					lineAdvance = 0;
				} else {
					var width = frame == null ? advance : frame.data.rect.width * scale;
					var height = frame == null ? caretHeight : frame.data.rect.height * scale;
					charBounds.push(new Rectangle(offsetX, offsetY, width, height));
					if (frame != null) {
						var image = __images_pool.get();
						image.data = frame.data;
						image.smoothing = label.smoothing;
						image.x = offsetX;
						image.y = offsetY;
						images.push(image);
						__imageIndices.push(index);
						var color = ColorUtils.toShaderColor(textFormat.color);
						var colorTransform = __colorTransformPool.get();
						colorTransform.redMultiplier = color.r;
						colorTransform.greenMultiplier = color.g;
						colorTransform.blueMultiplier = color.b;
						colorTransform.alphaMultiplier = 1;
						image.colorTransform = colorTransform;
						__colorTransformPool.release(colorTransform);
					}
					textWidth = Math.max(textWidth, offsetX + Math.max(width, advance));
					offsetX += advance;
					textHeight = Math.max(textHeight, offsetY + height);
				}
			}
			__caretBounds.push(new Rectangle(offsetX, offsetY, 1, caretHeight));
			// 同一行的插入位置使用统一高度，字符字形的高低不会影响点击定位。
			var lineStart = 0;
			var lineHeight = 0.;
			for (i in 0...__caretBounds.length) {
				if (i > lineStart && __caretBounds[i].y != __caretBounds[lineStart].y) {
					for (j in lineStart...i) __caretBounds[j].height = lineHeight;
					lineStart = i;
					lineHeight = 0;
				}
				lineHeight = Math.max(lineHeight, __caretBounds[i].height);
			}
			for (j in lineStart...__caretBounds.length) __caretBounds[j].height = lineHeight;
			// 普通文字仍以字形高度测量；末尾换行需要保留空行的布局高度。
			if (chars.length > 0 && (chars[chars.length - 1] == "\n" || chars[chars.length - 1] == "\r"))
				textHeight = Math.max(textHeight, offsetY + caretHeight);
			__textBounds.setTo(0, 0, textWidth, textHeight);
			layoutVersion++;
			label.updateAlignTranform();
			label.__updateTransform(label.parent);
			// 字符对象已全部换新，即使`label`的世界矩阵分量与上次完全相同，
			// 也必须在下一次绘制前重算一遍字符的世界矩阵
			__worldSynced = false;
		}
		if (render != null) {
			// 不能用`label.__transformDirty`做判断：它在祖先节点上永不清除，一旦场景动过
			// 所有后代文本每帧都会被重新标脏；而`updateAlignTranform`改原点时又不会打脏标记。
			// 这里改为比对世界矩阵分量，静止的文本直接跳过重算
			if (__needWorldSync()) {
				__syncWorldTransform(context);
			}
			for (image in images) {
				ImageRender.render(image, render);
			}
		}
	}

	/**
	 * 判断字符的世界矩阵是否需要重新同步：
	 * 刚重建过渲染数据、或`label`的世界矩阵任一分量、世界透明度、平滑设置发生变化
	 */
	private function __needWorldSync():Bool {
		if (!__worldSynced) {
			return true;
		}
		var worldTransform = label.__worldTransform;
		return __lastWorldA != worldTransform.a || __lastWorldB != worldTransform.b || __lastWorldC != worldTransform.c
			|| __lastWorldD != worldTransform.d || __lastWorldTX != worldTransform.tx || __lastWorldTY != worldTransform.ty
			|| __lastWorldAlpha != label.__worldAlpha || __lastSmoothing != label.smoothing;
	}

	/**
	 * 把每个字符的世界矩阵、世界透明度同步到`label`的当前值
	 */
	private function __syncWorldTransform(context:TextFieldContextBitmapData):Void {
		var worldTransform = label.__worldTransform;
		__lastWorldA = worldTransform.a;
		__lastWorldB = worldTransform.b;
		__lastWorldC = worldTransform.c;
		__lastWorldD = worldTransform.d;
		__lastWorldTX = worldTransform.tx;
		__lastWorldTY = worldTransform.ty;
		__lastWorldAlpha = label.__worldAlpha;
		__lastSmoothing = label.smoothing;
		for (index => image in images) {
			var textFormat = label.getCharTextFormatAt(__imageIndices[index]);
			var scale = textFormat.size / context.fontSize;
			var world = image.__worldTransform;
			image.smoothing = label.smoothing;
			image.__worldAlpha = label.__worldAlpha * image.__alpha;
			image.setTransformDirty(true);
			// 世界矩阵
			world.identity();
			world.scale(scale, scale);
			world.concat(image.__transform);
			world.concat(worldTransform);
		}
		__worldSynced = true;
	}
}
