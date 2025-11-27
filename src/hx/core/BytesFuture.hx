package hx.core;

import hx.net.RequestQueue;
import hx.events.FutureErrorEvent;
import haxe.io.Bytes;
import hx.assets.Future;

class BytesFuture extends Future<Bytes, String> {
	override function post() {
		super.post();
		RequestQueue.loadBytes(this.getLoadData(), (data:Bytes, error:FutureErrorEvent) -> {
			if (error != null) {
				this.errorValue(error);
				RequestQueue.loadComplete();
			} else {
				this.completeValue(data);
				RequestQueue.loadComplete();
			}
		});
	}
}
