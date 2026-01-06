package hx.filters;

import hx.utils.ContextStats;
import openfl.Lib;
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
	 * 获取当前缓存的位图数据数量
	 */
	public static var counts(get, never):Int;

	private static function get_counts():Int {
		return __pool.length;
	}

	/**
	 * 重置位图数据池
	 */
	public static function resetPool():Void {
		__poolIndex = 0;
	}

	private static var __lastUpdateTime:Float = 0;

	/**
	 * 更新位图数据池，持续6秒，超过6秒未被使用的位图数据会被释放
	 * @param dt 时间间隔
	 */
	public static function update(dt:Float):Void {
		__lastUpdateTime += dt;
		if (ContextStats.blendModeFilterDrawCall > 0)
			__lastUpdateTime = 0;
		if (__lastUpdateTime > 6) {
			disposeAll();
		}
	}

	/**
	 * 释放所有位图数据
	 */
	public static function disposeAll(force:Bool = false):Void {
		if (__pool.length == 0)
			return;
		for (index => bitmapData in __pool) {
			if (bitmapData != null) {
				if (force || index >= __cacheSize)
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
		}
		this.data = __pool[__poolIndex];
		__poolIndex++;
		super.clear();
	}
}
