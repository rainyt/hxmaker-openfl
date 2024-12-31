package test;

import hx.display.DisplayObjectContainer;
import hx.gemo.Rectangle;
import hx.display.Image;
import hx.assets.Assets;
import hx.display.Scene;

/**
 * 九宫格图处理
 */
class Scale9GridRender extends Scene {
	public var assets:Assets = new Assets();

	override function onStageInit() {
		super.onStageInit();
		assets.loadBitmapData("assets/logo.jpg");
		assets.loadAtlas("assets/CommonAtlas.png", "assets/CommonAtlas.xml");
		assets.onComplete(onLoaded);
		assets.start();
	}

	private function onLoaded(assets:Assets):Void {
		trace("加载完成");

		var box = new DisplayObjectContainer();
		this.addChild(box);

		var BiaoTiDi = new Image(assets.atlases.get("CommonAtlas").bitmapDatas.get("BiaoTiDi"));

		var bgBitmapData = assets.atlases.get("CommonAtlas").bitmapDatas.get("s9_bg");
		var s9bg = new Image(bgBitmapData);
		box.addChild(s9bg);
		s9bg.width = BiaoTiDi.width - 20;
		s9bg.x = 10;
		s9bg.y = BiaoTiDi.y + BiaoTiDi.height - 30;
		s9bg.height = 900;
		var rect = new Rectangle();
		rect.css("10 29 34 28", bgBitmapData.rect.width, bgBitmapData.rect.height);
		s9bg.scale9Grid = rect;

		box.addChild(BiaoTiDi);

		var image = new Image(assets.bitmapDatas.get("logo"));
		box.addChild(image);
		image.width = 500;
		image.height = 800;
		image.x = box.width / 2 - image.width / 2;
		image.y = box.height / 2 - image.height / 2 + 40;
		// 9宫格缩放
		var rect = new Rectangle();
		rect.x = 25;
		rect.y = 25;
		rect.width = image.data.data.getWidth() - 50;
		rect.height = image.data.data.getHeight() - 50;
		image.scale9Grid = rect;

		box.scaleX = box.scaleY = 0.5;

		box.x = stage.stageWidth / 2 - box.width / 2;
		box.y = stage.stageHeight / 2 - box.height / 2 - 35;
	}
}
