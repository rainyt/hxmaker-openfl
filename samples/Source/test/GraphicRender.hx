package test;

import hx.events.Event;
import hx.displays.Image;
import hx.utils.Assets;
import hx.displays.Graphic;
import hx.displays.Scene;

/**
 * 图形渲染用例
 */
class GraphicRender extends Scene {
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
		// 图形渲染

		for (i in 0...1000) {
			var graphic = new Graphic();
			this.addChild(graphic);
			graphic.clear();
			graphic.beginBitmapData(assets.bitmapDatas.get("logo"));
			graphic.drawTriangles([0, 0, 100, 0, 0, 100, 100, 100], [0, 1, 2, 1, 2, 3], [0, 0, 1, 0, 0, 1, 1, 1], 0.5);
			graphic.drawTriangles([-100, 100, 100, 0, 0, 400, 100, 100], [0, 1, 2, 1, 2, 3], [0, 0, 1, 0, 0, 1, 1, 1], 0.5);
			graphic.drawTriangles([200, 300, 100, 0, 0, 100, 100, 100], [0, 1, 2, 1, 2, 3], [0, 0, 1, 0, 0, 1, 1, 1], 0.5);
			graphic.x = Math.random() * stage.stageWidth;
			graphic.y = Math.random() * stage.stageHeight;
			graphic.rotation = Std.random(360);
		}

		var image = new Image();
		image.smoothing = true;
		image.data = assets.bitmapDatas.get("logo");
		this.addChild(image);

		this.addEventListener(Event.UPDATE, (e) -> {
			image.rotation++;
		});
	}
}
