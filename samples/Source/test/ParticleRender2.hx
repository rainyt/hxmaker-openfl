package test;

import hx.display.UILoadScene;
import hx.events.MouseEvent;
import hx.particle.FourAttribute;
import hx.particle.TweenAttribute;
import hx.particle.RandomTwoAttribute;
import hx.particle.OneAttribute;
import hx.assets.Assets;
import hx.ui.UIManager;
import hx.display.Particle;
import hx.display.Scene;

/**
 * 粒子渲染2
 */
@:build(hx.macro.UIBuilder.build("assets/views/ParticleRender2.xml"))
class ParticleRender2 extends UILoadScene {
	private var __targetX:Float = 0;
	private var __targetY:Float = 0;

	override function onLoaded() {
		super.onLoaded();
		this.particle.x = this.stage.stageWidth / 2;
		this.particle.y = this.stage.stageHeight / 2;
		this.addChild(this.particle.dynamicSprite);
		this.addEventListener(MouseEvent.MOUSE_MOVE, (e:MouseEvent) -> {
			this.__targetX = e.stageX;
			this.__targetY = e.stageY;
		});
		this.particle.dynamicSprite.x = this.particle.x;
		this.particle.dynamicSprite.y = this.particle.y;
		this.updateEnabled = true;
	}

	override function onUpdate(dt:Float) {
		super.onUpdate(dt);
		if (particle == null)
			return;
		this.particle.x += (this.__targetX - this.particle.x) * 0.1;
		this.particle.y += (this.__targetY - this.particle.y) * 0.1;
		this.particle.dynamicSprite.x = this.particle.x;
		this.particle.dynamicSprite.y = this.particle.y;
		this.particle.dynamicSprite.onUpdate(0.0016);
	}
}
