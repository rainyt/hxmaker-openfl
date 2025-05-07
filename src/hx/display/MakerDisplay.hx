package hx.display;

import haxe.Timer;
import openfl.Lib;
import openfl.events.Event;
import openfl.geom.Rectangle;
import hx.core.Render;
import hx.core.Engine;

/**
 * hxmaker渲染器
 */
@:access(hx.display.Stage)
class MakerDisplay extends openfl.display.Sprite {
	/**
	 * 渲染器
	 */
	public var renderer:Render = new Render();

	/**
	 * 容器
	 */
	public var container:Stage = new Stage();

	public function new(width:Float = 0, height:Float = 0) {
		super();
		if (width == 0 || height == 0) {
			width = Lib.current.stage.stageWidth;
			height = Lib.current.stage.stageHeight;
		}
		container.__stageWidth = width;
		container.__stageHeight = height;
		this.scrollRect = new Rectangle(0, 0, width, height);
		this.addChild(renderer.stage);
		container.onStageInit();
		__time = Timer.stamp();
	}

	private var __time:Float = 0;

	override private function __enterFrame(deltaTime:Int):Void {
		var now:Float = Timer.stamp();
		var currentDeltaTime:Float = now - __time;
		__time = now;
		container.onUpdate(currentDeltaTime);
		if (container.__dirty) {
			renderer.clear();
			container.__updateTransform(container);
			renderer.renderDisplayObjectContainer(container);
			container.__dirty = false;
			renderer.endFill();
		}
	}

	override private function set_width(value:Float):Float {
		container.__stageWidth = value;
		this.scrollRect = new Rectangle(0, 0, value, height);
		return super.set_width(value);
	}

	override private function set_height(value:Float):Float {
		container.__stageHeight = value;
		this.scrollRect = new Rectangle(0, 0, width, value);
		return super.set_height(value);
	}

	override function addChildAt(child:openfl.display.DisplayObject, index:Int):openfl.display.DisplayObject {
		if (child != renderer.stage) {
			throw "Use container.addChildAt() instead of MakerDisplay.addChildAt()";
		} else {
			return super.addChildAt(child, index);
		}
	}

	override private function get_width():Float {
		return container.__stageWidth;
	}

	override private function get_height():Float {
		return container.__stageHeight;
	}
}
