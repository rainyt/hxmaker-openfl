package hx.core;

import hx.gemo.Matrix;
import hx.display.DisplayObjectContainer;
import hx.display.IRender;
import openfl.Lib;
import openfl.system.System;
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
@:access(hx.display.DisplayObjectContainer)
@:access(hx.display.Stage)
class Engine implements IEngine {
	@:noCompletion private var __stageWidth:Float = 0;

	@:noCompletion private var __stageHeight:Float = 0;

	public var touchX:Float = 0;

	public var touchY:Float = 0;

	public function new() {}

	/**
	 * 渲染
	 */
	public var renderer:IRender;

	public var stage:openfl.display.Stage;

	/**
	 * 舞台列表
	 */
	public var stages:Array<Stage> = [];

	/**
	 * 添加舞台
	 * @param stage 
	 */
	public function addToStage(stage:Stage):Void {
		if (stages.indexOf(stage) == -1) {
			stages.insert(stages.length - 1, stage);
		}
		stage.__stageWidth = this.stageWidth;
		stage.__stageHeight = this.stageHeight;
		stage.onStageInit();
	}

	/**
	 * 移除舞台
	 * @param stage 
	 */
	public function removeToStage(stage:Stage):Void {
		stages.remove(stage);
	}

	/**
	 * 初始化OpenFL的渲染，避免异常
	 * @param root 
	 */
	public function initOpenFLRoot(root:Sprite):Void {
		root.graphics.beginFill(0x404040, 1);
		root.graphics.drawRect(-1, 0, 1, 1);
		root.graphics.endFill();
	}

	/**
	 * 初始化引擎入口类
	 * @param mainClasses 
	 */
	public function init(stageWidth:Int, stageHeight:Int):Void {
		trace("[HXMAKER] init", stageWidth, stageHeight);
		if (this.stage == null) {
			this.stage = Lib.current.stage;
			// 初始化渲染器
			this.renderer = new hx.core.Render();
			this.stage.addChild(cast(this.renderer, Render).stage);
		}
		// 舞台尺寸计算
		__stageWidth = stageWidth;
		__stageHeight = stageHeight;
		__lastTime = Timer.stamp();
		__onStageSizeEvent(null);
		__initStageEvent();
	}

	private function onAddedToStage(e:Event):Void {
		__onStageSizeEvent(null);
		__initStageEvent();
	}

	private function onRemovedFromStage(e:Event):Void {
		__removeStageEvent();
	}

	/**
	 * 缩放比例
	 */
	public var scaleFactor:Float = 1;

	@:noCompletion private var ____stageWidth:Float = 0;
	@:noCompletion private var ____stageHeight:Float = 0;

	public var stageWidth(get, never):Float;

	private function get_stageWidth():Float {
		return ____stageWidth;
	}

	public var stageHeight(get, never):Float;

	private function get_stageHeight():Float {
		return ____stageHeight;
	}

	private function __onStageSizeEvent(e:Event):Void {
		scaleFactor = ScaleUtils.mathScale(this.stage.stageWidth, this.stage.stageHeight, __stageWidth, __stageHeight);
		____stageWidth = Std.int(this.stage.stageWidth / scaleFactor);
		____stageHeight = Std.int(this.stage.stageHeight / scaleFactor);
		var render = cast(renderer, Render);
		render.stage.scaleX = render.stage.scaleY = scaleFactor;
		for (stage in stages) {
			stage.__stageWidth = this.stageWidth;
			stage.__stageHeight = this.stageHeight;
			stage.dispatchEvent(new hx.events.Event(hx.events.Event.RESIZE));
		}
	}

	private var __lastTime:Float = 0;

	private var __lastMouseX = 0.;

	private var __lastMouseY = 0.;

	private var __time = 1.;

	private function __onRenderEnterFrame(e:Event):Void {
		if (render == null)
			return;
		ContextStats.statsCpuStart();
		var now = Timer.stamp();
		var dt = now - __lastTime;
		__lastTime = now;
		var __dirty = false;
		for (stage in stages) {
			if (!stage.customRender) {
				stage.onUpdate(dt);
				if (stage.__dirty) {
					__dirty = true;
				}
			}
		}
		ContextStats.reset();
		if (__dirty) {
			renderer.clear();
			for (stage in stages) {
				if (!stage.customRender)
					this.render(stage);
			}
			renderer.endFill();
		}
		ContextStats.statsCpu();
		__time += dt;
		if (__time > 1) {
			__time = 0;
			ContextStats.statsMemory(System.totalMemory);
		}
	}

	private function __initStageEvent():Void {
		#if cpp
		this.stage.frameRate = 61;
		#else
		this.stage.frameRate = 60;
		#end
		// 帧渲染事件
		this.stage.addEventListener(Event.ACTIVATE, __onActivate);
		this.stage.addEventListener(Event.DEACTIVATE, __onDeactivate);
		this.stage.addEventListener(Event.ENTER_FRAME, __onRenderEnterFrame);
		this.stage.addEventListener(Event.RESIZE, __onStageSizeEvent);
		this.stage.addEventListener(MouseEvent.MOUSE_DOWN, __onMouseEvent);
		this.stage.addEventListener(MouseEvent.MOUSE_UP, __onMouseEvent);
		this.stage.addEventListener(MouseEvent.MOUSE_WHEEL, __onMouseEvent);
		this.stage.addEventListener(MouseEvent.MOUSE_MOVE, __onMouseEvent);
		this.stage.addEventListener(KeyboardEvent.KEY_DOWN, __onKeyboardEvent);
		this.stage.addEventListener(KeyboardEvent.KEY_UP, __onKeyboardEvent);
	}

	private function __onActivate(e:Event):Void {
		for (stage in stages) {
			stage.onActivate();
		}
	}

	private function __onDeactivate(e:Event):Void {
		for (stage in stages) {
			stage.onDeactivate();
		}
	}

	private function __removeStageEvent():Void {
		this.stage.removeEventListener(Event.ENTER_FRAME, __onRenderEnterFrame);
		this.stage.removeEventListener(Event.RESIZE, __onStageSizeEvent);
		this.stage.removeEventListener(MouseEvent.MOUSE_DOWN, __onMouseEvent);
		this.stage.removeEventListener(MouseEvent.MOUSE_UP, __onMouseEvent);
		this.stage.removeEventListener(MouseEvent.MOUSE_WHEEL, __onMouseEvent);
		this.stage.removeEventListener(MouseEvent.MOUSE_MOVE, __onMouseEvent);
		this.stage.removeEventListener(KeyboardEvent.KEY_DOWN, __onKeyboardEvent);
		this.stage.removeEventListener(KeyboardEvent.KEY_UP, __onKeyboardEvent);
	}

	private function __onKeyboardEvent(e:KeyboardEvent):Void {
		var engineEvent:hx.events.KeyboardEvent = new hx.events.KeyboardEvent(e.type);
		engineEvent.keyCode = e.keyCode;
		for (stage in stages) {
			stage.handleKeyboardEvent(engineEvent);
		}
	}

	private function __onMouseEvent(e:MouseEvent):Void {
		touchX = e.stageX / scaleFactor;
		touchY = e.stageY / scaleFactor;
		var openflRenderer:hx.core.Render = cast this.renderer;
		var engineEvent:hx.events.MouseEvent = new hx.events.MouseEvent(e.type);
		engineEvent.stageX = openflRenderer.stage.mouseX;
		engineEvent.stageY = openflRenderer.stage.mouseY;
		var i = stages.length;

		if (e.type == MouseEvent.MOUSE_WHEEL) {
			engineEvent.delta = e.delta;
		}

		while (i-- > 0) {
			var stage = stages[i];
			if (stage.handleMouseEvent(engineEvent)) {
				break;
			}
		}
		switch e.type {
			case MouseEvent.MOUSE_DOWN:
				__lastMouseX = openflRenderer.stage.mouseX;
				__lastMouseY = openflRenderer.stage.mouseY;
			case MouseEvent.MOUSE_UP:
				// 判断距离
				if (Math.sqrt(Math.pow(__lastMouseX - openflRenderer.stage.mouseX, 2) + Math.pow(__lastMouseY - openflRenderer.stage.mouseY, 2)) < 10) {
					var engineEvent:hx.events.MouseEvent = new hx.events.MouseEvent(hx.events.MouseEvent.CLICK);
					engineEvent.stageX = openflRenderer.stage.mouseX;
					engineEvent.stageY = openflRenderer.stage.mouseY;
					var i = stages.length;
					while (i-- > 0) {
						var stage = stages[i];
						if (stage.handleMouseEvent(engineEvent)) {
							break;
						}
					}
				}
		}
	}

	/**
	 * 释放引擎
	 */
	public function dispose():Void {
		// 删除所有跟stage有关的事件
		__removeStageEvent();
	}

	/**
	 * 引擎渲染逻辑
	 * @param display 
	 * @param parentMatrix
	 */
	public function render(display:DisplayObjectContainer, ?parentMatrix:Matrix):Void {
		display.__updateTransform(display);
		renderer.renderDisplayObjectContainer(display);
		display.__dirty = false;
	}
}
