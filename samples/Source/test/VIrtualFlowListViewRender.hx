package test;

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

		var quad = new Quad(400, 600, 0xffffff);
		box.addChild(quad);

		var listView = new ListView();
		listView.data = new ArrayCollection([
			for (i in 0...10000) {
				'i';
			}
		]);
		var itemRendererRecycler = DisplayObjectRecycler.withClass(Quad);
		listView.itemRendererRecycler = itemRendererRecycler;
		listView.layout = new VirtualFlowLayout(50, 50, 5, 5);
		box.addChild(listView);
		listView.layoutData = AnchorLayoutData.fill(5);
		box.layoutData = AnchorLayoutData.center();
		box.layout = new AnchorLayout();
		this.layout = new AnchorLayout();
	}
}
