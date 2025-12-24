package hx.filters;

import hx.shader.InvertBlendShader;
import hx.display.DisplayObject;

/**
 * 翻转颜色滤镜，对应`BlendMode.INVERT`
 */
class InvertFilter extends BlendModeFilter {
	override function init() {
		super.init();
		this.render.shader = InvertBlendShader.getInstance();
	}
}
