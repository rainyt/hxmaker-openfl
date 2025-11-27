package hx.net;

import hx.core.OpenFLSound;
import hx.core.BaseSound;
import openfl.events.IOErrorEvent;
import openfl.events.Event;
import openfl.net.URLRequest;
import hx.events.FutureErrorEvent;
import openfl.Assets;
import hx.assets.Sound;
import hx.assets.Future;

class SoundRequest extends BaseRequest<Sound> {
	override function request() {
		super.request();
		var path = this.url;
		#if cpp
		path = StringTools.replace(path, ".mp3", ".ogg");
		#end
		var url = new URLRequest(hx.assets.Assets.getDefaultNativePath(path));
		var sound = new BaseSound();
		sound.addEventListener(Event.COMPLETE, (e) -> {
			var data = new Sound();
			data.root = new OpenFLSound(sound);
			this.callback(data, null);
		});
		sound.addEventListener(IOErrorEvent.IO_ERROR, (e) -> {
			this.callback(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.url));
		});
		sound.load(url);
	}
}
