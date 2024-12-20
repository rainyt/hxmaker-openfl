package test;

import hx.displays.TextFormat;
import hx.displays.FPS;
import hx.events.Event;
import hx.displays.Spine;
import hx.utils.atlas.SpineTextureAtlas;
import hx.utils.Assets;
import hx.displays.Scene;

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
		for (i in 0...100) {
			var spine = new Spine(data);
			this.addChild(spine);
			spine.x = stage.stageWidth * Math.random();
			spine.y = stage.stageHeight * Math.random();
			spine.scaleX = spine.scaleY = 0.15;
			this.addEventListener(Event.UPDATE, (e) -> {
				spine.update(1 / 60);
			});
			for (animation in spine.skeleton.data.animations) {
				trace(animation.name);
			}
			spine.animationState.setAnimationByName(0, "shake", true);
		}
	}
}
