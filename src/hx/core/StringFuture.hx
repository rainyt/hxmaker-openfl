package hx.core;

import hx.net.RequestQueue;
import hx.events.FutureErrorEvent;
import hx.assets.Future;

class StringFuture extends Future<String, String> {
	override function post() {
		super.post();
		RequestQueue.loadString(this.getLoadData(), (data:String, error:FutureErrorEvent) -> {
			if (error != null) {
				this.errorValue(error);
			} else {
				this.completeValue(data);
			}
		});
	}
}
