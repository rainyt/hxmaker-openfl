package hx.display;

import hx.core.Hxmaker;
import haxe.Timer;
import openfl.Lib;
import openfl.events.Event;
import openfl.geom.Rectangle;
import hx.core.Render;
import hx.core.Engine;

/**
 * hxmaker渲染器
 */
@:keep
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
		this.addEventListener(Event.ADDED_TO_STAGE, onAddToStage);
		this.addEventListener(Event.REMOVED_FROM_STAGE, onRemoveFromStage);
		container.customRender = true;
		// this.mouseChildren = false;
	}

	private function onAddToStage(event:Event):Void {
		Hxmaker.engine.addToStage(container);
	}

	private function onRemoveFromStage(event:Event):Void {
		Hxmaker.engine.removeToStage(container);
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
			renderer.renderDisplayObject(container);
			container.__dirty = false;
			renderer.endFill();
		}
	}

	override private function set_width(value:Float):Float {
		container.__stageWidth = value;
		this.scrollRect = new Rectangle(0, 0, value, height);
		return value;
	}

	override private function set_height(value:Float):Float {
		container.__stageHeight = value;
		this.scrollRect = new Rectangle(0, 0, width, value);
		return value;
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

	#if !flash
	/**
	 * 重写触摸事件，用于实现在TouchImageBatchsContainer状态中，允许穿透点击
	 * @param x 
	 * @param y 
	 * @param shapeFlag 
	 * @param stack 
	 * @param interactiveOnly 
	 * @param hitObject 
	 * @return Bool
	 */
	override private function __hitTest(x:Float, y:Float, shapeFlag:Bool, stack:Array<openfl.display.DisplayObject>, interactiveOnly:Bool,
			hitObject:openfl.display.DisplayObject):Bool {
		if (!hitObject.visible || width == 0 || height == 0 || !this.mouseEnabled)
			return false;
		if (mask != null && !mask.__hitTestMask(x, y))
			return false;

		__getRenderTransform();
		var px = @:privateAccess __renderTransform.__transformInverseX(x, y);
		var py = @:privateAccess __renderTransform.__transformInverseY(x, y);
		if (px > 0 && py > 0 && px <= this.width && py <= this.height) {
			if (__scrollRect != null && !__scrollRect.contains(px, py)) {
				return false;
			}

			if (container.hitTestWorldPoint(this.mouseX, this.mouseY)) {
				if (stack != null && !interactiveOnly) {
					stack.push(hitObject);
				}

				var childTouch = super.__hitTest(x, y, false, stack, interactiveOnly, hitObject);
				if (!childTouch) {
					if (stack != null)
						stack.push(this);
					return true;
				}
				return childTouch;
			} else {
				return false;
			}
		}

		return false;
	}
	#end
}
