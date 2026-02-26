package hx.net;

import hx.ui.UIManager;
import hx.core.OpenFlBitmapData;
import lime.graphics.Image;
import hx.events.FutureErrorEvent;
import openfl.utils.Assets;
import hx.display.BitmapData;
import hx.assets.Future;

class BitmapDataRequest extends BaseRequest<BitmapData> {
	override function request() {
		super.request();

		var future = UIManager.loadBitmapDataFromAssetsBundle(this.url);
		if (future != null) {
			#if assets_debug
			trace("[Assets] Loading bitmap data from assets bundle: " + this.url);
			#end
			future.onComplete((data) -> {
				this.callback(data, null);
				RequestQueue.loadComplete();
			}).onError((err) -> {
				this.callback(null, err);
				RequestQueue.loadComplete();
			});
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

	private function __load(?path:String):Void {
		#if zygameui
		zygame.utils.AssetsUtils.loadBitmapData(path ?? hx.assets.Assets.getDefaultNativePath(this.url), false)
			.onComplete(function(data:openfl.display.BitmapData):Void {
				this.callback(BitmapData.formData(new OpenFlBitmapData(data)), null);
				RequestQueue.loadComplete();
			})
			.onError(err -> {
				this.callback(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.url));
				RequestQueue.loadComplete();
			});
		#elseif cpp
		Assets.loadBitmapData(path ?? hx.assets.Assets.getDefaultNativePath(this.url), false).onComplete((data) -> {
			this.callback(BitmapData.formData(new OpenFlBitmapData(data)), null);
			RequestQueue.loadComplete();
		}).onError(err -> {
			this.callback(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.url));
			RequestQueue.loadComplete();
		});
		#else
		var img:Image = new Image();
		@:privateAccess img.__fromFile(path ?? hx.assets.Assets.getDefaultNativePath(this.url), function(loadedImage:Image):Void {
			var bitmapData:openfl.display.BitmapData = openfl.display.BitmapData.fromImage(loadedImage);
			if (bitmapData == null) {
				this.callback(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.url));
				RequestQueue.loadComplete();
			} else {
				this.callback(BitmapData.formData(new OpenFlBitmapData(bitmapData)), null);
				RequestQueue.loadComplete();
			}
		}, function():Void {
			// 加载失败，应该移除所有回调，并且重新载入
			this.callback(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.url));
			RequestQueue.loadComplete();
		});
		#end
	}
}
