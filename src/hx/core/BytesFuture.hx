package hx.core;

import hx.net.RequestQueue;
import hx.events.FutureErrorEvent;
import haxe.io.Bytes;
import hx.assets.Future;

class BytesFuture extends Future<Bytes, String> {
	override function post() {
		super.post();
		// 并发计数由 BytesRequest 在回调后统一结算，这里不重复调用 loadComplete。
		RequestQueue.loadBytes(this.getLoadData(), (data:Bytes, error:FutureErrorEvent) -> {
			if (error != null) {
				this.errorValue(error);
			} else {
				this.completeValue(data, this.path);
			}
		});
	}
}
