package test;

import hx.events.Event;
import hx.display.TextFormat;
import hx.display.Label;
import hx.assets.Assets;
import hx.display.Scene;

/**
 * 文本渲染支持
 */
class MoreLabelRender extends Scene {
	override function onStageInit() {
		super.onStageInit();
		var labels = [];
		for (i in 0...1000) {
			var label = new Label();
			this.addChild(label);
			label.data = "随机内容：" + Std.random(9999);
			label.textFormat = new TextFormat(null, 26, 0xffffff);
			label.x = Math.random() * stage.stageWidth;
			label.y = Math.random() * stage.stageHeight;
			labels.push(label);
		}
		this.addEventListener(Event.UPDATE, (e) -> {
			for (label in labels) {
				label.data = "随机内容：" + Std.random(9999);
			}
		});
	}
}
