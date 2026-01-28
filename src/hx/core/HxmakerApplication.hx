package hx.core;

import hx.display.Stage;
import openfl.display.Sprite;

class HxmakerApplication extends Sprite {
	public function new() {
		super();
	}

	/**
	 * 初始化应用程序
	 * @param mainClasses 主场景类
	 * @param hdwidth 高清宽度
	 * @param hdheight 高清高度
	 * @param cacheAsBitmap 是否缓存为位图
	 * @param lockLandscape 是否锁定横屏
	 */
	public function init(mainClasses:Class<Stage>, hdwidth:Int = 1920, hdheight:Int = 1080, cacheAsBitmap:Bool = false, lockLandscape:Bool = false):Void {
		var engine = Hxmaker.init(Engine, hdwidth, hdheight, cacheAsBitmap, lockLandscape);
		engine.initOpenFLRoot(this);
		Hxmaker.engine.addToStage(Type.createInstance(mainClasses, []));
	}
}
