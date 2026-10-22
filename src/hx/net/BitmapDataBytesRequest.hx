package hx.net;

import haxe.io.Bytes;
import hx.core.OpenFlBitmapData;
import hx.display.BitmapData;
import hx.events.FutureErrorEvent;

/** 只解码已经下载的图片字节，不经 URL 再次请求资源。 */
class BitmapDataBytesRequest extends BaseRequest<BitmapData> {
	private var bytes:Bytes;
	private var settled:Bool = false;
	public function new(key:String, bytes:Bytes, callback:BitmapData->FutureErrorEvent->Void) {
		super(key, callback); this.bytes = bytes;
	}
	override public function request():Void {
		if (bytes == null || bytes.length == 0) { finish(null, "图片字节不能为空"); return; }
		var future:openfl.utils.Future<openfl.display.BitmapData>;
		try { future = openfl.display.BitmapData.loadFromBytes(openfl.utils.ByteArray.fromBytes(bytes)); }
		catch (error:Dynamic) { finish(null, "图片解码失败：" + Std.string(error)); return; }
		future.onComplete(bitmap -> {
			if (bitmap == null || bitmap.width <= 0 || bitmap.height <= 0) { finish(null, "图片解码结果无效"); return; }
			finish(BitmapData.formData(new OpenFlBitmapData(bitmap)), null);
		});
		future.onError(error -> finish(null, "图片解码失败：" + Std.string(error)));
	}
	private function finish(bitmap:BitmapData, message:String):Void {
		if (settled) return;
		settled = true; bytes = null;
		var error = message == null ? null : FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, message);
		if (error != null) error.path = url;
		try { callback(bitmap, error); }
		catch (failure:Dynamic) { RequestQueue.loadComplete(); throw failure; }
		RequestQueue.loadComplete();
	}
}
