package hx.core;

import hx.render.TextFieldRender;
import hx.render.ImageBufferData;
import hx.render.ImageRender;
import openfl.display.ShaderInput;
import openfl.display.BitmapData;
import openfl.display.ShaderParameter;
import lime.graphics.opengl.GL;
import openfl.display.Shader;
import hx.displays.DisplayObject;
import openfl.geom.Matrix;
import hx.displays.Quad;
import openfl.text.TextFormat;
import hx.displays.Label;
import openfl.utils.ObjectPool;
import hx.displays.Image;
import hx.displays.DisplayObjectContainer;
import openfl.display.Sprite;
import hx.displays.IRender;

using Reflect;

/**
 * OpenFL的渲染器支持
 */
@:access(hx.displays.DisplayObject)
@:access(openfl.geom.Matrix)
class Render implements IRender {
	/**
	 * 默认的着色器支持
	 */
	public var defalutShader:Shader;

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
	public function renderImageBuffData(data:ImageBufferData):Void {
		if (data.index > 0) {
			// 图形绘制
			var shape:Sprite = __pool.get();
			shape.graphics.clear();
			var openfl_TextureId:ShaderParameter<Float> = defalutShader.data.openfl_TextureId;
			var openfl_Alpha:ShaderParameter<Float> = defalutShader.data.openfl_Alpha_multi;
			var openfl_ColorMultiplier:ShaderParameter<Float> = defalutShader.data.openfl_ColorMultiplier_muti;
			var openfl_ColorOffer:ShaderParameter<Float> = defalutShader.data.openfl_ColorOffset_muti;
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
			shape.graphics.beginShaderFill(defalutShader);
			shape.graphics.drawTriangles(data.vertices, data.indices, data.uvtData);
			shape.graphics.endFill();
			__stage.addChild(shape);
			drawImageBuffDataIndex++;
			createImageBufferData(drawImageBuffDataIndex);
		}
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
	});

	/**
	 * 游戏引擎对象
	 */
	public var engine:Engine;

	/**
	 * 多纹理支持的纹理单元数量
	 */
	public var supportedMultiTextureUnits:Int = 1;

	public function new(engine:Engine) {
		this.__stage.mouseChildren = this.__stage.mouseEnabled = false;
		this.engine = engine;
		this.engine.addChild(__stage);
		#if cpp
		engine.stage.frameRate = 61;
		#else
		engine.stage.frameRate = 60;
		#end
		// 使用多纹理支持
		var maxCombinedTextureImageUnits:Int = GL.getParameter(GL.MAX_COMBINED_TEXTURE_IMAGE_UNITS);
		var maxTextureImageUnits:Int = GL.getParameter(GL.MAX_TEXTURE_IMAGE_UNITS);
		supportedMultiTextureUnits = Math.floor(Math.min(maxCombinedTextureImageUnits, maxTextureImageUnits));
		defalutShader = new MultiTextureShader(supportedMultiTextureUnits);
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
			} else if (object is Quad) {
				renderQuad(cast object);
			}
		}
		container.__dirty = false;
	}

	public function renderImage(image:Image):Void {
		ImageRender.render(image, this);
	}

	/**
	 * 渲染矩阵
	 * @param quad 
	 */
	public function renderQuad(quad:Quad):Void {
		if (quad.root == null) {
			quad.root = new Sprite();
			quad.setDirty();
		}
		var sprite:Sprite = quad.root;
		sprite.graphics.clear();
		sprite.graphics.beginFill(quad.data);
		sprite.graphics.drawRect(0, 0, quad.width, quad.height);
		sprite.transform.matrix = getMarix(quad);
		sprite.alpha = quad.__worldAlpha;
		endFillImageDataBuffer();
		__stage.addChild(sprite);
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
	public function renderLabel(label:Label):Void {
		TextFieldRender.render(label, this);
		// if (label.root == null) {
		// 	label.root = new EngineTextField();
		// 	label.setDirty();
		// }
		// var textField:EngineTextField = cast label.root;
		// if (label.data != null && textField.text != label.data) {
		// 	textField.text = label.data;
		// 	var format:hx.displays.TextFormat = label.__textFormat;
		// 	textField.setTextFormat(new TextFormat(format.font, format.size, format.color));
		// 	label.updateAlignTranform();
		// 	label.__updateTransform(label.parent);
		// 	var context = EngineTextField.getTextFieldContextBitmapData();
		// 	context.drawText(textField.text);
		// }
		// textField.alpha = label.__worldAlpha;
		// textField.transform.matrix = getMarix(label);
		// textField.width = label.width;
		// textField.height = label.height;
		// label.__dirty = false;
		// // 不直接渲染文本，使用位图渲染方式
		// // textField.render(this, label);
		// this.endFillImageDataBuffer();
		// __stage.addChild(textField);
	}

	public function endFillImageDataBuffer():Void {
		this.renderImageBuffData(this.imageBufferData[this.drawImageBuffDataIndex]);
	}

	/**
	 * 结束所有绘制调用
	 */
	public function endFill():Void {
		this.renderImageBuffData(this.imageBufferData[this.drawImageBuffDataIndex]);
		this.imageBufferData = this.imageBufferData.splice(0, this.drawImageBuffDataIndex + 1);
	}
}
