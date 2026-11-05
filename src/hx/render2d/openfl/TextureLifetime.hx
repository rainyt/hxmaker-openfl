package hx.render2d.openfl;

import openfl.display.BitmapData;
import hx.core.Engine;
import hx.core.Hxmaker;

/** 只保存标量的资源状态；诊断信息不持有位图和显示树。 */
class TextureRecord {
	public var resourceId:Int;
	public var references:Int = 0;
	public var owners:Int = 0;
	public var pending:Bool = false;
	public var disposed:Bool = false;
	public var generation:Int;
	public var releaseReason:String = "";
	public var label:String = "";
	public var entryId:Int = 0;
	public var lastBatchId:Int = 0;
	public var releaseStack:String = "";
	public function new(resourceId:Int, generation:Int) {
		this.resourceId = resourceId;
		this.generation = generation;
	}
}

/** 以快照退役为释放边界，不在 draw 后或帧尾解除持久显示树持有。 */
@:access(openfl.display.BitmapData)
@:access(openfl.display3D.Context3D)
@:access(openfl.display3D.textures.TextureBase)
class TextureLifetime {
	#if js
	private static var records:js.lib.WeakMap<TextureRecord> = new js.lib.WeakMap();
	#elseif cpp
	private static var records:haxe.ds.WeakMap<BitmapData, TextureRecord> = new haxe.ds.WeakMap();
	#else
	private static var records:haxe.ds.ObjectMap<BitmapData, TextureRecord> = new haxe.ds.ObjectMap();
	#end
	private static var nextId:Int = 0;
	public static var references(default, null):Int = 0;
	public static var pendingDisposals(default, null):Int = 0;
	public static var physicalDisposals(default, null):Int = 0;

	/** 当前设备代次，不以原始 GL 对象相等推断资源有效。 */
	public static function generation():Int {
		return Hxmaker.engine is Engine ? cast(Hxmaker.engine, Engine).contextGeneration : 0;
	}

	/** 按需建立弱关联，分配稳定资源编号。 */
	public static function record(bitmap:BitmapData):TextureRecord {
		var result:TextureRecord = cast records.get(bitmap);
		if (result == null) {
			result = new TextureRecord(++nextId, generation());
			records.set(bitmap, result);
			RenderDiagnostics.lifecycle("分配登记", result, 0);
		}
		return result;
	}

	/** 新快照不能重新取得已请求释放的资源；旧快照可以继续消费。 */
	public static function acquire(bitmap:BitmapData, batchId:Int = 0):Bool {
		if (bitmap == null) return false;
		var state:TextureRecord = record(bitmap);
		if (state.pending || state.disposed || !bitmap.__isValid) return false;
		state.references++; references++; state.lastBatchId = batchId;
		RenderDiagnostics.lifecycle("快照持有", state, batchId);
		return true;
	}

	/** 解除一次实际持有，最后一个快照退役时完成延迟释放。 */
	public static function release(bitmap:BitmapData, batchId:Int = 0):Void {
		var state:TextureRecord = record(bitmap);
		if (state.references <= 0) throw "纹理持有计数不匹配";
		state.references--; references--;
		RenderDiagnostics.lifecycle("快照退役", state, batchId);
		if (state.references == 0 && state.pending) destroy(bitmap, state);
	}

	/** 请求逻辑释放；不会将已释放资源自动复活。 */
	public static function requestDispose(bitmap:BitmapData, reason:String):Void {
		if (bitmap == null) return;
		var state:TextureRecord = record(bitmap);
		if (state.pending || state.disposed) return;
		state.pending = true; pendingDisposals++;
		state.releaseReason = RenderDiagnostics.sanitize(reason);
		#if (debug || hxmaker_render_debug)
		state.releaseStack = haxe.CallStack.toString(haxe.CallStack.callStack()).substr(0, 8192);
		#end
		RenderDiagnostics.lifecycle("请求释放", state, state.lastBatchId);
		if (state.references == 0) destroy(bitmap, state);
	}

	/** 最终销毁由引擎拥有的根纹理；旧设备句柄只能废弃，不能在新设备删除。 */
	private static function destroy(bitmap:BitmapData, state:TextureRecord):Void {
		if (state.disposed) return;
		state.disposed = true; pendingDisposals--; physicalDisposals++;
		RenderDiagnostics.lifecycle("物理释放", state, state.lastBatchId);
		var texture:openfl.display3D.textures.TextureBase = bitmap.__texture;
		var current:Bool = state.generation == generation();
		if (texture != null && current && texture.__context != null && !texture.__context.gl.isContextLost()) texture.dispose();
		bitmap.__texture = null;
		bitmap.dispose();
		#if (!js && !cpp)
		records.remove(bitmap);
		#end
	}
}
