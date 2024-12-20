package hx.core;

import openfl.Assets;
import hx.utils.Future;

class StringFuture extends Future<String, String> {
	override function post() {
		super.post();
		Assets.loadText(getLoadData()).onComplete((text) -> {
			this.completeValue(text);
		}).onError(this.errorValue);
	}
}
