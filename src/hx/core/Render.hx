package hx.core;

import openfl.geom.Rectangle;
import openfl.display.Shape;
import hx.render.CustomDisplayObjectRender;
import hx.display.CustomDisplayObject;
import hx.utils.ContextStats;
import hx.render.GraphicRender;
import hx.display.Graphic;
import hx.render.TextFieldRender;
import hx.render.ImageBufferData;
import hx.render.ImageRender;
import openfl.display.ShaderInput;
import openfl.display.BitmapData;
import openfl.display.ShaderParameter;
import lime.graphics.opengl.GL;
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
@:access(hx.display.DisplayObject)
@:access(openfl.geom.Matrix)
class Render implements IRender {
	/**
	 * 默认的着色器支持
	 */
	public static var defalutShader:Shader;

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
			var openfl_TextureId:ShaderParameter<Float> = defalutShader.data.openfl_TextureId;
			var openfl_Alpha:ShaderParameter<Float> = defalutShader.data.openfl_Alpha_multi;
			var openfl_ColorMultiplier:ShaderParameter<Float> = defalutShader.data.openfl_ColorMultiplier_muti;
			var openfl_ColorOffer:ShaderParameter<Float> = defalutShader.data.openfl_ColorOffset_muti;
			var openfl_HasColorTransform:ShaderParameter<Float> = defalutShader.data.openfl_HasColorTransform_muti;
			var offests:Array<Float> = [];
			var mapIds:Map<BitmapData, Int> = [];
			for (index => data in data.bitmapDatas) {
				mapIds.set(data, index);
				var sampler:ShaderInput<BitmapData> = defalutShader.data.getProperty('uSampler$index');
				sampler.input = data;
				sampler.filter = LINEAR;
			}
			openfl_ColorOffer.value = data.colorOffset;
			openfl_ColorMultiplier.value = data.colorMultiplier;
			openfl_TextureId.value = data.ids;
			openfl_Alpha.value = data.alphas;
			openfl_HasColorTransform.value = data.hasColorTransform;
			shape.graphics.beginShaderFill(defalutShader);
			shape.graphics.drawTriangles(data.vertices, data.indices, data.uvtData);
			shape.graphics.endFill();
			__stage.addChild(shape);
			drawImageBuffDataIndex++;
			createImageBufferData(drawImageBuffDataIndex);
			ContextStats.statsVertexCount(data.indices.length);
			ContextStats.statsDrawCall();
			switch data.blendMode {
				case ADD:
					shape.blendMode = ADD;
				case MULTIPLY:
					shape.blendMode = MULTIPLY;
				case NORMAL:
					shape.blendMode = NORMAL;
				case SCREEN:
					shape.blendMode = SCREEN;
			}
			return shape;
		}
		return null;
	}

	/**
	 * 在OpenFL中渲染的舞台对象
	 */
	@:noCompletion private var __stage:Sprite = new Sprite();

	public var stage(get, never):Sprite;

	private function get_stage():Sprite {
		return __stage;
	}

	private var __pool:ObjectPool<EngineSprite> = new ObjectPool<EngineSprite>(() -> {
		return new EngineSprite();
	}, (sprite) -> {
		sprite.x = 0;
		sprite.y = 0;
		sprite.scrollRect = null;
	});

	/**
	 * 游戏引擎对象
	 */
	// public var engine:Engine;

	/**
	 * 多纹理支持的纹理单元数量
	 */
	public static var supportedMultiTextureUnits:Int = 1;

	public function new() {
		this.__stage.mouseChildren = this.__stage.mouseEnabled = false;
		// 使用多纹理支持
		if (defalutShader == null) {
			var maxCombinedTextureImageUnits:Int = GL.getParameter(GL.MAX_COMBINED_TEXTURE_IMAGE_UNITS);
			var maxTextureImageUnits:Int = GL.getParameter(GL.MAX_TEXTURE_IMAGE_UNITS);
			supportedMultiTextureUnits = Math.floor(Math.min(maxCombinedTextureImageUnits, maxTextureImageUnits));
			defalutShader = new MultiTextureShader(Std.int(Math.min(16, supportedMultiTextureUnits)));
		}
	}

	public function clear():Void {
		// 清理舞台
		for (i in 0...__stage.numChildren) {
			var display = __stage.getChildAt(i);
			if (display is EngineSprite) {
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

	public function renderDisplayObjectContainer(container:DisplayObjectContainer) {
		// 如果存在遮罩时，需要结束掉之前的所有绘制
		if (container.maskRect != null) {
			endFillImageDataBuffer();
		}
		for (object in container.children) {
			if (!object.visible || object.alpha == 0) {
				continue;
			}
			if (object is Image) {
				renderImage(cast object);
			} else if (object is DisplayObjectContainer) {
				renderDisplayObjectContainer(cast object);
			} else if (object is Label) {
				renderLabel(cast object);
			} else if (object is Graphic) {
				renderGraphics(cast object);
			} else if (object is CustomDisplayObject) {
				renderCustomDisplayObject(cast object);
			}
		}
		if (container.maskRect != null) {
			var shape = endFillImageDataBuffer();
			if (shape != null) {
				// 遮罩
				__retRect.setTo(0, 0, 0, 0);
				container.maskRect.transform(__retRect, container.__worldTransform);
				__maskRect.setTo(__retRect.x, __retRect.y, __retRect.width, __retRect.height);
				shape.scrollRect = __maskRect;
				shape.x = __retRect.x;
				shape.y = __retRect.y;
			}
		}
		container.__dirty = false;
	}

	private static var __retRect:hx.gemo.Rectangle = new hx.gemo.Rectangle();

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
		var hm:hx.gemo.Matrix = display.__worldTransform;
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
	public function renderGraphics(graphics:Graphic):Void {
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
