package hx.net;

import hx.core.OpenFlBitmapData;
import lime.graphics.Image;
import hx.events.FutureErrorEvent;
import openfl.utils.Assets;
import hx.display.BitmapData;
import hx.assets.Future;

class BitmapDataRequest extends BaseRequest<BitmapData> {
	override function request() {
		super.request();
		#if zygameui
		zygame.utils.AssetsUtils.loadBitmapData(hx.assets.Assets.getDefaultNativePath(this.url), false)
			.onComplete(function(data:openfl.display.BitmapData):Void {
				this.callback(BitmapData.formData(new OpenFlBitmapData(data)), null);
				RequestQueue.loadComplete();
			})
			.onError(err -> {
				this.callback(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.url));
				RequestQueue.loadComplete();
			});
		#elseif cpp
		Assets.loadBitmapData(hx.assets.Assets.getDefaultNativePath(this.url), false).onComplete((data) -> {
			this.callback(BitmapData.formData(new OpenFlBitmapData(data)), null);
			RequestQueue.loadComplete();
		}).onError(err -> {
			this.callback(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.url));
			RequestQueue.loadComplete();
		});
		#else
		var img:Image = new Image();
		@:privateAccess img.__fromFile(hx.assets.Assets.getDefaultNativePath(this.url), function(loadedImage:Image):Void {
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
