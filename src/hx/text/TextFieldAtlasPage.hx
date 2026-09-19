package hx.text;

import hx.core.OpenFlBitmapData;
import openfl.display.BitmapData;

/**
 * 文本图集的单页纹理。
 *
 * 一页 = 一张纹理 + 一个`MaxRectsBinPack`打包器。
 * 页一旦创建，除非客户端显式清理，内部永不擦除、永不重排，
 * 因此写入本页的字形、以及引用它的已入队顶点在任何时刻都保持有效。
 *
 * 这是"溢出不再擦除整张图集"的载体：写满时只把本页标记为满并另开一页，
 * 已经使用过的矩形永远不会被后来的字形覆盖，文字串字的问题从机制上消失。
 */
class TextFieldAtlasPage {
	/**
	 * 底层纹理，会被`ImageBufferData`当作一个独立的纹理单元参与批次
	 */
	public var bitmapData:BitmapData;

	/**
	 * 裁剪视图根，字形通过它的`sub()`生成子位图
	 */
	public var view:hx.display.BitmapData;

	/**
	 * 本页专属的打包器，容量与本页纹理严格一致
	 */
	public var rects:MaxRectsBinPack;

	/**
	 * 页索引，仅用于调试与统计
	 */
	public var index:Int = 0;

	/**
	 * 本页是否已经放不下新的字形
	 */
	public var full:Bool = false;

	public function new(bitmapData:BitmapData, index:Int = 0) {
		this.bitmapData = bitmapData;
		this.index = index;
		this.view = hx.display.BitmapData.formData(new OpenFlBitmapData(bitmapData));
		this.rects = new MaxRectsBinPack(bitmapData.width, bitmapData.height, false);
	}

	/**
	 * 本页是否从未写入过任何字形，用于识别"字形本身就大于整页"的情况
	 */
	public var isEmpty(get, never):Bool;

	private function get_isEmpty():Bool {
		return rects.usedRectangles.length == 0;
	}

	/**
	 * 释放本页占用的显存
	 */
	public function dispose():Void {
		bitmapData.dispose();
	}
}
