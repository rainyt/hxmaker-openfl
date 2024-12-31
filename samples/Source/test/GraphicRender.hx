package test;

import hx.display.Quad;
import hx.events.Event;
import hx.display.Image;
import hx.assets.Assets;
import hx.display.Graphic;
import hx.display.Scene;

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
		for (i in 0...25) {
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

		for (i in 0...1000) {
			var quad = new Quad(32, 32, Std.random(0xFFFFFF));
			this.addChild(quad);
			quad.x = Math.random() * stage.stageWidth;
			quad.y = Math.random() * stage.stageHeight;
		}

		var image = new Image();
		image.smoothing = true;
		image.data = assets.bitmapDatas.get("logo");
		image.x = stage.stageWidth / 2;
		image.y = stage.stageHeight / 2;
		this.addChild(image);

		this.addEventListener(Event.UPDATE, (e) -> {
			image.rotation++;
		});
	}
}
