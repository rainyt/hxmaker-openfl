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
		var version = lime.utils.Assets.cache.version;
		var url:String = getLoadData();
		if (url.indexOf("?") != -1) {
			url += "&v=" + version;
		} else {
			url += "?v=" + version;
		}
		var loader = new URLLoader(new URLRequest(hx.assets.Assets.getDefaultNativePath(url)));
		loader.addEventListener(Event.COMPLETE, (e) -> {
			this.completeValue(loader.data);
		});
		loader.addEventListener(IOErrorEvent.IO_ERROR, (e) -> {
			this.errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + getLoadData()));
		});
	}
}
