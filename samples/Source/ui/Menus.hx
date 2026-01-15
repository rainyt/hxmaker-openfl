package ui;

import hx.layout.AnchorLayoutData;
import hx.layout.AnchorLayout;
import hx.events.Event;
import hx.events.MouseEvent;
import hx.display.TextFormat;
import hx.display.Label;
import hx.display.Scene;
import hx.display.Quad;
import hx.display.DisplayObjectContainer;
import hx.layout.VerticalLayout;
import hx.display.Box;
import hx.display.DisplayObject;

/**
 * 左侧栏功能模块
 */
class Menus extends Box {
	override function onInit() {
		super.onInit();
		this.layout = new AnchorLayout();
		this.width = 250;
		// this.height = stage.stageHeight;
		var bg = new Quad(this.width, this.height, 0x282828);
		bg.layoutData = AnchorLayoutData.fill();
		this.addChild(bg);
		var box = new Box();
		this.addChild(box);
		box.width = this.width;
		box.height = this.height;
		box.layout = new VerticalLayout().setGap(5);
		for (c in Game.tests) {
			var button = new MenuButton(c);
			box.addChild(button);
		}
	}
}

/**
 * 菜单按钮
 */
class MenuButton extends DisplayObjectContainer {
	private var __c:Class<Scene>;

	public function new(c:Class<Scene>) {
		super();
		__c = c;
		this.mouseChildren = false;
		this.addEventListener(MouseEvent.CLICK, (e) -> {
			var event = new Event("changeScene");
			event.data = __c;
			this.stage.dispatchEvent(event);
		});
	}

	override function onStageInit() {
		super.onStageInit();
		var quad = new Quad(250, 36);
		quad.alpha = 0.8;
		this.addChild(quad);
		var className = Type.getClassName(__c);
		var label = new Label(className);
		label.textFormat = new TextFormat(null, 20, 0xff0000);
		label.height = this.height;
		label.x = 10;
		label.verticalAlign = MIDDLE;
		this.addChild(label);
	}
}
