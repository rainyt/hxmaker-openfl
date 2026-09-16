package hx.text;

import hx.display.Label;
import hx.render.TextFieldRender;

/**
 * 文本渲染队列处理，每次文本添加到、或者移除舞台时，都会更新此队列。
 * 该队列提供给正式渲染之前，将文本动态渲染正确处理。
 *
 * 动态纹理字渲染的图集是一张会被原地改写的共享纹理，而渲染遍历只负责构建顶点/UV，
 * 真正的采样会推迟到后端自己的渲染 pass 中。因此在渲染遍历途中改写图集（尤其是图集写满
 * 后触发的整张重排），会让本帧所有已经入队的顶点读到错误的内容。
 *
 * 该队列把本帧所有文本变动收集起来，在`prepare`阶段（引擎清理画面前）统一写入图集，
 * 使渲染阶段不再需要写图集，从而让图集重排永远只发生在安全区内。
 */
class TextFieldQueue {
	/**
	 * 舞台上驻留的文本对象，按`textCacheId`分组
	 */
	private static var __resident:Map<Int, Array<Label>> = [];

	/**
	 * 驻留登记表，记录文本对象使用的`textCacheId`，用于保证`add`/`remove`的幂等性
	 */
	private static var __residentMap:Map<Label, Int> = new haxe.ds.ObjectMap();

	/**
	 * 本帧文本发生变动的文本对象，按`textCacheId`分组
	 */
	private static var __pending:Map<Int, Array<Label>> = [];

	/**
	 * 待写登记表，用于避免同一个文本对象重复入队
	 */
	private static var __pendingMap:Map<Label, Int> = new haxe.ds.ObjectMap();

	/**
	 * 空的驻留列表，避免`getResident`每次都创建新数组
	 */
	private static var __emptyResident:Array<Label> = [];

	/**
	 * 单次`prepare`最多迭代的次数，用于兜底防止图集重排反复触发导致死循环
	 */
	private static var __maxPrepareLoop:Int = 4;

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
	 * 所以遍历途中写图集（尤其是写满后触发的整张重排）会让本帧已经入队的顶点全部失效。
	 * 渲染器在开始渲染前调用`beginRender`，渲染期间所有图集写入都会推迟到下一次`prepare`。
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
		var cacheId = label.textCacheId;
		if (__residentMap.exists(label)) {
			if (__residentMap.get(label) == cacheId) {
				// 已经在队列中，只需要确保它会被重新写入
				invalidate(label);
				return;
			}
			// 切换过缓存器，先摘掉旧的登记
			remove(label);
		}
		__residentMap.set(label, cacheId);
		var list = __resident[cacheId];
		if (list == null) {
			list = [];
			__resident[cacheId] = list;
		}
		list.push(label);
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
		var cacheId = __residentMap.get(label);
		__residentMap.remove(label);
		var list = __resident[cacheId];
		if (list != null)
			list.remove(label);
		// 离场后不再需要预写
		if (__pendingMap.exists(label)) {
			__pendingMap.remove(label);
			var pending = __pending[cacheId];
			if (pending != null)
				pending.remove(label);
		}
	}

	/**
	 * 文本内容或者文本格式发生变动时调用，仅对舞台上驻留的文本生效
	 * @param label 文本对象
	 */
	public static function invalidate(label:Label):Void {
		if (label == null)
			return;
		if (!__residentMap.exists(label))
			return;
		if (__pendingMap.exists(label))
			return;
		var cacheId = label.textCacheId;
		__pendingMap.set(label, cacheId);
		var list = __pending[cacheId];
		if (list == null) {
			list = [];
			__pending[cacheId] = list;
		}
		list.push(label);
	}

	/**
	 * 获得指定缓存器上驻留的文本对象列表，用于图集重排时的重建名单
	 * @param cacheId 文本缓存id
	 * @return Array<Label>
	 */
	public static function getResident(cacheId:Int):Array<Label> {
		var list = __resident[cacheId];
		return list == null ? __emptyResident : list;
	}

	/**
	 * 正式渲染之前调用，把本帧所有变动的文本预写进图集。
	 *
	 * 预写过程中图集可能写满并触发整张重排，重排会把所有驻留文本重新标记为待写，
	 * 因此这里需要循环处理，直到没有新的待写文本为止。
	 */
	public static function prepare():Void {
		// 复位渲染标记：渲染器若在渲染途中抛异常，可能来不及调用`endRender`，
		// 这里每帧兜底一次，避免标记残留导致后续所有写入都被推迟
		__rendering = false;
		var loop = 0;
		// `Map.keys()`返回的迭代器在调用`next()`前`hasNext()`是有效的，这里用它判断是否还有待写文本
		while (__pendingMap.keys().hasNext() && loop < __maxPrepareLoop) {
			loop++;
			// 先快照并清空，避免预写过程中产生的入队被本轮重复处理
			var list = __pending;
			__pending = [];
			__pendingMap = new haxe.ds.ObjectMap();
			for (cacheId in list.keys()) {
				var labels = list[cacheId];
				if (labels == null)
					continue;
				for (label in labels) {
					TextFieldRender.prepareLabel(label);
				}
			}
		}
	}

	/**
	 * 获得当前待写的文本数量，用于调试
	 */
	public static var pendingCount(get, never):Int;

	private static function get_pendingCount():Int {
		var count = 0;
		for (cacheId in __pending.keys()) {
			var labels = __pending[cacheId];
			if (labels != null)
				count += labels.length;
		}
		return count;
	}

	/**
	 * 获得当前驻留的文本数量，用于调试
	 */
	public static var residentCount(get, never):Int;

	private static function get_residentCount():Int {
		var count = 0;
		var keys = __residentMap.keys();
		while (keys.hasNext()) {
			keys.next();
			count++;
		}
		return count;
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
