package hx.net;

import hx.utils.System;
import hx.ui.UIManager;
import hx.core.OpenFlBitmapData;
import lime.graphics.Image;
import hx.events.FutureErrorEvent;
import openfl.utils.Assets;
import hx.display.BitmapData;
import hx.assets.Future;

using StringTools;

class BitmapDataRequest extends BaseRequest<BitmapData> {
	override function request():Void {
		super.request();

		// 资源包优先：包内提供的是位图就直接使用
		var future = UIManager.loadBitmapDataFromAssetsBundle(this.url);
		if (future != null) {
			#if assets_debug
			trace("[Assets] Loading bitmap data from assets bundle: " + this.url);
			#end
			future.onComplete((data) -> {
				this.callback(data.data, null);
				RequestQueue.loadComplete();
			}).onError((err) -> {
				// 包内位图不可用时继续按清单分发
				__loadManifestOrPng();
			});
			return;
		}
		__loadManifestOrPng();
	}

	/** 清单命中且设备支持 ASTC 时直接使用 ASTC，加载失败不再回退原图。 */
	private function __loadManifestOrPng():Void {
		#if hx_astcenc
		// 首次使用时绑定后端解码器，之后由核心通过 IASTCDecoder 接口调用。
		if (hx.assets.astc.ASTCLoader.decoder == null)
			hx.assets.astc.ASTCLoader.registerDecoder(new hx.core.ASTCDecoder());
		if (hx.assets.astc.ASTCLoader.load(this.url, __onASTC))
			return;
		#end
		__loadPng();
	}

	#if hx_astcenc
	/** ASTC 成功或失败都只结算一次，不改变外层请求的并发计数。 */
	private function __onASTC(bitmap:BitmapData, error:Null<String>):Void {
		if (bitmap != null) {
			this.callback(bitmap, null);
		} else {
			this.callback(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, error ?? ("ASTC 加载失败：" + this.url), this.url));
		}
		RequestQueue.loadComplete();
	}
	#end

	private function __loadPng():Void {
		#if wechat_zygame_dom
		// 微信小游戏，可先检查本地是否存在这个文件，然后进行本地加载
		var localFile = haxe.io.Path.join([Wx.env.USER_DATA_PATH, this.url]);
		hx.utils.System.existFile(localFile).onComplete(function(data) {
			if (data.data) {
				#if assets_debug
				trace("[Assets] Loading bitmap data from local file: " + localFile);
				#end
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
				this.callback(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.url, url));
				RequestQueue.loadComplete();
			} else {
				this.callback(BitmapData.formData(new OpenFlBitmapData(bitmapData)), null);
				RequestQueue.loadComplete();
			}
		}, function():Void {
			// 加载失败，应该移除所有回调，并且重新载入
			this.callback(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.url, url));
			RequestQueue.loadComplete();
		});
		#end
	}
}
