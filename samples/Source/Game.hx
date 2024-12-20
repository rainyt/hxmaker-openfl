import test.SpineRender;
import hx.events.KeyboardEvent;
import hx.events.Keyboard;
import test.GraphicRender;
import test.ButtonRender;
import test.WabbitRender;
import test.LabelRender;
import hx.displays.Stage;
import hx.displays.Scene;
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
	public static var tests:Array<Class<hx.displays.Scene>> = [SpineRender, GraphicRender, ButtonRender, WabbitRender, ImageRender, LabelRender];

	override function onStageInit() {
		super.onStageInit();
		this.showScene(0);
		this.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
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
		this.addChild(scene);
	}
}
