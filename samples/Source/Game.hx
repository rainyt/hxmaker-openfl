import test.XmlRender;
import hx.layout.AnchorLayoutData;
import hx.layout.AnchorLayout;
import test.AnchorLayoutRender;
import test.LayoutRender;
import test.CustomRender;
import test.SpineDuckRender;
import hx.events.MouseEvent;
import hx.display.Quad;
import hx.events.Event;
import test.MovieClipRender;
import hx.display.Label;
import test.BlendModeRender;
import test.Scale9GridRender;
import test.AllDisplayRender;
import hx.display.TextFormat;
import hx.display.FPS;
import test.SpineRender;
import hx.events.KeyboardEvent;
import hx.events.Keyboard;
import test.GraphicRender;
import test.ButtonRender;
import test.WabbitRender;
import test.LabelRender;
import hx.display.Stage;
import hx.display.Scene;
import test.ImageRender;

/**
 * 游戏基础类入口
 */
class Game extends Stage {
	/**
	 * 索引
	 */
	public var index:Int = 0;

	/**
	 * 测试用例列表
	 */
	public static var tests:Array<Class<hx.display.Scene>> = [
		XmlRender
		,
		AnchorLayoutRender,
		LayoutRender,
		CustomRender,
		SpineDuckRender,
		ButtonRender,
		MovieClipRender,
		BlendModeRender,
		WabbitRender,
		Scale9GridRender,
		AllDisplayRender,
		SpineRender,
		GraphicRender,
		ImageRender,
		LabelRender
	];

	var title = new Label("Samples Name");
	var descText = new Label("使用A/D切换样品（Use A/D to switch samples）");

	override function onStageInit() {
		super.onStageInit();
		this.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);

		var fps = new FPS();
		fps.label.textFormat = new TextFormat(null, 32, 0xff0000);
		this.addChild(fps);
		fps.layoutData = AnchorLayoutData.topRight(0, 0);

		this.layout = new AnchorLayout();

		this.addChild(title);
		title.textFormat = new TextFormat(null, 26, 0xffffff);
		title.layoutData = AnchorLayoutData.bottomCenter(55, 0);

		this.addChild(descText);
		descText.textFormat = new TextFormat(null, 26, 0xffffff);
		descText.width = descText.getTextWidth();
		descText.layoutData = AnchorLayoutData.bottomCenter(15, 0);

		// 左侧菜单
		var leftMenu = new ui.Menus();
		leftMenu.layoutData = AnchorLayoutData.fillVertical(0);

		var lastButton = new Quad(100, 100, 0xff0000);
		this.addChild(lastButton);
		lastButton.layoutData = AnchorLayoutData.bottomLeft(0, leftMenu.width);
		lastButton.data = 0xff0000;
		lastButton.alpha = 1;
		lastButton.addEventListener(MouseEvent.CLICK, (e) -> {
			last();
		});

		var nextButton = new Quad(100, 100, 0xff0000);
		this.addChild(nextButton);
		nextButton.layoutData = AnchorLayoutData.bottomRight();
		nextButton.addEventListener(MouseEvent.CLICK, (e) -> {
			next();
		});

		this.addChild(leftMenu);

		this.showScene(0);

		this.stage.addEventListener("changeScene", (e:Event) -> {
			index = tests.indexOf(e.data);
			showScene(index);
		});
	}

	private function next():Void {
		index++;
		if (index >= tests.length) {
			index = 0;
		}
		showScene(index);
	}

	private function last():Void {
		index--;
		if (index < 0) {
			index = tests.length - 1;
		}
		showScene(index);
	}

	private function onKeyUp(e:KeyboardEvent):Void {
		switch e.keyCode {
			case Keyboard.A:
				last();
			case Keyboard.D:
				next();
		}
	}

	public function showScene(index:Int):Void {
		if (this.getChildAt(0) is Scene)
			this.removeChildAt(0);
		var scene:Scene = Type.createInstance(tests[index], []);
		this.addChildAt(scene, 0);
		title.data = Type.getClassName(Type.getClass(scene)) + " Samples";
		title.x = stage.stageWidth / 2 - title.getTextWidth() / 2;
		this.updateLayout();
	}
}
