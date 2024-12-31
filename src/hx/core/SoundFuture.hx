package hx.core;

import hx.events.FutureErrorEvent;
import openfl.Assets;
import hx.assets.Sound;
import hx.assets.Future;

class SoundFuture extends Future<Sound, String> {
	override function post() {
		super.post();
		Assets.loadSound(getLoadData()).onComplete((sound) -> {
			var data = new Sound();
			data.root = new OpenFLSound(sound);
			this.completeValue(data);
		}).onError(err -> {
			this.errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.getLoadData()));
		});
	}
}
