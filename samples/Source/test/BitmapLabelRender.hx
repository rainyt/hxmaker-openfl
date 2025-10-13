package test;

import hx.assets.Assets;
import hx.display.Scene;

/**
 * 位图纹理字渲染支持
 */
class BitmapLabelRender extends Scene {
	override function onStageInit() {
		super.onStageInit();
		var assets = new Assets();
		assets.loadAtlas("assets/NumberAtlas.png", "assets/NumberAtlas.xml");
		assets.onComplete(a -> {
			for (i in 0...1000) {
				var label = new hx.display.BitmapLabel();
				label.atlas = assets.atlases.get("NumberAtlas");
				this.addChild(label);
				label.x = Math.random() * stage.stageWidth;
				label.y = Math.random() * stage.stageHeight;
				label.data = Std.string(Std.random(999999));
				label.space = -10;
			}
		});
		assets.start();
	}
}
