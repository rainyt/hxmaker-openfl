package hx.render3d.openfl;

import lime.graphics.WebGLRenderContext;

/** 浏览器支持时隔离三维顶点输入；其他平台保持原有逐属性保护。 */
class VertexArrayBridge3D {
	public var available(default, null):Bool = false;
	public var webgl2(default, null):Bool = false;
	public var bindingEnum(default, null):Int = 0x85B5;
	private var api:Dynamic;
	private var extension:Bool = false;
	private var objects:Map<String, Dynamic> = [];
	public function new(gl:WebGLRenderContext, webgl2:Bool) {
		#if (js && html5)
		var raw:Dynamic = cast gl;
		this.webgl2 = webgl2;
		#if (!hxmaker_3d_legacy_state_guard && !hxmaker_3d_no_vao)
		if (webgl2 && Reflect.isFunction(Reflect.field(raw, "createVertexArray"))) { api = raw; available = true; }
		else {
			api = gl.getExtension("OES_vertex_array_object");
			extension = api != null; available = extension;
		}
		#end
		#end
	}
	public function bind(name:String):Void {
		if (!available) return;
		var object = objects.get(name);
		if (object == null) {
			object = extension ? api.createVertexArrayOES() : api.createVertexArray();
			if (object == null) throw "无法创建三维顶点输入对象";
			objects.set(name, object);
		}
		restore(object);
	}
	public function restore(object:Dynamic):Void {
		if (!available) return;
		if (extension) api.bindVertexArrayOES(object); else api.bindVertexArray(object);
	}
	public function dispose():Void {
		if (available) for (object in objects) {
			if (extension) api.deleteVertexArrayOES(object); else api.deleteVertexArray(object);
		}
		abandon();
	}
	/** 上下文丢失后不再向旧设备提交删除调用。 */
	public function abandon():Void { objects.clear(); api = null; available = false; }
}
