package test;

import hx.layout.VerticalLayout;
import hx.display.Quad;
import hx.layout.HorizontalLayout;
import hx.display.Sprite;
import hx.display.Scene;

/**
 * 布局渲染
 */
class LayoutRender extends Scene {
	override function onStageInit() {
		super.onStageInit();

		// 横向布局
		var box = new Sprite();
		this.addChild(box);
		box.layout = new HorizontalLayout().setGap(30);
		for (i in 0...5) {
			var quad = new Quad(100, 100, Std.random(0xffffff));
			box.addChild(quad);
		}

		// 竖向布局
		var box2 = new Sprite();
		box.addChild(box2);
		box2.layout = new VerticalLayout().setGap(30);
		for (i in 0...5) {
			var quad = new Quad(100, 100, Std.random(0xffffff));
			box2.addChild(quad);
		}

		box.x = stage.stageWidth / 2 - box.width / 2;
		box.y = 30;
	}
}
