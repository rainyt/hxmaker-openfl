package test;

import hx.display.DisplayObjectContainer;
import hx.events.MouseEvent;
import hx.display.TextFormat;
import hx.display.Label;
import hx.events.Event;
import hx.display.Image;
import hx.assets.Assets;
import hx.display.Scene;

class WabbitRender extends Scene {
	/**
	 * 资源管理器
	 */
	var assets = new Assets();

	var label = new Label();

	var bunnys:Array<Bunny> = [];

	var gravity = 0.5;

	var box:DisplayObjectContainer;

	override function onStageInit() {
		super.onStageInit();
		box = new DisplayObjectContainer();
		this.addChild(box);
		for (i in 0...6) {
			assets.loadBitmapData("assets/wabbit_alpha_" + (i + 1) + ".png");
		}
		assets.onComplete((data) -> {
			this.onLoaded();
		}).onError(err -> {
			trace("加载失败");
		});
		assets.start();

		this.addChild(label);
		label.width = stage.stageWidth;
		label.horizontalAlign = CENTER;
		label.height = 50;
		label.textFormat = new TextFormat(null, 46, 0xff0000);
	}

	public function onLoaded():Void {
		this.createBunny();
		this.addEventListener(Event.UPDATE, onUpdateEvent);
	}

	override function onAddToStage() {
		super.onAddToStage();
		this.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
	}

	override function onRemoveToStage() {
		super.onRemoveToStage();
		this.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
	}

	private function onMouseDown(e:MouseEvent):Void {
		createBunny(100);
	}

	private function createBunny(counts = 500):Void {
		for (i in 0...counts) {
			var bunny = new Bunny(assets.bitmapDatas.get("wabbit_alpha_" + (Std.random(6) + 1)));
			box.addChild(bunny);
			bunny.x = Math.random() * this.stage.stageWidth;
			bunny.y = Math.random() * this.stage.stageHeight;
			bunny.speedX = Math.random() * 5;
			bunny.speedY = (Math.random() * 5) - 2.5;
			bunnys.push(bunny);
		}
		label.data = "数量：" + bunnys.length;
	}

	private function onUpdateEvent(e:Event):Void {
		for (bunny in bunnys) {
			bunny.x += bunny.speedX;
			bunny.y += bunny.speedY;
			bunny.speedY += gravity;
			if (bunny.x > stage.stageWidth) {
				bunny.speedX *= -1;
				bunny.x = stage.stageWidth;
			} else if (bunny.x < 0) {
				bunny.speedX *= -1;
				bunny.x = 0;
			}

			if (bunny.y > stage.stageHeight) {
				bunny.speedY *= -0.8;
				bunny.y = stage.stageHeight;

				if (Math.random() > 0.5) {
					bunny.speedY -= 3 + Math.random() * 4;
				}
			} else if (bunny.y < 0) {
				bunny.speedY = 0;
				bunny.y = 0;
			}
		}
	}
}

/**
 * 兔子
 */
class Bunny extends Image {
	public var speedX:Float = 1;
	public var speedY:Float = 1;
}
