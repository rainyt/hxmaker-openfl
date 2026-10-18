package hx.core;

import openfl.display.DisplayObjectContainer;
import openfl.display.Sprite;

@:access(openfl.display.DisplayObjectContainer)
class EngineSprite extends Sprite {
	public var isPool = true;

	public function new() {
		super();
	}

	/** 在对象重新入池前，完成旧容器的延迟清理，释放历史子对象引用。 */
	@:allow(hx.core.Render)
	private static function cleanupRemovedChildren(container:DisplayObjectContainer):Void {
		container.__cleanupRemovedChildren();
	}
}
