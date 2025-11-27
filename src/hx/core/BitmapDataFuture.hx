package hx.core;

import hx.net.RequestQueue;
import lime.graphics.Image;
import hx.events.FutureErrorEvent;
import openfl.utils.Assets;
import hx.display.BitmapData;
import hx.assets.Future;

/**
 * 纹理加载器
 */
class BitmapDataFuture extends Future<BitmapData, String> {
	override function post() {
		super.post();
		RequestQueue.loadBitmapData(this.getLoadData(), (data, err) -> {
			if (err != null) {
				this.errorValue(err);
			} else {
				this.completeValue(data);
			}
		});
	}
}
