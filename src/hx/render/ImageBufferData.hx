package hx.render;

import lime.utils.UInt16Array;
import hx.utils.ContextStats;
import hx.geom.Matrix3D;
import hx.shader.MultiTextureShader;
import hx.display.DisplayObject;
import hx.display.BlendMode;
import hx.core.OpenFlBitmapData;
import hx.geom.Matrix;
import hx.display.Graphics;
import hx.core.Render;
import openfl.display.BitmapData;
import hx.display.Image;
import openfl.Vector;
import lime.utils.Float32Array;

/**
 * 图片缓存数据
 */
@:access(hx.display.Image)
@:access(hx.display.Graphics)
@:access(hx.geom.Matrix)
class ImageBufferData {
	/**
	 * 索引缓冲区大小
	 */
	public static inline var INDICES_SIZE = 65535;

	/**
	 * 只有1像素的位图
	 */
	public static var px1bitmapData(get, never):hx.display.BitmapData;

	private static var __px1bitmapData:hx.display.BitmapData;

	private static function get_px1bitmapData():hx.display.BitmapData {
		if (__px1bitmapData == null) {
			__px1bitmapData = hx.display.BitmapData.formData(new OpenFlBitmapData(new BitmapData(1, 1, false, 0xffffff)));
		}
		return __px1bitmapData;
	}

	/**
	 * 纹理ID顶点列表
	 */
	public var ids:Array<Float> = [];

	/**
	 * 透明度渲染
	 */
	public var alphas:Array<Float> = [];

	/**
	 * 叠加渲染支持
	 */
	public var addBlendModes:Array<Float> = [];

	/**
	 * 是否包含颜色转换
	 */
	public var hasColorTransform:Array<Float> = [];

	/**
	 * 颜色相乘
	 */
	public var colorMultiplier:Array<Float> = [];

	/**
	 * 颜色偏移
	 */
	public var colorOffset:Array<Float> = [];

	/**
	 * 纹理顶点坐标
	 */
	public var vertices:Vector<Float> = new Vector();

	/**
	 * 纹理顶点索引
	 */
	public var indices:Vector<Int> = new Vector();

	/**
	 * 纹理顶点UV
	 */
	public var uvtData:Vector<Float> = new Vector();

	/**
	 * 待渲染纹理
	 */
	public var bitmapDatas:Array<BitmapData> = [];

	/**
	 * 渲染列表
	 */
	public var drawDisplayList:Array<DisplayObject> = [];

	/**
	 * 纹理ID映射表
	 */
	public var mapIds:Map<BitmapData, Int> = [];

	/**
	 * 平滑
	 */
	public var smoothing:Bool = false;

	/**
	 * 渲染模式
	 */
	public var blendMode:BlendMode = null;

	/**
	 * 数据缓存是否已经损坏
	 */
	public var isBad:Bool = false;

	/**
	 * 数据索引
	 */
	public var index = 0;

	/**
	 * 每个顶点缓冲区所需的数据大小
	 */
	public var perBufferSize(get, never):Int;

	private function get_perBufferSize():Int {
		/**
			attribute float openfl_Alpha_multi;
			attribute vec4 openfl_ColorMultiplier_muti;
			attribute vec4 openfl_ColorOffset_muti;
			attribute vec4 openfl_Position;
			attribute vec2 openfl_TextureCoord;
			attribute float openfl_TextureId;
			attribute float openfl_HasColorTransform_muti;
			attribute float openfl_blendMode_add;

			uniform mat4 openfl_Matrix;
			uniform vec2 openfl_TextureSize;
			uniform float time;

		 */
		return __vertexBufferIndex * perBufferCounts;
	}

	public var vertexCount(get, never):Int;

	private function get_vertexCount():Int {
		return __vertexBufferIndex;
	}

	public var perBufferCounts:Int = 18;

	public var indicesCount(get, never):Int;

	private function get_indicesCount():Int {
		return __indicesBufferIndex;
	}

	// private function get_perBufferCounts():Int {
	// return (1 + 4 + 4 + 4 + 2 + 1 + 1 + 1);
	// }

	/**
	 * 顶点缓冲区
	 */
	public var vertexBuffer(get, never):Float32Array;

	private function get_vertexBuffer():Float32Array {
		return __vertexBuffer;
	}

	/**
	 * 索引缓冲区
	 */
	public var indicesBuffer(get, never):UInt16Array;

	private function get_indicesBuffer():UInt16Array {
		return __indicesBuffer;
	}

	/**
	 * 缓冲区数据
	 */
	private var __vertexBuffer:Float32Array;

	/**
	 * 顶点缓冲区索引
	 */
	private var __vertexBufferIndex = 0;

	/**
	 * 索引缓冲区数据
	 */
	private var __indicesBuffer:UInt16Array = new UInt16Array(INDICES_SIZE);

	/**
	 * 索引缓冲区索引
	 */
	private var __indicesBufferIndex = 0;

	/**
	 * 缓冲区数据大小
	 */
	private var __bufferSize = 0;

	/**
	 * 写入缓冲区数据
	 * @param buffer 缓冲区数据
	 * @param step 顶点缓冲区索引
	 * @param alpha 透明度渲染
	 * @param multiplierR 颜色相乘R
	 * @param multiplierG 颜色相乘G
	 * @param multiplierB 颜色相乘B
	 * @param multiplierA 颜色相乘A
	 * @param colorR 颜色偏移R
	 * @param colorG 颜色偏移G
	 * @param colorB 颜色偏移B
	 * @param colorA 颜色偏移A
	 * @param verticeX 顶点X坐标
	 * @param verticeY 顶点Y坐标
	 * @param textureId 纹理ID
	 * @param hasColorTransform 是否包含颜色转换
	 * @param blendMode 叠加渲染支持
	 * @param u 纹理U坐标
	 * @param v 纹理V坐标
	 */
	public function writeBuffer(step:Int, alpha:Float, multiplierR:Float, multiplierG:Float, multiplierB:Float, multiplierA:Float, colorR:Float, colorG:Float,
			colorB:Float, colorA:Float, verticeX:Float, verticeY:Float, textureId:Float, hasColorTransform:Float, blendMode:Float, u:Float, v:Float):Void {
		if (__vertexBuffer == null) {
			__vertexBuffer = new Float32Array(1024);
		}
		if (step >= __vertexBuffer.length) {
			__vertexBuffer = new Float32Array(step * 2);
		}
		__vertexBuffer[step] = alpha;
		__vertexBuffer[step + 1] = multiplierR;
		__vertexBuffer[step + 2] = multiplierG;
		__vertexBuffer[step + 3] = multiplierB;
		__vertexBuffer[step + 4] = multiplierA;
		__vertexBuffer[step + 5] = colorR;
		__vertexBuffer[step + 6] = colorG;
		__vertexBuffer[step + 7] = colorB;
		__vertexBuffer[step + 8] = colorA;
		__vertexBuffer[step + 9] = verticeX;
		__vertexBuffer[step + 10] = verticeY;
		__vertexBuffer[step + 11] = 0;
		__vertexBuffer[step + 12] = 2;
		__vertexBuffer[step + 13] = u;
		__vertexBuffer[step + 14] = v;
		__vertexBuffer[step + 15] = textureId;
		__vertexBuffer[step + 16] = hasColorTransform;
		__vertexBuffer[step + 17] = blendMode;
	}

	private var dataPerVertex6 = 0;
	private var dataPerVertex24 = 0;
	private var dataPerVertex = 0;
	private var indicesOffset = 0;

	public function new() {}

	public function reset() {
		index = 0;
		dataPerVertex6 = 0;
		dataPerVertex24 = 0;
		dataPerVertex = 0;
		indicesOffset = 0;
		__vertexBufferIndex = 0;
		__indicesBufferIndex = 0;
		setArrayLength(bitmapDatas, 0);
		mapIds.clear();
		isBad = false;
		blendMode = null;
	}

	public function endFill():Void {
		// vertices.length = dataPerVertex;
		// indices.length = dataPerVertex6;
		// setArrayLength(ids, dataPerVertex6);
		// setArrayLength(alphas, dataPerVertex6);
		// setArrayLength(hasColorTransform, dataPerVertex6);
		// setArrayLength(colorMultiplier, dataPerVertex24);
		// setArrayLength(colorOffset, dataPerVertex24);
		setArrayLength(drawDisplayList, index);
		uvtData.length = dataPerVertex;
	}

	private function setArrayLength(array:Array<Dynamic>, length:Int):Void {
		while (array.length > length) {
			array.pop();
		}
	}

	/**
	 * 绘制图形
	 * @param graphic 
	 * @param render 
	 * @return Bool
	 */
	public function drawGraphic(graphic:Graphics, render:Render):Bool {
		var data = graphic.__graphicsDrawData;
		var len = data.draws.length;
		while (graphic.__graphicsDrawData.index < len) {
			var command = data.draws[data.index];
			if (command == null) {
				// 当命令为空时，则意味着渲染已结束
				break;
			}
			switch command {
				case BEGIN_FILL(color):
					data.currentBitmapData = px1bitmapData;
					data.smoothing = true;
				case BEGIN_BITMAP_DATA(bitmapData, smoothing):
					data.currentBitmapData = bitmapData;
					data.smoothing = smoothing;
				case DRAW_TRIANGLE(vertices, indices, uvs, alpha, colorTransform, applyBlendAddMode):
					// 开始绘制三角形
					// 超出限制，则开始下一次绘制
					if (__indicesBufferIndex + 6 >= __indicesBuffer.length) {
						return false;
					}
					if (data.currentBitmapData != null) {
						var texture = data.currentBitmapData.data.getTexture();
						if (index == 0 || !mapIds.exists(texture)) {
							if (bitmapDatas.length >= MultiTextureShader.supportedMultiTextureUnits) {
								return false;
							}
						}
						// 如果平滑值不同，则产生新的绘制
						if (index == 0) {
							smoothing = data.smoothing;
							blendMode = graphic.blendMode;
						} else if (blendMode != graphic.blendMode) {
							if (blendMode == ADD || blendMode == NORMAL) {
								if (graphic.blendMode != ADD && graphic.blendMode != NORMAL) {
									return false;
								}
							} else {
								return false;
							}
						} else if (smoothing != data.smoothing) {
							return false;
						}
						if (!applyBlendAddMode && graphic.blendMode == ADD) {
							applyBlendAddMode = true;
						}
						// 可以绘制，记录纹理ID
						var id = mapIds.get(texture);
						if (id == null) {
							bitmapDatas.push(texture);
							id = bitmapDatas.length - 1;
							mapIds.set(texture, id);
						}
						// 根据顶点设置数据
						for (i in 0...indices.length) {
							__indicesBuffer[__indicesBufferIndex] = indices[i];
							__indicesBufferIndex++;
						}

						// 颜色处理
						var isHasColorTransform = 0;
						var pColorMultiplier:Array<Float> = [];
						var pColorOffset:Array<Float> = [];
						if (colorTransform != null) {
							isHasColorTransform = 1;
							pColorMultiplier[0] = colorTransform.redMultiplier;
							pColorMultiplier[1] = colorTransform.greenMultiplier;
							pColorMultiplier[2] = colorTransform.blueMultiplier;
							pColorMultiplier[3] = colorTransform.alphaMultiplier;
							pColorOffset[0] = colorTransform.redOffset;
							pColorOffset[1] = colorTransform.greenOffset;
							pColorOffset[2] = colorTransform.blueOffset;
							pColorOffset[3] = colorTransform.alphaOffset;
						} else {
							isHasColorTransform = 0;
							pColorMultiplier[0] = 1;
							pColorMultiplier[1] = 1;
							pColorMultiplier[2] = 1;
							pColorMultiplier[3] = 1;
							pColorOffset[0] = 0;
							pColorOffset[1] = 0;
							pColorOffset[2] = 0;
							pColorOffset[3] = 0;
						}
						if (graphic.colorTransform != null) {
							isHasColorTransform = 1;
							pColorMultiplier[0] *= graphic.colorTransform.redMultiplier;
							pColorMultiplier[1] *= graphic.colorTransform.greenMultiplier;
							pColorMultiplier[2] *= graphic.colorTransform.blueMultiplier;
							pColorMultiplier[3] *= graphic.colorTransform.alphaMultiplier;
							pColorOffset[0] += graphic.colorTransform.redOffset;
							pColorOffset[1] += graphic.colorTransform.greenOffset;
							pColorOffset[2] += graphic.colorTransform.blueOffset;
							pColorOffset[3] += graphic.colorTransform.alphaOffset;
						}

						// 顶点坐标
						var tileTransform:Matrix = @:privateAccess graphic.__worldTransform;
						var len = Std.int(vertices.length / 2);
						var blendModeValue = applyBlendAddMode ? 1 : 0;
						for (i in 0...len) {
							var x = vertices[i * 2];
							var y = vertices[i * 2 + 1];
							var step = __vertexBufferIndex * perBufferCounts;
							writeBuffer(step, alpha, pColorMultiplier[0], pColorMultiplier[1], pColorMultiplier[2], pColorMultiplier[3], pColorOffset[0],
								pColorOffset[1], pColorOffset[2], pColorOffset[3], tileTransform.__transformX(x, y), tileTransform.__transformY(x, y), id,
								isHasColorTransform, blendModeValue, uvs[i * 2], uvs[i * 2 + 1]);
							__vertexBufferIndex++;
						}

						dataPerVertex6 += indices.length;
						dataPerVertex24 += indices.length * 4;
						dataPerVertex += vertices.length;
						this.indicesOffset = Std.int(dataPerVertex / 2);
						this.index++;
						// 写入
						drawDisplayList[index] = graphic;
						graphic.__transformDirty = false;
						graphic.__colorTransformDirty = false;
						graphic.__uvsDirty = false;
						this.isBad = true;
					}
			}
			data.index++;
		}
		graphic.__graphicsDrawData.index = 0;
		ContextStats.statsGraphicRenderCount();
		return true;
	}

	/**
	 * 绘制图片
	 * @param image 
	 */
	public function draw(image:Image, render:Render):Bool {
		var texture = image.data.data.getTexture();
		var id = mapIds.get(texture);
		if (id == null && bitmapDatas.length >= MultiTextureShader.supportedMultiTextureUnits) {
			return false;
		}

		// 超出限制，则开始下一次绘制
		if (__indicesBufferIndex + 6 >= __indicesBuffer.length) {
			return false;
		}

		// 如果平滑值不同，则产生新的绘制
		if (index == 0) {
			smoothing = image.smoothing;
			blendMode = image.blendMode;
		} else if (blendMode != image.blendMode) {
			if (blendMode == ADD || blendMode == NORMAL) {
				if (image.blendMode != ADD && image.blendMode != NORMAL) {
					return false;
				}
			} else {
				return false;
			}
		} else if (smoothing != image.smoothing) {
			return false;
		}
		// 可以绘制，记录纹理ID
		if (id == null) {
			bitmapDatas.push(texture);
			id = bitmapDatas.length - 1;
			mapIds.set(texture, id);
		}

		if (!isBad) {
			var displayObject = drawDisplayList[index];
			var isSame = displayObject == image;
			if (!isSame)
				isBad = true;
		}

		var isHasColorTransform = 0;
		var pColorMultiplier:Array<Float> = [];
		var pColorOffset:Array<Float> = [];
		if (image.__colorTransform != null) {
			isHasColorTransform = 1;
			pColorMultiplier[0] = image.__colorTransform.redMultiplier;
			pColorMultiplier[1] = image.__colorTransform.greenMultiplier;
			pColorMultiplier[2] = image.__colorTransform.blueMultiplier;
			pColorMultiplier[3] = image.__colorTransform.alphaMultiplier;
			pColorOffset[0] = image.__colorTransform.redOffset;
			pColorOffset[1] = image.__colorTransform.greenOffset;
			pColorOffset[2] = image.__colorTransform.blueOffset;
			pColorOffset[3] = image.__colorTransform.alphaOffset;
		} else {
			isHasColorTransform = 0;
			pColorMultiplier[0] = 1;
			pColorMultiplier[1] = 1;
			pColorMultiplier[2] = 1;
			pColorMultiplier[3] = 1;
			pColorOffset[0] = 0;
			pColorOffset[1] = 0;
			pColorOffset[2] = 0;
			pColorOffset[3] = 0;
		}

		// 坐标顶点
		var tileWidth:Float = image.data.rect != null ? image.data.rect.width : image.data.data.getWidth();
		var tileHeight:Float = image.data.rect != null ? image.data.rect.height : image.data.data.getHeight();
		var tileTransform = @:privateAccess image.__worldTransform;
		var points = [@:privateAccess
			tileTransform.__transformX(0, 0), @:privateAccess
			tileTransform.__transformY(0, 0), @:privateAccess
			tileTransform.__transformX(tileWidth, 0), @:privateAccess
			tileTransform.__transformY(tileWidth, 0), @:privateAccess
			tileTransform.__transformX(0, tileHeight), @:privateAccess
			tileTransform.__transformY(0, tileHeight), @:privateAccess
			tileTransform.__transformX(tileWidth, tileHeight), @:privateAccess
			tileTransform.__transformY(tileWidth, tileHeight)
		];

		// TODO：3D变化支持
		// var __transformMatrix3D = @:privateAccess image.__transformMatrix3D;
		// if (__transformMatrix3D.transform3D != null) {
		// 	var matrix3D = new Matrix3D();
		// 	matrix3D.identity();
		// 	matrix3D.appendTranslation(-tileTransform.tx, -tileTransform.ty, 0);
		// 	if (__transformMatrix3D.center3DVector != null)
		// 		matrix3D.appendTranslation(-__transformMatrix3D.center3DVector.x, -__transformMatrix3D.center3DVector.y, -__transformMatrix3D.center3DVector.z);
		// 	matrix3D.append(__transformMatrix3D.transform3D);
		// 	// if (__transformMatrix3D.projectionMatrix3D != null) {
		// 	// 	matrix3D.appendTranslation(image.stage.stageWidth / 2, 0, 400);
		// 	// 	matrix3D.append(__transformMatrix3D.projectionMatrix3D);
		// 	// }
		// 	// if (__transformMatrix3D.projectionMatrix3D != null) {
		// 	// matrix3D.appendTranslation(0, 0, 1000);
		// 	// matrix3D.append(__transformMatrix3D.projectionMatrix3D);
		// 	// }
		// 	if (__transformMatrix3D.center3DVector != null)
		// 		matrix3D.appendTranslation(__transformMatrix3D.center3DVector.x, __transformMatrix3D.center3DVector.y, __transformMatrix3D.center3DVector.z);
		// 	matrix3D.appendTranslation(tileTransform.tx, tileTransform.ty, 0);
		// 	// if (__transformMatrix3D.projectionMatrix3D != null) {
		// 	// 	matrix3D.appendTranslation(image.stage.stageWidth / 2, image.stage.stageHeight / 2, 1000);
		// 	// 	matrix3D.append(__transformMatrix3D.projectionMatrix3D);
		// 	// }
		// 	var array = [x, y, 0, x2, y2, 0, x3, y3, 0, x4, y4, 0];
		// 	// var array = [0, 0, tileWidth, 0, 0, tileWidth, tileWidth, tileHeight];
		// 	var projected = [];
		// 	var uvt = [];

		// 	Utils3D.projectVectors2D(matrix3D, array, projected, uvt);
		// 	// trace(projected);
		// 	x = projected[0];
		// 	y = projected[1];
		// 	x2 = projected[2];
		// 	y2 = projected[3];
		// 	x3 = projected[4];
		// 	y3 = projected[5];
		// 	x4 = projected[6];
		// 	y4 = projected[7];
		// 	// x = @:privateAccess tileTransform.__transformX(x, y);
		// 	// y = @:privateAccess tileTransform.__transformY(x, y);
		// 	// x2 = @:privateAccess tileTransform.__transformX(x2, y2);
		// 	// y2 = @:privateAccess tileTransform.__transformY(x2, y2);
		// 	// x3 = @:privateAccess tileTransform.__transformX(x3, y3);
		// 	// y3 = @:privateAccess tileTransform.__transformY(x3, y3);
		// 	// x4 = @:privateAccess tileTransform.__transformX(x4, y4);
		// 	// y4 = @:privateAccess tileTransform.__transformY(x4, y4);
		// }

		__indicesBuffer[__indicesBufferIndex] = (indicesOffset);
		__indicesBuffer[__indicesBufferIndex + 1] = (indicesOffset + 1);
		__indicesBuffer[__indicesBufferIndex + 2] = (indicesOffset + 2);
		__indicesBuffer[__indicesBufferIndex + 3] = (indicesOffset + 1);
		__indicesBuffer[__indicesBufferIndex + 4] = (indicesOffset + 2);
		__indicesBuffer[__indicesBufferIndex + 5] = (indicesOffset + 3);
		__indicesBufferIndex += 6;

		var pUvtData:Array<Float> = [];

		if (image.data.rect != null) {
			var imageWidth = image.data.data.getWidth();
			var imageHeight = image.data.data.getHeight();
			var uvX = image.data.rect.x / imageWidth;
			var uvY = image.data.rect.y / imageHeight;
			var uvW = (image.data.rect.x + image.data.rect.width) / imageWidth;
			var uvH = (image.data.rect.y + image.data.rect.height) / imageHeight;
			pUvtData[0] = (uvX);
			pUvtData[1] = (uvY);
			pUvtData[2] = (uvW);
			pUvtData[3] = (uvY);
			pUvtData[4] = (uvX);
			pUvtData[5] = (uvH);
			pUvtData[6] = (uvW);
			pUvtData[7] = (uvH);
		} else {
			pUvtData[dataPerVertex] = (0);
			pUvtData[dataPerVertex + 1] = (0);
			pUvtData[dataPerVertex + 2] = (1);
			pUvtData[dataPerVertex + 3] = (0);
			pUvtData[dataPerVertex + 4] = (0);
			pUvtData[dataPerVertex + 5] = (1);
			pUvtData[dataPerVertex + 6] = (1);
			pUvtData[dataPerVertex + 7] = (1);
		}

		for (i in 0...4) {
			var step = __vertexBufferIndex * perBufferCounts;
			writeBuffer(step, image.__worldAlpha, pColorMultiplier[0], pColorMultiplier[1], pColorMultiplier[2], pColorMultiplier[3], pColorOffset[0],
				pColorOffset[1], pColorOffset[2], pColorOffset[3], points[i * 2], points[i * 2 + 1], id, isHasColorTransform, image.__addBlendMode,
				pUvtData[i * 2], pUvtData[i * 2 + 1]);
			__vertexBufferIndex++;
		}

		drawDisplayList[index] = image;
		image.__transformDirty = false;
		image.__colorTransformDirty = false;
		image.__uvsDirty = false;
		// 下一个
		index++;
		dataPerVertex6 += 6;
		dataPerVertex24 += 24;
		dataPerVertex += 8;
		indicesOffset += 4;
		return true;
	}
}
