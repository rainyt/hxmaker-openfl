package hx.render;

import hx.core.Render;
import openfl.display.BitmapData;
import hx.displays.Image;
import openfl.Vector;

/**
 * 图片缓存数据
 */
@:access(hx.displays.Image)
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

	public function new() {}

	public function reset() {
		index = 0;
		bitmapDatas = [];
		mapIds = [];
		indices = new Vector();
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
		var dataPerVertex6 = index * 6;
		var dataPerVertex24 = index * 24;
		for (i in 0...6) {
			ids[dataPerVertex6 + i] = id;
			alphas[dataPerVertex6 + i] = image.__worldAlpha;
			colorMultiplier[dataPerVertex24 + i * 4] = 1;
			colorMultiplier[dataPerVertex24 + i * 4 + 1] = 1;
			colorMultiplier[dataPerVertex24 + i * 4 + 2] = 1;
			colorMultiplier[dataPerVertex24 + i * 4 + 3] = 1;
			colorOffset[dataPerVertex24 + i * 4] = 0;
			colorOffset[dataPerVertex24 + i * 4 + 1] = 0;
			colorOffset[dataPerVertex24 + i * 4 + 2] = 0;
			colorOffset[dataPerVertex24 + i * 4 + 3] = 0;
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
		var dataPerVertex = index * 8;
		vertices[dataPerVertex] = x;
		vertices[dataPerVertex + 1] = y;
		vertices[dataPerVertex + 2] = (x2);
		vertices[dataPerVertex + 3] = (y2);
		vertices[dataPerVertex + 4] = (x3);
		vertices[dataPerVertex + 5] = (y3);
		vertices[dataPerVertex + 6] = (x4);
		vertices[dataPerVertex + 7] = (y4);

		// 顶点
		var indicesOffset = index * 4;
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
		return true;
	}
}
