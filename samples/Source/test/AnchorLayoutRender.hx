package test;

import hx.layout.AnchorLayoutData;
import hx.display.Quad;
import hx.display.Scene;

/**
 * AnchorLayout布局测试
 */
class AnchorLayoutRender extends Scene {
	override function onStageInit() {
		super.onStageInit();
		this.layout = new hx.layout.AnchorLayout();

		var quad = new Quad(200, 200, 0x061626);
		quad.layoutData = AnchorLayoutData.fill();
		this.addChild(quad);

		var quad = new Quad(200, 200, 0xffff00);
		quad.layoutData = AnchorLayoutData.center();
		this.addChild(quad);

		var quad = new Quad(200, 200, 0xffff00);
		quad.layoutData = AnchorLayoutData.topRight(100, 100);
		this.addChild(quad);

		var quad = new Quad(200, 200, 0xffff00);
		quad.layoutData = AnchorLayoutData.bottomRight(100, 100);
		this.addChild(quad);

		var quad = new Quad(200, 200, 0xffff00);
		quad.layoutData = AnchorLayoutData.bottomCenter(100, 0);
		this.addChild(quad);

		var quad = new Quad(200, 200, 0xffff00);
		quad.layoutData = AnchorLayoutData.topCenter(100, 0);
		this.addChild(quad);

		var quad = new Quad(200, 200, 0xffff00);
		quad.layoutData = AnchorLayoutData.topLeft(100, 300);
		this.addChild(quad);

		var quad = new Quad(200, 200, 0xffff00);
		quad.layoutData = AnchorLayoutData.middleLeft(0, 300);
		this.addChild(quad);

		var quad = new Quad(200, 200, 0xffff00);
		quad.layoutData = AnchorLayoutData.middleRight(0, 100);
		this.addChild(quad);

		var quad = new Quad(200, 200, 0xffff00);
		quad.layoutData = AnchorLayoutData.bottomLeft(100, 300);
		this.addChild(quad);
	}
}
