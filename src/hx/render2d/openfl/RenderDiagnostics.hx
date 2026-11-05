package hx.render2d.openfl;

/** 有上限的发布诊断，不强引用资源；同类故障只保留首次上下文及累计次数。 */
class RenderDiagnostics {
	public static var strict:Bool = #if hxmaker_render_strict true #else false #end;
	public static var faults(default, null):Int = 0;
	public static var skipped(default, null):Int = 0;
	public static var drawn(default, null):Int = 0;
	public static var onFault:Dynamic->Void;
	private static var reports:Array<Dynamic> = [];
	private static var keys:Array<String> = [];
	private static var events:Array<Dynamic> = [];
	/** 记录完成的健康批次。 */
	public static function didDraw():Void { drawn++; }
	/** 聚合局部故障；业务可订阅结构化首报，不逐帧刷日志。 */
	public static function report(batch:DirectBatchDisplay, error:TextureInputError):Void {
		var shader:String = batch.shaderBuffer == null || batch.shaderBuffer.shader == null ? "直接合批" : Type.getClassName(Type.getClass(batch.shaderBuffer.shader));
		var key:String = error.kind + ":" + error.resourceId + ":" + shader + ":" + error.inputName;
		store(key, {kind:error.kind, resourceId:error.resourceId, input:error.inputName,
			batchId:batch.batchId, shader:shader, generation:TextureLifetime.generation(),
			message:sanitize(error.message), revision:batch.revision, passId:RenderPass.currentId(), count:1, at:haxe.Timer.stamp(), resources:batch.resourceReport()});
	}
	/** 滤镜的分配失败也按视觉单元隔离，不能拖垮健康显示对象。 */
	public static function reportFilter(filter:hx.filters.RenderFilter, error:TextureInputError):Void {
		var name:String = Type.getClassName(Type.getClass(filter));
		store(error.kind + ":filter:" + name + ":" + error.inputName, {kind:error.kind, resourceId:error.resourceId,
			input:error.inputName, filter:name, batchId:0, generation:TextureLifetime.generation(),
			message:sanitize(error.message), passId:RenderPass.currentId(), count:1, at:haxe.Timer.stamp(), resources:[]});
	}
	/** 环形首报记录，重复错误只增加标量计数。 */
	private static function store(key:String, entry:Dynamic):Void {
		faults++; skipped++;
		var index:Int = keys.indexOf(key);
		if (index >= 0) { reports[index].count++; return; }
		if (keys.length == 64) { keys.shift(); reports.shift(); }
		keys.push(key); reports.push(entry);
		if (onFault != null) onFault(entry);
	}
	/** 详细引用变化只在显式诊断构建启用，发布热路径通过内联完全移除。 */
	public static inline function lifecycle(action:String, state:TextureLifetime.TextureRecord, batchId:Int):Void {
		#if hxmaker_render_debug
		if (events.length == 128) events.shift();
		events.push({action:action, resourceId:state.resourceId, batchId:batchId, references:state.references,
			pending:state.pending, disposed:state.disposed, reason:state.releaseReason, at:haxe.Timer.stamp(), generation:state.generation});
		#end
	}

	/** 查询参数可能含凭据；发布记录去除查询串并限制单条长度。 */
	public static function sanitize(value:String):String {
		if (value == null) return "";
		var pattern:EReg = ~/https?:\/\/[^\s?#]+[?#][^\s]*/g;
		return pattern.map(value, function(match:EReg):String { return match.matched(0).split("?")[0].split("#")[0]; }).substr(0, 1024);
	}

	/** 返回无资源引用的诊断副本。 */
	public static function snapshot():Dynamic {
		return {buildId:hx.utils.RenderBuildInfo.buildId, faults:faults, skipped:skipped, drawn:drawn, references:TextureLifetime.references,
			pendingDisposals:TextureLifetime.pendingDisposals, physicalDisposals:TextureLifetime.physicalDisposals,
			events:events.copy(), reports:haxe.Json.parse(haxe.Json.stringify(reports))};
	}
}
