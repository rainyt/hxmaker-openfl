package test;

import hx.display.Quad;
import hx.display.CustomDisplayObject;
import openfl.display.Sprite;
import hx.display.Scene;

/**
 * 自定义渲染对象
 */
class CustomRender extends Scene {
	override function onStageInit() {
		super.onStageInit();

		for (i in 0...50) {
			var quad = new Quad(100, 100, Std.random(0xffffff));
			this.addChild(quad);
			quad.x = Math.random() * stage.stageWidth;
			quad.y = Math.random() * stage.stageHeight;
		}

		// 构造一个openfl的圆形
		var quad = new Sprite();
		quad.graphics.beginFill(0xff0000);
		quad.graphics.drawCircle(100, 100, 100);
		// 使用自定义渲染对象完成渲染
		var custom = new CustomDisplayObject(quad);
		this.addChild(custom);
		custom.scaleX = 2;
		custom.x = stage.stageWidth / 2 - custom.width / 2;
		custom.y = stage.stageHeight / 2 - custom.height / 2;

		for (i in 0...50) {
			var quad = new Quad(100, 100, Std.random(0xffffff));
			this.addChild(quad);
			quad.x = Math.random() * stage.stageWidth;
			quad.y = Math.random() * stage.stageHeight;
		}
	}
}
