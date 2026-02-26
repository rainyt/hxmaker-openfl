package hx.net;

import hx.utils.Timer;
import hx.ui.UIManager;
import hx.events.FutureErrorEvent;
import openfl.events.IOErrorEvent;
import openfl.events.Event;
import openfl.net.URLRequest;
import openfl.net.URLLoader;
import haxe.io.Bytes;

class BytesRequest extends BaseRequest<Bytes> {
	override function request() {
		super.request();

		var bytes = UIManager.getBytesByBundle(this.url);
		if (bytes != null) {
			#if assets_debug
			trace("[Assets] Loading bytes data from assets bundle: " + this.url);
			#end
			this.callback(bytes, null);
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
		urlLoader.load(new URLRequest(path ?? hx.assets.Assets.getDefaultNativePath(this.url)));
	}
}
