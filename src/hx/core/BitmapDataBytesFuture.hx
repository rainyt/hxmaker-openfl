package hx.core;

import haxe.io.Bytes;
import hx.assets.Future;
import hx.assets.AssetObject;
import hx.display.BitmapData;
import hx.net.RequestQueue;

/** 在既有请求队列中解码内嵌图片，缓存键由调用方的内容摘要确定。 */
class BitmapDataBytesFuture extends Future<BitmapData, {bytes:Bytes, path:String}> {
	private var pending:Bool = false;
	override public function post():Void {
		if (pending || isComplete) return;
		pending = true; isError = false; error = null;
		var input = getLoadData(), cached = RequestQueue.enableCache;
		RequestQueue.decodeBitmapData(input.path, input.bytes, (bitmap, error) -> {
			pending = false;
			if (error != null) { errorValue(error); return; }
			// 关闭队列缓存时，通过子资产保持共享引用，最后一次释放时销毁位图。
			if (!cached) addAssetObject(new LocalBitmapAsset(bitmap));
			completeValue(bitmap, cached ? input.path : null);
		});
	}
}

private class LocalBitmapAsset extends AssetObject<BitmapData> {
	private var references:Int = 1;
	public function new(bitmap:BitmapData) { super(null, bitmap); }
	override public function retain():Void { references++; }
	override public function release():Void {
		if (references <= 0) return;
		references--;
		if (references == 0) { data.dispose(); data = null; }
	}
}
