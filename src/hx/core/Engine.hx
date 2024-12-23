package hx.core;

import hx.utils.ContextStats;
import openfl.geom.Rectangle;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import hx.utils.ScaleUtils;
import haxe.Timer;
import openfl.events.Event;
import hx.display.Stage;
import openfl.display.Sprite;

/**
 * OpenFL引擎上的引擎
 */
@:access(hx.display.Stage)
class Engine extends Sprite implements IEngine {
	@:noCompletion private var __stageWidth:Float = 0;

	@:noCompletion private var __stageHeight:Float = 0;

	/**
	 * 舞台对象
	 */
	public var render:Stage;

	/**
	 * 初始化引擎入口类
	 * @param mainClasses 
	 */
	public function init(mainClasses:Class<Stage>, stageWidth:Int, stageHeight:Int):Void {
		this.render = Type.createInstance(mainClasses, []);
		this.render.__render = new hx.core.Render(this);
		// 舞台尺寸计算
		__stageWidth = stageWidth;
		__stageHeight = stageHeight;
		// 帧渲染事件
		this.addEventListener(Event.ENTER_FRAME, __onRenderEnterFrame);
		this.stage.addEventListener(Event.RESIZE, __onStageSizeEvent);
		__lastTime = Timer.stamp();
		__onStageSizeEvent(null);
		this.render.onStageInit();
		// 鼠标事件
		__initMouseEvent();
	}

	private function __onStageSizeEvent(e:Event):Void {
		var scale = ScaleUtils.mathScale(this.stage.stageWidth, this.stage.stageHeight, __stageWidth, __stageHeight);
		this.scaleX = this.scaleY = scale;
		render.__stageWidth = Std.int(this.stage.stageWidth / scale);
		render.__stageHeight = Std.int(this.stage.stageHeight / scale);
		render.dispatchEvent(new hx.events.Event(hx.events.Event.RESIZE));
		trace("Stage size and scale:", render.stageWidth, render.stageHeight, scale);
		this.scrollRect = new Rectangle(0, 0, render.__stageWidth, render.stageHeight);
	}

	private var __lastTime:Float = 0;

	private var __lastMouseX = 0.;

	private var __lastMouseY = 0.;

	private function __onRenderEnterFrame(e:Event):Void {
		ContextStats.statsCpuStart();
		var now = Timer.stamp();
		var dt = now - __lastTime;
		__lastTime = now;
		this.render.onUpdate(dt);
		ContextStats.reset();
		this.render.render();
		ContextStats.statsCpu();
	}

	private function __initMouseEvent():Void {
		this.stage.addEventListener(MouseEvent.MOUSE_DOWN, __onMouseEvent);
		this.stage.addEventListener(MouseEvent.MOUSE_UP, __onMouseEvent);
		this.stage.addEventListener(MouseEvent.MOUSE_WHEEL, __onMouseEvent);
		this.stage.addEventListener(MouseEvent.MOUSE_MOVE, __onMouseEvent);
		this.stage.addEventListener(KeyboardEvent.KEY_DOWN, __onKeyboardEvent);
		this.stage.addEventListener(KeyboardEvent.KEY_UP, __onKeyboardEvent);
	}

	private function __onKeyboardEvent(e:KeyboardEvent):Void {
		var engineEvent:hx.events.KeyboardEvent = new hx.events.KeyboardEvent(e.type);
		engineEvent.keyCode = e.keyCode;
		render.handleKeyboardEvent(engineEvent);
	}

	private function __onMouseEvent(e:MouseEvent):Void {
		var engineEvent:hx.events.MouseEvent = new hx.events.MouseEvent(e.type);
		engineEvent.stageX = this.mouseX;
		engineEvent.stageY = this.mouseY;
		render.handleMouseEvent(engineEvent);
		switch e.type {
			case MouseEvent.MOUSE_DOWN:
				__lastMouseX = this.mouseX;
				__lastMouseY = this.mouseY;
			case MouseEvent.MOUSE_UP:
				// 判断距离
				if (Math.sqrt(Math.pow(__lastMouseX - this.mouseX, 2) + Math.pow(__lastMouseY - this.mouseY, 2)) < 10) {
					var engineEvent:hx.events.MouseEvent = new hx.events.MouseEvent(hx.events.MouseEvent.CLICK);
					engineEvent.stageX = this.mouseX;
					engineEvent.stageY = this.mouseY;
					render.handleMouseEvent(engineEvent);
				}
		}
	}

	/**
	 * 释放引擎
	 */
	public function dispose():Void {
		// 删除所有跟stage有关的事件
		this.stage.removeEventListener(Event.ENTER_FRAME, __onRenderEnterFrame);
		this.stage.removeEventListener(Event.RESIZE, __onStageSizeEvent);
		this.stage.removeEventListener(MouseEvent.MOUSE_DOWN, __onMouseEvent);
		this.stage.removeEventListener(MouseEvent.MOUSE_UP, __onMouseEvent);
		this.stage.removeEventListener(MouseEvent.MOUSE_WHEEL, __onMouseEvent);
		this.stage.removeEventListener(MouseEvent.MOUSE_MOVE, __onMouseEvent);
		this.stage.removeEventListener(KeyboardEvent.KEY_DOWN, __onKeyboardEvent);
		this.stage.removeEventListener(KeyboardEvent.KEY_UP, __onKeyboardEvent);
	}
}
