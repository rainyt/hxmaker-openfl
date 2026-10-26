package hx.filters;

import openfl.Lib;
import hx.core.OpenFlBitmapData;
import hx.display.IBitmapData;
import hx.display.BitmapData;
import hx.display.Quad;
import hx.geom.Matrix;

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
		// 缓存好了之后，进行一次简易的绘制进行激活
		var quad = new Quad(10, 10, 0xff0000);
		for (i in 0...size) {
			if (__pool[i] == null) {
				__pool[i] = OpenFlBitmapData.fromSize(Std.int(hx.core.Hxmaker.engine.stageWidth), Std.int(hx.core.Hxmaker.engine.stageHeight), true, 0x0).data;
				__pool[i].clear();
				__pool[i].draw(quad, new Matrix());
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
	 * 每六秒回收闲置尾部；上次渲染占用的前缀在画面静止时仍被显示树引用。
	 * @param dt 时间间隔
	 */
	public static function update(dt:Float):Void {
		__lastUpdateTime += dt;
		if (__lastUpdateTime > 6) {
			disposeAll();
		}
	}

	/**
	 * 普通回收保留当前画面和预设缓存；强制释放必须在旧批次拆除后调用。
	 */
	public static function disposeAll(force:Bool = false):Void {
		var keepCount:Int = force ? 0 : Std.int(Math.min(__pool.length, Math.max(__cacheSize, __poolIndex)));
		for (index in keepCount...__pool.length) {
			var bitmapData:IBitmapData = __pool[index];
			if (bitmapData != null) bitmapData.dispose();
		}
		__pool.resize(keepCount);
		if (force) __poolIndex = 0;
		__lastUpdateTime = 0;
	}

	/** 恢复后丢弃全部失效目标；保留池容量配置，实际目标在下次 clear 时创建。 */
	public static function onContextRestored():Void {
		for (bitmap in __pool) if (bitmap != null) bitmap.dispose();
		__pool = []; __poolIndex = 0; __lastUpdateTime = 0;
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
