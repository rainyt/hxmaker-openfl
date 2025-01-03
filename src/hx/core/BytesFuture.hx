package hx.core;

import haxe.io.Bytes;
import openfl.Assets;
import hx.assets.Future;

class BytesFuture extends Future<Bytes, String> {
	override function post() {
		super.post();
		Assets.loadBytes(getLoadData()).onComplete((bytes) -> {
			this.completeValue(bytes);
		}).onError(this.errorValue);
	}
}
