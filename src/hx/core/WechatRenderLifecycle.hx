package hx.core;

/** 微信激活事件沿用适配层的 focus/blur 转发，只补充可配对移除的内存告警。 */
class WechatRenderLifecycle {
	private var api:Dynamic;
	private var memoryCallback:Dynamic;
	public var registered(default, null):Bool = false;
	/** 必须同时具备注册和移除能力，避免引擎重建后遗留监听器。 */
	public function new(engine:Engine) {
		#if (js && wechat_zygame_dom)
		api = js.Syntax.code("typeof wx !== 'undefined' ? wx : null");
		if (api == null || !Reflect.isFunction(Reflect.field(api, "onMemoryWarning"))
			|| !Reflect.isFunction(Reflect.field(api, "offMemoryWarning"))) return;
		memoryCallback = function(event:Dynamic):Void { engine.requestMemorySweep(); };
		Reflect.callMethod(api, Reflect.field(api, "onMemoryWarning"), [memoryCallback]);
		registered = true;
		#end
	}
	/** 幂等解除，不调用 triggerGC 代替 GPU 资源治理。 */
	public function dispose():Void {
		if (!registered) return;
		Reflect.callMethod(api, Reflect.field(api, "offMemoryWarning"), [memoryCallback]);
		registered = false; memoryCallback = null; api = null;
	}
}
