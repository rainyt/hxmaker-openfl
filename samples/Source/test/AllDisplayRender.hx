package test;

import hx.displays.Graphic;
import hx.displays.Image;
import hx.displays.TextFormat;
import hx.displays.Label;
import hx.displays.Spine;
import hx.utils.atlas.SpineTextureAtlas;
import hx.displays.Quad;
import hx.utils.Assets;
import hx.displays.Scene;

class AllDisplayRender extends Scene {
	public var assets:Assets = new Assets();

	override function onStageInit() {
		super.onStageInit();
		assets.loadBitmapData("assets/logo.jpg");
		assets.loadSpineAtlas("assets/spine/snowglobe-pro.png", "assets/spine/snowglobe-pro.atlas");
		assets.loadString("assets/spine/snowglobe-pro.json");
		assets.onComplete(a -> {
			// 加载完成
			trace("加载完成");
			this.onLoaded();
		}).onError(err -> {
			trace("加载失败");
		});
		assets.start();
	}

	private function onLoaded():Void {
		// Quad
		var quad = new Quad(200, 200, 0xfff000);
		this.addChild(quad);

		// Spine
		var spineAtlas:SpineTextureAtlas = cast assets.atlases.get("snowglobe-pro");
		var data = spineAtlas.createSkeletonData(assets.strings.get("snowglobe-pro"));
		var spine = new Spine(data);
		this.addChild(spine);
		spine.scaleX = spine.scaleY = 0.15;
		spine.animationState.setAnimationByName(0, "idle", true);
		spine.x = stage.stageWidth / 2;
		spine.y = stage.stageHeight / 2;

		// 文本
		var label = new Label("Hello World");
		this.addChild(label);
		label.textFormat = new TextFormat(null, 56, 0xfff000);
		label.x = stage.stageWidth / 2 - label.getTextWidth() / 2;
		label.y = stage.stageHeight / 2 - 300;

		// 图片
		var image = new Image(assets.bitmapDatas.get("logo"));
		this.addChild(image);
		image.x = stage.stageWidth - image.width;
		image.y = stage.stageHeight - image.height;

		// 图形
		var graphic:Graphic = new Graphic();
		graphic.beginFill(0xff0000);
		graphic.drawTriangles([50, 0, 100, 100, 0, 100], [0, 1, 2], [0, 0, 0, 0, 0, 0]);
		this.addChild(graphic);
		graphic.x = stage.stageWidth / 2 - graphic.width / 2;
		graphic.y = stage.stageHeight / 2 - graphic.height / 2 + 300;
	}
}
