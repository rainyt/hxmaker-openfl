package test;

import hx.ui.UIManager;
import hx.assets.Assets;
import hx.ui.UIAssets;
import hx.display.Box;
import hx.layout.AnchorLayout;
import hx.display.Scene;

/**
 * 读取配置构造界面
 */
class XmlRender extends Scene {
	override function onStageInit() {
		super.onStageInit();
		var uiAssets = new Assets();
		UIManager.bindAssets(uiAssets);
		uiAssets.loadUIAssets("assets/views/XmlScene.xml");
		uiAssets.onComplete((a) -> {
			trace("加载完成");
			var view = new XmlRenderView();
			this.addChild(view);
		}).onError(err -> {
			trace("加载失败");
		});
		uiAssets.start();
	}
}

@:build(hx.macro.UIBuilder.build("assets/views/XmlScene.xml"))
class XmlRenderView extends Scene {
	override function onInit() {
		super.onInit();
		this.btn_view.clickEvent = () -> {
			trace("触发点击");
		}
	}
}
