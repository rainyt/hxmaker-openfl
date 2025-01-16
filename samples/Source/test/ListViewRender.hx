package test;

import hx.display.Quad;
import hx.display.Box;
import hx.layout.AnchorLayout;
import hx.layout.AnchorLayoutData;
import hx.display.ArrayCollection;
import hx.display.ListView;
import hx.display.Scene;

/**
 * ListView测试用例
 */
class ListViewRender extends Scene {
	override function onInit() {
		super.onInit();

		var box = new Box();
		box.width = 400;
		box.height = 600;
		this.addChild(box);

		var quad = new Quad(400, 600, 0xffffff);
		box.addChild(quad);

		var listView = new ListView();
		listView.data = new ArrayCollection([
			for (i in 0...100) {
				'Item ${i + 1}';
			}
		]);
		box.addChild(listView);
		listView.layoutData = AnchorLayoutData.fill(5);
		box.layoutData = AnchorLayoutData.center();
		box.layout = new AnchorLayout();
		this.layout = new AnchorLayout();
	}
}
