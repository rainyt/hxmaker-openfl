package hx.filters;

import hx.core.Hxmaker;
import hx.core.OpenFlBitmapData;
import hx.display.IBitmapData;
import hx.display.BitmapData;
import hx.render2d.openfl.TextureLifetime;

/** 池拥有目标，借用视图只归还令牌；正在被快照读取的目标不会再次作为输出。 */
class StageBitmapData extends BitmapData {
	private static var pool:Array<StageBitmapEntry> = [];
	private static var cacheCount:Int = 0;
	private static var elapsed:Float = 0;
	private var lease:StageBitmapLease;
	public static var counts(get, never):Int;
	private static function get_counts():Int { return pool.length; }

	/** 设定空闲预留数；实际分配使用统一尺寸检查。 */
	public static function cacheSize(size:Int):Void {
		cacheCount = Std.int(Math.max(0, size));
		while (pool.length < cacheCount) pool.push(createEntry());
	}
	/** 帧边界不解除活跃借用，也不让嵌套 Pass 覆写正在读取的目标。 */
	public static function resetPool():Void {}
	/** 定期预算回收不再被借用或读取的空闲目标。 */
	public static function update(dt:Float):Void {
		elapsed += dt;
		if (elapsed > 6) disposeAll();
	}
	/** 强制清理将目标退出池；实际根释放仍遵守快照存活期。 */
	public static function disposeAll(force:Bool = false):Void {
		var index:Int = pool.length;
		while (index-- > 0) {
			var entry:StageBitmapEntry = pool[index];
			if (force || (pool.length > cacheCount && !entry.borrowed && !isRead(entry))) {
				pool.splice(index, 1); entry.retired = true;
				if (!entry.borrowed) entry.bitmap.dispose();
			}
		}
		elapsed = 0;
	}
	/** 旧代次目标退出池，由下一次滤镜绘制生成真实内容。 */
	public static function onContextRestored():Void { disposeAll(true); }
	/** 新建与当前舞台大小一致的目标，记录设备代次。 */
	private static function createEntry():StageBitmapEntry {
		return new StageBitmapEntry(OpenFlBitmapData.fromSize(Math.ceil(Hxmaker.engine.stageWidth), Math.ceil(Hxmaker.engine.stageHeight), true, 0));
	}
	/** 查询快照读取，不扫描显示树。 */
	private static function isRead(entry:StageBitmapEntry):Bool {
		var raw:openfl.display.BitmapData = entry.bitmap.data.getTexture();
		return raw != null && TextureLifetime.record(raw).references > 0;
	}
	public function new() { super(); }
	/** 归还上次借用，再借出尺寸、有效性、代次均正确且没有读取者的目标。 */
	override public function clear():Void {
		dispose();
		var width:Int = Math.ceil(Hxmaker.engine.stageWidth);
		var height:Int = Math.ceil(Hxmaker.engine.stageHeight);
		var selected:StageBitmapEntry = null;
		for (entry in pool) {
			if (entry.borrowed || isRead(entry)) continue;
			if (entry.generation != TextureLifetime.generation() || entry.bitmap.width != width || entry.bitmap.height != height
				|| !cast(entry.bitmap.data, OpenFlBitmapData).isAvailable()) continue;
			selected = entry; break;
		}
		// 清理无效空闲条目，避免尺寸变化后留下无法复用的池尾部。
		var index:Int = pool.length;
		while (index-- > 0) {
			var entry:StageBitmapEntry = pool[index];
			if (!entry.borrowed && !isRead(entry) && (entry.generation != TextureLifetime.generation()
				|| entry.bitmap.width != width || entry.bitmap.height != height || !cast(entry.bitmap.data, OpenFlBitmapData).isAvailable())) {
				pool.splice(index, 1); entry.bitmap.dispose();
			}
		}
		if (selected == null) { selected = createEntry(); pool.push(selected); }
		selected.borrowed = true;
		lease = new StageBitmapLease(selected);
		data = lease;
		super.clear();
	}
	/** 借用者释放只归还令牌；池拥有者负责最终销毁。 */
	override public function dispose():Void { super.dispose(); lease = null; }
}

/** 池条目显式区分借用和退役状态。 */
private class StageBitmapEntry {
	public var bitmap:BitmapData;
	public var borrowed:Bool = false;
	public var retired:Bool = false;
	public var generation:Int;
	public function new(bitmap:BitmapData) { this.bitmap = bitmap; generation = TextureLifetime.generation(); }
}

/** 不具有底层资源释放权的借用令牌。 */
private class StageBitmapLease implements IBitmapData {
	private var entry:StageBitmapEntry;
	public function new(entry:StageBitmapEntry) { this.entry = entry; }
	public function getTexture():Dynamic { return entry == null ? null : entry.bitmap.data.getTexture(); }
	public function getWidth():Int { return entry == null ? 0 : Std.int(entry.bitmap.width); }
	public function getHeight():Int { return entry == null ? 0 : Std.int(entry.bitmap.height); }
	public function clear(?rect:hx.geom.Rectangle):Void { if (entry != null) entry.bitmap.data.clear(rect); }
	public function draw(source:hx.display.DisplayObject, matrix:hx.geom.Matrix, ?blendMode:hx.display.BlendMode, updateTransform:Bool = true):Void {
		if (entry != null) entry.bitmap.data.draw(source, matrix, blendMode, updateTransform);
	}
	/** 最后一个借用视图归还后，退役条目才交还底层所有权。 */
	public function dispose():Void {
		if (entry == null) return;
		entry.borrowed = false;
		if (entry.retired) entry.bitmap.dispose();
		entry = null;
	}
}
