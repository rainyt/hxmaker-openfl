package hx.net;

import openfl.events.IOErrorEvent;
import hx.events.FutureErrorEvent;
import openfl.events.Event;
import openfl.net.URLRequest;
import openfl.net.URLLoader;

class StringRequest extends BaseRequest<String> {
	override function request() {
		var version = lime.utils.Assets.cache.version;
		if (url.indexOf("?") != -1) {
			url += "&v=" + version;
		} else {
			url += "?v=" + version;
		}
		var loader = new URLLoader(new URLRequest(hx.assets.Assets.getDefaultNativePath(url)));
		loader.addEventListener(Event.COMPLETE, (e) -> {
            callback(loader.data, null);
			RequestQueue.loadComplete();
		});
		loader.addEventListener(IOErrorEvent.IO_ERROR, (e) -> {
            callback(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + url));
			RequestQueue.loadComplete();
		});
	}
}
