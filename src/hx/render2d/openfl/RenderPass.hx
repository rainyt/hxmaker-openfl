package hx.render2d.openfl;

import openfl.display.BitmapData;

/** 仅保留当前调用栈的输出目标，用于嵌套离屏和反馈检测。 */
class RenderPass {
	private static var targets:Array<BitmapData> = [];
	private static var ids:Array<Int> = [];
	private static var nextId:Int = 0;
	/** 当前同步 Pass 编号，零表示主显示树。 */
	public static function currentId():Int { return ids.length == 0 ? 0 : ids[ids.length - 1]; }
	public static var depth(get, never):Int;
	private static function get_depth():Int { return targets.length; }
	/** 推入输出；禁止递归向同一目标绘制。 */
	public static function push(bitmap:BitmapData):Void {
		if (contains(bitmap)) throw new TextureInputError(Feedback, TextureLifetime.record(bitmap).resourceId, "离屏输出", "不能递归写入相同离屏目标");
		if (targets.length >= 16) throw new TextureInputError(Unsupported, 0, "离屏输出", "嵌套离屏深度超过十六层预算");
		targets.push(bitmap); ids.push(++nextId);
	}
	/** 结束一次调用后立即清除输出强引用。 */
	public static function pop():Void { targets.pop(); ids.pop(); }
	/** 常数上限的 Pass 栈检查，不扫描显示树或缓存。 */
	public static function contains(bitmap:BitmapData):Bool { return targets.indexOf(bitmap) >= 0; }
}
