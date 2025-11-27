package hx.net;

import haxe.io.Bytes;
import hx.display.BitmapData;
import hx.assets.Sound;
import hx.events.FutureErrorEvent;

/**
 * 请求队列
 */
class RequestQueue {
	/**
	 * 最大请求数量
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

	/**
	 * 加载字符串
	 */
	public static function loadString(url:String, cb:String->FutureErrorEvent->Void):Void {
		var request = new StringRequest(url, cb);
		__requestQueue.push(request);
		// 如果请求数量已经超过最大数量，直接等待
		if (CURRENT_REQUEST_COUNT >= MAX_REQUEST_COUNT) {
			return;
		}
		loadNext();
	}

	/**
	 * 加载声音
	 */
	public static function loadSound(url:String, cb:Sound->FutureErrorEvent->Void):Void {
		var request = new SoundRequest(url, cb);
		__requestQueue.push(request);
		// 如果请求数量已经超过最大数量，直接等待
		if (CURRENT_REQUEST_COUNT >= MAX_REQUEST_COUNT) {
			return;
		}
		loadNext();
	}

	/**
	 * 加载图片
	 */
	public static function loadBitmapData(url:String, cb:BitmapData->FutureErrorEvent->Void):Void {
		var request = new BitmapDataRequest(url, cb);
		__requestQueue.push(request);
		// 如果请求数量已经超过最大数量，直接等待
		if (CURRENT_REQUEST_COUNT >= MAX_REQUEST_COUNT) {
			return;
		}
		loadNext();
	}

	/**
	 * 加载字节
	 */
	public static function loadBytes(url:String, cb:Bytes->FutureErrorEvent->Void):Void {
		var request = new BytesRequest(url, cb);
		__requestQueue.push(request);
		// 如果请求数量已经超过最大数量，直接等待
		if (CURRENT_REQUEST_COUNT >= MAX_REQUEST_COUNT) {
			return;
		}
		loadNext();
	}

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
}
