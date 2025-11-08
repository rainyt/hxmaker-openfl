package hx.core;

import hx.events.FutureErrorEvent;
import openfl.events.IOErrorEvent;
import openfl.events.Event;
import openfl.net.URLRequest;
import openfl.net.URLLoader;
import haxe.io.Bytes;
import openfl.Assets;
import hx.assets.Future;

class BytesFuture extends Future<Bytes, String> {
	override function post() {
		super.post();
		var urlLoader = new URLLoader();
		urlLoader.dataFormat = BINARY;
		urlLoader.addEventListener(Event.COMPLETE, (e) -> {
			this.completeValue(urlLoader.data);
		});
		urlLoader.addEventListener(IOErrorEvent.IO_ERROR, (e) -> {
			this.errorValue(new FutureErrorEvent(FutureErrorEvent.LOAD_ERROR, false, false));
		});
		urlLoader.load(new URLRequest(hx.assets.Assets.getDefaultNativePath(getLoadData())));
	}
}
