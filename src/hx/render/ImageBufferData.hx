package hx.render;

import hx.gemo.Matrix;
import hx.displays.Graphic;
import hx.core.Render;
import openfl.display.BitmapData;
import hx.displays.Image;
import openfl.Vector;

/**
 * 图片缓存数据
 */
@:access(hx.displays.Image)
@:access(hx.displays.Graphic)
@:access(hx.gemo.Matrix)
class ImageBufferData {
	/**
	 * 纹理ID顶点列表
	 */
	public var ids:Array<Float> = [];

	/**
	 * 透明度渲染
	 */
	public var alphas:Array<Float> = [];

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
	 * 纹理ID映射表
	 */
	public var mapIds:Map<BitmapData, Int> = [];

	/**
	 * 平滑
	 */
	public var smoothing:Bool = false;

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
		bitmapDatas = [];
		mapIds = [];
		indices = new Vector();
	}

	/**
	 * 绘制图形
	 * @param graphic 
	 * @param render 
	 * @return Bool
	 */
	public function drawGraphic(graphic:Graphic, render:Render):Bool {
		var data = graphic.__graphicDrawData;
		var len = data.draws.length;
		while (graphic.__graphicDrawData.index < len) {
			var command = data.draws[data.index];
			if (command == null) {
				// 当命令为空时，则意味着渲染已结束
				break;
			}
			switch command {
				case BEGIN_BITMAP_DATA(bitmapData, smoothing):
					data.currentBitmapData = bitmapData;
					data.smoothing = smoothing;
				case DRAW_TRIANGLE(vertices, indices, uvs, alpha, colorTransform):
					// 开始绘制三角形
					var texture = data.currentBitmapData.data.getTexture();
					if (index == 0 || !mapIds.exists(texture)) {
						if (bitmapDatas.length >= render.supportedMultiTextureUnits) {
							return false;
						}
					}
					// 如果平滑值不同，则产生新的绘制
					if (index == 0) {
						smoothing = data.smoothing;
					} else if (smoothing != data.smoothing) {
						return false;
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
						colorMultiplier[dataPerVertex24 + i * 4] = graphic.__colorTransform.redMultiplier;
						colorMultiplier[dataPerVertex24 + i * 4 + 1] = graphic.__colorTransform.greenMultiplier;
						colorMultiplier[dataPerVertex24 + i * 4 + 2] = graphic.__colorTransform.blueMultiplier;
						colorMultiplier[dataPerVertex24 + i * 4 + 3] = graphic.__colorTransform.alphaMultiplier;
						colorOffset[dataPerVertex24 + i * 4] = graphic.__colorTransform.redOffset;
						colorOffset[dataPerVertex24 + i * 4 + 1] = graphic.__colorTransform.greenOffset;
						colorOffset[dataPerVertex24 + i * 4 + 2] = graphic.__colorTransform.blueOffset;
						colorOffset[dataPerVertex24 + i * 4 + 3] = graphic.__colorTransform.alphaOffset;
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
			}
			data.index++;
		}
		graphic.__graphicDrawData.index = 0;
		return true;
	}

	/**
	 * 绘制图片
	 * @param image 
	 */
	public function draw(image:Image, render:Render):Bool {
		var texture = image.data.data.getTexture();
		if (index == 0 || !mapIds.exists(texture)) {
			if (bitmapDatas.length >= render.supportedMultiTextureUnits) {
				return false;
			}
		}
		// 如果平滑值不同，则产生新的绘制
		if (index == 0) {
			smoothing = image.smoothing;
		} else if (smoothing != image.smoothing) {
			return false;
		}
		// 可以绘制，记录纹理ID
		var id = mapIds.get(texture);
		if (id == null) {
			bitmapDatas.push(texture);
			id = bitmapDatas.length - 1;
			mapIds.set(texture, id);
		}

		// 6个顶点数据
		for (i in 0...6) {
			ids[dataPerVertex6 + i] = id;
			alphas[dataPerVertex6 + i] = image.__worldAlpha;
			colorMultiplier[dataPerVertex24 + i * 4] = image.__colorTransform.redMultiplier;
			colorMultiplier[dataPerVertex24 + i * 4 + 1] = image.__colorTransform.greenMultiplier;
			colorMultiplier[dataPerVertex24 + i * 4 + 2] = image.__colorTransform.blueMultiplier;
			colorMultiplier[dataPerVertex24 + i * 4 + 3] = image.__colorTransform.alphaMultiplier;
			colorOffset[dataPerVertex24 + i * 4] = image.__colorTransform.redOffset;
			colorOffset[dataPerVertex24 + i * 4 + 1] = image.__colorTransform.greenOffset;
			colorOffset[dataPerVertex24 + i * 4 + 2] = image.__colorTransform.blueOffset;
			colorOffset[dataPerVertex24 + i * 4 + 3] = image.__colorTransform.alphaOffset;
		}

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

		// UVs
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

		// 下一个
		index++;
		dataPerVertex6 += 6;
		dataPerVertex24 += 24;
		dataPerVertex += 8;
		indicesOffset += 4;
		return true;
	}
}
