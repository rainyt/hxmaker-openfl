package;

import test.CustomRender;
import test.WabbitRender;
import test.SpineRender;
import hx.display.Label;
import hx.display.Quad;
import hx.core.Engine;
import hx.core.Hxmaker;
import hx.display.MakerDisplay;
import openfl.display.Sprite;
import openfl.display.FPS;

/**
 * 使用`hxmaker`游戏引擎
 */
class Main extends Sprite {
	public function new() {
		super();
		this.stage.color = 0x404040;
		var engine = Hxmaker.init(Engine, 1920, 1080);
		engine.initOpenFLRoot(this);
		engine.addToStage(new Game());

		// var hxmaker = new MakerDisplay(1000, 1000);
		// hxmaker.container.addChild(new Quad(100, 100, 0xff0000));
		// hxmaker.container.addChild(new Label("你好"));
		// hxmaker.container.addChild(new CustomRender());
		// this.addChild(hxmaker);
	}
}
