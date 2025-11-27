package hx.net;

import hx.events.FutureErrorEvent;
import openfl.events.IOErrorEvent;
import openfl.events.Event;
import openfl.net.URLRequest;
import openfl.net.URLLoader;
import haxe.io.Bytes;

class BytesRequest extends BaseRequest<Bytes> {
	override function request() {
		super.request();
		var urlLoader = new URLLoader();
		urlLoader.dataFormat = BINARY;
		urlLoader.addEventListener(Event.COMPLETE, (e) -> {
			this.callback(urlLoader.data, null);
			RequestQueue.loadComplete();
		});
		urlLoader.addEventListener(IOErrorEvent.IO_ERROR, (e) -> {
			this.callback(null, new FutureErrorEvent(FutureErrorEvent.LOAD_ERROR, false, false));
			RequestQueue.loadComplete();
		});
		urlLoader.load(new URLRequest(hx.assets.Assets.getDefaultNativePath(this.url)));
	}
}
