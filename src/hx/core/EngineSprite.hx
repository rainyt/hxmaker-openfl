package hx.core;

import openfl.display.DisplayObjectContainer;
import openfl.display.Sprite;
import lime.graphics.RenderContext;
import hx.render2d.openfl.DisplayContextBridge;

@:access(openfl.display.DisplayObjectContainer)
@:access(openfl.display3D.Context3D)
class EngineSprite extends Sprite {
	public var isPool = true;
	private var renderContext:RenderContext;

	public function new() {
		super();
	}

	/** 在对象重新入池前，完成旧容器的延迟清理，释放历史子对象引用。 */
	@:allow(hx.core.Render)
	private static function cleanupRemovedChildren(container:DisplayObjectContainer):Void {
		container.__cleanupRemovedChildren();
	}

	/** 闲置池对象不一定出现在恢复时的显示树中，复用时再检查设备。 */
	@:allow(hx.core.Render)
	private function prepareContext():Void {
		var stage:openfl.display.Stage = openfl.Lib.current.stage;
		var current:RenderContext = stage.context3D == null ? null : stage.context3D.__context;
		if (current == renderContext) return;
		DisplayContextBridge.invalidate(this);
		renderContext = current;
	}
}
