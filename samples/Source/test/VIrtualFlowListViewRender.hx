package test;

import hx.display.ItemRenderer;
import hx.display.DisplayObjectRecycler;
import hx.layout.VirtualFlowLayout;
import hx.display.Quad;
import hx.display.Box;
import hx.layout.AnchorLayout;
import hx.layout.AnchorLayoutData;
import hx.display.ArrayCollection;
import hx.display.ListView;
import hx.display.Scene;

/**
 * 虚拟流列表视图测试用例
 */
class VirtualFlowListViewRender extends Scene {
	override function onInit() {
		super.onInit();

		var box = new Box();
		box.width = 55 * 5;
		box.height = 55 * 5;
		this.addChild(box);

		var quad = new Quad(400, 600, 0x000000);
		box.addChild(quad);
		quad.alpha = 0.5;

		var listView = new ListView();
		listView.scrollXEnable = false;
		var itemRendererRecycler = DisplayObjectRecycler.withClass(VIrtualFlowListViewItemRenderer);
		listView.itemRendererRecycler = itemRendererRecycler;
		listView.layout = new VirtualFlowLayout(50, 50, 5, 5);
		box.addChild(listView);
		listView.width = quad.width;
		listView.height = quad.height;
		box.layoutData = AnchorLayoutData.center();
		box.layout = new AnchorLayout();
		this.layout = new AnchorLayout();

		listView.data = new ArrayCollection([
			for (i in 0...10000) {
				'i';
			}
		]);
	}
}

class VIrtualFlowListViewItemRenderer extends ItemRenderer {
	override function onInit() {
		super.onInit();
		var quad = new Quad(50, 50, 0x00ff00);
		this.addChild(quad);
	}
}
