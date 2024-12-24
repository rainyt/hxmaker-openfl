package;

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
	}
}
