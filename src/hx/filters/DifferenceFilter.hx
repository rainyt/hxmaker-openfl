package hx.filters;

import hx.shader.DifferenceShader;

/**
 * 差值混合
 */
class DifferenceFilter extends BlendModeFilter {
	override function init() {
		super.init();
		this.render.shader = DifferenceShader.getInstance();
	}
}
