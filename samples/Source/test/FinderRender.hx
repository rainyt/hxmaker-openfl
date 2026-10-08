package test;

import hx.layout.AnchorLayout;
import hx.layout.AnchorLayoutData;
import hx.layout.VerticalLayout;
import hx.layout.VirtualVerticalLayout;
import hx.display.Button;
import hx.display.DisplayObjectRecycler;
import hx.display.FinderItemRenderer;
import hx.display.FinderView;
import hx.display.HBox;
import hx.display.Label;
import hx.display.TextFormat;
import hx.display.TreeItem;
import hx.events.Event;
import hx.display.Scene;

/**
 * FinderView组件测试用例（访达风格资源选择器，虚拟列表性能）
 *
 * 数据为一万条：20个模块 × 5个包 × 100个文件（共10122个节点），FinderView与Tree一样默认使用
 * VirtualVerticalLayout虚拟布局，只会创建可视区域内的行渲染器。通过左上角的状态面板可以观察：
 * - 当前目录：从根到当前目录的路径（path），双击文件夹进入下一级
 * - 可见行数：当前目录的子项数量
 * - 渲染器数量：实际创建的ItemRenderer数量（虚拟模式下应始终约为可视行数+缓冲，滚动一万行也不会增长）
 *
 * 使用A/D切换到该用例后，单击行选择（Ctrl/Cmd+点击切换、Shift+点击区间、右键选择，与Tree一致），
 * 双击文件夹进入下一级，双击第一行的`..`返回上一级（会自动选中刚退出的文件夹，访达行为），
 * 双击文件会在控制台打印"打开文件"。
 * 底部按钮提供返回上一级、回到根目录、跳转到最后一个模块（currentItem跳转）、定位到当前目录最后一项
 * （scrollToItem）与虚拟/普通布局切换（用于对比性能）。根目录额外放了两个文件用于演示foldersFirst排序。
 */
class FinderRender extends Scene {
	/**
	 * 资源选择器组件
	 */
	var finder:FinderView;

	/**
	 * 状态面板
	 */
	var status:Label;

	/**
	 * 数据总节点数
	 */
	var nodeCount:Int = 0;

	/**
	 * 最后一个模块，用于测试currentItem跳转
	 */
	var lastModule:TreeItem;

	/**
	 * 帧计数，用于降低状态面板的刷新频率
	 */
	var frame:Int = 0;

	override function onInit() {
		super.onInit();

		finder = new FinderView();
		finder.width = 320;
		finder.height = 600;
		// 使用VSCode暗色主题风格的背景
		finder.backgroundColor = 0x1E1E1E;
		finder.backgroundAlpha = 1;
		finder.itemRendererRecycler = DisplayObjectRecycler.withClass(FinderItemRenderer);
		// 文件夹稳定排在文件前面
		finder.foldersFirst = true;
		finder.data = buildData();
		finder.addEventListener(Event.CHANGE, function(_) {
			trace('选中 ${finder.selectedItems.length} 项：' + (finder.selectedItem != null ? finder.selectedItem.label : "无"));
		});
		// 双击文件时用作"打开"钩子，文件夹由组件自动进入
		finder.addEventListener(FinderView.ITEM_DOUBLE_CLICKED, function(e) {
			var item:TreeItem = e.data;
			if (!item.isFolder) {
				trace('打开文件：${item.label}');
			}
		});
		finder.addEventListener(FinderView.PATH_CHANGED, function(_) {
			trace('目录变化：${getPathText()}');
		});
		this.addChild(finder);
		finder.layoutData = AnchorLayoutData.center();

		// 状态面板：观察当前路径、可见行数与渲染器数量
		status = new Label();
		status.textFormat = new TextFormat(null, 18, 0xCCCCCC);
		status.wordWrap = false;
		this.addChild(status);
		status.layoutData = AnchorLayoutData.topLeft(20, 20);

		// 操作按钮
		var buttonBox = new HBox();
		buttonBox.gap = 10;
		buttonBox.addChild(createButton("返回上一级", function() {
			finder.goUp();
		}));
		buttonBox.addChild(createButton("回到根目录", function() {
			finder.goToRoot();
		}));
		buttonBox.addChild(createButton("进入最后模块", function() {
			// 通过currentItem直接跳转，与goInto等价
			finder.currentItem = lastModule;
		}));
		buttonBox.addChild(createButton("定位到最后一项", function() {
			var last = finder.getItemAt(finder.rowCount - 1);
			finder.scrollToItem(last);
		}));
		buttonBox.addChild(createButton("切换虚拟/普通", function() {
			if (finder.virtual) {
				finder.layout = new VerticalLayout();
			} else {
				finder.layout = new VirtualVerticalLayout(finder.rowHeight);
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
			var rendererCount = finder.children.length - (finder.virtual ? 1 : 0);
			status.data = '模式: ${finder.virtual ? "虚拟列表" : "普通布局"}\n节点总数: ${nodeCount}\n当前目录: ${getPathText()}\n可见行数: ${finder.rowCount}\n渲染器数量: ${rendererCount}\n选中: ${finder.selectedItem != null ? finder.selectedItem.label : "无"}${finder.selectedItems.length > 1 ? ' (${finder.selectedItems.length}项)' : ""}';
		});
	}

	/**
	 * 当前目录的路径文本，根层级显示"根目录"
	 */
	function getPathText():String {
		return finder.path.length > 0 ? finder.path.map(p -> p.label).join(" › ") : "根目录";
	}

	/**
	 * 生成一万条测试数据：20个模块 × 5个包 × 100个文件，根目录额外放两个文件演示foldersFirst排序
	 */
	function buildData():Array<TreeItem> {
		var data:Array<TreeItem> = [];
		for (m in 0...20) {
			var module = new TreeItem('module_${m}');
			for (p in 0...5) {
				var pkg = new TreeItem('package_${p}');
				for (f in 0...100) {
					pkg.addChild(new TreeItem('File_${m}_${p}_${f}.hx'));
				}
				module.addChild(pkg);
			}
			data.push(module);
		}
		lastModule = data[19];
		// 根目录下的散文件，配合foldersFirst观察文件夹优先排序
		data.push(new TreeItem("project.hxml"));
		data.push(new TreeItem("README.md"));
		nodeCount = 20 * (1 + 5) + 20 * 5 * 100 + 2;
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
