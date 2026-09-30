package test;

import hx.display.TreeItemRenderer;
import hx.display.DisplayObjectRecycler;
import hx.display.TreeItem;
import hx.display.Tree;
import hx.display.Scene;

/**
 * Tree组件测试支持
 */
class TreeRender extends Scene {
	override function onBuildUI() {
		super.onBuildUI();
		var tree = new Tree();
		tree.width = 400;
		tree.height = 600;
        tree.itemRendererRecycler = DisplayObjectRecycler.withClass(TreeItemRenderer);
		var src = new TreeItem("src", [new TreeItem("Main.hx"), new TreeItem("Player.hx")], true);
		tree.data = [src, new TreeItem("assets"), new TreeItem("project.hxml")];
        this.addChild(tree);
	}
}
