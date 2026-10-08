package test;

import hx.layout.AnchorLayout;
import hx.layout.AnchorLayoutData;
import hx.layout.VerticalLayout;
import hx.layout.VirtualVerticalLayout;
import hx.display.Box;
import hx.display.Button;
import hx.display.DisplayObjectRecycler;
import hx.display.HBox;
import hx.display.Label;
import hx.display.TextFormat;
import hx.display.Tree;
import hx.display.TreeItem;
import hx.display.TreeItemRenderer;
import hx.events.Event;
import hx.display.Scene;

/**
 * Tree组件测试用例（虚拟列表性能）
 *
 * 数据为一万条：20个模块 × 5个包 × 100个文件（共10120个节点），Tree默认使用VirtualVerticalLayout虚拟布局，
 * 只会创建可视区域内的行渲染器。通过左上角的状态面板可以观察：
 * - 可见行数：展开/折叠后扁平化的总行数
 * - 渲染器数量：实际创建的ItemRenderer数量（虚拟模式下应始终约为可视行数+缓冲，滚动一万行也不会增长）
 *
 * 使用A/D切换到该用例后，滚轮/拖拽滚动、点击行选择、点击文件夹展开、点击箭头热区折叠，底部按钮提供展开全部、
 * 折叠全部、定位到最深的文件（自动展开祖先）与虚拟/普通布局切换（用于对比性能）。
 * 多选与VSCode资源管理器一致：Ctrl/Cmd+点击切换单个选中，Shift+点击选择区间（Ctrl+Shift追加区间），
 * 右键已选中的节点会保留多选。
 */
class TreeRender extends Scene {
	/**
	 * 树组件
	 */
	var tree:Tree;

	/**
	 * 状态面板
	 */
	var status:Label;

	/**
	 * 数据总节点数
	 */
	var nodeCount:Int = 0;

	/**
	 * 最深的文件节点，用于测试scrollToItem自动展开祖先
	 */
	var lastFile:TreeItem;

	/**
	 * 帧计数，用于降低状态面板的刷新频率
	 */
	var frame:Int = 0;

	override function onInit() {
		super.onInit();

		tree = new Tree();
		tree.width = 320;
		tree.height = 600;
		// 使用VSCode暗色主题风格的背景
		tree.backgroundColor = 0x1E1E1E;
		tree.backgroundAlpha = 1;
		tree.itemRendererRecycler = DisplayObjectRecycler.withClass(TreeItemRenderer);
		tree.data = buildData();
		tree.addEventListener(Event.CHANGE, function(_) {
			trace('选中 ${tree.selectedItems.length} 项：' + (tree.selectedItem != null ? tree.selectedItem.label : "无"));
		});
		this.addChild(tree);
		tree.layoutData = AnchorLayoutData.center();

		// 状态面板：观察虚拟列表的行数与渲染器数量
		status = new Label();
		status.textFormat = new TextFormat(null, 18, 0xCCCCCC);
		status.wordWrap = false;
		this.addChild(status);
		status.layoutData = AnchorLayoutData.topLeft(20, 20);

		// 操作按钮
		var buttonBox = new HBox();
		buttonBox.gap = 10;
		buttonBox.addChild(createButton("展开全部", function() {
			tree.expandAll();
		}));
		buttonBox.addChild(createButton("折叠全部", function() {
			tree.collapseAll();
		}));
		buttonBox.addChild(createButton("定位到最深的文件", function() {
			tree.scrollToItem(lastFile);
		}));
		buttonBox.addChild(createButton("切换虚拟/普通", function() {
			if (tree.virtual) {
				tree.layout = new VerticalLayout();
			} else {
				tree.layout = new VirtualVerticalLayout(tree.rowHeight);
			}
		}));
		this.addChild(buttonBox);
		buttonBox.layoutData = AnchorLayoutData.bottomCenter(20, 0);
		buttonBox.layout = new AnchorLayout();

		this.layout = new AnchorLayout();

		// 每10帧刷新一次状态面板
		this.addEventListener(Event.UPDATE, function(_) {
			if (++frame % 10 != 0) {
				return;
			}
			// 虚拟模式下children中会额外包含一个占位对象，渲染器数量需要排除它
			var rendererCount = tree.children.length - (tree.virtual ? 1 : 0);
			status.data = '模式: ${tree.virtual ? "虚拟列表" : "普通布局"}\n节点总数: ${nodeCount}\n可见行数: ${tree.rowCount}\n渲染器数量: ${rendererCount}\n选中: ${tree.selectedItem != null ? tree.selectedItem.label : "无"}${tree.selectedItems.length > 1 ? ' (${tree.selectedItems.length}项)' : ""}';
		});
	}

	/**
	 * 生成一万条测试数据：20个模块 × 5个包 × 100个文件
	 */
	function buildData():Array<TreeItem> {
		var data:Array<TreeItem> = [];
		for (m in 0...20) {
			var module = new TreeItem('module_${m}', null, m == 0);
			for (p in 0...5) {
				var pkg = new TreeItem('package_${p}');
				for (f in 0...100) {
					var file = new TreeItem('File_${m}_${p}_${f}.hx');
					pkg.addChild(file);
					// 记录最后一个文件，用于测试scrollToItem
					if (m == 19 && p == 4 && f == 99) {
						lastFile = file;
					}
				}
				module.addChild(pkg);
			}
			data.push(module);
		}
		nodeCount = data.length * (1 + 5) + 20 * 5 * 100;
		return data;
	}

	/**
	 * 创建一个无皮肤的文本按钮
	 */
	function createButton(label:String, onClick:Void->Void):Button {
		var button = new Button(label);
		button.width = 130;
		button.height = 32;
		button.textFormat = new TextFormat(null, 16, 0xCCCCCC);
		button.clickEvent = onClick;
		return button;
	}
}
