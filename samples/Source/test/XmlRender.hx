package test;

import hx.layout.AnchorLayout;
import hx.display.Scene;

/**
 * 读取配置构造界面
 */
@:build(hx.macro.UIBuilder.build("assets/views/XmlScene.xml"))
class XmlRender extends Scene {
	override function onStageInit() {
		super.onStageInit();
		var uiAssets = new hx.ui.UIAssets("assets/views/XmlScene.xml");
		uiAssets.onComplete((a) -> {
			trace("加载完成");
			uiAssets.build(this);
		}).onError(err -> {
			trace("加载失败");
		});
		uiAssets.start();
	}
}
