package hx.display;

import openfl.events.Event;
import openfl.geom.Rectangle;
import hx.core.Render;
import hx.core.Engine;

/**
 * hxmaker渲染器
 */
class MakerDisplay extends openfl.display.Sprite {
	/**
	 * 渲染器
	 */
	public var renderer:Render = new Render();

	/**
	 * 容器
	 */
	public var container:Stage = new Stage();

	public function new(width:Float, height:Float) {
		super();
		@:privateAccess container.__stageWidth = width;
		@:privateAccess container.__stageHeight = height;
		this.scrollRect = new Rectangle(0, 0, width, height);
		this.addChild(renderer.stage);
		container.onStageInit();
	}

	override private function __enterFrame(deltaTime:Int):Void {
		container.onUpdate(deltaTime / 1000);
		if (@:privateAccess container.__dirty) {
			renderer.clear();
			@:privateAccess container.__updateTransform(container);
			renderer.renderDisplayObjectContainer(container);
			@:privateAccess container.__dirty = false;
			renderer.endFill();
		}
	}
}
