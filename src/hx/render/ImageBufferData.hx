package hx.render;

import hx.display.DisplayObject;
import hx.display.BlendMode;
import hx.core.OpenFlBitmapData;
import hx.gemo.Matrix;
import hx.display.Graphics;
import hx.core.Render;
import openfl.display.BitmapData;
import hx.display.Image;
import openfl.Vector;

/**
 * 图片缓存数据
 */
@:access(hx.display.Image)
@:access(hx.display.Graphics)
@:access(hx.gemo.Matrix)
class ImageBufferData {
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
		setArrayLength(bitmapDatas, 0);
		mapIds.clear();
		isBad = false;
		blendMode = null;
	}

	public function endFill():Void {
		vertices.length = dataPerVertex;
		indices.length = dataPerVertex6;
		setArrayLength(ids, dataPerVertex6);
		setArrayLength(alphas, dataPerVertex6);
		setArrayLength(hasColorTransform, dataPerVertex6);
		setArrayLength(colorMultiplier, dataPerVertex24);
		setArrayLength(colorOffset, dataPerVertex24);
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
					data.smoothing = false;
				case BEGIN_BITMAP_DATA(bitmapData, smoothing):
					data.currentBitmapData = bitmapData;
					data.smoothing = smoothing;
				case DRAW_TRIANGLE(vertices, indices, uvs, alpha, colorTransform, applyBlendAddMode):
					// 开始绘制三角形
					if (data.currentBitmapData != null) {
						var texture = data.currentBitmapData.data.getTexture();
						if (index == 0 || !mapIds.exists(texture)) {
							if (bitmapDatas.length >= Render.supportedMultiTextureUnits) {
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
							ids[dataPerVertex6 + i] = id;
							alphas[dataPerVertex6 + i] = graphic.__worldAlpha * alpha;
							addBlendModes[dataPerVertex6 + i] = applyBlendAddMode ? 1 : 0;
							if (colorTransform != null) {
								hasColorTransform[dataPerVertex6 + i] = 1;
								colorMultiplier[dataPerVertex24 + i * 4] = colorTransform.redMultiplier;
								colorMultiplier[dataPerVertex24 + i * 4 + 1] = colorTransform.greenMultiplier;
								colorMultiplier[dataPerVertex24 + i * 4 + 2] = colorTransform.blueMultiplier;
								colorMultiplier[dataPerVertex24 + i * 4 + 3] = colorTransform.alphaMultiplier;
								colorOffset[dataPerVertex24 + i * 4] = colorTransform.redOffset;
								colorOffset[dataPerVertex24 + i * 4 + 1] = colorTransform.greenOffset;
								colorOffset[dataPerVertex24 + i * 4 + 2] = colorTransform.blueOffset;
								colorOffset[dataPerVertex24 + i * 4 + 3] = colorTransform.alphaOffset;
								// if (colorTransform != null) {
								// 	colorMultiplier[dataPerVertex24 + i * 4] = graphic.__colorTransform.redMultiplier * colorTransform.redMultiplier;
								// 	colorMultiplier[dataPerVertex24 + i * 4 + 1] = graphic.__colorTransform.greenMultiplier * colorTransform.greenMultiplier;
								// 	colorMultiplier[dataPerVertex24 + i * 4 + 2] = graphic.__colorTransform.blueMultiplier * colorTransform.blueMultiplier;
								// 	colorMultiplier[dataPerVertex24 + i * 4 + 3] = graphic.__colorTransform.alphaMultiplier * colorTransform.alphaMultiplier;
								// 	colorOffset[dataPerVertex24 + i * 4] = graphic.__colorTransform.redOffset + colorTransform.redOffset;
								// 	colorOffset[dataPerVertex24 + i * 4 + 1] = graphic.__colorTransform.greenOffset + colorTransform.greenOffset;
								// 	colorOffset[dataPerVertex24 + i * 4 + 2] = graphic.__colorTransform.blueOffset + colorTransform.blueOffset;
								// 	colorOffset[dataPerVertex24 + i * 4 + 3] = graphic.__colorTransform.alphaOffset + colorTransform.alphaOffset;
								// } else {
								// 	colorMultiplier[dataPerVertex24 + i * 4] = graphic.__colorTransform.redMultiplier;
								// 	colorMultiplier[dataPerVertex24 + i * 4 + 1] = graphic.__colorTransform.greenMultiplier;
								// 	colorMultiplier[dataPerVertex24 + i * 4 + 2] = graphic.__colorTransform.blueMultiplier;
								// 	colorMultiplier[dataPerVertex24 + i * 4 + 3] = graphic.__colorTransform.alphaMultiplier;
								// 	colorOffset[dataPerVertex24 + i * 4] = graphic.__colorTransform.redOffset;
								// 	colorOffset[dataPerVertex24 + i * 4 + 1] = graphic.__colorTransform.greenOffset;
								// 	colorOffset[dataPerVertex24 + i * 4 + 2] = graphic.__colorTransform.blueOffset;
								// 	colorOffset[dataPerVertex24 + i * 4 + 3] = graphic.__colorTransform.alphaOffset;
								// }
							} else {
								hasColorTransform[dataPerVertex6 + i] = 0;
								colorMultiplier[dataPerVertex24 + i * 4] = 1;
								colorMultiplier[dataPerVertex24 + i * 4 + 1] = 1;
								colorMultiplier[dataPerVertex24 + i * 4 + 2] = 1;
								colorMultiplier[dataPerVertex24 + i * 4 + 3] = 1;
								colorOffset[dataPerVertex24 + i * 4] = 0;
								colorOffset[dataPerVertex24 + i * 4 + 1] = 0;
								colorOffset[dataPerVertex24 + i * 4 + 2] = 0;
								colorOffset[dataPerVertex24 + i * 4 + 3] = 0;
							}
							if (graphic.colorTransform != null) {
								hasColorTransform[dataPerVertex6 + i] = 1;
								colorMultiplier[dataPerVertex24 + i * 4] *= graphic.colorTransform.redMultiplier;
								colorMultiplier[dataPerVertex24 + i * 4 + 1] *= graphic.colorTransform.greenMultiplier;
								colorMultiplier[dataPerVertex24 + i * 4 + 2] *= graphic.colorTransform.blueMultiplier;
								colorMultiplier[dataPerVertex24 + i * 4 + 3] *= graphic.colorTransform.alphaMultiplier;
								colorOffset[dataPerVertex24 + i * 4] += graphic.colorTransform.redOffset;
								colorOffset[dataPerVertex24 + i * 4 + 1] += graphic.colorTransform.greenOffset;
								colorOffset[dataPerVertex24 + i * 4 + 2] += graphic.colorTransform.blueOffset;
								colorOffset[dataPerVertex24 + i * 4 + 3] += graphic.colorTransform.alphaOffset;
							}
							this.indices[dataPerVertex6 + i] = indicesOffset + indices[i];
						}

						// 顶点坐标
						var tileTransform:Matrix = @:privateAccess graphic.__worldTransform;
						var len = Std.int(vertices.length / 2);
						for (i in 0...len) {
							var x = vertices[i * 2];
							var y = vertices[i * 2 + 1];
							this.vertices[dataPerVertex + i * 2] = tileTransform.__transformX(x, y);
							this.vertices[dataPerVertex + i * 2 + 1] = tileTransform.__transformY(x, y);
							this.uvtData[dataPerVertex + i * 2] = uvs[i * 2];
							this.uvtData[dataPerVertex + i * 2 + 1] = uvs[i * 2 + 1];
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
		return true;
	}

	/**
	 * 绘制图片
	 * @param image 
	 */
	public function draw(image:Image, render:Render):Bool {
		var texture = image.data.data.getTexture();
		if (index == 0 || !mapIds.exists(texture)) {
			if (bitmapDatas.length >= Render.supportedMultiTextureUnits) {
				return false;
			}
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
		}
		// 可以绘制，记录纹理ID
		var id = mapIds.get(texture);
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
		var isColorDirty = isBad || image.__colorTransformDirty;
		var isTransformDirty = isBad || image.__transformDirty;
		var isUvsDirty = isBad || image.__uvsDirty;

		// if (displayObject != image || image.__transformDirty) {
		// if (isColorDirty) {
		// 6个顶点数据
		for (i in 0...6) {
			ids[dataPerVertex6 + i] = id;
			alphas[dataPerVertex6 + i] = image.__worldAlpha;
			addBlendModes[dataPerVertex6 + i] = image.blendMode == ADD ? 1 : 0;
			if (image.__colorTransform != null) {
				hasColorTransform[dataPerVertex6 + i] = 1;
				colorMultiplier[dataPerVertex24 + i * 4] = image.__colorTransform.redMultiplier;
				colorMultiplier[dataPerVertex24 + i * 4 + 1] = image.__colorTransform.greenMultiplier;
				colorMultiplier[dataPerVertex24 + i * 4 + 2] = image.__colorTransform.blueMultiplier;
				colorMultiplier[dataPerVertex24 + i * 4 + 3] = image.__colorTransform.alphaMultiplier;
				colorOffset[dataPerVertex24 + i * 4] = image.__colorTransform.redOffset;
				colorOffset[dataPerVertex24 + i * 4 + 1] = image.__colorTransform.greenOffset;
				colorOffset[dataPerVertex24 + i * 4 + 2] = image.__colorTransform.blueOffset;
				colorOffset[dataPerVertex24 + i * 4 + 3] = image.__colorTransform.alphaOffset;
			} else {
				hasColorTransform[dataPerVertex6 + i] = 0;
				colorMultiplier[dataPerVertex24 + i * 4] = 1;
				colorMultiplier[dataPerVertex24 + i * 4 + 1] = 1;
				colorMultiplier[dataPerVertex24 + i * 4 + 2] = 1;
				colorMultiplier[dataPerVertex24 + i * 4 + 3] = 1;
				colorOffset[dataPerVertex24 + i * 4] = 0;
				colorOffset[dataPerVertex24 + i * 4 + 1] = 0;
				colorOffset[dataPerVertex24 + i * 4 + 2] = 0;
				colorOffset[dataPerVertex24 + i * 4 + 3] = 0;
			}
		}
		// }

		// if (isTransformDirty) {
		// 坐标顶点
		var tileWidth:Float = image.data.rect != null ? image.data.rect.width : image.data.data.getWidth();
		var tileHeight:Float = image.data.rect != null ? image.data.rect.height : image.data.data.getHeight();
		var tileTransform = @:privateAccess image.__worldTransform;
		var x = @:privateAccess tileTransform.__transformX(0, 0);
		var y = @:privateAccess tileTransform.__transformY(0, 0);
		var x2 = @:privateAccess tileTransform.__transformX(tileWidth, 0);
		var y2 = @:privateAccess tileTransform.__transformY(tileWidth, 0);
		var x3 = @:privateAccess tileTransform.__transformX(0, tileHeight);
		var y3 = @:privateAccess tileTransform.__transformY(0, tileHeight);
		var x4 = @:privateAccess tileTransform.__transformX(tileWidth, tileHeight);
		var y4 = @:privateAccess tileTransform.__transformY(tileWidth, tileHeight);
		vertices[dataPerVertex] = x;
		vertices[dataPerVertex + 1] = y;
		vertices[dataPerVertex + 2] = (x2);
		vertices[dataPerVertex + 3] = (y2);
		vertices[dataPerVertex + 4] = (x3);
		vertices[dataPerVertex + 5] = (y3);
		vertices[dataPerVertex + 6] = (x4);
		vertices[dataPerVertex + 7] = (y4);

		// 顶点
		indices[dataPerVertex6] = (indicesOffset);
		indices[dataPerVertex6 + 1] = (indicesOffset + 1);
		indices[dataPerVertex6 + 2] = (indicesOffset + 2);
		indices[dataPerVertex6 + 3] = (indicesOffset + 1);
		indices[dataPerVertex6 + 4] = (indicesOffset + 2);
		indices[dataPerVertex6 + 5] = (indicesOffset + 3);
		// }

		// UVs
		if (isUvsDirty) {
			if (image.data.rect != null) {
				var imageWidth = image.data.data.getWidth();
				var imageHeight = image.data.data.getHeight();
				var uvX = image.data.rect.x / imageWidth;
				var uvY = image.data.rect.y / imageHeight;
				var uvW = (image.data.rect.x + image.data.rect.width) / imageWidth;
				var uvH = (image.data.rect.y + image.data.rect.height) / imageHeight;
				uvtData[dataPerVertex] = (uvX);
				uvtData[dataPerVertex + 1] = (uvY);
				uvtData[dataPerVertex + 2] = (uvW);
				uvtData[dataPerVertex + 3] = (uvY);
				uvtData[dataPerVertex + 4] = (uvX);
				uvtData[dataPerVertex + 5] = (uvH);
				uvtData[dataPerVertex + 6] = (uvW);
				uvtData[dataPerVertex + 7] = (uvH);
			} else {
				uvtData[dataPerVertex] = (0);
				uvtData[dataPerVertex + 1] = (0);
				uvtData[dataPerVertex + 2] = (1);
				uvtData[dataPerVertex + 3] = (0);
				uvtData[dataPerVertex + 4] = (0);
				uvtData[dataPerVertex + 5] = (1);
				uvtData[dataPerVertex + 6] = (1);
				uvtData[dataPerVertex + 7] = (1);
			}
		}
		// }
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
