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
	public var container:DisplayObjectContainer = new DisplayObjectContainer();

	public function new(width:Float, height:Float) {
		super();
		this.scrollRect = new Rectangle(0, 0, width, height);
		this.addChild(renderer.stage);
	}

	override private function __enterFrame(deltaTime:Int):Void {
		@:privateAccess container.__updateTransform(container);
		renderer.clear();
		renderer.renderDisplayObjectContainer(container);
		renderer.endFill();
	}
}
