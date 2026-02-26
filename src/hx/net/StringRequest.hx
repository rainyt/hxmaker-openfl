package hx.net;

import hx.utils.Timer;
import hx.ui.UIManager;
import openfl.events.IOErrorEvent;
import hx.events.FutureErrorEvent;
import openfl.events.Event;
import openfl.net.URLRequest;
import openfl.net.URLLoader;

class StringRequest extends BaseRequest<String> {
	override function request() {
		var bytes = UIManager.getBytesByBundle(this.url);
		if (bytes != null) {
			#if assets_debug
			trace("[Assets] Loading string data from assets bundle: " + this.url);
			#end
			this.callback(bytes.toString(), null);
			RequestQueue.loadComplete();
			return;
		}

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

	private function __load(?path:String) {
		if (path == null) {
			path = hx.assets.Assets.getDefaultNativePath(this.url);
			var version = lime.utils.Assets.cache.version;
			if (path.indexOf("?") != -1) {
				path += "&v=" + version;
			} else {
				path += "?v=" + version;
			}
		}
		var loader = new URLLoader(new URLRequest(path));
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
