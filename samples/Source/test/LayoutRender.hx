package test;

import hx.layout.FlowLayout;
import hx.display.Box;
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

		// 虚拟盒子 + 流布局
		var virvaulBox = new Box();
		virvaulBox.layout = new FlowLayout();
		for (i in 0...50) {
			var quad = new Quad(100, 100, Std.random(0xffffff));
			virvaulBox.addChild(quad);
		}
		virvaulBox.width = stage.stageWidth;
		this.addChild(virvaulBox);
		virvaulBox.y = stage.stageHeight - virvaulBox.height - 100;

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
