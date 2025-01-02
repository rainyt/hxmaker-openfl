package hx.core;

import hx.events.FutureErrorEvent;
import openfl.events.IOErrorEvent;
import openfl.events.Event;
import openfl.net.URLRequest;
import openfl.net.URLLoader;
import openfl.Assets;
import hx.assets.Future;

class StringFuture extends Future<String, String> {
	override function post() {
		super.post();
		var loader = new URLLoader(new URLRequest(getLoadData()));
		loader.addEventListener(Event.COMPLETE, (e) -> {
			this.completeValue(loader.data);
		});
		loader.addEventListener(IOErrorEvent.IO_ERROR, (e) -> {
			this.errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + getLoadData()));
		});
	}
}
