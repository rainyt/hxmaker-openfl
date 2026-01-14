package test;

import hx.particle.FourAttribute;
import hx.particle.TweenAttribute;
import hx.particle.RandomTwoAttribute;
import hx.particle.OneAttribute;
import hx.assets.Assets;
import hx.ui.UIManager;
import hx.display.Particle;
import hx.display.Scene;

class ParticleRender extends Scene {
	override function onStageInit() {
		super.onStageInit();
		var assets = new Assets();
		assets.loadBitmapData("assets/texture.png");
		assets.onComplete((a) -> {
			// 创建一个粒子
			var p = new Particle(null, assets.getBitmapData("texture"));
			// 设置粒子数量
			p.counts = 15000;
			// 设置整个粒子的持续时间
			p.duration = 10;
			this.addChild(p);
			// 设置粒子的初始位置
			p.x = this.stage.stageWidth / 2;
			p.y = this.stage.stageHeight / 2;
			// 设置粒子的生成范围
			p.widthRange = 1000;
			p.heightRange = 100;
			// 设置粒子的旋转角度
			p.rotaionAttribute.start = new OneAttribute(0);
			p.rotaionAttribute.end = new RandomTwoAttribute(180, 360);
			// 设置粒子的缩放系数
			p.scaleXAttribute.start = new OneAttribute(1);
			p.scaleXAttribute.end = new RandomTwoAttribute(3.5, 6);
			p.scaleYAttribute.start = new OneAttribute(1);
			p.scaleYAttribute.end = new RandomTwoAttribute(3.5, 6);
			// 设置粒子的速度
			p.velocity.x = new RandomTwoAttribute(-100, 100);
			p.velocity.y = new RandomTwoAttribute(-100, 100);
			// 设置粒子的重力
			p.gravity.x = new OneAttribute(0);
			p.gravity.y = new OneAttribute(500);
			// 设置粒子的加速度
			p.acceleration.x = new OneAttribute(100);
			p.acceleration.y = new OneAttribute(100);
			// 设置粒子的切向加速度
			p.tangential.x = new RandomTwoAttribute(-100, 100);
			p.tangential.y = new RandomTwoAttribute(-100, 100);
			// 设置粒子的颜色，透明度渐出渐隐效果
			p.colorAttribute.start = new FourAttribute(1, 1, 1, 0);
			p.colorAttribute.tween.pushAttribute(10, new FourAttribute(1, 1, 1, 1));
			p.colorAttribute.tween.pushAttribute(20, new FourAttribute(1, 1, 1, 1));
			p.colorAttribute.tween.pushAttribute(80, new FourAttribute(1, 1, 1, 1));
			p.colorAttribute.tween.pushAttribute(20, new FourAttribute(1, 1, 1, 0));
            // 启动粒子系统
			p.start();
		});
		assets.start();
	}
}
