package hx.core;

import hx.shader.MultiTextureShader;
import openfl.geom.Rectangle;
import openfl.display.Shape;
import hx.render.CustomDisplayObjectRender;
import hx.display.CustomDisplayObject;
import hx.utils.ContextStats;
import hx.render.GraphicRender;
import hx.display.Graphics;
import hx.render.TextFieldRender;
import hx.render.ImageBufferData;
import hx.render.ImageRender;
import openfl.display.ShaderInput;
import openfl.display.BitmapData;
import openfl.display.ShaderParameter;
import openfl.display.Shader;
import hx.display.DisplayObject;
import openfl.geom.Matrix;
import hx.display.Quad;
import openfl.text.TextFormat;
import hx.display.Label;
import openfl.utils.ObjectPool;
import hx.display.Image;
import hx.display.DisplayObjectContainer;
import openfl.display.Sprite;
import hx.display.IRender;

using Reflect;

/**
 * OpenFL的渲染器支持
 */
@:keep
@:access(hx.display.DisplayObject)
@:access(openfl.geom.Matrix)
class Render implements IRender {
	/**
	 * 默认的着色器支持
	 */
	public static var defalutShader:Shader;

	/**
	 * 当前渲染的着色器
	 */
	public static var currentShader:Shader;

	/**
	 * 图片的缓存数据
	 */
	public var imageBufferData:Array<ImageBufferData> = [];

	/**
	 * 当前图片的缓存数据索引
	 */
	public var drawImageBuffDataIndex:Int = 0;

	/**
	 * 绘制图片缓存数据
	 * @param data 
	 */
	public function renderImageBuffData(data:ImageBufferData):Sprite {
		if (data.index > 0) {
			// 图形绘制
			data.endFill();
			var shape:Sprite = __pool.get();
			shape.graphics.clear();
			if (currentShader == null)
				currentShader = defalutShader;
			var openfl_TextureId:ShaderParameter<Float> = currentShader.data.openfl_TextureId;
			var openfl_Alpha:ShaderParameter<Float> = currentShader.data.openfl_Alpha_multi;
			var openfl_ColorMultiplier:ShaderParameter<Float> = currentShader.data.openfl_ColorMultiplier_muti;
			var openfl_ColorOffer:ShaderParameter<Float> = currentShader.data.openfl_ColorOffset_muti;
			var openfl_HasColorTransform:ShaderParameter<Float> = currentShader.data.openfl_HasColorTransform_muti;
			var openfl_blendMode_add:ShaderParameter<Float> = currentShader.data.openfl_blendMode_add;
			var offests:Array<Float> = [];
			var mapIds:Map<BitmapData, Int> = [];
			for (index => data in data.bitmapDatas) {
				mapIds.set(data, index);
				var sampler:ShaderInput<BitmapData> = currentShader.data.getProperty('uSampler$index');
				sampler.input = data;
				sampler.filter = LINEAR;
			}
			openfl_ColorOffer.value = data.colorOffset;
			openfl_ColorMultiplier.value = data.colorMultiplier;
			openfl_TextureId.value = data.ids;
			openfl_Alpha.value = data.alphas;
			openfl_blendMode_add.value = data.addBlendModes;
			openfl_HasColorTransform.value = data.hasColorTransform;
			shape.graphics.beginShaderFill(currentShader);
			shape.graphics.drawTriangles(data.vertices, data.indices, data.uvtData);
			shape.graphics.endFill();
			stage.addChild(shape);
			drawImageBuffDataIndex++;
			createImageBufferData(drawImageBuffDataIndex);
			ContextStats.statsVertexCount(data.indices.length);
			ContextStats.statsDrawCall();
			switch data.blendMode {
				case ADD:
					// shape.blendMode = ADD;
				case MULTIPLY:
					shape.blendMode = MULTIPLY;
				case NORMAL:
					shape.blendMode = NORMAL;
				case SCREEN:
					shape.blendMode = SCREEN;
				case DIFFERENCE:
					shape.blendMode = DIFFERENCE;
				case SUBTRACT:
					shape.blendMode = SUBTRACT;
				case INVERT:
					shape.blendMode = INVERT;
			}
			// currentShader = null;
			return shape;
		}
		return null;
	}

	/**
	 * 在OpenFL中渲染的舞台对象
	 */
	@:noCompletion private var __stage:Sprite = new Sprite();

	@:noCompletion private var __maskSprite:EngineSprite;

	/**
	 * 设置遮罩行为
	 * @param isMask 
	 */
	public function setMask(isMask:Bool):Void {
		if (isMask) {
			__maskSprite = new EngineSprite();
			__maskSprite.isPool = false;
			this.__stage.addChild(__maskSprite);
		} else {
			__maskSprite = null;
		}
	}

	public var stage(get, never):Sprite;

	private function get_stage():Sprite {
		if (__maskSprite != null) {
			return __maskSprite;
		}
		return __stage;
	}

	private var __pool:ObjectPool<EngineSprite> = new ObjectPool<EngineSprite>(() -> {
		return new EngineSprite();
	}, (sprite) -> {
		sprite.x = 0;
		sprite.y = 0;
		sprite.scrollRect = null;
		sprite.blendMode = NORMAL;
	});

	/**
	 * 游戏引擎对象
	 */
	// public var engine:Engine;

	public function new() {
		this.__stage.mouseChildren = this.__stage.mouseEnabled = false;
		// 使用多纹理支持
		if (defalutShader == null) {
			defalutShader = new MultiTextureShader();
		}
	}

	public function clear():Void {
		// 清理舞台
		for (i in 0...__stage.numChildren) {
			var display = __stage.getChildAt(i);
			if (display is EngineSprite) {
				var sprite:EngineSprite = cast display;
				if (!sprite.isPool && sprite.numChildren > 0) {
					for (i in 0...sprite.numChildren) {
						var child:openfl.display.DisplayObject = sprite.getChildAt(i);
						if (child is EngineSprite) {
							__pool.release(cast child);
						}
					}
					sprite.removeChildren();
				} else if (sprite.isPool)
					__pool.release(cast display);
			}
		}
		drawImageBuffDataIndex = 0;
		this.createImageBufferData(0);
		__stage.removeChildren();
		ContextStats.statsFps();
	}

	/**
	 * 创建图片缓存数据
	 * @param index 
	 * @return ImageBufferData
	 */
	public function createImageBufferData(index:Int):ImageBufferData {
		if (imageBufferData[index] == null) {
			var data = new ImageBufferData();
			imageBufferData[index] = data;
			return data;
		}
		var data = imageBufferData[index];
		data.reset();
		return data;
	}

	public function renderDisplayObject(object:DisplayObject):Void {
		// 自定义着色器支持
		var renderShader = currentShader;
		if (object.shader != null && object.shader != currentShader) {
			endFillImageDataBuffer();
			currentShader = object.shader;
		}
		if (object is Image) {
			renderImage(cast object);
		} else if (object is DisplayObjectContainer) {
			renderDisplayObjectContainer(cast object);
		} else if (object is Label) {
			renderLabel(cast object);
		} else if (object is Graphics) {
			renderGraphics(cast object);
		} else if (object is CustomDisplayObject) {
			renderCustomDisplayObject(cast object);
		}
		if (object.shader != null) {
			endFillImageDataBuffer();
			currentShader = renderShader;
		}
	}

	public function renderDisplayObjectContainer(container:DisplayObjectContainer) {
		// 如果存在遮罩时，需要结束掉之前的所有绘制
		if (container.maskRect != null) {
			endFillImageDataBuffer();
			this.setMask(true);
		}
		for (object in container.children) {
			if (!object.visible || object.alpha == 0) {
				continue;
			}
			if (object.background != null) {
				renderDisplayObject(object.background);
			}
			renderDisplayObject(object);
		}
		if (container.maskRect != null) {
			var shape = endFillImageDataBuffer();
			// 遮罩
			__retRect.setTo(0, 0, 0, 0);
			container.maskRect.transform(__retRect, container.__worldTransform);
			__maskRect.setTo(__retRect.x, __retRect.y, __retRect.width, __retRect.height);
			// shape.scrollRect = __maskRect;
			__maskSprite.x = __retRect.x;
			__maskSprite.y = __retRect.y;
			__maskSprite.scrollRect = __maskRect;
			this.setMask(false);
		}
		container.__dirty = false;
	}

	private static var __retRect:hx.geom.Rectangle = new hx.geom.Rectangle();

	private static var __maskRect:Rectangle = new Rectangle();

	/**
	 * 渲染自定义对象
	 * @param displayObject 
	 */
	public function renderCustomDisplayObject(displayObject:CustomDisplayObject):Void {
		this.endFillImageDataBuffer();
		if (displayObject.root != null) {
			CustomDisplayObjectRender.render(displayObject, this);
		}
		ContextStats.statsVisibleDisplayCounts();
	}

	public function renderImage(image:Image):Void {
		if (image.scale9Grid != null) {
			renderGraphics(image.getScale9GridGraphic());
		} else {
			ImageRender.render(image, this);
		}
		ContextStats.statsVisibleDisplayCounts();
	}

	public function getMarix(display:DisplayObject):Matrix {
		var hm:hx.geom.Matrix = display.__worldTransform;
		var m = new Matrix(hm.a, hm.b, hm.c, hm.d, hm.tx, hm.ty);
		return m;
	}

	/**
	 * 渲染Label对象
	 * @param image 
	 */
	public function renderLabel(label:Label, offScreenRender:Bool = false):Void {
		TextFieldRender.render(label, offScreenRender ? null : this);
		ContextStats.statsVisibleDisplayCounts();
	}

	/**
	 * 渲染三角形图形
	 * @param graphics 
	 */
	public function renderGraphics(graphics:Graphics):Void {
		GraphicRender.render(graphics, this);
		ContextStats.statsVisibleDisplayCounts();
	}

	/**
	 * 最终写入图片缓冲区
	 */
	public function endFillImageDataBuffer():Sprite {
		return this.renderImageBuffData(this.imageBufferData[this.drawImageBuffDataIndex]);
	}

	/**
	 * 结束所有绘制调用
	 */
	public function endFill():Void {
		this.renderImageBuffData(this.imageBufferData[this.drawImageBuffDataIndex]);
		this.imageBufferData = this.imageBufferData.splice(0, this.drawImageBuffDataIndex + 1);
	}
}
