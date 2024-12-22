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
		WabbitRender,
		Scale9GridRender,
		AllDisplayRender,
		SpineRender,
		GraphicRender,
		ButtonRender,
		ImageRender,
		LabelRender
	];

	override function onStageInit() {
		super.onStageInit();
		this.showScene(0);
		this.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
		var fps = new FPS();
		fps.label.textFormat = new TextFormat(null, 32, 0xff0000);
		this.addChild(fps);
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
		this.removeChildren();
		var scene:Scene = Type.createInstance(tests[index], []);
		this.addChildAt(scene, 0);
	}
}
