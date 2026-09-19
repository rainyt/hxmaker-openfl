package hx.text;

import hx.display.Label;
import hx.render.TextFieldRender;

/**
 * 文本渲染队列处理，每次文本添加到、或者移除舞台时，都会更新此队列。
 * 该队列提供给正式渲染之前，将文本动态渲染正确处理。
 *
 * 动态纹理字渲染的图集是一组共享纹理，而渲染遍历只负责构建顶点/UV，
 * 真正的采样会推迟到后端自己的渲染 pass 中。因此在渲染遍历途中改写图集，
 * 会让本帧所有已经入队的顶点读到错误的内容。
 *
 * 该队列把本帧所有文本变动收集起来，在`prepare`阶段（引擎清屏之前）统一写入图集，
 * 使渲染阶段不再需要写图集。图集写满时只会追加一张新的纹理，**永远不会改写已经写好的字形**，
 * 所以渲染阶段唯一要做的事情就是提交绘制。
 *
 * 由此，队列也是"文本是否需要重写"的唯一权威来源：文本内容相同不代表字形还有效
 * （图集可能已经被替换、释放），`TextFieldRender.render`依赖`isPending`与
 * `Text.prepared`判断某个文本本帧能不能直接绘制，所以文本变动之后必须入队。
 */
class TextFieldQueue {
	/**
	 * 舞台上驻留的文本对象
	 */
	private static var __resident:Array<Label> = [];

	/**
	 * 驻留登记表，保证`add`/`remove`的幂等性
	 */
	private static var __residentMap:Map<Label, Bool> = new haxe.ds.ObjectMap();

	/**
	 * 本帧文本发生变动的文本对象，等待`prepare`写入图集
	 */
	private static var __pending:Array<Label> = [];

	/**
	 * 待写登记表，保证同一个文本对象在同一帧内只入队一次
	 */
	private static var __pendingMap:Map<Label, Bool> = new haxe.ds.ObjectMap();

	/**
	 * 当前是否处于渲染遍历中
	 */
	private static var __rendering:Bool = false;

	/**
	 * 标记进入渲染遍历。渲染期间不允许写图集，见`isRendering`
	 */
	public static function beginRender():Void {
		__rendering = true;
	}

	/**
	 * 标记离开渲染遍历
	 */
	public static function endRender():Void {
		__rendering = false;
	}

	/**
	 * 是否处于渲染遍历中。
	 *
	 * 渲染遍历只负责构建顶点与 UV，纹理采样推迟到后端自己的渲染 pass，
	 * 所以遍历途中写图集会让本帧已经入队的顶点全部失效。
	 * 渲染器在开始渲染前调用`beginRender`，写入统一由`prepare`在渲染前完成。
	 */
	public static function isRendering():Bool {
		return __rendering;
	}

	/**
	 * 文本对象添加到舞台时调用
	 * @param label 文本对象
	 */
	public static function add(label:Label):Void {
		if (label == null)
			return;
		if (__residentMap.exists(label)) {
			// 已经在队列中，只需要确保它会被重新写入
			invalidate(label);
			return;
		}
		__residentMap.set(label, true);
		__resident.push(label);
		// 首次上舞台时，它的字符可能还没有写入图集
		invalidate(label);
	}

	/**
	 * 文本对象从舞台移除时调用，该方法为幂等操作
	 * @param label 文本对象
	 */
	public static function remove(label:Label):Void {
		if (label == null)
			return;
		if (!__residentMap.exists(label))
			return;
		__residentMap.remove(label);
		__resident.remove(label);
		// 离场后不再需要预写
		drop(label);
	}

	/**
	 * 文本内容或者文本格式发生变动时调用，仅对舞台上驻留的文本生效。
	 *
	 * 离屏文本（只在测量宽度、或者由`renderLabel`单独绘制的文本）不入队，
	 * 它会在需要时由`TextFieldRender.render`就地构建布局。
	 * @param label 文本对象
	 */
	public static function invalidate(label:Label):Void {
		if (label == null)
			return;
		if (!__residentMap.exists(label))
			return;
		push(label);
	}

	/**
	 * 让所有驻留的文本重新写入图集。
	 *
	 * 图集被替换或者释放之后必须调用：此时文本内容没有变、字形却已经失效，
	 * 只靠内容比对是察觉不到的，文本会一直渲染成空白。
	 */
	public static function invalidateAll():Void {
		for (label in __resident) {
			push(label);
		}
	}

	/**
	 * 该文本是否需要重新写入图集
	 * @param label 文本对象
	 */
	public static function isPending(label:Label):Bool {
		return label != null && __pendingMap.exists(label);
	}

	/**
	 * 获得舞台上驻留的文本对象列表
	 */
	public static function getResident():Array<Label> {
		return __resident;
	}

	/**
	 * 正式渲染之前调用，把本帧所有变动的文本预写进图集。
	 *
	 * 预写只做两件事：把字形写进图集、构建文本布局。图集写满时追加新纹理，
	 * 不会让其他文本重新变脏，所以这里一轮迭代就够了。
	 */
	public static function prepare():Void {
		// 复位渲染标记：渲染器若在渲染途中抛异常，可能来不及调用`endRender`，
		// 这里每帧兜底一次，避免标记残留导致后续所有写入都被推迟
		__rendering = false;
		if (__pending.length == 0)
			return;
		// 先快照再清空，避免预写过程中产生的入队被本轮重复处理
		var list = __pending;
		__pending = [];
		__pendingMap = new haxe.ds.ObjectMap();
		for (label in list) {
			TextFieldRender.prepareLabel(label);
		}
	}

	/**
	 * 入队
	 */
	private static function push(label:Label):Void {
		if (__pendingMap.exists(label))
			return;
		__pendingMap.set(label, true);
		__pending.push(label);
	}

	/**
	 * 出队
	 */
	private static function drop(label:Label):Void {
		if (!__pendingMap.exists(label))
			return;
		__pendingMap.remove(label);
		__pending.remove(label);
	}

	/**
	 * 获得当前待写的文本数量，用于调试
	 */
	public static var pendingCount(get, never):Int;

	private static function get_pendingCount():Int {
		return __pending.length;
	}

	/**
	 * 获得当前驻留的文本数量，用于调试
	 */
	public static var residentCount(get, never):Int;

	private static function get_residentCount():Int {
		return __resident.length;
	}

	/**
	 * 清空队列，一般用于引擎销毁时
	 */
	public static function reset():Void {
		__resident = [];
		__residentMap = new haxe.ds.ObjectMap();
		__pending = [];
		__pendingMap = new haxe.ds.ObjectMap();
	}
}
