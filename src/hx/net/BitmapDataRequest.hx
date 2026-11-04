package hx.net;

import hx.utils.System;
import hx.assets.ASTCManifest;
import haxe.Timer;
#if hx_astcenc
import openfl.display.ASTCBitmapData;
#end
import hx.ui.UIManager;
import hx.core.OpenFlBitmapData;
import lime.graphics.Image;
import hx.events.FutureErrorEvent;
import openfl.utils.Assets;
import hx.display.BitmapData;
import hx.assets.Future;

using StringTools;

class BitmapDataRequest extends BaseRequest<BitmapData> {
	private var settled:Bool = false;
	private static var failedUntil:Map<String, Float> = [];

	/** 保留原图片路径作为队列缓存标识，仅在请求内部切换实际纹理格式。 */
	override public function request():Void {
		super.request();
		#if hx_astcenc
		var clean:String = url.split("?")[0].split("#")[0];
		var explicit:Bool = StringTools.endsWith(clean, ".astc");
		var supported:Bool = false;
		try { supported = ASTCBitmapData.isSupportASTCConfig(); } catch (error:Dynamic) {}
		if (explicit) {
			if (supported)
				__loadASTC(url, false);
			else
				__finish(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "当前设备不支持 ASTC", url));
			return;
		}
		var astcPath:Null<String> = supported ? ASTCManifest.resolve(url) : null;
		if (astcPath != null) {
			var key:String = hx.assets.Assets.getDefaultNativePath(astcPath) + ASTCManifest.getVersion();
			var until:Null<Float> = failedUntil.get(key);
			if (until == null || Timer.stamp() >= until) {
				failedUntil.remove(key);
				__loadASTC(astcPath, true);
				return;
			}
		}
		#if wechat_zygame_dom
		// 未接入宏的旧项目继续支持读取资源包中已经解压的本地 ASTC，不探测远程文件。
		if (supported && ASTCManifest.enabled && !ASTCManifest.isConfigured() && StringTools.endsWith(url, ".png")) {
			var legacyPath:String = url.substr(0, url.length - 4) + ".astc";
			System.existFile(haxe.io.Path.join([Wx.env.USER_DATA_PATH, legacyPath])).onComplete(function(data):Void {
				if (data.data)
					__loadASTC(legacyPath, true);
				else
					__loadOriginal();
			});
			return;
		}
		#end
		#end
		__loadOriginal();
	}

	#if hx_astcenc
	/** 本地和远程 ASTC 共用校验与解码；失败后回退原图，并短暂抑制重复失败请求。 */
	private function __loadASTC(path:String, fallback:Bool):Void {
		new ASTCBytesLoader(path, function(bytes:haxe.io.Bytes, error:Null<String>):Void {
			var bitmap:BitmapData = null;
			if (error == null) {
				try {
					var texture:openfl.display.ASTCBitmapData = ASTCBitmapData.fromBytes(bytes);
					bitmap = BitmapData.formData(new OpenFlBitmapData(texture));
				} catch (failure:Dynamic) {
					error = "ASTC 解码失败：" + Std.string(failure);
					ASTCBytesLoader.invalidate(path);
				}
			}
			if (error == null && bitmap != null) {
				__finish(bitmap, null);
				return;
			}
			if (fallback) {
				failedUntil.set(hx.assets.Assets.getDefaultNativePath(path) + ASTCManifest.getVersion(), Timer.stamp() + 30);
				trace("ASTC 加载失败，使用原图片：" + url + "，" + error);
				__loadOriginal();
			} else {
				__finish(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, error ?? "ASTC 解码结果无效", url));
			}
		});
	}
	#end

	/** 按原路径尝试资源包和普通图片；ASTC 失败不提前向外层报告错误。 */
	private function __loadOriginal():Void {
		var future:Future<BitmapData> = UIManager.loadBitmapDataFromAssetsBundle(this.url);
		if (future != null) {
			future.onComplete((data) -> __finish(data.data, null)).onError((error) -> __loadPng());
			return;
		}
		__loadPng();
	}

	/** 整个图片请求只结算一次，内部字节加载和原图回退不改变并发计数。 */
	private function __finish(bitmap:BitmapData, error:FutureErrorEvent):Void {
		if (settled)
			return;
		settled = true;
		if (error != null)
			error.path = url;
		try { callback(bitmap, error); }
		catch (failure:Dynamic) { RequestQueue.loadComplete(); throw failure; }
		RequestQueue.loadComplete();
	}

	/** 原格式沿用原来的本地优先策略。 */
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

	/** 保持普通图片解码兼容，通过统一完成入口返回结果。 */
	private function __load(?path:String):Void {
		#if zygameui
		zygame.utils.AssetsUtils.loadBitmapData(path ?? hx.assets.Assets.getDefaultNativePath(this.url), false)
			.onComplete(function(data:openfl.display.BitmapData):Void {
				__finish(BitmapData.formData(new OpenFlBitmapData(data)), null);
			})
			.onError(err -> {
				__finish(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.url));
			});
		#elseif cpp
		Assets.loadBitmapData(path ?? hx.assets.Assets.getDefaultNativePath(this.url), false).onComplete((data) -> {
			__finish(BitmapData.formData(new OpenFlBitmapData(data)), null);
		}).onError(err -> {
			__finish(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.url));
		});
		#else
		var img:Image = new Image();
		@:privateAccess img.__fromFile(path ?? hx.assets.Assets.getDefaultNativePath(this.url), function(loadedImage:Image):Void {
			var bitmapData:openfl.display.BitmapData = openfl.display.BitmapData.fromImage(loadedImage);
			if (bitmapData == null) {
				__finish(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.url, url));
			} else {
				__finish(BitmapData.formData(new OpenFlBitmapData(bitmapData)), null);
			}
		}, function():Void {
			// 加载失败，应该移除所有回调，并且重新载入
			__finish(null, FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.url, url));
		});
		#end
	}
}
