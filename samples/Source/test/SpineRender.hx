package test;

import hx.display.Spine;
import hx.assets.SpineTextureAtlas;
import hx.assets.Assets;
import hx.display.Scene;

class SpineRender extends Scene {
	var assets:Assets = new Assets();

	override function onStageInit() {
		super.onStageInit();
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
		// 获得spine精灵图
		var spineAtlas:SpineTextureAtlas = cast assets.atlases.get("snowglobe-pro");
		var data = spineAtlas.createSkeletonData(assets.strings.get("snowglobe-pro"));
		for (i in 0...50) {
			var spine = new Spine(data);
			this.addChild(spine);
			spine.x = stage.stageWidth * Math.random();
			spine.y = stage.stageHeight * Math.random();
			spine.scaleX = spine.scaleY = 0.15;
			for (animation in spine.skeleton.data.animations) {
				trace(animation.name);
			}
			spine.animationState.setAnimationByName(0, "shake", true);
		}
	}
}
