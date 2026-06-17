package hx.net;

import haxe.io.Bytes;
import haxe.Timer;
import hx.display.BitmapData;
import hx.assets.Sound;
import hx.events.FutureErrorEvent;
import hx.utils.ContextStats;

/**
 * 请求队列
 * 支持并发控制、资源缓存与引用计数
 */
class RequestQueue {
	/**
	 * 最大并发请求数量
	 */
	public static var MAX_REQUEST_COUNT:Int = 10;

	/**
	 * 当前请求数量
	 */
	private static var CURRENT_REQUEST_COUNT:Int = 0;

	/**
	 * 请求队列
	 */
	private static var __requestQueue:Array<BaseRequest<Dynamic>> = [];

	// ---------------------------------------------------------------------------
	// 缓存与引用计数
	// ---------------------------------------------------------------------------

	/**
	 * 是否启用缓存，默认启用
	 */
	public static var enableCache:Bool = true;

	/**
	 * 资源释放延迟时间（秒）
	 * 当引用计数归零后，延迟此时间才真正释放资源。
	 * 在延迟期间若资源被重新请求，则取消释放并恢复引用计数。
	 * 默认60秒。
	 */
	public static var RELEASE_DELAY:Float = 60;

	/**
	 * 资源缓存表，以URL为键
	 */
	private static var __cache:Map<String, CacheEntry> = [];

	/**
	 * 上次懒清理时间戳，用于节流
	 */
	private static var __lastSweepTime:Float = 0;

	// ---------------------------------------------------------------------------
	// 加载方法
	// ---------------------------------------------------------------------------

	/**
	 * 加载字符串
	 */
	public static function loadString(url:String, cb:String->FutureErrorEvent->Void):Void {
		if (enableCache) {
			lazySweep();
			var entry = ensureCacheEntry(url, cb);
			if (entry == null)
				return; // 缓存命中或等待中，已处理

			var wrappedCb:String->FutureErrorEvent->Void = function(data, err) {
				resolveCacheEntry(url, entry, data, err);
				cb(data, err);
			};
			var request = new StringRequest(url, wrappedCb);
			__requestQueue.push(request);
			if (CURRENT_REQUEST_COUNT >= MAX_REQUEST_COUNT)
				return;
			loadNext();
			return;
		}

		// 缓存未启用，保持原始行为
		var request = new StringRequest(url, cb);
		__requestQueue.push(request);
		if (CURRENT_REQUEST_COUNT >= MAX_REQUEST_COUNT)
			return;
		loadNext();
	}

	/**
	 * 加载声音
	 */
	public static function loadSound(url:String, cb:Sound->FutureErrorEvent->Void, isMusic:Bool = false):Void {
		if (enableCache) {
			lazySweep();
			var entry = ensureCacheEntry(url, cb);
			if (entry == null)
				return;

			var wrappedCb:Sound->FutureErrorEvent->Void = function(data, err) {
				resolveCacheEntry(url, entry, data, err);
				cb(data, err);
			};
			var request = new SoundRequest(url, wrappedCb);
			request.isMusic = isMusic;
			__requestQueue.push(request);
			if (CURRENT_REQUEST_COUNT >= MAX_REQUEST_COUNT)
				return;
			loadNext();
			return;
		}

		var request = new SoundRequest(url, cb);
		request.isMusic = isMusic;
		__requestQueue.push(request);
		if (CURRENT_REQUEST_COUNT >= MAX_REQUEST_COUNT)
			return;
		loadNext();
	}

	/**
	 * 加载图片
	 */
	public static function loadBitmapData(url:String, cb:BitmapData->FutureErrorEvent->Void):Void {
		if (enableCache) {
			lazySweep();
			var entry = ensureCacheEntry(url, cb);
			if (entry == null)
				return;

			var wrappedCb:BitmapData->FutureErrorEvent->Void = function(data, err) {
				resolveCacheEntry(url, entry, data, err);
				cb(data, err);
			};
			var request = new BitmapDataRequest(url, wrappedCb);
			__requestQueue.push(request);
			if (CURRENT_REQUEST_COUNT >= MAX_REQUEST_COUNT)
				return;
			loadNext();
			return;
		}

		var request = new BitmapDataRequest(url, cb);
		__requestQueue.push(request);
		if (CURRENT_REQUEST_COUNT >= MAX_REQUEST_COUNT)
			return;
		loadNext();
	}

	/**
	 * 加载字节
	 */
	public static function loadBytes(url:String, cb:Bytes->FutureErrorEvent->Void):Void {
		if (enableCache) {
			lazySweep();
			var entry = ensureCacheEntry(url, cb);
			if (entry == null)
				return;

			var wrappedCb:Bytes->FutureErrorEvent->Void = function(data, err) {
				resolveCacheEntry(url, entry, data, err);
				cb(data, err);
			};
			var request = new BytesRequest(url, wrappedCb);
			__requestQueue.push(request);
			if (CURRENT_REQUEST_COUNT >= MAX_REQUEST_COUNT)
				return;
			loadNext();
			return;
		}

		var request = new BytesRequest(url, cb);
		__requestQueue.push(request);
		if (CURRENT_REQUEST_COUNT >= MAX_REQUEST_COUNT)
			return;
		loadNext();
	}

	// ---------------------------------------------------------------------------
	// 队列控制
	// ---------------------------------------------------------------------------

	private static function loadNext():Void {
		if (__requestQueue.length == 0) {
			return;
		}
		var request = __requestQueue.shift();
		request.request();
		CURRENT_REQUEST_COUNT++;
	}

	public static function loadComplete():Void {
		CURRENT_REQUEST_COUNT--;
		loadNext();
	}

	// ---------------------------------------------------------------------------
	// 引用计数 API（供前端调用）
	// ---------------------------------------------------------------------------

	/**
	 * 保留资源（增加引用计数）
	 * 通常在手动获取缓存资源时调用，普通加载流程会自动计数
	 * @param url 资源URL
	 * @return 当前引用计数，若资源不存在则返回0
	 */
	public static function retain(url:String):Int {
		var entry = __cache.get(url);
		if (entry == null)
			return 0;
		entry.refCount++;
		syncContextStats();
		#if assets_debug
		trace("[RequestQueue] Retain resource: " + url + ", new refCount: " + entry.refCount);
		#end
		return entry.refCount;
	}

	/**
	 * 释放资源（减少引用计数）
	 * 前端释放资源时调用。当引用计数归零时，不会立即释放，
	 * 而是启动延迟计时，在 RELEASE_DELAY 秒后若仍为0才真正释放。
	 * 延迟期间若资源被重新请求，将取消释放并恢复引用。
	 * @param url 资源URL
	 * @return 当前引用计数，归零后返回0
	 */
	public static function release(url:String):Int {
		if (url == null) {
			return 0;
		}
		var entry = __cache.get(url);
		if (entry == null)
			return 0;
		entry.refCount--;
		if (url.indexOf("postman") != -1) {
			trace("why");
		}
		#if assets_debug
		trace("[RequestQueue] Release resource: " + url + ", new refCount: " + entry.refCount);
		#end
		if (entry.refCount <= 0) {
			entry.refCount = 0;
			entry.releaseTimestamp = Timer.stamp() + RELEASE_DELAY;
			syncContextStats();
			return 0;
		}
		syncContextStats();
		return entry.refCount;
	}

	/**
	 * 查询资源的引用计数
	 * @param url 资源URL
	 * @return 引用计数，不存在则返回-1
	 */
	public static function getRefCount(url:String):Int {
		var entry = __cache.get(url);
		if (entry == null)
			return -1;
		return entry.refCount;
	}

	/**
	 * 获取所有缓存资源的总引用计数
	 * 供调试显示使用（如 FPS 面板）
	 * @return 总引用计数
	 */
	public static function getTotalRefCount():Int {
		var total = 0;
		for (entry in __cache) {
			if (entry.refCount > 0)
				total += entry.refCount;
		}
		return total;
	}

	/**
	 * 输出所有资源的引用计数信息
	 * 在 assets_debug 模式下自动 trace 输出
	 * @return 包含 {url:String, refCount:Int, pendingRelease:Bool, remainSeconds:Float} 的数组
	 */
	public static function dumpRefCounts():Array<{
		url:String,
		refCount:Int,
		pendingRelease:Bool,
		remainSeconds:Float
	}> {
		var result:Array<{
			url:String,
			refCount:Int,
			pendingRelease:Bool,
			remainSeconds:Float
		}> = [];
		var now = Timer.stamp();
		for (url => entry in __cache) {
			var pending = entry.releaseTimestamp > 0 && entry.refCount <= 0;
			var remain = pending ? entry.releaseTimestamp - now : 0;
			result.push({
				url: url,
				refCount: entry.refCount,
				pendingRelease: pending,
				remainSeconds: remain
			});
		}
		trace("========== 资源引用计数 ==========");
		trace("总计缓存条目: " + result.length);
		for (item in result) {
			if (item.pendingRelease) {
				trace('  ${item.url} -> refCount: ${item.refCount} [待释放, 剩余 ${Math.ceil(item.remainSeconds)}秒]');
			} else {
				trace('  ${item.url} -> refCount: ${item.refCount}');
			}
		}
		trace("==================================");
		return result;
	}

	// ---------------------------------------------------------------------------
	// 缓存管理 API
	// ---------------------------------------------------------------------------

	/**
	 * 检查指定URL是否已缓存
	 * @param url 资源URL
	 * @return 是否已缓存（加载完成且数据有效）
	 */
	public static function hasCache(url:String):Bool {
		var entry = __cache.get(url);
		return entry != null && entry.data != null;
	}

	/**
	 * 清理所有已过期的延迟释放资源
	 * 检查所有引用计数为0且延迟时间已到的条目，执行真正的资源释放。
	 * 通常在每帧或场景切换时调用。也会被加载方法自动触发懒清理。
	 * @return 本次清理的条目数量
	 */
	public static function sweepCache():Int {
		var count = 0;
		var now = Timer.stamp();
		for (url => entry in __cache) {
			if (entry.releaseTimestamp > 0 && now >= entry.releaseTimestamp && entry.refCount <= 0) {
				disposeResource(entry.data);
				__cache.remove(url);
				count++;
			}
		}
		if (count > 0)
			syncContextStats();
		return count;
	}

	/**
	 * 强制移除缓存（不检查引用计数，立即释放）
	 * @param url 资源URL
	 */
	public static function removeCache(url:String):Void {
		var entry = __cache.get(url);
		if (entry != null) {
			disposeResource(entry.data);
			__cache.remove(url);
			syncContextStats();
		}
	}

	/**
	 * 清空所有缓存
	 */
	public static function clearCache():Void {
		for (entry in __cache) {
			disposeResource(entry.data);
		}
		__cache = [];
		syncContextStats();
	}

	// ---------------------------------------------------------------------------
	// 内部方法
	// ---------------------------------------------------------------------------

	/**
	 * 懒清理：按固定间隔检查并释放过期资源
	 * 间隔为 RELEASE_DELAY 的 1/6，确保不会遗漏
	 */
	private static function lazySweep():Void {
		var now = Timer.stamp();
		var interval = RELEASE_DELAY / 6;
		if (now - __lastSweepTime >= interval) {
			__lastSweepTime = now;
			sweepCache();
		}
	}

	/**
	 * 同步总引用计数到 ContextStats，供 FPS 等调试面板使用
	 */
	private static function syncContextStats():Void {
		var totalRef = 0;
		var totalCache = 0;
		for (entry in __cache) {
			if (entry.data != null) {
				totalCache++;
			}
			if (entry.refCount > 0) {
				totalRef += entry.refCount;
			}
		}
		ContextStats.totalRefCount = totalRef;
		ContextStats.totalCacheCount = totalCache;
	}

	/**
	 * 确保缓存条目存在并处理缓存命中/去重逻辑
	 * 返回非null表示需要发起新请求，返回null表示已处理（缓存命中或加入等待）
	 */
	private static function ensureCacheEntry(url:String, cb:Dynamic):CacheEntry {
		var entry = __cache.get(url);

		if (entry != null) {
			// 缓存命中：数据已就绪，直接回调
			if (entry.data != null) {
				// entry.refCount++;
				// 如果在延迟释放期间被重新请求，取消延迟释放
				entry.releaseTimestamp = 0;
				syncContextStats();
				cb(entry.data, null);
				return null;
			}

			// 正在加载中：加入等待列表，不重复发起请求
			if (entry.isLoading) {
				// entry.refCount++;
				syncContextStats();
				entry.pendingCallbacks.push(cb);
				return null;
			}
		}

		// 首次加载：创建新条目
		if (entry == null) {
			entry = new CacheEntry();
			__cache.set(url, entry);
		}
		entry.isLoading = true;
		entry.refCount = 1;
		return entry;
	}

	/**
	 * 请求完成后的缓存解析：存储数据、通知等待者
	 */
	private static function resolveCacheEntry(url:String, entry:CacheEntry, data:Dynamic, err:FutureErrorEvent):Void {
		entry.isLoading = false;

		if (err == null && data != null) {
			entry.data = data;
			syncContextStats();
		} else {
			// 加载失败：清理缓存条目，后续请求将重新加载
			entry.refCount--;
			if (entry.refCount <= 0 && entry.pendingCallbacks.length == 0) {
				__cache.remove(url);
			}
			syncContextStats();
		}

		// 通知所有等待中的回调
		var pending = entry.pendingCallbacks;
		entry.pendingCallbacks = [];
		for (pendingCb in pending) {
			pendingCb(data, err);
		}

		// 如果加载失败且还有等待者，清空缓存让后续请求重新加载
		if (err != null && entry.data == null) {
			__cache.remove(url);
			syncContextStats();
		}
	}

	/**
	 * 释放底层资源
	 */
	private static function disposeResource(data:Dynamic):Void {
		if (data == null)
			return;
		// BitmapData：释放GPU纹理
		if ((data is BitmapData)) {
			var bd:BitmapData = cast data;
			bd.dispose();
			return;
		}
		// Sound：当前无实际释放逻辑，由GC处理
		// Bytes / String：由GC处理
	}
}

/**
 * 缓存条目
 * 记录资源的缓存数据、引用计数和加载状态
 */
private class CacheEntry {
	/** 缓存的数据 */
	public var data:Dynamic;

	/** 引用计数 */
	public var refCount:Int = 0;

	/** 是否正在加载中 */
	public var isLoading:Bool = false;

	/** 延迟释放时间戳，0表示未处于延迟释放状态 */
	public var releaseTimestamp:Float = 0;

	/** 等待中的回调列表（相同URL的重复请求） */
	public var pendingCallbacks:Array<Dynamic->FutureErrorEvent->Void> = [];

	public function new() {}
}
