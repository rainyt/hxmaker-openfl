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
	public var isMusic:Bool = false;

	override function request() {
		super.request();

		#if wechat_zygame_dom
		// 微信小游戏，可先检查本地是否存在这个文件，然后进行本地加载
		var localFile = haxe.io.Path.join([Wx.env.USER_DATA_PATH, this.url]);
		hx.utils.System.existFile(localFile).onComplete(function(exist) {
			if (exist) {
				__load(localFile);
			} else {
				__load();
			}
		});
		#else
		__load();
		#end
	}

	private function __load(?path:String):Void {
		if (path == null)
			path = hx.assets.Assets.getDefaultNativePath(this.url);
		#if (cpp && !hxmaker_sound)
		path = StringTools.replace(path, ".mp3", ".ogg");
		#end
		var url = new URLRequest(path);
		var sound = new BaseSound();
		#if hxmaker_sound
		@:privateAccess sound.__isMusic = isMusic;
		#end
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
