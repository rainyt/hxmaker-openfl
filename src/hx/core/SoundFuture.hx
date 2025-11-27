package hx.core;

import hx.net.RequestQueue;
import hx.events.FutureErrorEvent;
import hx.assets.Sound;
import hx.assets.Future;

/**
 * 声音加载
 */
class SoundFuture extends Future<Sound, String> {
	override function post() {
		super.post();
		RequestQueue.loadSound(this.getLoadData(), (data:Sound, error:FutureErrorEvent) -> {
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
