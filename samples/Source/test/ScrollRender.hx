package test;

import hx.display.Quad;
import hx.events.MouseEvent;
import hx.display.Scroll;
import hx.display.Scene;

/**
 * 滚动列表
 */
class ScrollRender extends Scene {
	var scroll = new Scroll();

	override function onInit() {
		super.onInit();
		this.addChild(scroll);
		scroll.width = 500;
		scroll.height = 500;
		scroll.backgroundColor = 0xffffff;
		scroll.backgroundAlpha = 0.5;
		scroll.x = 300;
		scroll.y = 300;

		var quad = new Quad(100, 100, 0xff0000);
		scroll.addChild(quad);

		// this.addChild(scroll.quad);
		// scroll.quad.x = 500;
		// scroll.quad.y = 500;
		// scroll.quad.width = 500;
		// scroll.quad.height = 500;
	}

	override function onAddToStage() {
		super.onAddToStage();
		this.stage.addEventListener(MouseEvent.CLICK, (e) -> {
			// trace(scroll, scroll.width, scroll.height, scroll.quad.parent);
			trace("点击", e.target);
		});
	}
}
