package hx.core;

import openfl.events.IOErrorEvent;
import openfl.events.Event;
import openfl.net.URLRequest;
import hx.events.FutureErrorEvent;
import openfl.Assets;
import hx.assets.Sound;
import hx.assets.Future;

class SoundFuture extends Future<Sound, String> {
	override function post() {
		super.post();
		var path = getLoadData();
		#if cpp
		path = StringTools.replace(path, ".mp3", ".ogg");
		#end
		var url = new URLRequest(path);
		var sound = new openfl.media.Sound();
		sound.addEventListener(Event.COMPLETE, (e) -> {
			var data = new Sound();
			data.root = new OpenFLSound(sound);
			this.completeValue(data);
		});
		sound.addEventListener(IOErrorEvent.IO_ERROR, (e) -> {
			this.errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.getLoadData()));
		});
		sound.load(url);
	}
}
