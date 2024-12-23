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
		MovieClipRender,
		BlendModeRender,
		WabbitRender,
		Scale9GridRender,
		AllDisplayRender,
		SpineRender,
		GraphicRender,
		ButtonRender,
		ImageRender,
		LabelRender
	];

	var title = new Label("Samples Name");

	override function onStageInit() {
		super.onStageInit();
		this.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);

		var fps = new FPS();
		fps.label.textFormat = new TextFormat(null, 32, 0xff0000);
		this.addChild(fps);

		title.textFormat = new TextFormat(null, 30, 0xffffff);
		this.addChild(title);
		title.textFormat = new TextFormat(null, 26, 0xffffff);
		title.x = stage.stageWidth / 2 - title.getTextWidth() / 2;
		title.y = stage.stageHeight - title.getTextHeight() - 55;

		var descText = new Label("使用A/D切换样品（Use A/D to switch samples）");
		this.addChild(descText);
		descText.textFormat = new TextFormat(null, 26, 0xffffff);
		descText.x = stage.stageWidth / 2 - descText.getTextWidth() / 2;
		descText.y = stage.stageHeight - descText.getTextHeight() - 15;

		this.showScene(0);
	}

	private function onKeyUp(e:KeyboardEvent):Void {
		switch e.keyCode {
			case Keyboard.A:
				index--;
				if (index < 0) {
					index = tests.length - 1;
				}
				showScene(index);
			case Keyboard.D:
				index++;
				if (index >= tests.length) {
					index = 0;
				}
				showScene(index);
		}
	}

	public function showScene(index:Int):Void {
		if (this.getChildAt(0) is Scene)
			this.removeChildAt(0);
		var scene:Scene = Type.createInstance(tests[index], []);
		this.addChildAt(scene, 0);
		title.data = Type.getClassName(Type.getClass(scene)) + " Samples";
		title.x = stage.stageWidth / 2 - title.getTextWidth() / 2;
	}
}
