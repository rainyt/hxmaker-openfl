package hx.core;

import lime.graphics.Image;
import hx.events.FutureErrorEvent;
import openfl.utils.Assets;
import hx.display.BitmapData;
import hx.assets.Future;

/**
 * 纹理加载器
 */
class BitmapDataFuture extends Future<BitmapData, String> {
	override function post() {
		super.post();
		#if zygameui
		zygame.utils.AssetsUtils.loadBitmapData(hx.assets.Assets.getDefaultNativePath(path), false).onComplete(function(data:openfl.display.BitmapData):Void {
			this.completeValue(BitmapData.formData(new OpenFlBitmapData(data)));
		}).onError(err->{
			errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.getLoadData()));
		});
		#elseif cpp
		Assets.loadBitmapData(hx.assets.Assets.getDefaultNativePath(this.getLoadData()), false).onComplete((data) -> {
			this.completeValue(BitmapData.formData(new OpenFlBitmapData(data)));
		}).onError(err -> {
			errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.getLoadData()));
		});
		#else
		var img:Image = new Image();
		@:privateAccess img.__fromFile(hx.assets.Assets.getDefaultNativePath(this.getLoadData()), function(loadedImage:Image):Void {
			var bitmapData:openfl.display.BitmapData = openfl.display.BitmapData.fromImage(loadedImage);
			if (bitmapData == null) {
				errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.getLoadData()));
			} else {
				this.completeValue(BitmapData.formData(new OpenFlBitmapData(bitmapData)));
			}
		}, function():Void {
			// 加载失败，应该移除所有回调，并且重新载入
			errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.getLoadData()));
		});
		#end
	}
}
