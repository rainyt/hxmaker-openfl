package hx.core;

import hx.display.Stage;
import openfl.display.Sprite;

class HxmakerApplication extends Sprite {
	public function new() {
		super();
	}

	public function init(mainClasses:Class<Stage>, hdwidth:Int = 1920, hdheight:Int = 1080):Void {
		var engine = Hxmaker.init(Engine, hdwidth, hdheight);
		engine.initOpenFLRoot(this);
		Hxmaker.engine.addToStage(Type.createInstance(mainClasses, []));
	}
}
