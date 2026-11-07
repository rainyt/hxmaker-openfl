package hx.net;

import haxe.Timer;
import haxe.crypto.Sha256;
import haxe.io.Bytes;
import haxe.io.Path;
import hx.assets.ASTCFormat;
import hx.assets.ASTCManifest;
import hx.assets.Assets;
import hx.ui.UIManager;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.URLLoader;
import openfl.net.URLRequest;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** 图片请求内部使用的 ASTC 字节加载器，不占用或释放 RequestQueue 的并发位置。 */
class ASTCBytesLoader {
	public static var timeoutMilliseconds:Int = 60000;
	private var path:String;
	private var callback:Bytes->Null<String>->Void;
	private var completed:Bool = false;
	private var timer:Timer;
	private var loader:URLLoader;
	private var cachePath:Null<String>;
	private var temporary:Null<String>;
	#if wechat_zygame_dom
	private var downloadTask:Dynamic;
	#end

	/** 优先读取包内、本地缓存和已解压资源，缺失或校验失败时请求远程单图。 */
	public function new(path:String, callback:Bytes->Null<String>->Void) {
		this.path = path;
		this.callback = callback;
		cachePath = getCachePath(path);
		timer = Timer.delay(() -> finish(null, "ASTC 加载超时：" + path), timeoutMilliseconds);
		start();
	}

	/** 删除本生成器拥有的缓存；GPU 解码失败时不继续使用该文件。 */
	public static function invalidate(path:String):Void {
		removeFile(getCachePath(path));
	}

	/** 读取内存资源包和原生安装包，图片字节不进入全局字节缓存。 */
	private function start():Void {
		var bytes:Bytes = null;
		var logical:Null<String> = localLogicalPath(path);
		try {
			if (logical != null)
				bytes = UIManager.getBytesByBundle(logical);
			#if cpp
			if (bytes == null && logical != null && openfl.utils.Assets.exists(logical, BINARY) && openfl.utils.Assets.isLocal(logical, BINARY))
				bytes = openfl.utils.Assets.getBytes(logical);
			#end
		} catch (error:Dynamic) {}
		bytes = decode(bytes);
		if (bytes != null) {
			finish(bytes, null);
			return;
		}
		#if wechat_zygame_dom
		readWechatFile(cachePath, () -> {
			if (logical == null) {
				download();
				return;
			}
			readWechatFile(Path.join([Wx.env.USER_DATA_PATH, logical]), download);
		});
		#elseif sys
		if (readNativeFile(cachePath))
			return;
		if (logical != null && readNativeFile(logical))
			return;
		download();
		#else
		download();
		#end
	}

	#if wechat_zygame_dom
	/** 本地文件不存在、损坏或读取失败均继续下一来源。 */
	private function readWechatFile(file:Null<String>, next:Void->Void):Void {
		if (completed)
			return;
		if (file == null) {
			next();
			return;
		}
		try {
			Wx.getFileSystemManager().readFile({
				filePath: file,
				success: function(result:Dynamic):Void {
					if (completed)
						return;
					var bytes:Bytes = null;
					try { bytes = Bytes.ofData(cast result.data); } catch (error:Dynamic) {}
					bytes = decode(bytes);
					if (bytes != null)
						finish(bytes, null);
					else {
						removeFile(file);
						next();
					}
				},
				fail: function(error:Dynamic):Void { if (!completed) next(); }
			});
		} catch (error:Dynamic) {
			if (!completed)
				next();
		}
	}
	#end

	#if sys
	/** 原生文件读取失败时忽略缓存，包内原始资源不被删除。 */
	private function readNativeFile(file:Null<String>):Bool {
		var bytes:Bytes = null;
		try {
			if (file != null && FileSystem.exists(file) && !FileSystem.isDirectory(file))
				bytes = File.getBytes(file);
		} catch (error:Dynamic) {}
		bytes = decode(bytes);
		if (bytes == null) {
			if (file == cachePath)
				removeFile(file);
			return false;
		}
		finish(bytes, null);
		return true;
	}
	#end

	/** 远程下载统一设置超时；下载成功后校验二进制内容再保存缓存。 */
	private function download():Void {
		if (completed)
			return;
		var remote:String = Assets.getDefaultNativePath(path);
		#if wechat_zygame_dom
		try {
			downloadTask = untyped Wx.downloadFile({
				url: remote,
				timeout: timeoutMilliseconds,
				success: function(result:Dynamic):Void {
					if (completed) {
						removeFile(result.tempFilePath);
						return;
					}
					temporary = result.tempFilePath;
					if (result.statusCode != 200 || temporary == null) {
						finish(null, "ASTC 下载失败，HTTP " + result.statusCode + "：" + remote);
						return;
					}
					Wx.getFileSystemManager().readFile({
						filePath: temporary,
						success: function(data:Dynamic):Void {
							if (completed)
								return;
							var bytes:Bytes = null;
							try { bytes = Bytes.ofData(cast data.data); } catch (error:Dynamic) {}
							acceptDownload(bytes);
						},
						fail: function(error:Dynamic):Void { finish(null, "ASTC 下载文件读取失败：" + remote); }
					});
				},
				fail: function(error:Dynamic):Void { finish(null, "ASTC 下载失败：" + remote + "，" + Std.string(error)); }
			});
		} catch (error:Dynamic) {
			finish(null, "ASTC 下载异常：" + Std.string(error));
		}
		#else
		loader = new URLLoader();
		loader.dataFormat = BINARY;
		loader.addEventListener(Event.COMPLETE, function(event:Event):Void {
			if (completed)
				return;
			var bytes:Bytes = null;
			try { bytes = cast loader.data; } catch (error:Dynamic) {}
			acceptDownload(bytes);
		});
		loader.addEventListener(IOErrorEvent.IO_ERROR, function(event:IOErrorEvent):Void {
			finish(null, "ASTC 下载失败：" + remote);
		});
		var request:URLRequest = new URLRequest(remote);
		request.idleTimeout = timeoutMilliseconds;
		try { loader.load(request); } catch (error:Dynamic) { finish(null, "ASTC 下载异常：" + Std.string(error)); }
		#end
	}

	/** 磁盘保留下载时的压缩或裸文件，只有传给纹理上传的字节才还原为原始 ASTC。 */
	private function acceptDownload(bytes:Bytes):Void {
		if (completed)
			return;
		var decoded:Bytes = decode(bytes);
		if (decoded == null) {
			finish(null, "ASTC 文件校验失败：" + path);
			return;
		}
		try {
			if (cachePath != null) {
				#if wechat_zygame_dom
				var fileSystem:Dynamic = Wx.getFileSystemManager();
				fileSystem.mkdirSync(Path.directory(cachePath), true);
				removeFile(cachePath);
				fileSystem.renameSync(temporary, cachePath);
				temporary = null;
				#elseif sys
				FileSystem.createDirectory(Path.directory(cachePath));
				temporary = cachePath + "." + Std.random(0x3fffffff) + ".tmp";
				File.saveBytes(temporary, bytes);
				if (Sys.systemName() == "Windows")
					removeFile(cachePath);
				FileSystem.rename(temporary, cachePath);
				temporary = null;
				#end
			}
		} catch (error:Dynamic) {
			trace("ASTC 缓存写入失败，本次继续使用已下载纹理：" + path);
		}
		finish(decoded, null);
	}

	/** 所有来源共用格式识别和大小校验，运行时优先通过 Lime 调用平台 zlib 实现。 */
	private static function decode(bytes:Bytes):Bytes {
		if (bytes == null)
			return null;
		try {
			#if lime
			return ASTCFormat.decode(bytes, 67108864, inflate);
			#else
			return ASTCFormat.decode(bytes);
			#end
		} catch (error:Dynamic) {
			return null;
		}
	}

	#if lime
	/** JS 使用适配层现有的 pako，原生平台由 Lime 调用 CFFI，不在 Haxe 层重复解压完整数据。 */
	private static function inflate(bytes:Bytes):Bytes {
		var source:lime.utils.Bytes = bytes;
		return source.decompress(lime.utils.CompressionAlgorithm.ZLIB);
	}
	#end

	/** 取消未结束的传输并阻止超时后的迟到回调，不处理外层请求队列。 */
	private function finish(bytes:Bytes, error:Null<String>):Void {
		if (completed)
			return;
		completed = true;
		if (timer != null)
			timer.stop();
		if (error != null) {
			try {
				#if wechat_zygame_dom
				if (downloadTask != null)
					downloadTask.abort();
				#else
				if (loader != null)
					loader.close();
				#end
			} catch (failure:Dynamic) {}
		}
		removeFile(temporary);
		temporary = null;
		var result:Bytes->Null<String>->Void = callback;
		callback = null;
		result(bytes, error);
	}

	/** 基址、清单内容版本和完整请求路径共同隔离缓存，避免跨版本误用。 */
	private static function getCachePath(path:String):Null<String> {
		var key:String = Sha256.encode((Assets.defaultNativePath ?? "") + "\n" + ASTCManifest.getVersion() + "\n" + path);
		#if wechat_zygame_dom
		return Path.join([Wx.env.USER_DATA_PATH, "hxmaker_astc", key + ".astc"]);
		#elseif sys
		return Path.join([lime.system.System.applicationStorageDirectory, "hxmaker_astc", key + ".astc"]);
		#else
		return null;
		#end
	}

	/** 只允许相对资源路径映射到包解压目录，外部地址不参与目录拼接。 */
	private static function localLogicalPath(path:String):Null<String> {
		var clean:String = path.split("?")[0].split("#")[0];
		if (clean.indexOf("://") >= 0) {
			var base:Null<String> = Assets.defaultNativePath;
			if (base == null)
				return null;
			base = StringTools.endsWith(base, "/") ? base : base + "/";
			if (!StringTools.startsWith(clean, base))
				return null;
			clean = clean.substr(base.length);
		}
		if (clean.indexOf(":") >= 0 || Path.isAbsolute(clean) || clean.split("/").indexOf("..") >= 0)
			return null;
		return clean;
	}

	/** 清理缓存或下载临时文件；失败不影响原图回退。 */
	private static function removeFile(file:Null<String>):Void {
		if (file == null)
			return;
		try {
			#if wechat_zygame_dom
			var fileSystem:Dynamic = Wx.getFileSystemManager();
			fileSystem.unlinkSync(file);
			#elseif sys
			if (FileSystem.exists(file) && !FileSystem.isDirectory(file))
				FileSystem.deleteFile(file);
			#end
		} catch (error:Dynamic) {}
	}
}
