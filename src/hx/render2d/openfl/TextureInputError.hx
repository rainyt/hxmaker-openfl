package hx.render2d.openfl;

/** 二维输入故障分类，不以错误字符串决定渲染策略。 */
enum abstract TextureFaultKind(String) to String {
	var Disposed = "disposed";
	var InvalidSize = "invalidSize";
	var NotReady = "notReady";
	var DeviceLost = "deviceLost";
	var UploadFailed = "uploadFailed";
	var Unsupported = "unsupported";
	var Feedback = "feedback";
	var MissingRecovery = "missingRecovery";
}

/** 预期的资源故障，仅包含诊断标量。 */
class TextureInputError extends haxe.Exception {
	public var kind(default, null):TextureFaultKind;
	public var resourceId(default, null):Int;
	public var inputName(default, null):String;
	/** 创建类型明确的输入错误。 */
	public function new(kind:TextureFaultKind, resourceId:Int, inputName:String, message:String) {
		super(message); this.kind = kind; this.resourceId = resourceId; this.inputName = inputName;
	}
}
