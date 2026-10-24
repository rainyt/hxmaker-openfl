package test;

import hx.display.ArrayCollection;
import hx.display.Button;
import hx.display.FPS;
import hx.display.Label;
import hx.display.Scene;
import hx.display.TextFormat;
import hx.display.TreeView;
import hx.events.Event;
import hx.events.MouseEvent;

/**
 * TreeView演示场景，类似VSCode资源管理器的树形列表
 *
 * 生成的节点树有数千个节点，TreeView只渲染可见行，可以感受滚动与展开/收起时的复用性能。
 */
class TreeViewDemoRender extends Scene {
	/**
	 * 生成节点的计数器，保证每次生成的数据一致
	 */
	private static var __counter:Int = 0;

	/**
	 * 一个位于深层的节点，用于演示`scrollToItem()`自动展开祖先链并定位
	 */
	private static var __deepNode:Dynamic = null;

	override function onInit() {
		super.onInit();

		// 布局整体从x=560开始，避开样例工程左侧的用例菜单
		var title = new Label("TreeView 演示 — 数千节点只渲染可见行");
		title.x = 560;
		title.y = 14;
		title.textFormat = new TextFormat(null, 16, 0xffffff);
		this.addChild(title);

		var tree = new TreeView();
		tree.x = 560;
		tree.y = 50;
		tree.width = 420;
		tree.height = 520;
		tree.backgroundColor = 0x1e1e1e;
		tree.backgroundAlpha = 1;
		tree.data = new ArrayCollection(makeRoots());
		tree.addEventListener(Event.CHANGE, function(e:Event) {
			var node = tree.selectedItem;
			log(node != null ? '选中：${Reflect.field(node, "name")}' : "取消选中");
		});
		tree.addEventListener(TreeView.ITEM_TOGGLE, function(e:Event) {
			var name = Reflect.field(e.data, "name");
			log('${tree.isExpanded(e.data) ? "展开" : "收起"}：$name');
		});
		this.addChild(tree);

		createButton("展开全部", 1040, 50, function() {
			tree.expandAll();
			log("已展开全部节点");
		});
		createButton("收起全部", 1040, 100, function() {
			tree.collapseAll();
			log("已收起全部节点");
		});
		createButton("定位深层文件", 1040, 150, function() {
			if (__deepNode != null) {
				tree.scrollToItem(__deepNode, 0.3);
				log('定位：${Reflect.field(__deepNode, "name")}');
			}
		});

		logLabel = new Label("操作日志：");
		logLabel.x = 1040;
		logLabel.y = 210;
		logLabel.width = 420;
		logLabel.textFormat = new TextFormat(null, 13, 0xcccccc);
		this.addChild(logLabel);

		var fps = new FPS();
		this.addChild(fps);
	}

	/**
	 * 日志标签
	 */
	private var logLabel:Label;

	private function log(message:String):Void {
		if (logLabel != null) {
			logLabel.data = '操作日志：$message';
		}
	}

	private function createButton(text:String, x:Float, y:Float, onClick:Void->Void):Void {
		var button = new Button(text);
		button.x = x;
		button.y = y;
		button.width = 110;
		button.height = 28;
		button.addEventListener(MouseEvent.CLICK, function(e:MouseEvent) {
			onClick();
		});
		this.addChild(button);
	}

	/**
	 * 生成演示用的目录树，目录与文件交错，前两层初始展开
	 */
	private static function makeRoots():Array<Dynamic> {
		__counter = 0;
		__deepNode = null;
		var roots:Array<Dynamic> = [];
		for (i in 0...6) {
			roots.push(makeFolder(0, 4, 'project_${i + 1}'));
		}
		return roots;
	}

	private static function makeFolder(depth:Int, maxDepth:Int, name:String):Dynamic {
		__counter++;
		var children:Array<Dynamic> = [];
		if (depth < maxDepth) {
			var folderCount = 2 + (__counter + depth) % 3;
			for (i in 0...folderCount) {
				children.push(makeFolder(depth + 1, maxDepth, 'folder_${__counter}_${i + 1}'));
			}
		}
		var fileCount = 2 + (__counter * 3 + depth) % 4;
		for (i in 0...fileCount) {
			__counter++;
			var file = {name: 'file_${__counter}.hx'};
			children.push(file);
			if (depth == maxDepth) {
				__deepNode = file;
			}
		}
		return {name: name, expanded: depth < 2, children: children};
	}
}
