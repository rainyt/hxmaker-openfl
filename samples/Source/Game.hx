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
	 * 测试用例列表
	 */
	public static var tests:Array<Class<hx.displays.Scene>> = [ButtonRender, WabbitRender, ImageRender, LabelRender];

	override function onStageInit() {
		super.onStageInit();
		this.showScene(0);
	}

	public function showScene(index:Int):Void {
		var scene:Scene = Type.createInstance(tests[index], []);
		this.addChild(scene);
	}
}
