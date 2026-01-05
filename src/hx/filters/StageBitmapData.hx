package hx.filters;

import hx.core.OpenFlBitmapData;
import hx.display.IBitmapData;
import hx.display.BitmapData;

/**
 * 舞台位图数据，它们之间会进行共享，以便提高性能
 */
class StageBitmapData extends BitmapData {
	private static var __pool:Array<IBitmapData> = [];
	private static var __poolIndex:Int = 0;
	private static var __cacheSize:Int = 0;

	/**
	 * 缓存位图数据池的数量
	 * @param size 
	 */
	public static function cacheSize(size:Int):Void {
		__cacheSize = size;
		for (i in 0...size) {
			if (__pool[i] == null) {
				__pool[i] = OpenFlBitmapData.fromSize(Std.int(hx.core.Hxmaker.engine.stageWidth), Std.int(hx.core.Hxmaker.engine.stageHeight), true, 0x0).data;
			}
		}
	}

	/**
	 * 重置位图数据池
	 */
	public static function resetPool():Void {
		__poolIndex = 0;
	}

	/**
	 * 释放所有位图数据
	 */
	public static function disposeAll():Void {
		for (bitmapData in __pool) {
			if (bitmapData != null) {
				bitmapData.dispose();
			}
		}
		__pool = [];
		__poolIndex = 0;
	}

	public function new() {
		super();
	}

	override function clear() {
		if (__pool[__poolIndex] == null) {
			__pool[__poolIndex] = OpenFlBitmapData.fromSize(Std.int(hx.core.Hxmaker.engine.stageWidth), Std.int(hx.core.Hxmaker.engine.stageHeight), true, 0x0)
				.data;
			trace("create new stage bitmap data pool item: " + __poolIndex);
		}
		this.data = __pool[__poolIndex];
		__poolIndex++;
		super.clear();
	}
}
