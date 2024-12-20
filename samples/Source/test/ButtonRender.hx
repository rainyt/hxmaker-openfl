package test;

import hx.events.Event;
import hx.displays.TextFormat;
import hx.utils.Assets;
import hx.displays.DisplayObject;
import hx.displays.Scene;
import hx.displays.Button;

class ButtonRender extends Scene {
	/**
	 * 资源管理器
	 */
	var assets = new Assets();

	override function onStageInit() {
		super.onStageInit();
		// 开始加载资源
		assets.loadBitmapData("assets/logo.jpg");
		for (i in 0...6) {
			assets.loadBitmapData("assets/wabbit_alpha_" + (i + 1) + ".png");
		}
		assets.loadAtlas("assets/EmojAtlas.png", "assets/EmojAtlas.xml");
		assets.onComplete((data) -> {
			this.onLoaded();
		}).onError(err -> {
			trace("加载失败");
		});
		assets.start();
	}

	public function onLoaded() {
		for (i in 0...3000) {
			var button:Button = new Button("测试文案", {
				up: assets.bitmapDatas.get("logo")
			});
			button.textFormat = new TextFormat(null, 36, 0xff0000);
			this.addChild(button);
			button.clickEvent = () -> {
				trace("点击事件");
			}
			button.x = Std.random(Std.int(stage.stageWidth));
			button.y = Std.random(Std.int(stage.stageHeight));
		}
		this.addEventListener(Event.UPDATE, (e) -> {
			this.getChildAt(this.children.length - 1).rotation += 1;
		});
	}
}
