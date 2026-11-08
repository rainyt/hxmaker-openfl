package hx.core;

import hx.net.RequestQueue;
import lime.graphics.Image;
import hx.events.FutureErrorEvent;
import hx.display.BitmapData;
import hx.assets.Future;
#if hx_astcenc
import haxe.Timer;
import hx.assets.astc.ASTCLoader;
#end

using StringTools;

/**
 * 纹理加载器
 */
class BitmapDataFuture extends Future<BitmapData, String> {
	#if hx_astcenc
	/** 同一 ASTC 地址的并发请求共用一次读取。 */
	private static var __astcPending:Map<String, Array<BitmapData->Null<String>->Void>> = [];

	/** ASTC 失败后短时间内直接使用原图，避免重复失败。 */
	private static var __astcFailedUntil:Map<String, Float> = [];
	#end

	override function post() {
		super.post();
		#if hx_astcenc
		// 在进入图片请求队列之前先决定是否走 ASTC，避免图片请求内部再发起字节请求。
		var url:String = this.getLoadData();
		if (ASTCLoader.decoder == null)
			ASTCLoader.registerDecoder(new ASTCDecoder());
		var clean:String = cleanUrl(url);
		var until:Null<Float> = __astcFailedUntil.get(clean);
		if ((until == null || Timer.stamp() >= until) && !RequestQueue.hasCache(url)) {
			if (__loadASTC(url, clean))
				return;
		}
		#end
		__loadOriginal();
	}

	/** 按原路径进入请求队列；缓存命中、并发去重和引用计数仍由 RequestQueue 负责。 */
	private function __loadOriginal():Void {
		RequestQueue.loadBitmapData(this.getLoadData(), (data, err) -> {
			if (err != null) {
				this.errorValue(err);
			} else {
				this.completeValue(data, this.path);
			}
		});
	}

	#if hx_astcenc
	/** 返回 true 表示已由 ASTC 接管；false 表示与 ASTC 无关。 */
	private function __loadASTC(url:String, clean:String):Bool {
		if (!ASTCLoader.canLoad(url))
			return false;
		var pending:Array<BitmapData->Null<String>->Void> = __astcPending.get(clean);
		if (pending != null) {
			pending.push(__onASTC);
			return true;
		}
		pending = [__onASTC];
		__astcPending.set(clean, pending);
		var handled:Bool = ASTCLoader.load(url, function(bitmap:BitmapData, error:Null<String>):Void {
			__astcPending.remove(clean);
			for (callback in pending)
				callback(bitmap, error);
		});
		if (!handled) {
			__astcPending.remove(clean);
			return false;
		}
		return true;
	}

	/** ASTC 成功时登记进请求缓存，保证引用计数与延迟释放仍然有效。 */
	private function __onASTC(bitmap:BitmapData, error:Null<String>):Void {
		var url:String = this.getLoadData();
		if (bitmap != null) {
			RequestQueue.put(url, bitmap);
			this.completeValue(bitmap, this.path);
			return;
		}
		var clean:String = cleanUrl(url);
		if (clean.endsWith(".astc")) {
			// 显式 ASTC 地址失败时直接报告错误，不再猜测 PNG 地址。
			this.errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, error ?? ("ASTC 加载失败：" + url), url));
			return;
		}
		// 清单命中但 ASTC 不可用时回退原图，并在 30 秒内不再重复尝试该资源。
		__astcFailedUntil.set(clean, Timer.stamp() + 30);
		trace("[ASTC] 加载失败，回退原图：" + url + "，" + (error ?? "未知错误"));
		__loadOriginal();
	}

	/** 去掉查询参数和锚点，用于扩展名判断、去重与失败抑制。 */
	private static function cleanUrl(url:String):String {
		return url.split("?")[0].split("#")[0];
	}
	#end
}
