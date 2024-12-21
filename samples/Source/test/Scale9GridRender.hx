package test;

import hx.gemo.Rectangle;
import hx.displays.Image;
import hx.utils.Assets;
import hx.displays.Scene;

/**
 * 九宫格图处理
 */
class Scale9GridRender extends Scene {
	public var assets:Assets = new Assets();

	override function onStageInit() {
		super.onStageInit();
		assets.loadBitmapData("assets/logo.jpg");
		assets.onComplete(onLoaded);
		assets.start();
	}

	private function onLoaded(assets:Assets):Void {
		trace("加载完成");
		var image = new Image(assets.bitmapDatas.get("logo"));
		this.addChild(image);
		image.width = 500;
		image.height = 800;
		image.x = stage.stageWidth / 2 - image.width / 2;
		image.y = stage.stageHeight / 2 - image.height / 2;
		// 9宫格缩放
		var rect = new Rectangle();
		rect.x = 25;
		rect.y = 25;
		rect.width = image.data.data.getWidth() - 50;
		rect.height = image.data.data.getHeight() - 50;
		image.scale9Grid = rect;
	}
}
